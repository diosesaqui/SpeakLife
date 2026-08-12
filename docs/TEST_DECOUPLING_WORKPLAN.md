# Work Plan: Decouple the unit tests from the app target

**Owner:** _unassigned_
**Branch:** `feature/test-decoupling` (cut from `main`)
**Goal:** CI runs `swift test` against a dependency-free local package in ~1–2 minutes,
instead of a 22-minute `xcodebuild test` that compiles the whole app, resolves six
remote SPM packages, boots a simulator and launches the real product.

This document is self-contained. You do not need to read
`CI_PIPELINE_PLAN.md` (why CI is red today) or `TEST_ARCHITECTURE_PLAN.md`
(the reasoning behind the target shape) to execute it, though both are worth
skimming once.

---

## 0. Why this is needed, in five lines

`SpeakLifeTests` is an app-hosted bundle: `TEST_HOST` and `BUNDLE_LOADER`
(`project.pbxproj:2637`, `:2658`) point it at `SpeakLife.app`, and it does
`@testable import SpeakLife` against a 368-file **application** target. So running 484
logic assertions requires compiling the app, linking Firebase / Facebook / TikTok /
RevenueCat / PostHog / ChartView, booting a simulator, and launching the app —
including `AppDelegate`, which still calls live RevenueCat and Firebase.

No `xcodebuild` flag removes any of that. It is a target-graph problem, so the fix is a
target-graph change.

## 1. The measurements this plan is built on

All verified against `main` at the time of writing. Re-run any of these if you want to
confirm before starting.

| Finding | Number |
|---|---|
| App source files | 368 |
| Files importing `Firebase*` | 86 |
| …that never reference a Firebase symbol (**dead imports**) | **64** |
| …that genuinely use Firebase | 22 |
| Test files / test methods | 33 / 484 |
| Test files importing UIKit or SwiftUI | **0** |
| Everything the tests import | `XCTest`(33), `CoreData`(11), `Combine`(9), `FirebaseFirestore`(2) |
| Non-portable call sites across all tested code | **11** (see §6) |

The important one is the last: outside of the Prayer Wall / Warrior Room feature, the
entire test suite's coupling to the app's platform and SDK surface is eleven call sites.

## 2. Target architecture

Three targets in **one** local package. Dependencies point one way, and the graph is
verified acyclic (§6.8).

```
Packages/SpeakLifeKit/                 ← local SPM package, ZERO remote dependencies
  Sources/
    SpeakLifeCore/          Foundation only
                            models, enforcement assembler/curator/prompt,
                            thought classifier, burst session, checklist models
    SpeakLifePersistence/   → depends on Core. CoreData + CloudKit.
                            persistence controller, repositories, ProgressSyncStore,
                            SyncedSettingsStore, migrations, owns SpeakLife.xcdatamodeld
    SpeakLifeServices/      → depends on Core + Persistence.
                            EnforcementService, streak/checklist engine,
                            TakeItCaptiveService, notification scheduling logic
  Tests/
    SpeakLifeCoreTests/  SpeakLifePersistenceTests/  SpeakLifeServicesTests/

SpeakLife.xcodeproj
  SpeakLife.app           → depends on SpeakLifeKit. Views, AppDelegate, SDK wiring,
                            Firestore features. Keeps the 6 remote packages.
  SpeakLifeTests.xctest   → shrinks to 3 Firestore-bound files. Nightly only.
```

**Why three targets and not two.** `EnhancedStreakViewModel` genuinely depends on
`ProgressSyncStore` and `SyncedSettingsStore` — not incidentally, but through
`ProgressSyncStore.shared.events(ofKind:)` (`:313`), `SyncedSettingsStore.settingsDidChange`
(`:137`) and `SyncedSettingsStore.mergedEnforcementProgress` (`EnforcementService.swift:197`).
The service layer sits **on top of** persistence, so it cannot be a sibling of it.

Splitting Core out separately is what de-risks the plan: Core has no Core Data in it, so
it ships to `swift test` even if the `.xcdatamodeld` spike (§4, PR2) fails.

### What CI becomes

