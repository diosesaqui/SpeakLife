# iCloud State Sync Plan — Pick Up Where You Left Off on Every Device

**Goal:** Every piece of user progress and preference follows the user's iCloud account, so a new
iPhone/iPad (or a reinstall) restores streaks, listened audio, reading progress, badges, and
personalization automatically — the same way journals and favorites already do.

**Date:** 2026-07-16
**Status:** Research complete, implementation plan proposed.

---

## Part 1 — Verification: What Already Syncs Today

### ✅ Journals, custom affirmations, favorites — CONFIRMED syncing

The app runs a proven `NSPersistentCloudKitContainer` stack
(`Services/CoreData/PersistenceController.swift:59-100`), container
`iCloud.com.franchiz.speaklife`, private database, with history tracking, remote-change
notifications, launch/background sync triggers, and an initial-import retry loop. Four Core Data
entities are CloudKit-synced (`Models/SpeakLife.xcdatamodeld/SpeakLife.xcdatamodel/contents`):

| Entity | What it is | Status |
|---|---|---|
| `JournalEntry` | User journal entries | ✅ syncs |
| `AffirmationEntry` | "Create your own" affirmations | ✅ syncs |
| `DeclarationFavoriteEntry` | Favorited declarations | ✅ syncs |
| `AudioFavoriteEntry` | Favorited audio | ✅ syncs |

Supporting infra already in place and reusable: `CloudKitSyncMonitor` (sync status for UI),
`UnifiedFavoritesManager` (remote-change refresh + retry), per-entity repositories, a
`CustomMergePolicy` (last-`lastModified`-wins, in `Services/CoreData/Sync/SyncConflictResolver.swift`),
and three battle-tested one-shot migration patterns (`DataMigrationManager`,
`FavoritesMigrationService`, `UnifiedFavoritesManager.migrateJSONFavoritesToCoreDataIfNeeded`).

### ✅ Subscription — CONFIRMED restores across devices (with caveats)

- Stack is **RevenueCat** (entitlements `premium` / `devotional`), StoreKit 2 only for price display.
- RC is configured **anonymously** — there is no `Purchases.logIn(...)` anywhere. Entitlement
  restore is **receipt-based via the Apple ID**, and `AppDelegate` calls
  `Purchases.shared.syncPurchases()` on every cold launch (`App/AppDelegate.swift:48-53`).
- **Result: a new device on the same Apple ID gets premium automatically.** No work strictly
  required for the same-Apple-ID story.
- Caveats to be aware of:
  1. Nothing ties the subscription to the Firebase UID, so entitlement will **not** follow a user
     across Apple IDs / platforms. If that ever matters, add `Purchases.logIn(firebaseUID)` on
     sign-in (planned but never implemented per `REVENUECAT_PLAN.md`).
  2. `@AppStorage("lastDevotionalPurchase")` (`SubscriptionStore.swift:66`) is a device-local
     30-day window check that will not exist on a fresh device — verify the devotional
     non-consumable path re-derives correctly from RC alone.
  3. `TrialExperienceService` trial flags are device-local; a second device may re-show
     trial-experience UI.

### ❌ Everything else is device-local and is LOST on device change

There is **no `NSUbiquitousKeyValueStore` usage anywhere** (and no KVS entitlement), and no other
sync mechanism. All of the following live only in `UserDefaults`/files:

