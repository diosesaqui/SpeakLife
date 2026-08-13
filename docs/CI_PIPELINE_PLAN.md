# CI Pipeline Remediation Plan — "just run the unit tests"

Status: proposal, not yet implemented.
Author: generated from an audit of `.github/workflows/ci.yml`, the `SpeakLifeTests`
target, and all 20 CI runs to date (2026-08-11).

---

## 1. Where the pipeline actually stands

The CI workflow was added in #332 and has run 20 times. **It has never been green.**

| Runs | Conclusion |
|---:|---|
| 16 | failure |
| 3 | cancelled (superseded by concurrency) |
| 1 | still in progress at time of audit |
| **0** | **success** |

Wall clock, completed runs only: **5–33 minutes, median ≈ 22 min**. One run sat for
61 minutes before being cancelled.

Every pull request therefore reports a red required check, and the only way anything
merges is by override — which is the exact situation the workflow was written to end.

### What the last run on `main` actually says (run #19, `31518547988`)

```
2 failed, 447 passed, 0 skipped

✗ testAutoCompleteFirstTask_ShouldOnlyHappenOnce()
    Asynchronous wait failed: Exceeded timeout of 1 seconds,
    with unfulfilled expectations: "First auto-completion".
✗ testFetchByCategory()
    Test crashed with signal segv.
```

and, separately, a simulator clone died outright:

```
iOSSimulator: 2EBC6C2B-…: Failed to launch app with identifier: com.Franchiz.SpeakLife
  (error = Error Domain=NSMachErrorDomain Code=-308 "(ipc/mig) server died")
```

So this is **not** a broken build and **not** a broadly broken test suite. 447 of 449
tests pass. Two defects plus an unstable host-app launch are holding the entire
pipeline red, and the pipeline's shape makes each attempt to fix them cost ~22 minutes
of blind turnaround.

---

## 2. Root causes, ranked

### R1 — A Core Data test drops its stack on the floor mid-test (the segv)

`PersistenceController` owns the `NSPersistentCloudKitContainer`. Four test sites build
one, take `.container.viewContext` off it, and **never retain the controller**, so the
container is deallocated before the first assertion runs:

| File | Line | Form |
|---|---:|---|
| `CoreData/AffirmationRepositoryTests.swift` | 23 | `let persistenceController = …` (local) |
| `CoreData/JournalRepositoryTests.swift` | 23 | `let persistenceController = …` (local) |
| `CoreData/Services/FavoritesMigrationServiceTests.swift` | 175 | `PersistenceController(inMemory: true).container.viewContext` |
| `CoreData/Services/UnifiedFavoritesManagerTests.swift` | 289 | `PersistenceController(inMemory: true).container.viewContext` |

The eight other sites store it in a property and are fine. `AffirmationRepositoryTests`
is the one with a `testFetchByCategory()`, and `DeclarationFavoriteRepositoryTests` —
which has an identically-named test but *does* retain the controller — is not the
crasher. That asymmetry is the whole tell.

This is the prime suspect, and it is cheap to fix and cheap to disprove. It is not yet
*proven*: the crash log inside the uploaded `.xcresult` will name the frame. Confirm
before closing.

Compounding it: the in-memory path (`PersistenceController.swift:121–137`) does not use
`NSInMemoryStoreType`. It points a **SQLite** store at `/dev/null`. Every test class
stands up its own such store, and under parallel testing several coexist in one
process. That is a known crash shape independent of the retain bug.

### R2 — Wall-clock-dependent tests (the 1-second timeout)

`testAutoCompleteFirstTask_ShouldOnlyHappenOnce` schedules work at `now + 0.6s` and
waits with `timeout: 1.0`. That is a **0.4 s margin** on a shared macOS runner driving
multiple simulator clones. It passes on a laptop and loses the race in CI.

It is not alone. The suite has **89** timing-dependent constructs across 10 files, and
**16 waits with a timeout of ≤ 2 seconds** — `EnhancedStreakViewModelTests` alone has
10. Fixing only the one that happens to be red today guarantees a different one goes
red next week.

### R3 — The host app still boots the entire production SDK stack under test

`SpeakLifeApp.swift:116` correctly renders `Color.clear` under test, and
`PersistenceController` gates CloudKit — both good, both already landed. But
`AppDelegate.application(_:didFinishLaunchingWithOptions:)` has **no test gate at all**.
On every run, on every simulator clone, before a single test executes:

- `FirebaseApp.configure()` (`AppDelegate.swift:32`)
- `Purchases.configure(withAPIKey:)` + `syncPurchases()` — **live network** (`:39–52`)
- `BranchAttribution.initSession(launchOptions:)` (`:106`)
- `Event.trackTikTokAppLaunch()`, and `initializeTikTokSDK()` on a delay (`:164–176`)
- remote notification registration

