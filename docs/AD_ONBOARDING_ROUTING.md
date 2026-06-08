# Ad-Matched Onboarding Routing

Route a new user to a specific onboarding flow based on the ad they tapped, so the
onboarding continues the ad's emotional angle. Implemented via the `ob=<variant>`
deep-link param + a Meta deferred app link.

## How it works

1. Each ad's deep link carries `?ob=<variant>`.
2. On a fresh install from a Meta ad, `AppLinkUtility.fetchDeferredAppLink`
   (FB SDK, called once in `AppDelegate`) recovers that link on first launch.
   For owned channels (email/push/IG bio/QR/landing page) where the app opens
   directly, `.onOpenURL` in `SpeakLifeApp` handles it instead.
3. `SubscriptionStore.handleIncomingURL` parses `ob=` and records it **once**
   (`assignOnboardingVariantFromAd`, persisted in UserDefaults — first assignment
   wins and is stable for the user).
4. `resolvedOnboardingVariant` returns the ad-matched arm **above** the Remote
   Config experiment, so `HomeView` shows the matched onboarding.
5. An `onboarding_variant_assigned` event (`{ variant, source }`) fires so PostHog
   can separate ad-matched (`source: "ad"`) from experiment users.

## URLs to post for each ad

Use the deep link that matches the ad creative's angle. **You only need these four
URLs — reuse the same one across every ad of that angle** (not one per ad).

| Ad creative angle / hook | Variant | Deep link to paste |
|---|---|---|
| "Who God says you are" / labels / self-worth | `identity` | `speaklife://onboard?ob=identity` |
| "Peace in 60 seconds" / anxiety / the storm | `product` | `speaklife://onboard?ob=product` |
| "Take back what the enemy stole" / warfare | `survey` | `speaklife://onboard?ob=survey` |
| "Answer 3 questions…" interactive hook | `quiz` | `speaklife://onboard?ob=quiz` |

> The custom scheme works for the FB deferred-app-link path (the SDK just returns
> the stored link string after install; it doesn't try to open it). If/when
> universal links are configured (Associated Domains `applinks:speaklife.app`), the
> equivalent `https://speaklife.app/onboard?ob=<variant>` form also works and is
> preferable for owned web channels.

## Setting it in Meta Ads Manager

Per ad (or ad set), in the **Ad** level → **Destination**:

1. Keep the App Store as the install destination.
2. In the **Deep link** field, paste the URL for that creative's angle from the
   table above (e.g. `speaklife://onboard?ob=identity`).
3. Publish. Every install from that ad will recover the link on first launch and
   show the matched onboarding.

Tip: keep one ad set per angle so the deep link is set once and all creatives in it
inherit the same `ob=` value.

## Caveats

- **First-session timing (important).** Meta's `fetchDeferredAppLink` only returns
  the link once ATT is resolved, and we prompt ATT ~1.5s after launch. The landing
  animation is ~2.8s, after which onboarding renders and **freezes the variant**
  (`lockOnboardingVariant`, so a late link can't swap the flow mid-run). On a fast
  first session the deferred link can resolve *after* that lock — in which case the
  ad match is recorded but applies on a **later launch**, not the first onboarding.
  If you need guaranteed first-session ad-matching, either (a) gate first-launch
  onboarding behind the deferred-link resolution with a short timeout, or (b) use an
  MMP whose link resolves at launch without the ATT dependency (below).
- **Meta deferred app links are best-effort post-ATT.** If a user denies tracking or
  Meta can't attribute, the link won't resolve and the user falls through to the
  Remote Config experiment / default — graceful, not broken. For high-volume,
  cross-network reliability (and first-session matching), an MMP (Branch / AppsFlyer
  / Adjust) is the robust upgrade: generate the same four `ob=` links there and the
  in-app plumbing is unchanged (just call `SubscriptionStore.handleIncomingURL` from
  the MMP callback, which resolves at launch before onboarding).
- **Ad-matched routing is targeting, not an A/B test.** Ad users are deliberately
  paired with their best-fit onboarding and are not random-assigned (the override
  wins, and `source: "ad"` keeps them separable from the experiment in PostHog).
  Keep running the random `onboardingVariant` experiment on organic/untargeted
  installs to keep learning which flow wins cold.
- **First assignment wins.** Once a user has an ad-matched variant, later deep links
  don't change it — their onboarding stays consistent.

## Code touchpoints

- `SubscriptionStore.swift` — `adOnboardingVariant`, `resolvedOnboardingVariant`
  (override precedence), `handleIncomingURL`, `assignOnboardingVariantFromAd`.
- `AppDelegate.swift` — `AppLinkUtility.fetchDeferredAppLink` on first launch.
- `SpeakLifeApp.swift` — `.onOpenURL` handling for direct opens.
