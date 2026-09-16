# Lead Magnet — "UNSHAKABLE"

**Status:** plan, nothing built yet
**Deliverable:** a free downloadable asset that teaches the SpeakLife mechanism, gives
away real value, and makes the app the obvious next step.
**Audience:** cold-to-warm believers off Meta / IG / TikTok, plus the email list.

Everything here is pulled from live app copy, the live declaration set, and PostHog,
so the magnet argues the same thing the onboarding and paywall already argue. Message
match is the whole point: magnet → email → App Store → onboarding → paywall should say
one sentence, not five.

Companion docs: `ad-creative-brief.md` (visual system, verbatim ad copy),
`paywall-copy-research.md` (what converts and why), root `CLAUDE.md` (declaration rules,
which are binding on every declaration printed in this asset).

---

## 1. Research: the problems SpeakLife actually solves

Two layers. The **method problems** are what the magnet teaches and what nobody else in
the category is selling. The **felt problems** are what the reader came in with and how
we segment the pages.

### 1a. The method problems (the real product)

These are ranked by how hard they are to solve without the app, which is the same as
ranking them by how well they justify a download.

| # | Problem | The reader's version of it | What Scripture says | How SpeakLife answers it |
|---|---|---|---|---|
| 1 | **Praying *about* the storm instead of *to* it** | "I've prayed about this for years and it hasn't moved." | Jesus spoke to the storm, the sickness and the grave (Mark 4:39, Matt 8:3, John 11:43), then said we do the same (Mark 11:23-24) | The entire product is built on speaking, not reading |
| 2 | **Reading it without ever saying it** | "I know the verse. It still doesn't feel true." | Faith comes by hearing (Rom 10:17). Your own mouth is the cheapest source of hearing you own (Josh 1:8) | Declarations are written for the mouth: first person, present tense, one breath |
| 3 | **Not knowing what God says about *this*** | "I don't know where to look for a verse about my custody hearing / my womb / my debt." | 2 Tim 3:16 | 3,586 declarations across 80 categories (47 of them life situations), matched to what the user writes in their own words |
| 4 | **Your mind runs the world's script all day** | "I wake up already anxious." | Rom 12:2 — transformed by the renewing of the mind | The 60-second morning, and audio that runs while hands are busy |
| 5 | **You believe it for a day, not for thirty** | "I start strong every January." | Rom 5:17 — reign in life. Reigning is trained, not felt | 30-day plans / Enforcement campaigns, streaks, daily checklist |
| 6 | **You do it alone, so you quit** | "Nobody knows I'm struggling with this." | Eccl 4:12 | Stand With Me: 2–12 people speaking the same declaration over the same week |
| 7 | **You feel something and then change nothing** | "Good devotional. Same Tuesday." | James 2:17 — faith without works is dead | Every declaration is paired with the move that proves you believed it |

**The open lane, restated** (from `paywall-copy-research.md` §3): every winning faith app
sells a felt outcome with God as the mechanism and library size as proof. **Nobody sells
Scripture itself as the active agent, spoken out loud.** The magnet should plant that
flag before the reader ever sees a price.

### 1b. The felt problems, ranked by live data

Two independent reads agree, so the magnet's page order is evidence-led, not a guess.

**Paywall impressions by resolved pain, 90 days** (`paywall_impression.pain`, people):

| peace 63 · identity 51 · health 42 · nearness 27 · abundance 25 · purpose 23 · joy 17 |
|---|

**Declarations users actually favourite, 90 days** (`user_action` / `action='add'`,
simulator excluded, people):

| faith 162 · health 100 · destiny 96 · identity 88 · anxiety 85 · gratitude 60 · joy 59 · rest 50 · wealth 49 · love 48 |
|---|

Collapsed into the magnet's seven storm pages, in this order:

1. **The mind** (peace / anxiety / rest) — the largest segment on both reads
2. **Who you are** (identity / shame / confidence)
3. **The body** (health / wellness)
4. **The money** (wealth / work / debt / housing)
5. **The calling** (destiny / purpose / new season)
6. **The heart** (joy / grief / gratitude)
7. **The people you love** (marriage / parenting / prodigal / a womb)

Nearness (God feels far) is not a page. It is the close, because it is what the other
seven produce.

### 1c. One number worth knowing before writing

77.2% of user-days inside the app end with zero tasks completed, and three tasks carry
the entire feed (burst, devotional, audio). Do not build a magnet that asks for a
twenty-minute daily practice. The magnet's ask is **sixty seconds, out loud, once.** That
is also the app's real activation event, so the magnet trains the exact behaviour the
product needs.

---

## 2. Format recommendation

**Build a PDF at 1080×1350 per page, not a 16:9 deck.**

