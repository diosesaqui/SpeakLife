# Attribution / MMP: what SpeakLife has, what it's missing, and what AppsFlyer costs

Written to answer two questions: *what would it take to add AppsFlyer*, and
*is AppsFlyer the right one*. Short version: yes, AppsFlyer over Branch — but
only once paid spend is real, and there are two free fixes that beat either
of them per hour spent.

---

## 1. Where the app stands today

| Piece | State |
|---|---|
| `AcquisitionAttribution` | Live. First-touch channel per person, priority-ranked, sealed at 24h, mirrored to PostHog person properties + RevenueCat subscriber attributes. |
| Apple Search Ads | Live and **deterministic**. `AAAttribution` token exchanged against `api-adservices.apple.com`, 3 retries. This is the strongest signal the app has. |
| Meta | Partial. `AppLinkUtility.fetchDeferredAppLink` only, and only for campaigns that carry a deferred link — and it runs *after* the ATT answer. `acquisition_channel = meta` is a floor, never the total. |
| TikTok | **Nothing.** TikTok Business SDK sends events *to* TikTok; it returns no attribution. Every TikTok install files as `organic`. |
| Google | **Nothing.** Same. |
| SKAdNetwork | Conversion value now owned by the Meta SDK alone; TikTok stands down via `disableSKAdNetworkSupport()`. The 52 `SKAdNetworkItems` entries are inert (see §4). |
| Branch | Package now added (`ios-branch-sdk-spm` 3.9.1) and the wrapper is live code, but it no-ops until `branch_key` is in Info.plist. Two values still needed: the key, and the Associated Domains entitlement for OneLink-equivalent deep links. |
| RevenueCat | 5.61.0, attribution namespace already used (`setMediaSource`, `setFBAnonymousID`, `setFirebaseAppInstanceID`). |

**The two gaps that cost money right now:**

1. **TikTok and Google have no CAC.** Their installs land in the `organic`
   bucket, which simultaneously overstates organic and makes those channels
   unpriceable. Any "organic is our best channel" read off PostHog today is
   partly TikTok spend wearing a disguise.
2. **Two SDKs were writing the same SKAdNetwork conversion value.** Each
   install gets one 6-bit value and `updatePostbackConversionValue` is
   last-writer-wins. Meta's SDK writes it off automatic in-app-purchase
   logging (on by default, never disabled here) and TikTok's writes it from a
   schema fetched at runtime. Whichever wrote second won, and neither knew it
   lost. Fixed in §4.

---

## 2. Which MMP

| | AppsFlyer | Branch | Adjust | Tenjin / Singular |
|---|---|---|---|---|
| Free tier | Zero plan: 12,000 **attributed** conversions as a ONE-TIME welcome package, spent once and gone (12-month expiry). Organic installs are never billed. Not a monthly allowance. | Free to 10,000 **MAU**, standard attribution included. A recurring ceiling, not a one-time grant. | None, annual contract | Free/cheap tiers, thinner support |
| Paid | ~$0.07/conversion (Growth), $0.03–0.05 negotiated | Subscription by MAU | Enterprise | Usage |
| Meta / TikTok / Google as MMP partner | All three, first-class, cost + SKAN postbacks | Weaker on ad-network attribution; the product has drifted toward linking | All three | Yes |
| SKAN conversion-value management | Yes, and it becomes the single writer | Limited | Yes | Yes |
| RevenueCat integration | Native, mature (`setAppsflyerID` + server-side purchase events) | Exists | Exists | Partial |
| Deferred deep link without ATT | OneLink, yes | Yes — Branch's strongest feature | Yes | Yes |

**Recommendation: AppsFlyer**, and it *replaces* Branch rather than joining
it — two MMPs double-count every install.

Why it wins here specifically:

- It closes both gaps above at once. Branch closes the deep-link half of the
  `ob=` routing problem and leaves TikTok/Google CAC exactly where it is.
