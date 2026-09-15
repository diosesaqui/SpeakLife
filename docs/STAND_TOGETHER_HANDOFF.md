# Stand With Me — Local Handoff

Everything needed to take this from here to shipped, on a Mac with Xcode.

The design lives in **`STAND_TOGETHER_SPEC.md`** — read §2 (the core invariant) and
§4.2 (the security regression) before touching anything. This file is the runbook.

**Why the split:** the backend was built and verified in a Linux container with no
Swift toolchain and no Xcode. Everything server-side is done and tested. Everything
client-side needs a Mac.

---

## Where it stands

| | Status |
|---|---|
| `docs/STAND_TOGETHER_SPEC.md` | ✅ written |
| `firestore.rules` — Prayer Wall hardening + Stand rules | ✅ 23 emulator tests green |
| `functions/standTogether.js` — 11 functions | ✅ 35 emulator tests green |
| `firestore.indexes.json` — 3 composite indexes | ✅ |
| **Deploy to `speaklife-3e5c4`** | ❌ **not done** (see Step 2) |
| All Swift (items 5–14) | ❌ not started |

---

## Step 1 — Get the branch and prove it locally

```bash
cd ~/Developer/SpeakLife
git fetch origin
git checkout claude/speaklife-sharing-accountability-7kgso3
git pull origin claude/speaklife-sharing-accountability-7kgso3
```

Confirm you actually have it:

```bash
ls functions/standTogether.js        # must exist
grep -c isFullAccount firestore.rules # must print 9
```

Then run the suite. Needs the `firebase` CLI on your PATH (you have it) and a JDK
for the Firestore emulator:

```bash
cd functions
npm install
npm test        # 23 rules tests, then 35 function tests. All 58 must pass.
```

**If `npm test` is not green, stop.** Everything below assumes it is.

---

## Step 2 — Deploy

The earlier attempt ran against a checkout that didn't have this branch, so it
deployed the *old* rules ("already up to date, skipping upload") and created zero
functions. Redo it now that you have the code.

```bash
# 1. Rules. Worth doing on its own — see "Why the rules go first" below.
firebase deploy --only firestore:rules

# 2. Indexes. They build asynchronously; wait for "Enabled" in the console.
firebase deploy --only firestore:indexes

# 3. Functions, named explicitly so the existing prayerWall / bibleChat /
#    personalMessage functions are not re-containerized for no reason.
firebase deploy --only functions:createStand,functions:createStandInvite,functions:revokeStandInvite,functions:joinStand,functions:leaveStand,functions:onStandRoomUpdated,functions:standDailyNudge,functions:beginAccountMerge,functions:completeAccountMerge,functions:deleteAccount,functions:standSweep
```

### What success looks like

- **Step 1** must say it is *releasing* a new ruleset. If it says
  `latest version of firestore.rules already up to date, skipping upload`, you are
  on the wrong branch — go back to Step 1.
- **Step 3** must print one pair of lines per function:
  ```
  i  functions: creating Node.js 22 (2nd Gen) function createStand(us-central1)...
  ✔  functions[createStand(us-central1)] Successful create operation.
  ```
  Eleven of them. If it jumps from `functions folder uploaded successfully`
  straight to `Deploy complete!`, nothing was created.

### Why the rules go first

There is no hole today — nothing in the app calls `signInAnonymously`, so
`signedIn()` (`request.auth != null`) happens to mean "a real account" by accident.
The moment a build ships anonymous auth, anonymous users satisfy that same check and
can post free text to the Prayer Wall, which has always required a real account. The
rule text never changes; its meaning changes underneath it.

Rules deploy in seconds. An app release goes through review and then trickles out as
users update. You cannot make them land together, so the only safe order is rules
first. `isFullAccount()` only excludes `anonymous` — Apple *and* the
`BibleAuthenticationView` email/password users keep working untouched.

### Do NOT do this

The CLI will suggest `npm install --save firebase-functions@latest`. **Ignore it.**
This code is written against v6; v7 has breaking changes and upgrading would take
the existing prayerWall and bibleChat functions down with it. Separate task.

---

## Step 3 — The Swift (items 5–14, ~14 days)

Build order. **5 → 7 → 8 is the spine**: after those three you have a working stand
testable on two devices with everything else stubbed. 6, 9, 10, 11, 12 hang off it
in any order.

