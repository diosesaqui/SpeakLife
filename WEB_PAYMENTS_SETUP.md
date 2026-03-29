# SpeakLife Web Payments — Setup Guide

## Architecture
```
User visits speaklife.app/subscribe
  → Signs in with Apple (Firebase Auth)
  → Selects plan → Firebase Function creates Stripe Checkout session
  → Stripe Checkout (hosted by Stripe)
  → Payment succeeds → Stripe webhook fires
  → Firebase Function grants RevenueCat entitlement via REST API
  → Writes to Firestore webSubscriptions/{uid}
  → iOS app: RC detects entitlement + Firestore fallback check
  → isPremium = true ✅
```

## What Was Built

### iOS Changes
- `AppleSignInService.swift` — calls `Purchases.shared.logIn(firebaseUID)` after Apple Sign In
  - This ties the RevenueCat customer ID to the Firebase UID so web purchases sync
- `SubscriptionStore.swift` — `checkWebSubscription()` checks Firestore as fallback
  - Catches cases where RC entitlement hasn't synced yet

### Firebase Functions
- `createCheckoutSession.js` — creates Stripe Checkout session (requires auth token)
- `stripeWebhook.js` — handles Stripe events, grants RC entitlement + writes Firestore
- `index.js` — exports all functions

### Web Page
- `web/public/subscribe.html` — checkout page (Apple Sign In + plan selection)
- `web/public/subscribe/success.html` — post-payment success page

---

## Setup Steps

### 1. Stripe
1. Create account at stripe.com
2. Create two products:
   - "SpeakLife Premium Monthly" → $9.99/month
   - "SpeakLife Premium Annual" → $49.99/year (with 7-day trial)
3. Copy the Price IDs (price_xxx)

### 2. Firebase Functions — Environment Variables
```bash
firebase functions:config:set \
  stripe.secret_key="sk_live_xxx" \
  stripe.webhook_secret="whsec_xxx" \
  stripe.monthly_price_id="price_xxx" \
  stripe.annual_price_id="price_xxx" \
  revenuecat.api_key="YOUR_RC_SECRET_KEY"
```

Map to process.env in functions by adding to `.runtimeconfig.json` for local dev.

### 3. Stripe Webhook
In Stripe Dashboard → Webhooks → Add endpoint:
- URL: `https://us-central1-YOUR_PROJECT.cloudfunctions.net/stripeWebhook`
- Events to listen for:
  - `checkout.session.completed`
  - `invoice.payment_succeeded`

### 4. RevenueCat Secret Key
Dashboard → Account → API Keys → Secret keys → copy the `sk_` key

### 5. Firebase Hosting
```bash
cd web
firebase init hosting
firebase deploy --only hosting
```

### 6. Update subscribe.html Firebase config
Replace placeholders in subscribe.html:
- `FIREBASE_API_KEY`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_PROJECT_ID`

### 7. Apple Sign In on Web (Firebase Auth)
Firebase Console → Authentication → Sign-in method → Apple
- Add `speaklife.app` to authorized domains
- Configure Apple Developer → Services IDs for web

### 8. External Link Entitlement (iOS)
Apply at: developer.apple.com/contact/request/external-link-account/
Once approved, add `com.apple.developer.web-browser` entitlement to SpeakLifeApp.entitlements
Then add the "Subscribe on our website →" button to the paywall.

---

## Firestore Rules (add to firestore.rules)
```
match /webSubscriptions/{uid} {
  allow read: if request.auth != null && request.auth.uid == uid;
  allow write: if false; // only Firebase Functions can write
}
```

---

## Revenue Impact
| Plan | Apple (30%) | Web (Stripe 2.9%) | Saved/user/yr |
|------|------------|-------------------|---------------|
| Monthly $9.99 | $7.00 | $9.69 | $31.92 |
| Annual $49.99 | $35.00 | $48.54 | $162.48 |

At 500 annual subscribers → +$81,000/year retained.
