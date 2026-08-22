# PostHog Data Quality — Known Traps

Audited 2026-08-22 against project 455580 (`Default project`, org DiosEstaAqui).

**Read this before answering any question with PostHog numbers.** Several of the
highest-volume events are misleading in ways that are invisible from the query
result alone: they look populated, they just aren't measuring what their name
says. Every trap below produced a wrong first answer at least once.

Companion doc: `ANALYTICS_FUNNELS.md` (funnel definitions).

---

## Rule 0 — how to test for a missing property

`empty(toString(properties.x))` **always returns 0**, because `toString(NULL)`
is `NULL` and `empty(NULL)` is `NULL`, so `countIf` counts nothing. A null audit
written that way reports a clean bill of health on completely broken events.

Use `isNull(properties.x)`:

```sql
countIf(isNull(properties.category)) AS null_category
```

---

## Rule 1 — always filter to current app builds

Global context (`app_version`, `app_build`, `session_id`, `subscription_status`,
`days_since_install`) was introduced in **app version 4.54**. Everything older
sends none of it.

On a 30-day window that reads as ~85% null and looks like catastrophic breakage.
It is a rollout curve, not a bug — 100% null before 4.54, down to 7.4% by
2026-08-21 as users update. **Do not "fix" this.**

Any audit of instrumentation quality must scope to current builds:

```sql
AND properties.$app_version IN ('4.54','4.55','4.56','4.57')
```

Corollary: `days_since_install` is unusable as a cohorting dimension on older
data. An in-app cancel-flow histogram built on it returned n=3 out of 22 events.

---

## Rule 2 — non-JSON property values are dropped silently

The destination SDKs serialize properties to JSON and discard anything that
isn't a JSON primitive. The event still arrives, just missing that key.

`swipe_affirmation` — the highest-volume engagement event in the app at 12,255
events / 30 days — passed `declaration.category`, the Swift enum rather than its
`.rawValue`, and so **never carried a category at all**. Nothing about the event
looked wrong; the breakdown just came back 100% null.

`AnalyticsPropertySanitizer` (in `AnalyticsService.swift`) now coerces enums,
URLs, UUIDs and Dates and drops `nil` explicitly, with a DEBUG warning naming
the event and key. New call sites are protected. **Historical data is not** —
anything before the fix ships is permanently missing those properties.

---

## Rule 3 — simulator traffic is in the production project

Before the fix, simulator builds reported to the same PostHog project as real
users. A single favorites test suite produced **1,769 of 2,007
`audio_favorite_tapped` events over 90 days — 88% of the metric** — from 27
phantom "users" favoriting rows named `Test Audio`, `Zebra`, `Mango`,
`To Remove` and `Retry Test`.

Simulator reporting to PostHog/TikTok/Meta is now disabled, but **all historical
data is still contaminated**. When querying anything favorites- or
engagement-related over a window that predates the fix:

```sql
AND properties.$is_emulator = false
AND properties.$is_testflight = false
```

Sanity check: if a content title looks like test data, it is.

---

## Rule 4 — events that do not mean what they are named

| Event | Trap |
|---|---|
| `content_listened` | Fired on **every** playback callback, not per play. A 30-day window counted 10,617 progress milestones, 1,055 pauses and 752 seeks as listens against only 1,938 real starts — inflated ~5x. Fixed to fire on `.started` only. Pre-fix play counts are meaningless; unique-user counts are still valid. |
| `user_action` | 14,525 of 30,077 rows over 30 days were `ml_training_ios_ai_init`, app-boot telemetry filed as user behaviour with `screen: "unknown"`. It outranked every real action. Fixed to `ml_model_initialized`. Exclude it from any pre-fix "top actions" breakdown. |
| `paywall_shown` + `paywall_impression` | **Still broken.** `HighConversionPaywallView` fires both for one impression (531 vs 532 unique users / 30d; union 532). Never sum them. `paywall_impression` is the canonical one — it is also emitted by five other paywalls. |
| `audio_played` | Pre-fix, carried only `id`. Not comparable to `audio_playback`. |
| `favorites_category_viewed` | Name promises a category dimension it never had. Pre-fix rows have no category. |
| `category_chooser_tapped` | One of three call sites wrote `declaration_category` instead of `category`, so 69% of the event read as having no category. |
| `trial_started` vs `trial_experience_started` | Not duplicates despite near-identical daily counts. `trial_started` is the StoreKit subscription trial (single-sourced in `SubscriptionStore`); `trial_experience_started` is the in-app trial-push scheduler. |

---

## Rule 5 — declaration favourites are `user_action`, not a favourite event