- The free tier fits the shape of this app. Organic installs are free, so a
  devotional app with a large organic tail only pays for the paid installs it
  actually bought. But the 12,000 is a ONE-TIME welcome package, not a monthly
  allowance — see the correction in §6.
- RevenueCat already carries the attribution plumbing. One line
  (`setAppsflyerID`) makes trials, conversions and *renewals that happen while
  the app is closed* land on the right channel. That is the half of LTV the
  client SDK physically cannot see, and it is the half that decides CAC payback.
- Meta, TikTok and Google all treat AppsFlyer as an approved MMP, so cost data
  flows back in and ROAS stops being a spreadsheet join.

**When not to do this:** if paid spend is under roughly $2–3k/month, an MMP is
a week of setup and a permanent integration to maintain in exchange for numbers
you can still get by reading three ad dashboards. In that case do §4 and stop.
The threshold question is simply: *are TikTok and Google getting real budget?*
If the answer is "not yet", this can wait.

---

## 3. What it takes to add AppsFlyer

### Already done (this branch)

`AppsFlyerAttribution` + `AppsFlyerBridge` in `App/AppDelegate.swift`, written
to the same shape as the existing `BranchAttribution` wrapper and guarded by
`#if canImport(AppsFlyerLib)`, so it compiles to nothing until the package is
added. Call sites are wired: `configure()` at launch, `handleOpen` /
`handleUserActivity` in `AppDelegate`, `handleDeepLink` in `SpeakLifeApp`'s
`.onOpenURL`. Conversion data maps into `AcquisitionAttribution.record(...)`
and OneLink's `ob=` into `SubscriptionStore.assignOnboardingVariantFromAd`.
`AcquisitionChannel.from` now recognises `bytedanceglobal_int` as TikTok.

**Not verified by a build** — this environment has no Xcode. Expect to fix
signature drift against whatever SDK version you pin.

### Xcode / project (≈1 hour)

1. **File → Add Package Dependencies** →
   `https://github.com/AppsFlyerSDK/AppsFlyerFramework` → add `AppsFlyerLib`
   to the app target. (Deployment target 17.0 is comfortably above its minimum.)
2. **Info.plist** — add the two config keys the wrapper reads:
   - `AppsFlyerDevKey` (String) — from the AppsFlyer dashboard
   - `AppsFlyerAppleAppID` (String) — the numeric App Store id, digits only
3. **Info.plist** — add `NSAdvertisingAttributionReportEndpoint` =
   `https://appsflyer-skadnetwork.com/` so Apple copies SKAN postbacks to
   AppsFlyer directly.
4. **Info.plist** — replace the 52 `SKAdNetworkItems` with AppsFlyer's
   maintained list (~150). Missing ids are silently unattributed installs.
5. **Associated Domains capability** — the entitlements file has none today.
   OneLink needs `applinks:<subdomain>.onelink.me` (plus the AppsFlyer-provided
   alternate). Without this, install attribution still works; *deferred deep
   linking and the `ob=` onboarding match do not.*
6. **Decide the SKAN conversion-value owner.** Set Facebook's
   `FacebookSKAdNetworkReportEnabled` to `false` and let AppsFlyer own the
   value. Leaving both on is the clobbering problem, just with a new
   participant.

### Dashboard / accounts (≈1 day, mostly waiting on approvals)

1. AppsFlyer account → add iOS app (bundle `com.Franchiz.SpeakLife` + App Store id).
2. Link the networks: Meta (needs AppsFlyer set as MMP in Events Manager and
   the ad account linked), TikTok for Business, Google Ads (link id).
3. Apple Search Ads: **decide who wins.** The in-app `AAAttribution` path is
   deterministic and already works. Either leave it as the authority (it
   outranks everything at priority 100 anyway) or turn AppsFlyer's ASA
   connector on and accept two sources describing the same install.
4. Conversion Studio: define the SKAN conversion-value schema. For a
   subscription app the useful ladder is trial start → paywall view → purchase,
   not raw revenue buckets.
