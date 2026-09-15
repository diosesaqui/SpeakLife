/**
 * standTogether.js
 * Firebase Cloud Functions v2 — Stand With Me
 *
 * A "stand" is one seven-day Enforcement run by 2-12 people at once. Full
 * design, data model and rationale: docs/STAND_TOGETHER_SPEC.md.
 *
 * Two rules here carry the whole feature and should not be tidied away:
 *
 *  1. JOINING IS SERVER-ONLY. A client never writes a room's roster. That is
 *     why standInvites is closed to clients in firestore.rules — an eight
 *     character code a client could probe for validity is an eight character
 *     code that can be enumerated. Every join runs through joinStand, which
 *     throttles per uid and audits.
 *
 *  2. THE PUSH FAN-OUT IS CAPPED BY ROOM SIZE, NOT BY POLITENESS. A duo gets
 *     an immediate "your partner spoke" push. A group does not, ever: ten
 *     people each completing a day is ninety pushes, which is an uninstall,
 *     not accountability. Groups get one digest per person per day and
 *     nothing else. See onStandRoomUpdated and standDailyNudge.
 */

const { onCall, HttpsError }     = require('firebase-functions/v2/https');
const { onDocumentUpdated }      = require('firebase-functions/v2/firestore');
const { onSchedule }             = require('firebase-functions/v2/scheduler');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging }           = require('firebase-admin/messaging');
const { getAuth }                = require('firebase-admin/auth');
const crypto                     = require('node:crypto');

// prayerWallNotifications.js already calls initializeApp() at module load and
// index.js requires both modules. Calling it twice throws.
if (getApps().length === 0) initializeApp();

const db        = getFirestore();
const messaging = getMessaging();
const auth      = getAuth();

// ─── Constants ──────────────────────────────────────────────────────────────

const MAX_MEMBERS            = 12;
const ENFORCEMENT_LENGTH     = 7;
const INVITE_TTL_DAYS        = 14;
const MAX_ACTIVE_INVITES     = 5;
const MAX_ROOMS_PER_USER     = 3;
const MAX_JOIN_ATTEMPTS_HOUR = 20;
const STAND_PASS_DAYS        = 7;
const MERGE_TICKET_TTL_MIN   = 10;
const DEFAULT_NUDGE_HOUR     = 19;   // 7pm, in the member's own local time
const ORPHAN_ROOM_DAYS       = 14;   // one member, invite never used
const DORMANT_AFTER_DAYS     = 14;   // nobody has spoken
const ARCHIVE_AFTER_DAYS     = 60;

// No 0/O/1/I/L. Both halves of each confusable pair are excluded, so a typed
// `0` or `I` cannot be valid under any reading and is rejected outright rather
// than guessed at — guessing is how someone lands in the wrong family's stand.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH   = 8;

// ═══ Helpers ════════════════════════════════════════════════════════════════

/**
 * A cryptographically random invite code, uniformly distributed.
 *
 * Rejection sampling, not `% alphabet.length`: 256 is not a multiple of 31, so
 * modulo would make the first few characters of the alphabet measurably more
 * likely and shrink the real keyspace.
 */
function generateCode() {
  const max = 256 - (256 % CODE_ALPHABET.length);
  let out = '';
  while (out.length < CODE_LENGTH) {
    for (const byte of crypto.randomBytes(CODE_LENGTH * 2)) {
      if (byte >= max) continue;                    // reject, keep it uniform
      out += CODE_ALPHABET[byte % CODE_ALPHABET.length];
      if (out.length === CODE_LENGTH) break;
    }
  }
  return out;
}

/** Uppercase, strip separators, reject anything outside the alphabet. */
function normalizeCode(raw) {
  if (typeof raw !== 'string') return null;
  const cleaned = raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (cleaned.length !== CODE_LENGTH) return null;
  for (const ch of cleaned) if (!CODE_ALPHABET.includes(ch)) return null;
  return cleaned;
}

// ─── Timezone math ──────────────────────────────────────────────────────────
//
// Done with Intl rather than a date library so functions/ gains no dependency.
// Every entry point guards against a bad IANA identifier: `tz` arrives from a
// client, and Intl.DateTimeFormat throws a RangeError on an unknown zone,
// which would otherwise take down a whole scheduled batch.

function safeTz(tz) {
  if (typeof tz !== 'string' || !tz) return 'UTC';
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return tz;
  } catch {
    return 'UTC';
  }
}

