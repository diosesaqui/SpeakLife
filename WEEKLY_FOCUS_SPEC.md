# Weekly Focus Spec
### "One question before the week starts."
**Version:** 1.0 — MVP
**Status:** Draft for review

---

## Overview

A Sunday-evening check-in that asks the user one question — *"What's the biggest
thing you need God's help with this week?"* — and uses the answer to shape that
week's declarations, audio, and devotionals.

**Why this matters:**
- The app currently learns about the user once, during onboarding, and never
  again. A week later the content is still keyed off a single category chosen
  before they ever used the product.
- Sunday night is when people are already taking stock of the week ahead. The
  ask lands when the need is top of mind.
- It converts a static content library into something that visibly responds to
  them, which is the difference between a devotional app and a companion.
- Every answer is a free, high-signal input for personalization that costs one
  LLM call per user per week.

**Premium feature.** The generated week is gated behind the `premium`
entitlement. Free users still get the Sunday ask — see *Entitlement* below.

**Non-goal:** this is not a replacement for the personal declaration. See below.

---

## The two-layer model (read this first)

`PersonalDeclaration` is a **single-record** model (`personal_declaration_v1`),
and the entire emotional payoff is built on one long-running commitment:
`dayCount` → *"Day 47 of believing"* → **It Came to Pass** → testimony →
celebration.

If the Sunday check-in overwrites that record, the day count resets to 1 every
week and no user ever reaches the breakthrough moment. That trades the strongest
retention loop in the app for a weaker one.

So Weekly Focus is a **second, additive layer**:

| | The Anchor | The Week |
|---|---|---|
| Model | `PersonalDeclaration` | `WeeklyFocus` (new) |
| Storage key | `personal_declaration_v1` | `weekly_focus_history_v1` |
| Set at | Onboarding | Every Sunday |
| Horizon | Until it comes to pass | 7 days |
| Question | "What's one thing you're trusting God for?" | "What do you need God's help with this week?" |
| Day count | Keeps climbing | Resets weekly (by design) |
| Breakthrough flow | Yes | No |

The Anchor is untouched by anything in this spec. If a weekly answer repeatedly
matches the Anchor, that's a signal worth surfacing — not a conflict to resolve.

---

## Entitlement

Weekly Focus is **premium**. But the gate goes *after* the answer, not before the
ask — the moment a user has just spoken their need aloud is the highest-investment
point in the week, and it's the wrong moment to show them a locked door with
nothing behind it.

### What each tier gets

| | Free | Premium |
|---|---|---|
| Sunday push + feed card | ✅ | ✅ |
| Check-in sheet, voice input | ✅ | ✅ |
| Answer echoed back with a matched verse | ✅ (keyword match, no LLM) | ✅ |
| The 7-day week (declarations, audio, devotionals) | 🔒 Paywall | ✅ |
| Carry-over / fallback ladder | — | ✅ |

Free users answer, see their need reflected back with one verse and one
declaration, and then hit the paywall on *"Here's your week."* Same structure the
onboarding personal declaration already uses (`PERSONAL_DECLARATION_SPEC.md`,
Gap 4): capture at peak investment, then ask.

Critically, the free path costs **zero LLM calls** — it uses the existing
`KeywordDeclarationMatcher`. A free user who answers every Sunday and never
converts costs nothing but a local notification.

### Enforcement

Server-side, following `bibleChat.js:74-96` exactly: RevenueCat
`/v1/subscribers/{appUserId}` checked for the `premium` entitlement, authoritative
when it answers, with the client's `isPremiumClaim` used **only** when RevenueCat
is unreachable or the secret is unset. An RC outage must never lock out a paying
user mid-week.

Client-side gating is presentation only — it decides whether to show the week or
the paywall. It is not the security boundary.

Feature flag: Remote Config `weeklyFocusEnabled`, mirroring `enableAIFeatures`.

### When premium lapses

Let the current week finish. It's already built, already cached, and costs
nothing more to serve — yanking content mid-week reads as punitive and buys
nothing. No new week is built after it ends; the Sunday card falls back to the
free experience.

