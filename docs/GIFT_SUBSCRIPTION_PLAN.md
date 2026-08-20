# Gift a Subscription — Research & Implementation Plan

**Date:** 2026-08-20
**Status:** Research complete, not implemented. Awaiting product decisions (see "Decisions needed").
**Ask:** Let a user buy SpeakLife premium *for someone else*, surfaced as its own destination in
Settings alongside "Redeem a Code".

---

## 1. What exists today

| Piece | Where | Notes |
|---|---|---|
| "Redeem a Code" row | `SpeakLife/Views/ProfileView/ProfileView.swift:225` | Calls `subscriptionStore.redeemOfferCode()`, in the `Premium` section right under "Manage Subscription". |
| Apple offer-code sheet | `Services/IAP/SubscriptionStore.swift:686` → `RevenueCatManager.presentOfferCodeRedemption()` (`RevenueCatManager.swift:132`) | Presents Apple's own redemption sheet, then `syncPurchases()` + `updateEntitlementsFromRC()`. Only accepts **App Store** offer codes, never a code we mint ourselves. |
| Entitlement source of truth | `SubscriptionStore.applyCustomerInfo` (`SubscriptionStore.swift:705`) | RevenueCat `premium` / `devotional` entitlements drive `isPremium`. A promotional entitlement granted server-side flows through this path with **zero client changes**. |
| RC identity | `AppDelegate.swift:39` — `Purchases.configure(withAPIKey:)` with no app user ID | Every install is an **anonymous** RC ID (`$RCAnonymousID:…`). Matters a lot for gift durability (§6). |
| Server-side RC access | `functions/bibleChat.js:36,74` | `REVENUECAT_SECRET_KEY` is **already in Secret Manager** and the function already calls `api.revenuecat.com/v1/subscribers/{id}`. The hard part of the backend is done. |
| Cloud Functions | `functions/index.js`, Firebase v2 `onRequest`, project `speaklife-3e5c4`, `us-central1` | Auth pattern for privileged endpoints: shared secret in the body (`personalMessage.js:316`). Client calls a raw URL (`Services/Bible/BibleChatService.swift:126`). |
| Firestore | `firestore.rules` | Established pattern for server-only collections: `allow read, write: if false` and write via admin SDK (see `bibleChatUsage`, `scheduledMessages`). |
| Deep links | `SpeakLifeApp.swift:145` `.onOpenURL`, scheme `speaklife://` (`Info.plist:26`), **Branch SDK** wired for deferred deep links (`AppDelegate.swift:517`) | No `associated-domains` entitlement (`SpeakLife.entitlements`) — so Branch is how a gift link survives "recipient doesn't have the app yet". |
| Client identity/durability | `Services/IAP/Security/KeychainHelper.swift`, CloudKit sync (`docs/ICLOUD_STATE_SYNC_PLAN.md`) | Reusable for pinning a stable gift identity. |

**Bottom line:** roughly 70% of the plumbing (RC secret key on the server, entitlement pipeline in
the client, Firestore server-only collection pattern, deep-link handling) already exists. The new
work is a gift SKU, a code ledger, two endpoints, and a settings screen.

---

## 2. Is gifting even allowed?

Yes, explicitly. App Review Guidelines 3.1.1: *"Apps may enable gifting of items that are eligible
for in-app purchase to others. Such gifts may only be refunded to the original purchaser and may
not be exchanged."*

Two consequences to design around:
1. The gift must be **bought through IAP** (Apple gets its cut). No Stripe / web checkout inside
   the iOS app for this.
2. Refunds go to the **purchaser only**. The recipient can never convert a gift to cash or swap it
   for another product. Our refund handling has to match that (§7).

Note that App Store Connect has **no native "gift a subscription"** product type. Whatever we ship,
we build the gift layer ourselves on top of a normal IAP.

---

## 3. Three ways to build it

### Option A — Consumable IAP + RevenueCat promotional entitlement ✅ **Recommended**

Gifter buys a **consumable** SKU (`SpeakLifeGift1YR`). Our Cloud Function verifies the purchase
against RevenueCat, mints a gift code into Firestore, and hands it back. The recipient enters the
code in the app; a second function marks it redeemed and calls RC's
`POST /v1/subscribers/{app_user_id}/entitlements/premium/promotional` to grant premium for the
gifted duration. `applyCustomerInfo` picks it up on the next customer-info refresh.

