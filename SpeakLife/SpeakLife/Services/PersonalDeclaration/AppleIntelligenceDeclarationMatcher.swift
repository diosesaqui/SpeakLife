//
//  AppleIntelligenceDeclarationMatcher.swift
//  SpeakLife
//
//  Uses Apple's on-device Foundation Models framework (WWDC25, iOS 26+) to
//  generate a personalized declaration and Bible verse from the user's
//  free-form prayer need. Private (nothing leaves the device), instant, and
//  free per call.
//
//  Falls back to ClaudeDeclarationMatcher when:
//    • iOS < 26
//    • Foundation Models framework unavailable at build time
//    • SystemLanguageModel is not currently available at runtime (e.g. model
//      not yet downloaded, low-storage state, user disabled Apple
//      Intelligence in Settings).
//
//  The Claude matcher itself falls back to KeywordDeclarationMatcher when
//  offline or when no API key is configured, giving us three tiers:
//    on-device → cloud → local rules.
//

import Foundation
import FirebaseAnalytics

#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleIntelligenceDeclarationMatcher: DeclarationMatcherProtocol {
    private let cloudFallback: ClaudeDeclarationMatcher
    private let localFallback: KeywordDeclarationMatcher

    init(cloudFallback: ClaudeDeclarationMatcher = ClaudeDeclarationMatcher(),
         localFallback: KeywordDeclarationMatcher = KeywordDeclarationMatcher()) {
        self.cloudFallback = cloudFallback
        self.localFallback = localFallback
    }

    // MARK: - DeclarationMatcherProtocol

    func match(input: String) async -> DeclarationMatch {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let result = await tryOnDevice(input: input) {
                return result
            }
        }
        #endif
        return await cloudFallback.match(input: input)
    }

    /// Multi-topic scan stays on the keyword matcher — no LLM call needed.
    func matchAll(input: String) -> [DeclarationCategory] {
        localFallback.matchAll(input: input)
    }

    // MARK: - On-device path

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func tryOnDevice(input: String) async -> DeclarationMatch? {
        guard SystemLanguageModel.default.isAvailable else {
            print("🍎 [AppleAI] Model unavailable — falling back to cloud")
            Analytics.logEvent("apple_ai_fallback", parameters: ["reason": "model_unavailable"])
            return nil
        }

        do {
            let session = LanguageModelSession(instructions: AnthropicConfig.systemPrompt)
            let response = try await session.respond(
                to: "User need: \(input)",
                generating: OnDeviceDeclaration.self
            )
            let category = DeclarationCategory(rawValue: response.content.category) ?? .faith
            Analytics.logEvent("apple_ai_success", parameters: ["category": category.rawValue])
            print("✅ [AppleAI] Generated declaration for category: \(category.rawValue)")
            return DeclarationMatch(
                category: category,
                declarationText: response.content.declarationText,
                verse: response.content.verseText,
                verseReference: response.content.verseReference,
                isConfident: true
            )
        } catch {
            print("❌ [AppleAI] Error: \(error) — falling back to cloud")
            Analytics.logEvent("apple_ai_fallback", parameters: ["reason": "\(error)"])
            return nil
        }
    }
    #endif
}

// MARK: - Structured output shape

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct OnDeviceDeclaration {
    @Guide(description: "Exact rawValue of the matched DeclarationCategory enum: health, wealth, anxiety, fear, love, relationship, marriage, parenting, destiny, identity, rest, joy, favor, grace, godsprotection, warfare, addiction, confidence, wisdom, innerHealing, spiritualGrowth, miracles, hardtimes, friendship, purity, hope, grief, fertility, salvation, education, housing, divorce, wellness, mentalHealth, forgiveness, newSeason, singleParent, anger, faith, debt, business, work, praise, gratitude")
    let category: String

    @Guide(description: "First-person, present-tense declaration the user will speak aloud. 2-4 short, punchy sentences. Bold and direct. No em dashes or en dashes. Use spiritually rich words like rooted, sealed, commissioned, anchored, redeemed, established, unshakeable, radiant.")
    let declarationText: String

    @Guide(description: "Exact NIV Bible verse text supporting the declaration. Quote the verse verbatim without abbreviation.")
    let verseText: String

    @Guide(description: "Bible reference in 'Book Chapter:Verse' format, e.g. 'Jeremiah 29:11' or 'Romans 8:28'")
    let verseReference: String
}
#endif
