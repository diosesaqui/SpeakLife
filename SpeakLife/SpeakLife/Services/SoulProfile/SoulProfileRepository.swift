//
//  SoulProfileRepository.swift
//  SpeakLife
//
//  UserDefaults-backed repository, mirrored to Firestore.
//  Protocol-isolated so the storage can be swapped in DIContainer without
//  touching a caller — same shape as PersonalDeclarationRepository.
//

import Foundation

final class SoulProfileRepository: SoulProfileRepositoryProtocol {
    static let storageKey = "soul_profile_v1"
    private let key = SoulProfileRepository.storageKey
    private let defaults: UserDefaults
    private let remote: SoulProfileRemoteMirrorProtocol?

    init(defaults: UserDefaults = .standard,
         remote: SoulProfileRemoteMirrorProtocol? = SoulProfileFirestoreMirror()) {
        self.defaults = defaults
        self.remote = remote
    }

    // MARK: - Synchronous accessors
    //
    // For main-thread callers that can't await `load()`. NotificationManager
    // builds its fire times inside a synchronous scheduling pass, so the
    // hits-hardest bias has to be readable without an await — same reason
    // PersonalDeclarationRepository.activeCategoryRaw() exists.

    /// Whole profile, decoded synchronously. Returns nil when nothing is saved
    /// or the stored blob no longer decodes.
    static func loadSync(defaults: UserDefaults = .standard) -> SoulProfile? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(SoulProfile.self, from: data)
    }

    /// The raw `hits_hardest` answer (night | morning | midday | evening), or
    /// nil when the user's arm never asked or they skipped it.
    static func hitsHardestRaw(defaults: UserDefaults = .standard) -> String? {
        guard let raw = loadSync(defaults: defaults)?.hitsHardest,
              !raw.isEmpty else { return nil }
        return raw
    }

    // MARK: - SoulProfileRepositoryProtocol

    func saveNow(_ profile: SoulProfile) {
        guard let data = try? JSONEncoder().encode(profile) else {
            AnalyticsService.shared.track("soul_profile_encode_failed", parameters: [:])
            return
        }
        defaults.set(data, forKey: key)
        // Remote leg is deliberately last and deliberately non-throwing: the
        // local write is the source of truth and onboarding must never fail
        // because Firestore was slow or unreachable.
        remote?.mirror(profile)
    }

    func save(_ profile: SoulProfile) async throws {
        saveNow(profile)
    }

    func load() async -> SoulProfile? {
        SoulProfileRepository.loadSync(defaults: defaults)
    }

    func clear() async throws {
        defaults.removeObject(forKey: key)
    }
}
