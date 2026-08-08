//
//  SoulProfileFirestoreMirror.swift
//  SpeakLife
//
//  Prepares the local SoulProfile for the server, keyed by the RevenueCat
//  appUserId — the same identity `bibleChat` already meters on (see
//  BibleChatService.send, which sends RevenueCatManager.shared.appUserID).
//  Using the identical key is what lets the AI proxies read the profile
//  without a second identity to reconcile.
//
//  The device does NOT write to Firestore directly. The app has no anonymous
//  Firebase Auth, so there is no request.auth.uid to bind ownership to, and
//  any client-writable rule for `soulProfiles` reduces to an open-write path:
//  a shape check on appUserId is trivially satisfied by choosing both the doc
//  id and the field. Per-document size caps bound how big each write is, not
//  how many a script can make. That is the same client-trust assumption the
//  declarationMatch proxy exists to remove, so `soulProfiles` is server-only
//  in firestore.rules and the profile is persisted by the Cloud Function that
//  receives it (the admin SDK bypasses rules).
//
//  What survives here is the payload encoding — the request bodies for those
//  functions are built from exactly this shape, so there is still one
//  definition and nothing to drift.
//
//  Contract: this must never block, never throw, and never fail onboarding.
//  Every error path is a silent no-op plus an analytics counter.
//

import Foundation

final class SoulProfileFirestoreMirror: SoulProfileRemoteMirrorProtocol {

    static let collection = "soulProfiles"

    func mirror(_ profile: SoulProfile) {
        // Purchases.shared traps before configure(); appUserID returns "" in
        // that window, and a profile with no id can never be joined back to a
        // user — so there is nothing worth sending.
        let appUserId = RevenueCatManager.shared.appUserID
        guard !appUserId.isEmpty else {
            AnalyticsService.shared.track("soul_profile_mirror_skipped", parameters: [
                "reason": "no_app_user_id"
            ])
            return
        }

        guard Self.requestPayload(for: profile, appUserId: appUserId) != nil else {
            AnalyticsService.shared.track("soul_profile_mirror_skipped", parameters: [
                "reason": "encode_failed"
            ])
            return
        }

        // Deliberately not sent yet. The endpoint that persists this is the
        // weeklyFocus function, which already receives the profile in its
        // request body — wiring a second one-off upload now would mean two
        // ways to write the same document. Until then the profile lives
        // locally (soul_profile_v1) and in iCloud via SyncedSettingsStore,
        // which is everything the shipped features actually read.
        AnalyticsService.shared.track("soul_profile_mirror_deferred", parameters: [
            "reason": "awaiting_server_endpoint"
        ])
    }

    /// SoulProfile → the request body the Cloud Functions expect, with the
    /// identity attached.
    static func requestPayload(for profile: SoulProfile, appUserId: String) -> [String: Any]? {
        guard var payload = firestorePayload(for: profile) else { return nil }
        payload["appUserId"] = appUserId
        return payload
    }

    /// SoulProfile → Firestore document body. Goes through JSON so the wire
    /// shape is exactly the Codable shape (one definition, no hand-maintained
    /// second mapping to drift). Nil fields are dropped by `encodeIfPresent`,
    /// which is what makes `merge: true` safe.
    static func firestorePayload(for profile: SoulProfile) -> [String: Any]? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(profile),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any]
        else { return nil }
        return dictionary
    }
}