| # | Work | Files | Est. |
|---|---|---|---|
| 5 | Core models + day stamps + tests | `SpeakLifeCore/StandRoom.swift`, `StandDayStamp.swift` | 1d |
| 7 | `StandService` + `StandMirror` seam + write hook | `Services/Stand/`, `EnhancedStreakViewModel.swift` | 1.5d |
| 8 | Room UI | `Views/Stand/StandRoomView.swift` | 2d |
| 6 | Anonymous auth + Apple linking + merge | `StandAuthCoordinator.swift`, `AppleSignInService.swift` | 2d |
| 9 | Invite / join / conflict UI | `StandInviteSheet`, `StandJoinView`, `StandConflictSheet` | 1.5d |
| 10 | Deep link + notification routing + Branch stand key | `SpeakLifeApp.swift`, `AppDelegate.swift` | 0.5d |
| 11 | Stand Pass client | `StandPassStore.swift` + premium check | 0.5d |
| 12 | Day-7 completion + shared share card | `StandCompletionView.swift` | 1d |
| 12b | Discovery surfaces (spec §9.5) | `EnforcementCard.swift`, `DayCelebrationView`, … | 1.5d |
| 13 | Analytics + feature flag | various | 0.5d |
| 14 | QA matrix | — | 1.5d |

### Four things that will bite

1. **New app-target files need `project.pbxproj` registration.** Only `SpeakLifeQuiz`
   is a `PBXFileSystemSynchronizedRootGroup`; the rest of the target uses explicit
   file references, so files dropped in `Services/Stand/` and `Views/Stand/` will
   **not** be compiled until added. Drag the folders into Xcode rather than
   hand-editing the pbxproj — `docs/CLEANUP_AND_HARDENING_PLAN.md` is right that
   hand-editing it is fragile. Anything that can live in `Packages/SpeakLifeKit`
   (item 5) is auto-globbed by SwiftPM and needs no registration, which is why the
   models go there.

2. **Do not import Firebase into `EnhancedStreakViewModel`.** The write hook at
   `EnhancedStreakViewModel.swift:629` must call through a `StandMirror` protocol
   declared in `SpeakLifeServices` and implemented by `StandService` in the app
   target. This is the same seam `StreakShareCardRenderer` uses to keep UIKit out of
   Core, and breaking it blocks the package extraction already in progress.

3. **The room is a mirror, never the source of truth** (spec §2). `recordDay` is
   fire-and-forget and non-throwing. A failed write costs a dot on someone's week
   strip and must never touch `EnforcementProgress`. If you find yourself making the
   room authoritative, stop — that reintroduces every failure mode the spec dismisses.

4. **Branch is live** — SDK in `Package.resolved`, key at `Info.plist:58`,
   `applinks:speaklife.app.link` in the entitlements. Deferred deep links work on day
   one. Note `docs/ATTRIBUTION_MMP.md:20` and the doc comment at
   `AppDelegate.swift:602` both claim otherwise; they are stale.

### Handing item 5 to a local Claude Code session

```
Read docs/STAND_TOGETHER_SPEC.md sections 2, 5.1 and 11.2, then implement item 5
of docs/STAND_TOGETHER_HANDOFF.md: StandRoom.swift and StandDayStamp.swift in
Packages/SpeakLifeKit/Sources/SpeakLifeCore, plus tests in
Packages/SpeakLifeKit/Tests/SpeakLifeCoreTests.

Foundation only — no Firebase, no UIKit. The models must decode the exact
document shape in spec §5.1. Mirror the lenient decoding in
SpeakLifeCore/Enforcement.swift: an unknown theme degrades to .faith rather
than throwing, because a room's campaign blob comes off another person's device.

Day stamps are "yyyy-MM-dd" from Calendar.current — never an interval divided by
86400. Cover DST boundaries, the date line, and 23:59:59 in the tests.

The server-side equivalents are in functions/standTogether.js (localDayStamp,
the merge logic in completeAccountMerge) — match their semantics exactly, and
check functions/test/standTogether.test.js for the cases already pinned down.

Run: swift test --package-path Packages/SpeakLifeKit
```

---

## The callable API the Swift codes against

All are `httpsCallable` on the default region. Source of truth:
`functions/standTogether.js`. Every failure branch is covered by a test in
`functions/test/standTogether.test.js`.

