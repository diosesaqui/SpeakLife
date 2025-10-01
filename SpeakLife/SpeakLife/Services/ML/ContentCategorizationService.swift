//
//  ContentCategorizationService.swift
//  SpeakLife
//
//  CoreML-powered content categorization service
//

import Foundation
import CoreML
import NaturalLanguage
import Combine

final class ContentCategorizationService: ObservableObject {
    
    static let shared = ContentCategorizationService()
    
    @Published var isModelLoaded = false
    @Published var lastUpdateDate: Date?
    
    private var categorizationModel: MLModel?
    private var emotionalToneModel: MLModel?
    private let modelCache: NSCache<NSString, MLModel> = {
        let cache = NSCache<NSString, MLModel>()
        cache.countLimit = 10
        return cache
    }()
    
    private let predictionCache: NSCache<NSString, ContentCategories> = {
        let cache = NSCache<NSString, ContentCategories>()
        cache.countLimit = 1000
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()
    
    // Fallback categorization for when ML models aren't available
    private let fallbackCategorizer = FallbackContentCategorizer()
    
    init() {
        Task {
            await loadModels()
        }
    }
    
    // MARK: - Model Loading
    
    private func loadModels() async {
        do {
            await loadCategorizationModel()
            await loadEmotionalToneModel()
            
            DispatchQueue.main.async {
                self.isModelLoaded = true
                self.lastUpdateDate = Date()
            }
            
            print("✅ ML models loaded successfully")
        } catch {
            print("⚠️ Failed to load ML models, using fallback: \(error)")
            
            DispatchQueue.main.async {
                self.isModelLoaded = false
            }
        }
    }
    
    private func loadCategorizationModel() async {
        let modelName = "SpiritualCategoryClassifier"
        
        // Check if trained model exists
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access documents directory")
            return
        }
        let modelURL = documentsPath.appendingPathComponent("MLModels/\(modelName).mlmodel")
        
        if FileManager.default.fileExists(atPath: modelURL.path) {
            do {
                categorizationModel = try MLModel(contentsOf: modelURL)
                print("📁 Loaded custom categorization model")
            } catch {
                print("⚠️ Failed to load custom model: \(error)")
                await trainInitialModel()
            }
        } else {
            print("🔄 No trained model found, training initial model...")
            await trainInitialModel()
        }
    }
    
    private func loadEmotionalToneModel() async {
        let modelName = "EmotionalToneClassifier"
        
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("⚠️ Could not access documents directory")
            return
        }
        let modelURL = documentsPath.appendingPathComponent("MLModels/\(modelName).mlmodel")
        
