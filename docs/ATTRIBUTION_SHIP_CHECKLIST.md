# Attribution: what has to be true before shipping

Everything in the app is committed. Nothing below is code — it is the
configuration and verification that decides whether the code does anything.

Values you will need repeatedly:

| | |
|---|---|
| Apple Team ID (App Prefix) | `G7398P2856` |
| Bundle ID | `com.Franchiz.SpeakLife` |
| Branch key | `key_live_pAyTGgj5uXAKKXaaKyPRWefkrEb34NYf` (in `Info.plist`) |
| Deep linking domains | `vqdga.app.link`, `vqdga-alternate.app.link` |

The Team ID above is the app target's. `652R6A63L8` also appears in the project
but belongs only to the test target — do not use it anywhere here.

---

## 1. Branch dashboard

- [ ] **Apple Team ID / App Prefix = `G7398P2856`.** This is the field that
      silently breaks universal links. Branch builds the
      apple-app-site-association file from it, so a blank or wrong prefix
      produces a valid-looking file that does not list this app, and every link
      falls back to Safari with no error anywhere.
- [ ] **Bundle ID = `com.Franchiz.SpeakLife`.** Case-sensitive. Note the
      capital F. The widget's id is not needed — universal links target the app.
- [ ] **Leave NativeLink™ off.** It is a fallback for iCloud Private Relay
      users, where Branch's IP-based match fails: it passes the link through
      the device clipboard instead. The cost is an iOS 16+ system paste prompt
      on first launch, landing in the same few seconds as the ATT prompt and
      the landing animation, and it needs a `checkPasteboardOnInstall()` call
      that is not in this app. Not worth a second permission dialog during
      onboarding unless deferred-link match rates turn out to be genuinely bad.
      Revisit with real numbers, not before.
- [ ] **Decide the subdomain now, not later.** Branch assigned the random
      `vqdga`. It can be changed exactly **once, ever**. If it should read
      `speaklife.app.link`, change it before any link ships: afterwards every
      live link breaks *and* the entitlement needs another App Store release to
      match. If `vqdga` is fine, say so and move on — it is invisible to users
      who tap a link.
- [ ] **Create one Quick Link per onboarding angle**, each with custom data
      `ob=<variant>`. Valid values, from `SubscriptionStore.OnboardingVariant`:
      `quiz`, `product`, `identity`, `outcomes`, `warfare`, `promises`,
      `closer`, `direct`. A typo here fails closed — `OnboardingVariant(code:)`
      returns nil and the person quietly gets the default arm.

## 2. Verify the association file

Branch hosts it; nothing is hosted on our side. Confirm it is actually correct
before wiring ads:

```
curl -s https://vqdga.app.link/apple-app-site-association | python3 -m json.tool
```

- [ ] The response lists **`G7398P2856.com.Franchiz.SpeakLife`** under
      `applinks`. If the prefix is missing or different, step 1 is wrong — fix
      it there, not here.
- [ ] Repeat for `https://vqdga-alternate.app.link/apple-app-site-association`.

Two things about how iOS reads this file, both of which cause "it worked on my
machine" confusion:

- iOS fetches it through **Apple's CDN**
  (`app-site-association.cdn-apple.com/a/v1/vqdga.app.link`), not from Branch
  directly, so a dashboard change can take **up to 24 hours** to reach devices.
- The file is fetched **at install time**. An already-installed build will not
  pick up a change — delete the app and reinstall to force a refetch.

To bypass the CDN while testing, append `?mode=developer` to the entitlement
entries and enable **Settings → Developer → Associated Domains Development** on
the device. That is a debugging aid only and must not ship.

## 3. Xcode

- [ ] **Associated Domains capability on the app target.** The entitlement is
      already in `SpeakLife.entitlements`, but the capability also has to exist
      on the App ID in the Apple Developer portal. Signing is `Automatic`, so
      Xcode will add it and regenerate the profile on the next build —
      *provided* the signed-in account has Admin or Account Holder rights. On a
      restricted account it fails with a provisioning error rather than doing
      it silently.
- [ ] **First build after this change will re-sign.** Expect Xcode to fetch a
      new provisioning profile. If it errors, that is the capability above, not
      the entitlement file.
- [ ] **Resolve the Swift package.** `ios-branch-sdk-spm` 3.9.1 is pinned in
      `Package.resolved` and wired into `project.pbxproj` by hand, since this
      work was done without Xcode. File → Packages → Resolve, and confirm
      `BranchSDK` appears under the app target's Frameworks.
- [ ] **Build.** None of the code in this workstream has been compiled — no
      Xcode in the environment it was written in. Expect to fix signature drift.

## 4. RevenueCat dashboard

- [x] ~~Turn on the PostHog integration.~~ **Already on**, and has been since
      **2026-08-08** — `ANALYTICS_DATA_QUALITY.md` Rule 8 dates the `rc_*`
      event history from then, and those events only exist because RevenueCat
      is sending them. Nothing to enable. The plan question is likewise already
      answered: the integration is running, so the plan covers it.
- [ ] **Verify it is still on** before relying on it: in PostHog, confirm
      `rc_renewal_event` or `rc_trial_converted_event` has landed in the last
      few days. If the series stops, that is the integration, not the app.
- [ ] After the first purchase on a real build, confirm the subscriber in
      RevenueCat carries a **`$posthogUserId`** attribute. **This is the part
      that was actually missing** — the integration was sending revenue all
      along, to person records the app's behaviour never touched (78 with
      revenue, 3,914 with behaviour, overlap zero). Without the attribute the
      events keep arriving and keep being unjoinable.

## 5. Device test, on TestFlight

None of this can be tested in the simulator — PostHog, TikTok and Meta
reporting are deliberately disabled there, and attribution needs a real
install.

- [ ] Tap a Branch link on a device **with the app deleted**. Install, open.
- [ ] Onboarding shows the arm matching that link's `ob=` value.
- [ ] PostHog shows `acquisition_attributed`. Expect it **twice** on a slow ATT
      answer: once as `organic`, then again with `is_upgrade = true` carrying
      the real channel. That is by design — filter on `is_upgrade` when
      counting.
- [ ] Tap a Branch link with the app **already installed**. It opens the app
      directly rather than bouncing to Safari. If it bounces, the association
      file or the capability is wrong.
- [ ] Buy something. Confirm `subscription_started` in PostHog, and the
      purchase in RevenueCat.

## 6. Watch after release

- [ ] **First-launch background music now actually turns on.** The install
      counter used to consume the flag that gated it, so this has never fired
      on a real first launch. It is the coded intent restored, but it is a
      visible change on fresh installs. Revert if unwanted.
- [ ] **Rebuild any dashboard keyed on the removed revenue properties** —
      `lifetime_revenue_usd`, `purchase_count`, `first_purchase_at`,
      `last_purchase_at`, `trial_converted`. They stop updating. Rebuild on
      RevenueCat's PostHog events instead.
- [ ] **Cancellations start appearing** from `rc_customer_info_update`. They
      were unreachable before, so a sudden non-zero cancellation count is the
      fix working, not a spike in churn.
- [ ] **Give channel numbers two weeks** before trusting them.

## Not blocking, but worth knowing

- `Info.plist` sets `NSAllowsArbitraryLoads = true`, disabling App Transport
  Security app-wide. Unrelated to attribution; worth its own look.
- The Meta SDK now owns the SKAdNetwork conversion value and TikTok stands
  down. The value only becomes *meaningful* once the schema in Meta Events
  Manager reflects subscription value rather than raw revenue buckets — a
  dashboard job nobody has done yet. See `ATTRIBUTION_MMP.md` §4.
