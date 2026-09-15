//
//  StandLink.swift
//  SpeakLife
//
//  Parsing one shape of URL: https://speaklife.app.link/stand/<CODE>
//
//  Three paths reach this (spec §9), and all of them land here so the rules
//  about what counts as a code live in exactly one place:
//
//   1. App installed  → `onOpenURL` in SpeakLifeApp.
//   2. Not installed  → App Store → Branch resolves the deferred link in
//                       `BranchAttribution.apply`.
//   3. Match missed   → the human types the code, which Branch's probabilistic
//                       matching makes a real case rather than a theoretical one.
//

import Foundation

enum StandLink {

    /// Mirrors CODE_ALPHABET in functions/standTogether.js. Both halves of each
    /// confusable pair are excluded (0/O, 1/I/L), so a typed `0` or `I` cannot
    /// be valid under any reading — it is rejected rather than guessed at.
    /// Guessing is how somebody lands in the wrong family's stand.
    static let alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    static let codeLength = 8

    /// The invite code in a URL, or nil when this is not a stand link.
    ///
    /// Matches on the path only, never the host: the invite works from the
    /// Branch domain, from a custom scheme, and from anything the marketing
    /// site might front it with later, and none of those should need a code
    /// change here.
    static func code(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let index = parts.firstIndex(where: { $0.caseInsensitiveCompare("stand") == .orderedSame }),
              index + 1 < parts.count else {
            // Also accept it as a query parameter, which is the shape a
            // marketing or email link is most likely to carry.
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "stand" }?.value
            return query.flatMap(normalize)
        }
        return normalize(parts[index + 1])
    }

    /// Uppercase, strip separators, then require exactly eight characters from
    /// the alphabet. Identical to `normalizeCode` server-side, so the client
    /// never sends a call the server is going to reject.
    static func normalize(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == codeLength,
              cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// `ABCD-2345` — how a code is shown and read aloud.
    static func formatted(_ code: String) -> String {
        guard code.count == codeLength else { return code }
        let mid = code.index(code.startIndex, offsetBy: 4)
        return "\(code[code.startIndex..<mid])-\(code[mid...])"
    }

    static func shareURL(for code: String) -> URL? {
        URL(string: "https://speaklife.app.link/stand/\(code)")
    }
}
