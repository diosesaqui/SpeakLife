//
//  StandInviteSheet.swift
//  SpeakLife
//
//  The send. Spec §9 and §9.5.
//
//  Two things here are conversion, not decoration:
//
//   1. It shares an IMAGE, not a bare URL. A rendered card lands in a text
//      thread far harder than a link does, and `StreakShareCardRenderer` proves
//      the app can already draw one.
//   2. The human code rides in the message body underneath. Branch's deferred
//      matching is probabilistic, not guaranteed, so somebody who installs from
//      the App Store and does not get matched can still type eight characters.
//
//  It also says plainly, before the link exists, that everyone invited will see
//  the theme being stood for. A campaign theme can be a private thing.
//
//  ⚠️ THIS SHEET OWNS CREATING THE ROOM, and that is the point (see
//  `StandInviteSource`). Callers used to mint the room themselves and only
//  present this once they had one, so every failure on the way — no network, a
//  Cloud Function error, anonymous auth turned off in the Firebase console —
//  ended as a `print` and a button that did nothing at all. Presenting first
//  and resolving inside means there is exactly one place a failure can land,
//  and it is a screen with a Try again on it.
//

import SwiftUI
import SpeakLifeCore

/// What the sheet was opened for.
///
/// `.newStand` is the case that matters: the sheet appears immediately, shows a
/// spinner, and creates the room behind it. Nothing the user taps can silently
/// do nothing.
enum StandInviteSource {
    /// A stand that already exists.
    case room(StandRoom)
    /// No stand yet. Reuse an active one for this campaign, or mint one.
    case newStand(Enforcement)

    var enforcement: Enforcement {
        switch self {
        case .room(let room):      return room.enforcement
        case .newStand(let plan):  return plan
        }
    }
}

struct StandInviteSheet: View {

    let source: StandInviteSource

    init(source: StandInviteSource) { self.source = source }
    /// Convenience for the callers that already hold a room.
    init(room: StandRoom) { self.source = .room(room) }

    @State private var roomId: String?
    @State private var code: String?
    @State private var shareImage: UIImage?
    @State private var isWorking = true
    @State private var failureShown: InviteFailure?
    @Environment(\.dismiss) private var dismiss

    private var enforcement: Enforcement { source.enforcement }

    private var link: String {
        "https://speaklife.app.link/stand/\(code ?? "")"
    }

    /// The message body. The link and the typed code both appear, because the
    /// two install paths need different things.
    private var shareText: String {
        """
        I'm speaking God's word over \(enforcement.theme.name.lowercased()) for 7 days. Stand with me.

        \(link)

        (or open SpeakLife and enter code \(formattedCode))
        """
    }

    private var formattedCode: String {
        Self.formatted(code)
    }

