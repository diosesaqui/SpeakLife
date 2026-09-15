//
//  StandService.swift
//  SpeakLife
//
//  The only Firestore-aware layer of Stand With Me. Everything above it works
//  in `StandRoom` / `StandMember` (SpeakLifeCore, Foundation only), and
//  everything below it is the Cloud Functions in functions/standTogether.js.
//
//  Full design: docs/STAND_TOGETHER_SPEC.md. Two rules from there govern this
//  file and should not be tidied away:
//
//   1. THE ROOM IS A MIRROR (spec §2). `recordDay` cannot throw, cannot block,
//      and cannot touch EnforcementProgress. A failed write costs a dot on a
//      week strip. That is the whole reason the rest of the feature is allowed
//      to be this simple.
//
//   2. JOINING IS SERVER-ONLY. Every roster change goes through a callable.
//      The single direct client write is the day mirror below, which exists as
//      a direct write only so it queues offline.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseFunctions
import SpeakLifeCore
import SpeakLifeServices

@MainActor
final class StandService: ObservableObject, StandMirroring {

    static let shared = StandService()

    // MARK: - Published state

    /// Rooms this user belongs to, freshest first. Driven by a live listener
    /// while a Stand screen is on-screen and by the cache otherwise.
    @Published private(set) var rooms: [StandRoom] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    /// Set when a stand finishes so the Today tab can present the celebration,
    /// mirroring how `EnforcementService.justCompleted` works.
    @Published var justCompletedRoom: StandRoom?

    // MARK: - Dependencies

    private let db = Firestore.firestore()
    private lazy var functions = Functions.functions()
    private var listeners: [String: ListenerRegistration] = [:]
    private let cacheKey = "cachedStandRooms"

    private var uid: String? { StandAuthCoordinator.shared.currentUid }

    private init() {}

    // No deinit.
    //
    // `listeners` is main-actor isolated and a deinit is nonisolated, so
    // reading it there does not compile under strict concurrency. There is also
    // nothing to clean up: this is a `static let` singleton that lives for the
    // process, so its deinit would never run. Listener teardown happens in
    // `stopListening()`, which the screens call.

    // MARK: - Firestore date bridge
    //
    // SpeakLifeCore cannot name `Timestamp`, so decoding takes a converter.
    // This is it — the one place Firebase's date type is known.

    private static let dateFromFirestore: (Any?) -> Date? = { value in
        if let ts = value as? Timestamp { return ts.dateValue() }
        if let date = value as? Date { return date }
        return nil
    }

    // MARK: - StandMirroring
    //
    // Called from EnhancedStreakViewModel.completeTask via the StandMirror
    // seam. Everything here is best-effort by contract.

    nonisolated func recordDay(_ dayNumber: Int) {
        Task { @MainActor [weak self] in
            await self?.mirrorDay(dayNumber)
        }
    }

    private func mirrorDay(_ dayNumber: Int) async {
        guard FeatureFlag.standTogetherEnabled, let uid else { return }

        // Read room ids from the cache rather than the network: this runs the
        // instant a burst completes, and the mirror must never make the
        // celebration wait on a round trip.
        let ids = rooms.filter { $0.status == .active }.map(\.id)
        guard !ids.isEmpty else { return }

        let stamp = StandDayStamp.stamp()
        let payload: [String: Any] = [
            "members.\(uid).dayNumber": dayNumber,
            // arrayUnion makes a repeat write on the same day free, which is
            // what lets this be called without tracking whether it already ran.
            "members.\(uid).daysSpoken": FieldValue.arrayUnion([stamp]),
            "members.\(uid).lastSpokeAt": FieldValue.serverTimestamp(),
            "members.\(uid).tz": StandDayStamp.currentTimeZoneIdentifier,
            "lastActivityAt": FieldValue.serverTimestamp(),
        ]

        for id in ids {
            // Nested field paths, so two members writing at the same moment
            // touch different paths in one document and neither clobbers the
            // other.
            //
            // No await on the result and no retry: with offline persistence on,
            // Firestore queues this and flushes it on reconnect. A write that is
            // still rejected after that is a dot on a strip, and swallowing it
            // is the documented behavior, not an oversight.
            db.collection("standRooms").document(id).updateData(payload) { error in
                if let error {
                    print("⚠️ Stand mirror failed for \(id): \(error.localizedDescription)")
                }
            }
        }

        AnalyticsService.shared.track("stand_day_spoken", parameters: [
            "day": dayNumber,
            "room_count": ids.count,
        ])
    }

