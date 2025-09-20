//
//  DeclarationViewModel.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/1/22.
//

import SwiftUI
import Combine


final class DeclarationViewModel: ObservableObject {
    
    // MARK: - Properties
    @EnvironmentObject var appState: AppState
    
    @AppStorage("selectedCategory") var selectedCategoryString = "general"
    
    @AppStorage("backgroundMusicEnabled") var backgroundMusicEnabled = true
    
    @Published private(set) var declarations: [Declaration] = []
    
    private var resetListToTop: Bool = false {
        didSet {
            selectedTab = 0
        }
    }
    
    @Published var showVerse = false
    
    @Published var selectedTab = 0
    
    @Published var errorAlert = false
    
    @Published var requestReview = false 
    
    @Published var showDiscountView = false
    
    @Published var helpUsGrowAlert = false
    
    private(set) var currentDeclaration: Declaration?
    
    @Published var speaklifeCategories: [DeclarationCategory] = DeclarationCategory.categoryOrder
    
    @Published var allcategories: [DeclarationCategory] = DeclarationCategory.allCategories
    
    @Published var bibleCategories: [DeclarationCategory] = DeclarationCategory.bibleCategories
    
    @Published var generalCategories: [DeclarationCategory] = DeclarationCategory.generalCategories
    
    private var allDeclarationsDict: [DeclarationCategory: [Declaration]] = [:]
    
    var selectedCategory: DeclarationCategory {
        DeclarationCategory(rawValue: selectedCategoryString) ?? .destiny
    }
    
    private var isTogglingFavorite = false
    private var pendingSaveTimer: Timer?
    
    @Published var favorites: [Declaration] = [] {
        didSet  {
            // Skip updates if we're in the middle of toggling a favorite
            guard !isTogglingFavorite else { return }
            
            if selectedCategory == .favorites {
                // Only shuffle on category change or initial load
                if declarations.isEmpty || oldValue.isEmpty {
                    declarations = favorites.shuffled()
                    showVerse = false
                }
            }
        }
    }
    
    @Published var general: [Declaration] = [] {
        didSet  {
            if selectedCategory == .general {
                declarations = general.shuffled()
            }
        }
    }
    
    @Published var createOwn: [Declaration] = [] {
        didSet {
            if selectedCategory == .myOwn {
                declarations = createOwn.shuffled()
                showVerse = false
            }
        }
    }
    
    @Published var isFetching = false
    
    @Published var isPurchasing = false
    
    var errorMessage: String? {
        didSet {
            if errorMessage != nil  {
                showErrorMessage = true
            }
        }
    }
    
    @Published var showErrorMessage = false
    
    @Published var showNewAlertMessage = false
    
    private var allDeclarations: [Declaration] = []
    
    var selectedCategories = Set<DeclarationCategory>() {
        didSet {
            print(selectedCategories, "RWRW changed")
        }
    }
   
    private var service: APIService
    
    private let notificationManager: NotificationManager
    
    // MARK: - Init(s)
    
    init(apiService: APIService,
         notificationManager: NotificationManager = .shared) {
        self.service = apiService
        self.notificationManager = notificationManager
        
        // Listen for CloudKit import completion
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("CloudKitImportCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("RWRW: DeclarationViewModel received CloudKit import notification - refreshing data")
            self?.fetchDeclarations()
        }
        
        // Clean up duplicates on startup if using CoreDataAPIService
        if let coreDataService = service as? CoreDataAPIService {
            Task {
                try? await coreDataService.removeDuplicates()
            }
        }
        
        fetchSelectedCategories() { [weak self] in
            self?.cleanUpSelectedCategories() { [weak self] _ in
                guard let self = self else { return }
                if general.isEmpty {
                    let destiny = self.allDeclarations.filter({ $0.category == .destiny })
                    let identity = self.allDeclarations.filter({ $0.category == .identity })
                    let love = self.allDeclarations.filter({ $0.category == .love })
                    general = destiny + identity + love
                }
                self.fetchDeclarations(isInitialLoad: true)
            }
        }
    }
    
    func cleanUpSelectedCategories(completion: (Set<DeclarationCategory>) -> Void) {
        var temp = Set<DeclarationCategory>()
        
        for category in selectedCategories {
            if DeclarationCategory.allCategories.contains(category) {
                temp.insert(category)
            }
        }
        selectedCategories = temp
        completion(selectedCategories)
    }
    