```yaml
# Gates every PR. No Xcode project, no .app, no simulator, no package resolution.
- run: swift test --package-path Packages/SpeakLifeKit --parallel

# Proves the app still compiles. main + nightly only.
- run: xcodebuild build -scheme SpeakLife -destination 'generic/platform=iOS'
```

---

## 3. PR sequence

Nine PRs. **PR1–PR5 are pure refactors inside the existing project** — the build does not
change, CI stays as it is, and each merges independently. Only PR6 introduces the
package. If the effort stops after PR5, everything landed still stands on its own.

Land them in order. PR1 and PR2 can go in parallel on day one.

---

### PR1 — Delete 64 dead Firebase imports

**Type:** mechanical, zero behaviour change. Start here.

64 files `import Firebase*` and never reference a Firebase symbol. Two of them
(`DataMigrationManager`, `FavoritesMigrationService`) are directly under test, and one
(`EnhancedStreakViewModel`) imports `Firebase` because the word "Analytics" appears in
two comments.

**Steps**

1. Regenerate the list rather than trusting the one in §7 (the tree moves):
   ```bash
   cd SpeakLife/SpeakLife
   while IFS= read -r f; do
     grep -qE '\b(Analytics|FirebaseApp|Firestore|RemoteConfig|Timestamp|DocumentID|DocumentReference|DocumentSnapshot|QuerySnapshot|FieldValue|Installations|Crashlytics|Messaging|StorageReference|AuthDataResult)\b' \
       <(grep -vE '^\s*(//|///|\*)' "$f") || echo "$f"
   done < <(grep -rl "^import Firebase" --include=*.swift .)
   ```
   Note the `grep -v` on comment lines — without it you get 57 instead of 64, because
   seven files only mention Firebase symbols in prose.
2. Delete the matching `import Firebase*` line from each.
3. Build the app. The compiler is the check: if an import was live, it fails.

**Verify:** `xcodebuild build -scheme SpeakLife -destination 'generic/platform=iOS'` succeeds.

**Acceptance criteria**
- [ ] Files importing `Firebase*` drops from 86 to 22
- [ ] App builds clean
- [ ] No behaviour change (no non-import lines touched)

**Estimate:** half a day.

---

### PR2 — Spike: `.xcdatamodeld` as a SwiftPM resource

**Type:** throwaway spike. **This is the one assumption that could force a redesign — do
it early.** Nothing is committed from this PR except the answer.

`SpeakLife.xcdatamodeld` currently lives at `SpeakLife/SpeakLife/Models/`, and
`PersistenceController.swift:103` loads it via `Bundle(for: PersistenceController.self)`.
In a package that becomes `Bundle.module`. SwiftPM does compile `.xcdatamodeld` with
`momc`, but confirm it on your Xcode before betting PR7 on it.

**Steps**

1. Create a scratch package outside the repo.
2. Copy in `SpeakLife.xcdatamodeld` as `.process("Resources/SpeakLife.xcdatamodeld")`.
3. Copy in the generated `NSManagedObject` subclasses from `Models/CoreData/`.
4. Write one test: load an `NSPersistentContainer` from `Bundle.module`, insert an
   `AffirmationEntry`, fetch it back.
5. `swift test`.

**Deliverable:** a comment on this PR saying it works or does not, with the momc output
if it does not.

**If it fails:** PR7 changes shape — persistence tests stay on a simulator job that
builds only the persistence target (still no app bundle, still no Firebase, still a big
win). PR6 and the ~10 Core test files are unaffected either way. Do not let this block
PR3–PR6.

**Estimate:** one day.

---

### PR3 — Feature-flag seam (removes `FirebaseRemoteConfig` from tested code)

**Type:** dependency inversion. Two call sites.

```swift
// EnforcementService.swift:268
var isEnabled: Bool { RemoteConfig.remoteConfig()["enforcementEnabled"].boolValue }

// TakeItCaptiveService.swift:360
var isEnabled: Bool { RemoteConfig.remoteConfig()["guardEnabled"].boolValue }
```

Today the tests route *around* these. `EnforcementService.swift:270` says so in a
comment: _"Tests exercise `activeDay` directly to stay clear of Remote Config."_ That
comment is the design telling you the dependency is in the wrong place.

**Steps**

