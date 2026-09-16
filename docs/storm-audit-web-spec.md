# The Storm Audit — Web Implementation Spec

**For:** the web engineer. Self-contained. You should not need to read anything else to
build this.
**What it is:** a free, eight-question diagnostic at `speaklife.app/audit`. It names the
storm someone is in, gives them three gaps and a next step, captures an email, delivers a
personalized PDF, and sends them to the App Store on a link that pre-routes their
onboarding.
**Target:** live in a week. There is no backend.

Background, if you want it: `lead-magnet-unshakable.md` (why this asset exists and what it
has to clear), `ad-creative-brief.md` (the visual system), `AD_ONBOARDING_ROUTING.md` (the
`ob=` contract in §9).

---

## 1. Scope

| Owner | Work |
|---|---|
| **Web (you)** | The audit page, all branching, the result page, Klaviyo capture, outbound links, analytics events. |
| **Design** | Eight PDF variants and the page's visual treatment. You consume the PDFs as static files. |
| **iOS** | Nothing required for v1. There is one optional follow-up in §12. |

**No backend, no database, no server-side rendering.** Every answer lives in client state.
Scoring is a lookup table. The only network calls are the Klaviyo subscribe and the
analytics events. This should deploy as a static page.

---

## 2. Flow

```
/audit
  → Q1  storm            (8 options)
  → Q1b sub-storm        (conditional: only when Q1 = heart or people)
  → Q2  free text        (one line, stored, never parsed)
  → Q3  duration
  → Q4  what you do
  → Q5  spoken it out loud            ← hinge question
  → Q6  first hour
  → Q7  loudest voice
  → Q8  do you know a verse for this
  → email capture        ("Where should we send your plan?")
  → /audit/result        (client-side route, all state in memory)
```

One question per screen. A progress bar. Back is allowed and must preserve answers.
No question is skippable except Q2, which may be left blank (see §4).

**Total screens: 9 for most users, 10 for the two branches.**

---

## 3. Q1 and the routing table

This is the most important table in the spec. Q1 (plus Q1b where it applies) decides three
separate things: which PDF they get, which identity line the result page shows, and which
`ob=` code goes on the outbound App Store link.

**Q1: "What is heaviest right now?"**

| `storm` value | Label shown | PDF variant | `ob=` | `pain` (result copy key) |
|---|---|---|---|---|
| `mind` | My mind will not stop. | `mind` | `anxiety` | `peace` |
| `body` | My body. | `body` | `healing` | `health` |
| `money` | Money, work, the bills. | `money` | `provision` | `abundance` |
| `self` | How I see myself. | `self` | `renewal` | `identity` |
| `calling` | What I am supposed to be doing with my life. | `calling` | `outcomes` | `purpose` |
| `heart` | My joy, or something I lost. | `heart` | *see Q1b* | *see Q1b* |
| `people` | Someone I love. | `people` | *see Q1b* | *see Q1b* |
| `all` | Everything at once. | `all` | `hardtimes` | `more` |

**Q1b, shown only when `storm` = `heart`:** *"Which is closer?"*

| `substorm` | Label | `ob=` | `pain` |
|---|---|---|---|
| `loss` | I lost someone. | `grief` | `grief` |
| `flat` | Everything feels flat. The joy is gone. | `depression` | `joy` |

**Q1b, shown only when `storm` = `people`:** *"Who is on your heart?"*

| `substorm` | Label | `ob=` | `pain` |
|---|---|---|---|
| `spouse` | My marriage. | `marriage` | `marriage` |
| `child` | My kids. | `parenting` | `family` |
| `prodigal` | Someone who has walked away from God. | `prodigal` | `family` |

So: **8 PDF variants, 11 routing outcomes.** `heart` and `people` share one PDF each but
route to different onboarding arms, because the arm is what stops a grief ad seeding a
money feed.

**The `ob=` values are a closed set defined in the iOS app.** A value not in this table is
silently ignored by the app and the user falls back to a random onboarding experiment. Do
not invent new codes, do not change casing (the app lowercases, but keep them lowercase
anyway), and do not pass anything else in the link expecting the app to read it (§9).

---

## 4. Q2 through Q8

Store every answer by its machine value, not its label.

