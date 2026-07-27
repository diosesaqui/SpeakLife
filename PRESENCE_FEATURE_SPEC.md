# The Secret Place — Presence Feature Spec
### "Enter His presence before you enter your day"
**Version:** 1.0 — Scoping / PRD
**Status:** Ready for founder decision, then development
**Author:** SpeakLife AI Chief of Staff

---

## The Question This Doc Answers

Creed shipped "Faith Lock" — it blocks your distracting apps until you complete a
daily prayer goal. Should SpeakLife build the same thing for entering God's
presence, and should it be **a daily task** or **a timed gate before you can do
anything**?

**Recommendation: build the timed session as the product, surface it as a daily
task, and make the gate opt-in — never a hard lock on our own app.**

Three separate things are being conflated in the original question. Splitting
them is the whole decision:

| | What it is | Verdict |
|---|---|---|
| **The session** | A timed, guided experience where you actually sit with God | **This is the feature.** Build it first, build it beautifully. |
| **The task** | A row in the existing daily checklist that opens the session | **Yes — nearly free.** The checklist infra already exists. |
| **The gate** | Something stands between the user and the rest of the app/phone | **Opt-in only.** Soft interstitial in Phase 2, app-blocking in Phase 3. |

### Why not a hard gate (the Creed copy)

Creed's Faith Lock blocks **other** apps — Instagram, TikTok, X. It taxes the
distraction and rewards the faith app. That works.

Locking a user out of **SpeakLife's own** declarations, audio, and devotional
until they finish a timer inverts the mechanic: it taxes the thing we want them
to do. A user who opens the app at 6:47am for one declaration before a meeting
and hits a mandatory 5-minute wall does not enter rest. They feel resented, they
tap "skip," and if there is no skip they close the app. We would be spending our
best asset — intent — to enforce a ritual.

There is also a theological point that matters for this brand specifically:
God's presence is not a toll booth. The moment it becomes a requirement to
unlock content, we have taught the user that presence is a transaction. That is
the opposite of what this feature exists to produce.

**The gate belongs on the distraction, not on the Word.** That is Phase 3.

### Why not "just a checklist item"

A row that says "Pray — 5 min ☐" with a checkbox is a to-do, and it will be
tapped-to-complete without ever being done. Rest, healing, and hearing His voice
are not accomplished by a checkbox — they are accomplished by **time held open**.
The timer is not gamification here; it is the mechanism. It is what makes the
user stay still long enough for something to happen.

So: the task is the doorway, the session is the room.

---

## The Feature

