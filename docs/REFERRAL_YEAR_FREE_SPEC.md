# Invite Friends, Get a Year Free — Spec

Status: **Draft, pre-build.** Tests come first. Write the cases in
`REFERRAL_BE_TDD.md` and `REFERRAL_FE_TDD.md` as failing tests before any
production code.

Companion docs:
- `docs/REFERRAL_BE_TDD.md`: Cloud Functions, Firestore rules, offer code pool
- `docs/REFERRAL_FE_TDD.md`: the iOS app
- `docs/STAND_TOGETHER_SPEC.md`: the invite system this feature reuses

---

## 1. What it is

A person finishes onboarding and closes the paywall without subscribing. The
app then offers them another way in: **invite friends, and when 5 of them
install SpeakLife and finish onboarding, you get a year of Premium free.**

The reward is an **App Store offer code** for one free year on the annual
subscription. It is redeemed through Apple, it shows up in RevenueCat like any
other subscription, and at the end of the year it renews at full price unless
the person cancels.

## 2. Principles (do not trade these away)

1. **Count friends who actually install, never taps on Share.** The app cannot
   see whether a share was sent to anyone. Rewarding taps invites gaming, and
   Apple rejects designs where the reward is tied to the act of sharing itself.
2. **The server decides everything that matters.** Counting, the target, the
   cheating checks and handing out codes all happen in Cloud Functions. The
   client displays progress and never writes it.
3. **One reward per person, ever** (v1).
4. **Never block or delay onboarding.** The referral page appears after
   onboarding, can always be skipped, and a backend failure never strands
   anyone on it.
5. **A friend is counted exactly once,** however many times they tap the link,
   reinstall or open it on another device.

## 3. Glossary

| Term | Meaning |
|---|---|
| **Referrer** | The person inviting friends. |
| **Friend** | Someone who installs through a referrer's link or code. |
| **Referral code** | The referrer's personal 8-character code, e.g. `K7MQ2XPA`, using the same alphabet as Stand codes. |
| **Referral link** | `https://speaklife.app.link/r/<CODE>`, a Branch link. |
| **Qualified referral** | A friend who passes every check in §7 and so counts toward the 10. |
| **Target** | How many qualified referrals unlock the reward. Default 5 (launch decision; 3 is a one-value config change). Locked per referrer when they enroll. |
| **Reward code** | A one-time App Store offer code for a free year, taken from the server-side pool. |
| **Pool** | The offer codes uploaded from App Store Connect, stored server-side. |

## 4. Decisions

Decisions marked **(default)** are what the tests are written against. Changing
one means changing the tests listed next to it.

| # | Decision | Choice | Tests affected |
|---|---|---|---|
| D1 | What counts | New install that arrived through the link or code, finished onboarding, on a device never counted before. | BE-CLM-*, FE-CLM-* |
| D2 | Reward mechanism | App Store offer code, one free year on the annual subscription. Fallback (not built in v1): a RevenueCat promotional entitlement. | BE-RWD-* |
| D3 | Target | 5 **(default, decided 2026-10-02)**; 3 is the alternative. Every UI string reads the number from the record, never hardcodes it. A server config value, locked onto the referrer's record when they enroll, so later config changes never move anyone's goalposts. | BE-ENR-04, BE-CLM-10 |
| D4 | Hard paywall | **(default)** The automatic page only appears when the paywall could be closed. Remote Config flag `referralOnHardPaywall` (default `false`) adds a small "Or invite 5 friends for a free year" (number from config) link to the hard paywall. That link opens the same page, and the paywall stays behind it. | FE-ENT-* |
| D5 | Welcome discount offer | **(default)** Unchanged. The welcome offer still appears after the first Daily Burst. The two don't conflict: one is a discount, the other is free. | FE-ENT-09 |
| D6 | Reward for the friend | **(default)** None in v1. | — |
| D7 | Referrer subscribes before reaching the target | **(default)** Keep counting, and still issue the code at the target. The App Store Connect offer is eligible for new, existing and expired subscribers, so the code always redeems. To confirm in sandbox: an existing subscriber's free year applies from their next renewal. | BE-RWD-06, FE-QA-07 |
| D8 | Attribution window | **(default)** The friend must finish onboarding within 14 days of the link being captured. | BE-CLM-08, FE-CLM-06 |
| D9 | Velocity cap | **(default)** At most 5 qualified referrals per referrer per rolling 24 hours. Anything over the cap gets `retry_later`, and the friend's app retries on later launches. | BE-CLM-11 |
| D10 | Kill switch | Client: Remote Config `referralYearFreeEnabled` (default `false`) hides all referral UI. Server: `referralConfig/current.enabled` rejects new enrollments and claims. Rewards already unlocked are always readable. | BE-CFG-*, FE-FLG-* |

