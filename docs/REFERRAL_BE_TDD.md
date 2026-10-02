# Referral (Year Free) — Backend TDD Plan

Spec: `docs/REFERRAL_YEAR_FREE_SPEC.md`. Section numbers like §7 refer to it.

**How to use this doc.** Every row below becomes a test **before** the code it
covers exists. Write a group's tests, watch them fail for the right reason,
then write just enough of `functions/referral.js` to turn them green. A row is
done when its test passes and has failed once first. Nothing ships with a row
unimplemented. Skipping a row needs a written reason here.

---

## 1. Harness

Follow `functions/test/standTogether.test.js` exactly. Don't invent a second
pattern.

| Item | Decision |
|---|---|
| Runner | `node:test` + `node:assert` |
| Firestore | Emulator through `firebase emulators:exec` |
| New files | `functions/test/referral.test.js` (functions), with new rules cases added to `functions/test/rules.test.js` |
| npm script | `"test:referral": "cd .. && firebase emulators:exec --only firestore --project speaklife-fn-test \"node functions/test/referral.test.js\""`, added to `npm test` |
| FCM | Stub `getMessaging()` before the module loads (same code as the Stand tests). Assert on the `sent[]` array. |
| DeviceCheck | Injected verifier: `H.setDeviceCheck(fake)`. The fake keeps a `Map<token, {bit0, bit1}>` and can be told to throw (Apple down). Production uses the real Apple client, constructed lazily so tests never need the key. |
| Clock | `H.setNow(fn)`, which every function in `referral.js` reads instead of `Date.now()` directly. Windows and caps are tested by moving the clock, never by sleeping. |
| Config | `beforeEach` writes `referralConfig/current = { enabled: true, target: 10, windowDays: 14, dailyCap: 5, minCodeValidityDays: 30 }`. Tests that need something else overwrite it. |
| Wipe | `beforeEach` clears `referrals` (including `credits`), `referralCodes`, `referralClaims`, `referralRewardCodes`, `referralConfig`, `referralRateLimits`, `users`, and resets `sent` and the fake DeviceCheck. |
| Helpers | `req(uid, data)`, `expectCode(fn, code)`, already in the Stand tests and copied over. Plus new ones: `enroll(uid)`, `claim(friendUid, code, overrides)`, `seedPool(n, {expiresInDays})`, `creditN(referrerCode, n)`, which generates `n` distinct friends and devices. |

**Determinism rule:** no test depends on wall-clock time, test order or random
values it doesn't control. Codes come from `generateCode`, and any test that
needs a collision stubs it through `H.setCodeGenerator`.

---

## 2. Pure helpers (`H.*`, no emulator)

| ID | Case | Expect |
|---|---|---|
| BE-HLP-01 | `generateCode` over 20,000 draws | Length 8, only alphabet characters, no collisions, every character within 20% of even (same test as Stand) |
| BE-HLP-02 | `normalizeCode('k7mq-2xpa')` | `'K7MQ2XPA'` |
| BE-HLP-03 | `normalizeCode` with `0`, `O`, `1`, `I`, `L`, 7 characters, 9 characters, `null`, a number, `''` | `null` for each |
| BE-HLP-04 | `normalizeCode` with spaces, dashes and unicode separators | Stripped, then validated |
| BE-HLP-05 | `validateCapturedAt(capturedAt, accountCreatedAt, now, windowDays)` within the window | ok |
| BE-HLP-06 | ...exactly at the window edge (14d 0s) | ok (inclusive) |
| BE-HLP-07 | ...14 days plus 1 second | `expired` |
| BE-HLP-08 | ...`capturedAt` in the future, beyond 5 minutes of clock skew | `expired` |
| BE-HLP-09 | ...`capturedAt` more than 5 minutes before the friend's account was created | `expired` (a link captured on a previous install doesn't carry over) |
| BE-HLP-10 | ...`capturedAt` missing, not a number, or NaN | `invalid_argument` |
| BE-HLP-11 | `pickRewardCode(pool, now, minValidityDays)` | Soonest-expiring code that's still valid for at least `minValidityDays` |
| BE-HLP-12 | `pickRewardCode` when every code expires within `minValidityDays` | `null` |
| BE-HLP-13 | `pickRewardCode` skips codes that are already assigned | ✓ |
| BE-HLP-14 | `readConfig` when the document is missing | Defaults with `enabled: false` |
| BE-HLP-15 | `readConfig` with a partial document | Missing fields get defaults. A non-integer `target` or a target below 1 falls back to 10. |
| BE-HLP-16 | `mergeReferrals(a, b)` as a pure function | See the BE-MRG table, run on plain objects first |

