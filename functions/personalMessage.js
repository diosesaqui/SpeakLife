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
 *  Broadcast to everyone via the "allUsers" FCM topic (every device subscribes
 *  to it on launch — see AppDelegate). Omit "token", add "broadcast":
 *    curl ... -d '{ "secret":"...", "broadcast":true, "title":"...",
 *                   "body":"...", "messageTitle":"...", "messageBody":"..." }'
 *  (Or target a custom topic with "topic":"<name>".)
 *
 *  Add "dryRun": true to validate without sending. Note: topic sends can't
 *  report a subscriber count (FCM doesn't expose it) — a dry run only echoes
 *  the target topic.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

// prayerWallNotifications.js also calls initializeApp() at module load. When both
// are pulled in via index.js, guard against double-init.
if (getApps().length === 0) initializeApp();

const messaging = getMessaging();

// Shared secret that gates who can send. Set via:
//   firebase functions:secrets:set MSG_BROADCAST_SECRET
const MSG_BROADCAST_SECRET = defineSecret('MSG_BROADCAST_SECRET');

// Every device subscribes to this topic on launch (see AppDelegate), so a
// single topic send reaches the whole user base — no per-user token store.
const ALL_USERS_TOPIC = 'allUsers';

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
      topic,
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

      // ── Broadcast to every device via the allUsers topic ─────────────────
      if (broadcast === true || (typeof topic === 'string' && topic.trim())) {
        const targetTopic =
          typeof topic === 'string' && topic.trim()
            ? topic.trim()
            : ALL_USERS_TOPIC;
        if (dryRun) {
          // FCM doesn't expose topic subscriber counts, so a dry run can only
          // confirm the target topic, not a recipient number.
          res.json({ mode: 'topic', dryRun: true, topic: targetTopic });
          return;
        }
        const id = await messaging.send({ notification, data, apns, topic: targetTopic });
        res.json({ mode: 'topic', topic: targetTopic, messageId: id });
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