5. OneLink template + one link per onboarding angle, each carrying custom data
   `ob=identity|product|outcomes|quiz|warfare|promises|closer`
   (see `docs/AD_ONBOARDING_ROUTING.md` — the Branch link table maps 1:1).
6. RevenueCat → Integrations → AppsFlyer. Confirm your RC plan includes
   third-party integrations before counting on server-side revenue events.

### Validation (≈half a day + a release)

Attribution cannot be tested in the simulator. Ship to TestFlight, install from
a real OneLink on a real device, and check: the AppsFlyer dashboard shows the
install non-organic; PostHog shows `acquisition_attributed` with
`is_upgrade = true` and the right `acquisition_channel`; the onboarding arm
matches the link's `ob=`; RevenueCat shows `$appsflyerId` on the subscriber.

Then give it **two weeks** before trusting any channel number.

### One timing note

`AcquisitionAttribution` writes `organic` 8 seconds after launch if nothing
else has spoken, and AppsFlyer's conversion callback waits on the ATT answer
(10s timeout as configured). So on a slow ATT response the person is stamped
organic first and *upgraded* to `meta`/`tiktok` when AppsFlyer replies. That is
by design — organic is priority 10, the record stays open for 24h — but it
means `acquisition_attributed` fires twice for those installs. Filter on
`is_upgrade` when counting.

---

## 4. The free fixes, and one correction

### Done: one SKAdNetwork conversion-value writer

`AppDelegate.initializeTikTokSDK()` now calls `config.disableSKAdNetworkSupport()`
before `initializeSdk`, and `Info.plist` sets `FacebookSKAdNetworkReportEnabled`
to `true` explicitly rather than leaning on the SDK default. Meta owns the
value; TikTok stands down. TikTok documents this exact call for the case where
another SDK owns SKAN.

Meta gets it because it is the larger paid channel and already owns the
deferred-app-link path. To flip: delete the `disableSKAdNetworkSupport()` line
and set `FacebookSKAdNetworkReportEnabled` to `false`. Never both, and never a
third writer in app code.

**Remaining half, and it is a dashboard job, not a code one:** the value is
only meaningful once the schema in Meta Events Manager reflects subscription
value — paywall view → trial start → paid conversion, not raw revenue buckets.
Until that schema is set, Meta is now writing a *consistent* value rather than
a contested one, which is strictly better but not yet the win.

Whether TikTok was actually clobbering depends on whether a SKAN schema was
ever uploaded to TikTok Events Manager — its SDK writes from a remote config,
so with no schema it may have been writing nothing. Standing it down costs
nothing either way, and removes the question.

### Correction: `SKAdNetworkItems` is not a fix

An earlier draft of this doc said to expand the 52-entry `SKAdNetworkItems`
list to AppsFlyer's ~150. **That was wrong, and doing it would buy nothing.**

`SKAdNetworkItems` is a key for apps that **display** ads — it declares which
ad networks may serve ads *inside* the app, and only ads from listed networks
are eligible for install validation. SpeakLife is an advertised app, never a
publisher: the AdMob imports in `Core/GoogleAdMob.swift` and
`Core/Components/AdBanner.swift` are commented out, and no ad SDK is in
`Package.resolved`. Nothing reads the key.

The list is also malformed for its own purpose — Apple expects an array of
dicts keyed `SKAdNetworkIdentifier`, and this is an array of bare strings —
which is a second sign it has been dead since AdMob was removed. Left in place
with an explanatory comment rather than deleted, since removing it changes
nothing either.

`SKAdNetworkSupportEnabled` next to it is not an Apple key and no SDK in this
project reads it. Also left alone.

### Unrelated, noticed in passing

`Info.plist` sets `NSAllowsArbitraryLoads = true`, which disables App Transport
Security app-wide. Not an attribution problem, but worth a look on its own.

---

## 5. Review findings: downloads, purchases, attribution

Six faults were found reviewing these paths. All six are now fixed.

