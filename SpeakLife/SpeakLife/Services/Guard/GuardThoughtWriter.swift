//
//  GuardThoughtWriter.swift
//  SpeakLife
//
//  Writes the counter-declaration for a thought the user typed, using the
//  Anthropic Messages API.
//
//  **This file sends the user's words off the device.** It is the only place in
//  Guarding that does, it runs for premium users only, and the ASK screen's copy
//  changes to say so when it is going to happen. If that copy ever drifts back
//  to "it stays on this phone" while this path is live, the app is lying at the
//  worst possible moment — see `AskForThoughtView.privacyLine`.
//
//  What is still true, and must stay true:
//
//  1. **Crisis screening runs locally and FIRST.** `ThoughtClassifier` screens
//     before it ever calls this. Someone typing that they want to end their life
//     gets a person, not a network round trip.
//  2. **The text is never stored, synced, or logged.** It exists for the length
//     of one request. `CapturedThought` still has no text field, and no
//     analytics event carries the sentence — only the matched terrain.
//  3. **A failure is never a dead end.** Offline, no key, a timeout, a refusal
//     to parse: every path falls back to the on-device keyword match, which is
//     what free users get anyway. Nobody is left holding the thought because a
//     request failed.
//
//  Separate from `ClaudeDeclarationMatcher` on purpose. That one answers "here
//  is my prayer need, write me a declaration". This one answers a different
//  question: "here is a lie I am carrying, write the truth that displaces it."
//  The framing changes the output, and the nine Guard terrains are not the same
//  set as `DeclarationCategory`.
//

import Foundation

/// What Claude wrote for a thought, in the shape Guarding needs.
struct WrittenCounter: Equatable {
    let category: ThoughtCategory
    let declaration: String
    let verseText: String
    let book: String
}

enum GuardWriterError: Error {
    case notConfigured
    case httpError(statusCode: Int)
    case emptyResponse
    case invalidJSON
    /// Claude read it and will not write for it. Distinct from a failure: the
    /// caller must NOT fall back to the keyword matcher, because answering a
    /// refusal with a generated declaration defeats the refusal.
    case declined
}

final class GuardThoughtWriter {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isConfigured: Bool { !AnthropicConfig.apiKey.isEmpty }

    /// - Parameter thought: the user's own words. Sent, never stored.
    func write(thought: String) async throws -> WrittenCounter {
        let apiKey = AnthropicConfig.apiKey
        guard !apiKey.isEmpty else { throw GuardWriterError.notConfigured }

        var request = URLRequest(url: AnthropicConfig.apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Shorter than the personal-declaration matcher's 15s. This one runs
        // while someone is staring at a button they just pressed, so a slow
        // answer is worse than the keyword answer arriving now.
        request.timeoutInterval = 8

        let body = Request(
            model: AnthropicConfig.model,
            maxTokens: 400,
            system: Self.systemPrompt,
            messages: [.init(role: "user", content: "The thought: \(thought)")]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GuardWriterError.httpError(statusCode: 0)
        }
        guard http.statusCode == 200 else {
            throw GuardWriterError.httpError(statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw GuardWriterError.emptyResponse
        }

        let parsed = try JSONDecoder().decode(WrittenJSON.self, from: Self.extractJSON(from: text))

        // Checked before anything else is read, and the other fields are
        // optional so this can be reached at all.
        //
        // They were non-optional, which meant a decline — which the prompt asks
        // for as `{"terrain": "decline"}` with the rest empty or absent — threw
        // `keyNotFound` during decoding instead. That surfaced as a generic
        // failure, the caller's `catch` answered it with the keyword matcher,
        // and a refusal got a written declaration anyway. Exactly the
        // fallthrough `declined` exists to stop.
        guard parsed.terrain != "decline" else { throw GuardWriterError.declined }

        guard let category = ThoughtCategory(rawValue: parsed.terrain),
              let declaration = parsed.declaration, !declaration.isEmpty,
              let verseText = parsed.verseText, !verseText.isEmpty,
              let book = parsed.book, !book.isEmpty else {
            // A well-formed response naming a terrain we do not have is still a
            // miss. Better to fall back than to serve an empty card.
            throw GuardWriterError.invalidJSON
        }

        return WrittenCounter(category: category,
                              declaration: declaration,
                              verseText: verseText,
                              book: book)
    }

    // MARK: - Prompt

    /// The declaration rules from `CLAUDE.md`, plus the one thing that makes
    /// this different from the prayer-need prompt: the input is a lie, and the
    /// output has to displace it rather than answer it.
    static let systemPrompt = """
    You write counter-declarations for SpeakLife's "Take It Captive" drill. The \
    user has typed a thought about themselves or their future that does not line \
    up with who they already are in Christ. You write the one line they will \
    speak out loud to displace it.

    The declaration answers the thought with a finished fact about them, not \
    with advice, encouragement, or a promise to try harder. They are not \
    becoming this; they already are it.

    Return ONLY JSON:
    {"terrain": "...", "declaration": "...", "verseText": "...", "book": "..."}

    "terrain" is exactly one of: fear, condemnation, lack, rejection, sickness, \
    inadequacy, abandonment, confusion, lust.
    Pick the terrain the thought actually lives in. A thought about illness or \
    the body is "sickness" even when it is phrased as worry. A thought about \
    money is "lack". A thought about being unwanted is "rejection".

    THE DECLARATION:
    - First person only: I / me / my / mine.
    - Present tense, spoken as already done. "I am." "I have." Never "I will" \
      or "I hope".
    - ONE sentence, 10 to 18 words. Compression is the power.
    - Plain words anyone grasps on the first read. No poetry, no riddles, no \
      churchy vocabulary the speaker would have to decode.
    - Built for the mouth. Easy to say out loud in one breath.
    - No em dashes or en dashes.
    - NEVER name the thing being displaced. Do not mention the fear, the \
      sickness, the lack, the shame, not even to overrule it. Declare the \
      higher reality that makes it irrelevant, in the exact domain it lives in. \
      A thought about a body gets a declaration about that body being whole.
    - Never soften what scripture actually promises. If the verse says it, say \
      it finished and say it flat.
    - Never promise what scripture does not: that another free person will \
      change, or any specific outcome no verse states.

    "verseText" is the scripture the declaration stands on, quoted accurately, \
    NIV preferred. "book" is its reference, like "Isaiah 53:5".

    Return terrain "decline" with all other fields empty ONLY if the thought \
    asks for harm to someone, or for another person's spouse.
    """

    // MARK: - Wire types

    private static func extractJSON(from text: String) throws -> Data {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end,
              let data = String(text[start...end]).data(using: .utf8) else {
            throw GuardWriterError.invalidJSON
        }
        return data
    }

    private struct Request: Encodable {
        let model: String
        let maxTokens: Int
        let system: String
        let messages: [Message]

        struct Message: Encodable {
            let role: String
            let content: String
        }

        enum CodingKeys: String, CodingKey {
            case model, system, messages
            case maxTokens = "max_tokens"
        }
    }

    private struct Response: Decodable {
        let content: [Block]
        struct Block: Decodable {
            let type: String
            let text: String?
        }
    }

    /// Only `terrain` is required. The rest are optional so a decline — which
    /// carries no declaration by definition — decodes cleanly and can be
    /// recognised, instead of failing as a malformed response.
    private struct WrittenJSON: Decodable {
        let terrain: String
        let declaration: String?
        let verseText: String?
        let book: String?
    }
}
