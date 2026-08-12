//
//  NotificationProcessor.swift
//  SpeakLifeServices
//
//  Picks the declarations that a batch of notifications is built from,
//  and remembers what just went out so the next batch does not repeat
//  it. Foundation-only; the `APIService` it consults comes from the
//  app via `NotificationDeclarationSource.apiServiceFactory` (see
//  ServiceSeams.swift).
//

import Foundation
import SpeakLifeCore

public final class NotificationProcessor {

    private let service: APIService
    private var allDeclarations: [Declaration] = []
    private var allDeclarationsDict: [DeclarationCategory: [Declaration]] = [:]

    public init(service: APIService)  {
        self.service = service
        getDeclarations()

    }

    public struct NotificationData {
        public let book: String
        public let body: String
        public let category: String

        public init(book: String, body: String, category: String) {
            self.book = book
            self.body = body
            self.category = category
        }
    }

    // MARK: - Recently sent

    /// Declarations pushed in the last few batches, so a rebuild doesn't hand
    /// someone the same line they read yesterday.
    ///
    /// Every rebuild reshuffles the whole library independently, so nothing
    /// stopped a fresh batch re-drawing a declaration the previous one had just
    /// sent. Over 3,500 declarations that is not common, but it happens, and
    /// when it does the app looks like it has about ten things to say.
    ///
    /// Deliberately best-effort. If filtering would leave too little to choose
    /// from — a narrow category, a small remote pool — the filter yields and
    /// returns everything, because a repeated declaration is a much smaller
    /// failure than an empty batch.
    private static let recentlySentKey = "notificationRecentlySentBodies"
    private static let recentlySentLimit = 120
    /// Never filter a pool down past this, or a small category starves.
    private static let minimumPoolAfterFiltering = 12

    public static func excludingRecentlySent(_ declarations: [Declaration],
                                             defaults: UserDefaults = .standard) -> [Declaration] {
        let recent = Set(defaults.stringArray(forKey: recentlySentKey) ?? [])
        guard !recent.isEmpty else { return declarations }
        let filtered = declarations.filter { !recent.contains($0.text) }
        return filtered.count >= minimumPoolAfterFiltering ? filtered : declarations
    }

    /// Records what just went out. Trimmed to the most recent entries so the
    /// list can't grow without bound in UserDefaults.
    public static func rememberSent(_ bodies: [String], defaults: UserDefaults = .standard) {
        guard !bodies.isEmpty else { return }
        var recent = defaults.stringArray(forKey: recentlySentKey) ?? []
        recent.append(contentsOf: bodies)
        if recent.count > recentlySentLimit {
            recent.removeFirst(recent.count - recentlySentLimit)
        }
        defaults.set(recent, forKey: recentlySentKey)
    }

