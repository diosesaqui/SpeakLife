# SpeakLife — Project Rules for Claude

## Declaration Writing Rules

All declarations in `declarationsv10.json` must follow these rules without exception.

**Why the rules are what they are.** Faith to speak it is what lets God get to
work. The declaration is not a mood, a reminder, or a nice thought to read. It is
a line someone says out loud in their own voice over their own body, marriage,
mind, or money, and the saying is the point. Every rule below serves that single
moment: first person because they are the one speaking, present tense because
faith says it done, one sentence because the mouth cannot carry a paragraph with
conviction, plain words because you cannot speak in faith a line you had to stop
and decode, and bold because a hedged sentence gives faith nothing to stand on.
A declaration the speaker cannot say with their whole chest has already failed,
however true and well-crafted it is.

### 1. First-Person Only
Every declaration must be spoken in the first person. Use **I / me / my / mine**.
- ✅ "I am walking in God's favor."
- ✅ "God has called me by name, and I am His."
- ❌ "Your steps are ordered by God." → Fix to "My steps are ordered by God."
- ❌ "You are chosen." → Fix to "I am chosen."

Exception: references to what God does toward the speaker are fine ("God knows the plans He has for *me*").

### 2. Present / Active Tense
Declarations are spoken NOW — they are not memories or future wishes.
- ✅ "I walk through fire without being burned."
- ❌ "I went through the fire and came out." → Fix to present tense.
- ❌ "I will one day fulfill my calling." → Fix to "I am fulfilling my calling."

### 3. No Duplicate Verses Within a Category
Each scripture reference (`book` field) should appear at most once per category.
- If a verse is used twice in the same category, keep the stronger declaration and replace the other with a genuinely different verse and new text.

### 4. No Near-Duplicate Text Within a Category
If two declarations convey the same truth in nearly identical language, one must be meaningfully differentiated or replaced entirely.

### 5. Category-Specific Focus
Each declaration must clearly connect to its category theme. A generic declaration that could belong to any category needs to be rewritten through the lens of that category.

### 6. Power Language
- Direct and bold. No weak qualifiers ("I think", "maybe", "I hope to").
- Short punchy sentences are powerful — use them.
- Avoid filler phrases. Every word must earn its place.
- **Never soften a promise scripture makes.** Boldness and faith are what make a declaration work at all. If the verse says it, declare it finished and say it flat. Psalm 1:3 says "whatever they do prospers", so the declaration says *"whatever I do prospers"*, not "I build steadily and well". Isaiah 53:5 says "by his wounds we are healed", so someone with cancer declares *"I am healed and this body makes a full recovery"*, not "God is able to help me".
- **The limit is the verse, never squeamishness.** The only thing that may hold a declaration back is that scripture does not actually promise it. Grief gets joy (John 16:22, Psalm 126:5). A struggling mind gets the mind of Christ (1 Corinthians 2:16). Infertility gets a full womb (Genesis 17:16, Psalm 113:9, Exodus 23:26). Do not import outside caution over a promise the Bible plainly makes.
- **Two things scripture never promises**, so declarations never claim them: that another free person will change, return, or believe, and any specific outcome no verse states. Declare God's faithfulness toward them and the speaker's own standing instead.

### 7. No Dashes
Never use em dashes (—) or en dashes (–) in declaration text. They create run-on compound thoughts. Break into two clean sentences instead.
- ❌ "God's banner over me is love—I live under His unfailing claim on my life."
- ✅ "God's banner over me is love. I live under His unfailing, unbreakable claim on my life."

### 8. Vocabulary Depth (Rich, Never Obscure)
Language must be spiritually rich, resonant, and precise. Declarations should feel weighty and specific — not flat or generic.
- **Rich but never obscure.** Choose words that carry weight AND land instantly. The speaker should never have to stop and ask what a word means. If a word feels churchy, academic, or seminary-only, cut it for a plainer word that hits just as hard.
- ❌ "God loves me and things are good." → flat
- ❌ "I will never forget His precepts." → obscure, churchy, makes the eye stall
- ✅ Words that carry weight and stay clear: *rooted, sealed, unshakeable, anchored, redeemed, radiant, dwelling, revive, breathe, broken, whole, free*
- The test: weighty on the heart, effortless on the tongue. Each declaration should feel like it cost something to write, but nothing to understand.

