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

## 4. The pain-led copy (live — unconditional, no flags)

### Variants report as `high_conversion_pain_v1` / `_pain_clean_v1` / `_pain_clean_dark_v1`

**Supersedes the storm arm** (`high_conversion_storm_*`), which led with the
mechanism before the screen had named a problem. The storm line is not gone — it
moved into beat 2, where a mechanism belongs. The screen now runs three beats:

1. **Name the problem** — the headline says the thing that is wrong
2. **Turn it** — why what they've been doing hasn't moved it, and what does
3. **Solve it, concretely** — four mechanics described against *that* problem

The problem comes from `PaywallPain`, resolved from `AppState.onboardingSegment`
(stamped by every arm *before* the paywall renders). Deliberately not from
`surveyGoalWord`: that is written after the paywall in every arm except quiz, so
it is empty exactly when this screen needs it.

**Headline (pain known):** the problem, named in the user's terms —

| Pain | Headline |
|------|----------|
| peace | Your mind won't stop. |
| health | Your body is still waiting on an answer. |
| abundance | The money keeps running out before the month does. |
| identity | You've lost sight of who you are. |
| purpose | You're off the track you were built for. |
| joy | Everything feels flat. |
| more | You've prayed for years. It hasn't moved. |

**Subhead:** the turn, aimed at that pain. E.g. for peace — *"Reading one more
verse about peace hasn't quieted it. Jesus didn't ask the storm to settle. He
spoke to it, and SpeakLife puts that same Word in your mouth every morning until
your mind is what obeys."*

**Headline (no segment — settings, feature gates, `unsegmented`):** still pain-led,
naming the one problem every user on this screen shares —
> **You've prayed about it. It hasn't moved.**
> Jesus never begged the storm to leave. He spoke to it. SpeakLife puts the exact Word for what you're facing in your mouth every morning, until it obeys.

**Headline (just spoke their personal declaration):** unchanged, and it keeps
priority over the pain — naming a problem right after someone took authority over
it steps on the warmest moment in the funnel.
> **You just spoke to your storm.**
> Jesus stilled a sea with three words. Keep speaking your *peace* every morning until it obeys.

**Solution rows (beat 3):** the same four capabilities every time — declarations,
audio, the 30-day plan, Bible chat — each with a title and a detail line written
against the named pain. For peace: *Speak peace, don't just read it* · *Audio for
the loud hours* · *Caught before it spirals* · *An answer at 3am*. The social-proof
line (100,000+ believers) drops to a quiet footer under the rows instead of
competing as a fifth "benefit". The clean layout carries a titles-only three-row
version — naming a problem and then showing nothing but a price is a worse screen
than the one it replaced.

**CTA:** trial-eligible → **"Try 7 Days Free"** (real StoreKit day count);
otherwise **"Continue"**. (Control keeps "Start Free Trial" / "Start Taking Ground →".)

Why this shape: the storm arm's weakness was that it opened on the answer. A user
who has not yet had their problem named has no reason to weigh a mechanism, and
the value props read as a feature list rather than as relief. Problem → turn →
mechanics is the order the same user already walked in onboarding, so the paywall
now continues that argument instead of restarting it.

## 5. How to read it out

The pain copy ships unconditionally — no Remote Config flags. The rollout reads
as a **before/after** in PostHog: funnel `paywall_shown → paywall_cta_tapped →
trial_started` broken down by `variant` — pain impressions carry the new
`high_conversion_pain_*` names, so the release date is the comparison line against
the storm baseline. Guardrails: `paywall_dismissed` seconds-on-paywall and the
trial→paid rate (a change that boosts trials but tanks paid conversion is a loss).
Reverting means reverting the commit.

`paywall_shown` and `paywall_impression` also carry **`pain`** (`peace` / `health`
/ `abundance` / `identity` / `purpose` / `joy` / `more` / `none`) — already
resolved, so breaking conversion down by which problem was named needs no segment
parsing, and works for the quiz arm whose segment names don't map by string. The
cut worth making first: does a named pain convert better than `none`? If not, the
personalization is decoration and only the generic pain-led headline is earning.

## 6. Recommendations not implemented here (next levers, in order)

1. **Send more traffic to the clean light layout** — it's beating the dark layout
   19.6% vs 11.6% on shown→trial. Confirm with ~2 more weeks of volume, then make
   it the default. Stop testing the clean-dark skin (5.1%, losing).
2. **Blinkist trial timeline** — "How your free trial works": 🔓 Today full
   access · 🔔 Day 2 we remind you (true — TrialExperienceService schedules the
   pushes) · ⭐ Day 3 trial ends, cancel before and pay nothing. Strongest
   documented paywall pattern (+23% trials). A build was drafted and removed with
   the no-more-flags decision (recoverable from git history at commit efb37ab);
   ship it unconditionally if wanted.
3. **Trial structure test before any price test** — highest documented win-rate
   category (59.6%). E.g. 7-day vs 3-day trial on annual.
4. **Behavior-change testimonial** — if a real review exists in the vein of "this
   app got me speaking God's Word every day when nothing else did," lead the
   featured-testimonial slot with it (behavior proof beats outcome proof in the
   faith category). Do not fabricate one.
5. **Seasonal challenge engine (Hallow's real machine)** — a named, dated, free
   communal challenge ("40 Days of Speaking to the Storm") with the content inside
   the trial; Lent/Advent function as twice-yearly Black Fridays (Hallow: 25x
   downloads on Ash Wednesday, $10M months). This is the biggest lever on this
   list and it's marketing + content, not paywall code.
6. **Storm-frame the App Store listing** to match ("the exact Word for your exact
   storm") so ad → store → onboarding → paywall says one thing.

## Sources

RevenueCat State of Subscription Apps 2025/2026; Adapty State of In-App
Subscriptions 2026; Superwall test archive & Cal AI case study; Growth.Design
Blinkist case study; abtest.design (Going CTA test); RevenueCat paywall-redesign
case studies (Mojo, Claim); ScreensDesign teardowns (Hallow, Abide, Glorify,
Pray.com, Bible Chat); Hallow "Why do we charge" + help docs; Contrary Research
Hallow breakdown; Appfigures Lent analyses; live PostHog funnels (project 455580).
