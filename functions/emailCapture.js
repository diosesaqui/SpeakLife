/**
 * emailCapture — onboarding email collection.
 *
 * The app posts an address from the pre-paywall onboarding screen; this module
 * is the only thing that ever touches it. Two jobs, in this order:
 *
 *   1. Write it to Firestore (`emailSubscribers/{sha256(email)}`). This is the
 *      source of truth and it is what makes the address OURS — it survives a
 *      Klaviyo outage, a rotated key, and a decision to move off Klaviyo
 *      entirely.
 *   2. Subscribe it to the Klaviyo list, so it is usable for campaigns without
 *      anyone exporting anything by hand.
 *
 * Step 2 failing NEVER fails the request. An address written to Firestore but
 * not yet in Klaviyo is a sync to retry (`retryKlaviyoSync` below); an address
 * rejected at the door because Klaviyo was down is gone for good, and the user
 * is already past the screen. So the client gets a 200 as soon as the write
 * lands, and the doc carries `klaviyoStatus` for the retry sweep to find.
 *
 * Setup:
 *   firebase functions:secrets:set KLAVIYO_API_KEY     # private key, pk_...
 *   firebase functions:secrets:set KLAVIYO_LIST_ID     # e.g. WaeTSA ("Email List")
 *
 * The private key is a secret and stays server-side. It is never shipped in the
 * app binary, which is the whole reason this function exists instead of the
 * client calling Klaviyo directly.
 */

const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

if (admin.apps.length === 0) admin.initializeApp();
const db = admin.firestore();

const KLAVIYO_API_KEY = defineSecret('KLAVIYO_API_KEY');
const KLAVIYO_LIST_ID = defineSecret('KLAVIYO_LIST_ID');

const COLLECTION = 'emailSubscribers';

// Pinned deliberately. Klaviyo versions its API by date and an unpinned client
// gets moved onto breaking changes without a deploy on our side.
const KLAVIYO_REVISION = '2024-10-15';
const KLAVIYO_SUBSCRIBE_URL =
  'https://a.klaviyo.com/api/profile-subscription-bulk-create-jobs/';

// Length caps. RFC 5321 puts the real ceiling at 254; everything else is a
// free-text field we stamp on the profile and never render as HTML.
const MAX_EMAIL_LENGTH = 254;
const MAX_FIELD_LENGTH = 120;

// Retry ceiling. Ten sweeps an hour apart is ~10 hours of trying; past that the
// failure is structural (bad key, deleted list) and retrying forever just
// burns invocations while hiding the real problem in the logs.
const MAX_RETRIES = 10;
const RETRY_BATCH_SIZE = 100;

// ═══════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════

/**
 * Deliberately permissive: one @, something either side, a dot in the domain.
 * A stricter regex rejects valid addresses (plus-addressing, new TLDs, unicode
 * domains) and every one of those is a subscriber we just threw away. Klaviyo
 * does the authoritative validation on its end.
 */
function isValidEmail(value) {
  if (typeof value !== 'string') return false;
  const trimmed = value.trim();
  if (trimmed.length === 0 || trimmed.length > MAX_EMAIL_LENGTH) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed);
}

/** Lowercased and trimmed, so the same person typing `Me@X.com` twice is one doc. */
function normalizeEmail(value) {
  return value.trim().toLowerCase();
}

/**
 * Doc id is the hash, not the address. Firestore ids show up in logs, console
 * URLs and error traces; a hash keeps the address itself in the document body
 * where the security rules actually cover it. It also sidesteps `/` and `..`,
 * which are legal in an email local part and would make `.doc()` throw.
 */
function docIdFor(normalizedEmail) {
  return crypto.createHash('sha256').update(normalizedEmail).digest('hex');
}

