# Gift a Subscription — Research & Implementation Plan

**Date:** 2026-08-20
**Status:** Research complete, not implemented. Awaiting product decisions (see "Decisions needed").
**Ask:** Let a user buy SpeakLife premium *for someone else* — picking the plan and **how many** —
surfaced as its own destination in Settings alongside "Redeem a Code".

**Shape:** Phase 1 ships a **yearly gift at $39.99** (against $49.99 retail — a gift costs less than
buying it for yourself), quantity 1–10 per purchase. Lifetime gifting is designed for but held back;
§6 explains why.

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

**Bottom line:** most of the plumbing (RC secret key on the server, entitlement pipeline in the
client, Firestore server-only collection pattern, deep-link handling) already exists. The new work
is two gift SKUs, a code ledger, two endpoints, a settings screen, and one genuinely new capability:
verifying an Apple-signed transaction server-side, which is what lets a gifter buy several at once
(§4.1).

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

Gifter picks yearly or lifetime and a quantity, and buys a **consumable** SKU
(`SpeakLifeGiftYear` / `SpeakLifeGiftLifetime`) in one transaction. Our Cloud Function verifies the
Apple-signed transaction, mints that many gift codes into Firestore, and hands them back. Each
recipient enters their code in the app; a second function marks it redeemed and calls RC's
`POST /v1/subscribers/{app_user_id}/entitlements/premium/promotional` to grant premium for the
gifted duration. `applyCustomerInfo` picks it up on the next customer-info refresh, so no view code
changes.

- ✅ Instant, fully in-app, works end-to-end without leaving SpeakLife.
- ✅ Recipient needs **no payment method** and gets **no auto-renew** — clean gift semantics, no
  surprise charge, no "I got charged after my gift ended" support load.
- ✅ We own the code format, expiry, resend, revocation, and the "My Gifts" ledger — which is what
  makes buying a batch of 5 and handing them out over weeks actually work.
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
  an ASC API private key server-side. Handing out N codes at once means keeping N in stock.
- ❌ No lifetime story: offer codes attach to an auto-renewable subscription, so "gift someone
  lifetime" has no equivalent here at all.
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
  │  "Give SpeakLife"      │                            │                        │
  │  picks Yearly/Lifetime │                            │                        │
  │  + quantity (1–10)     │                            │                        │
  │───────────────────────>│ product.purchase(          │                        │
  │                        │   options: [.quantity(5)]) │                        │
  │                        │──────── StoreKit 2 (one payment sheet) ─────────────│
  │                        │  POST /giftCreate          │                        │
  │                        │  {appUserId, jws, note?}   │                        │
  │                        │───────────────────────────>│ verify JWS offline     │
  │                        │                            │ (Apple root certs)     │
  │                        │                            │ → productId, quantity  │
  │                        │  {gifts:[{code,shareURL}]} │ mint N codes, 1 batch  │
  │                        │<───────────────────────────│                        │
  │  shares each code      │                            │                        │
  ▼                                                                              │
Recipient                                                                        │
  │  opens speaklife://gift?code=XXXX or types the code                          │
  │───────────────────────>│ POST /giftRedeem           │                        │
  │                        │ {code, appUserId}          │ txn: mark redeemed     │
  │                        │───────────────────────────>│ POST …/entitlements/   │
  │                        │                            │   premium/promotional  │
  │                        │                            │   (yearly | lifetime)  │
  │                        │                            │───────────────────────>│
  │                        │  {ok, durationLabel}       │                        │
  │                        │<───────────────────────────│                        │
  │                        │ syncPurchases() + updateEntitlementsFromRC()        │
  │                        │ → applyCustomerInfo → isPremium = true              │