## 5. User journeys

### J1. Referrer: offer after onboarding
1. They finish any onboarding arm. `finishOnboarding()` runs with `converted == false`.
2. If eligible (§9.1), the **Referral page** is shown over Home as a full-screen cover.
3. The page shows a headline, how it works in three steps, a progress bar at 0/5, a primary **Invite friends** button and a secondary **Not now**.
4. **Invite friends**: the app creates an anonymous account if there isn't one, the server returns the person's code (§8.1), and the share sheet opens with an image card plus text and link.
5. **Not now** dismisses the page, which never comes back automatically. It stays reachable from Profile.

### J2. Referrer: watching progress
- A **Get a year free** row in Profile opens the same page in progress mode: "2 of 5 friends joined", a share button, and the code written out for reading aloud (`K7MQ-2XPA`).
- A push arrives whenever a friend counts ("A friend joined. 2 of 5.") and when the reward unlocks. Friends' names are never shown, only counts.

### J3. Referrer: unlocking
1. The final qualified referral arrives (the 5th at launch). In the same transaction, the server assigns one reward code from the pool.
2. A push goes out: "You did it. Your free year is ready."
3. The page shows the reward state, the code, and a **Redeem my free year** button that opens `https://apps.apple.com/redeem?ctx=offercodes&id=1617492998&code=<CODE>`.
4. The person redeems with Apple. RevenueCat's customer info listener turns on `isPremium`, and the page shows "Premium active".
5. If the pool is empty when they reach the target, the page shows "Your free year is being prepared", a sweep assigns a code once the pool is refilled, and they get a push (§8.5).

### J4. Friend: doesn't have the app
1. They tap the link. Safari opens, Branch redirects to the App Store, and they install.
2. On first launch Branch resolves the deferred link with `~referring_link` set to `.../r/<CODE>`. The app stores a **pending referral** (code plus capture time) and does not present anything.
3. The friend goes through normal onboarding, getting whatever arm Remote Config assigns.
4. In `finishOnboarding()`, whether or not they subscribed, the app sends the claim (§8.2). On a network failure the pending claim persists and is retried on later launches until the window closes.
5. The friend sees no referral UI as a result of the claim. Their own referral page, if eligible, follows J1 like anyone else's.

### J5. Friend: Branch fails to match the install
- Branch matching is probabilistic, so this will happen. Within 14 days of first launch, Profile shows **Have an invite code?**, which takes an 8-character code. This only appears if no pending or completed claim exists and onboarding is finished. The entered code is submitted as a claim with source `manual`.

### J6. Friend: already has the app
- Every build since 4.59 claims `speaklife.app.link` (see `StandLink.shareHost`), so the link opens the installed app.
- Builds with this feature parse the code in `onOpenURL`, see the person is already onboarded, record `referral_link_opened` with outcome `existing_user` and **do not claim**. They aren't a new install.
- Older builds open and do nothing. That is correct, because existing users never count.

## 6. Data model (Firestore, default database)

All collections are **server-write only**. A client can read only its own records.

### `referrals/{uid}`: the referrer's record
```js
{
  uid,                        // the referrer's Firebase uid (anonymous or Apple)
  code: 'K7MQ2XPA',
  target: 5,                  // locked when they enroll (D3)
  count: 4,                   // qualified referrals; ALWAYS == creditedCount below
  status: 'active' | 'unlocked' | 'unlocked_pending_code',
  createdAt, updatedAt,
  unlockedAt: null | Timestamp,
  reward: null | {
    code: 'ABCD1234EFGH',     // App Store offer code
    assignedAt, expiresAt,    // code expiry from App Store Connect
    reissueCount: 0
  }
}
```
Read: owner only. Write: never from a client.

### `referrals/{uid}/credits/{friendUid}`: one document per counted friend
```js
{ friendUid, creditedAt, source: 'deferred'|'universal_link'|'manual', deviceVerified: true }
```
Using the document id as the key gives exactly-once counting: a second claim by
the same friend hits an existing document. Read: never, from any client
(friend uids are private).

### `referralCodes/{CODE}`: lookup from code to referrer
```js
{ uid, createdAt, revoked: false }
```
Read and write: never from a client. As with `standInvites`, a code a client
could look up is a code someone can enumerate.

### `referralClaims/{friendUid}`: one per friend, ever
```js
{ friendUid, code, referrerUid, outcome: 'credited'|'rejected', reason, createdAt }
```
This makes a friend's claim final. A second claim from the same uid, even with
a different code, returns the first outcome. No client access.

