# Test Architecture — running the unit tests without the app

Companion to `CI_PIPELINE_PLAN.md`. That document covers *why CI is red today*.
This one covers the structural question: **what has to change so the pipeline builds
and runs a unit test bundle only — no app bundle, no simulator, no dependency fetch.**

---

## 1. Why the pipeline builds the whole app today

Nothing in CI asks for the app. The app comes along because of two settings:

```
project.pbxproj:2637   BUNDLE_LOADER = "$(TEST_HOST)"
project.pbxproj:2658   TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SpeakLife.app/…/SpeakLife"
```

`SpeakLifeTests` is an app-hosted iOS unit-test bundle that does `@testable import SpeakLife`
against a **368-file application target**. That single fact forces the entire chain:

| Because… | CI must… |
|---|---|
| the test bundle links against the app binary | compile all 368 app files |
| the app links 6 remote SPM packages | resolve and build Firebase, Facebook, TikTok, RevenueCat, PostHog, ChartView |
| an iOS unit test runs inside its host process | boot a simulator, install the `.app`, launch it |
| the host app is the real app | run `AppDelegate`, Firebase, RevenueCat (live network), Branch, TikTok |

There is no `xcodebuild` flag that removes any of this. It is a **target-graph problem**,
so it needs a target-graph fix.

## 2. The finding that makes this cheap

The obvious assumption is that the app is a tangle of SDK calls and the tests are stuck
to it. **The measurements say otherwise.**

### The tests barely touch the app's dependencies

Every `import` across all 33 test files:

```
33  import XCTest
11  import CoreData
 9  import Combine
 2  import FirebaseFirestore
```

**Zero** test file imports UIKit or SwiftUI. The suite is already logic-only in character.

### Two thirds of the Firebase coupling is not real

86 app files `import Firebase*`. **56 of them — 65% — never reference a single Firebase
symbol.** The import is dead weight, copy-pasted forward. Only 30 files genuinely use it.

Better still, the dead imports include files that are *directly under test*:

| File | `import` | Firebase symbols actually used |
|---|---|---|
| `EnhancedStreakViewModel.swift` | `Firebase` | **none** — only the word "Analytics" in two comments |
| `DataMigrationManager.swift` | `FirebaseAnalytics` | **none** |
| `FavoritesMigrationService.swift` | `FirebaseAnalytics` | **none** |

### What real coupling remains is a handful of lines

Across everything the tests exercise, the genuine non-portable surface is:

| Coupling | Sites | Where |
|---|---:|---|
| `RemoteConfig.remoteConfig()[…].boolValue` | **2** | `EnforcementService.swift:268`, `TakeItCaptiveService.swift:360` |
| `UIApplication.didBecomeActive/didEnterBackground` | **4** | `PersistenceController:309,319`, `SyncedSettingsStore:291`, `ProgressSyncStore:140` |
| `UIDevice.current.identifierForVendor` | **1** | `ProgressSyncStore.swift:69` |
| `var color: Color` on model types | **3** | `DailyChecklistModels:27,247`, `BurstCompletionModel:56` |
| `BGTaskScheduler` / `BackgroundTasks` | **1** | `NotificationManager.swift:330–334` |
| Firestore wire types (`@DocumentID`, `Timestamp`, `FieldValue`) | many | `PrayerWallPost`, `PrayerWallViewModel`, Warrior Room |

That is **eleven call sites** plus one genuinely Firestore-bound feature. The rest of the
252 SwiftUI files, the 16 StoreKit files, the ad SDKs — the tests never go near any of it.

**The app is not entangled with the tests. It is merely stapled to them by `TEST_HOST`.**

---

## 3. Target architecture

Extract the tested logic into a **local Swift package with zero external dependencies**,
and let the app depend on the package rather than the tests depending on the app.

