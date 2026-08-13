# Cleanup & Hardening Plan

**Branch:** `feature/cleanup-hardening` (cut from `main`)
**Runs alongside:** `TEST_DECOUPLING_WORKPLAN.md`. That plan moves code into a package;
this one decides what deserves to be moved. **Do Track A before that plan's PR6** —
there is no sense converting access levels on 13,000 lines that should not exist.

Three tracks, independent, each landable on its own:

| Track | Goal | Verdict |
|---|---|---|
| **A — Delete** | Remove code nothing runs | ~13,200 lines, mechanically identifiable |
| **B — Structure** | SOLID where it actually pays | Targeted, not codebase-wide (see §3.0) |
| **C — Tests** | Cover the interfaces that can hurt you | Risk-ranked; money logic first |

---

## 1. What we measured

Every number below came from the tree at `claude/pipeline-unit-test-plan-hl5kgg`.
Regeneration commands are in §6 so this survives contact with a moving codebase.

| Measure | Value |
|---|---|
| App Swift files / lines | 368 / 123,415 |
| **Never compiled** (on disk, absent from `project.pbxproj`) | **~5,115 lines** |
| **Compiled but entirely commented out** (the dead Bootcamp feature) | **~2,865 lines** |
| Unreachable onboarding — raw scan / **after verification** | 22 files, 8,459 lines / **16 files, 4,551 lines** |
| Types declared in more than one file (raw) / **that actually collide** | 57 names / **0** |
| Commented-out code lines | 455 |
| `print()` in shipping code | 439 (only 28 files use `#if DEBUG` at all) |
| Singletons (`static let shared`) | 56 declarations |
| `AnalyticsService.shared` call sites | 436 |
| `fatalError` / `as!` / `try!` | 17 / 1 / 0 |
| Unused asset sets | 9 |
| Tests touching subscription or entitlement logic | **0** |

Two of those deserve to be read twice: **~5,115 lines that the compiler has never seen**,
and **zero tests on the code that decides whether someone has paid.**

---

## 2. Track A — Delete what nothing runs

Ordered by risk, lowest first. Wave 1 is genuinely risk-free; by Wave 4 you are making
judgement calls. Do not reorder.

### Wave A1 — Files the compiler has never seen · ~5,115 lines · risk: none

These exist on disk but are absent from `project.pbxproj`, so they are **already not part
of the app**. Deleting them cannot change behaviour — it only stops them appearing in
search results and misleading whoever greps next.

**A1.1 — The shadow `Utils/` directory · 2,816 lines.**
`SpeakLife/Utils/` duplicates the live `SpeakLife/Core/Utils/`. Only `Core/Utils` is in
the project (verified by walking the `PBXGroup` tree, not by guessing from the path).
The copies have **diverged**. Direction is not provable from divergence alone — and the
live copies are consistently the larger ones, which reads as the live file being extended
rather than the dead one being edited. Diff before deleting either way:

| File | Divergence |
|---|---|
| `Utils/GestureDelights.swift` | 166 differing lines |
| `Utils/PremiumHaptics.swift` | 89 |
| `Utils/AudioDelights.swift` | 75 |
| `Utils/CategoryParticleEffects.swift` | 28 |
| `Utils/CelebrationAnimations.swift` | 8 |
| `Utils/MicroInteractions.swift` | identical |

> Budget an hour to diff the six pairs and port anything that landed only in the dead
> copy. It is the one part of Wave A1 that is not mindless.

**A1.2 — Orphaned single files · 1,615 lines.** Delete outright:

| Lines | File |
|---:|---|
| 486 | `Services/Analytics/AIAnalyticsService.swift` |
| 413 | `Views/AI/AIIntegrationExtensions.swift` |
| 238 | `Views/Onboarding/FixedSpiritualWarfareScreens.swift` |
| 231 | `Views/ProfileView/WidgetPreferencesView.swift` |
| 95 | `Core/Utils/TaskCompletionAnimation.swift` |
| 78 | `Views/Declaration View/Streak/CompactStreakButton.swift` (the live `CompactStreakButton` lives in `EnhancedStreakView.swift`) |
| 74 | `Views/Bible/BibleVersionSelectorView.swift` |

**A1.3 — Duplicate service copies · 683 lines.** Live copy named first:

- `Views/Community/AppleSignInService.swift` is live → delete `Services/Auth/AppleSignInService.swift` (222 lines, **diverged** — diff first)
- `Services/IAP/Security/KeychainHelper.swift` is live → delete `Services/Security/KeychainHelper.swift` (104 lines, identical, safe)
- `Views/Bootcamp/BootcampMainView.swift` is live → delete
  `Views/ProfileView/Bootcamp/BootcampMainView.swift` (357 lines, **diverged by 696 lines**).
  Note the live copy is itself entirely commented out and dies in Wave A5 — but delete the
  shadow here so the §5 "no uncompiled file on disk" guardrail can pass.

> **Do NOT delete `Views/SpeakLifeQuiz/`.** Eight files there look orphaned by the same
> test and are not: `SpeakLifeQuiz` is the project's one
> `PBXFileSystemSynchronizedRootGroup`, so its contents are included automatically
> without appearing as paths. This is the single false positive in the scan — it is
> called out here because the naive version of this analysis says delete them.

**Verify:** `xcodebuild build -scheme SpeakLife -destination 'generic/platform=iOS'`
must produce a byte-identical result. Nothing here was ever compiled.

---

### Wave A2 — The onboarding graveyard · **4,551 lines verified** · risk: low

A raw reference scan flagged 22 files. **Two rounds of verification cut that to 16.** The
raw number was 8,459 lines; the number that is actually safe is **4,551**. Do not use the
raw list — six of those files are load-bearing in ways a filename scan cannot see, and one
of the six survived the *first* verification pass too (see the box below A2.3).

**The live router:** `Views/HomeView.swift:416–441` switches on
`subscriptionStore.resolvedOnboardingVariant` (`SubscriptionStore.swift:122–124`, enum at `:112–115`, fed by
Remote Config `onboardingVariant` + an `ob=` deep-link override, defaulting to `"warfare"`
at `AppDelegate.swift:127`). The live destinations are exactly seven:
`QuizOnboardingView`, `ProductOnboardingView`, `IdentityOnboardingView`,
`OutcomesOnboardingView`, `WarfareOnboardingView`, `PromisesOnboardingView`,
`CloserOnboardingView`. **None of the 22 is a router destination** — but that alone was
not enough to clear them.

**A2.1 — Delete outright · 3,001 lines**

