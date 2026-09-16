# Lead Magnet — The Storm Audit → "UNSHAKABLE"

**Status:** plan, nothing built yet
**Deliverable:** a free diagnostic that names the storm someone is standing in, their top
three gaps, and their next step, delivering a personalized 7-day speaking plan.
**Build target:** v1 live in a week, not a quarter. See §10.
**Audience:** cold-to-warm believers off Meta / IG / TikTok, plus the email list.

Everything here is pulled from live app copy, the live declaration set, and PostHog, so
the magnet argues the same thing the onboarding and paywall already argue. Message match
is the whole point: magnet → email → App Store → onboarding → paywall should say one
sentence, not five.

Companion docs: `ad-creative-brief.md` (visual system, verbatim ad copy),
`paywall-copy-research.md` (what converts and why), `AD_ONBOARDING_ROUTING.md` (deep-link
routing), root `CLAUDE.md` (declaration rules, binding on every declaration printed here).

---

## 1. Research: the problems SpeakLife actually solves

Two layers. The **method problems** are what the magnet diagnoses and what nobody else in
the category is selling. The **felt problems** are what the reader came in with, and how
the audit segments them.

### 1a. The method problems (the real product)

Ranked by how hard they are to solve without the app, which is the same as ranking them
by how well they justify a download.

| # | Problem | The reader's version of it | What Scripture says | How SpeakLife answers it |
|---|---|---|---|---|
| 1 | **Praying *about* the storm instead of *to* it** | "I've prayed about this for years and it hasn't moved." | Jesus spoke to the storm, the sickness and the grave (Mark 4:39, Matt 8:3, John 11:43), then said we do the same (Mark 11:23-24) | The entire product is built on speaking, not reading |
| 2 | **Reading it without ever saying it** | "I know the verse. It still doesn't feel true." | Faith comes by hearing (Rom 10:17). Your own mouth is the cheapest source of hearing you own (Josh 1:8) | Declarations written for the mouth: first person, present tense, one breath |
| 3 | **Not knowing what God says about *this*** | "I don't know where to look for a verse about my custody hearing / my womb / my debt." | 2 Tim 3:16 | 3,586 declarations across 80 categories (47 of them life situations), matched to what the user writes in their own words |
| 4 | **Your mind runs the world's script all day** | "I wake up already anxious." | Rom 12:2 — transformed by the renewing of the mind | The 60-second morning, and audio that runs while hands are busy |
| 5 | **You believe it for a day, not for thirty** | "I start strong every January." | Rom 5:17 — reign in life. Reigning is trained, not felt | 30-day plans / Enforcement campaigns, streaks, daily checklist |
| 6 | **You do it alone, so you quit** | "Nobody knows I'm struggling with this." | Eccl 4:12 | Stand With Me: 2–12 people speaking the same declaration over the same week |
| 7 | **You feel something and then change nothing** | "Good devotional. Same Tuesday." | James 2:17 — faith without works is dead | Every declaration paired with the move that proves you believed it |

**The open lane, restated** (`paywall-copy-research.md` §3): every winning faith app sells
a felt outcome with God as the mechanism and library size as proof. **Nobody sells
Scripture itself as the active agent, spoken out loud.** The magnet plants that flag
before the reader ever sees a price.

### 1b. The felt problems, ranked by live data

Two independent reads agree, so the audit's storm list is evidence-led, not a guess.

**Paywall impressions by resolved pain, 90 days** (`paywall_impression.pain`, people):
peace 63 · identity 51 · health 42 · nearness 27 · abundance 25 · purpose 23 · joy 17

**Declarations users actually favourite, 90 days** (`user_action` / `action='add'`,
simulator excluded, people): faith 162 · health 100 · destiny 96 · identity 88 ·
anxiety 85 · gratitude 60 · joy 59 · rest 50 · wealth 49 · love 48

Collapsed into seven storms, in this order:

1. **The mind** (peace / anxiety / rest) — the largest segment on both reads
2. **Who you are** (identity / shame / confidence)
3. **The body** (health / wellness)
4. **The money** (wealth / work / debt / housing)
5. **The calling** (destiny / purpose / new season)
6. **The heart** (joy / grief / gratitude)
7. **The people you love** (marriage / parenting / prodigal / a womb)