```

### 4.1 Products and quantity

Two **consumable** IAPs — consumable, not non-consumable, so one person can buy many:

| Product ID | Gift | Price | Retail equivalent | RC promo duration | Ship |
|---|---|---|---|---|---|
| `SpeakLifeGiftYear` | 1 year of premium | **$39.99** | $49.99 | `yearly` | Phase 1 |
| `SpeakLifeGiftLifetime` | Lifetime premium | $99.99 | $99.99 | `lifetime` | Later — see §6 |

**A gift costs less than buying it for yourself.** $39.99 against the $49.99 retail yearly, using a
price point the app already runs during onboarding (`SpeakLife1YR39`, `InAppPurchases.swift:22`), so
it is proven and needs no new pricing thinking. That inversion is the marketing hook — *"give a
year for $10 less than it costs you"* — and it makes the batch maths friendlier too: five gifts is
$199.95 instead of $249.95.

Two implementation notes on that:

- The gift SKU is a **new consumable at the $39.99 price point**, not a reuse of `SpeakLife1YR39`.
  That existing product is an auto-renewable subscription; a gift has to be a consumable, so the
  price point carries over but the product does not.
- The retail yearly is whatever Remote Config's `yearlySubscription` currently points at
  (`SubscriptionStore.swift:312`), not the compiled `currentYearlyID` constant — so if the retail
  price moves, revisit the gift price rather than assuming the $10 gap holds.

**Lifetime is deliberately not in Phase 1.** It is the same build with one different string, but it
carries a durability liability that yearly does not (§6). Ship yearly, prove the flow, add lifetime
once redemption is identity-bound.

**How the quantity is bought:** StoreKit 2 supports it natively via
[`Product.PurchaseOption.quantity(_:)`](https://developer.apple.com/documentation/storekit/product/purchaseoption/quantity(_:)),
which applies to consumables only. One payment sheet, one transaction, quantity N.

**Ceiling: 10 per transaction.** That is an App Store limit on the purchase sheet, not something we
set. For a church or small group wanting 25 seats, the options are (a) let them run the flow more
than once, or (b) add explicit bundle SKUs later (`SpeakLifeGiftYear25` etc.), which also lets us
give a bulk discount. Ship the stepper capped at 10 first; add bundles if demand shows up.
Also worth a sandbox check: quantity × price still has to land under Apple's per-transaction price
ceiling, so 10 × lifetime at $99.99 sits right at the edge.

**RevenueCat cannot be the source of truth for quantity.** RC tracks that a consumable was bought
and surfaces it in `CustomerInfo`, but by its own documentation the quantity-to-value logic belongs
to your backend — its subscriber payload does not tell us "this one transaction was worth 5 gifts."
So the gift purchase leg does **not** go through `Purchases.shared.purchase(...)`. Instead:

1. The client buys directly with StoreKit 2:
   `try await product.purchase(options: [.quantity(n)])`.
2. On success it sends the transaction's **`jwsRepresentation`** to `giftCreate`.
3. The function verifies that JWS **offline** against Apple's root certificates using the
   [App Store Server Library](https://developer.apple.com/documentation/appstoreserverapi/simplifying-your-implementation-by-using-the-app-store-server-library)
   (`@apple/app-store-server-library` on npm) and reads the authoritative `quantity`, `productId`,
   `transactionId`, and `purchaseDate` straight out of the signed payload.

Offline JWS verification means **no App Store Connect API key is needed** for v1 — the signature
itself is the proof. (An ASC key only becomes necessary if we later want to re-fetch transaction
history server-side; refunds are better handled by App Store Server Notifications V2, which needs a
notification URL but no key.)

RevenueCat still does the half it is good at: **granting the recipient's entitlement**. And because
the RC SDK picks up StoreKit transactions it did not initiate, gift revenue still shows up in the RC
dashboard. Critical config detail: in RevenueCat, **do not attach the gift products to the `premium`
entitlement** — buying a gift must never make the *gifter* premium.

### 4.2 Firestore

Two server-only collections (`allow read, write: if false`, same as `bibleChatUsage`).

`giftBatches/{transactionId}` — one doc per purchase, keyed by the Apple transaction id so a retry
can never mint a second set of codes:

```js
{
  transactionId: "2000000…",      // doc id — the idempotency key
  purchaserAppUserId: "$RCAnonymousID:abc…",
  productId: "SpeakLifeGiftYear",
  quantity: 5,                     // straight from the signed JWS payload
  codes: ["GIFT-7K4M-92QX", …],    // exactly `quantity` of them
  purchasedAt: Timestamp,
  refundedAt: Timestamp | null
}
```

`gifts/{code}` — one doc per individual gift:

```js
{
  code: "GIFT-7K4M-92QX",        // doc id too
  batchId: "2000000…",
  status: "unredeemed",           // unredeemed | redeemed | revoked
  productId: "SpeakLifeGiftYear",
  grantDuration: "yearly",        // yearly | lifetime — resolved server-side from productId
  purchaserAppUserId: "$RCAnonymousID:abc…",
  purchasedAt: Timestamp,
  expiresUnredeemedAt: Timestamp,      // the code itself dies after 12 months
  recipientNote: "Praying for you, sis.",   // optional, ≤200 chars, moderated
  redeemedAt: Timestamp | null,
  redeemedByAppUserId: string | null,
  grantedUntil: Timestamp | null,      // null for lifetime
  reclaims: [{ appUserId, at }],       // device re-claims (see §6)
  revokedReason: string | null
}
```

The duration is **never taken from the client** — the server maps `productId` → `yearly` /
`lifetime`, so a tampered request cannot upgrade a yearly gift into a lifetime one.

Indexes: `gifts` on `purchaserAppUserId + purchasedAt desc` (the "My Gifts" list), and
`giftBatches` on `purchaserAppUserId + purchasedAt desc`.

### 4.3 Cloud Function: `giftCreate` (new `functions/gifting.js`)

`POST { appUserId, jws, recipientNote? }`

1. Verify `jws` offline with `@apple/app-store-server-library`'s `SignedDataVerifier` (Apple root
   certs, bundle id `com.franchiz.speaklife`, production/sandbox environment). Reject anything that
   fails signature, bundle id, or environment checks.
2. Read `transactionId`, `productId`, `quantity`, `purchaseDate` from the **verified payload only**.
   Reject a `productId` that is not one of the two gift SKUs.
3. Firestore transaction on `giftBatches/{transactionId}`:
   - If the doc already exists, return its existing codes. **Idempotent by construction** — a
     retried call, a crash mid-flow, or a reinstall all return the same codes, never new ones.
   - Otherwise mint exactly `quantity` codes, write the batch doc and the `gifts/{code}` docs
     together in one atomic commit.
4. Return `{ transactionId, quantity, gifts: [{ code, shareURL }] }`.

Because the signed transaction is the proof, the client's word is never trusted for anything that
costs money. No shared secret is needed on this endpoint.

### 4.4 Cloud Function: `giftRedeem`

`POST { code, appUserId }`

1. Normalize the code (uppercase, strip dashes/spaces).
2. Firestore transaction: load `gifts/{code}`, reject if missing / redeemed / revoked / past
   `expiresUnredeemedAt`, reject if `appUserId === purchaserAppUserId` (can't gift yourself), then
   flip to `redeemed`.
3. Grant via RC: `POST /v1/subscribers/{appUserId}/entitlements/premium/promotional` with the
   duration taken from `grantDuration` on the gift doc — `yearly` or `lifetime`, both of which are
   named RC durations, so no custom start/end arithmetic is needed. (RC also supports custom windows
   by passing explicit start/end times, which is how a partial-remaining re-claim in §6 is granted.)
4. If the RC call fails, **roll the doc back to `unredeemed`** before returning the error — never
   burn a code on a failed grant.
5. Return `{ ok: true, expiresAt, durationLabel }`.

Rate-limit by `appUserId` (e.g. 10 attempts/hour) so the code space can't be brute-forced. With an
8-character code from a 32-symbol unambiguous alphabet (no `O/0/I/1`), the space is ~10^12 — fine
with rate limiting.

### 4.5 Client

**New service** `Services/IAP/GiftService.swift`, modeled on `BibleChatAIService`
(`Services/Bible/BibleChatService.swift:117-170`) — same raw-URL + `URLSession` + emulator-toggle
pattern, endpoints `…cloudfunctions.net/giftCreate` and `/giftRedeem`. It also owns the direct
StoreKit purchase, which is the one place the app buys outside RevenueCat:

```swift
let result = try await product.purchase(options: [.quantity(count)])
guard case .success(let verification) = result,
      case .verified(let transaction) = verification else { … }