`PolishedCrossOnboardingFlow` (1307) · `AudioDevotionalsTutorial` (302) ·
`DemoExperienceView` (232) · `PersonalizationSummaryScene` (208) · `DevotionalsTutorial` (206) ·
`AffirmationsTutorial` (192) · `HookScene` (139) · `WidgetScene` (125) ·
`LoadingView` (112) · `BenefitScene` (89) · `HelpUsGrowView` (89)

**A2.2 — Delete as clusters · 1,550 lines** (each is dead only *together*; deleting half breaks the build)

- `SpiritualWarfareOnboardingView` (394) **+** `SpiritualWarfareContentScreens` (524)
- `EnhancedOnboardingModels` (63) **+** `EnhancedOnboardingScreensRefactored` (569) **+** `EnhancedOnboardingViewRefactored` (528)

`StreamlinedSpiritualWarfareFlow` (922) is also unreachable — its only inbound reference
is the extension in the never-compiled `FixedSpiritualWarfareScreens`, whose
`useFixedBattleIntro`/`useFixedVictorySolution` are never called. Taking it plus
`EnhancedOnboardingViewRefactored` brings the total to **6,001 lines**. Add
`Views/Onboarding/OnboardingView.swift` (343, also unreachable) to the same sweep.

**A2.3 — KEEP these six.** Each looked dead and is not. This is the part a naive cleanup
gets wrong — and note that the *first verified pass still missed one of them*:

| File | Why it must stay |
|---|---|
| `NewOnboardingScreens` (2414) | Declares `ScaleButtonStyle`, used by `Views/Bible/BibleView.swift:465`; four of its screens are used by the live `HowToUseSpeakLifeView` |
| **`ImprovementScene` (202)** | **Sole declaration of `class ImprovementViewModel` (`:81`), used by `NewOnboardingScreens.swift:301` and `CombinedPersonalizationScene.swift:15,172` — both KEEP files. Deleting it is a hard compile failure.** |
| `CombinedPersonalizationScene` (334) | Sole declaration of `ProgressDots` (used by the live `OptimizedSubscriptionViewV1.swift:593`) **and** of `DeclarationCategory.iconName:269` |
| `TimeNotificationStepper` (114) | `ReminderCell.swift:45,50,66` — live via `ReminderView` |
| `WhatsNewView` (80) | `HomeView.swift:579` presents `WhatsNewBottomSheet` in a live sheet |
| `IntroScene` (527) | `SubscriptionView.swift:675` instantiates **`IntroTipScene`** (`IntroScene.swift:26`) — not the `IntroScene` type itself, which has zero references. That call sits inside the unused `patronView`, so the file is dead *in effect* but deleting it breaks the build. Removable once `patronView` goes. |

> **Why `ImprovementScene` slipped through twice.** Both the raw scan and the first
> verification pass matched on *filenames*. `ImprovementScene.swift` declares
> `ImprovementViewModel` — a name that shares nothing with its file. Same trap:
> `LoadingView.swift` declares `PersonalizationLoadingView`, `IntroScene.swift` declares
> `IntroTipScene`. **Enumerate declared types, not filenames** — or just run `periphery`
> (§5), which uses the compiler's index and would have caught this without argument.

**Remove the `project.pbxproj` entries for the 16 deleted files only** — *not* for the six
KEEP files above. No storyboard, xib, Info.plist, entitlements or Intents references exist
for any of them. Note `FixedSpiritualWarfareScreens` has **no** pbxproj entries at all; it
is handled in Wave A1.2, not here.

**Ship one PR per cluster, not one 5,000-line PR.** A reviewer can sanity-check "the dead
spiritual-warfare flow" and cannot meaningfully review five thousand deleted lines at once.

**Verify:** build, then walk all seven live onboarding variants on a device before merging.

---

### Wave A3 — Dead code inside living files · risk: low

- **455 lines of commented-out code.** Delete on sight. Git remembers; commented code
  does not. Exempt genuine explanatory comments — the filter matches lines beginning
  `// let`, `// func`, `// if`, `// return`, `// self.`, so it is already narrow.
- **`APIClientTests.swift`** — all 91 lines commented out, 6 phantom tests. Delete the file.
- **9 unused asset sets.** Confirm against `WidgetBackground` and `AccentColor`, which
  are referenced by the system rather than by name in code — those two stay.
- **~440 `print()` calls.** Do not mass-delete: several are load-bearing diagnostics
  (`PersistenceController` has 46 and they are how Core Data failures get diagnosed).
  Route them through one `Log` helper that compiles to nothing in release. That is a
  single mechanical pass and turns 439 unconditional writes into zero shipped.
- **The fake-AI task branch · `DailyChecklistModels.swift:1233–1240` and `:1531–1639`
  · ~110 lines.** Surfaced by the SOLID audit. The four `select*TasksWithAI` functions
  (`:1582–1631`) contain no AI — they are `filter`/`prefix` over the same data the
  standard path uses, and `selectFoundationTasksWithAI:1587–1590` sorts by
  `minimumStreakDay`, which is **already the array order**. Deleting the branch has no
  behavioural delta worth keeping, and it is what makes the core task-generation
  algorithm untestable (`getUserBehaviorData:1567` reaches `EnhancedAnalyticsService.shared`).
  Verify the no-op claim by diffing outputs for streak days 1–90 before deleting.
- **`BibleInteractor.searchVerses:818–829`** returns an empty result unconditionally but
  is declared on `BibleInteractorProtocol:14`, so callers get silence. Either implement
  it or remove it from the protocol and delete the callers' dead branches.

---

### Wave A5 — The dead Bootcamp feature · ~2,865 lines · risk: low

**Missed by the first pass, and larger than the entire shadow `Utils/` directory.** These
files *are* in the build — but they contain essentially no executable code. They are
whole-file comment blocks, which is why the commented-code scan in A3 cannot see them
(the style is `//    @ObservedObject var …`, indented past the regex).

| Lines | Executable | File |
|---:|---:|---|
| 947 | 0 | `Views/Bootcamp/BootcampDetailViews.swift` |
| 607 | 1 | `Views/Bootcamp/BootcampTabViews.swift` |
| 425 | 0 | `ViewModels/BootcampViewModel.swift` |
| 353 | 1 | `Views/Bootcamp/BootcampMainView.swift` |
| 155 | 1 | `Views/Declaration View/DeclarationContent/DeclarationAnimationSettings.swift` |

Plus `Models/BootcampModels.swift` (378 lines, 308 live) whose 29 declared types
(`BootcampProgram`, `BootcampModule`, `Lesson`, `WeeklyChallenge`, `Certificate`…) have
**zero references outside the dead Bootcamp files** — verified. The whole feature is dead.

