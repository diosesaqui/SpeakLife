---
name: check-funnels
description: Query the live SpeakLife PostHog funnels (Onboarding quiz flow + Activation→Trial) and report conversion rates and drop-off. Trigger when the user asks to check funnels, pull funnel numbers, see onboarding/activation conversion, "how are the funnels doing", or any on-demand read of SpeakLife analytics funnel performance.
---

# Check SpeakLife Funnels

Pull the current numbers for SpeakLife's two PostHog funnels and report conversion +
where users drop off. The funnel **definitions** live in `docs/ANALYTICS_FUNNELS.md`;
this skill is the on-demand **read**.

## Context

- PostHog project: **Default project**, id `455580`
- Dashboard: **SpeakLife Funnels** — https://us.posthog.com/project/455580/dashboard/1673390
- Saved insights:
  - Onboarding Funnel (quiz flow) — short_id `JmNj0xoV` — https://us.posthog.com/project/455580/insights/JmNj0xoV
  - Activation → Paid Funnel — short_id `Q9Sw8t24` — https://us.posthog.com/project/455580/insights/Q9Sw8t24

The PostHog MCP tools are namespaced `mcp__<server>__<tool>` (server id is a UUID that
can change between sessions). Find them with `ToolSearch` queries like
`select:...insight-query` or keyword `posthog funnel`. If the PostHog MCP isn't
connected, tell the user to add it (see `docs/ANALYTICS_FUNNELS.md`) and stop.

## Steps

1. **Re-run the saved insights** (preferred — stays in sync with the dashboard). Load
   and call the `insight-query` tool with `short_id: JmNj0xoV`, then `short_id: Q9Sw8t24`.
   - If `insight-query` is unavailable, fall back to `query-funnel` with the series and
     settings below.
2. **Honor any date range the user gives** ("last 7 days", "this month"). Default to the
   range saved on the insight (last 90 days) otherwise. With `query-funnel`, pass
   `dateRange: { date_from: "-7d" }` etc.
3. **Report** per funnel:
   - Count + conversion % at each step.
   - Overall conversion (first step → last step).
   - The single biggest drop-off step (largest % loss between consecutive steps).
   - Median time to convert if the tool returns it.
4. **If a funnel returns "No data recorded"**, say so plainly and remind the user this is
   expected until a PostHog-enabled build ships and real users generate events (per the
   warning in `docs/ANALYTICS_FUNNELS.md`). Do not treat it as a wiring bug.

## Fallback funnel definitions (if re-running by short_id fails)

**Onboarding Funnel** — `funnelOrderType: ordered`, window **1 day**, ordered steps:
`onboarding_quiz_shown` → `onboarding_quiz_answered` → `onboarding_belief_shown` →
`onboarding_belief_spoken` → `onboarding_burden_answered` →
`onboarding_first_declaration_spoken` → `onboarding_personal_declaration_completed` →
`onboarding_completed` → `onboarding_notification_time_picked`
(`onboarding_completed` fires at the commitment-hold screen BEFORE the paywall;
`onboarding_notification_time_picked` fires post-paywall, so it is the true last step.)

**Activation → Paid Funnel** — `funnelOrderType: ordered`, window **30 days**, ordered steps:
`onboarding_completed` → `paywall_impression` → `trial_started` → `rc_trial_converted_event`
(Steps 1–3 are in-app events; step 4 is RevenueCat's server-side PostHog integration. Identity
joins via the `$posthogUserId` RC attribute set in AnalyticsService.setUserId. No `screen_viewed`
or `paywall_conversion` step — both would mis-order or double-count. If `rc_trial_converted_event`
reads zero, check the RC→PostHog integration is enabled, not just that no build shipped.)

## Output format

Give a short text summary per funnel (not a giant table dump). Lead with overall
conversion and the worst drop-off — that's what the user wants first. Link the dashboard
at the end.
