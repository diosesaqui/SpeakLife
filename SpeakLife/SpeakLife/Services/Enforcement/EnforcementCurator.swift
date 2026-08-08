//
//  EnforcementCurator.swift
//  SpeakLife
//
//  Picks the seven declarations for someone's week from what they actually said.
//
//  Keyword matching gets you a category. "My wife left and I'm drinking again"
//  becomes `marriage` + `addiction`, and then seven generic lines out of those
//  buckets. That's better than four fixed themes but it still isn't *their* week.
//
//  This asks Claude to read the sentence and choose from the reviewed pool. It
//  returns INDEXES, never text, so the model cannot introduce a line that hasn't
//  already passed the rules in CLAUDE.md — the personalization is in the
//  selection and the ordering, not in the writing.
//
//  Every failure path falls back to `EnforcementAssembler`, so a dead network,
//  a missing key, or a malformed response still produces a real campaign.
//

import Foundation

enum EnforcementCurator {

    /// How many candidates to put in front of the model. Enough to choose well,
    /// small enough to keep the request cheap and fast at campaign start.
    static let candidateLimit = 40

    struct Curation {
        let days: [Declaration]
        /// True when Claude did the choosing; false when we fell back.
        let wasCurated: Bool
    }

    /// - Parameters:
    ///   - situation: the user's own words.
    ///   - candidates: reviewed declarations from the matched categories.
    /// - Returns: seven declarations in the order they should be spoken.
    static func curate(situation: String,
                       candidates: [Declaration],
                       session: URLSession = .shared) async -> [Declaration]? {
        guard candidates.count >= Enforcement.length else { return nil }
        let apiKey = AnthropicConfig.apiKey
        guard !apiKey.isEmpty else { return nil }

        let shortlist = Array(candidates.prefix(candidateLimit))
        let numbered = shortlist.enumerated()
            .map { "\($0.offset). \($0.element.text)" }
            .joined(separator: "\n")

        let prompt = """
        Someone is starting a seven-day campaign. In their words, this is what \
        they are walking through:

        "\(situation)"

        Below are numbered declarations they could speak. Choose exactly \
        \(Enforcement.length) and order them as a seven-day arc: start where they \
        are, end where God is taking them.

        \(numbered)

        Return only JSON: {"days":[<seven distinct indexes, in order>]}
        """

        var request = URLRequest(url: AnthropicConfig.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        let body = ClaudeCurationRequest(
            model: AnthropicConfig.model,
            maxTokens: 256,
            system: """
            You select scripture declarations for a seven-day campaign. You never \
            write declarations; you only choose from the numbered list you are \
            given. Prefer a set that speaks to the person's actual situation and \
            builds across the week. Respond with JSON only.
            """,
            messages: [.init(role: "user", content: prompt)]
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                AnalyticsService.shared.track("enforcement_curation_failed",
                                              parameters: ["reason": "http_\(status)"])
                return nil
            }
            let decoded = try JSONDecoder().decode(ClaudeCurationResponse.self, from: data)
            guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
                  let json = extractJSON(from: text),
                  let picks = try? JSONDecoder().decode(CuratedDays.self, from: json) else {
                AnalyticsService.shared.track("enforcement_curation_failed",
                                              parameters: ["reason": "unparseable"])
                return nil
            }

            // Trust nothing: drop out-of-range and duplicate indexes rather than
            // crash or serve the same line twice.
            var seen = Set<Int>()
            let chosen = picks.days
                .filter { $0 >= 0 && $0 < shortlist.count && seen.insert($0).inserted }
                .map { shortlist[$0] }

            guard chosen.count == Enforcement.length else {
                AnalyticsService.shared.track("enforcement_curation_failed",
                                              parameters: ["reason": "wrong_count_\(chosen.count)"])
                return nil
            }
            AnalyticsService.shared.track("enforcement_curated")
            return chosen
        } catch {
            AnalyticsService.shared.track("enforcement_curation_failed",
                                          parameters: ["reason": "\(error)"])
            return nil
        }
    }

    private static func extractJSON(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        return String(text[start...end]).data(using: .utf8)
    }
}

// MARK: - Wire types

private struct ClaudeCurationRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    struct Message: Encodable { let role: String; let content: String }

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

private struct ClaudeCurationResponse: Decodable {
    let content: [Block]
    struct Block: Decodable { let type: String; let text: String? }
}

private struct CuratedDays: Decodable {
    let days: [Int]
}
