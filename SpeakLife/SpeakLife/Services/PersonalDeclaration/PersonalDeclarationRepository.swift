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
    private let key = "personal_declaration_v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
