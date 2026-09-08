//
//  Magnify.swift
//  SpeakLifeCore
//
//  Magnifying the Lord — the fifth pillar. "Magnify the Lord with me, and let
//  us exalt his name together." (Psalm 34:3)
//
//  This replaces Take It Captive, and the replacement is a deliberate inversion
//  rather than a rename. That drill worked by naming the low thing and throwing
//  it off the screen. This one never names it at all: it enlarges God until the
//  thing is in proportion, which is what magnifying has always meant.
//
//  Magnifying does not make God bigger. He is already infinite, and nothing a
//  person says adds a inch to Him. It makes Him bigger TO THE SPEAKER. A
//  telescope never moved a mountain; it filled the eye with it. That sentence is
//  the whole product.
//
//  Four rules carry the feature and must survive every future edit:
//
//  1. **The count is cumulative and never resets.** No streak, no "days missed",
//     no chart. A broken streak tells a believer mid-storm that they failed at
//     worship, which is law, and the exact inversion of this app's grace-first
//     positioning. Inherited unchanged from the drill this replaces, along with
//     its storage key, so nobody's total moved on upgrade day.
//  2. **The loop terminates in SPEAKING, always.** Hearing and Quiet Time end at
//     receiving; this one ends at words out loud. Anything that makes this feel
//     like journaling or like reading a devotional is the wrong change.
//  3. **The low thing is never named.** Not by the app, not in a model name, not
//     in a domain's raw value. This is what `TakeItCaptive.swift` had to carve a
//     standing exception to CLAUDE.md rule 12 for, and the exception is gone:
//     every string in this feature points up. The one place a user may still put
//     a name to what they are carrying is the optional written route, in their
//     own words, and the app answers it by exalting God over that domain rather
//     than by repeating it back.
//  4. **It works when there is nothing to say.** The old front door asked
//     "what are you up against?" and required a typed sentence. At 7am nothing
//     is queued, and at 2am in a real storm articulating the worst thing in your
//     head is the last thing a person can do. Magnifying needs no input at all —
//     you can always exalt God — so the daily task is reachable in one tap and
//     Storm mode is reachable in none.
//

import Foundation

// MARK: - Domain

/// The nine domains a person lifts God over.
///
/// The raw values ARE the higher reality — `peace`, `provision`, `healing` —
/// never the thing being displaced. This is the same nine terrains the drill
/// this replaces mapped to, so the declaration library routing carries over
/// intact, but there is no longer a low-side name anywhere in the type.
/// `MagnifyService.migrateLegacyEngagement` maps a returning user's old
/// engagement weights onto these.
public enum MagnifyDomain: String, Codable, CaseIterable, Identifiable {
    case peace
    case grace
    case provision
    case belonging
    case healing
    case identity
    case nearness
    case clarity
    case purity

    public var id: String { rawValue }

    /// How the domain is offered on the opening screen. Possessive and concrete
    /// — someone taps the part of their life they want God lifted over, not a
    /// mood and not a diagnosis.
    public var chipTitle: String {
        switch self {
        case .peace:     return "My mind"
        case .grace:     return "My past"
        case .provision: return "My provision"
        case .belonging: return "My people"
        case .healing:   return "My body"
        case .identity:  return "Who I am"
        case .nearness:  return "My heart"
        case .clarity:   return "My next step"
        case .purity:    return "My walk"
        }
    }

    /// SF Symbol for the chip.
    public var icon: String {
        switch self {
        case .peace:     return "brain.head.profile"
        case .grace:     return "arrow.uturn.backward.circle"
        case .provision: return "basket"
        case .belonging: return "person.2"
        case .healing:   return "heart.text.square"
        case .identity:  return "person.crop.circle.badge.checkmark"
        case .nearness:  return "hands.and.sparkles"
        case .clarity:   return "signpost.right"
        case .purity:    return "flame"
        }
    }

