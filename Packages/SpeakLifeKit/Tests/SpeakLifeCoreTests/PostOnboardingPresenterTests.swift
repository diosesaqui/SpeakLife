//
//  PostOnboardingPresenterTests.swift
//  SpeakLifeCoreTests
//
//  FE-ORD rows from docs/REFERRAL_FE_TDD.md §10. Never two full-screen covers
//  at once, and a Stand invite always goes first.
//

import XCTest
@testable import SpeakLifeCore

final class PostOnboardingPresenterTests: XCTestCase {

    func test_FE_ORD_01_standCodeAndReferralEligibleShowsStandOnly() {
        XCTAssertEqual(PostOnboardingPresenter.next(hasPendingStandCode: true, referralEligible: true), .standJoin)
        XCTAssertEqual(PostOnboardingPresenter.next(hasPendingStandCode: true, referralEligible: false), .standJoin)
    }

    func test_FE_ORD_02_referralEligibleOnly() {
        XCTAssertEqual(PostOnboardingPresenter.next(hasPendingStandCode: false, referralEligible: true), .referral)
        XCTAssertEqual(PostOnboardingPresenter.next(hasPendingStandCode: false, referralEligible: false), PostOnboardingStep.none)
    }

    func test_FE_ORD_03_welcomeOfferAfterReferralDismissed() {
        XCTAssertTrue(PostOnboardingPresenter.canPresentWelcomeOffer(referralPageOpen: false))
    }

    func test_FE_ORD_04_welcomeOfferWaitsWhileReferralOpen() {
        XCTAssertFalse(PostOnboardingPresenter.canPresentWelcomeOffer(referralPageOpen: true))
    }

    func test_FE_ORD_05_referralBeforePersonalDeclarationPrompt() {
        XCTAssertEqual(PostOnboardingPresenter.next(hasPendingStandCode: false, referralEligible: true), .referral)
        XCTAssertFalse(PostOnboardingPresenter.canPresentPersonalDeclarationPrompt(referralPageOpen: true))
        XCTAssertTrue(PostOnboardingPresenter.canPresentPersonalDeclarationPrompt(referralPageOpen: false))
    }
}
