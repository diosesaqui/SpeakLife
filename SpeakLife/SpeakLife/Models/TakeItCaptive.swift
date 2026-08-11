//
//  TakeItCaptive.swift
//  SpeakLife
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
enum ThoughtCategory: String, Codable, CaseIterable, Identifiable {
    case fear
    case condemnation
    case lack
    case rejection
    case sickness
    case inadequacy
    case abandonment
    case confusion
    case lust

    var id: String { rawValue }

    /// How the terrain is named to the user. Only ever shown as ground taken
    /// ("You've been taking ground in provision"), never as a label on them.
    ///
    /// The case names what comes IN; this names what the user takes. They are
    /// deliberately different words, and the second is always the higher reality
    /// that displaces the first in its own domain — fear lives in the mind, so
    /// the ground taken there is peace, not courage. Courage is a response to
    /// fear and keeps fear in the frame; peace is what replaces it.
    var terrainName: String {
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
    static func from(_ declarationCategory: DeclarationCategory) -> ThoughtCategory? {
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
        default:
            return nil
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
struct IncomingThought: Codable, Identifiable, Equatable {
    let id: String
    /// The lie, as it actually sounds in someone's head. Second person, because
    /// that is how it arrives — and because a first-person thought would read as
    /// the user's own, which this feature never does.
    let text: String
    let category: ThoughtCategory
    /// 1...3. A new user never opens on the heaviest thought in the bank.
    let intensity: Int
    /// The line they speak out loud. Verbatim from the declaration library.
    let counterDeclaration: String
    let verseText: String
    /// Reference only, e.g. "Isaiah 49:15".
    let book: String
    /// `DeclarationCategory` rawValue the counter was drawn from. Kept so the
    /// bank stays auditable against the library it was built from.
    let declarationCategory: String
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
    func wearing(_ userText: String) -> IncomingThought {
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
struct ThoughtBank: Codable {
    let version: Int
    let thoughts: [IncomingThought]
}

// MARK: - Log

/// One completed rep.
///
/// **The raw text of an escape-hatch entry is deliberately absent.** What
/// someone types when a real thought is on them is the most private thing this
/// app ever sees. The category syncs; the sentence never leaves the phone and
/// never reaches analytics. Adding a `text` field here would quietly break that
/// promise on every device the user owns, so it must not be added.
struct CapturedThought: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case daily
        case escapeHatch
        case interrupt
    }

    let id: UUID
    let date: Date
    let source: Source
    let category: ThoughtCategory
    /// The bank entry's id, or `Self.escapeHatchDeclarationId` when the
    /// declaration came from a live match rather than the bank.
    let thoughtId: String
    /// True when the user actually voiced it (mic or press-and-hold). The health
    /// metric for the whole feature.
    let spoken: Bool

    static let escapeHatchDeclarationId = "escape_hatch"
}

// MARK: - Ground taken

/// The only number this feature keeps.
///
/// Cumulative, monotonic, cross-device. Backed by the same synced-counter
/// machinery as `totalAffirmationsSpoken` (see `ProgressSyncStore`), which is
/// append-only by construction — so there is no code path that can take ground
/// back, and no calendar that can expire it.
enum GroundTaken {
    /// Whitelisted in `ProgressSyncStore.syncedCounterKeys`, which is what makes
    /// it merge across devices instead of resetting on a restore.
    static let counterKey = "totalThoughtsTakenCaptive"

    static func total(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: counterKey)
    }

    /// Adds one. Returns the new total so the completion screen can show the
    /// number it just earned rather than re-reading and racing the write.
    @discardableResult
    static func take(defaults: UserDefaults = .standard) -> Int {
        let next = defaults.integer(forKey: counterKey) + 1
        defaults.set(next, forKey: counterKey)
        return next
    }
}
