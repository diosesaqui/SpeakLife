# AI Personalization — Implementation Plan

Consolidated task list for the work discussed across the onboarding-pain /
AI-content sessions. Covers four workstreams: securing the Anthropic key,
capturing the onboarding data we already collect and discard, the quick AI wins
that data unlocks, and the Weekly Focus feature.

Detail for Weekly Focus lives in `WEEKLY_FOCUS_SPEC.md` (repo root).

**Sizing** is relative, not calendar time: **S** = hours, **M** = a day or two,
**L** = multi-day.

---

## Critical path

```
B (data capture)  ──┬──▶  C1 (Bible Chat context)     ── S, immediate payoff
                    ├──▶  D  (Weekly Focus Phase 1)   ── the big build
                    └──▶  G  (personalized push)

A (key proxy)     ──────▶  E, F, and any new generation path
```

**A and B are independent** and touch different files — they can run in parallel.
Everything with an LLM call in it waits on A.

---

## A. Secure the Anthropic key  *(blocks all new generation)*

The key is fetched from Remote Config at runtime and used for a direct
device→Anthropic call. Fetching beats compiling it in — rotation without a
release, no strings-dump exposure — but the usable key still lands on the device
(Remote Config caches to disk; `AnthropicConfig.apiKey` is a static var readable
via debugger or MITM) with no rate limit or spend cap behind it.
`functions/bibleChat.js:5-9` already documents this rationale.

- [ ] **[upkeep] Spend cap on the current Anthropic key** — interim blast-radius
      bound while the migration ships. Console-only, no code. **S**
- [ ] **[bug] Remove key-prefix console print** — `ClaudeDeclarationMatcher.swift:32`. **S**
- [ ] **[bug] Stop forwarding Anthropic error bodies to Firebase Analytics** —
      `ClaudeDeclarationMatcher.swift:74` ships 100 chars of the error body,
      which can echo request metadata. **S**
- [ ] **[feature] Create `functions/declarationMatch.js`** — mirrors
      `bibleChat.js`: key in Secret Manager, `cache_control` on the system
      prompt, Firestore metering. Separate file from `bibleChat`, not a mode
      flag — the two need different abuse controls. **M**
- [ ] **[feature] Per-`appUserId` rate limit on `declarationMatch`** — the
      matcher runs during onboarding *before purchase*, so every caller is free
      by definition and `bibleChat`'s entitlement + free-message-cap model does
      not transfer. ~5/day bounds an extracted endpoint. **S**
- [ ] **[feature] Move the full CLAUDE.md declaration rules + the `bibleChat.js`
      safety block into the server prompt** — the current
      `AnthropicConfig.systemPrompt` is missing rules 11–15 (emotional
      resonance, call higher, brevity, speak it like Jesus, perfectly clear) and
      has no safety block at all. **S**
- [ ] **[feature] Export `declarationMatch` from `functions/index.js`** **S**
- [ ] **[feature] Migrate `ClaudeDeclarationMatcher` to the endpoint** — drop
      `x-api-key` / `anthropic-version`, send `{ appUserId, input }`. Keep
      `extractJSON`, the `DeclarationJSON` decode, the `KeywordDeclarationMatcher`
      fallback, and the existing analytics. **M**
- [ ] **[feature] Delete `AnthropicConfig.apiKey` and `.systemPrompt`** — and the
      Remote Config read at `SubscriptionStore.swift:493`. **S**
- [ ] **[release] Blank Remote Config `anthropic_api_key`, THEN rotate the key** —
      order matters. Blanking first makes old builds hit the existing empty-key
      guard and degrade cleanly to keyword matching. Rotating first just hands
      old clients a working new key. **S**
- [ ] **[upkeep] Update the rotation runbook** — `BibleChat-Runbook.html:149-166`
      documents two keys that must be rotated together; after this there is one. **S**

**Later, only if the endpoint sees abuse:** App Attest / DeviceCheck. It protects
the endpoint, not a key, so it belongs on top of the proxy, never instead of it.

---

## B. Capture what onboarding already collects  *(no AI, unblocks everything)*

Onboarding persist is lossy by design: `HeaviestBurden` (7) → `SurveyGoalWord`
(7) → one `DeclarationCategory`. These fields are collected, emitted as analytics
parameters, and dropped app-side:

`battleDuration` · `alreadyTried` · `hitsHardest` · `connectStyle` ·
`dailyMinutes` · `victoryOutcome` · `beliefLevel` · `barriers` ·
`burdenDuration` · `declarationExperience` · `wantsCloser` · `hasDrifted` ·
**all 6 belief-question answers** (each carrying an `isConfident: Bool`)

