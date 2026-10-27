# Creative Learnings

The memory of the creative engine (see `.claude/skills/creative-engine`). Newest first. Each entry
records **why** an ad won or lost at a level the next brief can build on. A bare "X won" doesn't count.

---

## 2026-10-15 — Two new leaders, and the copy DNA they share

| Ad | Format | Spend | Trials | CPT |
|---|---|---|---|---|
| PAIN-06 fever what-if (sickness) | static + long copy | $385 | 45 | **$8.56** |
| you cant fight a thought silently (active re-run) | 7-card carousel | $1,098 | 73 | **$15.04** |
| authority video | video | $478 | 29 | $16.48 |

Both are under the ~$18 one-times-ROAS line, and PAIN-06 is under the ~$9 2x cap.

Lessons:
1. **"Jesus didn't pray about it. He spoke to it."** is the mechanism line. Both winners put
   it (or the thought-silently version of it) in the first beat. Why: it names the one
   behaviour change SpeakLife sells, in a scene the viewer already believes.
2. **"(step 2 is the key)" earns the swipe**, and SpeakLife goes on that step and nowhere else,
   as the tool that makes the hard step easy ("type the thought, it hands you the verse").
   Why: the viewer meets the app at the exact moment they feel the friction it removes.
3. **Skip the setup slides.** The thought-silently carousel goes hook → steps → close. Our
   2026-10-15 white carousels dropped their two "most nights end the same way" slides for this.
4. **Close on "X doesn't get the last word. His does."**
5. **Carousels win with one-line post text; statics win with the full steps in the copy.**
6. **What-if is a storm with legs.** The fever what-if is the cheapest trial in the account. 2026-10-15
   spins it to a body what-if and a money what-if (`docs/creative/slideshows/2026-10-15/`).
   Test them before widening to other storms.

## 2026-10-01 — Full history read, main account `253451158661796` (~$46K lifetime)

Optimizing for `start_trial_mobile_app`. CPT = cost per trial start (Meta-attributed; cross-check
paid in RevenueCat). Ads with ≥ $250 spend:

| Ad | Format | Spend | Trials | CPT | CTR |
|---|---|---|---|---|---|
| you can't fight a thought silently | native TikTok-style slideshow | $1,115 | 46 | **$24.25** | 1.14% |
| 5 ways to renew | native slideshow | $341 | 14 | **$24.37** | 1.75% |
| The promise is settled | static + long copy | $337 | 13 | **$25.93** | 1.44% |
| lost overthinking (2 ads) | static + "no hype" copy | $631 | 22 | $26.55 / $30.46 | ~1.0% |
| you can't fight a thought silently (copy) | native slideshow | $575 | 18 | $31.96 | 1.74% |
| Rewire your mind (2 ads) | static | $3,745 | 107 | $33.65 / $36.10 | ~1.4% |
| Renewal: the mind repeats what it hears | static + long copy | $658 | 18 | $36.55 | 3.28% |
| how to pray | native slideshow | $370 | 10 | $37.04 | 1.37% |
| Rewire your mind v2 | static | $868 | 22 | $39.46 | 1.34% |
| trample lions | — | $531 | 13 | $40.85 | 1.24% |
| Battlefield of the Mind (+V2) | static + long copy | $636 | 15 | $42–43 | 6.6–14.7% |
| Trial Activation (May 2025, UGC video "This one app changed how I pray every morning") | video | $2,286 | 51 | $44.82 | 1.11% |
| fear to peace | — | $421 | 8 | $52.67 | 1.61% |
| TXT_01_AnxietyFirst | text | $355 | 6 | $59.21 | 1.06% |
| The Believer's Authority | — | $483 | 8 | $60.40 | 2.37% |
| UGC arcads car | AI UGC video | $249 | 3 | $83.04 | 1.00% |
| Stop begging | — | $313 | 2 | $156.47 | 6.25% |
| new identity in Christ | — | $217 | 1 | $217.04 | 0.68% |

Install-optimized winners (older, cheap installs, unknown trial quality): "secret weapon" ($1.63
CPI, 868), "God of breakthroughs" ($2.19, 646), "looking for inspo" ($0.80–2.12).

Lessons:
1. **The mind is our best storm.** Six of the top ten by CPT are about thoughts. Why: it's the
   storm everyone has daily (not a crisis subset), and "speak to it" is a concrete, believable
   mechanism for a thought ("you can't fight a thought silently"). → Lead every batch with 2+
   renewal/thought concepts; `ob=renewal`.
2. **Native organic-style slideshows beat polished ads.** The two cheapest CPTs were TikTok-format
   slideshows with lowercase captions ("step 2 is the whole key. save this.") and hashtags. Why:
   they read as content, not ads (they *serve* before they sell, so the skip reflex never fires),
   and the "step N" promise earns the swipe. → Every batch gets
   native slideshow variants; the faith-ad-formulas "no hashtags" rule doesn't apply to this format.
3. **Numbered steps / "how to" packaging works.** "5 ways to renew", "how to pray", "step 2 is the
   key". Why: a concrete, savable method lowers effort. → Use Menu/Straight Shot formulas as list
   slideshows.
4. **Promises framing converts in ads.** "The promise is settled" at $26 CPT supports Promises as the
   default onboarding. Pair it with `ob=promises`.
5. **High CTR ≠ trials.** "Battlefield of the Mind V2" (14.7% CTR) and "Stop begging" (6.25%) got
   clicks at $43 and $156 per trial. Provocation and curiosity pull the wrong clickers. → Judge on CPT,
   never CTR.
6. **Identity-in-Christ and "believer's authority" as cold openers lost.** Too abstract/churchy for
   a cold feed (Copy Vault Principle 1). Keep identity as the payoff, not the hook.
7. **Women 55+ are the cheapest installs ($3.83–3.85), women 25–54 are the volume, men cost
   30–50% more.** Caveat: at least the main 2026 winners ran in ad set `march 17 2026`
   (`120237846131480227`), which was **women only, 25–65, US+CA, iOS 17+**, so the gender skew is
   partly our own targeting, not Meta's discovery. Men's numbers come from older broad sets.
   Worth one broad (all genders, 18+) test of the same winners to see what Meta finds on its own.
8. **AI UGC lost** (arcads car, $83). Real-feeling speakers or native slideshows instead.

Correction: the earlier v2-only read ("rewire your mind lost, authority won") came from ~$745 of
spend. The main account reverses it: rewire/renewal is a proven volume winner.