Delete all six files and their pbxproj entries. Confirm first that Bootcamp is not a
product commitment someone intends to revive; if it is, the code is worth nothing in this
state anyway and git has it.

### Wave A4 — Duplicate type names · **verify before doing anything** · risk: low

**The raw count of 57 is real; the number that actually collide in the compiled module is
zero.** Verified by restricting the scan to column-0 declarations in files that are in the
app's Sources phase.

Every example worth naming turns out to be either a **nested** type — which does not
collide, in this module or across a package boundary — or a declaration in a
never-compiled file:

- `Event`: `Core/Analytics/Events.swift:11` is module scope; `ProgressSyncStore.swift:270`
  is `struct Event` **nested** inside `ProgressSyncStore`. The tests already write
  `ProgressSyncStore.Kind`. No rename needed, and it does **not** become mandatory at the
  package boundary.
- `UserPreferences`, `ParticleType`, `HeartData`, `StatCard`, `Step`, `Origin` — all nested.
- `Feature` / `FeatureCard` — second declaration is in the never-compiled
  `Views/ProfileView/Bootcamp/BootcampMainView.swift`.

**Recommendation: skip this wave.** Re-run the check after Waves A1 and A5 land, and only
act if a genuine module-scope collision survives. A day of renaming aimed at a
non-problem is churn a reviewer cannot justify.

---

## 3. Track B — SOLID, where it actually pays

### 3.0 Read this before starting Track B

You asked for every file to follow SOLID. **I would push back on that as written**, and
then do the version that pays.

368 files and 123,415 lines cannot be audited against five principles without becoming a
rewrite, and most of that surface is SwiftUI view code where SOLID barely applies — a
`View` struct that renders a screen has one responsibility by construction. Chasing a
principle across files that are already fine burns weeks and produces churn a reviewer
cannot evaluate.

What pays is targeting the three places where structure has real consequences:

1. **It blocks the package extraction** (a domain type reaching into UIKit or Firebase)
2. **It blocks testing** (a hard-coded singleton with no seam)
3. **It guards money or user data** (entitlements, Core Data, sync)

Everything else is left alone deliberately. If a file is 1,600 lines of declaration data,
its size is not a violation — `DailyChecklistModels.swift` is largely that.

### 3.1 The dependency-inversion problem is the whole game

**56 singletons, and `AnalyticsService.shared` alone is called from 436 sites.** A type
that reaches for a global cannot be tested without that global, which is exactly why the
untested list in §4 looks the way it does.

Do **not** attempt to de-singleton 436 call sites. The cheap, high-yield version:

- **Analytics** — leave the 436 call sites. Note the existing `AnalyticsProvider` protocol
  (`AnalyticsService.swift:51`) is the *destination* interface implemented by
  `FirebaseAnalyticsProvider:490`; `AnalyticsService` itself does not conform to it, so
  there is no consumer-facing seam yet. Declare a **new** `AnalyticsTracking` and conform
  `AnalyticsService` — see §3.3 target 2 for the detail. One change, all 436 sites become
  test-neutral.
- **The six singletons that block tests** — `PersistenceController:14`,
  `ProgressSyncStore:35`, `SyncedSettingsStore:47`, `EnforcementService:38`,
  `BurstCompletionTracker` (`BurstCompletionModel.swift:38`), `NotificationManager:18`.
  Give each an injectable initializer while keeping `.shared` as the app's default.
  Additive: no call site changes, and every consumer becomes testable.
- **`SubscriptionStore` is *not* a singleton** — it has no `static shared`; it is an
  `ObservableObject` injected via `@EnvironmentObject`. Its testability blocker is
  different: `init():286` calls `setupRemoteConfigListener()` and `fetchRemoteConfig()`
  directly, so constructing it touches Firebase. Fixed by §8 S1.4, not by this bullet.
- **Everything else** — leave it.

### 3.2 The rule for new and touched code

Rather than auditing 368 files, apply this at the point of change. Cheap, enforceable,
compounding:

1. A type that holds business logic takes its dependencies through `init`. No `.shared`
   inside the type.
2. Domain and model types import Foundation only. Presentation (`Color`, `Image`,
   formatting) lives in the view layer as an `extension`.
3. A protocol has one reason to exist; if a conformer leaves half the members unimplemented
   or fatal, split it.
4. New file over 400 lines needs a reason in the PR description.

Add these four lines to `CLAUDE.md` so they apply automatically to future work.

### 3.3 Named targets — audited, in leverage order

Full per-file audit of the seven largest files, ranked *blocks-extraction (P0) →
blocks-testing (P1) → readability (P2)*. Effort: S = under an hour, M = half day, L = multi-day.

**1. `SyncedSettingsStore.swift:694–1066` — invert the merge rules · L · P0**
370 lines of **domain-specific** merge algorithms live inside the CloudKit sync engine:
`mergeStreakStats:694`, `mergePersonalDeclarations:750`, `mergeEnforcementProgress:871`,
`mergedEnforcementHistory:993`, and seven more (eleven in total). An infrastructure type knows `StreakStats`,
`PersonalDeclaration`, `EnforcementProgress`, `InboxUnreadTracker`. **This is the
extraction blocker in both directions** — the domain package can never own its own merge
rules while they live here. Give each domain type `static func merge(_:_:) -> Self`
(the pattern `StreakStats.merging` at `DailyChecklistModels.swift:433` already
establishes), and let the store hold a registry of type-erased closures registered at app
start. The store drops to ~450 lines of pure reconciliation.
Also: the 131-line `whitelist:78–209` is app policy compiled into infrastructure — move it
out with the same `register(...)` call site.

**2. `AnalyticsService.swift:86` — one line, 436 call sites · M · P0**
`static let shared` + `private init:95`. Declare `protocol AnalyticsTracking { func track(...) }`
— the surface actually used at nearly all 436 sites is just `track` — conform
`AnalyticsService`, and keep `shared` as the composition-root default so sites migrate
incrementally rather than in one commit. The provider design here is already *good*
(`AnalyticsProvider:51–76` is correct ISP); only the singleton and two leaks are wrong.
Also `registerDefaultProviders:105–117` hardcodes four SDKs and the PostHog project key
`:113`, so constructing this for a test boots Firebase, TikTok, Meta and PostHog. Moving
those four lines to app startup is an **S**.
And `trackAudioPlayback:236` calls `ListenerMetricsService.shared` — an analytics
dispatcher mutating product state. Move to the call site (**S**).

