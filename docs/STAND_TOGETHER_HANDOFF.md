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
| **Deploy to `speaklife-3e5c4`** | ✅ rules, indexes, 11/11 functions live |
| All Swift (items 5–13) | ✅ **builds** |
| Xcode project registration | ✅ done in `project.pbxproj` |
| Package tests (`swift test`) | ✅ 32/32 |
| Gating `hasFullAccess` at content sites | ❌ **one decision left — see below** |
| QA (item 14) | ❌ not started |

### The one deliberately unfinished thing

`SubscriptionStore.hasFullAccess` (`isPremium || StandPassStore.shared.isActive`)
exists but **nothing gates on it yet**. Content checks still read `isPremium`,
so an invitee's seven-day pass currently unlocks nothing.

It was left that way on purpose rather than folded into `isPremium`:
`isPremium` has a `didSet` that stamps the monetization dimension onto every
analytics event, so OR-ing a free pass into it would report pass holders as
subscribers and quietly corrupt every revenue cut. `isPremium` stays
RevenueCat's truth.

Adopting `hasFullAccess` means choosing, per gate, whether a Stand Pass should
open that door. Audio and the burst almost certainly yes; anything that offers
to sell a subscription, no. That is a product call on surfaces already shipping,
so it is yours.

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

### Step 2b — Turn on Anonymous sign-in (console, not the CLI)

**This is not optional and the CLI cannot do it.** Firebase Console →
Authentication → Sign-in method → **Anonymous** → Enable.

Anonymous is **off by default on every Firebase project**. `ensureAccount()`
calls `signInAnonymously()` the instant somebody taps Invite, and with the
provider disabled it throws `ERROR_OPERATION_NOT_ALLOWED` — "The given sign-in
provider is disabled for this Firebase project." Every Stand entry point runs
through that call, so with it off the whole feature is dead on arrival while
the rules, the indexes and all eleven functions look perfectly healthy.

This was missing from the original handoff, and the first TestFlight build hit
exactly this: the invite row did nothing at all. It is also why
`StandInviteSheet` now shows the failure on screen instead of printing it —
see "Nothing fails silently" below.

### Step 2c — Check the invoker binding on every callable

A v2 `onCall` is a Cloud Run service. The Firebase CLI grants it `allUsers` →
`roles/run.invoker` as a **post-deploy step**, and if the deploy run dies partway
that grant never happens. The function still builds, still reports ACTIVE, still
shows a URL — and every call is rejected by Cloud Run with a 401 before the
function body runs. The iOS SDK maps that 401 onto `unauthenticated`, which is
indistinguishable from a real sign-in failure unless you read the logs.

This is not hypothetical. `createStandInvite`'s first `CreateFunction` failed
with `Could not authenticate 'service-…@gcf-admin-robot.iam.gserviceaccount.com':
Deadline Exceeded.` A later `UpdateFunction` brought the service up but did not
redo the create-time grant, so the stand was created and then the invite code
could never be minted.

Check all eight callables:

```bash
for f in createstand createstandinvite revokestandinvite joinstand \
         leavestand beginaccountmerge completeaccountmerge deleteaccount; do
  printf '%-22s ' "$f"
  gcloud run services get-iam-policy "$f" --region=us-central1 \
    --project=speaklife-3e5c4 --format='value(bindings.members)' 2>/dev/null \
    | grep -q allUsers && echo OK || echo MISSING
done
```

Grant whatever is missing:

```bash
gcloud run services add-iam-policy-binding <service> --region=us-central1 \
  --member=allUsers --role=roles/run.invoker --project=speaklife-3e5c4
```

No redeploy is needed — this is IAM only, and it takes effect in seconds.

**"Allow unauthenticated" here does not mean the function is unauthenticated.**
It means Cloud Run stops gate-keeping at the edge so the request can reach the
function, where `requireAuth(request)` verifies the Firebase ID token exactly as
before. This is the required configuration for every Firebase callable; without
it a callable cannot work at all.

