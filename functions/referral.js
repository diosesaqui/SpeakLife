/**
 * referral.js
 * Firebase Cloud Functions v2 — Invite friends, get a year free
 *
 * Full design and the reasons behind it: docs/REFERRAL_YEAR_FREE_SPEC.md.
 * Every case below has a test row in docs/REFERRAL_BE_TDD.md.
 *
 * Rules that carry the feature and should not be tidied away:
 *
 *  1. THE SERVER DECIDES EVERYTHING THAT MATTERS. Counting, the target, the
 *     cheating checks and handing out offer codes all happen here. Every
 *     referral collection is closed to clients in firestore.rules except the
 *     referrer's own record, which they may read and never write.
 *
 *  2. A FRIEND IS COUNTED EXACTLY ONCE. referralClaims/{friendUid} makes a
 *     friend's first final outcome permanent, and the credit, the count and
 *     the claim are written in one transaction.
 *
 *  3. THE POOL IS A PILE OF FREE YEARS. A reward code is assigned inside the
 *     same transaction that unlocks, so two concurrent unlocks can never get
 *     the same code, and a code that has been handed to anyone is never put
 *     back unless it was certainly never seen (the merge's 24-hour rule).
 *
 *  4. NO DIRECT CLOCK OR RANDOMNESS. Everything reads now() and newCode(),
 *     which the tests replace through __test. Codes come from the crypto
 *     generator in inviteCode.js.
 */

const { onCall, HttpsError }     = require('firebase-functions/v2/https');
const { onSchedule }             = require('firebase-functions/v2/scheduler');
const { defineSecret }           = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging }           = require('firebase-admin/messaging');
const { CODE_ALPHABET, CODE_LENGTH, generateCode, normalizeCode } = require('./inviteCode');
const DeviceCheck                = require('./deviceCheck');

if (getApps().length === 0) initializeApp();

const db        = getFirestore();
const messaging = getMessaging();

// Apple DeviceCheck credentials (App Store Connect → Keys → DeviceCheck).
// Declared here, bound to the functions that use them below, never logged.
const DEVICECHECK_KEY_P8  = defineSecret('DEVICECHECK_KEY_P8');
const DEVICECHECK_KEY_ID  = defineSecret('DEVICECHECK_KEY_ID');
const DEVICECHECK_TEAM_ID = defineSecret('DEVICECHECK_TEAM_ID');
const SECRETS = [DEVICECHECK_KEY_P8, DEVICECHECK_KEY_ID, DEVICECHECK_TEAM_ID];

// ─── Constants ──────────────────────────────────────────────────────────────

const DAY_MS  = 86400000;
const HOUR_MS = 3600000;
const CLOCK_SKEW_MS          = 5 * 60000;
const CODE_ATTEMPTS          = 5;
const ENROLL_CALLS_PER_HOUR  = 20;
const CLAIM_CALLS_PER_HOUR   = 10;
const REISSUE_CALLS_PER_HOUR = 5;
const MAX_REISSUES           = 1;
const POOL_LOW_WARNING       = 100;
const BIT_RETRY_MAX_ATTEMPTS = 14;
const SOURCES = ['deferred', 'universal_link', 'manual'];

// dailyCap MUST stay below target: the target_reached check runs first, so a
// cap at or above the target can never fire (BE-HLP-14b).
const DEFAULT_CONFIG = Object.freeze({
  enabled: false, target: 5, windowDays: 14, dailyCap: 3, minCodeValidityDays: 30,
  claimGraceDays: 30,
});

// ─── Injection seams (tests only) ───────────────────────────────────────────

// The only references to the system clock and the real code generator. Tests
// replace both through __test; nothing else in this file reads either.
let clock = Date.now;
let codeGenerator = null;
let deviceCheckOverride = null;
let deviceCheckClient = null;

const now = () => clock();
const newCode = () => (codeGenerator ? codeGenerator() : generateCode());

/**
 * The DeviceCheck client. Built on first use, so a test (or an emulator run)
 * that injected a fake never touches the secrets.
 */
function deviceCheck() {
  if (deviceCheckOverride) return deviceCheckOverride;
  if (!deviceCheckClient) {
    deviceCheckClient = DeviceCheck.createAppleDeviceCheck({
      keyP8: DEVICECHECK_KEY_P8.value(),
      keyId: DEVICECHECK_KEY_ID.value(),
      teamId: DEVICECHECK_TEAM_ID.value(),
      now,
    });
  }
  return deviceCheckClient;
}

// ═══ Pure helpers ═══════════════════════════════════════════════════════════

