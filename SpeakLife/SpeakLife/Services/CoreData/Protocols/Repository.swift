//
//  Repository.swift
//  SpeakLife
//
//  Repository Protocol for SOLID principles
//

import Foundation
import Combine

protocol Repository {
    associatedtype Entity
    
    func create(_ entity: Entity) async throws
    func update(_ entity: Entity) async throws
    func delete(_ entity: Entity) async throws
    func fetch(predicate: NSPredicate?) async throws -> [Entity]
    func fetchById(_ id: UUID) async throws -> Entity?
    func observeAll() -> AnyPublisher<[Entity], Never>
}