### 9. JSON Structure (never change these field names)
```json
{
  "text": "Declaration text here.",
  "bibleVerseText": "Exact scripture quote (NIV preferred).",
  "book": "Book Chapter:Verse",
  "category": "categoryname"
}
```

### 10. Declaration Count
Do not reduce the count of any category. If you replace a declaration, the total number stays the same.

### 11. Emotional Resonance (Never Apathy)
The one reaction a declaration must never produce is apathy. Every declaration is spoken over the speaker's own heart, and if it leaves them indifferent, it has failed — no matter how doctrinally correct it is. The eye should not be able to skim past it unmoved.

- **Make them feel something.** Each declaration must stir a real emotion: awe, courage, comfort, holy defiance, longing, joy, or gratitude that genuinely moves. Aim for the line that gives chills or steadies a shaking heart.
- **Emotion creates action.** Feeling is what moves the speaker to actually believe the Word and act on it. A declaration that only informs is dead weight; one that ignites is doing its job.
- **Engage the senses.** Use concrete, vivid, embodied language over abstract theology. Show the higher reality the speaker is stepping into, not the threat they are leaving. Let them feel the weight of the promise, not just read it.
- ❌ "God is able to help me with my health." → flat, forgettable, apathy-inducing.
- ✅ "I am healed, whole, and full of His life. This body carries the strength of Christ." → stirs assurance without naming the sickness.

This rule works with Rules 6 and 8, not against them: power and vocabulary are the tools; *making the speaker feel something* is the goal.

### 12. Call Higher (Declare the Greater Reality)
A declaration does not argue with the problem, name it, or rebuke it. It declares the higher truth that makes the problem irrelevant, and calls the speaker up into it.

- **Never name the low thing.** Do not call out worry, fear, sickness, lack, or shame, even to overrule it. Skip straight to the higher reality that displaces it. The mind ruled by Christ has no room for anxiety, so you never have to mention anxiety at all.
- **Declare exactly what is to come to pass, as already true.** Say the concrete reality the speaker is stepping into, not the thing they are leaving. Specific and scriptural, never vague.
- **Hit the exact domain.** Declare over the real place the issue lives. Anxiety is in the mind, so declare a sound mind. Sickness is in the body, provision in the finances. Name the place plainly.
- ❌ "Worry, settle down. My heart grows quiet in Him." → names the low thing, vague, wrong domain.
- ✅ "I have the mind of Christ. It is clear, sound, and at rest." → claims the higher reality, concrete, right domain.

Exception: the `warfare` category may still command the enemy directly, the way Jesus did in deliverance, because confronting the enemy is the point of that category. Everywhere else, call higher and never name the low.

Also allowed everywhere: broad scriptural umbrella-promises that declare blanket victory over *any* attack, such as "No weapon formed against me prospers." These cover everything at once without dwelling on one specific fear, so they call higher rather than name a low thing.

This replaces the old "name the war and command it out" approach: we no longer drag the problem into the light to fight it. We out-shine it.

### 13. One Sentence. No Fluff.
Potency comes from compression. A declaration should hit like a hammer, not unfold like a paragraph. The longer it runs, the more the power leaks out before it lands.

**Scope: life-situation categories only.** The 33 Bible-book categories (`psalms`, `john`, `romans`, `genesis`…) are read-through-a-book content, not lines someone speaks over their marriage or their body. `EnforcementAssembler.bookCategories` already keeps them out of campaign matching, and the longer expository style suits them. They are deliberately left at the older two-sentence standard. **Do not "fix" them** — an audit will flag ~1,200 of them and every one of those flags is a false positive.

**The enemy is the wasted word, not the period.** Read that before anything below it. New declarations are written as one sentence, and that is the right default. But an existing two-sentence line where each sentence lands its own blow is already doing the job, and joining it with a comma makes it worse, not better.

