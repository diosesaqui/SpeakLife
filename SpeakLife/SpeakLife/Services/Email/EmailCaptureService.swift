//
//  EmailCaptureService.swift
//  SpeakLife
//
//  Sends an address from the onboarding email screen to the `collectEmail`
//  Cloud Function, which stores it and subscribes it to the Klaviyo list.
//
//  Two things this service is built around:
//
//  1. **The user never waits on the network.** The email screen sits one tap
//     before a hard paywall. A spinner there, or worse a failure alert, costs a
//     conversion to save an address — a terrible trade. So the screen advances
//     immediately and the send happens behind it.
//
//  2. **A failed send is not a lost address.** Onboarding is the one moment we
//     get to ask, and a fresh install on a weak connection is exactly when it
//     fails. Anything that doesn't reach the server is queued to disk and
//     retried on the next launch, so the address survives the app being killed.
//
//  The Klaviyo key lives in the function's secrets, never in this binary.
//

import Foundation
import FirebaseAuth

final class EmailCaptureService {
    static let shared = EmailCaptureService()

    // us-central1 HTTPS function for the speaklife-3e5c4 project. Mirrors
    // BibleChatAIService: DEBUG builds with USE_FIREBASE_EMULATOR=1 in the
    // scheme hit the local emulator, everything else hits production.
    private static let cloudEndpoint = URL(string: "https://us-central1-speaklife-3e5c4.cloudfunctions.net/collectEmail")!
    private static let emulatorEndpoint = URL(string: "http://127.0.0.1:5001/speaklife-3e5c4/us-central1/collectEmail")!

    private var endpoint: URL {
        BibleChatLocal.usesEmulator ? Self.emulatorEndpoint : Self.cloudEndpoint
    }

    // MARK: - Persisted state

    private enum Keys {
        /// Set once the address has actually reached the server. Gates the
        /// onboarding screen so a returning user is never asked twice.
        static let captured = "emailCaptureCompleted"
        /// The address itself, for the Profile row and for prefilling.
        ///
        /// Deliberately the LEGACY key. `AppState.email` was `@AppStorage("email")`
        /// before the subsystem was removed, and installs that gave an address
        /// back then still have it sitting in UserDefaults under this name.
        /// Reusing it means those users see their address in the Profile row and
        /// are never asked for it again, instead of being treated as brand new.
        static let address = "email"
        /// A submission that has not reached the server yet, retried on launch.
        static let pending = "emailCapturePendingPayload"
        /// Legacy: set when the post-purchase ask has been shown once, so it
        /// never reappears. Same key the removed EmailCaptureView used, so
        /// anyone who already dismissed it is not asked again.
        static let shownAfterPurchase = "hasShownEmailCapture"
    }

