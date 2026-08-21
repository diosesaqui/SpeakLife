//
//  TakeItCaptive.swift
//  SpeakLifeCore
//
//  Guarding — the fifth pillar. "We take captive every thought to make it
//  obedient to Christ." (2 Corinthians 10:5)
//
//  The loop terminates in SPEAKING, always. That is the whole differentiation:
//  Hearing and Quiet Time end at receiving; this one ends at words out loud.
//  Anything that makes this feel like journaling is the wrong change.
//
//  Two rules here carry the feature and must survive every future edit:
//
//  1. **Ground taken is cumulative and never resets.** There is no streak, no
//     "days missed", no chart. A broken counter tells a believer mid-storm they
//     failed at guarding their mind, which is law, and the exact inversion of
//     this app's grace-first positioning.
//  2. **The thought is never the user's.** Every model name, every string, calls
//     it *incoming* — something to reject, never something that indicts them.
//     `IncomingThought`, not `UserThought`. Copy says "the thought", never
//     "your thought".
//

import Foundation

// MARK: - Category

/// The nine terrains a thought comes in on.
///
/// Terrain, not pathology, deliberately: this is where ground gets taken, not a
/// diagnosis of the speaker. Nothing in the UI ever says "you struggle with
/// anxiety" — at most it says where they have been taking ground.
public enum ThoughtCategory: String, Codable, CaseIterable, Identifiable {
    case fear
    case condemnation
    case lack
    case rejection
    case sickness
    case inadequacy
    case abandonment
    case confusion
    case lust

    public var id: String { rawValue }

    /// How the terrain is named to the user. Only ever shown as ground taken
    /// ("You've been taking ground in provision"), never as a label on them.
    ///
    /// The case names what comes IN; this names what the user takes. They are
    /// deliberately different words, and the second is always the higher reality
    /// that displaces the first in its own domain — fear lives in the mind, so
    /// the ground taken there is peace, not courage. Courage is a response to
    /// fear and keeps fear in the frame; peace is what replaces it.
    public var terrainName: String {
        switch self {
        case .fear:         return "peace"
        case .condemnation: return "grace"
        case .lack:         return "provision"
        case .rejection:    return "belonging"
        case .sickness:     return "healing"
        case .inadequacy:   return "identity"
        case .abandonment:  return "God's nearness"
        case .confusion:    return "clarity"
        case .lust:         return "purity"
        }
    }

    /// The declaration categories this terrain draws its counters from. Used by
    /// the escape hatch to turn a `DeclarationCategory` from the shared matcher
    /// into one of these nine.
    public static func from(_ declarationCategory: DeclarationCategory) -> ThoughtCategory? {
        switch declarationCategory {
        case .fear, .godsprotection, .warfare, .anxiety:
            return .fear
        case .purity:
            return .lust
        // `.addiction` deliberately stays on grace rather than moving to `.lust`
        // with purity. It also carries alcohol, drugs, and every other
        // compulsion, and the keyword rule that owns it fires before the purity
        // rule — so routing it here would send someone fighting a bottle to
        // declarations about their eyes. Grace and freedom are the right
        // medicine for the shame underneath any of them.
        case .grace, .forgiveness, .addiction, .salvation:
            return .condemnation
        case .wealth, .debt, .housing, .work, .business, .education:
            return .lack
        case .love, .friendship, .marriage, .relationship, .divorce, .singleParent:
            return .rejection
        case .health, .wellness, .fertility, .mentalHealth:
            return .sickness
        case .identity, .confidence, .destiny, .favor:
            return .inadequacy
        case .rest, .hardtimes, .grief, .innerHealing, .hope, .joy, .anger:
            return .abandonment
        case .faith, .wisdom, .spiritualGrowth, .miracles, .obedience:
            return .confusion
        // Parenting sits on identity rather than on the child. A thought that
        // arrives as "I am ruining my kids" is a thought about the speaker's
        // adequacy, and that is the only half of it scripture lets a
        // declaration settle — the child is a free person (see rule 6 in
        // CLAUDE.md), so the ground taken here is the parent's standing.
        // `.singleParent` is deliberately absent: it is already claimed above
        // by rejection, where the ache of doing it alone lives.
        case .parenting, .newSeason:
            return .inadequacy
        // Praise, gratitude and heaven all answer the same lie: that God is
        // distant or has stopped paying attention.
        case .praise, .gratitude, .heaven, .godsheart:
            return .abandonment
        default:
            return nil
        }
    }

    /// The declaration categories to draw this terrain's counters from, best
    /// first. The inverse of `from(_:)`, and deliberately narrower than a true
    /// inverse: it names where the strongest line for this terrain lives, not
    /// every category that maps back here.
    ///
    /// Used when the 42-rule keyword table finds nothing — the terrain lexicon
    /// speaks 2am English ("biopsy", "test results", "can't stop thinking")
    /// that the rule table never learned, so a terrain hit still has to be able
    /// to reach the library.
    public var declarationCategories: [DeclarationCategory] {
        switch self {
        case .fear:         return [.fear, .anxiety, .godsprotection]
        case .condemnation: return [.grace, .forgiveness, .addiction]
        case .lack:         return [.wealth, .debt, .housing]
        case .rejection:    return [.love, .friendship, .innerHealing]
        case .sickness:     return [.health, .wellness, .mentalHealth]
        case .inadequacy:   return [.identity, .confidence, .destiny]
        case .abandonment:  return [.hope, .innerHealing, .rest]
        case .confusion:    return [.wisdom, .faith, .destiny]
        case .lust:         return [.purity, .addiction]
        }
    }
}

