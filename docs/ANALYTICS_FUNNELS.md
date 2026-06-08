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
the chosen arm, so the four variants (`product` / `identity` / `quiz` /
`survey`, selected by Remote Config `onboardingVariant`) compare head-to-head.
These route through `AnalyticsService`, so PostHog and Firebase both receive them.

**PostHog insight:** [Onboarding A/B — Winner by Variant](https://us.posthog.com/project/455580/insights/QfVRKZ3H)

| # | Event | Meaning |
|---|-------|---------|
| 1 | `onboarding_started` | Entered onboarding (any variant) |
| 2 | `onboarding_finished` | Completed onboarding |
| 3 | `subscription_started` | Started a trial or paid sub |

**Breakdown:** event property `variant` (`product` / `identity` / `quiz` / `survey`).
**Funnel settings:** conversion window `14 days`, order `ordered`.

`onboarding_finished` also carries `converted` (bool) and `conversion_type`
(`trial` / `purchase` / `none`), so you can read completion and conversion mix
straight off step 2. `trial_started` and `subscription_started` carry `variant`
too, for revenue attribution per arm.

> Ships in app **v4.27+**. Until that build is live, this funnel reads zero.

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
