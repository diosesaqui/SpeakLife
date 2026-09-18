/**
 * emailCapture — email collection for the app.
 *
 * This replaces `EmailMarketingService.swift`, which shipped from 2026-03-16
 * until commit c605131f removed the whole subsystem on 2026-06-19. The app
 * posts an address here from onboarding, the Profile row, or after a purchase;
 * this module is the only thing that ever touches it. Two jobs, in order:
 *
 *   1. Write it to Firestore (`email_list` in the `speaklife` database, the
 *      same collection the old service wrote). This is the source of truth and
 *      it is what makes the address OURS — it survives a Klaviyo outage, a
 *      rotated key, and a decision to move off Klaviyo entirely.
 *   2. Subscribe it to the Klaviyo list, so it is usable for campaigns without
 *      anyone exporting anything by hand.
 *
 * Step 2 failing NEVER fails the request. An address written to Firestore but
 * not yet in Klaviyo is a sync to retry (`retryKlaviyoSync` below); an address
 * rejected at the door because Klaviyo was down is gone for good, and the user
 * is already past the screen. So the client gets a 200 as soon as the write
 * lands, and the doc carries `klaviyoStatus` for the retry sweep to find.
 *
 * TWO THINGS THE OLD SERVICE GOT WRONG, both fixed here:
 *
 *   - It read the Klaviyo PRIVATE key from `EmailConfig.plist`, bundled in the
 *     app. That key was committed to git and extractable from every shipped
 *     binary, and a Klaviyo private key is full account access. It now lives in
 *     this function's secrets, which is the entire reason this is server-side.
 *   - It never recorded consent (see `subscribeToKlaviyo`).
 *
 * Setup:
 *   firebase functions:secrets:set KLAVIYO_API_KEY     # private key, pk_...
 *   firebase functions:secrets:set KLAVIYO_LIST_ID     # WaeTSA ("Email List")
 *
 * Use a NEWLY ROTATED key. The one the app shipped with must be considered
 * compromised.
 */

const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const crypto = require('crypto');

if (admin.apps.length === 0) admin.initializeApp();

// The NAMED database, not the default one, and not a detail to "clean up".
// Every address collected between 2026-03-16 and 2026-06-12 lives in
// `email_list` here, written by the EmailMarketingService that shipped until
// commit c605131f removed it. Pointing this function anywhere else would fork
// the list in two: the same person re-subscribing would land in a different
// database from their own existing record.
//
// Nothing else in the app reads or writes this database — every other
// Firestore call site uses the default one.
const DATABASE_ID = 'speaklife';
const db = getFirestore(DATABASE_ID);

const KLAVIYO_API_KEY = defineSecret('KLAVIYO_API_KEY');
const KLAVIYO_LIST_ID = defineSecret('KLAVIYO_LIST_ID');

const COLLECTION = 'email_list';

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

// ─── Abuse limits ──────────────────────────────────────────────────────────
//
// This endpoint is unauthenticated and CORS-open, because it has to be: the
// onboarding ask runs before any account exists, so there is no identity to
// require. That leaves it open to two abuses, and the second is the dangerous
// one:
//
//   - List poisoning: stuffing the list with addresses nobody owns.
//   - Email bombing: every accepted address is subscribed WITH CONSENT, so it
//     triggers the welcome flow. A script pointed at this URL sends our mail to
//     strangers, and the complaints land on our sending domain.
//
// A per-IP window is the cheap mitigation that needs no client change. Real
// traffic is roughly a dozen submissions a day across all users, so 10 per IP
// per hour is far above anything legitimate and still caps a script hard.
//
// The PROPER fix is Firebase App Check, which would let the function require a
// genuine app attestation rather than guessing from an address. That needs an
// app-side provider configured and a rollout, so it is deliberately left as a
// follow-up rather than half-done here. See docs/EMAIL_COLLECTION.md.
const RATE_LIMIT_COLLECTION = 'emailCaptureRateLimits';
const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;

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
 * The document id for an address, matching the legacy scheme EXACTLY.
 *
 * `EmailMarketingService.saveToFirebase` used the Firebase UID when there was
 * one and a sanitized address otherwise:
 *
 *     let documentId = userId ?? email
 *         .replacingOccurrences(of: ".", with: "_")
 *         .replacingOccurrences(of: "@", with: "_at_")
 *
 * Dots first, then `@` — the order matters, and so does reproducing it here.
 * Get it wrong and a returning subscriber writes a SECOND document instead of
 * updating their own, which is how a list quietly doubles and every count
 * drawn from it becomes wrong.
 *
 * A hash would be the better design in isolation (it keeps the address out of
 * logs and console URLs, and sidesteps `/` and `..`), but it would orphan every
 * record already written. Compatibility wins; the sanitizing below covers the
 * ids `.doc()` would actually reject.
 */
