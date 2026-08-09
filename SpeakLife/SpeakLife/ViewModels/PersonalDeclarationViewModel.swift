//
//  PersonalDeclarationViewModel.swift
//  SpeakLife
//

import Foundation
import SwiftUI

enum PersonalDeclarationStep {
    case input                              // mic / text entry
    case focusChoice([DeclarationCategory]) // user named >1 thing — ask them to pick one
    case clarify                            // input too vague — ask for a little more detail
    case matching                           // 1.5s loading — builds anticipation
    case result                             // shows matched verse + declaration
}

enum PersonalDeclarationError: Error {
    case noMatch
    case saveFailed(Error)
}

@MainActor
final class PersonalDeclarationViewModel: ObservableObject {

    // MARK: - State

    @Published var step: PersonalDeclarationStep = .input
    @Published var inputText: String = ""
    @Published var isRecording: Bool = false
    @Published var showTextInput: Bool = false
    @Published var match: DeclarationMatch? = nil
    @Published var errorMessage: String? = nil

    // MARK: - Dependencies (injected — never instantiated inside)

    private let matchUseCase: MatchDeclarationUseCase
    private let saveUseCase: SavePersonalDeclarationUseCase
    private let speechService: SpeechTranscriptionProtocol

    init(matchUseCase: MatchDeclarationUseCase,
         saveUseCase: SavePersonalDeclarationUseCase,
         speechService: SpeechTranscriptionProtocol) {
        self.matchUseCase = matchUseCase
        self.saveUseCase = saveUseCase
        self.speechService = speechService
    }

    // MARK: - Actions

    func startRecording() async {
        let permitted = await speechService.requestPermission()
        guard permitted else {
            showTextInput = true  // graceful fallback if denied
            return
        }
        do {
            try await speechService.startRecording()
            isRecording = true
        } catch {
            showTextInput = true
        }
    }

    func stopRecording() async {
        let transcribed = await speechService.stopRecording()
        isRecording = false
        inputText = transcribed
        do {
            try DeclarationInputValidator.validate(transcribed)
            await runMatch(input: transcribed)
        } catch let error as DeclarationInputError {
            errorMessage = error.prompt
        } catch {
            errorMessage = "We couldn't understand that. Try again."
        }
    }

    func submitTextInput() async {
        do {
            try DeclarationInputValidator.validate(inputText)
            await runMatch(input: inputText)
        } catch let error as DeclarationInputError {
            errorMessage = error.prompt
        } catch {
            errorMessage = "Please tell us more about what you're believing for."
        }
    }

    /// - Parameter limit: how many active declarations the user may carry. The
    ///   entry points gate on this up front, so hitting it here means something
    ///   slipped through and the flow surfaces the error rather than silently
    ///   dropping what they just declared.
    func saveAndContinue(startTimeIndex: Int,
                         limit: Int = PersonalDeclarationLimits.premium) async throws -> PersonalDeclaration {
        guard let match else { throw PersonalDeclarationError.noMatch }
        return try await saveUseCase.execute(
            beliefText: inputText,
            match: match,
            startTimeIndex: startTimeIndex,
            limit: limit
        )
    }

    // MARK: - Focus Choice

    /// Called when user taps one of the focus-choice cards.
    func selectFocus(category: DeclarationCategory) async {
        await runMatchForCategory(input: inputText, category: category)
    }

    // MARK: - Private

    private func runMatch(input: String) async {
        // Keyword scan to detect multiple distinct topics before calling AI
        let allMatches = matchUseCase.matchAll(input: input)
        if allMatches.count >= 2 {
            try? await Task.sleep(nanoseconds: 400_000_000)
            step = .focusChoice(allMatches)
            return
        }
        await runMatchForCategory(input: input, category: nil)
    }

    /// Called when the user submits refined input from the clarify screen.
    func submitClarification() async {
        await runMatchForCategory(input: inputText, category: nil)
    }

    /// The single chokepoint before anything is matched or generated, which is
    /// why the screen lives here rather than at the two entry points: `runMatch`,
    /// `selectFocus`, and `submitClarification` all pass through it.
    ///
    /// This path is the more exposed of the two that take free text. The
    /// campaign only ever *selects* from reviewed declarations; here Claude
    /// **writes** the declaration and picks the verse, so an unscreened request
    /// comes back as original scripture-shaped text endorsing it.
    private func runMatchForCategory(input: String, category: DeclarationCategory?) async {
        switch SituationScreen.screen(input) {
        case .redirect(let redirect):
            AnalyticsService.shared.track("personal_declaration_screened",
                                          parameters: ["verdict": redirect.reason])
            errorMessage = redirect.message
            step = .input
            return
        case .reachOut:
            AnalyticsService.shared.track("personal_declaration_screened",
                                          parameters: ["verdict": "reach_out"])
            errorMessage = "Please don't carry this alone. Reach out to someone you trust right now, before anything else. You are not a burden, and you are not too far gone."
            step = .input
            return
        case .standable:
            break
        }

        step = .matching
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if let category {
            match = DeclarationMatch(
                category: category,
                declarationText: DeclarationContent.declaration(for: category),
                verse: DeclarationContent.verse(for: category),
                verseReference: DeclarationContent.verseReference(for: category),
                isConfident: true
            )
        } else {
            match = await matchUseCase.execute(input: input)
        }
        step = .result
    }
}