- ✅ Instant, fully in-app, works end-to-end without leaving SpeakLife.
- ✅ Recipient needs **no payment method** and gets **no auto-renew** — clean gift semantics, no
  surprise charge, no "I got charged after my gift ended" support load.
- ✅ We own the code format, expiry, resend, revocation, and the "My Gifts" ledger.
- ✅ Uses infrastructure that already exists (RC secret key, function pattern, Firestore rules).
- ⚠️ Promotional entitlements attach to an **RC app user ID**, and ours are anonymous — a reinstall
  loses the gift unless we handle it (§6). This is the one real engineering risk.
- ⚠️ Gift never converts to a paying subscriber automatically. Conversion has to be earned with a
  win-back push/paywall near expiry (which is arguably healthier than a silent auto-charge).

### Option B — Consumable IAP + pre-minted App Store offer codes

Same purchase flow, but instead of a promo entitlement we hand out a real **App Store one-time-use
offer code** from a pre-minted batch stored in Firestore. Recipient redeems it through Apple.

- ✅ Recipient ends up with a genuine App Store subscription → converts to paid automatically.
- ✅ Entitlement is tied to their **Apple ID**, so it survives reinstalls and new devices for free.
- ❌ Recipient must have a payment method on file and it **auto-renews** after the free period.
  That is a bad gift experience and a support/refund magnet.
- ❌ Code minting via the App Store Connect API (`POST /v1/subscriptionOfferCodeOneTimeUseCodes`) is
  batch/CSV-oriented, not per-request — we'd pre-generate batches and manage inventory, plus store
  an ASC API private key server-side.
- ❌ Quota: 1,000,000 redemptions per app per quarter across all offers, 25,000 per batch. Fine at
  our volume, but it's another ceiling to watch.

### Option C — Manual offer codes (zero build) — **do this today as a stopgap**

Generate one-time-use offer codes in App Store Connect and hand them out by email/DM. The existing
"Redeem a Code" row already opens Apple's sheet, so redemption works right now with no release.

- ✅ Ships in zero engineering time. Good for partners, testimonies, giveaways, benevolence.
- ❌ Not a product. No purchase flow, no scale, no self-serve — doesn't satisfy the request.

**Recommendation: Option A**, with Option C used immediately while A is built. Option B is the
fallback if the anonymous-ID durability work in §6 turns out worse than expected.

---

## 4. Recommended architecture (Option A)

```
Gifter                    App                     Cloud Functions            RevenueCat
  │  taps "Give SpeakLife" │                            │                        │
  │───────────────────────>│ purchase(SpeakLifeGift1YR) │                        │
  │                        │────────────── StoreKit / RC purchase ──────────────>│
  │                        │  POST /giftCreate          │                        │
  │                        │  {appUserId, note, ...}    │                        │
  │                        │───────────────────────────>│ GET /v1/subscribers/…  │
  │                        │                            │───────────────────────>│
  │                        │                            │ verify unconsumed      │
  │                        │                            │ non-subscription txn   │
  │                        │  {code, shareURL}          │ write gifts/{code}     │
  │                        │<───────────────────────────│                        │
  │  shares link/code      │                            │                        │
  ▼                                                                              │
Recipient                                                                        │
  │  opens speaklife://gift?code=XXXX or types the code                          │
  │───────────────────────>│ POST /giftRedeem           │                        │
  │                        │ {code, appUserId}          │ txn: mark redeemed     │
  │                        │───────────────────────────>│ POST …/entitlements/   │
  │                        │                            │   premium/promotional  │
  │                        │                            │───────────────────────>│
  │                        │  {ok, expiresAt}           │                        │
  │                        │<───────────────────────────│                        │
  │                        │ syncPurchases() + updateEntitlementsFromRC()        │
  │                        │ → applyCustomerInfo → isPremium = true              │
```

### 4.1 Products (App Store Connect + RevenueCat)

New **consumable** IAPs — consumable, not non-consumable, so one person can buy many gifts:

| Product ID | Gift | Suggested price |
|---|---|---|
| `SpeakLifeGift1MO` | 1 month of premium | $4.99 |
| `SpeakLifeGift3MO` | 3 months of premium | $12.99 |
| `SpeakLifeGift1YR` | 1 year of premium | $29.99 |

