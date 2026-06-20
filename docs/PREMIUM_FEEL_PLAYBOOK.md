# SpeakLife — Premium Feel Playbook

> A research-backed specification for making SpeakLife *feel* like a premium app.
> No code is changed by this document — it is the spec we build from.
>
> Status: **Draft for approval** · Owner: design/eng · Date: 2026-06-19

---

## 0. The thesis in one paragraph

Across the apps and games most praised for "premium feel" — Calm, Headspace, Hallow,
Duolingo, Things 3, Flighty, Monument Valley, Alto's Odyssey, Vampire Survivors —
"premium" almost never means *more features*. It means two things working together:

1. **Consistency** — every screen looks and behaves like one careful hand made it
   ("it feels like Apple made it themselves").
2. **Juice** — the everyday actions a user already takes are wrapped in matched
   visual + haptic + sound feedback that makes them *satisfying to do*.

SpeakLife already has world-class **ingredients** (an orchestrated cold-start, a deep
haptic library, particle/celebration systems, 40+ themes). What it lacks is a **system**
that fires those ingredients consistently on the core loop. This playbook defines that
system.

---

## 1. What the research actually says

### 1.1 The five qualities reviewers describe as "premium"

| # | Quality | What reviewers say | Source signal |
|---|---------|--------------------|---------------|
| 1 | **Instant, fluid responsiveness** | Verdict forms in ~50ms; motion should feel like it "had to happen." Jank reads as cheap. | Mobile UX trend reports; game-feel writing |
| 2 | **Multisensory harmony** | "It feels so good" = matched visual + haptic + sound at equal intensity. | Apple HIG on haptics; micro-interaction research |
| 3 | **Calm visual restraint** | Whitespace, one palette, bold-but-limited type, real depth. Calm wins on "nature-inspired visuals, calming blue/green palette." | Calm/Headspace review analysis |
| 4 | **Emotional anchoring & identity** | Streaks work via loss aversion + identity, not the number. Home-screen streak widget lifted commitment 60%. | Duolingo (600+ streak experiments) |
| 5 | **Polish in the dead zones** | Empty/loading/error/first-run are designed moments, not afterthoughts. | ADA-winner reviews |

### 1.2 What games & ADA winners add

- **"Juice" is a multiplier, not a feature.** The non-functional layer (particles,
  impact sound, haptics, completion flourishes) doesn't change what the app does, only
  how it feels to do it. Vampire Survivors, Threes, and Monument Valley are praised
  *almost entirely* for juice.
- **The first 3 minutes decide retention.** Games: "if movement feels floaty, they
  uninstall." Apply disproportionate care to cold-start, onboarding, and the **first real
  declaration interaction** — not just the splash.
- **"Capture a feeling, not a feature."** Team Alto built Alto's Odyssey around "the
  coziness, calm, and comfort of being somewhere that feels like home," not high-fidelity
  mechanics. SpeakLife's "feeling" is **rooted, sealed, unshakeable peace and holy
  confidence** — every motion and sound should serve that, not generic flashiness.
- **Zen mode as a design value.** Alto's Zen mode *strips* UI, scores, and failure to
  deepen immersion. SpeakLife should have moments that remove chrome and let the Word and
  the breath take the whole screen.
- **"Feels like Apple made it."** The top compliment for Things 3 / Flighty. It comes
  from purposeful transitions, native gestures, consistent behavior, and complexity
  hidden until needed.

> Sources are listed in §9.

---

## 2. Current-state audit (what SpeakLife has today)

**Strong (keep, systematize):**
- `LandingView.swift` — orchestrated 2.8s cold-start (icon spring, wordmark cascade,
  shimmer, breathing). Respects `accessibilityReduceMotion`.
- `PremiumHaptics.swift` — 16+ context-aware patterns (heartbeat, prayerPulse,
  peacefulWave, celebrationBurst), some tied to categories.
- `CelebrationAnimations.swift` — milestone confetti with category-themed particles.
- `MicroInteractions.swift` / `GestureDelights.swift` — card-tap springs, heart ripples,
  swipe trails, magnetic buttons, pull-to-refresh.
- 40+ themes, custom photo upload, per-theme styling.

**Gaps (the premium-feel cost):**
1. **No design system.** No type scale (sizes hardcoded, mixing `AppleSDGothicNeo` and
   system). One spacing constant (`Constants.padding = 8`). Colors scattered across
   `GlobalConstants`, `Gradients`, `Theme`, and inline. Shadows vary randomly (5/10/20pt).
