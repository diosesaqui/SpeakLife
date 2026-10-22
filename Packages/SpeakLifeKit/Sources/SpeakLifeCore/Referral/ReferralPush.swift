//
//  ReferralPush.swift
//  SpeakLifeCore
//
//  The push contract between functions/referral.js and the app's notification
//  handler. The server sends exactly `referral_push_fixture.json` as the data
//  payload (BE-CON-01 asserts it); this type recognises it (FE-CON-01 reads the
//  same file). A rename on either side fails a test instead of silently
//  dropping the user on Home.
//

import Foundation

public enum ReferralPush {

    /// The `deepLink` value `SpeakLifeApp.handleNotificationContent` routes on.
    public static let deepLink = "referral"

    /// True for a referral push ("A friend joined", "Your free year is ready").
    public static func isReferral(_ userInfo: [AnyHashable: Any]) -> Bool {
        (userInfo["deepLink"] as? String) == deepLink
    }
}