Nearness (God feels far) is not a storm. It is the close, because it is what the other
seven produce.

### 1c. One number worth knowing before building anything

77.2% of user-days inside the app end with zero tasks completed, and three tasks carry the
entire feed (burst, devotional, audio). Do not build a magnet that asks for a
twenty-minute daily practice. The ask is **sixty seconds, out loud, once.** That is also
the app's real activation event, so the magnet trains the exact behaviour the product
needs.

---

## 2. Which type of magnet (the call)

Three types, run against this business.

| Type | What it would be here | Verdict |
|---|---|---|
| **Give a taste** | A free trial of the real thing, limited by quantity, uses or time | **Slot already occupied.** SpeakLife ships a free tier *and* a 7-day trial. A magnet in this shape gives away something the App Store gives away one tap later, and spends an email capture to do it. |
| **One step of many** | Step one of a multi-step process. A 21-declaration PDF, day one of the thirty | **Weakest of the three for this product, and this was the original plan.** The problem: the app *is* a daily practice, so "step one" is literally day one, which the free tier already hands out. A one-step magnet competes with the free app instead of feeding it. |
| **Reveal the problem** | A scored diagnostic: which storm you are standing in, and what you have been doing with your mouth about it | **Build this.** It passes the type's own test and it is the only one of the three SpeakLife is uniquely equipped to run. |

**Why "reveal the problem" wins on its own criterion.** The type is strongest when the
problem gets worse the longer they wait, because urgency is built in and nobody has to
manufacture it. That is literally true here and the app already says so: the outcomes
onboarding opens on *"How much longer will you wait?"* under an hourglass. An unrenewed
mind does not hold steady, it deepens the groove it has been running (Rom 12:2). The
waiting cost is real, so naming it is honest rather than a pressure tactic.

**Why SpeakLife specifically can run it.** A diagnostic magnet is usually expensive because
the vocabulary and the result copy have to be invented. Here they already exist and are in
production:

- `UserPain` is a settled 15-way model of what people actually walk in, sized against the
  matcher rather than guessed.
- Every pain already has a headline, a subhead, a domain and mechanism copy written and
  live on the paywall.
- `AD_ONBOARDING_ROUTING.md` already deep-links a segment to the matching onboarding arm.

So the audit is not new machinery. It is a questionnaire onto a vocabulary we ship, and its
output is exactly the variable the rest of the funnel is built to consume. Note it does not
need to *call* the app's matcher to do this: Q1 resolves the storm directly (§3b). The
existing classifier matters because it proves the fifteen pains are real categories people
sort into, not because the web page has to run it.

**The operational argument, which is the one that actually decides it.** A PDF download
returns an email address. The audit returns an email address **plus the resolved pain**,
which routes the install to the matching onboarding arm and pre-resolves the paywall
headline. `paywall_impression` already carries `pain`, and the open question in
`paywall-copy-research.md` §5 is whether a named pain converts better than `none` — 169
people hit `none` in 90 days against 63 for the largest named pain. The audit is the only
acquisition asset that can arrive with that field already filled.

**All three types still ship, stacked, in one funnel:** the audit reveals the problem, the
personalized 7-day plan is one step of many, and the trial at the end is the taste. The
question was never whether each type works. It is which one goes at the front.

### The standard it has to clear

> **It has to feel like they could have paid for it.** People judge what you sell by what
> you give away. If the free thing is thin, they assume the paid thing is thin too, and
> the price on the next step becomes a question instead of a formality.

This is the acceptance test, and it is worth being concrete about what passes, because
"make it good" is not a spec. The audit clears the bar if and only if all five are true:

1. **It quotes their own words back.** Q2 appears verbatim on the result page. Nothing else
   in the asset is as cheap or as convincing.
2. **It tells them something they had not put into words themselves.** The Asker finding is
   the one that does this: *you have been praying about it for years, which is exactly what
   you were taught, and it is half the instruction.* If a reader could have written the
   result themselves, we have built a mirror, not an assessment.
