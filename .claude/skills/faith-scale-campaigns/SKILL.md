---
name: faith-scale-campaigns
description: Plan, launch, read and scale SpeakLife Meta campaigns with the Faith-Scale 2-Campaign system (Marcos Torres / HIVE), adapted from e-com ROAS to an app with a free trial and subscription. Covers broad Advantage+ targeting (no interests), the weekly Test campaign (4 ad sets × 5 ads), winner rules, breeding variations, the Scale campaign loaded by Post ID, the 20%/48h budget rule, the 80/20 test/scale split, and diagnosing zero winners. Use when asked to "set up a test campaign", "plan this week's ad test", "which ads are winners", "how do I scale this", "move winners to scale", "raise budget", "why did my winner flop in scale", "ads aren't working", or "weekly creative day". Pair with faith-ad-formulas for the copy and speaklife-personas for the angles.
---

# Faith-Scale Campaigns (Test → Scale)

**The one idea:** your creative is your targeting. We don't tell Meta who our audience is. We tell
it what the ad is for, in plain Christian language with a clear persona callout, and it finds the
people who behave like our buyers (stop the scroll → watch 3s+ → comment → install → trial → pay).
We scale by refining *message*, not targeting.

## The four moves

1. **Strip targeting.** Broad / Advantage+ audience. Country (and age only if needed). **No
   interests**, no "Christianity/Bible" proxies, no megachurch zip codes. Narrow boxes shrink the
   learning pool and raise CPMs.
2. **Plain, clear Christian messaging.** The hook tells Meta and the reader exactly who it's for.
3. **Call the persona out** through a moment or role (see `faith-ad-formulas` → Personal
   Attributes; "As a Christian parent…" is a rejection risk for us).
4. **Volume of real variation.** 10–20 genuinely different creatives per round: different angle,
   persona, formula, visual. You can't scale off one winner anymore.

## Translating e-com rules to SpeakLife

The PDFs assume a physical product with instant Purchase ROAS. SpeakLife has a free trial, so
revenue lands days later and annual plans front-load it. Before planning, **ask the user** for the
numbers below; never invent them.

| Faith-Scale (e-com) | SpeakLife equivalent | Needs from user |
|---|---|---|
| Conversion event = Purchase | Optimize for the deepest app event with enough volume: trial start (`StartTrial`) or `Purchase`; installs only if events are thin | Which events Meta receives (SDK / Branch / RevenueCat→Meta) |
| Winner = ROAS ≥ 3 | Winner = cost per trial ≤ target CPT **and** trial→paid holding (read at day 7+ in RevenueCat) | Target CPT; trial→paid rate; annual price |
| Kill at ROAS ≤ 1.9 after 2× price spent | Kill when spend ≥ 2× target CPT with 0 trials, or CPT ≥ ~1.5× target after 3× target spend | Target CPT |
| Test budget ≈ 2× item price/day | Each test ad set ≥ $50/day (the PDF's floor) | Daily budget |
| Scale budget ≈ 4× item price/day | Start scale ad sets at ~2× the test ad-set budget | — |

**Current account facts (2026-10-01):** the main account is `253451158661796` (~$46K lifetime,
optimizes `start_trial_mobile_app`; historical best CPT ≈ $24–26, volume winners $34–36). SpeakLife
v2 `2082620432359498` is small and optimizes `fb_mobile_add_payment_info`. `967944814851435` is
disabled.

**Target set by the user (2026-10-27), from Meta spend vs RevenueCat revenue:** break-even is about
$16 per real trial (43% of trials pay ≈ $39 net in year one). Meta over-counts trials by about 10%,
so in Meta's numbers: **winner (target) CPT ≤ $12, ceiling $14.** Kill: 0 trials after $30
spend, or CPT > $14 after $45 spend. Winners graduate at CPT < $12 with ≥ 5 trials. Campaign
`120247236092730227` ("SL Scale | Mind winners") is really the Test campaign; graduates go to an
"SL Winners" campaign with the same setup, loaded by the same creative/post. Details:
memory `max-cpa-unit-economics`. Re-derive if price, trial length or trial→paid moves.

**Low-budget version.** The full 4 ad sets × $50/day test is ~$6K/month. Below that, keep the logic
and shrink the shape: 1–2 test ad sets × 3–5 ads at the highest daily budget you can sustain, run
the full 7–14 days, and judge each ad only after it has spent ≥ 2× target CPT. Fewer ads, same rules.
Tell the user what their budget can actually read out before planning 20 ads.

Revenue truth is RevenueCat, not PostHog (see memory `posthog-weekly-scorecard`). PostHog has no
ad-spend source, so CPT/CAC must come from Ads Manager.

## Campaign 1 — Test

- App promotion (or Sales, if web-to-app) campaign, **ad-set budget**, the optimization event above.
- Broad audience, Advantage+ audience and placements on. **Exclude warm audiences** (existing
  users/app activity) with "further limit reach" so tests hit fresh eyes. Exclusions only, no
  inclusions.
- In each ad: correct FB + IG accounts, **multi-advertiser ads off**, destination = install link
  carrying the persona's `ob=` code, Advantage+ creative enhancements / text variations / AI image
  generation **off**, related media "0 selected". One media, one primary text, one headline. CTA:
  Install Now (Learn More for very cold).
- Structure: **1 campaign → 4 ad sets → 5 ads** = 20 creatives. Use full Duplicate, not Quick
  Duplicate. Group ad sets by formula or persona so you can read the pattern.
- Run **7–14 days. Don't touch it.**
  - Day ~5: look for ads hitting the winner bar.
  - Day 7: if still winning, **breed** them: duplicate, make a variation (see faith-ad-formulas →
    Spinning a winner), publish into a new ad set.
  - Day 14 verdict: **0 winners** → diagnose (below). **1–2** → breed and keep testing. **3–5** →
    ready to scale.

## Campaign 2 — Scale

1. Open each winning ad's post and copy its **Post ID** (the long number at the end of the post
   URL). Keep them in a doc with the ad name.