    public func getNotificationData(count: Int,
                                    categories: [DeclarationCategory]? = nil,
                                    completion: @escaping([NotificationData]) -> Void) {

//        DispatchQueue.global(qos: .userInitiated).sync {
//            getDeclarations()

            // Only a genuinely empty library is fatal. This used to bail when
            // the library held fewer than `count`, handing back nothing at all
            // — and the caller now asks for a whole batch's worth rather than a
            // single day's, so "fewer than asked for" is a state worth serving
            // rather than refusing. The sampling below already takes
            // `min(count, available)`, and the scheduler is happy with a short
            // pool.
            guard !allDeclarations.isEmpty else {
                print("⚠️ NotificationProcessor: Declarations array is empty, attempting to reload")
                getDeclarations()
                completion([])
                return
            }
            if allDeclarations.count < count {
                print("⚠️ NotificationProcessor: Have \(allDeclarations.count), asked for \(count) — serving what's available")
            }

            print("✅ NotificationProcessor: Using \(allDeclarations.count) declarations for \(count) notifications")


            // get enough for the week
            //let newCount = count * 7

            var data = [NotificationData]()
            var categoryReminders: [Declaration] = []

            // Treat nil or empty category list the same — fall back to all declarations.
            let resolvedCategories = categories?.isEmpty == false ? categories : nil

            if resolvedCategories == nil {
                let shuffled = Self.excludingRecentlySent(allDeclarations).shuffled()
                guard !shuffled.isEmpty else { return }
                // Use 0-based indexing (was 1...count which caused an off-by-one crash)
                for index in 0..<min(count, shuffled.count) {
                    let declaration = shuffled[index]
                    // Send the declaration text (not the Bible verse) as the notification body.
                    // The scripture reference (book) is kept as the subtitle for context.
                    let body = declaration.text
                    let book = declaration.book ?? ""
                    let notificationData = NotificationData(book: book, body: body, category: declaration.category.rawValue)
                    data.append(notificationData)
                }
            } else {
                let categoryList = resolvedCategories!
                let categoryCount = categoryList.count  // guaranteed > 0 by resolvedCategories check above

                // Distribute `count` slots evenly across categories using proper integer math.
                // baseSlots = floor(count / categoryCount) per category
                // remainder categories each get one extra slot (round-robin top-up).
                // Example: count=5, categories=3 → [2, 2, 1] instead of old [1, 1, 1].
                let baseSlots = count / categoryCount          // integer floor division
                let extraSlots = count % categoryCount         // first N categories get +1

                for (index, category) in categoryList.enumerated() {
                    let slots = baseSlots + (index < extraSlots ? 1 : 0)
                    guard slots > 0 else { continue }

                    let categoryDeclarations = Self.excludingRecentlySent(
                        allDeclarations.filter { $0.category == category }
                    )
                    guard !categoryDeclarations.isEmpty else { continue }

                    // Pick exactly `slots` items; repeat if the category has fewer.
                    let shuffled = categoryDeclarations.shuffled()
                    var picked: [Declaration] = []
                    while picked.count < slots {
                        let remaining = slots - picked.count
                        picked.append(contentsOf: shuffled.prefix(remaining))
                    }
                    categoryReminders.append(contentsOf: picked)
                }

                // Ensure we have at least some notifications
                if categoryReminders.isEmpty {
                    // Warning:
                    print("⚠️ NotificationProcessor: Selected categories \(categoryList.map { $0.rawValue }) matched no declarations — falling back to all categories")
                    let shuffled = allDeclarations.shuffled()
                    let fallbackCount = min(count, shuffled.count)
                    categoryReminders.append(contentsOf: shuffled.prefix(fallbackCount))
                }

                // Shuffle the assembled list so categories interleave instead of
                // appearing in blocks (fixes "same 1-2 categories every time" bug).
                let finalList = categoryReminders.shuffled()
                data = parse(finalList, count: min(count, finalList.count))
            }
            completion(data)
            return
       // }

    }

    private func getDeclarations() {
        service.declarations { declarations, error, _ in
            self.allDeclarations = declarations
        }
    }

    private func parse(_ categoryReminders: [Declaration], count: Int) -> [NotificationData] {
        var data = [NotificationData]()
        var localCount = 0

        while localCount < count  {
            let declaration = categoryReminders[localCount]
            // Send the declaration text (not the Bible verse) as the notification body.
            // The scripture reference (book) is kept as the subtitle for context.
            let body = declaration.text
            let book = declaration.book ?? ""
            let notificationData = NotificationData(book: book, body: body, category: declaration.category.rawValue)
            data.append(notificationData)
            localCount += 1
        }

        return data

    }

    private func fetchDeclarations(for category: DeclarationCategory, completion: @escaping(([Declaration]) -> Void)) {
        if let declarations = allDeclarationsDict[category] {
            completion(declarations)

        } else if category == .favorites {
            let faves = allDeclarations.filter { $0.isFavorite == true }
               completion(faves)
        }  else {
            let declarations = allDeclarations.filter { $0.category == category }
            allDeclarationsDict[category] = declarations
            completion(declarations)
        }
    }
}
