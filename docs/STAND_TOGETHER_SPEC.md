# Stand With Me — Implementation Spec

**Status:** proposed, not built
**Feature flag:** `stand_together_enabled` (default `false`)
**Branch:** `claude/speaklife-sharing-accountability-7kgso3`

---

## 1. What this is

A **Stand** is an existing 7-day `Enforcement` run by 2–12 people at once. One person
starts Enforcing Peace (or Healing, Provision, Victory, or a campaign assembled from
their own words), invites their spouse / mother / small group with a link, and from
then on everyone speaks the same daily anchor declaration and can see who has spoken
today and who hasn't.

The accountability unit is **the mouth, not the eye**. Every competitor ships "we read
the same chapter." Nothing ships "we spoke the same word over our family this week."
That is the only version of this feature SpeakLife is uniquely positioned to build, and
it is why the spec hangs off `Enforcement` rather than off a new plan type.

### What this is NOT (deliberate, do not add in v1)

| Not building | Why |
|---|---|
| Free-text chat | Turns a 2-week build into an ongoing moderation obligation. The Prayer Wall already carries that cost; this feature is designed to carry none. |
| A shared/group streak | Streaks are per-device `@AppStorage("currentStreak")`. A joint streak means one person's hard week breaks their mother's. Accountability without shame is the whole point. |
| Profile photos | Image moderation, CSAM surface, storage cost. Initials on a colored disc. |
| Public rooms / discovery | Invite-only, unguessable codes. No browse, no search, no join-by-name. Removes the entire stranger-danger surface in a product families use. |
| Leaderboards / "who's winning" | Competitive framing is theologically wrong here and retention-negative for the person who is struggling — the exact person the feature exists to carry. |

---

## 2. Core invariant (read this before writing any code)

> **The room is a mirror of local truth. It is never the source of truth.**

`EnforcementService` stays exactly as it is: the local, offline, lock-guarded owner of
the user's campaign position. A Stand write is a *projection* of a local advance that
already happened. Nothing in the room can advance, reset, or roll back a campaign.

Every consequence of this is good:

- A failed network write costs a dot on someone else's week strip, never a campaign day.
- A Firestore outage degrades the feature to the single-player experience shipping today.
- A malicious or buggy room write cannot corrupt a user's progress.
- The rules can be strict about staleness without risking data loss.

Any change that makes the room authoritative over `EnforcementProgress` defeats the
design and reintroduces every failure mode below as data loss.

A second invariant inherited from `EnforcementService`:

> **Campaigns wait, they don't expire.** `EnforcementProgress.currentDay` counts
> completed days, never calendar days. Two members of the same Stand can be on day 3
> and day 6 and both are correct. The room must never render one of them as "behind."

---

## 3. Vocabulary

| Term | Meaning |
|---|---|
| **Stand** | One room. Holds one `Enforcement` and 2–12 members. |
| **Member** | One `uid` inside a Stand. |
| **Day number** | 1…7, that member's own `EnforcementProgress.currentDay`. Never calendar-derived. |
| **Day stamp** | `"yyyy-MM-dd"` in the member's own local calendar. Display only — drives "spoke today," never progress. |
| **Stand Pass** | 7 days of full app access granted to an invitee on join. |

---

## 4. Identity: anonymous auth (the hard part)

Today `AppleSignInService` is the only path to a `uid`, and `uid` is `""` for everyone
who hasn't signed in. Forcing Sign in with Apple at the moment someone taps a link from
their mother is the worst possible place to put a wall.

**Plan: Firebase anonymous auth on demand, upgraded to Apple at the first moment the
user has something to lose.**

### 4.1 Lifecycle

1. **Never at launch.** Anonymous sign-in happens the first time the user taps
   *Invite someone* or opens an invite link. Creating anonymous users at launch would
   fabricate millions of auth records and pollute every user-count metric.
2. Anonymous credentials persist in the **Keychain**, so they survive an app delete and
   reinstall on the same device, but do **not** move to a new device.
3. After the user's **first completed day inside a Stand**, prompt once:
   *"Save your stand. Sign in with Apple so this follows you to any device."* Dismissible,
   re-asked at day 4 and at completion, then never again (`standUpgradePromptCount`, cap 3).
4. On sign-out, if the user is anonymous and in any Stand, block with a warning. An
   anonymous sign-out is unrecoverable account deletion.

### 4.2 🔴 Security regression this introduces (must not be missed)

`firestore.rules` currently defines:

```
function signedIn() { return request.auth != null; }
```

Every Prayer Wall write rule is built on it. The moment anonymous auth exists, **every
anonymous user can post to the Prayer Wall**, which today is gated behind Sign in with
Apple. Shipping anonymous auth without the rules change below is a moderation incident.

Add, and use it everywhere the *Prayer Wall* currently calls `signedIn()`:

```
function isFullAccount() {
  return request.auth != null
         && request.auth.token.firebase.sign_in_provider != 'anonymous';
}
```

`signedIn()` stays as-is and is used **only** by Stand rules and `users/{uid}`.

### 4.3 Linking anonymous → Apple

```
Auth.auth().currentUser?.link(with: appleCredential)
```

Succeeds in the common case: same person, first Apple sign-in. The uid is preserved and
nothing else needs to happen.

**The failure case that matters:** `AuthErrorCode.credentialAlreadyInUse`. The user
already has an Apple-backed account (they used the Prayer Wall on an old phone, or
reinstalled). Linking is impossible; they must sign in *as* that account, which
abandons the anonymous uid — and its Stand memberships — unless we migrate.

Do **not** trust the client to say which uid it used to be. Use a server-issued ticket:

1. While still anonymous, client calls `beginAccountMerge()` (callable). Server records
   `accountMerges/{ticket} = { fromUid: <anon uid from the verified token>, createdAt }`,
   TTL 10 minutes, returns the opaque `ticket`.
