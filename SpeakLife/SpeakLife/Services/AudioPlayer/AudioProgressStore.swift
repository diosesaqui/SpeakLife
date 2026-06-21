//
//  AudioProgressStore.swift
//  SpeakLife
//

import Foundation
import Combine

/// Persists which audio IDs the user has listened to past the 50% mark.
/// Backed by UserDefaults — survives app restarts.
final class AudioProgressStore: ObservableObject {
    static let shared = AudioProgressStore()

    private let defaultsKey = "sl_audioPlayedIDs_v1"

    @Published private(set) var playedIDs: Set<String>

    private init() {
        let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []
        playedIDs = Set(saved)
    }

    /// Mark an audio ID as played (no-op if already marked).
    func markPlayed(_ id: String) {
        guard !playedIDs.contains(id) else { return }
        playedIDs.insert(id)
        persist()
    }

    /// Manually clear the played state for an audio ID (no-op if not marked).
    func markUnplayed(_ id: String) {
        guard playedIDs.contains(id) else { return }
        playedIDs.remove(id)
        persist()
    }

    /// Flip the played state for an audio ID. Used by the manual toggle in the UI.
    func togglePlayed(_ id: String) {
        if playedIDs.contains(id) {
            markUnplayed(id)
        } else {
            markPlayed(id)
        }
    }

    func isPlayed(_ id: String) -> Bool {
        playedIDs.contains(id)
    }

    private func persist() {
        UserDefaults.standard.set(Array(playedIDs), forKey: defaultsKey)
    }
}
