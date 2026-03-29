/**
 * createCheckoutSession.js
 * Firebase Cloud Function — creates a Stripe Checkout session for web purchases.
 * Called by the subscribe.html page after user authenticates with Apple Sign In.
 *
 * The Firebase UID is stored in session metadata so the webhook
 * can grant the RevenueCat entitlement on completion.
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const stripe = require("stripe")(process.env.STRIPE_SECRET_KEY);

exports.createCheckoutSession = functions.https.onRequest(async (req, res) => {
  // CORS
  res.set("Access-Control-Allow-Origin", "https://speaklife.app");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
  if (req.method === "OPTIONS") return res.status(204).send("");
  if (req.method !== "POST") return res.status(405).send("Method Not Allowed");

  // Verify Firebase ID token
  const authHeader = req.headers.authorization || "";
  const idToken = authHeader.replace("Bearer ", "");
  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch (err) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const firebaseUID = decodedToken.uid;
  const { plan } = req.body; // "monthly" or "annual"

  const PRICES = {
    monthly: process.env.STRIPE_MONTHLY_PRICE_ID,
    annual: process.env.STRIPE_ANNUAL_PRICE_ID,
  };

  const priceId = PRICES[plan];
  if (!priceId) return res.status(400).json({ error: "Invalid plan" });

  try {
    const session = await stripe.checkout.sessions.create({
      mode: "subscription",
      payment_method_types: ["card"],
      line_items: [{ price: priceId, quantity: 1 }],
      // 7-day free trial on annual
      ...(plan === "annual" && {
        subscription_data: { trial_period_days: 7 },
      }),
      metadata: {
        firebaseUID,
        priceId,
        source: "speaklife_web",
      },
      success_url: "https://speaklife.app/subscribe/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: "https://speaklife.app/subscribe",
      // Pre-fill email if available
      customer_email: decodedToken.email || undefined,
    });

    return res.status(200).json({ url: session.url });
  } catch (err) {
    console.error("❌ Stripe session creation failed:", err.message);
    return res.status(500).json({ error: "Failed to create checkout session" });
  }
});
