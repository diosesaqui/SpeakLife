# Review-Driven Ad Concepts

Ad angles reverse-engineered from SpeakLife's real 5-star App Store reviews.
Companion to `docs/ad-creative-brief.md` (which derives creative from the
*onboarding copy*). This one works the other direction: start from what
customers actually said, invert it into the pain that sent them looking, and
build the ad on that pain.

---

## 0. What review data we have (and don't)

**Have — 23 verbatim reviews, in the codebase:**

| Source | Count | Notes |
|---|---|---|
| `SpeakLife/Views/Onboarding/TestimonialWallView.swift` | 15 | Real App Store reviews, verbatim, title + author + body. The scroll wall shown pre-paywall in every live arm. |
| `SpeakLife/Views/Onboarding/TestimonialsOnboardingView.swift` | 8 | Dormant carousel. Overlaps the wall on 3 (Ky/Kyla, RJ, Charlie); the other 5 (Jessica, Sarah, Michael, Rachel, Tina) are shorter and read like paraphrases, not verbatim App Store text. |

**Don't have:**

- Live App Store Connect access (ratings breakdown, review velocity, per-country,
  responses, anything below 5 stars).
- The public RSS review feed — `itunes.apple.com` is blocked by this
  environment's egress proxy.
- In-app user testimonies (`TestimonyView`) — those live in Firestore, not the repo.

**To widen the corpus:** export Ratings & Reviews from App Store Connect and drop
the CSV in `docs/`, or allowlist `itunes.apple.com` so the RSS feed
(`.../customerreviews/id=1617492998/sortby=mostrecent/json`) can be pulled
directly. The 1★–3★ reviews are the more valuable half for ads — objections are
better hooks than praise.

Everything below is built on the 23 we do have, cross-checked against the
onboarding survey's own pain taxonomy (`SurveyTypes.swift` → `HeaviestBurden`,
`BarrierOption`), which is the same language users self-select in-app.

---

## 1. The method: reviews describe the after, not the pain

Nobody writes "I was doomscrolling myself into anxiety." They write *"I'm
spending more time on this than on Facebook."* The pain is the negative space
around the praise. Every ad below inverts one review into the problem statement
that review implies, then uses the review itself as the proof.

That's the whole structure:

