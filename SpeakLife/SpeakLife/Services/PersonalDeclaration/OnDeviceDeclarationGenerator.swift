//
//  OnDeviceDeclarationGenerator.swift
//  SpeakLife
//
//  "Declaration of the Moment" — generates a fresh, personalized declaration
//  on-device whenever the user asks (e.g. mid-day prayer, post to the Warrior
//  Room). Unlike the onboarding matcher, these declarations are not
//  persisted, not notified, and not de-duplicated. Pure ephemeral generation.
//
//  Distinction from AppleIntelligenceDeclarationMatcher: that one returns
//  the full DeclarationMatch object used by the onboarding pipeline. This
//  one streams partial output for UX (typewriter effect) and is meant to be
//  consumed by transient sheets.
//

import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// What the UI receives. Identical shape to DeclarationMatch but without
/// the `category` (categories are an onboarding-pipeline concept).
struct MomentDeclaration: Equatable {
    let declarationText: String
    let verseText: String
    let verseReference: String
}

enum MomentGenerationError: Error, LocalizedError {
    case unavailable
    case modelFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "On-device generation needs iOS 26 with Apple Intelligence enabled."
        case .modelFailed(let reason):
            return "Couldn't generate a declaration. \(reason)"
        }
    }
}

protocol OnDeviceDeclarationGeneratorProtocol {
    /// True when the on-device model is reachable on this device, right now.
    var isAvailable: Bool { get }

    /// One-shot generation. Returns the full declaration when the model
    /// finishes. Throws `MomentGenerationError.unavailable` if the model
    /// can't be reached at all.
    func generate(from input: String) async throws -> MomentDeclaration

    /// Streaming generation. Yields partial values as the model produces
    /// them — every yield is a snapshot of the structured output with the
    /// fields filled in so far. Final yield is the complete value.
    func stream(from input: String) -> AsyncThrowingStream<MomentDeclaration, Error>
}

final class OnDeviceDeclarationGenerator: OnDeviceDeclarationGeneratorProtocol {

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    func generate(from input: String) async throws -> MomentDeclaration {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                throw MomentGenerationError.unavailable
            }
            do {
                let session = LanguageModelSession(instructions: AnthropicConfig.systemPrompt)
                let response = try await session.respond(
                    to: "User need: \(input)",
                    generating: OnDeviceDeclaration.self
                )
                return MomentDeclaration(
                    declarationText: response.content.declarationText,
                    verseText: response.content.verseText,
                    verseReference: response.content.verseReference
                )
            } catch {
                throw MomentGenerationError.modelFailed(error.localizedDescription)
            }
        }
        #endif
        throw MomentGenerationError.unavailable
    }

    func stream(from input: String) -> AsyncThrowingStream<MomentDeclaration, Error> {
        // Wraps the non-streaming respond(...) and emits a single final value.
        // The released Foundation Models SDK exposes streaming partials via a
        // `Snapshot` wrapper whose field-access pattern we haven't yet
        // confirmed against a working build; rather than guess, ship the
        // one-shot path and revisit streaming as a follow-up enhancement.
        let (stream, continuation) = AsyncThrowingStream<MomentDeclaration, Error>.makeStream()
        Task {
            do {
                let result = try await self.generate(from: input)
                continuation.yield(result)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        return stream
    }
}