function tzParts(tz, date) {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: tz, hour12: false,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
  });
  const p = {};
  for (const { type, value } of fmt.formatToParts(date)) p[type] = value;
  // Some ICU versions emit '24' for midnight under hour12:false.
  const hour = p.hour === '24' ? '00' : p.hour;
  return {
    y: +p.year, m: +p.month, d: +p.day,
    H: +hour, M: +p.minute, S: +p.second,
  };
}

/** "yyyy-MM-dd" in the given zone — the same stamp the client writes. */
function localDayStamp(tz, date = new Date()) {
  const p = tzParts(safeTz(tz), date);
  return `${p.y}-${String(p.m).padStart(2, '0')}-${String(p.d).padStart(2, '0')}`;
}

function tzOffsetMs(tz, date) {
  const p = tzParts(tz, date);
  const asUTC = Date.UTC(p.y, p.m - 1, p.d, p.H, p.M, p.S);
  return asUTC - (date.getTime() - (date.getTime() % 1000));
}

/**
 * The UTC instant at which the wall clock in `tz` reads y-m-d H:00.
 *
 * Iterates twice: the first pass corrects by the offset at the guessed
 * instant, the second settles the case where that correction crossed a DST
 * boundary and changed which offset applies.
 */
function zonedTimeToUTC(tz, y, m, d, H) {
  const wall = Date.UTC(y, m - 1, d, H, 0, 0);
  let ts = wall;
  for (let i = 0; i < 2; i++) ts = wall - tzOffsetMs(tz, new Date(ts));
  return new Date(ts);
}

/** The next time it is `hour` o'clock in `tz`, strictly after `now`. */
function nextLocalHour(tz, hour, now = new Date()) {
  const zone = safeTz(tz);
  const p = tzParts(zone, now);
  let target = zonedTimeToUTC(zone, p.y, p.m, p.d, hour);
  if (target.getTime() <= now.getTime()) {
    const next = new Date(Date.UTC(p.y, p.m - 1, p.d) + 86400000);
    target = zonedTimeToUTC(zone,
      next.getUTCFullYear(), next.getUTCMonth() + 1, next.getUTCDate(), hour);
  }
  return target;
}

// ─── Push ───────────────────────────────────────────────────────────────────

async function tokenFor(uid) {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists ? (snap.data().fcmToken || null) : null;
}

/**
 * Sends one push. A token FCM reports as dead is cleared, so the nudge
 * scheduler stops paying to retry a device whose app was deleted.
 */
async function push(uid, title, body, data = {}) {
  const token = await tokenFor(uid);
  if (!token) return false;
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: { notificationType: 'stand', ...data },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return true;
  } catch (err) {
    if (err.code === 'messaging/registration-token-not-registered') {
      await db.collection('users').doc(uid)
        .set({ fcmToken: FieldValue.delete() }, { merge: true });
    }
    console.error(`stand push failed for ${uid}: ${err.message}`);
    return false;
  }
}

// ─── Misc ───────────────────────────────────────────────────────────────────

function requireAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return uid;
}

/** First name only, bounded, control characters stripped — shown to others. */
function sanitizeName(raw) {
  const stripped = String(raw ?? '')
    .split('')
    .filter((ch) => {
      const c = ch.codePointAt(0);
      if (c <= 0x1F || c === 0x7F) return false;               // control
      if (c >= 0x200B && c <= 0x200F) return false;            // zero-width
      if (c === 0x2028 || c === 0x2029) return false;          // line separators
      return true;
    })
    .join('')
    .trim();
  const first = stripped.split(/\s+/)[0] || 'Friend';
  return first.slice(0, 24);
}

function colorIndexFor(uid) {
  return crypto.createHash('sha256').update(uid).digest()[0] % 8;
}

function activeMembers(room) {
  return Object.entries(room.members || {}).filter(([, m]) => !m.left);
}

/**
 * Validates a campaign before it is stored and served to other people's
 * devices. A room's `enforcement` blob is the one piece of client-supplied
 * content other users render, so it is bounded here rather than trusted.
 */
