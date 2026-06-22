//
//  SavePersonalDeclarationUseCase.swift
//  SpeakLife
//

import Foundation

final class SavePersonalDeclarationUseCase {
    private let repository: PersonalDeclarationRepositoryProtocol
    private let notificationService: DeclarationNotificationServiceProtocol

    init(repository: PersonalDeclarationRepositoryProtocol,
         notificationService: DeclarationNotificationServiceProtocol) {
        self.repository = repository
        self.notificationService = notificationService
    }

    func execute(beliefText: String, match: DeclarationMatch, startTimeIndex: Int) async throws -> PersonalDeclaration {
        let declaration = PersonalDeclaration(
            id: UUID(),
            beliefText: beliefText,
            declarationText: match.declarationText,
            verse: match.verse,
            verseReference: match.verseReference,
            categoryRaw: match.category.rawValue,
            startDate: Date()
        )
        // A new declaration starts fresh: clear the previous declaration's
        // spoken-day tracking so "Day N" begins at Day 1 rather than inheriting
        // the prior progress.
        PersonalDeclaration.resetSpeakTracking()
        try await repository.save(declaration)
        notificationService.schedule(for: declaration, startTimeIndex: startTimeIndex)
        return declaration
    }
}
