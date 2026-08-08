//
//  WeeklyFocusEscalation.swift
//  SpeakLife
//
//  Three weeks carried, nothing moved. Phase 4.
//
//  Phase 1 already advances the angle to `.escalate` at three carry-overs,
//  swaps the Sunday question to "You've been carrying this a while. What's
//  actually in the way?", and fires `weekly_focus_escalated`. What it does not
//  do is anything about it — a fourth, fifth, sixth silently regenerated week
//  on an unmoved need is the app failing to notice, which is worse than the
//  content being wrong.
//
//  So the escalation offers the two things a stuck need actually needs, and
//  neither of them is more declarations:
//
//    1. Bible Chat, with the need pre-loaded. They have said the same sentence
//       four Sundays running. At some point the answer is a conversation.
//    2. The Anchor's It Came to Pass flow. The likeliest reason a need has
//       "not moved" for a month is that it moved and nobody marked it. Asking
//       is free; assuming is not.
//
//  ONCE PER NEED, NOT ONCE PER WEEK. `weekly_focus_escalated` fires every week
//  the angle is `.escalate` (that is Phase 1's behaviour and it is untouched —
//  the cohort size is what it measures). This offer is different: showing the
//  same interruption every Sunday for a need they have chosen not to resolve
//  is exactly the nagging the feature is supposed to avoid. A new need gets a
//  new offer; the same need never gets a second one.
//

import Foundation

@MainActor
final class WeeklyFocusEscalation {

    /// Needs already offered the escalation, as stable keys. An array rather
    /// than a set because UserDefaults has no set type; membership is a linear
    /// scan over a list that is bounded by how many distinct needs one person
    /// carries for a month, which is a very small number.
    private static let offeredKey = "weekly_focus_escalations_offered"
    /// Keeps the list from growing without bound over years of use.
    private static let historyLimit = 40

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Policy

    /// True when this week has reached the escalation angle and this particular
    /// need has never been offered the escalation before.
    func shouldOffer(for focus: WeeklyFocus) -> Bool {
        guard focus.isEscalating else { return false }
        // A need nobody stated cannot be "carried" in any meaningful sense —
        // the ladder only carries `needText`, so this is belt and braces.
        guard Self.key(for: focus) != nil else { return false }
        guard focus.resolvedAt == nil else { return false }
        return !hasOffered(for: focus)
    }

    func hasOffered(for focus: WeeklyFocus) -> Bool {
        guard let key = Self.key(for: focus) else { return false }
        return offered().contains(key)
    }

    /// Records the offer so it never fires again for this need. Called when the
    /// sheet is PRESENTED, not when it is acted on: a user who dismisses it has
    /// answered the question, and re-asking next Sunday is the nag.
    func markOffered(for focus: WeeklyFocus) {
        guard let key = Self.key(for: focus) else { return }
        var keys = offered()
        guard !keys.contains(key) else { return }
        keys.append(key)
        if keys.count > Self.historyLimit {
            keys.removeFirst(keys.count - Self.historyLimit)
        }
        defaults.set(keys, forKey: Self.offeredKey)

        AnalyticsService.shared.track("weekly_focus_escalation_offered", parameters: [
            "need_bucket": focus.needBucket,
            "carry_over_count": focus.carryOverCount
        ])
    }

    // MARK: - Identity of a need

    /// The identity of a need, stable across launches.
    ///
    /// `hashValue` is deliberately avoided for the same reason the selector
    /// avoids it: Swift re-seeds it every launch, so a key built from it would
    /// forget every past offer on the next cold start and the "at most once"
    /// promise would quietly become "once per launch". Normalized text plus
    /// bucket is stable, readable in a defaults dump, and cheap.
    nonisolated static func key(for focus: WeeklyFocus) -> String? {
        guard let need = focus.needText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
              !need.isEmpty else { return nil }
        let collapsed = need
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return "\(focus.needBucket)|\(String(collapsed.prefix(120)))"
    }

    private func offered() -> [String] {
        defaults.stringArray(forKey: Self.offeredKey) ?? []
    }

    // MARK: - Copy
    //
    // On the model side rather than in the view so the two entry points below
    // cannot drift from what the sheet says they do.

    /// What Bible Chat is opened with. Their own words, framed as the question
    /// they have been carrying, so the first reply is already about them.
    nonisolated static func chatPrompt(for focus: WeeklyFocus) -> String? {
        guard let need = focus.needText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !need.isEmpty else { return nil }
        let weeks = max(2, focus.carryOverCount + 1)
        return "I've been praying about this for \(weeks) weeks and it hasn't changed: \(need). What does God's Word say to me here?"
    }
}
