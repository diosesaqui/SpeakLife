---
name: creative-engine
description: The SpeakLife creative system — the weekly Brief → Make → Test → Learn loop that keeps Meta fed with fresh ads, sized to current ad spend (Build Your Creative Engine, Marcos Torres / HIVE). Decides how many new ad IDEAS we need this month (≈1 per $2,500 spend, min 4), turns each concept into variations × formats, pulls live Meta results, writes the "why it won" lesson into docs/creative/LEARNINGS.md, and feeds that into the next brief. Orchestrates speaklife-personas → faith-ad-formulas → the asset skills (static ads, story ads, slideshows, reels) → faith-scale-campaigns. Use when asked to "run creative day", "plan this week's ads", "what should we make next", "how many ads do we need", "read last week's results", "what did we learn", "build the creative system", "brief the next batch", or "who should be making our ads".
---

# SpeakLife Creative Engine

**The bottleneck moved.** Meta finds the buyer now. What decides growth is whether we can keep
making enough good ads to feed it, because most ads lose and every winner fatigues. The engine is
the small, steady system that keeps producing, and the loop is what makes it get smarter.

Caveat from the source: creative can't rescue a weak offer or a leaky funnel. If installs don't
become trials, fix onboarding/paywall first (`check-funnels`, `onboarding-ab-ranking`).

## Idea 1 — Creative supply rule

About **one new idea (concept) per ~$2,500 of monthly ad spend**, never fewer than 4 a month.
| Monthly spend | New concepts / month |
|---|---|
| < $10K | 4–8 (1–2 a week) |
| $15K | ~6 |
| $40K | ~16 |
Get actual spend from Meta. Main account with the history is **`253451158661796`** (named "Riccardo
Washington", optimizes `start_trial_mobile_app`); `2082620432359498` SpeakLife v2 is small;
`967944814851435` is disabled. At today's spend, SpeakLife is **Tier 1: Just You** (founder +
Claude + skills, maybe a freelance editor or a ~$200 UGC creator per video).

## Idea 2 — One concept becomes many ads

