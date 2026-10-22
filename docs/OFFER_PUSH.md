# Offer Push: Test and Send

A push with custom data `deepLink = offer` opens the discount screen
(`PushOfferView`) for anyone not subscribed. By default it sells
`SpeakLife1YR29` ($29.99/year). The "% off" badge is worked out from the live
App Store prices against the regular yearly plan Remote Config points at
($49.99 today, so 40% off). Subscribers who tap it see nothing.

Code: `Views/Offer/PushOfferView.swift`, the `offer` case in
`SpeakLifeApp.swift`, and the rules in
`Packages/SpeakLifeKit/Sources/SpeakLifeCore/PushOffer.swift` (tested by
`PushOfferTests`).

## Push data

| Key         | Value                        | Required |
|-------------|------------------------------|----------|
| `deepLink`  | `offer`                      | Yes      |
| `campaign`  | a tag, e.g. `fall40_dose`    | No (defaults to `none`). Use it: it is how PostHog tells sends apart |
| `productId` | a yearly SKU, e.g. `SpeakLife1YR39` | No (defaults to `SpeakLife1YR29`) |

Values are trimmed, so stray spaces typed into the console are harmless.

## 1. Test on your own phone

1. Run a **debug** build from Xcode on a phone that is **not subscribed**.
   Sign in to a sandbox Apple ID under Settings → App Store → Sandbox Account.
2. In the app, open Profile and tap the **FCM token** row. It copies this
   device's push ID. The row exists in debug builds only.
3. Firebase console → Messaging → **New campaign → Notifications**. Enter the
   title and body.
4. **Additional options → Custom data:** `deepLink` = `offer`,
   `campaign` = `test`.
5. **Send test message** and paste the push ID.
6. Check all of these:
   - [ ] Tapping the push opens the offer screen.
   - [ ] It shows **40% OFF**, ~~$49.99~~ **$29.99/year**, and "Just $2.50/month,
         billed yearly" (or "3 days free" if the sandbox account can still take
         the trial).
   - [ ] The X closes it.
   - [ ] With the app open, the push shows a banner only; the screen waits for
         the tap.
   - [ ] A sandbox purchase completes and the screen closes.
   - [ ] Tapping the push again now does nothing, because you are subscribed.
   - [ ] PostHog shows `offer_push_opened` and `push_offer_shown` with
         `campaign = test`.

## 2. Send to everyone

Wait until most users are on the release that includes this. On older builds
a tap just opens the app.

1. Same campaign, but click **Next** instead of Send test message.
2. **Target:**
   - your iOS app
   - App version is at least the release that shipped this
   - user property `subscription_status` = `free`

   If `subscription_status` is missing from the list, register it once under
   Firebase Analytics → Custom definitions as a **user-scoped** property. It
   takes about a day to fill.
3. **Scheduling:** a morning time, in the recipient's time zone.
4. **Custom data:** `deepLink` = `offer`, `campaign` = your tag.
5. Review and publish.

A loose audience does no harm: the app never shows the offer to a subscriber.

Do **not** use `scripts/send-message.sh` for this. It sends the long-message
push type (`deepLink = message`) and goes to every user.

## Reading the results

PostHog funnel, filtered by `campaign`:

`offer_push_opened` → `push_offer_shown` → `push_offer_converted`

Also useful: `push_offer_dismissed` (with `seconds_on_paywall`),
`push_offer_product_unavailable` (the App Store did not answer), and
`offer_push_opened` with `presented = false` (subscribers who tapped).
Purchases also carry `paywall_name = push_offer_v1`.

Read `docs/ANALYTICS_DATA_QUALITY.md` before trusting any number.

## Copy that has been written

Each one fits on a lock screen.

**💊 A bigger dose, for less** (`fall40_dose`)
The Word is life and health to all your flesh (Prov 4:22). Take it every
morning this year. Premium is 40% off. Tap to claim.

**🎁 40% off your year ahead** (`fall40_mercies`)
His mercies are new every morning (Lam 3:23). Speak life over all 365 of
them. Premium is now $29.99/year.

**Premium is 40% off 🙌** (`fall40_plain`)
Daily declarations, Scripture audio, and Ask the Bible. $29.99/year, down
from $49.99. Tap to claim it.

If the regular yearly price changes, the badge updates by itself but the
copy above does not. Check the percentage before reusing it.
