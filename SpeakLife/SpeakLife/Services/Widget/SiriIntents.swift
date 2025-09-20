//
//  SiriIntents.swift
//  SpeakLife
//
//  Created by Claude on 8/9/25.
//

import AppIntents
import Foundation
import SwiftUI

// MARK: - Siri-Enabled App Intents

@available(iOS 16.0, *)
struct GetDailyPromiseIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Daily Promise"
    static var description = IntentDescription("Get today's inspirational Bible promise")
    
    // Make this discoverable to Siri
    static var openAppWhenRun: Bool = false
    static var parameterSummary: some ParameterSummary {
        Summary("Get my daily Bible promise")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let currentPromise = getCurrentPromise()
        
        // Update widget if needed
        UserDefaults.widgetGroup.set(currentPromise, forKey: "currentWidgetPromise")
        UserDefaults.widgetGroup.set(Date(), forKey: "lastPromiseChangeDate")
        
        return .result(
            dialog: IntentDialog(stringLiteral: currentPromise),
            view: PromiseSnippetView(promise: currentPromise)
        )
    }
    
    private func getCurrentPromise() -> String {
        // Use time-based selection for daily promise
        let promises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        if promises.isEmpty {
            return "I am blessed!"
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let index = hour % promises.count
        return promises[index]
    }
}

@available(iOS 16.0, *)
struct GetRandomPromiseIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Random Promise"
    static var description = IntentDescription("Get a random Bible promise for inspiration")
    
    static var openAppWhenRun: Bool = false
    static var parameterSummary: some ParameterSummary {
        Summary("Get a random Bible promise")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let randomPromise = getRandomPromise()
        
        // Update widget
        UserDefaults.widgetGroup.set(randomPromise, forKey: "currentWidgetPromise")
        UserDefaults.widgetGroup.set(Date(), forKey: "lastPromiseChangeDate")
        
        return .result(
            dialog: IntentDialog(stringLiteral: randomPromise),
            view: PromiseSnippetView(promise: randomPromise)
        )
    }
    
    private func getRandomPromise() -> String {
        let promises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        return promises.randomElement() ?? "I am blessed!"
    }
}

@available(iOS 16.0, *)
struct GetFavoritePromiseIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Favorite Promise"
    static var description = IntentDescription("Get one of your favorite Bible promises")
    
    static var openAppWhenRun: Bool = false
    static var parameterSummary: some ParameterSummary {
        Summary("Get one of my favorite Bible promises")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let favorites = UserDefaults.widgetGroup.stringArray(forKey: "widgetFavorites") ?? []
        
        let favoritePromise: String
        if !favorites.isEmpty {
            favoritePromise = favorites.randomElement() ?? "I am blessed!"
        } else {
            favoritePromise = "You haven't favorited any promises yet. Try favoriting one from your widget!"
        }
        
        // Update widget if it's a real promise
        if !favorites.isEmpty {
            UserDefaults.widgetGroup.set(favoritePromise, forKey: "currentWidgetPromise")
            UserDefaults.widgetGroup.set(Date(), forKey: "lastPromiseChangeDate")
        }
        
        return .result(
            dialog: IntentDialog(stringLiteral: favoritePromise),
            view: PromiseSnippetView(promise: favoritePromise)
        )
    }
}