This is the most likely source of the `server died` launch failure, it makes the suite
depend on third-party network availability, and it is pure latency in every run.

Note also that `@StateObject` properties on `SpeakLifeApp` (`:75–86`) — twelve view
models including `SubscriptionStore` and `AudioDeclarationViewModel` — are constructed
when the `App` value is created, regardless of what the scene body renders.

### R4 — The pipeline's shape makes every fix attempt cost ~22 minutes

- **One monolithic step.** `xcodebuild test` builds *and* tests in a single invocation,
  so a compile error and an assertion failure are the same red X, and nothing about the
  build can be cached between the two phases.
- **The 114 MB artifact uploads on `if: always()`** — every run, green or red, spends
  ~7 s of upload and 2,370 files of storage.
- **No test plan.** There is no `.xctestplan`, so there is no way to express "run the
  fast unit tests" versus "run everything", no per-test retry, no timeout policy, and
  no way to quarantine a known-flaky test without deleting it.
- **Unpinned Xcode.** `ls -d /Applications/Xcode*.app | sort -V | tail -1` takes
  whatever is newest on the image. Today that is 26.6. The day the image ships 27, the
  pipeline changes toolchain with no commit and no warning.
- **No retry, no worker-count control**, and `timeout-minutes: 60` is ~3× the observed
  runtime, so a hung run burns an hour of a scarce macOS runner.
- **Duplicate work on merge**: a PR run and a `push: main` run cover the same commit.

### R5 — Structural: the tests are app-hosted and cannot be un-hosted cheaply

`TEST_HOST` and `BUNDLE_LOADER` are set (`project.pbxproj:2637–2685`), and the suite
uses `@testable import SpeakLife` against a 368-file **application** target. iOS unit
tests that `@testable import` an app target must load that app in a simulator. There is
no flag that removes this.

Encouragingly, **no test file imports UIKit or SwiftUI directly** — the suite is already
logic-only in character. Extracting the domain layer into a local Swift package
(testable on a plain macOS runner in seconds, no simulator at all) is therefore
*viable*, but it is a multi-week refactor and explicitly **out of scope for getting
green**. It is recorded in Phase 4 as the eventual destination.

---

## 3. The plan

Sequenced so the pipeline goes green as early as possible, and each phase is
independently mergeable.

### Phase 0 — See what we're doing (½ day)

Right now every iteration is a 22-minute blind guess. Fix that first.

1. **Split build from test.** Replace the single `xcodebuild test` step with:
   - `xcodebuild build-for-testing` — a compile failure now reads as a compile failure
   - `xcodebuild test-without-building` — a test failure reads as a test failure
2. **Add `workflow_dispatch` inputs** for `only_testing` (an `-only-testing:` filter)
   and `skip_upload`, so a single suspect class can be re-run in ~4 minutes instead of
   re-running 449 tests.
3. **Upload the artifact only on failure** (`if: failure()`), and upload
   `TestResults.xcresult` compressed. Saves ~114 MB and ~10 s on every green run.
4. **Print the crash log**, not just the failure summary. Extend the existing
   "Summarise test failures" step to also emit the crash frames — that is what turns
   R1 from a hypothesis into a fact.

**Exit criteria:** a red run tells you *why* on the summary page, and a targeted re-run
takes under 5 minutes.

### Phase 1 — Make the suite green (1–2 days)

5. **Fix R1.** Give all four sites a retained `persistenceController` property, torn
   down in `tearDown`. Confirm against the crash log from Phase 0 step 4 before
   declaring it fixed.
6. **Switch the in-memory store to `NSInMemoryStoreType`** in
   `PersistenceController.init(inMemory:)`, replacing the `/dev/null` SQLite store.
   Verify no test depends on SQLite-specific behaviour (`NSBatchDeleteRequest` and
   `NSPersistentHistoryTracking` are the two things that behave differently — grep the
   suite before switching, and keep `/dev/null` SQLite for any test that needs them).
7. **Fix R2 properly, not locally.** For `testAutoCompleteFirstTask_ShouldOnlyHappenOnce`
   and its 15 siblings: replace `asyncAfter` + fixed-timeout `wait` with expectations
   that fulfil on the observed state change (KVO / Combine sink / completion handler).
   Where a real delay is unavoidable, raise the timeout to ≥ 5 s — a *correct* test never
   waits the full timeout, so a generous timeout costs nothing and buys all the headroom.
   Produce a checklist of all 16 sites; do not stop at the two that are currently red.
