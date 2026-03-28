# MEMORY.md — Long-Term Memory

> **Structure inspired by memelord (2026-03-07):**
> Memories are categorized by confidence weight.
> - 🔴 USER_INPUT — Franchiz told me directly. Highest weight. Never assume stale.
> - 🟠 CORRECTION — Was wrong, now right. Remember what broke.
> - 🟡 INSIGHT — Discovered during work. Verified in practice.
> - ⚪ ASSUMPTION — Inferred or unverified. Treat as provisional.
> Time-sensitive items are tagged `[verified: YYYY-MM-DD]`.

---

## Who I Am

🔴 Operating as AI Chief of Staff for SpeakLife
🔴 Owner: Franchiz (Telegram ID: 7533986283)
🔴 Mandate: Oversee everything. Grow SpeakLife every week. No excuses.

---

## Who Is Franchiz

🔴 Building SpeakLife to $1M MRR
🔴 Vision-first thinker — big picture, high standards
🔴 Communication style: Telegram, voice messages, direct
🔴 Timezone: São Paulo (BRT, UTC-3)
🔴 Wants execution, not explanations. Report what's done, not what you plan to do.

---

## SpeakLife App

🔴 iOS-only faith app: declarations, Bible verses, audio devotionals, push notifications
🔴 6 categories: Anxiety, Joy, Destiny, Wisdom, Identity, Confidence
🔴 Audience: 65% female / 35% male, age 25–40
🔴 Pricing: $10/mo | $50/yr (3-day free trial on annual)
🔴 FB App ID: 904572920975437 | App Store ID: 1617492998
🔴 Ad Account: act_253451158661796

---

## Ad Rules (LOCKED IN)

🔴 **MAX 6 ADS PER ADSET — no exceptions, ever** (Franchiz mandate March 19)
🔴 **Winning ad format:** "If you wake up and **[bold pain point],** we made this for you." — one sentence, bold on pain, no second paragraph on image. FB copy field holds the long-form body.
🔴 **Campaign budget at CBO level** — do not set adset-level budgets when campaign uses CBO

## Delivery Rules

🔴 **Ad content always goes to Operations group, topic 2**
  - Chat ID: `-1003748448073`, topic_id: `2`
  - Includes: ad creatives (images), UGC videos, scripts, copy, rendered assets
  - Franchiz mandate: March 7, 2026

🔴 **Skin health & improvements → Operations group, topic 3334**
  - Chat ID: `-1003748448073`, topic_id: `3334`
  - Franchiz mandate: March 15, 2026

---

## Active Systems [verified: 2026-03-07]

🟡 Testing Trials campaign: 3 adsets × 6 ads = 18 ads running [verified: 2026-03-19]
  - Adset A (120237846166550227): 6 ads incl. TXT_01 proven winner
  - Adset B (120237900675600227): 6 batch 2 ads
  - Adset C (120237900682420227): 6 batch 3 ads
🟡 Scaling Winners campaign: running (Rewire your mind best performer $2.90 CPI)
🟡 Retargeting C3+C4: re-enabled March 19, audiences 1k+
🟡 Daily content cron: 7am BRT — Scout + Copywriter → 3 slideshows, static ads
🟡 Pillar rotation: Identity → Grace → Anxiety/Fear → Love → Health (day-of-year % 5)
🟡 Ad static formats: S1 (carousel hook) ✅, S2 (quote card) ✅, S5 (social proof) ✅ | S3 (before/after) ❌, S4 (screenshot) ❌
🟡 HeyGen UGC system: live (API key in memory/2026-03-04.md)
🟡 EOD report cron: 1am UTC daily (cron ID: 513e1f85)
🟡 Social auto-post crons (LIVE — 3x/day IG + TikTok):
  - Morning 7AM ET: cron ID 8d305ac8 — declare angle carousel
  - Midday 12PM ET: cron ID ba989ecc — God Speaks / POV video
  - Evening 8PM ET: cron ID 9015624c — quote card
  - Ayrshare API key stored: speaklife/.env
  - Platforms connected: instagram, tiktok, twitter (all 3 active)
🟡 Weekly plan cron: Sunday 8pm UTC (cron ID: f48cd541)
🟡 Crypto daily report cron: 9pm Eastern (cron ID: b984e0cb-0d84-4cf0-9137-f3a1fb704821)