- [ ] **[feature] `SoulProfile` model** — one Codable struct holding every field
      above plus burden, goalWord, and the Anchor's `beliefText`. **M**
- [ ] **[feature] Persist `SoulProfile`** — UserDefaults, mirrored to Firestore
      under the RevenueCat `appUserId` already sent to `bibleChat`. **M**
- [ ] **[feature] Add `SoulProfile` to `SyncedSettingsStore`** — follows the user
      across devices like `personal_declaration_v1` does. **S**
- [ ] **[feature] Write it from all 7 variants** — each runs an identical
      `applyResponsesAndComplete()`; extend rather than duplicate. **M**
- [ ] **[feature] Wire `hitsHardest` → notification scheduling** — options are
      `night` "3am wake-ups and racing thoughts" / `morning` / `midday` /
      `evening`. The user tells us when they hurt, we discard it, then ask them
      separately to pick a notification time. **Zero AI, likely the fastest
      retention win on this list.** **M**
- [ ] **[bug] `personalDeclarationBelief` is in-memory only** —
      `UserPreferencesTracker.swift:105`. The warmest paywall personalization
      silently degrades to generic copy after any app relaunch. The raw text does
      survive in `personal_declaration_v1`; nothing reads `beliefText` back into
      the tracker. **S**
- [ ] **[bug] `IdentityOnboardingView` never writes `onboardingSegment`** — every
      other variant has the block. That arm is invisible to segment-based paywall
      copy. **S**
