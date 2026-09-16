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

**Headline (pain known): who they are in Jesus.** Reframed September 2026 from
the problem-naming version below it; variants renamed `pain` → `identity` so the
rollout reads as a before/after the same way `pain` read against `storm`.

| Pain | Headline | Standing on |
|------|----------|-------------|
| peace | You have the mind of Christ. | 1 Cor 2:16 |
| fear | You are as bold as a lion. | Prov 28:1 |
| health | You are healed and whole. | Isa 53:5 |
| abundance | You are an heir, not a beggar. | Rom 8:17 |
| identity | You are who God says you are. | |
| shame | There is no condemnation on you. | Rom 8:1 |
| bondage | Jesus already made you free. | John 8:36 |
| purpose | You are called, and already equipped. | |
| joy | The joy of the Lord is your strength. | Neh 8:10 |
| grief | You are held, and you are not alone. | Ps 34:18 |
| loneliness | You are never alone again. | Heb 13:5 |
| marriage | You carry peace into your home. | |
| family | You are the one who stands for them. | |
| nearness | You are His, and He is near. | Jas 4:8 |
| more | You carry the authority Jesus gave you. | Luke 10:19 |

**Why the problem headline went.** A problem headline sells relief, and relief is
a smaller thing than the app's actual claim. Speaking God's Word is not supposed
to return someone to neutral, it is supposed to put them in their right identity
— unshakable, walking in authority, reigning in life rather than surviving it —
and a screen that opens on what is wrong has already agreed to sell the smaller
thing. Every line stands on a specific verse, which is what keeps an identity
claim from being flattery.

**This is the riskiest change on the screen and should be watched as one.** The
problem-led version is what the 16.5% onboarding paywall→purchase baseline was
measured on, and the storm arm's documented failure was opening on the answer
before the screen had named anything. Two things are different here: the storm
arm led with a *mechanism* ("speak to every storm") where this leads with the
reader's own standing, and the problem did not disappear — it moved into the
subhead, which still names the domain and still says what to do. Beat 1 asserts,
beat 2 turns, beat 3 says who they become. If `identity` underperforms `pain` on
shown→trial over a comparable window, the headline is the thing to revert; the
rows, the timeline and the pricing changes are independent of it.

**Returning users** get recognition first, then the identity it earns: *"You came
back for healing. It is already yours."* Told "it is already yours" cold, a
returning user hears marketing; told right after the app has shown it was paying
attention, they hear it.

**The retired problem headlines**, for the revert:

| Pain | Headline |
|------|----------|
| peace | Your mind won't stop. |
| fear | You keep waiting for bad news. |
| health | Your body is still waiting on an answer. |
| abundance | The numbers don't work right now. |
| identity | You don't feel good enough. |
| shame | You can't seem to put it down. |
| bondage | You keep going back to it. |
| purpose | You're off the track you were built for. |
| joy | Everything feels flat. |
| grief | You lost something you can't replace. |
| loneliness | You're carrying this on your own. |
| marriage | Home doesn't feel like home right now. |
| family | Someone you love is on your heart. |
| nearness | God feels further away than He used to. |
| more | You've prayed about it. It hasn't moved. |

**Fifteen, not seven.** The first version mirrored the seven options on the old
category screen. But the `direct` arm resolves pain from what the user *wrote*,
and the matcher classifies that into forty-odd declaration categories — so seven
buckets sent fear, loneliness, grief, addiction, bitterness, marriage and every
family situation to the same generic catch-all, which is the one thing a
pain-led paywall cannot do. `UserPain.from(categoryRaw:)` is the exhaustive map;
`more` is still the catch-all but should now be rare rather than routine. The
seven legacy segment values from the other arms all remain case names, so those
arms round-trip unchanged.

**Subhead: declare it, then act on it.** The headline already named the problem,
so this line says what to do — and it names the second half on purpose. Ten to
thirteen words:

> **You don't feel good enough.**
> Declare what God already said you are, then carry yourself like it's true.