| Domain | Keys (owner) |
|---|---|
| **Streaks** | `streakStats` blob, `dailyChecklist` (`EnhancedStreakViewModel.swift:490-503`); `currentStreak`/`longestStreak`/`totalDaysCompleted` scalar mirrors (`StreakDetails.swift:19-21`, `TimerViewModel.swift:15-19`); `weekCompletions`; `burstCompletions` history (`BurstCompletionModel.swift:46`) |
| **Listened audio** | `sl_audioPlayedIDs_v1` — IDs listened past 85% (`AudioProgressStore.swift:14`) |
| **Devotional/reading progress** | `devotionalDictionary` (`DevotionalViewModel.swift:12`), `totalVersesRead`, `abbasLoveLetterIndex` |
| **Badges & milestones** | `UnlockedBadges` (`BadgeModel.swift:189`), `celebratedMilestones` (inside `streakStats`) |
| **Personal declaration** | `personal_declaration_v1` + day/speak counters (`PersonalDeclarationRepository.swift:13`, `PersonalDeclaration.swift:25-27`) |
| **Quiz & lifetime counters** | `completedQuizTitlesRaw`, `totalAffirmationsSpoken`, `totalSocialShares`, `totalFavoritesAdded`, `minutesPerDay` |
| **Bible** | `BibleBookmarks`, `BibleHighlights`, `BibleReadingHistory`, `BibleLastRead`, `SelectedBibleVersion` (`BibleInteractor.swift:136-139`) |
| **Onboarding personalization** | `userName`, `surveyGoalWord`, `onboarding_segment`, `selectedDeclarationStyles`, `userSelectedCategories`, `userTopCategories`, `foundationAudioDayAssignments` |
| **Community (own state)** | `warriorRoomUserReactions`, `warriorRoomUserAgreements` |
| **Preferences** | `theme`, `fontString`, custom theme images, `backgroundMusicEnabled`, animated-text prefs, haptics/audio-delights, Bible reader appearance, reminder times/counts/categories |

Notable: audio **playback position/resume does not exist at all** (in-memory only) — syncing it
requires building the persistence first.

---

## Part 2 — Architecture Decision

**Recommendation: extend the existing Core Data + CloudKit stack. Do not introduce iCloud
key-value store or Firestore for this.**

Why:
- The user's ask is "tie it to the iCloud account" — `NSPersistentCloudKitContainer` private DB is
  exactly that, zero sign-in friction, and it's already proven in this app (schema, monitoring,
  retry, migration patterns all exist).
- iCloud KVS is last-writer-wins with a 1 MB / 1024-key cap — wrong tool for streak history that
  must **merge** across devices, and it would add a second sync system to maintain.
- Firestore would require auth (optional today) and a privacy-policy/server story for progress data.

### Two new sync primitives

**1. Event-log entities (append-only rows) — for progress that must MERGE.**
CloudKit merges row sets naturally (union). Devices never edit the same record; they only add
rows. All derived numbers (current streak, longest streak, totals) are **recomputed locally from
the union** — this is already how `BurstCompletionTracker.calculateCurrentStreak()` self-heals, so
we promote that pattern to the source of truth.

**2. A generic `SyncedSetting` key-value entity — for preferences where last-writer-wins is fine.**
One entity: `key` (String, unique), `value` (Binary/String), `lastModified` (Date), `deviceId`
(String, debug). A thin `SyncedSettingsStore` wrapper exposes typed getters/setters and mirrors
into the existing UserDefaults keys so call sites don't all have to change at once.

### New Core Data entities (all `usedWithCloudKit`)

| Entity | Natural key | Replaces | Merge rule |
|---|---|---|---|
| `DayCompletionEntry` | `dayStamp` ("yyyy-MM-dd", local calendar at completion) | `burstCompletions`, `weekCompletions`, streak history | union by dayStamp; streak/longest/total derived |
| `ListenedAudioEntry` | `audioId` | `sl_audioPlayedIDs_v1` | union; explicit un-mark = delete row |
| `DevotionalReadEntry` | `dateKey` | `devotionalDictionary` | union |
| `BadgeUnlockEntry` | `badgeId` | `UnlockedBadges` | union, earliest `unlockedAt` wins |
| `QuizCompletionEntry` | `quizTitle` | `completedQuizTitlesRaw` | union |
| `BibleAnnotationEntry` | `id` + `kind` (bookmark/highlight) | `BibleBookmarks`, `BibleHighlights` | union; delete = row delete |
| `CounterEntry` | `counterKey` + `deviceId` | `totalAffirmationsSpoken`, `totalVersesRead`, `totalSocialShares`, `totalFavoritesAdded` | per-device rows, display = SUM (increments from two devices are never lost) |
| `SyncedSetting` | `key` | prefs/personalization listed below | last `lastModified` wins |

