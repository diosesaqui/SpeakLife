# Referral (Year Free) — iOS TDD Plan

Spec: `docs/REFERRAL_YEAR_FREE_SPEC.md`. Section numbers like §9 refer to it.

**How to use this doc.** Every row becomes a failing test before the code it
covers is written. The work is arranged so that **every decision the app makes
is pure logic, testable without Firebase, StoreKit, Branch or a simulator.** The
views only display a state that a tested type has already decided. If a bug can
only be caught by tapping through the app, the logic is in the wrong place:
move it out of the view.

---

## 1. Where the code goes (so it's testable)

`docs/TEST_ARCHITECTURE_PLAN.md` explains why app-hosted tests are slow and
fragile. So the logic lives in **SpeakLifeKit** (`SpeakLifeCore`), next to
`StandRoom` and `StandDayStamp`, and is tested in `SpeakLifeCoreTests` with no
app host.

| Type | Module | What it decides |
|---|---|---|
| `ReferralLink` | SpeakLifeCore | Pulls a referral code out of a URL or Branch parameters, and normalises it |
| `PendingReferral` + `PendingReferralStore` | SpeakLifeCore | Capturing, first-capture-wins, window expiry, persistence. Takes an injected `KeyValueStore` and `now()`. |
| `ReferralClaimPolicy` | SpeakLifeCore | Whether to claim now, what to do with each server outcome, retry rules |
| `ReferralEligibility` | SpeakLifeCore | Whether the page appears automatically after onboarding, and whether the Profile rows show |
| `ReferralPageState` + `ReferralPageReducer` | SpeakLifeCore | The page's state machine: (state, event) → state |
| `ReferralSnapshot` | SpeakLifeCore | Decodes the server record and the cached copy. Tolerates missing or unknown fields. |
| `ReferralShareText` | SpeakLifeCore | Fills the share copy template |
| `ReferralServicing` (protocol) | App | `getOrCreate()`, `claim(...)`, `reissue()`, `observe(uid)`. The real Firebase version, plus `FakeReferralService` for tests. |
| `ReferralViewModel` | App | Connects the reducer, service, analytics and cache. Tested in `SpeakLifeTests` with fakes. |
| `DeviceTokenProviding` (protocol) | App | Wraps `DCDevice`. A fake in tests. |
| Views | App | No branching beyond `switch state` |

Seams already in place to use: `DefaultFeatureFlags` (inject a dictionary in
tests), `DebugOverrides`, `AnalyticsTracking` (record events in a spy), and the
`PlatformSeams.swift` patterns.

**Test files**
- `Packages/SpeakLifeKit/Tests/SpeakLifeCoreTests/ReferralLinkTests.swift`
- `.../PendingReferralStoreTests.swift`
- `.../ReferralClaimPolicyTests.swift`
- `.../ReferralEligibilityTests.swift`
- `.../ReferralPageReducerTests.swift`
- `.../ReferralSnapshotTests.swift`
- `SpeakLife/SpeakLifeTests/ReferralViewModelTests.swift`
- `SpeakLife/SpeakLifeTests/AcquisitionAttributionTests.swift` (add cases)

---

## 2. `ReferralLink` (`FE-LNK`)

