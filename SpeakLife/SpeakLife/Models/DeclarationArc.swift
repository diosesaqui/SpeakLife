//
//  DeclarationArc.swift
//  SpeakLife
//
//  The 30 days that come after onboarding.
//
//  Onboarding ends with a person who has just told us the single heaviest thing
//  they are carrying. The feed they land in is a flat union of every declaration
//  in every category they picked — three thousand lines, shuffled, in no
//  relationship to anything they said. DeclarationArc is thirty of those lines,
//  chosen and ordered for that person: what they are carrying first, then who
//  God says they are, then what they can stand on, then what their life looks
//  like walking free.
//
//  RETRIEVAL, NOT GENERATION. This record holds IDs only. Every declaration it
//  points at was written by a human into declarationsv10.json and already
//  passes the CLAUDE.md rules, so there is no hallucinated verse to review and
//  no doctrinal risk. Nothing in this feature ever produces declaration text.
//
//  Three sibling records, three horizons:
//
//                  The Anchor              The Week            The Arc
//    Storage       personal_declaration_v1 weekly_focus_…_v1   declaration_arc_v1
//    Set at        Onboarding              Every Sunday        Onboarding, once
//    Horizon       Until it comes to pass  7 days              30 days
//    Count         1 declaration           14-21               30
//
//  The arc never replaces the Anchor and never competes with the Week. It
//  changes the ORDER of the general feed and nothing else; with no arc stored,
//  the feed is byte-for-byte what it has always been.
//

import Foundation

// MARK: - Source

/// Which path produced this arc. Stamped on the record so completion rate can
/// be split by source — i.e. "is the curated arc actually better than the
/// keyword one?" — before any decision is made about spending more on it.
enum DeclarationArcSource: String, Codable {
    /// The `declarationArc` Cloud Function selected and sequenced it.
    case curated
    /// Local, seeded, keyword-scored selection. The fallback whenever the
    /// network call is unavailable, rate limited, or returns something
    /// unusable — an arc is always built once the feature is on.
    case keyword
}

// MARK: - DeclarationArc

struct DeclarationArc: Codable, Equatable {

    /// Bump when a field changes meaning (not when one is added — decoding
    /// tolerates new optional fields).
    static let currentSchemaVersion = 1

    /// The full arc length. 30 is the product promise ("30-Day … Possession",
    /// see `SurveyGoalWord.challengeName`), not an arbitrary number.
    static let dayCount = 30

    var schemaVersion: Int = DeclarationArc.currentSchemaVersion

    let id: UUID

    /// `Declaration.id` values, in day order. Day 1 is index 0.
    ///
    /// Ids, not declarations: the library is already in memory in
    /// `DeclarationViewModel.allDeclarations`, storing the text again would
    /// double it in UserDefaults and in iCloud, and an id that stops resolving
    /// after a content update is a skipped day rather than a stale line the
    /// user keeps being shown.
    let declarationIDs: [String]

    /// `DeclarationCategory` rawValue the arc was built around.
    let categoryRaw: String

    let source: DeclarationArcSource

    /// When day 1 was served. Absolute, so a timezone change mid-arc cannot
    /// re-anchor a journey that is already running.
    let startDate: Date

    // MARK: - Day cursor

    /// 0-based index of the day the user is currently on.
    ///
    /// Advanced by *opening the app on a new calendar day*, not by calendar
    /// drift since `startDate`. Someone who misses four days comes back to day
    /// 5, not day 9 — they have not read days 5 through 8, and skipping them
    /// would quietly delete four thirtieths of the thing they were promised.
    /// This is the same "days actually spoken" rule `PersonalDeclaration`
    /// already uses for its Day N counter.
    var dayCursor: Int

    /// The calendar day `dayCursor` last moved on, so it moves at most once a
    /// day no matter how many times the feed is rebuilt.
    var lastAdvancedOn: Date?

    var category: DeclarationCategory? {
        DeclarationCategory(rawValue: categoryRaw)
    }

    /// 1-based, for display. "Day 7 of 30."
    var dayNumber: Int { clampedCursor + 1 }

    var isComplete: Bool { clampedCursor >= declarationIDs.count - 1 }

    /// `dayCursor` held inside the arc. Every caller that indexes into
    /// `declarationIDs` uses this one — a record written by an older build, or
    /// one whose library shrank, would otherwise index past the end.
    var clampedCursor: Int {
        guard !declarationIDs.isEmpty else { return 0 }
        return min(max(dayCursor, 0), declarationIDs.count - 1)
    }

    /// Today's declaration first, then every day already unlocked in arc order.
    ///
    /// Today leads because that is the whole point of the feature — the first
    /// card they see is the one chosen for today. The days behind it stay in
    /// arc order rather than reverse, so swiping back reads as the journey from
    /// day 1, not as a scroll through history. Days the user has not reached
    /// are never served: an arc that shows all thirty on day one is a list, not
    /// a journey.
    var feedDeclarationIDs: [String] {
        guard !declarationIDs.isEmpty else { return [] }
        let cursor = clampedCursor
        var ids = [declarationIDs[cursor]]
        ids.append(contentsOf: declarationIDs[0..<cursor])
        return ids
    }

    /// A copy advanced to `date`, or nil when the cursor should not move —
    /// already moved today, or the arc is finished.
    ///
    /// Pure on purpose: the repository owns persistence, this owns the rule.
    func advanced(to date: Date = Date(), calendar: Calendar = .current) -> DeclarationArc? {
        guard !declarationIDs.isEmpty else { return nil }
        guard clampedCursor < declarationIDs.count - 1 else { return nil }
        if let last = lastAdvancedOn, calendar.isDate(last, inSameDayAs: date) { return nil }

        // A first open on the same calendar day the arc was created must not
        // jump straight to day 2 — startDate is day 1.
        if lastAdvancedOn == nil, calendar.isDate(startDate, inSameDayAs: date) { return nil }

        var copy = self
        copy.dayCursor = clampedCursor + 1
        copy.lastAdvancedOn = date
        return copy
    }

    init(
        id: UUID = UUID(),
        declarationIDs: [String],
        categoryRaw: String,
        source: DeclarationArcSource,
        startDate: Date = Date(),
        dayCursor: Int = 0,
        lastAdvancedOn: Date? = nil
    ) {
        self.id = id
        self.declarationIDs = declarationIDs
        self.categoryRaw = categoryRaw
        self.source = source
        self.startDate = startDate
        self.dayCursor = dayCursor
        self.lastAdvancedOn = lastAdvancedOn
    }
}