Reasons, in order:
- It is read on a phone, in bed, at 11pm. 16:9 forces pinch-zoom.
- Every page doubles as an Instagram / TikTok carousel slide at native size, so the
  magnet is also two weeks of organic content with zero extra design work.
- The `speaklife-carousel` and `speaklife-quote-cards` skills already render at these
  dimensions, so the seven storm pages can be produced in the existing pipeline.
- A PDF is the thing people believe they are getting when they hand over an email. A
  deck reads like something you sat through.

**Length: 18 pages.** Long enough to feel like a real gift, short enough to finish in one
sitting. Under 10 pages reads like an ad; over 25 and nobody reaches the CTA.

Also produce, from the same source:
- **A 1-page printable** ("The Seven Declarations") for the fridge or the car dash. This is
  the piece that gets photographed and shared, and it carries the QR code.
- **A 7-slide carousel cutdown** for organic, ending on "full guide in bio."

---

## 3. Title and offer

Recommended:

> ### UNSHAKABLE
> **How to speak to your storm the way Jesus did**
> *Plus 21 declarations for the seven storms you are most likely standing in*

The subtitle is doing the work. People download **assets**, not essays, so the countable
thing ("21 declarations") has to be on the cover. "Unshakable" is already the word the
paywall and onboarding use for the outcome, and it is the promise the reader is actually
shopping for.

Alternates if a test is wanted: *"Pray Like Jesus"* (matches the store listing and the
storm opener exactly, strongest message match, weakest curiosity) and *"The 60-Second
Morning"* (strongest habit hook, weakest theology).

---

## 4. Page-by-page structure

The spine is the same argument the `direct` onboarding arm runs, because it is the
argument the app already tested: **assert → turn → mechanism → proof → practice →
payoff → ask.**

### Act I — The turn (pages 1–6)

| Page | Job | Content direction |
|---|---|---|
| **1. Cover** | Stop the scroll | Title, subtitle, cinematic dark plate. No logo lockup bigger than the title. |
| **2. Read this first** | Set the sixty-second contract | "This takes about eleven minutes to read and sixty seconds a day to do. Read it out loud. That is not a style note, it is the whole method." |
| **3. The honest page** | Name it once | "You have prayed about it. You have cried about it. You have asked other people to pray about it. It has not moved." One page. No solution yet. This is the only page in the asset that sits in the problem, and it earns everything after it. |
| **4. The turn** | Break the frame | "Jesus never once prayed about a storm." Big, alone on the page. |
| **5. The proof** | Three beats | The storm: *"Quiet! Be still!"* and the wind stopped (Mark 4:39). The sickness: *"Be clean."* and the leprosy left (Matt 8:3). The grave: *"Lazarus, come out!"* and a dead man walked (John 11:43). Lift verbatim from the app's mechanism screen. |
| **6. Then He said we do the same** | The hinge | Mark 11:23-24 in full, pulled out as type. Underline **"says to this mountain"** and **"believes that what they say."** Saying is the part He names. Without this page the reader infers a command from a pattern; with it, speaking is not our idea. |

### Act II — The method (pages 7–9)

These three pages are why the asset gets kept and re-sent. Give away the real rules.

| Page | Job | Content direction |
|---|---|---|
| **7. What a declaration is (and is not)** | Definition | Not an affirmation (that is you talking about you). Not a prayer request (that is asking). A declaration is God's own Word, in your mouth, over your situation, out loud. |
| **8. The four rules** | The teachable asset | **First person** — you are the one speaking. **Present tense** — faith says it done. **One sentence** — the mouth cannot carry a paragraph with conviction. **Out loud** — Rom 10:17, your ears are the delivery mechanism. These are the app's own authoring rules (`CLAUDE.md` §1, §2, §13, §14). Giving them away costs nothing and proves we know something. |
| **9. The one rule that changes everything** | Call higher | Never declare the low thing over yourself. You do not argue with the storm, name it, or rebuke your own body. You declare the higher reality that makes it irrelevant. ❌ "Worry, settle down." ✅ "I have the mind of Christ. It is clear, sound, and at rest." Straight from `CLAUDE.md` §12. |

### Act III — The seven storms (pages 10–16)

One page per storm. Identical shape every time, so the reader learns the pattern by page
three and can build their own by page seven. **This is the page count where a designer
needs a locked template** — see §5 for the fully written reference page.

Each page carries:
1. **The storm** — one line, plain, second person.
2. **The lie you have been agreeing with** — one line, in quotes. This is the only place
   the low thing appears, and it appears as something being taken off the reader.