### Fixed in code

- **Cancellations from RevenueCat were never reported.** `applyCustomerInfo`
  set `subscriptionGroupStatus = premiumActive ? .subscribed : nil` and then
  tested `!premiumActive && subscriptionGroupStatus != nil` — the branch it was
  testing for had just set that value to nil. Previous state is captured first
  now.
- **The install event and the first-launch background-music default shared the
  `hasLaunchedBefore` key.** `didFinishLaunching` runs before the view's
  `.onAppear`, so the install dedupe consumed the flag and the music default
  never applied. Separate keys, the new one seeded from the old so the existing
  base does not re-fire an install.
- **`userProperties` was mutated across threads with no lock**, and read
  unsynchronized when replaying into a newly registered provider.
- **`sessionStartTime` was guarded by `providersLock`**, which guards an
  unrelated array, and written under no lock at all in `startSession`.

### Fixed by handing revenue to RevenueCat

Two faults had the same root and the same fix. Decided: **RevenueCat and
PostHog own revenue; the app stops computing it.**

- **Lifetime revenue was not in USD.** `product.price` is StoreKit's price in
  the buyer's local currency, and it went straight into
  `recordPurchase(revenueUSD:)`. A subscriber paying ¥5,800 added 5,800 to
  `lifetime_revenue_usd`. Historical values in that field are contaminated and
  cannot be repaired from the client.
- **Renewals and trial conversions were never recorded.** `recordPurchase` had
  one call site, the in-app flow, always `isRenewal: false`. Renewals happen on
  Apple's servers while the app is shut. So lifetime revenue was permanently
  first-purchase price, and `trial_converted` — written `false` at trial start
  with no reachable path to `true` — read as zero conversions for everyone.

What changed: `GrowthMetrics` no longer accumulates revenue, no longer emits
`revenue_recorded`, and no longer writes `lifetime_revenue_usd`,
`purchase_count`, `first_purchase_at`, `last_purchase_at` or `trial_converted`.
`recordPurchase` is replaced by `recordPurchaseDimensions`, which sets `plan`
and `billing_term` only — the part RevenueCat's payload does not carry.

**The load-bearing detail.** RevenueCat's PostHog integration runs server-side
and chooses which PostHog person a renewal belongs to by reading the
`$posthogUserId` subscriber attribute. The app's existing `aliasUser` call runs
on the client and joins only what the client itself sends — it cannot help a
renewal that fires while the app is shut. Without the attribute, RevenueCat's
revenue keeps landing on RC-keyed person records with no behaviour on them,
which is exactly the 78-versus-3,914 zero-overlap split `GrowthMetrics`
documents. `linkRevenueIdentity` now pushes PostHog's distinct id into
RevenueCat on every launch, so the link runs in both directions.

### Still required, in the RevenueCat dashboard

Handing revenue to RevenueCat is only half done in code. **Turn on the PostHog
integration in the RevenueCat dashboard** (Integrations → PostHog, with the
PostHog project API key). Confirm the RevenueCat plan includes third-party
integrations. Until that is on, revenue is now reported by nobody: the app has
stopped and RevenueCat has not started.

Dashboards keyed on `lifetime_revenue_usd`, `purchase_count`, `first_purchase_at`,
`last_purchase_at` or `trial_converted` will stop updating and must be rebuilt
on RevenueCat's PostHog events. That is the accepted cost of the decision — the
old numbers were wrong in a way that could not be corrected in place.

## 6. Branch vs AppsFlyer: pricing and trade-offs

**Confidence note.** Both vendors' own pricing pages are unreachable from this
environment, so every figure below comes from third-party summaries and should
be confirmed on the vendor page before signing anything. The *shape* of each
model is consistent across sources and is what the recommendation rests on; the
exact dollar figures are the part to verify.

### Correction to §2

