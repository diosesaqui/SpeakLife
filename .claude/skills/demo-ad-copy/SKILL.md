---
name: demo-ad-copy
description: Write high-intent Meta ad copy (primary text, headlines, description, CTA) for a SpeakLife product demo or feature video, aimed at buyers who already want to speak life, walk in authority and grow their faith daily. Use when the user has a demo/feature video (journal, declarations, audio, burst, devotional, etc.), says "write copy for my demo ad", "high intent copy", "bottom of funnel copy", "rewrite her copy for the X feature", or wants ad text that sells a feature rather than teaching the pray-vs-speak idea. For cold, problem-aware traffic use the speaklife-ad-primary-text skill instead.
---

# SpeakLife Demo Ad Copy (High-Intent)

A demo video is shown to people who already believe in speaking God's Word. They do not need the
idea sold to them. They need to see the tool, believe it works for them, and feel it costs almost
nothing to start. This skill writes for that buyer.

## When to use this vs. the six-beat spine

| Audience | Awareness (Schwartz) | Skill |
|---|---|---|
| Cold, feels the battle, never heard of declaring | Problem aware | `speaklife-ad-primary-text` (six beats, app named late) |
| Already speaks life / wants authority / wants daily growth, watching a demo | Product or most aware | **this skill** (app named in line 1–2) |

If unsure, ask what the video shows. A screen recording of the app = this skill.

## The DNA (research-grounded)

1. **Match awareness (Eugene Schwartz, *Breakthrough Advertising*).** For the most-aware buyer the ad
   needs little more than the product name and the offer. So name SpeakLife in the first two lines
   and cut the pray-vs-speak teaching.
2. **Channel desire, don't create it (Schwartz).** The desire to walk in authority and grow daily
   already exists. Say it back in their words, then point it at the feature.
3. **Value equation (Alex Hormozi).** Value = (dream outcome × perceived likelihood) ÷ (time delay ×
   effort). Most copy only sells the outcome. Work the other three:
   - **Likelihood:** real proof only (rating, review count, real review, "every one rooted in a verse").
   - **Time:** "60 seconds", "tonight", "first thing in the morning".
   - **Effort:** "already written for you", "just talk", "no blank page", "open it and speak".
4. **Video app-install practice (Meta).** Value lands in the first 2 to 3 seconds; the best demos open
   inside the app. The caption supports the video, it does not retell it. Every line should map to
   something visible on screen, and the first line should match the video's opening beat.
5. **Scripture carries the promise, not the app.** Payoff lands on a verse, quoted accurately with
   its reference.

## Workflow

1. **Get the inputs.** Which feature, what the first 3 seconds show, and any existing draft (if the
   user says "she wrote one", ask them to paste it; never pretend to have it). Also ask for real
   proof: App Store rating, review count, user count, or 2 to 3 real reviews.
2. **Verify the feature in code before describing it.** Grep the repo (`SpeakLife/SpeakLife/Views/…`)
   for the feature and use its real prompts, labels and behavior. Never claim a capability the code
   doesn't show. Example facts found this way for the journal: opens on "What is God showing you
   today?", subtitle "He's listening to every word", voice input transcribes as you talk, entries
   save, "Open Journal →" appears as a daily task.
3. **Position the feature against speaking.** Speaking the Word is the core. Supporting features
   (journal, audio, devotional) are sold as part of the daily rhythm around speaking, never as equal
   substitutes for it (the onboarding was deliberately changed for this reason). Features competitors
   also offer (e.g. journaling) must be framed through what only SpeakLife pairs them with.
4. **Write three variants**, one per angle, 4 to 6 short lines each:
   - **Name + offer:** product + feature in line 1, what you do in it, why it matters, CTA.
   - **Belief + low effort:** a truth they already hold, the feature removes the friction, a verse.
   - **Daily rhythm:** where the feature sits in the day with speaking, time cost, compounding result.
5. **Write 5 headlines** (~5 words, front-load the first 25 characters, result + speed/ease, never
   repeat the button), **1 description**, and the button (**Install Now**, a dropdown).
6. **Add a proof line only if the user gave real numbers or reviews.** Otherwise say it is the
   biggest missing lever and ask for it.
7. **End by offering** to match line 1 to the video's first 3 seconds exactly.

## Guardrails (all non-negotiable)

- **Meta Personal Attributes.** Never bind "you" to a religion, health, mental-health or financial
  state ("Are you a Christian who…", "Struggling with anxiety?"). Describe the content or situation.
- **No outcome claims.** No "guaranteed", "100%", or time-bound results. No promise Scripture doesn't make.
- **No trial day counts.** Trial length is Remote Config resolved; "try it free" at most.
- **No invented proof or testimony.** Numbers and reviews come from the user or the App Store.
- **Voice:** conversational, bold, grace-based. Never *manifest · the universe · name it claim it ·
  prosperity framing*. Never sneer at prayer.
- **Format:** short lines with white space, first line works alone, one CTA ending in 👇 or 👉, no
  hashtags, no naked URLs.
- **Testing:** keep structure identical across variants so results differ by angle; tell the user to
  turn off Advantage+ text optimizations during a test. Deep-link `ob=` codes: command, healing,
  anxiety, provision, renewal (not "rewire").

## Worked example: journal feature, Variant 2

> The prayers you write down are the ones you remember He answered.
>
> SpeakLife's journal opens to one prompt: *What is God showing you today?* No blank page. No
> pressure to write well. Tap the mic and talk. Your words appear as you speak.
>
> *"Write down the revelation and make it plain"* Habakkuk 2:2.
>
> Start your first entry tonight 👉

Headline: *Speak it. Then write it down.* · Description: *Declarations + a voice journal, in one
daily rhythm.* · Button: Install Now.

Why it works: a truth they already hold (desire channeled), a real on-screen prompt (proof it's
real), "no blank page / just talk" (effort cut), "tonight" (time cut), and a verse carrying the
promise.

## Checklist before handing over

- SpeakLife named in the first two lines?
- Every feature claim verified in code?
- Feature framed around speaking, not as a substitute?
- Each variant hits likelihood, time and effort, not just outcome?
- Verse quoted accurately with reference?
- No personal-attribute phrasing, outcome claim, trial day count, or invented proof?
- Headlines don't repeat the button or each other?