    // MARK: - Listening

    /// Attach live listeners for every room this user is in.
    ///
    /// Called when a Stand surface appears. One listener per room, and a room
    /// is one document, so a twelve-person stand costs exactly one listener and
    /// one read per change rather than N+1.
    func startListening() {
        guard FeatureFlag.standTogetherEnabled, let uid else { return }
        isLoading = rooms.isEmpty

        // Attach to the cached ids immediately so a returning user sees their
        // stand without waiting on a round trip, then reconcile against the
        // authoritative list. standRoomIds is server-written (firestore.rules
        // forbids the client touching it), so it is the source of truth for
        // membership — the cache is only ever a head start.
        attach(to: cachedRoomIds())

        db.collection("users").document(uid).getDocument { [weak self] snap, _ in
            let ids = snap?.data()?["standRoomIds"] as? [String] ?? []
            Task { @MainActor in
                self?.attach(to: ids)
                self?.saveCache()
            }
        }
    }

    func stopListening() {
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }

    private func attach(to ids: [String]) {
        // Drop listeners for rooms we are no longer in.
        for (id, registration) in listeners where !ids.contains(id) {
            registration.remove()
            listeners[id] = nil
        }
        rooms.removeAll { !ids.contains($0.id) }

        for id in ids where listeners[id] == nil {
            listeners[id] = db.collection("standRooms").document(id)
                .addSnapshotListener { [weak self] snap, error in
                    Task { @MainActor in
                        self?.handle(id: id, snapshot: snap, error: error)
                    }
                }
        }
        if ids.isEmpty { isLoading = false }
    }

    private func handle(id: String, snapshot: DocumentSnapshot?, error: Error?) {
        isLoading = false
        if let error {
            lastError = error.localizedDescription
            return
        }
        guard let data = snapshot?.data() else {
            // The room was deleted — the last member left, or it was swept.
            rooms.removeAll { $0.id == id }
            listeners[id]?.remove()
            listeners[id] = nil
            saveCache()
            return
        }
        guard let room = StandRoom(id: id, data: data, date: Self.dateFromFirestore) else { return }

        let wasComplete = rooms.first { $0.id == id }?.everyoneFinished ?? false
        if let index = rooms.firstIndex(where: { $0.id == id }) {
            rooms[index] = room
        } else {
            rooms.append(room)
        }
        rooms.sort { ($0.lastActivityAt ?? .distantPast) > ($1.lastActivityAt ?? .distantPast) }

        // Present the celebration on the transition, not on every snapshot —
        // otherwise reopening a finished stand re-congratulates them forever.
        if room.everyoneFinished, !wasComplete {
            justCompletedRoom = room
            AnalyticsService.shared.track("stand_completed", parameters: [
                "room_id": room.id,
                "member_count": room.activeMembers.count,
            ])
        }
        saveCache()
    }

    // MARK: - Callables

    /// Create a stand for a campaign and return its first invite code.
    func createStand(enforcement: Enforcement, name: String) async throws -> (roomId: String, code: String) {
        let payload: [String: Any] = [
            "enforcement": try Self.encode(enforcement),
            "name": name,
            "tz": StandDayStamp.currentTimeZoneIdentifier,
        ]
        let result = try await call("createStand", payload)
        guard let roomId = result["roomId"] as? String,
              let code = result["code"] as? String else { throw StandError.malformedResponse }

        AnalyticsService.shared.track("stand_created", parameters: [
            "enforcement_id": enforcement.id,
            "theme": enforcement.theme.rawValue,
            "is_generated": enforcement.isGenerated,
        ])
        startListening()
        return (roomId, code)
    }

    func createInvite(roomId: String) async throws -> String {
        let result = try await call("createStandInvite", ["roomId": roomId])
        guard let code = result["code"] as? String else { throw StandError.malformedResponse }
        return code
    }

    func revokeInvite(code: String) async throws {
        _ = try await call("revokeStandInvite", ["code": code])
    }

