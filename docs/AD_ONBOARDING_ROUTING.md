# Ad-Matched Onboarding Routing

Route a new user to a specific onboarding flow based on the ad they tapped, so the
onboarding continues the ad's emotional angle. Driven by an `ob=<variant>` value on
the ad's deep link, resolved on first launch.

## Sources (how the `ob=` value reaches the app)

1. **Branch (MMP) — primary.** Resolves the deferred deep link **at launch without
   waiting on ATT**, so the variant is known *before* onboarding renders. Wired in
   `AppDelegate` (`BranchAttribution.initSession`). This is the reliable path for
   paid App-Store installs.
2. **Meta deferred app link — fallback.** `AppLinkUtility.fetchDeferredAppLink` runs
   after the ATT response. Works, but on a fast first session it can resolve after
   onboarding has already locked (see Caveats), so Branch is preferred.
3. **Owned channels — direct.** Email, push, IG bio, QR, landing page links open via
   `.onOpenURL` / universal links and route immediately.

All three funnel into the same in-app override:
`SubscriptionStore.handleIncomingURL` / `assignOnboardingVariantFromAd` →
`resolvedOnboardingVariant` returns the ad-matched arm above the Remote Config
experiment. The variant is **frozen** once onboarding appears
(`lockOnboardingVariant`) so a late link can't swap the flow mid-run. An
`onboarding_variant_assigned` event (`{ variant, source }`) fires for analytics.

## The variants

**Broad arms.** The arc argues the mechanism from one emotional entry point, then
the user names their own area on a seven-row picker (one row per `HeaviestBurden`).

| Ad creative angle / hook | `ob=` value |
|---|---|
| "Who God says you are" / labels / self-worth | `identity` |
| "Peace in 60 seconds" / anxiety / the storm | `product` |
| "Picture your breakthrough" / health, provision, peace, victory | `outcomes` |
| "Answer 3 questions…" interactive hook | `quiz` |
| "The enemy has been stealing from you" / the fight | `warfare` |
| "God's promises have never failed" / trust and activate | `promises` |
| "Feel closer to God" / drifted away, come back near | `closer` |
| "Command your day in 60 seconds" / the morning routine | `command` |
| Straight-to-the-offer, no narrative | `direct` |

`command` is the ritual arm: its hook is WHEN rather than WHAT. The day is decided
in its first sixty seconds, so you speak over your finances, your body and your
household before the phone gets a vote. It is also the **lean** arm — 14 screens
against the other broad arms' 22 to 23 — because a 24-screen flow selling a
sixty-second habit argues against itself. What it drops: the storm opener, the
product recap, two of five scenes, the four analytics-only quiz questions plus the
no-input insight screen, and the plan loader. What it keeps is everything that
seeds the app or sells: the picker, the burden-matched payoff (the words the user
will actually say tomorrow morning), the taste, record-your-own, the plan reveal
and the testimonial wall.

Two consequences. Its completion event carries `battle_duration`, `already_tried`,
`hits_hardest` and `belief` as `"unknown"`, because the screens that collected them
are gone — deliberate, since nothing but that event ever read them. And it varies
angle AND depth at once, so it is not a pure angle result: `warfare` is still the
arm to control it against, but `direct` (the depth arm) is the one that says how
much of any win is just the shorter funnel. Pair it with morning-routine, "first
thing when you wake up" and 60-second creative.

**Single-issue arms.** Built to be deep linked from angle-matched creative: every
screen, the picker included, stays on the one subject the ad promised, so a healing
ad can never seed a money feed. Each row still separates the *intent* inside that
subject (`onboardingSegment` = `<flow>_<row>`, e.g. `healing_diagnosis`), which is
the granularity to optimise creative against.

| Ad creative angle / hook | `ob=` value | Seeds | Picker asks |
|---|---|---|---|
| Healing, a diagnosis, chronic pain, praying for a loved one | `healing` | `health` | "What are you believing God for right now?" |
| Provision, bills, debt, a job, business increase | `provision` | `wealth` | "What are you believing God to provide?" |
| Anxiety, overwhelm, sleepless nights, waiting on news | `anxiety` | `anxiety` | "Where do you most need His peace?" |
| Renew your mind, self-talk, how you see yourself | `renewal` | `identity` | "Where does your mind most need renewing?" |

An `ob=` value is only accepted if it matches a `SubscriptionStore.OnboardingVariant`
case, so a typo in an ad link is ignored and the user falls back to the Remote Config
experiment rather than to a blank screen.

## Adding a new angle

Angle arms (everything except `identity`, `product`, `quiz`, `closer` and `direct`)
share one driver, so a new angle is copy plus three lines of wiring:

