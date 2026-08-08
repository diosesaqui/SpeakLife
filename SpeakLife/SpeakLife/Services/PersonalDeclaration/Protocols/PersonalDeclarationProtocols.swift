//
//  PersonalDeclarationProtocols.swift
//  SpeakLife
//

import Foundation

// MARK: - Matcher

protocol DeclarationMatcherProtocol {
    func match(input: String) async -> DeclarationMatch
    func matchAll(input: String) -> [DeclarationCategory]
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
    /// Inserts a new declaration or updates an existing one with the same id.
    func save(_ declaration: PersonalDeclaration) async throws
    /// The declaration the single-declaration surfaces should show — the first
    /// one still being believed for, or the most recent if all have come to pass.
    func load() async -> PersonalDeclaration?
    /// Every declaration ever saved, oldest first, including received ones.
    func loadAll() async -> [PersonalDeclaration]
    /// Declarations still being believed for, oldest first.
    func loadActive() async -> [PersonalDeclaration]
    func markReceived(id: UUID, testimony: String?) async throws
    /// Records one successful speak against a declaration, advancing its daily
    /// and "Day N" counters. Returns the updated record.
    @discardableResult
    func recordSpeak(id: UUID) async throws -> PersonalDeclaration?
    func delete(id: UUID) async throws
    func clear() async throws
}

// MARK: - Notifications

protocol DeclarationNotificationServiceProtocol {
    /// Schedules one daily reminder per active declaration, staggered so several
    /// burdens don't all land in the same minute. Replaces any previously
    /// scheduled personal-declaration reminders.
    func scheduleAll(_ declarations: [PersonalDeclaration], startTimeIndex: Int)
    /// Cancels the reminder for a single declaration.
    func cancel(id: UUID)
    /// Cancels every personal-declaration reminder.
    func cancelAll()
}
