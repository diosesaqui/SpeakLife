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
 *   Every allUsers broadcast is ALSO written to the `speakLifeMessages`
 *   Firestore collection, which backs the "Messages" tab in the app's
 *   Community section — so the message history is visible to every user,
 *   including those who install later or never tap the notification.
 *   Single-device token sends (testing) and custom-topic sends are not
 *   published there.
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
 *  IMPORTANT: "token" and "broadcast"/"topic" are mutually exclusive. Sending
 *  both is rejected with a 400 — a leftover test token would otherwise turn a
 *  broadcast into a single-device send. In the iPhone Shortcut, make sure the
 *  JSON body has NO "token" field when broadcasting.
 *
 *  ── Scheduling ────────────────────────────────────────────────────────────
 *  Add ONE of these to any send to schedule it instead of sending now:
 *    "delayMinutes": 90                          → send ~90 minutes from now
 *    "sendAt": "2026-07-08T19:00:00-04:00"       → send at that exact time
 *  (sendAt must be ISO 8601 WITH a timezone offset — in the Shortcuts app use
 *   Format Date → ISO 8601 with time — or epoch milliseconds. Max 60 days out.)
 *  The message is stored in Firestore `scheduledMessages`; the
 *  processScheduledMessages cron (runs every minute) delivers it when due.
 *
 *  Manage pending sends (same URL, same secret):
 *    { "secret":"...", "list": true }            → list pending scheduled sends
 *    { "secret":"...", "cancel": "<doc id>" }    → cancel one before it sends
 *
 *  Deploying this file the first time after adding scheduling:
 *    firebase deploy --only functions:sendPersonalMessage,functions:processScheduledMessages
 *
 *  Add "dryRun": true to validate without sending. Note: topic sends can't
 *  report a subscriber count (FCM doesn't expose it) — a dry run only echoes
 *  the target topic.
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');

// prayerWallNotifications.js also calls initializeApp() at module load. When both
// are pulled in via index.js, guard against double-init.
if (getApps().length === 0) initializeApp();

const messaging = getMessaging();
const db = getFirestore();

// Pending scheduled sends live here until processScheduledMessages delivers
// them (status: pending → sent | error | cancelled). Clients are locked out
// via firestore.rules; only these functions touch it through the admin SDK.
const SCHEDULED_COLLECTION = 'scheduledMessages';

// Every allUsers broadcast is also published here so the app's Community
// "Messages" tab can show the full history — including to users who install
// after a message was sent or never tapped the notification. Read-only for
// clients (see firestore.rules). Token (single-device test) sends and custom
// topic sends are NOT published: only true everyone-broadcasts belong on the
// public timeline.
const MESSAGES_COLLECTION = 'speakLifeMessages';

// Refuse schedules absurdly far out — almost always a typo'd year/timezone.
const MAX_SCHEDULE_DAYS = 60;

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

// Publish a delivered allUsers broadcast to the public timeline the app's
// Community "Messages" tab reads. Resolves the display title/body with the
// same fallback the iOS RemoteMessage uses (messageTitle/messageBody first,
// banner title/body second). Never throws: the push already went out, so a
// timeline write failure must not fail the send — it is logged instead.
async function publishToMessagesTimeline(notification, data) {
  try {
    const title = (data.messageTitle || notification.title || '').trim();
    const body = (data.messageBody || notification.body || '').trim();
    if (!body) return;
    await db.collection(MESSAGES_COLLECTION).add({
      title,
      body,
      sentAt: FieldValue.serverTimestamp(),
    });
  } catch (err) {
    console.error('publishToMessagesTimeline failed (push was still sent):', err);
  }
}

// Resolve "delayMinutes" / "sendAt" into a future Date, or an error string.
// sendAt accepts epoch milliseconds or ISO 8601 — but an ISO string MUST carry
// a timezone (Z or ±hh:mm): a bare "2026-07-08T19:00" would silently be
// interpreted in the server's timezone, and the push would fire hours off.
function parseSchedule(sendAt, delayMinutes) {
  if (sendAt != null && delayMinutes != null) {
    return { error: 'Provide either "sendAt" or "delayMinutes", not both.' };
  }

  let when;
  if (delayMinutes != null) {
    const mins = Number(delayMinutes);
    if (!Number.isFinite(mins) || mins <= 0) {
      return { error: '"delayMinutes" must be a positive number of minutes.' };
    }
    when = new Date(Date.now() + mins * 60 * 1000);
  } else if (typeof sendAt === 'number') {
    when = new Date(sendAt);
  } else if (typeof sendAt === 'string' && sendAt.trim()) {
    const s = sendAt.trim();
    if (/^\d+$/.test(s)) {
      when = new Date(Number(s));
    } else {
      if (!/(Z|[+-]\d{2}:?\d{2})$/.test(s)) {
        return {
          error:
            '"sendAt" needs a timezone, e.g. "2026-07-08T19:00:00-04:00". ' +
            'In Shortcuts use Format Date → ISO 8601 (with time).',
        };
      }
      when = new Date(s);
    }
  } else {
    return { error: '"sendAt" must be an ISO 8601 string or epoch milliseconds.' };
  }

  if (isNaN(when.getTime())) {
    return { error: `Could not parse "sendAt": ${JSON.stringify(sendAt)}` };
  }
  if (when.getTime() <= Date.now()) {
    return { error: `"sendAt" is in the past (${when.toISOString()}). Use a future time.` };
  }
  if (when.getTime() > Date.now() + MAX_SCHEDULE_DAYS * 24 * 60 * 60 * 1000) {
    return { error: `"sendAt" is more than ${MAX_SCHEDULE_DAYS} days out — check the date.` };
  }
  return { when };
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
      sendAt,
      delayMinutes,
      list,
      cancel,
    } = req.body || {};

    // Auth gate.
    if (!secret || secret !== MSG_BROADCAST_SECRET.value()) {
      res.status(401).json({ error: 'Invalid or missing secret.' });
      return;
    }

    // ── Manage scheduled sends ─────────────────────────────────────────────
    if (list === true) {
      const snap = await db
        .collection(SCHEDULED_COLLECTION)
        .where('status', '==', 'pending')
        .get();
      const pending = snap.docs
        .map((d) => ({
          id: d.id,
          sendAt: d.get('sendAt').toDate().toISOString(),
          title: d.get('notification')?.title || '',
          body: d.get('notification')?.body || '',
          target: d.get('token') ? 'single device' : `topic:${d.get('topic')}`,
        }))
        .sort((a, b) => a.sendAt.localeCompare(b.sendAt));
      res.json({ mode: 'list', pending });
      return;
    }

    if (typeof cancel === 'string' && cancel.trim()) {
      const ref = db.collection(SCHEDULED_COLLECTION).doc(cancel.trim());
      const doc = await ref.get();
      if (!doc.exists) {
        res.status(404).json({ error: `No scheduled message with id "${cancel.trim()}".` });
        return;
      }
      if (doc.get('status') !== 'pending') {
        res.status(409).json({
          error: `Message ${cancel.trim()} is "${doc.get('status')}", not pending — nothing to cancel.`,
        });
        return;
      }
      await ref.update({ status: 'cancelled', cancelledAt: FieldValue.serverTimestamp() });
      res.json({ mode: 'cancel', id: cancel.trim(), cancelled: true });
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

    // Ambiguous target: a leftover test "token" alongside "broadcast"/"topic"
    // used to silently win, so a "broadcast" only ever reached the one test
    // device. Refuse loudly instead of guessing.
    const wantsTopic =
      broadcast === true || (typeof topic === 'string' && topic.trim());
    if (token && wantsTopic) {
      res.status(400).json({
        error:
          'Provide either "token" (single test device) OR "broadcast"/"topic" — not both. ' +
          'To reach all users, delete the "token" field and keep "broadcast": true.',
      });
      return;
    }

    if (!token && !wantsTopic) {
      res.status(400).json({
        error: 'Provide a "token" (single device) or "broadcast": true.',
      });
      return;
    }

    // ── Scheduled send: store it; the cron delivers it when due ───────────
    if (sendAt != null || delayMinutes != null) {
      const { when, error } = parseSchedule(sendAt, delayMinutes);
      if (error) {
        res.status(400).json({ error });
        return;
      }
      const targetTopic =
        typeof topic === 'string' && topic.trim() ? topic.trim() : ALL_USERS_TOPIC;
      if (dryRun) {
        res.json({
          mode: 'scheduled',
          dryRun: true,
          sendAt: when.toISOString(),
          target: token ? 'single device' : `topic:${targetTopic}`,
        });
        return;
      }
      const ref = await db.collection(SCHEDULED_COLLECTION).add({
        status: 'pending',
        sendAt: Timestamp.fromDate(when),
        createdAt: FieldValue.serverTimestamp(),
        notification,
        data,
        ...(token ? { token } : { topic: targetTopic }),
      });
      res.json({
        mode: 'scheduled',
        id: ref.id,
        sendAt: when.toISOString(),
        target: token ? 'single device' : `topic:${targetTopic}`,
      });
      return;
    }

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
      if (wantsTopic) {
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
        if (targetTopic === ALL_USERS_TOPIC) {
          await publishToMessagesTimeline(notification, data);
        }
        res.json({ mode: 'topic', topic: targetTopic, messageId: id });
        return;
      }
    } catch (err) {
      console.error('sendPersonalMessage error:', err);
      res.status(500).json({ error: err.message });
    }
  }
);

