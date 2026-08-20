/**
 * giftingCore.js
 * Pure logic behind gift subscriptions. No Firestore, no network, no Firebase.
 *
 * Everything here is deterministic (or takes its randomness/clock as an
 * argument), which is the whole point: these are the rules that decide who gets
 * premium and for how long, so they are the parts that must be unit tested.
 * `gifting.js` is the thin shell that wires these to Firestore, Apple, and
 * RevenueCat.
 *
 * See docs/GIFT_SUBSCRIPTION_PLAN.md for the design this implements.
 */

// ─── Product catalog ────────────────────────────────────────────────────────
// Server-side only, and deliberately so: the client tells us which product it
// bought via the Apple-signed transaction, and we decide what that is worth. A
// tampered request cannot ask for a longer grant than it paid for, because the
// duration is never read from the request body.
//
// Lifetime is designed for but not shipped — see §6 of the plan. Enabling it is
// one line here plus the identity work described there.
const GIFT_PRODUCTS = {
  SpeakLifeGiftYear: { duration: 'yearly', label: '1 year' },
  // SpeakLifeGiftLifetime: { duration: 'lifetime', label: 'lifetime' },
};

// Apple caps a single purchase at 10 of a consumable. A signed payload above
// that is something we do not understand, so refuse it rather than mint 50
// codes off one charge.
const MAX_QUANTITY = 10;

// How long an unredeemed code stays alive before it lapses.
const CODE_LIFETIME_MONTHS = 12;

// A redeemed gift may be re-claimed onto new devices this many times. This is
// the mitigation for anonymous RevenueCat IDs: the recipient re-enters their
// code on a new phone. Lifetime grants are exempt (see maxReclaimsFor).
const MAX_RECLAIMS = 3;

const DURATION_MS = {
  // RevenueCat's named `yearly` promotional duration is 365 days.
  yearly: 365 * 24 * 60 * 60 * 1000,
};

// ─── Codes ──────────────────────────────────────────────────────────────────
// 30 glyphs, with 0/1/I/L/O/U left out so nothing in a code can be misread on
// paper or misheard over the phone. 30^8 ≈ 6.6e11, which together with the
// redeem rate limit puts brute force out of reach.
const ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
const CODE_LENGTH = 8;

/**
 * Generates one code in canonical form (bare, uppercase, no separator).
 * `randomBytes` is injected so tests can pin the output.
 */
function generateCode(randomBytes) {
  // Rejection sampling: 256 is not a multiple of 30, so naively taking the
  // modulo would make the first few glyphs measurably likelier than the rest.
  const ceiling = 256 - (256 % ALPHABET.length);
  let code = '';
  while (code.length < CODE_LENGTH) {
    const byte = randomBytes(1)[0];
    if (byte < ceiling) code += ALPHABET[byte % ALPHABET.length];
  }
  return code;
}

/** Canonical code → the form we show and share: `ABCD-EFGH`. */
function formatCode(code) {
  return `${code.slice(0, 4)}-${code.slice(4)}`;
}

/**
 * Whatever the user typed → canonical form, or '' if it cannot be one.
 *
 * Characters outside the alphabet are dropped rather than mapped to a guess.
 * They can never appear in a real code, so a mistyped one changes the length
 * and falls out as "invalid code" instead of silently resolving to somebody
 * else's gift.
 */
function normalizeCode(raw) {
  if (typeof raw !== 'string') return '';
  const cleaned = raw
    .toUpperCase()
    .split('')
    .filter((c) => ALPHABET.includes(c))
    .join('');
  return cleaned.length === CODE_LENGTH ? cleaned : '';
}

// ─── Products and durations ─────────────────────────────────────────────────

function grantForProduct(productId) {
  return GIFT_PRODUCTS[productId] || null;
}

function maxReclaimsFor(duration) {
  // A lifetime grant has to survive every device its owner will ever have, so
  // capping re-claims would eventually strand someone permanently.
  return duration === 'lifetime' ? Infinity : MAX_RECLAIMS;
}

/** When a first-time grant of `duration` should end. null means never. */
function grantEndMs(duration, nowMs) {
  if (duration === 'lifetime') return null;
  return nowMs + DURATION_MS[duration];
}

/** When an unredeemed code lapses. */
function codeExpiryMs(purchasedAtMs) {
  const d = new Date(purchasedAtMs);
  d.setUTCMonth(d.getUTCMonth() + CODE_LIFETIME_MONTHS);
  return d.getTime();
}

// ─── Apple transaction validation ───────────────────────────────────────────

/**
 * Checks an already signature-verified Apple payload before we mint anything.
 * Signature verification happens in gifting.js; this is the business-rule pass
 * layered on top of it.
 */