```
Packages/SpeakLifeCore/            ← local SPM package, NO remote dependencies
  Sources/
    SpeakLifeCore/                 pure domain: declarations, bursts, enforcement,
                                   streaks, checklists, thought classifier, catalogs
    SpeakLifePersistence/          Core Data stack, repositories, sync, migrations
                                   (owns SpeakLife.xcdatamodeld as a resource)
  Tests/
    SpeakLifeCoreTests/            ~19 of today's 33 test files
    SpeakLifePersistenceTests/     ~11 of today's 33 test files

SpeakLife.xcodeproj
  SpeakLife.app                    ← views, AppDelegate, SDK wiring, Firestore features
      depends on → SpeakLifeCore, SpeakLifePersistence
      remote packages: Firebase, Facebook, TikTok, RevenueCat, PostHog, ChartView
  SpeakLifeTests.xctest            ← shrinks to the 3 Firestore-bound files only
```

Dependencies point **one way**: app → core. The core never learns that Firebase exists.

### What CI becomes

```yaml
# Job 1 — the unit tests. This is the one that gates PRs.
- run: swift test --package-path Packages/SpeakLifeCore --parallel
```

No Xcode project is opened. No `.app` is produced. No simulator is booted. No remote
package is resolved, because the package declares none. Expected wall clock:
**about one minute, on any macOS runner**, versus 22 today.

```yaml
# Job 2 — proof the app still compiles. Runs on main / nightly, not on every PR.
- run: xcodebuild build -scheme SpeakLife -destination 'generic/platform=iOS'
```

The slow, dependency-heavy, simulator-bound work stops gating anybody's pull request.

---

## 4. The seams that have to be cut

Each one is small, and each is independently mergeable *before* any package exists —
which is what makes this safe to do incrementally rather than as a big-bang refactor.

### S1 — Delete the 56 dead Firebase imports
Mechanical, zero behaviour change, and it immediately shows the true dependency graph.
Add a lint rule (or a CI grep) so they do not creep back. **Do this first.**

### S2 — A feature-flag seam for the two `RemoteConfig` reads
```swift
public protocol FeatureFlagProviding {
    func bool(_ key: String, default: Bool) -> Bool
}
```
Core takes a `FeatureFlagProviding` (defaulting to a static provider). The app injects a
Firebase-backed implementation at launch. Removes `FirebaseRemoteConfig` from
`EnforcementService` and `TakeItCaptiveService` — and from the test path entirely, where
today it means tests read a live remote config.

### S3 — A lifecycle seam for the four `UIApplication` notification observers
Core should not know what `UIApplication` is. Either inject the notification names, or
declare a tiny `AppLifecycleNotifying` protocol the app satisfies. Removes `UIKit` from
`PersistenceController`, `SyncedSettingsStore`, and `ProgressSyncStore`.

### S4 — Inject the device identifier
`ProgressSyncStore.swift:69` calls `UIDevice.current.identifierForVendor`. Becomes an
injected `deviceID: () -> String`. As a bonus, the sync tests stop depending on what
device the simulator claims to be.

### S5 — Move the three `var color: Color` properties into the app target
`DailyChecklistModels` and `BurstCompletionModel` import SwiftUI for **three computed
properties**. Move them to `extension DailyTask { var color: Color }` in the app. The
models become Foundation-only. This is the cheapest seam on the list.

### S6 — Keep `BGTaskScheduler` in the app
`NotificationManager` is 697 lines, of which the `BackgroundTasks` dependency is one
`submit()` call. Split the scheduling call into the app target (or guard it with
`#if canImport(BackgroundTasks)`); the scheduling *logic* — which is what
`NotificationManagerTests` actually tests — moves to core.

### S7 — Decide the Prayer Wall / Warrior Room boundary
This is the only genuine Firestore coupling: `@DocumentID`, `Timestamp`, `FieldValue`
are on the model types themselves. Two options:

- **(a) Leave them hosted.** `SpeakLifeTests` shrinks to 3 files, still app-hosted, and
  runs on the nightly job. Zero refactor cost. Recommended for the first pass.
