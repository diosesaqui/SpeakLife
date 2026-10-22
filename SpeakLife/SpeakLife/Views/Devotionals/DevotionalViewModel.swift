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
    @Published var isGeneratingCategory = false
    @Published var categoryNeedsPaywall = false
    @Published var categoryFailed = false

    var selectedCategory: DeclarationCategory? {
        DeclarationCategory(rawValue: selectedCategoryRaw)
    }

    /// Life-situation categories the Cloud Function accepts, in picker order.
    /// Must stay a subset of CATEGORIES in functions/categoryDevotional.js.
    static let devotionalCategories: [DeclarationCategory] = [
        .anxiety, .health, .marriage, .wealth, .fear, .rest, .identity, .faith,
        .hope, .joy, .grace, .love, .parenting, .work, .business, .destiny,
        .wisdom, .hardtimes, .grief, .innerHealing, .mentalHealth, .addiction,
        .purity, .anger, .forgiveness, .relationship, .singleParent, .friendship,
        .godsprotection, .warfare, .favor, .miracles, .gratitude, .debt,
        .fertility, .salvation, .newSeason, .wellness, .divorce, .education,
        .housing, .obedience
    ]

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
    /// today's devotional for it.
    @MainActor
    func selectCategory(_ category: DeclarationCategory?, isPremium: Bool) async {
        selectedCategoryRaw = category?.rawValue ?? ""
        devotionValue = 0
        AnalyticsService.shared.track("devotional_category_selected", parameters: [
            "category": category?.rawValue ?? "daily"
        ])
        if category == nil {
            categoryFailed = false
            if let calendarDevotional {
                devotional = calendarDevotional
            } else {
                await fetchDevotionalFor(value: 0)
            }
            return
        }
        await loadCategoryDevotional(isPremium: isPremium)
    }

    /// Loads today's devotional for the saved category. Safe to call on every
    /// appear: after the first load of the day it is served from cache.
    @MainActor
    func loadCategoryDevotional(isPremium: Bool) async {
        guard let category = selectedCategory, !isGeneratingCategory else { return }
        isGeneratingCategory = true
        categoryFailed = false
        defer { isGeneratingCategory = false }

        do {
            switch try await categoryService.todaysDevotional(for: category, isPremium: isPremium) {
            case .devotional(let generated):
                // The user may have tapped another chip while this was writing.
                guard selectedCategory == category else { return }
                devotional = generated
                AnalyticsService.shared.track("category_devotional_loaded", parameters: [
                    "category": category.rawValue,
                    "devotional_title": generated.title
                ])
            case .needsPaywall:
                categoryNeedsPaywall = true
                AnalyticsService.shared.track("category_devotional_paywall", parameters: [
                    "category": category.rawValue
                ])
            }
        } catch {
            categoryFailed = true
        }
    }
}