function validateTransaction(payload) {
  if (!payload || typeof payload !== 'object') {
    return { ok: false, reason: 'invalid_payload' };
  }

  const { transactionId, productId } = payload;
  if (!isSafeDocId(transactionId)) {
    return { ok: false, reason: 'invalid_transaction_id' };
  }

  const product = grantForProduct(productId);
  if (!product) return { ok: false, reason: 'not_a_gift_product' };

  // StoreKit always sends quantity, but a missing one is unambiguous: a single
  // purchase. Anything non-integer or out of range is not.
  const quantity = payload.quantity === undefined ? 1 : payload.quantity;
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > MAX_QUANTITY) {
    return { ok: false, reason: 'invalid_quantity' };
  }

  const purchasedAtMs = Number(payload.purchaseDate);
  if (!Number.isFinite(purchasedAtMs) || purchasedAtMs <= 0) {
    return { ok: false, reason: 'invalid_purchase_date' };
  }

  return {
    ok: true,
    value: { transactionId, productId, quantity, purchasedAtMs, duration: product.duration },
  };
}

// ─── Redemption state machine ───────────────────────────────────────────────

/**
 * Decides what a redeem request should do. Takes plain data so every branch is
 * testable without a database.
 *
 * `gift` is null when the code matched nothing.
 * Returns { ok: true, kind: 'first' | 'reclaim' | 'idempotent' }
 *      or { ok: false, reason }.
 */
function decideRedemption({ gift, appUserId, nowMs }) {
  if (!gift) return { ok: false, reason: 'not_found' };
  if (gift.status === 'revoked') return { ok: false, reason: 'revoked' };

  // Checked ahead of status so gifting yourself always reads the same way,
  // whether the code is fresh or already burned.
  if (gift.purchaserAppUserId && gift.purchaserAppUserId === appUserId) {
    return { ok: false, reason: 'self_redeem' };
  }

  if (gift.status === 'unredeemed') {
    if (nowMs > gift.expiresUnredeemedAtMs) return { ok: false, reason: 'expired' };
    return { ok: true, kind: 'first' };
  }

  if (gift.status === 'redeemed') {
    // The same user asking again is a retry, not a second claim. Answer yes
    // without spending a re-claim — the client may well be repeating itself
    // after a dropped response.
    if (gift.redeemedByAppUserId === appUserId) return { ok: true, kind: 'idempotent' };

    const isLifetime = gift.grantDuration === 'lifetime';
    if (!isLifetime && gift.grantedUntilMs !== null && nowMs >= gift.grantedUntilMs) {
      return { ok: false, reason: 'grant_expired' };
    }
    if ((gift.reclaimCount || 0) >= maxReclaimsFor(gift.grantDuration)) {
      return { ok: false, reason: 'reclaim_limit' };
    }
    return { ok: true, kind: 'reclaim' };
  }

  return { ok: false, reason: 'unknown_status' };
}

// ─── RevenueCat promotional grant ───────────────────────────────────────────

/**
 * Body for POST /v1/subscribers/{id}/entitlements/{ent}/promotional.
 *
 * RevenueCat only accepts its own named durations, so an arbitrary window is
 * expressed by back-dating the start: pick the named duration and set
 * start_time_ms so that start + duration lands on the end we actually want.
 * That is how a re-claim grants only the time still remaining rather than a
 * fresh full year.
 */
function promotionalGrantBody({ duration, kind, grantedUntilMs }) {
  if (duration === 'lifetime') return { duration: 'lifetime' };
  if (kind === 'reclaim' && grantedUntilMs) {
    return { duration, start_time_ms: grantedUntilMs - DURATION_MS[duration] };
  }
  // A first claim starts now, which is RevenueCat's default.
  return { duration };
}

// ─── Misc ───────────────────────────────────────────────────────────────────

/** Rejects anything that would make Firestore's .doc() throw. */
function isSafeDocId(id) {
  return (
    typeof id === 'string' &&
    id.length > 0 &&
    id.length <= 1500 &&
    !id.includes('/') &&
    id !== '.' &&
    id !== '..'
  );
}

/**
 * The gifter's note travels to a stranger's screen, so it is length-capped and
 * stripped of control characters. The client renders it as plain text, never as
 * a link.
 */
function sanitizeNote(raw) {
  if (typeof raw !== 'string') return null;
  const cleaned = raw
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .trim()
    .slice(0, 200)
    .trim();
  return cleaned.length ? cleaned : null;
}

module.exports = {
  GIFT_PRODUCTS,
  MAX_QUANTITY,
  MAX_RECLAIMS,
  CODE_LIFETIME_MONTHS,
  ALPHABET,
  CODE_LENGTH,
  DURATION_MS,
  generateCode,
  formatCode,
  normalizeCode,
  grantForProduct,
  maxReclaimsFor,
  grantEndMs,
  codeExpiryMs,
  validateTransaction,
  decideRedemption,
  promotionalGrantBody,
  isSafeDocId,
  sanitizeNote,
};
