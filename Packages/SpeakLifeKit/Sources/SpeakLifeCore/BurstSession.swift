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
public struct BurstDeclaration: Equatable {
    public let text: String
    /// The reference only, e.g. "Psalm 139:14". Named `verse` since before the
    /// scripture text was carried alongside it; the quote itself is `scripture`.
    public let verse: String
    /// The scripture quoted in full, when the source carried it.
    ///
    /// Optional because it genuinely is: a declaration the user wrote themselves
    /// has no verse behind it, and a handful of the bundled ones carry only a
    /// reference. Empty strings are normalised to nil at init so no caller has to
    /// check for both.
    public let scripture: String?
    /// What the chip above the declaration reads.
    public let categoryLabel: String
    public let category: DeclarationCategory?

    public init(
        text: String,
        verse: String,
        scripture: String? = nil,
        category: DeclarationCategory?,
        categoryLabel: String? = nil
    ) {
        self.text = text
        self.verse = verse
        let trimmed = scripture?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scripture = (trimmed?.isEmpty == false) ? trimmed : nil
        self.category = category
        // Defaulting the label off the category is what keeps the two in step;
        // callers only pass one explicitly when the campaign names the theme.
        self.categoryLabel = categoryLabel ?? category?.name ?? ""
    }

    /// True when this slat can be spoken as scripture.
    public var hasScripture: Bool { scripture != nil }

    /// The line to actually put in someone's mouth.
    ///
    /// Falls back to the declaration whenever the scripture is missing, so a
    /// burst in scripture mode never shows a blank card. The fallback is silent
    /// on purpose: a slat that reads "no verse available" would be a worse thing
    /// to hand someone mid-burst than simply giving them the declaration.
    public func spokenLine(_ mode: BurstSpeakMode) -> String {
        switch mode {
        case .declaration: return text
        case .scripture:   return scripture ?? text
        }
    }

    /// Whether `spokenLine` actually honoured the requested mode. The card uses
    /// this to decide how to style the line, since a declaration set in quotes
    /// under a "Scripture" tab would be a lie.
    public func resolvedMode(_ mode: BurstSpeakMode) -> BurstSpeakMode {
        (mode == .scripture && !hasScripture) ? .declaration : mode
    }
}

// MARK: - Speak Mode

/// Which words the burst puts in the user's mouth.
///
/// Both are the same seven slats in the same order, with the same reference
/// underneath. Only the line being spoken changes, so a burst switched halfway
/// through keeps its place, its progress and its theme.
public enum BurstSpeakMode: String, CaseIterable, Equatable {
    /// The declaration: first person, present tense, written to be spoken.
    case declaration
    /// The scripture it stands on, quoted.
    case scripture

    /// Label for the segment control.
    public var title: String {
        switch self {
        case .declaration: return "Declaration"
        case .scripture:   return "Scripture"
        }
    }

    public var icon: String {
        switch self {
        case .declaration: return "bolt.fill"
        case .scripture:   return "book.fill"
        }
    }

    /// Parses a persisted raw value, defaulting to the declaration — which is
    /// what the burst has always been, so an unreadable preference costs nobody
    /// their familiar screen.
    public static func from(rawValue: String?) -> BurstSpeakMode {
        guard let rawValue, let mode = BurstSpeakMode(rawValue: rawValue) else { return .declaration }
        return mode
    }
}

// MARK: - Burst Session

/// A composed burst: the lines to speak, where they came from, and what the
/// session is about.
public struct BurstSession: Equatable {

    /// How the burst was filled. Recorded rather than re-derived, because the
    /// difference matters to the closing action: a campaign that owns the burst
    /// is an authoritative theme, while a draw from the pool is a guess made
    /// from what happened to be selected.
    public enum Origin: Equatable {
        /// An active campaign filled every slot.
        case enforcement(DeclarationCategory)
        /// Drawn from favorites, the user's own, and the selected category.
        case pool
        /// The pool could not fill the burst, so built-ins topped it up.
        case fallback

