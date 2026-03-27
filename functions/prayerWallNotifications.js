/**
 * prayerWallNotifications.js
 * Firebase Cloud Functions v2 — Prayer Wall FCM push notifications
 *
 * ─── iOS App Setup Required ────────────────────────────────────────────────
 *  1. Save FCM token to Firestore on each app launch:
 *       Firestore path: users/{uid}/fcmToken  (String)
 *     PrayerWallViewModel.registerForPrayerWallNotifications() does this.
 *
 *  2. Subscribe device to "prayerWall" topic on app launch (handled in the
 *     same registerForPrayerWallNotifications() call via Messaging.messaging()
 *     .subscribe(toTopic:)).  This drives `onNewPrayerPost` broadcasts.
 *
 *  3. Deploy these functions:
 *       firebase deploy --only functions
 *
 *  4. Firestore security rules should allow Cloud Functions (admin SDK)
 *     to read/write the meta/prayerWallNotifications doc and users collection.
 * ───────────────────────────────────────────────────────────────────────────
 */

const { onDocumentUpdated, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp }                         = require('firebase-admin/app');
const { getFirestore, FieldValue }              = require('firebase-admin/firestore');
const { getMessaging }                          = require('firebase-admin/messaging');

initializeApp();

const db        = getFirestore();
const messaging = getMessaging();

// ─── Constants ──────────────────────────────────────────────────────────────

const PRAYER_MILESTONES       = [5, 10, 25, 50, 100];
const NEW_POST_TOPIC          = 'prayerWall';
const NEW_POST_COOLDOWN_HOURS = 6;
const NEW_POST_COOLDOWN_MAX   = 3;   // max notifications per cooldown window
const META_DOC                = 'meta/prayerWallNotifications';

// ─── Helper: look up FCM token for a deviceId ────────────────────────────────

async function getFcmToken(deviceId) {
  if (!deviceId) return null;
  const snap = await db.collection('users').doc(deviceId).get();
  if (!snap.exists) return null;
  return snap.data().fcmToken || null;
}

// ─── Helper: send a single-device FCM message ────────────────────────────────

async function sendToDevice(fcmToken, title, body) {
  if (!fcmToken) {
    console.log('sendToDevice: no token, skipping');
    return;
  }
  const message = {
    notification: { title, body },
    token: fcmToken,
    apns: {
      payload: { aps: { sound: 'default', badge: 1 } },
    },
  };
  try {
    const response = await messaging.send(message);
    console.log(`✅ FCM sent: ${response}`);
  } catch (err) {
    console.error(`❌ FCM error: ${err.message}`);
  }
}

// ─── Helper: send FCM topic message ──────────────────────────────────────────

async function sendToTopic(topic, title, body) {
  return sendToTopicWithData(topic, title, body, {});
}

async function sendToTopicWithData(topic, title, body, data = {}) {
  const message = {
    notification: { title, body },
    topic,
    data,  // extra key/value pairs forwarded to the app (strings only)
    apns: {
      payload: { aps: { sound: 'default' } },
    },
  };
  try {
    const response = await messaging.send(message);
    console.log(`✅ FCM topic sent: ${response}`);
  } catch (err) {
    console.error(`❌ FCM topic error: ${err.message}`);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. onPrayerCountIncremented
//    Fires when a prayerWall document is updated.
//    Sends FCM to the post author when prayerCount hits a milestone.
// ═══════════════════════════════════════════════════════════════════════════

exports.onPrayerCountIncremented = onDocumentUpdated(
  'prayerWall/{postId}',
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();

    const prevCount = before.prayerCount || 0;
    const newCount  = after.prayerCount  || 0;

    // Only act when prayerCount increased
    if (newCount <= prevCount) return;

    // Only notify on milestones
    const hitMilestone = PRAYER_MILESTONES.some(
      (m) => newCount >= m && prevCount < m
    );
    if (!hitMilestone) return;

    const deviceId = after.deviceId;
    const fcmToken = await getFcmToken(deviceId);

    const title = 'People are praying for you 🙏';
    const body  = `Your prayer request has ${newCount} ${newCount === 1 ? 'person' : 'people'} lifting you up.`;

    await sendToDevice(fcmToken, title, body);
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// 2. onNewPrayerPost
//    Fires when a new prayerWall document is created.
//    Broadcasts to the "prayerWall" FCM topic with cooldown throttle.
//    Cooldown: max 3 notifications per 6-hour window, tracked in Firestore.
// ═══════════════════════════════════════════════════════════════════════════

exports.onNewPrayerPost = onDocumentCreated(
  'prayerWall/{postId}',
  async (event) => {
    const post = event.data.data();

    if (post.isHidden) return; // don't notify for hidden posts

    // ── Cooldown check ──────────────────────────────────────────────────────
    const metaRef  = db.doc(META_DOC);
    const metaSnap = await metaRef.get();
    const now      = Date.now();
    const windowMs = NEW_POST_COOLDOWN_HOURS * 60 * 60 * 1000;

    let sentTimestamps = [];
    if (metaSnap.exists) {
      sentTimestamps = (metaSnap.data().sentTimestamps || [])
        .filter((ts) => now - ts < windowMs); // keep only within window
    }

    if (sentTimestamps.length >= NEW_POST_COOLDOWN_MAX) {
      console.log(
        `onNewPrayerPost: cooldown active (${sentTimestamps.length}/${NEW_POST_COOLDOWN_MAX} in last ${NEW_POST_COOLDOWN_HOURS}h)`
      );
      return;
    }

    // ── Build message ────────────────────────────────────────────────────────
    const rawText = post.text || '';
    const preview = rawText.length > 80
      ? rawText.substring(0, 80).trimEnd() + '…'
      : rawText;

    const title = 'Someone needs prayer 🙏';
    const body  = preview;

    // Include posterDeviceId so the iOS app can suppress the notification
    // for the person who just posted (they don't need to be notified of their own request).
    await sendToTopicWithData(NEW_POST_TOPIC, title, body, { posterDeviceId: post.deviceId || '' });

    // ── Update meta doc ──────────────────────────────────────────────────────
    sentTimestamps.push(now);
    await metaRef.set(
      { sentTimestamps, lastUpdated: FieldValue.serverTimestamp() },
      { merge: true }
    );
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// 3. onPrayerAnswered
//    Fires when a prayerWall document is updated.
//    When isAnswered flips false → true, notifies the post author.
// ═══════════════════════════════════════════════════════════════════════════

exports.onPrayerAnswered = onDocumentUpdated(
  'prayerWall/{postId}',
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();

    // Only act when isAnswered flips from false/undefined to true
    const wasAnswered = before.isAnswered === true;
    const isNowAnswered = after.isAnswered === true;
    if (wasAnswered || !isNowAnswered) return;

    const deviceId = after.deviceId;
    const fcmToken = await getFcmToken(deviceId);

    const title = 'Praise God! 🙌';
    const body  = 'Mark your answered prayer as a testimony — share what He did.';

    await sendToDevice(fcmToken, title, body);
  }
);
