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
        /// The address itself, for the profile row and for prefilling.
        static let address = "emailCaptureAddress"
        /// A submission that has not reached the server yet, retried on launch.
        static let pending = "emailCapturePendingPayload"
    }

    private let defaults: UserDefaults
    private let session: URLSession

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
    }

    /// True once an address has been accepted by the server. The onboarding
    /// step reads this and skips itself.
    var hasCapturedEmail: Bool { defaults.bool(forKey: Keys.captured) }

    /// The captured address, if there is one.
    var capturedEmail: String? { defaults.string(forKey: Keys.address) }

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
    func submit(email: String, source: String, variant: String?, burden: String?) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidEmail(normalized) else { return }

        // Stored before the send, not after. If the app is killed mid-flight the
        // address is still on disk to retry, and the user is not asked again for
        // something they already gave us.
        defaults.set(normalized, forKey: Keys.address)

        var payload: [String: String] = ["email": normalized, "source": source]
        payload["appUserId"] = RevenueCatManager.shared.appUserID
        if let variant { payload["variant"] = variant }
        if let burden { payload["burden"] = burden }

        queue(payload)

        Task.detached(priority: .utility) { [weak self] in
            await self?.flushPending()
        }
    }

    /// Retry anything a previous run could not deliver. Called on launch.
    func retryPendingIfNeeded() {
        guard defaults.dictionary(forKey: Keys.pending) != nil else { return }
        Task.detached(priority: .background) { [weak self] in
            await self?.flushPending()
        }
    }

    // MARK: - Delivery

    private func queue(_ payload: [String: String]) {
        defaults.set(payload, forKey: Keys.pending)
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
        guard let payload = defaults.dictionary(forKey: Keys.pending) as? [String: String],
              let email = payload["email"], !email.isEmpty else { return }

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
                defaults.removeObject(forKey: Keys.pending)
                defaults.set(true, forKey: Keys.captured)
                AnalyticsService.shared.track("email_capture_delivered", parameters: [
                    "source": payload["source"] ?? "unknown"
                ])
            case 400...499:
                // Unfixable by retrying. Drop it rather than carry a poison
                // payload on every launch for the life of the install.
                defaults.removeObject(forKey: Keys.pending)
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
}