/** Timestamp, Date, millis or null → millis or null. */
function toMs(v) {
  if (v == null) return null;
  if (typeof v === 'number') return Number.isFinite(v) ? v : null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  return null;
}

const positiveInt = (v, fallback) => (Number.isInteger(v) && v >= 1 ? v : fallback);

/**
 * referralConfig/current → a complete config. A missing document is the
 * defaults with the switch OFF; a partial one fills its gaps from the
 * defaults. Only a literal `true` turns the feature on.
 */
function readConfig(data) {
  const d = data && typeof data === 'object' ? data : {};
  return {
    enabled: d.enabled === true,
    target: positiveInt(d.target, DEFAULT_CONFIG.target),
    windowDays: positiveInt(d.windowDays, DEFAULT_CONFIG.windowDays),
    dailyCap: positiveInt(d.dailyCap, DEFAULT_CONFIG.dailyCap),
    minCodeValidityDays: positiveInt(d.minCodeValidityDays, DEFAULT_CONFIG.minCodeValidityDays),
    claimGraceDays: positiveInt(d.claimGraceDays, DEFAULT_CONFIG.claimGraceDays),
  };
}

/**
 * D8: the friend must finish onboarding within `windowDays` of capturing the
 * link. All times in epoch millis. Returns 'ok', 'expired' or
 * 'invalid_argument'.
 *
 * A capture time in the future (beyond clock skew) is a forged or broken
 * clock.
 *
 * Deliberately NOT compared with the friend's account creation time. The app
 * creates that account at claim time, after onboarding, so a link captured at
 * first launch always predates it; comparing them expired nearly every real
 * friend. A previous install's link cannot carry over anyway: the pending
 * value lives in UserDefaults, which deleting the app wipes.
 */
/**
 * D8, measured where it means something: the friend must FINISH ONBOARDING
 * within `windowDays` of capturing the link, and the claim must then arrive
 * within `claimGraceDays` of that. Measuring capture-to-claim instead lost
 * friends who onboarded on day 12, hit a transient failure and did not
 * reopen the app for three days. `onboardedAt` is optional: without it the
 * window runs to now, the old rule.
 */
function validateWindow(capturedAt, onboardedAt, nowMs, { windowDays, claimGraceDays }) {
  if (typeof capturedAt !== 'number' || !Number.isFinite(capturedAt)) return 'invalid_argument';
  if (onboardedAt === undefined || onboardedAt === null) {
    return validateCapturedAt(capturedAt, null, nowMs, windowDays);
  }
  if (typeof onboardedAt !== 'number' || !Number.isFinite(onboardedAt)) return 'invalid_argument';
  if (capturedAt > nowMs + CLOCK_SKEW_MS) return 'expired';
  if (onboardedAt > nowMs + CLOCK_SKEW_MS) return 'expired';
  if (onboardedAt < capturedAt - CLOCK_SKEW_MS) return 'expired';
  if (onboardedAt - capturedAt > windowDays * DAY_MS) return 'expired';
  if (nowMs - onboardedAt > claimGraceDays * DAY_MS) return 'expired';
  return 'ok';
}

function validateCapturedAt(capturedAt, _accountCreatedAt, nowMs, windowDays) {
  if (typeof capturedAt !== 'number' || !Number.isFinite(capturedAt)) return 'invalid_argument';
  if (capturedAt > nowMs + CLOCK_SKEW_MS) return 'expired';
  if (nowMs - capturedAt > windowDays * DAY_MS) return 'expired';
  return 'ok';
}

/**
 * The unassigned, unretired code with the soonest expiry that is still valid
 * for at least `minValidityDays`, or null. Soonest first, so the pool is used
 * before it rots.
 */
function pickRewardCode(pool, nowMs, minValidityDays) {
  const floor = nowMs + minValidityDays * DAY_MS;
  let best = null;
  for (const entry of pool || []) {
    if (!entry || entry.assignedTo != null || entry.retired) continue;
    const exp = toMs(entry.expiresAt);
    if (exp == null || exp < floor) continue;
    if (!best || exp < toMs(best.expiresAt)) best = entry;
  }
  return best;
}

/**
 * The referral merge, as a pure plan. `a` is the anonymous source, `b` the
 * signed-in target; each is { record, credits: {friendUid: credit} } or null.
 * Returns null when there is nothing to do, otherwise:
 *
 *   { record, credits, keepCode, aliasCode,
 *     retireRewardCodes, needsRewardCode }
 *
 * `record` is the target's new referral record. If `needsRewardCode` is set,
 * the caller assigns one from the pool in the same transaction.
 */
