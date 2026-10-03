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
}
