//
//  WelcomeResponse.swift
//  SpeakLifeCore
//
//  The root shape of `declarationsv10.json`.
//
//  Moved into Core so the assembler tests can decode the shipped pool from
//  `Bundle.main` without pulling in the app's `LazyJSONLoader` (which lives on
//  Firebase Storage plumbing that has no place in a unit test).
//

import Foundation

public struct WelcomeResponse: Codable {
    public let count: Int
    public let version: Int
    public let declarations: [Declaration]

    public init(count: Int, version: Int, declarations: [Declaration]) {
        self.count = count
        self.version = version
        self.declarations = declarations
    }
}