1. Add to the domain layer:
   ```swift
   public protocol FeatureFlagProviding {
       func bool(_ key: String, default defaultValue: Bool) -> Bool
   }

   public struct StaticFeatureFlags: FeatureFlagProviding {
       private let values: [String: Bool]
       public init(_ values: [String: Bool] = [:]) { self.values = values }
       public func bool(_ key: String, default d: Bool) -> Bool { values[key] ?? d }
   }
   ```
2. Inject `FeatureFlagProviding` into `EnforcementService` and `TakeItCaptiveService`
   (initializer parameter with a default, matching the existing style at
   `TakeItCaptiveService.swift:96`).
3. In the app target, add the Firebase-backed implementation and wire it at composition
   time:
   ```swift
   struct RemoteConfigFlags: FeatureFlagProviding {
       func bool(_ key: String, default d: Bool) -> Bool {
           RemoteConfig.remoteConfig()[key].boolValue
       }
   }
   ```
4. Update `EnforcementServiceTests` and `TakeItCaptiveServiceTests` to inject
   `StaticFeatureFlags` and **delete the workaround comment** at `EnforcementService.swift:270`.
5. Now test `isEnabled` directly — it was previously untestable.

**Acceptance criteria**
- [ ] `EnforcementService.swift` and `TakeItCaptiveService.swift` no longer import `FirebaseRemoteConfig`
- [ ] Tests inject a static provider; no network at test time
- [ ] New tests cover `isEnabled` in both true and false states
- [ ] Flag behaviour in the running app is unchanged (verify manually on device or sim)

**Estimate:** half a day.

---

### PR4 — Move `var color: Color` out of the model layer

**Type:** the cheapest seam on the list. Three computed properties.

| File | Line | Property |
|---|---:|---|
| `Views/Declaration View/Streak/DailyChecklistModels.swift` | 27 | `ProgressionPhase.color` |
| `Views/Declaration View/Streak/DailyChecklistModels.swift` | 247 | (second `color`) |
| `Models/BurstCompletionModel.swift` | 56 | `color` |

`DailyChecklistModels.swift` is 1,640 lines and its **only** SwiftUI usage is these two
properties. Same for `BurstCompletionModel`.

**Steps**

1. Delete each `var color: Color { … }` from the model file.
2. Recreate it verbatim as an extension in the app target — suggested home:
   `Views/Declaration View/Streak/ProgressionPhase+Appearance.swift`.
   ```swift
   import SwiftUI
   extension ProgressionPhase {
       var color: Color { switch self { case .foundation: .blue; … } }
   }
   ```
3. Remove `import SwiftUI` from both model files.

Call sites do not change. This is the pattern to reach for whenever a domain type needs
something from a higher layer: put the code in the higher layer as an `extension`.

**Acceptance criteria**
- [ ] `DailyChecklistModels.swift` and `BurstCompletionModel.swift` import Foundation only
- [ ] No call site changed
- [ ] App builds and the checklist UI looks identical

**Estimate:** 2 hours.

---

### PR5 — Platform seams: lifecycle, device ID, background tasks

**Type:** dependency inversion. Removes `UIKit` and `BackgroundTasks` from what becomes
the package.

**5a — Lifecycle notifications (4 sites).** These are the only reason three persistence
files import UIKit:

| File | Line | Symbol |
|---|---:|---|
| `Services/CoreData/PersistenceController.swift` | 309 | `UIApplication.didBecomeActiveNotification` |
| `Services/CoreData/PersistenceController.swift` | 319 | `UIApplication.didEnterBackgroundNotification` |
| `Services/CoreData/SyncedSettingsStore.swift` | 291 | `UIApplication.didBecomeActiveNotification` |
| `Services/CoreData/ProgressSyncStore.swift` | 140 | `UIApplication.didBecomeActiveNotification` |

Declare the names in the package and have the app forward the real ones, or inject the
`Notification.Name` pair. Either works; injecting the names is smaller.
**Bonus:** tests can then drive foreground/background transitions directly instead of
hoping the simulator posts them.

**5b — Device identifier (1 site).** `ProgressSyncStore.swift:69` calls
`UIDevice.current.identifierForVendor`. Make it an injected `deviceID: () -> String?`,
defaulting to the UIKit implementation in the app. Read the comment above that line
first — the vendor-ID pinning is deliberate, and the seam must preserve it.

