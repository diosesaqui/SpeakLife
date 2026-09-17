# Email Collection

How SpeakLife collects email addresses, where they go, and what to do when
something looks wrong.

---

## History (read this first)

Email collection is not new. It shipped on **2026-03-16**, ran until
**2026-06-12**, and was deleted on **2026-06-19** by commit `c605131f`
("Email collection is no longer needed"), which removed `EmailCaptureView`,
`EmailConfirmationView`, `DirectEmailCaptureView`, `EmailMarketingService`,
`EmailMarketingConfig`, `EmailConfig.plist` and every piece of wiring.

This document describes the restored system. Two things about the old one are
load-bearing context:

**1. The Klaviyo private key was in the app.** `EmailConfig.plist` carried
`pk_3d962d390e864808f15988adaa1ca212e8`, committed to git and extractable from
every shipped binary. A Klaviyo *private* key is full account access. **That key
must be treated as compromised and rotated**, independently of anything here.
It is the reason the Klaviyo call moved server-side rather than being restored
as it was.

**2. Consent was never recorded.** The old service created a profile with
`POST /api/profiles/` and then added it to the list via a relationship. That
writes list membership but never touches consent, so every profile collected
before June still reads `consent: NEVER_SUBSCRIBED` with a null
`consent_timestamp` and no `method`. They remain *mailable* — most carry
`can_receive_email_marketing: true`, and campaigns have demonstrably gone out —
but there is no consent record behind them. The restored path writes real
consent.

Existing records are not migrated or rewritten. See "Legacy records" below.

---

## Why it exists

The paywall is hard, and most people who reach it do not subscribe. Without an
address those people are unreachable the moment they close the app — no
follow-up, no welcome sequence, no second chance. The email ask exists to turn
that majority into a list we own.

That single fact decides most of the design below: the ask runs **before** the
paywall, and the address is stored in **our** database first and Klaviyo second.

---

## The three surfaces

| Surface | View | `source` | When |
|---|---|---|---|
| Onboarding, before the review wall | `EmailCaptureScreen` | `onboarding` | every install, skippable |
| Profile → Support | `EmailCaptureSheet` | `settings` | any time, also edits a stale address |
| After a purchase | `EmailCaptureSheet` | `post_purchase` | once per install, only if no address held |

```
  plan reveal  →  EMAIL ASK  →  review wall  →  paywall  →  notification time
```

The onboarding step is one screen inserted in all six drivers (`quiz`,
`product`, `identity`, `closer`, `direct`, and `AngleOnboardingView`, which
renders all 18 angle arms). It is skippable, and the skip is visible — which is
exactly why the Profile row matters: without it, every skip would be permanent.

A buyer whose address we already hold is **not** shown anything. The old build
raised a second `EmailConfirmationView` at them purely to re-tag the profile as
`post_purchase`; `EmailCaptureService.retagAsPostPurchase()` now does that
silently. Asking someone to re-confirm an address they never changed, seconds
after they paid, is friction spent on our own bookkeeping.

The `source` vocabulary (`ios_app_profile`, `settings`, `post_purchase`) is
carried over verbatim from the old system, because the Klaviyo profiles already
in the account are segmented by those exact strings.

```
 app                     Cloud Function                  storage
 ───                     ──────────────                  ───────
 EmailCaptureScreen
 EmailCaptureSheet
   └─ EmailCaptureService
        └── POST ───────► collectEmail
                            ├─ validate + normalize
                            ├─ write ─────────────────►  Firestore (speaklife db)
                            │                            email_list/{uid or email}
                            └─ subscribe ─────────────►  Klaviyo list
                                 (best effort)
                                                          ▲
                            retryKlaviyoSync (hourly) ────┘
```

---

## Design decisions worth keeping

**Pre-paywall, not post.** Measured over 90 days: 1,062 people reach the screen
where the ask sits, 1,050 see the paywall, and only 116 ever reach a screen
*after* it. The paywall is a real wall — about 89% of the people who see it
never get past it — so an ask placed after would address roughly a ninth of the
audience, and specifically the ninth we can already reach.

(A comment in `DirectOnboardingView` claims post-paywall screens are seen by
"everyone, because the paywall is hard and the flow continues through it either
way." The data disagrees; that comment predates the current
`showPayWhatYouCanLink` setting.)

**Before the review wall, not after it.** The wall is social proof placed
deliberately against the paywall, and 98.9% of the people who see it go on to
see the paywall — the tightest, cleanest stretch of the funnel. Putting a
keyboard in that gap spends the adjacency the wall exists for.

