//
//  PersonalDeclaration.swift
//  SpeakLife
//

import Foundation

struct PersonalDeclaration: Codable, Equatable, Identifiable {
    let id: UUID
    let beliefText: String          // raw text from user (transcribed or typed)
    let declarationText: String     // matched declaration
    let verse: String               // matched Bible verse text
    let verseReference: String      // e.g. "Jeremiah 29:11"
    let categoryRaw: String         // DeclarationCategory rawValue
    let startDate: Date
    var receivedDate: Date?
    var testimony: String?
    /// Set when the user stops carrying this declaration. A tombstone rather
    /// than a real delete: the list is merged across devices as a union by id,
    /// so a removed record has to stay visible-as-removed or the next iCloud
    /// reconcile would hand it straight back.
    var deletedDate: Date?

    // MARK: - Speak Tracking
    //
    // The user can carry several declarations at once (one per thing they're
    // believing God for), so progress lives on the record rather than in
    // globally-named UserDefaults keys. That also means it rides along with the
    // record through iCloud sync, which whitelists fixed key names and could
    // never have covered a per-declaration key.

    /// Unique calendar days this declaration has actually been spoken.
    var completedDayCount: Int = 0
    /// Times it has been spoken today. Drives the tiered badge on the card.
    var dailySpeakCount: Int = 0
    /// ISO day string of the last successful speak.
    var lastSpokenDate: String = ""

    enum CodingKeys: String, CodingKey {
        case id, beliefText, declarationText, verse, verseReference
        case categoryRaw, startDate, receivedDate, testimony, deletedDate
        case completedDayCount, dailySpeakCount, lastSpokenDate
    }

    init(id: UUID,
         beliefText: String,
         declarationText: String,
         verse: String,
         verseReference: String,
         categoryRaw: String,
         startDate: Date,
         receivedDate: Date? = nil,
         testimony: String? = nil,
         deletedDate: Date? = nil,
         completedDayCount: Int = 0,
         dailySpeakCount: Int = 0,
         lastSpokenDate: String = "") {
        self.id = id
        self.beliefText = beliefText
        self.declarationText = declarationText
        self.verse = verse
        self.verseReference = verseReference
        self.categoryRaw = categoryRaw
        self.startDate = startDate
        self.receivedDate = receivedDate
        self.testimony = testimony
        self.deletedDate = deletedDate
        self.completedDayCount = completedDayCount
        self.dailySpeakCount = dailySpeakCount
        self.lastSpokenDate = lastSpokenDate
    }

    /// Decoded leniently: records written before the speak counters existed
    /// simply start at zero.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        beliefText = try container.decode(String.self, forKey: .beliefText)
        declarationText = try container.decode(String.self, forKey: .declarationText)
        verse = try container.decode(String.self, forKey: .verse)
        verseReference = try container.decode(String.self, forKey: .verseReference)
        categoryRaw = try container.decode(String.self, forKey: .categoryRaw)
        startDate = try container.decode(Date.self, forKey: .startDate)
        receivedDate = try container.decodeIfPresent(Date.self, forKey: .receivedDate)
        testimony = try container.decodeIfPresent(String.self, forKey: .testimony)
        deletedDate = try container.decodeIfPresent(Date.self, forKey: .deletedDate)
        completedDayCount = try container.decodeIfPresent(Int.self, forKey: .completedDayCount) ?? 0
        dailySpeakCount = try container.decodeIfPresent(Int.self, forKey: .dailySpeakCount) ?? 0
        lastSpokenDate = try container.decodeIfPresent(String.self, forKey: .lastSpokenDate) ?? ""
    }

    var isReceived: Bool { receivedDate != nil }
    /// True once the user has stopped carrying this one. Filtered out of every
    /// read; only the sync merge and the stored blob ever see it.
    var isDeleted: Bool { deletedDate != nil }

    /// Shared because `todayKey` is read once per declaration per render (the
    /// feed counts how many are still unspoken today), and building an
    /// ISO8601DateFormatter costs far more than the formatting itself.
    /// Formatters are safe to share for formatting.
    private static let dayFormatter = ISO8601DateFormatter()

    /// Today, in the format `lastSpokenDate` is written in.
    static var todayKey: String {
        dayFormatter.string(from: Calendar.current.startOfDay(for: Date()))
    }

    /// True once the user has successfully spoken this declaration today.
    /// Lets a user carrying several burdens see at a glance which are covered.
    var spokenToday: Bool { lastSpokenDate == Self.todayKey }

    /// Speaks recorded *today* — zero when the stored count is from a past day.
    var todaySpeakCount: Int { spokenToday ? dailySpeakCount : 0 }

    /// "Day N" reflects the number of unique days the user has actually spoken
    /// this declaration — not calendar drift since `startDate`. This keeps the
    /// feed tile ("Day N of believing"), the breakthrough flow, and the full
    /// card in sync; previously the tile counted calendar days while the card
    /// counted spoken days, so they diverged whenever a day was skipped.
    var dayCount: Int { max(1, completedDayCount) }

    /// Records a successful speak. The first speak of a day starts the daily
    /// counter over and advances "Day N"; every speak after that in the same
    /// day only raises the daily counter.
    mutating func recordSpeak(on day: String = PersonalDeclaration.todayKey) {
        if lastSpokenDate == day {
            dailySpeakCount += 1
        } else {
            dailySpeakCount = 1
            completedDayCount += 1
        }
        lastSpokenDate = day
    }

    var category: DeclarationCategory? {
        DeclarationCategory(rawValue: categoryRaw)
    }

    // MARK: - Legacy speak-tracking keys
    //
    // How progress was stored before the feature supported several
    // declarations. Read once, moved onto the first declaration's record by
    // the repository's migration, then cleared.

    static let legacyCompletedDayCountKey = "personalDeclaration_completedDayCount"
    static let legacyDailySpeakCountKey = "personalDeclaration_dailySpeakCount"
    static let legacyLastSpokenDateKey = "personalDeclaration_lastSpokenDate"

    /// Folds the pre-multi-declaration counters into this record so an existing
    /// user's "Day N" survives the upgrade, then clears them.
    mutating func absorbLegacySpeakTracking(from defaults: UserDefaults = .standard) {
        completedDayCount = max(completedDayCount, defaults.integer(forKey: Self.legacyCompletedDayCountKey))
        dailySpeakCount = max(dailySpeakCount, defaults.integer(forKey: Self.legacyDailySpeakCountKey))
        if let lastSpoken = defaults.string(forKey: Self.legacyLastSpokenDateKey), !lastSpoken.isEmpty {
            lastSpokenDate = lastSpoken
        }
        defaults.removeObject(forKey: Self.legacyCompletedDayCountKey)
        defaults.removeObject(forKey: Self.legacyDailySpeakCountKey)
        defaults.removeObject(forKey: Self.legacyLastSpokenDateKey)
    }
}

// MARK: - Limits

/// How many things a user can believe for at once. Free users anchor on one;
/// premium users can carry a declaration for each burden they're praying over.
enum PersonalDeclarationLimits {
    static let free = 1
    static let premium = 5

    static func maxDeclarations(isPremium: Bool) -> Int {
        isPremium ? premium : free
    }
}