function validateEnforcement(e) {
  if (!e || typeof e !== 'object') {
    throw new HttpsError('invalid-argument', 'Missing campaign.');
  }
  const str = (v, max) => typeof v === 'string' && v.length > 0 && v.length <= max;
  if (!str(e.id, 128) || !str(e.title, 120) || !str(e.theme, 64)) {
    throw new HttpsError('invalid-argument', 'Malformed campaign.');
  }
  if (typeof e.tagline !== 'string' || e.tagline.length > 200) {
    throw new HttpsError('invalid-argument', 'Malformed campaign.');
  }
  if (!Array.isArray(e.days) || e.days.length !== ENFORCEMENT_LENGTH) {
    throw new HttpsError('invalid-argument', `A campaign is ${ENFORCEMENT_LENGTH} days.`);
  }
  const seen = new Set();
  for (const d of e.days) {
    if (!Number.isInteger(d?.dayNumber) || d.dayNumber < 1 || d.dayNumber > ENFORCEMENT_LENGTH) {
      throw new HttpsError('invalid-argument', 'Malformed campaign day.');
    }
    if (seen.has(d.dayNumber)) {
      throw new HttpsError('invalid-argument', 'Duplicate campaign day.');
    }
    seen.add(d.dayNumber);
    if (!str(d.anchorText, 600) || !str(d.anchorVerse, 1200) || !str(d.anchorBook, 120)) {
      throw new HttpsError('invalid-argument', 'Malformed campaign day.');
    }
  }
  if (JSON.stringify(e).length > 64 * 1024) {
    throw new HttpsError('invalid-argument', 'Campaign too large.');
  }
  // Rebuilt field by field rather than stored as received, so nothing the
  // client attached rides along into other people's documents.
  return {
    id: e.id, title: e.title, tagline: e.tagline || '', theme: e.theme,
    days: e.days.map((d) => ({
      dayNumber: d.dayNumber,
      anchorText: d.anchorText,
      anchorVerse: d.anchorVerse,
      anchorBook: d.anchorBook,
      anchorTranslation: String(d.anchorTranslation || '').slice(0, 64),
      audioId: String(d.audioId || '').slice(0, 128),
      audioTitle: String(d.audioTitle || '').slice(0, 200),
      audioMinutes: Number.isInteger(d.audioMinutes) ? d.audioMinutes : 0,
    })),
  };
}

/** Sliding-window counter. The brute-force guard on an 8-character code. */
async function throttle(uid, bucket, limit, windowMs) {
  const ref = db.collection('standRateLimits').doc(`${uid}|${bucket}`);
  const now = Date.now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : {};
    const start = data.windowStart || 0;
    const count = data.count || 0;
    if (now - start > windowMs) {
      tx.set(ref, { windowStart: now, count: 1 });
      return;
    }
    if (count >= limit) {
      throw new HttpsError('resource-exhausted', 'Too many attempts. Try again later.');
    }
    tx.set(ref, { windowStart: start, count: count + 1 }, { merge: true });
  });
}

function memberEntry({ uid, name, tz, isOwner }) {
  const clean = sanitizeName(name);
  return {
    name: clean,
    initial: clean.charAt(0).toUpperCase(),
    colorIndex: colorIndexFor(uid),
    joinedAt: Timestamp.now(),
    dayNumber: 0,
    daysSpoken: [],
    lastSpokeAt: null,
    tz: safeTz(tz),
    left: false,
    isOwner: !!isOwner,
  };
}

function newInvite(tx, roomId, uid) {
  const code = generateCode();
  tx.set(db.collection('standInvites').doc(code), {
    roomId,
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + INVITE_TTL_DAYS * 86400000),
    maxUses: MAX_MEMBERS,
    uses: 0,
    revoked: false,
  });
  return code;
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. createStand — mint a room with the caller as its first member
// ═══════════════════════════════════════════════════════════════════════════

exports.createStand = onCall(async (request) => {
  const uid = requireAuth(request);
  const { enforcement, name, tz } = request.data || {};
  const campaign = validateEnforcement(enforcement);

  await throttle(uid, 'createStand', 10, 7 * 86400000);

  // Tapping Invite mints a room before anything is shared, so someone who taps
  // and never sends leaves an orphan. Capping active rooms stops that from
  // compounding; standSweep collects the orphans themselves.
  const existing = await db.collection('standRooms')
    .where('memberUids', 'array-contains', uid)
    .where('status', '==', 'active')
    .count().get();
  if (existing.data().count >= MAX_ROOMS_PER_USER) {
    throw new HttpsError('resource-exhausted',
      `You can run ${MAX_ROOMS_PER_USER} stands at once.`);
  }

  const roomRef = db.collection('standRooms').doc();
  let code;
  await db.runTransaction(async (tx) => {
    code = newInvite(tx, roomRef.id, uid);
    tx.set(roomRef, {
      id: roomRef.id,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: uid,
      status: 'active',
      schemaVersion: 1,
      enforcement: campaign,
      memberUids: [uid],
      members: { [uid]: memberEntry({ uid, name, tz, isOwner: true }) },
      completedAt: null,
      notifiedMilestones: [],
      lastNotifiedDay: {},
      lastActivityAt: FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('users').doc(uid),
      { standRoomIds: FieldValue.arrayUnion(roomRef.id) }, { merge: true });
  });

  await rescheduleNudge(uid, safeTz(tz));
  return { roomId: roomRef.id, code };
});

// ═══════════════════════════════════════════════════════════════════════════
// 2. createStandInvite / revokeStandInvite
// ═══════════════════════════════════════════════════════════════════════════

exports.createStandInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId || '');
  const roomSnap = await db.collection('standRooms').doc(roomId).get();
  if (!roomSnap.exists) throw new HttpsError('not-found', 'Stand not found.');
  const room = roomSnap.data();
  if (!room.members?.[uid]?.isOwner) {
    throw new HttpsError('permission-denied', 'Only the owner can invite.');
  }
  if (room.status !== 'active') {
    throw new HttpsError('failed-precondition', 'This stand already finished.');
  }

  const live = await db.collection('standInvites')
    .where('roomId', '==', roomId)
    .where('revoked', '==', false)
    .where('expiresAt', '>', Timestamp.now())
    .count().get();
  if (live.data().count >= MAX_ACTIVE_INVITES) {
    throw new HttpsError('resource-exhausted', 'Too many open invites.');
  }

  let code;
  await db.runTransaction(async (tx) => { code = newInvite(tx, roomId, uid); });
  return { code };
});

