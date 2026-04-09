# SpeakLife Marketing System

Inspired by Greg Isenberg's "AI Marketing Masterclass" — a stacked skills + MCP system for running SpeakLife growth operations.

---

## Skills Library

These are instruction manuals for the AI agent. Open the relevant skill before starting any task.

| Skill | When to Use |
|-------|-------------|
| `ORCHESTRATOR.md` | Start here every session — tells you what to do next |
| `POSITIONING_ANGLES.md` | Finding the emotional hook for new campaigns |
| `AD_ANGLE_DISCOVERY.md` | Writing ad briefs, hooks, and creative direction |
| `DECLARATION_COPYWRITING.md` | Writing new app declarations (5th grade level) |
| `APP_STORE_OPTIMIZATION.md` | ASO audits, keyword research, review responses |
| `PERPLEXITY_RESEARCH.md` | Audience + competitive research before any creative work |

---

## Competitive Monitor

Daily automated scraper that tracks:
- App Store ratings for SpeakLife, Hallow, YouVersion, Abide
- Competitor pricing changes
- New feature signals

### Setup

```bash
cd competitive-monitor
cp .env.example .env
# Add your FIRECRAWL_API_KEY to .env
npm install
node monitor.mjs
```

### Add FIRECRAWL_API_KEY

Once Franchiz provides the Firecrawl API key:
1. Add it to `competitive-monitor/.env`
2. Also add to `/home/node/.openclaw/workspace/speaklife/.env`
3. Run `npm install` in the monitor directory
4. Test with `node monitor.mjs`
5. Schedule as cron (daily 9am BRT / 12pm UTC)

---

## Workflow

```
PERPLEXITY_RESEARCH (1hr)
    ↓
POSITIONING_ANGLES (identify top 2 angles)
    ↓
AD_ANGLE_DISCOVERY (write 6 briefs)
    ↓
Production (video/static)
    ↓
Launch → monitor → kill/scale
```

---

## Daily Routine

1. Run ORCHESTRATOR → get today's priority
2. Check competitive monitor digest (auto-delivered daily)
3. Execute highest-leverage task
4. Log results in GROWTH_TRACKER.md