`SyncedSetting` keys (Phase 4): `userName`, `surveyGoalWord`, `onboarding_segment`,
`selectedDeclarationStyles`, `userSelectedCategories`, `userTopCategories`,
`foundationAudioDayAssignments`, `personal_declaration_v1` + its counters, `theme`, `fontString`,
`SelectedBibleVersion`, `BibleLastRead`, Bible reader appearance, `backgroundMusicEnabled`,
animated-text prefs, reminder times/counts/categories, `warriorRoomUserReactions`,
`warriorRoomUserAgreements`, `warriorRoomIsSister`, `abbasLoveLetterIndex`.

### Streak derivation (the important design change)

Today the streak lives in **four disagreeing stores** (`streakStats` blob, scalar `currentStreak`
keys, `weekCompletions`, `BurstCompletionTracker`) reconciled by max-taking and "heal" patches.
The plan collapses this:

1. `DayCompletionEntry` rows become the **only stored truth** (synced).
2. A single `StreakEngine` derives `currentStreak`, `longestStreak`, `totalDaysCompleted`, and
   week view from the row set, on every change and every remote-change notification.
3. Derived values are still mirrored to the legacy UserDefaults keys (`currentStreak`, etc.) so
   the many existing readers (`TimerViewModel`, `AIIntelligenceService`, notifications, widget)
   keep working untouched.
4. Streak freeze: store freeze **usage** as a special `DayCompletionEntry` row
   (`kind = "freeze"`) so it merges like any other day; "freeze available" is derived
   (one per rolling window / per streak, per current product rule).
5. `celebratedMilestones` moves to `SyncedSetting` (union-merge set) so a milestone never
   re-celebrates on a second device.

Timezone note: day identity is captured as a local-calendar `dayStamp` at completion time, which
matches today's `Calendar.current` behavior. Two devices in different timezones completing "the
same day" produce one row (same stamp) or two adjacent stamps — both merge safely under
union+derive. No UTC migration needed now; keep it as a known limitation.

### What deliberately does NOT sync

Device/install-scoped state stays local: migration flags, content-cache versions, FCM token,
`prayerWallDeviceId`, A/B assignments (`subscriptionTest`, ad-onboarding attribution), paywall/
review/discount gating counters, trial-experience flags, in-progress timer, journal drafts,
feature-announcement flags, ML weight caches, and the **OS notification permission** (we sync the
user's reminder *preferences*, never the permission bit — on a new device the app re-prompts and
then applies the synced times).

Ambiguous, needs product call (defaults proposed):
- `onboarded` / `hasCompletedEnhancedOnboarding`: **sync = true** so a returning user on a new
  device skips onboarding and lands on "Welcome back, restoring your progress…". (Analytics
  should distinguish `new_user` vs `restored_user`.)
- Paywall "hasShown" flags: **do not sync** (each device is a fresh conversion surface).
- Widget App Group parallel streak (`dailyReadStreak`/`readPromises` in `WidgetDataBridge`):
  keep device-local but re-feed it from the synced `StreakEngine` output.

---

## Part 3 — Work Plan

### Phase 0 — Groundwork (≈2-3 days)
- Add new entities to `SpeakLife.xcdatamodeld` (new model **version**, lightweight migration).
- Build `SyncedSettingsStore` (typed KV wrapper + UserDefaults mirroring + remote-change refresh).
- Build `ProgressEventRepository` following the existing repository pattern
  (`Services/CoreData/Repositories/*`, incl. `requestImmediateSync()` on write).
- **CloudKit schema deployment:** new record types auto-create in the Development environment on
  first save; they must be **promoted to Production in CloudKit Console before release**. Add this
  to the release checklist — it is the #1 way this ships broken.
- Extend `CloudKitSyncMonitor` events + analytics (`sync_import_completed`, `sync_restore_found_data`).

### Phase 1 — Streaks (highest user value, ≈1 week)
- Implement `StreakEngine` deriving all streak stats from `DayCompletionEntry` rows.
- One-time local migration (established flag pattern: idempotent guard, set-flag-only-on-success,
  analytics, retry next launch): convert existing `burstCompletions` history → `DayCompletionEntry`
  rows; if history is shorter than `streakStats.currentStreak` (older installs), synthesize
  back-dated rows so nobody's streak shrinks.