    private func fetchDeclarations(isInitialLoad: Bool = false) {
        isFetching = true
        
        // Store current state before fetching
        let currentDeclarationId = currentDeclaration?.id
        let currentDeclarations = declarations
        
        service.declarations() {  [weak self] declarations, error, _ in
            guard let self  = self else { return }
            self.isFetching = false
            self.allDeclarations = declarations
            self.populateDeclarationsByCategory()
            
            // Only reshuffle if it's initial load or declarations is empty
            if isInitialLoad || self.declarations.isEmpty {
                self.choose(self.selectedCategory) { _ in }
            } else {
                // Update existing declarations in place without reshuffling
                self.updateDeclarationsInPlace(from: declarations, preservingOrder: currentDeclarations)
            }
            
            self.favorites = self.getFavorites()
            self.createOwn = self.getCreateOwn()
            
            // Sync initial favorites to widget
            let favoriteTexts = self.favorites.map { $0.text }
            WidgetDataBridge.shared.syncDeclarationFavorites(favoriteTexts)
            
            // Sync all declarations to widget for accurate text matching
            let allTexts = self.allDeclarations.map { $0.text }
            WidgetDataBridge.shared.syncAllDeclarationsToWidget(allTexts)
            
            // Sync categorized declarations for smart widget filtering
            self.syncCategorizedDeclarationsToWidget()
            self.errorMessage = error?.localizedDescription
            
//            if neededSync {
//                self.showNewAlertMessage = true
//            }
        }
    }
    
    private func updateDeclarationsInPlace(from newDeclarations: [Declaration], preservingOrder currentDeclarations: [Declaration]) {
        // Update each declaration in the current array with new data from backend
        var updatedDeclarations = currentDeclarations
        for (index, declaration) in updatedDeclarations.enumerated() {
            if let updatedDeclaration = newDeclarations.first(where: { $0.id == declaration.id }) {
                // Preserve position but update the data (especially isFavorite status)
                updatedDeclarations[index] = updatedDeclaration
            }
        }
        self.declarations = updatedDeclarations
    }
    
    private func populateDeclarationsByCategory() {
        for declaration in allDeclarations {
            let category = declaration.category
            if allDeclarationsDict[category] == nil {
                allDeclarationsDict[category] = []
            }
            allDeclarationsDict[category]?.append(declaration)
        }
    }
    
    // MARK: - Intent(s)
    
    func setCurrent(_ declaration: Declaration) {
        currentDeclaration = declaration
    }
    
    func toggleDeclaration(_ declaration: Declaration) {
        guard let _ = declarations.firstIndex(where: { $0.id == declaration.id } ) else {
            return
        }
        
        showVerse.toggle()
    }
    
    func subtitle(_ declaration: Declaration) -> String {
        if DeclarationCategory.bibleCategories.contains(declaration.category) || showVerse  {
            return declaration.book ?? ""
        } else if !showVerse, declaration.book == "Jesus" {
           return "Jesus"
        } else {
            return ""
        }
    }
    
    
    // MARK: - Favorites
    
