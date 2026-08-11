//
//  BurstSession.swift
//  SpeakLife
//
//  What a Daily Burst is made of, and the policy that decides it.
//
//  This used to live inside `DailyDeclarationBurstView.loadDynamicDeclarations`
//  — a hundred lines of campaign lookup, weighted pooling, shuffling, deduping,
//  and fallback, inside a SwiftUI `View`. Two things came from that.
//
//  It could not be tested. The only way to ask "does an active campaign own the
//  burst?" was to render a view with five environment objects and read its
//  private state.
//
//  And it leaked. The composer knew exactly how the burst was built, then threw
//  that away and left the view to re-derive it later by asking
//  `EnforcementService` a second time — which is a different question, asked at
//  a different moment, and could answer differently. `BurstSession` closes that
//  by making the composer state what it did: the lines, where they came from,
//  and the theme, resolved once while the answer is still known for certain.
//

import Foundation

// MARK: - Burst Declaration

/// One slat of the burst.
///
/// Carries the category as an enum *and* the label to render. They are not
/// interchangeable: `DeclarationCategory.name` is a browse label
/// ("Warfare & Victory", "Peace & Rest") that does not parse back into a
/// category, so a view that keeps only the label has lost the theme.
struct BurstDeclaration: Equatable {
    let text: String
    let verse: String
    /// What the chip above the declaration reads.
    let categoryLabel: String
    let category: DeclarationCategory?

    init(text: String, verse: String, category: DeclarationCategory?, categoryLabel: String? = nil) {
        self.text = text
        self.verse = verse
        self.category = category
        // Defaulting the label off the category is what keeps the two in step;
        // callers only pass one explicitly when the campaign names the theme.
        self.categoryLabel = categoryLabel ?? category?.name ?? ""
    }
}

// MARK: - Burst Session

/// A composed burst: the lines to speak, where they came from, and what the
/// session is about.
struct BurstSession: Equatable {

    /// How the burst was filled. Recorded rather than re-derived, because the
    /// difference matters to the closing action: a campaign that owns the burst
    /// is an authoritative theme, while a draw from the pool is a guess made
    /// from what happened to be selected.
    enum Origin: Equatable {
        /// An active campaign filled every slot.
        case enforcement(DeclarationCategory)
        /// Drawn from favorites, the user's own, and the selected category.
        case pool
        /// The pool could not fill the burst, so built-ins topped it up.
        case fallback

        /// The campaign's theme, or nil when no campaign owns this burst.
        var enforcementTheme: DeclarationCategory? {
            switch self {
            case .enforcement(let category): return category
            case .pool, .fallback: return nil
            }
        }
    }

    let declarations: [BurstDeclaration]
    let origin: Origin
    /// What this burst was about. Resolved at composition time, when the origin
    /// is known for certain, and never recomputed.
    let theme: DeclarationCategory
}

// MARK: - Theme Resolution

/// Decides what a burst was about.
///
/// Separate from `FaithActionCatalog` on purpose: this is policy over what the
/// user spoke, and the catalog is content keyed by the answer. Keeping them
/// apart means the rules can change without touching 151 lines of copy, and the
/// copy can change without touching the rules.
enum BurstThemeResolver {

    /// Precedence is deliberate:
    ///
    ///   1. A campaign that owns the burst — every slot came from it, so it is
    ///      the only honest answer.
    ///   2. Otherwise the dominant category among the spoken declarations, which
    ///      is what the user actually said regardless of what is selected.
    ///   3. Otherwise whatever category is selected.
    ///   4. Otherwise faith, which fits anyone.
    static func resolve(
        enforcement: DeclarationCategory?,
        spoken: [DeclarationCategory],
        selected: DeclarationCategory?
    ) -> DeclarationCategory {
        if let enforcement, isActionable(enforcement) {
            return enforcement
        }
        if let dominant = dominantCategory(in: spoken) {
            return dominant
        }
        if let selected, isActionable(selected) {
            return selected
        }
        return .faith
    }

    /// True when a category names a life situation someone can take a step in
    /// today. Bible books, the favorites bin, and the user's own bucket are all
    /// containers rather than themes, so they never win theme resolution.
    static func isActionable(_ category: DeclarationCategory) -> Bool {
        if category.isBibleBook { return false }
        switch category {
        case .favorites, .myOwn, .general: return false
        default: return true
        }
    }

    /// Most frequent actionable category, ties broken by first appearance so the
    /// result is stable for a given burst rather than dependent on dictionary
    /// ordering.
    private static func dominantCategory(in spoken: [DeclarationCategory]) -> DeclarationCategory? {
        let actionable = spoken.filter(isActionable)
        guard !actionable.isEmpty else { return nil }

        var counts: [DeclarationCategory: Int] = [:]
        for category in actionable {
            counts[category, default: 0] += 1
        }
        var best: DeclarationCategory?
        var bestCount = 0
        for category in actionable where counts[category, default: 0] > bestCount {
            best = category
            bestCount = counts[category, default: 0]
        }
        return best
    }
}

// MARK: - Burst Session Builder

/// Composes a burst from everything available to draw on.
///
/// Pure: it reads no singletons and touches no storage. The campaign, the
/// favorites, and the pool are all handed in, which is what lets the whole
/// policy be tested without a view, a view model, or a running service.
struct BurstSessionBuilder {

