//
//  PersonalDeclarationRepository.swift
//  SpeakLife
//
//  UserDefaults-backed repository.
//  Protocol-isolated so it can be replaced with CoreData
//  by swapping one line in DIContainer.
//
//  Storage moved from a single record (`personal_declaration_v1`) to an ordered
//  list (`personal_declarations_v2`) when the feature grew to support believing
//  for several things at once. The v1 record is migrated in place on first read.
//
//  Two rules keep the user's declarations safe, because losing one means losing
//  a promise they've been standing on for weeks:
//
//  1. Deletes are tombstones, never removals. The list merges across devices as
//     a union by id, so a record that simply vanished locally would be handed
//     straight back by the next iCloud reconcile.
//  2. A partially undecodable blob is salvaged element by element rather than
//     read as "empty". Every write is a read-modify-write, so treating a bad
//     read as empty would let the next save overwrite everything that survived.
//

import Foundation

final class PersonalDeclarationRepository: PersonalDeclarationRepositoryProtocol {
    static let storageKey = "personal_declarations_v2"
    static let legacyStorageKey = "personal_declaration_v1"
    static let migrationFlagKey = "personal_declarations_migratedToV2"
    /// Where an unreadable blob is parked before being replaced, so a support
    /// request still has something to recover from.
    static let corruptBackupKey = "personal_declarations_v2_unreadable"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Synchronous helpers

    /// Synchronous read of the active personal declaration's category rawValue.
    /// For callers on the main thread that can't await `load()` (e.g. ordering
    /// the audio filters as they're built). Returns nil when none is saved.
    static func activeCategoryRaw(defaults: UserDefaults = .standard) -> String? {
        PersonalDeclarationRepository(defaults: defaults)
            .readAll()
            .first(where: { !$0.isReceived })?
            .categoryRaw
    }

    // MARK: - Reads

    func load() async -> PersonalDeclaration? {
        let all = readAll()
        return all.first(where: { !$0.isReceived }) ?? all.last
    }

    func loadAll() async -> [PersonalDeclaration] {
        readAll()
    }

    func loadActive() async -> [PersonalDeclaration] {
        readAll().filter { !$0.isReceived }
    }

    // MARK: - Writes

    func save(_ declaration: PersonalDeclaration) async throws {
        var stored = readStored()
        if let index = stored.firstIndex(where: { $0.id == declaration.id }) {
            stored[index] = declaration
        } else {
            stored.append(declaration)
        }
        try writeStored(stored)
    }

    func markReceived(id: UUID, testimony: String?) async throws {
        var stored = readStored()
        guard let index = stored.firstIndex(where: { $0.id == id }) else { return }
        stored[index].receivedDate = Date()
        stored[index].testimony = testimony
        try writeStored(stored)
    }

    /// Tombstones the record rather than dropping it — see the note at the top.
    func delete(id: UUID) async throws {
        var stored = readStored()
        guard let index = stored.firstIndex(where: { $0.id == id }),
              !stored[index].isDeleted
        else { return }
        stored[index].deletedDate = Date()
        try writeStored(stored)
    }

    /// Records a successful speak and returns the updated record. Kept on the
    /// repository so the counters are written in one read-modify-write and the
    /// card never has to own persistence.
    @discardableResult
    func recordSpeak(id: UUID) async throws -> PersonalDeclaration? {
        var stored = readStored()
        guard let index = stored.firstIndex(where: { $0.id == id }) else { return nil }
        stored[index].recordSpeak()
        try writeStored(stored)
        return stored[index]
    }

    func clear() async throws {
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.legacyStorageKey)
        // The v1 record is gone, so there is nothing left to import and
        // re-running the migration would be a no-op at best and a resurrection
        // at worst.
        defaults.set(true, forKey: Self.migrationFlagKey)
    }

    // MARK: - Storage

    /// Everything the user can see: tombstones filtered out.
    private func readAll() -> [PersonalDeclaration] {
        readStored().filter { !$0.isDeleted }
    }

    /// The raw stored list, tombstones included. Every write reads through this
    /// so a delete on one device isn't undone by a save on another.
    private func readStored() -> [PersonalDeclaration] {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return migrateLegacyRecordIfNeeded()
        }
        if let list = try? JSONDecoder().decode([PersonalDeclaration].self, from: data) {
            return list
        }
        return salvage(data)
    }

    private func writeStored(_ declarations: [PersonalDeclaration]) throws {
        let data = try JSONEncoder().encode(declarations)
        defaults.set(data, forKey: Self.storageKey)
        // Once the list exists it is the only source of truth.
        defaults.set(true, forKey: Self.migrationFlagKey)
    }

    /// Rescues what it can from a blob the array decoder rejected. One bad
    /// record — a truncated write, a field a future build added — must not cost
    /// the user the declarations either side of it.
    private func salvage(_ data: Data) -> [PersonalDeclaration] {
        // Park the original before anything overwrites it.
        if defaults.data(forKey: Self.corruptBackupKey) == nil {
            defaults.set(data, forKey: Self.corruptBackupKey)
        }

        guard let elements = (try? JSONSerialization.jsonObject(with: data)) as? [Any] else {
            print("❌ personal declarations blob unreadable; backed up to \(Self.corruptBackupKey)")
            return []
        }

        let decoder = JSONDecoder()
        let recovered = elements.compactMap { element -> PersonalDeclaration? in
            guard let elementData = try? JSONSerialization.data(withJSONObject: element) else { return nil }
            return try? decoder.decode(PersonalDeclaration.self, from: elementData)
        }
        print("⚠️ personal declarations blob partially unreadable; recovered \(recovered.count) of \(elements.count)")
        return recovered
    }

    /// Pulls the pre-multi-declaration single record into the list, carrying its
    /// spoken-day counters over so "Day N" doesn't reset on upgrade.
    private func migrateLegacyRecordIfNeeded() -> [PersonalDeclaration] {
        guard !defaults.bool(forKey: Self.migrationFlagKey) else { return [] }

        // The flag is only burned once there is actually something to import.
        // Setting it on the way in would lose the declaration of anyone whose
        // v1 record arrives from iCloud a moment after first launch — exactly
        // the reinstall/new-device case this migration exists for.
        guard let data = defaults.data(forKey: Self.legacyStorageKey),
              var declaration = try? JSONDecoder().decode(PersonalDeclaration.self, from: data)
        else { return [] }

        declaration.absorbLegacySpeakTracking(from: defaults)

        if let encoded = try? JSONEncoder().encode([declaration]) {
            defaults.set(encoded, forKey: Self.storageKey)
            defaults.set(true, forKey: Self.migrationFlagKey)
        }
        return [declaration]
    }
}