### `referralRewardCodes/{offerCode}`: the pool
```js
{ code, batchId, expiresAt, assignedTo: null | uid, assignedAt: null }
```
No client access. Filled by the admin import script (§10).

### `referralConfig/current`
```js
{ enabled: true, target: 5, windowDays: 14, dailyCap: 5, minCodeValidityDays: 30 }
```
Read by functions only. If the document is missing, functions use built-in
defaults equal to the values above, with `enabled: false` and `target: 5`.

### `referralRateLimits/{uid|bucket}`
Same sliding-window shape as `standRateLimits`.

### `referralBitRetries/{autoId}`
```js
{ deviceToken, bit: 0 | 1, isDevelopment, attempts, createdAt, lastError? }
```
DeviceCheck bit updates that failed after a credit (bit 0) or an enrollment
(bit 1). `referralSweep` retries them daily and drops one after 14 failed
attempts or when Apple calls the token invalid. No client access.

Retired reward codes keep `assignedTo` and gain `retired: true`, so the pool
query (`assignedTo == null`) can never hand one out again. That query needs the
`(assignedTo, expiresAt)` composite index in `firestore.indexes.json`.

### Changes to `firestore.rules`
Explicit deny blocks for each collection above, so they don't rely on the
default deny. Owner-only read on `referrals/{uid}` (not its `credits`
subcollection).

## 7. What makes a referral qualify

A claim is **credited** only if all of these hold, checked in this order. The
first failure decides the `reason`.

| # | Check | Reason on failure | Client behaviour |
|---|---|---|---|
| 1 | Server kill switch is on | `disabled`, **not** recorded as final | Keep the pending claim, retry |
| 2 | Caller is authenticated | Error `unauthenticated` | Retry later |
| 3 | Per-friend throttle: 10 claims an hour | Error `resource-exhausted` | Retry later |
| 4 | Code is well formed | `invalid_code`, **not** recorded as final (a typo is not a lifetime lockout) | Drop this code; a corrected code can still be entered |
| 5 | Friend has no earlier claim (`referralClaims/{friendUid}`) | Return the first outcome, unchanged | Drop |
| 6 | Code exists and isn't revoked | `unknown_code`, **not** recorded as final. Guessing is capped by the per-friend throttle (#3), and a guessed code only credits from a fresh, DeviceCheck-verified device. | Drop this code; manual entry shows "We couldn't find that code" |
| 7 | Friend isn't the referrer (uid) | `self_referral` | Drop |
| 8 | Captured within the window (D8), per the client-reported capture time. The server also rejects capture times in the future or older than the friend's account. | `expired` | Drop |
| 9 | DeviceCheck: the device has never been counted (bit 0 clear) and has never enrolled as a referrer (bit 1 clear) | `device_already_counted` / `device_is_referrer` | Drop |
| 10 | Referrer hasn't reached the target yet | `target_reached`, still recorded so the claim is final | Drop |
| 11 | Referrer is under the velocity cap (D9) | `retry_later`, **not** recorded as final | Keep the pending claim, retry |
| 12 | DeviceCheck service reachable | `retry_later` | Keep, retry |

When a claim is credited, all of these happen **in one transaction**: write the
credit, increment `count`, write the final claim, and if `count` reaches
`target`, unlock and assign a reward code. After the transaction, DeviceCheck
bit 0 is set and a push goes to the referrer. If setting the bit fails, the
credit stands and the failure is logged. Setting it is retried by the daily
sweep.

**DeviceCheck bits.** Apple keeps two bits per device per developer team. They
survive deleting the app and erasing the phone.
- bit 0 = "this device has been counted as a referred friend"
- bit 1 = "this device has enrolled as a referrer"

No other app on this developer account may use DeviceCheck bits without
coordinating with this table.

**Simulator and unsupported devices.** `DCDevice.isSupported == false` sends no
token, and the claim is rejected with `device_unverifiable`. Emulator tests
inject a fake verifier.

## 8. Cloud Functions (new file `functions/referral.js`)

All functions are callable (`onCall`) unless stated otherwise. Errors use
`HttpsError`. The file exports a `__test` seam like `standTogether.js` does.

