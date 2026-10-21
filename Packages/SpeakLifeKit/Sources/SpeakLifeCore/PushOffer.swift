//
//  PushOffer.swift
//  SpeakLifeCore
//
//  The rules behind the discount push. A push with data `deepLink = offer`
//  opens PushOfferView for anyone not subscribed. Everything that decides
//  what that screen says lives here, Foundation-only, so it is tested without
//  StoreKit: StoreKit `Product`s cannot be built outside the App Store, so the
//  view hands in plain prices and periods.
//

import Foundation

/// What a tapped offer push asked for. `Identifiable` so it can drive
/// `.sheet(item:)` directly.
public struct PushOfferRoute: Identifiable, Equatable, Sendable {

    /// The `deepLink` value that marks a push as an offer.
    public static let deepLinkValue = "offer"
    /// $29.99/year, sold when the push names no product.
    public static let defaultProductId = "SpeakLife1YR29"
    /// Analytics tag when the push names no campaign.
    public static let defaultCampaign = "none"

    public let productId: String
    public let campaign: String

    public var id: String { productId + "|" + campaign }

    public init(productId: String = PushOfferRoute.defaultProductId,
                campaign: String = PushOfferRoute.defaultCampaign) {
        self.productId = productId
        self.campaign = campaign
    }

    /// Reads a notification's `userInfo`. Nil unless `deepLink` is `offer`.
    /// FCM delivers custom data as strings, typed by hand in the Firebase
    /// console, so values are trimmed and blanks fall back to the defaults.
    public init?(userInfo: [AnyHashable: Any]) {
        guard Self.clean(userInfo["deepLink"]) == Self.deepLinkValue else { return nil }
        self.init(
            productId: Self.clean(userInfo["productId"]) ?? Self.defaultProductId,
            campaign: Self.clean(userInfo["campaign"]) ?? Self.defaultCampaign
        )
    }

    private static func clean(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum PushOfferRule {

    /// Deep links whose screen opens only when the user taps the banner, never
    /// on arrival over whatever they are doing in the foreground.
    public static let bannerOnlyDeepLinks: Set<String> = ["message", "audio", PushOfferRoute.deepLinkValue]

    /// Below this the badge is noise, and rounding could make it a claim the
    /// prices do not back.
    public static let minimumPercentShown = 5

    /// Paying subscribers never see a discount on a plan they already have.
    public static func shouldPresent(isPremium: Bool) -> Bool { !isPremium }

    /// Whole percent off the regular price, rounded DOWN so the badge never
    /// overstates the saving. Nil when there is no honest discount to show:
    /// same product, price unknown, offer not cheaper, or under 5%.
    ///
    /// $29.99 against $49.99 is 40.008%, so 40.
    public static func percentOff(offerPrice: Decimal,
                                  regularPrice: Decimal,
                                  sameProduct: Bool = false) -> Int? {
        guard !sameProduct, regularPrice > 0, offerPrice >= 0, offerPrice < regularPrice else { return nil }
        var raw = (regularPrice - offerPrice) / regularPrice * 100
        var floored = Decimal()
        NSDecimalRound(&floored, &raw, 0, .down)
        let percent = NSDecimalNumber(decimal: floored).intValue
        return percent >= minimumPercentShown ? percent : nil
    }

    /// The yearly price spread over twelve months, rounded to the nearest cent.
    /// Never rounded down: that would quote a monthly cost lower than the real
    /// one. $29.99 is $2.50.
    public static func monthlyEquivalent(yearlyPrice: Decimal) -> Decimal {
        var raw = yearlyPrice / 12
        var rounded = Decimal()
        NSDecimalRound(&rounded, &raw, 2, .plain)
        return rounded
    }

    public enum PeriodUnit: Sendable { case day, week, month, year }

    /// Length of a free trial in days, for the "N days free" line. Months and
    /// years use 30 and 365, matching how App Store Connect describes them.
    public static func trialDays(unit: PeriodUnit, value: Int, periodCount: Int) -> Int {
        let perPeriod: Int
        switch unit {
        case .day: perPeriod = value
        case .week: perPeriod = value * 7
        case .month: perPeriod = value * 30
        case .year: perPeriod = value * 365
        }
        return perPeriod * max(periodCount, 1)
    }
}