Reach is *not* a reason, despite an earlier version of this doc saying so. That
claim ("about 30% of the people who see the plan reveal never arrive at the
wall") came from a funnel spanning builds older than 4.42, which shipped no
review wall at all — their "drop-off" was a missing screen, not a leaving user.
Scoped to builds that have the wall, 894 people tap through the plan reveal and
890 reach the wall. The earlier slot gains four users. See
`docs/ANALYTICS_DATA_QUALITY.md` Rule 1.

**It might still cost trial starts, so measure it.** Roughly, the pre-paywall
slot reaches ~950 more people per 90 days than a post-paywall one; at a ~40%
submit rate that is ~380 addresses, against ~7.6 trials lost if the screen costs
5% of trial starts. That trade — about 50 addresses per trial — only pays off if
the list converts back at ~2% or better. **Do not ship this at 100%.** Run
`emailCaptureEnabled` as a Remote Config A/B and read `trial_started` across the
arms.

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
# Use a NEWLY ROTATED key. The one the app shipped with is compromised.
firebase functions:secrets:set KLAVIYO_API_KEY    # private key, pk_...
firebase functions:secrets:set KLAVIYO_LIST_ID    # WaeTSA ("Email List")

firebase deploy --only functions:collectEmail,functions:retryKlaviyoSync
firebase deploy --only firestore:speaklife     # rules + index for email_list
```

⚠️ **Before that last line.** `firestore.speaklife.rules` is the first
source-controlled rules file for the `speaklife` database; deploying it
**replaces** whatever the Firebase Console currently holds there, which nobody
has in version control. The old app wrote `email_list` directly from the
client, so those console rules almost certainly permit client writes. Check the
Console first. The new file denies all client access, which is correct now that
only the Cloud Function writes (the Admin SDK bypasses rules) — and no Swift
file in the app opens this database any more.

Until both secrets are set the function still works: addresses are stored in
Firestore and marked `pending`, and the sweep subscribes them once the secrets
land. Nothing is lost by deploying the app before configuring Klaviyo.

**Remote Config kill switch:** `emailCaptureEnabled` (default `true`). Set it to
`false` and every flow skips the step, going straight to the review wall. This
is also the A/B switch — see "It might still cost trial starts" above; prefer
running it as an experiment over shipping it to everyone.

---

## Data

`email_list/{docId}` in the **named `speaklife` database** — not the default
one. Server-only, closed to clients in both directions (see
`firestore.speaklife.rules`).

The document id is `userId ?? sanitizedEmail`, reproducing the legacy scheme
exactly: dots replaced with `_`, then `@` with `_at_`, so `me@example.com`
becomes `me_at_example_com`. A hash would be a better design in isolation, but
it would orphan every record written before June — a returning subscriber would
create a second document instead of updating their own, and every count drawn
from the collection would drift. Compatibility wins.

Fields marked *legacy* below keep their original names for the same reason: any
export or Klaviyo import built against this collection still works.

| Field | Meaning |
|---|---|
| `email` | *legacy* — normalized: trimmed, lowercased |
| `source` | *legacy* — `onboarding`, `settings`, `post_purchase`, `ios_app_profile` |
| `platform` | *legacy* — always `iOS` |
| `app_version` | *legacy* — `CFBundleShortVersionString` at submission |
| `user_id` | *legacy* — Firebase UID, when there is one |
| `first_name` | *legacy* — optional |
| `timestamp` | *legacy* — first submission only |
| `appUserId` | RevenueCat id, to line the address up with subscription state |
| `variant` | onboarding arm, so list segments match funnel segments |
| `burden` | the area the user picked, for segmented sends |
| `updatedAt` | every submission |
| `klaviyoStatus` | `synced` or `pending` |
| `klaviyoError` | last failure, while pending |
| `klaviyoSyncedAt` | when the subscribe succeeded |
| `retryCount` | sweep attempts, capped at 10 |

The Klaviyo profile carries `source`, `platform`, `app_version` and
`firebase_uid` (the property names the existing profiles already use, so
segments built on them keep working) plus the new
`speaklife_onboarding_variant` and `speaklife_burden`, so Klaviyo segments line
up with the funnels in PostHog.

### Legacy records

Records written before 2026-06-12 carry no `klaviyoStatus`, so the retry sweep's
query never matches them. That is deliberate: those profiles are already in
Klaviyo, and re-subscribing thousands of them would rewrite consent timestamps
to today and fire the welcome flow at people who joined months ago. If you ever
do want to backfill real consent onto them, that is a deliberate one-off
migration with its own decision about what the consent timestamp should say —
not something this sweep should do by accident.

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

**A user says they never got anything.** Find the doc — the id is their
Firebase UID if they have one, else their lowercased address with dots as `_`
and `@` as `_at_`. Check `klaviyoStatus`, then
check the profile's consent in Klaviyo — a profile can exist and be
unsubscribed, which is not the same as missing.

**The step never appears.** Either `emailCaptureEnabled` is false in Remote
Config, or `EmailCaptureService.hasCapturedEmail` is already true on that
install — the flow deliberately never asks twice, and that includes installs
carrying an address from before June under the legacy `email` UserDefaults key.

**The post-purchase sheet never appears.** By design in two cases: we already
hold an address (the profile is re-tagged silently instead), or
`hasShownEmailCapture` is set, which spends the one ask per install whether or
not the user submitted.

---

## Tests

`functions/test/emailCapture.test.js` — 24 tests, no emulator needed, run in CI
on Linux (`npm run test:email`). They cover validation, normalization, doc ids,
the legacy doc-id scheme, and the Klaviyo request shape — which is where the
quiet failures live. A missing consent block produces a profile that exists,
looks fine, and has no consent behind it; a doc-id regression silently doubles
the list.

`SpeakLife/SpeakLifeTests/OnboardingAngleTests.swift` asserts the step indices
for every angle arm, that the email ask sits immediately before the review wall,
and that nothing comes between the wall and the paywall.