**5c — Background task scheduling (1 site).** `NotificationManager.swift` is 697 lines;
its `BackgroundTasks` dependency is one `BGTaskScheduler.shared.submit()` at `:334`.
Move the submit call to the app target (or guard with `#if canImport(BackgroundTasks)`).
The *scheduling logic* — which is what `NotificationManagerTests` exercises — stays.

**Acceptance criteria**
- [ ] `PersistenceController`, `SyncedSettingsStore`, `ProgressSyncStore` no longer import UIKit
- [ ] `NotificationManager` no longer imports `BackgroundTasks`
- [ ] Sync still works across two devices (manual check — `deviceId` is load-bearing)
- [ ] Background refresh still schedules on device

**Estimate:** 1–2 days. 5b needs care; the rest is mechanical.

---

### PR6 — Create the package, move `SpeakLifeCore`

**Type:** the first structural change. Biggest single PR — consider splitting per target
if review gets unwieldy.

**Steps**

1. Create `Packages/SpeakLifeKit/Package.swift` with **no** `dependencies:` entry. That
   empty array is the enforcement mechanism: `import Firebase` inside the package will
   not compile.
2. Move the Foundation-only sources (§8 table, Core rows).
3. Add the package to the Xcode project as a local package; add `SpeakLifeCore` to the
   app target's frameworks.
4. Add `import SpeakLifeCore` where the app needs it and **mark the used declarations
   `public`**.
5. Move the Core test files (§8) into `Tests/SpeakLifeCoreTests/`, switching
   `@testable import SpeakLife` → `@testable import SpeakLifeCore`.
6. `swift test --package-path Packages/SpeakLifeKit`.

> **Read this before estimating.** The bulk of the work is not moving files — it is
> access-control. Inside one module everything is implicitly `internal` and visible.
> Once `SpeakLifeCore` is its own module, every type, initializer, property and method
> the *app* touches needs `public`, and every memberwise init needs an explicit
> `public init`. Expect hundreds of declarations across the domain layer. It is
> mechanical and compiler-guided, but it is the reason this PR is a week and not a day.
>
> The tests are unaffected — `@testable import` still sees `internal`. Only the app→package
> boundary needs widening, so **do not blanket-`public` everything**: let the compiler tell
> you what the app actually uses, and leave the rest `internal`.

**Acceptance criteria**
- [ ] `swift test --package-path Packages/SpeakLifeKit` passes with no simulator
- [ ] `Package.swift` declares zero remote dependencies
- [ ] App builds and runs; no behaviour change
- [ ] Moved test files deleted from `SpeakLifeTests`

**Estimate:** ~1 week, dominated by access-control.

---

### PR7 — Move `SpeakLifePersistence`

**Gated on PR2.** Same shape as PR6 for the Core Data tier: repositories, persistence
controller, sync stores, migrations, and `SpeakLife.xcdatamodeld` as a package resource.
`PersistenceController.swift:103` switches `Bundle(for:)` → `Bundle.module`.

Move the 11 `SpeakLifeTests/CoreData/**` files to `Tests/SpeakLifePersistenceTests/`.

**Do the fixes from `CI_PIPELINE_PLAN.md` §Phase 1 as part of this PR**, since you are
already in these files: four test sites build a `PersistenceController`, take
`.container.viewContext` off it and never retain the controller, so the container
deallocates before the first assertion. This is the prime suspect for the `testFetchByCategory`
SIGSEGV currently failing CI:

| File | Line |
|---|---:|
| `CoreData/AffirmationRepositoryTests.swift` | 23 |
| `CoreData/JournalRepositoryTests.swift` | 23 |
| `CoreData/Services/FavoritesMigrationServiceTests.swift` | 175 |
| `CoreData/Services/UnifiedFavoritesManagerTests.swift` | 289 |

**Acceptance criteria**
- [ ] Persistence tests pass under `swift test` (or on the reduced simulator job if PR2 failed)
- [ ] The four sites retain their controller and release it in `tearDown`
- [ ] `testFetchByCategory` no longer crashes

**Estimate:** 3–5 days, plus whatever PR2 revealed.

---

### PR8 — Move `SpeakLifeServices`

