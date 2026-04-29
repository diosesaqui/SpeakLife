//
//  MatchDeclarationUseCase.swift
//  SpeakLife
//

import Foundation

final class MatchDeclarationUseCase {
    private let matcher: DeclarationMatcherProtocol

    init(matcher: DeclarationMatcherProtocol) {
        self.matcher = matcher
    }

    func execute(input: String) async -> DeclarationMatch {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            return await matcher.match(input: "faith")
        }
        return await matcher.match(input: sanitized)
    }

    func matchAll(input: String) -> [DeclarationCategory] {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else { return [] }
        return matcher.matchAll(input: sanitized)
    }
}