8. **Gate `AppDelegate` for tests (R3).** Early-return from
   `didFinishLaunchingWithOptions` when `AppEnvironment.isRunningTests` — before
   Firebase, RevenueCat, Branch, TikTok, and notification registration. Keep the return
   value `true`. This is the single highest-value change for both stability and speed.

**Exit criteria:** three consecutive green runs on the branch. Not one — the whole
point is flakiness, and one green run proves nothing.

### Phase 2 — Make it fast and keep it green (2–3 days)

9. **Add `SpeakLife.xctestplan`** with two configurations:
   - `Unit` — the default for PRs; the fast, hermetic classes
   - `All` — adds `CoreData/Integration/*`, run on `main` and nightly
   Set `testTimeoutsEnabled` with a per-test limit (60 s) so a hang fails one test
   rather than burning the job's 60 minutes. Point the workflow at the plan via
   `-testPlan`.
10. **Pin Xcode explicitly** (e.g. `/Applications/Xcode_26.app`), keeping the existing
    `MAJOR < 26` guard as a floor check. Toolchain upgrades become a reviewed commit.
11. **Retry policy for the last mile**: `-retry-tests-on-failure -test-iterations 2` on
    PR runs only. This is a shock absorber, not a licence — pair it with a rule that any
    test needing the retry gets an issue filed against it.
12. **Cache the build, not just the packages.** Key a `DerivedData/Build` cache on
    `hashFiles('**/*.swift', '**/project.pbxproj')` with a `restore-keys` prefix, so an
    unchanged dependency graph does not recompile 368 files.
13. **Tighten `timeout-minutes` to 30**, and set an explicit
    `-parallel-testing-worker-count` (start at 2) rather than letting xcodebuild clone
    as many simulators as it likes on a shared runner.
14. **Drop the duplicate `push: main` run** for commits that already passed as a PR, or
    reduce it to the `All` test plan on a schedule.

**Exit criteria:** PR feedback in **under 10 minutes**, ≥ 95 % green rate over 20 runs.

### Phase 3 — Make it trustworthy (1 day)

15. **Turn the required status check back on** in branch protection, now that it can
    actually pass, and **stop merging on override**.
16. **Add a flake tracker**: a scheduled job that runs the suite on `main` nightly and
    opens/updates an issue when a test fails intermittently. Cheap insurance against
    sliding back to where we are today.
17. **Document the local command** in `CLAUDE.md` so a contributor can reproduce CI
    exactly (`xcodebuild test -testPlan Unit -destination …`).

### Phase 4 — The real fix, later (out of scope for going green)

18. Extract the pure-logic layer (enforcement, streaks, bursts, declaration assembly —
    the ~20 non-Core-Data test files) into a **local Swift package**. Those tests then
    run with `swift test` on a plain runner in seconds, with no simulator, no app host,
    and no SDK stack. Keep only the genuinely Core Data / UIKit-bound tests on the
    simulator job. This is where "just run the unit tests" actually becomes literally
    true; everything above is making the hosted path survivable in the meantime.

---

## 4. Effort and sequencing

| Phase | Effort | Unblocks |
|---|---|---|
| 0 — diagnosability | ½ day | everything after it |
| 1 — green suite | 1–2 days | merging without override |
| 2 — fast + stable | 2–3 days | PR feedback under 10 min |
| 3 — trustworthy | 1 day | branch protection back on |
| 4 — package extraction | multi-week | the real "just unit tests" |

**Total to a green, enforceable pipeline: roughly one engineer-week (Phases 0–3).**

Phase 0 must go first — without it, Phases 1 and 2 are 22-minute guesses. Phases 1 and
2 can overlap once Phase 0 lands, since 5–8 touch Swift sources and 9–14 touch the
workflow. Phase 4 should not start until Phase 3 is holding.

## 5. Risks

- **R1 may not be the segv.** It is the strongest hypothesis, not a confirmed
  diagnosis — the crash log from Phase 0 step 4 settles it. If it is something else, the
  retain fix is still correct and still cheap; the schedule slips by roughly a day.
- **`NSInMemoryStoreType` is not a drop-in.** Batch requests and persistent history
  behave differently. Step 6 is gated on the grep, and is skippable if the retain fix
  alone stops the crash.
- **Retry-on-failure (step 11) can hide real bugs.** It ships only alongside the flake
  tracker in step 16, never on its own.
- **No verification is possible from this environment.** There is no macOS or Xcode
  here, so every change in Phases 0–2 is verified by pushing to the branch and reading
  the CI result. Budget for that loop; it is the reason Phase 0 comes first.
