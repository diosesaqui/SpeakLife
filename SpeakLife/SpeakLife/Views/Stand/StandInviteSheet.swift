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
    /// Open the system share sheet by itself, once, as soon as the invite is
    /// ready. Only for callers whose button already said "Invite someone": the
    /// tap was the decision, so asking for a second tap on "Send the invite"
    /// is where 43 of 56 people stopped. Callers that open this to show the
    /// card first leave it off.
    let autoShare: Bool
    /// Called once an invite actually goes out (see `countsAsSent`). The
    /// day-1 ask uses it to close itself behind this sheet, so Done after a
    /// send does not land the user back on "Who needs this with you?".
    let onSent: (() -> Void)?

    init(source: StandInviteSource, autoShare: Bool = false,
         onSent: (() -> Void)? = nil) {
        self.source = source
        self.autoShare = autoShare
        self.onSent = onSent
    }
    /// Convenience for the callers that already hold a room.
    init(room: StandRoom, autoShare: Bool = false) {
        self.source = .room(room)
        self.autoShare = autoShare
        self.onSent = nil
    }

    @State private var roomId: String?
    @State private var code: String?
    @State private var shareImage: UIImage?
    @State private var isWorking = true
    @State private var showShareSheet = false
    @State private var failureShown: InviteFailure?
    /// Set the moment the automatic share sheet is presented, and never
    /// cleared. It is what keeps a re-render, a Try again, or dismissing the
    /// share sheet from opening it a second time.
    @State private var didAutoShare = false
    /// At least one share finished with the user actually sending.
    @State private var hasSent = false
    @Environment(\.dismiss) private var dismiss

    private var enforcement: Enforcement { source.enforcement }

    /// Built by `StandLink`, not here.
    ///
    /// This string used to be a second, hardcoded copy of the invite URL, so
    /// the host lived in two places and the one that actually gets SENT was
    /// the copy — `StandLink.shareURL` was never called by anything.
    private var link: String {
        guard let code, let url = StandLink.shareURL(for: code) else { return "" }
        return url.absoluteString
    }

    /// The message body: a personal ask, the link, and the code as the
    /// fallback for anyone Branch's deferred matching misses.
    ///
    /// Short on purpose. It sits under the card in a text thread, and the
    /// first line is what shows in the notification preview.
    private var shareText: String {
        var parts = [StandInviteCopy.ask(enforcement.theme)]
        if !link.isEmpty { parts.append(link) }
        if code != nil { parts.append("Link won't open? Use code \(formattedCode) in SpeakLife.") }
        return parts.joined(separator: "\n\n")
    }

    /// Said before the link is sent, not after. The theme is visible to
    /// everyone invited, and that can be a private thing.
    private var privacyLine: String {
        "They'll see you're standing for \(StandInviteCopy.secondPerson(enforcement.theme))."
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
                if isWorking {
                    working
                } else if let failureShown {
                    failureView(failureShown)
                        .padding(DS.Spacing.md)
                } else {
                    StandInviteReadyView(
                        card: shareImage,
                        privacyLine: privacyLine,
                        formattedCode: formattedCode,
                        recipientNote: recipientNote,
                        hasSent: hasSent,
                        onSend: { presentShare(trigger: "tap") }
                    )
                    .task { await autoShareIfNeeded() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Spends the automatic share first. Inside its 650ms
                        // wait the `.task` is not cancelled until the dismissal
                        // finishes, so it could otherwise fire mid-dismiss.
                        didAutoShare = true
                        dismiss()
                    }
                    .foregroundColor(DS.Palette.gold)
                }
            }
            // The binding is cleared here, in `onDismiss`, and never from the
            // activity controller's completion. That completion runs while
            // UIKit is already dismissing the controller, and writing the
            // binding there as well asks SwiftUI to dismiss a second time,
            // which can take a parent sheet down with it.
            .sheet(isPresented: $showShareSheet, onDismiss: { showShareSheet = false }) {
                StandActivitySheet(items: shareItems) { activity, completed in
                    shareFinished(activity: activity, completed: completed)
                }
                // Half height first, like the system share sheet, so the card
                // stays in view behind it.
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
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

    /// RETIRED, BUT STILL REMOTE. This was a boxed warning above the send
    /// button: "If they already have SpeakLife, ask them to update to 4.65 or
    /// later. Older versions can't open the invite."
    ///
    /// It existed because builds 4.59 to 4.64 claim `speaklife.app.link` but
    /// cannot route `/stand/…`, so a recipient on one of them taps the link,
    /// the app opens, and nothing happens (docs/STAND_TOGETHER_HANDOFF.md,
    /// Step 2d). The sender was the only person in the chain who could be
    /// told.
    ///
    /// It came out because it cost more than it saved. Those builds are now a
    /// small share of users, and the warning sat on the one button this screen
    /// exists for: 43 of the 56 people who opened this sheet in its last 30
    /// days never tapped Send. A recipient on an old build can still update and
    /// re-tap the same link, since codes live 14 days and `joinStand` treats
    /// `alreadyMember` as success.
    ///
    /// The default is empty, so nothing renders. The key is still read, so if
    /// the old-build share ever climbs again, setting
    /// `standInviteRecipientNote` in Remote Config brings back a quiet line
    /// under the button without a build.
    private var recipientNote: String {
        DefaultFeatureFlags.shared.string("standInviteRecipientNote", default: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

            Button {
                Task { await prepare() }
            } label: {
                Text("Try again")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(DS.Palette.gold))
            }
            .buttonStyle(.dsPressable())
            .padding(.top, DS.Spacing.xs)
        }
        .padding(.horizontal, DS.Spacing.sm)
    }

    /// The card FIRST, then the message body.
    ///
    /// ⚠️ THIS IS WHY IT IS NOT A `ShareLink`. `ShareLink(item:preview:)` sends
    /// `item` and nothing else — `preview` is only the thumbnail drawn inside
    /// the share sheet, never part of the payload. So `item: shareText` shipped
    /// text alone, which is the single thing this screen exists not to do: the
    /// rendered card is what makes an invite land in a thread rather than read
    /// as a link somebody forwarded.
    ///
    /// A `Transferable` with both an image and a text representation does not
    /// fix it either — the receiving app picks ONE, so Messages would attach the
    /// card and silently drop the typed code underneath it. Both have to travel,
    /// because the code is the fallback for everybody Branch's deferred matching
    /// misses. `UIActivityViewController` is what carries an image and a string
    /// together, so the invite goes as a card with the link and the code beneath
    /// it.
    ///
    /// Text-only when the render failed, which is the old behavior and still
    /// better than sending nothing.
    private var shareItems: [Any] {
        var items: [Any] = []
        if let shareImage { items.append(shareImage) }
        items.append(shareText)
        return items
    }

    // MARK: - Sharing

    /// Three events, because auto-share changed what "opened" means:
    ///
    /// - `stand_invite_share_opened` (`trigger`: tap or auto) every time the
    ///   share sheet comes up.
    /// - `stand_invite_shared` ONLY on a real tap of "Send the invite", so it
    ///   keeps its old meaning. Firing it on the automatic open would meet the
    ///   plan's shared/created target by construction.
    /// - `stand_invite_share_completed` when the sheet closes. The real "sent"
    ///   signal is `completed = true` with `sent = true` (not Copy, not Save).
    private func presentShare(trigger: String) {
        guard code != nil else { return }
        AnalyticsService.shared.track("stand_invite_share_opened", parameters: [
            "room_id": roomId ?? "",
            "trigger": trigger,
            "has_image": shareImage != nil,
        ])
        if trigger == "tap" {
            AnalyticsService.shared.track("stand_invite_shared", parameters: [
                "room_id": roomId ?? "",
                "channel": "share_sheet",
                "has_image": shareImage != nil,
            ])
        }
        guard showShareSheet else {
            showShareSheet = true
            return
        }
        // Still true with nothing on screen (the only state in which this
        // button can be tapped while it is true). Reset, then present once the
        // reset has been applied, so a stuck binding can never block a send.
        showShareSheet = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            showShareSheet = true
        }
    }

    /// Copying the text or saving the image completes the share sheet but
    /// reaches nobody, so neither flips the screen to "on its way".
    static func countsAsSent(activity: String?, completed: Bool) -> Bool {
        guard completed else { return false }
        let notSent: Set<String> = [
            UIActivity.ActivityType.copyToPasteboard.rawValue,
            UIActivity.ActivityType.saveToCameraRoll.rawValue,
        ]
        return !notSent.contains(activity ?? "")
    }

    /// Reports only. The binding is cleared by the sheet's `onDismiss`.
    private func shareFinished(activity: String?, completed: Bool) {
        let sent = Self.countsAsSent(activity: activity, completed: completed)
        AnalyticsService.shared.track("stand_invite_share_completed", parameters: [
            "room_id": roomId ?? "",
            "completed": completed,
            "sent": sent,
            "activity": activity ?? "none",
        ])
        if sent {
            hasSent = true
            Juice.play(.success)
            onSent?()
        }
    }

    /// Opens the share sheet once, by itself, when this sheet was opened from
    /// an "Invite someone" tap.
    ///
    /// ⚠️ THE DELAY IS LOAD-BEARING. This screen is itself a sheet, and when
    /// the room and code are already cached the ready state appears while that
    /// sheet is still sliding up. SwiftUI drops a sheet presented during
    /// another presentation's animation ("Attempt to present … which is
    /// already presenting"), and the flag below would then be spent on a sheet
    /// that never showed. Waiting just past the system sheet animation lets the
    /// presentation settle first. `.task` is cancelled if the user closes this
    /// screen during the wait, so nothing opens over a sheet that is gone.
    @MainActor
    private func autoShareIfNeeded() async {
        guard autoShare, !didAutoShare else { return }
        try? await Task.sleep(nanoseconds: 650_000_000)
        guard !Task.isCancelled, !didAutoShare, !showShareSheet,
              !isWorking, failureShown == nil, code != nil else { return }
        didAutoShare = true
        presentShare(trigger: "auto")
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

    /// `stand_invite_sheet_ready` and `stand_invite_sheet_failed` split the
    /// gap between `stand_created` and `stand_invite_shared` into "the invite
    /// never loaded" and "it loaded and they chose not to send".
    @MainActor
    private func prepare() async {
        isWorking = true
        failureShown = nil
        do {
            let resolvedRoom: (id: String, isNew: Bool)
            do {
                resolvedRoom = try await resolveRoom()
            } catch {
                throw InviteFailure.creating(error)
            }
            let id = resolvedRoom.id
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
                headline: StandInviteCopy.cardHeadline(enforcement.theme),
                title: enforcement.displayTitle,
                code: Self.formatted(resolved)
            )
            AnalyticsService.shared.track("stand_invite_sheet_ready", parameters: [
                "room_id": id,
                "source": resolvedRoom.isNew ? "new" : "existing",
                "has_image": shareImage != nil,
            ])
        } catch let failure as InviteFailure {
            failureShown = failure
            AnalyticsService.shared.track("stand_invite_failed", parameters: [
                "stage": failure.stage,
                "reason": failure.reason,
            ])
            AnalyticsService.shared.track("stand_invite_sheet_failed", parameters: [
                "stage": failure.stage,
                "reason": failure.reason,
            ])
        } catch {
            let failure = InviteFailure.creating(error)
            failureShown = failure
            AnalyticsService.shared.track("stand_invite_sheet_failed", parameters: [
                "stage": failure.stage,
                "reason": failure.reason,
            ])
        }
        isWorking = false
    }

    /// The room to invite into, creating it if this is a fresh stand. `isNew`
    /// is true only when this call minted it.
    ///
    /// `createStand` already hands back a first code, so it is cached here
    /// rather than thrown away and immediately re-minted.
    @MainActor
    private func resolveRoom() async throws -> (id: String, isNew: Bool) {
        switch source {
        case .room(let room):
            return (room.id, false)

        case .newStand(let plan):
            if let existing = StandInviteLauncher.existingRoom(for: plan) {
                return (existing.id, false)
            }
            _ = try await StandAuthCoordinator.shared.ensureAccount()
            let name = UserDefaults.standard.string(forKey: "userName") ?? "Friend"
            let result = try await StandService.shared.createStand(
                enforcement: plan, name: name)
            Self.codesByRoom[result.roomId] = result.code
            return (result.roomId, true)
        }
    }
}