let gifts = try await createGifts(jws: verification.jwsRepresentation,
                                  appUserId: RevenueCatManager.shared.appUserID)
await transaction.finish()   // only after the server has minted the codes
```

Finishing the transaction *after* `giftCreate` returns means a crash or dropped connection leaves it
unfinished, so StoreKit re-delivers it on next launch and the codes still get minted. Belt and
braces on top of the transaction-id idempotency.

**New view** `Views/ProfileView/GiftSubscriptionView.swift` with three sections:
- **Give a gift** — a plan picker (yearly only until lifetime ships, so it renders as a single
  selected card), a quantity stepper (1–10) with the running total price, and one purchase button. On success, the minted codes appear as a list, each with its own
  Share button plus a "Copy all codes" action for someone buying a batch for a group.
- **My gifts** — every code sent, with status (unredeemed / redeemed / expired), grouped by purchase,
  re-shareable at any time. This is also the recovery path if the share never went out.
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
who don't have the app yet, generate each share URL as a **Branch** link carrying `code` in its
deep-link data; Branch's deferred deep linking already resolves post-install through
`BranchAttribution.apply` (`AppDelegate.swift:551`), which today only reads `ob`. That avoids
needing an `associated-domains` entitlement.

---

## 5. Suggested UX copy

- Row title: **"Give SpeakLife"** (not "Gift a Subscription" — matches the app's voice).
- Screen header: *"Someone you love needs this. Put God's Word in their hands."*
- Quantity control: a stepper, with the total updating live ("5 gifts · $199.95"). One gift is the
  default; the stepper is what makes buying for a small group feel intended rather than improvised.
- Say the saving out loud on the buy screen: *"$39.99 — that's $10 less than a year costs you."*
  A gift that is cheaper than self-purchase is unusual enough to be worth a line of copy.
- After purchase: one code per row, each with its own **Share** button (pre-filled iMessage text +
  link), **Copy code** secondary, and **Copy all codes** when the batch is larger than one.
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
   grants the **remaining** time to the new app user ID (a custom RC start/end window) and appends
   to `reclaims`. The user just enters their gift code again on the new phone. Bounded, self-serve,
   no identity work.
2. **Pin a stable RC identity at redemption** (ship in v1 too). At redeem time, call
   `Purchases.shared.logIn(stableId)` where `stableId` is a UUID stored in the Keychain
   (`Services/IAP/Security/KeychainHelper.swift`) and mirrored to `NSUbiquitousKeyValueStore`, or the
   Firebase Apple Sign-In uid when the user is signed in (`Services/Auth/AppleSignInService.swift`).
   RC aliases the anonymous ID into it, and the same iCloud account on a new device resolves to the
   same RC user → the gift follows them automatically.
3. **Fall back to Option B** (offer codes, Apple-ID-bound) if the above proves fragile in the wild.

Mitigation 2 is a change to app-wide RC identity and deserves its own careful test pass — do not
bundle it blindly with the gifting release; gate it so it only fires on the redemption path first.

### Why lifetime is the one to hold back

A **bought** lifetime is safe, and it is worth being precise about why: `SpeakLifeLifetime` is an
App Store non-consumable tied to the buyer's Apple ID. Apple is the system of record, and "Restore
Purchases" brings it back on any device forever. We carry no risk.

A **gifted** lifetime is a completely different object. The recipient never bought anything from
Apple, so no transaction of theirs exists anywhere in Apple's system. The only evidence they have
premium is a promotional entitlement row in RevenueCat attached to an anonymous app user ID that
lives in local app storage. Delete and reinstall, or set up a new phone without restoring a backup,
and that ID is gone — the entitlement is orphaned on an identifier nobody will ever use again. And
**Restore Purchases cannot rescue them**, because restore asks Apple what this Apple ID bought, and
the answer is nothing.

Over an actual lifetime, the chance of a reinstall or a new device approaches 100%. This is not an
edge case, it is the expected outcome on a delay. A yearly gift quietly self-heals because it was
going to end anyway; a lifetime gift becomes "I paid for my mom two years ago and now she has
nothing", at a point where she has no account, no receipt, and no memory of a gift code.

Manual recovery is also weak: we can re-grant from the RevenueCat dashboard, but only if we can tell
*which* anonymous ID is hers, and most users have no account and no email on file.

Two further considerations, both about lifetime as a product rather than about gifting:

- **Unmetered cost.** Premium unlocks unlimited Bible Chat, which is a real per-message Anthropic
  bill (`functions/bibleChat.js:41` — free users get 3 messages ever, premium is uncapped). One
  payment against a decade of uncapped AI is a margin question, and a 10-pack sells ten uncapped
  accounts in a single transaction.
- **Codes that never decay.** A leaked yearly code loses value in a year; a leaked lifetime code
  never does. And 10 × lifetime is a ~$999 charge, which is the size where chargebacks show up.

**So: ship yearly first.** If and when lifetime ships, make redemption identity-bound — when someone
redeems a lifetime gift, prompt Sign in with Apple (already in the codebase at
`Services/Auth/AppleSignInService.swift`) with the honest framing *"Sign in so your gift can never be
lost"*, then `Purchases.logIn` with that uid. That is the best moment in the entire app to ask for an
account: they have just been given something valuable and the reason is plainly in their interest.
Re-claims for lifetime should be **unlimited** rather than capped at 3.

**Worth considering instead of lifetime:** gift **5 years**. It feels like a huge gift, costs the
giver the same, and bounds the liability on both the identity and the cost side. RevenueCat grants it
as a custom start/end window, so it is no extra work.

---

## 7. Edge cases and policy

| Case | Handling |
|---|---|
| Gifter refunded by Apple | App Store Server Notifications V2 (`REFUND`) fires on the batch's transaction id. Revoke every **unredeemed** code in that batch (`status: revoked`); leave **already redeemed** ones standing — revoking premium from an innocent recipient is worse than eating the loss — and flag the purchaser for repeat abuse. Note a refund is all-or-nothing on the transaction, so a 5-gift batch where 2 were redeemed means 3 revoked and 2 honored. |
| Only part of a batch gets shared | Nothing to do. Unshared codes sit in "My Gifts" until the 12-month expiry, re-shareable at any time. |
| Recipient already premium | Still redeem it: the promo entitlement stacks behind their paid one and takes over if they cancel. Show "Your gift is saved and starts when your current subscription ends." Alternative (simpler) is to block redemption — decide in §9. |
| Gifting yourself | Blocked at redeem time by `appUserId === purchaserAppUserId`. Weak (a second device defeats it) but it stops the accidental case; the real abuse ceiling is that a gift costs full price. Buying a 10-pack to resell codes is the theoretical worst case, and it is self-limiting: they paid full retail for every one. |
| Code never redeemed | Expires 12 months after purchase. No refund (matches Apple's "refunded to the original purchaser only" — direct them to Apple's refund flow). |
| Same code entered twice | Firestore transaction makes it atomic; second attempt hits the re-claim path (§6.1) or is rejected. |
| Brute force | Rate limit per app user ID + per IP; 32-symbol 8-char codes. |
| Note field abuse | ≤200 chars, server-side profanity filter, never rendered as a link. |
| Family Sharing | Consumables aren't family-shareable — no interaction, nothing to do. |

---

## 8. Analytics

Reuse `AnalyticsService.trackUserAction` (`Core/Analytics/AnalyticsService.swift:201`), category
`gifting`:

`gift_screen_opened` (source) · `gift_product_selected` (productId) · `gift_quantity_changed`
(quantity) · `gift_purchase_started` (productId, quantity) · `gift_purchase_completed` (productId,
quantity, revenue) · `gift_purchase_failed` (reason) · `gift_shared` (channel, batchSize) ·
`gift_link_opened` (recipient side) · `gift_redeem_attempted` · `gift_redeem_succeeded`
(grantDuration) · `gift_redeem_failed` (reason) · `gift_reclaimed` ·
`gift_recipient_converted_to_paid` (the number that decides whether this feature earns its keep).

Stamp `quantity` on the purchase events specifically — average batch size is what tells us whether
bundle SKUs above 10 are worth building.

The one funnel to watch: **purchase → shared → opened → redeemed → converted.** If sharing is where
it dies, the share sheet copy is the fix, not the feature.

---

## 9. Decisions

**Settled:**
- Gift products are yearly and lifetime, not duration tiers.
- Yearly gift is **$39.99** against the $49.99 retail yearly — a gift costs less than buying it for
  yourself, using a price point the app already runs in onboarding.
- Lifetime does not ship in Phase 1 (§6).

**Still open:**

1. **Bulk discount** — should 5+ or 10 of the same gift come with a further break ("church pack")?
   Apple has no volume-discount mechanism on a quantity purchase, so this requires separate bundle
   SKUs and turns the stepper into a tier list. Worth it only if churches actually ask.
2. **Above 10** — Apple caps a single purchase at 10. Leave larger orders to "run it again", or add
   bundle SKUs (25 / 50) in a later pass?
3. **Lifetime, later** — ship it once redemption is identity-bound, or replace it with a 5-year gift
   that carries none of the liability (§6)?
4. **Stacking** — if the recipient is already premium, queue the gift behind their subscription
   (recommended) or refuse the redemption with "they're already covered"?
5. **Conversion push** — send the recipient a win-back offer at T-7 days and T-0 of expiry?
   (Recommended; it's where the ROI is, and at $39.99 the gift is already a discounted acquisition.)

## 10. Phased plan

**Phase 0 — today, no code.** Generate a batch of App Store offer codes and use the existing
"Redeem a Code" row to hand out gifts manually. Validates demand before we build anything.

**Phase 1 — backend (≈2–3 days).** `functions/gifting.js` with `giftCreate` + `giftRedeem`, the
`gifts` and `giftBatches` collections, `firestore.rules` entries (`allow read, write: if false`),
the indexes, and the `@apple/app-store-server-library` JWS verification (this is the new piece —
budget time for getting Apple's root certs and the sandbox/production environment switch right).
A `scripts/` curl harness against the emulator.

**Phase 2 — products (≈0.5 day, mostly waiting on review).** Create `SpeakLifeGiftYear` as a
consumable at $39.99 in App Store Connect, add it to RevenueCat, and confirm it is **not** attached
to the `premium` entitlement. (`SpeakLifeGiftLifetime` follows later, gated on §6.)

**Phase 3 — client (≈3 days).** `GiftService.swift` (direct StoreKit purchase with
`.quantity(n)` + both endpoints), `GiftSubscriptionView.swift` with the quantity stepper, running
total, the "$10 less than a year costs you" line, and the per-code share list, the
`giftSubscriptionRow` in `ProfileView`, `speaklife://gift?code=` routing, Branch share links,
analytics. The product picker is built but has one entry until lifetime ships.