3. **It is arithmetic, not adjectives.** 540 mornings. The input ledger in §3d. Numbers a
   reader can check make a free diagnostic feel measured rather than written.
4. **The deliverable is addressed to them.** Their storm on the cover, their seven
   declarations, not a table of contents with their problem somewhere inside it.
5. **It ends with something doable tomorrow at 7am in sixty seconds.** An assessment that
   ends in a pitch is a funnel. One that ends in a next step is a product.

The inverse is the failure mode to watch: a result page everyone gets, a PDF that is
visibly a brochure, and a CTA that arrives before the value does. Any one of those and the
reader correctly downgrades the paid thing on the other side of it.

**This standard is also why the PDF is designed, not typeset.** A framework in our voice
and our colours, laid out like something off a shelf. The design spec in §7 is not
decoration, it is the part that makes a free asset read as a paid one.

---

## 3. The magnet: The Storm Audit

**Name:** *The Storm Audit*. Alternate: *What Have You Been Agreeing With?*
**Promise on the button:** "Eight questions. Find out which storm you're standing in, why
it hasn't moved, and the one thing to do tomorrow morning."
**Length:** 8 questions, then the email. Sixty seconds.
**Output:** your storm · your top three gaps · your next step.

### 3a. Two axes, deliberately

The audit resolves two independent things, and the second one is the product.

- **Axis 1 — which storm.** Personalization, and the routing key. Feeds `UserPain`.
- **Axis 2 — the method gap.** What they have actually done with their mouth about it.
  Three outcomes: **Reader** (knows the verse, never says it), **Asker** (prays about it,
  faithfully, for years), **Speaker** (already doing it, needs the daily machine).

Nearly everyone lands Asker. That is the finding, and it is the whole argument: *you have
not been doing it wrong, you have been doing the thing you were taught. There is a second
half nobody handed you.*

### 3b. The questions