---

## Surfacing: how the Sunday ask actually reaches them

Push notification tap-through is low single digits. The push is the *invitation*,
not the capture mechanism. Three layers, escalating in visibility, all inside one
fixed window.

### The window

```
SUNDAY 5:00 PM local
  └─ SILENT: build provisional Week N+1 from the fallback ladder.
     Content is ready before anyone is asked anything.

SUNDAY 7:00 PM local
  └─ Local push fires: "One question before the week starts."

SUNDAY 7:00 PM  →  MONDAY 11:59 PM local   [ the ask window ]
  ├─ In-app card pinned to top of the declarations feed
  ├─ Monday cold-start interstitial (Remote Config flag, off by default)
  └─ Answer at any point → rebuild the REMAINING days from their answer

TUESDAY 12:00 AM local
  └─ Week locks. Card disappears. No mid-week asking.
```

The week is **always built**. Input upgrades it; the absence of input never
leaves an empty state. This is the core rule.

### Layer 1 — Local push (Sunday 7:00 PM local)

No server, no timezone fan-out. A repeating local notification fires in device
local time:

```swift
var components = DateComponents()
components.weekday = 1     // Sunday
components.hour    = 19
components.minute  = 0

let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
let content = UNMutableNotificationContent()
content.title = "One question before the week starts."
content.body  = "What do you need God's help with this week?"
content.userInfo = ["deepLink": "weeklyFocus"]
```

Mirrors the existing `DeclarationNotificationService` pattern exactly — new
identifier (`weekly_focus_checkin`), same deep-link mechanism.

Deep link handling goes in `SpeakLifeApp.handleNotificationContent()` alongside
the existing `"personalDeclaration"` case:

```swift
case "weeklyFocus":
    tabViewModel.selectedTab = 0
    appState.presentWeeklyCheckIn = true
    return
```

### Layer 2 — In-app card (the real capture surface)

A card pinned to the top of the declarations feed for the whole window. This is
where most answers will actually come from.

```
┌────────────────────────────────────────────┐
│  THIS WEEK                                 │
│                                            │
│  What do you need God's help with          │
│  this week?                                │
│                                            │
│  [ 🎤  Speak it ]        Takes 15 seconds  │
│                                    Not now │
└────────────────────────────────────────────┘
```

Dismissible. Dismissal hides it for the rest of the window, does not disable
future weeks.

### Layer 3 — Monday cold-start interstitial (flagged, A/B only)

Full-screen on first Monday open, skippable. Highest capture, highest annoyance.
Ships behind Remote Config `weeklyFocusInterstitialEnabled`, default **off**.
Only turn it on as a measured experiment.

### Answering late in the window

If the answer arrives Monday evening, days 1–2 of the week have already been
consumed. Do not discard them. Rebuild days 3–7 only and acknowledge it:

> *"Updated for the rest of your week."*

### The input screen itself

Reuse `PersonalDeclarationOnboardingView`'s flow — mic →
`SpeechTranscriptionService` → matching → result — presented as a sheet with
weekly copy. Voice-first, typing as fallback, skip always available.

The payoff must be immediate. On submit, show the week laid out — seven days,
their own words at the top. If answering feels like a form and the result feels
generic, nobody answers twice.

---

## The fallback ladder: building a week with no answer

Most users will not answer most weeks. The unanswered week must still be good,
and it must not be a copy of last week.

Resolved in order at Sunday 5:00 PM local. First hit wins.

| # | Source | Condition | `WeeklyFocusSource` |
|---|---|---|---|
| 1 | **Last week's answer, carried forward** | They answered a prior week and did not mark it resolved | `.carryOver` |
| 2 | **The Anchor** | `hasPersonalDeclaration == true` | `.anchor` |
| 3 | **SoulProfile** | Onboarding data exists | `.profile` |
| 4 | **Behavioral signal** | ≥5 content interactions in last 14 days | `.behavioral` |
| 5 | **Declared categories** | Always available | `.default` |

