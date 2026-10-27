---
name: faith-ad-formulas
description: Write SpeakLife Meta ad copy from the 15 battle-tested Christian ad formulas (The $50K Copy Vault, Marcos Torres / HIVE) adapted for an app install + subscription — Revival Reel, Third Door, Straight Shot, Confession, Feature Box, Moment, Zoom In, Tool Belt, Triple Threat, Menu, Handoff, Gut Check, Courtroom, Endorsement Ladder, Invite. Runs one formula across many personas, long and short, to produce a 10–20 creative test batch where every ad lands on the matching onboarding (Promises or Storm) via its ob= deep link. Use when asked for "ad variations", "a test batch", "20 ads", "run the copy vault", "use formula X", "spin this winner", "new angles", "seasonal ad", "Easter/Christmas/New Year ad", "testimonial ad", "serve ad", "native ad", "make it not look like an ad", or "write ads for [persona]". For a single six-beat cold ad use speaklife-ad-primary-text; for a feature demo video use demo-ad-copy.
---

# Faith Ad Formulas (Copy Vault → SpeakLife)

Source: *The $50K Copy Vault* + *The Faith-Scale Framework* (Marcos Torres). The core belief behind
both: **in 2026 your creative is your targeting.** Meta no longer lets you pick "Christians". It
watches who stops, watches 3s+, comments and installs, then finds more people like them. So the copy
has to make it unmistakable *who* the ad is for, in plain words, and we need many angles so Meta can
find many pockets of buyers.

The full formula steps and a SpeakLife example for each are in
[references/formulas.md](references/formulas.md). Read it before writing.

## The three principles (apply to every formula)

1. **Clear, not clever.** Talk the way the reader thinks, not the way a marketer or a pulpit talks.
   Calm, plain, a little boring is fine. Poetic or churchy language confuses both the reader and the
   algorithm. The test: would an 8-year-old understand the hook? (This matches CLAUDE.md Rule 15.)
2. **Short and long both win.** Length isn't the variable; *"is this about me?"* is. Every formula
   gets a long version and a short version. Let the data choose.
3. **One avatar, many personas.** Never run one formula once. Run it across 3–5 personas from
   `speaklife-personas`. One formula → 20+ ads.

## The #1 rule: make it not look like an ad (serve, don't sell)

People are on Facebook/Instagram to scroll, not to buy, and they've been trained to skip anything
that looks like an ad within half a second. The job is to get past that reflex. The way through is
**native content that serves**: a genuinely helpful post that would be worth reading even if they
never install. By the time they realise it's an ad, they've already been helped, so now they listen.
Not a trick: the post really does help, and the offer is honest.

**Two weapons, run both in every batch:**
| | Serve ad | Sell ad |
|---|---|---|
| Goal | Give real help first, offer after | Show the product so they want it |
| Looks like | A post a friend would share/save | An ad |
| Opening | A usable truth, a method, "step N" | The product, the problem, the offer |
| Formulas | Menu, Third Door, Gut Check, Confession, Moment (as teaching) | Straight Shot, Feature Box, Zoom In, Tool Belt, Courtroom |
| SpeakLife proof | "you can't fight a thought silently" and "5 ways to renew" slideshows: **$24 per trial, our best** | "Rewire your mind" statics: $34–36 per trial, our biggest volume |

**How to build a SpeakLife serve ad:**
1. Teach one thing they can use today without the app: how to answer a thought out loud, 3 verses
   for a 3 a.m. spiral, the difference between praying about a storm and speaking to it, how to
   speak over your kids before school. Real Scripture, real steps.
2. Make it the whole post. The help must stand alone. If you deleted the last line, it should still
   be worth saving.
3. Then one soft bridge to the offer: *"If you want these ready to speak every morning, that's what
   SpeakLife does 👇"*.
4. Format it native: TikTok-style slideshow or a plain text post, lowercase organic caption, "save
   this", no logo on slide 1, no price.

Serve example (caption for a 5-slide list deck):
> you can't fight a thought silently and win. step 2 is the whole key. save this for a 3am morning.
>
> 1. notice the thought 2. answer it out loud 3. with a verse, not a feeling 4. say it again in the
> morning 5. let your mind catch up to your mouth
>
> if you want the verses ready to speak every morning, that's what SpeakLife does 👇

## Workflow

