/**
 * gifting.js
 * Firebase Cloud Functions (v2 HTTPS) — gift subscriptions.
 *
 *   giftCreate  POST { appUserId, jws, recipientNote? }
 *               → { transactionId, quantity,
 *                   gifts: [{ code, display, status, redeemedAt }] }
 *               Idempotent on the Apple transaction id, and returns live
 *               status, so replaying a device's signed transactions through it
 *               is also how the app rebuilds its "My Gifts" list.
 *
 *   giftRedeem  POST { code, appUserId }
 *               → { ok, kind, grantDuration, expiresAt }
 *
 * ─── Why the client's word is never trusted ─────────────────────────────────
 * A gift is a thing of value minted on request, so the request has to prove it
 * was paid for. The proof is Apple's own signature: the app buys the consumable
 * directly through StoreKit 2 with `Product.PurchaseOption.quantity(n)` and
 * sends us the transaction's `jwsRepresentation`. We verify that JWS offline
 * against Apple's root certificates and read productId, quantity and
 * transactionId out of the *verified* payload. Nothing about what the gift is
 * worth ever comes from the request body.
 *
 * RevenueCat cannot do this job: it records that a consumable was bought but
 * does not carry the quantity, so it cannot tell one gift from five. RevenueCat
 * keeps the half it is good at — granting the recipient's entitlement.
 *
 * ─── Setup ──────────────────────────────────────────────────────────────────
 *  1. npm install                      (adds @apple/app-store-server-library)
 *  2. Drop Apple's root certificates into functions/certs — see certs/README.md
 *  3. Secret (already set for bibleChat, shared here):
 *       firebase functions:secrets:set REVENUECAT_SECRET_KEY
 *  4. firebase deploy --only functions:giftCreate,functions:giftRedeem
 *  5. firebase deploy --only firestore:rules,firestore:indexes
 * ─────────────────────────────────────────────────────────────────────────────
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { SignedDataVerifier, Environment } = require('@apple/app-store-server-library');

const core = require('./giftingCore');

// bibleChat.js and prayerWallNotifications.js also call initializeApp() at
// module load. When all are pulled in via index.js, guard against double-init.
if (getApps().length === 0) initializeApp();

const db = getFirestore();

// ─── Secrets ────────────────────────────────────────────────────────────────
// Same secret bibleChat already uses. Firebase dedupes by name, so declaring it
// here does not create a second one.
const REVENUECAT_SECRET_KEY = defineSecret('REVENUECAT_SECRET_KEY');

// ─── Constants ──────────────────────────────────────────────────────────────
const BUNDLE_ID = 'com.Franchiz.SpeakLife';
const APP_APPLE_ID = 1617492998;
const PREMIUM_ENTITLEMENT = 'premium';

// Apple's own recommendation is to leave revocation checking on. It costs a
// round trip to Apple per verification, which is acceptable here: this runs
// once per purchase, not once per screen.
const ENABLE_ONLINE_CHECKS = true;

// Brute-forcing an 8-glyph code needs ~10^11 guesses on average; this caps a
// single user at 10 an hour, which makes that impossible rather than merely
// impractical.
const REDEEM_ATTEMPT_LIMIT = 10;
const REDEEM_ATTEMPT_WINDOW_MS = 60 * 60 * 1000;

// Firestore rejects a transaction that touches too many documents; 10 gift docs
// plus a batch doc is comfortably inside the limit.
const MAX_CODE_COLLISION_RETRIES = 5;

// ─── Apple signature verification ───────────────────────────────────────────

let cachedRootCAs = null;

/**
 * Apple's root certificates, read from functions/certs. They are public
 * downloads, not secrets, but they are binary so they live as files rather than
 * in an env var. A missing directory is a deploy mistake, not a runtime
 * condition, so it throws loudly instead of degrading to "trust the client".
 */