| ID | Input | Expect |
|---|---|---|
| FE-LNK-01 | `https://speaklife.app.link/r/K7MQ2XPA` | `K7MQ2XPA` |
| FE-LNK-02 | `https://any.host/r/k7mq-2xpa` | `K7MQ2XPA` (host ignored, normalised) |
| FE-LNK-03 | `speaklife://r/K7MQ2XPA` (code in the host position) | `K7MQ2XPA` |
| FE-LNK-04 | `https://speaklife.app.link/?ref=K7MQ2XPA` | `K7MQ2XPA` |
| FE-LNK-05 | `https://speaklife.app.link/R/K7MQ2XPA` (upper-case segment) | `K7MQ2XPA` |
| FE-LNK-06 | `https://speaklife.app.link/stand/K7MQ2XPA` | `nil` (**a Stand code is never a referral code**) |
| FE-LNK-07 | `StandLink.code(from:)` given `/r/K7MQ2XPA` | `nil` (the reverse also holds) |
| FE-LNK-08 | `/r/` with nothing after it, `/r/TOOSHORT1`, `/r/K7MQ0XPA` (has `0`) | `nil` |
| FE-LNK-09 | `/r/K7MQ2XPA/extra` | `K7MQ2XPA` |
| FE-LNK-10 | Branch parameters `["ref": "k7mq2xpa"]` | `K7MQ2XPA` |
| FE-LNK-11 | Branch parameters `["~referring_link": "https://speaklife.app.link/r/K7MQ2XPA"]` | `K7MQ2XPA` |
| FE-LNK-12 | Branch parameters with both `ref` and `~referring_link`, different codes | `ref` wins |
| FE-LNK-13 | Branch parameters with `stand` set and no `ref` | `nil` |
| FE-LNK-14 | `normalize` matches the server's `normalizeCode` on a shared fixture list (same JSON file used by the backend tests) | Same results row for row |
| FE-LNK-15 | `shareURL(code)` uses the Remote Config domain | `https://<domain>/r/<code>` |
| FE-LNK-16 | `formatted("K7MQ2XPA")` | `K7MQ-2XPA` |

**Fixture:** `referral_codes_fixture.json` holds `[{input, expected}]`. It's
read by both FE-LNK-14 and the backend's BE-HLP-02/03, so the client and server
can't drift apart.

---

## 3. `PendingReferralStore` (`FE-PND`)

Uses an in-memory `KeyValueStore` and a controllable clock.

