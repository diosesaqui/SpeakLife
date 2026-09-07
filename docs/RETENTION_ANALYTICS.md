# Retention Analytics — the weekly loop

How to measure retention in PostHog, and how to turn it into one decision a week.

Read `ANALYTICS_DATA_QUALITY.md` first. Several of the traps below are the same
ones that make other queries silently wrong.

The instrumentation this needs already exists (the weekly-decision metric set,
2026-08-22). What was missing is a defined set of insights, a cohort to read them
against, and a ritual that ends in a decision instead of a number.

---

## 0. The one rule that makes retention measurable

**Retention is `app_day_started`, never `Application Opened`.**

`Application Opened` is SDK autocapture. It fires on every foreground, so it
measures app switching. `app_day_started` fires exactly once per calendar day
and carries `days_since_last_open`, `is_resurrected`, `current_streak` and
`is_first_ever_day` (`GrowthMetrics.trackDayStarted`). Every insight below is
built on it.

Two filters belong on **every** retention query, always:

```
properties.$app_version IN (…current builds…)   -- Rule 1
NOT properties.is_simulator                     -- Rule 3: 88% of some events
```

---

## 1. The four insights

Four, not twenty. Each one answers a question that changes what you build next
week. Anything that does not change a decision does not go on the dashboard.

### A. The retention curve — *are we keeping anyone?*

PostHog **Retention** insight (not a funnel — retention is a cohort question).

- Cohortizing event: `app_day_started` where `is_first_ever_day = true`
- Returning event: `app_day_started`
- Period: **weekly**, 8 periods
- Breakdown: person property `onboarding_variant`

```json
{
  "kind": "RetentionQuery",
  "retentionFilter": {
    "targetEntity": { "id": "app_day_started", "type": "events" },
    "returningEntity": { "id": "app_day_started", "type": "events" },
    "retentionType": "retention_first_time",
    "period": "Week",
    "totalIntervals": 8
  },
  "breakdownFilter": { "breakdown_type": "person", "breakdown": "onboarding_variant" }
}
```

Read **W1 → W2** as the headline number. W1→W2 is where a habit either formed or
did not; everything after it is mostly decided there. Do not chase D1 — a devotional
app can win D1 on a push notification and still churn everyone by day 10.

### B. The habit funnel — *where does the new user fall out?*

PostHog **Funnel**, 14-day window, ordered. This is the funnel to build, and it
starts *after* the paywall — the pre-paywall funnels already exist (see
`ANALYTICS_FUNNELS.md` §1–3).

| # | Event | Meaning |
|---|---|---|
| 1 | `onboarding_finished` | Finished onboarding |
| 2 | `user_activated` | Did one real thing (spoke, listened, chatted, completed a task) |
| 3 | `app_day_started` where `days_since_install >= 1` | Came back a second day |
| 4 | `app_day_started` where `current_streak >= 3` | Three days in a row |
| 5 | `app_day_started` where `current_streak >= 7` | The week-one habit |

Breakdown by person property `onboarding_variant`, and for ad traffic by
`onboarding_segment` (mirrored to the person as of this doc — see §4).

Step 4 → 5 is the honest measure of whether the product forms a habit. Steps
1 → 2 is the measure of whether onboarding pointed at something worth doing.

### C. Breadth vs retention — *what should we push them toward?*

The most actionable insight on the board, because it names the intervention.

Cohort A: people with person property `features_used_count >= 3`
Cohort B: people with `features_used_count = 1`

Run insight A (the retention curve) for each cohort. If A retains materially
better — it does in nearly every app — then **week-one breadth is the lever**,
and the work is getting the second and third feature in front of people in the
first three days: the checklist, the audio, the chat.

Supporting cut: `feature_first_used` broken down by `feature`, filtered to
`days_since_install <= 7`, tells you which second feature people actually reach
for. Push the one they already choose, not the one you wish they chose.

### D. Resurrection and push — *does the notification programme work?*

- Trends on `app_day_started` where `is_resurrected = true`, weekly.
- Trends on `notification_opened` broken down by `type`.
- Funnel: `notification_opened` → `app_day_started` (same day, 1-day window).

This is the only lever that reaches people who already left. Kill any push type
whose open rate does not clear the others; the send budget is attention you do
not get back.

