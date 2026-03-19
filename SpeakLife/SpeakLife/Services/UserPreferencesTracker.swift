//
//  UserPreferencesTracker.swift
//  SpeakLife
//
//  Tracks user preferences and category selections for personalization
//

import Foundation
import SwiftUI

final class UserPreferencesTracker: ObservableObject {
    static let shared = UserPreferencesTracker()

    @AppStorage("userTopCategories") private var topCategoriesData: String = ""
    @AppStorage("lastCategorySelected") private var lastCategorySelected: String = ""
    @Published var topCategories: [CategoryPreference] = []
    @Published var primaryCategory: CategoryType = .general

    private init() {
        loadTopCategories()
    }

    enum CategoryType: String, CaseIterable {
        case anxiety = "anxiety"
        case faith = "faith"
        case joy = "joy"
        case rest = "rest"
        case health = "health"
        case confidence = "confidence"
        case fear = "fear"
        case marriage = "marriage"
        case love = "love"
        case hope = "hope"
        case general = "general"

        var displayName: String {
            switch self {
            case .anxiety: return "Anxiety"
            case .faith: return "Faith"
            case .joy: return "Joy"
            case .rest: return "Rest"
            case .health: return "Health"
            case .confidence: return "Confidence"
            case .fear: return "Fear"
            case .marriage: return "Marriage"
            case .love: return "Love"
            case .hope: return "Hope"
            case .general: return "General"
            }
        }
    }

    struct CategoryPreference: Codable {
        let category: String
        var count: Int
        var lastSelected: Date
    }

    struct PaywallCopy {
        let headline: String
        let subheadline: String
        let valueProps: [String]
        let ctaText: String
        let urgencyText: String?
    }

    func trackCategorySelection(_ categoryName: String) {
        lastCategorySelected = categoryName.lowercased()

        // Update category count
        var categories = topCategories
        if let index = categories.firstIndex(where: { $0.category == categoryName.lowercased() }) {
            categories[index].count += 1
            categories[index].lastSelected = Date()
        } else {
            categories.append(CategoryPreference(
                category: categoryName.lowercased(),
                count: 1,
                lastSelected: Date()
            ))
        }

        // Sort by count and keep top 5
        categories.sort { $0.count > $1.count }
        topCategories = Array(categories.prefix(5))

        // Update primary category
        if let topCategory = topCategories.first,
           let categoryType = CategoryType(rawValue: topCategory.category) {
            primaryCategory = categoryType
        }

        saveTopCategories()
    }