**Name:** The Secret Place (Psalm 91:1 — *"He who dwells in the secret place of
the Most High shall abide under the shadow of the Almighty."*)
**In-app label:** Presence

A timed, guided, sensory session where the user stops and receives from God.
Not teaching. Not a devotional to read. Not declarations to speak. **Receiving.**
This is the one place in SpeakLife where the user's mouth is closed and their
hands are open.

### Session anatomy (5-minute default)

| Beat | Time | What happens |
|---|---|---|
| **Arrival** | 0:00–0:30 | Screen dims to near-black. Ambient bed fades in. Slow breath pacer (4-in, 6-out). One line: *"Be still, and know that I am God."* |
| **Stillness** | 0:30–2:00 | No voice. Ambient only. A single promise fades onto the screen and holds. The user is doing nothing on purpose. |
| **Receiving** | 2:00–4:00 | Soft-spoken voice delivers 3–4 short first-person promises with long silences between. *"I am your rest."* … *"I am healing you."* |
| **Close** | 4:00–5:00 | A benediction. Ring completes. Optional single-line capture: **"What did He say to you?"** → saves to journal. |

The silences are the product. Resist the urge to fill them.

### Modes at launch (3, not more)

| Mode | Anchor | For |
|---|---|---|
| **Rest** | Matthew 11:28, Psalm 23 | The default. Exhaustion, striving, noise. |
| **Healing** | Psalm 103, Isaiah 53:5 | Sitting under His healing power in the body. |
| **His Voice** | John 10:27, 1 Kings 19:12 | Hearing Him. Longest silences of the three. |

Durations: **2 / 5 / 10 / 15 min.** Default 5. The 2-minute exists so a busy
morning still counts — it protects the streak and the habit.

### The stat we own

**Hours in His presence — lifetime.**

Not a streak. Not a badge count. A number that only goes up, that no other app
in this category shows, and that means something the first time a user sees
"You have spent 12 hours in His presence this year." Surface it on the profile
and in Year In Review.

---

## Placement & The Opt-In Gate

### Phase 1 placement — the daily task (ship first)

Add one task to the existing checklist. This is the doorway.

- Title: **"Enter His Presence"**
- Description: *"Be still. Let Him speak."*
- `estimatedMinutes: 5`, `category: .foundation`, `type: .reflect`
- New `TaskNavigationDestination.presence`

Placed **first** in the foundation list, above `complete_daily_burst` — the
visual order teaches the theology: receive before you declare.

### Phase 2 placement — "Presence First" (the soft gate)

A settings toggle, **off by default**, and offered once via a one-time prompt
after the user's 3rd completed session (i.e. only to people who already like it):

> **Start every day in His presence?**
> We'll bring you here first each morning before anything else.
> *[Yes, take me here first] [No thanks]*

When on, the first app open of each day routes into a Presence session before
the home tab. **It always has a "Not now" in the corner.** The escape hatch is
non-negotiable — it is what makes this a ritual the user chose rather than a
lock they resent.

Ship this behind an A/B (`presence_first_enabled`) and read D7/D30 retention and
burst-completion rate before defaulting it on for anyone.

### Phase 3 — Faith Lock (the real gate, on the real problem)

Block **distracting apps** — Instagram, TikTok, X, YouTube — until today's
Presence session is complete. This is the Creed mechanic pointed at the right
target.

This is a **separate bet with a hard external dependency** and should not be
bundled into the Phase 1/2 timeline:

- Requires the **Family Controls** entitlement from Apple. `SpeakLife.entitlements`
  does not have it. The request is a written justification form, takes weeks,
  and **can be denied**.
- Requires two new app extensions: a `DeviceActivityMonitor` extension and a
  `ShieldConfiguration` extension, plus shared state through the existing app
  group (`group.com.Franchiz.SpeakLife` — already configured, good).
- Screen Time authorization prompt is scary (see screenshot 4 — Creed's own
  prompt defaults the user's eye to "Don't Allow"). Expect meaningful drop-off
  and place the ask *after* value, never in onboarding.

**Action now:** if we want this at all, file the Family Controls entitlement
request this week so the approval clock runs in parallel with Phase 1. Nothing
else in Phase 3 is blocked on us.

This is also the strongest premium hook in the whole feature.

---

## Technical Scope

### New files

```
SpeakLife/SpeakLife/Models/PresenceSession.swift
    PresenceMode (rest/healing/hisVoice), PresenceScript (beats + timings),
    PresenceSessionRecord (mode, duration, completedAt, capturedWord)

SpeakLife/SpeakLife/Views/Presence/PresenceSessionView.swift
    Full-screen, dark, breath pacer, promise cards, completion ring

SpeakLife/SpeakLife/Views/Presence/PresenceSessionViewModel.swift
    Session lifecycle, wall-clock elapsed, audio coordination

SpeakLife/SpeakLife/Views/Presence/PresenceEntryView.swift
    Mode + duration picker (3 modes, 4 durations, one screen)

SpeakLife/SpeakLife/Views/Presence/PresenceCompletionView.swift
    Benediction, lifetime-hours counter, "What did He say?" capture

SpeakLife/SpeakLife/Services/PresenceSessionStore.swift
    Persistence + lifetime minutes; mirrors existing sync patterns
```

### Files touched

| File | Change |
|---|---|
| `Views/Declaration View/Streak/DailyChecklistModels.swift` | Add `.presence` to `TaskNavigationDestination`; add `enter_his_presence` to `TaskLibrary.foundationTasks` (first position) |
| `Views/Declaration View/Streak/EnhancedStreakViewModel.swift` | Handle completion of the new task |
| `Views/HomeView.swift` | Route `.presence`; reuse the existing `resources` ambient array (line 12) |
| `Views/ProfileView/…` | Lifetime hours row; Presence First toggle (Phase 2) |
| `Services/PaywallTriggerManager.swift` | Trigger after a premium mode/duration is tapped |
| `Views/Declaration View/Streak/TimerViewModel.swift` | **Leave alone.** See below. |

### Do not revive `TimerViewModel`

`TimerViewModel.swift` is a dead 10-minute timer — `loadRemainingTime()`,
`startTimer()`, the midnight observer, and the notification scheduler are all
commented out (lines 253–302, 362–388), and what remains is entangled with the
streak's `@AppStorage` keys. Reviving it would couple presence timing to streak
bookkeeping we do not want coupled. Build `PresenceSessionViewModel` fresh, and
delete `TimerViewModel` in a separate cleanup PR once nothing references it.

### The one hard technical requirement

**Compute elapsed time from wall-clock timestamps, not timer ticks.**

`TimerViewModel.runCountdownTimer()` decrements a counter on a `Timer` — that
stops firing the moment the app backgrounds or the screen locks. The entire
point of this feature is that the user puts the phone down and closes their
eyes. Store `startedAt: Date` and derive remaining time on every render and on
`didBecomeActive`.

Also required:
- `AVAudioSession` category `.playback` so audio survives screen lock
- Idle timer disabled during a session (`UIApplication.shared.isIdleTimerDisabled`)
- Session resumes correctly after a phone call or an interruption
- Haptic on each beat transition (`PremiumHaptics` already exists)

### Streak interaction — recommendation

`DailyChecklist.isStreakEarned` currently keys **only** off `complete_daily_burst`.
**Leave that alone at launch.** Do not let presence earn a streak day yet.

Reason: if presence earns the streak, the 2-minute session becomes the cheapest
path to protect a streak, and we will have built a feature whose most common use
is streak insurance. Ship it with its own metric (lifetime hours) and revisit
after we have 4 weeks of data on how it's actually used.

---

## Content Production (the real critical path)

This feature lives or dies on the audio. Engineering is ~3 weeks; **content is
the thing that will actually slip.**

Per mode × per duration, we need:
- A written script with **exact timing marks** for every silence
- A recorded voice track — soft, unhurried, close-mic, first-person as God
- A mixed ambient bed (start from `everpresent.mp3` / `washed.mp3`)

That is 3 modes × 4 durations = 12 sessions. **Cut this at launch to 3 modes ×
5 min, plus a 2-min Rest** = 4 recordings. Ship, then expand durations from
usage data.

Voice decision required from founder — see open questions.

---

## Success Metrics

Instrument via Firebase `Analytics.logEvent` (existing pattern) and mirror into
PostHog for funnels.

| Event | Properties |
|---|---|
| `presence_session_started` | mode, duration, entry_point (task / tab / presence_first / notification) |
| `presence_session_completed` | mode, duration, actual_seconds, captured_word (bool) |
| `presence_session_abandoned` | mode, duration, seconds_elapsed, beat |
| `presence_first_prompted` / `_enabled` / `_skipped` | — |
| `presence_paywall_triggered` | mode, duration |

**Targets, first 30 days after ship:**

- **Activation:** ≥ 35% of DAU complete ≥ 1 session in week 1
- **Depth:** ≥ 70% completion rate once started (abandonment above 30% means the
  silences are too long or the durations are wrong)
- **Retention:** D30 retention for presence-adopters ≥ +8pts vs non-adopters
- **Guardrail (the one that kills the gate):** daily burst completion rate and
  streak rate must **not drop**. If Presence First causes a drop in either, it
  stays off by default permanently.
- **Monetization:** trial-start rate from `presence_paywall_triggered` ≥ our
  current average paywall conversion

---

## Free vs Premium

Keep the free path genuinely good. This is a ministry surface before it is a
monetization surface, and a stingy free tier here reads as selling access to God.

**Free, unlimited, forever:** Rest mode, 2 and 5 minutes.
**Premium:** Healing + His Voice modes, 10 and 15-minute durations, the full
ambient pack, and (Phase 3) Faith Lock.

---

## Phasing

| Phase | Scope | Estimate |
|---|---|---|
| **0 — Content** | 4 scripts written, voiced, mixed. Runs in parallel with Phase 1. | 1–2 weeks (founder-gated) |
| **1 — The session** | Session engine, entry screen, completion, checklist task, lifetime hours, analytics | ~2 weeks eng |
| **2 — Presence First** | Opt-in soft gate, one-time prompt, A/B, presence notifications | ~1 week eng |
| **3 — Faith Lock** | Family Controls entitlement, DeviceActivity + Shield extensions, app-picker onboarding | 3+ weeks eng, **blocked on Apple approval** |

**File the Family Controls entitlement request now**, regardless of whether we
commit to Phase 3 — the approval clock is the long pole and costs us nothing to
start.

---

## Risks

| Risk | Mitigation |
|---|---|
| Apple denies Family Controls entitlement | Phase 3 is independently scoped; Phases 1–2 deliver the feature without it |
| Timer breaks when backgrounded | Wall-clock timestamps, not ticks (see above). Non-negotiable. |
| Presence First depresses core engagement | Ship behind A/B, off by default, always skippable, hard guardrail on burst completion |
| Content quality below bar | Cut scope to 4 recordings, not 12. Founder reviews audio before ship. |
| Feature becomes streak insurance | Presence does not earn a streak day at launch |
| Screen Time permission prompt scares users | Phase 3 only, asked after value, never in onboarding |

---

## Open Questions (founder decision needed)

1. **Whose voice?** Founder's own voice, Elizabeth (the locked AI host), or a
   third voice reserved for the presence surface? This is the single highest-
   leverage decision in the feature.
2. **First-person-as-God, or invitational?** *"I am your rest"* vs *"He is your
   rest."* First person hits harder and is consistent with the slideshow Jesus-
   voice format, but it is a stronger claim. Recommend first person.
3. **Do we want Phase 3 at all?** If yes, the entitlement request goes out this
   week.
4. **Confirm the free/premium line** above — specifically whether Healing should
   be free given how many users come to SpeakLife for healing.