    /// The word used when naming ground the speaker has covered — "You've been
    /// magnifying Him a lot over your provision". Never a label on them.
    public var groundName: String {
        switch self {
        case .peace:     return "peace"
        case .grace:     return "grace"
        case .provision: return "provision"
        case .belonging: return "belonging"
        case .healing:   return "healing"
        case .identity:  return "identity"
        case .nearness:  return "God's nearness"
        case .clarity:   return "clarity"
        case .purity:    return "freedom"
        }
    }

    /// The line spoken when nothing else is available — offline, a bank that
    /// failed to load, a written entry the classifier could not place.
    ///
    /// Nine lines, one per domain, and every one of them is addressed TO God.
    /// Compare `ThoughtCategory.rebuke`, which this replaces: those commanded
    /// the thing by name and were the app's one sanctioned exception to
    /// CLAUDE.md rule 12. Nothing here needs that exception.
    public var fallbackExaltation: String {
        switch self {
        case .peace:     return "You are the Prince of Peace. You are Lord over every storm."
        case .grace:     return "You are the Lamb of God. You took it all, and it is finished."
        case .provision: return "You are Jehovah Jireh. You see ahead and You provide."
        case .belonging: return "You call me by name. I am Yours."
        case .healing:   return "You are Jehovah Rapha. You are the God who heals."
        case .identity:  return "You are my Maker. You do not make mistakes."
        case .nearness:  return "You are Immanuel. God with me, right here."
        case .clarity:   return "You are the Light of the World. In Your light I see."
        case .purity:    return "You make clean. What You wash stays washed."
        }
    }

    /// Where this domain draws its declarations from, best first. Mirrors
    /// `SOURCES` in the content generator, and is what lets a written entry
    /// reach the whole reviewed library rather than only the bundled bank.
    public var declarationCategories: [DeclarationCategory] {
        switch self {
        case .peace:     return [.fear, .anxiety, .godsprotection]
        case .grace:     return [.grace, .forgiveness, .addiction]
        case .provision: return [.wealth, .debt, .housing]
        case .belonging: return [.love, .friendship, .innerHealing]
        case .healing:   return [.health, .wellness, .mentalHealth]
        case .identity:  return [.identity, .confidence, .destiny]
        case .nearness:  return [.hope, .innerHealing, .rest]
        case .clarity:   return [.wisdom, .faith, .destiny]
        case .purity:    return [.purity, .addiction]
        }
    }

    /// Turns a `DeclarationCategory` from the shared matcher into a domain, so
    /// the optional written route can land somewhere. Carried over verbatim from
    /// `ThoughtCategory.from(_:)` — the routing judgements in it were argued out
    /// once and none of them changed when the feature inverted.
    public static func from(_ declarationCategory: DeclarationCategory) -> MagnifyDomain? {
        switch declarationCategory {
        case .fear, .godsprotection, .warfare, .anxiety:
            return .peace
        case .purity:
            return .purity
        // `.addiction` deliberately stays on grace rather than moving to
        // `.purity`. It also carries alcohol, drugs, and every other compulsion,
        // and the keyword rule that owns it fires before the purity rule — so
        // routing it there would send someone fighting a bottle to declarations
        // about their eyes. Grace is the right medicine for the shame under any
        // of them.
        case .grace, .forgiveness, .addiction, .salvation:
            return .grace
        case .wealth, .debt, .housing, .work, .business, .education:
            return .provision
        case .love, .friendship, .marriage, .relationship, .divorce, .singleParent:
            return .belonging
        case .health, .wellness, .fertility, .mentalHealth:
            return .healing
        case .identity, .confidence, .destiny, .favor:
            return .identity
        case .rest, .hardtimes, .grief, .innerHealing, .hope, .joy, .anger:
            return .nearness
        case .faith, .wisdom, .spiritualGrowth, .miracles, .obedience:
            return .clarity
        // Parenting sits on identity rather than on the child. What arrives as
        // "I am ruining my kids" is a thought about the speaker's adequacy, and
        // that is the only half of it scripture lets a declaration settle — the
        // child is a free person (CLAUDE.md rule 6). `.singleParent` is already
        // claimed above by belonging, where the ache of doing it alone lives.
        case .parenting, .newSeason:
            return .identity
        // Praise, gratitude and heaven all answer the same ache: that God is
        // distant or has stopped paying attention.
        case .praise, .gratitude, .heaven, .godsheart:
            return .nearness
        default:
            return nil
        }
    }