2. Client calls `Auth.auth().signIn(with: updatedCredential)` — the credential handed
   back on the error in `userInfo[AuthErrorUserInfoUpdatedCredentialKey]`. Auth state is
   now the Apple uid.
3. Client calls `completeAccountMerge(ticket)`. Server reads `fromUid` from the ticket,
   `toUid` from the *verified* caller token, migrates, deletes the ticket and the
   anonymous auth user.

Per-room migration runs in a transaction and must handle all four states:

| `members[fromUid]` | `members[toUid]` | Action |
|---|---|---|
| absent | — | No-op (idempotent retry) |
| present | absent | Move the entry; update `memberUids`; keep `joinedAt` |
| present | present | **Merge**: union `daysSpoken`, `max(dayNumber)`, earliest `joinedAt`, then delete `fromUid`. Happens when someone joined their own family's Stand twice, once per identity. |
| present | present, and `left: true` | Same merge; result is `left: false` |

If `completeAccountMerge` never runs (app killed between steps 2 and 3), the ticket
expires and the anonymous memberships are orphaned. Mitigation: the client persists the
ticket in the Keychain before step 2 and retries `completeAccountMerge` on next launch
until it succeeds or the server reports the ticket unknown.

### 4.4 Analytics identity

`AppleSignInService.checkCurrentUser()` calls `AnalyticsService.shared.setUserId(uid)`.
**Do not call `setUserId` with an anonymous uid** — it would fragment every PostHog
funnel by creating a distinct id per device that later has to be aliased. Call it only
on a real Apple link/sign-in, and call PostHog `alias` at that moment so pre-link events
stay attached.

### 4.5 Account deletion (App Store 5.1.1(v))

A callable `deleteAccount` must: remove the user from every Stand (delete their member
entry outright; if they were the last member, delete the room and its invites), delete
`users/{uid}`, `standNudges/{uid}`, revoke invites they created, then delete the auth
user. Other members see the person disappear, not a tombstone.

---

## 5. Data model

### 5.1 `standRooms/{roomId}` — one document per Stand

**One document with a `members` map, not a subcollection.** Rationale: a member list is
capped at 12, so the whole room is one snapshot listener and one document read instead
of N+1. Firestore's ~1 sustained write/sec/document limit is irrelevant at 12 writes/day.
A subcollection would multiply reads by member count for zero benefit.

```jsonc
{
  "id": "r_7f3a9c2e",
  "createdAt": <serverTimestamp>,
  "createdBy": "<uid>",
  "status": "active",              // active | completed | dormant | archived
  "schemaVersion": 1,

  // The campaign, stored WHOLE. Non-negotiable: EnforcementAssembler and
  // EnforcementCurator mint ids ("assembled_…", "curated_…") that exist in no
  // catalog and whose content lives only in that user's UserDefaults. An
  // invitee could never resolve one by id. ~7 days of text — a few KB against
  // a 1 MiB document limit.
  "enforcement": { "id": "...", "title": "...", "tagline": "...",
                   "theme": "peace", "days": [ /* 7 × EnforcementDay */ ] },

  // Denormalized for the rules' `uid in resource.data.memberUids` read check
  // and for the nudge fan-out. Kept in sync with `members` by the server.
  "memberUids": ["<uid1>", "<uid2>"],

  "members": {
    "<uid>": {
      "name": "Sarah",             // ≤ 24 chars, first name only, filtered
      "initial": "S",
      "colorIndex": 3,             // 0-7, deterministic from uid hash
      "joinedAt": <serverTimestamp>,
      "dayNumber": 3,              // 0…7, monotonic, mirrors EnforcementProgress
      "daysSpoken": ["2026-09-13", "2026-09-14", "2026-09-15"],  // ≤ 14 entries
      "lastSpokeAt": <serverTimestamp>,
      "tz": "America/New_York",    // IANA
      "left": false,
      "isOwner": false
    }
  },

  "completedAt": null,             // set when every active member reaches day 7
  "notifiedMilestones": [],        // ["all_day_7"] — same pattern as prayerWall
  "lastActivityAt": <serverTimestamp>
}
```

`daysSpoken` is capped at 14 entries (7 days + slack) and trimmed oldest-first by the
client. It exists for the week strip only.

### 5.2 `standInvites/{code}` — never client-readable

```jsonc
{
  "roomId": "r_7f3a9c2e",
  "createdBy": "<uid>",
  "createdAt": <serverTimestamp>,
  "expiresAt": <serverTimestamp>,   // createdAt + 14 days
  "maxUses": 12,
  "uses": 2,
  "revoked": false
}
```

Code alphabet excludes visually ambiguous characters: `ABCDEFGHJKMNPQRSTUVWXYZ23456789`
(31 chars, no `0/O/1/I/L`). 8 characters ≈ 8.5 × 10¹¹ combinations, displayed as
`XXXX-XXXX`. Generated server-side with `crypto.randomBytes` and rejection sampling —
**not** `Math.random()`, and not modulo-biased.

### 5.3 `standNudges/{uid}` — the fan-out queue

Firestore cannot query inside a map, so scanning every room hourly to find who is due a
nudge does not scale. Invert it: one document per user, queried on an indexed timestamp.

```jsonc
{
  "uid": "<uid>",
  "nextNudgeAt": <timestamp>,      // indexed; the only query field
  "roomIds": ["r_7f3a9c2e"],
  "tz": "America/New_York",
  "consecutiveMisses": 0,          // drives back-off
  "lastNudgedAt": <timestamp>,
  "mutedUntil": null
}
```

Scheduled function query: `where('nextNudgeAt', '<=', now).limit(500)` — one index, one
page, no full scan.

### 5.4 `users/{uid}` — additive fields