### 8.1 `getOrCreateReferral()` → `{ code, count, target, status, reward }`
- Requires auth. Throttled to 20 calls an hour.
- If `referrals/{uid}` exists, returns it. **Idempotent: never creates a second code.**
- Otherwise, with the server switch on: generates a unique code (retrying on a collision), writes `referralCodes/{code}` and `referrals/{uid}` in one transaction with `target` from config, then sets DeviceCheck bit 1 (needs a `deviceToken` argument; if it's missing, enroll anyway and log).
- With the switch off: if a record exists, returns it (so existing progress stays visible). If not, `failed-precondition`.

`getOrCreateReferral` takes `{ deviceToken?, isDevelopment? }`. `reward` in the
response is `null` or `{ code, assignedAt, expiresAt, reissueCount }` with both
times in epoch milliseconds. The response never carries credits or friend uids.

### 8.2 `claimReferral({ code, capturedAt, source, deviceToken, isDevelopment? })` → `{ outcome, reason? }`
- `outcome` is one of `credited`, `rejected` or `retry_later`. Order of checks as in §7.
- `capturedAt` is epoch **milliseconds**. A value below 1e11 is read as seconds, so `Date().timeIntervalSince1970` also works.
- `isDevelopment: true` sends DeviceCheck calls to Apple's development host. Debug builds installed from Xcode set it; TestFlight and App Store builds omit it (they use Apple's production environment).
- A malformed `source` or a non-numeric `capturedAt` is an `invalid-argument` error, not a final claim.

### 8.3 `reissueReferralReward()` → `{ reward }`
- For a reward code that Apple refuses or that has expired. Allowed once per referrer (`reissueCount < 1`). Takes a fresh code from the pool, and the old one is never handed out again.

### 8.4 Push on credit and unlock
- Sent from inside `claimReferral` after the transaction commits, using `users/{uid}.fcmToken`. A push failure never fails the claim.
- Copy, body only: "A friend joined. {count} of {target}." on a credit, and "You did it. Your free year is ready." on the credit that unlocks a reward (one push, not two). Data: `{ notificationType: 'referral', deepLink: 'referral' }`. No friend data.

### 8.5 `referralSweep` (scheduled, daily)
- Assigns codes to `unlocked_pending_code` referrers, oldest first, while the pool has codes, and pushes to each.
- Retries any DeviceCheck bit updates that failed.
- Logs a warning when the pool has fewer than 100 unassigned codes valid for at least `minCodeValidityDays`. The warning goes through the existing function logging, with a log-based alert set up in Google Cloud.

### 8.6 Changes to existing functions in `standTogether.js`
- **`completeAccountMerge`**: when an anonymous user signs in with Apple, move their referral record.
  - Only the source has one: re-key it to the target uid, and repoint `referralCodes/{code}.uid`.
  - Both have one: union the credits, set `count` to the size of the union, keep the code with more credits (revoke the other), keep any reward already assigned (if both have one, keep the earlier one; the other code goes back to the pool unless it was assigned more than a day ago), and set `target` to the lower of the two.
  - Must be idempotent, like the existing merge.
- **`deleteAccount`**: delete `referrals/{uid}` and its credits, and revoke its `referralCodes`. Keep `referralClaims` documents where this uid was the friend (no personal data beyond uids; they stop reinstall farming).

### Code pool selection
- Take the unassigned code with the soonest `expiresAt` that is still valid for at least `minCodeValidityDays`. Assign it in the same transaction that unlocks, so two concurrent unlocks can never get the same code.

## 9. App behaviour

### 9.1 When the referral page appears automatically
All of these must be true:
- `referralYearFreeEnabled` is on.
- `finishOnboarding()` ran for real, not a debug replay.
- `converted == false`.
- `hasFullAccess == false`.
- It hasn't been shown automatically before (UserDefaults key `referralAutoShown`).
- There is no pending Stand invite. If there is one, the Stand join sheet goes first, and the referral page is skipped this time. It doesn't queue.

It appears after `isOnboarded = true`, as a full-screen cover on the home
screen. It is never presented on top of onboarding.

### 9.2 Profile entry
- **Get a year free**: shown while the flag is on and the person either has no referral record or has one whose reward hasn't been redeemed yet.
- **Have an invite code?**: J5 rules.

### 9.3 Page states
`loading` → `notEnrolled` → `enrolling` → `active(count, target)` → `unlocked(code)` / `unlockedPendingCode` → `redeemed`, plus `error(retryable)` and `offline(cached)`.

The last-known state is cached in UserDefaults, so the page opens instantly and
works offline, like `StandPassStore`. The server state wins when it arrives.

