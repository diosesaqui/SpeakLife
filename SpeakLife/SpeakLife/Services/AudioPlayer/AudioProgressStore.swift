//
//  AudioProgressStore.swift
//  SpeakLife
//

import Foundation
import Combine

/// Persists which audio IDs the user has listened to past the completion
/// threshold. Backed by UserDefaults for instant local reads, and mirrored
/// to iCloud (ProgressSyncStore event log) so played checkmarks follow the
/// user across devices.
final class AudioProgressStore: ObservableObject {
    static let shared = AudioProgressStore()

    private let defaultsKey = "sl_audioPlayedIDs_v1"
    private let migrationFlagKey = "sl_audioPlayedIDsMigratedToSync_v1"

    @Published private(set) var playedIDs: Set<String>

    private init() {
        let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []
        playedIDs = Set(saved)

        // One-time push of the existing local history into the synced store.
        // Purely additive — nothing local is touched — and retried on next
        // launch until it succeeds (recordEvents upserts are idempotent).
        if !UserDefaults.standard.bool(forKey: migrationFlagKey) {
            if !playedIDs.isEmpty {
                ProgressSyncStore.shared.recordEvents(
                    kind: ProgressSyncStore.Kind.listenedAudio,
                    items: playedIDs.map { (key: $0, payload: nil) }
                )
            }
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
        }

        // Refresh from the synced event log whenever CloudKit delivers
        // changes from the user's other devices.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncDataChanged),
            name: ProgressSyncStore.dataDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Mark an audio ID as played (no-op if already marked).
    func markPlayed(_ id: String) {
        guard !playedIDs.contains(id) else { return }
        playedIDs.insert(id)
        persist()
        ProgressSyncStore.shared.recordEvent(kind: ProgressSyncStore.Kind.listenedAudio, key: id)
    }

    /// Manually clear the played state for an audio ID (no-op if not marked).
    func markUnplayed(_ id: String) {
        guard playedIDs.contains(id) else { return }
        playedIDs.remove(id)
        persist()
        // Deleting the event row propagates the un-mark to other devices.
        ProgressSyncStore.shared.deleteEvent(kind: ProgressSyncStore.Kind.listenedAudio, key: id)
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

    // MARK: - iCloud Sync

    @objc private func handleSyncDataChanged(_ notification: Notification) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.handleSyncDataChanged(notification) }
            return
        }
        if let kinds = notification.userInfo?["kinds"] as? Set<String>,
           !kinds.contains(ProgressSyncStore.Kind.listenedAudio) {
            return
        }

        // After the one-time migration the synced event log is the source of
        // truth: it always contains at least everything this device wrote
        // (local rows persist even before CloudKit import completes), and
        // rebuilding from it lets un-marks from other devices propagate too.
        // Before the migration has run, only ADD remote IDs — never remove.
        let remote = Set(ProgressSyncStore.shared.events(ofKind: ProgressSyncStore.Kind.listenedAudio).map(\.key))
        let migrated = UserDefaults.standard.bool(forKey: migrationFlagKey)
        let merged = migrated ? remote : playedIDs.union(remote)

        if merged != playedIDs {
            playedIDs = merged
            persist()
        }
    }
}
