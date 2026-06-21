# SpeakLife — Project Rules for Claude

## Declaration Writing Rules

All declarations in `declarationsv10.json` must follow these rules without exception.

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
- **Engage the senses and the stakes.** Use concrete, vivid, embodied language over abstract theology. Name what is at war and what is won. Let the speaker feel the weight of the promise, not just read it.
- ❌ "God is able to help me with my health." → flat, forgettable, apathy-inducing.
- ✅ "Sickness has no claim on this body. I am bought, healed, and untouchable in Christ." → stirs defiance and assurance.

This rule works with Rules 6 and 8, not against them: power and vocabulary are the tools; *making the speaker feel something* is the goal.

### 12. Command and Triumph (Authority, Not Confession)
A declaration is an exercise of authority, not a journal entry or a prayer of resignation. The speaker rules over the body, the circumstance, and the feeling. Never the reverse.

- **Command the problem out; call the solution forward.** Speak to the pain, sickness, fear, or lack and command it to stop. Speak the healing, peace, provision, or breakthrough forward into the actual situation.
- **Truth triumphs LOUDLY over feeling.** You may name a symptom, fear, or feeling ONLY to overrule it. Never validate it, never let it stand, never end the line on it. The promise gets the last word, every time.
- **Declare the concrete outcome over the real thing.** Renewal is declared over *my body*, provision over *my finances*, peace over *my mind*. Not a vague "something inside."
- **Break the formula and name the stakes.** Vary the structure so no two lines march to the same cadence. Name the real war (the diagnosis, the dread, the empty account) only to put it under the speaker's feet.
- ❌ "Some days my heart feels like it is giving out, and I say so honestly. But God is my strength." → concedes the feeling and lets it stand.
- ✅ "Let my flesh say whatever it wants. The truth is louder. God is the strength of my heart, and what He holds does not fail." → names the feeling, then triumphs over it.

This rule governs Rule 11: the emotion we trigger is the emotion of victory and authority, never resignation.

### 13. Brevity Is Potency (Cut to the Bone)
Potency comes from compression. A declaration should hit like a hammer, not unfold like a paragraph. The longer it runs, the more the power leaks out before it lands.

- **One or two sentences. Aim for under ~18 words.** Three sentences is a warning sign, not a target. If a third sentence exists, it is almost always fat: cut it or fold it into the line.
- **Never say the same truth twice.** The most common leak is a closing sentence that just rephrases the one before it ("My footing does not depend on my grip. It depends on His."). Keep the stronger half and delete the rest.
- **Land the image and stop.** Do not explain the metaphor after it hits. Trust the line to do its work in the speaker's chest.
- **Every word earns its place or dies.** Strip filler, throat-clearing, and connective padding. If removing a word does not change the meaning, remove it.
- ❌ "Grace keeps me firm to the very end. I will stand blameless on the day of my Lord Jesus Christ, held by His hand. My footing does not depend on my grip. It depends on His." → 36 words; the last two sentences merely restate the first.
- ✅ "Grace holds me blameless to the end. My standing rests on His grip, not mine." → same truth, half the words, twice the force.

This rule sharpens Rules 6 and 12: still command, still triumph, but in the fewest words that land the blow. When brevity and completeness conflict, brevity wins.

---

## File Location
`SpeakLife/SpeakLife/Preview Content/AffirmationData/declarationsv10.json`
(This is the copy the Xcode target bundles, per `DEVELOPMENT_ASSET_PATHS` and the
project's Resources build phase. Edit THIS file. Do not recreate the old
single-nested `SpeakLife/Preview Content/...` copy, which the build never used.)

## Development Branch
Always develop on `claude/review-destiny-declarations-gVBrT` and push there.