    /// Takes the value directly rather than reading `code`.
    ///
    /// `prepare()` assigns `code` and then needs the formatted form in the same
    /// pass to render the card. Reading the `@State` it just wrote is not
    /// reliably the new value, so the card could be drawn with an empty code.
    private static func formatted(_ raw: String?) -> String {
        guard let raw, raw.count == StandLink.codeLength else { return raw ?? "" }
        let mid = raw.index(raw.startIndex, offsetBy: 4)
        return "\(raw[raw.startIndex..<mid])-\(raw[mid...])"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Gradients().speakLifeCYOCell.ignoresSafeArea()
                VStack(spacing: DS.Spacing.lg) {
                    if isWorking {
                        working
                    } else if let failureShown {
                        failureView(failureShown)
                    } else {
                        ready
                    }
                }
                .padding(DS.Spacing.md)
            }
            .navigationTitle("Invite someone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(DS.Palette.gold)
                }
            }
        }
        .task { await prepare() }
    }

    // MARK: - States

    /// Says what it is doing. A bare spinner on a screen that just appeared out
    /// of nowhere reads as a hang.
    private var working: some View {
        VStack(spacing: DS.Spacing.sm) {
            ProgressView().tint(.white)
            Text("Getting your invite ready…")
                .font(DS.Typography.callout)
                .foregroundColor(DS.Palette.textSecondary)
        }
    }

    private var ready: some View {
        VStack(spacing: DS.Spacing.lg) {
            if let shareImage {
                Image(uiImage: shareImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                    .shadow(color: DS.Elevation.medium.color,
                            radius: DS.Elevation.medium.radius,
                            x: DS.Elevation.medium.x, y: DS.Elevation.medium.y)
            }

            // Said before the link is sent, not after. The theme is visible to
            // everyone invited, and that can be a private thing.
            Text("Everyone you invite will see you're standing for \(enforcement.theme.name.lowercased()).")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ShareLink(item: shareText,
                      preview: SharePreview("Stand with me", image: previewImage)) {
                Label("Send the invite", systemImage: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(DS.Palette.gold))
            }
            .simultaneousGesture(TapGesture().onEnded {
                AnalyticsService.shared.track("stand_invite_shared", parameters: [
                    "room_id": roomId ?? "", "channel": "share_sheet",
                ])
            })

            codeRow
        }
    }

    private var codeRow: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("OR GIVE THEM THIS CODE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundColor(DS.Palette.textSecondary)

            Button {
                UIPasteboard.general.string = formattedCode
                PremiumHaptics.success()
            } label: {
                Text(formattedCode)
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(DS.Palette.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md,
                                                 style: .continuous)
                        .fill(DS.Palette.surface))
            }
            .accessibilityLabel("Invite code \(formattedCode). Tap to copy.")

            Text("Expires in 14 days.")
                .font(.system(size: 11))
                .foregroundColor(DS.Palette.textSecondary.opacity(0.7))
        }
    }

    /// User copy on top, the underlying reason underneath in small type.
    ///
    /// The detail line is deliberate. Without it a "couldn't create the invite"
    /// is unactionable for the person hitting it AND for whoever they send the
    /// screenshot to — and the first real failure of this feature was a
    /// disabled auth provider, which is invisible from the outside but names
    /// itself precisely in the underlying error.
    private func failureView(_ failure: InviteFailure) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(DS.Palette.gold.opacity(0.8))

            Text(failure.text)
                .font(DS.Typography.body)
                .foregroundColor(DS.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let detail = failure.detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(DS.Palette.textSecondary.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            Button("Try again") {
                Task { await prepare() }
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(DS.Palette.gold))
            .padding(.top, DS.Spacing.xs)
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    private var previewImage: Image {
        shareImage.map { Image(uiImage: $0) } ?? Image(systemName: "hands.and.sparkles")
    }

    // MARK: - Work

    /// Codes already minted this session, by room.
    ///
    /// Opening the sheet twice used to mint two invites, and the sixth open hit
    /// MAX_ACTIVE_INVITES — which surfaced as "This stand is full.", the copy
    /// for an entirely different failure. Reusing the code within a session is
    /// also just correct: it is the same invitation.
    @MainActor
    private static var codesByRoom: [String: String] = [:]

    @MainActor
    private func prepare() async {
        isWorking = true
        failureShown = nil
        do {
            let id: String
            do {
                id = try await resolveRoomId()
            } catch {
                throw InviteFailure.creating(error)
            }
            roomId = id

            let resolved: String
            if let cached = Self.codesByRoom[id] {
                resolved = cached
            } else {
                do {
                    resolved = try await StandService.shared.createInvite(roomId: id)
                } catch {
                    throw InviteFailure.minting(error)
                }
                Self.codesByRoom[id] = resolved
            }
            code = resolved
            shareImage = StandInviteCardRenderer.render(
                theme: enforcement.theme.name,
                title: enforcement.displayTitle,
                code: Self.formatted(resolved)
            )
        } catch let failure as InviteFailure {
            failureShown = failure
            AnalyticsService.shared.track("stand_invite_failed", parameters: [
                "stage": failure.stage,
                "reason": failure.reason,
            ])
        } catch {
            failureShown = InviteFailure.creating(error)
        }
        isWorking = false
    }

    /// The room to invite into, creating it if this is a fresh stand.
    ///
    /// `createStand` already hands back a first code, so it is cached here
    /// rather than thrown away and immediately re-minted.
    @MainActor
    private func resolveRoomId() async throws -> String {
        switch source {
        case .room(let room):
            return room.id

        case .newStand(let plan):
            if let existing = StandInviteLauncher.existingRoom(for: plan) {
                return existing.id
            }
            _ = try await StandAuthCoordinator.shared.ensureAccount()
            let name = UserDefaults.standard.string(forKey: "userName") ?? "Friend"
            let result = try await StandService.shared.createStand(
                enforcement: plan, name: name)
            Self.codesByRoom[result.roomId] = result.code
            return result.roomId
        }
    }
}

// MARK: - Failure copy

/// A failure with copy already chosen for the stage it happened in.
///
/// `StandError`'s own `errorDescription` is written for the JOIN path — where
/// every code the server returns really is about a typed invite code. On the
/// create path the same codes mean different things, and using the join copy
/// tells somebody who never typed anything to "check that code". So the mapping
/// happens here, where the call site is known.
struct InviteFailure: LocalizedError {

    /// What the user reads.
    let text: String
    /// The underlying reason, shown small. Nil when `text` already is it.
    let detail: String?
    /// Analytics only.
    let stage: String
    let reason: String

    var errorDescription: String? { text }

    /// `ensureAccount` or `createStand` failed — there is no stand yet.
    static func creating(_ error: Error) -> InviteFailure {
        let raw = detail(for: error, call: "createStand")
        if isOffline(error) {
            return InviteFailure(text: "You're offline. Reconnect and try again.",
                                 detail: nil, stage: "create", reason: "offline")
        }
        guard let stand = error as? StandError else {
            // Not a callable error, so it came from `ensureAccount` — Firebase
            // Auth. The raw message names the cause precisely (a disabled
            // provider says so in as many words) and nothing generic here could
            // replace it, so it is labelled for what it actually is.
            return InviteFailure(text: "Couldn't start the stand.",
                                 detail: detail(for: error, call: "signIn"),
                                 stage: "create", reason: "auth")
        }
        switch stand {
        case .full:
            return InviteFailure(
                text: "You're running as many stands as you can at once. Finish or leave one first.",
                detail: nil, stage: "create", reason: stand.analyticsReason)
        case .badCode:
            return InviteFailure(
                text: "We couldn't build an invite for this week. Try switching to a different one.",
                detail: raw, stage: "create", reason: stand.analyticsReason)
        case .throttled:
            return InviteFailure(text: "Too many tries. Give it a minute.",
                                 detail: nil, stage: "create", reason: stand.analyticsReason)
        case .needsAuth:
            return InviteFailure(text: "We couldn't sign you in. Try again in a moment.",
                                 detail: raw, stage: "create", reason: stand.analyticsReason)
        default:
            return InviteFailure(text: "Couldn't start the stand.",
                                 detail: raw, stage: "create", reason: stand.analyticsReason)
        }
    }

    /// The stand exists; minting its invite code failed.
    static func minting(_ error: Error) -> InviteFailure {
        let raw = detail(for: error, call: "createStandInvite")
        if isOffline(error) {
            return InviteFailure(text: "You're offline. Reconnect and try again.",
                                 detail: nil, stage: "invite", reason: "offline")
        }
        guard let stand = error as? StandError else {
            return InviteFailure(text: "Couldn't create the invite code.",
                                 detail: raw, stage: "invite", reason: "unknown")
        }
        switch stand {
        case .revoked:
            // permission-denied here is "Only the owner can invite.", not a
            // revoked invite.
            return InviteFailure(text: "Only the person who started this stand can invite others.",
                                 detail: nil, stage: "invite", reason: stand.analyticsReason)
        case .full:
            // resource-exhausted here is "Too many open invites.", not a full room.
            return InviteFailure(text: "This stand already has too many open invites.",
                                 detail: nil, stage: "invite", reason: stand.analyticsReason)
        case .alreadyFinished:
            return InviteFailure(text: "This stand already finished.",
                                 detail: nil, stage: "invite", reason: stand.analyticsReason)
        case .notFound:
            return InviteFailure(text: "This stand no longer exists.",
                                 detail: nil, stage: "invite", reason: stand.analyticsReason)
        case .needsAuth:
            // The account already worked one call earlier — createStand ran, or
            // there would be no stand to invite into. So this is the server
            // refusing THIS callable, not a sign-in the user can do anything
            // about, and the copy must not send them chasing one. The detail
            // line carries what actually matters.
            return InviteFailure(text: "The server turned this down. Try again in a moment.",
                                 detail: raw, stage: "invite", reason: stand.analyticsReason)
        default:
            return InviteFailure(text: "Couldn't create the invite code.",
                                 detail: raw, stage: "invite", reason: stand.analyticsReason)
        }
    }

    private static func isOffline(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain
            || ns.localizedDescription.localizedCaseInsensitiveContains("offline")
    }

    /// The small line under the copy: which call failed, and what it said.
    ///
    /// Deliberately NOT `StandError.errorDescription` — that is join-path prose
    /// ("That code doesn't exist.") and pasting it under create-path copy is how
    /// the last two failures read as the wrong problem. The wire reason and the
    /// callable name are what make a screenshot worth receiving.
    private static func detail(for error: Error, call: String) -> String {
        if let stand = error as? StandError {
            if case .unknown(let message) = stand { return "\(call) · \(message)" }
            return "\(call) · \(stand.analyticsReason)"
        }
        let ns = error as NSError
        let text = error.localizedDescription
        return text.isEmpty ? "\(call) · \(ns.domain) \(ns.code)" : "\(call) · \(text)"
    }
}