Favouriting a declaration is `user_action` with `action = 'add'` (and `'remove'`
to unfavourite), carrying `declaration_id`, `declaration_text`, `category`,
`total_favorites`. There is a `favorite_tapped` constant in `Events.swift` that
is **never fired** — do not query it.

Audio favourites are a separate event, `audio_favorite_tapped` (see Rule 3).

---

## Rule 6 — `Events.swift` is not a map of the taxonomy

**42 of 61 declared event-name constants have never fired in 90 days.** Some are
genuinely dead; others exist as `user_action.action` strings under the same name
while the constant sits unused — `bible_book_selected` (369 events),
`bible_version_changed` (100), `manage_subscription_tapped` (98).

Always confirm an event exists in the live schema (`read-data-schema`) before
building a query on a name found in the code.

---

## Rule 7 — `$screen` is 76% autocapture garbage

Over 30 days: **51,316 autocapture views vs 16,476 deliberate ones.** PostHog's
SwiftUI screen autocapture reports view *type names* —
`PresentationHostingController<AnyView>` alone is 43,776 views across 1,350
users, the single largest "screen" in the product, plus multi-line
`LazyView<ModifiedContent<...>>` monsters, `SKStoreReview`, `UIActivity`,
`CKSMSComposeController`.

Deliberate screens are the snake_case ones (`declarations_tab`, `audio_tab`,
`today_checklist_tab`, `bible_chat_conversation`, `profile_tab`). Filter to them:

```sql
AND match(toString(properties.$screen_name), '^[a-z0-9_]+$')
```

Setting `config.captureScreenViews = false` would remove the noise — not yet
done, since PostHog's mobile screen analytics depends on it.

---

## Rule 8 — RevenueCat history starts 2026-08-08

`rc_*` events (`rc_trial_started_event`, `rc_trial_cancelled_event`,
`rc_trial_converted_event`, `rc_cancellation_event`, `rc_renewal_event`,
`expiration_event`, `billing_issue_event`) do not exist before that date. Any
subscription-lifecycle question over a longer window is answering on a partial
series — say so.

The app's own `trial_started` has more history (173 users since 2026-06-07)
but no matching cancellation signal before the in-app cancel flow shipped
2026-08-02.

`rc_trial_cancelled_event` carries `purchased_at` and `expiration_at`, so
time-in-trial is computable from the single event without a join:

```sql
dateDiff('hour', toDateTime(properties.purchased_at), timestamp) AS hours_into_trial
```

**Split by `cancel_reason`.** `BILLING_ERROR` is a failed charge, not a decision
to cancel, and mixing the two badly distorts the timing picture (see below).

---

## Rule 9 — naming is inconsistent across the taxonomy

- Same dimension, different keys: `audio_playback` uses `category`,
  `audio_favorite_tapped` uses `audio_category`.
- Non-snake_case event names still live: `AudioScreenLoaded`, `LoveLetterOpened`,
  `Profile_StreakStats_Tapped`, `Devotional read`, `Affirmation spoken`,
  `Affirmation shared`, `Audio affirmation listened`. Kept deliberately so their
  history stays continuous.
- Quiz events were the quiz *title* as the event name, and the start and
  completion screens emitted the **same** name, making completion rate
  unmeasurable. Fixed to `quiz_started` / `quiz_completed` with `quiz_title` as
  a property — so those two names carry no history before the fix ships.
- Category picks also emitted one bare event per category (`faith`, `health`,
  `anxiety`, …). Removed. Low volume (max 12 events / 90 days), but they still
  clutter the event list.

---

## Trial cancellation timing (n=18, 2026-08-08 → 2026-08-22)

Recorded here because the shape is stable and the sample will stay small for a
while. Re-run before quoting.

| Time into trial | Voluntary | Billing failure |
|---|---|---|
| 0–3 hours | 2 | 0 |
| 3–24 hours | 1 | 0 |
| Day 1 | 2 | 0 |
| Day 2–3 | 2 | 0 |
| Day 4–6 | 3 | 0 |
| Day 7 (charge moment) | 2 | 6 |

Every `BILLING_ERROR` lands at 169–170 hours — exactly the 7-day conversion
attempt. **A third of all "trial cancellations" are failed payments, not
decisions.** Voluntary cancels (n=12) average 79.5 hours; five of twelve happen
inside the first 48 hours.

Stated reasons (in-app flow, n=19): "Other reason" 7, "It's too expensive" 6,
"I'm not using it enough" 4, "Technical issues" 1, "Missing a feature" 1. The
in-app save-offer retained 1 of 14.

---

## The weekly-decision metric set (added 2026-08-22)

Ten metrics were missing the instrumentation to compute them at all. What now
exists, and the gap each closes.

### 0. LTV was structurally impossible — identity was split

