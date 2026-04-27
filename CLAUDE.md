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

### 7. JSON Structure (never change these field names)
```json
{
  "text": "Declaration text here.",
  "bibleVerseText": "Exact scripture quote (NIV preferred).",
  "book": "Book Chapter:Verse",
  "category": "categoryname"
}
```

### 8. Declaration Count
Do not reduce the count of any category. If you replace a declaration, the total number stays the same.

---

## File Location
`SpeakLife/Preview Content/AffirmationData/declarationsv10.json`

## Development Branch
Always develop on `claude/review-destiny-declarations-gVBrT` and push there.
