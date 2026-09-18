---
name: check-funnels
description: Query the live SpeakLife PostHog funnels (all-arm onboarding, onboarding → paid, activation, retention, subscriptions/LTV) and report conversion, drop-off and retention. Trigger when the user asks to check funnels, pull funnel numbers, see onboarding/activation/retention conversion, "how are the funnels doing", the weekly growth review, or any on-demand read of SpeakLife analytics funnel performance.
---

# Check SpeakLife Funnels

Pull the current numbers for SpeakLife's PostHog funnels and report conversion, where
users drop off, and whether they come back. The funnel **definitions** live in
`docs/ANALYTICS_FUNNELS.md`; read `docs/ANALYTICS_DATA_QUALITY.md` before quoting any
number. This skill is the on-demand **read**.

## Context

- PostHog project: **Default project**, id `455580`
- Primary dashboard: **SpeakLife — Weekly Growth Scorecard** — https://us.posthog.com/project/455580/dashboard/2102993
- Also: **SpeakLife Funnels** (1673390), **SpeakLife — Subscription Funnel** (1970853)

Saved insights, top of funnel to bottom:

| Area | Insight | short_id |
|---|---|---|
| Onboarding, all arms | All arms, one funnel: start → personalize → paywall → finish → subscribe (by variant) | `5SClykhs` |
| Onboarding, all arms | Screen-by-screen reach, every arm (SQL table) | `SK4dKteb` |
| Onboarding A/B | Winner by Variant: start → finish → subscription | `QfVRKZ3H` |
| Onboarding → paid | Onboarding → Paid Funnel (all arms, by variant) | `Q9Sw8t24` |
| Activation | Install → onboarding → activated (7 days) | `4IioMFuz` |
| Activation | Weekly install → activated rate | `tahiXWFQ` |
| Retention | New users: day 1 / 7 / 30 return rate | `7tBLazhG` |
| Retention | Return rate by onboarding variant | `px6AqUy0` |
| Retention | Trialists: days they open the app during the trial | `MlyO1cah` |
| Retention | Paid subscribers still renewing, by first-paid month | `5K3PjLql` |
| Retention | Weekly retention / Growth accounting / WAU | `46ADQGA1` / `bwsyON1G` / `wbnncFSZ` |
| Trial | App days in first 3 trial days vs trial → paid (SQL) | `eq48jypP` |
| Paid | New paid subscribers per week (target 88) | `SqtO31aa` |
| Paid | Gross subscription revenue per week (target ~$4.3K) | `X17LWcuv` |
| Paid | Install → paywall → trial → paid (matured cohorts) | `uPC6kA4K` |
| LTV | Revenue per install, by install week (SQL) | `10F1G7Sn` |
| LTV | Revenue per onboarding starter, channel × variant (SQL) | `Bxp3WHNl` |
| Subs | Active paid subscribers & renewing MRR estimate (SQL) | `zbMOZO9G` |
| Churn | Paid cancellations, billing failures & refunds per week | `AmPfyTdp` |
| Push | Notification open rate / opens by type | `TrqcHt4k` / `9VoacXiy` |

`[Legacy — quiz arm only] Onboarding Funnel (quiz flow)` (`JmNj0xoV`) only sees the
quiz arm. Do not report it as the onboarding funnel.

The PostHog MCP tools are namespaced `mcp__<server>__<tool>` (server id is a UUID that
can change between sessions). Find them with `ToolSearch` queries like
`select:...exec` or keyword `posthog`. If the PostHog MCP isn't connected, tell the
user to authorize it and stop.

## Steps

1. **Re-run the saved insights** with `insight-query` by short_id. Results for retention
   insights are large; dump to a file and summarize with `jq` rather than reading inline.
   Default read: `5SClykhs`, `Q9Sw8t24`, `4IioMFuz`, `7tBLazhG`, `SqtO31aa`, `10F1G7Sn`.
   Add the rest when the user asks about that area.
2. **Honor any date range the user gives.** Otherwise use the range saved on the insight.
3. **Report**:
   - Funnels: conversion % per step, overall conversion, the single biggest drop-off.
     For by-variant funnels, lead with the best and worst arm and their sample sizes.
   - Retention: day 1 and day 7 return rate, using only cohorts old enough to have that day.
   - Paid/LTV: this week vs target, and D30 revenue per install.
4. **Empty results are expected in two places**: `5SClykhs` and `SK4dKteb` run on
   `onboarding_step_viewed`, which only exists from the first release after 4.65.
   Say so plainly; it is not a wiring bug.

## Known caveats to state when relevant

- `acquisition_channel = owned_deeplink` with source `branch` and no campaign is mostly
  mis-attributed organic traffic on builds up to 4.65. Don't compare channels until the
  fix has shipped for a few weeks.
- RevenueCat (`rc_*`) history starts 2026-08-08, and ~20% of RC people don't link to an
  app user. PostHog MRR undercounts annual subscribers bought before Aug 8; RevenueCat's
  dashboard is the source of truth for totals.
- Retention runs on `app_day_started` (once per calendar day), never `$screen`.

## Output format

Short text per area (not a giant table dump). Lead with the number that changed most
week over week and the worst drop-off. Link the Weekly Growth Scorecard at the end.
