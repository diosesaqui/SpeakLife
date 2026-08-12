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
| **Never compiled** (on disk, absent from `project.pbxproj`) | **4,757 lines** |
| Onboarding files with zero inbound references | 22 files / 8,459 lines |
| Types declared in more than one file | 57 names |
| Commented-out code lines | 1,091 |
| `print()` in shipping code | 439 (only 28 files use `#if DEBUG` at all) |
| Singletons (`static let shared`) | 56 declarations |
| `AnalyticsService.shared` call sites | 436 |
| `fatalError` / `as!` / `try!` | 17 / 1 / 0 |
| Unused asset sets | 9 |
| Tests touching subscription or entitlement logic | **0** |

Two of those deserve to be read twice: **4,757 lines that the compiler has never seen**,
and **zero tests on the code that decides whether someone has paid.**

---

## 2. Track A — Delete what nothing runs

Ordered by risk, lowest first. Wave 1 is genuinely risk-free; by Wave 4 you are making
judgement calls. Do not reorder.

### Wave A1 — Files the compiler has never seen · ~4,757 lines · risk: none

These exist on disk but are absent from `project.pbxproj`, so they are **already not part
of the app**. Deleting them cannot change behaviour — it only stops them appearing in
search results and misleading whoever greps next.

**A1.1 — The shadow `Utils/` directory · 2,816 lines.**
`SpeakLife/Utils/` duplicates the live `SpeakLife/Core/Utils/`. Only `Core/Utils` is in
the project (verified by walking the `PBXGroup` tree, not by guessing from the path).
The copies have **diverged**, which means someone has been editing a file that never
compiles:

| File | Divergence |
|---|---|
| `Utils/GestureDelights.swift` | 166 differing lines |
| `Utils/PremiumHaptics.swift` | 89 |
| `Utils/AudioDelights.swift` | 75 |
| `Utils/CategoryParticleEffects.swift` | 28 |
| `Utils/CelebrationAnimations.swift` | 8 |
| `Utils/MicroInteractions.swift` | identical |

> **Check before deleting.** Divergence runs both ways. Diff each pair and confirm the
> live `Core/Utils/` copy is the newer one — if a real fix landed only in the dead copy,
> port it across first. Budget an hour for this; it is the one part of Wave A1 that is
> not mindless.

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

**A1.3 — Duplicate service copies · 326 lines.** Live copy named first:

- `Views/Community/AppleSignInService.swift` is live → delete `Services/Auth/AppleSignInService.swift` (222 lines, **diverged** — diff first)
- `Services/IAP/Security/KeychainHelper.swift` is live → delete `Services/Security/KeychainHelper.swift` (104 lines, identical, safe)

> **Do NOT delete `Views/SpeakLifeQuiz/`.** Eight files there look orphaned by the same
> test and are not: `SpeakLifeQuiz` is the project's one
> `PBXFileSystemSynchronizedRootGroup`, so its contents are included automatically
> without appearing as paths. This is the single false positive in the scan — it is
> called out here because the naive version of this analysis says delete them.

**Verify:** `xcodebuild build -scheme SpeakLife -destination 'generic/platform=iOS'`
must produce a byte-identical result. Nothing here was ever compiled.

---

### Wave A2 — The onboarding graveyard · ~8,459 lines · risk: low, verify first

22 files in `Views/Onboarding/` that no other file references. They read as accumulated
A/B-test variants that were never removed when a winner was picked.

```
NewOnboardingScreens 2414   PolishedCrossOnboardingFlow 1307   EnhancedOnboardingScreensRefactored 569
IntroScene 527   SpiritualWarfareContentScreens 524   SpiritualWarfareOnboardingView 394
CombinedPersonalizationScene 334   AudioDevotionalsTutorial 302   FixedSpiritualWarfareScreens 237*
DemoExperienceView 232   PersonalizationSummaryScene 208   DevotionalsTutorial 206
ImprovementScene 202   AffirmationsTutorial 192   HookScene 139   WidgetScene 125
TimeNotificationStepper 114   LoadingView 112   BenefitScene 89   HelpUsGrowView 89
WhatsNewView 80   EnhancedOnboardingModels 63
```
\* already covered by Wave A1.2.

**Before deleting any of these, find the variant router.** The app runs a live onboarding
A/B test across `product / identity / quiz / outcomes / warfare / promises / closer`. A
view reached only by a variant string will not show up in a reference scan. Confirm the
live destination set first, then delete what is not in it.