Client-writable: `uid`, `displayName`, `email`, `fcmToken`, `deviceId`, `tz`, `source`,
`updatedAt`.
**Server-only:** `standRoomIds`, `standPass`.

```jsonc
{ "standRoomIds": ["r_7f3a9c2e"],
  "standPass": { "expiresAt": <timestamp>, "grantedBy": "r_7f3a9c2e" } }
```

### 5.5 `accountMerges/{ticket}`

`{ fromUid, createdAt, expiresAt }`. Never client-readable or writable.

### 5.6 Indexes (`firestore.indexes.json`)

```jsonc
{ "collectionGroup": "standNudges", "queryScope": "COLLECTION",
  "fields": [ { "fieldPath": "nextNudgeAt", "order": "ASCENDING" } ] },
{ "collectionGroup": "standRooms", "queryScope": "COLLECTION",
  "fields": [ { "fieldPath": "status", "order": "ASCENDING" },
              { "fieldPath": "lastActivityAt", "order": "ASCENDING" } ] }
```

### 5.7 TTL / retention

Firestore TTL policies on `standInvites.expiresAt` and `accountMerges.expiresAt`. A
scheduled sweep archives rooms `lastActivityAt` older than 60 days (`status: "archived"`,
`members` name fields cleared), and deletes archived rooms after a further 180 days.

---

## 6. Security rules

Append to `firestore.rules`. **Section 4.2's `isFullAccount()` swap in the Prayer Wall
rules ships in the same commit — the two are not separable.**

```
// ─── Helpers (Stand With Me) ────────────────────────────────────────

function isMember(roomData) {
  return signedIn() && request.auth.uid in roomData.memberUids;
}

// Fields on a room that no client may ever touch. Membership changes,
// the campaign itself, and milestone bookkeeping are server-only:
// joining goes through the joinStand callable precisely so a client
// cannot add itself to a room whose id it happened to learn.
function roomServerOnlyFields() {
  return ['id', 'createdAt', 'createdBy', 'enforcement', 'memberUids',
          'status', 'completedAt', 'notifiedMilestones', 'schemaVersion'];
}

// Day stamps are validated for SHAPE ONLY, deliberately.
//
// Rules have no date formatting, so comparing a "yyyy-MM-dd" string to
// request.time means hand-building a padded stamp with nested ternaries —
// fragile, and it would reject any write that sat in the offline queue
// overnight. It is also unnecessary: the stamp is display-only. What
// actually protects progress is dayNumber monotonicity, the 0…7 cap, the
// one-new-stamp-per-write cap, and the fact that the room is a mirror
// (§2). The worst a clock-manipulated client achieves is misplaced dots
// on its own week strip.
function isWellFormedDayStamp(stamp) {
  return stamp is string && stamp.size() == 10;
}

// ─── Stand rooms ────────────────────────────────────────────────────

match /standRooms/{roomId} {

  // Members only. There is no list/query path for clients — the app
  // reads rooms by id from users/{uid}.standRoomIds.
  allow read: if isMember(resource.data);

  // Created exclusively by the createStand callable (admin SDK bypasses
  // rules), so a client can never mint a room it owns the shape of.
  allow create: if false;
  allow delete: if false;

  allow update: if isMember(resource.data)
    // No client may rewrite the campaign, the roster, or the status.
    && !request.resource.data.diff(resource.data)
          .affectedKeys().hasAny(roomServerOnlyFields())
    // A member may only ever modify their OWN entry in the members map.
    && request.resource.data.members.diff(resource.data.members)
          .affectedKeys().hasOnly([request.auth.uid])
    // Progress is monotonic and bounded. Ground taken is never given back.
    && request.resource.data.members[request.auth.uid].dayNumber is int
    && request.resource.data.members[request.auth.uid].dayNumber >= 0
    && request.resource.data.members[request.auth.uid].dayNumber <= 7
    && request.resource.data.members[request.auth.uid].dayNumber
         >= resource.data.members[request.auth.uid].dayNumber
    // At most one new day stamp per write, capped at 14 total.
    && request.resource.data.members[request.auth.uid].daysSpoken.size()
         <= resource.data.members[request.auth.uid].daysSpoken.size() + 1
    && request.resource.data.members[request.auth.uid].daysSpoken.size() <= 14
    // The name is shown to other people; bound it here too, not only in the UI.
    && request.resource.data.members[request.auth.uid].name is string
    && request.resource.data.members[request.auth.uid].name.size() <= 24
    // Server clock, not the device's.
    && request.resource.data.members[request.auth.uid].lastSpokeAt == request.time
    && request.resource.data.lastActivityAt == request.time;
}

// ─── Invites, nudges, merge tickets: server-only ────────────────────
//
// standInvites is closed to clients so codes cannot be enumerated,
// probed for validity, or read off a room. Redemption is the joinStand
// callable, which rate-limits and audits.

match /standInvites/{code}   { allow read, write: if false; }
match /standNudges/{uid}     { allow read, write: if false; }
match /accountMerges/{ticket}{ allow read, write: if false; }
```

**Replace the existing `users/{uid}` rule.** It currently grants blanket
`read, write` to the owner, which would let any client mint itself a `standPass` (free
premium) and forge `standRoomIds`:

```
match /users/{uid} {
  allow read:   if signedIn() && request.auth.uid == uid;
  allow create: if signedIn() && request.auth.uid == uid
                && !request.resource.data.keys().hasAny(['standPass', 'standRoomIds']);
  allow update: if signedIn() && request.auth.uid == uid
                && !request.resource.data.diff(resource.data)
                      .affectedKeys().hasAny(['standPass', 'standRoomIds']);
  allow delete: if false;   // account deletion goes through the callable
}
```

---

## 7. Cloud Functions — `functions/standTogether.js`