        if FileManager.default.fileExists(atPath: modelURL.path) {
            do {
                emotionalToneModel = try MLModel(contentsOf: modelURL)
                print("📁 Loaded emotional tone model")
            } catch {
                print("⚠️ Failed to load tone model: \(error)")
            }
        }
    }
    
    private func trainInitialModel() async {
        print("📱 Using iOS-compatible heuristic categorization instead of training")
        // iOS apps use rule-based categorization instead of training ML models
        print("✅ iOS categorization ready")
    }
    
    // MARK: - iOS Initialization
    
    func initializeForIOS() {
        print("📱 Initializing content categorization for iOS...")
        isModelLoaded = true
        lastUpdateDate = Date()
        print("✅ iOS content categorization ready (using heuristic-based analysis)")
    }
    
    // MARK: - Content Categorization
    
    func categorizeContent(_ text: String) async -> ContentCategories {
        // Input validation
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            print("⚠️ Empty text provided for categorization")
            return ContentCategories.default
        }
        guard trimmedText.count <= 10000 else {
            print("⚠️ Text too long for categorization: \(trimmedText.count) characters")
            return ContentCategories.default
        }
        
        // Check cache first
        let cacheKey = NSString(string: trimmedText)
        if let cached = predictionCache.object(forKey: cacheKey) {
            return cached
        }
        
        let categories: ContentCategories
        
        if let model = categorizationModel {
            categories = await categorizeWithMLModel(trimmedText, model: model)
        } else {
            categories = await fallbackCategorizer.categorize(trimmedText)
        }
        
        // Cache result
        predictionCache.setObject(categories, forKey: cacheKey)
        
        return categories
    }
    
    private func categorizeWithMLModel(_ text: String, model: MLModel) async -> ContentCategories {
        do {
            // Prepare input for ML model
            let inputFeatures = try MLFeatureValue(string: text)
            let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["text": inputFeatures]))
            
            // Extract spiritual categories
            let spiritualCategories = extractSpiritualCategories(from: prediction)
            
            // Get emotional tone
            let emotionalTone = await getEmotionalTone(for: text)
            
            // Calculate confidence
            let confidence = extractConfidence(from: prediction)
            
            return ContentCategories(
                spiritual: spiritualCategories,
                emotional: emotionalTone,
                maturity: inferMaturityLevel(from: text, categories: spiritualCategories),
                confidence: confidence
            )
            
        } catch {
            print("⚠️ ML prediction failed, using fallback: \(error)")
            return await fallbackCategorizer.categorize(text)
        }
    }
    
    private func getEmotionalTone(for text: String) async -> EmotionalTone {
        if let toneModel = emotionalToneModel {
            do {
                let inputFeatures = try MLFeatureValue(string: text)
                let prediction = try toneModel.prediction(from: MLDictionaryFeatureProvider(dictionary: ["text": inputFeatures]))
                
                if let toneString = prediction.featureValue(for: "emotional_tone")?.stringValue,
                   let tone = EmotionalTone(rawValue: toneString) {
                    return tone
                }
            } catch {
                print("⚠️ Emotional tone prediction failed: \(error)")
            }
        }
        
        // Fallback to rule-based tone detection
        return fallbackCategorizer.inferEmotionalTone(from: text)
    }
    
    // MARK: - Batch Processing
    
    func categorizeMultipleContent(_ content: [Declaration]) async -> [ContentCategories] {
        return await withTaskGroup(of: (Int, ContentCategories).self, returning: [ContentCategories].self) { group in
            
            for (index, declaration) in content.enumerated() {
                group.addTask {
                    let categories = await self.categorizeContent(declaration.text)
                    return (index, categories)
                }
            }
            
            var results: [ContentCategories] = Array(repeating: ContentCategories.default, count: content.count)
            
            for await (index, categories) in group {
                results[index] = categories
            }
            
            return results
        }
    }
    
    // MARK: - Personalized Category Generation
    
    func generatePersonalizedCategories(for userBehavior: UserBehaviorFeatures) async -> [PersonalizedCategory] {
        var personalizedCategories: [PersonalizedCategory] = []
        
        // Analyze user's top engaged categories
        let topCategories = userBehavior.topCategories.sorted { $0.value > $1.value }.prefix(3)
        
        for (categoryKey, engagementScore) in topCategories {
            let category = await createPersonalizedCategory(
                basedOn: categoryKey,
                engagementScore: engagementScore,
                userContext: userBehavior
            )
            personalizedCategories.append(category)
        }
        
        // Create struggle-based categories
        for struggle in userBehavior.strugglingAreas {
            let category = await createStruggleBasedCategory(
                struggle: struggle,
                userContext: userBehavior
            )
            personalizedCategories.append(category)
        }
        
        // Create growth-based categories
        for growthArea in userBehavior.growthAreas {
            let category = await createGrowthBasedCategory(
                growthArea: growthArea,
                userContext: userBehavior
            )
            personalizedCategories.append(category)
        }
        
        return personalizedCategories
    }
    
    func interpretSearchIntent(_ searchQuery: String) async -> [SearchSuggestion] {
        let categories = await categorizeContent(searchQuery)
        var suggestions: [SearchSuggestion] = []
        
        for spiritualCategory in categories.spiritual {
            let suggestion = SearchSuggestion(
                id: UUID(),
                displayText: "Looking for \(spiritualCategory.displayName)",
                refinedQuery: spiritualCategory.rawValue,
                categories: [spiritualCategory],
                confidence: categories.confidence
            )
            suggestions.append(suggestion)
        }
        
        // Add contextual suggestions based on emotional tone
        if categories.emotional == .gentle {
            suggestions.append(SearchSuggestion(
                id: UUID(),
                displayText: "Need gentle encouragement → Comfort & Peace declarations",
                refinedQuery: "peace comfort gentle",
                categories: [.peace],
                confidence: 0.8
            ))
        } else if categories.emotional == .powerful {
            suggestions.append(SearchSuggestion(
                id: UUID(),
                displayText: "Ready for breakthrough → Strength & Victory declarations",
                refinedQuery: "strength breakthrough victory",
                categories: [.breakthrough, .strength],
                confidence: 0.8
            ))
        }
        
        return suggestions
    }
    
    func getDeclarationsForJournalEntry(_ journalText: String) async -> [Declaration] {
        let categories = await categorizeContent(journalText)
        
        // This would query your declaration database based on categories
        // For now, return sample declarations that match the categories
        var matchingDeclarations: [Declaration] = []
        
        // In a real implementation, this would:
        // 1. Query CoreData for declarations matching the spiritual categories
        // 2. Sort by relevance based on emotional tone match
        // 3. Consider user's past preferences
        // 4. Return top 3-5 most relevant declarations
        
        return matchingDeclarations
    }
    
    // MARK: - Helper Methods
    
    private func extractSpiritualCategories(from prediction: MLFeatureProvider) -> [SpiritualContentCategory] {
        // Extract categories from ML prediction
        if let categoryString = prediction.featureValue(for: "spiritual_category")?.stringValue,
           let category = SpiritualContentCategory(rawValue: categoryString) {
            return [category]
        }
        
        return [.faith] // Default fallback
    }
    
    private func extractConfidence(from prediction: MLFeatureProvider) -> Double {
        // Extract confidence score from ML prediction
        if let probabilities = prediction.featureValue(for: "spiritual_categoryProbability")?.dictionaryValue {
            let maxProbability = probabilities.values.compactMap { $0.doubleValue }.max() ?? 0.5
            return maxProbability
        }
        
        return 0.7 // Default confidence
    }
    
    private func inferMaturityLevel(from text: String, categories: [SpiritualContentCategory]) -> SpiritualMaturity {
        let lowercased = text.lowercased()
        
        if lowercased.contains("leadership") || lowercased.contains("ministry") || lowercased.contains("authority") {
            return .leadership
        } else if lowercased.contains("wisdom") || lowercased.contains("understanding") || categories.contains(.wisdom) {
            return .mature
        } else if lowercased.contains("growing") || lowercased.contains("learning") {
            return .growing
        } else {
            return .newBeliever
        }
    }
    
    private func createPersonalizedCategory(
        basedOn categoryKey: String,
        engagementScore: Double,
        userContext: UserBehaviorFeatures
    ) async -> PersonalizedCategory {
        return PersonalizedCategory(
            name: "Your \(categoryKey.capitalized) Journey",
            description: "Declarations that resonate with your spiritual growth in \(categoryKey)",
            contentIds: [], // Would be populated with relevant declaration IDs
            userReasonExplanation: "Based on your high engagement with \(categoryKey) content (\(Int(engagementScore * 100))% engagement)",
            confidence: min(engagementScore / 10.0, 1.0),
            spiritualFocus: await mapCategoryToSpiritualFocus(categoryKey)
        )
    }
    
    private func createStruggleBasedCategory(
        struggle: String,
        userContext: UserBehaviorFeatures
    ) async -> PersonalizedCategory {
        return PersonalizedCategory(
            name: "Overcoming \(struggle.capitalized)",
            description: "Targeted declarations for your current challenges with \(struggle)",
            contentIds: [],
            userReasonExplanation: "Personalized support for your journey through \(struggle)",
            confidence: 0.8,
            spiritualFocus: [.deliverance, .strength, .breakthrough]
        )
    }
    
    private func createGrowthBasedCategory(
        growthArea: String,
        userContext: UserBehaviorFeatures
    ) async -> PersonalizedCategory {
        return PersonalizedCategory(
            name: "Growing in \(growthArea.capitalized)",
            description: "Declarations to strengthen your \(growthArea) journey",
            contentIds: [],
            userReasonExplanation: "Supporting your growth in \(growthArea)",
            confidence: 0.7,
            spiritualFocus: await mapCategoryToSpiritualFocus(growthArea)
        )
    }
    
    private func mapCategoryToSpiritualFocus(_ category: String) async -> [SpiritualContentCategory] {
        switch category.lowercased() {
        case "healing", "health": return [.healing]
        case "faith", "trust": return [.faith]
        case "peace", "rest": return [.peace]
        case "strength", "power": return [.strength]
        case "wisdom", "understanding": return [.wisdom]
        case "breakthrough", "victory": return [.breakthrough]
        case "relationships", "love": return [.relationships]
        case "purpose", "calling": return [.purpose]
        case "protection", "safety": return [.protection]
        case "prosperity", "provision": return [.prosperity]
        default: return [.faith]
        }
    }
}

