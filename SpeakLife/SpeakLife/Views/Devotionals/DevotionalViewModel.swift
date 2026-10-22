//
//  DevotionalViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/10/23.
//

import SwiftUI

final class DevotionalViewModel: ObservableObject, Sendable {
    
    @AppStorage("devotionalDictionary") var devotionalDictionaryData = Data()
    
    @Published var devotionalText = ""
    @Published var devotionalDate = ""
    @Published var devotionalBooks = ""
    @Published var title = ""
    @Published var hasError = false
    var devotionalId: String {
        // Generate consistent ID based on date for tracking
        return "devotional_\(title+devotionalDate.replacingOccurrences(of: " ", with: "_"))"
    }
    let errorString = "Upgrade to the latest version for Today's Devotional."
    private let freeCount = 1
    @Published var lastFetchDate: String = ""
    
    var devotionals: [Devotional] = []
    
    @Published var devotionValue = 0

    // MARK: Category devotionals

    /// The category the user reads in every day. Empty means the shared
    /// calendar devotional from devotionals.json, which is how everyone starts.
    @AppStorage("devotionalCategory") var selectedCategoryRaw = ""
    /// Up to three categories picked from the More sheet, newest first,
    /// comma-separated. Top categories never go in here; they always show.
    @AppStorage("devotionalRecentCategories") private var recentCategoriesRaw = ""
    /// Set once a free user has spent their free category devotional, so the
    /// chips can show a lock instead of surprising them with a paywall.
    @AppStorage("categoryDevotionalFreeUsed") var categoryFreeUsed = false

    @Published var isGeneratingCategory = false
    @Published var categoryNeedsPaywall = false
    /// The category the reader asked for when the paywall went up.
    private var paywallCategory: DeclarationCategory?
    @Published var categoryFailed = false
    /// The category whose devotional is on screen (nil = calendar). Kept apart
    /// from the selection so the page never shows one topic under another's chip.
    @Published private(set) var displayedCategory: DeclarationCategory?

    var selectedCategory: DeclarationCategory? {
        DeclarationCategory(rawValue: selectedCategoryRaw)
    }

    /// A category is picked but its devotional is not on screen yet.
    var isAwaitingCategory: Bool {
        selectedCategory != nil && displayedCategory != selectedCategory && !categoryFailed
    }

    /// Life-situation categories the Cloud Function accepts, in More-sheet
    /// order. Must stay a subset of CATEGORIES in functions/categoryDevotional.js.
    static let devotionalCategories: [DeclarationCategory] = [
        .anxiety, .health, .wealth, .marriage, .parenting, .fear, .rest, .identity, .faith,
        .hope, .joy, .grace, .love, .work, .business, .destiny,
        .wisdom, .hardtimes, .grief, .innerHealing, .mentalHealth, .addiction,
        .purity, .anger, .forgiveness, .relationship, .singleParent, .friendship,
        .godsprotection, .warfare, .favor, .miracles, .gratitude, .debt,
        .fertility, .salvation, .newSeason, .wellness, .divorce, .education,
        .housing, .obedience
    ]

    /// Always on the chip row: the storms most readers come to SpeakLife with.
    static let topCategories: [DeclarationCategory] = Array(devotionalCategories.prefix(9))

    var recentCategories: [DeclarationCategory] {
        recentCategoriesRaw.split(separator: ",").compactMap { DeclarationCategory(rawValue: String($0)) }
    }

    /// Chip row order: the user's recent picks first, then the top nine.
    var chipCategories: [DeclarationCategory] {
        recentCategories + Self.topCategories
    }

    func isLocked(_ category: DeclarationCategory, isPremium: Bool) -> Bool {
        !isPremium && categoryFreeUsed && !categoryService.hasToday(category)
    }

    private func rememberRecent(_ category: DeclarationCategory) {
        guard !Self.topCategories.contains(category) else { return }
        let updated = [category] + recentCategories.filter { $0 != category }
        recentCategoriesRaw = updated.prefix(3).map(\.rawValue).joined(separator: ",")
    }

    /// Today's calendar devotional, kept so switching back to Daily is instant.
    private var calendarDevotional: Devotional?
    private let categoryService = CategoryDevotionalService.shared

    var devotional: Devotional? {
        didSet {
            updateViewModel()
        }
    }
    
