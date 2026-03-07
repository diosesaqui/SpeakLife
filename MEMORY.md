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

## Active Systems [verified: 2026-03-07]

🟡 4 FB campaigns live (~$70/day total) — running but monitored blind (see blocker below)
🟡 Daily content cron: 7am BRT — Scout + Copywriter → 3 slideshows, static ads
🟡 Pillar rotation: Identity → Grace → Anxiety/Fear → Love → Health (day-of-year % 5)
🟡 Ad static formats: S1 (carousel hook) ✅, S2 (quote card) ✅, S5 (social proof) ✅ | S3 (before/after) ❌, S4 (screenshot) ❌
🟡 HeyGen UGC system: live (API key in memory/2026-03-04.md)
🟡 EOD report cron: 1am UTC daily (cron ID: 513e1f85)
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

🔴 **BLOCKER #1 (Critical, 4x escalated):** Business Manager → System Users → "Telegram" → Add ad account `act_253451158661796`
  - System User ID: 122101851087260725 — has token + permissions but NOT on the right ad account
  - Impact: $210+ spent with zero performance oversight (started March 5)
  - System User currently only has access to: act_967944814851435 (old/paused)

🔴 **BLOCKER #2:** App screen recording footage — unblocks S4 ad format + V3 demo video

🔴 **BLOCKER #3:** RevenueCat/Stripe access — need real MRR + subscriber count

🔴 **BLOCKER #4:** Firestore email list export → Meta (seeds LAL campaign)

🔴 **BLOCKER #5:** Pexels API key is invalid (returns 401) — old key: `ewE8arkiYx39plxUBwQvaAd0mowXOp0wnn`. Needs fresh key from pexels.com/api

🔴 **PENDING (Franchiz requested, March 6):** Cheap weekend cruises from Miami, April or May 2026, 3–4 day sailings. Follow up needed.

---

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

🔴 Daily crypto research + report at 9pm Eastern (cron ID: b984e0cb-0d84-4cf0-9137-f3a1fb704821)
🔴 Goal: build expertise so Franchiz can trade live when ready
🟡 Topics rotating: TA, chart patterns, volume, risk mgmt, order types, psychology, liquidations, funding rates

---

## Meta-Memory Notes (2026-03-07)

🟡 Memory restructured to use weighted categories (inspired by memelord/Turso blog post)
🟡 Key principle: USER_INPUT > CORRECTIONS > INSIGHTS > ASSUMPTIONS
🟡 Time-sensitive entries tagged with [verified: date] — re-verify periodically
🟡 Corrections log added — highest retrieval priority when repeating similar tasks