| ID | Case | Expect |
|---|---|---|
| FE-PND-01 | `capture(code, source)` with nothing pending | Stored with `capturedAt = now`, returns `.captured` |
| FE-PND-02 | Second capture with a different code | Ignored, returns `.alreadyPending`, the first is kept |
| FE-PND-03 | Second capture with the same code | `.alreadyPending`, `capturedAt` **not** refreshed (the window can't be stretched) |
| FE-PND-04 | Capture after a claim is final (`markFinal`) | `.alreadyClaimed`, nothing stored |
| FE-PND-05 | `pending` 14 days later | Still returned |
| FE-PND-06 | `pending` at 14 days plus 1 second | `nil`, and the stored value is cleared |
| FE-PND-07 | Persisted value, then a new store built on the same storage (relaunch) | Same pending value comes back |
| FE-PND-08 | Corrupt stored data (bad JSON, wrong types) | `nil`, cleared, no crash |
| FE-PND-09 | `markFinal()` | Pending cleared, and a final flag stops any future capture |
| FE-PND-10 | `recordAttempt()` | Attempt counter goes up and persists (sent as `attempt` in analytics) |

---

## 4. `ReferralClaimPolicy` (`FE-CLM`)

The policy is a pure function of (pending, onboarding finished?, last attempt
time, now, server outcome).

| ID | Case | Expect |
|---|---|---|
| FE-CLM-01 | Pending present, onboarding just finished | `shouldClaim == true` |
| FE-CLM-02 | Pending present, onboarding **not** finished | `false` (never claim mid-onboarding) |
| FE-CLM-03 | No pending | `false` |
| FE-CLM-04 | Pending present, onboarding finished on an earlier launch (an earlier attempt got `retry_later`), app comes to the foreground | `true` |
| FE-CLM-05 | Last attempt less than 1 hour ago | `false` (no hammering on every foreground) |
| FE-CLM-06 | Pending expired | `false`, pending cleared |
| FE-CLM-07 | Outcome `credited` | `markFinal` |
| FE-CLM-08 | Outcome `rejected` (each reason in §7 except `disabled`, `invalid_code`, `unknown_code`) | `markFinal`. **No user-facing error** (the friend never asked for this). |
| FE-CLM-08b | Outcome `rejected` with `invalid_code` or `unknown_code` | Pending dropped, **not** final; a new code can be captured |
| FE-CLM-09 | Outcome `retry_later`, or `rejected` with reason `disabled` | Keep pending, record the attempt |
| FE-CLM-10 | Network error, timeout, `unavailable`, `unauthenticated`, `resource-exhausted` | Keep pending, record the attempt |
| FE-CLM-11 | Unknown outcome string from a newer server | Keep pending (fail safe, never drop a real friend) |
| FE-CLM-12 | iCloud-restored user (onboarding skipped) with a pending code | `false` (they aren't a new install). Pending cleared. |
| FE-CLM-13 | Debug replay of onboarding | `false` |

---

## 5. `ReferralEligibility` (`FE-ENT`, `FE-FLG`)

Inputs: `flagEnabled`, `hardPaywallFlag`, `isDebugReplay`, `converted`,
`hasFullAccess`, `autoShownBefore`, `pendingStandCode`, `referralStatus`.

### 5.1 Automatic page after onboarding

| ID | Case | Expect |
|---|---|---|
| FE-ENT-01 | Flag on, not converted, no full access, not shown before, no Stand code | **Show** |
| FE-ENT-02 | Converted (trial or purchase) | Don't show |
| FE-ENT-03 | Has full access through a Stand Pass | Don't show |
| FE-ENT-04 | Shown automatically before | Don't show |
| FE-ENT-05 | Stand code pending | Don't show (the Stand join sheet wins). **Not** marked as shown, so the referral page is still reachable from Profile. |
| FE-ENT-06 | Debug replay | Don't show |
| FE-ENT-07 | Flag off | Don't show |
| FE-ENT-08 | Already unlocked or redeemed (e.g. a reinstall with the same anonymous uid) | Don't show automatically |
| FE-ENT-09 | Welcome offer armed | Doesn't change the result (D5: they don't conflict) |

### 5.2 Profile rows

| ID | Case | Expect |
|---|---|---|
| FE-ENT-10 | Flag on, no record | "Get a year free" shown |
| FE-ENT-11 | Flag on, active or unlocked | Shown |
| FE-ENT-12 | Redeemed (this device saw the page reach `redeemed`) | Hidden |
| FE-ENT-12b | Premium with an unredeemed reward (subscribed before unlocking, D7) | Shown (an earned reward is never hidden) |
| FE-ENT-13 | "Have an invite code?" within 14 days of first launch, no pending code, never claimed, onboarded | Shown |
| FE-ENT-14 | ...day 15, or pending present, or claimed, or not onboarded | Hidden |

### 5.3 Hard paywall link

| ID | Case | Expect |
|---|---|---|
| FE-ENT-15 | `referralOnHardPaywall` on, paywall is hard | Link shown |
| FE-ENT-16 | Flag off, or the paywall is soft | Hidden (soft paywalls rely on the automatic page) |
| FE-ENT-17 | Tapping the link | Opens the page on top. Closing the page **returns to the paywall** (it never finishes onboarding). |

### 5.4 Kill switch

| ID | Case | Expect |
|---|---|---|
| FE-FLG-01 | Flag switches off at runtime while the page is open | Page stays usable until closed. No new entry points appear. |
| FE-FLG-02 | Flag off, but an unlocked reward exists | Profile row still shows "Redeem my free year". **A reward someone earned is never hidden.** |
| FE-FLG-03 | Flag off | Links are still captured and claims still sent (the server decides, and a friend shouldn't be lost to a client flag) |

---

## 6. `ReferralPageReducer` (`FE-PAG`)

States: `loading`, `notEnrolled`, `enrolling`, `active(count,target,code)`,
`unlocked(reward)`, `unlockedPendingCode`, `redeemed`, `error(retryable)`.

| ID | From | Event | To |
|---|---|---|---|
| FE-PAG-01 | `loading` | snapshot = none | `notEnrolled` |
| FE-PAG-02 | `loading` | cached snapshot `active(4/10)` | `active(4/10)` immediately |
| FE-PAG-03 | `active(4/10)` from cache | server snapshot `active(6/10)` | `active(6/10)`, event `referral_progress_seen` emitted |
| FE-PAG-04 | `active(6/10)` | stale server snapshot `active(4/10)` | `active(4/10)` (**the server always wins**, even if lower, e.g. after a merge correction). No `progress_seen`. |
| FE-PAG-05 | `notEnrolled` | tap Invite | `enrolling` |
| FE-PAG-06 | `enrolling` | enroll succeeds | `active(0/10)`, then the share sheet opens |
| FE-PAG-07 | `enrolling` | enroll fails (network) | `error(retryable: true)`, share sheet not opened |
| FE-PAG-08 | `enrolling` | enroll fails with `failed-precondition` (server switch off) | `error(retryable: false)`, message "Not available right now" |
| FE-PAG-09 | `enrolling` | tap Invite again | Ignored (no double enroll, no double sheet) |
| FE-PAG-10 | `active(9/10)` | snapshot `unlocked(code)` | `unlocked(code)`, `referral_reward_unlocked` emitted **once**, even across relaunches |
| FE-PAG-11 | `active` | snapshot `unlocked_pending_code` | `unlockedPendingCode` |
| FE-PAG-12 | `unlockedPendingCode` | snapshot `unlocked(code)` | `unlocked(code)` |
| FE-PAG-13 | `unlocked` | `isPremium` turns true within 30 minutes of a redeem tap | `redeemed`, `referral_reward_redeemed` emitted |
| FE-PAG-14 | `unlocked` | `isPremium` already true when the page opens (they subscribed earlier, D7) | `unlocked`. Copy explains the free year applies at renewal. |
| FE-PAG-14b | `loading` | already premium, a past redeem tap, snapshot reload | Still `unlocked` (a tap is not a redemption) |
| FE-PAG-14c | `unlocked(alreadyPremium)` | `premiumChanged(true)` right after a tap | No change. Only not-premium → premium counts. |
| FE-PAG-14d | `unlocked` | redemption observed, then reload | `redeemed` is remembered across reloads |
| FE-PAG-15 | `unlocked` | tap "My code didn't work", reissue succeeds | `unlocked(newCode)` |
| FE-PAG-16 | `unlocked` | reissue returns `resource-exhausted` | `unlocked(oldCode)` plus the message "Contact support". Support email prefilled with the last 4 of the code. |
| FE-PAG-17 | any | snapshot with `count > target` (should be impossible) | Shown as `target/target`, no crash |
| FE-PAG-18 | any | snapshot with `target == 0` or missing | Treated as 5 (matches the server default) |
| FE-PAG-19 | `error(retryable)` | tap Retry | `enrolling` |

---

## 7. `ReferralSnapshot` decoding (`FE-SNP`)

| ID | Case | Expect |
|---|---|---|
| FE-SNP-01 | Full server document | Decoded |
| FE-SNP-02 | Missing `reward` | `reward == nil` |
| FE-SNP-03 | Unknown `status` string | `.active` (fail safe: keep showing progress) |
| FE-SNP-04 | Extra unknown fields | Ignored |
| FE-SNP-05 | Round trip to the UserDefaults cache and back | Equal |
| FE-SNP-06 | Corrupt cache | `nil`, no crash |

---

## 8. `ReferralViewModel` with fakes (`FE-VM`)

Fakes: `FakeReferralService`, `FakeDeviceTokenProvider`, `SpyAnalytics`,
`InMemoryKeyValueStore`, `FakeAuth` (wraps `ensureAccount`), `FakeShareSheet`.

| ID | Case | Expect |
|---|---|---|
| FE-VM-01 | Tap Invite with no Firebase user | `ensureAccount` called **before** `getOrCreate`, once |
| FE-VM-02 | Tap Invite | `getOrCreate` gets the device token. If the token provider fails, the call still goes out without it (BE-ENR-08). |
| FE-VM-03 | Enroll succeeds | Share sheet presented with an image, text containing `https://<domain>/r/<code>`, and **exactly one** link |
| FE-VM-04 | Share sheet completes with `completed == true` | `referral_share_completed` with `activity_type` |
| FE-VM-05 | Share sheet cancelled | No `share_completed` |
| FE-VM-06 | Page shown from each entry point | `referral_page_shown` with the right `entry` |
| FE-VM-07 | "Not now" | `referral_page_dismissed`, the auto-shown flag set, `onDismiss` called |
| FE-VM-08 | Redeem tap | Opens `https://apps.apple.com/redeem?ctx=offercodes&id=1617492998&code=<CODE>` (assert the exact URL). If `open` returns false, the code is copied and RevenueCat's code redemption sheet opens instead. |
| FE-VM-09 | Server snapshot arrives | Cache written |
| FE-VM-10 | Claim on onboarding finish (friend side) | `claim` called with code, `capturedAt`, `source`, token. `referral_claim_result` tracked with `attempt`. |
| FE-VM-11 | Claim with no Firebase user | `ensureAccount` first (friends are usually brand new) |
| FE-VM-12 | Claim throws | Pending kept, no UI shown, analytics `outcome: "error"` |
| FE-VM-13 | Analytics properties | Never contain the referral code, a reward code or a uid. Asserted across every event the spy recorded. |
| FE-VM-14 | `onboarding_finished` | Includes `referral_pending` true or false |

---

## 9. Link capture wiring (`FE-CAP`)

These are app-target tests of the small entry functions. Pull the body of each
`onOpenURL` branch and `BranchAttribution.apply` branch into a static function
that takes its dependencies, the same way `attribution(from:)` already works.

| ID | Case | Expect |
|---|---|---|
| FE-CAP-01 | Deferred Branch parameters with `/r/CODE`, not onboarded | Pending captured, `source: deferred`, `referral_link_opened` with `outcome: captured` |
| FE-CAP-02 | `onOpenURL` with `/r/CODE`, not onboarded | Captured, `source: universal_link` |
| FE-CAP-03 | `onOpenURL` with `/r/CODE`, **already onboarded** | Not captured, `outcome: existing_user` |
| FE-CAP-04 | `onOpenURL` with `/stand/CODE` | Stand path only, no referral capture |
| FE-CAP-05 | Referral link carrying `ob=warfare` | Both the arm and the referral handled (they're independent) |
| FE-CAP-06 | Manual code entry with a valid code | Captured with `source: manual`, and the claim fires immediately (they're already onboarded) |
| FE-CAP-07 | Manual entry with an invalid code | Inline error, nothing captured, the button stays usable |
| FE-CAP-07b | Manual entry with a well-formed code the server doesn't know (a typo) | Inline "We couldn't find that code", nothing made final, the corrected code is credited |
| FE-CAP-08 | `BranchAttribution.attribution(from:)` with a `/r/` referring link | `channel == .referral` (add to `AcquisitionAttributionTests`) |
| FE-CAP-09 | Same, with `~channel` set to an ad network | The ad network wins (existing priority unchanged) |

---

## 10. Presentation order (`FE-ORD`)

Decided by a pure `PostOnboardingPresenter.next(...)` in Core. Add the welcome
offer and the Stand join to it, rather than leaving the order to whichever
modifier happens to fire first.

| ID | Pending | Expect |
|---|---|---|
| FE-ORD-01 | Stand code + referral eligible | Stand join only |
| FE-ORD-02 | Referral eligible only | Referral page |
| FE-ORD-03 | Referral page dismissed, then the first Daily Burst finishes | Welcome offer can show (D5) |
| FE-ORD-04 | Referral page **open** when the welcome offer would arm | Welcome offer waits until the page is closed. Never two covers at once. |
| FE-ORD-05 | Personal declaration prompt pending | Referral page first, prompt afterwards |

---

## 10b. Journeys and contracts (`FE-JRN`, `FE-CON`)

The app half of BE-JRN / BE-CON. See the backend plan §12b for why these exist.

| ID | Journey / contract |
|---|---|
| FE-JRN-01 | Friend: deferred link before onboarding → no claim during onboarding → first claim with no token gets retry_later and stays pending → foreground 10 min later is throttled → an hour later credited and final. Asserts `capturedAt` is the first-launch time, not the claim time. |
| FE-CON-01 | The server's push payload (`referral_push_fixture.json`, asserted server-side by BE-CON-01) is recognised by `ReferralPush.isReferral`, which the notification handler routes on |
| FE-CON-02 | Other pushes are not referral pushes |
| FE-CLM-14 | Reaching the onboarding paywall claims (D1), stamps `onboardedAt`, and a later `finishOnboarding()` claim is a no-op |
| FE-CLM-15 | The paywall during a debug replay never claims |
| FE-CLM-16 | The paywall with no pending referral does nothing (no account minted) |
| FE-PND-11..14 | Window is capture→onboarding; 30-day claim grace after; `markOnboarded` stamps once |
| FE-PAG-14e/f | Redemption inferred on reload (not premium at the tap, premium now), event fires once; never inferred for someone premium at the tap |

## 11. Device QA matrix (manual, before release)

**Resetting a test phone.** DeviceCheck bits survive deleting the app and erasing
the phone, so each phone can be counted once until it is reset. Debug panel →
Referral QA shows the phone's Firebase uid and DeviceCheck token (copy buttons).
Then: `node functions/scripts/resetReferralTestDevice.js --confirm-qa --token <token> --uid <uid>`
(add `--development` for an Xcode debug build, `--referrer <uid>` to restart a
referrer at 0, `--dry-run` to look first). Reset a phone after FE-QA-04 and
before reusing it as a friend.

Things only a real device or sandbox can prove. Each row is run and initialled
on the release ticket. Use a TestFlight build with the flag on through the
Remote Config debug override.

| ID | Scenario | Pass when |
|---|---|---|
| FE-QA-01 | Phone A finishes onboarding and closes the paywall | Referral page appears once. Doesn't reappear on relaunch. |
| FE-QA-02 | A shares to Messages; phone B (no app) taps the link | Safari, then the App Store, install, onboarding normal, no referral UI on B |
| FE-QA-03 | B finishes onboarding | A gets a push "1 of 5" within a minute. A's page shows 1/5. |
| FE-QA-04 | B deletes and reinstalls, taps the link again, finishes onboarding | A stays at 1 |
| FE-QA-05 | Phone C already has SpeakLife and taps A's link | App opens, nothing counted |
| FE-QA-06 | B's link capture fails (install without the link), then B uses "Have an invite code?" | Counted |
| FE-QA-07 | Sandbox: A reaches 10 (target set to 2 in the server config for QA; production default is 5), redeems | Apple sheet prefilled. After confirming, Premium on within a minute, RevenueCat shows the `premium` entitlement with a year's expiry. Repeat on a sandbox account that's **already subscribed** (D7) and record what Apple does. |
| FE-QA-08 | Redeem the same code on a second Apple ID | Apple refuses. "My code didn't work" gives a new code once. |
| FE-QA-09 | Airplane mode on A, open the page | Cached progress shown, Invite shows a retryable error |
| FE-QA-10 | A signs in with Apple on the Prayer Wall after 1 credit | Progress kept (merge) |
| FE-QA-11 | Server switch off | Invite gives "Not available right now". An existing unlocked reward is still redeemable. |
| FE-QA-12 | Hard paywall with `referralOnHardPaywall` on | Link visible. Page opens over the paywall. Closing returns to the paywall. |
| FE-QA-12b | Referred friend reaches a HARD paywall and does not pay | Referrer's count goes up (D1: counted at the paywall) |
| FE-QA-13 | Each onboarding arm (product, identity, quiz, closer, direct, storm, and one angle arm) | Page appears after a decline in each. Storm's objection flow finishes first. |
| FE-QA-14 | VoiceOver and Dynamic Type at the largest size | All text readable, buttons reachable, progress announced as "2 of 5 friends joined" |
| FE-QA-15 | Stand invite link and referral page at once | Stand join first. Referral page still in Profile. |

---

## 12. Done checklist (iOS)

- [ ] Every FE row has a test that failed first. QA rows signed off.
- [ ] `SpeakLifeCoreTests` and `SpeakLifeTests` green in CI.
- [ ] No referral branching inside a SwiftUI `body` beyond `switch state`.
- [ ] The shared code fixture is read by both the client and server tests.
- [ ] `referralYearFreeEnabled` defaults to `false` in `AppDelegate`'s Remote Config defaults.
- [ ] No referral code, reward code or uid in any analytics event (FE-VM-13).
- [ ] New Swift files added to the Xcode target (`add_swift_files.sh`) and the package.