/**
 * Delivers due scheduled messages. Runs every minute; queries only on the
 * `status` field (single-field auto-index — no composite index to deploy)
 * and filters due-ness in code, since pending docs number a handful at most.
 *
 * Each doc is claimed pending → sending in a transaction before the FCM call,
 * so an overlapping run can never double-send the same message.
 */
exports.processScheduledMessages = onSchedule(
  { schedule: 'every 1 minutes', timeZone: 'UTC' },
  async () => {
    const snap = await db
      .collection(SCHEDULED_COLLECTION)
      .where('status', '==', 'pending')
      .get();

    const now = Date.now();
    const due = snap.docs.filter((d) => d.get('sendAt').toMillis() <= now);
    if (due.length === 0) return;

    for (const doc of due) {
      const claimed = await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        if (fresh.get('status') !== 'pending') return false;
        tx.update(doc.ref, { status: 'sending' });
        return true;
      });
      if (!claimed) continue;

      const { notification, data, token, topic } = doc.data();
      try {
        const id = await messaging.send({
          notification,
          data,
          apns: buildApns(),
          ...(token ? { token } : { topic }),
        });
        await doc.ref.update({
          status: 'sent',
          sentAt: FieldValue.serverTimestamp(),
          messageId: id,
        });
        if (!token && topic === ALL_USERS_TOPIC) {
          await publishToMessagesTimeline(notification, data);
        }
        console.log(`processScheduledMessages: sent ${doc.id} → ${token ? 'token' : `topic:${topic}`}`);
      } catch (err) {
        // Leave the error on the doc so a failed schedule is visible in the
        // Firestore console instead of vanishing silently.
        console.error(`processScheduledMessages: ${doc.id} failed:`, err);
        await doc.ref.update({ status: 'error', error: String(err.message || err) });
      }
    }
  }
);
