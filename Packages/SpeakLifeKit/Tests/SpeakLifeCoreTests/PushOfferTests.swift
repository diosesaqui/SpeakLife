//
//  PushOfferTests.swift
//  SpeakLifeCoreTests
//
//  The offer push puts a price claim in front of non-subscribers. A wrong
//  percentage is a misleading price claim, a misread push opens the wrong
//  product, and a paying subscriber shown a discount feels cheated. Each gets
//  its own cases.
//

import XCTest
@testable import SpeakLifeCore

final class PushOfferTests: XCTestCase {

    // MARK: - Reading the push

    func testOfferPushWithNoExtrasUsesTheDefaults() {
        let route = PushOfferRoute(userInfo: ["deepLink": "offer"])
        XCTAssertEqual(route, PushOfferRoute(productId: "SpeakLife1YR29", campaign: "none"))
    }

    func testDefaultProductIsTheTwentyNineNinetyNineYearly() {
        XCTAssertEqual(PushOfferRoute.defaultProductId, "SpeakLife1YR29")
        XCTAssertEqual(PushOfferRoute().productId, "SpeakLife1YR29")
    }

    func testOfferPushCarriesProductAndCampaign() {
        let route = PushOfferRoute(userInfo: [
            "deepLink": "offer",
            "productId": "SpeakLife1YR39",
            "campaign": "fall40"
        ])
        XCTAssertEqual(route?.productId, "SpeakLife1YR39")
        XCTAssertEqual(route?.campaign, "fall40")
    }

    /// Values are typed by hand in the Firebase console, so stray spaces and
    /// blank fields are expected and must not break the product lookup.
    func testHandTypedValuesAreTrimmedAndBlanksFallBack() {
        let route = PushOfferRoute(userInfo: [
            "deepLink": " offer\n",
            "productId": "   ",
            "campaign": "  fall40 "
        ])
        XCTAssertEqual(route?.productId, "SpeakLife1YR29")
        XCTAssertEqual(route?.campaign, "fall40")
    }

    func testNonStringValuesFallBack() {
        let route = PushOfferRoute(userInfo: ["deepLink": "offer", "productId": 29, "campaign": NSNull()])
        XCTAssertEqual(route, PushOfferRoute())
    }

    func testOtherPushesAreNotOffers() {
        XCTAssertNil(PushOfferRoute(userInfo: [:]))
        XCTAssertNil(PushOfferRoute(userInfo: ["deepLink": "message"]))
        XCTAssertNil(PushOfferRoute(userInfo: ["deepLink": "audio", "productId": "SpeakLife1YR29"]))
        XCTAssertNil(PushOfferRoute(userInfo: ["deepLink": ""]))
        XCTAssertNil(PushOfferRoute(userInfo: ["deepLink": 1]))
    }

    /// Deep link values are matched exactly elsewhere in the router, so this
    /// one must be too.
    func testDeepLinkIsCaseSensitive() {
        XCTAssertNil(PushOfferRoute(userInfo: ["deepLink": "Offer"]))
    }

    func testRouteIdentityChangesWithProductOrCampaign() {
        let base = PushOfferRoute(productId: "A", campaign: "x")
        XCTAssertEqual(base.id, PushOfferRoute(productId: "A", campaign: "x").id)
        XCTAssertNotEqual(base.id, PushOfferRoute(productId: "A", campaign: "y").id)
        XCTAssertNotEqual(base.id, PushOfferRoute(productId: "B", campaign: "x").id)
        // The separator stops two different pairs gluing into the same id.
        XCTAssertNotEqual(PushOfferRoute(productId: "ab", campaign: "c").id,
                          PushOfferRoute(productId: "a", campaign: "bc").id)
    }

    // MARK: - Who sees it

    func testOnlyNonSubscribersSeeTheOffer() {
        XCTAssertTrue(PushOfferRule.shouldPresent(isPremium: false))
        XCTAssertFalse(PushOfferRule.shouldPresent(isPremium: true))
    }

    /// Foreground arrival must not throw the offer screen over whatever the
    /// user is doing; it opens on tap. Message and audio keep their behavior.
    func testOfferOpensOnTapOnlyAlongsideMessageAndAudio() {
        XCTAssertEqual(PushOfferRule.bannerOnlyDeepLinks, ["message", "audio", "offer"])
        XCTAssertFalse(PushOfferRule.bannerOnlyDeepLinks.contains("declarations"))
    }

    // MARK: - Percent off