Register in `functions/index.js`:

```js
module.exports = {
  ...require('./prayerWallNotifications'),
  ...require('./bibleChat'),
  ...require('./personalMessage'),
  ...require('./standTogether'),
};
```

### 7.1 `createStand` (callable)

Input `{ enforcement, name, tz }`. Steps:

1. Reject anonymous-*and*-unverified abuse: max **3 active rooms created per uid**, max
   10 created per uid per 7 days.
2. Validate `enforcement`: exactly 7 days, `dayNumber` 1…7 unique, every string field
   within length bounds, total serialized size < 64 KB. Reject anything else — this blob
   is served to other people's devices.
3. Create the room with the caller as sole member, `isOwner: true`.
4. Mint the first invite code.
5. Write `users/{uid}.standRoomIds` via `FieldValue.arrayUnion`.
6. Return `{ roomId, code }`.

### 7.2 `createStandInvite` (callable)

Owner-only. Max 5 unrevoked, unexpired invites per room. Returns a fresh code.

### 7.3 `revokeStandInvite` (callable)

Owner-only. Sets `revoked: true`.

### 7.4 `joinStand` (callable) — the interesting one

Input `{ code, name, tz }`. **All of this runs in one transaction.**

```
throttle: max 20 join attempts per uid per rolling hour → resource-exhausted
          (this is the brute-force guard on an 8-character code)

lookup standInvites/<normalized code>       → not-found      "That code doesn't exist."
invite.revoked                              → permission-denied "This invite was turned off."
invite.expiresAt < now                      → deadline-exceeded "This invite expired."
invite.uses >= invite.maxUses               → resource-exhausted "This invite is used up."
room missing                                → not-found
room.status != 'active'                     → failed-precondition "This stand already finished."
room.memberUids.length >= 12                → resource-exhausted "This stand is full."

already a member, left == false             → OK, return {roomId, alreadyMember: true}
already a member, left == true              → rejoin: left = false, keep prior days
otherwise                                   → add member { dayNumber: 0, daysSpoken: [] }

increment invite.uses
users/{uid}.standRoomIds arrayUnion roomId
grant Stand Pass if the joiner has no active entitlement (§10)
recompute standNudges/{uid}
```

Normalize the code before lookup: uppercase, strip `-`, whitespace and any other
non-alphanumeric characters. No confusable-character *mapping* is applied, and that falls
out of the alphabet choice: because both members of each confusable pair are excluded
(`0`/`O`, `1`/`I`/`L`), a typed `0`, `O`, `1`, `I` or `L` cannot be a valid code character
under any reading. Reject with *"Check that code — it should be 8 letters and numbers"*
rather than guessing, which is the one behavior that could silently drop someone into the
wrong family's stand.

Returning `alreadyMember` rather than an error is deliberate: tapping the same link
twice, or tapping it on a second device, must be a no-op, not an error screen.

### 7.5 `leaveStand` (callable)

Sets `left: true`, removes the uid from `memberUids`, removes the room from
`standRoomIds`, recomputes nudges. The member entry is kept (with `name` cleared) so the
remaining members' week strip does not silently renumber. If the leaver was the owner,
ownership transfers to the earliest-joined remaining member. If they were the last
member, the room and its invites are deleted.

### 7.6 `onStandRoomUpdated` — `onDocumentUpdated('standRooms/{roomId}')`

Diffs `before`/`after` members maps and finds uids whose `daysSpoken` grew.

**Fan-out policy — this is the difference between a beloved feature and an uninstall:**

| Room size | Behavior on a member speaking |
|---|---|
| **2 (duo)** | Immediate push to the partner: *"Sarah spoke Day 3 over your family. Your turn."* Capped at **one per sender per day** via a `notifiedDays` bookkeeping map on the room. |
| **3–12** | **No immediate push.** Ever. A 10-person room would otherwise emit 90 pushes/day. Only the daily digest in §7.7 fires. |

Also here:

- When every non-`left` member has `dayNumber == 7`: set `status: 'completed'`,
  `completedAt`, push once to all (`notifiedMilestones` contains `all_day_7` → skip), and
  drop all nudges.
- Always refresh `lastActivityAt` and each affected `standNudges/{uid}`.

### 7.7 `standDailyNudge` — `onSchedule('every 60 minutes')`

```
query standNudges where nextNudgeAt <= now limit 500
for each:
  skip if mutedUntil > now
  load the user's rooms; skip rooms that are completed/dormant
  if the user already spoke today (their local day stamp is in daysSpoken) → reschedule, no send
  if NOBODY else in the room spoke today → no send (never nudge into silence;
     a nudge is "join them," never "you're failing")
  send ONE push aggregating across all their rooms:
     duo   → "Mom spoke Day 4. Stand with her."
     group → "3 of 5 have spoken today. Your turn."
  consecutiveMisses += 1
  nextNudgeAt = next 19:00 in the member's tz, then back off:
     misses 0-2 → daily
     misses 3-5 → every 3rd day
     misses 6+  → stop; mark the room dormant if no member has spoken in 14 days
```

Back-off is the feature, not an optimization. The person who stopped speaking is having
the hardest week of the year; a daily push that says *your turn* forever is how this
feature becomes the reason they delete the app.

Quiet hours are structural: the send time is 19:00 **in the member's own `tz`**, which is
why `tz` is stored per member and refreshed on every app foreground.

Token handling mirrors `prayerWallNotifications.js`: missing token → skip;
`messaging/registration-token-not-registered` → clear the token from `users/{uid}`.

### 7.8 `beginAccountMerge` / `completeAccountMerge` / `deleteAccount`

Per §4.3 and §4.5. `completeAccountMerge` is idempotent and safe to retry.

---

## 8. Client architecture

### 8.1 New files