/** Trimmed, capped, and empty-to-null so blank strings never reach Klaviyo. */
function cleanField(value) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim().slice(0, MAX_FIELD_LENGTH);
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Subscribe one address to the list, with marketing consent.
 *
 * Uses the bulk subscribe job because it is the only endpoint that creates or
 * updates the profile AND records consent in one call — a plain profile upsert
 * leaves the person unsubscribed, i.e. collected but unmailable.
 *
 * Returns { ok: true } or { ok: false, error, status }. Never throws: the
 * caller's contract with the client is that Klaviyo cannot fail the request.
 */
async function subscribeToKlaviyo({ apiKey, listId, email, properties }) {
  const profile = {
    type: 'profile',
    attributes: {
      email,
      subscriptions: { email: { marketing: { consent: 'SUBSCRIBED' } } },
    },
  };
  // Only stamp properties we actually have — an object of nulls overwrites
  // good values from an earlier submission with nothing.
  const stamped = Object.fromEntries(
    Object.entries(properties || {}).filter(([, v]) => v != null)
  );
  if (Object.keys(stamped).length > 0) profile.attributes.properties = stamped;

  const body = {
    data: {
      type: 'profile-subscription-bulk-create-job',
      attributes: {
        profiles: { data: [profile] },
        // false = a real, current opt-in (the user just typed it in the app),
        // which is what lets welcome flows trigger. `true` would import it as
        // backdated history and silently skip those flows.
        historical_import: false,
      },
      relationships: { list: { data: { type: 'list', id: listId } } },
    },
  };

  try {
    const res = await fetch(KLAVIYO_SUBSCRIBE_URL, {
      method: 'POST',
      headers: {
        Authorization: `Klaviyo-API-Key ${apiKey}`,
        revision: KLAVIYO_REVISION,
        'content-type': 'application/json',
        accept: 'application/vnd.api+json',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(10000),
    });

    // The job endpoint answers 202 Accepted on success and has no body.
    if (res.status === 202 || res.status === 200) return { ok: true };

    const text = await res.text().catch(() => '');
    return { ok: false, status: res.status, error: text.slice(0, 500) };
  } catch (err) {
    return { ok: false, status: 0, error: String(err && err.message).slice(0, 500) };
  }
}

/** Shared by the live path and the retry sweep so they can never drift. */
function klaviyoResultFields(result) {
  if (result.ok) {
    return {
      klaviyoStatus: 'synced',
      klaviyoSyncedAt: admin.firestore.FieldValue.serverTimestamp(),
      klaviyoError: admin.firestore.FieldValue.delete(),
    };
  }
  return {
    klaviyoStatus: 'pending',
    klaviyoError: `${result.status || 0}: ${result.error || 'unknown'}`,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// collectEmail — POST { email, appUserId?, source?, variant?, burden? }
//   → 200 { ok: true, klaviyo: 'synced' | 'pending' }
//   → 400 { error: 'invalid_email' | 'missing_email' }
// ═══════════════════════════════════════════════════════════════════════════
exports.collectEmail = onRequest(
  {
    region: 'us-central1',
    cors: true,
    secrets: [KLAVIYO_API_KEY, KLAVIYO_LIST_ID],
    timeoutSeconds: 20,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const body = req.body || {};
    const rawEmail = body.email;

    if (typeof rawEmail !== 'string' || rawEmail.trim().length === 0) {
      res.status(400).json({ error: 'missing_email' });
      return;
    }
    if (!isValidEmail(rawEmail)) {
      res.status(400).json({ error: 'invalid_email' });
      return;
    }

    const email = normalizeEmail(rawEmail);
    const docId = docIdFor(email);

    const appUserId = cleanField(body.appUserId);
    const source = cleanField(body.source) || 'onboarding';
    const variant = cleanField(body.variant);
    const burden = cleanField(body.burden);

    const ref = db.collection(COLLECTION).doc(docId);

    // ─── 1. Firestore: the address is ours the moment this returns ───────
    try {
      const existing = await ref.get();
      const payload = {
        email,
        appUserId,
        source,
        variant,
        burden,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        klaviyoStatus: 'pending',
        retryCount: 0,
      };
      // Stamped on the first write only. A returning user re-submitting the
      // same address must not look like a brand new subscriber, so this is
      // conditional rather than part of the merge.
      if (!existing.exists) {
        payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }
      await ref.set(payload, { merge: true });
    } catch (err) {
      logger.error('collectEmail: Firestore write failed', err);
      res.status(500).json({ error: 'storage_failed' });
      return;
    }

    // ─── 2. Klaviyo: best effort, never fatal ────────────────────────────
    const apiKey = KLAVIYO_API_KEY.value();
    const listId = KLAVIYO_LIST_ID.value();

    if (!apiKey || !listId) {
      // Unconfigured is not an error the user should feel. The address is
      // already saved; the sweep picks it up once the secrets are set.
      logger.warn('collectEmail: Klaviyo secrets unset — stored locally only');
      res.json({ ok: true, klaviyo: 'pending' });
      return;
    }

    const result = await subscribeToKlaviyo({
      apiKey,
      listId,
      email,
      properties: {
        speaklife_source: source,
        speaklife_onboarding_variant: variant,
        speaklife_burden: burden,
      },
    });

    await ref.update(klaviyoResultFields(result)).catch((err) => {
      logger.error('collectEmail: status update failed', err);
    });

    if (!result.ok) {
      logger.warn('collectEmail: Klaviyo subscribe failed, queued for retry', {
        status: result.status,
        error: result.error,
      });
    }

    res.json({ ok: true, klaviyo: result.ok ? 'synced' : 'pending' });
  }
);

// ═══════════════════════════════════════════════════════════════════════════
// retryKlaviyoSync — hourly sweep for addresses Firestore has and Klaviyo
// doesn't.
//
// Without this, any address collected while Klaviyo was down, rate-limiting, or
// misconfigured sits in Firestore forever and never receives a single email —
// collected but worthless, and invisible unless someone reads the logs.
// ═══════════════════════════════════════════════════════════════════════════
exports.retryKlaviyoSync = onSchedule(
  {
    schedule: 'every 60 minutes',
    region: 'us-central1',
    secrets: [KLAVIYO_API_KEY, KLAVIYO_LIST_ID],
    timeoutSeconds: 540,
  },
  async () => {
    const apiKey = KLAVIYO_API_KEY.value();
    const listId = KLAVIYO_LIST_ID.value();
    if (!apiKey || !listId) {
      logger.warn('retryKlaviyoSync: Klaviyo secrets unset — nothing to do');
      return;
    }

    const snap = await db
      .collection(COLLECTION)
      .where('klaviyoStatus', '==', 'pending')
      .where('retryCount', '<', MAX_RETRIES)
      .limit(RETRY_BATCH_SIZE)
      .get();

    if (snap.empty) return;

    let synced = 0;
    let stillFailing = 0;

    // Sequential on purpose. This is a backlog drain, not a latency path, and
    // firing a hundred parallel requests at Klaviyo is how a recovering API
    // starts rate-limiting us again.
    for (const doc of snap.docs) {
      const data = doc.data();
      if (!data.email) continue;

      const result = await subscribeToKlaviyo({
        apiKey,
        listId,
        email: data.email,
        properties: {
          speaklife_source: data.source,
          speaklife_onboarding_variant: data.variant,
          speaklife_burden: data.burden,
        },
      });

      const update = klaviyoResultFields(result);
      if (!result.ok) {
        update.retryCount = (data.retryCount || 0) + 1;
        stillFailing += 1;
      } else {
        synced += 1;
      }
      await doc.ref.update(update).catch(() => {});
    }

    logger.info('retryKlaviyoSync: sweep complete', {
      considered: snap.size,
      synced,
      stillFailing,
    });
  }
);

// Exported for the unit tests; not part of the deployed surface.
exports.__test = {
  isValidEmail,
  normalizeEmail,
  docIdFor,
  cleanField,
  subscribeToKlaviyo,
  klaviyoResultFields,
  KLAVIYO_SUBSCRIBE_URL,
  KLAVIYO_REVISION,
};