Levels 3 and 4 blend: the profile picks the theme, behavior breaks ties and adds
variety, so two consecutive profile-driven weeks don't look identical.

### Carry-over must progress, not repeat

This is the part that decides whether an unanswered week feels alive or feels
like the app is stuck. The same stated need in week 2 gets a **different angle**,
not the same 21 declarations reshuffled.

| `carryOverCount` | Angle | Content emphasis |
|---|---|---|
| 0 (fresh answer) | **Promise** | What God says about this. Verse-forward. |
| 1 | **Identity** | Who I am inside this. Identity + grace categories. |
| 2 | **Authority** | I speak to it. Warfare + declaration-of-authority content. |
| 3+ | **Escalate** — see below | Change the question, not the answer |

`carryOverCount` and `needBucket` are stored on the record and passed into
retrieval, so the selector is explicitly told *"week 3 on this need, go deeper."*

### Escalation at 3+ carry-overs

If the same need has carried three or more weeks with no engagement and no
breakthrough, silently regenerating a fourth week is the wrong response. Instead:

- Swap the Sunday question to: *"You've been carrying this a while. What's
  actually in the way?"*
- Surface Bible Chat with the need pre-loaded as context.
- Offer the Anchor's **It Came to Pass** flow, in case it resolved and was never
  marked.

Fires at most once per need. Tracked as `weekly_focus_escalated`.

### Push decay

If the check-in is ignored four weeks running, drop the Sunday push to monthly
while continuing to build weeks silently. The in-app card stays. Don't train
users to ignore a notification.

---

## Data model

**File:** `Models/WeeklyFocus.swift`

```swift
enum WeeklyFocusSource: String, Codable {
    case userAnswered
    case carryOver
    case anchor
    case profile
    case behavioral
    case `default`
}

enum WeeklyFocusAngle: String, Codable {
    case promise      // carryOverCount 0
    case identity     // 1
    case authority    // 2
    case escalate     // 3+
}

struct WeeklyFocus: Codable, Equatable, Identifiable {
    let id: UUID
    let weekStart: Date              // Sunday 00:00 local
    let source: WeeklyFocusSource
    let angle: WeeklyFocusAngle

    let needText: String?            // their words, verbatim. nil when not answered
    let needBucket: String           // clustering key — drives the shared cache
    let categoryRaw: String          // DeclarationCategory rawValue

    let declarationIDs: [String]     // selected from declarationsv10.json
    let devotionalKey: String        // "\(needBucket)_w\(weekOfYear)" — cache key, not content
    let audioCategoryRaw: String     // feeds existing audio ordering

    var carryOverCount: Int
    var completedDays: Set<Int>      // 0...6
    var answeredAt: Date?
    var resolvedAt: Date?

    var isAnswered: Bool { source == .userAnswered }
    var dayIndex: Int {
        Calendar.current.dateComponents([.day], from: weekStart, to: Date()).day ?? 0
    }
}
```

**`AppState.swift` — two new properties:**

```swift
@AppStorage("presentWeeklyCheckIn")  var presentWeeklyCheckIn: Bool = false
@AppStorage("weeklyFocusEnabled")    var weeklyFocusEnabled: Bool = true
```

### Storage

`UserDefaults` key `weekly_focus_history_v1`, holding an **array** of the last 12
weeks — not a single record.

Keeping history is cheap and unlocks a real feature later: *"Here's what you've
been carrying this year, and here's what God did."* A year-end recap is the
natural payoff and it needs the data to exist from day one.

Add to `SyncedSettingsStore` alongside `personal_declaration_v1` so it follows
the user across devices.

---

## Architecture

Follows the existing `Services/PersonalDeclaration/` layout — protocols, use
cases, repository, no logic in views.

