---
name: onboarding-ab-ranking
description: Query PostHog for the onboarding A/B funnel and rank the variants (product / identity / quiz / survey) to pick a winner. Use when asked which onboarding is winning, onboarding A/B results, onboarding funnel rankings, or "which onboarding should we ship".
---

# Onboarding A/B Ranking

Pull the live onboarding A/B funnel from PostHog and tell the user which onboarding
variant is winning, with the numbers behind it.

## Context

- The app shows one of four onboarding flows, chosen by Remote Config
  `onboardingVariant`: `product`, `identity`, `quiz`, `survey`.
- Every flow fires a unified, variant-tagged funnel (added in app **v4.27+**):
  1. `onboarding_started`  — entered onboarding `{ variant }`
  2. `onboarding_finished` — completed onboarding `{ variant, converted, conversion_type }`
  3. `subscription_started` — started a trial or paid sub `{ variant, is_trial }`
- `conversion_type` on `onboarding_finished` is `trial` | `purchase` | `none`.
- Saved PostHog insight: **Onboarding A/B — Winner by Variant**, short_id `QfVRKZ3H`,
  on the **SpeakLife Funnels** dashboard (id `1673390`), project `455580`.
- Source of truth in the repo: `docs/ANALYTICS_FUNNELS.md` (section 3).

## How to run it

Use the **PostHog MCP** (`exec` tool). Follow its required workflow — `info` before
every `call`, and `read-data-schema` to confirm events exist.

1. **Confirm the events exist** (they only appear once a v4.27+ build is live):
   `call read-data-schema {"query": {"kind": "events"}}` and check for
   `onboarding_started`, `onboarding_finished`, `subscription_started`.
   If they are absent, STOP and tell the user the funnel has no data yet because no
   v4.27+ build has reported events — do not query guessed names.

2. **Run the funnel, broken down by variant.** Prefer a fresh `query-funnel` so you
   control the window; `info query-funnel` first, then:
   ```json
   {
     "kind": "FunnelsQuery",
     "series": [
       { "kind": "EventsNode", "event": "onboarding_started" },
       { "kind": "EventsNode", "event": "onboarding_finished" },
       { "kind": "EventsNode", "event": "subscription_started" }
     ],
     "breakdownFilter": { "breakdown_type": "event", "breakdown": "variant" },
     "dateRange": { "date_from": "-30d" },
     "funnelsFilter": { "funnelOrderType": "ordered", "funnelWindowInterval": 14, "funnelWindowIntervalUnit": "day" }
   }
   ```
   Adjust `date_from` to the experiment window if the user gives one.
   (Equivalent saved insight: `call insight-query {"short_id": "QfVRKZ3H"}`.)

3. **Optional — trial vs paid mix.** `query-trends` on `onboarding_finished`,
   breakdown by `conversion_type`, filtered or split by `variant`, to see how each
   arm's conversions split between trial and outright purchase.

## How to interpret + rank

For each variant compute, from the funnel:

- **Starts** = `onboarding_started` count (the arm's sample size).
- **Completion %** = `onboarding_finished` / `onboarding_started`.
- **Conversion %** = `subscription_started` / `onboarding_started`  ← **primary ranking metric**.

Then:

1. Rank variants by **Conversion %** (highest = winner). Use Completion % as the
   tie-breaker and as color on *why* an arm wins or loses (great completion but weak
   conversion = the flow engages but the paywall/positioning underperforms).
2. **Confidence guardrails — do NOT crown a winner when:**
   - any arm has **< ~100 starts**, or **< ~25 conversions**, or
   - the gap between #1 and #2 is small relative to the counts (rough rule: if the
     leader's conversion-count lead is within roughly the square root of the
     conversions, treat it as noise).
   In those cases say "no statistically meaningful winner yet — keep running," and
   for a real significance test point them at Firebase A/B Testing or a PostHog
   Experiment on `onboardingVariant`.
3. Note any arm that isn't receiving traffic (0 starts) — usually means the Remote
   Config split isn't routing to it.

## Output format

Keep it tight:

- A ranked table: `Variant | Starts | Completion % | Conversion % | Trial:Paid` (drop
  the last column if step 3 wasn't run).
- One line naming the winner **with the confidence caveat**, or stating that it's too
  early.
- One line of *why* (e.g. "identity converts best despite lower completion — the
  emotional framing sells the paywall harder").
- Link the insight: https://us.posthog.com/project/455580/insights/QfVRKZ3H
