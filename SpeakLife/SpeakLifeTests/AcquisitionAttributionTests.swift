//
//  AcquisitionAttributionTests.swift
//  SpeakLifeTests
//
//  Guards the per-person acquisition channel against the two ways it has
//  silently gone wrong:
//
//  1. Branch's `initSession` calls back on every launch, clicked or not, and
//     every one of those sessions used to be recorded as `owned_deeplink`,
//     outranking the organic decision for almost every install.
//  2. `AcquisitionChannel.from` matched short abbreviations as substrings, so
//     "digital" or "signup" read as Meta.
//
//  Also covers the plan / billing_term derivation GrowthMetrics mirrors from
//  RevenueCat, whose "life" match filed the weekly SKU as lifetime.
//

import XCTest
@testable import SpeakLife

final class AcquisitionAttributionTests: XCTestCase {

    // MARK: - Branch: no click, no attribution

    func testSessionWithoutLinkClickRecordsNothing() {
        let organicLaunch: [String: Any] = [
            "+clicked_branch_link": false,
            "+is_first_session": true
        ]
        XCTAssertNil(BranchAttribution.attribution(from: organicLaunch))
    }

    func testNonBranchLinkOpenRecordsNothing() {
        let params: [String: Any] = [
            "+clicked_branch_link": false,
            "+is_first_session": false,
            "+non_branch_link": "speaklife://event/daily-declarations"
        ]
        XCTAssertNil(BranchAttribution.attribution(from: params))
    }

    func testMissingClickFlagRecordsNothing() {
        XCTAssertNil(BranchAttribution.attribution(from: [:]))
        XCTAssertNil(BranchAttribution.attribution(from: ["~channel": "Facebook"]))
    }

    func testClickFlagIsReadInEveryShapeItArrivesIn() {
        XCTAssertTrue(BranchAttribution.clickedBranchLink(["+clicked_branch_link": true]))
        XCTAssertTrue(BranchAttribution.clickedBranchLink(["+clicked_branch_link": NSNumber(value: true)]))
        XCTAssertTrue(BranchAttribution.clickedBranchLink(["+clicked_branch_link": NSNumber(value: 1)]))
        XCTAssertTrue(BranchAttribution.clickedBranchLink(["+clicked_branch_link": "true"]))
        XCTAssertTrue(BranchAttribution.clickedBranchLink(["+clicked_branch_link": "1"]))

        XCTAssertFalse(BranchAttribution.clickedBranchLink(["+clicked_branch_link": NSNumber(value: false)]))
        XCTAssertFalse(BranchAttribution.clickedBranchLink(["+clicked_branch_link": "false"]))
        XCTAssertFalse(BranchAttribution.clickedBranchLink(["+clicked_branch_link": "0"]))
        XCTAssertFalse(BranchAttribution.clickedBranchLink(["+clicked_branch_link": NSNull()]))
    }

    // MARK: - Branch: clicked links