function mergeReferrals(a, b, toUid, nowMs) {
  if (!a) return null;   // only the target has one (or neither): unchanged
  if (!b) {
    return {
      record: { ...a.record, uid: toUid },
      credits: { ...a.credits },
      keepCode: a.record.code,
      aliasCode: null,
      retireRewardCodes: [],
      needsRewardCode: false,
    };
  }

  // Union of credits, keyed by friend: a friend credited to both identities
  // counts once. Keep the earlier credit.
  const credits = { ...b.credits };
  for (const [f, c] of Object.entries(a.credits)) {
    if (!credits[f] || (toMs(c.creditedAt) ?? Infinity) < (toMs(credits[f].creditedAt) ?? Infinity)) {
      credits[f] = c;
    }
  }
  const count = Object.keys(credits).length;

  // The code with more credits is the one the record shows. The other stays
  // live as an alias for the same record: friends were already sent it, and
  // revoking it dropped every one of them who had not finished onboarding.
  // A tie shows the signed-in account's own code.
  const aCredits = Object.keys(a.credits).length;
  const bCredits = Object.keys(b.credits).length;
  const keep   = aCredits > bCredits ? a.record : b.record;
  const revoke = keep === a.record ? b.record : a.record;

  const target = Math.min(positiveInt(a.record.target, DEFAULT_CONFIG.target),
                          positiveInt(b.record.target, DEFAULT_CONFIG.target));

  // Rewards: keep the earlier and retire the other. Never back to the pool:
  // a code is redeemable the moment it is assigned (push, Redeem button), so
  // no age makes it safe to hand to someone else.
  const ra = a.record.reward || null;
  const rb = b.record.reward || null;
  let reward = ra || rb;
  const retireRewardCodes = [];
  if (ra && rb) {
    const [kept, other] = (toMs(ra.assignedAt) ?? Infinity) <= (toMs(rb.assignedAt) ?? Infinity)
      ? [ra, rb] : [rb, ra];
    reward = kept;
    retireRewardCodes.push(other.code);
  }

  const unlockedTimes = [a.record.unlockedAt, b.record.unlockedAt]
    .map(toMs).filter((t) => t != null);
  const firstUnlock = unlockedTimes.length ? Math.min(...unlockedTimes) : null;

  let status = 'active';
  let needsRewardCode = false;
  if (reward) status = 'unlocked';
  else if (count >= target) { status = 'unlocked_pending_code'; needsRewardCode = true; }

  const createdTimes = [a.record.createdAt, b.record.createdAt].map(toMs).filter((t) => t != null);

  return {
    record: {
      ...b.record,
      uid: toUid,
      code: keep.code,
      target,
      count,
      status,
      createdAt: createdTimes.length ? Math.min(...createdTimes) : nowMs,
      updatedAt: nowMs,
      unlockedAt: status === 'active' ? null : (firstUnlock ?? nowMs),
      reward,
    },
    credits,
    keepCode: keep.code,
    aliasCode: revoke.code === keep.code ? null : revoke.code,
    retireRewardCodes,
    needsRewardCode,
  };
}

// ═══ Effectful helpers ══════════════════════════════════════════════════════

const ts = (ms) => Timestamp.fromMillis(ms);

function requireAuth(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');
  return uid;
}

async function loadConfig() {
  const snap = await db.collection('referralConfig').doc('current').get();
  return readConfig(snap.exists ? snap.data() : undefined);
}

/**
 * Sliding-window counter, the same shape as standRateLimits. The guard on an
 * 8-character code: it runs before any lookup, so a miss costs an attempt.
 */
async function throttle(uid, bucket, limit, windowMs) {
  const ref = db.collection('referralRateLimits').doc(`${uid}|${bucket}`);
  const t = now();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : {};
    const start = data.windowStart || 0;
    const count = data.count || 0;
    if (t - start > windowMs) {
      tx.set(ref, { windowStart: t, count: 1 });
      return;
    }
    if (count >= limit) {
      throw new HttpsError('resource-exhausted', 'Too many attempts. Try again later.');
    }
    tx.set(ref, { windowStart: start, count: count + 1 }, { merge: true });
  });
}

/** What a client is told about its own record. Never credits, never uids. */
function view(record) {
  const r = record.reward;
  return {
    code: record.code,
    count: record.count || 0,
    target: record.target,
    status: record.status,
    reward: r ? {
      code: r.code,
      assignedAt: toMs(r.assignedAt),
      expiresAt: toMs(r.expiresAt),
      reissueCount: r.reissueCount || 0,
    } : null,
  };
}

// ─── Push ───────────────────────────────────────────────────────────────────

const PUSH_CREDIT = (count, target) => `A friend joined. ${count} of ${target}.`;
const PUSH_UNLOCK = 'You did it. Your free year is ready.';

