//
//  ForYouTests.swift
//  SpeakLifeCoreTests
//
//  The app half of the weekly For You set. The server decides "favorited this
//  week" from the dates sent here, so a lost or wrong date quietly turns a
//  set built from this week into one built from older favorites. The decoder
//  reads exactly what functions/lib/forYouService.js returns.
//

import XCTest
@testable import SpeakLifeCore

final class ForYouTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ForYouTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Favorite log

    func testRecordsWhenAFavoriteWasSaved() {
        let log = ForYouFavoriteLog(defaults: defaults)
        let when = Date(timeIntervalSince1970: 1_790_000_000)
        log.record("I am healed.", isFavorite: true, at: when)
        XCTAssertEqual(log.favoritedAt("I am healed."), when)
        XCTAssertNil(log.favoritedAt("Never saved."))
    }

    func testUnfavoritingForgetsTheDate() {
        let log = ForYouFavoriteLog(defaults: defaults)
        log.record("I am healed.", isFavorite: true)
        log.record("I am healed.", isFavorite: false)
        XCTAssertNil(log.favoritedAt("I am healed."))
    }

    func testRefavoritingMovesTheDateForward() {
        let log = ForYouFavoriteLog(defaults: defaults)
        let first = Date(timeIntervalSince1970: 1_790_000_000)
        let later = first.addingTimeInterval(3 * 24 * 3600)
        log.record("I am healed.", isFavorite: true, at: first)
        log.record("I am healed.", isFavorite: true, at: later)
        XCTAssertEqual(log.favoritedAt("I am healed."), later)
    }

    func testOldDatesArePrunedSoTheLogCannotGrowForever() {
        let log = ForYouFavoriteLog(defaults: defaults)
        let old = Date(timeIntervalSince1970: 1_790_000_000)
        log.record("Old.", isFavorite: true, at: old)
        log.record("New.", isFavorite: true, at: old.addingTimeInterval(ForYouFavoriteLog.retention + 60))
        XCTAssertNil(log.favoritedAt("Old."))
        XCTAssertNotNil(log.favoritedAt("New."))
    }

    func testSurvivesAFreshInstanceOnTheSameDefaults() {
        ForYouFavoriteLog(defaults: defaults).record("Kept.", isFavorite: true)
        XCTAssertNotNil(ForYouFavoriteLog(defaults: defaults).favoritedAt("Kept."))
    }

    // MARK: - Sync payload

    func testPayloadCarriesEverythingTheServerReads() throws {
        let log = ForYouFavoriteLog(defaults: defaults)
        let when = Date(timeIntervalSince1970: 1_790_000_000)
        log.record("I am healed.", isFavorite: true, at: when)

        let body = ForYouPayload.sync(
            appUserId: "rc-123",
            favorites: [
                Declaration(text: "I am healed.", book: "Isaiah 53:5", category: .health),
                Declaration(text: "My own words.", book: nil, category: .myOwn),
            ],
            log: log,
            fcmToken: "tok",
            timeZone: TimeZone(identifier: "America/Chicago")!
        )

        XCTAssertEqual(body["appUserId"] as? String, "rc-123")
        XCTAssertEqual(body["fcmToken"] as? String, "tok")
        XCTAssertEqual(body["timeZone"] as? String, "America/Chicago")
        let items = try XCTUnwrap(body["favorites"] as? [[String: Any]])
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0]["text"] as? String, "I am healed.")
        XCTAssertEqual(items[0]["book"] as? String, "Isaiah 53:5")
        XCTAssertEqual(items[0]["category"] as? String, "health")
        XCTAssertEqual(items[0]["favoritedAt"] as? Int, 1_790_000_000_000)
        XCTAssertNil(items[1]["book"], "no reference, no key")
        XCTAssertNil(items[1]["favoritedAt"], "no known date, no key")

        // It has to survive JSONSerialization, which is how it is sent.
        XCTAssertTrue(JSONSerialization.isValidJSONObject(body))
    }

    func testPayloadPutsNewestFirstDedupesAndCaps() throws {
        let log = ForYouFavoriteLog(defaults: defaults)
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        var favorites: [Declaration] = []
        for i in 0..<130 {
            let text = "Line \(i)."
            favorites.append(Declaration(text: text, category: .faith))
            log.record(text, isFavorite: true, at: base.addingTimeInterval(TimeInterval(i)))
        }
        favorites.append(Declaration(text: "Line 129.", category: .rest)) // same text, other category

        let body = ForYouPayload.sync(appUserId: "u", favorites: favorites, log: log, fcmToken: nil)
        let items = try XCTUnwrap(body["favorites"] as? [[String: Any]])
        XCTAssertEqual(items.count, ForYouPayload.maxFavorites)
        XCTAssertEqual(items.first?["text"] as? String, "Line 129.")
        XCTAssertEqual(items.filter { $0["text"] as? String == "Line 129." }.count, 1)
        XCTAssertNil(body["fcmToken"], "an absent token is left out so the server keeps the old one")
    }

    func testEmptyTokenIsLeftOut() {
        let body = ForYouPayload.sync(appUserId: "u", favorites: [], log: ForYouFavoriteLog(defaults: defaults), fcmToken: "")
        XCTAssertNil(body["fcmToken"])
        XCTAssertEqual((body["favorites"] as? [[String: Any]])?.count, 0)
    }

    // MARK: - Decoding the set

    func testDecodesTheServerResponse() throws {
        // Exactly the shape getWeeklyForYou returns, extra fields included.
        let json = """
        {
          "set": {
            "weekId": "2026-10-25",
            "title": "Peace and Provision",
            "basis": "week",
            "createdAt": "2026-10-25T22:01:00.000Z",
            "declarations": [
              { "text": "My God supplies every need I have.", "bibleVerseText": "And my God will meet all your needs.", "book": "Philippians 4:19", "category": "wealth" },
              { "text": "My mind is kept in perfect peace.", "bibleVerseText": "You will keep in perfect peace.", "book": "Isaiah 26:3", "category": "notACategory" }
            ],
            "locked": 7
          },
          "isPremium": false
        }
        """
        let response = try JSONDecoder().decode(ForYouResponse.self, from: Data(json.utf8))
        let set = try XCTUnwrap(response.set)
        XCTAssertEqual(set.weekId, "2026-10-25")
        XCTAssertEqual(set.title, "Peace and Provision")
        XCTAssertEqual(set.locked, 7)
        XCTAssertEqual(set.declarations.count, 2)
        XCTAssertFalse(response.isPremium)
        XCTAssertFalse(response.disabled)

        let first = set.declarations[0].declaration
        XCTAssertEqual(first.text, "My God supplies every need I have.")
        XCTAssertEqual(first.book, "Philippians 4:19")
        XCTAssertEqual(first.bibleVerseText, "And my God will meet all your needs.")
        XCTAssertEqual(first.category, .wealth)
        XCTAssertEqual(set.declarations[1].declaration.category, .faith, "unknown theme falls back to faith")
    }

    func testDecodesNoSetAndTheSwitchBeingOff() throws {
        let none = try JSONDecoder().decode(ForYouResponse.self, from: Data(#"{"set":null}"#.utf8))
        XCTAssertNil(none.set)
        XCTAssertFalse(none.disabled)

        let off = try JSONDecoder().decode(ForYouResponse.self, from: Data(#"{"set":null,"disabled":true}"#.utf8))
        XCTAssertNil(off.set)
        XCTAssertTrue(off.disabled)
    }

    func testSetRoundTripsForTheOnDeviceCache() throws {
        let set = ForYouSet(weekId: "2026-10-25", title: "T", declarations: [
            ForYouDeclaration(text: "a", bibleVerseText: "b", book: "John 3:16", category: "faith"),
        ], locked: 0)
        let data = try JSONEncoder().encode(set)
        XCTAssertEqual(try JSONDecoder().decode(ForYouSet.self, from: data), set)
    }

    // MARK: - Push

    func testRecognisesAForYouPush() {
        XCTAssertEqual(ForYouPush.weekId(from: ["notificationType": "forYou", "weekId": "2026-10-25"]), "2026-10-25")
        XCTAssertEqual(ForYouPush.weekId(from: ["notificationType": "forYou"]), "")
        XCTAssertNil(ForYouPush.weekId(from: ["notificationType": "stand", "weekId": "2026-10-25"]))
        XCTAssertNil(ForYouPush.weekId(from: [:]))
    }
}
