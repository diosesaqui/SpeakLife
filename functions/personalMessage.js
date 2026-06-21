/**
 * personalMessage.js
 * Firebase Cloud Function (v2 HTTPS) — send a personalized in-app message push.
 *
 * Why this exists:
 *   The Firebase Console caps each "Custom data" value (and the notification
 *   text) at 200 characters, so long personalized messages can't be sent from
 *   the web composer. FCM itself allows up to ~4KB total payload, so we send
 *   these through the Admin SDK instead, where the only real limit is that 4KB.
 *
 *   The push carries data { deepLink: "message", messageTitle, messageBody }.
 *   The iOS app routes deepLink == "message" to RemoteMessageView and shows the
 *   full messageBody (falling back to the banner title/body when absent).
 *
 * ─── Setup ──────────────────────────────────────────────────────────────────
 *  1. Set a shared secret (any random string) so only you can trigger sends:
 *       firebase functions:secrets:set MSG_BROADCAST_SECRET
 *  2. Deploy:
 *       firebase deploy --only functions:sendPersonalMessage
 *
 * ─── Usage ────────────────────────────────────────────────────────────────
 *  Test to a single device (paste your device's FCM token):
 *    curl -X POST "https://<region>-<project>.cloudfunctions.net/sendPersonalMessage" \
 *      -H "Content-Type: application/json" \
 *      -d '{
 *            "secret": "<MSG_BROADCAST_SECRET>",
 *            "token": "<DEVICE_FCM_TOKEN>",
 *            "title": "Jesus",
 *            "body": "I have a word for you. Tap to read.",
 *            "messageTitle": "I See You",
 *            "messageBody": "<the full, long message ...>"
 *          }'
 *
 *  Broadcast to every user with a stored token (omit "token", add "broadcast"):
 *    curl ... -d '{ "secret":"...", "broadcast":true, "title":"...",
 *                   "body":"...", "messageTitle":"...", "messageBody":"..." }'
 *
 *  Add "dryRun": true to count recipients without actually sending.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

// prayerWallNotifications.js also calls initializeApp() at module load. When both
// are pulled in via index.js, guard against double-init.
if (getApps().length === 0) initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// Shared secret that gates who can send. Set via:
//   firebase functions:secrets:set MSG_BROADCAST_SECRET
const MSG_BROADCAST_SECRET = defineSecret('MSG_BROADCAST_SECRET');

// FCM multicast accepts at most 500 tokens per call.
const MULTICAST_CHUNK = 500;

// Build the message data payload. FCM data values must be strings, and empty
// strings are dropped so the app's fallback (banner title/body) kicks in.
function buildData(messageTitle, messageBody) {
  const data = { deepLink: 'message' };
  if (typeof messageTitle === 'string' && messageTitle.trim()) {
    data.messageTitle = messageTitle;
  }
  if (typeof messageBody === 'string' && messageBody.trim()) {
    data.messageBody = messageBody;
  }
  return data;
}

function buildApns() {
  return { payload: { aps: { sound: 'default' } } };
}

// Collect a deduped list of FCM tokens from the users collection.
async function collectAllTokens() {
  const snap = await db.collection('users').get();
  const tokens = new Set();
  snap.forEach((doc) => {
    const token = doc.data().fcmToken;
    if (typeof token === 'string' && token.length > 0) tokens.add(token);
  });
  return Array.from(tokens);
}

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

exports.sendPersonalMessage = onRequest(
  { secrets: [MSG_BROADCAST_SECRET], cors: false },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Use POST.' });
      return;
    }

    const {
      secret,
      token,
      broadcast,
      dryRun,
      title,
      body,
      messageTitle,
      messageBody,
    } = req.body || {};

    // Auth gate.
    if (!secret || secret !== MSG_BROADCAST_SECRET.value()) {
      res.status(401).json({ error: 'Invalid or missing secret.' });
      return;
    }

    // There must be something to display: either a full messageBody or at
    // least a banner body (the app falls back to it).
    const hasBody =
      (typeof messageBody === 'string' && messageBody.trim()) ||
      (typeof body === 'string' && body.trim());
    if (!hasBody) {
      res.status(400).json({ error: 'Provide messageBody (or body).' });
      return;
    }

    const notification = {
      title: typeof title === 'string' ? title : '',
      body: typeof body === 'string' ? body : '',
    };
    const data = buildData(messageTitle, messageBody);
    const apns = buildApns();

    try {
      // ── Single device (testing) ──────────────────────────────────────────
      if (token) {
        if (dryRun) {
          res.json({ mode: 'token', dryRun: true, recipients: 1 });
          return;
        }
        const id = await messaging.send({ notification, data, apns, token });
        res.json({ mode: 'token', sent: 1, messageId: id });
        return;
      }

      // ── Broadcast to all stored tokens ───────────────────────────────────
      if (broadcast === true) {
        const tokens = await collectAllTokens();
        if (dryRun) {
          res.json({ mode: 'broadcast', dryRun: true, recipients: tokens.length });
          return;
        }
        if (tokens.length === 0) {
          res.json({ mode: 'broadcast', sent: 0, note: 'No tokens found.' });
          return;
        }

        let success = 0;
        let failure = 0;
        for (const group of chunk(tokens, MULTICAST_CHUNK)) {
          const resp = await messaging.sendEachForMulticast({
            tokens: group,
            notification,
            data,
            apns,
          });
          success += resp.successCount;
          failure += resp.failureCount;
        }
        res.json({
          mode: 'broadcast',
          recipients: tokens.length,
          success,
          failure,
        });
        return;
      }

      res.status(400).json({
        error: 'Provide a "token" (single device) or "broadcast": true.',
      });
    } catch (err) {
      console.error('sendPersonalMessage error:', err);
      res.status(500).json({ error: err.message });
    }
  }
);