| # | Question | Feeds |
|---|---|---|
| 1 | What is heaviest right now? (seven storms + "all of it") | **Storm.** This alone resolves the routing key. |
| 2 | **Say it in your own words.** One line. | The quote-back. Not classified, just kept. |
| 3 | How long has it been like this? (weeks / months / a year / years) | The waiting cost |
| 4 | When it hits, what do you do? (pray about it · read a verse · try not to think about it · tell someone · nothing) | Method, gap 1 |
| 5 | Have you ever said God's Word out loud over this, by name? (never · once or twice · sometimes · most days) | Method. **The hinge question.** Gaps 1 and 5. |
| 6 | What does the first hour of your day sound like? (phone · news · silence · worship · the Word) | Gap 4, input ledger |
| 7 | Whose voice do you hear about this most? (the diagnosis · the numbers · what someone said about you · your own · God's) | Agreement, input ledger |
| 8 | Do you know a verse that speaks to this exact thing? (no · one · a few · yes, several) | Gap 3 |

Then the email, framed as delivery rather than as a gate: *"Where should we send your
plan?"* It lands after the work is done, when the answers are already invested.

**Q2 is free text on purpose and is never parsed.** An earlier draft had it posting to the
app's live matcher to refine the storm. That was the single most expensive line in the
plan and it bought nothing: Q1 already resolves the storm, and what makes Q2 land is that
the result quotes it back verbatim. Classification was over-engineering dressed as
personalization. Cutting it is what takes this build from a quarter to an afternoon.

### 3c. The three gaps

Tyler's format returns a score and the top three gaps. A score out of ten is wrong here
(see §3e), but **the three gaps are exactly right, and they already exist**: they are the
seven method problems from §1a. That inventory now does double duty as the research
backbone and the result page's diagnosis.

| Gap shown | Triggered by | §1a problem |
|---|---|---|
| **You have been praying about it, not to it.** | Q4 = pray about it / Q5 = never | 1 |
| **You know the verse. It has never been in your mouth.** | Q5 = never or once or twice, and Q8 ≥ one | 2 |
| **You do not know what God says about this exact thing.** | Q8 = no | 3 |
| **Your first hour belongs to something else.** | Q6 = phone or news | 4 |
| **You have never run it longer than a few days.** | Q5 = once or twice / sometimes, with Q3 ≥ a year | 5 |
| **The loudest voice about this is not God's.** | Q7 ≠ God's | 7 (agreement) |

Show the three highest-priority triggered gaps in the order above. Never show more than
three: a list of six reads as a scolding, and the reader stops at the first one they
recognise anyway.

### 3d. The result page

Five beats, in this order. The order is not negotiable — beat 4 exists so beat 1 does not
become the whole message.

1. **The storm, named.** *"You are standing in the storm of the mind."* Quote their Q2 line
   back verbatim underneath it.
2. **The method gap.** *"And you have been praying about it. Not to it."* Plus the label:
   **You are an Asker.** With the reassurance immediately: most people are, because it is
   what they were taught.
3. **Your three gaps.** From §3c, as three cards. This is the part that reads like an
   assessment rather than a quiz result.
4. **The turn, to identity.** Jesus never prayed about a storm (Mark 4:39), then Mark
   11:23-24, then their pain's identity line straight from the paywall: *"You have the mind
   of Christ."* (1 Cor 2:16). The same sentence they will meet again at the paywall.
5. **Their next step.** One declaration, on screen, right now, out loud. Then: the other six
   are in your plan, and it is in your inbox.

**Make them speak one before they leave the page.** The result page is the only moment we
will ever have their full attention with nothing to install, and speaking once is the app's
own activation event. A button that says **"Say it out loud"** and reveals the line, with a
three-second beat before the CTA appears, converts an assessment into an experience. This
is also beat 5 of the standard in §2: something doable in sixty seconds, done immediately
rather than promised.

### 3e. The waiting cost and the input ledger

Two arithmetic lines, both computed, both honest. These are what make it feel measured.

**The waiting cost**, from Q3:

> You have been carrying this for about eighteen months. That is roughly 540 mornings your
> mind started on something other than what God said about it.

**The input ledger**, from Q6 and Q7:

> This week, the thing you are afraid of got about forty run-throughs. What God says about
> it got none.

True, arithmetic, and neither one predicts a catastrophe. **Prefer this to a score out of
ten.** A number grading a person invites the reader to hear a verdict on their walk; a
ledger counting inputs points at a habit, which is the thing we are actually selling a fix
for. Same diagnostic force, none of the doctrinal cost.

### 3f. Two guardrails, and they are not optional

**Never score their faith, their righteousness, or their walk.** No "you scored 4/10 as a
Christian." The audit scores **behaviour only** — what has been in their mouth. SpeakLife
is grace-based and identity-first; a diagnostic that grades someone's standing with God
contradicts the product at the level of doctrine, not tone, and it would be the single
fastest way to lose the audience this is built for.

**Never imply the storm is their fault.** The sickness, the debt and the prodigal are not
consequences of insufficient declaring. The gap the audit names is a *method* they were
never handed, not a failure they committed. Every result line has to survive being read by
someone whose diagnosis came last week.

**One tension worth naming.** `paywall-copy-research.md` deliberately moved the paywall
*away* from problem headlines to identity headlines, because "a problem headline sells
relief, and relief is a smaller thing than the app's actual claim." That finding is about
the point of purchase and it stands. The magnet has a different job: at the top of the
funnel the diagnosis is the hook, and identity is the payoff. This is why beat 3 sits one
screen after beat 1 rather than five emails later. Diagnosis, then identity, fast.

---

## 4. The delivery: the personalized 7-day plan

The PDF work is not wasted, it is re-aimed. Instead of one 18-page guide covering seven
storms, build **one 10-page plan, branched seven ways.** Most pages are shared; only the
storm pages differ. Same total design effort, and every reader gets an asset addressed to
them rather than a table of contents with their problem somewhere in it.

**Format: 1080×1350 per page, PDF. Not a 16:9 deck.**

- Read on a phone, in bed, at 11pm. 16:9 forces pinch-zoom.
- Every page doubles as an IG / TikTok carousel slide at native size, so the shared pages
  are also organic content with no extra design work.
- The `speaklife-carousel` and `speaklife-quote-cards` skills already render at these
  dimensions.
- A PDF is what people believe they are getting. A deck reads like something you sat
  through.

### Page plan (10 pages, 3 of them storm-branched)

| Page | Shared or branched | Job |
|---|---|---|
| 1. Cover | Branched | *"UNSHAKABLE — your 7-day plan for the storm of the mind."* Their storm on the cover. |
| 2. Your result | Branched | The audit result restated, their own Q2 words quoted. Proof it was read. |
| 3. Jesus never prayed about a storm | Shared | The turn. One line, alone on the page. |
| 4. The proof | Shared | The storm: *"Quiet! Be still!"* (Mark 4:39). The sickness: *"Be clean."* (Matt 8:3). The grave: *"Lazarus, come out!"* (John 11:43). Verbatim from the app's mechanism screen. |
| 5. Then He said we do the same | Shared | Mark 11:23-24 pulled out as type. Underline **"says to this mountain"** and **"believes that what they say."** Saying is the part He names. |
| 6. The four rules | Shared | **First person** · **Present tense** · **One sentence** · **Out loud**. The app's own authoring rules (`CLAUDE.md` §1, §2, §13, §14). Giving them away costs nothing and proves we know something. |
| 7. Never declare the low thing | Shared | ❌ "Worry, settle down." ✅ "I have the mind of Christ. It is clear, sound, and at rest." (`CLAUDE.md` §12.) |
| 8. Your seven declarations | **Branched** | Seven lines for their storm, one per morning, lifted verbatim from `declarationsv10.json`. The asset they keep. |
| 9. Seven mornings | Shared | The plan: same declaration, out loud, before the phone. Then day 30 (Rom 5:17 — training for reigning, not counting days). Close on *unshakable*. |
| 10. Where this runs every day | Shared | The ask. See §6. |

Also produce from the same source: **a 1-page printable** (their seven declarations, for
the fridge or the car dash, carrying the QR) and **a 7-slide carousel cutdown** of the
shared pages for organic, ending "take the audit, link in bio."

---

## 5. Reference page (build the template from this)

Copy is final-standard, not placeholder. Declarations are verbatim from
`declarationsv10.json`, verified against the live set, so a reader who installs meets the
same lines they were given.

> **YOUR SEVEN DECLARATIONS**
> # The storm of the mind.
>
> **What God says**
> "You will keep in perfect peace those whose minds are steadfast, because they trust in
> you." — Isaiah 26:3
>
> **Speak one a morning, out loud**
> - You gave me Your own peace, and I carry it into every room. *(John 14:27)*
> - Your peace beyond all understanding guards my heart and my mind in Christ. *(Philippians 4:7)*
> - I believed You, so I am inside Your rest today and I breathe deep. *(Hebrews 4:3)*
>
> **Not in your head. Out loud, where your ears can hear it.**

Source declarations for the other six storms, all live and rule-compliant:

- **Who you are** — "I am a new creation in You, and the old is gone for good." (2 Cor 5:17) · "I am Your righteousness in Christ, and I stand right before You today." (2 Cor 5:21) · "You remade me in Your likeness, and righteousness is who I am right now." (Eph 4:24)
- **The body** — "Thank You Jesus, by Your wounds I am healed and whole." (Isa 53:5) · "Thank You Jesus, You took all my sickness, and strength rises in this body every morning." (Matt 8:17) · "I live and do not die, and I tell what You have done." (Ps 118:17)
- **The money** — "You meet every need of mine from the riches of Your glory." (Phil 4:19) · "You provide for me, and my supply waits on the mountain before I arrive." (Gen 22:14) · "I am Your child and Your heir, and I step into my full inheritance." (Gal 4:7)
- **The calling** — "Your plans for me are hope and a future, and I walk in them today." (Jer 29:11) · "Every day of mine is written in Your book, and it unfolds right on time." (Ps 139:16) · "You called me by Your own purpose and grace before time began." (2 Tim 1:9)
- **The heart** — "You live, and my joy is full, and no one can take it from me." (John 16:22) · "You put Your own joy in me, and it overflows until my joy is complete." (John 15:11) · "You are my strength, and my feet run light and sure on the heights." (Hab 3:19)
- **The people you love** — "You build my house Yourself, and what You raise stands firm." (Ps 127:1) · "My marriage is joined by Your own hand, and I let no one separate it." (Matt 19:6) · "You are the Rock, and I build my marriage on Your words so it stands." (Matt 7:24)

Each storm needs seven, so pull four more per storm from the same categories. For the
family storm, swap in parenting or fertility lines when the traffic source is a parenting
audience. The page shape does not change.

**Hard rules for anyone writing new lines:** first person, present tense, one sentence, no
em dashes or en dashes, never name the low thing as the speaker's present reality, and
never promise what Scripture does not (another person's free choice, or a specific outcome
no verse states). `CLAUDE.md` is binding here, not advisory. These lines sit next to the
app's.

---

## 6. The gap, and the CTA page

A magnet that solves the problem completely does not convert. One that withholds the good
part is resented. The gap here is real, so say it plainly:

> **You now have seven declarations for one storm. SpeakLife has 3,586, across 80
> categories, matched to the exact thing you are walking through.**

Page 10 carries four lines, each closing a method problem from §1a that paper physically
cannot:

| Line | Closes |
|---|---|
| **Your exact storm, not a category.** Tell it what you are facing in your own words and it finds the Scripture written for it. | #3 |
| **Sixty seconds, before the day starts.** The morning declaration, ready when you open your eyes. | #4 |
| **Spoken over you while your hands are busy.** Audio for the commute, the gym, the sleepless night. | #2, #4 |
| **Thirty days, not one good day.** A plan that carries you past the week your feelings quit. | #5 |

Then: App Store badge, QR, the 4.9 rating (verifiable on the listing — do **not** print a
subscriber count, per `paywall-copy-research.md` §4), and one line of risk reversal: *"Free
to start. No card to look around."*

**The QR and every result-page link must carry the resolved pain**, deep-linked to the
matching onboarding arm (`AD_ONBOARDING_ROUTING.md`) with UTMs attached. This is the entire
operational payoff of choosing a diagnostic over a download. A magnet install landing as
`organic` with `pain = none` is a magnet that threw away the only thing it was better at.

---

## 7. Design spec

Inherit `ad-creative-brief.md` §2 wholesale, so audit, PDF, ads and app are visibly one
thing:

- **Canvas** 1080×1350. Full-bleed cinematic plates on pages 1, 3, 9, 10; near-black flat
  ground on the teaching pages so the type carries.
- **Type** SF Pro Rounded (or a geometric humanist rounded sans). Eyebrow 12pt bold caps,
  tracking 1.4, white 50%. Headline 32pt bold. Body 17pt, white 75%. Scripture in serif
  italic, white 80%, reference 12pt gold.
- **Accent** the app's gold for eyebrows, verse references and rules. Success green only on
  checkmarks, sparingly.
- **Declarations get a card**, not a bullet: white 10% fill, 16pt radius, one per card,
  reference in gold beneath. They must look like the app's cards, because that is the
  recognition moment after install.
- **The audit itself** is one question per screen, thumb-reachable, with a progress bar. It
  must feel like the app's onboarding, because it is the same argument.
- **Mood** reverent but urgent. Dark, cinematic, hopeful light. No clip-art crosses, no
  stock praying hands.
- **No em dashes or en dashes anywhere in the asset**, headings included.

---

## 8. Distribution and capture

| Surface | How it is used |
|---|---|
| **Meta / IG ads** | Straight to the audit. Hook: the W3 "Read vs. Speak" line from the ad brief — it is the audit's thesis in seven words. |
| **Organic IG / TikTok** | The 7-slide carousel of shared pages, ending "take the audit, link in bio." |
| **Link in bio** | The audit is the landing page. No separate squeeze page. |
| **Existing email list** | Send once to everyone. Also the reactivation asset for lapsed trialists, and it re-segments a list we currently hold no pain data on. |
| **Inside the app** | Offer on the post-cancel screen and to non-subscribers inactive 14 days. A free, personal diagnosis to someone who just said no is the cheapest goodwill in the product. |

**Capture** through Klaviyo, email only, after the eighth question — *after* the work is
done, so the answers are already invested. Deliver the result on screen immediately and the
PDF by email, because a result that depends on inbox delivery loses a third of them.

**Follow-up sequence, five emails over seven days**, every one branched by the resolved
storm:

1. Day 0 — the plan (delivery, nothing else)
2. Day 1 — "Did you say it out loud?" The one thing people skip
3. Day 3 — their storm, expanded, one real testimonial matched to that pain where one
   exists (`PaywallTestimonial` tags real reviews; eight pains still have none — **do not
   fabricate one**)
4. Day 5 — the gap: your exact storm, not a category
5. Day 7 — the 30-day plan and the trial

---

## 9. Measurement

Do not measure this on completions. Completions are cheap and prove nothing.

| Metric | Where | Why |
|---|---|---|
| Audit start → complete | Klaviyo / audit events | Below ~60% means the audit is too long or Q2 is scaring people off |
| Complete → install | `acquisition_channel = 'owned_deeplink'` + the audit's UTM campaign, person-level | The only number that says the magnet works |
| **Install → `paywall_impression` carrying a named `pain`** | existing property | The unique claim of this format. If audit installs still land on `pain = none`, the deep-link handoff is broken and the whole reason for choosing a diagnostic is gone. Check this first. |
| Install → `user_activated` vs. baseline | existing activation event | The audit pre-trains the speaking habit, so these installs should activate faster. If not, the result page is not landing. |
| Install → trial → paid vs. baseline | `paywall_impression` → `trial_started` → RevenueCat, split by `source` | Whether a diagnosed reader converts better |
| Cost per install vs. direct-response ads | Meta + `acquisition_channel` | An audit funnel costing more per install than a straight install campaign is a content programme, not an acquisition channel. Say so if that is what it turns out to be. |

Watch the person-level joins: revenue only joins to behaviour for installs after the
RevenueCat identity fix, and historical cohorts stay orphaned
(`ANALYTICS_DATA_QUALITY.md`).

---

## 10. Build order

**This is a one-week build, and most of it is copy.** The earlier draft of this plan had a
seven-step programme with a "if it cannot be built this quarter" fallback, which was the
wrong posture: nothing here needs a backend. The audit is a static page with branching, the
scoring is a lookup table, and the PDF is seven exports of one template. The only reason it
was ever a quarter was the matcher call in Q2, and that is cut (§3b).

| Day | Work | Why it is this small |
|---|---|---|
| **1** | Lock all the copy: eight questions, the seven storms mapped to `UserPain`, the three method labels, six gap lines, seven result pages. | Copy is the whole product. A designer cannot rescue a weak beat 2. |
| **2** | Build the audit as one static page. Eight screens, client-side branching, no backend. Storm comes from Q1, gaps from a lookup table, Q2 is stored and echoed, never parsed. | Nothing here needs a server. |
| **2** | **Wire the deep link and UTMs carrying the resolved pain.** | Skipped, this silently degrades back into a PDF download and forfeits the entire reason the diagnostic beat the download (§2). Do it the same day the page exists, not after the ads are booked. |
| **3** | Design one PDF template: seven shared pages plus the three branched ones. | Per §7 and the standard in §2, designed rather than typeset. This is the page that makes a free asset read as a paid one. |
| **4** | Render seven variants by swapping the three branched pages. Pull the seven declarations per storm from `declarationsv10.json`. | Not seven documents. One document, one page swapped. |
| **5** | Klaviyo capture, the five-email sequence branched by storm, delivery tested. | |
| **6** | Ship to the email list. Nothing paid yet. | Cheapest read on whether the argument lands before money goes behind it, and it re-segments a list we hold no pain data on. |
| **7** | Read it, fix the weakest beat, then open the ads. The 1-page printable and the carousel cutdown fall out of the same source. | |

**The one thing to check before spending on ads**, ahead of any conversion number: do audit
installs arrive at `paywall_impression` carrying a named `pain`? If they land on `none`,
the handoff is broken and the audit is an expensive PDF. That is a day-7 check, not a
month-2 one.

---

*Built from the live warfare / outcomes / direct onboarding flows, the live declaration
set, and PostHog (project 455580, 90-day window, September 2026). When onboarding or
paywall copy changes, this asset changes with it: the whole value of a magnet is that it
says the same thing the app says.*
