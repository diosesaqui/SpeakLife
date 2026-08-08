//
//  WeeklyFocusSelecting.swift
//  SpeakLife
//
//  The seam Phase 2 swaps on.
//
//  `WeeklyFocusContentSelector` (keyword, local, free) and
//  `WeeklyFocusRemoteSelector` (the `/weeklyFocus` Cloud Function) are
//  interchangeable behind this one method, so `WeeklyFocusBuilder` never learns
//  which one it is holding and the Remote Config flag can move the whole
//  feature between them without touching the ladder.
//
//  Async on purpose, even though the keyword selector is synchronous: the
//  remote one cannot be, and a protocol that forced it to block would make the
//  fallback path the awkward one instead of the fast path.
//

import Foundation

protocol WeeklyFocusSelecting {
    /// Chooses and sequences the week's declarations from `pool`.
    ///
    /// Contract, inherited from Phase 1 and non-negotiable: this always
    /// returns a usable week. An implementation that can fail must fall back
    /// to one that cannot, rather than returning an empty selection.
    func selectWeek(input: WeeklyFocusSelectionInput,
                    from pool: [Declaration]) async -> WeeklyFocusSelection
}

// MARK: - Keyword selector conformance
//
// Declared here rather than on the type so Phase 1's file keeps its single
// responsibility, and so the async wrapper is obviously a shim: the keyword
// path does no work off the calling thread and never suspends.

extension WeeklyFocusContentSelector: WeeklyFocusSelecting {
    func selectWeek(input: WeeklyFocusSelectionInput,
                    from pool: [Declaration]) async -> WeeklyFocusSelection {
        select(input: input, from: pool)
    }
}