2. **Multisensory layer half-wired.** `AudioDelights.swift` names ~18 sounds that aren't
   really firing. Haptics exist but aren't consistently paired with sound + motion on the
   core loop.
3. **Reduce-Motion only in `LandingView`.** Every other interaction ignores it.
4. **Dead zones unpolished.** No skeletons, sparse empty states, no designed error toasts.
5. **Fragmented buttons.** 5+ custom button implementations, no unified style — taps feel
   different in different places.

---

## 3. Pillar A — The Design Token System (the "consistency" engine)

Goal: one source of truth so every screen obeys the same rules. This is what produces
"feels like Apple made it." Built on an **8pt grid with 4pt subdivisions**, Apple's de
facto convention.

### 3.1 Spacing scale (8pt grid, 4pt subdivisions)

```
xxs = 4    xs = 8    sm = 12    md = 16    lg = 24    xl = 32    xxl = 40    xxxl = 48
```
Rule: all padding/margins use these tokens. Inner spacing ≤ outer spacing. Minimum tap
target **44×44pt** for any interactive control.

### 3.2 Typography scale (semantic, not ad-hoc sizes)

Six roles. Sizes may vary, but **line-height stays a multiple of 4** (ideally 8).
Every style supports Dynamic Type.

| Token | Use | Size / Line | Weight |
|-------|-----|-------------|--------|
| `display` | Declaration hero text | 34–40 / 44 | Semibold |
| `title` | Screen titles | 28 / 32 | Bold |
| `headline` | Section headers, card titles | 20 / 24 | Semibold |
| `body` | Verse text, primary copy | 17 / 24 | Regular |
| `callout` | Secondary copy, captions of weight | 15 / 20 | Regular |
| `caption` | Labels, metadata | 13 / 16 | Medium |

Decision needed (§8): keep one display font (e.g. a refined serif/`AppleSDGothicNeo`
successor) for declaration text to give it sacred weight, with the rest on a clean
system-font stack.

### 3.3 Color tokens (semantic over raw hex)

Promote the existing palette in `GlobalConstants` into **semantic roles** so views never
reference raw hex again:

```
brand.primary     = DAMidBlue  #604FFF
brand.secondary   = DADarkBlue #4D80FF
accent.gold       = gold       #FFD700
surface.deep      = SLBlue     #192E4D
surface.card      = speakLifeBlueCell gradient
text.onDark / text.onLight / text.muted / text.gold
state.success / warning / error
```
Each token must have a light- and dark-mode value. (Audit: app is currently
dark-optimized; light mode needs verification.)

### 3.4 Elevation / shadow tokens

Three levels only — kill the random 5/10/20pt shadows:

```
elevation.flat   = none
elevation.raised = y2  blur8   12% black
elevation.float  = y8  blur24  18% black   (sheets, celebration cards)
```

### 3.5 Radius tokens

```
radius.sm = 8 (current default)   radius.md = 16   radius.lg = 24   radius.pill = 999
```

### 3.6 Motion tokens (codify the spring values from research)

These are the **canonical springs** — every animation references one of these, no more
inline magic numbers.

| Token | response | damping | Use |
|-------|----------|---------|-----|
| `motion.snappy` | 0.30 | 0.72 | Button press, toggle, favorite tap (Apple-Music feel) |
| `motion.standard` | 0.45 | 0.78 | Default transitions, card movement |
| `motion.gentle` | 0.60 | 0.80 | Reveals, breathing, calming entrances |
| `motion.deliberate` | 0.90 | 0.85 | Modal/sheet presentation |
| `motion.celebrate` | 0.55 | 0.55 | Bouncy milestone/confetti pop |

> Reference values: Apple-Music-like feel ≈ response 0.32 / damping 0.72; 0.3 snappy,
> 0.55 default, 0.9 deliberate; damping 0.5 bounce → 0.95 subtle.

### 3.7 Delivery shape (proposed)

A single `DesignSystem` namespace (e.g. `Core/DesignSystem/`) exposing
`DS.Spacing`, `DS.Type`, `DS.Color`, `DS.Elevation`, `DS.Radius`, `DS.Motion`, plus
SwiftUI conveniences (`.dsText(.display)`, `.dsCard()`, `.dsSpring(.snappy)`). Migration
is incremental, screen by screen — no big-bang rewrite.