An earlier version of the table read the AppsFlyer free tier as ~12,000
attributed conversions **per month**. It is not. It is a **one-time welcome
package** of 12,000 measured conversions, usable until spent or until 12 months
pass, whichever comes first. After that, Growth is ~$0.07 per conversion with
no recurring free allowance. Organic installs are still never billed.

That inverts the earlier reasoning. AppsFlyer is not "free for a long time at
this spend" — it is free until you have bought 12,000 installs, once, ever.

### The two pricing models are not comparable in shape

| | AppsFlyer | Branch |
|---|---|---|
| Free | 12,000 attributed conversions, one-time, 12-month expiry | Up to 10,000 MAU, recurring, standard attribution included |
| Meter | Per attributed conversion (~$0.07 Growth; ~$0.03–0.05 negotiated Enterprise) | Per MAU, contracted |
| Paid entry | Usage-based, scales smoothly from $0 | Reported ~$199/mo (Activation) to ~$499/mo (Engagement), enterprise-contracted |
| Cost driver | How much you **buy** | How many people **use the app** |
| Organic tail | Free | Counts against the cap |

The distinction matters for SpeakLife specifically: it is a devotional app with
a large organic base and (so far) modest paid spend. AppsFlyer bills the small
number; Branch bills the large one.

### Where each one is actually better

**AppsFlyer**
- Broadest and best-maintained ad-network integrations. Meta, TikTok and Google
  all treat it as a first-class MMP, so cost data flows back and ROAS is a
  report rather than a spreadsheet join.
- Best-in-class SKAN handling, and it becomes the single conversion-value owner
  — which is the fault §4 just worked around by hand.
- Mature RevenueCat integration: trials, conversions, renewals and refunds
  arrive with real USD amounts, which also fixes both open findings in §5.
- Cost scales with spend, so a month with no ad budget costs nothing.
- Against it: the free grant is finite and non-renewing. Once spent, every
  attributed install is a line item forever.

**Branch**
- Best deep linking on the market, and that is the half of the problem
  `docs/AD_ONBOARDING_ROUTING.md` was actually written for. The `ob=` variant
  needs to resolve before onboarding renders, and Branch does that at launch
  without waiting on ATT.
- Free tier is *recurring* and includes standard attribution, so at current
  scale it may genuinely cost nothing indefinitely.
- Already integrated in this repo. The package is added, the wrapper is
  written, and it needs a key and a domain rather than a week of work.
- Against it: weaker ad-network attribution than AppsFlyer — it will not close
  the TikTok/Google CAC gap as cleanly — and the paid cliff is a step, not a
  slope. Crossing 10,000 MAU moves you from $0 to a contracted plan reported in
  the hundreds per month, negotiated rather than self-serve.

### Which one for SpeakLife

**Branch, for now.** Three reasons, in order of weight:

1. It is nearly free at this scale and the work is nearly done. The only
   remaining inputs are a key and an Associated Domains entry.
2. The problem that actually has a written spec in this repo is ad-matched
   onboarding, and that is deep linking — Branch's strength, not AppsFlyer's.
3. The scale signal points below the free ceiling. `GrowthMetrics` records
   3,914 person records carrying behaviour over a 90-day window, and
   `AnalyticsService` records 32,444 `session_started` events over the same
   window — both consistent with an MAU in the low thousands, under Branch's
   10,000. **Verify this against a real PostHog MAU number before relying on
   it**; the 90-day person count is a proxy, and simulator traffic has polluted
   this app's counts before (see `ANALYTICS_DATA_QUALITY.md`).

**Switch to AppsFlyer when either of these becomes true:**

- MAU crosses ~10,000 and Branch's quote lands above what AppsFlyer's
  per-conversion meter would cost at your actual paid volume. Do the
  arithmetic then, not now: at $0.07/conversion, 2,000 paid installs a month is
  ~$140 — cheaper than a $499 Branch tier; 10,000 is ~$700 — more expensive.
- Paid spend on TikTok and Google becomes material enough that "no CAC for
  these channels" costs more than the migration does.

Running both is never the answer: two MMPs double-count every install.
