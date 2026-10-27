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
 * Abuse limits live in lib/claudeProxyRequest.js (model, output, input caps)
 * plus a per-IP hourly limit here.
 *
 * Deploy: firebase deploy --only functions:claudeProxy
 * (Uses the ANTHROPIC_API_KEY secret that bibleChat already reads.)
 */

const crypto = require('crypto');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const Anthropic = require('@anthropic-ai/sdk');
const { buildClaudeParams } = require('./lib/claudeProxyRequest');

if (getApps().length === 0) initializeApp();

const db = getFirestore();
const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');

// One person using every AI feature heavily stays far under this; a script
// replaying the endpoint does not.
const HOURLY_LIMIT_PER_IP = 60;

function clientIp(req) {
  const forwarded = req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return req.ip || 'unknown';
}

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
      // Firestore TTL policy on expiresAt can clear these automatically.
      expiresAt: new Date((hour + 2) * 3600000),
    }, { merge: true });
    return false;
  });
}

exports.claudeProxy = onRequest(
  {
    region: 'us-central1',
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const built = buildClaudeParams(req.body);
    if (!built.ok) {
      res.status(400).json({ error: built.error });
      return;
    }

    try {
      if (await overRateLimit(clientIp(req))) {
        res.status(429).json({ error: 'rate_limited' });
        return;
      }
    } catch (err) {
      // A Firestore hiccup must not take every AI feature down with it.
      console.error('Rate limit check failed:', err.message);
    }

    try {
      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      const completion = await client.messages.create(built.params);
      // Same shape as api.anthropic.com/v1/messages, so the app's decoders
      // read it unchanged.
      res.json(completion);
    } catch (err) {
      console.error('Anthropic error:', err.message);
      res.status(502).json({ error: 'ai_unavailable' });
    }
  }
);
