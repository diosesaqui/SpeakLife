//
//  SoulProfileProtocols.swift
//  SpeakLife
//

import Foundation

// MARK: - Repository

protocol SoulProfileRepositoryProtocol {
    /// Synchronous local write plus a fire-and-forget remote mirror.
    ///
    /// Required on the onboarding-completion path: notification scheduling runs
    /// moments later and reads `hitsHardest` back out synchronously, so an
    /// awaited write could lose the race and schedule an unbiased batch.
    /// Encoding one small struct is cheap enough to do inline.
    func saveNow(_ profile: SoulProfile)

    /// Async wrapper over `saveNow` for callers already in an async context.
    func save(_ profile: SoulProfile) async throws
    func load() async -> SoulProfile?
    func clear() async throws
}

// MARK: - Remote mirror

protocol SoulProfileRemoteMirrorProtocol {
    /// Best-effort upload. Implementations must swallow every failure — a
    /// dropped mirror is invisible to the user, a thrown one is not.
    func mirror(_ profile: SoulProfile)
}
