//
//  ReferralService.swift
//  SpeakLife
//
//  Talks to the referral Cloud Functions (getReferralCode / redeemReferral /
//  getReferralStatus). The device never touches the referral Firestore data
//  directly — everything goes through these endpoints, which key off the stable
//  RevenueCat appUserID and enforce all anti-fraud rules server-side.
//
//  Program (v1, single-sided): a non-subscriber shares their code; when 3 new
//  users join with it and finish onboarding, the inviter is granted a free
//  month of Premium via a RevenueCat promotional entitlement. The existing
//  `isPremium` flow lights up automatically once RC syncs — no extra gating.
//

import Foundation
import FirebaseAnalytics

struct ReferralStatus: Equatable {
    var code: String?
    var successfulReferrals: Int
    var rewardsEarned: Int
    var referralsNeeded: Int   // friends until the next free month
}

enum ReferralRedeemResult: Equatable {
    case granted(referralsNeeded: Int)
    case alreadyRedeemed
    case invalidCode
    case selfReferral
    case alreadyPremium
}

enum ReferralError: Error { case network, server, missingUser }

@MainActor
final class ReferralService: ObservableObject {

    static let shared = ReferralService()

    /// Friends needed per free month — mirrors `REWARD_THRESHOLD` on the server.
    static let rewardThreshold = 3

    @Published private(set) var code: String?
    @Published private(set) var successfulReferrals = 0
    @Published private(set) var rewardsEarned = 0
    @Published private(set) var referralsNeeded = ReferralService.rewardThreshold
    @Published private(set) var isLoading = false

    /// Progress within the current cycle (0..<threshold) for the progress UI.
    var progressInCycle: Int {
        Self.rewardThreshold - referralsNeeded
    }

    // A referral code captured from a share link or manual entry, redeemed once
    // the user finishes onboarding. Stored so it survives the install → launch
    // gap (Phase 2 deep-link capture writes here; manual entry redeems inline).
    private let pendingCodeKey = "pendingReferralCode"

    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Endpoints

    // us-central1 HTTPS functions for the speaklife-3e5c4 project. Honors the
    // same USE_FIREBASE_EMULATOR scheme flag as BibleChatAIService.
    private static let cloudBase = "https://us-central1-speaklife-3e5c4.cloudfunctions.net"
    private static let emulatorBase = "http://127.0.0.1:5001/speaklife-3e5c4/us-central1"

    private func endpoint(_ name: String) -> URL {
        let base = BibleChatLocal.usesEmulator ? Self.emulatorBase : Self.cloudBase
        return URL(string: "\(base)/\(name)")!
    }

    private var appUserID: String { RevenueCatManager.shared.appUserID }

    // MARK: - Public API

    /// Loads the user's code + progress. Safe to call on view appear.
    func refreshStatus() async {
        guard !appUserID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let json = try await post("getReferralStatus", body: ["appUserId": appUserID])
            apply(json)
        } catch {
            // Non-fatal: the UI just shows last-known/empty state.
        }
    }

    /// Ensures the user has a code, returning it. Used right before sharing.
    @discardableResult
    func ensureCode() async -> String? {
        if let code, !code.isEmpty { return code }
        guard !appUserID.isEmpty else { return nil }
        do {
            let json = try await post("getReferralCode", body: ["appUserId": appUserID])
            if let c = json["code"] as? String, !c.isEmpty {
                code = c
                return c
            }
        } catch { }
        return nil
    }

    /// The link a user shares with friends. Carries `?ref=CODE` so the code can
    /// be picked up post-install (Phase 2 deep-link capture); always works as a
    /// plain App Store link today.
    func shareURL(for code: String) -> URL {
        var components = URLComponents(string: APP.Product.urlID)
        components?.queryItems = [URLQueryItem(name: "ref", value: code)]
        return components?.url ?? URL(string: APP.Product.urlID)!
    }

    func shareMessage(for code: String) -> String {
        "I'm using SpeakLife to speak God's Word over my life every day. Join me with code \(code) and try it free."
    }

    /// Redeems a friend's code for the current user (the invitee path).
    func redeem(code rawCode: String) async throws -> ReferralRedeemResult {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return .invalidCode }
        guard !appUserID.isEmpty else { throw ReferralError.missingUser }

        let json = try await post("redeemReferral", body: [
            "inviteeAppUserId": appUserID,
            "code": code,
            "source": "manual",
        ])

        if json["success"] as? Bool == true {
            let needed = (json["referralsNeeded"] as? NSNumber)?.intValue ?? Self.rewardThreshold
            Analytics.logEvent(Event.referralRedeemed, parameters: ["source": "manual"])
            clearPendingCode()
            return .granted(referralsNeeded: needed)
        }

        switch json["reason"] as? String {
        case "already_redeemed": return .alreadyRedeemed
        case "self_referral":    return .selfReferral
        case "already_premium":  return .alreadyPremium
        default:                 return .invalidCode
        }
    }

    // MARK: - Pending code (for deferred / onboarding redemption)

    var pendingCode: String? {
        UserDefaults.standard.string(forKey: pendingCodeKey)
    }

    func capturePendingCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: pendingCodeKey)
    }

    private func clearPendingCode() {
        UserDefaults.standard.removeObject(forKey: pendingCodeKey)
    }

    /// Redeems a previously-captured code (e.g. after onboarding completes).
    /// No-op when there's nothing pending. Call sites can ignore the result.
    @discardableResult
    func redeemPendingCodeIfNeeded() async -> ReferralRedeemResult? {
        guard let pending = pendingCode, !pending.isEmpty else { return nil }
        return try? await redeem(code: pending)
    }

    // MARK: - Networking

    private func apply(_ json: [String: Any]) {
        if let c = json["code"] as? String, !c.isEmpty { code = c }
        successfulReferrals = (json["successfulReferrals"] as? NSNumber)?.intValue ?? successfulReferrals
        rewardsEarned = (json["rewardsEarned"] as? NSNumber)?.intValue ?? rewardsEarned
        referralsNeeded = (json["referralsNeeded"] as? NSNumber)?.intValue ?? referralsNeeded
    }

    private func post(_ name: String, body: [String: Any]) async throws -> [String: Any] {
        var request = URLRequest(url: endpoint(name))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReferralError.network }
        guard http.statusCode == 200 else { throw ReferralError.server }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