`rc_*` revenue events arrive from RevenueCat keyed on `$RCAnonymousID:…`; the
app reports behaviour under PostHog's device id. Over 90 days that produced
**78 person records holding revenue, 3,914 holding behaviour, and an overlap of
exactly zero.** No question crossing the two — "LTV by onboarding variant",
"revenue by acquisition cohort", "do activated users pay more" — had a join to
make.

`GrowthMetrics.linkRevenueIdentity` now aliases the RevenueCat id onto the app's
person on foreground. **This fixes new data only; historical revenue stays
orphaned.** Do not trust any pre-fix cohort revenue number.

| # | Metric | Event / person property | Gap it closed |
|---|---|---|---|
| 1 | **LTV / ARPU** | `revenue_recorded`; person `lifetime_revenue_usd`, `purchase_count`, `plan`, `billing_term`, `first_purchase_at` | Revenue was per-transaction only. A person who renewed four times was indistinguishable from one who paid once, so payback used first-purchase price. |
| 2 | **Activation** | `user_activated` (once ever); person `activated_at`, `hours_to_activate` | No definition of "an install became a user" existed. Fires on first declaration spoken, audio played, chat message or checklist task. |
| 3 | **Retention / resurrection** | `app_day_started` (once per calendar day) | `Application Opened` is autocapture and fires on every foreground, so it counted app switching, not days. Carries `days_since_last_open` and `is_resurrected`. |
| 4 | **Session length** | `session_ended` | `endSession()` had **zero call sites**: 32,444 sessions started over 90 days, none ended. Session duration was never measured. Now wired to `scenePhase == .background`. |
| 5 | **Push effectiveness** | `notification_opened` | Notification taps were never recorded. The whole push programme had no open rate and no way to tell which type earns its send. |
| 6 | **Feature breadth** | `feature_first_used` (once per feature); person `features_used_count` | First-week breadth is the strongest retention predictor most apps have, and it can't be recovered later without scanning each person's full history. |
| 7 | **Habit depth** | person `max_streak` | Streak was event-only, so "users who ever reached a 7-day streak" wasn't a cohort. |
| 8 | **Checklist denominator** | `home_checklist_viewed.offered_task_ids` / `incomplete_task_ids` | `task_unlocked` fires once when a task first unlocks, so nothing distinguished "offered and refused" from "never offered". |
| 9 | **Checklist un-completion** | `checklist_task_uncompleted` | Toggling a task off emitted nothing, so it still counted as done in every completion metric. |
| 10 | **Churn reason as a cohort** | person `churned_at`, `last_cancel_reason` | Cancel reason was event-only. |

### Still not instrumented

- **Notification *delivery*** — only opens. Open rate has no true denominator;
  `lifecycle_notifications_scheduled` counts scheduling, not delivery.
- **Renewal revenue while the app is closed.** `recordPurchase` runs in-app, so
  server-side renewals only reach PostHog as `rc_renewal_event`. Once the alias
  above has been live a while, sum `rc_*` `revenue` per person instead of
  trusting `lifetime_revenue_usd` alone.
- **Paid acquisition source per person.** Branch/Meta attribution is wired for
  onboarding routing but not mirrored to a person property, so CAC-vs-LTV still
  can't be split by channel.

---

## Checklist feed: what actually gets done (30 days)

Well instrumented — `checklist_task_completed` carries `task_id`, `task_type`,
`task_category`, `task_difficulty`, `current_phase`, `streak_day`, `is_burst`,
`is_newly_unlocked`, `recommended_audio_id`.

**77.2% of user-days end with zero tasks completed.** Only 2.5–3% complete the
whole list.

| Task | Type | Unlocked (users) | Completed (users) |
|---|---|---|---|
| complete_daily_burst | speak | 558 | 592 |
| read_devotional | read | 558 | 412 |
| listen_audio | listen | 558 | 157 |
| gratitude_moment | reflect | 238 | 58 |
| journal_insight | reflect | 54 | 39 |
| memorize_verse | memorize | 46 | 27 |
| share_affirmation | share | 16 | 12 |
| worship_song | worship | 42 | **0** |
| study_deeper | study | 35 | **0** |
| prayer_walk | worship | 28 | **0** |
| encourage_someone | serve | 17 | **0** |
| pray_for_others | worship | 15 | **0** |
| serve_someone | serve | 9 | **0** |
| testimony_share | share | 5 | **0** |

Seven tasks were unlocked 146 times and completed **zero** times. All seven are
the ones with no `navigationDestination` — off-app instructions ("pray while
walking", "do something kind for someone"). They are completable (tapping the
row calls `completeTask`), so this is refusal, not breakage.

Three tasks carry the entire feed: burst, devotional, audio.
