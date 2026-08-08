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

    // MARK: - Soul Profile

    /// Everything onboarding learns, persisted once at completion.
    /// UserDefaults-backed with a fire-and-forget Firestore mirror.
    lazy var soulProfileRepository: SoulProfileRepositoryProtocol = SoulProfileRepository()

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

    /// Re-schedules the personal declaration daily push using the user's current
    /// `startTimeIndex`. Needed because `schedule(for:startTimeIndex:)` only runs at
    /// save time — if the user saved before granting iOS permission, or before our
    /// V3 migration moved their startTimeIndex out of the midnight slot, the push
    /// either never landed or has been firing at the old (stale) time. Idempotent:
    /// if no active declaration exists, this is a no-op.
    func rescheduleActivePersonalDeclarationIfNeeded(startTimeIndex: Int) {
        Task { [personalDeclarationRepository, declarationNotificationService] in
            guard let active = await personalDeclarationRepository.load() else {
                print("🟡 PD reschedule skipped: no declaration in repo (load returned nil — either never saved, cleared, or decode failed silently)")
                return
            }
            guard !active.isReceived else {
                print("🟡 PD reschedule skipped: declaration marked received on \(active.receivedDate.map(String.init(describing:)) ?? "?")")
                return
            }
            await MainActor.run {
                declarationNotificationService.schedule(for: active, startTimeIndex: startTimeIndex)
            }
        }
    }
}
