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
//  for several things at once. The v1 record is migrated in place on first read
//  and the migration is flagged so an emptied list never re-imports it.
//

import Foundation

final class PersonalDeclarationRepository: PersonalDeclarationRepositoryProtocol {
    static let storageKey = "personal_declarations_v2"
    static let legacyStorageKey = "personal_declaration_v1"
    static let migrationFlagKey = "personal_declarations_migratedToV2"

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
        var all = readAll()
        if let index = all.firstIndex(where: { $0.id == declaration.id }) {
            all[index] = declaration
        } else {
            all.append(declaration)
        }
        try writeAll(all)
    }

    func markReceived(id: UUID, testimony: String?) async throws {
        var all = readAll()
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].receivedDate = Date()
        all[index].testimony = testimony
        try writeAll(all)
    }

    func delete(id: UUID) async throws {
        let all = readAll()
        guard all.contains(where: { $0.id == id }) else { return }
        try writeAll(all.filter { $0.id != id })
    }

    /// Records a successful speak and returns the updated record. Kept on the
    /// repository so the counters are written in one read-modify-write and the
    /// card never has to own persistence.
    @discardableResult
    func recordSpeak(id: UUID) async throws -> PersonalDeclaration? {
        var all = readAll()
        guard let index = all.firstIndex(where: { $0.id == id }) else { return nil }
        all[index].recordSpeak()
        try writeAll(all)
        return all[index]
    }

    func clear() async throws {
        defaults.removeObject(forKey: Self.storageKey)
        defaults.removeObject(forKey: Self.legacyStorageKey)
        // Keep the migration flag set: the v1 record is gone, so there is
        // nothing left to import and re-running the migration would be a no-op
        // at best and a resurrection at worst.
        defaults.set(true, forKey: Self.migrationFlagKey)
    }

    // MARK: - Storage

    private func readAll() -> [PersonalDeclaration] {
        if let data = defaults.data(forKey: Self.storageKey),
           let list = try? JSONDecoder().decode([PersonalDeclaration].self, from: data) {
            return list
        }
        return migrateLegacyRecordIfNeeded()
    }

    private func writeAll(_ declarations: [PersonalDeclaration]) throws {
        let data = try JSONEncoder().encode(declarations)
        defaults.set(data, forKey: Self.storageKey)
        // Once the list exists it is the only source of truth. The flag stops
        // the v1 record from being re-imported if the list is later emptied.
        defaults.set(true, forKey: Self.migrationFlagKey)
    }

    /// Pulls the pre-multi-declaration single record into the list, carrying its
    /// spoken-day counters over so "Day N" doesn't reset on upgrade.
    @discardableResult
    private func migrateLegacyRecordIfNeeded() -> [PersonalDeclaration] {
        guard !defaults.bool(forKey: Self.migrationFlagKey) else { return [] }
        defaults.set(true, forKey: Self.migrationFlagKey)

        guard let data = defaults.data(forKey: Self.legacyStorageKey),
              var declaration = try? JSONDecoder().decode(PersonalDeclaration.self, from: data)
        else { return [] }

        declaration.absorbLegacySpeakTracking(from: defaults)

        if let encoded = try? JSONEncoder().encode([declaration]) {
            defaults.set(encoded, forKey: Self.storageKey)
        }
        return [declaration]
    }
}
