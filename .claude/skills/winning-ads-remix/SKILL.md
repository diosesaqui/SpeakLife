---
name: winning-ads-remix
description: Find Facebook/Instagram ads that are clearly working for other faith and wellness apps (Abide, Hallow, Glorify, Theo, Calm and others) in the Meta Ad Library, work out WHY they work (format, hook, structure), and turn each proven pattern into a new SpeakLife ad built with our own words, verses and renderers. Logs every find to a swipe file. Use when asked to "look at what's working on Facebook", "check competitor ads", "find winning ads", "what is Abide/Hallow/Calm running", "make ads like this one", "remix this ad", "swipe file", "ad library research", or when the weekly check-in needs fresh angles. Only remixes ads that have run at least 14 days (videos and statics).
---

# Winning Ads Remix

**The idea.** The Ad Library shows every live ad, and long-running ads are the ones paying for
themselves: nobody keeps an ad on for months that loses money. We borrow the *pattern* (format,
hook shape, structure, pacing, end card), never the words or the footage, and rebuild it around
what only SpeakLife does: **speaking God's promises out loud**, not just praying or listening.
This is how the Abide scroll ad (SL-SCROLL-01) and the Calm credits ad (SL-CREDITS-01,
SL-PROMISE-01) were made on 2026-10-27.

## 1 · Where to look

Competitor pages (Ad Library page IDs, found 2026-10-27):

| Page | ID | Why watch |
|---|---|---|
| Abide from Guideposts | 504181156368650 | Christian meditation, text-over-nature video |
| Hallow | 531203563996048 | Biggest Christian app spender, many variants per idea |
| Glorify | 100547544858805 | Devotional app |
| Theo: Prayer & Meditation | 585662371287217 | Family/kids prayer, launches 20+ variants per idea |
| Women's Bible: Verse & Prayer | 608953965637061 | Women persona, same buyer as ours |
| Perfect Prayer | 397300820128446 | "Still feel distant from God?" angles |
| Olive & Cross | 1416385404891346 | Faith app, "Try free" CTA |

Calm, Pray.com and YouVersion: the keyword search returns noise for them. Find their page in the
Ad Library website search box (type the advertiser name, pick the page) and add the ID here.
New pages: run `ads_library_search` (Meta Ads MCP) with terms like "Bible app", "prayer app",
"Christian meditation", "devotional", country US, ACTIVE, and note any faith app page that shows
many ads. Add it to this table.

## 2 · Find the proven ads

The API (`ads_library_search`) returns page, title, start date and a link, **not** the ad text or
video, and lists newest first. So read the ads in the built-in browser:

```
https://www.facebook.com/ads/library/?active_status=active&ad_type=all&country=US&search_type=page&view_all_page_id=<PAGE_ID>&sort_data[mode]=total_impressions&sort_data[direction]=desc
```

That view is **sorted by impressions** (most-shown first) and needs no login. `get_page_text`
returns each ad's text, "Started running on <date>" and "This ad has multiple versions". Take a
screenshot to see the visual. Click "See ad details" for a single ad if needed.

An ad counts as **proven** only when ALL of these hold (videos and statics alike):
- **"Started running on" is at least 14 days ago** and it is still Active. This is the hard
  rule set by the owner: anything younger is a test, not a winner, however high it ranks.
- It is in that page's **top 10 by impressions**.

Extra confidence (note it, not required): running 30+ days, or the same hook/creative appears as
many copies or "multiple versions" (they are scaling it).

Ads under 14 days old that rank high: log them as "watch" with their start date and re-check
once they pass 14 days. Never remix a "watch" ad.

Look at both **videos and statics** (images and carousels). Use the Ad Library's media type
filter (`&media_type=video` or `&media_type=image` in the URL) to check each separately.
Keep it light: at most 8 pages and their top 10 per run. This is research, not scraping.

## 3 · Name the pattern (not the words)

For each proven ad write down:
- **Format:** text over nature video, scrolling credits, review cards, talking head/UGC, carousel,
  static quote, app screen demo, kid/family scene.
- **Hook shape:** question ("Still feel distant from God?"), callout ("If you're raising a Catholic
  kid"), number ("30 Bible stories"), moment ("Two minutes tonight"), relief ("Asleep in 9 minutes").
- **Structure:** hook → problem moment → what the app gives → proof → CTA; length; on-screen text
  vs voice; music/ambience; end card.
- **Why it works**, in one line (who it calls out, what it promises, why someone stops).

## 4 · Remix it for SpeakLife

- Keep the format and hook *shape*. Write new words. Swap the competitor's promise for ours:
  God's promises spoken out loud over a specific area (mind, body, money, home, fear, grief).
- Pick the persona and `ob=` onboarding code with `speaklife-personas`, and the copy formula with
  `faith-ad-formulas`. Name the ad `F{n}-{formula}-{persona}-{L|S}-{ob}` plus `-remix-<source>`.
- Copy rules (same as every SpeakLife ad): Meta personal attributes, never "you + a condition";
  phrase as moments ("When fear gets loud"). No outcome claims; quote what Scripture promises
  and note the verse. Never knock prayer ("Keep praying. Start speaking."). Plain words, no dashes.
  Any on-screen declaration follows CLAUDE.md declaration rules.
- **Never copy:** their exact lines, footage, music, characters, logos, app screens, or name.
  Never mention a competitor in our ad. Use our own theme backgrounds, our app audio artwork,
  our verses.

## 5 · Build it

| Their format | Our tool |
|---|---|
| Text over nature video (Abide) | `docs/creative/videos/2026-10-26-scroll-ad/render.py` |
| Scrolling credits + player card (Calm) | `render_credits.py` (add a new `--<name>` variant like `--promise`) |
| Hook + review cards | `render_pain.py` (reviews must be real App Store reviews, verbatim) |
| Talking head / FaceTime UGC | `speaklife-video-ads` (costs Higgsfield credits; say the cost first) |
| Static image | `speaklife-static-ads` |
| Carousel / slideshow | `speaklife-cinematic-slideshows`, `speaklife-format-slideshows` |

Backgrounds: `SpeakLife/SpeakLife/Assets.xcassets/themes`. Always look at a still before the
full render. Copy goes in the batch's `COPY.md`.

## 6 · Log and hand off

Add one entry per proven ad to `docs/creative/SWIPE_FILE.md` (create it if missing; newest on
top):

```
## <date> · <Page> · Library ID <id>
Running since <date> (<n> days, must be ≥ 14) · video or static · top-<k> by impressions · <multiple versions?>
Format: … · Hook: "<their hook, quoted short>" · Why it works: …
Our remix: <ad name> · status: idea / built / live (<Meta ad id>)
```

Then either:
- **Weekly check-in:** put 1-2 remixes in the top entry of `docs/creative/WEEKLY_BRIEF.md` for
  the daily job to build; or
- **When asked directly:** build it, send the video to the user, and upload/launch only as the
  user says (the daily job's standing rules cover launches into "new pack").

Results feed back: when a remix wins or loses, note it in `docs/creative/LEARNINGS.md` with its
source pattern, so we learn which competitor patterns transfer to SpeakLife.
