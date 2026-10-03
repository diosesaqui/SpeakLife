//
//  ReferralLink.swift
//  SpeakLifeCore
//
//  Pulls a referral code out of the shapes it can arrive in (spec §9.5):
//
//   - `https://<any host>/r/<CODE>`   (the Branch link, or anything fronting it)
//   - `speaklife://r/<CODE>`          (custom scheme: "r" lands in the HOST)
//   - `...?ref=<CODE>`                (marketing or email links)
//   - Branch params `ref`, else `~referring_link`
//
//  The parallel of `StandLink` in the app target, with the same alphabet and
//  the same normalisation, which in turn mirror `CODE_ALPHABET` and
//  `normalizeCode` in functions/standTogether.js. The shared fixture
//  `referral_codes_fixture.json` pins client and server to the same answers.
//
//  A Stand code is never read as a referral code, and vice versa. The path
//  segment decides, and any URL that carries the `stand` marker is refused
//  here outright, even if it also has a `?ref=`.
//
//  Foundation only.
//

import Foundation

public enum ReferralSource: String, Codable, Sendable {
    case deferred
    case universalLink = "universal_link"
    case manual
}

public enum ReferralLink {

    /// Mirrors CODE_ALPHABET in functions/standTogether.js and
    /// `StandLink.alphabet`. Both halves of each confusable pair are excluded
    /// (0/O, 1/I/L), so a typed `0` or `I` is rejected rather than guessed at.
    public static let alphabet: String = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    public static let codeLength: Int = 8

    /// The path segment (or custom-scheme host) that marks a referral link.
    static let pathMarker = "r"
    /// The query item a marketing link carries the code in.
    static let queryKey = "ref"
    /// The Stand marker. A URL carrying it is a Stand link, never a referral.
    static let standMarker = "stand"

    /// Uppercase, strip separators, then require exactly eight characters from
    /// the alphabet. The single client definition: `StandLink` delegates here,
    /// so both features accept exactly the same typed codes.
    public static func normalize(_ raw: String) -> String? {
        let cleaned = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        guard cleaned.count == codeLength,
              cleaned.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return cleaned
    }

    /// The referral code in a URL, or nil when this is not a referral link.
    ///
    /// Never matches on the DOMAIN, for the same reason `StandLink` doesn't:
    /// the link host is Remote Config and has to be movable without a build.
    public static func code(from url: URL) -> String? {
        let parts: [String] = url.path.split(separator: "/").map { String($0) }
        let host: String = url.host ?? ""

        // A Stand link is never a referral link, whatever else it carries.
        if host.caseInsensitiveCompare(standMarker) == .orderedSame { return nil }
        if parts.contains(where: { $0.caseInsensitiveCompare(standMarker) == .orderedSame }) {
            return nil
        }

        // `speaklife://r/K7MQ2XPA` puts "r" in the host and the code alone in
        // the path.
        if host.caseInsensitiveCompare(pathMarker) == .orderedSame, let first = parts.first {
            return normalize(first)
        }

        if let index = parts.firstIndex(where: { $0.caseInsensitiveCompare(pathMarker) == .orderedSame }),
           index + 1 < parts.count {
            // `/r/K7MQ2XPA/extra` still reads the segment right after the marker.
            return normalize(parts[index + 1])
        }

        let query: String? = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == queryKey })?
            .value
        guard let value = query else { return nil }
        return normalize(value)
    }

    /// The referral code in Branch's deep-link data.
    ///
    /// `ref` wins over `~referring_link` when both are present. An unusable
    /// `ref` falls through to the referring link rather than losing a friend.
    public static func code(fromBranchParams params: [String: Any]) -> String? {
        if let ref = params[queryKey] as? String, let code = normalize(ref) {
            return code
        }
        if let link = params["~referring_link"] as? String,
           let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return code(from: url)
        }
        return nil
    }

    /// `https://<host>/r/<CODE>`, the link a referrer shares. The host comes
    /// from Remote Config `referralLinkDomain` (read the `StandLink.shareHost`
    /// warning before changing it).
    ///
    /// Nil when the code does not normalise or the host is empty, so a broken
    /// link is never shared.
    public static func shareURL(code: String, host: String) -> URL? {
        guard let normalized = normalize(code) else { return nil }
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else { return nil }
        return URL(string: "https://\(trimmedHost)/\(pathMarker)/\(normalized)")
    }

    /// `K7MQ-2XPA`: how a code is shown and read aloud.
    public static func formatted(_ code: String) -> String {
        guard code.count == codeLength else { return code }
        let mid = code.index(code.startIndex, offsetBy: 4)
        return "\(code[code.startIndex..<mid])-\(code[mid...])"
    }
}
