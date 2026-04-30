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
const { onSchedule }                           = require('firebase-functions/v2/scheduler');
const { initializeApp }                         = require('firebase-admin/app');
const { getFirestore, FieldValue }              = require('firebase-admin/firestore');
const { getMessaging }                          = require('firebase-admin/messaging');

initializeApp();

const db        = getFirestore();
const messaging = getMessaging();

// ─── Constants ──────────────────────────────────────────────────────────────

const PRAYER_MILESTONES = [5, 10, 25, 50, 100];
const NEW_POST_TOPIC    = 'prayerWall';

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

    // Identify which milestones the new count has now crossed.
    const crossed = PRAYER_MILESTONES.filter(
      (m) => newCount >= m && prevCount < m
    );
    if (crossed.length === 0) return;

    // Filter out milestones we've already notified for on this post.
    // Without this guard, a post that oscillates across a threshold
    // (e.g. user toggles a reaction off and someone else re-adds it)
    // would re-fire the same milestone notification.
    const alreadyNotified = Array.isArray(after.notifiedMilestones)
      ? after.notifiedMilestones
      : [];
    const newlyHit = crossed.filter((m) => !alreadyNotified.includes(m));
    if (newlyHit.length === 0) return;

    const deviceId = after.deviceId;
    const fcmToken = await getFcmToken(deviceId);

    // Notify on the highest newly-crossed milestone (avoids stacking pushes
    // when a single write jumps past multiple thresholds).
    const milestone = Math.max(...newlyHit);

    // Copy adapts to the post type. Testimonies (posts created with or later
    // marked as isAnswered=true) frame reactions as celebration, not prayer.
    const isTestimony = after.isAnswered === true;
    const peoplePhrase = `${newCount} ${newCount === 1 ? 'person' : 'people'}`;
    const title = isTestimony
      ? 'People are celebrating with you 🙌'
      : 'People are praying with you 🙏';
    const body = isTestimony
      ? `${peoplePhrase} stood with you on this testimony.`
      : `${peoplePhrase} ${newCount === 1 ? 'is' : 'are'} standing with you in prayer.`;

    await sendToDevice(fcmToken, title, body);

    // Persist the milestones we've now notified for so re-crossings don't
    // re-fire. arrayUnion is safe under concurrent writes.
    const postRef = event.data.after.ref;
    await postRef.update({
      notifiedMilestones: FieldValue.arrayUnion(...newlyHit),
    });
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// 2. dailyPrayerDigest — PAUSED
//
//    This function used to run daily at 10:00 AM UTC and broadcast a
//    "X prayer requests today" digest to all `prayerWall` topic subscribers.
//    It was paused because the copy assumed every new post is a prayer
//    request, which is wrong now that the Warrior Room hosts both prayer
//    declarations and testimonies. The wrong framing was misleading users.
//
//    The export is commented out below and the deployed function has been
//    deleted from production (firebase functions:delete dailyPrayerDigest).
//    To resume, uncomment the export and run:
//        firebase deploy --only functions:dailyPrayerDigest
//
//    NOTE: There's also an `onNewPrayerPost` Cloud Function deployed in
//    production that broadcasts on every new post creation. Its source is
//    not in this file — it's intentionally kept out of source for now.
//    When deploying, scope to the specific function you're changing
//    (e.g. `firebase deploy --only functions:onPrayerCountIncremented`)
//    so the CLI doesn't try to reconcile the orphan and prompt for a delete.
// ═══════════════════════════════════════════════════════════════════════════

/*
exports.dailyPrayerDigest = onSchedule(
  { schedule: '0 10 * * *', timeZone: 'UTC' },
  async () => {
    const now        = Date.now();
    const since      = now - 24 * 60 * 60 * 1000; // last 24 hours

    // Count new, non-hidden posts in the last 24h
    const snap = await db.collection('prayerWall')
      .where('createdAt', '>=', new Date(since))
      .where('isHidden', '!=', true)
      .get();

    const count = snap.size;
    if (count === 0) {
      console.log('dailyPrayerDigest: no new posts today, skipping.');
      return;
    }

    // Build copy based on count
    let title, body;
    if (count === 1) {
      title = 'Someone needs prayer today 🙏';
      body  = 'A brother or sister shared a prayer request. Lift them up.';
    } else {
      title = `${count} prayer requests today 🙏`;
      body  = `Your community is seeking God. Take a moment to pray for them.`;
    }

    await sendToTopicWithData(NEW_POST_TOPIC, title, body, {
      notificationType: 'prayerWall',
    });

    console.log(`dailyPrayerDigest: sent digest for ${count} post(s).`);
  }
);
*/

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

// ═══════════════════════════════════════════════════════════════════════════
// 4. onNewPrayerPost
//    Fires when a new prayerWall document is created. Sends a topic
//    broadcast to all `prayerWall` subscribers. Copy adapts based on the
//    post type:
//      - Testimony (isAnswered: true at creation) → celebration framing
//      - Prayer request (isAnswered: false / unset) → prayer framing
//    The poster's own device suppresses the notification client-side using
//    the `posterDeviceId` payload key (NotificationHandler.swift).
// ═══════════════════════════════════════════════════════════════════════════

exports.onNewPrayerPost = onDocumentCreated(
  'prayerWall/{postId}',
  async (event) => {
    const data = event.data && event.data.data ? event.data.data() : null;
    if (!data) return;
    if (data.isHidden === true) return;

    const isTestimony = data.isAnswered === true;
    const posterDeviceId = data.deviceId || '';
    const postId = event.params.postId;

    let title, body;
    if (isTestimony) {
      title = '🏆 New testimony in the Warrior Room';
      body  = 'A brother or sister just shared what God did. Celebrate with them.';
    } else {
      title = '🙏 Someone needs prayer in the Warrior Room';
      body  = 'A brother or sister just asked for prayer. Stand with them.';
    }

    await sendToTopicWithData(NEW_POST_TOPIC, title, body, {
      notificationType: 'prayerWall',
      postId,
      posterDeviceId,
      isTestimony: String(isTestimony),
    });
  }
);

