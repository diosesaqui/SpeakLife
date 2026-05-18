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

        let start = Date()
        do {
            // permissiveContentTransformations relaxes the default on-device
            // safety filter which can reject scripture-heavy content.
            let session = LanguageModelSession(
                guardrails: .permissiveContentTransformations,
                instructions: Self.onDeviceSystemPrompt
            )
            let response = try await session.respond(
                to: "Need: \(input)",
                generating: OnDeviceDeclaration.self
            )
            let elapsed = Date().timeIntervalSince(start)
            let category = DeclarationCategory(rawValue: response.content.category) ?? .faith
            Analytics.logEvent("apple_ai_success", parameters: ["category": category.rawValue])
            print("✅ [AppleAI] Generated in \(String(format: "%.1f", elapsed))s, category: \(category.rawValue)")
            return DeclarationMatch(
                category: category,
                declarationText: response.content.declarationText,
                verse: response.content.verseText,
                verseReference: response.content.verseReference,
                isConfident: true
            )
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            print("❌ [AppleAI] Error after \(String(format: "%.1f", elapsed))s: \(error) — falling back to cloud")
            Analytics.logEvent("apple_ai_fallback", parameters: ["reason": "\(error)"])
            return nil
        }
    }
    #endif

    // Compact on-device prompt. The cloud Anthropic prompt is too long for
    // Apple's on-device model — it returns malformed output or hangs.
    fileprivate static let onDeviceSystemPrompt = """
    Match the user's stated need to a Christian declaration.

    declarationText: 2-3 short sentences. First person ("I am", "I have", "I walk"). Present tense. Bold and direct. No em dashes — use periods.
    verseText: One NIV Bible verse supporting it.
    verseReference: Book Chapter:Verse (e.g. "Romans 8:28").
    category: one lowercase word from this list — health, wealth, anxiety, fear, love, marriage, parenting, destiny, identity, rest, joy, favor, grace, warfare, addiction, confidence, wisdom, miracles, hope, grief, salvation, forgiveness, anger, faith, debt, work, gratitude.

    Voice: weighty, certain. Words like rooted, anchored, redeemed, established, unshakeable, called.
    """
}

// MARK: - Structured output shape

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct OnDeviceDeclaration {
    @Guide(description: "One lowercase word: health, wealth, anxiety, fear, love, marriage, parenting, destiny, identity, rest, joy, favor, grace, warfare, addiction, confidence, wisdom, miracles, hope, grief, salvation, forgiveness, anger, faith, debt, work, gratitude")
    let category: String

    @Guide(description: "First-person present-tense declaration, 2-3 short sentences. No em dashes.")
    let declarationText: String

    @Guide(description: "NIV Bible verse text, quoted verbatim.")
    let verseText: String

    @Guide(description: "Bible reference: 'Book Chapter:Verse', e.g. 'Romans 8:28'")
    let verseReference: String
}
#endif
