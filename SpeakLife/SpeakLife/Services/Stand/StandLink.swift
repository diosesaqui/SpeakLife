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
import SpeakLifeCore

enum StandLink {

    /// Mirrors CODE_ALPHABET in functions/standTogether.js. Both halves of each
    /// confusable pair are excluded (0/O, 1/I/L), so a typed `0` or `I` cannot
    /// be valid under any reading — it is rejected rather than guessed at.
    /// Guessing is how somebody lands in the wrong family's stand.
    static let alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    static let codeLength = 8

    /// The invite code in a URL, or nil when this is not a stand link.
    ///
    /// Never matches on the link's DOMAIN: the invite works from the Branch
    /// host, from a custom scheme, and from anything the marketing site might
    /// front it with later, and none of those should need a code change here.
    /// That is what makes `shareHost` safe to move remotely — an old link and
    /// a new one both still parse.
    static func code(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)

        // `speaklife://stand/ABCD2345` puts "stand" in the HOST and the code
        // alone in the path, so the path scan below never sees the marker and
        // returned nil for every custom-scheme open. The doc comment above has
        // claimed this shape works since the file was written; now it does.
        // It is the shape the web fallback's "Open in SpeakLife" button uses.
        if let host = url.host, host.caseInsensitiveCompare("stand") == .orderedSame,
           let first = parts.first {
            return normalize(first)
        }

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

    /// Remote Config key for the host invites are minted on.
    static let domainKey = "standLinkDomain"

    /// The host stand invites are SENT on.
    ///
    /// ⚠️ THIS MUST NOT BE A DOMAIN ALREADY-SHIPPED BUILDS CLAIM, and
    /// `speaklife.app.link` is exactly that. It went into
    /// `associated-domains` on 2026-08-29, twelve minutes before the 4.59
    /// version bump, so every build from 4.59 onward tells iOS it owns every
    /// path on it — including `/stand/…`, which none of them can handle.
    ///
    /// The result is the worst possible failure: iOS hands the link to the
    /// installed app, the app opens, `onOpenURL` finds no branch for it, and
    /// the invite evaporates with no error and no App Store prompt. At the
    /// time of writing that is 98% of the active base (2,026 of 2,067 over 14
    /// days). The typed code is no fallback either, because `StandJoinView`
    /// ships in the same build.
    ///
    /// A host those builds do NOT claim fails correctly instead: iOS cannot
    /// match it, so it opens in Safari, and Branch's own page offers the App
    /// Store. Configure a custom link domain in Branch, point DNS at it, and
    /// set this key — see docs/STAND_TOGETHER_HANDOFF.md, "Step 2d".
    ///
    /// Remote Config rather than a constant because the domain has to be
    /// changeable without a build, and because the default below is
    /// deliberately the BROKEN one: shipping a guess at a domain nobody owns
    /// would break the link for everybody instead of just for old builds.
    /// Setting the key is a required launch step, not a tuning knob.
    static var shareHost: String {
        DefaultFeatureFlags.shared.string(domainKey, default: "speaklife.app.link")
    }

    static func shareURL(for code: String) -> URL? {
        URL(string: "https://\(shareHost)/stand/\(code)")
    }
}
