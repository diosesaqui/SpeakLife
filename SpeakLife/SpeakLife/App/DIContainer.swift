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

    // MARK: - Weekly Focus

    /// Last 12 weeks under `weekly_focus_history_v1`, synced by SyncedSettingsStore.
    lazy var weeklyFocusRepository: WeeklyFocusRepositoryProtocol = WeeklyFocusRepository()

    lazy var weeklyCheckInScheduler: WeeklyCheckInSchedulerProtocol = WeeklyCheckInScheduler()

    /// Deliberately `KeywordDeclarationMatcher`, not `declarationMatcher` above.
    /// The whole premise of Weekly Focus Phase 1 is that a week costs zero LLM
    /// calls, so the answer rate can be measured before any generation spend —
    /// wiring the Claude-backed matcher here would quietly put a network call
    /// (and a bill) behind every Sunday for every user, answered or not.
    /// Phase 2 moves selection behind the `/weeklyFocus` Cloud Function; this
    /// is the line that changes then.
    lazy var weeklyFocusBuilder: WeeklyFocusBuilderProtocol = WeeklyFocusBuilder(
        repository: weeklyFocusRepository,
        personalDeclarationRepository: personalDeclarationRepository,
        soulProfileRepository: soulProfileRepository,
        matcher: KeywordDeclarationMatcher(),
        declarationProvider: LocalDeclarationProvider()
    )

    func makeBuildWeeklyFocusUseCase() -> BuildWeeklyFocusUseCase {
        BuildWeeklyFocusUseCase(
            repository: weeklyFocusRepository,
            builder: weeklyFocusBuilder,
            scheduler: weeklyCheckInScheduler
        )
    }

    @MainActor
    func makeWeeklyFocusViewModel() -> WeeklyFocusViewModel {
        WeeklyFocusViewModel(
            repository: weeklyFocusRepository,
            buildUseCase: makeBuildWeeklyFocusUseCase(),
            answerUseCase: AnswerWeeklyFocusUseCase(
                repository: weeklyFocusRepository,
                builder: weeklyFocusBuilder,
                scheduler: weeklyCheckInScheduler
            ),
            completeDayUseCase: CompleteWeeklyDayUseCase(repository: weeklyFocusRepository),
            // Keyword matching again, for the same reason: the free tier's echo
            // (one verse + one declaration) has to cost nothing, or a free user
            // who answers every Sunday and never converts stops being free.
            matchUseCase: MatchDeclarationUseCase(matcher: KeywordDeclarationMatcher()),
            speechService: speechTranscriptionService
        )
    }

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