```
Services/WeeklyFocus/
├── Protocols/
│   ├── WeeklyFocusRepositoryProtocol.swift
│   ├── WeeklyFocusBuilderProtocol.swift
│   └── WeeklyCheckInSchedulerProtocol.swift
├── WeeklyFocusRepository.swift          // UserDefaults, last 12 weeks
├── WeeklyFocusBuilder.swift             // the fallback ladder
├── WeeklyCheckInScheduler.swift         // local Sunday notification
├── WeeklyFocusContentSelector.swift     // retrieval from declarationsv10.json
└── UseCases/
    ├── BuildWeeklyFocusUseCase.swift    // Sunday 5pm, always runs
    ├── AnswerWeeklyFocusUseCase.swift   // on submit, rebuilds remaining days
    └── CompleteWeeklyDayUseCase.swift
```

```swift
protocol WeeklyFocusRepositoryProtocol {
    func save(_ focus: WeeklyFocus) async throws
    func current() async -> WeeklyFocus?
    func history(limit: Int) async -> [WeeklyFocus]
    func markDayComplete(_ day: Int) async throws
}

protocol WeeklyFocusBuilderProtocol {
    func build(for weekStart: Date, answer: String?) async -> WeeklyFocus
}
```

`build(for:answer:)` with `answer == nil` walks the fallback ladder. With an
answer it takes the `.userAnswered` path. One entry point, both cases.

Wire into `DIContainer` the same way the personal-declaration graph is wired.

---

## Content pipeline, per surface

### Declarations — retrieval, not generation

One call selects 14–21 declarations from the 3,156 already in
`declarationsv10.json` and sequences them across seven days.

Nothing is generated, so: no hallucinated verse references, no doctrinal risk,
and every line already passes the CLAUDE.md rules. Store IDs only.

The selector is given `needText`, `needBucket`, `angle`, and `carryOverCount`.

### Audio — nearly free

`AudioDeclarationViewModel.swift:458-470` already orders audio by
`selectedNotificationCategories` **plus**
`PersonalDeclarationRepository.activeCategoryRaw()`. Add `WeeklyFocus`'s
`audioCategoryRaw` as a third, highest-priority input and the audio tab re-sorts
itself for the week with almost no new code.

This is **curation from the existing library**, not generated audio. Per-user
generated audio is a separate project — cost, latency, and voice-quality risk all
land differently. Explicitly out of scope.

### Devotionals — generated, cached by bucket

`DevotionalService` currently serves one devotional to everyone, matched by
month/day. Weekly Focus adds a personalized layer on top:

- Content is generated **once per `(needBucket, weekOfYear)`** and shared by every
  user in that bucket.
- Only the framing line that quotes their own words is per-user — and that's a
  local string template, not an LLM call.

With ~20 buckets, the whole user base is covered by ~20 generations per week
regardless of user count. This is the difference between the feature being cheap
and being a real bill.

---

## Cost model

| Week type | LLM calls | Notes |
|---|---|---|
| Free user, any answer | **0** | Keyword match only. Paywall before generation. |
| Premium, answered | 1 per user | Classify → bucket, select IDs, write framing line. One call does all three. |
| Premium, carry-over (0–2) | **0** | Reuses stored `needBucket`, rotates IDs locally, reuses cached devotionals |
| Premium, anchor / profile / behavioral | **0** | Pure local retrieval |
| Escalation (carryOver 3+) | 1 per user | Rare by construction |
| Bucket devotionals | 1 per *occupied* bucket per week | Shared across every user in that bucket |

Unanswered weeks cost nothing. That property is worth protecting as the feature
evolves — it's what makes weekly personalization viable at scale.

**Generate buckets lazily.** Bucket caching amortizes across users, so gating to
premium shrinks the population each bucket is spread over. Generating all ~20
buckets on a schedule would mean paying for buckets nobody is in that week.
Instead, generate a bucket's devotional on first request and cache it — bucket
count then stops mattering for cost, and the number can be tuned for content
quality alone.

---

## Backend

**No cron required for v1.** The Sunday prompt is a local notification; the build
runs on device; generation happens on demand.

One new Cloud Function endpoint, following the `bibleChat.js` pattern exactly —
key in Secret Manager, server-side RevenueCat check, Firestore token metering,
`cache_control` on the system prompt:

```
POST /weeklyFocus
  { appUserId, needText, carryOverCount, angle, profile }
→ { needBucket, categoryRaw, declarationIDs[], framingLine }
```

Returns `{ needsPaywall: true }` for non-premium callers before doing any model
work, mirroring `bibleChat.js:165-168`.

**Prerequisite: move `ClaudeDeclarationMatcher` behind the proxy first.**

Today it calls `api.anthropic.com` directly, using a key fetched at runtime from
Remote Config (`SubscriptionStore.swift:493`). Fetching rather than compiling the
key in is the better of the two client-side options — it can be rotated without
an App Store release and it does not appear in a binary strings dump. But the
usable key still reaches the device: Remote Config caches fetched values to disk
in the app container, and `AnthropicConfig.apiKey` is a static var readable by a
debugger on a jailbroken device or via a MITM proxy with a user-installed CA.
There is no rate limit, no metering, and no spend cap behind it.

This is the exact rationale `bibleChat.js:5-9` gives for why chat was built as a
proxy. Note that premium-gating Weekly Focus does **not** reduce this exposure —
the matcher runs during onboarding, free and ungated, for 100% of installs.

Two related cleanups on the same file: `ClaudeDeclarationMatcher.swift:32` prints
the key prefix to the console, and `:74` ships 100 chars of Anthropic's error body
into Firebase Analytics.

The full CLAUDE.md declaration rules and the `bibleChat.js` safety block should
be the system prompt for **any** generation path, not just this one.

---

## Analytics

Instrument as an experiment from day one — the PostHog wiring already exists.

| Event | Properties |
|---|---|
| `weekly_focus_built` | `source`, `angle`, `carry_over_count`, `need_bucket` |
| `weekly_checkin_push_sent` | — |
| `weekly_checkin_shown` | `surface` (push / card / interstitial) |
| `weekly_checkin_answered` | `surface`, `input_method`, `seconds_to_answer`, `day_of_window` |
| `weekly_checkin_skipped` | `surface` |
| `weekly_focus_day_completed` | `day_index`, `source` |
| `weekly_focus_escalated` | `need_bucket`, `carry_over_count` |
| `weekly_focus_paywall_shown` | `need_bucket`, `weeks_answered_free` |
| `weekly_focus_paywall_converted` | `need_bucket`, `weeks_answered_free` |

**Primary metric:** D28 retention among premium users, split by answered vs.
never-answered. If answering does not move D28, the feature is ceremony — and
that's worth learning in week three rather than month six.

**Secondary:** answer rate by surface (tells you whether the card or the
interstitial is doing the work), and week-completion rate by `source` (tells you
whether fallback weeks are as good as answered ones).

**Conversion:** free→premium rate off `weekly_focus_paywall_shown`, and whether
it climbs with `weeks_answered_free`. If a free user answering three Sundays in a
row converts materially better than one answering once, the free ask is earning
its place and the gate is in the right spot. If not, the ask should probably be
premium-only too.

---

## Edge cases

| Scenario | Behavior |
|---|---|
| Never answers, ever | Ladder builds every week. Push decays to monthly after 4 ignored. |
| Answers Monday 10 PM | Days 3–7 rebuilt. Days 1–2 stand. "Updated for the rest of your week." |
| Skipped onboarding entirely | No Anchor, no profile → ladder falls to behavioral, then declared categories |
| Notification permission denied | Card and interstitial still work. Push layer silently absent. |
| Timezone change mid-week | `weekStart` is stored absolute. Local notification re-anchors on next fire. |
| Same need 3 weeks running | Escalation path fires once |
| Marks Anchor "It Came to Pass" mid-week | Week continues unchanged. The two layers are independent. |
| Premium lapses mid-week | Current week finishes. No new week after it. Card reverts to free experience. |
| Subscribes mid-week after answering free | Build the week immediately from the answer already captured. Don't make them re-answer. |
| RevenueCat unreachable | Fall back to client `isPremiumClaim` (`bibleChat.js:151-156`). Never lock out a payer. |
| Offline Sunday evening | Ladder is fully local. Answered path queues and retries; falls back to keyword matching on failure, mirroring `ClaudeDeclarationMatcher`. |
| App not opened for 3 weeks | Build only the current week on next launch. Don't backfill history. |

