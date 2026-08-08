//
//  WeeklyFocusRepository.swift
//  SpeakLife
//
//  UserDefaults-backed, same shape as PersonalDeclarationRepository and
//  SoulProfileRepository — protocol-isolated so the storage can be swapped in
//  DIContainer without touching a caller.
//
//  One deliberate difference: this holds an ARRAY of the last 12 weeks under a
//  single key rather than one record. `weekly_focus_history_v1` is synced by
//  SyncedSettingsStore, so a second device meets the user mid-week rather than
//  as a stranger.
//

import Foundation

final class WeeklyFocusRepository: WeeklyFocusRepositoryProtocol {

    static let storageKey = WeeklyFocus.storageKey
    private let key = WeeklyFocusRepository.storageKey
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Synchronous accessors
    //
    // For main-thread callers that can't await `current()`. The audio filter
    // order is built inside a synchronous pass, same reason
    // `PersonalDeclarationRepository.activeCategoryRaw()` exists.

    /// Every stored week, newest first. Returns [] when nothing is saved or the
    /// blob no longer decodes — a week is always rebuildable, so a failed
    /// decode is a rebuild, never an error the user sees.
    static func loadAllSync(defaults: UserDefaults = .standard) -> [WeeklyFocus] {
        guard let data = defaults.data(forKey: storageKey),
              let history = try? JSONDecoder().decode([WeeklyFocus].self, from: data)
        else { return [] }
        return history.sorted { $0.weekStart > $1.weekStart }
    }

    /// The record for the week containing `date`, decoded synchronously.
    static func currentSync(at date: Date = Date(), defaults: UserDefaults = .standard) -> WeeklyFocus? {
        loadAllSync(defaults: defaults).first { WeeklyFocus.isSameWeek($0.weekStart, date) }
    }

    /// `audioCategoryRaw` of the current week, for the audio filter ordering.
    /// Nil when this week has not been built yet.
    static func activeAudioCategoryRaw(defaults: UserDefaults = .standard) -> String? {
        guard let raw = currentSync(defaults: defaults)?.audioCategoryRaw,
              !raw.isEmpty else { return nil }
        return raw
    }

    // MARK: - WeeklyFocusRepositoryProtocol

    func save(_ focus: WeeklyFocus) async throws {
        var history = WeeklyFocusRepository.loadAllSync(defaults: defaults)
        // Upsert by week, not by id: a rebuild for the same Sunday replaces the
        // provisional week rather than stacking a second record the reader
        // would then have to disambiguate.
        history.removeAll { $0.weekStart == focus.weekStart }
        history.append(focus)
        history.sort { $0.weekStart > $1.weekStart }
        let trimmed = Array(history.prefix(WeeklyFocus.historyLimit))
        let data = try JSONEncoder().encode(trimmed)
        defaults.set(data, forKey: key)
    }

    func current() async -> WeeklyFocus? {
        WeeklyFocusRepository.currentSync(defaults: defaults)
    }

    func history(limit: Int) async -> [WeeklyFocus] {
        guard limit > 0 else { return [] }
        return Array(WeeklyFocusRepository.loadAllSync(defaults: defaults).prefix(limit))
    }

    /// The most recent week BEFORE the one containing `date`. The carry-over
    /// rung of the ladder reads this — it must never see the provisional week
    /// it is being asked to build.
    func previousWeek(before date: Date = Date()) async -> WeeklyFocus? {
        let weekStart = WeeklyFocus.weekStart(containing: date)
        return WeeklyFocusRepository.loadAllSync(defaults: defaults)
            .first { $0.weekStart < weekStart }
    }

    func markDayComplete(_ day: Int) async throws {
        guard (0...6).contains(day) else { return }
        guard var focus = await current() else { return }
        guard !focus.completedDays.contains(day) else { return }
        focus.completedDays.insert(day)
        try await save(focus)
    }

    /// Marks the current week's need resolved, so the carry-over rung stops
    /// carrying it forward.
    func markResolved() async throws {
        guard var focus = await current(), focus.resolvedAt == nil else { return }
        focus.resolvedAt = Date()
        try await save(focus)
    }
}