**Both halves, every time.** Saying it and then living unchanged is the thing
James calls dead faith, and a paywall that only promises a feeling is selling one
internal state in place of another. The first draft of the mechanism screen's
closing line read *"provision becomes what you expect instead of what you hope
for"* — expect and hope are the same thing wearing different clothes, and the
user does nothing differently either way. Every line now names the declaration
and then the move that proves they believed it. The onboarding mechanism screen
cites James 2:17 under that line, so "then do something" is scripture's
instruction and not ours.

**The "spoken the way Jesus did" reinforcement is not in the subhead.** It closes
every paywall in the assurance line, and the mechanism screen carries the full
proof — three things Jesus spoke to, plus Mark 11:23-24 — so by the paywall it is
being recalled, not argued.

Drafts that failed on the way here, worth carrying to the next surface: 38–45
words (a paragraph in 14pt on a screen whose next job is a price); halved but
still opening on the dead end the headline had already named; and solution-only
but purely descriptive, which is accurate and inert.

**One consistency rule this screen learned the hard way.** The subhead, the four
rows and the closing line must all resolve from `UserPain`. They briefly did not:
the fresh-personal-declaration branch read `surveyGoalWord`, which is written at
the *end* of onboarding, so at the paywall it is empty or a run stale — and a
provision paywall shipped subheaded *"your joy declarations"* over provision rows
and a provision closing line. Three sources of truth, one of them a run behind.
`pain` now wins wherever it is known.

**Solution rows (beat 3): who you become.** Five rows whose *titles are the
person* and whose *details are the mechanic*. Row one is bespoke per pain — for
peace, *You win the battle in your mind*; for identity, *You live from who Jesus says you
are* — and rows two through five run the same arc for everyone, aimed at that
pain's domain: **You walk in authority before the day starts** (the sixty-second
morning), **You stay unshakable all day** (audio), **You are training for
reigning** (the 30-day plan, on Romans 5:17 — a plan is a training claim, so the
row makes it out loud instead of counting days), **You know exactly what God
says** (Bible chat).
That shared arc is what keeps fifteen sets of copy honest rather than fifteen
sets of invented differences.

These rows were a feature list until September 2026 ("Ask the Bible anything",
"Thirty days, not one good day"). Nobody subscribes to a capability; they
subscribe to who they will be once they have it, and the app's whole claim is
that speaking God's Word makes you somebody — unshakable, walking in authority,
living from your identity in Jesus instead of from what is happening to you. The
details still carry the concrete mechanic, which is not a compromise: an identity
promise with no machinery under it is a slogan, and the storm arm already proved
what this screen does when it sells a claim the user cannot see the mechanism of.
The comparison grid's row labels moved the same way ("You speak it, not just read
it" rather than "Spoken declarations") — a comparison table is the easiest place
on a paywall to slip back into a spec sheet. The clean layout
carries a titles-only three-row version — naming a problem and then showing nothing
but a price is a worse screen than the one it replaced.

**Social proof is the 4.9 App Store rating only.** The "100,000+ believers" line
is gone from this screen: the rating is verifiable on the listing and a subscriber
count is not, and an unverifiable number sitting next to a price costs trust
exactly where the screen can least afford it. The stars banner under the headline
carries it; there is no second social-proof line competing with the mechanics.

**CTA:** trial-eligible → **"Try 7 Days Free"** (real StoreKit day count);
otherwise **"Continue"**. (Control keeps "Start Free Trial" / "Start Taking Ground →".)