---

## 4. Pillar B — Juice on the Core Loop (the "feel" engine)

Goal: wrap the 5 actions users take every day in **matched visual + haptic + sound**, at
equal intensity (per Apple HIG). Most parts already exist; this is wiring + tuning, not
new systems.

> **The Matched-Feedback Rule:** every juiced action defines a triplet —
> *(visual, haptic, sound)* — tuned to the same intensity & sharpness. Soft action →
> soft on all three. Big action → big on all three. Never fire one alone where a triplet
> belongs. Never let a frequent action's haptic get tiresome (HIG).

### 4.1 The five core-loop moments

| Moment | Visual | Haptic | Sound | Intensity |
|--------|--------|--------|-------|-----------|
| **Declaration reveals** | Char-by-char fade/slide (exists), `motion.gentle` | `prayerPulse` (soft) | Soft breath/swell pad | Low–calm |
| **Speak / read aloud** | `SpeakingPowerEffect` energy pulses (exists) | subtle on emphasis words only | optional ambient bed | Low, sustained |
| **Favorite a declaration** | Heart pulse + ripple (exists), `motion.snappy` | `heartbeat` | Soft "bloom" chime | Medium, warm |
| **Complete the day** | Checkmark morph + glow, gold accent | `successSequence` | Warm confirming tone | Medium-high |
| **Streak milestone** | Category confetti (exists) + count flourish | `celebrationBurst` | Triumphant short cue | High (rare → earned) |

### 4.2 Tuning rules

- **Calm-first intensity curve.** SpeakLife is a peace app, not an arcade. Default to the
  *gentle* end. Reserve high-juice (`celebrate`) for genuinely rare, earned moments
  (milestones, first-ever declaration). Frequent actions stay soft so they never tire.
- **Sound is the missing 1/3.** Finish `AudioDelights.swift`. Source a small, cohesive
  sound kit (breath pads, soft blooms, warm tones, one triumphant cue) in the same
  sonic family as the background music tracks. Every sound respects the existing music/sfx
  toggle and ducks under, not over, narration.
- **Match the music.** Sounds and background tracks should feel like one score (Alto's
  "lush piano motifs"), not stock UI blips.

### 4.3 "Zen moment" (capture-a-feeling)

Add a chrome-free mode for the declaration view: tap to hide all UI, leaving only the
Word, the background, and a slow breathing guide + ambient bed. No counters, no buttons.
This is SpeakLife's Alto Zen mode — the strongest possible expression of "rooted,
unshakeable peace." (Scope as a fast-follow after §4.1.)

---

## 5. Pillar C — Supporting polish (in service of A & B)

1. **Systematize Reduce-Motion.** One `@Environment(\.accessibilityReduceMotion)`-aware
   modifier applied to every juiced interaction (currently only `LandingView`). Reduced
   motion still keeps haptics + sound, just swaps springs for fades.
2. **Dead-zone components.** Reusable `EmptyState`, `SkeletonLoader`, and `Toast`
   (success/error) built on the tokens. Apply to declarations, audio, devotionals, Bible
   chat, community.
3. **Unified button.** One `DSButton` / `ButtonStyle` with variants (primary, secondary,
   ghost, destructive) that bakes in `motion.snappy` + matched haptic. Retire the
   one-off button implementations.