`joinStand` is the one to check hardest. Missing there, the entire receiving
half of the feature is dead: every invite link opens and then fails.

### Step 2d — Move the invite link off `speaklife.app.link` (REQUIRED before launch)

**The default link domain is broken for 98% of your users, on purpose, because
the alternative was a guess.**

`applinks:speaklife.app.link` entered `associated-domains` on 2026-08-29, twelve
minutes before the 4.59 version bump. Every build from 4.59 onward therefore
tells iOS it owns every path on that host — including `/stand/<code>`, which no
build before the Stand release can handle.

That produces the worst failure shape available: iOS hands the universal link to
the installed app, the app opens, `onOpenURL` finds no branch for it, and the
invite evaporates. No error, no App Store prompt, nothing for the recipient to
act on. The typed code is not a fallback either — `StandJoinView` ships in the
same build as the link handling.

Measured over 14 days, active users, simulator excluded:

| Build | Users | What a stand link does |
|---|---|---|
| 4.57, 4.58 | 40 (2%) | Does not claim the domain → opens in Safari → Branch page → App Store. Correct. |
| 4.59 – 4.64 | **2,026 (98%)** | Claims the domain, cannot route it → **app opens, nothing happens** |

The fix is a host those builds do not claim. iOS then cannot match it to any
installed app, so it opens in Safari and Branch's own page offers the App Store
— which is exactly the behaviour the 2% already get.

1. In the Branch dashboard, configure a **custom link domain** (for example
   `go.speaklife.app`) and point DNS at Branch as its setup flow instructs.
   Branch serves both the redirect page and the AASA for it.
2. Set Remote Config **`standLinkDomain`** to that host. No build required —
   `StandLink.shareHost` reads it, and `StandLink.code(from:)` has never matched
   on the domain, so links already in the wild keep parsing.
3. Optionally add `applinks:<that host>` to `SpeakLife.entitlements` in a later
   build so new builds open it directly instead of bouncing through Safari.
   **Do not add it to the build that ships Stand** — a host the shipping build
   claims is a host that behaves exactly like `speaklife.app.link` for the next
   release cycle.

Until step 2 is done, leave `standTogetherEnabled` off. An invite sent before
then is an invite that dies silently.

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

## Step 3 — The Swift: builds and tests green

```bash
swift test --package-path Packages/SpeakLifeKit --filter Stand   # 32/32
```

Covers `StandRoom` and `StandDayStamp`: day stamps across DST in both
directions and over the date line, lenient decoding of a room from another app
version, and `StandJoinResolver`, which decides whether somebody keeps the week
they are holding.

File registration and the `FirebaseFunctions` product link are already in
`project.pbxproj` — no dragging needed.

### What the first real build cost, for the record

Five rounds, all in the same two families, worth knowing because the next
person writing Swift against this will hit them too:

| Error | Cause |
|---|---|
| Main-actor property from a nonisolated context | `StandDiscovery` reading `StandService.shared.rooms` |
| `async` call in an autoclosure | `?? (await …)` — an autoclosure cannot be async |
| Main-actor property in a nonisolated autoclosure | `isPremium \|\| standPass.isActive` — same shape, `\|\|` also autocloses |
| `deinit` touching isolated state | dead code on a singleton whose deinit never runs |
| No `ObservableObject of type AppState` | a modifier applied ABOVE the `.environmentObject` calls it read from |
| `DeclarationCategory has no member 'peace'` | invented a category; the real theme is `.anxiety` |

The last one is the cautionary tale: the catalog ships `Enforcing Peace` as id
`"peace"` with theme `"anxiety"`, and `EnforcementServiceTests` already had it
right. Check the existing tests before inventing a fixture.

### Files

