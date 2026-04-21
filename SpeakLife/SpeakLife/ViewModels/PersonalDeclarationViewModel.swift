//
//  PersonalDeclarationViewModel.swift
//  SpeakLife
//

import Foundation
import SwiftUI

enum PersonalDeclarationStep {
    case input                              // mic / text entry
    case focusChoice([DeclarationCategory]) // user named >1 thing — ask them to pick one
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

    func saveAndContinue(startTimeIndex: Int) async throws -> PersonalDeclaration {
        guard let match else { throw PersonalDeclarationError.noMatch }
        return try await saveUseCase.execute(
            beliefText: inputText,
            match: match,
            startTimeIndex: startTimeIndex
        )
    }

    // MARK: - Focus Choice

    /// Called when user taps one of the focus-choice cards.
    func selectFocus(category: DeclarationCategory) async {
        await runMatchForCategory(input: inputText, category: category)
    }

    // MARK: - Private

    private func runMatch(input: String) async {
        // Check if the user named multiple distinct things
        let allMatches = matchUseCase.matchAll(input: input)
        if allMatches.count >= 2 {
            // Pause briefly so it doesn't feel instant
            try? await Task.sleep(nanoseconds: 400_000_000)
            step = .focusChoice(allMatches)
            return
        }
        await runMatchForCategory(input: input, category: nil)
    }

    private func runMatchForCategory(input: String, category: DeclarationCategory?) async {
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
            match = matchUseCase.execute(input: input)
        }
        step = .result
    }
}