exports.revokeStandInvite = onCall(async (request) => {
  const uid = requireAuth(request);
  const code = normalizeCode(request.data?.code);
  if (!code) throw new HttpsError('invalid-argument', 'Bad code.');
  const ref = db.collection('standInvites').doc(code);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new HttpsError('not-found', 'Unknown code.');
    if (snap.data().createdBy !== uid) {
      throw new HttpsError('permission-denied', 'Not your invite.');
    }
    tx.update(ref, { revoked: true });
  });
  return { ok: true };
});

// ═══════════════════════════════════════════════════════════════════════════
// 3. joinStand
// ═══════════════════════════════════════════════════════════════════════════

exports.joinStand = onCall(async (request) => {
  const uid = requireAuth(request);
  const code = normalizeCode(request.data?.code);
  const { name, tz } = request.data || {};

  // Throttle BEFORE the lookup. Rate limiting only on success would let an
  // attacker enumerate codes for free on every miss.
  await throttle(uid, 'joinStand', MAX_JOIN_ATTEMPTS_HOUR, 3600000);

  if (!code) {
    throw new HttpsError('invalid-argument',
      'Check that code — it should be 8 letters and numbers.');
  }

  const inviteRef = db.collection('standInvites').doc(code);
  let result;

  await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) throw new HttpsError('not-found', "That code doesn't exist.");
    const invite = inviteSnap.data();

    if (invite.revoked) {
      throw new HttpsError('permission-denied', 'This invite was turned off.');
    }
    if (invite.expiresAt && invite.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError('deadline-exceeded', 'This invite expired.');
    }

    const roomRef = db.collection('standRooms').doc(invite.roomId);
    const roomSnap = await tx.get(roomRef);
    if (!roomSnap.exists) throw new HttpsError('not-found', 'Stand not found.');
    const room = roomSnap.data();
    if (room.status !== 'active') {
      throw new HttpsError('failed-precondition', 'This stand already finished.');
    }

    const existing = room.members?.[uid];

    // Tapping the same link twice, or opening it on a second device, is a
    // no-op rather than an error. An error screen here reads as "you're not
    // welcome" at the exact moment someone accepted an invitation.
    if (existing && !existing.left) {
      result = { roomId: invite.roomId, alreadyMember: true,
                 enforcement: room.enforcement };
      return;
    }

    if (!existing && (room.memberUids || []).length >= MAX_MEMBERS) {
      throw new HttpsError('resource-exhausted', 'This stand is full.');
    }
    // A used-up invite still lets a former member rejoin: the seat was already
    // theirs, so it should not be charged twice.
    if (!existing && invite.uses >= invite.maxUses) {
      throw new HttpsError('resource-exhausted', 'This invite is used up.');
    }

    const updates = { lastActivityAt: FieldValue.serverTimestamp() };
    if (existing) {
      // Rejoin: their previous days are theirs. Never reset progress.
      updates[`members.${uid}.left`] = false;
      updates[`members.${uid}.name`] = sanitizeName(name);
      updates[`members.${uid}.tz`]   = safeTz(tz);
    } else {
      updates[`members.${uid}`] = memberEntry({ uid, name, tz, isOwner: false });
      tx.update(inviteRef, { uses: FieldValue.increment(1) });
    }
    updates.memberUids = FieldValue.arrayUnion(uid);
    tx.update(roomRef, updates);

    tx.set(db.collection('users').doc(uid),
      { standRoomIds: FieldValue.arrayUnion(invite.roomId) }, { merge: true });

    result = { roomId: invite.roomId, alreadyMember: false,
               enforcement: room.enforcement };
  });

  if (!result.alreadyMember) await grantStandPass(uid, result.roomId);
  await rescheduleNudge(uid, safeTz(tz));
  return result;
});