**Phase 4 — durability + polish (≈1–2 days).** Re-claim path, gift-redeemed push to the gifter,
expiry win-back sequence, App Store Server Notifications V2 endpoint for refunds.

**Phase 5 (optional, later) — lifetime.** `Purchases.logIn` identity pinning plus the Sign in with
Apple prompt at redemption (§6), then the `SpeakLifeGiftLifetime` product. Or swap lifetime for a
5-year gift and skip most of this.

**Tests (throughout).** Unit tests for code generation/normalization, the redemption state machine,
`productId` → duration mapping, and batch idempotency (a replayed `jws` must return the same N codes
and never mint more). Follow `SpeakLifeTests/APIClientTests.swift` for the URLSession stubbing
pattern. Manual, in sandbox: buy quantity 3 → confirm 3 codes → redeem one on a second device →
verify `isPremium` flips and survives a cold launch → confirm the other two stay unredeemed →
verify the 10-per-transaction ceiling.

**Total: roughly one focused week for yearly gifting end to end**, the bulk of it the JWS
verification and the quantity UI. Lifetime adds a few days on top, most of it identity work rather
than gifting work.

## 11. Sources

- [App Review Guidelines 3.1.1 (gifting)](https://developer.apple.com/app-store/review/guidelines/)
- [RevenueCat — Grant promotional access](https://www.revenuecat.com/docs/promotionals)
- [RevenueCat API v1](https://www.revenuecat.com/docs/api-v1)
- [App Store Connect — Set up offer codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/)
- [App Store Connect API — Create one-time use offer codes](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-subscriptionoffercodeonetimeusecodes)
- [StoreKit — Supporting offer codes in your app](https://developer.apple.com/documentation/storekit/supporting-offer-codes-in-your-app)
- [StoreKit — `Product.PurchaseOption.quantity(_:)`](https://developer.apple.com/documentation/storekit/product/purchaseoption/quantity(_:))
- [App Store Server API — `JWSTransactionDecodedPayload`](https://developer.apple.com/documentation/appstoreserverapi/jwstransactiondecodedpayload)
- [App Store Server Library](https://developer.apple.com/documentation/appstoreserverapi/simplifying-your-implementation-by-using-the-app-store-server-library)
- [RevenueCat — Non-subscription purchases](https://www.revenuecat.com/docs/platform-resources/non-subscriptions)