### 9.4 Share payload
- `UIActivityViewController` with an image card and text (same reason as `StandInviteSheet`: `ShareLink` can't carry both).
- Text: one line of copy plus the link. The copy is held in Remote Config `referralShareText`, where `{link}` stands in for the link.

### 9.5 Link and code capture
- New `ReferralLink` type, parallel to `StandLink`, using the same alphabet and normalisation:
  - Path `/r/<CODE>` on any host.
  - Custom scheme `speaklife://r/<CODE>`.
  - Query `?ref=<CODE>`.
  - Branch deep-link data key `ref`.
- **A Stand code is never read as a referral code, and vice versa.** The path segment decides.
- The pending referral is stored as `{code, capturedAt, source}` in UserDefaults key `pendingReferral`. **First capture wins**: a later link doesn't overwrite it.
- Branch attribution: a referral link sets `AcquisitionChannel.referral`, same as a Stand invite.

## 10. App Store Connect runbook (owner: founder)

1. App Store Connect → SpeakLife → Subscriptions → the annual product (`SpeakLife1YR29`, or whichever annual Remote Config is serving) → **Offer Codes** → create.
   - Name: `Referral 1 Year Free`. Type: **Free**. Duration: **1 year**. Eligibility: new, existing and expired subscribers (D7).
   - Confirm that a 1-year free duration is offered for this product. If it isn't, stop and revisit D2.
2. Create **one-time-use codes**: a batch of 500 to start. Note the expiry date App Store Connect sets, and check the current quarterly limit.
3. Download the CSV. Don't share it. Each line is a working free year.
4. Import: `node functions/scripts/importOfferCodes.js --file codes.csv --batch 2026Q4 --expires 2027-03-31`.
   - The script is idempotent: re-running it skips codes already in the pool and never resets an assigned code.
5. Each quarter, or when the low-pool alert fires, repeat steps 2 to 4.
6. Sandbox check before launch: redeem one code on a sandbox account, check that RevenueCat shows the `premium` entitlement, and check that the expiry is a year out.

## 11. Analytics (PostHog through `AnalyticsService`)

| Event | When | Properties |
|---|---|---|
| `referral_page_shown` | Page appears | `entry` (`post_onboarding` / `profile` / `hard_paywall` / `push`), `state`, `count`, `target` |
| `referral_page_dismissed` | Not now or close | `entry`, `state`, `seconds_on_page` |
| `referral_enrolled` | First code created | `entry` |
| `referral_share_tapped` | Invite button | `entry`, `count` |
| `referral_share_completed` | The share sheet's completion handler reports `completed == true` | `activity_type` |
| `referral_link_opened` | App reads a referral code | `source` (`deferred` / `universal_link` / `manual`), `outcome` (`captured` / `existing_user` / `already_pending` / `invalid`) |
| `referral_claim_result` | Claim response received | `outcome`, `reason`, `source`, `attempt` |
| `referral_progress_seen` | Page shows a higher count than the last one seen | `count`, `target` |
| `referral_reward_unlocked` | First time the client sees `unlocked` | `days_since_enrolled` |
| `referral_redeem_tapped` | Redeem button | — |
| `referral_reward_redeemed` | `isPremium` turns true within 30 minutes of a redeem tap | — |
| `referral_reissue_requested` | "My code didn't work" | `result` |

The existing `onboarding_finished` gains `referral_pending: Bool` on the friend side.

**The success metric is paid conversion per onboarding start, not shares.**
Run as a Remote Config A/B test: the flag on in the treatment, off in control.
Watch for cannibalisation, meaning people who would have paid waiting for a
free year instead. Follow `docs/ANALYTICS_DATA_QUALITY.md`. In particular,
exclude simulator traffic and don't count `paywall_shown` and
`paywall_impression` together.

## 12. Remote Config keys (client)

| Key | Type | Default |
|---|---|---|
| `referralYearFreeEnabled` | bool | `false` |
| `referralOnHardPaywall` | bool | `false` |
| `referralShareText` | string | `"I've been speaking God's promises out loud every morning with SpeakLife. Try it free: {link}"` |
| `referralLinkDomain` | string | `speaklife.app.link` (read the `StandLink.shareHost` warning before changing it) |

## 13. Rollout

1. Backend and rules, all BE tests green, deployed with `referralConfig/current.enabled = false`.
2. Pool imported and the sandbox redemption check (§10.6) passed.
3. App build with the flag defaulting to off, all FE tests green, and the QA matrix in the FE doc passed on a real device.
4. Turn on the server switch. Remote Config flag at 10% as an A/B test.
5. Read the results after two weeks per §11, then widen or roll back.

## 14. Out of scope for v1
- A reward for the friend (D6).
- Showing friends' names or a leaderboard.
- More than one reward per person.
- Android.
- RevenueCat promotional entitlement fallback (D2).