/**
 * Seven days of full access for someone who accepted an invitation.
 *
 * Never stacks onto an existing entitlement: a paying subscriber gets nothing
 * here, and a pass already running is not extended by joining a second stand.
 */
async function grantStandPass(uid, roomId) {
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();
  const current = snap.exists ? snap.data().standPass : null;
  if (current?.expiresAt && current.expiresAt.toMillis() > Date.now()) return;
  await ref.set({
    standPass: {
      expiresAt: Timestamp.fromMillis(Date.now() + STAND_PASS_DAYS * 86400000),
      grantedBy: roomId,
      grantedAt: FieldValue.serverTimestamp(),
    },
  }, { merge: true });
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. leaveStand
// ═══════════════════════════════════════════════════════════════════════════

exports.leaveStand = onCall(async (request) => {
  const uid = requireAuth(request);
  const roomId = String(request.data?.roomId || '');
  await removeMember(uid, roomId, { wipeName: true });
  await rescheduleNudge(uid);
  return { ok: true };
});

async function removeMember(uid, roomId, { wipeName }) {
  const roomRef = db.collection('standRooms').doc(roomId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(roomRef);
    if (!snap.exists) return;
    const room = snap.data();
    if (!room.members?.[uid]) return;

    const remaining = activeMembers(room).filter(([id]) => id !== uid);

    if (remaining.length === 0) {
      tx.delete(roomRef);
    } else {
      const updates = {
        memberUids: FieldValue.arrayRemove(uid),
        [`members.${uid}.left`]: true,
        lastActivityAt: FieldValue.serverTimestamp(),
      };
      // The row is kept, not deleted, so the remaining members' week strip
      // does not silently renumber around someone who was there yesterday.
      if (wipeName) {
        updates[`members.${uid}.name`] = '';
        updates[`members.${uid}.initial`] = '';
      }
      // Ownership follows the earliest joiner still standing.
      if (room.members[uid].isOwner) {
        const heir = remaining.sort((a, b) =>
          (a[1].joinedAt?.toMillis?.() || 0) - (b[1].joinedAt?.toMillis?.() || 0))[0][0];
        updates[`members.${uid}.isOwner`] = false;
        updates[`members.${heir}.isOwner`] = true;
      }
      tx.update(roomRef, updates);
    }
    tx.set(db.collection('users').doc(uid),
      { standRoomIds: FieldValue.arrayRemove(roomId) }, { merge: true });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. onStandRoomUpdated — the fan-out
// ═══════════════════════════════════════════════════════════════════════════

exports.onStandRoomUpdated = onDocumentUpdated('standRooms/{roomId}', async (event) => {
  const before = event.data.before.data();
  const after  = event.data.after.data();
  if (!after) return;

  const roomId  = event.params.roomId;
  const members = activeMembers(after);

  // Who spoke in this write?
  const spoke = members
    .filter(([uid, m]) => (m.daysSpoken?.length || 0) >
                          (before?.members?.[uid]?.daysSpoken?.length || 0))
    .map(([uid]) => uid);

  if (spoke.length > 0 && members.length === 2) {
    // DUO ONLY. A group never gets an immediate push — see the header note.
    for (const speaker of spoke) {
      const partner = members.find(([uid]) => uid !== speaker);
      if (!partner) continue;
      const [partnerUid] = partner;
      const m = after.members[speaker];
      const stamp = m.daysSpoken[m.daysSpoken.length - 1];

      // One push per speaker per day, however many times they write.
      if (after.lastNotifiedDay?.[speaker] === stamp) continue;
      await db.collection('standRooms').doc(roomId)
        .set({ lastNotifiedDay: { [speaker]: stamp } }, { merge: true });

      await push(partnerUid,
        `${m.name} spoke Day ${m.dayNumber}`,
        'Stand with them.',
        { deepLink: 'stand', roomId });
    }
  }

  // Everyone finished.
  const allDone = members.length > 0 &&
                  members.every(([, m]) => m.dayNumber >= ENFORCEMENT_LENGTH);
  if (allDone && !(after.notifiedMilestones || []).includes('all_day_7')) {
    await db.collection('standRooms').doc(roomId).set({
      status: 'completed',
      completedAt: FieldValue.serverTimestamp(),
      notifiedMilestones: FieldValue.arrayUnion('all_day_7'),
    }, { merge: true });

    for (const [uid] of members) {
      await push(uid, 'Your stand is finished',
        `Seven days, together. ${after.enforcement?.title || ''}`.trim(),
        { deepLink: 'stand', roomId });
      await rescheduleNudge(uid);   // a completed room stops nudging
    }
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// 6. standDailyNudge
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Recomputes when this user should next be nudged.
 *
 * One document per user rather than a scan over rooms: Firestore cannot query
 * inside a map, so finding "everyone due at 7pm local" by reading every room
 * does not scale past the first few thousand stands. Inverting it into a
 * single indexed timestamp keeps the scheduled pass to one page.
 */
async function rescheduleNudge(uid, tz, { missed = null } = {}) {
  const ref = db.collection('standNudges').doc(uid);
  const [snap, userSnap] = await Promise.all([
    ref.get(),
    db.collection('users').doc(uid).get(),
  ]);
  const prev = snap.exists ? snap.data() : {};
  const zone = safeTz(tz || prev.tz || userSnap.data()?.tz);

  const rooms = await db.collection('standRooms')
    .where('memberUids', 'array-contains', uid)
    .where('status', '==', 'active')
    .get();

  if (rooms.empty) {
    if (snap.exists) await ref.delete();
    return;
  }

  const misses = missed === null ? (prev.consecutiveMisses || 0) : missed;

  // Back-off is the feature, not an optimization. Someone who stopped speaking
  // is having the hardest week of their year; a daily "your turn" forever is
  // how this becomes the reason they delete the app.
  let days;
  if (misses <= 2) {
    days = 1;
  } else if (misses <= 5) {
    days = 3;
  } else {
    if (snap.exists) await ref.delete();
    return;
  }

  const hour = Number.isInteger(prev.nudgeHour) ? prev.nudgeHour : DEFAULT_NUDGE_HOUR;
  let next = nextLocalHour(zone, hour);
  if (days > 1) next = new Date(next.getTime() + (days - 1) * 86400000);

  await ref.set({
    uid,
    tz: zone,
    nudgeHour: hour,
    roomIds: rooms.docs.map((d) => d.id),
    nextNudgeAt: Timestamp.fromDate(next),
    consecutiveMisses: misses,
    lastNudgedAt: prev.lastNudgedAt || null,
    mutedUntil: prev.mutedUntil || null,
  }, { merge: true });
}

exports.standDailyNudge = onSchedule('every 60 minutes', async () => {
  const due = await db.collection('standNudges')
    .where('nextNudgeAt', '<=', Timestamp.now())
    .limit(500)
    .get();

  for (const nudgeDoc of due.docs) {
    const n = nudgeDoc.data();
    const uid = n.uid || nudgeDoc.id;
    try {
      if (n.mutedUntil && n.mutedUntil.toMillis() > Date.now()) {
        await rescheduleNudge(uid, n.tz);
        continue;
      }

      const stamp = localDayStamp(n.tz);
      let spokeToday = false;
      let othersToday = 0;
      let headline = null;
      let roomId = null;

      for (const id of n.roomIds || []) {
        const snap = await db.collection('standRooms').doc(id).get();
        if (!snap.exists) continue;
        const room = snap.data();
        if (room.status !== 'active') continue;
        const me = room.members?.[uid];
        if (!me || me.left) continue;

        if ((me.daysSpoken || []).includes(stamp)) { spokeToday = true; break; }

        const members = activeMembers(room);
        const others = members.filter(([id2, m]) =>
          id2 !== uid && (m.daysSpoken || []).includes(stamp));
        othersToday += others.length;

        if (others.length > 0 && !headline) {
          roomId = id;
          headline = members.length === 2
            ? `${others[0][1].name} spoke Day ${others[0][1].dayNumber}`
            : `${others.length} of ${members.length} have spoken today`;
        }
      }

      // Never nudge into silence. If nobody else has spoken either, a push
      // saying "your turn" is just an accusation. A nudge always means join
      // them, never you are failing.
      if (spokeToday || othersToday === 0 || !headline) {
        await rescheduleNudge(uid, n.tz,
          { missed: spokeToday ? 0 : (n.consecutiveMisses || 0) });
        continue;
      }

      const sent = await push(uid, headline, 'Stand with them.',
        { deepLink: 'stand', roomId: roomId || '' });

      await nudgeDoc.ref.set(
        { lastNudgedAt: FieldValue.serverTimestamp() }, { merge: true });

      await rescheduleNudge(uid, n.tz, {
        missed: sent ? (n.consecutiveMisses || 0) + 1 : (n.consecutiveMisses || 0),
      });
    } catch (err) {
      console.error(`standDailyNudge failed for ${uid}: ${err.message}`);
      // Never let one bad row (a deleted room, an unparseable tz) stall the
      // batch — push this user out an hour and carry on.
      await nudgeDoc.ref.set(
        { nextNudgeAt: Timestamp.fromMillis(Date.now() + 3600000) },
        { merge: true },
      ).catch(() => {});
    }
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// 7. Account merge (anonymous → Apple)
// ═══════════════════════════════════════════════════════════════════════════

exports.beginAccountMerge = onCall(async (request) => {
  const uid = requireAuth(request);
  const ticket = crypto.randomBytes(24).toString('base64url');
  await db.collection('accountMerges').doc(ticket).set({
    fromUid: uid,
    createdAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + MERGE_TICKET_TTL_MIN * 60000),
  });
  return { ticket };
});

/**
 * Moves an anonymous account's stand memberships onto the Apple account the
 * user just signed in as.
 *
 * `fromUid` comes off the server-issued ticket and `toUid` off the verified
 * caller token — never off the request body. A client that could name both
 * sides could graft itself onto any account whose uid it knew.
 *
 * Idempotent: the client persists the ticket and retries until it succeeds,
 * because the app can be killed between signing in and calling this.
 */
exports.completeAccountMerge = onCall(async (request) => {
  const toUid = requireAuth(request);
  const ticket = String(request.data?.ticket || '');
  const ticketRef = db.collection('accountMerges').doc(ticket);
  const ticketSnap = await ticketRef.get();
  if (!ticketSnap.exists) throw new HttpsError('not-found', 'Unknown or spent ticket.');

  const { fromUid, expiresAt } = ticketSnap.data();
  if (expiresAt && expiresAt.toMillis() < Date.now()) {
    await ticketRef.delete();
    throw new HttpsError('deadline-exceeded', 'That took too long. Try signing in again.');
  }
  if (fromUid === toUid) { await ticketRef.delete(); return { merged: 0 }; }

  const rooms = await db.collection('standRooms')
    .where('memberUids', 'array-contains', fromUid)
    .get();

  let merged = 0;
  for (const roomDoc of rooms.docs) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(roomDoc.ref);
      if (!snap.exists) return;
      const room = snap.data();
      const from = room.members?.[fromUid];
      if (!from) return;                    // already migrated; a retry no-ops
      const to = room.members?.[toUid];

      const next = to
        ? {
            // Both identities are in this room: the user joined their own
            // family's stand twice, once per account. Union the work rather
            // than picking a winner.
            ...to,
            dayNumber: Math.max(to.dayNumber || 0, from.dayNumber || 0),
            daysSpoken: Array.from(new Set([
              ...(to.daysSpoken || []), ...(from.daysSpoken || []),
            ])).sort().slice(-14),
            joinedAt: (to.joinedAt?.toMillis?.() || 0) <= (from.joinedAt?.toMillis?.() || 0)
              ? to.joinedAt : from.joinedAt,
            isOwner: !!(to.isOwner || from.isOwner),
            left: false,
            name: to.name || from.name,
          }
        : { ...from, left: false };

      tx.update(roomDoc.ref, {
        [`members.${toUid}`]: next,
        [`members.${fromUid}`]: FieldValue.delete(),
        memberUids: Array.from(new Set(
          (room.memberUids || []).filter((u) => u !== fromUid).concat(toUid))),
        lastActivityAt: FieldValue.serverTimestamp(),
      });
      merged += 1;
    });
    await db.collection('users').doc(toUid).set(
      { standRoomIds: FieldValue.arrayUnion(roomDoc.id) }, { merge: true });
  }

  // Carry the pass across, so signing in never costs someone access.
  const fromUser = await db.collection('users').doc(fromUid).get();
  const pass = fromUser.exists ? fromUser.data().standPass : null;
  if (pass?.expiresAt && pass.expiresAt.toMillis() > Date.now()) {
    const toUser = await db.collection('users').doc(toUid).get();
    const currently = toUser.exists ? toUser.data().standPass : null;
    if (!currently?.expiresAt || currently.expiresAt.toMillis() < pass.expiresAt.toMillis()) {
      await db.collection('users').doc(toUid).set({ standPass: pass }, { merge: true });
    }
  }

  await Promise.all([
    ticketRef.delete(),
    db.collection('users').doc(fromUid).delete().catch(() => {}),
    db.collection('standNudges').doc(fromUid).delete().catch(() => {}),
    auth.deleteUser(fromUid).catch(() => {}),
  ]);
  await rescheduleNudge(toUid);
  return { merged };
});

// ═══════════════════════════════════════════════════════════════════════════
// 8. deleteAccount — App Store 5.1.1(v)
// ═══════════════════════════════════════════════════════════════════════════

exports.deleteAccount = onCall(async (request) => {
  const uid = requireAuth(request);

  const rooms = await db.collection('standRooms')
    .where('memberUids', 'array-contains', uid).get();
  for (const roomDoc of rooms.docs) {
    // Removed outright, not tombstoned: the other members should see the
    // person gone, not a blank row where they used to be.
    await removeMember(uid, roomDoc.id, { wipeName: true });
    // update(), NOT set({...}, {merge:true}). Firestore only interprets a
    // dotted field path in update(); the same key handed to set() creates a
    // literal top-level field called "members.<uid>" and leaves the real
    // nested entry untouched — which left a deleted account's row sitting in
    // every stand it had joined.
    await db.collection('standRooms').doc(roomDoc.id)
      .update({ [`members.${uid}`]: FieldValue.delete() })
      .catch(() => {});
  }

  const invites = await db.collection('standInvites')
    .where('createdBy', '==', uid).get();
  await Promise.all(invites.docs.map((d) => d.ref.update({ revoked: true })));

  await Promise.all([
    db.collection('users').doc(uid).delete().catch(() => {}),
    db.collection('standNudges').doc(uid).delete().catch(() => {}),
  ]);
  await auth.deleteUser(uid).catch(() => {});
  return { ok: true };
});

// ═══════════════════════════════════════════════════════════════════════════
// 9. standSweep — orphans, dormancy, archival
// ═══════════════════════════════════════════════════════════════════════════

exports.standSweep = onSchedule('every 24 hours', async () => {
  const now = Date.now();
  const cutoff = (days) => Timestamp.fromMillis(now - days * 86400000);

  // Orphans: one member, invite never used. Left by someone who tapped Invite
  // and never sent it.
  const orphans = await db.collection('standRooms')
    .where('status', '==', 'active')
    .where('lastActivityAt', '<=', cutoff(ORPHAN_ROOM_DAYS))
    .limit(200).get();
  for (const d of orphans.docs) {
    const room = d.data();
    if ((room.memberUids || []).length > 1) continue;
    const invites = await db.collection('standInvites')
      .where('roomId', '==', d.id).get();
    if (invites.docs.some((i) => (i.data().uses || 0) > 0)) continue;
    await Promise.all(invites.docs.map((i) => i.ref.delete()));
    await db.collection('users').doc(room.createdBy)
      .set({ standRoomIds: FieldValue.arrayRemove(d.id) }, { merge: true })
      .catch(() => {});
    await d.ref.delete();
  }

  // Dormant: nobody has spoken in a fortnight. Stops the nudges without
  // deleting a campaign someone may still come back to — campaigns wait, they
  // do not expire, and that principle outlives the room.
  const stale = await db.collection('standRooms')
    .where('status', '==', 'active')
    .where('lastActivityAt', '<=', cutoff(DORMANT_AFTER_DAYS))
    .limit(200).get();
  for (const d of stale.docs) {
    await d.ref.update({ status: 'dormant' });
    for (const uid of d.data().memberUids || []) await rescheduleNudge(uid);
  }

  // Archive: names cleared, the room kept as a shell so a share card that
  // already went out still resolves to something.
  //
  // The status filter is load-bearing. Without it the query returned the
  // oldest 200 rooms by lastActivityAt regardless of whether they were already
  // archived — and since archiving does not touch lastActivityAt, the same 200
  // came back every single day and nothing past them was ever archived.
  // Filtering on status means archived rooms drop out of the result and the
  // sweep advances.
  for (const status of ['dormant', 'completed']) {
    const old = await db.collection('standRooms')
      .where('status', '==', status)
      .where('lastActivityAt', '<=', cutoff(ARCHIVE_AFTER_DAYS))
      .limit(200).get();
    for (const d of old.docs) {
      const cleared = {};
      for (const uid of Object.keys(d.data().members || {})) {
        cleared[`members.${uid}.name`] = '';
        cleared[`members.${uid}.initial`] = '';
      }
      await d.ref.update({ status: 'archived', ...cleared });
    }
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// Test seam
//
// Exported so functions/test/standTogether.test.js can exercise the pure
// helpers directly — code generation, timezone math, name sanitizing and
// campaign validation carry most of the sharp edges in this file, and none of
// them need a Firestore round trip to check.
// ═══════════════════════════════════════════════════════════════════════════

exports.__test = {
  generateCode, normalizeCode, safeTz, localDayStamp, nextLocalHour,
  sanitizeName, validateEnforcement, colorIndexFor, activeMembers,
  CODE_ALPHABET, CODE_LENGTH, MAX_MEMBERS,
};