    /// Redeem an invite code.
    ///
    /// `alreadyMember` is a SUCCESS, not an error: tapping the same link twice,
    /// or opening it on a second device, must open the room. An error screen at
    /// the moment somebody accepted an invitation is the worst possible outcome
    /// of the whole flow.
    @discardableResult
    func joinStand(code: String, name: String) async throws -> StandJoinOutcome {
        let payload: [String: Any] = [
            "code": code,
            "name": name,
            "tz": StandDayStamp.currentTimeZoneIdentifier,
        ]
        let result = try await call("joinStand", payload)
        guard let roomId = result["roomId"] as? String else { throw StandError.malformedResponse }

        let campaign = (result["enforcement"] as? [String: Any])
            .flatMap { StandRoom.decodeEnforcement($0) }
        let outcome = StandJoinOutcome(
            roomId: roomId,
            alreadyMember: (result["alreadyMember"] as? Bool) ?? false,
            enforcement: campaign
        )

        AnalyticsService.shared.track("stand_joined", parameters: [
            "room_id": roomId,
            "already_member": outcome.alreadyMember,
        ])
        startListening()
        return outcome
    }

    func leaveStand(roomId: String) async throws {
        let room = rooms.first { $0.id == roomId }
        _ = try await call("leaveStand", ["roomId": roomId])
        rooms.removeAll { $0.id == roomId }
        listeners[roomId]?.remove()
        listeners[roomId] = nil
        saveCache()

        AnalyticsService.shared.track("stand_left", parameters: [
            "room_id": roomId,
            "day_number": room?.member(uid ?? "")?.dayNumber ?? 0,
            "was_owner": room?.member(uid ?? "")?.isOwner ?? false,
        ])
    }

    // MARK: - Calling

    private func call(_ name: String, _ payload: [String: Any]) async throws -> [String: Any] {
        do {
            let result = try await functions.httpsCallable(name).call(payload)
            return result.data as? [String: Any] ?? [:]
        } catch let error as NSError {
            throw StandError(error)
        }
    }

    private static func encode(_ enforcement: Enforcement) throws -> [String: Any] {
        let data = try JSONEncoder().encode(enforcement)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StandError.malformedResponse
        }
        return dict
    }

    // MARK: - Cache
    //
    // Room ids only, so the UI knows a stand EXISTS before the listener lands
    // and does not flash an empty state on every launch. The room bodies are
    // not cached: the listener replaces them within a second, and a stale
    // roster on screen is worse than a brief skeleton.

    private func saveCache() {
        UserDefaults.standard.set(rooms.map(\.id), forKey: cacheKey)
    }

    private func cachedRoomIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: cacheKey) ?? []
    }
}

// MARK: - Supporting types

struct StandJoinOutcome {
    let roomId: String
    let alreadyMember: Bool
    let enforcement: Enforcement?
}

/// Maps the callable error codes in functions/standTogether.js onto copy.
///
/// Each case is a branch covered by a test in
/// functions/test/standTogether.test.js — keep them in step.
enum StandError: LocalizedError {
    case notFound
    case badCode
    case revoked
    case expired
    case alreadyFinished
    case full
    case throttled
    case needsAuth
    case malformedResponse
    case unknown(String)

    init(_ error: NSError) {
        guard error.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: error.code) else {
            self = .unknown(error.localizedDescription)
            return
        }
        switch code {
        case .notFound:           self = .notFound
        case .invalidArgument:    self = .badCode
        case .permissionDenied:   self = .revoked
        case .deadlineExceeded:   self = .expired
        case .failedPrecondition: self = .alreadyFinished
        case .resourceExhausted:  self = .full
        case .unauthenticated:    self = .needsAuth
        default:                  self = .unknown(error.localizedDescription)
        }
    }

    var errorDescription: String? {
        switch self {
        case .notFound:         return "That code doesn't exist."
        case .badCode:          return "Check that code. It should be 8 letters and numbers."
        case .revoked:          return "This invite was turned off."
        case .expired:          return "This invite expired."
        case .alreadyFinished:  return "This stand already finished."
        case .full:             return "This stand is full."
        case .throttled:        return "Too many tries. Give it a minute."
        case .needsAuth:        return "Something went wrong signing you in."
        case .malformedResponse: return "Something went wrong. Try again."
        case .unknown(let m):   return m
        }
    }

    /// For `stand_join_failed`. Kept short and stable so the funnel groups.
    var analyticsReason: String {
        switch self {
        case .notFound:          return "not_found"
        case .badCode:           return "bad_code"
        case .revoked:           return "revoked"
        case .expired:           return "expired"
        case .alreadyFinished:   return "completed"
        case .full:              return "full"
        case .throttled:         return "throttled"
        case .needsAuth:         return "needs_auth"
        case .malformedResponse: return "malformed"
        case .unknown:           return "unknown"
        }
    }
}