function loadRootCAs() {
  if (cachedRootCAs) return cachedRootCAs;

  const dir = path.join(__dirname, 'certs');
  let files = [];
  try {
    files = fs.readdirSync(dir).filter((f) => f.endsWith('.cer'));
  } catch (err) {
    throw new Error(
      `functions/certs is missing (${err.code}). Apple's root certificates are ` +
      'required to verify purchases — see functions/certs/README.md.'
    );
  }
  if (files.length === 0) {
    throw new Error(
      'functions/certs contains no .cer files. Apple\'s root certificates are ' +
      'required to verify purchases — see functions/certs/README.md.'
    );
  }

  cachedRootCAs = files.sort().map((f) => fs.readFileSync(path.join(dir, f)));
  return cachedRootCAs;
}

const verifierCache = new Map();

function verifierFor(environment) {
  if (!verifierCache.has(environment)) {
    verifierCache.set(
      environment,
      new SignedDataVerifier(
        loadRootCAs(),
        ENABLE_ONLINE_CHECKS,
        environment,
        BUNDLE_ID,
        APP_APPLE_ID
      )
    );
  }
  return verifierCache.get(environment);
}

/**
 * Verifies a StoreKit 2 signed transaction and returns its decoded payload.
 *
 * The environment is not in the request — a sandbox tester and a paying
 * customer send the same shaped JWS — so production is tried first and sandbox
 * second. Note that Xcode's StoreKit Testing signs with a local CA that Apple's
 * roots do not chain to, so sandbox testing needs a real Sandbox Apple ID.
 */
async function verifyTransaction(jws) {
  const attempts = [Environment.PRODUCTION, Environment.SANDBOX];
  let lastError = null;

  for (const environment of attempts) {
    try {
      const payload = await verifierFor(environment).verifyAndDecodeTransaction(jws);
      return { ok: true, payload, environment };
    } catch (err) {
      lastError = err;
    }
  }

  console.error('Apple JWS verification failed:', lastError && lastError.message);
  return { ok: false, error: lastError };
}

// ─── RevenueCat ─────────────────────────────────────────────────────────────

/**
 * Grants the premium entitlement promotionally. Returns true on success.
 *
 * This is the only step that actually hands someone premium, so a failure here
 * must never leave a code marked as spent — see the rollback in giftRedeem.
 */