Enforcement service, the streak/checklist engine, `TakeItCaptiveService`, notification
scheduling. Depends on both other targets. Moves the remaining ~11 test files.

One judgement call: `EnhancedStreakViewModel.swift` is 1,946 lines, and its only UI-bound
region is `generateShareImage()` at `:1132` plus the image helpers at `:1484–1517`.
Extract that into a `StreakShareCardRenderer` in the app target; the remaining ~1,800
lines are `Foundation + Combine` (`ObservableObject` and `@Published` come from Combine,
not SwiftUI, so `import SwiftUI` can go entirely). Five test files depend on this class,
so it is worth the split.

Also in this PR: **fix the timing-fragile tests before they move.** The suite has 16
waits with a timeout ≤ 2s; `EnhancedStreakViewModelTests` alone has 10, and
`testAutoCompleteFirstTask_ShouldOnlyHappenOnce` (`:308`) schedules work at `now + 0.6s`
and waits with `timeout: 1.0` — a 0.4s margin. Replace fixed sleeps with expectations
that fulfil on the observed state change; where a real delay is unavoidable, use ≥ 5s.
A correct test never waits the full timeout, so a generous timeout costs nothing.

**Acceptance criteria**
- [ ] All three targets green under `swift test`
- [ ] `EnhancedStreakViewModel` imports Foundation + Combine only
- [ ] No test in the package waits on a fixed `asyncAfter` deadline
- [ ] Share-image generation still works in the app (manual check)

**Estimate:** ~1 week.

---

### PR9 — Repoint CI

**Steps**

1. `swift test --package-path Packages/SpeakLifeKit --parallel` becomes the PR gate.
2. `xcodebuild build -scheme SpeakLife` moves to `push: main` + nightly.
3. The residual `SpeakLifeTests` (3 Firestore files) runs on the nightly job.
4. Update the required status check in branch protection to the new job name.
5. Add the guard greps below so the boundary cannot silently rot:
   ```bash
   # No SDK arrows into the package
   ! grep -rl "^import \(Firebase\|RevenueCat\|BranchSDK\|TikTok\)" Packages/SpeakLifeKit/Sources
   # Core stays Foundation-only
   ! grep -rl "^import \(SwiftUI\|UIKit\)" Packages/SpeakLifeKit/Sources/SpeakLifeCore
   # Dead imports don't come back
   ```
6. Drop `timeout-minutes` to 10 on the unit job.

**Acceptance criteria**
- [ ] PR feedback under 5 minutes (target 1–2)
- [ ] Required check passes on a clean PR
- [ ] Guard greps fail the build when deliberately violated (test this)

**Estimate:** 1 day.

---

## 4. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `.xcdatamodeld` does not work as a SwiftPM resource | medium | PR2 spike before committing to PR7. Fallback keeps persistence on a reduced simulator job. |
| Access-control conversion in PR6 is larger than estimated | **high** | Only `public` what the compiler demands; do not blanket-public. Split PR6 by subsystem if review stalls. |
| `ProgressSyncStore.deviceId` seam breaks multi-device sync | medium | Read the comment at `:60–67` — the vendor-ID pinning is deliberate. Test with two devices before merging PR5. |
| Merge conflicts against active feature branches | medium | PR1 and PR4 touch many files. Land them fast, early in a week, and tell the team. |
| Package refactor stalls half-done | low | PR1–PR5 are independently valuable. Nothing is left broken if work stops. |

## 5. Definition of done

- [ ] `swift test --package-path Packages/SpeakLifeKit` green, no simulator, no network
- [ ] PR gate under 5 minutes
- [ ] Zero remote dependencies in `Package.swift`
- [ ] `SpeakLifeTests` reduced to the Firestore-bound files, nightly only
- [ ] Branch protection enforcing the new check, with no override merges
- [ ] Guard greps in CI, verified to fail when violated

---

## 6. Seam inventory (the 11 call sites)

