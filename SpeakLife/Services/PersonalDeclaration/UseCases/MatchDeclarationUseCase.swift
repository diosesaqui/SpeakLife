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

    func execute(input: String) -> DeclarationMatch {
        let sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty else {
            return matcher.match(input: "faith")
        }
        return matcher.match(input: sanitized)
    }
}
