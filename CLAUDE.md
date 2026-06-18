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

---

## File Location
`SpeakLife/Preview Content/AffirmationData/declarationsv10.json`

## Development Branch
Always develop on `claude/review-destiny-declarations-gVBrT` and push there.