- **Write new declarations as one sentence.** 10 to 18 words. The `business` and `newSeason` sets are the reference (median 13). Ground and outcome fit in one line joined by *and* or *so*.
- **Collapse a second sentence when it restates, explains, or softens the first.** That is the actual target. If the second sentence says something the first already said, keep the stronger half and delete the rest.
- **Do NOT collapse two sentences that each land a blow.** Rule 14 governs here: short sentences win, and Jesus healed in two to seven words. Two punches beat one run-on.
  - ✅ Leave alone: "I am a new creation in Christ. The old is gone for good."
  - ❌ Do not "fix" it to: "I am a new creation in Christ, and the old is gone for good." → one word longer, one blow weaker.
- **A rewrite that adds words has failed**, whatever the sentence count says. If the new line is not shorter and not clearer, keep the original.
- **Fully intentional.** Every word is aimed. If removing a word does not change the meaning, it was fluff and it dies.
- **Land it and stop.** Do not explain the image after it hits.
- ❌ "Grace keeps me firm to the very end. I will stand blameless on the day of my Lord Jesus Christ, held by His hand. My footing does not depend on my grip. It depends on His." → 36 words, four sentences, the last three restating the first.
- ❌ "My plans are diligent, and diligent plans lead to profit. This business turns a profit." → the second sentence adds nothing the first did not already say.
- ✅ "My plans are diligent, and diligent plans lead to profit." → same truth, one sentence, nothing wasted.

**This rule was once written as a flat "one sentence, not two", and a bulk rewrite under it made 1,025 already-tight declarations longer by comma-splicing them.** The life-situation categories were never the problem: they sit at a median of 14 words. If an audit reports thousands of violations, check the word counts before rewriting anything — the count is the tell, not the period.

This rule sharpens Rules 6 and 12: still bold, still calling higher, but in the fewest words that land the blow. When brevity and completeness conflict, brevity wins.

### 14. Speak It Like Jesus (Built for the Mouth)
These are spoken out loud, with the authority Jesus carried when He healed and delivered. His words were short, direct, and final: "Be clean." "Get up." "Be opened." Write to that standard.

- **Built for the mouth, not the eye.** Every line must be easy to say out loud in one breath, with a rhythm the tongue wants to follow. Read it aloud before keeping it. If you stumble, run out of air, or hit a word you would never say in real speech, cut it.
- **Short sentences win.** Jesus healed in two to seven words. The first sentence should land the blow on its own.
- **Zero filler.** Kill "just," "really," "very," "truly," and every connective crutch. Start on the strongest word.
- **Faith speaks it done.** Say the outcome as finished and already possessed, never requested. "I have." "I am." "It is mine."

### 15. Perfectly Clear (Say What You Mean)
Every declaration must be understood instantly, the first time, by anyone. This outranks cleverness, imagery, and style.

- **If a line could make someone ask "what does that mean?", it has failed.** Rewrite it in plain words that say the exact thing.
- **No poetry, no riddles.** "I am undone," "my heart is quiet," "grace saved me with empty hands," "lit from the inside" are literary fog. Name the real thing plainly.
- **Plain beats pretty, every time.** A clear line the speaker grasps in one read does more than a beautiful one they have to decode.
- ❌ "Grace saved me with empty hands." → what does that even mean?
- ✅ "I could not earn my way to God. He saved me by grace, and I am His forever." → instantly clear.

---

## File Location
`SpeakLife/SpeakLife/Preview Content/AffirmationData/declarationsv10.json`
(This is the copy the Xcode target bundles, per `DEVELOPMENT_ASSET_PATHS` and the
project's Resources build phase. Edit THIS file. Do not recreate the old
single-nested `SpeakLife/Preview Content/...` copy, which the build never used.)

## Development Branch
Always develop on `claude/review-destiny-declarations-gVBrT` and push there.

---

## Analytics

**Read `docs/ANALYTICS_DATA_QUALITY.md` before answering any question with
PostHog numbers.** Several of the highest-volume events do not measure what
their names say, and the failure mode is silent — the query returns a clean
result that is simply wrong. Among them: a null test written as
`empty(toString(...))` always reports zero nulls; global context properties are
absent on app builds older than 4.54; simulator test traffic accounts for 88% of
audio favourites historically; `content_listened` counted pauses and seeks as
listens; and `paywall_shown` and `paywall_impression` double-count the same
impression.
