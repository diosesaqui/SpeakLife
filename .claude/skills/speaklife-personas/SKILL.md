---
name: speaklife-personas
description: The SpeakLife persona bank. One avatar (a believer in a storm who has been praying about it but not speaking to it) broken into concrete personas, each mapped to the storm SpeakLife solves, the onboarding arm its ad lands in (`ob=` deep-link code, Promises vs Storm), its anchor verse, and the words that persona actually uses. Use whenever you need to aim copy, an ad, a hook, a slideshow, or a test batch at a specific person — "write this for a new mom", "what personas should we test", "spin this winner across personas", "who else does this angle work for", "which ob code for this ad" — and before running any formula from faith-ad-formulas. Also use to pick the right deep link so the ad and onboarding say the same thing.
---

# SpeakLife Persona Bank

From the Copy Vault, Principle 3: **one avatar, many personas.** Meta's algorithm stops finding
new buyers when every ad speaks to the same generic person. In the 2026 model the creative IS the
targeting, so each persona we write to is effectively a new audience Meta goes and finds.

## The avatar (never changes)

A believer facing something real, who already prays about it, and has never been taught to
*speak* God's Word over it the way Jesus spoke to the storm. They don't need convincing that God is
good. They need a daily, 60-second way to put His promises to work over their own life.

SpeakLife's answer, in one line: **verse-rooted declarations spoken out loud every morning, over the
exact area of life under pressure.**

## Who Meta is actually finding (live data — refresh it)

Meta picks the audience from behaviour, so the account's own breakdown tells us which personas to
write for first. Refresh before planning a batch (Meta ads MCP → `ads_get_ad_entities`,
`level=ad_account`, `breakdowns=[age, gender]`, `date_preset=maximum`).

Ad accounts:
- **`253451158661796` (named "Riccardo Washington")**: the main SpeakLife history, ~$46K spend,
  optimizing for `start_trial_mobile_app`. **Use this one for persona and winner reads.**
- `2082620432359498` SpeakLife v2: small (~$745), optimizes for `fb_mobile_add_payment_info`.
- `967944814851435` SpeakLife: disabled, not queryable.

Lifetime snapshot, main account, 2026-10-01 (cost per install; trials aren't broken out by age):

| Age | Women CPI | Men CPI | Women CTR |
|---|---|---|---|
| 65+ | **$3.85** | $5.17 | 1.50% |
| 55–64 | **$3.83** | $5.41 | 1.44% |
| 45–54 | $4.49 | $6.43 | 1.23% |
| 35–44 | $5.10 | $6.60 | 0.80% |
| 25–34 | $5.36 | $6.29 | 0.76% |
| 18–24 | $8.64 | $9.36 | 0.80% |

Women took ~75% of spend and ~79% of installs. Women 55+ are the cheapest and most engaged; women
25–54 are the volume. Men convert, at 30–50% higher cost. Caveat: the 2026 winning ad set was
targeted women 25–65 only, so part of this skew is our targeting, not Meta's discovery. Check an
ad set's `targeting` before reading a breakdown as a persona signal.

What the winning ads say about the persona (see `docs/creative/LEARNINGS.md` for the full table):
- **The mind is the #1 storm.** The best cost-per-trial ads are all about thoughts: "you can't
  fight a thought silently" ($24 CPT, 46 trials), "5 ways to renew" ($24), "lost overthinking"
  ($27–30), "Rewire your mind" ($34–36, 107 trials across two ads), "the mind repeats what it hears"
  ($37), "Battlefield of the Mind" ($42). Write for **the woman whose own thoughts are the battle**:
  3 a.m. what-ifs, the inner critic, the replayed conversation. `ob=renewal` / `ob=anxiety`.
- **Promises framing works in ads too.** "The promise is settled" got $26 CPT, supporting the
  Promises onboarding.
- **Weaker as cold angles:** fear-to-peace ($53), anxiety-first copy ($59), "The Believer's
  Authority" ($60), identity in Christ ($217), "Stop begging" ($156 CPT despite a 6% CTR; the
  provocation pulls clicks, not trials).
- **Don't age-target.** Keep the audience broad and write the moment for her so Meta keeps finding
  her. Never put age or gender in the copy ("Ladies over 50…" breaks Personal Attributes and
  narrows learning). Show it through the moment: grandkids, an empty nest, retirement, a
  husband's health.

## How to build a persona (the formula)

A persona is not a demographic. It is **a role + a moment + the storm + the words they'd use.**

| Slot | Bad | Good |
|---|---|---|
| Role | "Christian woman 35-54" | "Mom of a 16-year-old who stopped coming to church" |
| Moment | "struggles with worry" | "lying awake at 11pm listening for the car" |
| Storm | "family" | `prodigal` |
| Their words | "spiritual warfare over my household" | "I just want my kid back" |

Write the moment so specific the reader thinks *"that's my house."* That recognition is the whole
job of the hook (Copy Vault Principle 1: clear, not clever).

## Persona → storm → landing map

The `ob=` code on the install link decides what onboarding they see. **Scent continuity:** the
first onboarding screen must feel like the next sentence of the ad. Pick the code that matches the
persona's storm, never a generic one when a specific one exists.