**3. `DailyChecklistModels.swift` — three members block the whole file · S · P0**
Best value-per-hour in the audit. `TaskCategory.color:27`, `ProgressionPhase.color:247`,
and `CompletionCelebration.shareImage: UIImage?:600` are the *only* reason this
1,640-line file imports SwiftUI. Move all three to app-side extensions and
`DailyTask` / `DailyChecklist` / `StreakStats` / `ProgressionPhase` become package-ready.
The file is otherwise **fine** — `:848–1180` is ~330 lines of static data tables, which is
not an SRP violation.

**4. `EnhancedStreakViewModel.swift` — four responsibilities, 31 singleton reaches · L · P0**
Bigger than the other plan assumed. **686 lines** (`:1131–1816`) are Core Graphics poster
rendering, not the ~100 estimated — `generateShareImage`, `drawFlameShapes`,
`addStellarParticles`, `addLightRays` and nine more. Extract `StreakShareImageRenderer`
taking `(streak:longestStreak:milestone:message:)`; take `getMilestone:1818` and
`getMotivationalMessage:1831` with it.
Then two more responsibilities: iCloud reconciliation (`:150–370` → `StreakSyncReconciler`,
removes 8 of the 31 `.shared` reaches at once) and task-list construction (`:373–457,
646–775, 1025–1034`, which **duplicates the same rebuild-and-reapply algorithm four
times** at `:387–421`, `:435–457`, `:708–726`, `:731–743` → one `DailyChecklistBuilder`).
`init():76` takes zero parameters, which is what forces all 31 reaches. The file already
shows the right pattern at `:51`.

**5. `AppState.swift:142–328` — a 186-line migration runner inside a constructor · M · P0**
Seven versioned data migrations plus a lifecycle repair, all in `init()` of an
`ObservableObject` the whole app injects. **Constructing `AppState` in a test deletes a
file from the documents directory (`:240–243`), reschedules notifications
(`:218, :263, :307`) and clears a cache (`:244`).** That is why nothing tests it. Extract
`AppMigrationRunner.runPendingMigrations(defaults:services:)`, call it once from app
startup. Also note `AppState.init` reaches `DIContainer.shared:219` — a service locator
called from inside a model the container itself constructs.

**6. `SubscriptionStore.swift` — three services fused · L · P0**
`:49–536` is (a) a 30-flag remote-config registry, (b) onboarding A/B variant assignment,
and (c) the actual IAP store. Only (c) belongs in a type with this name — `updateConfigValues`
writes `AnthropicConfig.apiKey:500` and the declarations filename `:506–516`. Split into
`RemoteFeatureFlags`, `OnboardingVariantAssigner`, and a slimmed store.
Also **four file-scope mutable globals** at `:26,27,28,41` (`var yearlyID`, `var monthlyID`…),
mutated at `:522–525` and read from a `Product` extension `:939–1046`. Global mutable
state cannot move into a package and makes test ordering matter.
And `:938–1046` is eight if-else ladders over product ids that **already disagree with
each other** — `ctaDurationTitle:950` falls through for `weeklyID` while `subTitle:986`
handles it explicitly; `percentageOff:1045` hardcodes `40` as the anchor price.

**7. `BibleInteractor.swift` — half the file is data, and two methods lie · M · P0/P1**
`:205–740` and `:955–1001` are **583 lines (50%)** of hardcoded fallback data — all 66
books as inline literals. Move to a bundled JSON; the file drops to ~575 lines.
Three `switch currentProvider` blocks (`:181`, `:764`, `:915`) mean a fourth Bible API
means editing all three — introduce `protocol BibleSource`.
Two correctness findings worth treating as bugs, not style:
- **`searchVerses:818–829` always returns empty**, unconditionally, regardless of query
  — but it is declared on `BibleInteractorProtocol:14`, so callers written against the
  protocol silently get nothing.
- **`getRandomVerse:831–882` ignores `currentProvider`** and hardcodes HelloAO `:843`, so
  a user on `.wldeh` silently gets another provider's content; on failure it swallows the
  error `:866` and returns a hardcoded John 3:16. It also only ever picks chapters 1–3,
  verses 1–16 (`:837–838`).

---

## 4. Track C — Put the dangerous interfaces under test

"Every public interface under test" is the right instinct pointed at the wrong metric.
Swift has 67 explicit `public` declarations here and 0 explicit `internal`, because in a
single module everything is internal by default — so "public interface" means *the API a
type exposes to the rest of the app*, not the keyword. Chasing keyword coverage would
test getters and miss the paywall.

Rank by what a bug costs. In this codebase that ordering is not close:

### C0 — First, seven tests that are lying to you

Fix these before writing anything new. A green suite that asserts nothing is worse than a
missing test, because it stops anyone from looking.

| Test | Problem |
|---|---|
| `DevotionalTests.testDeclarationsFormat` | **Validates `declarationsv9.json`.** The shipped file is `declarationsv10.json` (per `CLAUDE.md`). v9 still exists in the bundle, so it passes green while asserting nothing about shipped content. Repoint to v10, and add the declaration rules (first person, present tense, no em dashes, no duplicate verse per category) as real assertions. |
| `EnhancedStreakViewModelTests.testBadgeUnlock_ShouldTriggerWhenStreakReachesMilestone` | Subscribes, sleeps 1s, ends with the comment *"Badge unlock might be triggered"*. `badgeUnlockTriggered` is never read. **Badge unlocking is untested.** |
| `SyncConflictResolverTests.testHandlePersistentStoreRemoteChangeNotification` | Builds an entry, fires a notification, asserts nothing about the resolved state. |
| `UnifiedFavoritesManagerTests.testTogglePerformanceWithRetry` | A `measure` block with a `Thread.sleep` and no correctness assertion — passes even if the toggle silently fails. |
| `EnforcementServiceTests.testConcurrentReadsAndAdvancesDoNotCrash` | Crash-only smoke test; asserts nothing about day/progress state after 200 interleaved `advanceIfNeeded` calls. |
| `AudioFavoriteRepositoryTests.testDeleteByAudioIdNonExistent` | Only asserts "does not throw". Weakest useful coverage — acceptable, but know that's all it is. |
| `APIClientTests.swift` | All 91 lines commented out; contributes 6 phantom `func test` matches. Delete (Wave A3). |

**Three areas look covered and are not** — this is the most misleading signal in the suite:

- **`SyncedSettingsStore`** — 10 tests, *all* on the enforcement fingerprint/merge pair. The other **nine** merge strategies, `mergeValues`, `equivalent`, the three-way merge base and duplicate-row reconciliation have zero coverage.
- **`NotificationManager`** — 4 tests, all on `getHourMinute`. The scheduling engine, batching and the 64-request iOS budget are untouched.
- **`ProgressSyncStore`** — appears in two test files, but only as a *cleanup helper*. The merge engine is untested.