### Disabled Crons (intentional)
🟡 Daily Shorts — disabled per Franchiz (no more shorts)
🟡 Declaration Review — disabled (AppContent handles it now)
🟡 Daily Ad Batch (10 creatives) — disabled

---

## Current Goals (March 2026)

🔴 Phase 1: $10K MRR (1,304 subscribers)
🔴 Blended CAC target: $25–35

---

## Active Blockers [verified: 2026-03-07] — Franchiz must action

🟡 **BLOCKER #1 (RESOLVED 2026-03-18):** Now have full access to act_253451158661796 via 60-day long-lived user token.
  - Token stored: speaklife/.env → FB_ACCESS_TOKEN (expires 2026-05-17)
  - App ID + App Secret also stored in .env for token refresh
  - Page ID: 104027662277976 | IG User ID: 17841452261734156
  - System User ("Telegram") still only has act_967944814851435 — long-term fix: assign to act_253451158661796 in BM
  - Monitoring crons live: 12pm + 9pm BRT daily → posts to Operations topic 2

🔴 **BLOCKER #2:** App screen recording footage — unblocks S4 ad format + V3 demo video

🔴 RevenueCat secret key: `sk_PGIaaZlqQLMHIxyczNQrqIRRDBaZM` — stored in speaklife/secrets.json

🔴 **BLOCKER #4:** Firestore email list export → Meta (seeds LAL campaign)

🔴 **BLOCKER #5:** Pexels API key is invalid (returns 401) — old key: `ewE8arkiYx39plxUBwQvaAd0mowXOp0wnn`. Needs fresh key from pexels.com/api

🔴 **PENDING (Franchiz requested, March 6):** Cheap weekend cruises from Miami, April or May 2026, 3–4 day sailings. Follow up needed.

---

## Execution Rules

🔴 **NEVER report a failure without trying at least 3 times first.** Iterate, debug, adjust — then report if still stuck. (Franchiz mandate, March 13)

---

## Creative Production Rules

🔴 **After every research cycle: produce minimum 3–5 creatives. No exceptions.** (Franchiz mandate, March 12)

---

## UGC Video Standards [verified: 2026-03-20]

🔴 Max 25-30 seconds — previous ones were too long (30-40s)
🔴 HeyGen speed: 1.1–1.2x always
🟡 5-part structure: Hook (3s) → Problem (5-7s) → Solution (5-7s) → Proof (5-7s) → CTA (3s)
🟡 Hook must identify specific pain in 3 seconds for cold traffic
🟡 90% B-roll, 10% talking head for best performance
🟡 Tone: raw/personal, NOT polished or preachy — "like texting a friend"
🟡 Script parser strips timing markers [0-3s] before sending to HeyGen API
🟡 Transformation video concept approved: no dialogue, body language only, anxiety-reward.mp4 (before) + woman-peaceful.mp4 (after)

## Funnel Status [verified: 2026-03-20]

🔴 Full funnel aligned March 19 — ads/onboarding/paywall all anxiety-first messaging
🔴 Paywall live: "Start Your Morning with Peace, Not Anxiety" + Marcus T. testimonial above fold + 7-day trial CTA
🔴 Onboarding live: 9 steps (was 11), slides 1-3 + pre-paywall rewritten for anxiety audience
🔴 App Store Connect + RevenueCat: STILL NEEDS 3→7 day trial update (code says 7, product still 3)
🟡 Key funnel metric to watch: paywall_dismissed was 57% — should drop with new copy
🟡 Cost per trial: $16.32 (target: $10) — gap to close via funnel optimization

## Standing Instruction — Research Slideshows

🔴 **SLIDESHOW RULE (Franchiz mandate, March 25):** Every time research produces a learning/insight, create a 5-7 slide slideshow for EACH one. Started with March 21 virality research batch. Apply to:
- Daily Virality Research (each video/article finding = 1 slideshow)
- Optimizer agent findings
- Ad research insights
- Any other structured research output

## Content Standards