    /// Legacy `ThoughtCategory` raw value → domain. Used once, to carry a
    /// returning user's engagement weights across the rename so the rotation
    /// does not forget where their fight has been.
    public static func fromLegacyRawValue(_ raw: String) -> MagnifyDomain? {
        switch raw {
        case "fear":         return .peace
        case "condemnation": return .grace
        case "lack":         return .provision
        case "rejection":    return .belonging
        case "sickness":     return .healing
        case "inadequacy":   return .identity
        case "abandonment":  return .nearness
        case "confusion":    return .clarity
        case "lust":         return .purity
        default:             return nil
        }
    }
}

// MARK: - Entry

/// One rep: a facet of God to behold, the line spoken up to Him, and the
/// declaration spoken over the speaker's own life.
///
/// The declaration is stored WHOLE rather than referenced by id — the same call
/// `IncomingThought` made, for the same reason. The declaration pool loads
/// asynchronously and has no stable identifier beyond its own text, so a
/// reference could resolve to nothing at the exact moment someone needs a line
/// to say. Every declaration in `magnify.json` is copied verbatim out of
/// `declarationsv10.json` by the generator, so the two cannot drift.
public struct MagnifyEntry: Codable, Identifiable, Equatable {
    public let id: String
    public let domain: MagnifyDomain
    /// 1...3, gentle to deep. A new user never opens on the deepest facet in the
    /// bank — not because the deep ones are heavy, but because "You are my
    /// Shepherd, I lack nothing" is a truer first step than "You call things
    /// that are not as though they already are."
    public let intensity: Int
    /// What God is called here. "Jehovah Rapha", "The Lifter of My Head".
    public let nameOfGod: String
    /// The same thing in plain English, under the name. Rule 15: nothing in this
    /// feature may need decoding.
    public let attribute: String
    /// Spoken FIRST, and spoken UP. Second person, addressed to God. This is the
    /// line that replaced the rebuke, and it is the reason this feature no
    /// longer needs an exception to CLAUDE.md rule 12.
    public let exaltation: String
    /// Spoken SECOND, over the speaker's own life. Verbatim from the reviewed
    /// library — first person, present tense, already-done.
    public let declaration: String
    public let verseText: String
    /// Reference only, e.g. "Psalm 34:3".
    public let book: String
    /// `DeclarationCategory` rawValue the declaration was drawn from. Kept so
    /// the bank stays auditable against the library it was built from.
    public let declarationCategory: String

    public init(id: String,
                domain: MagnifyDomain,
                intensity: Int,
                nameOfGod: String,
                attribute: String,
                exaltation: String,
                declaration: String,
                verseText: String,
                book: String,
                declarationCategory: String) {
        self.id = id
        self.domain = domain
        self.intensity = intensity
        self.nameOfGod = nameOfGod
        self.attribute = attribute
        self.exaltation = exaltation
        self.declaration = declaration
        self.verseText = verseText
        self.book = book
        self.declarationCategory = declarationCategory
    }
}

extension MagnifyEntry {
    /// What they say out loud, in order: up to God, then over their own life.
    /// One utterance, one mic session, so the rep still fits in a breath.
    public var spokenLine: String {
        "\(exaltation) \(declaration)"
    }

