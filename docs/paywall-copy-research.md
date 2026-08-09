# Paywall Copy Research — "Pray Like Jesus. Speak to Every Storm."

*August 2026. Research into the highest-converting paywall copy in the market, what
the winning faith apps say on their paywalls, and the sharper storm-positioned copy
now implemented behind Remote Config flags (`useStormPaywallCopy`,
`useTrialTimelinePaywall`).*

---

## 1. Where we are today (live PostHog baseline, last 30 days)

Funnel: `paywall_shown → paywall_cta_tapped → trial_started`, by `variant`:

| Variant | Shown | CTA rate | Trial rate |
|---|---|---|---|
| `high_conversion_v1` (dark, personalized) | 706 | 24.8% | **11.6%** |
| `high_conversion_clean_v1` (light minimal) | 97 | 30.9% | **19.6%** |
| `high_conversion_clean_dark_v1` | 78 | 21.8% | 5.1% |

Takeaways: the **clean light layout is winning** (small sample, but directionally
strong — +69% relative on trial rate), and the clean **dark** skin is losing badly.
Blended paywall→trial sits around 12%. Median trial→paid for Health & Fitness apps
(closest public category) is ~38–40%; top decile 68% (RevenueCat 2026).

## 2. What the highest-converting paywalls do (evidence ranked)

1. **Trial timeline ("How your free trial works")** — Blinkist's Today / Day 5 /
   Day 7 timeline: **+23% trial starts**, 55% fewer complaints, push opt-in 6%→74%.
   The #1 reason users refuse a trial is fear of forgetting to cancel. Lose It!,
   Mimo (+60% trial opt-in) and others have replicated it. Apple now endorses the
   pattern; the old "free trial toggle" gets rejected under 3.1.2 as of Jan 2026.
2. **Free-anchored short CTAs** — "Trial for free" vs "Sign up for free" = **+104%
   trial starts** (Going). Superwall's 4,500-test archive: shortest CTA wins;
   "Continue" + "No commitment, cancel anytime" beneath is the standard winner.
3. **Reassurance microcopy under the CTA** — "No payment due now · Cancel anytime ·
   We'll remind you before your trial ends." On essentially every $100K+/mo paywall
   Superwall sees. We already ship the first two claims; the reminder claim is
   **truthful for us** (TrialExperienceService schedules day n−1 and last-day pushes).
4. **Personalized outcome headline** — Superwall: personalized paywalls +15%+.
   Noom's "Your personalized plan is ready" pattern; quiz-referencing headlines beat
   generic "Unlock Premium" everywhere. (Our headline stack already does this —
   keep it; the storm arm keeps the personal-declaration continuity moment.)
5. **Divided pricing + honest anchor** — "$4.99/month, billed annually" (Mojo) and
   per-week framing lift annual take-up 15–30% with no price change. Already live
   in the clean layout.