```
Packages/SpeakLifeKit/Sources/SpeakLifeCore/
    StandRoom.swift               # Codable models, pure, no Firebase
    StandDayStamp.swift           # local-day stamp + timezone helpers
Packages/SpeakLifeKit/Tests/SpeakLifeCoreTests/
    StandRoomTests.swift
    StandDayStampTests.swift

SpeakLife/SpeakLife/Services/Stand/
    StandService.swift            # Firestore + Functions; the only Firebase-aware layer
    StandAuthCoordinator.swift    # anonymous auth, Apple linking, merge tickets
    StandPassStore.swift          # server-granted 7-day entitlement
SpeakLife/SpeakLife/Views/Stand/
    StandRoomView.swift           # the room: week strip per member
    StandInviteSheet.swift        # ShareLink + code, matches StreakShareCardRenderer styling
    StandJoinView.swift           # link landing + manual code entry
    StandConflictSheet.swift      # "you're already on day 3 of …"
    StandCompletionView.swift     # day 7, shared share card
```

`StandRoom.swift` lives in `SpeakLifeCore` (Foundation-only) so the model and all its
merge/validation logic are unit-testable without Firebase, matching how `Enforcement`
and `EnforcementProgress` are already structured.

### 8.2 The write path — one hook

`EnhancedStreakViewModel.completeTask` already owns the advance
(`Packages/SpeakLifeKit/Sources/SpeakLifeServices/EnhancedStreakViewModel.swift:629`).
Extend that existing `switch`, do not add a second call site:

```swift
if taskId == "complete_daily_burst", EnforcementService.shared.isEnabled {
    let enforcementId = EnforcementService.shared.progress.activeEnforcementId
    switch EnforcementService.shared.advanceIfNeeded() {
    case .advanced(let day):
        CoreAnalytics.track("enforcement_day_completed", parameters: [...])
        StandMirror.shared?.recordDay(day - 1)          // ← new, fire-and-forget
    case .completed(let id, let elapsedDays):
        CoreAnalytics.track(...)
        StandMirror.shared?.recordDay(Enforcement.length)   // ← new
    case .notActive, .alreadyAdvancedToday:
        break
    }
}
```

`StandMirror` is a tiny protocol declared in `SpeakLifeServices` and implemented by
`StandService` in the app target. `EnhancedStreakViewModel` must not gain a Firebase
import — that is the same seam `StreakShareCardRenderer` already uses to keep UIKit out
of Core, and breaking it blocks the package extraction in progress.

`recordDay` is non-throwing, non-blocking, and its failure is invisible to the user. The
room is a mirror (§2).

### 8.3 Write mechanics

```swift
db.collection("standRooms").document(roomId).updateData([
    "members.\(uid).dayNumber":   dayNumber,
    "members.\(uid).daysSpoken":  FieldValue.arrayUnion([todayStamp]),
    "members.\(uid).lastSpokeAt": FieldValue.serverTimestamp(),
    "members.\(uid).tz":          TimeZone.current.identifier,
    "lastActivityAt":             FieldValue.serverTimestamp(),
])
```

- Nested field paths mean two members writing concurrently do not clobber each other.
- `arrayUnion` makes the day stamp idempotent — repeated writes on the same day are free.
- **Enable Firestore offline persistence** at startup so this queues on a plane and
  flushes on reconnect.

### 8.4 Read path

One snapshot listener per active room, attached when `StandRoomView` appears and
detached on disappear. Rooms are read by id from `users/{uid}.standRoomIds`; there is no
client query against `standRooms` (and the rules forbid one).

Last-known room state is cached to `UserDefaults` so the room renders instantly offline,
matching `PrayerWallViewModel`'s `cachedPrayerWallPosts` approach.

---

## 9. Invite & deep link flow

**Link:** `https://speaklife.app.link/stand/<CODE>` — the Branch domain already in
`SpeakLife.entitlements`.

**Branch is fully live**, all three halves in place: the SDK (`ios-branch-sdk-spm`) is in
`Package.resolved`, the live key is at `Info.plist:58`, and `applinks:speaklife.app.link`
is in `SpeakLife.entitlements`. `BranchAttribution.isConfigured` therefore returns `true`,
and `initSession` (`AppDelegate.swift:221`) already resolves deferred deep links on fresh
installs. Deferred deep linking is available to this feature on day one.

(Two docs claim otherwise — `docs/ATTRIBUTION_MMP.md:20` and the doc comment at
`AppDelegate.swift:602` both say the wrapper no-ops until the key is set.
`docs/ATTRIBUTION_SHIP_CHECKLIST.md:12` is the accurate one. The stale comments should be
corrected in a separate pass.)

Three paths, in order:

1. **App installed** → universal link opens the app, `onOpenURL`
   (`SpeakLife/SpeakLife/App/SpeakLifeApp.swift:145`) parses `/stand/<CODE>` and routes
   to `StandJoinView`.
2. **App not installed** → App Store → Branch's deferred link delivers the code on first
   launch. This is the primary path for the invitee who doesn't have SpeakLife yet, which
   is the highest-value install in the whole feature.
3. **Deferred match misses** → the invite message the sender shared *also contains the
   human code*, and the post-onboarding screen asks *"Were you invited to stand with
   someone?"* with a code field. Branch's deferred matching is probabilistic, not
   guaranteed, so this fallback stays — it is why the code alphabet is readable out loud
   over the phone.

### Wiring the code through Branch

`BranchAttribution.apply(_:)` currently handles only `ob=` onboarding variants and
attribution keys. It needs one more branch, reading a `stand` key set on the link's
deep-link data (falling back to parsing `/stand/<CODE>` out of `~referring_link`):

```swift
if let code = params["stand"] as? String {
    AppState.shared.pendingStandCode = code
}
```