---

## 3. Config and kill switch (`BE-CFG`)

| ID | Case | Expect |
|---|---|---|
| BE-CFG-01 | `enabled: false`, no existing record, `getOrCreateReferral` | `failed-precondition`, nothing written |
| BE-CFG-02 | `enabled: false`, existing record | Record returned unchanged |
| BE-CFG-03 | `enabled: false`, `claimReferral` | `{outcome:'rejected', reason:'disabled'}`, **no** `referralClaims` document written (the claim isn't final, so it could still count if the switch comes back on within the window) |
| BE-CFG-04 | `enabled: false`, unlocked referrer reads their record | Reward visible |
| BE-CFG-05 | Config target changed from 10 to 5 after enrollment | Existing referrer stays at 10. A new enrollment gets 5. |

---

## 4. Enrollment: `getOrCreateReferral` (`BE-ENR`)

| ID | Case | Expect |
|---|---|---|
| BE-ENR-01 | No auth | `unauthenticated` |
| BE-ENR-02 | First call | Returns `{code, count:0, target:10, status:'active', reward:null}`. `referrals/{uid}` and `referralCodes/{code}` both exist and point at each other. |
| BE-ENR-03 | Second call | Same code, no new `referralCodes` document (count the collection) |
| BE-ENR-04 | Two calls at once for the same uid (`Promise.all`) | Exactly one code exists, and both responses return it |
| BE-ENR-05 | Code collision: the generator stubbed to return an existing code once, then a fresh one | Second code used, the first referrer's mapping untouched |
| BE-ENR-06 | Generator always collides | Gives up after 5 attempts with `internal`, nothing partially written |
| BE-ENR-07 | With `deviceToken` | Fake DeviceCheck bit 1 set for that token |
| BE-ENR-08 | Without `deviceToken` | Enrolls. DeviceCheck not called. A warning is logged. |
| BE-ENR-09 | DeviceCheck throws during enrollment | Still enrolls (bit failures never block a referrer). The retry is queued for the sweep. |
| BE-ENR-10 | 21st call in an hour | `resource-exhausted` |
| BE-ENR-11 | The response contains no friend uids and no credits | Only the fields listed |
| BE-ENR-12 | Anonymous auth uid | Allowed (referrers are usually anonymous) |

---

## 5. Claims: `claimReferral` (`BE-CLM`)

Each row runs against a fresh referrer `R` with code `C`, unless stated
otherwise. "Final" means a `referralClaims/{friendUid}` document is written.

### 5.1 Happy path

| ID | Case | Expect |
|---|---|---|
| BE-CLM-01 | Valid claim | `credited`. R's count goes 0 → 1. Credit document exists with the right `source`. Claim final with `outcome:'credited'`. DeviceCheck bit 0 set. One push to R. |
| BE-CLM-02 | Each `source` value (`deferred`, `universal_link`, `manual`) | Stored as sent. Any other value → `invalid-argument`. |
| BE-CLM-03 | Code sent in lower case with a dash | Normalised and credited |

### 5.2 Exactly once

| ID | Case | Expect |
|---|---|---|
| BE-CLM-04 | Same friend claims the same code twice | Second call returns `credited` (the original outcome), count stays 1, one push in total |
| BE-CLM-05 | Same friend, different referrer's code | Returns the **first** outcome. R2's count unchanged. |
| BE-CLM-06 | Same friend, 5 identical claims at once | Count is 1, one credit, one push |
| BE-CLM-07 | Friend rejected first (e.g. `self_referral`) then tries again with a valid code | Still rejected (claims are final) |

### 5.3 Rejections (each one: correct reason, count unchanged, no push)

| ID | Case | Reason | Final? |
|---|---|---|---|
| BE-CLM-08 | Captured 15 days ago | `expired` | yes |
| BE-CLM-09 | Friend uid == R | `self_referral` | yes |
| BE-CLM-10 | R already at target | `target_reached` | yes |
| BE-CLM-12 | Malformed code | `invalid_code` | yes |
| BE-CLM-13 | Unknown code | `unknown_code` | yes |
| BE-CLM-14 | Revoked code (R deleted their account) | `unknown_code` | yes |
| BE-CLM-15 | Device bit 0 already set | `device_already_counted` | yes |
| BE-CLM-16 | Device bit 1 set (this device enrolled as a referrer) | `device_is_referrer` | yes |
| BE-CLM-17 | No `deviceToken` | `device_unverifiable` | yes |
| BE-CLM-18 | DeviceCheck rejects the token as invalid | `device_unverifiable` | yes |
| BE-CLM-19 | No auth | Error `unauthenticated` | no |
| BE-CLM-20 | 11th claim call in an hour from one friend | Error `resource-exhausted`, checked **before** the code lookup (no free enumeration) | no |

### 5.4 Retry later (not final, so the client keeps the pending claim)

| ID | Case | Expect |
|---|---|---|
| BE-CLM-11 | R already credited 5 in the last 24h | `retry_later`, no claim document. After advancing the clock 24h, the same claim is credited. |
| BE-CLM-21 | DeviceCheck throws (Apple down) | `retry_later`, nothing written. A retry after recovery is credited. |
| BE-CLM-22 | Velocity window is rolling: 5 credits at t=0, the clock moved to t=23h59m | Still `retry_later`. At t=24h00m01s it's credited. |

### 5.5 Order of checks

| ID | Case | Expect |
|---|---|---|
| BE-CLM-23 | Expired **and** self-referral | `self_referral` (§7 order: #7 comes before #8) |
| BE-CLM-24 | Unknown code **and** device already counted | `unknown_code`, and DeviceCheck **not called** (no Apple traffic for junk codes) |
| BE-CLM-25 | Kill switch off **and** everything else invalid | `disabled` |

### 5.6 Side effects after commit

| ID | Case | Expect |
|---|---|---|
| BE-CLM-26 | Setting bit 0 fails after the credit is written | Claim still returns `credited`. Retry queued. The sweep sets the bit later (BE-SWP-03). |
| BE-CLM-27 | R has no `fcmToken` | Credited, no push, no error |
| BE-CLM-28 | FCM send throws | Credited, error logged, not passed back to the friend |
| BE-CLM-29 | Push body | Contains the count and target ("4 of 10"), no friend data |

---

## 6. Unlocking and rewards (`BE-RWD`)

| ID | Case | Expect |
|---|---|---|
| BE-RWD-01 | 10th credit with the pool seeded | In the **same transaction**: `status:'unlocked'`, `unlockedAt` set, `reward.code` assigned, the pool document has `assignedTo: R`. One "credit" push and one "unlocked" push (or one combined; pick one and assert it). |
| BE-RWD-02 | 9th credit | No reward, status `active` |
| BE-RWD-03 | 10th credit with the pool empty | `status:'unlocked_pending_code'`, `reward: null`, the claim still `credited` |
| BE-RWD-04 | 10th credit when only codes expiring within 30 days remain | Same as BE-RWD-03 |
| BE-RWD-05 | Two referrers hit their 10th credit at once, pool holds **one** code | One gets the code, the other gets `unlocked_pending_code`. The code is never assigned twice. |
| BE-RWD-06 | R's `users` document shows a premium subscriber (D7) | Still unlocked and assigned |
| BE-RWD-07 | 11th claim after unlocking | `target_reached` (BE-CLM-10). The reward isn't changed. |
| BE-RWD-08 | `reissueReferralReward` while unlocked | New code. The old code marked `retired: true` and never assigned again. `reissueCount: 1`. |
| BE-RWD-09 | Second `reissueReferralReward` | `resource-exhausted`, reward unchanged |
| BE-RWD-10 | `reissueReferralReward` while not unlocked | `failed-precondition` |
| BE-RWD-11 | `reissueReferralReward` with the pool empty | `unavailable`, reward unchanged, `reissueCount` unchanged |
| BE-RWD-12 | Pool selection | Soonest-expiring valid code chosen (end-to-end version of BE-HLP-11) |

---

## 7. Scheduled sweep: `referralSweep` (`BE-SWP`)

Run the handler directly (`fns.referralSweep.run()`).

| ID | Case | Expect |
|---|---|---|
| BE-SWP-01 | Three `unlocked_pending_code` referrers, pool refilled with 2 | The two oldest unlocks get codes and pushes. The third stays pending. |
| BE-SWP-02 | Sweep run twice | Second run assigns nothing new, sends no duplicate pushes |
| BE-SWP-03 | Bit 0 update queued after BE-CLM-26 | Bit set, queue entry removed |
| BE-SWP-04 | Pool has 99 valid codes | Logs a `REFERRAL_POOL_LOW` warning with the count |
| BE-SWP-05 | Pool has 100 valid codes | No warning |
| BE-SWP-06 | One bad referrer document (missing fields) | Logged and skipped. The rest of the batch still runs. |

---

## 8. Account merge (changes to `completeAccountMerge`) (`BE-MRG`)

Anonymous uid `A` merging into Apple uid `P`. Every row is also run twice to
prove the merge is idempotent.

| ID | Case | Expect |
|---|---|---|
| BE-MRG-01 | Only A has a referral | Record moved to P, `referralCodes/{code}.uid == P`, credits moved, A's record gone |
| BE-MRG-02 | Only P has one | Unchanged |
| BE-MRG-03 | Both have one, with credit sets {f1,f2} and {f2,f3} | P's count is 3 (union, not 4). The code with more credits kept, the other revoked. |
| BE-MRG-04 | Both have one, and the union reaches the target | Unlocked and a code assigned during the merge |
| BE-MRG-05 | A unlocked with a reward, P active | P is unlocked with A's reward |
| BE-MRG-06 | Both have rewards | Earlier one kept. The other goes back to the pool only if assigned less than 24h ago, otherwise it's retired. |
| BE-MRG-07 | Different targets (10 and 5) | Lower one kept |
| BE-MRG-08 | A friend claim using A's old code after the merge | Credited to P |
| BE-MRG-09 | Merge with neither having a referral | No referral documents created |
| BE-MRG-10 | Existing Stand merge tests | Still pass, unchanged |

---

## 9. Account deletion (changes to `deleteAccount`) (`BE-DEL`)

| ID | Case | Expect |
|---|---|---|
| BE-DEL-01 | Referrer deletes their account | `referrals/{uid}` and credits deleted, the code revoked |
| BE-DEL-02 | A friend claims with the deleted referrer's code | `unknown_code` |
| BE-DEL-03 | A friend deletes their account | Their `referralClaims` document remains (it stops reinstall farming). The referrer's count unchanged. |
| BE-DEL-04 | Unlocked referrer with an assigned, unredeemed code deletes their account | Code retired, not returned to the pool (it may already have been redeemed) |
| BE-DEL-05 | Existing Stand deletion tests | Still pass |

---

## 10. Firestore rules (added to `functions/test/rules.test.js`) (`BE-RUL`)

Use `@firebase/rules-unit-testing`, as the file already does. Run each case for
both an **anonymous** and an **Apple** signed-in user.

| ID | Case | Expect |
|---|---|---|
| BE-RUL-01 | Owner reads `referrals/{own}` | allowed |
| BE-RUL-02 | Owner reads `referrals/{other}` | denied |
| BE-RUL-03 | Signed-out user reads `referrals/{any}` | denied |
| BE-RUL-04 | Owner writes, updates or deletes `referrals/{own}`, including only `count` | denied |
| BE-RUL-05 | Owner reads `referrals/{own}/credits/*` | denied |
| BE-RUL-06 | Anyone reads or writes `referralCodes/*` | denied |
| BE-RUL-07 | Anyone reads or writes `referralClaims/*` | denied |
| BE-RUL-08 | Anyone reads or writes `referralRewardCodes/*` | denied (**the most important rule in this feature**: a readable pool hands out free years) |
| BE-RUL-09 | Anyone reads or writes `referralConfig/*`, `referralRateLimits/*` | denied |
| BE-RUL-10 | A `list` query on `referralRewardCodes` | denied |
| BE-RUL-11 | Existing `users/{uid}` rules | unchanged, still pass |

---

## 11. Offer code import script (`functions/scripts/importOfferCodes.js`) (`BE-IMP`)

Pure parsing is tested without the emulator. The write path is tested against
it.

| ID | Case | Expect |
|---|---|---|
| BE-IMP-01 | App Store Connect CSV with a header row | Header skipped, codes imported |
| BE-IMP-02 | Windows line endings, trailing blank lines, surrounding whitespace | Handled |
| BE-IMP-03 | Duplicate code within the file | Imported once, reported |
| BE-IMP-04 | Re-running the same file | 0 new, N skipped. **Assigned codes untouched.** |
| BE-IMP-05 | `--expires` missing or in the past | Exits non-zero, writes nothing |
| BE-IMP-06 | `--batch` missing | Exits non-zero |
| BE-IMP-07 | A row with an empty or obviously malformed code | Rejected and reported, the rest imported |
| BE-IMP-08 | More than 500 codes | Batched writes (Firestore limit), all imported |
| BE-IMP-09 | `--dry-run` | Prints counts, writes nothing |
| BE-IMP-10 | The script never prints full codes, only counts and the last 4 characters | Assert on captured stdout |

---

## 12. End-to-end scenarios (`BE-E2E`)

Long-form tests that stitch the pieces together. These catch the bugs that
unit-level rows miss.

| ID | Scenario |
|---|---|
| BE-E2E-01 | R enrolls, 10 distinct friends claim over 3 simulated days (velocity cap respected: 5, 5), R unlocks, reads the record and sees the code, an 11th friend gets `target_reached`. |
| BE-E2E-02 | A farm: one device token used for 10 different friend uids. Exactly one is credited, nine get `device_already_counted`. |
| BE-E2E-03 | Self-farm: R's own device token (bit 1) used by 10 new uids. Zero credited. |
| BE-E2E-04 | R enrolls anonymously, gets 6 credits, signs in with Apple (merge), gets 4 more. Unlocks under P. |
| BE-E2E-05 | Pool empty at unlock, import adds codes, sweep runs, R gets the code and a push. |
| BE-E2E-06 | Kill switch off mid-campaign: claims rejected `disabled` (not final). Switch back on within the window, the same claims are credited. |

---

## 13. Done checklist (backend)

- [ ] Every row above has a test that failed before its code existed.
- [ ] `npm test` runs rules, Stand, referral and email suites, all green.
- [ ] `referral.js` has no direct `Date.now()` or `Math.random()` (grep for them in CI).
- [ ] `referralRewardCodes` is unreadable from a client (BE-RUL-08 green).
- [ ] The new DeviceCheck secret is declared with `defineSecret` and never logged.
- [ ] `index.js` exports the new functions.
- [ ] Deployed with `referralConfig/current.enabled = false` first.
