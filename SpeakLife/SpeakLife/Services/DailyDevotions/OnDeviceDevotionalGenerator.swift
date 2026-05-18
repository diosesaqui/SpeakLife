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
                print("📖 [AIDevotional] Model unavailable for category=\(category.rawValue)")
                throw MomentGenerationError.unavailable
            }
            print("📖 [AIDevotional] Generating for category=\(category.rawValue)")
            let start = Date()
            do {
                let session = LanguageModelSession(instructions: Self.systemPrompt)
                let response = try await session.respond(
                    to: "Category: \(category.label). Write today's devotional.",
                    generating: GeneratedDevotional.self
                )
                let elapsed = Date().timeIntervalSince(start)
                print("📖 [AIDevotional] ✅ Generated in \(String(format: "%.1f", elapsed))s — title='\(response.content.title)'")
                return Self.makeDevotional(from: response.content)
            } catch {
                let elapsed = Date().timeIntervalSince(start)
                print("📖 [AIDevotional] ❌ Failed after \(String(format: "%.1f", elapsed))s: \(error)")
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
    Write a short Christian devotional for the SpeakLife app.

    title: 4-7 words, evocative.
    scriptureLine: One NIV Bible verse, format: "Verse text. – Book Chapter:Verse"
    body: 3 paragraphs separated by \\n\\n. 150-220 words total.
      - Paragraph 1: a theological hook naming the truth.
      - Paragraph 2: apply it to the reader using "you". Pastoral, certain, weighty.
      - Paragraph 3: a one-sentence prayer ending "Amen. 💜"

    Voice: pastoral, weighty, no clichés. Write TO the reader, not as them.
    """

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func makeDevotional(from generated: GeneratedDevotional) -> Devotional {
        makeDevotional(
            title: generated.title,
            books: generated.scriptureLine,
            devotionalText: generated.body
        )
    }
    #endif

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
    @Guide(description: "Title, 4-7 words. Example: 'The Banner Over Me Is Love'")
    let title: String

    @Guide(description: "NIV verse formatted as 'Verse text. - Book Chapter:Verse'")
    let scriptureLine: String

    @Guide(description: "3 paragraphs separated by double newlines, 150-220 words. Last paragraph is a one-sentence prayer ending 'Amen. 💜'")
    let body: String
}
#endif