    func testClickedLinkWithNoNetworkIsOwnedDeeplink() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~referring_link": "https://speaklife.app.link/abc123"
        ])
        XCTAssertEqual(attribution?.channel, .ownedDeeplink)
        XCTAssertEqual(attribution?.source, "branch")
        XCTAssertNil(attribution?.campaign)
    }

    func testPaidMetaClickIsMetaWithCampaignFields() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": NSNumber(value: true),
            "~feature": "paid advertising",
            "~channel": "Facebook",
            "~advertising_partner_name": "Facebook",
            "~campaign": "healing_sept",
            "~ad_set_name": "women_35_54",
            "~creative_name": "jesus_portrait_v3",
            "~keyword": ""
        ])
        XCTAssertEqual(attribution?.channel, .meta)
        XCTAssertEqual(attribution?.source, "Facebook")
        XCTAssertEqual(attribution?.campaign, "healing_sept")
        XCTAssertEqual(attribution?.adGroup, "women_35_54")
        XCTAssertEqual(attribution?.creative, "jesus_portrait_v3")
        XCTAssertNil(attribution?.keyword, "an empty string is not a keyword")
    }

    func testPartnerNameBeatsChannelField() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~channel": "email",
            "~advertising_partner_name": "TikTok For Business"
        ])
        XCTAssertEqual(attribution?.channel, .tiktok)
        XCTAssertEqual(attribution?.source, "TikTok For Business")
    }

    func testUnclassifiedChannelFallsThroughToFeature() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~channel": "sms",
            "~feature": "invite"
        ])
        XCTAssertEqual(attribution?.channel, .referral)
        XCTAssertEqual(attribution?.source, "sms", "raw network text is kept even when a later field decides the channel")
    }

    func testOwnedChannelLinkStaysOwned() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~channel": "instagram bio",
            "~feature": "marketing"
        ])
        // "instagram" is matched before "bio": a bio link on Instagram files as Meta,
        // exactly as the same utm_source always has.
        XCTAssertEqual(attribution?.channel, .meta)

        let email = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~channel": "email",
            "~feature": "marketing"
        ])
        XCTAssertEqual(email?.channel, .ownedDeeplink)
        XCTAssertEqual(email?.source, "email")
    }

    // MARK: - Channel string matching

    func testMetaNetworkNames() {
        for name in ["Facebook", "facebook_ads", "Instagram", "instagram_stories", "Meta", "ig", "ig_story", "fb"] {
            XCTAssertEqual(AcquisitionChannel.from(sourceString: name), .meta, name)
        }
    }

    func testShortAbbreviationsNoLongerMatchInsideWords() {
        for name in ["digital", "signup", "bigfoot", "casa", "pleasant"] {
            XCTAssertEqual(AcquisitionChannel.from(sourceString: name), .unknown, name)
        }
    }

    func testOtherNetworkNamesUnchanged() {
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "Apple Search Ads"), .appleSearchAds)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "asa"), .appleSearchAds)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "TikTok"), .tiktok)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "bytedanceglobal_int"), .tiktok)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "Google AdWords"), .google)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "youtube"), .google)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "email"), .ownedDeeplink)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "push"), .ownedDeeplink)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "qr"), .ownedDeeplink)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "share"), .referral)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: "friend_referral"), .referral)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: ""), .unknown)
        XCTAssertEqual(AcquisitionChannel.from(sourceString: nil), .unknown)
    }

    // MARK: - Plan / billing term

    func testBillingTermForEveryShippedSku() {
        XCTAssertEqual(GrowthMetrics.billingTerm(for: "SpeakLife1YR29"), "annual")
        XCTAssertEqual(GrowthMetrics.billingTerm(for: "SpeakLife1YR99"), "annual")
        XCTAssertEqual(GrowthMetrics.billingTerm(for: "SpeakLife1MO9"), "monthly")
        XCTAssertEqual(GrowthMetrics.billingTerm(for: "SpeakLife1MO4"), "monthly")
        XCTAssertEqual(GrowthMetrics.billingTerm(for: "SpeakLife1Wk5"), "weekly")
        XCTAssertEqual(GrowthMetrics.billingTerm(for: "SpeakLifeLifetime"), "lifetime")
        XCTAssertEqual(GrowthMetrics.billingTerm(for: "SpeakLifeSomethingNew"), "unknown",
                       "the SpeakLife prefix alone must not read as lifetime")
    }

    func testResolvedPlanPrefersStoreKitLabelAndFallsBackToProductId() {
        XCTAssertEqual(GrowthMetrics.resolvedPlan(productId: "SpeakLife1YR29", plan: "annual"), "annual")
        XCTAssertEqual(GrowthMetrics.resolvedPlan(productId: "SpeakLife1Wk5", plan: nil), "weekly")
        XCTAssertEqual(GrowthMetrics.resolvedPlan(productId: "SpeakLifeLifetime", plan: "unknown"), "lifetime")
    }

    // MARK: - Share links count as referrals

    /// What Branch hands back when someone installs from a shared declaration
    /// card. If this stops reading as `referral`, every share-driven install
    /// silently falls back into `owned_deeplink` again.
    func testShareLinkClickIsAReferral() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~channel": "share",
            "~feature": "declaration_card",
            "~campaign": "faith"
        ])
        XCTAssertEqual(attribution?.channel, .referral)
        XCTAssertEqual(attribution?.source, "share")
        XCTAssertEqual(attribution?.campaign, "faith")
    }

    /// Every share has channel "share", so the surface has to ride somewhere
    /// else to be told apart in a breakdown.
    func testShareClickRecordsFeatureAsCreative() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~channel": "share",
            "~feature": "declaration_card"
        ])
        XCTAssertEqual(attribution?.creative, "declaration_card")
    }

    func testPaidClickDoesNotTakeFeatureAsCreative() {
        let attribution = BranchAttribution.attribution(from: [
            "+clicked_branch_link": true,
            "~channel": "Facebook",
            "~feature": "paid advertising"
        ])
        XCTAssertNil(attribution?.creative)
    }

    func testReferralLinkCarriesShareChannelOnTheRootPath() {
        let url = ReferralLink.url(.declarationCard, campaign: "faith")
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        XCTAssertEqual(url.host, ReferralLink.host)
        // Root path: shipped builds claim every path on this host, and the
        // root is the one they open cleanly.
        XCTAssertEqual(url.path, "/")
        XCTAssertEqual(value("channel"), "share")
        XCTAssertEqual(value("feature"), "declaration_card")
        XCTAssertEqual(value("campaign"), "faith")
        // Must never be mistaken for a stand invite.
        XCTAssertNil(StandLink.code(from: url))
    }

    // MARK: - Referrer: who shared the link behind an install

    /// What Branch hands back on the install session from a shared link.
    private func shareInstallParams(referrer: Any? = "sharer-123") -> [String: Any] {
        var params: [String: Any] = [
            "+clicked_branch_link": true,
            "+is_first_session": true,
            "~channel": "share",
            "~feature": "favorite"
        ]
        if let referrer { params[ReferralLink.referrerKey] = referrer }
        return params
    }

    /// Captures what a recorded referral reports, so no real event leaves
    /// the test host.
    private final class AnalyticsSpy {
        var properties: [(String, Any)] = []
        var events: [(String, [String: Any])] = []

        var analytics: BranchAttribution.ReferralAnalytics {
            BranchAttribution.ReferralAnalytics(
                setUserProperty: { [unowned self] in self.properties.append(($0, $1)) },
                track: { [unowned self] in self.events.append(($0, $1)) }
            )
        }
    }

    private func freshDefaults() -> UserDefaults {
        let name = "ReferralTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: name) }
        return defaults
    }

    func testReferrerIsReadFromSlRef() {
        let referral = BranchAttribution.referral(from: shareInstallParams(), ownDistinctId: "me")
        XCTAssertEqual(referral, BranchAttribution.Referral(referrer: "sharer-123", feature: "favorite"))
    }

    func testNoReferrerWhenSlRefIsAbsentOrUnusable() {
        XCTAssertNil(BranchAttribution.referral(from: shareInstallParams(referrer: nil), ownDistinctId: "me"))
        XCTAssertNil(BranchAttribution.referral(from: shareInstallParams(referrer: "   "), ownDistinctId: "me"))
        XCTAssertNil(BranchAttribution.referral(from: shareInstallParams(referrer: 42), ownDistinctId: "me"))
        XCTAssertNil(BranchAttribution.referral(
            from: shareInstallParams(referrer: String(repeating: "x", count: 129)), ownDistinctId: "me"))
    }

    func testReferrerNeedsAClickedInstallSession() {
        var notClicked = shareInstallParams()
        notClicked["+clicked_branch_link"] = false
        XCTAssertNil(BranchAttribution.referral(from: notClicked, ownDistinctId: "me"))

        // An existing user opening a friend's link was not brought in by it.
        var notFirst = shareInstallParams()
        notFirst["+is_first_session"] = false
        XCTAssertNil(BranchAttribution.referral(from: notFirst, ownDistinctId: "me"))

        var missingFirst = shareInstallParams()
        missingFirst.removeValue(forKey: "+is_first_session")
        XCTAssertNil(BranchAttribution.referral(from: missingFirst, ownDistinctId: "me"))
    }

    func testOwnLinkIsNotAReferral() {
        XCTAssertNil(BranchAttribution.referral(from: shareInstallParams(), ownDistinctId: "sharer-123"))
    }

    func testReferrerIsTrimmedAndBlankFeatureDropped() {
        var params = shareInstallParams(referrer: "  sharer-123\n")
        params["~feature"] = "  "
        XCTAssertEqual(BranchAttribution.referral(from: params, ownDistinctId: nil),
                       BranchAttribution.Referral(referrer: "sharer-123", feature: nil))
    }

    func testReferredByIsSetAndReported() {
        let defaults = freshDefaults()
        let spy = AnalyticsSpy()
        let first = BranchAttribution.recordReferral(
            from: shareInstallParams(), defaults: defaults, ownDistinctId: "me", analytics: spy.analytics)

        XCTAssertEqual(first?.referrer, "sharer-123")
        XCTAssertEqual(defaults.string(forKey: BranchAttribution.referredByDefaultsKey), "sharer-123")

        XCTAssertEqual(spy.properties.count, 1)
        XCTAssertEqual(spy.properties.first?.0, "referred_by")
        XCTAssertEqual(spy.properties.first?.1 as? String, "sharer-123")

        XCTAssertEqual(spy.events.count, 1)
        XCTAssertEqual(spy.events.first?.0, "referral_install_attributed")
        XCTAssertEqual(spy.events.first?.1["referred_by"] as? String, "sharer-123")
        XCTAssertEqual(spy.events.first?.1["feature"] as? String, "favorite")
    }

    func testReferredByIsNeverOverwritten() {
        let defaults = freshDefaults()
        let spy = AnalyticsSpy()
        BranchAttribution.recordReferral(
            from: shareInstallParams(), defaults: defaults, ownDistinctId: "me", analytics: spy.analytics)

        let second = BranchAttribution.recordReferral(
            from: shareInstallParams(referrer: "someone-else"), defaults: defaults,
            ownDistinctId: "me", analytics: spy.analytics)
        XCTAssertNil(second)
        XCTAssertEqual(defaults.string(forKey: BranchAttribution.referredByDefaultsKey), "sharer-123")
        // The second install session reports nothing.
        XCTAssertEqual(spy.properties.count, 1)
        XCTAssertEqual(spy.events.count, 1)
    }

    func testNothingIsStoredOrReportedWithoutSlRef() {
        let defaults = freshDefaults()
        let spy = AnalyticsSpy()
        XCTAssertNil(BranchAttribution.recordReferral(
            from: shareInstallParams(referrer: nil), defaults: defaults,
            ownDistinctId: "me", analytics: spy.analytics))
        XCTAssertNil(defaults.string(forKey: BranchAttribution.referredByDefaultsKey))
        XCTAssertTrue(spy.properties.isEmpty)
        XCTAssertTrue(spy.events.isEmpty)
    }
}