// MARK: - Ready

/// The ready state, on its own so it can be previewed without a network.
///
/// One job: send the invite. The card leads, one headline says what this is,
/// one gold button sends it, and the code (the fallback for a link that will
/// not open) waits behind a quiet disclosure instead of competing with it.
struct StandInviteReadyView: View {

    let card: UIImage?
    let privacyLine: String
    let formattedCode: String
    /// Empty unless Remote Config turns the old-build note back on.
    let recipientNote: String
    let hasSent: Bool
    let onSend: () -> Void

    @State private var showCode = false
    @State private var copied = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                cardImage
                    .padding(.top, DS.Spacing.xs)

                VStack(spacing: DS.Spacing.xs) {
                    Text(hasSent ? "Your invite is on its way" : "Stand with someone this week")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundColor(DS.Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)

                    Text(privacyLine)
                        .font(DS.Typography.callout)
                        .foregroundColor(DS.Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DS.Spacing.sm)

                VStack(spacing: DS.Spacing.sm) {
                    sendButton

                    if !recipientNote.isEmpty {
                        Text(recipientNote)
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                codeDisclosure
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
            .animation(reduceMotion ? nil : DS.Motion.smooth, value: hasSent)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var cardImage: some View {
        if let card {
            Image(uiImage: card)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 375)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .stroke(DS.Palette.gold.opacity(0.25), lineWidth: 1)
                )
                .dsShadow(DS.Elevation.high)
                .accessibilityLabel("Your invite card")
        } else {
            // The render failed. The invite still goes as text, so the screen
            // keeps its shape rather than collapsing around a missing card.
            Image(systemName: "person.2.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(DS.Palette.gold)
                .frame(width: 120, height: 120)
                .background(Circle().fill(DS.Palette.gold.opacity(0.12)))
                .accessibilityHidden(true)
        }
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Label(hasSent ? "Send to someone else" : "Send the invite",
                  systemImage: "paperplane.fill")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(DS.Gradient.gold))
                .contentShape(Capsule())
        }
        .buttonStyle(.dsPressable())
    }

