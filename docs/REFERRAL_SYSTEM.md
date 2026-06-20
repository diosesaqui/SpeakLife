# SpeakLife Referral System — Design & Recommendation

> "Share SpeakLife with 3 friends, get a free month of Premium."

This doc proposes a referral / viral-growth system built on top of the
infrastructure SpeakLife **already has**: RevenueCat entitlements, Firebase
Cloud Functions + Firestore, Branch deep links, the existing share sheet, and
PostHog/Firebase analytics. It also explains how the existing in-app "Redeem a
Code" feature fits in.

---

## 1. What we already have (and can reuse)

| Capability | Where it lives | Reuse for referrals |
|---|---|---|
| Premium entitlement (`premium`) via **RevenueCat** | `Services/IAP/RevenueCatManager.swift`, `SubscriptionStore.swift` | Grant the "free month" as a **promotional entitlement** — no App Store purchase, no card required |
| **Redeem a Code** (Apple offer-code sheet) | `ProfileView.swift` → `subscriptionStore.redeemOfferCode()` → `Purchases.shared.presentCodeRedemptionSheet()` | Fallback reward-delivery method; not how we attribute referrals (Apple can't tell us *who* referred whom) |
| Stable per-user ID | `RevenueCatManager.shared.appUserID` | The key we hang all referral records on |
| **Firebase backend** (Firestore + Cloud Functions v2, Node 20) | `functions/bibleChat.js`, `functions/prayerWallNotifications.js` | Store referral graph + orchestrate the grant via RevenueCat REST API |
| Server-side RC entitlement check | `bibleChat.js` → `isPremiumViaRevenueCat()` | Same pattern to validate/grant |
| **Branch** deep links + deferred attribution | `AppDelegate.swift` (`BranchAttribution`), `SpeakLifeApp.swift onOpenURL` | Carry the referral code through App Store install → first launch |
| Share sheet everywhere | `ProfileView.swift` (`showShareSheet`), `Events.shareSpeakLifeTapped` | Becomes the "Invite friends" entry point |
| Analytics fan-out (Firebase, PostHog, TikTok, Meta) | `Core/Analytics/AnalyticsService.swift`, `trackShare()` | Measure the full share → install → activate → reward funnel |
| FCM push | `AppDelegate.swift`, `NotificationHandler.swift` | "🎉 Your friend joined — 1 more for your free month!" |

**Bottom line:** ~80% of the plumbing exists. The two real gaps are (1) a
referral data model + grant logic in a Cloud Function, and (2) a small amount of
new UI (invite screen + optional "enter a code" field).

---

## 2. The core problem: attribution on iOS

The hard part of any mobile referral program is **connecting the friend who
installs back to the person who invited them**, across the App Store boundary
(the friend taps a link → goes to App Store → installs a fresh app with no
memory of the link).

We solve this **two ways**, used together:

1. **Deferred deep link (primary, frictionless).** Branch is already wired in.
   The inviter shares a Branch link with their `referralCode` embedded. When the
   friend installs and opens the app, Branch resolves the deferred link and hands
   us the `referralCode` on first launch — zero typing.
2. **Manual code entry (fallback, always works).** A short human-readable code
   (e.g. `GRACE-7K2`) the friend can type into an "Have a referral code?" field
   in onboarding or Profile. Covers cases where deferred matching fails (Branch
   match rates aren't 100%, especially post-iOS clipboard restrictions).

Both paths converge on the same Cloud Function.

---

## 3. How the "free month" is granted (no purchase required)

Use **RevenueCat Promotional Entitlements** — server-to-server, no App Store
transaction, no payment method on file:

```
POST https://api.revenuecat.com/v1/subscribers/{app_user_id}/entitlements/premium/promotional
Authorization: Bearer <REVENUECAT_SECRET_KEY>
{ "duration": "monthly" }
```

- Durations supported: `daily, three_day, weekly, monthly, two_month, three_month, six_month, yearly, lifetime`.
- The entitlement appears in `CustomerInfo` exactly like a paid one, so the
  existing `isPremium` flow (`updateEntitlementsFromRC()` / `applyCustomerInfo()`)
  lights up Premium automatically with **no client changes** to gating.
- The secret key lives **only** in Cloud Functions config
  (`REVENUECAT_SECRET_KEY`), never in the app.

> **Why not Apple offer codes for the reward?** Offer codes can't be issued
> programmatically per-user and can't track who earned them. They're great as a
> manual/marketing tool (and we already support redeeming them), but RC
> promotional grants are the right primitive for an automated referral reward.

---

## 4. Recommended program design

### Single-sided, non-subscribers only (decided for v1)
- **Inviter:** 3 successful referrals → **1 month Premium free**, granted as a
  RevenueCat promotional entitlement.
- **Invitee:** gets the app's **existing 3-day onboarding trial** (no separate
  referral reward in v1).
- **Only non-subscribers see the "earn a free month" UI.**

**Why not double-sided?** The classic "double-sided doubles accept rates"
finding assumes the invitee otherwise gets nothing. SpeakLife already gives every
new user a 3-day trial, so the friend isn't empty-handed. We launch single-sided
and keep the natural sweetener — *referred friends get an extended trial (e.g. 7
days instead of 3)* — as a Phase 2 A/B test that reuses the same grant path.

### Why a free month doesn't work for active subscribers
A RevenueCat **promotional** entitlement does **not** stop Apple from billing an
active auto-renewable subscription — Apple owns that billing. Granting "premium"
to someone already paying just double-covers them while Apple keeps charging, so
the free month only has real cash value to a **non-subscriber**. Therefore:
- The "Invite friends, get a free month" row is gated on `!isPremium` (client).
- `redeemReferral` additionally refuses to count an invitee RevenueCat reports as
  already Premium (server).
- Rewarding paying advocates (banked credit, exclusive content, recognition) is
  deferred — revisit once the core loop is proven.

### What counts as a "successful" referral (anti-fraud)
A referral only counts toward the inviter's 3 when the invitee:
1. Is a **brand-new** `appUserId` (never seen before), AND
2. Is **not already Premium**, AND
3. **Completes onboarding** (we already fire onboarding-complete; gate the count
   on this, not on raw install, to kill throwaway installs), AND
4. Was not self-referred (invitee ≠ inviter device/ID).

All of this is enforced **server-side** in the Cloud Function. The client is
never trusted to say "I earned it."

### Caps & expiry
- One referral credit per invitee `appUserId`, **ever**.
- A code can be redeemed many times (it's an inviter's personal code) but each
  invitee only once.
- Optional: cap total free months per inviter per quarter to bound abuse.

---

## 5. Data model (Firestore)

```
referralCodes/{code}                 // e.g. "GRACE-7K2"
  ownerAppUserId: string
  createdAt: timestamp
  active: bool

users/{appUserId}                    // referral state per user
  referralCode: string               // their own code
  successfulReferrals: number        // count toward the next reward
  rewardsEarned: number              // months granted so far
  referredBy: string|null            // code they came in on (set once)
  referralRewardPending: bool

referrals/{inviteeAppUserId}         // one doc per invitee = idempotency guard
  code: string
  inviterAppUserId: string
  status: "pending" | "qualified"    // qualified = onboarding complete
  createdAt: timestamp
  qualifiedAt: timestamp|null
```

`referrals/{inviteeAppUserId}` as the doc ID makes "an invitee can only be
counted once" a natural Firestore uniqueness constraint.

---

## 6. End-to-end flow

```
INVITER                          FRIEND                         BACKEND (Cloud Fn)
──────────────────────────────────────────────────────────────────────────────
Profile → "Invite friends"
  └─ getReferralCode() ─────────────────────────────────────▶ create/return code
  └─ Branch link w/ code
  └─ system share sheet ──────▶ taps link
                                 └─ App Store → install
                                 └─ first launch:
                                    Branch resolves code
                                    (or types it manually)
                                 └─ onboarding...
                                 └─ onboarding complete ─────▶ redeemReferral(
                                                                 invitee, code)
                                                               ├─ validate (new,
                                                               │   not premium,
                                                               │   not self,
                                                               │   not dup)
                                                               ├─ grant invitee
                                                               │   7-day promo
                                                               ├─ referrals/{inv}
                                                               │   = qualified
                                                               └─ inviter
                                                                   successfulReferrals++
                                 ◀── "You've got 7 days free!"
  ◀── push: "1 of 3 friends!" ◀──────────────────────────────  if count==3:
  ◀── Premium unlocked         ◀──────────────────────────────  grant inviter
                                                                 1-month promo,
                                                                 reset counter
```

---

## 7. Cloud Function surface (new file: `functions/referrals.js`)

Three callable/HTTPS endpoints, following the existing `bibleChat.js` pattern
(RC entitlement verification, Firestore writes, secret in config):

1. **`getReferralCode`** `{ appUserId } → { code }`
   Returns the user's code, creating it on first call. Code = short, collision-
   checked (e.g. word + base32 of a counter).

2. **`redeemReferral`** `{ inviteeAppUserId, code, source }`
   The heart of the system. Runs all anti-fraud checks in a Firestore
   transaction, grants the invitee welcome trial, marks the referral
   `qualified`, increments the inviter, and — when the inviter reaches 3 —
   calls RevenueCat to grant the free month and resets the counter. Idempotent
   on `inviteeAppUserId`.

3. **`getReferralStatus`** `{ appUserId } → { successfulReferrals, rewardsEarned, code }`
   Powers the progress UI ("2 of 3 friends joined").

All three reuse the RevenueCat REST helpers already proven in `bibleChat.js`.

---

## 8. Client changes (Swift)

Small, additive — no changes to existing Premium gating.

1. **`ReferralService.swift`** (new, `Services/`): thin wrapper calling the three
   Cloud Functions; exposes `@Published` referral status. Mirrors how
   `SubscriptionStore` talks to RC.
2. **Invite screen** (new, `Views/ProfileView/`): progress ring (2/3), the user's
   code, a big "Invite friends" button that builds the Branch link and presents
   the **existing** `ShareSheet`. Reachable from the Profile row currently labeled
   "Share SpeakLife" (upgrade it to "Invite friends — get a free month").
3. **"Have a referral code?" field**: optional row in onboarding (final step) and
   in Profile. Calls `redeemReferral` with `source: "manual"`.
4. **Deferred-link capture**: in the existing Branch `apply()` path
   (`AppDelegate.swift`), read a `referralCode` param and stash it; fire
   `redeemReferral` once onboarding completes with `source: "deeplink"`.
5. **Analytics**: add events `referral_invite_sent`, `referral_redeemed`,
   `referral_reward_earned` via `AnalyticsService` so PostHog can chart the
   funnel and retention of referred users.

---

## 8b. What's built (Phase 1, in this branch)

**Backend — `functions/referrals.js`** (wired into `functions/index.js`):
- `getReferralCode` — returns/creates the user's code (e.g. `GRACE-7K2`).
- `redeemReferral` — invitee path; runs all anti-fraud checks in a Firestore
  transaction (one referral per invitee ever, no self-referral, not-already-
  Premium), grants the inviter a promotional month at every 3rd qualified
  referral, and self-heals failed grants via a `pendingRewards` counter.
- `getReferralStatus` — code + progress for the UI; reconciles pending rewards.
- Firestore lockdown for `referralCodes` / `referralUsers` / `referrals`
  (server-only) added to `firestore.rules`.

**Client (Swift):**
- `Services/Referral/ReferralService.swift` — calls the three endpoints, mirrors
  `BibleChatAIService` networking (incl. emulator flag), exposes `@Published`
  progress, captures/redeems pending codes.
- `Views/ProfileView/ReferralView.swift` — invite screen: progress bar, code,
  "Invite Friends" → existing `ShareSheet`, and a "Have a code from a friend?"
  redeem field.
- `ProfileView.swift` — new **Invite Friends, Get a Free Month** row in the
  Premium section, shown only when `!subscriptionStore.isPremium`.
- Analytics events in `Events.swift`: `referral_screen_viewed`,
  `referral_invite_tapped`, `referral_redeemed`, `referral_reward_earned`.

**Deploy / config still required (not code):**
- `firebase deploy --only functions:getReferralCode,functions:redeemReferral,functions:getReferralStatus`
- `firebase deploy --only firestore:rules`
- Ensure `REVENUECAT_SECRET_KEY` secret is set (already used by `bibleChat`).
- In RevenueCat, confirm the `premium` entitlement accepts promotional grants.

**Deferred to Phase 2:** Branch deferred-deep-link capture of `?ref=CODE` and the
auto-redeem-on-onboarding-complete hook (`ReferralService` already has
`capturePendingCode` / `redeemPendingCodeIfNeeded` stubs ready), plus the
extended invitee trial.

## 9. Phased rollout

**Phase 1 — MVP (manual codes only, ~highest confidence):**
Cloud Function + Firestore model + invite screen + manual "enter a code" field +
RC promotional grant. Skip Branch deferred links at first. Fully functional, just
requires the friend to type a short code. Lowest risk, fastest to ship.

**Phase 2 — Frictionless:**
Wire Branch deferred deep links so the code carries through install
automatically. Add the double-sided invitee welcome trial. Add progress push
notifications.

**Phase 3 — Optimize:**
PostHog experiment on reward size (3 vs 5 friends; 1 week vs 1 month invitee
reward), milestone nudges, and a leaderboard / "founding member" angle for
power-sharers. Add abuse caps based on observed data.

---

## 10. Open questions for product

1. **Reward size:** 3 friends → 1 month confirmed? Or tiered (1 friend → 1 week,
   3 → 1 month, 5 → 3 months)?
2. **Invitee reward:** offer the friend a 7-day trial too? (Strongly recommended.)
3. **Eligibility:** can current/former paying subscribers also earn referral
   months, or new-ish users only?
4. **Definition of "successful":** gate on onboarding-complete (recommended) or
   something stronger like day-2 retention?
5. **Associated domains:** we currently have **no** `applinks:` entitlement, so
   web→app links rely on Branch's domain. Fine for v1; revisit if we want
   `speaklife.com/invite/...` universal links.

---

## Appendix — key code references

- Premium grant target entitlement: `RevenueCatManager.swift` →
  `premiumEntitlement = "premium"`
- Entitlement application (auto-reacts to promo grants): `SubscriptionStore.swift`
  → `updateEntitlementsFromRC()` / `applyCustomerInfo()`
- Existing redeem flow: `ProfileView.swift` → `redeemOfferCode()` →
  `RevenueCatManager.presentOfferCodeRedemption()`
- Stable user id: `RevenueCatManager.shared.appUserID`
- Backend pattern to copy: `functions/bibleChat.js` (`isPremiumViaRevenueCat`,
  Firestore usage docs, secret config)
- Share entry point: `ProfileView.swift` (`showShareSheet`, line ~621),
  `Events.shareSpeakLifeTapped`
- Deep link handling: `AppDelegate.swift` (`BranchAttribution`),
  `SpeakLifeApp.swift` `onOpenURL`
