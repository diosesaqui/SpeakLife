/**
 * referrals.js
 * Firebase Cloud Functions (v2 HTTPS) — SpeakLife referral program.
 *
 * Program (v1, single-sided):
 *   A non-subscriber shares their personal code. When 3 NEW users join with it
 *   (and finish onboarding), the inviter is granted 1 free month of Premium via
 *   a RevenueCat *promotional* entitlement — no App Store purchase required.
 *
 * Why single-sided + non-subscribers only:
 *   - A RevenueCat promotional grant does NOT stop Apple from billing an active
 *     auto-renewable sub, so a "free month" only has cash value to someone who
 *     isn't currently paying. The earn-a-month UI is gated to non-subscribers on
 *     the client; this backend additionally refuses to count an invitee who is
 *     already Premium.
 *   - New users already get the app's 3-day onboarding trial, so the invitee
 *     isn't empty-handed without a separate referral reward.
 *
 * Endpoints (all POST, CORS on):
 *   getReferralCode    { appUserId } -> { code }
 *   redeemReferral     { inviteeAppUserId, code, source? } -> { success, reason?, ... }
 *   getReferralStatus  { appUserId } -> { code, successfulReferrals, rewardsEarned, referralsNeeded }
 *
 * Firestore (all server-only; clients read via getReferralStatus):
 *   referralCodes/{CODE}          { ownerAppUserId, createdAt }
 *   referralUsers/{appUserId}     { code, successfulReferrals, rewardsEarned,
 *                                   pendingRewards, createdAt, updatedAt }
 *   referrals/{inviteeAppUserId}  { code, inviterAppUserId, status, createdAt,
 *                                   qualifiedAt }   // doc-id == invitee => idempotent
 *
 * ─── Setup ──────────────────────────────────────────────────────────────────
 *  1. REVENUECAT_SECRET_KEY must be set (RC v1 secret key):
 *       firebase functions:secrets:set REVENUECAT_SECRET_KEY
 *     Without it, reward grants are skipped and left pending for later retry.
 *  2. firebase deploy --only functions:getReferralCode,functions:redeemReferral,functions:getReferralStatus
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// bibleChat.js / prayerWallNotifications.js also call initializeApp() at module
// load. When all are pulled in via index.js, guard against double-init.
if (getApps().length === 0) initializeApp();

const db = getFirestore();

// ─── Secrets ──────────────────────────────────────────────────────────────
const REVENUECAT_SECRET_KEY = defineSecret('REVENUECAT_SECRET_KEY');

// ─── Constants ──────────────────────────────────────────────────────────────
const PREMIUM_ENTITLEMENT = 'premium';
const REWARD_THRESHOLD = 3;          // friends per free month
const REWARD_DURATION = 'monthly';   // RC promotional duration => 1 month

// On-brand code words. Code = WORD + '-' + 3 unambiguous chars (e.g. GRACE-7K2).
const CODE_WORDS = [
  'GRACE', 'FAITH', 'LIGHT', 'HOPE', 'GLORY', 'PRAISE',
  'SHINE', 'RISE', 'BLESS', 'SPIRIT', 'MERCY', 'PSALM',
];
// No 0/O/1/I/L to keep codes easy to read aloud and type.
const CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

// ─── Helpers ────────────────────────────────────────────────────────────────

// appUserId is used directly as a Firestore document ID. Mirror the guard used
// in bibleChat.js so .doc() can't throw synchronously.
function isValidId(id) {
  return typeof id === 'string'
    && id.length > 0
    && id.length <= 1500
    && !id.includes('/')
    && id !== '.'
    && id !== '..';
}

function randomCode() {
  const word = CODE_WORDS[Math.floor(Math.random() * CODE_WORDS.length)];
  let suffix = '';
  for (let i = 0; i < 3; i++) {
    suffix += CODE_ALPHABET[Math.floor(Math.random() * CODE_ALPHABET.length)];
  }
  return `${word}-${suffix}`;
}

// Grant the inviter one promotional month of Premium via the RevenueCat REST
// API. Returns true on success, false otherwise (caller leaves it pending).
async function grantPromotionalMonth(appUserId, secretKey) {
  if (!secretKey) return false;
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}` +
        `/entitlements/${PREMIUM_ENTITLEMENT}/promotional`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${secretKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ duration: REWARD_DURATION }),
      }
    );
    if (!resp.ok) {
      console.warn(`RC promo grant ${resp.status} for ${appUserId}`);
      return false;
    }
    return true;
  } catch (err) {
    console.error('RC promo grant failed:', err.message);
    return false;
  }
}

// Authoritative premium check (true/false) or null when RC is unreachable. Same
// shape as bibleChat.js so a misconfigured key never wrongly blocks a redeem.
async function isPremiumViaRevenueCat(appUserId, secretKey) {
  if (!secretKey) return null;
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      { headers: { Authorization: `Bearer ${secretKey}` } }
    );
    if (!resp.ok) return null;
    const data = await resp.json();
    const ent = data && data.subscriber && data.subscriber.entitlements
      ? data.subscriber.entitlements[PREMIUM_ENTITLEMENT]
      : null;
    if (!ent) return false;
    if (!ent.expires_date) return true;
    return new Date(ent.expires_date).getTime() > Date.now();
  } catch (err) {
    console.error('RC check failed:', err.message);
    return null;
  }
}

// Reads/creates the caller's referral code, returning the user doc data.
async function ensureUserDoc(appUserId) {
  const userRef = db.collection('referralUsers').doc(appUserId);
  const snap = await userRef.get();
  if (snap.exists && snap.data().code) return snap.data();

  // Generate a collision-free code (a handful of attempts is plenty given the
  // keyspace; codes are per-user and low volume).
  let code = null;
  for (let attempt = 0; attempt < 8 && !code; attempt++) {
    const candidate = randomCode();
    const created = await db.runTransaction(async (t) => {
      const codeRef = db.collection('referralCodes').doc(candidate);
      const exists = (await t.get(codeRef)).exists;
      if (exists) return false;
      t.set(codeRef, {
        ownerAppUserId: appUserId,
        createdAt: FieldValue.serverTimestamp(),
      });
      return true;
    });
    if (created) code = candidate;
  }
  if (!code) throw new Error('could not allocate referral code');

  const base = {
    code,
    successfulReferrals: snap.exists ? (snap.data().successfulReferrals || 0) : 0,
    rewardsEarned: snap.exists ? (snap.data().rewardsEarned || 0) : 0,
    pendingRewards: snap.exists ? (snap.data().pendingRewards || 0) : 0,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!snap.exists) base.createdAt = FieldValue.serverTimestamp();
  await userRef.set(base, { merge: true });
  return { ...base, code };
}

// Best-effort: if a user has reward grants that failed to apply earlier, retry
// them now. Keeps the program self-healing without a separate cron.
async function reconcilePendingRewards(appUserId, secretKey) {
  const userRef = db.collection('referralUsers').doc(appUserId);
  const snap = await userRef.get();
  const pending = snap.exists ? (snap.data().pendingRewards || 0) : 0;
  if (pending <= 0) return;

  for (let i = 0; i < pending; i++) {
    const ok = await grantPromotionalMonth(appUserId, secretKey);
    if (!ok) break;
    await userRef.set({
      pendingRewards: FieldValue.increment(-1),
      rewardsEarned: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }
}

const referralsNeeded = (count) => REWARD_THRESHOLD - (count % REWARD_THRESHOLD);

// ═══════════════════════════════════════════════════════════════════════════
// getReferralCode — POST { appUserId } -> { code }
// ═══════════════════════════════════════════════════════════════════════════
exports.getReferralCode = onRequest(
  { region: 'us-central1', cors: true, timeoutSeconds: 20 },
  async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
    const appUserId = ((req.body || {}).appUserId || '').toString().trim();
    if (!isValidId(appUserId)) return res.status(400).json({ error: 'invalid appUserId' });

    try {
      const user = await ensureUserDoc(appUserId);
      return res.json({ code: user.code });
    } catch (err) {
      console.error('getReferralCode failed:', err.message);
      return res.status(500).json({ error: 'internal' });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// redeemReferral — POST { inviteeAppUserId, code, source? }
//   -> { success, reason?, referralsNeeded? }
// Called when a referred user finishes onboarding. Idempotent per invitee.
// ═══════════════════════════════════════════════════════════════════════════
exports.redeemReferral = onRequest(
  { region: 'us-central1', cors: true, secrets: [REVENUECAT_SECRET_KEY], timeoutSeconds: 30 },
  async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });

    const body = req.body || {};
    const inviteeAppUserId = (body.inviteeAppUserId || '').toString().trim();
    const code = (body.code || '').toString().trim().toUpperCase();

    if (!isValidId(inviteeAppUserId)) return res.status(400).json({ error: 'invalid inviteeAppUserId' });
    if (!code) return res.status(400).json({ error: 'missing code' });

    const secretKey = REVENUECAT_SECRET_KEY.value();

    try {
      // One referral per invitee, ever (doc-id == invitee).
      const referralRef = db.collection('referrals').doc(inviteeAppUserId);
      if ((await referralRef.get()).exists) {
        return res.json({ success: false, reason: 'already_redeemed' });
      }

      // Resolve the code to its owner.
      const codeSnap = await db.collection('referralCodes').doc(code).get();
      if (!codeSnap.exists) return res.json({ success: false, reason: 'invalid_code' });
      const inviterAppUserId = codeSnap.data().ownerAppUserId;

      if (inviterAppUserId === inviteeAppUserId) {
        return res.json({ success: false, reason: 'self_referral' });
      }

      // Referrals are for NEW users. If RC says the invitee is already Premium,
      // refuse. (null == RC unreachable => allow; idempotency still bounds abuse.)
      const inviteePremium = await isPremiumViaRevenueCat(inviteeAppUserId, secretKey);
      if (inviteePremium === true) {
        return res.json({ success: false, reason: 'already_premium' });
      }

      // Atomically record the qualified referral and bump the inviter's count.
      const inviterRef = db.collection('referralUsers').doc(inviterAppUserId);
      const result = await db.runTransaction(async (t) => {
        if ((await t.get(referralRef)).exists) return { duplicate: true };
        const inviterSnap = await t.get(inviterRef);
        const before = inviterSnap.exists ? (inviterSnap.data().successfulReferrals || 0) : 0;
        const newCount = before + 1;
        const rewardDue = newCount % REWARD_THRESHOLD === 0;

        t.set(referralRef, {
          code,
          inviterAppUserId,
          status: 'qualified',
          source: (body.source || 'unknown').toString().slice(0, 32),
          createdAt: FieldValue.serverTimestamp(),
          qualifiedAt: FieldValue.serverTimestamp(),
        });
        t.set(inviterRef, {
          successfulReferrals: FieldValue.increment(1),
          ...(rewardDue ? { pendingRewards: FieldValue.increment(1) } : {}),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        return { rewardDue, newCount };
      });

      if (result.duplicate) return res.json({ success: false, reason: 'already_redeemed' });

      // Grant the month outside the transaction (network call). On failure it
      // stays in pendingRewards and is retried on the inviter's next status read.
      if (result.rewardDue) {
        const granted = await grantPromotionalMonth(inviterAppUserId, secretKey);
        if (granted) {
          await inviterRef.set({
            pendingRewards: FieldValue.increment(-1),
            rewardsEarned: FieldValue.increment(1),
            updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      }

      return res.json({ success: true, referralsNeeded: referralsNeeded(result.newCount) });
    } catch (err) {
      console.error('redeemReferral failed:', err.message);
      return res.status(500).json({ error: 'internal' });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// getReferralStatus — POST { appUserId }
//   -> { code, successfulReferrals, rewardsEarned, referralsNeeded }
// ═══════════════════════════════════════════════════════════════════════════
exports.getReferralStatus = onRequest(
  { region: 'us-central1', cors: true, secrets: [REVENUECAT_SECRET_KEY], timeoutSeconds: 20 },
  async (req, res) => {
    if (req.method !== 'POST') return res.status(405).json({ error: 'method_not_allowed' });
    const appUserId = ((req.body || {}).appUserId || '').toString().trim();
    if (!isValidId(appUserId)) return res.status(400).json({ error: 'invalid appUserId' });

    try {
      const user = await ensureUserDoc(appUserId);
      // Retry any rewards that failed to apply earlier.
      await reconcilePendingRewards(appUserId, REVENUECAT_SECRET_KEY.value());

      const snap = await db.collection('referralUsers').doc(appUserId).get();
      const data = snap.exists ? snap.data() : {};
      const count = data.successfulReferrals || 0;
      return res.json({
        code: user.code,
        successfulReferrals: count,
        rewardsEarned: data.rewardsEarned || 0,
        referralsNeeded: referralsNeeded(count),
      });
    } catch (err) {
      console.error('getReferralStatus failed:', err.message);
      return res.status(500).json({ error: 'internal' });
    }
  }
);