**Do not present the join UI from here.** A deferred link resolves during
`didFinishLaunching`, which on a fresh install is *before or during onboarding*. Stash the
code, let onboarding finish, then present `StandJoinView`. A join sheet fighting the
onboarding flow is how the invitee bounces on their first launch.

`pendingStandCode` persists (`@AppStorage`) so a kill mid-onboarding doesn't lose the
invite, and is cleared on successful join or explicit dismissal.

Share text (via `ShareLink`, already used in 12 views):

> I'm speaking God's word over {theme} for 7 days. Stand with me.
> speaklife.app.link/stand/ABCD-2345
> (or open SpeakLife and enter code ABCD-2345)

Add `/stand/` to the `onOpenURL` handler **before** the existing attribution calls, and
route notification taps with `notificationType == "stand"` through
`handleNotificationContent` — as a banner-only type like `prayerWall`, unless the payload
carries `deepLink: "stand"`, in which case open the room.

---

## 9.5 Discovery: how anyone finds out this exists

A share feature nobody finds is dead. The link mechanics above are worthless without
this section.

**The rule: ask at peak emotional payoff, not at peak convenience.**

This is usually a trade — asking later means partners start out of sync — but not here.
`dayNumber` is per-member and campaigns wait rather than expire (§2), so a partner who
joins on day 3 is not *behind*, they are on their own day 1. There is no sync to protect,
which frees the ask to land at the moment with the most emotional charge instead of the
moment that keeps a calendar tidy. This is a direct payoff of the mirror invariant and
should not be traded away later for a "start together" flow.

### Entry points, in priority order

| # | Surface | Copy / moment | Rationale |
|---|---|---|---|
| 1 | **Burst completion, day 1** (`DailyDeclarationBurstView` → `DayCelebrationView`) | *"Day 1 done. Who needs this with you?"* | **Primary.** They just spoke it out loud and felt it. Highest-charge moment in the loop. Fires once, on day 1 only — not every day. |
| 2 | **`EnforcementCard.activeCard`** — a row under the existing `DAY n OF 7 · ENFORCING …` eyebrow | *"Stand with me"* + member avatars once joined | **The durable home.** Always findable, and the only path by which users *already mid-campaign when this ships* discover the feature at all. |
| 3 | **Campaign start**, right after `startEnforcement` | Optional *"Invite someone"* step | Lower conversion — no value felt yet — but partners begin day 1 together. **Never blocking**; a skipped invite must not delay the first burst. |
| 4 | **`EnforcementCompletionView`**, beside `ENFORCE THE NEXT ONE` | *"Run the next one with someone."* | Converts finishers into inviters at the moment they have proof it works. |
| 5 | **Launch broadcast** — one push + one `speakLifeMessages` timeline entry via `personalMessage.js` | *"You can run your next seven days with someone now."* | The **only** way the existing install base learns this exists. One send, not a campaign. |
| 6 | **Onboarding** — *"Were you invited to stand with someone?"* code field | — | Catches the invitee whose deferred Branch match missed (§9, path 3). |
| 7 | **Profile → "My Stands"** | Durable list of active and past stands | Low discovery, but the feature needs a permanent address once the campaign card is gone. |

Surfaces 1, 3 and 4 are one-shot per campaign and must respect a global
`standInvitePromptCount` cap (3) so someone who is never going to invite anyone stops
being asked. Surface 2 is passive and always present, and does not count against the cap.

### The share itself

`ShareLink` (already used across 12 views) opens the iOS share sheet, which surfaces
iMessage and WhatsApp first — where family invites actually happen, as opposed to a
copy-link button that lands nowhere.