**Q2 — "Say it in your own words."** Free text, one line, 140 char cap, **optional**.
Stored as `own_words`. **Never parsed, classified, or sent anywhere except Klaviyo and the
result page.** Its only job is to be quoted back verbatim in §6 beat 1. If blank, the
result page drops that line and shows nothing in its place.

**Q3 — "How long has it been like this?"** → `duration`

| value | label | `months` (for §7) |
|---|---|---|
| `weeks` | A few weeks | 1 |
| `months` | A few months | 4 |
| `year` | About a year | 12 |
| `years` | Years | 36 |

**Q4 — "When it hits, what do you do?"** → `response`
`pray_about` (I pray about it) · `read_verse` (I read a verse) · `distract` (I try not to
think about it) · `tell_someone` (I tell someone) · `nothing` (Nothing, mostly)

**Q5 — "Have you ever said God's Word out loud over this, by name?"** → `spoken`
`never` · `once_twice` (Once or twice) · `sometimes` · `most_days` (Most days)

This is the hinge question. It decides the method label in §5 and it is the single answer
the whole result page turns on.

**Q6 — "What does the first hour of your day sound like?"** → `first_hour`
`phone` · `news` · `silence` · `worship` · `the_word` (God's Word)

**Q7 — "Whose voice do you hear about this most?"** → `loudest`
`diagnosis` (The diagnosis, or the report) · `numbers` (The numbers) · `someone_said`
(What someone said about me) · `my_own` (My own) · `gods` (God's)

**Q8 — "Do you know a verse that speaks to this exact thing?"** → `knows_verse`
`no` · `one` · `a_few` (A few) · `several` (Yes, several)

---

## 5. Derived values

All computed client-side from the answers above. Deterministic, no randomness.

### 5a. Method label → `method`

```
if spoken == "most_days"                        → "Speaker"
else if spoken == "sometimes"                   → "Speaker"
else if response == "pray_about"                → "Asker"
else if spoken in ("never", "once_twice")       → "Asker"
else                                            → "Reader"
```

Most people land **Asker**, and that is the intended result. The label is never shown
alone: it is always immediately followed by the reassurance line in §6 beat 2. **Never
render a label as a verdict.**

### 5b. The three gaps → `gaps[]`

Evaluate all six in this order, keep the first three that trigger, discard the rest.
**Never show more than three.**

| # | `gap` id | Headline shown | Triggers when |
|---|---|---|---|
| 1 | `praying_about` | You have been praying about it, not to it. | `response == "pray_about"` OR `spoken == "never"` |
| 2 | `never_spoken` | You know the verse. It has never been in your mouth. | `spoken in ("never","once_twice")` AND `knows_verse != "no"` |
| 3 | `dont_know` | You do not know what God says about this exact thing. | `knows_verse == "no"` |
| 4 | `first_hour` | Your first hour belongs to something else. | `first_hour in ("phone","news")` |
| 5 | `never_ran_it` | You have never run it longer than a few days. | `spoken in ("once_twice","sometimes")` AND `duration in ("year","years")` |
| 6 | `other_voice` | The loudest voice about this is not God's. | `loudest != "gods"` |

If fewer than three trigger, show what triggered. Do not pad.

### 5c. Waiting cost line → shown when `duration != "weeks"`

```
mornings = months * 30
"You have been carrying this for about {duration label, lowercased}.
 That is roughly {mornings} mornings your mind started on something other
 than what God said about it."
```

Render `mornings` with a thousands separator. For `years` this reads "roughly 1,080
mornings", which is the intended weight. **Do not round up for effect.**

### 5d. Input ledger line → shown when `first_hour in ("phone","news")` OR `loudest != "gods"`

Static copy, not computed. Pick one:

- If `loudest != "gods"`: *"This week, the thing you are carrying got hundreds of
  run-throughs. What God says about it got a handful."*
- Else: *"Your first hour sets the script for the other fifteen. Right now something else
  is writing it."*

### 5e. What is deliberately NOT computed

**There is no score out of ten.** Do not add one, do not let anyone talk you into one. A
number grading a person reads as a verdict on their faith, which is the wrong product and
the wrong theology. The gaps and the two lines above carry the diagnostic weight.

---

## 6. The result page

Client-side route. Five beats, **in this order**. Beat 4 is not optional and must not be
moved below the fold: it is what stops the page from being a list of someone's failures.

**Beat 1 — the storm, named**
Headline: `"You are standing in the storm of {storm name}."`
Then, if `own_words` is non-empty, their line in quotes, in serif italic, directly beneath.

**Beat 2 — the method gap**
`"And you have been praying about it. Not to it."` (vary by `method`)
Then the label, then immediately: *"Most people are. It is exactly what we were taught, and
it is half the instruction."*

**Beat 3 — your three gaps**
The `gaps[]` from §5b as three cards. Plus the §5c and §5d lines if they apply.

**Beat 4 — the turn**
1. `"Jesus never prayed about a storm."`
2. Mark 11:23-24, quoted, cited.
3. The identity line for their `pain`, large:

| `pain` | Identity line |
|---|---|
| `peace` | You have the mind of Christ. |
| `health` | You are healed and whole. |
| `abundance` | You are an heir, not a beggar. |
| `identity` | You are who God says you are. |
| `purpose` | You are called, and already equipped. |
| `grief` | You are held, and you are not alone. |
| `joy` | The joy of the Lord is your strength. |
| `marriage` | You carry peace into your home. |
| `family` | You are the one who stands for them. |
| `more` | You carry the authority Jesus gave you. |

**Beat 5 — say it now**
A button: **"Say it out loud"**. On tap, reveal their first declaration (§8) large and
centred, hold for three seconds, *then* fade in the App Store CTA. The delay is
deliberate; do not remove it.

Under the declaration: *"Not in your head. Out loud, where your ears can hear it."*

---

## 7. Email capture

Sits between Q8 and the result, framed as delivery: **"Where should we send your plan?"**
One field. Email only. No name, no phone.

- The result page must render **whether or not** the email submit succeeds. Never hold the
  result hostage to the capture, and never block on the network.
- Klaviyo subscribe, list TBD by marketing (ask before building; do not guess the list ID).
- Write these profile properties on subscribe:

| Property | Value |
|---|---|
| `audit_storm` | `storm` |
| `audit_substorm` | `substorm` or null |
| `audit_pain` | resolved `pain` |
| `audit_method` | `Reader` / `Asker` / `Speaker` |
| `audit_gaps` | comma-joined `gap` ids |
| `audit_duration` | `duration` |
| `audit_own_words` | `own_words` (may be empty) |
| `audit_completed_at` | ISO 8601 |

The email sequence branches on `audit_storm`, so that property must always be set.

PDF delivery: email the variant matching `audit_storm` (eight files, §8). Also expose a
direct download link on the result page, because inbox delivery loses roughly a third.

---

## 8. PDF variants and first declarations

Eight static files. Design supplies them; you map and serve them.

| `storm` | File | Verse on the page | First declaration (beat 5) |
|---|---|---|---|
| `mind` | `unshakable-mind.pdf` | Isaiah 26:3 | You gave me Your own peace, and I carry it into every room. *(John 14:27)* |
| `body` | `unshakable-body.pdf` | Isaiah 53:5 | Thank You Jesus, by Your wounds I am healed and whole. *(Isaiah 53:5)* |
| `money` | `unshakable-money.pdf` | Philippians 4:19 | You meet every need of mine from the riches of Your glory. *(Philippians 4:19)* |
| `self` | `unshakable-self.pdf` | 2 Corinthians 5:17 | I am a new creation in You, and the old is gone for good. *(2 Corinthians 5:17)* |
| `calling` | `unshakable-calling.pdf` | Jeremiah 29:11 | Your plans for me are hope and a future, and I walk in them today. *(Jeremiah 29:11)* |
| `heart` | `unshakable-heart.pdf` | Psalm 34:18 | You hold me close and steady my spirit with Your own strength today. *(Psalm 34:18)* |
| `people` | `unshakable-people.pdf` | Psalm 127:1 | You build my house Yourself, and what You raise stands firm. *(Psalm 127:1)* |
| `all` | `unshakable-all.pdf` | Psalm 46:1 | You are my refuge and my strength, and You are here the second I call. *(Psalm 46:1)* |

Every declaration above is verbatim from the app's live declaration set. **Do not edit,
reword, or re-punctuate them**, including the absence of em dashes, which is a brand rule.
If a line looks like it has a typo, it does not. Ask.

---

## 9. The outbound link (do not get this wrong)

The App Store CTA, the QR on the PDF, and every link in the email sequence carry the `ob=`
code from §3.

**Owned-channel form** (what you will use):

```
https://speaklife.app/onboard?ob=<code>&utm_source=audit&utm_medium=owned&utm_campaign=storm_audit&utm_content=<storm>
```

For paid traffic pointing *at* the audit, marketing supplies Branch links; that is not your
concern. Your concern is the link going *out* of the audit.

**What the app actually reads:** only `ob`. `SubscriptionStore.handleIncomingURL` pulls the
single `ob` query item and ignores every other parameter. The UTMs are for our attribution,
not for the app.

**Two consequences worth knowing:**

1. **First assignment wins.** Once a user has an ad-matched variant it is stable, and a
   later link will not change it. So the audit link has to be the first one they tap. Do
   not put a second, different `ob=` link earlier in the same email.
2. **`ob=` selects the onboarding arm, not the paywall headline.** The app resolves the
   paywall's `pain` from what the user picks *inside* that arm. The audit's contribution is
   that they land in the arm matched to their storm, so the picker is already on-subject.
   Passing `pain` on the URL does nothing today. See §12.

---

## 10. Analytics

Fire to PostHog (project 455580, existing web key). Event names are lowercase snake_case.

| Event | When | Properties |
|---|---|---|
| `audit_started` | Q1 renders | `utm_source`, `utm_campaign` |
| `audit_question_answered` | each answer | `question` (`q1`…`q8`), `value` |
| `audit_email_submitted` | submit succeeds | `storm`, `pain` |
| `audit_completed` | result renders | `storm`, `substorm`, `pain`, `method`, `gaps`, `duration`, `has_own_words` (bool) |
| `audit_declaration_revealed` | "Say it out loud" tapped | `storm` |
| `audit_cta_tapped` | App Store link tapped | `storm`, `ob` |
| `audit_pdf_downloaded` | direct download tapped | `storm` |

Send `has_own_words` as a boolean. **Do not send `own_words` itself to PostHog** — it is
free text about someone's marriage, health or child, and it belongs in Klaviyo for the
email sequence and nowhere else.

---

## 11. Build notes

- **Mobile first.** Most traffic is IG and TikTok in-app browsers. Test in both; they are
  not Safari.
- One question per viewport, no scrolling to find the options, thumb-reachable.
- **Answers survive a refresh** (sessionStorage). Losing eight answers to a mistap is the
  main drop-off risk after length.
- Preload the result page assets during Q6 so beat 1 is instant.
- Visual system: inherit `ad-creative-brief.md` §2. Dark, near-black ground, gold accent,
  rounded sans, scripture in serif italic. It should feel like the app's onboarding,
  because it is the same argument.
- **No em dashes or en dashes anywhere in the copy.** Brand rule, enforced in the app's own
  tests. Use two sentences.
- Accessibility: the whole thing must be keyboard-navigable and screen-reader sane. Beat 5
  reveals text, not an animation-only effect.

---

## 12. Out of scope, and one optional iOS follow-up

**Out of scope for v1:** accounts, saving results, retaking, sharing a result card,
comparing over time, anything server-side.

**The one iOS follow-up worth raising** (not yours to build, and the audit works without
it): the app could accept a `pain=` parameter alongside `ob=` and stamp the onboarding
segment from it, so the paywall headline matches what the audit already learned. Today that
parameter is ignored. It is a small change in `SubscriptionStore.handleIncomingURL` plus
the segment stamp. Worth doing only if the audit proves out.

---

## 13. Acceptance criteria

1. Eight questions, nine screens for most users and ten for the `heart` and `people`
   branches. Back preserves answers. Refresh preserves answers.
2. Every one of the 11 routing outcomes in §3 produces the correct PDF, identity line and
   `ob=` code. **Test all eleven**, not a happy path.
3. `gaps[]` never exceeds three and follows the §5b priority order exactly.
4. The result page renders fully with Q2 left blank, and with the Klaviyo call failing.
5. No score out of ten appears anywhere.
6. The App Store link carries exactly one `ob` parameter, lowercase, from the closed set.
7. `own_words` reaches Klaviyo and does not reach PostHog.
8. Works in the Instagram and TikTok in-app browsers on iOS and Android.
9. No em dashes or en dashes in any rendered copy.

---

*Content is drawn from the live app: declarations from `declarationsv10.json`, identity
lines from `UserPain.problem`, `ob=` codes from `SubscriptionStore.OnboardingVariant`. When
those change, this changes with them.*