- Rewire `EnhancedStreakViewModel` + `BurstCompletionTracker` to read/write through the engine;
  keep legacy key mirroring for downstream readers.
- Cross-device rule: streak is recomputed on `.NSPersistentStoreRemoteChange`, so completing the
  burst on iPhone updates the iPad within the sync window. Milestone celebration stays gated by
  the synced `celebratedMilestones` set.
- QA matrix: fresh install + existing iCloud data; two devices same day; gap day + freeze; offline
  week then sync; no-iCloud-account fallback (everything keeps working locally — CloudKit options
  already degrade gracefully).

### Phase 2 — Listened audio & reading progress (≈3-4 days)
- `ListenedAudioEntry`: migrate `sl_audioPlayedIDs_v1`, rewire `AudioProgressStore` to the
  repository (keep its API; swap the backing store). Manual un-mark deletes the row.
- `DevotionalReadEntry`: migrate `devotionalDictionary`, rewire `DevotionalViewModel`.
- `BibleAnnotationEntry` + `BibleLastRead`/`SelectedBibleVersion` via `SyncedSetting`: rewire
  `BibleInteractor`.
- Optional (new capability, small): persist audio playback position (`audioId` → seconds) in
  `SyncedSetting` on pause/background to enable true cross-device resume — currently positions
  aren't persisted even locally.

### Phase 3 — Badges, quiz, counters (≈2-3 days)
- `BadgeUnlockEntry` (migrate `UnlockedBadges`), `QuizCompletionEntry`, `CounterEntry` with
  per-device rows + SUM display. Rewire `BadgeModel`, `QuizProgressManager`, counter call sites in
  `DeclarationContentView` / `DevotionalView`.

### Phase 4 — Preferences & personalization (≈3-4 days)
- Move the `SyncedSetting` key list (above) behind `SyncedSettingsStore`; on remote change, apply
  and re-schedule notifications with synced times **only if** this device has permission.
- Personal declaration: move `personal_declaration_v1` + counters; day-count merges as max.

### Phase 5 — Restore experience & hardening (≈1 week)
- **New-device first-launch flow:** detect "existing user" (CloudKit data present) using the
  existing `CloudKitImportStarted/Completed/Failed` notifications and the import-retry loop in
  `PersistenceController`; show a brief "Restoring your progress from iCloud…" state instead of
  treating them as brand-new, then skip onboarding and greet with restored streak.
- Settings UI: surface sync status (reuse `CloudKitSyncBadge`), plus a "not syncing — check
  iCloud" hint when `CKContainer.accountStatus != .available`.
- Subscription hardening (small): verify devotional entitlement derives from RC on a fresh device
  (drop reliance on `lastDevotionalPurchase`); decide whether to adopt `Purchases.logIn(firebaseUID)`
  for future cross-platform portability (separate initiative; requires RC transfer-behavior review).
- Full QA pass on the two-device matrix + CloudKit Production schema promotion + staged rollout
  with analytics on restore success rate.

### Rough total: ~4 weeks of focused work, shippable in phase order (each phase is independently releasable).

## Risks & gotchas
1. **CloudKit Production schema promotion** forgotten → sync silently fails in TestFlight/App Store builds. Release-checklist item, verify via console.
2. **First-import race:** onboarding/paywall decisions made before CloudKit import completes can misclassify a restoring user as new. Gate on the import notifications with a short timeout (the retry loop already exists).
3. **Streak regression fear:** migration must never show a smaller streak than the user had. The max-of(local, derived) reconciliation stays in place for one release as a safety net, with analytics on disagreements.
4. **Merge policy:** current store uses `NSMergeByPropertyObjectTrumpMergePolicy`; event-log design mostly sidesteps conflicts, but `SyncedSetting` updates should write `lastModified` and rely on the existing `CustomMergePolicy` semantics (wire `setupConflictResolution()` in, currently unused).
5. **UserDefaults writes from multiple systems:** during transition, legacy keys remain as mirrors only — one writer (the new stores), many readers. Enforce via code review; the fragmented streak stores are the cautionary tale.