    func testTwentyNineNinetyNineAgainstFortyNineNinetyNineIsFortyPercent() {
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: dec("29.99"), regularPrice: dec("49.99")), 40)
    }

    /// 40.008% must show 40, never 41. Rounding up would overstate the saving.
    func testPercentRoundsDownNeverUp() {
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: dec("19.99"), regularPrice: dec("29.99")), 33) // 33.34%
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: dec("29.99"), regularPrice: dec("39.99")), 25) // 25.006%
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: dec("39.99"), regularPrice: dec("99.99")), 60) // 60.006%
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: dec("50.01"), regularPrice: dec("100")), 49)   // 49.99%
    }

    func testExactPercentagesAreExact() {
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: 50, regularPrice: 100), 50)
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: 0, regularPrice: 100), 100)
    }

    func testNoBadgeWhenThereIsNoRealDiscount() {
        // Same price.
        XCTAssertNil(PushOfferRule.percentOff(offerPrice: dec("29.99"), regularPrice: dec("29.99")))
        // Remote Config moved the regular price below the offer.
        XCTAssertNil(PushOfferRule.percentOff(offerPrice: dec("29.99"), regularPrice: dec("19.99")))
        // Push named the regular product itself.
        XCTAssertNil(PushOfferRule.percentOff(offerPrice: dec("29.99"), regularPrice: dec("49.99"), sameProduct: true))
        // Bad prices.
        XCTAssertNil(PushOfferRule.percentOff(offerPrice: dec("29.99"), regularPrice: 0))
        XCTAssertNil(PushOfferRule.percentOff(offerPrice: -1, regularPrice: dec("49.99")))
    }

    func testTinyDiscountsAreNotShown() {
        XCTAssertNil(PushOfferRule.percentOff(offerPrice: dec("47.99"), regularPrice: dec("49.99")))   // 4.0%
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: dec("47.49"), regularPrice: dec("49.99")), 5) // 5.0%
    }

    /// Non-USD storefronts have their own price points. The badge must hold
    /// for whatever the two live prices are.
    func testWorksForOtherCurrencyPricePoints() {
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: 4900, regularPrice: 8000), 38)   // yen-like 38.75%
        XCTAssertEqual(PushOfferRule.percentOff(offerPrice: dec("32.99"), regularPrice: dec("54.99")), 40) // 40.007%
    }

    // MARK: - Monthly equivalent

    func testMonthlyEquivalentRoundsToNearestCent() {
        XCTAssertEqual(PushOfferRule.monthlyEquivalent(yearlyPrice: dec("29.99")), dec("2.5"))   // 2.4991
        XCTAssertEqual(PushOfferRule.monthlyEquivalent(yearlyPrice: dec("49.99")), dec("4.17"))  // 4.1658
        XCTAssertEqual(PushOfferRule.monthlyEquivalent(yearlyPrice: dec("19.99")), dec("1.67"))  // 1.6658
        XCTAssertEqual(PushOfferRule.monthlyEquivalent(yearlyPrice: 120), 10)
    }

    /// Twelve of the quoted monthly figure must never fall more than a few
    /// cents short of the real yearly charge.
    func testMonthlyEquivalentNeverUnderstatesByMoreThanRounding() {
        for cents in stride(from: 999, through: 9999, by: 100) {
            let yearly = Decimal(cents) / 100
            let monthly = PushOfferRule.monthlyEquivalent(yearlyPrice: yearly)
            let shortfall = yearly - monthly * 12
            XCTAssertLessThanOrEqual(shortfall, dec("0.06"), "yearly \(yearly)")
        }
    }

    // MARK: - Trial length

    func testTrialDays() {
        XCTAssertEqual(PushOfferRule.trialDays(unit: .day, value: 3, periodCount: 1), 3)
        XCTAssertEqual(PushOfferRule.trialDays(unit: .week, value: 1, periodCount: 1), 7)
        XCTAssertEqual(PushOfferRule.trialDays(unit: .week, value: 1, periodCount: 2), 14)
        XCTAssertEqual(PushOfferRule.trialDays(unit: .month, value: 1, periodCount: 1), 30)
        XCTAssertEqual(PushOfferRule.trialDays(unit: .year, value: 1, periodCount: 1), 365)
    }

    /// StoreKit reports a free trial's periodCount as 1, but a 0 must never
    /// turn the line into "0 days free".
    func testZeroPeriodCountCountsAsOne() {
        XCTAssertEqual(PushOfferRule.trialDays(unit: .day, value: 3, periodCount: 0), 3)
    }

    // MARK: - Helpers

    /// Decimal from a string, so 29.99 is exactly 29.99 and not the nearest Double.
    private func dec(_ string: String) -> Decimal {
        Decimal(string: string, locale: Locale(identifier: "en_US_POSIX"))!
    }
}
