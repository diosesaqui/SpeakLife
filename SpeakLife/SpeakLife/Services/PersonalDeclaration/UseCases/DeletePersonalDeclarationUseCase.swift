//
//  DeletePersonalDeclarationUseCase.swift
//  SpeakLife
//
//  Removing a declaration is not the same as marking it received: nothing came
//  to pass, the user simply isn't carrying it any more. No testimony, no
//  celebration — just drop it and re-slot the remaining reminders.
//

import Foundation

final class DeletePersonalDeclarationUseCase {
    private let repository: PersonalDeclarationRepositoryProtocol
    private let notificationService: DeclarationNotificationServiceProtocol

    init(repository: PersonalDeclarationRepositoryProtocol,
         notificationService: DeclarationNotificationServiceProtocol) {
        self.repository = repository
        self.notificationService = notificationService
    }

    /// - Returns: the declarations the user is still believing for.
    @discardableResult
    func execute(id: UUID, startTimeIndex: Int) async throws -> [PersonalDeclaration] {
        try await repository.delete(id: id)
        notificationService.cancel(id: id)

        let remaining = await repository.loadActive()
        if remaining.isEmpty {
            notificationService.cancelAll()
        } else {
            notificationService.scheduleAll(remaining, startTimeIndex: startTimeIndex)
        }
        return remaining
    }
}