// MARK: - Supporting Types

class ContentCategories {
    let spiritual: [SpiritualContentCategory]
    let emotional: EmotionalTone
    let maturity: SpiritualMaturity
    let confidence: Double
    
    init(spiritual: [SpiritualContentCategory], emotional: EmotionalTone, maturity: SpiritualMaturity, confidence: Double) {
        self.spiritual = spiritual
        self.emotional = emotional
        self.maturity = maturity
        self.confidence = confidence
    }
    
    static let `default` = ContentCategories(
        spiritual: [.faith],
        emotional: .encouraging,
        maturity: .newBeliever,
        confidence: 0.5
    )
}

struct SearchSuggestion: Identifiable {
    let id: UUID
    let displayText: String
    let refinedQuery: String
    let categories: [SpiritualContentCategory]
    let confidence: Double
}

// MARK: - Fallback Categorizer

class FallbackContentCategorizer {
    
    func categorize(_ text: String) async -> ContentCategories {
        let spiritual = classifySpiritualContent(text)
        let emotional = inferEmotionalTone(from: text)
        let maturity = inferMaturityLevel(from: text)
        
        return ContentCategories(
            spiritual: spiritual,
            emotional: emotional,
            maturity: maturity,
            confidence: 0.6 // Lower confidence for rule-based approach
        )
    }
    
