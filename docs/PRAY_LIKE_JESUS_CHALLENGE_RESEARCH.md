# Pray Like Jesus — Social Challenge Research & Build Recommendation

**Question asked:** What kind of "pray like Jesus" social challenge can we run for
7 / 14 / 30 days on Firebase? What do the top apps do? Does it move retention?
Is it worth building?

**Short answer:** Yes, it is worth building — but not the way it's usually scoped.
The retention evidence for time-boxed social challenges is strong and specific.
The catch is that **SpeakLife already owns ~80% of the engine locally**
(`EnforcementService` + Prayer Wall + Cloud Functions), so the right first build
is a content variant with zero backend, not a greenfield Firebase feature. Buy
the backend only after the content proves out.

---

## 1. What the top apps actually ship

| App | Challenge | Shape | Social mechanic | Notable outcome |
|---|---|---|---|---|
| **Hallow** | Pray40 (Lent), Pray25 (Advent), 54-Day Rosary Novena, 9-day intro | Fixed-length, **calendar-anchored**, cohort start date (Ash Wednesday), celebrity-guided | Global participation counter, shared start date, church/parish groups | ~2M joined Pray40 in 2025 (1.7M in 2024); hit **#1 overall** on the App Store on Ash Wednesday |
| **YouVersion** | Plans + **Plans with Friends** | Any plan length, evergreen | Up to 150 friends on one plan, see each other's day progress, private per-day discussion thread | YouVersion states having **even one friend** makes a user more likely to stay engaged; **reschedules gracefully when you miss a day** |
| **Duolingo** | Streaks, **Friend Streaks**, Quests | Evergreen daily | Friend Streak = mutual daily commitment between two people | Learners with ≥1 Friend Streak are **22% more likely to complete their daily lesson**; more friend streaks → higher still |
| **Glorify** | Multi-day audio courses, streaks, community groups | Evergreen | Groups for prayer requests / Scripture discussion | 20M+ users; challenges are a browse shelf, not an event |
| **Abide** | Guided meditation series | Evergreen | Minimal social | Retention driven by sleep/audio habit, not social |

### The four things that separate the winners

1. **A start date the world already keeps.** Pray40 works because Lent is a
   pre-existing global cohort. Hallow does not have to manufacture urgency — the
   calendar does it. This is the single biggest lever, and it is bigger than
   length (7 vs 14 vs 30).
2. **Agreement over competition.** None of the faith apps run leaderboards.
   YouVersion shows friends' *progress*, Duolingo shows a *mutual* streak. Nobody
   ranks believers against each other.
3. **Missing a day is survivable.** YouVersion explicitly reschedules the plan.
   Duolingo sells Streak Freeze. A challenge that punishes the first slip loses a
   large share of users at that slip.
4. **The daily unit is small.** 3–8 minutes. The challenge is a habit scaffold,
   not a course.

### Evidence that time-boxing itself works

- Time-boxed challenges run **40–60% completion**, versus **5–15%** for
  open-ended/evergreen course content. The start and end dates are doing that work.
- Apps with **social** streak features show average streak length of **5.69 days
  vs 4.25 days** without — roughly a **34% lift** attributed to accountability.
- Limited-run challenges with a defined start date are consistently reported as
  the strongest **re-engagement** format for lapsed subscribers, because they give
  a dormant user an event-shaped reason to return rather than a vague one.

---

## 2. What "pray like Jesus" should actually be

The theological spine is the differentiator. Hallow's challenges are Catholic
devotional forms (novena, rosary, Lent). SpeakLife's should be **the way Jesus
Himself prayed** — which is both distinct and, conveniently, maps onto mechanics
the app already has.

What Jesus modeled, and the mechanic each one implies:

| Day theme | Scripture | Mechanic it maps to |
|---|---|---|
| Withdraw before dawn to a solitary place | Mark 1:35, Luke 5:16 | Morning reminder + quiet-time timer (exists) |
| Pray in secret, not for show | Matthew 6:5-6 | Private by default; nothing public unless chosen |
| The Father-first pattern | Matthew 6:9-13 | Guided audio, one movement per day |
| Speak to the mountain with authority | Mark 11:22-24, Mark 4:39 | **Declarations spoken aloud** (core engine) |
| Give thanks before the miracle | John 11:41-42 | Gratitude capture |
| Pray for others by name | John 17, Luke 22:32 | **Prayer Wall post** (exists) |
| Where two agree, it is done | **Matthew 18:19-20** | **The agreement mechanic (exists as `agreements/{userId}`)** |
| Ask in My name | John 14:13-14 | Declaration framing |
| Persist through the night | Luke 6:12 | Longer session on the 30-day track |
| Not my will, but Yours | Luke 22:42 | Surrender day |
| Forgive them | Luke 23:34 | Forgiveness day |