In RevenueCat: add all three as products in a dedicated `gifts` offering. **Do not attach them to
the `premium` entitlement** — buying a gift must not make the *gifter* premium. Map product ID →
granted duration server-side only, so a tampered client can't ask for a year after paying for a
month.

### 4.2 Firestore

`gifts/{code}` — server-only (`allow read, write: if false`, same as `bibleChatUsage`):

```js
{
  code: "GIFT-7K4M-92QX",       // doc id too
  status: "unredeemed",          // unredeemed | redeemed | revoked
  productId: "SpeakLifeGift1YR",
  durationDays: 365,
  purchaserAppUserId: "$RCAnonymousID:abc…",
  purchaseTransactionId: "2000000…",   // RC non_subscriptions id — idempotency key
  purchasedAt: Timestamp,
  expiresUnredeemedAt: Timestamp,      // code itself dies after 12 months
  recipientNote: "Praying for you, sis.",   // optional, ≤200 chars, moderated
  redeemedAt: Timestamp | null,
  redeemedByAppUserId: string | null,
  grantedUntil: Timestamp | null,
  reclaims: [{ appUserId, at }],       // device re-claims, ≤3 (see §6)
  revokedReason: string | null
}
```

Index: `purchaserAppUserId + purchasedAt desc` (powers the "My Gifts" list).

### 4.3 Cloud Function: `giftCreate` (new `functions/gifting.js`)

`POST { appUserId, productId, recipientNote? }`

1. `GET https://api.revenuecat.com/v1/subscribers/{appUserId}` with `REVENUECAT_SECRET_KEY` (reuse
   the existing helper shape in `bibleChat.js:74`).
2. Read `subscriber.non_subscriptions[productId]` — the array of consumable purchases.
3. For each purchase whose store transaction id is not already in `gifts`, mint a code in a
   Firestore transaction. **The transaction id is the idempotency key** — a retried call returns
   the same code, never a second one.
4. Return `{ codes: [{ code, productId, shareURL }] }`.

This "reconcile from RC" shape (rather than "trust the client's word that it purchased") means a
dropped network response, a crash mid-flow, or a reinstall all self-heal: the gifter reopens
"My Gifts" and the code is there. No shared secret needed for this endpoint — RC is authoritative
about what was actually paid for.

### 4.4 Cloud Function: `giftRedeem`

`POST { code, appUserId }`