1. **Inputs.** Ask for (or infer): the storm/persona(s), which onboarding it should feed (Promises
   default, Storm if in the test), the creative (static, video, slideshow — what's on screen in the
   first 3s), and any **real** proof (App Store rating, review count, real reviews). Never invent
   proof, prices or deadlines.
2. **Pick formulas by awareness.**
   | Reader state | Formulas |
   |---|---|
   | Cold, feels the storm, never heard of declaring | Revival Reel, Third Door, Gut Check, Confession |
   | Knows they want this, needs a nudge | Straight Shot, Feature Box, Zoom In, Menu |
   | Already speaks the Word daily (high intent) | Tool Belt (or `demo-ad-copy`) |
   | Wide net, early in testing | Triple Threat |
   | Has real reviews | Courtroom, Endorsement Ladder |
   | Seasonal / dated | Moment, Invite |
   | Speaking over people they're responsible for | Handoff |
   Brand-new test or untrained pixel: start with **one** formula × 5–10 persona/creative variants.
   Mature account: 3–4 formulas × 2–3 personas each = 6–12 copies per round.
3. **Pick personas** from `speaklife-personas` and attach each ad's `ob=` code.
4. **Write long + short** for each persona. Keep the formula's step order intact so results differ
   by angle/persona, not structure.
5. **Run the SpeakLife pass** (below) on every line.
6. **Deliver as a test-ready table**: ad name, formula, persona, frame (Promises/Storm), `ob=` code,
   primary text (long/short), headline (~5 words, front-load first 25 chars), description, CTA
   button (Install Now / Learn More for cold), suggested creative. Name ads
   `F{n}-{formula}-{persona}-{L|S}-{ob}` so `faith-scale-campaigns` can read winners back.

## SpeakLife pass (non-negotiable)

- **Speak, don't just pray.** The mechanism is speaking His Word over the storm the way Jesus did
  (Mark 4:39, Mark 11:23). Never sneer at prayer. Position speaking as what most were never taught.
- **Scripture carries the promise; the app carries the method.** Quote verses accurately with the
  reference. Don't promise what the verse doesn't (CLAUDE.md Rule 6). Never promise another free
  person will change.
- **Call higher.** Name the storm as the setting, then declare the higher reality. Don't dwell in
  the low thing.
- **Meta Personal Attributes.** The Faith-Scale hooks like "As a Christian parent…" or "Christian
  leaders!" are written for physical products and are a rejection risk for us. Never bind *you* to a
  religion, health, mental-health, financial or relationship state. Do the callout through the
  **moment or role** ("For the parent listening for the car at 11pm…", "For nurses coming off a
  night shift…") or through a **first-person speaker** ("I prayed over my son for two years and
  never once spoke to the storm."). The Christian words in the body do the algorithmic targeting.
- **No outcome claims, no fake urgency.** No "guaranteed", no "healed in 7 days". Urgency must be
  real (a holiday, a dated event) or behavioural ("before the day gets the first word"). No trial
  day counts ("try it free" at most; trial length is Remote Config). Discounts only if the user
  confirms a live offer.
- **Scent continuity.** Line 1 of the ad and screen 1 of the onboarding must feel like one
  conversation. A healing ad links `ob=healing`, never the generic store page.
- **Format.** Short lines, white space, line 1 works alone, one CTA ending 👇 or 👉, no naked URLs,
  no em dashes in declarations. Exception that wins: for **native TikTok-style slideshows** (our two
  cheapest-CPT ads), the caption is short, lowercase and organic with a "step N is the key. save
  this." hook and 3–5 hashtags. Read `docs/creative/LEARNINGS.md` before choosing formulas.
- **Never** *manifest, the universe, name it and claim it, prosperity gospel framing.*

## Spinning a winner (variation, not clone)

From the FAQ: *keep the winning promise, change the packaging.* Same emotional hook, rebuilt: new
opening line, new visual, static ↔ video, reworked body, different persona. If a stranger couldn't
tell at a glance they're the same ad, Meta won't treat them as a clone. When asked to "spin" a
winner, produce 5: (1) same formula new persona, (2) same persona new formula, (3) short ↔ long,
(4) Promises ↔ Storm frame, (5) new first line only.

## Checklist before handing over

- Every ad has formula, persona, frame and `ob=` code?
- Long and short version of each?
- Hook passes the 8-year-old test and the "that's my house" test?
- No personal-attribute phrasing, outcome claim, invented proof, fake deadline, or trial day count?
- Verse quoted accurately with reference, and it actually promises what the ad implies?
- Headlines don't repeat the button or each other?