    private var codeDisclosure: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button {
                Juice.play(.tapLight)
                withAnimation(reduceMotion ? nil : DS.Motion.smooth) { showCode.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("Can't open the link? Share a code")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(showCode ? 180 : 0))
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.Palette.textSecondary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityHint(showCode ? "Hides the invite code" : "Shows the invite code")

            if showCode {
                codeTile
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var codeTile: some View {
        Button {
            UIPasteboard.general.string = formattedCode
            PremiumHaptics.success()
            copied = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                copied = false
            }
        } label: {
            VStack(spacing: DS.Spacing.xs) {
                Text(formattedCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(DS.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(copied ? "Copied" : "Tap to copy. Good for 14 days.")
                    .font(DS.Typography.caption)
                    .foregroundColor(copied ? DS.Palette.gold : DS.Palette.textSecondary)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Palette.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
        .accessibilityLabel("Invite code \(formattedCode)")
        .accessibilityHint("Copies the code")
    }
}

// MARK: - Share sheet

/// `UIActivityViewController` with its completion reported back.
///
/// The shared `ShareSheet` has no way to pass a completion in, and now that
/// the sheet can open by itself, "the share sheet appeared" no longer means
/// "somebody chose to send". The completion is the only honest signal of a
/// send.
private struct StandActivitySheet: UIViewControllerRepresentable {

    let items: [Any]
    let onFinish: (_ activity: String?, _ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items,
                                                  applicationActivities: nil)
        controller.completionWithItemsHandler = { activity, completed, _, _ in
            onFinish(activity?.rawValue, completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview("Ready") {
    ZStack {
        Gradients().speakLifeCYOCell.ignoresSafeArea()
        StandInviteReadyView(
            card: StandInviteCardRenderer.render(
                headline: StandInviteCopy.cardHeadline(.anxiety),
                title: "Enforcing Peace",
                code: "ABCD-2345"),
            privacyLine: "They'll see you're standing for peace.",
            formattedCode: "ABCD-2345",
            recipientNote: "",
            hasSent: false,
            onSend: {}
        )
    }
}

#Preview("Sent, long theme") {
    ZStack {
        Gradients().speakLifeCYOCell.ignoresSafeArea()
        StandInviteReadyView(
            card: StandInviteCardRenderer.render(
                headline: StandInviteCopy.cardHeadline(.fertility),
                title: "Enforcing God's Promise",
                code: "WXYZ-6789"),
            privacyLine: "They'll see you're standing for \(StandInviteCopy.secondPerson(.fertility)).",
            formattedCode: "WXYZ-6789",
            recipientNote: "",
            hasSent: true,
            onSend: {}
        )
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