Also review, separately, the files with exactly **one** inbound reference — a single
reference is often a dead file referenced by another dead file:
`EnhancedOnboardingViewRefactored` (528), `FirstDeclarationGuideView` (325),
`CloserOnboardingView` (1544), `IdentityOnboardingView` (730), `OnboardingDailyBurstScreen` (516).
`CloserOnboardingView` and `IdentityOnboardingView` are almost certainly live variants —
check, don't assume.

**Ship as one PR per cluster, not one 8,000-line PR.** Onboarding is the highest-stakes
surface in the app; a reviewer can sanity-check "the warfare variant's dead screens" and
cannot meaningfully review eight thousand deleted lines at once.

**Verify:** build, then walk every live onboarding variant on a device before merging.

---

### Wave A3 — Dead code inside living files · risk: low

- **1,091 lines of commented-out code.** Delete on sight. Git remembers; commented code
  does not. Exempt genuine explanatory comments — the filter matches lines beginning
  `// let`, `// func`, `// if`, `// return`, `// self.`, so it is already narrow.
- **`APIClientTests.swift`** — all 91 lines commented out, 6 phantom tests. Delete the file.
- **9 unused asset sets.** Confirm against `WidgetBackground` and `AccentColor`, which
  are referenced by the system rather than by name in code — those two stay.
- **~440 `print()` calls.** Do not mass-delete: several are load-bearing diagnostics
  (`PersistenceController` has 46 and they are how Core Data failures get diagnosed).
  Route them through one `Log` helper that compiles to nothing in release. That is a
  single mechanical pass and turns 439 unconditional writes into zero shipped.

---

### Wave A4 — Duplicate type names · 57 names · risk: medium

Not all are bugs. `CodingKeys` and `Coordinator` repeating across files is idiomatic
Swift and should be left alone. The ones that matter are the accidental collisions:

- `Event` — `Core/Analytics/Events.swift` **and** `Services/CoreData/ProgressSyncStore.swift`.
  Two unrelated concepts sharing a name in one module. Rename the sync one to
  `SyncEvent`; this becomes mandatory when the package boundary lands.
- `UserPreferences` — `Services/ML/RecommendationEngine.swift` and
  `Services/Widget/SmartContentProvider.swift`.
- `ParticleType`, `HeartData`, `StatCard`, `FeatureCard`, `Step`, `Feature`, `Origin` —
  collisions between unrelated features. Namespace or rename.

Most of the remaining collisions live in the `Utils/` duplicate directory and disappear
for free with Wave A1.

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

- **Analytics** — leave the 436 call sites. Make `AnalyticsService.shared` swappable
  behind the `AnalyticsProviding` protocol that already exists (`FirebaseAnalyticsProvider`
  is already in `Core/Analytics/AnalyticsService.swift`). You have the seam; it just is
  not injectable. One change, all 436 sites become test-neutral.
- **The seven singletons that block tests** — `PersistenceController`, `ProgressSyncStore`,
  `SyncedSettingsStore`, `EnforcementService`, `BurstCompletionTracker`,
  `NotificationManager`, `SubscriptionStore`. Give each an injectable initializer while
  keeping `.shared` as the app's default. This is additive: no call site changes, and
  every consumer becomes testable.
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

### 3.3 Named targets

A detailed per-file audit of the seven largest files is being produced separately; when it
lands, its findings slot in here, ranked *blocks-extraction → blocks-testing → readability*.
The known ones already:

| File | Lines | Issue | Fix |
|---|---:|---|---|
| `EnhancedStreakViewModel.swift` | 1,945 | Streak logic + share-image rendering in one type | Extract `StreakShareCardRenderer` (`:1132`, `:1484–1517`) to the view layer. Rest becomes Foundation + Combine. Required by the extraction anyway. |
| `SubscriptionStore.swift` | 1,050 | Money logic, zero tests, singleton | §4 item 1 |
| `SyncedSettingsStore.swift` | 1,066 | Merge logic + UIKit lifecycle + storage | Seam the lifecycle (already scheduled as PR5a in the other plan) |
| `AnalyticsService.swift` | 699 | Provider seam exists but is not injectable | §3.1 |

---

## 4. Track C — Put the dangerous interfaces under test

"Every public interface under test" is the right instinct pointed at the wrong metric.
Swift has 67 explicit `public` declarations here and 0 explicit `internal`, because in a
single module everything is internal by default — so "public interface" means *the API a
type exposes to the rest of the app*, not the keyword. Chasing keyword coverage would
test getters and miss the paywall.

Rank by what a bug costs. In this codebase that ordering is not close:

