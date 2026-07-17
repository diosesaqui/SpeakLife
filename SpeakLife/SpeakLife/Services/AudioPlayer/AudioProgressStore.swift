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
///
/// Loss-proofing: an ID only becomes eligible for remote-driven removal
/// after this device has CONFIRMED it was written to the sync store (the
/// `syncedIDs` ledger). Locally-marked IDs whose write hasn't been confirmed
/// yet always survive a refresh, so a failed or in-flight write can never
/// cost the user a checkmark — while un-marks made on other devices still
/// propagate (a confirmed ID missing from the event log was deleted there).
final class AudioProgressStore: ObservableObject {
    static let shared = AudioProgressStore()

    private let defaultsKey = "sl_audioPlayedIDs_v1"
    private let syncedIDsKey = "sl_audioPlayedIDsSynced_v1"
    private let migrationFlagKey = "sl_audioPlayedIDsMigratedToSync_v1"

    @Published private(set) var playedIDs: Set<String>

    /// IDs confirmed present in the sync store (written by us or imported).
    private var syncedIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: syncedIDsKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: syncedIDsKey) }
    }

    private init() {
        let saved = UserDefaults.standard.array(forKey: defaultsKey) as? [String] ?? []
        playedIDs = Set(saved)

        // One-time push of the existing local history into the synced store.
        // Purely additive, idempotent, and the flag is only set once the
        // write DEFINITELY persisted — a failure retries on the next launch.
        if !UserDefaults.standard.bool(forKey: migrationFlagKey) {
            let ids = playedIDs
            if ids.isEmpty {
                UserDefaults.standard.set(true, forKey: migrationFlagKey)
            } else {
                ProgressSyncStore.shared.recordEvents(
                    kind: ProgressSyncStore.Kind.listenedAudio,
                    items: ids.map { (key: $0, payload: nil) }
                ) { [weak self] success in
                    guard success, let self = self else { return }
                    UserDefaults.standard.set(true, forKey: self.migrationFlagKey)
                    self.syncedIDs.formUnion(ids)
                }
            }
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
        ProgressSyncStore.shared.recordEvent(kind: ProgressSyncStore.Kind.listenedAudio, key: id) { [weak self] success in
            guard success else { return }
            self?.syncedIDs.insert(id)
        }
    }

    /// Manually clear the played state for an audio ID (no-op if not marked).
    func markUnplayed(_ id: String) {
        guard playedIDs.contains(id) else { return }
        playedIDs.remove(id)
        persist()
        // Deleting the event row propagates the un-mark to other devices.
        ProgressSyncStore.shared.deleteEvent(kind: ProgressSyncStore.Kind.listenedAudio, key: id) { [weak self] success in
            guard success else { return }
            self?.syncedIDs.remove(id)
        }
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
        if let kinds = notification.userInfo?["kinds"] as? Set<String>,
           !kinds.contains(ProgressSyncStore.Kind.listenedAudio) {
            return
        }
        // Asynchronous fetch — never block the main thread behind the sync
        // context. The completion runs on main, where @Published playedIDs
        // must be mutated anyway.
        ProgressSyncStore.shared.events(ofKind: ProgressSyncStore.Kind.listenedAudio) { [weak self] events in
            self?.applySyncedEvents(events)
        }
    }

    /// Runs on the main queue.
    private func applySyncedEvents(_ events: [ProgressSyncStore.Event]) {
        let remote = Set(events.map(\.key))
        let confirmed = syncedIDs

        // Safety valve: an empty event log while we previously confirmed IDs
        // means the local mirror was likely purged (iCloud sign-out/account
        // switch), not that the user un-marked everything one by one on
        // another device. Never mass-delete local history on that signal.
        if remote.isEmpty && !confirmed.isEmpty {
            return
        }

        // Keep: everything in the log, plus local marks not yet confirmed
        // synced (their write may have failed or still be in flight).
        // Drop: confirmed IDs missing from the log — deleted on a device.
        let merged = remote.union(playedIDs.subtracting(confirmed))

        if merged != playedIDs {
            playedIDs = merged
            persist()
        }
        if confirmed != remote {
            syncedIDs = remote
        }
    }
}