| # | Seam | File | Line | PR |
|---:|---|---|---:|---|
| 1 | `RemoteConfig` — enforcement flag | `Services/Enforcement/EnforcementService.swift` | 268 | PR3 |
| 2 | `RemoteConfig` — guard flag | `Services/Guard/TakeItCaptiveService.swift` | 360 | PR3 |
| 3 | `ProgressionPhase.color` | `Views/Declaration View/Streak/DailyChecklistModels.swift` | 27 | PR4 |
| 4 | second `color` | `Views/Declaration View/Streak/DailyChecklistModels.swift` | 247 | PR4 |
| 5 | `color` | `Models/BurstCompletionModel.swift` | 56 | PR4 |
| 6 | `didBecomeActive` | `Services/CoreData/PersistenceController.swift` | 309 | PR5a |
| 7 | `didEnterBackground` | `Services/CoreData/PersistenceController.swift` | 319 | PR5a |
| 8 | `didBecomeActive` | `Services/CoreData/SyncedSettingsStore.swift` | 291 | PR5a |
| 9 | `didBecomeActive` | `Services/CoreData/ProgressSyncStore.swift` | 140 | PR5a |
| 10 | `identifierForVendor` | `Services/CoreData/ProgressSyncStore.swift` | 69 | PR5b |
| 11 | `BGTaskScheduler.submit` | `Services/Notification/NotificationManager.swift` | 334 | PR5c |

Plus `generateShareImage` (`EnhancedStreakViewModel.swift:1132`), handled in PR8.

**6.8 — Cycle check.** Verified: no persistence file references the service or streak
layer, and no model file references a service. The single upward reference is
`SyncedSettingsStore.swift:695–707` decoding `StreakStats`, which points
Persistence → Core — the correct direction. The graph is acyclic and the layering holds.

## 7. The 64 dead imports (PR1)

Regenerate with the command in PR1 rather than trusting this snapshot. Distribution:

- `Views/Onboarding/` — 20 files
- `Views/ProfileView/` — 14 files
- `Views/Declaration View/` — 6 files
- other `Views/` — 15 files
- `Services/` — 9 files (incl. `DataMigrationManager`, `FavoritesMigrationService`, both under test)

Seven of these are visible only with the comment filter, because their sole Firebase
"usage" is prose: `EnhancedStreakViewModel.swift`, `AudioFavoritesView.swift`,
`BreakthroughFlowView.swift`, `AIAnalyticsService.swift`, `AudioAnalytics.swift`,
`EnhancedAnalyticsService.swift`, `Core/Analytics/Events.swift`.

## 8. Test file destinations

`APIClientTests.swift` is **entirely commented out** — 91 lines, every line disabled.
Delete it in PR1.

| Destination | Files | Tests |
|---|---:|---:|
| `SpeakLifeCoreTests` | `BurstSessionTests`, `DevotionalTests`, `EnforcementAssemblerTests`, `FaithActionCatalogTests`, `DailyChecklistTests`, `SimpleStreakTests`, `StreakStatsTests` | 143 |
| `SpeakLifePersistenceTests` | all 11 under `CoreData/**` | 117 |
| `SpeakLifeServicesTests` | `EnforcementServiceTests`, `EnforcementPromptTests`, `EnhancedStreakViewModelTests`, `StreakDisplayTests`, `StreakFreezeTests`, `StreakBreakNotificationTests`, `BurstStreakCalculationTests`, `TakeItCaptiveServiceTests`, `SyncedSettingsStoreEnforcementTests`, `NotificationManagerTests`, `TimerViewModelTests` | 175 |
| stays in `SpeakLifeTests` (hosted, nightly) | `PrayerWallPostTests`, `PrayerWallViewModelTests`, `WarriorRoomTypesTests` | 43 |
| delete | `APIClientTests` | 6 (disabled) |

`WarriorRoomTypesTests` is mostly enum raw-value assertions and could move later; it
imports `FirebaseFirestore` for `Agreement.id` (`@DocumentID`), which needs a real
`DocumentReference` in the decoder's `userInfo`. Splitting the Firestore wire type from a
plain domain type would free it — worth doing only if the Prayer Wall grows.

---

*Counts and line numbers measured against `claude/pipeline-unit-test-plan-hl5kgg`.
Two things are stated but unverified, because the analysis environment has no macOS or
Xcode: `.xcdatamodeld` behaviour under SwiftPM (that is what PR2 is for) and the
projected CI timings, which are extrapolated from the current build's shape rather than
benchmarked. Effort estimates are estimates.*
