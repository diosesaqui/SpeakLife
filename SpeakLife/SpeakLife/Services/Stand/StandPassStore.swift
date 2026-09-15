//
//  StandPassStore.swift
//  SpeakLife
//
//  The Stand Pass: seven days of full access for somebody who accepted an
//  invitation. Spec §10.
//
//  The run IS the trial, and it ends on a day-7 celebration with someone they
//  love — which is the best paywall moment the app has.
//
//  ⚠️ The pass is SERVER-WRITTEN AND CLIENT-UNWRITABLE. `firestore.rules`
//  forbids the client touching `users/{uid}.standPass`, because a client that
//  can write it mints itself premium. This type only ever READS. If you find
//  yourself adding a write here, the rules will reject it, and that is correct.
//

import Foundation
import FirebaseFirestore
import SpeakLifeCore

@MainActor
final class StandPassStore: ObservableObject {

    static let shared = StandPassStore()

    /// When the current pass runs out. Nil when there is none.
    @Published private(set) var expiresAt: Date?

    /// Mirrored locally so the premium check works offline and at launch,
    /// before the Firestore read lands. Worst case a tampered local value buys
    /// one device a few days; the server value re-asserts on the next read, and
    /// nothing here can extend the real grant.
    private let expiryKey = "standPassExpiresAt"

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() {
        let stored = UserDefaults.standard.double(forKey: expiryKey)
        if stored > 0 { expiresAt = Date(timeIntervalSince1970: stored) }
    }

    /// True while an unexpired pass is in hand. OR this into the app's premium
    /// check — never replace the real entitlement with it.
    var isActive: Bool {
        guard let expiresAt else { return false }
        return expiresAt > Date()
    }

    func startObserving() {
        guard let uid = StandAuthCoordinator.shared.currentUid else { return }
        listener?.remove()
        listener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snap, _ in
                let ts = snap?.data()?["standPass"] as? [String: Any]
                let date = (ts?["expiresAt"] as? Timestamp)?.dateValue()
                Task { @MainActor in self?.apply(date) }
            }
    }

    func stopObserving() {
        listener?.remove()
        listener = nil
    }

    private func apply(_ date: Date?) {
        expiresAt = date
        if let date {
            UserDefaults.standard.set(date.timeIntervalSince1970, forKey: expiryKey)
        } else {
            UserDefaults.standard.removeObject(forKey: expiryKey)
        }
    }

    /// Days left, for the banner. Never negative.
    var daysRemaining: Int {
        guard let expiresAt, expiresAt > Date() else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
        return max(days, 0) + 1
    }
}

// MARK: - Feature flag

/// Reads through the existing `DefaultFeatureFlags` seam, which the app
/// installs with the Firebase Remote Config implementation at startup.
enum FeatureFlag {

    /// Off by default. Flipping it off hides every Stand surface, and the
    /// user's campaign keeps running locally — because the room was only ever
    /// a mirror of it.
    static var standTogetherEnabled: Bool {
        DefaultFeatureFlags.shared.bool("stand_together_enabled", default: false)
    }
}