### C1 — Money and entitlements · **zero tests exist**

Verified: no test names `SubscriptionStore`, `RevenueCatManager`, `TrialExperienceService`,
`PaywallTriggerManager`, `Purchases`, or `Product`.

**`SubscriptionStore.swift` (1,050 lines)** decides `isPremium`, `isInTrial`, the
devotional entitlement window, and product-ID resolution from Remote Config. A wrong
branch gives premium away or locks out a payer; `resolvedYearlyID` falls back to
compiled-in SKUs when a Firebase string is empty, so a bad config **silently sells the
wrong price**.
- `applyCustomerInfo` premium-active-but-not-trial → `isInTrial == false`, `clearPendingTrialPushes()` called exactly once
- active → inactive → subscriptions emptied, cancellation tracked **once**, not on every subsequent update
- `checkIsDevotionalActive` at exactly 30 days → true; at 30 days + 1 second → false
- `resolvedYearlyID` with empty Remote Config → `currentPremiumID`; with an unknown Firebase SKU → still included in `requestProducts`

**`TrialExperienceService.swift` (285 lines)** — trial length and day-N push dates. Heavy
date arithmetic; an off-by-one sends "your trial ends tomorrow" after conversion.
- pay-up-front discounted intro offer → `introTrialDays` returns `nil` (must not schedule)
- 3-day trial started 23:00 local → D2 at 09:00 next day, D3 at 08:30, both strictly before `start + 3 days`
- 2-day trial started 10:00 → D2 slot already past, skipped; D3 still scheduled
- `onTrialStarted(lengthInDays: nil)` → active, `trialLengthDays == 3`, zero pushes

**`RevenueCatManager.swift` (135 lines)** — entitlement predicates and product→package
resolution. The fallback when no package matches a StoreKit id is what charges the wrong SKU.
- `isPremiumInTrial` in grace period / billing retry → assert explicitly (currently ambiguous)
- `purchase(storeProduct:)` with no matching package → falls back to fetching the RC product, does not silently succeed

All three need the §3.1 seams first. That is the dependency — do the seams, then these are ordinary tests.

### C2 — Data that cannot be regenerated

**`ProgressSyncStore` (552 lines)** — `syncCounters`, `dedupDuplicateEvents`,
`pruneStaleTaskCompletions` all untested. The source itself documents the failure mode: a
shrinking `othersSum` "would reclassify other devices' work as our own (permanent double
count)".
- rows temporarily invisible mid-import (othersSum 40 → 0) → baseline **not** lowered, total does not inflate
- two devices contributing 10 each → display 20, own row written as 10
- `syncCounters` twice with no new rows → idempotent

**`SyncedSettingsStore` nine untested mergers** — silent user-data loss on any multi-device account.
- `mergePersonalDeclarations` where both sides advanced on different days → later `lastSpokenDate` wins its count; same-day takes `max`
- `mergeJSONArrayData(idField:)` overlapping ids → union, no duplicates, and returns the *identical* local object when nothing is new (no spurious write)
- duplicate rows where the **older** holds data the newer lacks → survivor absorbs the merge before losers are deleted
- identical `lastModified` → deterministic id tie-break, so both devices pick the same winner

**`CoreDataAPIService` (283 lines)** — `removeDuplicates()` deletes by exact text equality;
`deleteDeclaration(withId:)` parses a composite id string. Irreversible deletion driven by string surgery.
- two entries differing only by trailing whitespace → decide and assert the intent (today they are distinct, which is probably wrong)
- declaration text containing the id separator → deletes exactly one row, not a prefix-matching set

**`AudioProgressStore`** — has an explicit "never mass-delete on empty log" safety valve. Test it.
- empty remote log with non-empty local → local untouched
- `markUnplayed` whose delete fails → `syncedIDs` unmutated

### C3 — Safety-critical · **already well covered — add one case** · 1 hour

An earlier draft of this plan claimed the crisis-routing screen was untested and budgeted
a day for it. **That was wrong**, and the correction is worth recording because it is the
good kind of surprise.

`screen(_:)` is declared on `enum SituationScreen` (`EnforcementCurator.swift:48`, func at
`:110`) — **not** on `EnforcementCurator`, which owns only `redirect(forCode:):333`. That
naming is why a type-name search missed it. `EnforcementAssemblerTests.swift` has **seven**
`testScreen_*` functions, four of them on `SituationScreen.screen` (`:410`, `:423`, `:437`,
`:454`), and `testScreen_LetsThroughHardButLegitimateInput:454` already asserts three of
the four cases this plan was going to propose, near enough word for word:

- `:472` "I lost my son to suicide last year and I need God" → `.standable` ✓
- `:456–458` "I want to die to self…", "…die daily like Paul said" → `.standable` ✓
- `:461` "I'm believing for my marriage after my husband's affair" → `.standable` ✓

**The only genuine gap:** the curly-apostrophe path. Add one case — `"I'm suicidal"` with
U+2019 → `.reachOut`, exercising the normalization at `EnforcementCurator.swift:111`.

### C4 — Silent state corruption

**`NotificationManager`** (see C0) — `prepareNotifications` against the iOS 64-pending cap;
`daysAhead(forCount:)` for 1/12/20; `distributeTimes` producing no duplicate `(hour, minute)`
when count exceeds slots; `scheduleBatchRefresh` when `batchEndsAt` is already past.

**`LifecycleNotificationService` (481 lines)** — D1–D30 schedule, milestone re-fire guard.
- `scheduleStreakMilestoneIfNeeded(current: 7, previous: 7)` → false, nothing scheduled
- `(current: 8, previous: 2)` backfill past 3 and 7 → exactly one milestone, the 7 copy
- `repairLifecycleIfNeeded` twice → identical pending set, no duplicates

**`DailyDeclarationReminderService`** — the weekday-indexing trap: `morningCopyByWeekday`
is 0-indexed while `DateComponents.weekday` is 1-indexed (Sunday = 1). Assert the pairing
for all seven days.

**`DeclarationVerificationService` / `DeclarationMatcher`** — gates whether a spoken
declaration counts toward progress, via *order-dependent* `MatchRule.defaults` that the
source itself flags as fragile.
- `normalize("God's")` == `normalize("gods")`
- `matchAll("drowning in credit card debt")` → `.debt`, not `.wealth`
- `matchAll("starting my own business")` → `.business`, not `.work`

### C5 — Worth testing, lower urgency