@available(iOS 16.0, *)
struct SetPromiseByCategoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Promise by Topic"
    static var description = IntentDescription("Get a Bible promise about a specific topic")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Topic", description: "What topic would you like encouragement about?")
    var topic: PromiseTopicEntity
    
    static var parameterSummary: some ParameterSummary {
        Summary("Get a Bible promise about \(\.$topic)")
    }
    
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let promiseForTopic = getPromiseForTopic(topic.rawValue)
        
        // Update widget
        UserDefaults.widgetGroup.set(promiseForTopic, forKey: "currentWidgetPromise")
        UserDefaults.widgetGroup.set(Date(), forKey: "lastPromiseChangeDate")
        
        return .result(
            dialog: IntentDialog(stringLiteral: "Here's a promise about \(topic.displayName.lowercased()): \(promiseForTopic)"),
            view: PromiseSnippetView(promise: promiseForTopic)
        )
    }
    
    private func getPromiseForTopic(_ topic: String) -> String {
        // This is a simplified implementation - in a real app you might filter by actual categories
        let promises = UserDefaults.widgetGroup.stringArray(forKey: "syncedPromises") ?? []
        
        if promises.isEmpty {
            return "I am blessed!"
        }
        
        // Filter promises that might relate to the topic (basic keyword matching)
        let filtered = promises.filter { promise in
            let lowercasePromise = promise.lowercased()
            let topicKeywords = getTopicKeywords(for: topic)
            return topicKeywords.contains { keyword in
                lowercasePromise.contains(keyword.lowercased())
            }
        }
        
        return filtered.randomElement() ?? promises.randomElement() ?? "I am blessed!"
    }
    
    private func getTopicKeywords(for topic: String) -> [String] {
        switch topic.lowercased() {
        case "faith": return ["faith", "believe", "trust", "God"]
        case "hope": return ["hope", "future", "plans", "tomorrow"]
        case "love": return ["love", "loved", "heart", "care"]
        case "peace": return ["peace", "calm", "rest", "quiet"]
        case "strength": return ["strength", "strong", "power", "mighty"]
        case "fear": return ["fear", "afraid", "courage", "brave"]
        case "joy": return ["joy", "joyful", "happiness", "glad", "rejoice"]
        case "wisdom": return ["wisdom", "wise", "understanding", "knowledge"]
        default: return [topic]
        }
    }
}

// MARK: - Promise Topic Entity
@available(iOS 16.0, *)
struct PromiseTopicEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Promise Topic")
    static var defaultQuery = PromiseTopicQuery()
    
    var id: String { rawValue }
    var displayName: String {
        switch rawValue {
        case "faith": return "Faith"
        case "hope": return "Hope"
        case "love": return "Love"
        case "peace": return "Peace"
        case "strength": return "Strength"
        case "fear": return "Fear & Courage"
        case "joy": return "Joy"
        case "wisdom": return "Wisdom"
        default: return rawValue.capitalized
        }
    }
    
    let rawValue: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }
    
    static let allTopics = [
        PromiseTopicEntity(rawValue: "faith"),
        PromiseTopicEntity(rawValue: "hope"),
        PromiseTopicEntity(rawValue: "love"),
        PromiseTopicEntity(rawValue: "peace"),
        PromiseTopicEntity(rawValue: "strength"),
        PromiseTopicEntity(rawValue: "fear"),
        PromiseTopicEntity(rawValue: "joy"),
        PromiseTopicEntity(rawValue: "wisdom")
    ]
}

@available(iOS 16.0, *)
struct PromiseTopicQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PromiseTopicEntity] {
        return identifiers.compactMap { id in
            PromiseTopicEntity.allTopics.first { $0.id == id }
        }
    }
    
    func suggestedEntities() async throws -> [PromiseTopicEntity] {
        return PromiseTopicEntity.allTopics
    }
    
    func defaultResult() async -> PromiseTopicEntity? {
        return PromiseTopicEntity.allTopics.first
    }
}

// MARK: - Snippet View
@available(iOS 16.0, *)
struct PromiseSnippetView: View {
    let promise: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "quote.bubble.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("Daily Promise")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text(promise)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(6)
            
            HStack {
                Spacer()
                Text("SpeakLife")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - App Shortcuts Provider
@available(iOS 16.0, *)
struct PromiseAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetDailyPromiseIntent(),
            phrases: [
                "Get my daily promise from \(.applicationName)",
                "Show me today's promise",
                "What's my Bible promise for today",
                "Get daily promise"
            ],
            shortTitle: "Daily Promise",
            systemImageName: "quote.bubble.fill"
        )
        
        AppShortcut(
            intent: GetRandomPromiseIntent(),
            phrases: [
                "Get a random promise from \(.applicationName)",
                "Show me a Bible promise",
                "I need encouragement",
                "Give me inspiration"
            ],
            shortTitle: "Random Promise",
            systemImageName: "shuffle"
        )
        
        AppShortcut(
            intent: GetFavoritePromiseIntent(),
            phrases: [
                "Get my favorite promise from \(.applicationName)",
                "Show me my favorite promise",
                "Read my favorite Bible verse"
            ],
            shortTitle: "Favorite Promise",
            systemImageName: "heart.fill"
        )
        
        AppShortcut(
            intent: SetPromiseByCategoryIntent(),
            phrases: [
                "Get a promise about faith from \(.applicationName)",
                "Show me a Bible verse about hope",
                "I need encouragement about love"
            ],
            shortTitle: "Promise by Topic",
            systemImageName: "tag.fill"
        )
    }
}