> **Caveat that limits D.** Only opens are instrumented, never *deliveries*, so
> open rate has no true denominator (`lifecycle_notifications_scheduled` counts
> scheduling, not delivery). Compare push types against each other, never against
> an absolute bar.

---

## 2. Assemble it as one dashboard

Name it **Retention — weekly**. Four insights, in the order above, plus two
number tiles that give the week its headline:

1. `app_day_started` where `is_first_ever_day = true`, weekly — new users
2. Weekly active people on `app_day_started` — the base everything else moves

Set the dashboard's date range to **last 8 weeks** and leave it there. Retention
read on a 7-day window is noise; the eye needs the shape of the curve, not this
week's point.

---

## 3. The weekly ritual

Fifteen minutes, same time every week, and it ends in **one** decision. The
failure mode is not lack of data — it is reading ten numbers and changing
nothing.

1. **Read the W1→W2 number first, before anything else.** Compare it to the
   trailing 4-week average, not to last week. A single week moves on cohort size.
2. **If it moved, find which arm moved it** (breakdown by `onboarding_variant`).
   Arms are targeted for ad traffic and random for organic, so never rank them
   against each other — read each arm against its own history (see
   `AD_ONBOARDING_ROUTING.md`).
3. **Walk the habit funnel and find the biggest single drop.** That step is the
   week's problem. Not the three smaller ones.
4. **Write the decision down** — one sentence, in the log below, with the number
   that prompted it and what you expect it to do.
5. **Next week, check whether the last decision did what you said it would.**
   That step is the one that compounds; skipping it is how teams ship for a year
   and learn nothing.

### The decision table

Each shape has a pre-committed response, so the week is not spent re-arguing
what to do.

| What the numbers show | What it means | The move |
|---|---|---|
| Step 1→2 low (finished onboarding, never activated) | Onboarding sold something the first session did not deliver | Cut steps between the paywall and the first spoken declaration |
| Step 2→3 low (activated, never came back) | No reason to return tomorrow | Push timing and copy; the day-2 notification is the whole game |
| Step 3→4 low (came back once, no streak) | The daily loop is too heavy or too shallow | Look at the checklist: 77% of user-days complete zero tasks, three tasks carry the feed |
| Step 4→5 healthy, trial→paid weak | Habit forms, value does not feel worth paying for | Paywall timing and framing, not retention work |
| Breadth cohort gap is large | Second feature is the lever | Surface feature #2 in the first 3 days |
| Resurrection flat while pushes rise | Sends are not earning attention | Cut the worst push type before adding another |

### Decision log

Append one row a week. Keep it in this file — the value is in reading it back
six months later.

| Week | Number that moved | Decision | Expected effect | Did it? |
|---|---|---|---|---|
| | | | | |

---

## 4. Instrumentation gaps that still limit this

- **`onboarding_segment` is now a person property** (`AppState.setOnboardingSegment`),
  so retention and RevenueCat revenue can finally be cut by the ad angle a person
  walked in on (`healing_diagnosis` vs `healing_loved_one`). **It only exists from
  the build that ships this change forward** — cohort on `install_date` when
  comparing, exactly as with the acquisition properties.
- **`trial_activated` never fires.** `AnalyticsService.trackTrialActivated` has no
  call sites, so the documented Activation→Trial step 5 dead-ends. Use RevenueCat's
  `rc_trial_converted_event` for trial→paid until it is wired.
- **Notification delivery is not instrumented** — see the caveat in §1D.
- **`rc_*` history starts 2026-08-08**, and revenue before the identity fix is
  orphaned from behaviour. Any retention-vs-revenue cut is on new data only.

---

## 5. Running these with an assistant

The insights above can be created and queried through the PostHog MCP rather than
by hand:

```
claude mcp add --transport http posthog https://mcp.posthog.com/mcp \
  --header "Authorization: Bearer phx_YOUR_PERSONAL_API_KEY"
```

The `phx_…` personal key is a server-side secret — never ship it in the app; the
app carries the `phc_…` project key only.

Two skills already read the funnels this way (`check-funnels`,
`onboarding-ab-ranking`). A third for this loop would pull the four insights,
apply §3, and draft the decision-log row.
