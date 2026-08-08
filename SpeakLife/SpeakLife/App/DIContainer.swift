//
//  DIContainer.swift
//  SpeakLife
//
//  Single place where concrete types are wired to protocols.
//  Swap implementations here without touching any other file.
//

import Foundation

final class DIContainer {
    static let shared = DIContainer()
    private init() {}

    // MARK: - Personal Declaration

    lazy var declarationMatcher: DeclarationMatcherProtocol = ClaudeDeclarationMatcher()
    lazy var personalDeclarationRepository: PersonalDeclarationRepositoryProtocol = PersonalDeclarationRepository()
    lazy var declarationNotificationService: DeclarationNotificationServiceProtocol = DeclarationNotificationService()
    lazy var speechTranscriptionService: SpeechTranscriptionProtocol = SpeechTranscriptionService()

    @MainActor
    func makePersonalDeclarationViewModel() -> PersonalDeclarationViewModel {
        PersonalDeclarationViewModel(
            matchUseCase: MatchDeclarationUseCase(matcher: declarationMatcher),
            saveUseCase: SavePersonalDeclarationUseCase(
                repository: personalDeclarationRepository,
                notificationService: declarationNotificationService
            ),
            speechService: speechTranscriptionService
        )
    }

    func makeMarkReceivedUseCase() -> MarkDeclarationReceivedUseCase {
        MarkDeclarationReceivedUseCase(
            repository: personalDeclarationRepository,
            notificationService: declarationNotificationService
        )
    }

    func makeDeleteDeclarationUseCase() -> DeletePersonalDeclarationUseCase {
        DeletePersonalDeclarationUseCase(
            repository: personalDeclarationRepository,
            notificationService: declarationNotificationService
        )
    }

    /// Re-schedules the personal declaration daily pushes using the user's current
    /// `startTimeIndex`. Needed because `scheduleAll(_:startTimeIndex:)` only runs at
    /// save time — if the user saved before granting iOS permission, or before our
    /// V3 migration moved their startTimeIndex out of the midnight slot, the push
    /// either never landed or has been firing at the old (stale) time. Idempotent:
    /// if no active declaration exists, this is a no-op.
    func rescheduleActivePersonalDeclarationIfNeeded(startTimeIndex: Int) {
        Task { [personalDeclarationRepository, declarationNotificationService] in
            let active = await personalDeclarationRepository.loadActive()
            guard !active.isEmpty else {
                print("🟡 PD reschedule skipped: no active declarations in repo (never saved, cleared, all received, or decode failed silently)")
                return
            }
            await MainActor.run {
                declarationNotificationService.scheduleAll(active, startTimeIndex: startTimeIndex)
            }
        }
    }
}