/**
 * One push to a referrer. Counts only: a friend's name, uid or device never
 * appears in a push. A failure is logged and swallowed, because a push must
 * never fail the claim that caused it.
 */
async function push(uid, body) {
  try {
    const snap = await db.collection('users').doc(uid).get();
    const token = snap.exists ? snap.data().fcmToken : null;
    if (!token) return false;
    await messaging.send({
      token,
      notification: { body },
      data: { notificationType: 'referral', deepLink: 'referral' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return true;
  } catch (err) {
    if (err.code === 'messaging/registration-token-not-registered') {
      await db.collection('users').doc(uid)
        .set({ fcmToken: FieldValue.delete() }, { merge: true }).catch(() => {});
    }
    console.error(`referral push failed for ${uid}: ${err.message}`);
    return false;
  }
}

// ─── DeviceCheck bits ───────────────────────────────────────────────────────

/**
 * Sets a DeviceCheck bit, or queues it for referralSweep. A bit failure never
 * blocks a credit or an enrollment; the sweep retries it.
 */
async function setBitOrQueue(deviceToken, bit, isDevelopment) {
  try {
    await deviceCheck().setBit(deviceToken, bit, { isDevelopment });
    return true;
  } catch (err) {
    console.error(`referral: DeviceCheck bit ${bit} update failed (${err.kind || 'error'}), queued`);
    await db.collection('referralBitRetries').add({
      deviceToken, bit, isDevelopment: !!isDevelopment, attempts: 0, createdAt: ts(now()),
    });
    return false;
  }
}

// ─── The offer code pool ────────────────────────────────────────────────────

/**
 * Unassigned codes valid for at least `minDays`, soonest expiry first.
 * Retired codes keep their `assignedTo`, so they never match. Needs the
 * (assignedTo, expiresAt) composite index in firestore.indexes.json.
 */
function poolQuery(t, minDays, limit) {
  let q = db.collection('referralRewardCodes')
    .where('assignedTo', '==', null)
    .where('expiresAt', '>=', ts(t + minDays * DAY_MS))
    .orderBy('expiresAt');
  if (limit) q = q.limit(limit);
  return q;
}

/** Reads candidate codes inside `tx` and picks one (or null). Reads only. */
async function pickInTx(tx, t, minDays) {
  const snap = await tx.get(poolQuery(t, minDays, 10));
  const entries = snap.docs.map((d) => ({ ...d.data(), code: d.data().code || d.id, ref: d.ref }));
  return pickRewardCode(entries, t, minDays);
}

/** Marks `picked` as assigned to `uid` inside `tx`; returns the reward. */
function assignInTx(tx, picked, uid, t, reissueCount) {
  tx.update(picked.ref, { assignedTo: uid, assignedAt: ts(t) });
  return {
    code: picked.code,
    assignedAt: ts(t),
    expiresAt: picked.expiresAt,
    reissueCount,
  };
}

/**
 * The client reports capture time in epoch millis. A value small enough to be
 * seconds (before 1973 in millis) is read as seconds, so a client that sends
 * Date().timeIntervalSince1970 is not silently treated as fifty years expired.
 */
function captureMs(raw) {
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return raw;
  return raw < 1e11 ? raw * 1000 : raw;
}

const outcomeOf = (claimData) => (claimData.outcome === 'credited'
  ? { outcome: 'credited' }
  : { outcome: claimData.outcome, reason: claimData.reason });

// ═══════════════════════════════════════════════════════════════════════════
// 1. getOrCreateReferral — the referrer's code and progress (§8.1)
// ═══════════════════════════════════════════════════════════════════════════

exports.getOrCreateReferral = onCall({ secrets: SECRETS }, async (request) => {
  const uid = requireAuth(request);
  const { deviceToken, isDevelopment } = request.data || {};
  await throttle(uid, 'getOrCreateReferral', ENROLL_CALLS_PER_HOUR, HOUR_MS);

  const ref = db.collection('referrals').doc(uid);
  const existing = await ref.get();
  // Idempotent, and readable with the switch off: progress already made, and
  // a reward already earned, never disappear.
  if (existing.exists) return view(existing.data());

  const config = await loadConfig();
  if (!config.enabled) {
    throw new HttpsError('failed-precondition', 'Referrals are not available right now.');
  }

  for (let attempt = 0; attempt < CODE_ATTEMPTS; attempt++) {
    const code = newCode();
    const codeRef = db.collection('referralCodes').doc(code);
    const t = now();
    const result = await db.runTransaction(async (tx) => {
      const [mine, taken] = await Promise.all([tx.get(ref), tx.get(codeRef)]);
      if (mine.exists) return { record: mine.data(), created: false };
      if (taken.exists) return { collision: true };
      const record = {
        uid, code,
        target: config.target,          // locked now, so the goalposts never move (D3)
        count: 0,
        status: 'active',
        createdAt: ts(t), updatedAt: ts(t),
        unlockedAt: null,
        reward: null,
      };
      tx.set(codeRef, { uid, createdAt: ts(t), revoked: false });
      tx.set(ref, record);
      return { record, created: true };
    });
    if (result.collision) continue;

    if (result.created) {
      if (typeof deviceToken === 'string' && deviceToken) {
        await setBitOrQueue(deviceToken, 1, !!isDevelopment);
      } else {
        console.warn(`getOrCreateReferral: no deviceToken for ${uid}; enrolled without bit 1`);
      }
    }
    return view(result.record);
  }
  throw new HttpsError('internal', 'Could not create a referral code. Try again.');
});

// ═══════════════════════════════════════════════════════════════════════════
// 2. claimReferral — a friend finished onboarding (§7, §8.2)
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Records a final rejection. A friend who already has a final claim keeps it:
 * the first outcome is returned instead (§6, referralClaims).
 */
async function rejectFinal(claimRef, base, reason) {
  try {
    await claimRef.create({ ...base, outcome: 'rejected', reason, createdAt: ts(now()) });
    return { outcome: 'rejected', reason };
  } catch (err) {
    if (err.code === 6 || /already exists/i.test(err.message || '')) {
      return outcomeOf((await claimRef.get()).data());
    }
    throw err;
  }
}

/**
 * A rejection that is NOT recorded: the friend may claim again with another
 * code. Used for a code that does not resolve to a referrer, so a typo in
 * "Have an invite code?" is not a lifetime lockout. Guessing stays bounded by
 * the per-friend throttle (#3), and a guessed code only credits a referrer
 * from a fresh, DeviceCheck-verified device.
 */
function rejectRetryable(reason) {
  return { outcome: 'rejected', reason };
}

exports.claimReferral = onCall({ secrets: SECRETS }, async (request) => {
  // §7 #1. Not final: the same claim can still count if the switch comes back
  // on within the window, so nothing is written.
  const config = await loadConfig();
  if (!config.enabled) return { outcome: 'rejected', reason: 'disabled' };

  const friendUid = requireAuth(request);                                 // #2
  await throttle(friendUid, 'claimReferral', CLAIM_CALLS_PER_HOUR, HOUR_MS); // #3

  const { code: rawCode, source, deviceToken, isDevelopment } = request.data || {};
  const capturedAt = captureMs(request.data?.capturedAt);
  const rawOnboarded = request.data?.onboardedAt;
  const onboardedAt = rawOnboarded === undefined || rawOnboarded === null ? undefined : captureMs(rawOnboarded);
  if (!SOURCES.includes(source)) {
    throw new HttpsError('invalid-argument', 'Unknown source.');
  }
  if (validateWindow(capturedAt, onboardedAt, now(), config) === 'invalid_argument') {
    throw new HttpsError('invalid-argument', 'capturedAt and onboardedAt must be epoch milliseconds.');
  }

  const code = normalizeCode(rawCode);
  const claimRef = db.collection('referralClaims').doc(friendUid);
  const base = { friendUid, code: code || null, referrerUid: null, source };

  if (!code) return rejectRetryable('invalid_code');                       // #4, not final

  const prior = await claimRef.get();                                     // #5
  if (prior.exists) return outcomeOf(prior.data());

  const codeSnap = await db.collection('referralCodes').doc(code).get();  // #6
  if (!codeSnap.exists || codeSnap.data().revoked) {
    return rejectRetryable('unknown_code');                               // not final
  }
  const referrerUid = codeSnap.data().uid;
  base.referrerUid = referrerUid;

  if (referrerUid === friendUid) return rejectFinal(claimRef, base, 'self_referral'); // #7

  if (validateWindow(capturedAt, onboardedAt, now(), config) !== 'ok') {      // #8
    return rejectFinal(claimRef, base, 'expired');
  }

  // #9. Apple is only ever asked about a claim that got this far, so junk
  // codes generate no DeviceCheck traffic. If Apple is unreachable, the
  // decision is deferred to #12 so the cheaper final checks still apply.
  // No token is a client-side failure (DCDevice can fail transiently), not a
  // verdict on the device, so it is never final: the app keeps the claim and
  // retries. A token Apple rejects outright is final (below).
  if (typeof deviceToken !== 'string' || !deviceToken) {
    return { outcome: 'retry_later' };
  }
  let appleDown = false;
  try {
    const bits = await deviceCheck().queryBits(deviceToken, { isDevelopment: !!isDevelopment });
    if (bits.bit0) return rejectFinal(claimRef, base, 'device_already_counted');
    // Bit 1 set by this same friend enrolling (e.g. the hard-paywall link
    // during onboarding, before their own claim) is not a referrer farming
    // their own phone. Bit 0 still limits the device to one credit ever.
    if (bits.bit1 && !(await db.collection('referrals').doc(friendUid).get()).exists) {
      return rejectFinal(claimRef, base, 'device_is_referrer');
    }
  } catch (err) {
    if (err.kind === 'invalid_token') return rejectFinal(claimRef, base, 'device_unverifiable');
    console.error(`claimReferral: DeviceCheck unavailable (${err.message}); retry_later`);
    appleDown = true;
  }

  const referralRef = db.collection('referrals').doc(referrerUid);
  const creditRef = referralRef.collection('credits').doc(friendUid);
  const t = now();

  const result = await db.runTransaction(async (tx) => {
    const [claimSnap, refSnap, recent] = await Promise.all([
      tx.get(claimRef),
      tx.get(referralRef),
      tx.get(referralRef.collection('credits').where('creditedAt', '>', ts(t - DAY_MS))),
    ]);
    if (claimSnap.exists) return { response: outcomeOf(claimSnap.data()) };

    // The code resolved but the record is gone: a merge re-keyed it between
    // the lookup and here. Retrying resolves the code to its new owner.
    if (!refSnap.exists) return { response: { outcome: 'retry_later' } };

    const r = refSnap.data();
    const count = r.count || 0;
    // #10. Not final: two friends racing for the last slot must not leave the
    // loser unable to count for anyone else who invited them.
    if (r.status !== 'active' || count >= r.target) return { response: rejectRetryable('target_reached') };
    if (recent.size >= config.dailyCap) return { response: { outcome: 'retry_later' } };  // #11
    if (appleDown) return { response: { outcome: 'retry_later' } };                       // #12

    const newCount = count + 1;
    const update = { count: newCount, updatedAt: ts(t) };
    let unlocked = false;
    if (newCount >= r.target) {
      // The unlock and the code assignment are one transaction, so two
      // referrers unlocking at once can never be handed the same code.
      const picked = await pickInTx(tx, t, config.minCodeValidityDays);
      update.unlockedAt = ts(t);
      if (picked) {
        update.status = 'unlocked';
        update.reward = assignInTx(tx, picked, referrerUid, t, 0);
        unlocked = true;
      } else {
        update.status = 'unlocked_pending_code';
        console.warn(`claimReferral: pool empty at unlock for ${referrerUid}; sweep will assign`);
      }
    }

    tx.set(creditRef, { friendUid, creditedAt: ts(t), source, deviceVerified: true });
    tx.update(referralRef, update);
    tx.set(claimRef, { ...base, outcome: 'credited', reason: null, createdAt: ts(t) });
    return {
      response: { outcome: 'credited' },
      credited: true, unlocked, count: newCount, target: r.target,
    };
  });

  if (result.credited) {
    await setBitOrQueue(deviceToken, 0, !!isDevelopment);
    await push(referrerUid, result.unlocked ? PUSH_UNLOCK : PUSH_CREDIT(result.count, result.target));
  }
  return result.response;
});

// ═══════════════════════════════════════════════════════════════════════════
// 3. reissueReferralReward — "my code didn't work" (§8.3)
// ═══════════════════════════════════════════════════════════════════════════

exports.reissueReferralReward = onCall(async (request) => {
  const uid = requireAuth(request);
  await throttle(uid, 'reissueReferralReward', REISSUE_CALLS_PER_HOUR, HOUR_MS);
  const config = await loadConfig();
  const ref = db.collection('referrals').doc(uid);
  const t = now();

  // Deliberately not gated on the kill switch: a reward already earned stays
  // usable whatever happens to the feature.
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const r = snap.exists ? snap.data() : null;
    if (!r || r.status !== 'unlocked' || !r.reward?.code) {
      throw new HttpsError('failed-precondition', 'There is no reward to replace.');
    }
    if ((r.reward.reissueCount || 0) >= MAX_REISSUES) {
      throw new HttpsError('resource-exhausted', 'This reward was already replaced. Contact support.');
    }
    const picked = await pickInTx(tx, t, config.minCodeValidityDays);
    if (!picked) throw new HttpsError('unavailable', 'No codes available right now. Try again later.');

    // The old code is retired, never returned: it may already be redeemed.
    tx.set(db.collection('referralRewardCodes').doc(r.reward.code),
      { retired: true, retiredAt: ts(t) }, { merge: true });
    const reward = assignInTx(tx, picked, uid, t, (r.reward.reissueCount || 0) + 1);
    tx.update(ref, { reward, updatedAt: ts(t) });
    return { reward: view({ reward }).reward };
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// 4. referralSweep — pending codes, bit retries, pool level (§8.5)
// ═══════════════════════════════════════════════════════════════════════════

/** Codes to referrers who unlocked while the pool was empty, oldest first. */
async function assignPendingRewards(config) {
  const pending = await db.collection('referrals')
    .where('status', '==', 'unlocked_pending_code').limit(500).get();

  // Sorted here rather than with orderBy: a document missing `unlockedAt`
  // would silently drop out of an ordered query and never be looked at.
  const valid = [];
  for (const d of pending.docs) {
    const r = d.data();
    if (toMs(r.unlockedAt) == null || !Number.isInteger(r.target) || typeof r.count !== 'number') {
      console.error(`referralSweep: skipping malformed referral ${d.id}`);
      continue;
    }
    valid.push({ ref: d.ref, unlockedAt: toMs(r.unlockedAt) });
  }
  valid.sort((a, b) => a.unlockedAt - b.unlockedAt);

  for (const { ref } of valid) {
    try {
      const t = now();
      const outcome = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists || snap.data().status !== 'unlocked_pending_code') return 'skip';
        const picked = await pickInTx(tx, t, config.minCodeValidityDays);
        if (!picked) return 'empty';
        tx.update(ref, {
          status: 'unlocked',
          reward: assignInTx(tx, picked, ref.id, t, 0),
          updatedAt: ts(t),
        });
        return 'assigned';
      });
      if (outcome === 'empty') break;
      if (outcome === 'assigned') await push(ref.id, PUSH_UNLOCK);
    } catch (err) {
      console.error(`referralSweep: assigning ${ref.id} failed: ${err.message}`);
    }
  }
}

/** Retries DeviceCheck bit updates that failed after a credit or enrollment. */
async function retryBits() {
  const queued = await db.collection('referralBitRetries').limit(500).get();
  for (const d of queued.docs) {
    const q = d.data();
    try {
      await deviceCheck().setBit(q.deviceToken, q.bit, { isDevelopment: !!q.isDevelopment });
      await d.ref.delete();
    } catch (err) {
      const attempts = (q.attempts || 0) + 1;
      // A token Apple calls invalid will never succeed; neither will one that
      // has failed for two weeks (DeviceCheck tokens do not live that long).
      if (err.kind === 'invalid_token' || attempts >= BIT_RETRY_MAX_ATTEMPTS) {
        console.error(`referralSweep: dropping bit ${q.bit} retry after ${attempts} attempts (${err.kind || err.message})`);
        await d.ref.delete();
      } else {
        await d.ref.update({ attempts, lastError: String(err.kind || 'error') });
      }
    }
  }
}

/**
 * Warns when fewer than POOL_LOW_WARNING codes are unassigned and valid for
 * the minimum. A log-based alert in Google Cloud matches REFERRAL_POOL_LOW.
 */
async function checkPoolLevel(config) {
  const agg = await poolQuery(now(), config.minCodeValidityDays).count().get();
  const n = agg.data().count;
  if (n < POOL_LOW_WARNING) {
    console.warn(`REFERRAL_POOL_LOW: ${n} unassigned offer codes valid for ` +
      `${config.minCodeValidityDays}+ days (threshold ${POOL_LOW_WARNING})`);
  }
  return n;
}

exports.referralSweep = onSchedule({ schedule: 'every 24 hours', secrets: SECRETS }, async () => {
  const config = await loadConfig();
  for (const [name, step] of [
    ['assignPendingRewards', () => assignPendingRewards(config)],
    ['retryBits', retryBits],
    ['checkPoolLevel', () => checkPoolLevel(config)],
  ]) {
    try { await step(); } catch (err) {
      console.error(`referralSweep: ${name} failed: ${err.message}`);
    }
  }
});

// ═══════════════════════════════════════════════════════════════════════════
// 5. Account hooks, called from standTogether.js (§8.6)
// ═══════════════════════════════════════════════════════════════════════════

const asTs = (v) => (typeof v === 'number' ? ts(v) : v);

/**
 * Anonymous `fromUid` signed in with Apple as `toUid`: move or merge their
 * referral record (rules in mergeReferrals). One transaction, and idempotent:
 * once the source record is gone, a retry finds nothing to do.
 */
async function mergeReferralAccounts(fromUid, toUid) {
  if (!fromUid || !toUid || fromUid === toUid) return { merged: false };
  const config = await loadConfig();
  const fromRef = db.collection('referrals').doc(fromUid);
  const toRef = db.collection('referrals').doc(toUid);
  const pool = (code) => db.collection('referralRewardCodes').doc(code);
  const t = now();

  return db.runTransaction(async (tx) => {
    // ── reads ──
    const [fromSnap, toSnap] = await Promise.all([tx.get(fromRef), tx.get(toRef)]);
    if (!fromSnap.exists) return { merged: false };
    const [fromCredits, toCredits] = await Promise.all([
      tx.get(fromRef.collection('credits')),
      toSnap.exists ? tx.get(toRef.collection('credits')) : Promise.resolve(null),
    ]);
    const side = (snap, creditSnap) => ({
      record: snap.data(),
      credits: Object.fromEntries(creditSnap.docs.map((d) => [d.id, d.data()])),
    });
    const plan = mergeReferrals(side(fromSnap, fromCredits),
      toSnap.exists ? side(toSnap, toCredits) : null, toUid, t);

    const picked = plan.needsRewardCode
      ? await pickInTx(tx, t, config.minCodeValidityDays) : null;
    const keptRewardCode = plan.record.reward?.code || null;
    const touched = [keptRewardCode, ...plan.retireRewardCodes]
      .filter(Boolean);
    const poolSnaps = touched.length ? await tx.getAll(...touched.map(pool)) : [];
    const poolExists = new Set(poolSnaps.filter((s) => s.exists).map((s) => s.id));

    // ── writes ──
    const record = {
      ...plan.record,
      createdAt: asTs(plan.record.createdAt),
      updatedAt: ts(t),
      unlockedAt: asTs(plan.record.unlockedAt),
    };
    if (picked) {
      record.reward = assignInTx(tx, picked, toUid, t, 0);
      record.status = 'unlocked';
    }
    tx.set(toRef, record);
    for (const [f, c] of Object.entries(plan.credits)) {
      tx.set(toRef.collection('credits').doc(f), c);
    }
    for (const d of fromCredits.docs) tx.delete(d.ref);
    tx.delete(fromRef);

    tx.set(db.collection('referralCodes').doc(plan.keepCode),
      { uid: toUid, revoked: false }, { merge: true });
    if (plan.aliasCode) {
      tx.set(db.collection('referralCodes').doc(plan.aliasCode),
        { uid: toUid, revoked: false, aliasOf: plan.keepCode }, { merge: true });
    }
    if (keptRewardCode && poolExists.has(keptRewardCode)) {
      tx.update(pool(keptRewardCode), { assignedTo: toUid });
    }
    for (const c of plan.retireRewardCodes) {
      if (poolExists.has(c)) tx.update(pool(c), { retired: true, retiredAt: ts(t) });
    }
    return { merged: true };
  });
}

/**
 * Account deletion: the record and its credits go, every code the uid owned
 * is revoked (a shared link then reads as unknown), and an assigned reward is
 * retired rather than returned, since it may already have been redeemed.
 *
 * referralClaims where this uid was the FRIEND are kept on purpose: they hold
 * nothing beyond uids, and they are what stops delete-and-reinstall farming.
 */
async function deleteReferralData(uid) {
  const ref = db.collection('referrals').doc(uid);
  const [snap, codes] = await Promise.all([
    ref.get(),
    db.collection('referralCodes').where('uid', '==', uid).get(),
  ]);
  const t = now();
  const batch = db.batch();
  for (const d of codes.docs) batch.update(d.ref, { revoked: true, revokedAt: ts(t) });
  const rewardCode = snap.exists ? snap.data().reward?.code : null;
  if (rewardCode) {
    const p = await db.collection('referralRewardCodes').doc(rewardCode).get();
    if (p.exists) batch.update(p.ref, { retired: true, retiredAt: ts(t) });
  }
  await batch.commit();
  if (snap.exists) await db.recursiveDelete(ref);
}

// Plain functions, not Cloud Functions: firebase deploy ignores exports
// without a trigger, and standTogether.js calls these from its own handlers.
exports.__accountHooks = { mergeReferralAccounts, deleteReferralData };

// ═══ Test seam ══════════════════════════════════════════════════════════════

exports.__test = {
  generateCode, normalizeCode, CODE_ALPHABET, CODE_LENGTH,
  validateCapturedAt, validateWindow, pickRewardCode, readConfig, mergeReferrals, toMs,
  DEFAULT_CONFIG,
  setNow(fn) { clock = fn || Date.now; },
  setDeviceCheck(fake) { deviceCheckOverride = fake || null; },
  setCodeGenerator(fn) { codeGenerator = fn || null; },
};
