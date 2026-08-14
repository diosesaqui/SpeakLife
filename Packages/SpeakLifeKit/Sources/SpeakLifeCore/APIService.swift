//
//  APIService.swift
//  SpeakLifeCore
//
//  API service protocol and error type. Moved from
//  Services/Networking/Protocols/APIService.swift and
//  Services/Networking/APIError.swift so `SpeakLifePersistence`
//  (which contains `DataMigrationManager`, `CoreDataAPIService`
//  in the app, and their tests) can name these types without
//  the app target being in the graph.
//

import Foundation

public enum APIError: Error {

    // MARK: - Cases

    case unknown
    case unreachable
    case failedRequest
    case invalidResponse
    case failedDecode
    case resourceNotFound
    case noData

    // MARK: - Properties

    public var message: String {
        switch self {
        case .unreachable:
            return "You need to have a network connection."
        case .unknown,
                .noData,
                .failedRequest,
                .invalidResponse,
                .failedDecode,
                .resourceNotFound:
            return "The list of delcarations could not be fetched."
        }
    }
}

public protocol APIService {
    var remoteVersion: Int { get set }
    var localVersion: Int { get set }
    func declarations(completion: @escaping ([Declaration], APIError?, Bool) -> Void)
    func save(declarations: [Declaration], completion: @escaping (Bool) -> Void)
    func declarationCategories(completion: @escaping (Set<DeclarationCategory>, APIError?) -> Void)
    func save(selectedCategories: Set<DeclarationCategory>, completion: @escaping (Bool) -> Void)
    func audio(version: Int, completion: @escaping (WelcomeAudio?, [AudioDeclaration]?) -> Void)
}
