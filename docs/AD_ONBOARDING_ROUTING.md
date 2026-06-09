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

## The four variants

| Ad creative angle / hook | `ob=` value |
|---|---|
| "Who God says you are" / labels / self-worth | `identity` |
| "Peace in 60 seconds" / anxiety / the storm | `product` |
| "Picture your breakthrough" / health, provision, peace, victory | `outcomes` |
| "Answer 3 questions…" interactive hook | `quiz` |

## Branch setup (one-time)

1. Create a free Branch account, add the iOS app (bundle `com.Franchiz.SpeakLife`),
   set the Apple App Prefix/Team ID, and turn on the App Store + universal links.
2. In Xcode: **File → Add Package Dependencies →**
   `https://github.com/BranchMetrics/ios-branch-sdk-spm` → add **BranchSDK** to the
   app target. (The integration code is already committed behind
   `#if canImport(BranchSDK)`; adding the package activates it.)
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
  `assignOnboardingVariantFromAd`.