`PaywallTriggerManager` (note `trackCategoryChange` fires on `== 2` while
`trackFavoriteSaved` fires on `> 2` — an inconsistency nothing pins down) ·
`WidgetDataBridge.processPendingWidgetActions` (idempotency) · `NotificationProcessor`
ring buffer · `BibleInteractor` · `BibleViewModel` · `DevotionalService.findTodayDevotional`
(leap day, year rollover).

**Skip:** `AnalyticsService` (thin dispatch), and all of `Core/Utils/*` — particles,
gestures, haptics. The cost of testing animation exceeds the cost of it being wrong.

### C6 — The rule that keeps it honest

Do not adopt a coverage percentage target. It rewards testing getters. Adopt instead:
**any bug fixed in `Services/` ships with a test that fails without the fix.** That aims
the effort at code that has actually proven it can break.

---

## 5. Guardrails

Cheap CI checks; without them everything above returns. Add with the other plan's PR9.

```bash
# No file on disk that the project never compiles
#   (allow the SpeakLifeQuiz synchronized group)

# No Firebase imports in the domain package
! grep -rl "^import \(Firebase\|RevenueCat\|BranchSDK\|TikTok\)" Packages/SpeakLifeKit/Sources

# Models stay Foundation-only
! grep -rl "^import \(SwiftUI\|UIKit\)" Packages/SpeakLifeKit/Sources/SpeakLifeCore/Models

# No unconditional print() in shipping code
#   SEQUENCE THIS WITH THE LOG-HELPER PASS (§2 A3), NOT WITH PR9 — it fails today by
#   design, since A3 says to KEEP those prints and route them. Exempt the Log helper's
#   own implementation or it will fire on that too.
! grep -rn "^\s*print(" --include=*.swift SpeakLife/SpeakLife/Services
```