- [ ] **[upkeep] Decide on `barriers`** — the only multi-select pain field, with
      the most specific copy in the model ("I read the Bible, but it stays in my
      head, not my heart"), unreachable in all 7 live variants. Surface it or
      delete the dead model. **S**

---

## C. Quick AI wins  *(needs B; C1 also needs nothing from A)*

- [ ] **[feature] Inject `SoulProfile` into Bible Chat** — as a **second,
      uncached** system block. Keep the large prompt in the cached block or the
      ~90% cache discount at `bibleChat.js:180` is destroyed. Two sentences of
      context and the chat stops meeting a stranger. **Cheapest real improvement
      on this list.** **S**
- [ ] **[feature] AI-curated 30-day declaration arc** — one call at onboarding
      selects and sequences ~30 declarations from the 3,156 in
      `declarationsv10.json`. **Retrieval, not generation**: no hallucinated
      verses, no doctrinal risk, every line already passes the CLAUDE.md rules.
      Store IDs; the feed reads them instead of the flat category union at
      `DeclarationViewModel.swift:675`. **M** *(needs A)*

---

## D. Weekly Focus — Phase 1  *(no AI; full detail in `WEEKLY_FOCUS_SPEC.md`)*

Sunday check-in whose answer shapes the week. Ships with keyword-based selection
so the answer rate can be measured before any LLM work is spent.

- [ ] **[feature] `Models/WeeklyFocus.swift`** — includes `WeeklyFocusSource`,
      `WeeklyFocusAngle`, `carryOverCount`. **S**
- [ ] **[feature] `WeeklyFocusRepository`** — array of the last 12 weeks under
      `weekly_focus_history_v1`, not a single record. History is what makes the
      year-end recap possible later. **M**
- [ ] **[feature] `WeeklyFocusBuilder`** — the fallback ladder: carry-over →
      anchor → profile → behavioral → declared categories. **L**
- [ ] **[feature] Carry-over angle progression** — promise → identity →
      authority, so an unanswered week 2 is a different angle rather than a
      reshuffle. **M**
- [ ] **[feature] `WeeklyCheckInScheduler`** — local
      `UNCalendarNotificationTrigger`, `weekday = 1`. No cron, no timezone
      fan-out. **S**
- [ ] **[feature] `WeeklyFocusContentSelector`** — keyword-based for Phase 1,
      reusing `KeywordDeclarationMatcher` over `declarationsv10.json`. **M**
- [ ] **[feature] 3 use cases** — Build / Answer / CompleteDay. **M**
- [ ] **[feature] `WeeklyFocusViewModel`** **M**
- [ ] **[feature] `WeeklyCheckInSheet`** — reuses the personal-declaration
      mic → transcribe → match flow with weekly copy. **M**
- [ ] **[feature] `WeeklyFocusCard`** — pinned to the feed for the window. This
      is the real capture surface; push tap-through is single digits. **M**
- [ ] **[feature] `WeekOverviewView`** — the 7-day payoff screen. Must land
      immediately on submit or nobody answers twice. **M**
- [ ] **[feature] Premium gate + paywall handoff** — gate goes *after* the
      answer. Free users answer, get one keyword-matched verse back, and hit the
      paywall on "here's your week". Free path costs zero LLM calls. **Ships in
      Phase 1** — retrofitting an entitlement onto a shipped free feature is a
      support problem. **M**
- [ ] **[feature] `AppState`** — `presentWeeklyCheckIn`, `weeklyFocusEnabled`. **S**
- [ ] **[feature] `weeklyFocus` deep link** — `SpeakLifeApp.handleNotificationContent()`,
      alongside the existing `personalDeclaration` case. **S**
- [ ] **[feature] Home feed** — inject the card, read `declarationIDs`. **M**
- [ ] **[feature] Audio ordering** — add `audioCategoryRaw` as top-priority input
      at `AudioDeclarationViewModel.swift:458-470`, which already reads
      `selectedNotificationCategories` + `PersonalDeclarationRepository.activeCategoryRaw()`.
      **Nearly free.** Curation from the existing library, not generated audio. **S**
- [ ] **[feature] `SyncedSettingsStore`** — sync `weekly_focus_history_v1`. **S**
- [ ] **[feature] `DIContainer`** — wire the graph. **S**
- [ ] **[feature] Analytics events** — the 9 events in the spec, including the
      paywall pair. **S**

---

## E. Weekly Focus — Phase 2+  *(needs A)*

- [ ] **[feature] `functions/weeklyFocus.js`** — mirrors `bibleChat.js`; returns
      `{ needsPaywall: true }` before any model work for non-premium. **M**
- [ ] **[feature] Swap keyword selection → LLM retrieval** **M**
- [ ] **[feature] Bucket devotionals, generated lazily** — keyed by
      `(needBucket, weekOfYear)`, generated on first request. Gating to premium
      shrinks the population each bucket amortizes over, so scheduled generation
      would pay for unoccupied buckets. **L**
- [ ] **[feature] Escalation path** — 3+ carry-overs changes the question rather
      than regenerating a fourth identical week. **M**
- [ ] **[idea] "What you've been carrying" recap** — the payoff for keeping 12
      weeks of history. **M**

---

## F. Devotional personalization  *(separate from Weekly Focus; needs A)*

`DevotionalService` currently serves one devotional to everyone, matched by
month/day. No personalization at all.

- [ ] **[feature] Personalized intro + closing prayer on the static devotional** —
      ties today's devotional to their burden and their own words. Bucket-cached;
      only the line quoting them is per-user, and that's a local template. **M**
- [ ] **[idea] Fully generated devotional, premium** — from profile + day index.
      Day 3 and day 22 should not read the same. **L**

---

## G. Personalized notifications  *(needs B)*

- [ ] **[feature] Batch-generate 30 push bodies at onboarding** from the
      `SoulProfile`. One call, thirty touchpoints. *"Day 14. You said you wanted
      to sleep through the night. Here's what God says."* **M** *(needs A)*
- [ ] **[upkeep] Wire `AINotificationService.registerAINotifications`** — it has
      no callers today (`AINotificationService.swift:33-38`). **S**

---

## Risks to track

- **Verse hallucination.** Nothing validates generated verse references against a
  real Bible text — `DeclarationVerificationService` is speech-matching despite
  the name. A fabricated reference in a Christian app is a trust-killer. Every
  retrieval-based item above sidesteps this; anything that *generates* a verse
  needs a check first.
- **Bucket count.** ~20 is a guess. With lazy generation it no longer drives
  cost, so tune on whether devotionals feel specific enough, using real answer
  text from Phase 1.
- **Weekly ask fatigue.** Fifteen seconds, voice-first, one question, skippable,
  with an immediate visible payoff. Push decays to monthly after 4 ignored weeks.
- **Pre-existing, unrelated but worth verifying:** `LocalAPIClient.swift:24`
  defaults to `declarationsv9.json`, and no such file exists in
  `Preview Content/AffirmationData/`. A fresh install that fails the Remote
  Config fetch may fall through to an empty array. Worth confirming what's
  actually in the Copy Bundle Resources phase.

---

## Suggested order

1. **B** — data capture + the two bugs + `hitsHardest`. No AI, no dependencies,
   and `hitsHardest` alone may pay for the whole workstream.
2. **A** — in parallel with B; different files, no conflicts.
3. **C1** — Bible Chat context. Hours, immediately felt.
4. **D** — Weekly Focus Phase 1. Measure the answer rate before spending LLM work.
5. **C2 / E / F / G** — ordered by whatever D's numbers say is worth it.
