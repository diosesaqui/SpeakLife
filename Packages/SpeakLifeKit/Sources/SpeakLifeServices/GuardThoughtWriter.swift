//
//  GuardThoughtWriter.swift
//  SpeakLife
//
//  Writes the counter-declaration for a thought the user typed, using the
//  Anthropic Messages API.
//
//  **This file sends the user's words off the device.** It is the only place in
//  Guarding that does, it runs for every user, and the ASK screen's copy changes
//  to say so when it is going to happen. If that copy ever drifts back to "it
//  stays on this phone" while this path is live, the app is lying at the worst
//  possible moment — see `AskForThoughtView.privacyLine`.
//
//  It is not gated on premium, and that is deliberate. Whatever someone is up
//  against, the line they speak has to be about that exact thing, and a tier
//  check here decided that most people got something adjacent instead. The only
//  gate left is `isConfigured` — no key from Remote Config, no request — which
//  doubles as the kill switch if this ever needs to be turned off in a hurry.
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
//     to parse: every path falls back to the on-device match, which draws from
//     the reviewed library the app already ships. Nobody is left holding the
//     thought because a request failed.
//
//  Separate from `ClaudeDeclarationMatcher` on purpose — same endpoint, same key,
//  same model, different question. That one answers "here is my prayer need,
//  write me a declaration". This one answers "here is what is coming at me:
//  rebuke it by name, then tell me who I am." The framing changes the output,
//  and the nine Guard terrains are not the same set as `DeclarationCategory`.
//
//  **It returns two lines, and they have opposite jobs.** The REBUKE names the
//  thing exactly and puts it out — the one place in the app where naming it is
//  the point, under the warfare exception in rule 12 of CLAUDE.md, because Jesus
//  did not affirm around the storm, He spoke to it. The DECLARATION never names
//  it and fills the room it left, which is not optional: Matthew 12:43-45 is a
//  house swept clean and left empty.
//

import Foundation
import SpeakLifeCore

/// What Claude wrote for a thought, in the shape Guarding needs.
public struct WrittenCounter: Equatable {
    public let category: ThoughtCategory
    /// The word spoken TO the thing, naming it exactly. Empty when the model
    /// returned one that failed review — the caller substitutes the mapped line
    /// for the terrain rather than dropping the rebuke.
    public let rebuke: String
    public let declaration: String
    public let verseText: String
    public let book: String
}

public enum GuardWriterError: Error {
    case notConfigured
    case httpError(statusCode: Int)
    case emptyResponse
    case invalidJSON
    /// Claude read it and will not write for it. Distinct from a failure: the
    /// caller must NOT fall back to the keyword matcher, because answering a
    /// refusal with a generated declaration defeats the refusal.
    case declined
}

public final class GuardThoughtWriter {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public var isConfigured: Bool { !AnthropicConfig.apiKey.isEmpty }

    /// - Parameter thought: the user's own words. Sent, never stored.
    public func write(thought: String) async throws -> WrittenCounter {
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

        // The rebuke is optional HERE and required by the time it is spoken.
        // A model that returns everything else correctly and forgets this one
        // field must not cost someone the whole written answer — the caller
        // fills the gap from the terrain's mapped line.
        return WrittenCounter(category: category,
                              rebuke: parsed.rebuke ?? "",
                              declaration: declaration,
                              verseText: verseText,
                              book: book)
    }

    // MARK: - Prompt

    /// The declaration rules from `CLAUDE.md`, plus the one thing that makes
    /// this different from the prayer-need prompt: the input is a lie, and the
    /// output has to displace it rather than answer it.
    static let systemPrompt = """
    You write what someone speaks out loud in SpeakLife's "Take It Captive" \
    drill. They have typed what they are up against right now, in their own \
    words: a thought, a diagnosis, a bill, a marriage ending, a child who \
    stopped calling. Answer the thing they actually named.

    They speak TWO lines, in this order, and both are yours to write:

    1. THE REBUKE, spoken to the thing itself, naming it exactly.
    2. THE DECLARATION, spoken over their own life, never naming it.

    That order is the whole drill. Jesus did not think His way around the storm \
    or affirm over the top of it. He spoke to it, and then it was done. And a \
    house swept clean and left empty gets worse, not better, so the thing is \
    never put out without the truth taking its place.

    Return ONLY JSON:
    {"terrain": "...", "rebuke": "...", "declaration": "...", "verseText": "...", "book": "..."}

    "terrain" is exactly one of: fear, condemnation, lack, rejection, sickness, \
    inadequacy, abandonment, confusion, lust.
    Pick the terrain the thought actually lives in. A thought about illness or \
    the body is "sickness" even when it is phrased as worry. A thought about \
    money is "lack". A thought about being unwanted is "rejection".

    THE REBUKE:
    - Name it exactly, in their own word for it: the cancer, the debt, the \
      divorce, the drinking, the panic, the diagnosis. This is the ONE line that \
      says it out loud, because you cannot command what you will not name.
    - Speak TO it, not about it. "Cancer, you have no claim on my mother's \
      body." "Debt, you have no hold on my future."
    - Command, never ask. No "God, please", no "I pray". Jesus said "Quiet! Be \
      still" and "Come out of him", and that is the register.
    - 4 to 12 words, one or two short sentences, with the drop at the end.
    - NEVER command a person. Not their spouse, their child, their boss, not \
      anyone. Command the thing over them instead: "Addiction, you have no claim \
      on my son" is right; ordering the son is not, because no scripture gives \
      anyone authority over another person's will.
    - Never aimed at the speaker either. No "you" pointed back at them.

    THE DECLARATION:
    - Answers with a finished fact about them, not advice, encouragement, or a \
      promise to try harder. They are not becoming this; they already are it.
    - First person only: I / me / my / mine.
    - Present tense, spoken as already done. "I am." "I have." Never "I will" \
      or "I hope".
    - ONE sentence, 10 to 18 words. Compression is the power.
    - Plain words anyone grasps on the first read. No poetry, no riddles, no \
      churchy vocabulary the speaker would have to decode.
    - Built for the mouth. Easy to say out loud in one breath.
    - No em dashes or en dashes.
    - NEVER name the thing the rebuke just named. Do not mention the fear, the \
      sickness, the lack, the shame, not even to overrule it. Declare the higher \
      reality that makes it irrelevant, in the exact domain it lives in. A \
      thought about a body gets a declaration about that body being whole.
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
        let rebuke: String?
        let declaration: String?
        let verseText: String?
        let book: String?
    }
}
