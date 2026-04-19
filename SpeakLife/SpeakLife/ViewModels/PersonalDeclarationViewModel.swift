//
//  PersonalDeclarationViewModel.swift
//  SpeakLife
//

import Foundation
import SwiftUI

enum PersonalDeclarationStep {
    case input      // mic / text entry
    case matching   // 1.5s loading — builds anticipation
    case result     // shows matched verse + declaration
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
        await runMatch(input: transcribed)
    }

    func submitTextInput() async {
        await runMatch(input: inputText)
    }

    func saveAndContinue(startTimeIndex: Int) async throws -> PersonalDeclaration {
        guard let match else { throw PersonalDeclarationError.noMatch }
        return try await saveUseCase.execute(
            beliefText: inputText,
            match: match,
            startTimeIndex: startTimeIndex
        )
    }

    // MARK: - Private

    private func runMatch(input: String) async {
        step = .matching
        // Brief intentional pause — builds anticipation, feels more personal
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        match = matchUseCase.execute(input: input)
        step = .result
    }
}