### C1 — Money and entitlements · **no tests exist at all**

`Services/IAP/SubscriptionStore.swift`, 1,050 lines, decides who has paid. Nothing in the
484-test suite touches it, nor `Purchases`, nor entitlements, nor `Product`.

A bug here either locks out a paying subscriber or gives the product away. Start here.
Concrete cases:

- entitlement stays active through a renewal boundary
- expired subscription loses access, and does so exactly once
- a restore on a fresh device re-grants the right tier
- lifetime purchase is never treated as expired
- a failed/cancelled purchase leaves prior state untouched
- promo code and Family Sharing entitlements resolve to the same access as a direct purchase

This needs the seam from §3.1 before it can be written. That is the dependency — do it
first, then the tests are ordinary.

### C2 — Data that cannot be regenerated

Core Data writes, CloudKit sync merges, and migrations. Partially covered today (11 test
files) and the coverage is real. Gaps to close: conflict resolution when two devices
write the same row, and migration from each shipped schema version rather than only the
current one.

### C3 — Silent state corruption

Streaks, progress, notification scheduling. Well covered already — this is where most of
the 484 tests live. Maintain, don't expand.

### C4 — Large untested services

Ranked by lines with no test naming them:

| Lines | File | Worth testing? |
|---:|---|---|
| 1,166 | `Services/Bible/BibleInteractor.swift` | yes — parsing and reference resolution |
| 1,050 | `Services/IAP/SubscriptionStore.swift` | **C1** |
| 865 | `Services/ML/RecommendationEngine.swift` | yes if it ships; verify it is reachable first |
| 730 | `Services/ML/AIIntelligenceService.swift` | verify reachable first |
| 719 | `ViewModels/BibleViewModel.swift` | yes |
| 699 | `Core/Analytics/AnalyticsService.swift` | low value — thin dispatch |

The `Core/Utils/*` entries in that scan (particles, gestures, haptics) are animation code.
Leave them untested; the cost of testing them exceeds the cost of them being wrong.

### C5 — The rule that keeps it honest

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
! grep -rn "^\s*print(" --include=*.swift SpeakLife/SpeakLife/Services
```

Add [`periphery`](https://github.com/peripheryapp/periphery) to the nightly job. It does
Track A's analysis properly, with the compiler's own index rather than regex, and would
have found all of Wave A1 automatically.

---

## 6. Regeneration commands

```bash
# Files on disk the project never compiles (excluding the SpeakLifeQuiz sync group)
# — see the python in this plan's companion analysis; the short version:
comm -13 <(grep -oE 'path = "?[^";]+\.swift"?;' SpeakLife/SpeakLife.xcodeproj/project.pbxproj \
           | sed -E 's/path = "?([^";]+)"?;/\1/' | xargs -n1 basename | sort -u) \
         <(find SpeakLife/SpeakLife -name '*.swift' | xargs -n1 basename | sort -u)

# Onboarding files nothing references
cd SpeakLife/SpeakLife && for f in Views/Onboarding/*.swift; do
  b=$(basename "$f" .swift)
  n=$(grep -rl "\b$b\b" --include=*.swift . | grep -v "$f" | wc -l)
  [ "$n" -eq 0 ] && echo "$b"
done

# Commented-out code
grep -rhoE '^\s*//\s*(let |var |func |if |guard |return |self\.|await |try )' --include=*.swift . | wc -l

# Duplicate type names / singletons / prints
grep -rhoE 'static (let|var) shared' --include=*.swift . | wc -l
grep -rn "^\s*print(" --include=*.swift . | wc -l
```

---

## 7. Sequencing

```
Now, in parallel with the package work
  A1  never-compiled files ....................... 1 day    zero risk
  A3  commented code, APIClientTests, log helper .. 1 day    zero risk

Before the other plan's PR6
  A2  onboarding graveyard ....................... 2-3 days  needs router check
  A4  duplicate type names ....................... 1 day

Unblocks Track C
  B   analytics + 7 singleton seams .............. 2-3 days

Then, highest value in this document
  C1  subscription & entitlement tests ........... 3-4 days
  C2  sync conflict + migration gaps ............. 2-3 days
  C4  BibleInteractor, BibleViewModel ............ 3-4 days

Ongoing
  §3.2 four rules into CLAUDE.md ................. 10 minutes
  §5   guardrails into CI ........................ half day
```

**Roughly three weeks**, and the order matters more than the total: A1 and A3 are free
and immediately shrink what PR6 has to convert, while C1 closes the only gap in this
document where a bug costs real money.

## 8. What I recommend against

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
