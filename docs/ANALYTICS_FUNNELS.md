# SpeakLife Analytics Funnels

Reference for the PostHog funnels built on SpeakLife's event stream.

All events flow through `AnalyticsService` (`Core/Analytics/AnalyticsService.swift`),
which fans every event out to all registered providers (Firebase, PostHog,
TikTok, Meta). To add a destination, implement `AnalyticsProvider` and call
`register(...)` in `registerDefaultProviders()`.

> ⚠️ Funnels only populate from events generated **after** a PostHog-enabled
> build ships. Until real users run that binary, the funnels read zero — this
> is expected, not a wiring problem.

---

## 1. Onboarding Funnel (quiz flow)

The live Treatment cohort (`useQuizOnboarding = true`) rendered by
`QuizOnboardingView`. Steps are ordered events; PostHog shows drop-off between
each.

| # | Event | Meaning |
|---|-------|---------|
| 1 | `onboarding_quiz_shown` | Entered onboarding |
| 2 | `onboarding_quiz_answered` | Answered the quiz |
| 3 | `onboarding_belief_shown` | Reached belief step |
| 4 | `onboarding_belief_spoken` | Spoke a belief declaration |
| 5 | `onboarding_burden_answered` | Shared their burden |
| 6 | `onboarding_first_declaration_spoken` | Spoke first declaration |
| 7 | `onboarding_personal_declaration_completed` | Got personalized declaration |
| 8 | `onboarding_notification_time_picked` | Set notification time |
| 9 | `onboarding_completed` | Finished onboarding |

**Funnel settings:** conversion window `1 day`, order `sequential`.

Other quiz events available for deeper analysis (not core funnel steps):
`onboarding_mirror_shown`, `onboarding_belief_answered`,
`onboarding_burden_shown`, `onboarding_first_declaration_shown`,
`onboarding_rating_step_shown`, `onboarding_notification_time_shown`,
`notification_permission` (carries `granted`/`denied` in properties).

---

## 2. Activation → Trial Funnel

From finishing onboarding through to a paid conversion.

| # | Event | Meaning |
|---|-------|---------|
| 1 | `onboarding_completed` | Finished onboarding |
| 2 | `screen_viewed` | Opened the app (first real screen) |
| 3 | `paywall_impression` | Saw the paywall |
| 4 | `trial_started` | Started a trial |
| 5 | `trial_activated` | Converted to paid |

**Funnel settings:** conversion window `7 days`, order `sequential`.

---

## 3. Onboarding A/B — Winner by Variant

The cross-variant experiment funnel. Every onboarding flow now fires a unified
`onboarding_started` → `onboarding_finished` pair from `HomeView`, tagged with
the chosen arm, so the variants (`product` / `identity` / `quiz` / `outcomes` /
`warfare` / `promises` / `closer`, selected by Remote Config `onboardingVariant`)
compare head-to-head. `warfare` is the default arm from app **v4.28+**.
These route through `AnalyticsService`, so PostHog and Firebase both receive them.