1. Add an `OnboardingAngle` constant in
   `Views/Onboarding/Model/OnboardingAngles.swift` — scenes, a picker, and the
   analytics strings. Start `flowSchema` at 1. Depth is data too: `quizSteps`
   (default `fullQuiz`) and `showsPlanBuilding` (default true) let an arm run a
   shorter funnel without a second driver, and both `connectStyle` and
   `dailyMinutes` have to stay in any quiz you shorten — their answers outlive
   onboarding.
2. Add its case to `SubscriptionStore.OnboardingVariant`, raw value == the angle's
   `id` == the `ob=` code.
3. Add the case to the angle-arm list in `HomeView.onboardingFlow`.

`OnboardingAngleTests` then holds you to the invariants (id/case agreement, a
terminal step, unique picker rows, no dashes in copy, single-issue arms staying on
one burden). The debug panel picks the new arm up automatically.

Analytics come out as `<flow>_onboarding_started`, `<flow>_step_completed`
(`step` is the screen's index, interpreted against `flow_schema`),
`<flow>_scene_shown`, `<flow>_picker_shown` and `<flow>_onboarding_completed`
(which carries `picker_choice`). Changing an arm's step ORDER must bump its
`flowSchema`, or the historical `step` integers stop meaning the same screens.

## Branch setup (one-time)

1. Create a free Branch account, add the iOS app (bundle `com.Franchiz.SpeakLife`),
   set the Apple App Prefix/Team ID, and turn on the App Store + universal links.
2. ~~Add the Swift Package.~~ **Done** — `ios-branch-sdk-spm` 3.9.1 is pinned in
   `Package.resolved` and `BranchSDK` is linked to the app target, so
   `canImport(BranchSDK)` is now true and the wrapper in `AppDelegate.swift` is
   live code. It still no-ops on every entry point until `branch_key` is set
   (step 3), so shipping without the key changes nothing.
3. In the app target **Info** tab, add:
   - `branch_key` (String) = your Branch key from the dashboard.
   - URL Type with scheme `speaklife` (already present) — keep it.
   - **Associated Domains** capability: `applinks:<yoursubdomain>.app.link` and
     `applinks:<yoursubdomain>-alternate.app.link` (Branch gives you these).
4. Create **4 Branch links** (Quick Links), one per angle, each with **custom data**
   `ob` = `identity` / `product` / `outcomes` / `quiz`. (Set the same `ob` on a link
   *template* per ad set so you don't hand-make one per ad.)

## What URLs to post on each ad

Paste the **Branch link** that matches the creative's angle into the ad's URL /
destination field (Meta/TikTok/Google). One link per angle, reused across all ads of
that angle:

| Angle | Branch link to paste (example shape) |
|---|---|
| identity | `https://speaklife.app.link/identity` (custom data `ob=identity`) |
| product  | `https://speaklife.app.link/product`  (custom data `ob=product`)  |
| outcomes | `https://speaklife.app.link/outcomes` (custom data `ob=outcomes`) |
| quiz     | `https://speaklife.app.link/quiz`      (custom data `ob=quiz`)     |

(Branch generates the real `*.app.link` slugs; the `ob` custom data is what the app
reads.) For **owned channels** without Branch you can still use
`speaklife://onboard?ob=identity` or a universal link `…/onboard?ob=identity`.

## Caveats

- **Branch removes the ATT timing problem.** It resolves at launch, before
  onboarding, which the Meta-only path cannot guarantee.
- **Meta-only first-session timing.** If you skip Branch and rely on
  `fetchDeferredAppLink`: ATT is prompted ~1.5s in, the landing is ~2.8s, and the
  link only returns after the ATT answer — so on a fast first session it can resolve
  after onboarding locks, and the match then applies on a later launch.
- **First assignment wins.** Once a user has an ad-matched variant it's stable; later
  links don't change it.
- **Targeting, not A/B.** Ad users are deliberately paired with their best-fit
  onboarding and are not random-assigned (the override wins; `source: "ad"` keeps
  them separable from the `onboardingVariant` experiment in PostHog). Keep running
  the random experiment on organic/untargeted installs.

## Code touchpoints

- `AppDelegate.swift` — `BranchAttribution` wrapper (`#if canImport(BranchSDK)`),
  `initSession` at launch, `handleOpen` / `continue` forwarding; `checkDeferredAppLinkOnce`
  (Meta fallback, after ATT).
- `SpeakLifeApp.swift` — `.onOpenURL` → `handleIncomingURL` + `BranchAttribution.handleDeepLink`.
- `SubscriptionStore.swift` — `adOnboardingVariant`, `resolvedOnboardingVariant`
  (override precedence), `lockOnboardingVariant`, `handleIncomingURL`,
  `assignOnboardingVariantFromAd`, `OnboardingVariant` (the set of valid `ob=` codes).
- `Views/Onboarding/Model/OnboardingAngle.swift` — the shared angle model and the
  step list every angle arm is built from.
- `Views/Onboarding/Model/OnboardingAngles.swift` — every angle's copy.
- `Views/Onboarding/AngleOnboardingView.swift` — the one driver that renders them.
