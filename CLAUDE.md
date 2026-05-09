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
- Short, punchy sentences carry more weight than long compound ones.
- Avoid filler phrases. Every word must earn its place.
- Never end on a weak trailing clause: "...and I walk in it." / "...and I receive it fully." / "...and I stand in that truth." These bleed the power out of a strong sentence. Cut them or make them the full sentence.

### 7. No Dashes
Never use em dashes (—) or en dashes (–) in declaration text. They create run-on compound thoughts. Break into two clean sentences instead.
- ❌ "God's banner over me is love—I live under His unfailing claim on my life."
- ✅ "God's banner over me is love. I live under His unfailing, unbreakable claim on my life."

### 8. Vocabulary Depth
Language must be spiritually rich, resonant, and precise. Declarations should feel weighty and specific — not flat or generic.
- ❌ "God loves me and things are good." → flat
- ✅ Words that carry weight: *rooted, sealed, unshakeable, commissioned, anchored, redeemed, established, radiant, dwelling*
- Each declaration should feel like it cost something to write.

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

### 11. Brevity and Sentence Economy
**2 sentences is ideal. 3 is the maximum. Never 4+.**

Every sentence must declare a distinct truth. If two sentences say the same thing in different words, cut one.

Never write setup or explanation sentences — declarations assert, they do not explain.

The final sentence must be the most powerful. It is the landing punch, not a trailing thought.

**Bad patterns (cut these):**
- Explanatory clauses: "He bore my suffering *so I do not carry it alone*." → the "so" explains; just declare
- Restatements: "His power is in me. I carry it. It lives in me." → three sentences, one truth
- Weak endings: "...and I walk in that." / "...and I receive it fully." / "...His power is mine."
- Four-sentence declarations where two would be twice as strong

**Examples of the problem and the fix:**
- ❌ "I fix my eyes on the Healer, not the sickness. What I focus on fills my whole body. I am filled with His light and His life and I thrive in His presence."
  → Sentence 2 explains sentence 1. Sentence 3 is weak.
- ✅ "I fix my eyes on the Healer, not the sickness. I am filled with His light and His life."

- ❌ "Jesus took up my pain on purpose. He bore my suffering so I do not carry it alone. His healing power is not distant. It is IN me, active and thorough."
  → 4 sentences. Sentences 1–2 say the same thing. Sentences 3–4 say the same thing.
- ✅ "Jesus bore my pain at the cross. His healing power is active in me right now."

- ❌ "I am diligent in all I do and my hands produce abundance. Diligence is my consecrated work ethic and it yields increase."
  → Both sentences say: diligence produces results.
- ✅ "I am diligent in all I do. My hands are anointed and what I build stands."

---

## File Location
`SpeakLife/Preview Content/AffirmationData/declarationsv10.json`

## Development Branch
Always develop on `claude/review-destiny-declarations-gVBrT` and push there.