🔴 Declarations: 5th grade reading level (Franchiz mandate, March 5–6)
🟡 FK Grade ~5.0: avg sentence ≤15 words, 1-2 syllable words, active voice
🔴 Devotionals full rewrite: branch `content/devotionals-rewrite`, file `SpeakLife/Preview Content/AffirmationData/devotionals.json` — 30-50/session batches, same quality bar as declarations
🟡 Git convention: `content/<description>-<date>` | never commit to engineering branches | always branch off main

---

## Ads & Creative Rules

🟡 Kill rule: ad set with $50+ spend and 0 installs → kill
🟡 Flag rule: CTR < 1% → flag
🟡 Scale rule: CPI < $2 AND 10+ installs → +20% budget
🟡 No emoji/special unicode in canvas text — Montserrat doesn't render them (shows as squares)
🟡 Video pipeline: render-hype-v3.mjs (canvas + ffmpeg, NOT Remotion — requires Chrome not in sandbox)
🟡 All footage must pass modesty check before use

### Blacklisted Footage
🔴 `IMG_8235` (c6) — revealing clothing, not brand appropriate
🔴 `IMG_0585` (c0) — pre-rendered short, text burned in (3.6MB vs ~550KB raw)
⚪ `c7`, `c8` — may have baked text, needs verification before use

### Music Library
🟡 `speaklife/studio/public/music/LIBRARY.json` — 5 tracks tagged by mood/use case
🟡 No music = default for most ad types

---

## Key Files

🟡 Workspace: /home/node/.openclaw/workspace/speaklife/
🟡 Ads playbook: /home/node/.openclaw/workspace/speaklife-facebook-ads-master-playbook.md
🟡 Ad testing framework: /home/node/.openclaw/workspace/speaklife/AD_TESTING_FRAMEWORK.md
🟡 Learnings: /home/node/.openclaw/workspace/speaklife/LEARNINGS.md
🟡 Growth tracker: /home/node/.openclaw/workspace/speaklife/GROWTH_TRACKER.md
🟡 Brand guide: /home/node/.openclaw/workspace/speaklife/BRAND.md
🟡 Content pillars: /home/node/.openclaw/workspace/speaklife/PILLARS.md

---

## Corrections Log

> Things that were wrong and got fixed. These carry the highest retrieval priority.

🟠 **FB Token Blocker (was: "token expired")** — CORRECTED 2026-03-06
  - ❌ WRONG: Assumed the blocker was an expired/missing token
  - ✅ RIGHT: Token is stored and valid (never-expiring System User token, has ads_management + ads_read). The actual blocker is that the System User isn't granted access to the correct ad account (`act_253451158661796`). Different fix entirely.

🟠 **CTA star emoji rendering** — CORRECTED 2026-03-06
  - ❌ WRONG: Used ★ in canvas text
  - ✅ RIGHT: Renders as a square. Use ASCII only — e.g., "Rated 4.9/5" not "★ 4.9"

🟠 **BRAND.md / PILLARS.md / SCOUT.md** — CORRECTED 2026-03-06
  - ❌ WRONG: Assumed these files existed (referenced everywhere)
  - ✅ RIGHT: They were never actually written to disk. Created them from scratch March 6.

🟠 **Logo size for ads** — CORRECTED (many iterations)
  - ❌ WRONG: Various sizes tried
  - ✅ RIGHT: 140px — locked in after multiple iterations

🟠 **Telegram topic sends** — CORRECTED
  - ❌ WRONG: Used message tool
  - ✅ RIGHT: Direct Bot API curl for topic sends (message tool doesn't route to topics correctly)

---

## Crypto Training Program

🔴 Daily reports: **DISABLED** (Franchiz request, March 20 2026) — cron ID: b984e0cb-0d84-4cf0-9137-f3a1fb704821
🔴 Goal: build expertise internally — will deliver insights when Franchiz is ready to invest
🟡 Topics rotating: TA, chart patterns, volume, risk mgmt, order types, psychology, liquidations, funding rates

---

## Meta-Memory Notes (2026-03-07)

🟡 Memory restructured to use weighted categories (inspired by memelord/Turso blog post)
🟡 Key principle: USER_INPUT > CORRECTIONS > INSIGHTS > ASSUMPTIONS
🟡 Time-sensitive entries tagged with [verified: date] — re-verify periodically
🟡 Corrections log added — highest retrieval priority when repeating similar tasks
