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
                headline: "Become Unshakable — One Declaration at a Time",
                subheadline: "Replace anxiety with God's truth. Every single morning.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Begin My Faith Reset",
                urgencyText: "3 Days Free • Cancel Anytime"
            )

        case .faith:
            return PaywallCopy(
                headline: "Build a Faith Nothing Can Move",
                subheadline: "Daily declarations rooted in God's Word to make you unshakable.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Strengthen Your Faith Today",
                urgencyText: "Start Free & Grow Stronger"
            )

        case .joy:
            return PaywallCopy(
                headline: "Find a Joy the World Cannot Steal",
                subheadline: "God's promises spoken daily build a happiness nothing can shake.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Unlock Your Joy Today",
                urgencyText: "Experience Joy in 3 Days"
            )

        case .rest:
            return PaywallCopy(
                headline: "Rest Like Someone Whose God Never Sleeps",
                subheadline: "Declarations that quiet your mind and anchor your soul at night.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Sleep Peacefully Tonight",
                urgencyText: "Better Sleep Starts Today"
            )

        case .health:
            return PaywallCopy(
                headline: "Speak Life Over Your Body — and Mean It",
                subheadline: "God's Word over your health is the most powerful medicine there is.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Claim Your Healing",
                urgencyText: "Start Your Healing Journey"
            )

        case .confidence:
            return PaywallCopy(
                headline: "Walk Like You Know Who Made You",
                subheadline: "Your identity in God is unshakable — start living like it.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Unlock Bold Confidence",
                urgencyText: "Transform in 3 Days Free"
            )

        case .fear:
            return PaywallCopy(
                headline: "You Were Not Made to Be Afraid",
                subheadline: "God's Word spoken daily dismantles fear at the root.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Overcome Fear Today",
                urgencyText: "Freedom Starts Now"
            )

        case .marriage:
            return PaywallCopy(
                headline: "A Marriage Built on the Word Does Not Break",
                subheadline: "Speak God's promises over your relationship every day.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Bless Your Marriage",
                urgencyText: "Transform Your Marriage"
            )

        case .love:
            return PaywallCopy(
                headline: "Loved by God. Unshakable.",
                subheadline: "When you know how God loves you, nothing else can define you.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Receive Perfect Love",
                urgencyText: "Love Transformation Awaits"
            )

        case .hope:
            return PaywallCopy(
                headline: "Your Future Is Written by God, Not Your Past",
                subheadline: "Daily declarations to reset your mind on what God says is possible.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Reclaim Your Hope",
                urgencyText: "Hope Starts Today"
            )

        case .general:
            return PaywallCopy(
                headline: "Become Unshakable — One Declaration at a Time",
                subheadline: "Join 100,000+ believers who chose God's truth over their feelings.",
                valueProps: [
                    "Replace Every Lie With God's Truth",
                    "Build a Mind Nothing Can Shake",
                    "No More Fear of the Future — God Has a Promise for It",
                    "Become Who God Said You Are",
                    "Pray With 100,000+ Believers"
                ],
                ctaText: "Begin My Faith Reset",
                urgencyText: "3 Days Free • Cancel Anytime"
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