| Storm | `ob=` code | Lands in | Anchor verse | Sample personas |
|---|---|---|---|---|
| Health | `healing` | healing arm, or Storm (Health preselected) when in the storm bucket | Psalm 107:20, Isaiah 53:5 | waiting on scan results; chronic pain at 40; caregiver for a sick parent; post-surgery recovery |
| Finances | `provision` | provision arm / Storm (Finances) | Philippians 4:19 | single mom between paychecks; small-business owner in a slow quarter; just laid off; first-gen debt payoff |
| Fear & anxiety | `anxiety` | anxiety arm / Storm (Fear & anxiety) | Isaiah 26:3, John 14:27 | 3 a.m. thought spiral; new job dread; panic before the commute; nurse after a hard shift |
| Thoughts / identity | `renewal` | renewal arm / Storm (Who I am) | Romans 12:2, 1 Cor 2:16 | the inner critic on replay; comparison on Instagram; "I'll never change" |
| Taking back what was stolen (broad) | `warfare` | warfare arm | John 10:10 | "the enemy has been taking my peace, sleep, joy" |
| The won life (broad) | `outcomes` | outcomes arm | John 10:10, Romans 8:37 | tired of waiting; wants to see the restored body, the open door |
| Mornings / authority (broad) | `command` | command arm / Storm (default "your storm") | Mark 11:23 | wakes up already behind; scrolls before praying; wants to start the day on offense |
| Specific fear | `fear` | fear arm | 2 Timothy 1:7 | flying, driving, a diagnosis they keep rehearsing in their head |
| Grief | `grief` | grief arm | Psalm 34:18, John 11:35 | widow at month four; lost a parent; miscarriage |
| Facing death | `mortality` | mortality arm | 1 Cor 15:55 | aging, a scary diagnosis, the quiet-house fear |
| Prodigal | `prodigal` | prodigal arm | Luke 15:20 | parent of an adult child who walked away |
| Purity | `purity` | purity arm | Matthew 4:4 | man who "meant it last time too" |
| Heaviness | `depression` | depression arm | Psalm 42:11 | "everything still works, nothing lands" |
| Parenting | `parenting` | parenting arm | Deuteronomy 6:7, Isaiah 54:13 | new dad; mom of teens; grandparent raising grandkids |
| Addiction | `addiction` | addiction arm | John 8:36 | 90 days sober; the drink, the vape, the feed |
| Marriage | `marriage` | marriage arm | Mark 10:9, Proverbs 24:3 | "still married, not close"; spouse who doesn't believe |
| Everything at once | `hardtimes` | hardtimes arm | Isaiah 43:2, 2 Cor 4:8 | job, health and family hit in the same month |
| Broad / trust | none or `promises` | Promises arm (default organic) | 2 Corinthians 1:20 | "I believe God comes through for other people" |

Storm-bucket note: only codes listed in `Views/Onboarding/Storm/storm_configs.json` (`healing`,
`provision`, `anxiety`, `renewal`, `command`) can be coin-flipped into the Storm flow, weighted by
Remote Config `stormAdShare`. The rest always land on their angle arm. Verify both files before
quoting the map, because arms get added. Source of truth for arm copy:
`Views/Onboarding/Model/OnboardingAngles.swift`.

## The two onboarding frames ads must hand off to

- **Promises (current default):** *God's promises have never failed. The only question is whether
  you'll trust them and put them to work over your own life.* Ads feeding it should open on a settled
  fact about God and turn the reader toward activation ("every promise has your name on it").
- **Storm (in A/B):** *Name your storm. Speak His Word over it before you ever see a price.* Ads
  feeding it should name one concrete storm and promise a ready-made declaration for that exact
  moment ("words ready for the 3 a.m. thoughts", "a healing declaration for every appointment").

Same persona, two frames: a widow can get a Promises ad ("He is close to the brokenhearted, and He
meant that for you") or a Storm ad ("For the ordinary Tuesday four months in, a word ready to
speak"). Testing both against one persona tells you which frame converts, not just which persona.

## Voice-of-customer rules

- Write the persona's words, not ours. "I just want peace" beats "spiritual authority over anxiety".
- The moment carries the emotion; the verse carries the promise; the app carries the method.
- **Call higher** (CLAUDE.md Rule 12): name the storm as the setting, never declare it over them.
  "For the 3 a.m. thoughts" is fine. "Your anxiety is winning" is not.
- **Meta Personal Attributes:** never bind *you* to a religion, health, mental-health, financial or
  family state ("Are you a Christian mom struggling with anxiety?"). Describe the moment instead
  ("lying awake at 11pm listening for the car"). A first-person speaker talking about themselves is
  fine ("I prayed over my son for two years…"). Plain Christian words in the content (Jesus,
  Scripture, declaration) are how the algorithm learns who it's for, so no religious callout is needed.
- Never promise another free person will change (prodigal, marriage, parenting). Promise God's
  faithfulness and the reader's own standing.

## Spinning a persona list fast

Given a storm, produce 5 personas by varying one axis at a time:
1. **Life stage:** new parent / mid-career / empty nester / retired.
2. **Role:** caregiver, business owner, pastor's wife, nurse, student, veteran.
3. **Time of day the storm hits:** 6 a.m. dread, the commute, 3 a.m., Sunday night.
4. **Who they're carrying it for:** themselves, a child, a spouse, a parent.
5. **How long:** this week vs. "year three of this".

Hand the list to `faith-ad-formulas` and run one formula across all five.
