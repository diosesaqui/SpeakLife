# SpeakLife Content Pillars

## The 7 Pillars (daily rotation by day of week)

| Day | Pillar | Core Declaration | Core Why |
|-----|--------|-----------------|----------|
| Monday | **Identity** | You are who God says you are | You can't speak life until you know who you are in Christ |
| Tuesday | **Health** | By His stripes you are healed | Your body should agree with what Jesus paid for |
| Wednesday | **Prosperity** | You are blessed and lack nothing | He came that you'd have life abundantly — not barely enough |
| Thursday | **Peace** | You have the peace that passes understanding | Your mouth can silence anxiety before it takes root |
| Friday | **Joy** | The joy of the Lord is your strength | Joy is a weapon, not a feeling |
| Saturday | **Boldness** | You have not been given a spirit of fear | Fear is a spirit — you were given power, love, and a sound mind |
| Sunday | **Destiny** | You were made on purpose, for a purpose | You were created with intention — speak your future into existence |

---

## Content Formula (Every Post)

Every SpeakLife post follows this 4-part structure:

```
1. THE TRUTH   → What Jesus already bought for you
2. THE WHY     → Why you must SPEAK it, not just think it
3. THE HOW     → What renewing your mind actually looks like
4. THE CLAIM   → The declaration / CTA
```

**Core "why speak life" scriptures (weave into every post):**
- Proverbs 18:21 — Death and life are in the power of the tongue
- Romans 12:2 — Be transformed by the renewing of your mind
- Mark 11:23 — Whoever *says* and does not doubt
- Philippians 4:8 — Whatever is true... *think on these things*

---

## Pillar Breakdown

### MONDAY — IDENTITY
**Core pain:** Shame. Comparison. Feeling like an imposter. "Who am I really?"
**Core truth:** You are chosen, royal, a new creation. God settled your worth before you were born.
**Why speak it:** The world has been speaking lies over your identity for years. You have to renew your mind with what God says — or the lie wins.
**Key scriptures:** Psalm 139:13-14, Ephesians 1:4-5, Jeremiah 1:5, 1 Peter 2:9, Romans 8:16-17, 2 Corinthians 5:17
**Declaration:** I am who God says I am. I am chosen, loved, and made new in Christ.

---

### TUESDAY — HEALTH
**Core pain:** Burnout. Chronic illness. Body shame. Physical exhaustion.
**Core truth:** By His stripes you were healed. Your body is His temple. Wholeness is His will.
**Why speak it:** Sickness speaks loud. You have to speak louder. What you agree with your mouth you invite into your body.
**Key scriptures:** Isaiah 53:5, 1 Peter 2:24, 3 John 1:2, Psalm 103:2-3, Matthew 8:17, James 5:16
**Declaration:** I am healed. My body is strong. I walk in divine health — spirit, soul, and body.

---

### WEDNESDAY — PROSPERITY
**Core pain:** Financial stress. Scarcity mindset. Feeling like abundance is for other people.
**Core truth:** He came that you'd have life *abundantly*. Abraham's blessing is yours. Poverty is not humility.
**Why speak it:** A scarcity mindset is renewed by a scarcity mouth. You renew it by speaking abundance until you believe it.
**Key scriptures:** John 10:10, Philippians 4:19, Deuteronomy 28:2-6, 2 Corinthians 9:8, Proverbs 10:22, Malachi 3:10
**Declaration:** I am blessed and I lack nothing. God supplies all my needs according to His riches. Abundance is my inheritance.

---

### THURSDAY — PEACE
**Core pain:** Anxiety. Overthinking. Dread. Can't sleep. Mind won't stop.
**Core truth:** Jesus gave you His peace — not as the world gives. It passes understanding and guards your mind.
**Why speak it:** Anxiety is loud. Peace is a choice you make with your mouth. Every time you speak fear, you feed it. Every time you speak peace, you starve it.
**Key scriptures:** John 14:27, Philippians 4:6-7, Isaiah 26:3, Isaiah 41:10, 2 Timothy 1:7, Colossians 3:15
**Declaration:** I have the peace of God. My mind is calm and clear. I trust God with everything I cannot control.

---

### FRIDAY — JOY
**Core pain:** Feeling empty. Going through the motions. Life feels heavy and colorless.
**Core truth:** The joy of the Lord is your strength. Joy is not based on circumstances — it's your inheritance.
**Why speak it:** You can speak joy into a joyless day. Your mouth sets the atmosphere of your mind.
**Key scriptures:** Nehemiah 8:10, Psalm 16:11, John 15:11, Romans 15:13, James 1:2-3, Habakkuk 3:18
**Declaration:** I choose joy today. The joy of the Lord is my strength. I am full of life, energy, and gladness.

---

### SATURDAY — BOLDNESS
**Core pain:** Fear. Timidity. Shrinking back. Anxiety about what people think. Paralyzed by the unknown.
**Core truth:** You have not been given a spirit of fear — but of power, love, and a sound mind.
**Why speak it:** Fear speaks. It tells you to shrink, to hide, to stay small. You have to speak boldness back at it — louder, until it submits.
**Key scriptures:** 2 Timothy 1:7, Joshua 1:9, Hebrews 4:16, Acts 4:29-31, Romans 8:31, Proverbs 28:1
**Declaration:** I am bold and courageous. Fear has no power over me. I step forward in confidence because God is with me.

---

### SUNDAY — DESTINY
**Core pain:** Feeling purposeless. Drifting. Wondering if your life matters. Fear you've missed it.
**Core truth:** You were made on purpose, for a purpose. God's plans for you are good — hope and a future.
**Why speak it:** Destiny is spoken into existence. Your words either call it forward or push it away. Speak your future like it's already settled.
**Key scriptures:** Jeremiah 29:11, Ephesians 2:10, Romans 8:28-30, Psalm 138:8, Isaiah 46:10, Philippians 1:6
**Declaration:** I am walking in my purpose. God's plan for my life is good. My best days are ahead of me.

---

## Carousel Format (13 slides)

| Slides | Function |
|--------|----------|
| 1–2 | Hook — bold God's-voice statement that stops the scroll |
| 3–8 | Scripture unpacked line by line (God speaking in first person) |
| 9–10 | The turn — why you must SPEAK it, not just receive it |
| 11–12 | Promise anchor — land the plane with the key scripture |
| 13 | Comment CTA — low friction, high meaning (e.g. "Comment YES LORD if you're claiming this") |

---

## Static / Short-Form Format

**Single image post:**
- Slide 1: Hook (the pain or bold truth)
- Caption: 4-part formula in full — Truth → Why → How → Claim

**Short-form reel:**
- 15–30 seconds
- God's voice speaking the declaration
- Visual: scripture text building on screen
- CTA: "Claim this. Drop it in the comments."

---

## Day-of-Week Rotation Code

```js
const PILLARS = {
  0: "destiny",    // Sunday
  1: "identity",   // Monday
  2: "health",     // Tuesday
  3: "prosperity", // Wednesday
  4: "peace",      // Thursday
  5: "joy",        // Friday
  6: "boldness"    // Saturday
};
const todaysPillar = PILLARS[new Date().getDay()];
```

---

*Locked in by Franchiz — April 16, 2026*