**Matthew 18:19 is the scriptural warrant for making this social at all** — "if
two of you on earth agree about anything they ask for, it will be done." That is
not a bolted-on growth hack; it is the reason the feature has two people in it.
And SpeakLife already stores exactly this object: `prayerWall/{postId}/agreements/{userId}`.

### The 7 / 14 / 30 ladder

Do not ship three lengths of the same thing. Ship three rungs.

- **7 — "The Secret Place."** Jesus' rhythm. Withdraw, Father-first, secret, ask,
  thanks, name, agree. Free. This is the on-ramp and the one everyone finishes.
- **14 — "Speak to the Mountain."** Authority prayer. Command, don't beg. Leans
  on the declarations engine and the existing `warfare` catalog. Premium.
- **30 — "The Upper Room."** Intercession — 30 days of praying for other people
  by name. This is the one that produces testimonies, and testimonies are the
  content flywheel. Premium.

### The daily unit (target 5 minutes)

1. 60–90s teaching: one thing Jesus did in prayer
2. Guided prayer in that pattern (audio)
3. **One declaration spoken aloud** (existing engine, existing rules)
4. One name carried into the Warrior Room, or one agreement given to someone
   else's request

Steps 1–3 are private. Step 4 is the social surface, and it is *giving*, not
performing.

---

## 3. Social mechanics — what to build and what to refuse

**Build:**

- **Covenant of Two / pods of 2–5** (Matthew 18:19). The Duolingo Friend Streak
  analog, and the mechanic with the best measured evidence (+22% daily completion).
  Members see each other's day number and can send one tap: *"I stood with you today."*
- **Global counter.** "14,312 believers are praying this with you today." Hallow's
  move. Cheap, no auth required, and it is the single highest ratio of felt-community
  to engineering cost in the whole list.
- **Grace day.** One or two forgivable misses per challenge, framed as grace, not
  as a purchased freeze. The app's whole voice is grace-based; a punishing streak
  is off-brand and, per YouVersion's own design, unnecessary.
- **Cohort start dates + evergreen fallback.** Monday cohorts create the event;
  evergreen join catches everyone who arrives on a Wednesday.
- **Invite link that creates a pod.** This is the acquisition loop, and it is a
  separate business case from retention.

**Refuse:**

- **Leaderboards and public streak rankings.** Ranking believers by prayer is both
  theologically wrong for this app and, in the data, unnecessary — the faith apps
  that win do not do it.
- **Public shaming of a broken streak.** Never notify a pod that someone missed.
  Only notify on positives.
- **Solo pods.** A pod of one is worse than no pod. If the invite doesn't fill,
  auto-match into an anonymous pod or fall back to the global counter.

---

## 4. Firebase backend design

### What already exists and is directly reusable

| Existing | Location | Reuse |
|---|---|---|
| 7-day themed campaign engine (catalog, progress, advance, completion, celebration, category matching) | `Packages/SpeakLifeKit/Sources/SpeakLifeServices/EnforcementService.swift`, `SpeakLifeCore/Enforcement.swift`, `enforcements.json` (4 campaigns) | **The challenge engine.** Needs `Enforcement.length` to stop being a hardcoded `static let 7`. |
| Firestore feed + pagination + offline cache | `Views/Community/PrayerWallViewModel.swift` | Pod feed, agreement feed |
| `agreements/{userId}` subcollection | `firestore.rules`, `Views/Community/Agreement.swift` | The agreement tap, verbatim |
| FCM + scheduled + trigger functions | `functions/prayerWallNotifications.js` (`onDocumentUpdated`, `onSchedule`, digest, milestones) | Pod pings, daily nudge, milestone push |
| Streaks, streak freeze, break notification | `SpeakLifeServices/EnhancedStreakViewModel.swift`, `StreakFreezeTests.swift` | Grace day |
| iCloud/CoreData settings sync | `SpeakLifePersistence/SyncedSettingsStore.swift` | Local progress sync (already handles Enforcement progress) |
| Rules idioms: `onlyAllowsFields`, `isPostOwner`, owner-gated field lists | `firestore.rules` | Copy the pattern for enrollments |