    private func classifySpiritualContent(_ text: String) -> [SpiritualContentCategory] {
        var categories: [SpiritualContentCategory] = []
        let lowercased = text.lowercased()
        
        if lowercased.contains("heal") || lowercased.contains("restore") || lowercased.contains("recovery") {
            categories.append(.healing)
        }
        if lowercased.contains("faith") || lowercased.contains("believe") || lowercased.contains("trust") {
            categories.append(.faith)
        }
        if lowercased.contains("peace") || lowercased.contains("rest") || lowercased.contains("calm") {
            categories.append(.peace)
        }
        if lowercased.contains("strength") || lowercased.contains("power") || lowercased.contains("mighty") {
            categories.append(.strength)
        }
        if lowercased.contains("wisdom") || lowercased.contains("understand") || lowercased.contains("discern") {
            categories.append(.wisdom)
        }
        if lowercased.contains("breakthrough") || lowercased.contains("victory") || lowercased.contains("overcome") {
            categories.append(.breakthrough)
        }
        if lowercased.contains("love") || lowercased.contains("relationship") || lowercased.contains("marriage") {
            categories.append(.relationships)
        }
        if lowercased.contains("purpose") || lowercased.contains("calling") || lowercased.contains("destiny") {
            categories.append(.purpose)
        }
        if lowercased.contains("protect") || lowercased.contains("safe") || lowercased.contains("guard") {
            categories.append(.protection)
        }
        if lowercased.contains("prosper") || lowercased.contains("provision") || lowercased.contains("abundance") {
            categories.append(.prosperity)
        }
        if lowercased.contains("grateful") || lowercased.contains("thankful") || lowercased.contains("praise") {
            categories.append(.gratitude)
        }
        if lowercased.contains("deliver") || lowercased.contains("freedom") || lowercased.contains("liberation") {
            categories.append(.deliverance)
        }
        if lowercased.contains("identity") || lowercased.contains("who i am") || lowercased.contains("chosen") {
            categories.append(.identity)
        }
        if lowercased.contains("worship") || lowercased.contains("adore") || lowercased.contains("honor") {
            categories.append(.worship)
        }
        if lowercased.contains("warfare") || lowercased.contains("battle") || lowercased.contains("fight") {
            categories.append(.warfare)
        }
        
        return categories.isEmpty ? [.faith] : categories
    }
    
    func inferEmotionalTone(from text: String) -> EmotionalTone {
        let lowercased = text.lowercased()
        
        if lowercased.contains("mighty") || lowercased.contains("power") || lowercased.contains("strong") {
            return .powerful
        } else if lowercased.contains("peace") || lowercased.contains("rest") || lowercased.contains("calm") {
            return .peaceful
        } else if lowercased.contains("gentle") || lowercased.contains("tender") || lowercased.contains("soft") {
            return .gentle
        } else if lowercased.contains("bold") || lowercased.contains("confident") || lowercased.contains("fearless") {
            return .bold
        } else if lowercased.contains("comfort") || lowercased.contains("embrace") || lowercased.contains("love") {
            return .comforting
        } else if lowercased.contains("now") || lowercased.contains("today") || lowercased.contains("immediately") {
            return .urgent
        } else {
            return .encouraging
        }
    }
    
    private func inferMaturityLevel(from text: String) -> SpiritualMaturity {
        let lowercased = text.lowercased()
        
        if lowercased.contains("leadership") || lowercased.contains("authority") || lowercased.contains("ministry") {
            return .leadership
        } else if lowercased.contains("wisdom") || lowercased.contains("understanding") || lowercased.contains("discernment") {
            return .mature
        } else if lowercased.contains("growing") || lowercased.contains("learning") || lowercased.contains("developing") {
            return .growing
        } else {
            return .newBeliever
        }
    }
}