2. New campaign, ad-set budget, same optimization event, broad, **no exclusions** (scale mixes warm
   and cold on its own), no interests.
3. Ad Setup → **Use existing post → Enter Post ID** so likes and comments (social proof) carry over.
   Browser add-ons none. One ad set per winner (duplicate, swap Post ID).
4. Give it 3–5 days. If CPT is healthy, raise budget **no more than 20% every 48 hours.** Faster
   resets learning and kills the ad.

**Winner flopped in scale?** Usually: scaled faster than 20%/48h; test was cold-only and scale is
mixing warm (give it 3–5 days); or it was rebuilt instead of loaded by Post ID and lost its proof.

## Budget split

20% testing / 80% scaling. Example: $300/day → $60 test, $240 scale. But each test ad set needs
≥ $50/day, so until you have 3–5 winners, front-load testing, then settle into 80/20.

## Weekly loop (same day every week = creative day)

1. Write 10–20 new ads (`faith-ad-formulas` across `speaklife-personas`), mostly variations of
   proven angles, not blank-page inventions.
2. Launch them in the existing Test campaign (7–14 days).
3. Roll new 3–5 winners into Scale by Post ID.
4. Turn off scale ads below the kill bar (after enough spend).
5. Turn off originals in Test so new creatives get budget.

Winners fatigue faster the more you spend. There is no forever-winner; always have the next one
proven and waiting.

## Diagnosing zero winners

Change one variable at a time.
- **Low CTR + high CPM** → the ads aren't connecting. New hooks, new personas, new formulas.
- **Good CTR, few installs** → the App Store page is leaking (screenshots/first line don't match
  the ad).
- **Installs but few trials** → onboarding scent break or paywall. Check the ad's `ob=` arm in the
  funnel (`check-funnels`, `onboarding-ab-ranking`); is line 1 of the ad the same promise as screen
  1 of the onboarding?
- **Trials but no paid** → offer/price/retention, not copy.

## Volume without burnout

Factory, not art project: rebuild one proven angle five ways (new line, new visual, static vs
video, new persona). Batch-shoot/render raw material in one sitting and slice it all week. Keep a
swipe file of every ad that stopped your scroll. AI multiplies; a human finishes the spiritual
nuance.

## Output when asked to plan a test

A table: ad set, ad name (`F{n}-{formula}-{persona}-{L|S}-{ob}`), formula, persona, `ob=` code,
creative, primary text, headline, CTA, plus the budget per ad set, optimization event, exclusions,
day-5 / day-7 / day-14 check dates, and the winner/kill bars filled with the user's real numbers.
Never launch, pause or change budgets in Ads Manager without explicit confirmation for that action.
Exception: the scheduled task `speaklife-ads-daily` runs with the user's standing authorization
(2026-10-27) to pause, scale (+20%/48h, $600/day total cap), graduate and launch within these bars.