// MARK: - Incoming thought

/// One rep at the range: a thought the app supplies, and the declaration that
/// displaces it.
///
/// The counter declaration is stored WHOLE rather than referenced by id, the
/// same call `EnforcementDay` makes and for the same reason: the declaration
/// pool loads asynchronously and has no stable identifier beyond its own text,
/// so a reference could resolve to nothing at the exact moment the user needs a
/// line to speak. Every counter in `thoughts.json` is copied verbatim out of
/// `declarationsv10.json` by the build script, so the two cannot drift.
public struct IncomingThought: Codable, Identifiable, Equatable {
    public let id: String
    /// The lie, as it actually sounds in someone's head. Second person, because
    /// that is how it arrives — and because a first-person thought would read as
    /// the user's own, which this feature never does.
    public let text: String
    public let category: ThoughtCategory
    /// 1...3. A new user never opens on the heaviest thought in the bank.
    public let intensity: Int
    /// The line they speak out loud. Verbatim from the declaration library.
    public let counterDeclaration: String
    public let verseText: String
    /// Reference only, e.g. "Isaiah 49:15".
    public let book: String
    /// `DeclarationCategory` rawValue the counter was drawn from. Kept so the
    /// bank stays auditable against the library it was built from.
    public let declarationCategory: String

    public init(id: String,
                text: String,
                category: ThoughtCategory,
                intensity: Int,
                counterDeclaration: String,
                verseText: String,
                book: String,
                declarationCategory: String) {
        self.id = id
        self.text = text
        self.category = category
        self.intensity = intensity
        self.counterDeclaration = counterDeclaration
        self.verseText = verseText
        self.book = book
        self.declarationCategory = declarationCategory
    }
}

extension IncomingThought {
    /// The same entry, wearing the user's own words on the card.
    ///
    /// When someone names their own thought, that sentence is what goes on the
    /// card they watch get taken — seeing a line you wrote yourself seized is
    /// the whole reason for asking. The matched bank entry still supplies the
    /// counter, the verse and the terrain; only the text that goes is theirs.
    ///
    /// The id deliberately becomes `escapeHatchDeclarationId`, not the bank
    /// entry's. That id is what reaches the log and the rotation history, and
    /// neither should record a bank thought as "served" when the user never saw
    /// it — nor should it carry anything traceable to what they typed.
    public func wearing(_ userText: String) -> IncomingThought {
        IncomingThought(
            id: CapturedThought.escapeHatchDeclarationId,
            text: userText,
            category: category,
            intensity: intensity,
            counterDeclaration: counterDeclaration,
            verseText: verseText,
            book: book,
            declarationCategory: declarationCategory
        )
    }
}

/// Root of `thoughts.json`. Mirrors `EnforcementCatalog` so content ships and
/// versions the same way.
public struct ThoughtBank: Codable {
    public let version: Int
    public let thoughts: [IncomingThought]

    public init(version: Int, thoughts: [IncomingThought]) {
        self.version = version
        self.thoughts = thoughts
    }
}

// MARK: - Log

/// One completed rep.
///
/// **The raw text of an escape-hatch entry is deliberately absent.** What
/// someone types when a real thought is on them is the most private thing this
/// app ever sees. The category syncs; the sentence never leaves the phone and
/// never reaches analytics. Adding a `text` field here would quietly break that
/// promise on every device the user owns, so it must not be added.
public struct CapturedThought: Codable, Identifiable, Equatable {
    public enum Source: String, Codable {
        case daily
        case escapeHatch
        case interrupt
    }

    public let id: UUID
    public let date: Date
    public let source: Source
    public let category: ThoughtCategory
    /// The bank entry's id, or `Self.escapeHatchDeclarationId` when the
    /// declaration came from a live match rather than the bank.
    public let thoughtId: String
    /// True when the user actually voiced it (mic or press-and-hold). The health
    /// metric for the whole feature.
    public let spoken: Bool

    public init(id: UUID, date: Date, source: Source, category: ThoughtCategory, thoughtId: String, spoken: Bool) {
        self.id = id
        self.date = date
        self.source = source
        self.category = category
        self.thoughtId = thoughtId
        self.spoken = spoken
    }

    public static let escapeHatchDeclarationId = "escape_hatch"
}

// MARK: - Ground taken

/// The only number this feature keeps.
///
/// Cumulative, monotonic, cross-device. Backed by the same synced-counter
/// machinery as `totalAffirmationsSpoken` (see `ProgressSyncStore`), which is
/// append-only by construction — so there is no code path that can take ground
/// back, and no calendar that can expire it.
public enum GroundTaken {
    /// Whitelisted in `ProgressSyncStore.syncedCounterKeys`, which is what makes
    /// it merge across devices instead of resetting on a restore.
    public static let counterKey = "totalThoughtsTakenCaptive"

    public static func total(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: counterKey)
    }

    /// Adds one. Returns the new total so the completion screen can show the
    /// number it just earned rather than re-reading and racing the write.
    @discardableResult
    public static func take(defaults: UserDefaults = .standard) -> Int {
        let next = defaults.integer(forKey: counterKey) + 1
        defaults.set(next, forKey: counterKey)
        return next
    }
}