async function grantPromotionalEntitlement(appUserId, body, secretKey) {
  const url =
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}` +
    `/entitlements/${PREMIUM_ENTITLEMENT}/promotional`;

  try {
    const resp = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    if (!resp.ok) {
      console.error('RevenueCat grant failed:', resp.status, await resp.text());
      return false;
    }
    return true;
  } catch (err) {
    console.error('RevenueCat grant error:', err.message);
    return false;
  }
}

// ─── Rate limiting ──────────────────────────────────────────────────────────

async function withinRedeemRateLimit(appUserId, nowMs) {
  const ref = db.collection('giftRedeemAttempts').doc(appUserId);
  return db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    const data = snap.exists ? snap.data() : null;

    const windowExpired =
      !data || nowMs - (data.windowStartMs || 0) > REDEEM_ATTEMPT_WINDOW_MS;

    if (windowExpired) {
      t.set(ref, { windowStartMs: nowMs, count: 1 });
      return true;
    }
    if ((data.count || 0) >= REDEEM_ATTEMPT_LIMIT) return false;

    t.update(ref, { count: FieldValue.increment(1) });
    return true;
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// giftCreate — POST { appUserId, jws, recipientNote? }
// ═══════════════════════════════════════════════════════════════════════════
exports.giftCreate = onRequest(
  {
    region: 'us-central1',
    cors: true,
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const body = req.body || {};
    const appUserId = typeof body.appUserId === 'string' ? body.appUserId.trim() : '';
    const jws = typeof body.jws === 'string' ? body.jws.trim() : '';

    if (!core.isSafeDocId(appUserId) || !jws) {
      res.status(400).json({ error: 'missing appUserId or jws' });
      return;
    }

    // ─── Proof of purchase ───────────────────────────────────────────────
    const verified = await verifyTransaction(jws);
    if (!verified.ok) {
      res.status(400).json({ error: 'invalid_transaction' });
      return;
    }

    const check = core.validateTransaction(verified.payload);
    if (!check.ok) {
      console.warn('giftCreate rejected transaction:', check.reason);
      res.status(400).json({ error: check.reason });
      return;
    }

    const { transactionId, productId, quantity, purchasedAtMs, duration } = check.value;
    const note = core.sanitizeNote(body.recipientNote);
    const batchRef = db.collection('giftBatches').doc(transactionId);

    // ─── Mint, idempotently ──────────────────────────────────────────────
    // The Apple transaction id is the key, so a retry after a dropped response
    // returns the codes that already exist rather than minting a second set.
    let codes;
    try {
      codes = await db.runTransaction(async (t) => {
        const existing = await t.get(batchRef);
        if (existing.exists) return existing.data().codes;

        // Generate and check for collisions inside the transaction, so a code
        // cannot be claimed by a concurrent batch between check and write.
        let candidates = null;
        for (let attempt = 0; attempt < MAX_CODE_COLLISION_RETRIES; attempt++) {
          const tryCodes = Array.from({ length: quantity }, () =>
            core.generateCode(crypto.randomBytes)
          );
          if (new Set(tryCodes).size !== tryCodes.length) continue;

          const refs = tryCodes.map((c) => db.collection('gifts').doc(c));
          const snaps = await t.getAll(...refs);
          if (snaps.every((s) => !s.exists)) {
            candidates = tryCodes;
            break;
          }
        }
        if (!candidates) throw new Error('code_generation_exhausted');

        const purchasedAt = Timestamp.fromMillis(purchasedAtMs);
        const expiresUnredeemedAt = Timestamp.fromMillis(core.codeExpiryMs(purchasedAtMs));

        t.set(batchRef, {
          transactionId,
          purchaserAppUserId: appUserId,
          productId,
          quantity,
          codes: candidates,
          environment: verified.environment,
          purchasedAt,
          refundedAt: null,
        });

        for (const code of candidates) {
          t.set(db.collection('gifts').doc(code), {
            code,
            batchId: transactionId,
            status: 'unredeemed',
            productId,
            grantDuration: duration,
            purchaserAppUserId: appUserId,
            purchasedAt,
            expiresUnredeemedAt,
            recipientNote: note,
            redeemedAt: null,
            redeemedByAppUserId: null,
            grantedUntil: null,
            reclaimCount: 0,
            reclaims: [],
            revokedReason: null,
          });
        }

        return candidates;
      });
    } catch (err) {
      console.error('giftCreate mint failed:', err.message);
      res.status(500).json({ error: 'mint_failed' });
      return;
    }

    // ─── Current state of each code ──────────────────────────────────────
    // Read back after the commit so the response carries live status, which is
    // what makes this endpoint double as the recovery path: the app can rebuild
    // "My Gifts" by replaying the device's own signed transactions through
    // here. No separate list endpoint, and therefore no endpoint that hands out
    // codes to anyone who can guess an appUserId.
    let gifts;
    try {
      const snaps = await db.getAll(...codes.map((c) => db.collection('gifts').doc(c)));
      gifts = snaps.map((snap) => {
        const g = snap.data() || {};
        return {
          code: snap.id,
          display: core.formatCode(snap.id),
          status: g.status || 'unknown',
          redeemedAt: g.redeemedAt ? g.redeemedAt.toDate().toISOString() : null,
        };
      });
    } catch (err) {
      // The codes are safely committed; only the status decoration failed.
      console.error('giftCreate status read failed:', err.message);
      gifts = codes.map((code) => ({
        code,
        display: core.formatCode(code),
        status: 'unknown',
        redeemedAt: null,
      }));
    }

    console.log(
      `giftCreate: ${gifts.length} code(s) for ${productId} ` +
      `(txn ${transactionId}, ${verified.environment})`
    );

    res.json({ transactionId, quantity, gifts });
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// giftRedeem — POST { code, appUserId }
// ═══════════════════════════════════════════════════════════════════════════
exports.giftRedeem = onRequest(
  {
    region: 'us-central1',
    cors: true,
    secrets: [REVENUECAT_SECRET_KEY],
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const body = req.body || {};
    const appUserId = typeof body.appUserId === 'string' ? body.appUserId.trim() : '';
    const code = core.normalizeCode(body.code);

    if (!core.isSafeDocId(appUserId)) {
      res.status(400).json({ error: 'missing appUserId' });
      return;
    }
    if (!code) {
      res.status(400).json({ error: 'invalid_code' });
      return;
    }

    const secretKey = REVENUECAT_SECRET_KEY.value();
    if (!secretKey) {
      // Without the secret we cannot grant anything, and marking the code spent
      // would destroy it. Fail closed and leave the gift intact.
      console.error('giftRedeem: REVENUECAT_SECRET_KEY is unset');
      res.status(503).json({ error: 'grant_unavailable' });
      return;
    }

    const nowMs = Date.now();

    if (!(await withinRedeemRateLimit(appUserId, nowMs))) {
      res.status(429).json({ error: 'too_many_attempts' });
      return;
    }

    const giftRef = db.collection('gifts').doc(code);

    // ─── Claim the code ──────────────────────────────────────────────────
    // Marked spent first, inside a transaction, so two people racing on the
    // same code cannot both win. If the grant then fails we put it back.
    let claim;
    try {
      claim = await db.runTransaction(async (t) => {
        const snap = await t.get(giftRef);
        const data = snap.exists ? snap.data() : null;

        const gift = data && {
          status: data.status,
          purchaserAppUserId: data.purchaserAppUserId,
          redeemedByAppUserId: data.redeemedByAppUserId,
          grantDuration: data.grantDuration,
          grantedUntilMs: data.grantedUntil ? data.grantedUntil.toMillis() : null,
          expiresUnredeemedAtMs: data.expiresUnredeemedAt
            ? data.expiresUnredeemedAt.toMillis()
            : 0,
          reclaimCount: data.reclaimCount || 0,
        };

        const decision = core.decideRedemption({ gift, appUserId, nowMs });
        if (!decision.ok) return { decision, previous: null, gift };

        if (decision.kind === 'idempotent') {
          // Nothing to write; the grant is re-sent below in case the previous
          // attempt died between marking and granting.
          return { decision, previous: null, gift };
        }

        const previous = {
          status: data.status,
          redeemedAt: data.redeemedAt,
          redeemedByAppUserId: data.redeemedByAppUserId,
          grantedUntil: data.grantedUntil,
          reclaimCount: data.reclaimCount || 0,
        };

        if (decision.kind === 'first') {
          const endMs = core.grantEndMs(gift.grantDuration, nowMs);
          t.update(giftRef, {
            status: 'redeemed',
            redeemedAt: Timestamp.fromMillis(nowMs),
            redeemedByAppUserId: appUserId,
            grantedUntil: endMs === null ? null : Timestamp.fromMillis(endMs),
          });
        } else {
          t.update(giftRef, {
            redeemedByAppUserId: appUserId,
            reclaimCount: FieldValue.increment(1),
            reclaims: FieldValue.arrayUnion({
              appUserId,
              at: Timestamp.fromMillis(nowMs),
            }),
          });
        }

        return { decision, previous, gift };
      });
    } catch (err) {
      console.error('giftRedeem claim failed:', err.message);
      res.status(500).json({ error: 'claim_failed' });
      return;
    }

    if (!claim.decision.ok) {
      res.status(400).json({ error: claim.decision.reason });
      return;
    }

    // ─── Grant ───────────────────────────────────────────────────────────
    const { gift, decision, previous } = claim;
    const grantedUntilMs =
      decision.kind === 'first'
        ? core.grantEndMs(gift.grantDuration, nowMs)
        : gift.grantedUntilMs;

    const granted = await grantPromotionalEntitlement(
      appUserId,
      core.promotionalGrantBody({
        duration: gift.grantDuration,
        kind: decision.kind,
        grantedUntilMs,
      }),
      secretKey
    );

    if (!granted) {
      // Put the code back exactly as it was. A gift is worth real money, so a
      // RevenueCat outage must cost the user a retry, not the gift itself.
      if (previous) {
        try {
          await giftRef.update(previous);
        } catch (err) {
          console.error('giftRedeem rollback failed:', code, err.message);
        }
      }
      res.status(502).json({ error: 'grant_failed' });
      return;
    }

    console.log(`giftRedeem: ${code} ${decision.kind} by ${appUserId}`);

    res.json({
      ok: true,
      kind: decision.kind,
      grantDuration: gift.grantDuration,
      expiresAt: grantedUntilMs === null ? null : new Date(grantedUntilMs).toISOString(),
    });
  }
);