| Function | Input | Returns |
|---|---|---|
| `createStand` | `{ enforcement, name, tz }` | `{ roomId, code }` |
| `createStandInvite` | `{ roomId }` | `{ code }` |
| `revokeStandInvite` | `{ code }` | `{ ok: true }` |
| `joinStand` | `{ code, name, tz }` | `{ roomId, alreadyMember, enforcement }` |
| `leaveStand` | `{ roomId }` | `{ ok: true }` |
| `beginAccountMerge` | — | `{ ticket }` |
| `completeAccountMerge` | `{ ticket }` | `{ merged: Int }` |
| `deleteAccount` | — | `{ ok: true }` |

`enforcement` is the `Enforcement` struct encoded as JSON: exactly 7 days, every
`dayNumber` 1–7 and unique, under 64 KB. The server rebuilds it field by field, so
anything extra the client attaches is dropped.

### Error codes — surface these, don't swallow them

| Code | Meaning | Suggested copy |
|---|---|---|
| `not-found` | Unknown code | "That code doesn't exist." |
| `invalid-argument` | Malformed code or campaign | "Check that code — it should be 8 letters and numbers." |
| `permission-denied` | Invite revoked / not the owner | "This invite was turned off." |
| `deadline-exceeded` | Invite or merge ticket expired | "This invite expired." |
| `failed-precondition` | Stand already finished | "This stand already finished." |
| `resource-exhausted` | Full / invite used up / throttled | "This stand is full." |
| `unauthenticated` | No auth | Trigger anonymous sign-in and retry once |

**`alreadyMember: true` is a success, not an error.** Tapping the same link twice, or
opening it on a second device, must open the room — not show an error screen at the
exact moment someone accepted an invitation.

### Writing a day (the only direct client write)

Everything else goes through a callable. This one is a direct Firestore write so it
queues offline:

```swift
db.collection("standRooms").document(roomId).updateData([
    "members.\(uid).dayNumber":   dayNumber,
    "members.\(uid).daysSpoken":  FieldValue.arrayUnion([todayStamp]),
    "members.\(uid).lastSpokeAt": FieldValue.serverTimestamp(),
    "members.\(uid).tz":          TimeZone.current.identifier,
    "lastActivityAt":             FieldValue.serverTimestamp(),
])
```

Nested field paths so two members writing at once don't clobber each other;
`arrayUnion` so a repeat write on the same day is free. **Enable Firestore offline
persistence at startup** or the offline case doesn't work.

The rules reject anything else: you cannot write another member's row, lower your
`dayNumber`, exceed day 7, add two day stamps in one write, or touch `enforcement`,
`memberUids`, `status` or any notification bookkeeping.

---

## Behavior already decided and built

Change these in `functions/standTogether.js` if you disagree — each is one constant
or one line, and the tests will tell you what you broke.

| | Value | Where |
|---|---|---|
| Room size | 2–12 | `MAX_MEMBERS` |
| Immediate push | **duo only** — a group of 3+ gets zero | `members.length === 2` in `onStandRoomUpdated` |
| Digest | one per person per day, 19:00 their local time | `standDailyNudge` |
| Nudge into silence | never — no push unless someone else spoke today | `standDailyNudge` |
| Back-off | daily → every 3rd day after 3 misses → stop after 6 | `rescheduleNudge` |
| Stand Pass | 7 days, never stacks on an existing entitlement | `grantStandPass` |
| Invite code | 8 chars, `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, 14-day TTL | `CODE_ALPHABET` |
| Stands per user | 3 active | `MAX_ROOMS_PER_USER` |
| Join throttle | 20/hour/uid, checked *before* the lookup | `MAX_JOIN_ATTEMPTS_HOUR` |

The fan-out rule is the one worth re-reading before changing: ten people each
completing a day is ninety pushes if you fan out immediately. That is an uninstall,
not accountability.

---

## Final QA before shipping

Two physical devices, two Apple IDs. Create → invite → join → both speak → verify
both week strips. Then the cases that actually break things:

- airplane mode during a completion, then reconnect
- change device timezone mid-campaign
- move the clock forward a week
- delete and reinstall the app (anonymous first, then Apple-linked)
- sign out while in a stand
- join a full room, and join with an expired code
- both members finish day 7 minutes apart
- leave as the owner
- delete the account while in two stands

Ship behind `stand_together_enabled` (default `false`, Firebase Remote Config via the
existing `RemoteConfigFlags`). Internal → 5% → 50% → 100%, watching
`stand_join_failed` reasons and push opt-out rate at each step. Flipping the flag off
hides all Stand UI and the campaign keeps running locally, because the room was only
ever a mirror.
