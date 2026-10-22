//
//  ForYou.swift
//  SpeakLifeCore
//
//  The weekly For You set: every Sunday evening the server writes ten new
//  declarations modelled on what the user favorited that week, checks each
//  one's verse, and sends a push (functions/weeklyForYou.js). This file is
//  the Foundation-only half the app needs: remembering when each favorite was
//  saved, building the sync payload, and decoding the set.
//
//  Gated by the `weeklyForYouEnabled` Remote Config key, which the server
//  reads too.
//

import Foundation

// MARK: - When each favorite was saved

/// Core Data stores whether a declaration is a favorite, not when it became
/// one, and adding a CloudKit-synced attribute for this would need a schema
/// deploy. The set only needs a rough "saved this week", so the date lives on
/// this device, keyed by declaration text. A favorite saved before this
/// shipped, or on another device, simply has no date and is treated as older.
public struct ForYouFavoriteLog {
    public static let storageKey = "forYouFavoriteDates"
    /// Dates older than this are dropped; the set only ever looks back a week.
    public static let retention: TimeInterval = 60 * 24 * 3600

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func record(_ text: String, isFavorite: Bool, at date: Date = Date()) {
        var dates = load()
        if isFavorite {
            dates[text] = date.timeIntervalSince1970
        } else {
            dates.removeValue(forKey: text)
        }
        let cutoff = date.timeIntervalSince1970 - Self.retention
        dates = dates.filter { $0.value >= cutoff }
        defaults.set(dates, forKey: Self.storageKey)
    }

    public func favoritedAt(_ text: String) -> Date? {
        load()[text].map { Date(timeIntervalSince1970: $0) }
    }

    private func load() -> [String: Double] {
        defaults.dictionary(forKey: Self.storageKey) as? [String: Double] ?? [:]
    }
}

// MARK: - Sync payload

public enum ForYouPayload {
    /// The server keeps at most this many; sending more is wasted bytes.
    public static let maxFavorites = 100

    /// The JSON body for `syncForYouFavorites`. Newest-dated favorites first,
    /// so if the list is capped it is the old ones that fall off.
    public static func sync(
        appUserId: String,
        favorites: [Declaration],
        log: ForYouFavoriteLog,
        fcmToken: String?,
        timeZone: TimeZone = .current
    ) -> [String: Any] {
        var seen = Set<String>()
        let unique = favorites.filter { seen.insert($0.text).inserted }
        let dated = unique.map { ($0, log.favoritedAt($0.text)) }
        let ordered = dated.sorted { ($0.1 ?? .distantPast) > ($1.1 ?? .distantPast) }

        let items: [[String: Any]] = ordered.prefix(maxFavorites).map { declaration, date in
            var item: [String: Any] = [
                "text": declaration.text,
                "category": declaration.category.rawValue,
            ]
            if let book = declaration.book, !book.isEmpty { item["book"] = book }
            if let date { item["favoritedAt"] = Int(date.timeIntervalSince1970 * 1000) }
            return item
        }

        var body: [String: Any] = [
            "appUserId": appUserId,
            "favorites": items,
            "timeZone": timeZone.identifier,
        ]
        if let fcmToken, !fcmToken.isEmpty { body["fcmToken"] = fcmToken }
        return body
    }
}

// MARK: - The set

public struct ForYouDeclaration: Codable, Equatable, Identifiable {
    public let text: String
    public let bibleVerseText: String
    public let book: String
    public let category: String

    public var id: String { text }

    public init(text: String, bibleVerseText: String, book: String, category: String) {
        self.text = text
        self.bibleVerseText = bibleVerseText
        self.book = book
        self.category = category
    }

    /// As an app Declaration, so it can be favorited like any other. Filed
    /// under the theme the server chose; an unknown one becomes faith.
    public var declaration: Declaration {
        Declaration(
            text: text,
            book: book,
            bibleVerseText: bibleVerseText,
            category: DeclarationCategory(rawValue: category) ?? .faith
        )
    }
}

public struct ForYouSet: Codable, Equatable {
    public let weekId: String
    public let title: String
    public let declarations: [ForYouDeclaration]
    /// How many more were written but are behind the paywall.
    public let locked: Int

    public init(weekId: String, title: String, declarations: [ForYouDeclaration], locked: Int) {
        self.weekId = weekId
        self.title = title
        self.declarations = declarations
        self.locked = locked
    }
}

/// The `getWeeklyForYou` response.
public struct ForYouResponse: Decodable, Equatable {
    public let set: ForYouSet?
    public let isPremium: Bool
    /// True when the server's switch is off.
    public let disabled: Bool

    enum CodingKeys: String, CodingKey { case set, isPremium, disabled }

    public init(set: ForYouSet?, isPremium: Bool = false, disabled: Bool = false) {
        self.set = set
        self.isPremium = isPremium
        self.disabled = disabled
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        set = try c.decodeIfPresent(ForYouSet.self, forKey: .set)
        isPremium = try c.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        disabled = try c.decodeIfPresent(Bool.self, forKey: .disabled) ?? false
    }
}

// MARK: - Push

public enum ForYouPush {
    /// `notificationType` on the FCM data payload.
    public static let notificationType = "forYou"

    /// The week a For You push is about, or nil when it is some other push.
    public static func weekId(from userInfo: [AnyHashable: Any]) -> String? {
        guard userInfo["notificationType"] as? String == notificationType else { return nil }
        return userInfo["weekId"] as? String ?? ""
    }
}