3. **What God actually says** — one verse, quoted, cited, NIV.
4. **Speak this** — three declarations, lifted from the live app set so the reader is
   holding real product, not marketing copy.
5. **Then do this today** — one concrete move. The James 2:17 half. Without it the page
   sells a feeling.

### Act IV — The close (pages 17–18)

| Page | Job | Content direction |
|---|---|---|
| **17. Seven days** | Make it doable | The plan: one storm, one declaration, seven mornings, sixty seconds, out loud, before the phone. Not seven storms in seven days — **one**. Then: what happens at day 30 (Rom 5:17, you are training for reigning, not counting days). Close on the word the cover promised: unshakable. |
| **18. Where this runs every day** | The ask | See §6. |

---

## 5. Reference page (build the template from this)

Copy is final-standard, not placeholder. Declarations are verbatim from
`declarationsv10.json` so the reader who downloads the app sees the same lines.

> **STORM ONE**
> # The mind that will not stop.
>
> **The lie you have been agreeing with**
> *"This is just how I am now."*
>
> **What God says**
> "You will keep in perfect peace those whose minds are steadfast, because they trust
> in you."
> — Isaiah 26:3
>
> **Speak this, out loud**
> - You gave me Your own peace, and I carry it into every room. *(John 14:27)*
> - Your peace beyond all understanding guards my heart and my mind in Christ. *(Philippians 4:7)*
> - I believed You, so I am inside Your rest today and I breathe deep. *(Hebrews 4:3)*
>
> **Then do this today**
> Say the first one out loud before you touch your phone tomorrow morning. Not in your
> head. Out loud, where your ears can hear it.

Source declarations for the other six pages, all already live and rule-compliant:

- **Who you are** — "I am a new creation in You, and the old is gone for good." (2 Cor 5:17) · "I am Your righteousness in Christ, and I stand right before You today." (2 Cor 5:21) · "You remade me in Your likeness, and righteousness is who I am right now." (Eph 4:24)
- **The body** — "Thank You Jesus, by Your wounds I am healed and whole." (Isa 53:5) · "Thank You Jesus, You took all my sickness, and strength rises in this body every morning." (Matt 8:17) · "I live and do not die, and I tell what You have done." (Ps 118:17)
- **The money** — "You meet every need of mine from the riches of Your glory." (Phil 4:19) · "You provide for me, and my supply waits on the mountain before I arrive." (Gen 22:14) · "I am Your child and Your heir, and I step into my full inheritance." (Gal 4:7)
- **The calling** — "Your plans for me are hope and a future, and I walk in them today." (Jer 29:11) · "Every day of mine is written in Your book, and it unfolds right on time." (Ps 139:16) · "You called me by Your own purpose and grace before time began." (2 Tim 1:9)
- **The heart** — "You live, and my joy is full, and no one can take it from me." (John 16:22) · "You put Your own joy in me, and it overflows until my joy is complete." (John 15:11) · "You are my strength, and my feet run light and sure on the heights." (Hab 3:19)
- **The people you love** — "You build my house Yourself, and what You raise stands firm." (Ps 127:1) · "My marriage is joined by Your own hand, and I let no one separate it." (Matt 19:6) · "You are the Rock, and I build my marriage on Your words so it stands." (Matt 7:24)

For the family page, swap in parenting or fertility lines when the traffic source is a
parenting audience. The page shape does not change.

**Hard rules for anyone writing new lines for this asset:** first person, present tense,
one sentence, no em dashes or en dashes, never name the low thing as the reader's present
reality, and never promise what Scripture does not (another person's free choice, or a
specific outcome no verse states). `CLAUDE.md` is binding here, not advisory — these lines
will be read next to the app's.

---

## 6. The gap, and the CTA page

A lead magnet that solves the problem completely does not convert. A lead magnet that
withholds the good part is resented. The honest gap here is real, so say it plainly:

> **You now have 21 declarations for seven storms. SpeakLife has 3,586, across 80
> categories, matched to the exact thing you are walking through.**

Page 18 carries four lines, each one a method problem from §1a that paper physically
cannot solve:

| Line | The problem it closes |
|---|---|
| **Your exact storm, not a category.** Tell it what you are facing in your own words and it finds the Scripture written for it. | #3 |
| **Sixty seconds, before the day starts.** The morning declaration, ready when you open your eyes. | #4 |
| **Spoken over you while your hands are busy.** Audio for the commute, the gym, the sleepless night. | #2, #4 |
| **Thirty days, not one good day.** A plan that carries you past the week your feelings quit. | #5 |

Then: App Store badge, QR code, the 4.9 rating (verifiable on the listing — do **not**
print a subscriber count, per `paywall-copy-research.md` §4), and one line of risk
reversal: *"Free to start. No card to look around."*

