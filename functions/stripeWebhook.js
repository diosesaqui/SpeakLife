/**
 * stripeWebhook.js
 * Firebase Cloud Function — handles Stripe payment webhooks
 * and grants RevenueCat entitlements for web purchases.
 *
 * Flow:
 *   Stripe checkout.session.completed
 *   → verify signature
 *   → extract firebaseUID (stored in metadata during checkout creation)
 *   → call RevenueCat REST API to grant "premium" entitlement
 *   → write subscription record to Firestore
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);
const axios = require("axios");

const RC_API_KEY = process.env.RC_API_KEY; // RevenueCat secret key
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET;
const RC_BASE = "https://api.revenuecat.com/v1";

// Entitlement durations for each Stripe price
const PRICE_TO_ENTITLEMENT = {
  [process.env.STRIPE_MONTHLY_PRICE_ID]: {
    entitlement: "premium",
    durationDays: 31,
  },
  [process.env.STRIPE_ANNUAL_PRICE_ID]: {
    entitlement: "premium",
    durationDays: 366,
  },
};

exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error("⚠️ Webhook signature verification failed:", err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;
    const firebaseUID = session.metadata?.firebaseUID;
    const priceId = session.metadata?.priceId;
    const customerEmail = session.customer_details?.email;

    if (!firebaseUID) {
      console.error("❌ No firebaseUID in session metadata");
      return res.status(400).send("Missing firebaseUID in metadata");
    }

    const mapping = PRICE_TO_ENTITLEMENT[priceId];
    if (!mapping) {
      console.error("❌ Unknown priceId:", priceId);
      return res.status(400).send("Unknown priceId");
    }

    try {
      // Grant RevenueCat entitlement
      await grantRevenueCatEntitlement(
        firebaseUID,
        mapping.entitlement,
        mapping.durationDays
      );

      // Write to Firestore for app-side checks
      await admin.firestore().collection("webSubscriptions").doc(firebaseUID).set(
        {
          isPremium: true,
          source: "stripe",
          priceId,
          stripeSessionId: session.id,
          stripeCustomerId: session.customer,
          email: customerEmail,
          grantedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + mapping.durationDays * 24 * 60 * 60 * 1000)
          ),
        },
        { merge: true }
      );

      console.log(`✅ Granted ${mapping.entitlement} to ${firebaseUID}`);
      return res.status(200).json({ received: true });
    } catch (err) {
      console.error("❌ Failed to grant entitlement:", err.message);
      return res.status(500).send("Failed to grant entitlement");
    }
  }

  // Handle subscription renewals
  if (event.type === "invoice.payment_succeeded") {
    const invoice = event.data.object;
    const firebaseUID = invoice.metadata?.firebaseUID;
    if (firebaseUID) {
      const priceId = invoice.lines?.data?.[0]?.price?.id;
      const mapping = PRICE_TO_ENTITLEMENT[priceId];
      if (mapping) {
        await grantRevenueCatEntitlement(
          firebaseUID,
          mapping.entitlement,
          mapping.durationDays
        ).catch(console.error);
      }
    }
  }

  return res.status(200).json({ received: true });
});

/**
 * Grants a RevenueCat entitlement to a user via REST API.
 * Uses the "promotional" endpoint to bypass App Store.
 */
async function grantRevenueCatEntitlement(appUserID, entitlementId, durationDays) {
  const expiresDate = new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000);
  const expiresISO = expiresDate.toISOString();

  await axios.post(
    `${RC_BASE}/subscribers/${encodeURIComponent(appUserID)}/entitlements/${entitlementId}/promotional`,
    {
      duration: "custom",
      start_time_ms: Date.now(),
      end_time_ms: expiresDate.getTime(),
    },
    {
      headers: {
        Authorization: `Bearer ${RC_API_KEY}`,
        "Content-Type": "application/json",
      },
    }
  );

  console.log(
    `✅ RC entitlement '${entitlementId}' granted to ${appUserID} until ${expiresISO}`
  );
}