- **(b) Split wire type from domain type.** A plain `PrayerWallPost` in core plus a
  `PrayerWallPostDocument` in the app that maps to and from it. Better architecture,
  more work, and it can be done later without disturbing anything else.

Take (a) now. Revisit (b) if the Prayer Wall grows.

### S8 — The Core Data model in a package *(highest technical risk)*
`SpeakLife.xcdatamodeld` moves into `Sources/SpeakLifePersistence/Resources/`, declared
as `.process(...)`. SwiftPM does compile `.xcdatamodeld` with `momc`, and
`PersistenceController.swift:103` changes from `Bundle(for:)` to `Bundle.module`.

**Verify this early with a throwaway package containing nothing but the model and one
fetch test.** It is the single assumption in this plan that could force a rethink. If it
does not hold, the fallback is clean: `SpeakLifeCore` still goes to `swift test` (the
~19 pure files, the bulk of the suite), and the 11 persistence tests stay on a
simulator job that builds only the persistence package — still no app bundle, still no
Firebase.

---

## 5. Sequencing

| Step | Work | Ships value on its own? |
|---|---|---|
| 1 | S1 — delete 56 dead imports | yes: honest dependency graph, faster compile |
| 2 | Spike S8 — `.xcdatamodeld` in a bare package | yes: de-risks the whole plan in a day |
| 3 | S2, S5 — flag seam + `Color` extraction | yes: removes RemoteConfig from the test path |
| 4 | S3, S4, S6 — lifecycle, device ID, BGTask | yes: core becomes platform-agnostic |
| 5 | Create `Packages/SpeakLifeCore`, move pure sources + ~19 test files | the payoff |
| 6 | Add `SpeakLifePersistence`, move the Core Data tier + ~11 test files | gated on step 2 |
| 7 | Repoint CI: `swift test` gates PRs, `xcodebuild build` moves to nightly | the goal |
| 8 | S7(b) if wanted | optional |

Steps 1–4 are **pure refactors inside the existing project**. Nothing about the build
changes, CI stays as it is, and each can merge on its own. Only step 5 introduces the
package. If the effort stalls after step 4, everything done so far still stands on its
own merits.

**Rough size:** steps 1–4 are a few days of mechanical, reviewable work. Step 5 is the
big one — moving files and fixing access levels across ~19 test files and their
sources — call it a week. Step 6 depends entirely on the step 2 spike.

## 6. What this buys

| | Today | After |
|---|---|---|
| PR feedback | ~22 min (never green) | ~1–2 min |
| Files compiled to run tests | 368 app + 6 SDK graphs | the package only |
| Remote packages resolved | 6, incl. firebase-ios-sdk | **0** |
| Simulator required | yes | **no** |
| Network required at test time | yes (RevenueCat, RemoteConfig) | **no** |
| Runner | `macos-26` (scarce, slow) | any macOS runner |
| A test can fail because | almost anything | the code under test |

The last row is the real point. Today a red check means the SDK stack, the simulator,
the network, the runner image, or the code — and reading which takes 22 minutes. After
this, red means the code.

## 7. Relationship to `CI_PIPELINE_PLAN.md`

These are complements, not alternatives. The tactical plan gets CI green in about a week
so the team can stop merging on override. This one removes the reason it was fragile.

Do the tactical fixes first — in particular gating `AppDelegate` under test, which stays
correct and valuable no matter how far this refactor goes. Start S1 in parallel, since
deleting dead imports cannot break anything.

---

*Every count in this document was measured against the tree at
`claude/pipeline-unit-test-plan-hl5kgg`. Two things are stated but not verified,
because this environment has no macOS or Xcode: the `.xcdatamodeld`-in-SwiftPM
behaviour (S8, spike it) and the projected timings in §6 (extrapolated from the current
build's shape, not benchmarked).*