4. **Streak as identity (Duolingo lesson).** Lean into the home-screen widget
   (`PromisesWidget`) showing the streak, plus identity framing ("Day 47 of walking in
   the Word") over a bare number. Loss-aversion-aware reminders, gently worded.

---

## 6. The standard every screen must pass ("the premium checklist")

Before any screen ships, it must answer yes to all:

- [ ] Uses **only** tokens (spacing, type, color, radius, elevation, motion) — no inline
      magic numbers or raw hex.
- [ ] Every interactive control is **≥44×44pt** and gives **matched feedback** on tap.
- [ ] Transitions are **purposeful** (a `motion.*` token), never default/abrupt.
- [ ] Has designed **empty, loading, and error** states.
- [ ] Honors **Reduce Motion** and **Dynamic Type**.
- [ ] Works in **light and dark**.
- [ ] Nothing pops in abruptly; nothing janks; first paint feels intentional.

---

## 7. Proposed sequencing (for when we build)

> Pillar choice was deferred to "keep researching / spec first." When we proceed, the
> recommended order is:

1. **Tokens foundation** (§3) — unlocks everything, lowest risk, incremental migration.
2. **Core-loop juice** (§4.1–4.2) — highest "feels so good" payoff; mostly wiring.
3. **Reduce-Motion + dead zones + unified button** (§5.1–5.3).
4. **Zen moment** (§4.3) and **streak identity** (§5.4) as differentiating fast-follows.

Each step is independently shippable and reviewable.

---

## 8. Open decisions for the user

1. **Declaration display font** — keep a distinct, weighty font for declaration text
   (sacred feel) with system font elsewhere, or unify on one family?
2. **Sound kit** — source/commission a bespoke sound set, or start with a tasteful
   licensed pack matched to the existing music?
3. **Zen moment scope** — in this effort, or logged as a separate follow-up?
4. **Light mode** — is full light-mode support in scope, or stay dark-first for now?
5. **Migration appetite** — incremental screen-by-screen token adoption (recommended), or
   a focused flagship-screen showcase first (e.g. declaration view) to prove the feel?

---

## 9. Sources

- [Mobile App Design Trends 2025 (Medium)](https://medium.com/@CarlosSmith24/top-mobile-app-design-trends-to-watch-in-2025-e95f633cd6ef)
- [UI/UX Trends 2025 (Chop Dawg)](https://www.chopdawg.com/ui-ux-design-trends-in-mobile-apps-for-2025/)
- [Designing Delightful Micro-interactions (Bootcamp/Medium)](https://medium.com/design-bootcamp/designing-delightful-micro-interactions-for-mobile-apps-e37ed8bea7bc)
- [iOS 2025 UX Trends — Micro-interactions & Fluid Animations](https://medium.com/@bhumibhuva18/hot-ios-2025-ux-trends-micro-interactions-fluid-animations-and-design-principles-developers-b52673769cd6)
- [Apple HIG — Playing Haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)
- [Analyzing mindfulness app reviews: Calm vs Headspace (Relative Insight)](https://relativeinsight.com/analyzing-mindfulness-app-reviews-calm-vs-headspace/)
- [Calm Review 2026 (Selfpause)](https://www.selfpause.com/resources/calm)
- [The Psychology Behind Duolingo's Streak System (Medium)](https://medium.com/@patricia-smith/the-psychology-behind-duolingos-addictive-learning-streak-system-ce29c5374d36)
- [Duolingo Gamification (StriveCloud)](https://www.strivecloud.io/blog/gamification-examples-boost-user-retention-duolingo)
- [The "Juice" Factor: Designing Game Feel (Hackread)](https://hackread.com/the-juice-factor-designing-game-feel/)
- [Juice in Game Design (Blood Moon Interactive)](https://www.bloodmooninteractive.com/articles/juice.html)
- [Addictive Mobile Games: Gameplay Over Graphics (Wayline)](https://www.wayline.io/blog/addictive-mobile-games-gameplay-over-graphics)
- [Things 3 Review: Delightful Task Management (Medium)](https://medium.com/@pankaj_k/things-3-app-review-delightful-task-management-e9498c9abcd5)
- [Apple Design Awards 2017 (Dice)](https://insights.dice.com/2017/06/07/apple-design-awards-2017-winners)
- [Q&A with Team Alto (The Sweet Setup)](https://thesweetsetup.com/quick-qa-team-alto-makers-altos-odyssey/)
- [Cultivating Mindfulness through Alto's Odyssey (Christ and Pop Culture)](https://christandpopculture.com/cultivating-mindfulness-through-altos-odyssey/)
- [SwiftUI Animation Timing (Nil Coalescing)](https://nilcoalescing.com/blog/AnimationTimingInSwiftUI/)
- [SwiftUI Spring Animations Guide (GetStream)](https://github.com/GetStream/swiftui-spring-animations)
- [The 8pt Grid System (Prototypr)](https://blog.prototypr.io/the-8pt-grid-consistent-spacing-in-ui-design-with-sketch-577e4f0fd520)
- [Typography in Design Systems (UX Collective)](https://uxdesign.cc/mastering-typography-in-design-systems-with-semantic-tokens-and-responsive-scaling-6ccd598d9f21)
- [How Apple Designs Their UI (Superdesign)](https://www.superdesign.dev/blog/apple-design-system)
