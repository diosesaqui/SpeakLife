//
//  PersonalDeclarationRepository.swift
//  SpeakLife
//
//  UserDefaults-backed repository for MVP.
//  Protocol-isolated so it can be replaced with CoreData in v2
//  by swapping one line in DIContainer.
//

import Foundation

final class PersonalDeclarationRepository: PersonalDeclarationRepositoryProtocol {
    static let storageKey = "personal_declaration_v1"
    private let key = PersonalDeclarationRepository.storageKey
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Synchronous read of the active personal declaration's category rawValue.
    /// For callers on the main thread that can't await `load()` (e.g. ordering
    /// the audio filters as they're built). Returns nil when none is saved.
    static func activeCategoryRaw(defaults: UserDefaults = .standard) -> String? {
        guard let data = defaults.data(forKey: storageKey),
              let declaration = try? JSONDecoder().decode(PersonalDeclaration.self, from: data)
        else { return nil }
        return declaration.categoryRaw
    }

    func save(_ declaration: PersonalDeclaration) async throws {
        let data = try JSONEncoder().encode(declaration)
        defaults.set(data, forKey: key)
    }

    func load() async -> PersonalDeclaration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersonalDeclaration.self, from: data)
    }

    func markReceived(id: UUID, testimony: String?) async throws {
        guard var declaration = await load(), declaration.id == id else { return }
        declaration.receivedDate = Date()
        declaration.testimony = testimony
        try await save(declaration)
    }

    func clear() async throws {
        defaults.removeObject(forKey: key)
    }
}