        /// The campaign's theme, or nil when no campaign owns this burst.
        public var enforcementTheme: DeclarationCategory? {
            switch self {
            case .enforcement(let category): return category
            case .pool, .fallback: return nil
            }
        }
    }

    public let declarations: [BurstDeclaration]
    public let origin: Origin
    /// What this burst was about. Resolved at composition time, when the origin
    /// is known for certain, and never recomputed.
    public let theme: DeclarationCategory

    public init(declarations: [BurstDeclaration], origin: Origin, theme: DeclarationCategory) {
        self.declarations = declarations
        self.origin = origin
        self.theme = theme
    }

    /// Whether this burst can be spoken as scripture at all.
    ///
    /// One line carrying a verse is enough to offer the switch: the rest fall
    /// back to their declaration, which is still seven lines of truth. A burst
    /// with none — someone speaking only their own written declarations — is
    /// offered no switch, because flipping it would change nothing on screen and
    /// a control that does nothing is worse than no control.
    public var scriptureAvailable: Bool {
        declarations.contains(where: \.hasScripture)
    }

    /// How many slats can honour scripture mode. Reported with the burst so the
    /// fallback rate is measurable rather than assumed.
    public var scriptureCount: Int {
        declarations.filter(\.hasScripture).count
    }
}

// MARK: - Theme Resolution

/// Decides what a burst was about.
///
/// Separate from `FaithActionCatalog` on purpose: this is policy over what the
/// user spoke, and the catalog is content keyed by the answer. Keeping them
/// apart means the rules can change without touching 151 lines of copy, and the
/// copy can change without touching the rules.
public enum BurstThemeResolver {