    let declarationCount: Int
    /// Favorites are added to the pool this many times.
    let favoriteWeight: Int
    /// The user's own declarations are added this many times.
    let customWeight: Int
    /// Injected so tests can pin the draw. Production shuffles.
    private let shuffle: ([Declaration]) -> [Declaration]

    init(
        declarationCount: Int = 7,
        favoriteWeight: Int = 2,
        customWeight: Int = 3,
        shuffle: @escaping ([Declaration]) -> [Declaration] = { $0.shuffled() }
    ) {
        self.declarationCount = declarationCount
        self.favoriteWeight = favoriteWeight
        self.customWeight = customWeight
        self.shuffle = shuffle
    }

    /// - Parameters:
    ///   - enforcement: the active campaign, or nil when none is running or the
    ///     feature is off. The caller does that check, so this stays pure.
    ///   - currentDay: the campaign day to lead with.
    ///   - selected: the category selected in the app, used only as a fallback
    ///     theme when the spoken lines cannot name one.
    func build(
        enforcement: Enforcement?,
        currentDay: Int,
        favorites: [Declaration],
        custom: [Declaration],
        categoryPool: [Declaration],
        selected: DeclarationCategory?
    ) -> BurstSession {
        if let session = enforcementSession(enforcement, currentDay: currentDay) {
            return session
        }
        return poolSession(
            favorites: favorites,
            custom: custom,
            categoryPool: categoryPool,
            selected: selected
        )
    }

    // MARK: Campaign

    /// An active Enforcement owns the burst.
    ///
    /// The burst is BOTH the streak-earning action and the thing that advances a
    /// campaign. Without this, someone completes "day 4 of Enforcing Peace" by
    /// speaking seven random declarations from whatever category happens to be
    /// selected — the campaign's words would live only on the card and in the
    /// push, and what actually comes out of their mouth would have nothing to do
    /// with the week they chose. That makes the campaign decoration.
    ///
    /// Today's anchor leads; the rest of the week fills in behind it.
    ///
    /// Returns nil when the campaign cannot fill every slot. A campaign is always
    /// seven days so that should not happen, but a half-empty burst is worse than
    /// a pooled one, and claiming the campaign's theme over lines the campaign
    /// did not supply is worse than both.
    private func enforcementSession(_ enforcement: Enforcement?, currentDay: Int) -> BurstSession? {
        guard let enforcement else { return nil }

        let ordered = enforcement.days.sorted { lhs, rhs in
            if lhs.dayNumber == currentDay { return true }
            if rhs.dayNumber == currentDay { return false }
            return lhs.dayNumber < rhs.dayNumber
        }
        let declarations = ordered.prefix(declarationCount).map { day in
            BurstDeclaration(
                text: day.anchorText,
                verse: day.anchorBook,
                category: enforcement.theme,
                categoryLabel: enforcement.themeName
            )
        }
        guard declarations.count == declarationCount else { return nil }

        return BurstSession(
            declarations: Array(declarations),
            origin: .enforcement(enforcement.theme),
            theme: enforcement.theme
        )
    }

    // MARK: Pool

    private func poolSession(
        favorites: [Declaration],
        custom: [Declaration],
        categoryPool: [Declaration],
        selected: DeclarationCategory?
    ) -> BurstSession {
        var pool: [Declaration] = []
        for _ in 0..<favoriteWeight {
            pool.append(contentsOf: favorites)
        }
        for _ in 0..<customWeight {
            pool.append(contentsOf: custom)
        }
        pool.append(contentsOf: categoryPool)

        var selectedDeclarations: [BurstDeclaration] = []
        var usedIds = Set<String>()
        for declaration in shuffle(pool) {
            if selectedDeclarations.count >= declarationCount { break }
            if usedIds.contains(declaration.id) { continue }
            selectedDeclarations.append(
                BurstDeclaration(
                    text: declaration.text,
                    verse: declaration.book ?? "",
                    category: declaration.category
                )
            )
            usedIds.insert(declaration.id)
        }

        let neededFallback = declarationCount - selectedDeclarations.count
        if neededFallback > 0 {
            selectedDeclarations.append(contentsOf: Self.fallback.prefix(neededFallback))
        }

        let theme = BurstThemeResolver.resolve(
            enforcement: nil,
            spoken: selectedDeclarations.compactMap(\.category),
            selected: selected
        )
        return BurstSession(
            declarations: selectedDeclarations,
            origin: neededFallback > 0 ? .fallback : .pool,
            theme: theme
        )
    }

    /// Used when the pool cannot fill the burst — a brand new install, or a
    /// category whose declarations have not loaded yet.
    static let fallback: [BurstDeclaration] = [
        BurstDeclaration(text: "I am loved by God unconditionally", verse: "Romans 8:38-39", category: .love),
        BurstDeclaration(text: "My God supplies all my needs according to His riches", verse: "Philippians 4:19", category: .wealth),
        BurstDeclaration(text: "I have the mind of Christ", verse: "1 Corinthians 2:16", category: .wisdom),
        BurstDeclaration(text: "Greater is He that is in me than he that is in the world", verse: "1 John 4:4", category: .warfare),
        BurstDeclaration(text: "I can do all things through Christ who strengthens me", verse: "Philippians 4:13", category: .faith),
        BurstDeclaration(text: "The joy of the Lord is my strength", verse: "Nehemiah 8:10", category: .joy),
        BurstDeclaration(text: "I am fearfully and wonderfully made", verse: "Psalm 139:14", category: .identity)
    ]
}