**PostHog insight:** [Onboarding A/B — Winner by Variant](https://us.posthog.com/project/455580/insights/QfVRKZ3H)

| # | Event | Meaning |
|---|-------|---------|
| 1 | `onboarding_started` | Entered onboarding (any variant) |
| 2 | `onboarding_finished` | Completed onboarding |
| 3 | `subscription_started` | Started a trial or paid sub |

**Breakdown:** event property `variant` (`product` / `identity` / `quiz` / `outcomes` / `warfare` / `promises` / `closer`). Dynamic, so new arms appear automatically.
**Funnel settings:** conversion window `14 days`, order `ordered`.

`onboarding_finished` also carries `converted` (bool) and `conversion_type`
(`trial` / `purchase` / `none`), so you can read completion and conversion mix
straight off step 2. `trial_started` and `subscription_started` carry `variant`
too, for revenue attribution per arm.

> Ships in app **v4.27+**. Until that build is live, this funnel reads zero.

### 3a. Warfare vs Product (head-to-head)

A focused cut of the same funnel for the planned **80/20 warfare-vs-product
holdout**: identical steps and breakdown, but filtered to `variant in [warfare,
product]` so the default arm and its control read side-by-side without the other
arms' noise.

**PostHog insight:** [Onboarding A/B — Warfare vs Product (head-to-head)](https://us.posthog.com/project/455580/insights/e1Gfs1SQ)

> Populates from app **v4.28+** (when `warfare` is the default); reads zero until
> warfare traffic lands.

### 3b. The `closer` arm (visual-system test)

`closer` is the first arm that changes the *look* rather than only the angle:
a flat SpeakLife-navy canvas with full-bleed cinematic hero art, a segmented progress bar,
full-width gold CTAs, two binary yes/no agreement screens in the front half, and
an "I'm In" pledge screen between the plan reveal and the paywall. The quiz and
the whole back-half are identical to `outcomes`, so a `closer` vs `outcomes` cut
isolates the visual system + nearness angle, not funnel depth.

Arm-specific events, useful for reading *where* it wins or loses:

| Event | Properties | Why it matters |
|-------|-----------|----------------|
| `closer_scene_shown` | `scene` (`storm` / `nearness` / `spoken`) | Front-half narrative reach |
| `closer_agreement_shown` | `question` (`longing` / `drift`) | Agreement-ladder reach |
| `closer_agreement_answered` | `question`, `answer` (`yes` / `no`) | Whether the ladder actually gets a yes |
| `closer_growth_shown` | — | Proof-curve screen reach |
| `closer_rhythm_shown` | — | Streak/reminder screen reach |
| `closer_picker_shown` | — | Seeding-picker reach |
| `closer_pledge_shown` / `closer_pledge_accepted` | `burden` | **Pledge take-rate — the arm's key novel step** |
| `closer_step_completed` | `step`, `flow_schema` | Per-step drop-off |
| `closer_onboarding_completed` | `wants_closer`, `has_drifted`, + the standard quiz fields | Completion + agreement mix |

The one number worth watching beyond conversion: `closer_pledge_accepted` /
`closer_pledge_shown`. If the pledge take-rate is high but paywall conversion is
not, the commitment beat is landing and the *price* is the blocker, not the flow.

#### The pledge cell (`closerPledgeEnabled`)

The pledge is the one element of this arm that could plausibly go **negative** —
it may convert through commitment-and-consistency, or it may discharge the
tension the paywall runs on by handing the user a sense of completion one screen
early. Rather than spend a whole extra variant on that question, it sits behind
Remote Config `closerPledgeEnabled` (default `true`). Set it to `false` to run
the no-pledge cell; the plan reveal then leads straight into the testimonial
wall.

`pledge_enabled` (bool) is stamped on `closer_onboarding_started`,
`closer_step_completed`, and `closer_onboarding_completed`, so **break any
`closer` funnel down by it** to read the two cells. It is stamped at funnel
entry, not at the pledge, so users who drop before reaching the pledge still
count into the right cell. The flag is frozen at the flow's first appearance, so
a realtime Remote Config activation cannot move a user between cells mid-run.

Split traffic within `closer` 50/50 to read it; leave it at the default if you
only want the arm-vs-arm result first.

### 3c. The storm opener (screen one, `outcomes` / `promises` / `closer`)

The App Store listing is **"SpeakLife: Pray Like Jesus — Victory Over Every
Storm."** Screen one of these three arms now answers that line directly ("Jesus
didn't ask the storm to calm down. He spoke to it.") so the listing reads as the
hook instead of an unexplained promise the user carries through the whole flow.

| Event | Properties | Why it matters |
|-------|-----------|----------------|
| `storm_opener_shown` | `flow` (`outcomes` / `promises` / `closer`) | Screen-one reach; the denominator for everything after it |

Because the opener is prepended as step 0, every step raw value in those three
arms shifted by one. **`flow_schema` was bumped on all three** — `outcomes` 3→4,
`promises` 2→3, `closer` 1→2 — so filter any per-step funnel to the new schema
before comparing step numbers across builds. Pre-bump data is not comparable
step-for-step.

---

## Key event reference

These route through `AnalyticsService` and reach every provider:

| Event | Source method | Notable properties |
|-------|---------------|--------------------|
| `onboarding_started` | `AnalyticsService.track` (HomeView) | `variant` |
| `onboarding_finished` | `AnalyticsService.track` (HomeView) | `variant`, `converted`, `conversion_type` |
| `subscription_started` | `track` (SubscriptionStore.purchase) | `product_id`, `value`, `is_trial`, `variant` |
| `screen_viewed` | `trackScreenView` | `screen_name`, `previous_screen` |
| `paywall_impression` | `trackPaywallImpression` | `paywall_id` |
| `paywall_conversion` | `trackPaywallConversion` | `product_id`, `price` |
| `trial_started` | `trackTrialStarted` / `track` (purchase) | `product_id`, `value`, `variant` |
| `trial_activated` | `trackTrialActivated` | `product_id`, `price` |
| `subscription_renewal` | `trackSubscriptionRenewal` | `product_id`, `price` |
| `subscription_cancelled` | `trackSubscriptionCancelled` | `product_id` |
| `content_interaction` | `trackContentInteraction` | `content_type`, `content_id`, `action` |
| `audio_playback` | `trackAudioPlayback` | `audio_id`, `action` |
| `conversion` | `trackConversion` | `conversion_event`, `value` |

User identity is attached at sign-in via `setUserId(firebaseUid)` (see
`FirebaseAuthService` and `AppleSignInService`), with `auth_method` set to
`email` or `apple`.

---

## Creating these in PostHog

**Manually:** Product Analytics → New Funnel → add the events above in order.

**Via the PostHog MCP** (lets an assistant build/query them): add the server,
then ask it to create the funnels.

```
claude mcp add --transport http posthog https://mcp.posthog.com/mcp \
  --header "Authorization: Bearer phx_YOUR_PERSONAL_API_KEY"
```

The `phc_…` project key goes in the app (`PostHogAnalyticsProvider`); the
`phx_…` personal key is a server-side secret for the MCP / query API only —
never ship it in the app.
