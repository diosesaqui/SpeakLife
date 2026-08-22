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

## 0. Global Event Metadata

`AnalyticsContext` (`Core/Analytics/AnalyticsContext.swift`) stamps these
properties onto **every** event automatically. `AnalyticsService.dispatch` is
the single choke point that merges them in, so no call site has to pass them
and nothing can forget to. A call site that passes the same key wins — the
global value is only a default.

| Property | Example | Why it's here |
|----------|---------|---------------|
| `app_version` | `4.54` | Pin a conversion drop or error spike to the release that shipped it, and keep stale-build traffic out of funnels. Filter every funnel by this. |
| `app_build` | `1001` | Separates TestFlight/internal builds sharing one marketing version — where regressions show up first. |
| `subscription_status` | `free` / `trial` / `premium` | Segments every event by monetization state without a single call site passing it. Fed by `SubscriptionStore` via `didSet`. |
| `days_since_install` | `0`, `7`, `30` | Lifecycle stage. Separates day-0 behavior from week-2 retention on any event. Backfilled from `lifecycle_install_date` / `firstLaunchDate` so existing users don't read as day 0. |
| `session_id` | UUID | One id per launch, shared across Firebase and PostHog, so a session can be reconstructed across destinations. |
| `timestamp` | ISO 8601 | Client-side event time, so offline-batched events aren't misordered by ingest time. |

