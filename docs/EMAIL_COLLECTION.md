# Email Collection

How SpeakLife collects email addresses during onboarding, where they go, and
what to do when something looks wrong.

---

## Why it exists

The paywall is hard, and most people who reach it do not subscribe. Without an
address those people are unreachable the moment they close the app — no
follow-up, no welcome sequence, no second chance. The email ask exists to turn
that majority into a list we own.

That single fact decides most of the design below: the ask runs **before** the
paywall, and the address is stored in **our** database first and Klaviyo second.

---

## The flow

```
  review wall  →  EMAIL ASK  →  paywall  →  notification time
```

One screen, `EmailCaptureScreen`, inserted in all six onboarding drivers
(`quiz`, `product`, `identity`, `closer`, `direct`, and `AngleOnboardingView`,
which renders all 18 angle arms). It is skippable, and the skip is visible.

```
 app                     Cloud Function                  storage
 ───                     ──────────────                  ───────
 EmailCaptureScreen
   └─ EmailCaptureService
        └── POST ───────► collectEmail
                            ├─ validate + normalize
                            ├─ write ─────────────────►  Firestore
                            │                            emailSubscribers/{sha256}
                            └─ subscribe ─────────────►  Klaviyo list
                                 (best effort)
                                                          ▲
                            retryKlaviyoSync (hourly) ────┘
```

---

## Design decisions worth keeping

**Pre-paywall, not post.** Asking after the paywall would collect addresses only
from people who subscribed — who we can already reach. The value is in the
people who say no.

**Skippable.** A hard gate one screen before a hard paywall stacks two walls in
a row. The skip costs some addresses and protects the trial starts, which is the
right way round. Every address is worth something; a lost subscription is worth
more.

**The client never blocks on the network.** Tapping continue advances the flow
immediately and the send runs behind it. A fresh install on a weak connection is
exactly when this fails, and a spinner or an error alert there would cost a
conversion to save an address.

**A failed send is not a lost address.** Anything that does not reach the server
is queued in `UserDefaults` and retried on the next launch, so it survives the
app being killed. A 4xx clears the queue (the server will never accept that
payload); a 5xx or a transport error stays queued.

**Firestore is the source of truth, Klaviyo is a projection.** The address is
ours the moment the write lands. A Klaviyo outage, a rotated key, or a decision
to move to another ESP costs nothing. Klaviyo failing **never** fails the
request — the doc is marked `pending` and the hourly sweep picks it up.

**The step is never renumbered.** `<flow>_step_completed` reports an integer
`step`, and the live A/B funnels are read against it. In the five raw-value
arms, `.email` is **appended** at the end of the enum and reached by an explicit
hop in `advance()`; in the angle arms the index does shift, so every angle's
`flowSchema` was bumped. See "Analytics" below.

---

## Configuration

Two secrets, both server-side. The Klaviyo private key is never in the app
binary — that is the reason the Cloud Function exists rather than the client
calling Klaviyo directly.

```bash
firebase functions:secrets:set KLAVIYO_API_KEY    # private key, pk_...
firebase functions:secrets:set KLAVIYO_LIST_ID    # e.g. WaeTSA ("Email List")
firebase deploy --only functions:collectEmail,functions:retryKlaviyoSync
firebase deploy --only firestore:rules,firestore:indexes
```

Until both secrets are set the function still works: addresses are stored in
Firestore and marked `pending`, and the sweep subscribes them once the secrets
land. Nothing is lost by deploying the app before configuring Klaviyo.

**Remote Config kill switch:** `emailCaptureEnabled` (default `true`). Set it to
`false` and every flow skips the step, advancing straight to the paywall. This
is the switch to reach for if trial starts dip after the ask ships.

---

## Data

`emailSubscribers/{sha256(email)}` — server-only, closed to clients in both
directions (see `firestore.rules`). The document id is a hash rather than the
address itself so that ids in logs, console URLs and stack traces carry no
personal data, and so a local part containing `/` or `..` cannot break
`.doc()`.

