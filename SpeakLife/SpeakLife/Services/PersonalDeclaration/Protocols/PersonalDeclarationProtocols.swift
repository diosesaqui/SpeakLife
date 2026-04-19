//
//  PersonalDeclarationProtocols.swift
//  SpeakLife
//

import Foundation

// MARK: - Matcher

protocol DeclarationMatcherProtocol {
    func match(input: String) -> DeclarationMatch
}

// MARK: - Speech

protocol SpeechTranscriptionProtocol {
    var isRecording: Bool { get }
    func requestPermission() async -> Bool
    func startRecording() async throws
    func stopRecording() async -> String
}

// MARK: - Repository

protocol PersonalDeclarationRepositoryProtocol {
    func save(_ declaration: PersonalDeclaration) async throws
    func load() async -> PersonalDeclaration?
    func markReceived(id: UUID, testimony: String?) async throws
    func clear() async throws
}

// MARK: - Notifications

protocol DeclarationNotificationServiceProtocol {
    func schedule(for declaration: PersonalDeclaration, startTimeIndex: Int)
    func cancel()
}