### What is genuinely new

**Collections**

```
challenges/{challengeId}
  title, tagline, lengthDays, tier, days[]        # catalog; can stay bundled JSON at first

cohorts/{cohortId}
  challengeId, startDate, participantCount        # counter written by function only

users/{uid}/enrollments/{challengeId}
  cohortId, startedAt, currentDay, completedDays[], graceDaysUsed,
  lastCompletedAt, timeZone, status, podId

pods/{podId}
  challengeId, cohortId, inviteCode, memberCount  # 2–5 members
pods/{podId}/members/{uid}
  displayName, currentDay, lastCompletedAt        # mirror, written by function
pods/{podId}/agreements/{agreementId}
  fromUid, toUid, dayNumber, createdAt

challengeStats/{challengeId}_{yyyyMMdd}/shards/{shardId}
  count                                           # distributed counter for the global number
```

**Cloud Functions** (all v2, matching the existing file's style)

- `onEnrollmentDayCompleted` (`onDocumentUpdated`) → mirror into `pods/{podId}/members/{uid}`,
  increment the day's stat shard, push to pod: *"Marcus finished Day 3. He's praying for you."*
- `dailyChallengeNudge` (`onSchedule`, hourly, bucketed by `timeZone`) → nudge users
  who haven't completed today. Reuse the digest pattern already in
  `prayerWallNotifications.js:187`.
- `applyGraceDay` (`onSchedule`, nightly) → for a missed day, consume a grace day and
  reschedule rather than break, YouVersion-style.
- `rolloverCohorts` (`onSchedule`, weekly) → open next Monday's cohort.
- `onPodAgreement` (`onDocumentCreated`) → push to the recipient.

**Rules posture**

- `users/{uid}/enrollments/**`: read/write by owner only.
- `currentDay` may only increment by ≤1, and `lastCompletedAt` must advance — reject
  same-day double-advance client-side *and* in rules; the authoritative advance can
  move to a callable function if abuse shows up.
- `pods/{podId}/members/**`: **read** by pod members, **write** by functions only.
  This is what keeps a client from faking a pod-mate's progress.
- `challengeStats/**`: read public, write functions only.
- `pods/{podId}/agreements`: create by pod members, one per (fromUid, toUid, dayNumber).

**Prerequisite the design depends on:** the codebase has email/password and Apple
sign-in (`Services/Auth/FirebaseAuthService.swift`) but **no anonymous auth** —
`signInAnonymously` appears nowhere. The Prayer Wall currently leans on a device
ID for local state while rules require a signed-in user for writes. Pods need a
stable identity. Add anonymous auth plus an upgrade-to-Apple path **before**
Phase 2, or the sign-in wall will eat the funnel that the challenge was supposed
to fill.

**Cost:** negligible and not a decision factor. A 30-day challenge is roughly
~10 writes and a few dozen reads per user per challenge. At 100k enrolled users
completing 30 days, that's low single-digit millions of writes — on the order of
a few dollars. The expensive resource here is engineering weeks and funnel
friction, not Firestore.

---

## 5. Does it boost retention and engagement?

**Yes — with three honest caveats.**

**The case for:**

- Time-boxing is one of the few mechanics with a large, consistent effect:
  40–60% completion vs 5–15% for open-ended content.
- The social layer multiplies it: +22% daily completion for Duolingo users with a
  friend streak; ~34% longer average streaks in apps with social streaks;
  YouVersion's own stated finding that a single friend raises engagement.
- The category proof exists and is enormous: Hallow's Pray40 took a prayer app to
  **#1 overall in the App Store**, twice, on the back of one challenge.

**The caveats:**

1. **Hallow's spike is mostly acquisition, and it is seasonal.** Lent supplies the
   demand; the challenge captures it. An unanchored challenge shipped in a random
   week does not inherit that. Read Pray40 as *proof the format can carry a brand
   moment*, not as proof that any 30-day challenge lifts D30 retention on its own.
2. **Day 31 is a cliff.** A challenge concentrates engagement inside its window and
   can *depress* it after, unless completion hands off to the next thing — a next
   rung, a cohort, or a pod that outlives the challenge. Instrument this
   specifically; it is the failure mode most teams discover late.
3. **Social features can backfire in a faith app.** Anything that surfaces
   non-participation converts a spiritual practice into a performance. This is the
   reason to build agreement and refuse leaderboards — and it is a product-values
   constraint, not a nice-to-have.

---

## 6. Recommendation: staged, with a gate

The reason not to start with Firebase is that `EnforcementService` already runs
themed multi-day campaigns end to end, and `enforcements.json` already ships four
of them. The cheapest possible test of *"do our users want a prayer challenge"*
requires no backend at all.

**Phase 0 — content only, no Firebase (~1–2 weeks).**
Ship "Pray Like Jesus: 7 Days in the Secret Place" as a new entry in
`enforcements.json`, with prayer-shaped days. Generalize `Enforcement.length`
from a hardcoded 7 to a per-campaign value so the 14/30 rungs are unblocked.
Measure completion and retention against a matched control.

**Gate:** proceed only if Day-7 completion ≥40% and enrolled users show a
measurable D14 retention delta over control. If the content doesn't hold people
solo, a pod will not save it — it will just cost four more weeks first.

**Phase 1 — light Firebase (~1 week).**
Global participation counter + cohort start dates + a share card. Read-mostly,
one stats collection, no auth requirement, minimal rules risk. This is where the
"I'm not doing this alone" feeling comes from, at a fraction of Phase 2's cost.

**Phase 2 — real social (~3–4 weeks).**
Anonymous auth + upgrade path, pods, agreement pings, pod push, grace day,
rules and functions above. **This is the phase to justify with the Phase 1
numbers**, specifically the with-pod vs solo completion delta.

**Phase 3 — the ladder and the anchor.**
14 and 30-day rungs, then attach the flagship run to a date the audience already
keeps: New Year, Lent, Easter, back-to-school. **The seasonal anchor is worth more
than any additional mechanic on this list.** Pray40 is not a better challenge than
its competitors; it is a challenge with Ash Wednesday attached.

### Metrics to instrument up front (PostHog is already wired)

- Enrollment rate from the prompt, by surface
- Day 1 / 3 / 7 challenge completion; full-challenge completion
- **D30 app retention: enrolled vs matched non-enrolled** (the headline number)
- **With-pod vs solo completion delta** (the number that authorizes Phase 2)
- Trial start and conversion inside the challenge window
- **Day 31 cliff:** % of finishers who start something else within 7 days
- Grace-day usage, and completion rate of users who used one (validates the mechanic)

---

## Sources

- [Pray40 — Hallow's Lent community prayer challenge](https://hallow.com/pray40/)
- [Hallow Lent Pray40 FAQs](https://help.hallow.com/en/articles/10697582-hallow-lent-pray40-faqs)
- [Hallow makes history taking #1 spot in App Store](https://hallow.com/blog/hallow-makes-history-taking-no-1-spot-in-app-store/)
- [Hallow announces worldwide Lent prayer challenge, Pray40: The Way](https://www.pressenza.com/2025/03/hallow-announces-worldwide-lent-prayer-challenge-leading-up-to-easter-pray40-the-way/)
- [YouVersion — top hacks for more consistent Bible engagement](https://youversion.com/news/youversion-shares-its-top-hacks-for-more-consistent-bible-engagement)
- [YouVersion — Plan with Friends](https://help.youversion.com/l/en/article/at3uptn298-plan-with-friends)
- [Duolingo — product lessons from Friend Streak](https://blog.duolingo.com/product-lessons-friend-streak/)
- [Duolingo streaks: how the mechanic drives 2x daily retention](https://duolingo.deconstructoroffun.com/mechanics/streaks)
- [Mobile app engagement strategies that retain users](https://trophy.so/blog/mobile-app-engagement-strategies)
- [10 apps that use the challenges feature](https://trophy.so/blog/challenges-feature-gamification-examples)
- [Interactive challenge models for creators: 5–21 day frameworks](https://communipass.com/blog/interactive-challenge-models-for-creators-2026/)
- [Glorify: Devotional & Prayer](https://faith.tools/app/48-glorify)
