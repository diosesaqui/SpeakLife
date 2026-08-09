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

/// What we can honestly hand someone seven days of scripture for.
///
/// Without this, "I'm believing for another man's wife to leave him for me"
/// matches `marriage` and `love` cleanly and the app builds a week of
/// declarations aimed at it. That is worse than failing: it puts scripture in
/// someone's mouth over something scripture does not say.
///
/// Two layers, because neither is enough on its own:
///
/// 1. **This local screen.** Unmistakable phrases only. It runs before any
///    network call, so a dead connection cannot skip it — which matters,
///    because when the network is down both Claude layers fall back to keyword
///    matching and this is the only guard left standing.
/// 2. **Claude, inside `curate`.** It reads intent the way a keyword list never
///    will, and catches the wording nobody thought to enumerate.
///
/// Precision over recall on layer 1, deliberately. A false positive tells a
/// grieving person their pain is out of bounds, which is far more costly than a
/// miss that layer 2 picks up. Every phrase below was checked against the real
/// input it could collide with — "my husband's affair", "believing God will
/// make them pay what they owe", "I want to die to self" — and the ones that
/// collided were removed rather than tightened.
///
/// The answer is never a scolding. We decline the object, name the real need
/// underneath it, and offer to build the week on that instead. Someone who
/// typed something they shouldn't stand on still opened this app wanting God.
enum SituationScreen {

    struct Redirect: Equatable {
        /// Short code for analytics. Never shown to anyone.
        let reason: String
        /// What the person reads.
        let message: String
        /// The week we can honestly build instead. Nil when there's nothing
        /// specific to offer and the right move is letting them retype.
        let offerTitle: String?
        let offerCategory: DeclarationCategory?

        static let anotherPersonsPartner = Redirect(
            reason: "another_persons_partner",
            message: "We won't build a week on someone else's marriage. But God has a covenant love with your name on it, and that will hold for seven days.",
            offerTitle: "Stand on God's love for me",
            offerCategory: .love
        )

        static let harmToAnother = Redirect(
            reason: "harm_to_another",
            message: "Scripture won't put another person's harm in your mouth. What was done to you is real, though. Let's build the week on what heals you.",
            offerTitle: "Stand on my healing",
            offerCategory: .innerHealing
        )

        /// Claude saw something it can't back but that doesn't fit either box.
        static let unscriptural = Redirect(
            reason: "unscriptural",
            message: "We couldn't find scripture to stand on for that one. Tell us what's underneath it and we'll build the week on ground that holds.",
            offerTitle: nil,
            offerCategory: nil
        )
    }

    enum Verdict: Equatable {
        case standable
        case redirect(Redirect)
        /// Someone said they want to end their life. No campaign and no
        /// correction — seven days of declarations is not what this moment is.
        case reachOut
    }

    /// Support address, the same one `ProfileView`, `MailView`, and
    /// `BibleChatView` already use.
    static let supportEmail = "speaklife@diosesaqui.com"

    /// One copy, used by the campaign card and the personal-declaration flow, so
    /// the two can never drift into saying different things at the worst moment
    /// the app has.
    ///
    /// The order is deliberate. "Someone you trust, right now" is the real-time
    /// action; the address is offered after it, as care rather than as the
    /// emergency path, because email is not answered in the moment. Nothing here
    /// argues, corrects, or quotes scripture at them.
    static let reachOutHeadline = "Please don't carry this alone."
    static let reachOutMessage = """
        Reach out to someone you trust right now, before anything else. \
        You can write us any time at \(supportEmail). You are not a burden, \
        and you are not too far gone.
        """

    static func screen(_ input: String) -> Verdict {
        let text = input.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")

        if unambiguousSelfHarm.contains(where: text.contains) { return .reachOut }
        if ambiguousSelfHarm.contains(where: text.contains),
           !selfHarmExemptions.contains(where: text.contains) { return .reachOut }

        if partnerPhrases.contains(where: text.contains) { return .redirect(.anotherPersonsPartner) }
        if harmPhrases.contains(where: text.contains) { return .redirect(.harmToAnother) }

        return .standable
    }

    /// Possessive constructions that cannot mean anything else. Deliberately
    /// missing: "a married man", "an affair", "affair with" — each collides
    /// with the most common legitimate input of all, someone believing for
    /// their own marriage after their spouse's affair.
    /// Also deliberately missing: "leave his wife" / "leave her husband" — a
    /// parent praying their child gets out of an abusive marriage says exactly
    /// that. And "his mistress", which is how a betrayed spouse names the other
    /// woman. Both were here and both were wrong.
    static let partnerPhrases = [
        "someone else's husband", "someone elses husband",
        "someone else's wife", "someone elses wife",
        "somebody else's husband", "somebody elses husband",
        "somebody else's wife", "somebody elses wife",
        "another man's wife", "another mans wife",
        "another woman's husband", "another womans husband",
        "side chick", "my mistress"
    ]

    /// Deliberately missing: "make him/her/them pay" — "believing God will make
    /// them pay me what they owe" is a debt campaign, not a curse. "get back at"
    /// is spelled out with an object for the same reason: bare, it swallows
    /// "I'm ready to get back at it".
    static let harmPhrases = [
        "get revenge", "take revenge",
        "get back at him", "get back at her", "get back at them",
        "make him suffer", "make her suffer", "make them suffer",
        "ruin his life", "ruin her life", "ruin their life",
        "hope he dies", "hope she dies", "hope they die",
        "curse him", "curse her", "curse them"
    ]