**Closing line, under the CTA.** Two lines run here: the risk reversal ("No
payment due now · Cancel anytime in Settings", trial-eligible only) and then the
last doubt-killer — *is this the right answer for what I came in with?* It names
what this is not, then what it is, aimed at the pain the headline named:

> 📕 Not tips or affirmations. God's own Word over your mind, spoken the way Jesus did.

The honest close is that the guarantee was never the app, it is Scripture, so the
line points at Scripture rather than at features or at us.

This slot previously carried the generosity / pay-what-you-can framing ("your
subscription helps keep SpeakLife within reach for believers who can't afford
full price"). That is a *meaning* frame, not a *decision* frame — it told a
hesitating user what their money does for someone else at the exact moment they
were still asking whether it does anything for them. It is not lost: the
post-purchase mission screen carries it, which is where a "you did something
good" message actually lands. The pay-what-you-can link itself is unchanged and
still sits directly below, gated by `showPayWhatYouCanCTA`.

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

## 5b. September 2026 pass — what shipped

Four changes, all unconditional (no new flags). 30-day baseline they were
measured against, person-level, `high_conversion_pain_*`:

| Cut | Shown | CTA | Purchased |
|---|---|---|---|
| Onboarding | 237 | 54 (22.8%) | 39 (**16.5%**) |
| Settings | 191 | 27 (14.1%) | 5 (**2.6%**) |

**1. Both plan cards now quote the same cadence.** The dark selector put the
annual card's *yearly total* ($59.99) beside the monthly card's *monthly* price
($9.99), so the eye compared two numbers that were never comparable and the
cheaper plan read as six times the price. Annual now shows the per-month (or
per-week, under `useWeeklyPlan`) figure with the real
`nonAnnualYearlyEquivalent` struck through beside "$59.99 per year". This is
what the clean layout already did, and it is a candidate explanation for why
that layout converted at 19.6% against 11.6% — the gap may have been pricing
legibility rather than minimalism. 29 of the 54 onboarding CTA tappers cancelled
at the Apple sheet at least once, which is where a price surprise shows up.

**2. The trial timeline shipped** ("How your free trial works", both layouts,
directly above the price). Today → day n−1 → day n, built from the real
StoreKit day count, and the reminder row is only drawn from n ≥ 3 so it never
describes a push landing on a day already on screen. Every claim is backed by
`TrialExperienceService`: `trial_d2` at 9am on day n−1, `trial_d3` on the last
day, both scheduled at trial start and deliverable even though the notification
permission ask comes after this screen. The dark layout's `trialCallout` and the
clean layout's day-count line stood down to avoid saying the same sentence
twice; the clean layout's reassurance moved under the CTA where the pattern puts
it.

**3. The featured testimonial is pain-matched.** It was a fixed anxiety review
shown to all fifteen pains — fifteen lines of tailored copy followed by somebody
else's problem, immediately above the price. `PaywallTestimonial` tags real
reviews by the pains they actually speak to and falls back to the quote that
claims least. **It never invents one.** Eight pains still have no real review
(health, abundance, shame, purpose, grief, loneliness, marriage, family) and
currently fall back; sourcing a real provision or healing review is the highest
-value copy task left on this screen. The clean layout, which shipped with no
social proof at all, now carries a compact rating + matched quote.

**4. Returning users get a returning-user screen.** 135 of 191 settings
impressions were being served the cold-open pain headline "You've prayed about
it. It hasn't moved." — a stranger's guess at someone whose behaviour we can
see. Settings and feature-gate entries now resolve pain from
`UserPreferencesTracker.topCategories` when the top category has ≥3 selections
("You keep coming back for healing."), fall back to the onboarding segment, then
to "You've been reading it. Start speaking it." Behaviour beats the segment for
returning users only; at the end of onboarding there is no behaviour yet.

`paywall_cta_tapped` now carries `pain` and `source`, so the cut that matters —
does a named pain convert better than `none`, and separately by entry point —
no longer needs a person-level join against `paywall_shown`.

**Reading it out.** Variant names did not change, so the release date is the
comparison line, exactly as the pain rollout was read. Split by `source` before
anything else: onboarding and settings convert 6x apart and blending them hides
both. Guardrails unchanged — `paywall_dismissed` seconds-on-paywall, and
trial→paid (a change that lifts trials and drops paid conversion is a loss).

## 6. Recommendations not implemented here (next levers, in order)

1. **Send more traffic to the clean light layout** — it's beating the dark layout
   19.6% vs 11.6% on shown→trial. Confirm with ~2 more weeks of volume, then make
   it the default. Stop testing the clean-dark skin (5.1%, losing).
2. ~~**Blinkist trial timeline**~~ — shipped, see 5b.
3. **Trial structure test before any price test** — highest documented win-rate
   category (59.6%). E.g. 7-day vs 3-day trial on annual.
4. **Behavior-change testimonial** — the matching mechanism shipped (see 5b);
   what is left is sourcing. Eight pains have no real review and fall back.
   Real reviews for provision, healing and marriage would cover the three
   highest-volume unmatched segments. Do not fabricate one.
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