1. Normalize the code (uppercase, strip dashes/spaces).
2. Firestore transaction: load `gifts/{code}`, reject if missing / redeemed / revoked / past
   `expiresUnredeemedAt`, reject if `appUserId === purchaserAppUserId` (can't gift yourself), then
   flip to `redeemed`.
3. Grant via RC: `POST /v1/subscribers/{appUserId}/entitlements/premium/promotional` with the
   duration. RC's named durations are `daily`, `three_day`, `weekly`, `monthly`, `two_month`,
   `three_month`, `six_month`, `yearly`, `lifetime`; for anything custom you pass explicit start/end
   times so the window lands where you want. Our three SKUs map cleanly onto `monthly`,
   `three_month`, `yearly`.
4. If the RC call fails, **roll the doc back to `unredeemed`** before returning the error — never
   burn a code on a failed grant.
5. Return `{ ok: true, expiresAt, durationLabel }`.

Rate-limit by `appUserId` (e.g. 10 attempts/hour) so the code space can't be brute-forced. With an
8-character code from a 32-symbol unambiguous alphabet (no `O/0/I/1`), the space is ~10^12 — fine
with rate limiting.

### 4.5 Client

**New service** `Services/IAP/GiftService.swift`, modeled on `BibleChatAIService`
(`Services/Bible/BibleChatService.swift:117-170`) — same raw-URL + `URLSession` + emulator-toggle
pattern, endpoints `…cloudfunctions.net/giftCreate` and `/giftRedeem`.

**New view** `Views/ProfileView/GiftSubscriptionView.swift` with three sections:
- **Give a gift** — the three SKUs with prices from StoreKit, an optional short note, purchase → code.
- **My gifts** — sent codes with status (unredeemed / redeemed / expired), share and re-share.
- **Redeem** — a field for a SpeakLife gift code, plus a row that keeps the existing Apple offer-code
  sheet (`subscriptionStore.redeemOfferCode()`) for App Store codes.

**ProfileView change** — one row in the existing `Premium` section, right under `redeemCodeRow`
(`ProfileView.swift:114`):

```swift
private var giftSubscriptionRow: some View {
    HStack {
        Image(systemName: "gift.circle.fill").foregroundColor(Constants.DAMidBlue)
        NavigationLink(destination: LazyView(GiftSubscriptionView())) {
            HStack { Text("Give SpeakLife", comment: "gift subscription row"); Spacer() }
        }
    }
}
```

**Deep link** — extend `.onOpenURL` (`SpeakLifeApp.swift:145`) to route
`speaklife://gift?code=XXXX` into `GiftSubscriptionView` with the field prefilled. For recipients
who don't have the app yet, generate the share URL as a **Branch** link carrying `code` in its
deep-link data; Branch's deferred deep linking already resolves post-install through
`BranchAttribution.apply` (`AppDelegate.swift:551`), which today only reads `ob`. That avoids
needing an `associated-domains` entitlement.

---

## 5. Suggested UX copy

- Row title: **"Give SpeakLife"** (not "Gift a Subscription" — matches the app's voice).
- Screen header: *"Someone you love needs this. Put God's Word in their hands."*
- After purchase: show the code big, with **Share** as the primary button (pre-filled iMessage text
  + link), and **Copy code** secondary.
- Share text: *"I got you a gift — SpeakLife premium, on me. Tap to open it: {link}"*
- Recipient success state: full-screen celebration, the gifter's note if present, then straight into
  the app (not into a paywall).
- The gifter should get a push when their gift is redeemed ("Your gift was opened 🎁") — the
  `personalMessage.js` FCM infrastructure already supports targeted sends by device.

---

## 6. The one real risk: anonymous RC IDs

Promotional entitlements attach to a RevenueCat **app user ID**. Because `Purchases.configure` runs
without an ID (`AppDelegate.swift:39`), every install is anonymous — so if the recipient deletes and
reinstalls the app, or gets a new phone, **their gifted premium is gone** and `restore()` will not
bring it back (restore only recovers real App Store transactions).

Three mitigations, in order of preference:

1. **Re-claim the same code** (ship this in v1, cheap). `giftRedeem` accepts a code that is already
   redeemed *if* the request is within the original grant window and `reclaims.length < 3`. It then
   grants the remaining time to the new app user ID and appends to `reclaims`. The user just enters
   their gift code again on the new phone. Bounded, self-serve, no identity work.
2. **Pin a stable RC identity at redemption** (ship in v1 too). At redeem time, call
   `Purchases.shared.logIn(stableId)` where `stableId` is a UUID stored in the Keychain
   (`Services/IAP/Security/KeychainHelper.swift`) and mirrored to `NSUbiquitousKeyValueStore`, or the
   Firebase Apple Sign-In uid when the user is signed in (`Services/Auth/AppleSignInService.swift`).
   RC aliases the anonymous ID into it, and the same iCloud account on a new device resolves to the
   same RC user → the gift follows them automatically.
3. **Fall back to Option B** (offer codes, Apple-ID-bound) if the above proves fragile in the wild.

Mitigation 2 is a change to app-wide RC identity and deserves its own careful test pass — do not
bundle it blindly with the gifting release; gate it so it only fires on the redemption path first.

---

## 7. Edge cases and policy

| Case | Handling |
|---|---|
| Gifter refunded by Apple | RC webhook / periodic reconcile: if the gift is **unredeemed**, set `status: revoked`. If **already redeemed**, let it stand (revoking premium from an innocent recipient is worse than eating the loss) and flag the purchaser for repeat abuse. |
| Recipient already premium | Still redeem it: the promo entitlement stacks behind their paid one and takes over if they cancel. Show "Your gift is saved and starts when your current subscription ends." Alternative (simpler) is to block redemption — decide in §9. |
| Gifting yourself | Blocked at redeem time by `appUserId === purchaserAppUserId`. Weak (a second device defeats it) but it stops the accidental case; the real abuse ceiling is that a gift costs full price. |
| Code never redeemed | Expires 12 months after purchase. No refund (matches Apple's "refunded to the original purchaser only" — direct them to Apple's refund flow). |
| Same code entered twice | Firestore transaction makes it atomic; second attempt hits the re-claim path (§6.1) or is rejected. |
| Brute force | Rate limit per app user ID + per IP; 32-symbol 8-char codes. |
| Note field abuse | ≤200 chars, server-side profanity filter, never rendered as a link. |
| Family Sharing | Consumables aren't family-shareable — no interaction, nothing to do. |

---

## 8. Analytics

Reuse `AnalyticsService.trackUserAction` (`Core/Analytics/AnalyticsService.swift:201`), category
`gifting`:

`gift_screen_opened` (source) · `gift_product_selected` (productId) · `gift_purchase_started` ·
`gift_purchase_completed` (productId, revenue) · `gift_purchase_failed` (reason) · `gift_shared`
(channel) · `gift_link_opened` (recipient side) · `gift_redeem_attempted` · `gift_redeem_succeeded`
(durationDays) · `gift_redeem_failed` (reason) · `gift_reclaimed` · `gift_recipient_converted_to_paid`
(the number that decides whether this feature earns its keep).

The one funnel to watch: **purchase → shared → opened → redeemed → converted.** If sharing is where
it dies, the share sheet copy is the fix, not the feature.

---

## 9. Decisions needed before build

1. **Durations and prices** — is $4.99 / $12.99 / $29.99 for 1mo / 3mo / 1yr right, or should the
   gift be priced at parity with the normal yearly ($29.99, `SpeakLife1YR29`)?
2. **Stacking** — if the recipient is already premium, queue the gift behind their subscription
   (recommended) or refuse the redemption with "they're already covered"?
3. **Conversion push** — do we send the recipient a win-back offer at T-7 days and T-0 of gift
   expiry? (Recommended; it's where the ROI is.)
4. **Bulk gifting** — do churches/small groups need "buy 10 at once"? That changes the UI
   materially (a quantity picker and a code list/CSV export) but not the backend.
5. **Anonymous → identified RC IDs** (§6.2) — approve this as part of the gifting release, or defer
   and ship with re-claim only?

---

## 10. Phased plan

**Phase 0 — today, no code.** Generate a batch of App Store offer codes and use the existing
"Redeem a Code" row to hand out gifts manually. Validates demand before we build anything.

**Phase 1 — backend (≈2 days).** `functions/gifting.js` with `giftCreate` + `giftRedeem`, the
`gifts` collection, `firestore.rules` entry (`allow read, write: if false`), the Firestore index,
and a `scripts/` curl harness against the emulator.

**Phase 2 — products (≈0.5 day, mostly waiting).** Create the three consumables in App Store
Connect, add them to RevenueCat in a `gifts` offering, confirm they are **not** attached to the
`premium` entitlement.

**Phase 3 — client (≈2–3 days).** `GiftService.swift`, `GiftSubscriptionView.swift`, the
`giftSubscriptionRow` in `ProfileView`, `speaklife://gift?code=` routing, Branch share links,
analytics.

**Phase 4 — durability + polish (≈1–2 days).** Re-claim path, optional `Purchases.logIn` identity
pinning, gift-redeemed push to the gifter, expiry win-back sequence.

**Phase 5 — tests.** Unit tests for code generation/normalization, redemption state machine, and
duration mapping (`SpeakLifeTests/` — follow `APIClientTests.swift` for the URLSession stubbing
pattern). Manual: sandbox purchase → code → redeem on a second device → verify `isPremium` flips and
survives a cold launch.

**Total: roughly one focused week.**

---

## 11. Sources

- [App Review Guidelines 3.1.1 (gifting)](https://developer.apple.com/app-store/review/guidelines/)
- [RevenueCat — Grant promotional access](https://www.revenuecat.com/docs/promotionals)
- [RevenueCat API v1](https://www.revenuecat.com/docs/api-v1)
- [App Store Connect — Set up offer codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/)
- [App Store Connect API — Create one-time use offer codes](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-subscriptionoffercodeonetimeusecodes)
- [StoreKit — Supporting offer codes in your app](https://developer.apple.com/documentation/storekit/supporting-offer-codes-in-your-app)
