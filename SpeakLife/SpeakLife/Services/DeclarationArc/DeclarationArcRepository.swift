//
//  DeclarationArcRepository.swift
//  SpeakLife
//
//  UserDefaults-backed repository, synced across devices by SyncedSettingsStore.
//  Protocol-isolated so the storage can be swapped in DIContainer without
//  touching a caller — same shape as PersonalDeclarationRepository and
//  SoulProfileRepository.
//

import Foundation

final class DeclarationArcRepository: DeclarationArcRepositoryProtocol {

    static let storageKey = "declaration_arc_v1"

    private let key = DeclarationArcRepository.storageKey
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Synchronous accessors
    //
    // `DeclarationViewModel.refreshGeneral` is a synchronous main-thread
    // function on the hot path of every feed rebuild — it cannot await. Same
    // reason `PersonalDeclarationRepository.activeCategoryRaw()` and
    // `SoulProfileRepository.loadSync()` exist.

    static func loadSync(defaults: UserDefaults = .standard) -> DeclarationArc? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(DeclarationArc.self, from: data)
    }

    /// True when an arc is stored, without paying the decode. Guards the
    /// once-per-user build at onboarding completion.
    static func hasArc(defaults: UserDefaults = .standard) -> Bool {
        defaults.data(forKey: storageKey) != nil
    }

    /// Reads the arc and moves its day cursor forward if a new calendar day has
    /// started, persisting the move.
    ///
    /// Called from the feed rather than from a timer or a launch hook on
    /// purpose: the cursor should track days the user actually showed up, and
    /// the feed rebuilding *is* the user showing up. `DeclarationArc.advanced`
    /// owns the once-a-day rule, so calling this on every rebuild is cheap and
    /// idempotent — it writes at most one time per day.
    ///
    /// - Returns: the arc as it now stands, or nil when none is stored.
    @discardableResult
    static func advanceIfNeeded(
        at date: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> DeclarationArc? {
        guard let arc = loadSync(defaults: defaults) else { return nil }
        guard let advanced = arc.advanced(to: date) else { return arc }
        guard let data = try? JSONEncoder().encode(advanced) else { return arc }
        defaults.set(data, forKey: storageKey)
        return advanced
    }

    // MARK: - DeclarationArcRepositoryProtocol

    func save(_ arc: DeclarationArc) async throws {
        let data = try JSONEncoder().encode(arc)
        defaults.set(data, forKey: key)
    }

    func load() async -> DeclarationArc? {
        DeclarationArcRepository.loadSync(defaults: defaults)
    }

    func clear() async throws {
        defaults.removeObject(forKey: key)
    }
}
