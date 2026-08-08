//
//  DeclarationArcProtocols.swift
//  SpeakLife
//

import Foundation

// MARK: - Repository

protocol DeclarationArcRepositoryProtocol {
    func save(_ arc: DeclarationArc) async throws
    func load() async -> DeclarationArc?
    func clear() async throws
}

// MARK: - Remote selection

/// The `declarationArc` Cloud Function, behind a protocol so the builder can be
/// exercised without a network (and so the whole remote leg can be swapped for
/// a no-op in a test or a DEBUG build).
protocol DeclarationArcRemoteSelecting {
    /// - Returns: the selected declaration IDs and the category the server
    ///   resolved, or nil on ANY failure — no throw, no error surface. The
    ///   caller's answer to a nil is always the same: build the keyword arc.
    func selectArc(beliefText: String?, profile: SoulProfile?) async -> DeclarationArcSelection?
}

/// What both the remote call and the local selector produce.
struct DeclarationArcSelection {
    let declarationIDs: [String]
    let categoryRaw: String
}