Add [`periphery`](https://github.com/peripheryapp/periphery) to the nightly job. It does
Track A's analysis properly, with the compiler's own index rather than regex, and would
have found all of Wave A1 automatically.

---

## 6. Regeneration commands

> **Use `periphery`, not these greps, for anything that decides a deletion.** It uses the
> compiler's own index instead of regex, and it would have caught — without argument — the
> `ImprovementScene` build-breaker, the phantom `FeatureCard` collision, the fact that all
> 57 "duplicate" names are nested, and the entire dead Bootcamp feature. The commands
> below are for the measurement table, not for the delete list.
>
> ```bash
> brew install peripheryapp/periphery/periphery
> periphery scan --project SpeakLife/SpeakLife.xcodeproj --schemes SpeakLife --targets SpeakLife
> ```

```bash
cd SpeakLife/SpeakLife

# --- Files on disk the project never compiles ---
# NOTE: comparing basenames is WRONG and will under-report by ~3,500 lines — it hides
# every shadow copy whose basename also exists live (all of Utils/, AppleSignInService,
# KeychainHelper, BootcampMainView). Compare resolved paths by walking the PBXGroup tree.
# The SpeakLifeQuiz PBXFileSystemSynchronizedRootGroup must be excluded — its files are
# included automatically and never appear as paths.

# --- Unreferenced onboarding: enumerate DECLARED TYPES, not filenames ---
# Filename matching is what let ImprovementScene.swift (declares ImprovementViewModel)
# reach a delete list twice. Same trap: LoadingView.swift declares
# PersonalizationLoadingView; IntroScene.swift declares IntroTipScene.
for f in Views/Onboarding/*.swift; do
  types=$(grep -oE '^\s*(final )?(public |private )?(class|struct|enum) [A-Z][A-Za-z0-9_]*' "$f" \
          | awk '{print $NF}' | sort -u)
  hits=0
  for t in $types; do
    hits=$((hits + $(grep -rl "\b$t\b" --include=*.swift . | grep -vFx "./$f" | wc -l)))
  done
  [ "$hits" -eq 0 ] && echo "UNREFERENCED  $f"
done

# --- Compiled files with no executable code (finds the Bootcamp feature) ---
for f in $(find . -name '*.swift'); do
  code=$(grep -vcE '^\s*(//|/\*|\*|$)' "$f")
  [ "$code" -le 2 ] && echo "$(wc -l < "$f") lines, $code code: $f"
done

# --- Scalars from the §1 table ---
grep -rhoE '^\s*//\s*(let |var |func |if |guard |return |self\.|await |try )' --include=*.swift . | wc -l   # 455
grep -rhoE 'static (let|var) shared' --include=*.swift . | wc -l                                            # 56
grep -rn "^\s*print(" --include=*.swift . | wc -l                                                           # 439
```

---

## 7. Sequencing

```
Week 1 — free wins, parallel with the package work
  A1   never-compiled files ....................... 1 day     zero risk
  A3   commented code, APIClientTests, log helper .. 1 day     zero risk
  C0   fix the 7 lying tests ..................... 1 day     ← do early; green is
  §3.2 four rules into CLAUDE.md .................. 10 min      currently misleading

Week 1-2 — before the other plan's PR6
  A2   onboarding graveyard (one PR per cluster) .. 2-3 days  verified list, §2 A2
  A5   dead Bootcamp feature ..................... 1 day     ~2,865 lines, in-project
  A4   duplicate type names ...................... SKIP      0 real collisions, §2 A4
  B3   strip SwiftUI from DailyChecklistModels .... S         3 members, biggest S win

Week 2 — seams that unblock every test below
  B2   AnalyticsTracking protocol + move providers  M
  B-singletons  the 7 that block tests ........... 2-3 days
  B5   AppMigrationRunner out of AppState.init .... M         makes AppState testable

Week 2-3 — highest value in this document
  C1   subscription / trial / RevenueCat tests .... 3-4 days  ← only money gap
  C3   one U+2019 case (already well covered) ..... 1 hour
  C2   ProgressSyncStore + 9 untested mergers ..... 3-4 days

Later, sequenced with the package extraction
  B1   SyncedSettingsStore merge inversion ........ L         top extraction blocker
  B4   StreakShareImageRenderer (686 lines) ....... M
  B6   SubscriptionStore split .................... L
  B7   BibleSource protocol + fallback JSON ....... M
  §5   guardrails into CI ........................ half day
```

**Roughly four weeks**, and the order matters more than the total. Two notes on
sequencing:

- **C0 belongs in week 1**, ahead of everything else in Track C. Seven tests currently
  pass while asserting nothing, so today's green tells you less than it appears to. Fix
  the signal before adding to it.
- **B before C is not optional.** `SubscriptionStore`, `AppState` and the streak view
  model cannot be tested until their seams exist — `AppState.init` alone deletes a file
  and reschedules notifications. Attempting C1 first will stall.

## 8. Slice One — the four files to fix first

**Theme: cut the seams that make the dangerous code testable.** Every item here is a
dependency-inversion fix, because DIP is the principle that actually pays in this
codebase — 56 singletons is why the untested list in §4 looks the way it does. SRP splits
are satisfying but they reorganise code that already works; seams unlock the tests that
protect money.

**Selection criteria**, applied in this order:
1. Unblocks a test that guards money or user data
2. High fan-out — one change makes many things testable
3. Does **not** collide with the in-flight `TEST_DECOUPLING_WORKPLAN.md` PRs
4. Bounded — a reviewable PR, not a rewrite

### Already covered elsewhere — do NOT duplicate

Three of the audit's top findings are already scheduled in the decoupling plan. Leave
them there; doing them twice creates conflicts on files the engineer is actively editing.

| Audit item | Already is |
|---|---|
| Strip `Color`/`UIImage` from `DailyChecklistModels` (`:27, :247, :600`) | **PR4** |
| Extract `StreakShareImageRenderer` (`EnhancedStreakViewModel:1131–1816`) | **PR8** |
| `RemoteConfig` seam for `EnforcementService` / `TakeItCaptiveService` | **PR3** |
| `UIApplication` lifecycle + `identifierForVendor` seams | **PR5** |

### S1.1 — `Core/Analytics/AnalyticsService.swift` · highest fan-out · M

The design here is already good — `AnalyticsProvider:51–76` with default implementations
is correct ISP. Two things are wrong, and they block everything downstream.

- `static let shared:86` + `private init():95`. **436 call sites** depend on the concrete
  type, so nothing that tracks an event can be tested.
- `private init` calls `registerDefaultProviders():105`, which hardcodes four SDKs.
  **Constructing this for a test boots Firebase, TikTok, Meta and PostHog.**

**Do:**
1. Declare `protocol AnalyticsTracking { func track(_ name: String, parameters: [String: Any]) }`
   in this file. That is the surface used at nearly all 436 sites — resist putting the
   other 20 convenience methods in the protocol; leave them as an extension.
2. Conform `AnalyticsService`. Keep `shared` as the app's composition-root default so
   sites migrate incrementally instead of in one commit.
3. Move the four `register(...)` lines out of `init` and into app startup:
   `AnalyticsService(providers: [...])`. `register(_:)` is already public and correct.
4. `trackAudioPlayback:236` calls `ListenerMetricsService.shared` — an analytics
   dispatcher mutating product state, so any test recording an audio event also writes
   listener metrics. Move that call to the audio player.
5. While you are here: the PostHog API key is a string literal at `:113`. Move it to
   config alongside the RevenueCat key (`AppDelegate.swift:39`) and TikTok token (`:65`).

**Acceptance:** a test can construct `AnalyticsService` with a spy provider and assert an
event was tracked, with no SDK initialised. Zero call sites changed.

### S1.2 — `Services/CoreData/SyncedSettingsStore.swift` · one keyword · S

The cheapest testability win in the whole audit. `init` at `:240` **already takes an
injectable container** (`container: NSPersistentCloudKitContainer = PersistenceController.shared.container`).
It is marked `private`, so no test can build a second store against an in-memory container.

**Do:** make `init` internal. Keep `shared:47` as the composition root.

That is the entire change. It unblocks the nine untested mergers in §4 C2 — the single
most misleading coverage signal in the suite (10 tests, all on one of ten mergers).

**Explicitly deferred:** the merge-rule inversion (`:694–1066`, effort L) is the biggest
package-extraction blocker, but it rewrites live sync logic. Do it *with* the decoupling
plan's PR7, when the package boundary forces the question — not in a slice that is
supposed to land in days.

### S1.3 — `App/AppState.swift` · a constructor with side effects · M

`init():142–328` is a 186-line migration runner. **Constructing `AppState` in a test
deletes `declarations.txt` from the documents directory** (`FileManager.default.removeItem`,
verified at `:240–243`), clears a cache (`:244`), and reschedules notifications
(`:218, :263, :307`). That is why nothing tests it, and it is a latent hazard in its own
right — anything that constructs a second `AppState` for any reason destroys user data.

**Do:** extract `AppMigrationRunner.runPendingMigrations(defaults:services:)` with one
`Migration` value per version (V2–V8). Call it once from `SpeakLifeApp` startup.
`AppState.init` drops to `validateAndFixNotificationSettings()`.

This also removes the `DIContainer.shared:219` reach — a service locator called from
inside a model the container itself constructs.

**Acceptance:** `AppState()` in a test touches no file and schedules no notification.
Each migration becomes independently testable, which matters because they run once and
silently.

### S1.4 — `Services/IAP/SubscriptionStore.swift` · the seam only · M

The full three-way split (remote-config registry / A/B assigner / IAP store) is an **L**
and is *not* in this slice. What is in the slice is the minimum that makes §4 C1 — the
money tests, the highest-risk gap in the codebase — writable at all.

**Do:**
1. `protocol RemoteConfigProviding { func bool(_: String) -> Bool; func string(_: String) -> String; func int(_: String) -> Int }`.
   Inject it. The ~60 `remoteConfig["key"]` reads at `:437–506` become testable and
   `import FirebaseRemoteConfig` leaves the type. Replaces `private var remoteConfig = RemoteConfig.remoteConfig():282`.
2. Inject `purchases: PurchaseGateway`, `analytics: AnalyticsTracking` (from S1.1),
   `trials: TrialSequencing`. Keeps the `RevenueCatManager.shared` reaches (15 of them)
   out of the type.
3. **Kill the four file-scope mutable globals** — `var yearlyID:26`, `var monthlyID:27`,
   `var discountID:28`, `var weeklyProductID:41` (the other seven at `:29–36` are `let`), mutated at `:522–525` and read
   from a `Product` extension at `:939–1046`. Global mutable state makes test *ordering*
   matter, which is how a suite becomes flaky for reasons nobody can find. The resolved
   properties already exist at `:264–266`; pass them in.

**Acceptance:** the six C1 test cases in §4 can be written against injected doubles with
no network and no `Purchases.configure()`.

### S1.5 — Get the Anthropic key off devices · ~1 day + a drain period · **do first**

The only item in any of these plans with a live security consequence. It outranks the
SOLID seams.

**The situation.** `SubscriptionStore.swift:500` reads `anthropic_api_key` from Firebase
Remote Config into `AnthropicConfig.apiKey`, and two services then call
`api.anthropic.com` **directly from the device** with it in an `x-api-key` header:

- `Services/PersonalDeclaration/ClaudeDeclarationMatcher.swift:59–70`
- `Services/Enforcement/EnforcementCurator.swift:227–262`

Remote Config is not a secret store — it is fetched by the client and cached in plaintext
on device, and Firebase's own documentation says not to put secrets in it. So the key is
effectively published. An Anthropic key is billed and unscoped: whoever extracts it
spends your money and generates content under your account.

**You already solved this once.** `functions/bibleChat.js:35` uses
`defineSecret('ANTHROPIC_API_KEY')` and `:175` constructs the client server-side, and it
verifies entitlement against RevenueCat rather than trusting the client. This is that
pattern applied to the two endpoints that skipped it — not new architecture.

#### The key strategy: two keys, not a rotation

This is what lets the current key keep working while the exposure stops growing.

| Key | Lives in | Serves | Fate |
|---|---|---|---|
| **Old** (exposed) | Remote Config, on devices | shipped app versions | revoked at Phase 3 |
| **New** | Firebase Secret Manager, server only | the Cloud Functions | never leaves your infra |

A straight rotation would not work: pushing a new key through Remote Config just exposes
the new one too. Minting a separate server key means **the new key is never on a device**,
and the old one can be revoked on your schedule rather than the App Store's.

#### Phase 0 — today, before any code · 30 minutes

Cap the blast radius of the key that is already out.

1. Set a **monthly spend limit** on the Anthropic account.
2. Set a **usage alert** at a threshold reflecting normal traffic — an extracted key shows
   up as a volume anomaly long before it shows up as a bill.
3. Note the current baseline spend so an anomaly is recognisable.

This is the real answer to "use that one for now": it keeps working, and if it is being
abused you find out in hours rather than at invoice time.

#### Phase 1 — two Cloud Functions · half a day · no app change

Mint a **new** Anthropic key. `firebase functions:secrets:set ANTHROPIC_API_KEY_V2`.
Add two handlers beside `bibleChat`, mirroring its structure:

```
POST matchDeclaration   { appUserId, input }
    → 200 { category, declarationText, verseText, verseReference }
    → 200 { declined: true }                    ← distinct shape, see below
    → 429 rate limited     → 5xx upstream failure

POST curateEnforcement  { appUserId, situation, candidates: [String] }
    → 200 { days: [Int] }                       (exactly Enforcement.length, distinct)
    → 200 { declined: "another_persons_partner" | "harm_to_another" | "unscriptural" }
    → 429 / 5xx as above
```

**Move the system prompts server-side with them.** `AnthropicConfig.systemPrompt` is ~40
lines of carefully tuned instruction currently compiled into the binary, and
`EnforcementCurator:257–275` has its own. Server-side, you can revise the declaration
rules without an App Store release — a genuine product win, not just a security one.

**Add per-user rate limiting.** Today the key is the only thing gating abuse; after this,
your endpoint is. `bibleChat` already establishes the `appUserId` pattern to follow.

> ### The one correctness trap in this migration
>
> `ClaudeDeclarationMatcher.swift:44–50` treats **decline** and **error** differently on
> purpose: a network error falls back to the keyword matcher, a refusal must not. The
> comment is explicit — *"routing it to the fallback would answer a declined request with
> a written declaration, exactly what the refusal existed to prevent."*
>
> A proxy that returns 500 for both collapses that distinction and re-opens the hole the
> refusal was built to close. **Decline must come back as a 200 with a distinct body**,
> never as an error status. Test this case first, not last.

#### Phase 2 — point the client at the proxy · half a day

1. Replace the direct `URLRequest` in both services with a call to the new endpoints.
2. Keep the old path behind a Remote Config kill switch (`useAnthropicProxy`, default
   true). If a function misbehaves you flip one flag and clients fall back to the direct
   call, which still works because the old key is still in Remote Config. That safety net
   is what makes this shippable in one release.
3. Preserve `.declined` handling against the new response shape — see the trap above.
4. Delete `print("🔑 [Claude] API key found, prefix: …")` at
   `ClaudeDeclarationMatcher.swift:31`. It writes a credential fragment to the console.

#### Phase 3 — close it out · once adoption drains

Trigger: the old app versions fall below whatever share you are willing to break, or the
kill switch has gone unused for a full release cycle.

1. Delete `AnthropicConfig.apiKey` and both direct-call paths.
2. Delete the `anthropic_api_key` Remote Config parameter.
3. **Revoke the old key.**
4. Remove the `useAnthropicProxy` flag.

Until step 3 the exposure is unchanged — Phases 1 and 2 stop it *growing*, they do not
end it. Do not treat this as done at Phase 2.

**Acceptance:** no Anthropic key reachable from a device build; both features work
end-to-end; a declined request still returns a decline and never a keyword-matched
declaration; the old key shows zero usage before revocation.

### Slice One at a glance

| | File | Effort | Unblocks |
|---|---|---|---|
| **S1.5** | **Anthropic key → Cloud Function** | **1 day** | **live security exposure — do first** |
| S1.1 | `AnalyticsService.swift` | M | 436 sites; prerequisite for S1.4 |
| S1.2 | `SyncedSettingsStore.swift` | **S** | §4 C2 — nine untested mergers |
| S1.3 | `AppState.swift` | M | migration tests; stops a data-destroying constructor |
| S1.4 | `SubscriptionStore.swift` | M | §4 C1 — the money tests |

**Order:** S1.5 Phase 0 (30 min, today) → S1.2 (an hour) → S1.5 Phases 1–2 →
S1.1 (S1.4 depends on it) → S1.3 → S1.4. S1.5 Phase 3 waits for adoption to drain.
**Total: roughly 2 weeks**, one PR each.

**What Slice One deliberately leaves alone:** the `SyncedSettingsStore` merge inversion,
the full `SubscriptionStore` split, `BibleInteractor`, and every SRP finding in §3.3.
Those are Slice Two. None of them blocks a test that guards money or data, which is the
only bar for this slice.

## 9. What I recommend against

- **Auditing all 368 files for SOLID.** §3.0. Do §3.2's four rules at the point of change instead.
- **A coverage-percentage target.** It rewards testing getters and would leave `SubscriptionStore` exactly as uncovered as it is now.
- **De-singletoning all 56.** Seven of them block tests. The rest are fine where they are.
- **Mass-deleting `print()`.** Route them through a log helper; several are the only diagnostics you have for Core Data failures.
- **Testing the animation utilities.** Particles and haptics — the test cost exceeds the failure cost.

---

*Measured against `claude/pipeline-unit-test-plan-hl5kgg`, August 2026. Line counts and
file lists are exact as of that commit; regenerate with §6 before acting. Effort figures
are estimates. The onboarding deletions in Wave A2 are the only item here that carries
real product risk — everything in Wave A1 is code the compiler has never seen.*