---

## Files to create / modify

| File | Action |
|---|---|
| `Models/WeeklyFocus.swift` | **Create** |
| `Services/WeeklyFocus/Protocols/` (3 files) | **Create** |
| `Services/WeeklyFocus/WeeklyFocusRepository.swift` | **Create** |
| `Services/WeeklyFocus/WeeklyFocusBuilder.swift` | **Create** |
| `Services/WeeklyFocus/WeeklyCheckInScheduler.swift` | **Create** |
| `Services/WeeklyFocus/WeeklyFocusContentSelector.swift` | **Create** |
| `Services/WeeklyFocus/UseCases/` (3 files) | **Create** |
| `ViewModels/WeeklyFocusViewModel.swift` | **Create** |
| `Views/WeeklyFocus/WeeklyCheckInSheet.swift` | **Create** — reuses the personal-declaration input flow |
| `Views/WeeklyFocus/WeeklyFocusCard.swift` | **Create** — the feed card |
| `Views/WeeklyFocus/WeekOverviewView.swift` | **Create** — the 7-day payoff screen |
| `functions/weeklyFocus.js` | **Create** — mirrors `bibleChat.js` |
| `App/DIContainer.swift` | **Modify** — wire the graph |
| `App/AppState.swift` | **Modify** — 2 properties |
| `App/SpeakLifeApp.swift` | **Modify** — `weeklyFocus` deep link case |
| `Views/Declaration View/` (home feed) | **Modify** — inject card, read `declarationIDs` |
| `Views/AudioDeclarationView/AudioDeclarationViewModel.swift` | **Modify** — add `audioCategoryRaw` as top-priority sort input |
| `Services/CoreData/SyncedSettingsStore.swift` | **Modify** — sync `weekly_focus_history_v1` |
| `functions/index.js` | **Modify** — export `weeklyFocus` |

---

## Phasing

**Phase 1 — the loop, no AI.** `WeeklyFocus` model, repository, builder with the
full fallback ladder, local Sunday notification, feed card, check-in sheet, week
overview, **and the premium gate plus paywall handoff**. Content selection is
keyword-based (reuse `KeywordDeclarationMatcher`) and pulls from
`declarationsv10.json`. Audio ordering wired.

The gate ships in Phase 1, not later — retrofitting an entitlement onto a feature
users already have free is a support problem, and the free/premium split changes
what the check-in sheet does on submit.

Shippable and measurable on its own. If the answer rate is near zero, that's the
answer, and no LLM work was spent finding out.

**Phase 2 — retrieval behind the proxy.** Move `ClaudeDeclarationMatcher` to the
Cloud Function, add `/weeklyFocus`, replace keyword selection with LLM selection.
Carry-over angle progression turns on here.

**Phase 3 — bucket devotionals.** Generated weekly devotional content keyed by
`(needBucket, weekOfYear)`, personalized framing line on top.

**Phase 4 — escalation + history.** The 3+ carry-over path, and the
"what you've been carrying" recap view.

---

## Open questions

1. **7:00 PM Sunday default** — worth deriving from `hitsHardest` (`night` users
   later, `morning` users earlier), or is a fixed evening slot better because the
   ask is about *planning*, not the pain itself? Leaning fixed.
2. **Bucket count.** ~20 is a guess. With lazy generation it no longer drives
   cost, so tune it purely on whether devotionals feel specific enough. Needs
   real answer text from Phase 1 to settle.
3. **Should free users get the ask at all?** Currently yes — they answer, get one
   verse back, and hit the paywall on the week. The bet is that speaking the need
   aloud makes the paywall convert better than a cold one. If
   `weekly_focus_paywall_shown` → conversion doesn't beat the baseline paywall,
   make the whole feature premium-only and drop the free ask.