`app_version`, `app_build`, and `subscription_status` are also set as **user
properties**, so people-level cohorts ("everyone currently on trial", "everyone
still on 4.53") work, not just event filters.

**To add another global property:** add a key to `AnalyticsContext.Key`, return
it from `properties()`, and it lands on every event in every destination. Do not
add it to individual call sites.

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

> **Which arms enter this funnel.** Step 1, `onboarding_completed`, is fired by
> the **`quiz`** arm (at the commitment hold) and the **`direct`** arm (leaving
> the review wall) — both at the last pre-paywall milestone. The other arms
> (`product` / `identity` / `outcomes` / `warfare` / `promises` / `closer`) do
> not fire it, so they are invisible here; read those in funnel 3 instead.
> Both arms that do fire it stamp `variant`, and every event carries the
> `onboarding_variant` person property, so **break this funnel down by variant**
> rather than reading it as one population. Firing `onboarding_completed` from
> `HomeView.finishOnboarding` would put every arm in — at the cost of moving the
> quiz arm's step from pre-paywall to post-paywall, which is why it hasn't been
> done.

---

## 3. Onboarding A/B — Winner by Variant

The cross-variant experiment funnel. Every onboarding flow now fires a unified
`onboarding_started` → `onboarding_finished` pair from `HomeView`, tagged with
the chosen arm, so the variants (`product` / `identity` / `quiz` / `outcomes` /
`warfare` / `promises` / `closer` / `direct`, selected by Remote Config
`onboardingVariant`) compare head-to-head. `warfare` is the default arm from app **v4.28+**.
These route through `AnalyticsService`, so PostHog and Firebase both receive them.

**PostHog insight:** [Onboarding A/B — Winner by Variant](https://us.posthog.com/project/455580/insights/QfVRKZ3H)

| # | Event | Meaning |
|---|-------|---------|
| 1 | `onboarding_started` | Entered onboarding (any variant) |
| 2 | `onboarding_finished` | Completed onboarding |
| 3 | `subscription_started` | Started a trial or paid sub |

**Breakdown:** event property `variant` (`product` / `identity` / `quiz` / `outcomes` / `warfare` / `promises` / `closer` / `direct`). Dynamic, so new arms appear automatically.
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

### 3d. The `direct` arm (pain-led, funnel-depth test)

`direct` is the depth test. Every other arm pitches first and asks what is wrong
five or six screens in; this one asks on the **first frame** and reaches the
paywall in three screens instead of sixteen — and the first of those three is the
personal-declaration feature itself, so the product does its one job on the
user's real situation before a word of pitch. The category picker still exists
but only as a fallback for users the declaration produced nothing for. Cut: the
extended quiz, the product capability recap, the plan-building loader, the plan
reveal, the pledge and the rating ask. Its natural control is any arm running the
full quiz — `warfare` (the default) for an arm-vs-default read, or `closer` if
you want depth isolated from angle.

The whole front half is the declaration screen, so **that screen's drop-off is
the arm**. Build the internal funnel on `step_name`, not the raw `step` integer:

`personal_declaration_screen_shown` (`flow: direct`) → `personal_declaration_saved` →
`direct_mechanism_shown` → `testimonial_wall_shown` (`flow: direct`) →
`paywall_impression` → `direct_onboarding_completed`

The recovery ladder runs beside it, for the users the first ask lost:
`direct_pain_shown` → `direct_pain_answered` → `personal_declaration_saved`
(`flow: direct_retry`).

| Event | Properties | Why it matters |
|-------|-----------|----------------|
| `direct_onboarding_started` | `flow_schema` | Arm entry; denominator for everything below |
| `personal_declaration_screen_shown` | `flow` | Frame-one reach (shared screen, stamped `direct`) |
| `personal_declaration_saved` / `_skipped` | `flow` | **The arm's whole bet: will a cold user describe their situation on frame one?** Shared with every other arm running this screen, so it is directly comparable — but note this arm asks it first and they ask it deep in the back half |
| `direct_pain_shown` / `direct_pain_answered` | `flow_schema`, `burden` | The fallback picker. **Only fires for users the declaration produced nothing for** — its volume is the size of the refusal |
| `personal_declaration_*` (`flow: direct_retry`) | `flow` | The narrow re-ask after the picker. Its take-rate is how much of the refusal the recovery ladder wins back |
| `direct_mechanism_shown` | `pain`, `spoke_declaration` | Which of the two mechanism framings they saw |
| `direct_step_completed` | `step`, `step_name`, `flow_schema` | Per-step drop-off (`personal_declaration` / `pain_fallback` / `personal_declaration_retry` / `mechanism` / `testimonials` / `paywall` / `notification_time`) |
| `direct_onboarding_completed` | `goal_word`, `pain`, `burden`, `pain_source`, `seeded_category`, `notification_time`, `set_personal_declaration`, `total_duration_seconds`, `flow_schema` | Completion, plus every cut worth making |

Shared screens stamp `flow: "direct"` (`personal_declaration_*`,
`testimonial_wall_shown`, `survey_q8_shown`), and the paywall reads
`appState.onboardingSegment`, so every paywall event carries
`segment: direct_<burden>` — including for users whose burden was read back out
of the matcher's category rather than tapped.

Three numbers to watch beyond conversion:

- **`personal_declaration_saved` / `personal_declaration_screen_shown`.** Asking
  a cold user to describe their situation on frame one, before any framing, is
  the entire risk of this arm. Compare it against the same ratio in `warfare` or
  `closer`, where the identical screen runs deep in the back half with fifteen
  screens of setup in front of it. If it holds anywhere near those, framing was
  never load-bearing.
- **`pain_source` on `direct_onboarding_completed`** (`open` / `retry` /
  `picker` / `none`) — how far down the recovery ladder each user had to go.
  `open` is the frame-one ask landing. `retry` is the narrow re-ask rescuing
  someone who declined it, and a meaningful share there earns that extra screen
  on its own. `picker` is a tap and nothing more; a large share says the
  free-text open is too heavy an ask for frame one. `none` gave us nothing.
- **`set_personal_declaration`, cut against conversion.** This arm puts the
  declaration first instead of in the back half; if the users who got one convert
  far better, position is what's earning and it should move forward elsewhere.

`total_duration_seconds` is the arm's headline claim — compare its median against
the quiz arms to confirm the flow actually is faster in practice, not just
shorter on paper.

> **`flow_schema` is at 4.** Schema 1 opened with the picker and showed a canned
> one-of-seven declaration; schema 2 made that step the real feature but kept it
> third; schema 3 moved it to frame one and demoted the picker to a fallback;
> schema 4 added the narrow re-ask after the picker. The step order and the
> drop-off shape differ across all four, so **filter per-step funnels to
> `flow_schema = 4`** rather than pooling them. Retired:
> `direct_declaration_shown` / `direct_declaration_spoken` and the
> `spoke_declaration` completion property (schema 1), and the guarantee that
> every user passes through `direct_pain_shown` (schemas 1–2).

**Person property:** this arm sets `onboarding_burden` to the resolved
`UserPain` (`peace` / `fear` / `health` / `abundance` / `identity` / `shame` /
`bondage` / `purpose` / `joy` / `grief` / `loneliness` / `marriage` / `family` /
`nearness` / `more`) when the opening question
is answered, so **every** later event — `trial_started`, `subscription_started`,
retention — can be split by the pain the user walked in with. Only `direct` sets
it today, so it reads null for other arms.

---

## Key event reference

These route through `AnalyticsService` and reach every provider:

| Event | Source method | Notable properties |
|-------|---------------|--------------------|
| `onboarding_started` | `AnalyticsService.track` (HomeView) | `variant` |
| `onboarding_finished` | `AnalyticsService.track` (HomeView) | `variant`, `converted`, `conversion_type` |
| `subscription_started` | `track` (SubscriptionStore.purchase) | `product_id`, `value`, `is_trial`, `variant` |
| `screen_viewed` | `trackScreenView` | `screen_name`, `previous_screen` |
| `paywall_impression` | `trackPaywallImpression` | `paywall_id`, `variant`, `segment`, `pain` |
| `paywall_shown` | `track` (HighConversionPaywallView) | `variant`, `segment`, `source`, `pain` |
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

## 4. Enforcement campaigns (premium)

The seven-day campaign a user starts by describing what they're facing. The
funnel worth building is **offered → input → started → day 1 spoken → completed**.

| Event | Source | Notable properties |
|-------|--------|--------------------|
| `enforcement_offered` | `ModernDailyChecklistView` | weekly prompt reached an eligible user |
| `enforcement_locked_tapped` | card, non-premium | pairs with `paywall_impression` (`enforcement_card`) |
| `enforcement_input_rejected` | card | `reason`, `length` — too thin to build a week |
| `enforcement_started` | checklist view | `theme`, `source` (`curated` \| `matched` \| `redirect` \| `completion`), `secondaries` |
| `enforcement_curated` | `EnforcementCurator` | Claude chose the seven |
| `enforcement_curation_failed` | `EnforcementCurator` | `reason` — fell through to keyword assembly |
| `enforcement_burst_opened` | checklist Burst row | `day`. Fired from the card's CTA before that button moved to the checklist |
| `enforcement_day_completed` | `EnhancedStreakViewModel` | the day banked |
| `enforcement_completed` | `EnhancedStreakViewModel` | all seven |
| `enforcement_abandoned` | card | `enforcement_id`, `last_day` |

### 4a. Input screening

Requests the app won't build a week for. Watch these two together: a rise in
`enforcement_input_screened` with `layer: local` and no matching rise in
`enforcement_redirect_accepted` means the local phrase list is declining people
who came to stay.

| Event | Notable properties |
|-------|--------------------|
| `enforcement_input_screened` | `verdict` (`another_persons_partner` \| `harm_to_another` \| `unscriptural` \| `reach_out`), `layer` (`local` \| `claude`) |
| `enforcement_redirect_accepted` | `reason`, `category` — took the week we offered instead |
| `personal_declaration_screened` | `verdict`, including `claude_declined` when only the model caught it |
| `claude_declined` | Claude refused to write a personal declaration |

`verdict: reach_out` is the self-harm branch. It should be **rare**; a
sustained rise is a signal to look at, not a metric to optimise.

### 4b. Campaign-refreshed tasks

`checklist_task_completed` carries `is_burst` and `recommended_audio_id` but
**not** whether the task was rebuilt by a campaign, so it cannot currently
answer "do people complete campaign tasks more than generic ones?" — the ROI
question for the whole feature. Adding `is_campaign: task.isCampaignRefreshed`
to that event would close it.

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
