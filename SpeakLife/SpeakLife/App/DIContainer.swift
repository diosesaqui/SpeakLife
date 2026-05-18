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

    /// Cloud Anthropic matcher with a keyword-rule fallback baked in.
    /// (AppleIntelligenceDeclarationMatcher exists in the tree but produced
    /// low-quality output for SpeakLife's voice; keeping the cloud path
    /// active until on-device generation is good enough to take back over.)
    lazy var declarationMatcher: DeclarationMatcherProtocol = ClaudeDeclarationMatcher()
    lazy var personalDeclarationRepository: PersonalDeclarationRepositoryProtocol = PersonalDeclarationRepository()
    lazy var declarationNotificationService: DeclarationNotificationServiceProtocol = DeclarationNotificationService()
    lazy var speechTranscriptionService: SpeechTranscriptionProtocol = SpeechTranscriptionService()

    /// Cloud-backed generators powering the "Declaration of the Moment"
    /// sheet and the AI devotional category sheet. Class names retain
    /// the "OnDevice" prefix for historical reasons — implementations
    /// now call the same Anthropic API used by ClaudeDeclarationMatcher.
    lazy var momentDeclarationGenerator: OnDeviceDeclarationGeneratorProtocol = OnDeviceDeclarationGenerator()
    lazy var categoryDevotionalGenerator: OnDeviceDevotionalGeneratorProtocol = OnDeviceDevotionalGenerator()

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