    /// The same facet, carrying a declaration matched to what the user wrote on
    /// the optional written route.
    ///
    /// Only the DECLARATION moves. The name of God, the exaltation and the
    /// domain stay exactly as the bank wrote them, because the answer to "here
    /// is what I am carrying" is not a rewritten God — it is this God, over that
    /// thing. Compare `IncomingThought.wearing(_:)`, which put the user's own
    /// sentence on the card to be seized; nothing here ever displays back what
    /// they typed, which is the sharper end of rule 3.
    public func answering(_ matched: (declaration: String, verseText: String, book: String, category: String)) -> MagnifyEntry {
        MagnifyEntry(
            id: MagnifiedMoment.writtenEntryId,
            domain: domain,
            intensity: intensity,
            nameOfGod: nameOfGod,
            attribute: attribute,
            exaltation: exaltation,
            declaration: matched.declaration,
            verseText: matched.verseText,
            book: matched.book,
            declarationCategory: matched.category
        )
    }
}

/// Root of `magnify.json`. Mirrors `ThoughtBank` and `EnforcementCatalog` so
/// content ships and versions the same way.
public struct MagnifyBank: Codable {
    public let version: Int
    /// The teaching layer. One line is shown on BEHOLD each day, rotating, so
    /// the reason this works accrues over months instead of being a wall the
    /// user dismisses once on first run. Lives in the JSON so it can be extended
    /// through Remote Config without a build.
    public let whyLines: [String]
    public let entries: [MagnifyEntry]

    public init(version: Int, whyLines: [String], entries: [MagnifyEntry]) {
        self.version = version
        self.whyLines = whyLines
        self.entries = entries
    }
}

// MARK: - Log

/// One completed rep.
///
/// **The raw text of a written entry is deliberately absent.** What someone
/// types when something real is on them is the most private thing this app ever
/// sees. The domain syncs; the sentence never leaves the phone and never reaches
/// analytics. Adding a `text` field here would quietly break that promise on
/// every device the user owns, so it must not be added.
public struct MagnifiedMoment: Codable, Identifiable, Equatable {
    public enum Source: String, Codable {
        /// The day's rep, from a tapped domain or the bank's own pick.
        case daily
        /// The optional written route — they named it, the app answered it.
        case written
        /// Storm mode: no question asked, straight to the facet.
        case storm
        /// An extra rep on a day already banked.
        case extra
    }

    public let id: UUID
    public let date: Date
    public let source: Source
    public let domain: MagnifyDomain
    /// The bank entry's id, or `Self.writtenEntryId` when the declaration came
    /// from a live match rather than the bank.
    public let entryId: String
    /// True when they actually voiced it (mic or press-and-hold). The health
    /// metric for the whole feature.
    public let spoken: Bool

    public init(id: UUID, date: Date, source: Source, domain: MagnifyDomain, entryId: String, spoken: Bool) {
        self.id = id
        self.date = date
        self.source = source
        self.domain = domain
        self.entryId = entryId
        self.spoken = spoken
    }

    public static let writtenEntryId = "written_entry"
}

// MARK: - The count

/// The only number this feature keeps.
///
/// Cumulative, monotonic, cross-device. Backed by the same synced-counter
/// machinery as `totalAffirmationsSpoken` (see `ProgressSyncStore`), which is
/// append-only by construction — so there is no code path that can take it back,
/// and no calendar that can expire it.
public enum TimesMagnified {
    /// **Deliberately still `totalThoughtsTakenCaptive`.** This is the same daily
    /// rep under a truer name, and the key is whitelisted in
    /// `ProgressSyncStore.syncedCounterKeys` and already merged across every one
    /// of the user's devices. A new key would have silently reset a 400-rep user
    /// to zero on upgrade day, which rule 1 forbids outright. The storage name is
    /// history; the label is the product.
    public static let counterKey = "totalThoughtsTakenCaptive"

    public static func total(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: counterKey)
    }

    /// Adds one. Returns the new total so the closing screen can show the number
    /// it just earned rather than re-reading and racing the write.
    @discardableResult
    public static func add(defaults: UserDefaults = .standard) -> Int {
        let next = defaults.integer(forKey: counterKey) + 1
        defaults.set(next, forKey: counterKey)
        return next
    }
}