function docIdFor(normalizedEmail, userId) {
  if (userId) return userId;
  const sanitized = normalizedEmail
    .replace(/\./g, '_')
    .replace(/@/g, '_at_')
    // Not in the legacy scheme, because a Swift String could hold these where
    // a Firestore id cannot. `/` makes .doc() throw and a bare dot segment is
    // reserved, so they are neutralized rather than left to crash the write.
    .replace(/\//g, '_');
  return sanitized === '.' || sanitized === '..' ? `_${sanitized}_` : sanitized;
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
async function subscribeToKlaviyo({ apiKey, listId, email, firstName, properties }) {
  const profile = {
    type: 'profile',
    attributes: {
      email,
      // The half the old EmailMarketingService never wrote.
      //
      // It created the profile with POST /api/profiles/ and then added it to
      // the list through a relationship, which records MEMBERSHIP but leaves
      // consent untouched. Every profile collected that way still reads
      // `consent: NEVER_SUBSCRIBED` with a null consent_timestamp and no
      // method, so there is no record of anyone having agreed to anything.
      //
      // The bulk subscribe job is the only endpoint that creates-or-updates
      // the profile AND writes consent in one call, which is why this uses it.
      subscriptions: { email: { marketing: { consent: 'SUBSCRIBED' } } },
    },
  };
  if (firstName) profile.attributes.first_name = firstName;
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

/**
 * The caller's IP, as far as it can be trusted.
 *
 * Behind Google's front end `x-forwarded-for` is a list whose FIRST entry is
 * the client. It is spoofable, which is why this is a speed bump rather than a
 * security control — but a spoofing script is a different, larger effort than
 * curling a URL in a loop, and that is the bar being raised.
 */
function callerIp(req) {
  const forwarded = req.headers && req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.length > 0) {
    return forwarded.split(',')[0].trim();
  }
  return (req.ip || 'unknown').toString();
}

/**
 * Count this caller against the window. Returns true when they are over it.
 *
 * Fails OPEN: if the rate-limit read or write throws, the submission proceeds.
 * A Firestore hiccup must not start rejecting real addresses at the one moment
 * we get to ask for them — the downside of a missed limit is some junk in a
 * list we control, and the downside of a false rejection is a subscriber gone
 * for good.
 */
async function isRateLimited(ip) {
  const ref = db.collection(RATE_LIMIT_COLLECTION)
    .doc(crypto.createHash('sha256').update(ip).digest('hex'));
  try {
    const snap = await ref.get();
    const now = Date.now();
    const data = snap.exists ? snap.data() : null;
    const windowStart = data && typeof data.windowStart === 'number' ? data.windowStart : 0;
    const within = now - windowStart < RATE_LIMIT_WINDOW_MS;
    const count = within && typeof data.count === 'number' ? data.count : 0;

    if (within && count >= RATE_LIMIT_MAX) return true;

    await ref.set(
      within
        ? { count: count + 1, windowStart }
        : { count: 1, windowStart: now },
      { merge: true }
    );
    return false;
  } catch (err) {
    logger.error('collectEmail: rate limit check failed, allowing', err);
    return false;
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

    // After validation so a malformed request is rejected without spending a
    // Firestore round trip, and before the write so a script cannot fill the
    // list while being told no.
    if (await isRateLimited(callerIp(req))) {
      logger.warn('collectEmail: rate limited');
      res.status(429).json({ error: 'rate_limited' });
      return;
    }

    const email = normalizeEmail(rawEmail);

    const userId = cleanField(body.userId);
    const appUserId = cleanField(body.appUserId);
    const source = cleanField(body.source) || 'onboarding';
    const variant = cleanField(body.variant);
    const burden = cleanField(body.burden);
    const firstName = cleanField(body.firstName);
    const appVersion = cleanField(body.appVersion) || 'unknown';

    const docId = docIdFor(email, userId);
    const ref = db.collection(COLLECTION).doc(docId);

    // ─── 1. Firestore: the address is ours the moment this returns ───────
    try {
      const existing = await ref.get();
      const payload = {
        // Legacy field names, kept verbatim. `timestamp`, `platform`,
        // `app_version`, `user_id` and `first_name` are what the records
        // written before June already carry, and what any export or Klaviyo
        // import built against this collection expects. Renaming them to
        // something tidier would split the schema across one collection.
        email,
        source,
        platform: 'iOS',
        app_version: appVersion,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        klaviyoStatus: 'pending',
        retryCount: 0,
      };
      // Every optional field is written only when we actually have it.
      //
      // This is a merge, so writing `null` does not mean "no value" — it
      // OVERWRITES. The onboarding submit is the only one carrying `variant`
      // and `burden`; the Profile sheet and the post-purchase re-tag send
      // neither, so an unguarded null here would erase the onboarding arm off
      // the record the moment the user updates their address, and the sweep
      // would then re-send a profile with those properties blanked.
      if (userId) payload.user_id = userId;
      if (firstName) payload.first_name = firstName;
      if (appUserId) payload.appUserId = appUserId;
      if (variant) payload.variant = variant;
      if (burden) payload.burden = burden;
      // `timestamp` is the legacy creation stamp and is written once, on the
      // first write. A returning user re-submitting must not look like a brand
      // new subscriber, so this is conditional rather than part of the merge.
      if (!existing.exists) {
        payload.timestamp = admin.firestore.FieldValue.serverTimestamp();
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
      firstName,
      properties: {
        // `source`, `platform` and `app_version` are the property names the
        // existing Klaviyo profiles already carry, so segments built on them
        // keep working. The speaklife_* pair is new.
        source,
        platform: 'iOS',
        app_version: appVersion,
        firebase_uid: userId,
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

    // `klaviyoStatus` is a field this function introduced, so records written
    // by the old service — every address collected before 2026-06-12 — simply
    // do not match and are never touched. That is deliberate: those profiles
    // are already in Klaviyo, and re-subscribing thousands of them would
    // rewrite consent timestamps to today and fire the welcome flow at people
    // who joined months ago.
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
      if (!data.email) {
        // A doc with no address can never be subscribed, and leaving it
        // `pending` would let it occupy a slot in every future 100-doc batch
        // forever, crowding out addresses that could actually be sent.
        await doc.ref.update({
          klaviyoStatus: 'unsendable',
          klaviyoError: 'no email on record',
        }).catch(() => {});
        continue;
      }

      const result = await subscribeToKlaviyo({
        apiKey,
        listId,
        email: data.email,
        firstName: data.first_name,
        properties: {
          source: data.source,
          platform: 'iOS',
          app_version: data.app_version,
          firebase_uid: data.user_id,
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
