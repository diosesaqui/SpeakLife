//
//  WeeklyFocusBuilderProtocol.swift
//  SpeakLife
//

import Foundation

/// One entry point, both cases. `answer == nil` walks the fallback ladder
/// (carry-over → anchor → profile → behavioral → declared categories);
/// a non-nil answer takes the `.userAnswered` path.
///
/// Contract: this can never return nil and can never return an empty week.
/// The week is always built — input upgrades it, the absence of input must
/// never leave an empty state.
protocol WeeklyFocusBuilderProtocol {
    func build(for weekStart: Date, answer: String?) async -> WeeklyFocus
}

/// Supplies the declaration pool the selector chooses from. Isolated behind a
/// protocol so the builder does not depend on `LocalAPIClient` (or on the feed
/// view model having already loaded) and stays testable with a fixed pool.
protocol WeeklyFocusDeclarationProviding {
    func loadDeclarations() async -> [Declaration]
}