    func getDynamicPaywallCopy() -> PaywallCopy {
        switch primaryCategory {
        case .anxiety:
            return PaywallCopy(
                headline: "If anxiety hits first - your words can change that",
                subheadline: "Daily declarations to speak peace over your morning",
                valueProps: [
                    "Wake up calm with anxiety-specific declarations",
                    "God's peace in 2 minutes - morning and night",
                    "Retrain your thoughts with Scripture daily",
                    "Built for people who wake up already overwhelmed"
                ],
                ctaText: "Start My Free 7-Day Trial",
                urgencyText: "7 Days Free • Cancel Anytime"
            )

        case .faith:
            return PaywallCopy(
                headline: "Deepen Your Faith, Transform Your Life",
                subheadline: "Build an unshakeable foundation with daily spiritual practices",
                valueProps: [
                    "Scripture-powered declarations",
                    "Faith-building audio series",
                    "Daily devotionals & prayers",
                    "Spiritual growth tracking"
                ],
                ctaText: "Strengthen Your Faith Today",
                urgencyText: "Start Free & Grow Stronger"
            )

        case .joy:
            return PaywallCopy(
                headline: "Rediscover True Joy Through Faith",
                subheadline: "Cultivate lasting happiness grounded in God's love",
                valueProps: [
                    "Joy activation morning routines",
                    "Gratitude-focused declarations",
                    "Happiness breakthrough audio",
                    "Daily encouragement & hope"
                ],
                ctaText: "Unlock Your Joy Today",
                urgencyText: "Experience Joy in 3 Days"
            )

        case .rest:
            return PaywallCopy(
                headline: "Find Deep Rest in God's Peace",
                subheadline: "End restless nights with faith-based sleep solutions",
                valueProps: [
                    "Bedtime peace declarations",
                    "Sleep meditation prayers",
                    "Calming nighttime audio",
                    "Rest & restoration toolkit"
                ],
                ctaText: "Sleep Peacefully Tonight",
                urgencyText: "Better Sleep Starts Today"
            )

        case .health:
            return PaywallCopy(
                headline: "Heal Your Body, Mind & Spirit",
                subheadline: "Activate divine health through daily declarations",
                valueProps: [
                    "Healing scripture declarations",
                    "Wellness prayer library",
                    "Mind-body-spirit alignment",
                    "Health breakthrough audio"
                ],
                ctaText: "Claim Your Healing",
                urgencyText: "Start Your Healing Journey"
            )

        case .confidence:
            return PaywallCopy(
                headline: "Build Unshakeable God-Confidence",
                subheadline: "Discover your true identity and worth in Christ",
                valueProps: [
                    "Identity-affirming declarations",
                    "Confidence-building audio",
                    "Fear-conquering prayers",
                    "Daily courage activation"
                ],
                ctaText: "Unlock Bold Confidence",
                urgencyText: "Transform in 3 Days Free"
            )

        case .fear:
            return PaywallCopy(
                headline: "Conquer Fear with Faith",
                subheadline: "Replace fear with courage through God's promises",
                valueProps: [
                    "Fear-breaking declarations",
                    "Courage-building prayers",
                    "Anxiety-defeating audio",
                    "Daily strength activation"
                ],
                ctaText: "Overcome Fear Today",
                urgencyText: "Freedom Starts Now"
            )

        case .marriage:
            return PaywallCopy(
                headline: "Strengthen Your Marriage with Faith",
                subheadline: "Build a God-centered relationship that thrives",
                valueProps: [
                    "Marriage blessing declarations",
                    "Couples prayer guides",
                    "Relationship healing audio",
                    "Love & unity exercises"
                ],
                ctaText: "Bless Your Marriage",
                urgencyText: "Transform Your Marriage"
            )

        case .love:
            return PaywallCopy(
                headline: "Experience God's Perfect Love",
                subheadline: "Open your heart to receive and give divine love",
                valueProps: [
                    "Love-affirming declarations",
                    "Self-love in Christ audio",
                    "Relationship prayers",
                    "Heart-healing meditations"
                ],
                ctaText: "Receive Perfect Love",
                urgencyText: "Love Transformation Awaits"
            )

        case .hope:
            return PaywallCopy(
                headline: "Restore Hope, Renew Purpose",
                subheadline: "Find renewed hope and direction in God's plan",
                valueProps: [
                    "Hope-building declarations",
                    "Purpose discovery prayers",
                    "Future-focused audio",
                    "Daily encouragement"
                ],
                ctaText: "Reclaim Your Hope",
                urgencyText: "Hope Starts Today"
            )

        case .general:
            return PaywallCopy(
                headline: "Start Your Morning with Peace, Not Anxiety",
                subheadline: "Join 100,000+ believers who took their peace back",
                valueProps: [
                    "Wake up calm — declarations that quiet morning anxiety",
                    "God's peace in 2 minutes, morning or night",
                    "Retrain your mind to respond instead of react",
                    "Daily Scripture that speaks to what you're feeling"
                ],
                ctaText: "Start My Free 7-Day Trial",
                urgencyText: "7 Days Free • Cancel Anytime"
            )
        }
    }

    func getSecondaryValueProps() -> [String] {
        // Additional value props based on top 3 categories
        var props: Set<String> = []

        for category in topCategories.prefix(3) {
            if let categoryType = CategoryType(rawValue: category.category) {
                switch categoryType {
                case .anxiety:
                    props.insert("Proven anxiety relief techniques")
                case .faith:
                    props.insert("Deeper spiritual connection")
                case .joy:
                    props.insert("Daily joy practices")
                case .rest:
                    props.insert("Better sleep guaranteed")
                case .health:
                    props.insert("Holistic wellness approach")
                case .confidence:
                    props.insert("Confidence coaching included")
                case .fear:
                    props.insert("Fear-free living guide")
                case .marriage:
                    props.insert("Relationship strengthening")
                case .love:
                    props.insert("Love language activation")
                case .hope:
                    props.insert("Hope restoration toolkit")
                default:
                    break
                }
            }
        }

        return Array(props.prefix(2))
    }

    private func loadTopCategories() {
        guard !topCategoriesData.isEmpty,
              let data = topCategoriesData.data(using: .utf8),
              let categories = try? JSONDecoder().decode([CategoryPreference].self, from: data) else {
            return
        }
        topCategories = categories

        if let topCategory = categories.first,
           let categoryType = CategoryType(rawValue: topCategory.category) {
            primaryCategory = categoryType
        }
    }

    private func saveTopCategories() {
        guard let data = try? JSONEncoder().encode(topCategories),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        topCategoriesData = string
    }
}
