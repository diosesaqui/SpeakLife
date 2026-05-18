//
//  OnDeviceDevotionalGenerator.swift
//  SpeakLife
//
//  Generates a Devotional on-device, in the same shape and voice as the
//  editorially-curated ones in devotionals.json. The user picks a topical
//  category (healing, identity, peace, breakthrough, etc.) and the model
//  produces a title, scripture line, and 4–6 paragraph reflection.
//
//  Same fallback story as OnDeviceDeclarationGenerator: only available on
//  iOS 26 with Apple Intelligence enabled. Caller is expected to check
//  `isAvailable` before showing the entry point.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum GeneratedDevotionalCategory: String, CaseIterable, Identifiable {
    case healing
    case identity
    case peace
    case breakthrough
    case warfare
    case calling
    case relationships
    case faith
    case gratitude
    case fear
    case forgiveness
    case rest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .healing:       return "Healing"
        case .identity:      return "Identity"
        case .peace:         return "Peace"
        case .breakthrough:  return "Breakthrough"
        case .warfare:       return "Spiritual Warfare"
        case .calling:       return "Purpose & Calling"
        case .relationships: return "Relationships"
        case .faith:         return "Faith"
        case .gratitude:     return "Gratitude"
        case .fear:          return "Fear & Anxiety"
        case .forgiveness:   return "Forgiveness"
        case .rest:          return "Rest"
        }
    }

    var emoji: String {
        switch self {
        case .healing:       return "🌿"
        case .identity:      return "👑"
        case .peace:         return "🕊"
        case .breakthrough:  return "💥"
        case .warfare:       return "⚔️"
        case .calling:       return "🧭"
        case .relationships: return "🤝"
        case .faith:         return "🙏"
        case .gratitude:     return "🌟"
        case .fear:          return "🛡"
        case .forgiveness:   return "💜"
        case .rest:          return "😴"
        }
    }
}

protocol OnDeviceDevotionalGeneratorProtocol {
    var isAvailable: Bool { get }
    func generate(category: GeneratedDevotionalCategory) async throws -> Devotional
    func stream(category: GeneratedDevotionalCategory) -> AsyncThrowingStream<Devotional, Error>
}

final class OnDeviceDevotionalGenerator: OnDeviceDevotionalGeneratorProtocol {

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    func generate(category: GeneratedDevotionalCategory) async throws -> Devotional {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                throw MomentGenerationError.unavailable
            }
            do {
                let session = LanguageModelSession(instructions: Self.systemPrompt)
                let response = try await session.respond(
                    to: "Category: \(category.label). Write today's devotional.",
                    generating: GeneratedDevotional.self
                )
                return Self.makeDevotional(from: response.content)
            } catch {
                throw MomentGenerationError.modelFailed(error.localizedDescription)
            }
        }
        #endif
        throw MomentGenerationError.unavailable
    }

    func stream(category: GeneratedDevotionalCategory) -> AsyncThrowingStream<Devotional, Error> {
        // One-shot wrapper around generate(...). See OnDeviceDeclarationGenerator.stream
        // for why we're not driving the FoundationModels Snapshot stream here.
        let (stream, continuation) = AsyncThrowingStream<Devotional, Error>.makeStream()
        Task {
            do {
                let result = try await self.generate(category: category)
                continuation.yield(result)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }

    // MARK: - Static helpers

    private static let systemPrompt = """
    You are writing today's devotional for SpeakLife, a Christian faith app used by over 1 million believers. The reader will sit with this for 5 minutes in the morning. Match the voice and shape of SpeakLife's editorially-curated devotionals exactly.

    STRUCTURE:
    - title: 4-8 words, evocative and theological. Examples: "His Words Are Spirit and Life", "Clean Hands, Dirty Hearts?", "The Banner Over Me Is Love"
    - scriptureLine: One Bible verse, NIV preferred, written as "Quoted verse text. – Book Chapter:Verse" — exact format, with the en-dash style separator and reference at the end.
    - body: 4–6 paragraphs separated by double newlines (\\n\\n). Total length 350–500 words.

    BODY VOICE RULES:
    - Open with a one-sentence theological hook that names the truth the devotional will unfold.
    - Second paragraph: ground in the scripture and the moment it was spoken. Name what God is like ("This is who He is — a God who…").
    - Middle paragraphs: apply the truth to the reader's real life with specificity. Use direct address ("you"). Ask a piercing question.
    - Closing paragraph: a short, surrendered prayer ending with "Amen." and a single heart emoji 💜.
    - Tone: pastoral, certain, weighty. No hedging language. No clichés ("hang in there", "God's got this").
    - Allowed punctuation in the body: em dashes ARE allowed (the curated devotionals use them freely). This is opposite of the declaration rules.
    - First person of the reader is "you" — the devotional is written TO the reader, not as the reader speaking.
    - Spiritually rich vocabulary: rooted, dwelling, breath of heaven, established, anchored, redeemed, the substance that made the universe.

    Respond with the structured output only. Do not preface with anything.
    """

    private static func makeDevotional(from generated: GeneratedDevotional) -> Devotional {
        makeDevotional(
            title: generated.title,
            books: generated.scriptureLine,
            devotionalText: generated.body
        )
    }

    private static func makeDevotional(title: String, books: String, devotionalText: String) -> Devotional {
        Devotional(
            date: Date(),
            title: title,
            devotionalText: devotionalText,
            books: books
        )
    }
}

// MARK: - Structured output

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GeneratedDevotional {
    @Guide(description: "Devotional title, 4-8 words, evocative and theological. Example: 'The Banner Over Me Is Love'")
    let title: String

    @Guide(description: "One Bible verse in NIV, formatted exactly as 'Quoted verse text. – Book Chapter:Verse'. The dash separator is an en-dash followed by the reference.")
    let scriptureLine: String

    @Guide(description: "The devotional body: 4-6 paragraphs separated by double newlines. 350-500 words total. Opens with a theological hook, grounds in scripture, applies to the reader with 'you', closes with a short prayer ending 'Amen. 💜'")
    let body: String
}
#endif