    /// Precedence is deliberate:
    ///
    ///   1. A campaign that owns the burst — every slot came from it, so it is
    ///      the only honest answer.
    ///   2. Otherwise the dominant category among the spoken declarations, which
    ///      is what the user actually said regardless of what is selected.
    ///   3. Otherwise whatever category is selected.
    ///   4. Otherwise faith, which fits anyone.
    public static func resolve(
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
    public static func isActionable(_ category: DeclarationCategory) -> Bool {
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
public struct BurstSessionBuilder {

    public let declarationCount: Int
    /// Favorites are added to the pool this many times.
    public let favoriteWeight: Int
    /// The user's own declarations are added this many times.
    public let customWeight: Int
    /// Injected so tests can pin the draw. Production shuffles.
    private let shuffle: ([Declaration]) -> [Declaration]

    public init(
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
    ///   - fullPool: every reviewed declaration, used to fill the six slots
    ///     behind a campaign's daily anchor. Defaults to empty, which is not a
    ///     convenience but a real state: the pool loads asynchronously, and a
    ///     burst opened before it arrives still has to produce seven lines.
    ///     `enforcementSession` degrades to the week's other anchors when it is
    ///     empty, so a missing pool costs variety and never the burst.
    public func build(
        enforcement: Enforcement?,
        currentDay: Int,
        favorites: [Declaration],
        custom: [Declaration],
        categoryPool: [Declaration],
        selected: DeclarationCategory?,
        fullPool: [Declaration] = []
    ) -> BurstSession {
        if let session = enforcementSession(enforcement, currentDay: currentDay, fullPool: fullPool) {
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
    /// Today's anchor leads, and six fresh lines from the campaign's theme fill
    /// in behind it.
    ///
    /// This used to seat all seven of the week's anchors in the seven slots and
    /// merely rotate today's to the front. Every slot was campaign-owned, which
    /// was the point — but it meant the burst was byte-identical from day 1 to
    /// day 7. Someone on day 4 of Enforcing Peace spoke the exact seven lines
    /// they spoke on day 1, so the only thing a new day changed was the order,
    /// and the campaign gave them no reason to come back for the content.
    ///
    /// So the anchor stays the spine — it is what the card shows, what the push
    /// says, and what "day 4" actually means — and the other six rotate. The
    /// draw is windowed rather than re-shuffled per day: one ordering per
    /// campaign, day N taking the Nth slice of six. That is what makes the whole
    /// week non-repeating instead of merely random, which independent daily
    /// draws would not be — six of forty-five twice over collides about once a
    /// day.
    ///
    /// Returns nil when the campaign cannot fill every slot. A half-empty burst
    /// is worse than a pooled one, and claiming the campaign's theme over lines
    /// the campaign did not supply is worse than both.
    private func enforcementSession(
        _ enforcement: Enforcement?,
        currentDay: Int,
        fullPool: [Declaration]
    ) -> BurstSession? {
        guard let enforcement else { return nil }
        guard let today = enforcement.day(currentDay) ?? enforcement.days.first else { return nil }

        var declarations: [BurstDeclaration] = [anchorLine(today, of: enforcement)]
        var spoken: Set<String> = [today.anchorText]

        // Every anchor of the week is off limits to the fresh draw, not just
        // today's. Day 6's line surfacing as filler on day 2 would spend the
        // campaign's own material early and land twice.
        let anchorTexts = Set(enforcement.days.map(\.anchorText))

        let candidates = Self.freshCandidates(
            chain: Self.freshChain(for: enforcement.theme),
            in: fullPool,
            excluding: anchorTexts,
            seed: enforcement.id
        )
        if !candidates.isEmpty {
            let window = max(currentDay - 1, 0) * (declarationCount - 1)
            // Wraps rather than running off the end. A thin category cannot feed
            // six new lines a day for a week even after the chain extends it, and
            // repeating this campaign's earlier fill beats dropping to the static
            // fallback list, which is not about their theme at all.
            for step in 0..<candidates.count where declarations.count < declarationCount {
                let candidate = candidates[(window + step) % candidates.count]
                guard !spoken.contains(candidate.text) else { continue }
                declarations.append(
                    BurstDeclaration(
                        text: candidate.text,
                        verse: candidate.book ?? "",
                        scripture: candidate.bibleVerseText,
                        category: candidate.category
                    )
                )
                spoken.insert(candidate.text)
            }
        }

        // The pool loads asynchronously and a burst can open before it lands.
        // Falling back to the week's other anchors reproduces exactly the old
        // behaviour for that one burst — repetitive, but campaign-owned and
        // seven lines long, which is the promise that matters.
        for day in enforcement.days.sorted(by: { $0.dayNumber < $1.dayNumber })
        where declarations.count < declarationCount {
            guard !spoken.contains(day.anchorText) else { continue }
            declarations.append(anchorLine(day, of: enforcement))
            spoken.insert(day.anchorText)
        }

        guard declarations.count == declarationCount else { return nil }

        return BurstSession(
            declarations: declarations,
            origin: .enforcement(enforcement.theme),
            theme: enforcement.theme
        )
    }

    private func anchorLine(_ day: EnforcementDay, of enforcement: Enforcement) -> BurstDeclaration {
        BurstDeclaration(
            text: day.anchorText,
            verse: day.anchorBook,
            // `anchorVerse` is the quote; `anchorBook` is the reference. The
            // campaign already carries both, so scripture mode costs a campaign
            // burst nothing.
            scripture: day.anchorVerse,
            category: enforcement.theme,
            categoryLabel: enforcement.themeName
        )
    }

    /// Where the six fresh lines come from, nearest-truth first.
    ///
    /// The theme's own declarations, then the siblings `EnforcementAssembler`
    /// already maps for it, then faith and identity — which fit anyone and are
    /// two of the deepest categories in the pool, so the chain cannot run dry.
    ///
    /// The extension past the theme is not hypothetical. Seventeen categories a
    /// campaign can be named for — `grief`, `business`, `debt`, `fertility` and
    /// the rest — carry exactly twenty-five referenced declarations, and a week
    /// of six-a-day wants forty-two. Those campaigns lean on the chain from
    /// about day four. The twenty-eight deeper categories never reach it.
    static func freshChain(for theme: DeclarationCategory) -> [DeclarationCategory] {
        var chain = [theme]
        chain += EnforcementAssembler.contentFallbacks[theme] ?? []
        chain += [.faith, .identity]
        var seen = Set<DeclarationCategory>()
        return chain.filter { EnforcementAssembler.isCampaignable($0) && seen.insert($0).inserted }
    }

    /// The chain's declarations, flattened in chain order and shuffled stably
    /// within each category.
    ///
    /// Ordering per category rather than across the whole chain is what keeps
    /// the early week on-theme: the window walks the theme's own lines first and
    /// only reaches a sibling once they are spent.
    ///
    /// Seeded on the campaign id, so the week's ordering is fixed the moment the
    /// campaign starts. `Array.shuffled()` would re-draw on every launch and day
    /// 3 would be six different lines each time the user opened the app.
    static func freshCandidates(
        chain: [DeclarationCategory],
        in pool: [Declaration],
        excluding blocked: Set<String>,
        seed: String
    ) -> [Declaration] {
        var result: [Declaration] = []
        var used = blocked
        for category in chain {
            var matching: [Declaration] = []
            for declaration in pool {
                guard declaration.category == category else { continue }
                guard declaration.contentType == .affirmation else { continue }
                guard !used.contains(declaration.text) else { continue }
                // The slat renders the reference under the line, so an unreferenced
                // declaration leaves a blank row. Same rule the assembler applies
                // when it picks the anchors.
                guard let book = declaration.book, !book.isEmpty else { continue }
                matching.append(declaration)
            }
            matching.sort {
                EnforcementAssembler.stableHash(seed + $0.text)
                    < EnforcementAssembler.stableHash(seed + $1.text)
            }
            used.formUnion(matching.map(\.text))
            result += matching
        }
        return result
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
                    scripture: declaration.bibleVerseText,
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
    /// Each carries its scripture as well as its reference, so a burst opened on
    /// a brand new install can still be spoken either way.
    public static let fallback: [BurstDeclaration] = [
        BurstDeclaration(
            text: "I am loved by God unconditionally",
            verse: "Romans 8:38-39",
            scripture: "For I am convinced that neither death nor life, neither angels nor demons, neither the present nor the future, nor any powers, neither height nor depth, nor anything else in all creation, will be able to separate us from the love of God that is in Christ Jesus our Lord.",
            category: .love
        ),
        BurstDeclaration(
            text: "My God supplies all my needs according to His riches",
            verse: "Philippians 4:19",
            scripture: "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
            category: .wealth
        ),
        BurstDeclaration(
            text: "I have the mind of Christ",
            verse: "1 Corinthians 2:16",
            scripture: "For who has known the mind of the Lord so as to instruct him? But we have the mind of Christ.",
            category: .wisdom
        ),
        BurstDeclaration(
            text: "Greater is He that is in me than he that is in the world",
            verse: "1 John 4:4",
            scripture: "You, dear children, are from God and have overcome them, because the one who is in you is greater than the one who is in the world.",
            category: .warfare
        ),
        BurstDeclaration(
            text: "I can do all things through Christ who strengthens me",
            verse: "Philippians 4:13",
            scripture: "I can do all this through him who gives me strength.",
            category: .faith
        ),
        BurstDeclaration(
            text: "The joy of the Lord is my strength",
            verse: "Nehemiah 8:10",
            scripture: "Do not grieve, for the joy of the Lord is your strength.",
            category: .joy
        ),
        BurstDeclaration(
            text: "I am fearfully and wonderfully made",
            verse: "Psalm 139:14",
            scripture: "I praise you because I am fearfully and wonderfully made; your works are wonderful, I know that full well.",
            category: .identity
        )
    ]
}
