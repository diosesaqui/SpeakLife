//
//  MarkDeclarationReceivedUseCase.swift
//  SpeakLife
//

import Foundation

final class MarkDeclarationReceivedUseCase {
    private let repository: PersonalDeclarationRepositoryProtocol
    private let notificationService: DeclarationNotificationServiceProtocol

    init(repository: PersonalDeclarationRepositoryProtocol,
         notificationService: DeclarationNotificationServiceProtocol) {
        self.repository = repository
        self.notificationService = notificationService
    }

    func execute(id: UUID, testimony: String?) async throws {
        try await repository.markReceived(id: id, testimony: testimony)
        notificationService.cancel()
    }
}