Count **ideas, not files.** A concept is one big idea (e.g. *"Jesus didn't ask the storm to calm
down. He spoke to it."*). Multiply it:
- **Variations** (same idea, new packaging): new hook, new headline, new speaker (founder, the AI
  host, a real user), new persona, new formula, Promises vs Storm frame.
- **Formats**: 1:1 feed, 4:5 feed, 9:16 story/reel; static vs video vs slideshow.
1 concept → 3 variations → 3 formats ≈ 9 ads. So 3–4 concepts fill the 20-ad test from
`faith-scale-campaigns`. The fastest win is usually **refreshing a proven concept** (new hook, new
first 3 seconds, new speaker), not inventing a new one.

## The loop (run weekly, same day)

### 1 · Learn (start here, not with a blank page)
1. Pull last 7–14 days at ad level from Meta: `name, amount_spent, mobile_app_install, results`
   (main account optimizes for `start_trial_mobile_app`; v2 for `fb_mobile_add_payment_info`),
   `omni_purchase, ctr, cpm`. Judge on cost per trial, never CTR (high-CTR provocation ads lost).
   Add `breakdowns=[age, gender]` monthly to keep the persona read fresh.
2. Apply the winner/kill bars from `faith-scale-campaigns` (cost per result vs target, ≥ 2× target
   spent before judging). Cross-check paid conversion in RevenueCat, not PostHog.
3. For each winner and each clear loser write **why**, at the level of a reusable lesson:
   - weak: "Jesus is power won."
   - strong: "Cold women 55+ installed when the first line declared Jesus's authority as a fact,
     and skipped copy that framed the problem as a 'mind to rewire'."
   Check hook vs body vs visual vs persona vs frame, and the onboarding arm it fed.
4. Update `docs/creative/SpeakLife_Ad_Tracker.xlsx` (one row per ad: angle, persona, `ob=`,
   frame, serve/sell, formula, format, hook, copy, spend/installs/trials/CTR, lesson; cost per
   trial and verdict are formulas driven by the Settings tab). Add a row for every new ad the
   day it ships, refresh the numbers each week, and park untested hooks in its Hooks Bank tab.
   Edit with openpyxl and keep the existing formulas and columns.
5. Append the lessons to `docs/creative/LEARNINGS.md` (newest first). This file is the engine's
   memory; a lesson that isn't written there is lost.

### 2 · Brief
From the lessons, pick this week's concepts (supply rule) — mostly refreshes of winners, plus one
or two new bets. For each concept write a one-screen brief:
- Concept (one sentence) and the lesson it builds on
- **Serve or sell** (see faith-ad-formulas). Every batch carries both; start around 60% serve /
  40% sell, since serve native slideshows hold our best cost per trial, then let the data move the mix
- Persona(s) and `ob=` code (`speaklife-personas`)
- Formula(s) (`faith-ad-formulas`) and frame (Promises / Storm)
- Variations to make and formats
- Asset skill to render it and the first-3-seconds description
- What this test will teach us if it wins or loses (the hypothesis)

### 3 · Make
Write copy with `faith-ad-formulas`; render with the matching asset skill:
native TikTok-style slideshow (our cheapest CPT format) → `speaklife-format-slideshows` /
`speaklife-viral-slideshows`, Higgsfield statics/video when connected, static → `speaklife-static-ads`, story → `speaklife-story-ads`, slideshow →
`speaklife-mechanism-slideshows` / `speaklife-viral-slideshows`, reel →
`speaklife-content-engine`, feature demo → `demo-ad-copy`. Name every ad
`F{n}-{formula}-{persona}-{L|S}-{ob}` plus the concept id (`C{yyMMdd}-{n}`) so results map back to
the brief.

**Higgsfield video recipe (proven on V1, Oct 2026, ~60 credits a video):**
1. Stills: `gpt_image_2_5`, `quality: high`, `resolution: 2k`, 9:16 (~0.25 cr low, more at high). Lock
   the person by passing the best still as `image_references` to every other shot, or she changes
   between shots.
2. Motion: `kling3_0`, `mode: pro`, `sound: off`, 5s, `start_image` = the still (~9 cr each). If the
   batch returns "Preset … recommended instead", resubmit with `declined_preset_id`.
3. Voiceover: `seed_audio`, preset voice **Romy** `2e5f5f01-6d50-5335-a9ae-e8f81cd42342` (founder's
   pick), `speech_rate: -10`. Don't put "..." pause marks in the text; those jobs failed.
4. Edit locally: local ffmpeg has no `drawtext`, so render captions as transparent PNGs with PIL
   (Arial Bold, white, soft shadow, centred ~27% from the top, clear of Reels UI) and overlay them.
   Time each shot to the VO with `silencedetect`, stretch clips with `setpts`, and close on an end
   card: app icon (`Assets.xcassets/appIconDisplay.imageset`, cropped to the rounded square) +
   "save this" + "SpeakLife / verses ready to speak every morning". Export H.264 CRF 18, 30fps,
   AAC, loudnorm -14 LUFS.
5. Copy check before rendering the voiceover (founder caught this on V1): every caption must say
   exactly what the shot shows ("put the phone down" over the phone shot, not a "don't scroll"
   metaphor), each step must be a concrete action, and the end card must carry the serve-ad soft
   bridge as a question ("want a verse ready for every 3am thought? SpeakLife has them ready to
   speak."). Keep captions off faces: move a card down onto the body when the face is high in frame.
6. Show the real app at the step it solves (founder's call on V2): a 3–5s insert of a real in-app
   screenshot (never AI-generated UI), rounded and centred over a blurred, darkened frame of the
   same scene with a slow push-in. Pick a declaration from `declarationsv10.json` whose verse matches
   the ad, and prefer a category that isn't mental-health worded (e.g. innerHealing over mentalHealth).

### 4 · Test
Load the batch with `faith-scale-campaigns` (Test campaign, broad, no interests, one copy + one
headline per ad, Advantage+ creative off). Never publish, pause or change budgets without the
user's explicit go-ahead for that action.

Then back to **Learn**. Volume isn't the goal; learning is. Volume is how we take enough shots to
learn fast.

## Tracking must be trustworthy first
The loop learns from noise if events are wrong. Before trusting a result: Meta is receiving the
optimization event, installs are attributed (Branch fix shipped after 4.65; see memory
`posthog-weekly-scorecard`), and paid conversion is read from RevenueCat.

## Tiers (build the rung you're on)

| Tier | Monthly revenue | New concepts / mo | Who makes them | Cost / mo |
|---|---|---|---|---|
| 1 Just You | $0–10K | 4–8 | Founder + Claude skills (+ cheap editor / UGC ~$200 a video) | $0–500 |
| 2 A Little Help | $10–30K | 8–15 | Founder steers; freelance editor + 1–2 UGC creators | $500–2K |
| 3 First Real System | $30–80K | 15–30 | Creative strategist (or agency) directing freelancers | $3–8K |
| 4 Hybrid | $80–250K | 30–60 | In-house strategist + producer, agency for peaks | $10–25K |
| 5 Department | $250K+ | 60–100+ | Creative director, pods, creative ops | $30K+ |

Next-move signal for Tier 1 → 2: the day making ads is the thing that never gets done, hire a
freelance editor so the founder keeps doing angles, which only the founder can do.

## Output of a creative-day run
1. The learnings added to `docs/creative/LEARNINGS.md`.
2. This week's briefs (one per concept).
3. The ad table from `faith-ad-formulas` ready to render/load.
4. A one-line count: concepts → ads, vs what the supply rule says spend needs.