| Field | Meaning |
|---|---|
| `email` | normalized: trimmed, lowercased |
| `appUserId` | RevenueCat id, to line the address up with subscription state |
| `source` | where the ask happened, e.g. `onboarding` |
| `variant` | onboarding arm, so list segments match funnel segments |
| `burden` | the area the user picked, for segmented sends |
| `createdAt` | first submission only |
| `updatedAt` | every submission |
| `klaviyoStatus` | `synced` or `pending` |
| `klaviyoError` | last failure, while pending |
| `klaviyoSyncedAt` | when the subscribe succeeded |
| `retryCount` | sweep attempts, capped at 10 |

The Klaviyo profile carries `speaklife_source`, `speaklife_onboarding_variant`
and `speaklife_burden` so segments there line up with the funnels in PostHog.

### Consent

The screen states plainly what the address is for and that it can be
unsubscribed in one tap, so the profile is subscribed with
`consent: "SUBSCRIBED"` and `historical_import: false` — a real, current opt-in.
`historical_import: true` would import it as backdated history and silently skip
the welcome flow, which is most of the reason for collecting it.

If the screen's copy ever changes to stop describing what gets sent, the consent
value has to be revisited with it.

---

## Analytics

| Event | When |
|---|---|
| `email_capture_shown` | screen appears |
| `email_capture_submitted` | valid address, user tapped continue |
| `email_capture_skipped` | user tapped "Not right now" |
| `email_capture_delivered` | server accepted it (may be a later launch) |
| `email_capture_rejected` | server refused it, 4xx — not retried |
| `email_capture_deferred` | send failed, still queued |

`submitted` minus `delivered` is the queue; a persistent gap means the function
is unreachable, not that users are dropping off.

**Flow schema bumps.** A screen now stands between the review wall and the
paywall in every arm, so paywall drop-off is not comparable across the boundary.
Split on `flow_schema` when reading any funnel that spans this release:

| Arm | Before | After |
|---|---|---|
| angle arms (all 18) | *n* | *n* + 1 |
| `product` | 3 | 4 |
| `identity` | 2 | 3 |
| `closer` | 2 | 3 |
| `direct` | 7 | 8 |

`quiz` has no raw step values and emits no `flow_schema`.

Read `docs/ANALYTICS_DATA_QUALITY.md` before drawing conclusions from any of
these numbers.

---

## Troubleshooting

**Addresses in Firestore, nothing in Klaviyo.** Check `klaviyoStatus`. If docs
are `pending` with a `klaviyoError` of `401`, the private key is wrong or unset;
`404` means the list id does not exist. Fix the secret and the hourly sweep
drains the backlog on its own.

**`retryCount` stuck at 10.** The sweep gave up, which it only does after ~10
hours of failing. The cause is structural — bad key, deleted list. Fix it, then
reset the counter on the affected docs to let the sweep pick them up again.

**A user says they never got anything.** Confirm the doc exists
(`sha256` of their lowercased address is the id), check `klaviyoStatus`, then
check the profile's consent in Klaviyo — a profile can exist and be
unsubscribed, which is not the same as missing.

**The step never appears.** Either `emailCaptureEnabled` is false in Remote
Config, or `EmailCaptureService.hasCapturedEmail` is already true on that
install — the flow deliberately never asks twice.

---

## Tests

`functions/test/emailCapture.test.js` — 21 tests, no emulator needed, run in CI
on Linux (`npm run test:email`). They cover validation, normalization, doc ids,
and the Klaviyo request shape, which is where the quiet failures live: a missing
consent block produces a profile that exists, looks fine, and never receives
mail.

`SpeakLife/SpeakLifeTests/OnboardingAngleTests.swift` asserts the step indices
for every angle arm, and that the email ask sits immediately before the paywall
in all of them.