6. **2–3 plans max, annual preselected, one badge** — already live.
7. **Social proof cluster near the CTA** — "Join N users" + star rating + one
   goal-matched testimonial; typical lifts 10–40%. Behavior-change testimonials beat
   theology ("This app has gotten me to pray every day when nothing else has" —
   Hallow's hero line).
8. **Day-0 paywall, hard-ish wall** — 82–90% of all trials start day 0. RevenueCat
   2026: hard paywalls out-earn freemium ~5–8x per install with identical 1-year
   retention. Faith-app caveat below.
9. **Test order** — trial structure (59.6% win rate) > plan duration > price >
   visual-only tweaks (lowest win rate). Copy about *the trial and the outcome*
   beats decoration.

## 3. What the winning faith apps say (and the open lane)

| App | Paywall posture | The line that does the work |
|---|---|---|
| Hallow (#1 grossing) | Soft wall, ~85% of library locked, 7-day trial → $69.99/yr "= $5.83/mo" | "Find God's Peace in Prayer" · pay = "you're not the product" · one-for-one given subscriptions |
| Abide | Soft, 7-day trial → $39.99/yr | "The #1 Bible app to stress less & sleep better" · "Your first week's on us" · claimed outcome stats (80% sleep better) |
| Glorify | Soft; "Pay It Forward" ON the paywall — your sub sponsors someone else's | "Grow with God every day" |
| Pray.com | Annual-only $99.99, 3-day trials | "Join millions of Christians experiencing stronger faith & deeper sleep" — and public trust damage from the pressure |
| YouVersion | Free forever | Owns "free Bible text," which is why every paid app sells transformation, not text |

**The open lane:** every winner sells felt outcomes (peace, sleep, habit) with God as
the mechanism and library size as proof. **Nobody sells Scripture itself as the
active agent, spoken out loud.** "Pray like Jesus — speak to every storm" is exactly
that claim, and no top-grossing faith app owns it. Our onboarding already teaches it
("Reading about the storm" vs "Speaking to the storm"); until now the paywall
dropped the thread.

Money+ministry: our generosity line + pay-what-you-can is the right category
pattern (Hallow/Glorify both wrap commerce in stewardship). Keep it.

## 4. The sharper copy (implemented, flag-gated)

### `useStormPaywallCopy` → variants `high_conversion_storm_v1` / `_storm_clean_v1` / `_storm_clean_dark_v1`

**Headline (default):**
> **Pray like Jesus. Speak to your storm.**
> He stilled a sea with three words. SpeakLife puts the exact Word for your storm in your mouth every morning.

**Headline (goal word known — peace/healing/identity/…):** same headline, subhead
> Your *peace* declarations, in your mouth every morning, until the storm obeys.

**Headline (just spoke their personal declaration):**
> **You just spoke to your storm.**
> Jesus stilled a sea with three words. Keep speaking yours every morning until it obeys.

**Value props (classic layout):** The exact Word for your exact storm · Peace in
under 60 seconds · Declarations over your health, home, and mind · God's Word in
your ears morning and night · Ask the Bible anything · 100,000+ believers speaking
life daily.

**CTA:** trial-eligible → **"Try 7 Days Free"** (real StoreKit day count);
otherwise **"Continue"**. (Control keeps "Start Free Trial" / "Start Taking Ground →".)

Why this shape: outcome-first + mechanism ("the exact Word, spoken") + continuity
with the ad/onboarding storm language + the free-anchored CTA pattern. The headline
is uniform in the storm arm so the reposition reads cleanly in analytics; the
subhead carries the personalization (goal word / fresh declaration), which the
evidence says is where the +15% lives.

### `useTrialTimelinePaywall` → `trial_timeline` param on every paywall event

Blinkist block replacing the single trial line (both layouts, only when the selected
plan is genuinely trial-eligible and ≥3 days):

> **How your free trial works**
> 🔓 **Today** — Full access unlocked. Start speaking life today.
> 🔔 **Day 2** — We send you a reminder that your trial is ending.
> ⭐ **Day 3** — Trial ends. Cancel anytime before and pay nothing.

Every line is true: TrialExperienceService schedules the day n−1 (9:00am) and
last-day pushes. Independent flag so its effect is separable from the copy test.

## 5. How to run it

1. Firebase Remote Config: add `useStormPaywallCopy` and `useTrialTimelinePaywall`
   (both Boolean, default `false` — everything ships dormant).
2. Test one at a time (the storm copy first), 50/50, on the winning layout.
3. Read out in PostHog: funnel `paywall_shown → paywall_cta_tapped → trial_started`
   broken down by `variant` (storm variants carry a `storm` segment) and by the
   `trial_timeline` property for the timeline test.
4. Guardrails: watch `paywall_dismissed` seconds-on-paywall and the trial→paid rate
   (a timeline that boosts trials but tanks paid conversion is a loss).

## 6. Recommendations not implemented here (next levers, in order)

1. **Send more traffic to the clean light layout** — it's beating the dark layout
   19.6% vs 11.6% on shown→trial. Confirm with ~2 more weeks of volume, then make
   it the default. Stop testing the clean-dark skin (5.1%, losing).
2. **Trial structure test before any price test** — highest documented win-rate
   category (59.6%). E.g. 7-day vs 3-day trial on annual.
3. **Behavior-change testimonial** — if a real review exists in the vein of "this
   app got me speaking God's Word every day when nothing else did," lead the
   featured-testimonial slot with it (behavior proof beats outcome proof in the
   faith category). Do not fabricate one.
4. **Seasonal challenge engine (Hallow's real machine)** — a named, dated, free
   communal challenge ("40 Days of Speaking to the Storm") with the content inside
   the trial; Lent/Advent function as twice-yearly Black Fridays (Hallow: 25x
   downloads on Ash Wednesday, $10M months). This is the biggest lever on this
   list and it's marketing + content, not paywall code.
5. **Storm-frame the App Store listing** to match ("the exact Word for your exact
   storm") so ad → store → onboarding → paywall says one thing.

## Sources

RevenueCat State of Subscription Apps 2025/2026; Adapty State of In-App
Subscriptions 2026; Superwall test archive & Cal AI case study; Growth.Design
Blinkist case study; abtest.design (Going CTA test); RevenueCat paywall-redesign
case studies (Mojo, Claim); ScreensDesign teardowns (Hallow, Abide, Glorify,
Pray.com, Bible Chat); Hallow "Why do we charge" + help docs; Contrary Research
Hallow breakdown; Appfigures Lent analyses; live PostHog funnels (project 455580).