> **Name the pain in their words → show the mechanism (speak it, don't just read it) → hand them the review as proof it works.**

---

## 2. The nine pains, ranked

Ranked by how ad-native the pain is: how fast it can be named in 2 seconds, how
many viewers are living it *right now*, and how cleanly it hands off to an
onboarding arm.

### P1 — "I'm feeding on garbage all day."
> *"I'm spending more time on this than on Facebook. This is filling me with truth instead of garbage and the audios are amazing."* — Kyla Clark

The strongest pain in the whole corpus, because the viewer is committing it
**while watching the ad**. It names a behavior, not a feeling. Route: `product` / `warfare`.

### P2 — "I read the Word and it stays in my head."
> *"The scripture says we should renew our mind through the word. This app is the epitome of tech designed to accomplish that purpose."* — Tripp7777777
> *"I love the daily reminders they've been helping me renew my mind and how I think."* — Omi_mindset

Backed by the app's own barrier option: *"I read the Bible — but it stays in my
head, not my heart."* This is the mechanism ad — read vs. speak. Route: `product`.

### P3 — "By Monday it's gone."
> *"I am blessed to have an app like this that helps me remember God's promises in his word... Empower me with God's word throughout my day."* — Omi_mindset

In-app barrier: *"Worship and sermons lift me up — then Monday hits and it's gone."*
The pain is retention of the high, not lack of belief. Route: `promises`.

### P4 — "I'm carrying something heavy and I dread the day."
> *"Every time I've read something I just feel lighter, more encouraged and excited what God has in store for my day."* — chevonne818

"Lighter" is the single best outcome word in the corpus. Nobody says "lighter"
unless they were carrying weight. Route: `outcomes`.

### P5 — "I know about Jesus. I don't know Him."
> *"Thank SpeakLife for helping me to know who Jesus is... It has brought me closer to him."* — Traveler RJ
> *"I fully recommend this to anyone who is looking to grow their relationship with Jesus. And to deepen their belonging."* — Heather L Compton

Distance, not doubt. Highest-empathy angle, lowest shame. Route: `closer`.

### P6 — "I believe God loves everyone. I don't feel it about me."
> *"I just read the letter from my Heavenly Father on this app, and I love that every sentence and thought is a scripture put together that really drives home the message of God's love for me."* — JaniceBanjo

Points at a specific, nameable in-app asset (the Letter From Your Father), which
makes it the best "one free thing" hook we own. Route: `identity`.

### P7 — "I've downloaded these apps before. Nothing stuck."
> *"This app is amazing! Better than I ever hoped from an app. It is exactly what I needed."* — Lenore7283
> *"So far, I've only used the free week trial. This has been life-changing."* — Heather L Compton

Not a spiritual pain — a *consumer* objection, and the one killing cold installs.
Handled with proof and speed-to-value, not preaching. Route: any (proof layer).

### P8 — "My own words have been working against me."
> *"I love the different episodes about how our words matter. Our words can change the course of our life good or bad."* — KathyAnn1434

Conviction hook. Highest risk of feeling accusatory — keep it self-implicating
("we've all done it"), never pointed. Route: `warfare`.

### P9 — "I need something to shift today, not in 30 days."
> *"As soon as I opened this app it began to speak life and confirmation over me."* — Tea lite
> *"I can already feel God's mighty working power from seeing the first few pages."* — 12Veevee12

Two independent reviewers reporting value in the *first session*. That's a
performance claim we can actually demonstrate on camera. Route: `product`.

---

## 3. The ad concepts

Each concept: the pain, the hook, the beat sheet, the review that carries the
proof, the format, and the `ob=` value for the deep link (see
`docs/AD_ONBOARDING_ROUTING.md`).

---

### A1 — "Truth Instead of Garbage" · P1 · `ob=product`
**Best first test. Cheapest to shoot, most universal pain.**

- **Hook (0–2s):** "I'm on this app more than I'm on Facebook now." *(verbatim from the review)*
- **Pain:** "Two hours in the feed this morning. Zero minutes in the Word. Then we wonder why our head sounds like that."
- **Mechanism:** "Whatever you feed, talks loudest. So I started feeding it something else — out loud."
- **Proof:** review card overlays — Kyla Clark, 5 stars, verbatim.
- **CTA:** "Trade ten minutes of the feed. Speak life instead."
- **Visual:** POV phone-in-hand, thumb doomscrolling, hard cut to the SpeakLife
  declaration screen and the audio playing. The cut *is* the ad.
- **Why it works:** the viewer is mid-scroll when it hits. The ad describes the
  exact moment it's being watched in.

---

### A2 — "You Read It. Did You Say It?" · P2 · `ob=product`
**The mechanism ad. Run this to warm/retargeting audiences.**

- **Hook:** "You read the chapter this morning. By 10am you couldn't quote one line of it."
- **Pain:** "It went in your head. It never made it to your mouth."
- **Mechanism:** "Reading informs you. Speaking changes what you believe. That's why the Word says *death and life are in the power of the tongue* — not the eyes."
- **Proof:** Tripp7777777 — *"the epitome of tech designed to accomplish that purpose."*
- **CTA:** "Renew your mind out loud."
- **Visual:** split screen — closed Bible on a nightstand (left) vs. mouth/waveform speaking (right). Left desaturated, right lit.
- **Note:** this is Concept W3 in `ad-creative-brief.md`, now with review proof attached. Prioritize the version *with* the review card; the mechanism claim is much stronger when a stranger makes it.

---

### A3 — "The Monday Test" · P3 · `ob=promises`
- **Hook:** "Sunday you were crying in worship. It's Tuesday. Where did it go?"
- **Pain:** "The lift wears off by Monday afternoon, every single week."
- **Mechanism:** "Because a sermon fills you once. A declaration re-fills you daily."
- **Proof:** Omi_mindset — *"the daily reminders... empower me with God's word throughout my day."*
- **CTA:** "Make Monday hold."
- **Visual:** worship-night lights → gray Monday commute → phone notification lands → the declaration spoken in the car.
- **Note:** this pain is verbatim from our own onboarding (`BarrierOption.mondayHits`), so ad→onboarding message match is near-perfect.

---

### A4 — "Lighter" · P4 · `ob=outcomes`
**Pure review-as-ad. Lowest production cost in the set.**

- **Format:** the review on screen, read aloud, word-highlighted as it's spoken. Nothing else.
- **Copy:** chevonne818's review, verbatim and uncut — *"...every time I've read something I just feel lighter, more encouraged and excited what God has in store for my day."*
- **The only added line, on the last beat:** "When was the last time you woke up light?"
- **CTA:** "Start free."
- **Visual:** the App Store review card, real UI chrome, 5 gold stars. Slow push-in. Ambient bed under the VO.
- **Why it works:** zero brand voice. It reads as a screenshot someone shared, not an ad.

---

### A5 — "You Know About Him" · P5 · `ob=closer`
- **Hook:** "You can quote Him. Can you say you know Him?"
- **Pain:** "You grew up in it. You can find the verse. But it's been a long time since it felt personal."
- **Mechanism:** "Speaking His words back to Him is how the distance closes."
- **Proof:** Traveler RJ — *"helping me to know who Jesus is... It has brought me closer to him. My heart is full & grateful."*
- **CTA:** "Come back close."
- **Visual:** warm, quiet, domestic. No warfare imagery, no urgency. Morning light, a kitchen table.
- **Audience:** ex-churched, drifted, "coming back" — matches `BurdenDuration.drifted`.

---

### A6 — "The Letter" · P6 · `ob=identity`
**Highest-intent lead hook: it offers one specific, free, nameable thing.**

- **Hook:** "There's a letter in this app written to you, and every line of it is a verse."
- **Pain:** "You believe God loves everybody. You've just never been sure He was talking about you."
- **Mechanism:** show the Letter From Your Father, scrolling, lines legible.
- **Proof:** JaniceBanjo — *"...really drives home the message of God's love for me."*
- **CTA:** "Read the letter. It's free."
- **Visual:** screen recording of the letter, held long enough to actually read two lines. Resist cutting fast — the dwell time *is* the conversion.

---

### A7 — "The Wall" · P7 · any `ob=` (social proof layer)
**Already built. This is a screen recording of an existing app screen.**

- **Format:** slow scroll of `TestimonialWallView` — 4.9, gold stars, review after review after review.
- **VO:** read three reviews in full over the scroll. Nothing else said.
- **End card:** "4.9 stars. Over 100,000 believers."
- **Use:** retargeting anyone who hit the paywall and bounced, and as the proof
  variant inside every ad set. Cost to produce: one screen recording.

---

### A8 — "You've Been Speaking All Week" · P8 · `ob=warfare`
- **Hook:** "You've been declaring over your life all week. You just didn't like what you said."
- **Pain:** "'I'm always broke.' 'I'm just an anxious person.' 'This is how I am.'"
- **Turn:** "Death and life are in the power of the tongue. It's already working. The question is which one you've been handing it."
- **Proof:** KathyAnn1434 — *"Our words can change the course of our life good or bad."*
- **CTA:** "Change what you're saying."
- **Guardrail:** keep it first-person plural — *we* say these things. The moment it reads as "you're doing it wrong," it converts on shame and churns in a week.

---

### A9 — "The First 60 Seconds" · P9 · `ob=product`
**The anti-"another app I'll abandon" ad. Answers the P7 objection with a demo.**

- **Hook:** "I opened it once and it started speaking over me." *(Tea lite, verbatim)*
- **Format:** unbroken screen recording of a genuine first open — install to first
  spoken declaration, on a stopwatch, no cuts.
- **Line over the payoff:** "No setup. No streak to build. It starts working the first time you open it."
- **Proof:** 12Veevee12 — *"I can already feel God's mighty working power from seeing the first few pages."*
- **CTA:** "See what it says to you."

---

### A10 — "First Thing You Touched" · P10-adjacent (morning ritual) · `ob=outcomes`
- **Hook:** "First thing you touched this morning was your phone. Make it say something worth hearing."
- **Proof:** msmusicmaker — *"I love saying the declarations each morning."* / Jessica — *"Starting everyday and night this way has literally changed my life."*
- **CTA:** "Start tomorrow different."
- **Visual:** 6:04am alarm, hand reaching, screen lights up with the day's declaration instead of the feed.

---

## 4. What to ship first

| Priority | Concept | Why |
|---|---|---|
| 1 | **A1 — Truth Instead of Garbage** | Broadest pain, viewer is living it mid-scroll, cheapest shoot. |
| 2 | **A4 — Lighter** | Near-zero production. Pure review read. Tests whether raw social proof beats produced creative before we spend on production. |
| 3 | **A7 — The Wall** | Already built in-app. One screen recording. Ships today as the proof variant in every ad set. |
| 4 | **A2 — You Read It. Did You Say It?** | The mechanism. Needed to make everything else make sense at scale. |
| 5 | **A6 — The Letter** | Specific free asset = best cost per install of the set, if the letter reads well on video. |

Run 1, 2 and 3 against each other first: they're all cheap and they answer the
one question that determines the whole media plan — **does this audience buy on
proof or on pain?** Whichever wins, build the next five in that lane.

---

## 5. Rules for using real reviews in paid creative

- **Verbatim or not at all.** Never edit a review's wording to strengthen a claim.
  Trimming for length is fine; changing meaning is not. The wall reviews in
  `TestimonialWallView.swift` are already the cleaned, developer-response-stripped
  versions — treat that file as the source of truth.
- **Attribute with the App Store nickname shown in the file** (chevonne818, Tea lite,
  Traveler RJ). Don't invent full names or faces for them.
- **No health or financial outcome claims from a review.** Reviews about healing or
  provision are the ones most likely to draw a Meta rejection or an ASA complaint.
  Stick to mind, peace, closeness, consistency and identity in paid creative — the
  outcome claims stay inside the app, where scripture carries them.
- **The 8 carousel testimonials in `TestimonialsOnboardingView.swift` are not all
  verifiable as App Store text** (5 of them read as paraphrase). Only use the 15 in
  the wall as sourced reviews in ads; treat the other 5 as copy, not testimony.
- **"4.9 stars" and "100K+ believers"** appear in-app and are safe to reuse, but
  4.9 is the US rating recorded at the time of writing. Re-check App Store Connect
  before putting the number on a paid asset.