| # | Item | Files |
|---|---|---|
| 5 | Core models | `SpeakLifeCore/StandRoom.swift`, `StandDayStamp.swift`, + 2 test files |
| 6 | Auth | `Services/Stand/StandAuthCoordinator.swift` |
| 7 | Mirror seam | `SpeakLifeServices/StandMirror.swift`, `Services/Stand/StandService.swift`, hook in `EnhancedStreakViewModel.swift` |
| 8 | Room | `Views/Stand/StandRoomView.swift` |
| 9 | Invite / join | `StandInviteSheet.swift`, `StandJoinView.swift`, `StandConflictSheet.swift` |
| 10 | Links | `Services/Stand/StandLink.swift`, edits to `SpeakLifeApp.swift`, `AppDelegate.swift`, `AppState.swift` |
| 11 | Pass + flag | `Services/Stand/StandPassStore.swift` |
| 12 | Completion | `StandCompletionView.swift`, `StandInviteCardRenderer.swift` |
| 12b | Discovery | `StandDiscovery.swift`, `StandListView.swift`, edits to `EnforcementCard.swift`, `EnforcementCompletionView.swift`, `ProfileView.swift` |

### Edits to existing files — review these closely

New files are contained; these touch code you already ship:

- `EnhancedStreakViewModel.swift` — two `StandMirror.recordDay` calls in the existing `advanceIfNeeded` switch.
- `EnforcementService.swift` — new `startShared(_:)`.
- `EnforcementCard.swift` — a `StandInviteRow`, a day-1 prompt sheet, two `@State` vars.
- `EnforcementCompletionView.swift` — "Run the next one with someone".
- `ProfileView.swift` — a `standsRow`.
- `SpeakLifeApp.swift` — `/stand/` parsing, `standRedemption()`, stand push routing.
- `AppDelegate.swift` — deferred-link code in `BranchAttribution.apply`.
- `AppState.swift` — `pendingStandCode`, `pendingStandRoomId`.

Everything user-visible is behind `FeatureFlag.standTogetherEnabled`, default
**false**, so a merge with the flag off changes nothing for users.

### One deliberate compromise

The day-1 prompt fires from `EnforcementCard` when `completedDayNumbers` first
reaches 1, not from inside the burst's completion sequence. Spec §9.5 wants it
at the instant the burst ends; hanging it off the card puts it a beat later, on
the Today tab. That was chosen because splicing into `DailyDeclarationBurstView`
blind — unable to compile or see the result — risks breaking a flow you already
ship. **Moving it into the burst completion is a worthwhile follow-up** once
somebody can run the app.

### Launch broadcast (12c)

Not code — a send you trigger from your own tooling when the flag goes on.
Suggested copy:

> **You don't have to stand alone.**
> Your next seven days can be run with someone. Your wife, your mom, your
> small group. Same word, same week, spoken together.

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

## Nothing fails silently

Every entry point — the row on the campaign card, the day-1 prompt, the "run
the next one with someone" button on the completion screen — now presents
`StandInviteSheet` **immediately** and hands it a `StandInviteSource`. The sheet
creates the stand itself.

Before this, each caller minted the room first through a helper that returned
`nil` on every failure after a `print`, and only presented the sheet if it got
one back. So no network, a Cloud Function error, or Anonymous sign-in being off
all produced the same thing on screen: nothing. The button looked broken
because, from the user's side, it was.

The sheet has three states — working, ready, and a failure with the reason and
a Try again. There is now exactly one place a failure can surface, and it is a
screen the user is already looking at.

Creating also no longer mints two invites: `createStand` returns a first code,
which is cached rather than discarded and immediately re-minted.

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

Ship behind `standTogetherEnabled` (default `false`, Firebase Remote Config via the
existing `RemoteConfigFlags`). Internal → 5% → 50% → 100%, watching
`stand_join_failed` reasons and push opt-out rate at each step. Flipping the flag off
hides all Stand UI and the campaign keeps running locally, because the room was only
ever a mirror.