**Share an image, not a bare URL.** `StreakShareCardRenderer` already renders a 1080x1920
card; a `StandInviteCardRenderer` built the same way ("I'm speaking God's word over peace
for 7 days. Stand with me.") lands far harder in a text thread than a naked link, and the
drawing code to copy already exists. The link and the human code ride in the message body
underneath it.

### Room creation timing

Tapping Invite must call `createStand` *before* there is a code to render, so the room is
minted at first tap, not at first join. Consequence: a user who taps Invite and never
sends anything leaves a one-member orphan room. These are swept by the same archive job
as §5.7 but on a shorter clock — 14 days with one member and zero invite uses.

Do not pre-create rooms speculatively at campaign start; an unshared room is cheap but a
room per campaign per user is not.

---

## 10. Premium gating & the Stand Pass

- **Creating** a Stand requires premium — consistent with
  `startEnforcement(id:isPremium:)`, which already gates campaigns.
- **Joining** does not. The invitee receives a **Stand Pass**: 7 days of full access,
  granted server-side by `joinStand` at `users/{uid}.standPass.expiresAt`.
- The pass is **server-written and client-unwritable** (§6). A client-writable pass is
  free premium for anyone who can open a Firestore console.
- The app ORs the pass into its premium check. `StandPassStore` reads the value on
  launch and caches it; a tampered local cache costs at most 7 days of access to one
  device, and the server value re-asserts on next read.
- **Mid-campaign lapse:** a pass that expires on day 5 must not eject someone from their
  stand. `advanceIfNeeded` is already deliberately not premium-gated
  (`EnforcementService.swift:13`) — a Stand inherits that rule exactly. The paywall
  appears on day 7 at the completion screen, which is the best conversion moment the app
  has: they just finished something with someone they love.
- Do **not** grant a pass to a user who already has an active entitlement (no stacking,
  no accidental refund exposure).

---

## 11. Edge cases

### 11.1 Campaign conflicts on join

| Situation | Behavior |
|---|---|
| Joiner has no active campaign | Start the room's campaign. Straight through. |
| Joiner is on the **same** `enforcement.id` | Adopt it. Keep their existing `completedDayNumbers` — do **not** call `begin()`, which resets progress. |
| Joiner is on a **different** campaign, day 1–2 | `StandConflictSheet`: *"You're on day 2 of Enforcing Healing. Joining Mom's stand starts Enforcing Peace instead."* Confirm required. |
| Joiner is on a **different** campaign, day 3+ | Same sheet plus a *Finish mine first* option: join the room at `dayNumber: 0` and start the shared campaign when the current one completes. Never silently discard 3+ days of someone's week. |
| Joiner's campaign is complete but uncelebrated | Let the celebration present first, then join. `justCompleted` is persisted precisely so it survives this. |

`begin()` wipes `activeEnforcementId`, `startedOn`, `completedDayNumbers` and
`lastAdvancedOn` while preserving `completedEnforcementIds`. Any path that calls it
without explicit user confirmation is a data-loss bug.

### 11.2 Time

| Case | Behavior |
|---|---|
| Members in different timezones | Each member's "spoke today" uses **their own** local day stamp. Nobody is late because of a date line. |
| Member travels across timezones | `tz` refreshes on every foreground; the nudge reschedules to the new local 19:00. A stamp written in the old zone stays — it's display only. |
| Member sets their clock forward to farm days | `dayNumber` is monotonic and capped at 7, `daysSpoken` at 14, one new stamp per write. Worst case: misplaced dots on their own strip. Campaign integrity is untouched — `advanceIfNeeded` guards locally with `hasAdvancedToday`. |
| Write queued offline for 3 days | Accepted on flush — stamps are shape-validated only (§6), so a queued write never fails for being stale. `arrayUnion` and `dayNumber` monotonicity keep the result correct. |
| DST transition | Day stamps come from `Calendar.current`, which handles DST. Never compute a day by dividing an interval by 86 400. |

### 11.3 Membership

| Case | Behavior |
|---|---|
| Same link tapped twice | `alreadyMember: true`, no error, opens the room. |
| Same person on iPhone and iPad | Same uid if Apple-linked → one member, two devices, both listening. If anonymous → two members; the §4.3 merge collapses them on link. |
| Room full (12) | `resource-exhausted`, clear copy, offer to start their own stand. |
| Owner leaves | Ownership transfers to earliest-joined remaining member. |
| Last member leaves | Room and invites deleted. |
| Deferred link resolves mid-onboarding | Code is stashed in `pendingStandCode`, never presented over onboarding. `StandJoinView` opens once onboarding completes (§9). |
| Member joins and never speaks | No nudges after 3 misses (§7.7). They are not shamed and the room's other members are not told. |
| Member deletes the app | Nothing breaks. Their row freezes. Nudges stop when the FCM token goes stale. |
| Invited person already in the room under another identity | Merge table, §4.3. |

### 11.4 Content & safety

| Case | Behavior |
|---|---|
| Profanity / a slur as a display name | Length-capped at 24 (UI **and** rules), run through the app's existing local filter before write, first name only. No free text anywhere else in the feature. |
| A child in a family stand | No free text, no photos, no discovery, invite-only. A stand cannot be joined by someone who wasn't sent the code. |
| Harassment via nudges | Nudges are template-only and server-generated; no user can compose a message to another. Leaving a stand is one tap and immediate. |
| Someone's private struggle revealed by the campaign theme | The theme is visible to everyone in the room. Say so plainly on the invite screen *before* the link is generated: *"Everyone you invite will see you're standing for {theme}."* |

### 11.5 Failure modes

| Case | Behavior |
|---|---|
| Firestore unreachable | Room renders from cache with a "last updated" line. Local campaign unaffected (§2). |
| Push permission denied | Feature works fully in-app; the room screen is the surface. Never block joining on a notification prompt. |
| Cloud Function cold start / timeout | `joinStand` is idempotent; the client retries twice with backoff before showing an error. |
| Malformed / hostile `enforcement` blob | Validated server-side on `createStand` (§7.1). Client decode uses the lenient `Enforcement.init(from:)`, which already degrades an unknown theme to `.faith` rather than throwing. |
| Room doc approaching 1 MiB | Impossible at 12 members × 14 stamps + a 64 KB campaign, but `createStand` enforces the campaign size bound anyway. |
| Two members complete simultaneously | Different nested field paths; both writes land. |
| Clock skew between client and server | Only `request.time` is trusted for `lastSpokeAt` and `lastActivityAt`. |

---

## 12. Analytics

Use `CoreAnalytics.track` in the package, `AnalyticsService.shared.track` in the app.

| Event | Properties |
|---|---|
| `stand_created` | `enforcement_id`, `theme`, `is_generated` |
| `stand_invite_shared` | `room_id`, `channel` |
| `stand_invite_opened` | `source` (`universal_link` \| `deferred` \| `manual_code`) |
| `stand_joined` | `room_id`, `member_count`, `had_active_campaign`, `conflict_resolution` |
| `stand_join_failed` | `reason` (`expired` \| `revoked` \| `full` \| `not_found` \| `completed` \| `throttled`) |
| `stand_day_spoken` | `room_id`, `day`, `member_count`, `others_spoken_today` |
| `stand_nudge_sent` | server-side; `room_id`, `kind` (`duo` \| `digest`) |
| `stand_nudge_opened` | `room_id`, `kind` |
| `stand_completed` | `room_id`, `member_count`, `elapsed_days`, `all_finished` |
| `stand_left` | `room_id`, `day_number`, `was_owner` |
| `stand_pass_granted` / `stand_pass_converted` | `room_id`, `days_to_convert` |
| `account_anonymous_created`, `account_linked_apple`, `account_merge_completed` | `trigger` |

**Per `docs/ANALYTICS_DATA_QUALITY.md`:** do not write null tests as
`empty(toString(...))` — it always reports zero nulls. Global context properties are
absent on builds older than 4.54, so every Stand event carries the properties it needs
explicitly rather than relying on context. Filter simulator traffic before reading any
of these.

**North-star metric:** D7 retention of *invitees* vs. matched non-invited installs.
Secondary: Stand Pass → paid conversion, and day-7 completion rate for Stands vs. solo
Enforcements (the hypothesis is that it roughly doubles).

---

## 13. Rollout

1. `stand_together_enabled` defaults `false` via `DefaultFeatureFlags`; flip through
   Firebase Remote Config, which `RemoteConfigFlags` already backs.
2. Deploy rules + functions **before** the client build reaches TestFlight. The
   `isFullAccount()` Prayer Wall change (§4.2) is backward-compatible with every shipped
   client, so it can go first and independently.
3. Internal (team Apple IDs) → 5% → 50% → 100%, watching `stand_join_failed` reasons and
   push opt-out rate at each step.
4. Kill switch: flipping the flag off hides all Stand UI. The campaign keeps running
   locally, because the room was only ever a mirror.

---

## 14. Testing

### Unit — `SpeakLifeCoreTests` (no Firebase)
- Day-stamp generation across DST boundaries, across the date line, and at 23:59:59.
- Room model decode with an unknown theme → `.faith`, not a throw.
- Member-merge logic: all four states in the §4.3 table.
- Join-conflict resolution: all five rows in the §11.1 table.
- `daysSpoken` trim keeps the newest 14.

### Rules — `@firebase/rules-unit-testing` against the emulator
- Non-member cannot read a room. ✗
- Member cannot write another member's entry. ✗
- Member cannot lower their own `dayNumber`. ✗
- Member cannot write `dayNumber: 8`. ✗
- Member cannot add two day stamps in one write. ✗
- Member cannot touch `enforcement`, `memberUids`, or `status`. ✗
- Member can record today's stamp. ✓
- Client cannot write `users/{uid}.standPass`. ✗
- **Anonymous user cannot create a Prayer Wall post.** ✗ ← guards §4.2
- Apple-signed user still can. ✓
- Client cannot read `standInvites`. ✗

### Functions — emulator
- `joinStand`: every failure branch in §7.4, plus double-join idempotency.
- Throttle: the 21st join attempt in an hour is rejected.
- `onStandRoomUpdated`: a 2-person room pushes once; a 5-person room pushes zero.
- `completeAccountMerge`: run twice, assert identical end state.
- Invite code generation: 100 000 codes, zero collisions, uniform character distribution.

### Manual QA matrix
Two physical devices, two Apple IDs. Create → invite → join → both speak → verify strips.
Then: airplane mode during a completion; timezone change mid-campaign; clock moved
forward a week; app deleted and reinstalled (anonymous, then Apple-linked); sign out
while in a stand; join a full room; join with an expired code; both members finish day 7
minutes apart; leave as owner; delete account while in two stands.

---

## 15. Work breakdown

| # | Work | Files | Est. |
|---|---|---|---|
| 1 | Rules: `isFullAccount()` swap + `users` field lockdown + Stand rules | `firestore.rules` | 0.5d |
| 2 | Rules tests | `functions/test/rules.test.js` (new) | 0.5d |
| 3 | Cloud Functions | `functions/standTogether.js`, `index.js`, `firestore.indexes.json` | 2d |
| 4 | Function tests | `functions/test/standTogether.test.js` | 1d |
| 5 | Core models + day stamps + tests | `SpeakLifeCore/StandRoom.swift`, `StandDayStamp.swift` | 1d |
| 6 | Anonymous auth + Apple linking + merge | `StandAuthCoordinator.swift`, `AppleSignInService.swift` | 2d |
| 7 | `StandService` + `StandMirror` seam + write hook | `Services/Stand/`, `EnhancedStreakViewModel.swift` | 1.5d |
| 8 | Room UI | `StandRoomView.swift` + components | 2d |
| 9 | Invite / join / conflict UI | `StandInviteSheet`, `StandJoinView`, `StandConflictSheet` | 1.5d |
| 10 | Deep link + notification routing + `BranchAttribution.apply` stand key | `SpeakLifeApp.swift`, `AppDelegate.swift` | 0.5d |
| 11 | Stand Pass | `StandPassStore.swift`, premium check | 0.5d |
| 12 | Completion + shared share card | `StandCompletionView.swift`, `StandShareCardRenderer.swift` | 1d |
| 12b | Discovery surfaces (§9.5) + `StandInviteCardRenderer` | `EnforcementCard.swift`, `DayCelebrationView`, `EnforcementCompletionView.swift`, onboarding, Profile | 1.5d |
| 12c | Launch broadcast | `functions/personalMessage.js` (content only) | 0.25d |
| 13 | Analytics + flag + rollout | various | 0.5d |
| 14 | QA matrix | — | 1.5d |

**≈ 18 working days.** Items 1–4 are independent of the client and can ship first.

---

## 16. Open decisions

1. **Room cap of 12.** Chosen so one document holds the room and one listener serves it.
   A small-group ministry use case wanting 30 needs a subcollection refactor. Confirm 12
   is right before building.
2. **Deferred-match rate.** Branch is live (§9), so invitees without the app land
   straight in the room. Branch's deferred matching is probabilistic, though — instrument
   `stand_invite_opened.source` from day one and watch the `manual_code` share. If it runs
   high, the fallback prompt needs to be more prominent, not less.
3. **Stand Pass length.** 7 days matches the campaign. 14 would cover a slow starter and
   land the paywall after a *completed* stand rather than during one.
4. **Nudge time.** 19:00 local is a guess. The app already models time slots in
   `TimeSlots.swift`; using the member's own reminder window would be better and costs
   little.
5. **Should a Stand grant streak days?** Recommendation: **no.** Keep streak and stand
   orthogonal, per §1.
