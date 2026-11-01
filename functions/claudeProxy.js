/**
 * claudeProxy.js
 * Firebase Cloud Function (v2 HTTPS) — Claude proxy for the app's on-device
 * AI features (personal declarations, Guard's written counter, the seven-day
 * campaign curator).
 *
 * Those features used to call api.anthropic.com straight from the device with
 * a key delivered through Remote Config. Remote Config is readable by anyone
 * who installs the app, so the key was public. This proxy holds the key in
 * Secret Manager instead; the app sends the same Messages API body it always
 * built and gets the same response back.
 *
 * Abuse limits:
 *   - lib/claudeProxyRequest.js: server-chosen model, output/input caps.
 *   - Firebase App Check: the app attaches a token proving it is a real
 *     install. Logged-only until the ENFORCE_APP_CHECK param is true; turn it
 *     on once the DeviceCheck key is registered in the Firebase console and the
 *     App Check build has rolled out.
 *   - A per-IP hourly limit (fails closed).
 *
 * Deploy: firebase deploy --only functions:claudeProxy
 * (Uses the ANTHROPIC_API_KEY secret that bibleChat already reads.)
 */

const crypto = require('crypto');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret, defineBoolean } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getAppCheck } = require('firebase-admin/app-check');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const Anthropic = require('@anthropic-ai/sdk');
const { createClaudeProxyHandler } = require('./lib/claudeProxyHandler');

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');
const ENFORCE_APP_CHECK = defineBoolean('ENFORCE_APP_CHECK', { default: false });

// One person using every AI feature heavily stays far under this; a script
// replaying the endpoint does not.
const HOURLY_LIMIT_PER_IP = 60;

/** Counts this request and reports whether the IP is over its hourly limit. */
async function overRateLimit(ip) {
  const hour = Math.floor(Date.now() / 3600000);
  // Hashed so raw IPs are never stored.
  const id = crypto.createHash('sha256').update(ip).digest('hex').slice(0, 32) + '_' + hour;
  const ref = db.collection('claudeProxyUsage').doc(id);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const count = snap.exists ? snap.data().count || 0 : 0;
    if (count >= HOURLY_LIMIT_PER_IP) return true;
    tx.set(ref, {
      count: FieldValue.increment(1),
      hour,
      // Cleared by the TTL policy in firestore.indexes.json.
      expiresAt: new Date((hour + 2) * 3600000),
    }, { merge: true });
    return false;
  });
}

async function verifyAppCheck(token) {
  await getAppCheck().verifyToken(token);
  return true;
}

let anthropic;
function callClaude(params) {
  anthropic = anthropic || new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
  return anthropic.messages.create(params);
}

exports.claudeProxy = onRequest(
  {
    region: 'us-central1',
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 30,
    // One warm instance so a cold start does not eat Guard's 8-second client
    // timeout and push people onto the keyword fallback.
    minInstances: 1,
  },
  createClaudeProxyHandler({
    verifyAppCheck,
    enforceAppCheck: () => ENFORCE_APP_CHECK.value(),
    overRateLimit,
    callClaude,
  })
);