    private let defaults: UserDefaults
    private let session: URLSession

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
    }

    /// True once we hold an address for this install. The onboarding step reads
    /// this and skips itself.
    ///
    /// The second clause is what carries legacy users across: someone who gave
    /// their address through the old capture sheet has `email` in UserDefaults
    /// but none of this service's own flags, and asking them again for
    /// something they already gave is the rudest thing this feature could do.
    var hasCapturedEmail: Bool {
        defaults.bool(forKey: Keys.captured) || !capturedEmail.isEmpty
    }

    /// The captured address, or "" when there is none.
    var capturedEmail: String {
        (defaults.string(forKey: Keys.address) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the post-purchase ask has already had its one chance.
    var hasShownPostPurchaseAsk: Bool { defaults.bool(forKey: Keys.shownAfterPurchase) }

    /// Spend the post-purchase ask, whether or not the user actually submitted.
    /// Mirrors the old view's `onDisappear`: one ask per install, ever.
    func markPostPurchaseAskShown() {
        defaults.set(true, forKey: Keys.shownAfterPurchase)
    }

    // MARK: - Validation

    /// Deliberately permissive, and matched to the function's own check: one @,
    /// something either side, a dot in the domain. Stricter client validation
    /// rejects real addresses (plus-addressing, long TLDs) and every rejection
    /// is a subscriber lost at the only moment we get to ask.
    static func isValidEmail(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 254 else { return false }
        return trimmed.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }

    // MARK: - Submitting

    /// Record an address and send it. Returns immediately; the network call
    /// runs detached so the caller can advance the flow on the same tap.
    ///
    /// - Parameters:
    ///   - email: what the user typed. Trimmed and lowercased here.
    ///   - source: where in the app the ask happened, e.g. "onboarding".
    ///   - variant: the onboarding arm, so list segmentation matches the funnel.
    ///   - burden: the area they picked, for segmented sends.
    func submit(
        email: String,
        source: String,
        variant: String? = nil,
        burden: String? = nil,
        firstName: String? = nil
    ) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidEmail(normalized) else { return }

        // Stored before the send, not after. If the app is killed mid-flight the
        // address is still on disk to retry, and the user is not asked again for
        // something they already gave us.
        defaults.set(normalized, forKey: Keys.address)

        var payload: [String: String] = ["email": normalized, "source": source]
        payload["appUserId"] = RevenueCatManager.shared.appUserID
        // The Firebase UID is the legacy document id: `userId ?? sanitizedEmail`.
        // Usually nil during onboarding, because nothing has created an account
        // yet — which is exactly why the server keeps the sanitized-email
        // fallback rather than requiring one.
        if let uid = Auth.auth().currentUser?.uid, !uid.isEmpty {
            payload["userId"] = uid
        }
        payload["appVersion"] =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        if let variant { payload["variant"] = variant }
        if let burden { payload["burden"] = burden }
        if let firstName, !firstName.isEmpty { payload["firstName"] = firstName }

        queue(payload)

        Task.detached(priority: .utility) { [weak self] in
            await self?.flushPending()
        }
    }

    /// Re-send the address we already hold, tagged `post_purchase`.
    ///
    /// This is what the removed `EmailConfirmationView` was for: someone who
    /// gave their address earlier subscribes, and the profile should say so, so
    /// buyer and non-buyer flows can be segmented apart in Klaviyo.
    ///
    /// It does that without a screen. The old build put a whole confirmation
    /// sheet in front of a user who had already typed their address, purely to
    /// change a string on the server. Asking someone to re-confirm something
    /// they never changed is friction spent on our bookkeeping, seconds after
    /// they paid — the worst possible moment to take up their attention.
    func retagAsPostPurchase() {
        let stored = capturedEmail
        guard !stored.isEmpty else { return }
        submit(email: stored, source: "post_purchase")
    }

    /// Retry anything a previous run could not deliver. Called on launch.
    func retryPendingIfNeeded() {
        guard !pendingQueue.isEmpty else { return }
        Task.detached(priority: .background) { [weak self] in
            await self?.flushPending()
        }
    }

    // MARK: - Delivery

    /// Append to the pending queue.
    ///
    /// A LIST, not a single slot. The slot version silently dropped an
    /// undelivered address whenever a second submit landed on top of it — an
    /// onboarding address still waiting on a bad connection, discarded by the
    /// post-purchase re-tag or by the user editing their address in Profile.
    /// That is exactly the loss the queue exists to prevent.
    ///
    /// Same-address submissions collapse: a re-tag carries no new address, only
    /// a newer `source`, so keeping both would just send the same record twice.
    private func queue(_ payload: [String: String]) {
        var pending = pendingQueue
        if let email = payload["email"] {
            pending.removeAll { $0["email"] == email }
        }
        pending.append(payload)
        // Bounded: an install that somehow never delivers must not grow an
        // unbounded array in UserDefaults.
        if pending.count > 10 { pending.removeFirst(pending.count - 10) }
        defaults.set(pending, forKey: Keys.pending)
    }

    private var pendingQueue: [[String: String]] {
        if let queued = defaults.array(forKey: Keys.pending) as? [[String: String]] {
            return queued
        }
        // Tolerate the single-dictionary shape an earlier build of this branch
        // wrote, so a TestFlight install mid-upgrade does not silently drop the
        // address it was still holding.
        if let single = defaults.dictionary(forKey: Keys.pending) as? [String: String] {
            return [single]
        }
        return []
    }

    /// Sends the queued payload, clearing it only on a definitive outcome.
    ///
    /// "Definitive" is doing real work here: a 2xx means delivered, and a 4xx
    /// means the server will never accept this payload however many times we
    /// send it (a malformed address that slipped past the local check), so both
    /// clear the queue. A 5xx or a transport error is the server's problem or
    /// the network's, both of which pass — those stay queued for the next
    /// launch. Clearing on those would throw the address away for a reason that
    /// has nothing to do with the address.
    private func flushPending() async {
        for payload in pendingQueue {
            await send(payload)
        }
    }

    /// Sends one queued payload and resolves its place in the queue.
    private func send(_ payload: [String: String]) async {
        guard let email = payload["email"], !email.isEmpty else {
            drop(payload)
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }

            switch http.statusCode {
            case 200...299:
                drop(payload)
                defaults.set(true, forKey: Keys.captured)
                AnalyticsService.shared.track("email_capture_delivered", parameters: [
                    "source": payload["source"] ?? "unknown"
                ])
            case 400...499:
                // Unfixable by retrying. Drop it rather than carry a poison
                // payload on every launch for the life of the install.
                drop(payload)
                // Forget the address too. It was stored optimistically at
                // submit time, and leaving it behind would keep
                // `hasCapturedEmail` true — so every surface would go on
                // believing we hold an address the server has permanently
                // refused, and the user would never be asked again.
                if defaults.string(forKey: Keys.address) == email {
                    defaults.removeObject(forKey: Keys.address)
                }
                AnalyticsService.shared.track("email_capture_rejected", parameters: [
                    "status": http.statusCode
                ])
            default:
                AnalyticsService.shared.track("email_capture_deferred", parameters: [
                    "status": http.statusCode
                ])
            }
        } catch {
            // Offline or timed out. Stays queued; next launch tries again.
            AnalyticsService.shared.track("email_capture_deferred", parameters: ["status": 0])
        }
    }

    /// Remove one payload from the queue, matched on its address.
    private func drop(_ payload: [String: String]) {
        let email = payload["email"]
        let remaining = pendingQueue.filter { $0["email"] != email }
        if remaining.isEmpty {
            defaults.removeObject(forKey: Keys.pending)
        } else {
            defaults.set(remaining, forKey: Keys.pending)
        }
    }
}