    /// First person only, and spelled out. Bare "suicide" and bare "suicidal"
    /// were here and routed "I lost my son to suicide" — a bereaved parent — to
    /// a personal-safety message with no campaign and no scripture. That is the
    /// single worst thing this screen could do, so the word alone is not enough:
    /// it has to be them, saying it about themselves.
    static let unambiguousSelfHarm = [
        "kill myself", "killing myself",
        "end my life", "ending my life",
        "take my own life", "taking my own life",
        "no reason to live", "nothing to live for",
        "better off dead", "better off without me",
        "hurt myself", "harm myself",
        "i am suicidal", "i'm suicidal", "im suicidal",
        "been suicidal", "feel suicidal", "feeling suicidal",
        "thoughts of suicide", "thinking about suicide", "commit suicide"
    ]

    /// These need the rest of the sentence before they mean anything.
    static let ambiguousSelfHarm = ["want to die", "wanna die", "don't want to live", "dont want to live"]

    /// "I want to die to self" is Romans 6, not a crisis. So is dying to sin,
    /// to the flesh, and dying daily. Checked only against the ambiguous list,
    /// so it can never suppress "kill myself".
    static let selfHarmExemptions = [
        "die to self", "die to sin", "die to my flesh", "die to the flesh",
        "dying to self", "dying to sin", "dying to my flesh", "die daily"
    ]
}

/// What came back from describing a situation. The card needs more than a Bool:
/// a decline keeps their text and offers a different week, a failure keeps their
/// text and says try again, and they must not look the same.
enum EnforcementStartResult: Equatable {
    case started
    case failed
    case declined(SituationScreen.Redirect)
    case reachOut
}

enum EnforcementCurator {

    /// How many candidates to put in front of the model. Enough to choose well,
    /// small enough to keep the request cheap and fast at campaign start.
    static let candidateLimit = 40

    struct Curation {
        let days: [Declaration]
        /// True when Claude did the choosing; false when we fell back.
        let wasCurated: Bool
    }

    /// The second screening layer, and the reason it lives here rather than in
    /// its own call: Claude is already reading the sentence to choose the week,
    /// so refusing to choose costs nothing extra.
    enum Outcome: Equatable {
        case curated([Declaration])
        /// Claude read it and won't back it.
        case declined(SituationScreen.Redirect)
        /// No key, no network, or an unparseable reply. The caller falls
        /// through to keyword assembly: a dead connection must never cost
        /// someone a legitimate week.
        case unavailable
    }

    /// - Parameters:
    ///   - situation: the user's own words.
    ///   - candidates: reviewed declarations from the matched categories.
    /// - Returns: seven declarations in the order they should be spoken, a
    ///   decline, or `.unavailable`.
    static func curate(situation: String,
                       candidates: [Declaration],
                       session: URLSession = .shared) async -> Outcome {
        guard candidates.count >= Enforcement.length else { return .unavailable }
        let apiKey = AnthropicConfig.apiKey
        guard !apiKey.isEmpty else { return .unavailable }

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

        If you cannot back what they are asking for, return \
        {"decline":"<code>"} instead, using one of: another_persons_partner, \
        harm_to_another, unscriptural.
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

            Decline only when scripture plainly cannot back what they are asking \
            for: another person's spouse or partner, harm or loss coming to \
            someone, or an outright sin named as the thing they want. \
            Everything a believer could honestly bring to God is fine to \
            curate, including bitter, angry, doubting, or desperate wording, \
            and including anger at God himself. Grief, divorce, addiction, \
            bankruptcy, an affair done to them, and hating their job are all \
            normal weeks. When unsure, curate.
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
                return .unavailable
            }
            let decoded = try JSONDecoder().decode(ClaudeCurationResponse.self, from: data)
            guard let text = decoded.content.first(where: { $0.type == "text" })?.text,
                  let json = extractJSON(from: text),
                  let picks = try? JSONDecoder().decode(CuratedResponse.self, from: json) else {
                AnalyticsService.shared.track("enforcement_curation_failed",
                                              parameters: ["reason": "unparseable"])
                return .unavailable
            }

            // A decline is an answer, not a failure. It must never fall through
            // to keyword assembly, which would build the week Claude just
            // refused to build.
            if let code = picks.decline, !code.isEmpty {
                AnalyticsService.shared.track("enforcement_input_screened",
                                              parameters: ["verdict": code, "layer": "claude"])
                return .declined(redirect(forCode: code))
            }

            // Trust nothing: drop out-of-range and duplicate indexes rather than
            // crash or serve the same line twice.
            var seen = Set<Int>()
            let chosen = (picks.days ?? [])
                .filter { $0 >= 0 && $0 < shortlist.count && seen.insert($0).inserted }
                .map { shortlist[$0] }

            guard chosen.count == Enforcement.length else {
                AnalyticsService.shared.track("enforcement_curation_failed",
                                              parameters: ["reason": "wrong_count_\(chosen.count)"])
                return .unavailable
            }
            AnalyticsService.shared.track("enforcement_curated")
            return .curated(chosen)
        } catch {
            AnalyticsService.shared.track("enforcement_curation_failed",
                                          parameters: ["reason": "\(error)"])
            return .unavailable
        }
    }

    /// An unrecognized code still declines. A model that invents a reason has
    /// still told us it won't back this, and guessing a week from that is the
    /// one thing worse than a vague message.
    static func redirect(forCode code: String) -> SituationScreen.Redirect {
        switch code {
        case SituationScreen.Redirect.anotherPersonsPartner.reason: return .anotherPersonsPartner
        case SituationScreen.Redirect.harmToAnother.reason:         return .harmToAnother
        default:                                                    return .unscriptural
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

/// Both fields optional: the model answers with one or the other, never both.
private struct CuratedResponse: Decodable {
    let days: [Int]?
    let decline: String?
}