    func favorite(declaration: Declaration) {
        print("💖 DeclarationViewModel: Toggling favorite for:", declaration.text)
        
        guard let indexOf = declarations.firstIndex(where: { $0.id == declaration.id } ) else {
            print("❌ Declaration not found in current declarations")
            return
        }
        
        let wasFavorite = declarations[indexOf].isFavorite ?? false
        declarations[indexOf].isFavorite = !wasFavorite
        print("   Was favorite:", wasFavorite, "Now:", !wasFavorite)
        
        guard let index = allDeclarations.firstIndex(where: { $0.id == declaration.id }) else { 
            print("❌ Declaration not found in allDeclarations")
            return 
        }
        allDeclarations[index] = declarations[indexOf]
        print("✅ Updated in allDeclarations")
        
        // Set flag to prevent array mutations during favorite toggle
        isTogglingFavorite = true
        
        // Update favorites list based on category context
        if selectedCategory == .favorites {
            // In favorites view, update the item in place without removing
            if let favIndex = favorites.firstIndex(where: { $0.id == declaration.id }) {
                favorites[favIndex] = declarations[indexOf]
            }
            
            // If unfavoriting in favorites view, we keep the item visible until user navigates away
            // This prevents the TabView from jumping to wrong items
        } else {
            // In other categories, update the favorites list normally
            if !wasFavorite {
                // Adding to favorites
                if !favorites.contains(where: { $0.id == declaration.id }) {
                    favorites.append(declarations[indexOf])
                }
            } else {
                // Removing from favorites
                favorites.removeAll { $0.id == declaration.id }
            }
        }
        
        // Reset flag
        isTogglingFavorite = false
        
        // Cancel any pending save
        pendingSaveTimer?.invalidate()
        
        // Debounce the save operation to prevent rapid CloudKit syncs
        pendingSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            self.service.save(declarations: self.allDeclarations) { [weak self] success in
                // Sync only actual favorites to widget
                guard let self = self else { return }
                let actualFavorites = self.allDeclarations.filter { $0.isFavorite == true }
                let favoriteTexts = actualFavorites.map { $0.text }
                WidgetDataBridge.shared.syncDeclarationFavorites(favoriteTexts)
            }
        }
    }
    
    func refreshFavorites() {
        // Clear the toggling flag before refresh
        isTogglingFavorite = false
        favorites = getFavorites()
    }
    
    private func getFavorites() -> [Declaration] {
        allDeclarations.filter { $0.isFavorite == true }
    }
    
    
    func removeFavorite(at indexSet: IndexSet) {
        _ = indexSet.map { int in
            let declaration = favorites[int]
            favorite(declaration: declaration)
        }
    }
    
    // MARK: - Create own
    
    func createDeclaration(_ text: String, contentType: ContentType = .affirmation)  {
        guard text.count > 2 else {  return }
        let declaration = Declaration(text: text, category: .myOwn, isFavorite: false, contentType: contentType, lastEdit: Date())
        guard !allDeclarations.contains(declaration) else {
            return
        }
        allDeclarations.append(declaration)
        
        // Use the new single declaration create method if available
        if let coreDataService = service as? CoreDataAPIService {
            Task {
                do {
                    try await coreDataService.createSingleDeclaration(declaration)
                    await MainActor.run {
                        self.refreshCreateOwn()
                    }
                } catch {
                    print("RWRW: Error creating declaration - \(error.localizedDescription)")
                    // Remove from allDeclarations if save failed
                    await MainActor.run {
                        self.allDeclarations.removeAll(where: { $0.id == declaration.id })
                    }
                }
            }
        } else {
            // Fallback to old save method for legacy service
            service.save(declarations: allDeclarations) { [weak self] success in
                guard success else { return }
                self?.refreshCreateOwn()
            }
        }
    }
    
    func editMyOwn(_ declaration: String) {
        let declaration = Declaration(text: declaration, category: .myOwn, isFavorite: false, contentType: .affirmation, lastEdit: Date())
        removeOwn(declaration: declaration)
    }
    
    func removeOwn(declaration: Declaration) {
        guard let indexOf = createOwn.firstIndex(where: { $0.id == declaration.id } ) else {
            return
        }
        
        // Update UI immediately to prevent collection view inconsistency
        allDeclarations.removeAll(where: { $0.id == declaration.id })
        createOwn.removeAll(where: { $0.id == declaration.id })
        objectWillChange.send()
        
        // If using CoreDataAPIService, delete from Core Data in background
        if let coreDataService = service as? CoreDataAPIService {
            Task {
                do {
                    try await coreDataService.deleteDeclaration(withId: declaration.id, contentType: declaration.contentType)
                    print("RWRW: Declaration removed from Core Data successfully")
                } catch {
                    print("RWRW: Error removing declaration from Core Data - \(error.localizedDescription)")
                    
                    // If Core Data delete fails, restore the item
                    await MainActor.run {
                        self.allDeclarations.append(declaration)
                        self.refreshCreateOwn()
                    }
                }
            }
        } else {
            // Fallback for non-Core Data services
            service.save(declarations: allDeclarations) { [weak self] success in
                if !success {
                    // Restore item if save fails
                    DispatchQueue.main.async {
                        self?.allDeclarations.append(declaration)
                        self?.refreshCreateOwn()
                    }
                }
            }
        }
    }
    
    
    func refreshCreateOwn() {
        createOwn = getCreateOwn()
    }
    
    private func getCreateOwn() -> [Declaration] {
        allDeclarations.filter { $0.category == .myOwn }
    }
    
    
    func removeOwn(at indexSet: IndexSet) {
        _ = indexSet.map { int in
            let declaration = createOwn[int]
            removeOwn(declaration: declaration)
        }
    }
    
    // MARK: - Declarations
    
    func choose(_ category: DeclarationCategory, completion: @escaping(Bool) -> Void) {
        // Don't reshuffle if we're already in this category
        let isChangingCategory = selectedCategory != category
        
        fetchDeclarations(for: category) { [weak self] declarations in
            guard let self = self else { return }
            guard declarations.count > 0 else {
                if general.isEmpty {
                    let destiny = self.allDeclarations.filter({ $0.category == .destiny })
                    let identity = self.allDeclarations.filter({ $0.category == .identity })
                    let love = self.allDeclarations.filter({ $0.category == .love })
                    general = destiny + identity + love
                    self.selectedCategoryString = category.rawValue
                    self.resetListToTop = true
                    completion(true)
                    return
                }
                self.errorMessage = "Oops, you need to add one to this category first!"
                completion(false)
                return
            }
            self.selectedCategoryString = category.rawValue
            
            // Only shuffle if changing categories or if declarations is empty
            if isChangingCategory || self.declarations.isEmpty {
                let shuffled = declarations.shuffled()
                self.declarations = shuffled
                self.resetListToTop = true
            }
            completion(true)
        }
    }
    
    func choose(_  declaration: Declaration) {
        if !declarations.contains(where: { $0 == declaration }) {
            declarations.append(declaration)
            guard declarations.count > 1 else { return }
            declarations.swapAt(declarations.indices.first!, declarations.indices.last!)
        }  else {
            let favIndex = declarations.firstIndex(where: { $0.id == declaration.id})
            declarations.swapAt(declarations.indices.first!, favIndex!)
        }
    }
    
    func fetchDeclarations(for category: DeclarationCategory, completion: @escaping(([Declaration]) -> Void)) {
            if category == .general {
            refreshGeneral(categories: selectedCategories)
            completion(general)
        }  else if category == .favorites {
            refreshFavorites()
            completion(favorites)
        } else if category == .myOwn {
            refreshCreateOwn()
            completion(createOwn)
        } else {
            let declarations = allDeclarations.filter { $0.category == category }
            allDeclarationsDict[category] = declarations
            completion(declarations)
        }
    }
    
    func fetchSelectedCategories(completion: @escaping () -> Void?)  {
        service.declarationCategories { [weak self] selectedCategories, error in
            if let error = error {
                print(error)
            }
            self?.selectedCategories = selectedCategories
            completion()
        }
    }
    
    func save(_ selectedCategories: Set<DeclarationCategory>) {
        self.selectedCategories = selectedCategories
        service.save(selectedCategories: selectedCategories) { [weak self] success in
            if success && self?.selectedCategory == .general {
                self?.refreshGeneral(categories: selectedCategories)
            }
        }
    }
    
    func refreshGeneral(categories: Set<DeclarationCategory>) {
        var tempGen: [Declaration] = []
        for category in categories {
            let affirmations = allDeclarations.filter { $0.category == category }
            tempGen.append(contentsOf: affirmations)
        }
        general = tempGen
    }
    
    func setDeclaration(_ content: String,  category: String)  {
        let contentData = content
       // contentData += " ~ " + category
        let contentText = prefixString(content, until: " ~").dropLast()
        print(contentText, category, "RWRW")
        
            guard let declaration = allDeclarations.first(where: { $0.text.hasPrefix(contentText) }) else {
                print("Failed to find a matching declaration")
                return
            }
            self.choose(declaration)
    }
    
    func setRemoteDeclarationVersion(version: Int) {
        service.remoteVersion = version
    }
    
    // MARK: - Smart Widget Category Integration
    
    /// Sync declarations organized by categories to widget for intelligent filtering
    private func syncCategorizedDeclarationsToWidget() {
        var categorizedDeclarations: [String: [String]] = [:]
        
        // Map your DeclarationCategory to widget-friendly category names
        let categoryMapping: [DeclarationCategory: [String]] = [
            // Spiritual Life
            .faith: ["Faith", "Strength", "Wisdom"],
            .hope: ["Hope", "New Beginnings", "Purpose"],
            .destiny: ["Purpose", "New Beginnings", "Strength"],
            .identity: ["Identity", "Purpose", "Strength"],
            .grace: ["Grace", "Forgiveness", "Love"],
            .love: ["Love", "Family", "Gratitude"],
            .gratitude: ["Gratitude", "Joy", "Celebration"],
            .praise: ["Worship", "Gratitude", "Joy"],
            .joy: ["Joy", "Celebration", "Gratitude"],
            
            // Life Challenges  
            .fear: ["Peace", "Comfort", "Strength"],
            .anxiety: ["Peace", "Comfort", "Rest"],
            .hardtimes: ["Strength", "Perseverance", "Hope"],
            .addiction: ["Strength", "New Beginnings", "Purpose"],
            .rest: ["Rest", "Peace", "Comfort"],
            
            // Relationships & Work
            .marriage: ["Love", "Family", "Gratitude"],
            .parenting: ["Family", "Love", "Wisdom"],
            .friendship: ["Love", "Gratitude", "Joy"],
            .work: ["Work", "Productivity", "Wisdom", "Perseverance"],
            
            // Spiritual Warfare & Protection
            .warfare: ["Protection", "Strength", "Faith"],
            .godsprotection: ["Protection", "Peace", "Comfort"],
            
            // Personal Growth
            .wisdom: ["Wisdom", "Growth", "Purpose"],
            .confidence: ["Strength", "Identity", "Purpose"],
            .purity: ["Purity", "Identity", "Purpose"],
            .obedience: ["Wisdom", "Growth", "Purpose"],
            .spiritualGrowth: ["Growth", "Wisdom", "Purpose"],
            
            // Blessings & Favor
            .health: ["Health", "Strength", "Gratitude"],
            .wealth: ["Prosperity", "Gratitude", "Wisdom"],
            .favor: ["Favor", "Gratitude", "Purpose"],
            .miracles: ["Miracles", "Faith", "Hope"],
            
            // Bible categories get mapped to contextual categories
            .psalms: ["Worship", "Gratitude", "Peace"],
            .proverbs: ["Wisdom", "Growth", "Purpose"]
        ]
        
        // Group declarations by widget categories
        for declaration in allDeclarations {
            let categoryKeys = categoryMapping[declaration.category] ?? ["General"]
            
            for categoryKey in categoryKeys {
                if categorizedDeclarations[categoryKey] == nil {
                    categorizedDeclarations[categoryKey] = []
                }
                categorizedDeclarations[categoryKey]?.append(declaration.text)
            }
        }
        
        // Always include user's favorites and personal declarations
        if !favorites.isEmpty {
            categorizedDeclarations["Favorites"] = favorites.map { $0.text }
        }
        
        if !createOwn.isEmpty {
            categorizedDeclarations["Personal"] = createOwn.map { $0.text }
        }
        
        // Sync to widget
        WidgetDataBridge.shared.syncCategorizedDeclarations(categorizedDeclarations)
        
        // Update user's selected categories for widget
        syncUserCategoryPreferences()
    }
    
    /// Sync user's currently selected categories to widget for personalization
    private func syncUserCategoryPreferences() {
        // Convert user's selected DeclarationCategories to widget category names
        let widgetCategories = selectedCategories.compactMap { category -> [String]? in
            switch category {
            case .faith: return ["Faith", "Strength"]
            case .hope: return ["Hope", "New Beginnings"]
            case .love: return ["Love", "Family"]
            case .rest: return ["Peace", "Rest"]
            case .work: return ["Work", "Productivity"]
            case .anxiety: return ["Peace", "Comfort"]
            case .fear: return ["Peace", "Strength"]
            case .gratitude: return ["Gratitude", "Joy"]
            case .wisdom: return ["Wisdom", "Growth"]
            case .health: return ["Health", "Strength"]
            case .confidence: return ["Strength", "Identity"]
            case .favor: return ["Favor", "Gratitude"]
            case .destiny: return ["Purpose", "New Beginnings"]
            default: return nil
            }
        }.flatMap { $0 }
        
        // Include contextual categories based on current time if user hasn't selected many
        var finalCategories = widgetCategories
        if finalCategories.count < 3 {
            let hour = Calendar.current.component(.hour, from: Date())
            switch hour {
            case 5...8: finalCategories.append(contentsOf: ["Morning", "Energy", "New Beginnings"])
            case 12...13: finalCategories.append(contentsOf: ["Rest", "Reflection"])
            case 18...20: finalCategories.append(contentsOf: ["Family", "Gratitude"])
            case 21...23: finalCategories.append(contentsOf: ["Peace", "Rest"])
            default: break
            }
        }
        
        // Remove duplicates and update widget
        let uniqueCategories = Array(Set(finalCategories))
        WidgetDataBridge.shared.updateSelectedCategories(uniqueCategories)
    }
    
    /// Call this when user changes their category selections
    func updateCategorySelections(_ newCategories: Set<DeclarationCategory>) {
        selectedCategories = newCategories
        
        // Immediately sync the updated preferences to widget
        syncUserCategoryPreferences()
        
        // Track usage for analytics
        for category in newCategories {
            let categoryName = category.rawValue
            WidgetDataBridge.shared.trackCategoryUsage(categoryName)
        }
    }
}

func prefixString(_ text: String, until substring: String) -> String {
    if let range = text.range(of: substring) {
        let prefix = text[..<range.lowerBound]
        return String(prefix)
    } else {
        return text
    }
}