Deep link the QR to the onboarding arm that matches the traffic source (see
`AD_ONBOARDING_ROUTING.md`), and carry UTMs so the install attributes — a magnet install
landing as `organic` is a magnet we cannot measure.

---

## 7. Design spec

Inherit `ad-creative-brief.md` §2 wholesale so the PDF, the ads and the app are visibly
one thing:

- **Canvas** 1080×1350. Full-bleed cinematic photo plates on act openers (pages 1, 3, 4,
  17, 18); near-black flat ground on the teaching and storm pages so the type carries.
- **Type** SF Pro Rounded (or a geometric humanist rounded sans). Eyebrow 12pt bold caps,
  tracking 1.4, white 50%. Headline 32pt bold. Body 17pt, white 75%. Scripture in serif
  italic, white 80%, with the reference at 12pt in gold.
- **Accent** the app's gold for eyebrows, verse references and rules. Success green only
  on checkmarks, sparingly.
- **Declarations get a card**, not a bullet list: white 10% fill, 16pt radius, one
  declaration per card, reference in gold beneath. They must look like the app's cards,
  because that is the moment of recognition after install.
- **Mood** reverent but urgent. Dark, cinematic, hopeful light. No clip-art crosses, no
  stock praying hands.
- **No em dashes or en dashes anywhere in the asset**, including headings and body.
- Every page needs a quiet footer: small wordmark, page number, `speaklife.app`.

---

## 8. Distribution and capture

| Surface | How the magnet is used |
|---|---|
| **Meta / IG lead ads** | Native lead form, magnet delivered by email. Reuse the W3 "Read vs. Speak" hook from the ad brief — it is the magnet's thesis in seven words. |
| **Organic IG / TikTok** | The 7-slide carousel cutdown, ending "full guide in bio." Costs nothing and pre-qualifies. |
| **Link in bio** | Landing page with one field. The 1-page printable shown as the preview image. |
| **Existing email list** | Send to everyone once. This is also the reactivation asset for lapsed trialists. |
| **Inside the app** | Offer it on the post-cancel screen and to non-subscribers who have been inactive 14 days. A free gift to someone who just said no is the cheapest goodwill in the product. |

**Capture** through Klaviyo. One field, email only. Deliver instantly on the confirmation
page as well as by email, because a download that depends on inbox delivery loses a third
of them.

**Follow-up sequence, five emails over seven days**, each one carrying a single storm page
as an image and the same CTA:

1. Day 0 — the guide (delivery, nothing else)
2. Day 1 — "Did you say it out loud?" The one thing people skip
3. Day 3 — the mind page, expanded, one real testimonial
4. Day 5 — the gap: your exact storm, not a category
5. Day 7 — the 30-day plan and the trial

---

## 9. Measurement

Do not measure this on downloads. Downloads are free to get and prove nothing.

| Metric | Where | Why |
|---|---|---|
| Email → install | `acquisition_channel = 'owned_deeplink'` + the magnet's UTM campaign, person-level | The only number that says the magnet works |
| Install → `user_activated` | existing activation event | The magnet's whole job is to pre-train the speaking habit, so magnet installs should activate faster than the baseline. If they do not, the teaching pages are not landing. |
| Install → trial → paid, vs. baseline | `paywall_impression` → `trial_started` → RevenueCat, split by `source` | Whether a warmed reader converts better |
| Cost per install vs. direct-response ads | Meta + `acquisition_channel` | A magnet funnel that costs more per install than a straight install campaign is a content programme, not an acquisition channel. Say so if that is what it turns out to be. |

Watch the person-level joins: revenue only joins to behaviour for installs after the
RevenueCat identity fix, and historical cohorts stay orphaned
(`ANALYTICS_DATA_QUALITY.md`).

---

## 10. Build order

1. Lock the title and the seven storm pages' copy (this doc, §4–§5). Copy first; a
   designer cannot rescue a weak page 6.
2. Write the remaining six storm pages against the reference template, pulling every
   declaration from `declarationsv10.json` rather than writing new ones.
3. Design the locked storm template, then the five act-opener plates.
4. Produce the 18-page PDF, the 1-page printable, and the 7-slide carousel from the same
   source.
5. Landing page + Klaviyo capture + the five-email sequence.
6. Deep link and UTMs wired before a single ad runs.
7. Ship to the email list first. It is the cheapest read on whether the argument lands
   before any money goes behind it.

---

*Built from the live warfare / outcomes / direct onboarding flows, the live declaration
set, and PostHog (project 455580, 90-day window, September 2026). When onboarding or
paywall copy changes, this asset changes with it: the whole value of a magnet is that it
says the same thing the app says.*
