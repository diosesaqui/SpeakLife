//
//  SavePersonalDeclarationUseCase.swift
//  SpeakLife
//

import Foundation

enum PersonalDeclarationLimitError: LocalizedError {
    case limitReached(max: Int)

    var errorDescription: String? {
        switch self {
        case .limitReached(let max):
            return "You can believe for \(max) things at a time. Mark one as answered to add another."
        }
    }
}

final class SavePersonalDeclarationUseCase {
    private let repository: PersonalDeclarationRepositoryProtocol
    private let notificationService: DeclarationNotificationServiceProtocol

    init(repository: PersonalDeclarationRepositoryProtocol,
         notificationService: DeclarationNotificationServiceProtocol) {
        self.repository = repository
        self.notificationService = notificationService
    }

    /// Adds a new declaration alongside any the user is already believing for.
    /// - Parameter limit: how many active declarations this user may carry.
    ///   Enforced here as a backstop; entry points gate on it up front so the
    ///   user sees the paywall instead of an error.
    func execute(beliefText: String,
                 match: DeclarationMatch,
                 startTimeIndex: Int,
                 limit: Int = PersonalDeclarationLimits.premium) async throws -> PersonalDeclaration {
        let active = await repository.loadActive()
        guard active.count < limit else {
            throw PersonalDeclarationLimitError.limitReached(max: limit)
        }

        let declaration = PersonalDeclaration(
            id: UUID(),
            beliefText: beliefText,
            declarationText: match.declarationText,
            verse: match.verse,
            verseReference: match.verseReference,
            categoryRaw: match.category.rawValue,
            startDate: Date()
        )
        // Speak counters live on the record, so a new declaration always starts
        // at Day 1 without any global state to clear.
        try await repository.save(declaration)

        // Reschedule the whole set: each declaration's reminder time depends on
        // its position, so adding one shifts nothing but must place the new one.
        let updated = await repository.loadActive()
        notificationService.scheduleAll(updated, startTimeIndex: startTimeIndex)
        return declaration
    }
}