    var devotionalDictionary: [DateComponents: Bool] {
        get {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([DateComponents: Bool].self, from: devotionalDictionaryData) {
                return decoded
            } else {
                return [:]  // Return an empty dictionary as a default value
            }
        }
        
        set  {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                DispatchQueue.main.async { [weak self] in
                    self?.devotionalDictionaryData = encoded
                }
            }
        }
    }
    
    var devotionalsLeft: Int {
        if !devotionalLimitReached {
            return freeCount - devotionalDictionary.count
        }
        return 0
    }
    
    var devotionalLimitReached: Bool {
        devotionalDictionary.count > 1
    }
    
    private func setDevotionalDictionary(date: Date = Date()) {

        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        // means we added the date user looked at devotional already
        if let _ = devotionalDictionary[components] {
            
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.devotionalDictionary[components] = true
            }
        }
        
    }
    
    private let service: DevotionalService
    
    init(service: DevotionalService = DevotionalServiceClient()) {
        self.service = service
    }
    
    private func updateViewModel() {
        guard let devotional = devotional else { return }
        DispatchQueue.main.async { [ weak self] in
            self?.devotionalText = devotional.devotionalText
            self?.devotionalDate = devotional.date.toSimpleDate()
            self?.devotionalBooks = devotional.books
            self?.title = devotional.title
            self?.objectWillChange.send() // Force UI update for date change
        }
    }
    
    func fetchDevotional(remoteVersion: Int) async {
        
        if let devotional = await service.fetchTodayDevotional(remoteVersion: remoteVersion).first {
            DispatchQueue.main.async { [weak self] in
                self?.calendarDevotional = devotional
                // A reader who picked a category sees that instead; the
                // calendar one waits behind the Daily chip.
                if self?.selectedCategory == nil {
                    self?.devotional = devotional
                }
            }
            setDevotionalDictionary()
        }
        else {
            DispatchQueue.main.async { [weak self] in
                self?.hasError = true
            }
        }
        return
    }
    
    func fetchDevotionalFor(value: Int) async {
        guard devotionValue > -14 && devotionValue < 1 else {
            return
        }
        if self.devotionals.isEmpty {
            let devotionals = await service.fetchAllDevotionals(needsSync: false)
            self.devotionals = devotionals
        }
            let now = Date()
            let calendar = Calendar.current
        if let searchDate = calendar.date(byAdding: .day, value: value, to: now) {
        
            let searchComponents = calendar.dateComponents([.month, .day], from: searchDate)
        
            let month = searchComponents.month
            let day = searchComponents.day
        
        if let foundDevotional = devotionals.first(where: {
            let devotionalComponents = calendar.dateComponents([.month, .day], from: $0.date)
            let devotionalMonth = devotionalComponents.month
            let devotionalDay = devotionalComponents.day
            return (devotionalMonth, devotionalDay) == (month, day)}) {
            self.devotional = foundDevotional
            setDevotionalDictionary(date: searchDate)
        }
        }
    }
    
    func shouldFetchNewDevotional() -> Bool {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        return today != lastFetchDate
    }
    
    func forceRefreshDevotional(remoteVersion: Int) async {
        if let devotional = await service.forceRefreshDevotionals(remoteVersion: remoteVersion).first {
            DispatchQueue.main.async { [weak self] in
                self?.devotional = devotional
            }
            setDevotionalDictionary()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.hasError = true
            }
        }
    }

    // MARK: - Category devotionals

    /// Switch to a category (nil = back to the calendar devotional) and show
    /// today's devotional for it. A tap on a locked chip goes straight to the
    /// paywall without spending a network round trip.
    @MainActor
    func selectCategory(_ category: DeclarationCategory?, isPremium: Bool) async {
        AnalyticsService.shared.track("devotional_category_selected", parameters: [
            "category": category?.rawValue ?? "daily"
        ])
        guard let category else {
            showCalendarDevotional()
            return
        }
        if isLocked(category, isPremium: isPremium) {
            paywallCategory = category
            categoryNeedsPaywall = true
            AnalyticsService.shared.track("category_devotional_paywall", parameters: [
                "category": category.rawValue, "source": "locked_chip"
            ])
            return
        }
        selectedCategoryRaw = category.rawValue
        devotionValue = 0
        rememberRecent(category)
        await loadCategoryDevotional(isPremium: isPremium, userInitiated: true)
    }

    /// Back to the shared calendar devotional.
    @MainActor
    func showCalendarDevotional() {
        selectedCategoryRaw = ""
        categoryFailed = false
        devotionValue = 0
        displayedCategory = nil
        if let calendarDevotional {
            devotional = calendarDevotional
        } else {
            Task { await fetchDevotionalFor(value: 0) }
        }
    }

    /// Called when the paywall closes. A purchase loads the devotional they
    /// asked for. Walking away leaves them on whatever they were reading, so
    /// the chip and the page agree and a saved category never reopens the
    /// paywall on its own.
    @MainActor
    func paywallClosed(isPremium: Bool) async {
        let requested = paywallCategory
        paywallCategory = nil
        if isPremium, let requested {
            selectedCategoryRaw = requested.rawValue
            rememberRecent(requested)
            await loadCategoryDevotional(isPremium: true, userInitiated: true)
        } else if let displayedCategory {
            selectedCategoryRaw = displayedCategory.rawValue
        } else {
            showCalendarDevotional()
        }
    }

    /// Loads today's devotional for the saved category. Safe to call on every
    /// appear: after the first load of the day it is served from cache.
    /// `userInitiated` is false for the automatic load when the screen opens;
    /// a paywall there would greet the reader with a wall, so that path falls
    /// back to Daily quietly instead.
    @MainActor
    func loadCategoryDevotional(isPremium: Bool, userInitiated: Bool = false) async {
        guard let category = selectedCategory else { return }
        if displayedCategory == category && !userInitiated { return }
        guard !isGeneratingCategory else { return }
        isGeneratingCategory = true
        categoryFailed = false
        defer { isGeneratingCategory = false }

        do {
            switch try await categoryService.todaysDevotional(for: category, isPremium: isPremium) {
            case .devotional(let generated, let remainingFree):
                if remainingFree == 0 { categoryFreeUsed = true }
                // The user may have tapped another chip while this was writing.
                guard selectedCategory == category else { return }
                devotional = generated
                displayedCategory = category
                AnalyticsService.shared.track("category_devotional_loaded", parameters: [
                    "category": category.rawValue,
                    "devotional_title": generated.title
                ])
            case .needsPaywall:
                categoryFreeUsed = true
                if userInitiated {
                    paywallCategory = category
                    categoryNeedsPaywall = true
                    AnalyticsService.shared.track("category_devotional_paywall", parameters: [
                        "category": category.rawValue, "source": "generation"
                    ])
                } else {
                    showCalendarDevotional()
                }
            }
        } catch {
            categoryFailed = true
        }
    }
}
