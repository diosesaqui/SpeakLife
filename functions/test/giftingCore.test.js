/**
 * Unit tests for giftingCore — the rules that decide who gets premium and for
 * how long. Run with `npm test` in functions/ (Node's built-in runner, no
 * dependencies).
 *
 * The Cloud Functions themselves are covered by the emulator harness in
 * scripts/; what lives here is everything that can go wrong without a network.
 */

const test = require('node:test');
const assert = require('node:assert/strict');

const core = require('../giftingCore');

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 7, 20, 12, 0, 0);

/** A deterministic stand-in for crypto.randomBytes. */
function seededBytes(values) {
  let i = 0;
  return () => Buffer.from([values[i++ % values.length]]);
}

// ─── Code generation ────────────────────────────────────────────────────────

test('generateCode produces a code of the fixed length', () => {
  const code = core.generateCode(seededBytes([0]));
  assert.equal(code.length, core.CODE_LENGTH);
});

test('generateCode only emits glyphs from the alphabet', () => {
  // Only accepted bytes are fed one at a time: a stream of nothing but
  // rejected bytes would (correctly) never produce a code at all.
  const ceiling = 256 - (256 % core.ALPHABET.length);
  for (let seed = 0; seed < ceiling; seed++) {
    const code = core.generateCode(seededBytes([seed]));
    for (const ch of code) {
      assert.ok(core.ALPHABET.includes(ch), `unexpected glyph ${ch} from byte ${seed}`);
    }
  }
});

test('generateCode keeps drawing until it gets an unbiased byte', () => {
  // A byte at or above the ceiling is discarded rather than folded in, so a
  // source that mixes rejected and accepted bytes still terminates and still
  // only uses the accepted ones.
  const code = core.generateCode(seededBytes([255, 250, 240, 11]));
  assert.equal(code, core.ALPHABET[11].repeat(core.CODE_LENGTH));
});

test('generateCode never emits a glyph that can be misread', () => {
  const banned = ['0', '1', 'I', 'L', 'O', 'U'];
  for (const ch of banned) {
    assert.ok(!core.ALPHABET.includes(ch), `${ch} must not be in the alphabet`);
  }
});

test('generateCode rejects biased bytes rather than folding them in', () => {
  // 240..255 are above the rejection ceiling for a 30-glyph alphabet. If they
  // were folded in with a plain modulo, the first 16 glyphs would come up
  // measurably more often. Feeding only rejected bytes then one good byte must
  // yield that good byte's glyph every time.
  const code = core.generateCode(seededBytes([250, 255, 240, 7]));
  assert.equal(code, core.ALPHABET[7 % core.ALPHABET.length].repeat(core.CODE_LENGTH));
});

test('generateCode is uniform across the alphabet', () => {
  // Every accepted byte value maps to some glyph, and across the whole accepted
  // range each glyph is hit the same number of times.
  const counts = new Map();
  const ceiling = 256 - (256 % core.ALPHABET.length);
  for (let byte = 0; byte < ceiling; byte++) {
    const glyph = core.generateCode(seededBytes([byte]))[0];
    counts.set(glyph, (counts.get(glyph) || 0) + 1);
  }
  assert.equal(counts.size, core.ALPHABET.length);
  const frequencies = new Set(counts.values());
  assert.equal(frequencies.size, 1, 'every glyph should be equally likely');
});

test('formatCode splits the code for reading aloud', () => {
  assert.equal(core.formatCode('ABCD2345'), 'ABCD-2345');
});

// ─── Code normalization ─────────────────────────────────────────────────────

test('normalizeCode accepts the canonical form', () => {
  assert.equal(core.normalizeCode('ABCD2345'), 'ABCD2345');
});

test('normalizeCode accepts what a user would actually type', () => {
  assert.equal(core.normalizeCode('abcd-2345'), 'ABCD2345');
  assert.equal(core.normalizeCode(' ABCD 2345 '), 'ABCD2345');
  assert.equal(core.normalizeCode('ABCD_2345'), 'ABCD2345');
});

test('normalizeCode rejects a mistyped glyph instead of guessing', () => {
  // O is not in the alphabet, so it cannot be part of a real code. Dropping it
  // leaves 7 characters, which fails the length check — the user gets "invalid
  // code" rather than somebody else's gift.
  assert.equal(core.normalizeCode('ABCDO345'), '');
});

test('normalizeCode rejects wrong lengths and non-strings', () => {
  assert.equal(core.normalizeCode('ABCD234'), '');
  assert.equal(core.normalizeCode('ABCD23456'), '');
  assert.equal(core.normalizeCode(''), '');
  assert.equal(core.normalizeCode(null), '');
  assert.equal(core.normalizeCode(12345678), '');
});

// ─── Products and durations ─────────────────────────────────────────────────

test('grantForProduct maps the shipped gift SKU', () => {
  assert.deepEqual(core.grantForProduct('SpeakLifeGiftYear'), {
    duration: 'yearly',
    label: '1 year',
  });
});

test('grantForProduct refuses a non-gift product', () => {
  // A real subscription SKU must never be redeemable as a gift.
  assert.equal(core.grantForProduct('SpeakLife1YR49'), null);
  assert.equal(core.grantForProduct('SpeakLifeLifetime'), null);
  assert.equal(core.grantForProduct('nonsense'), null);
});

test('grantEndMs puts a yearly grant 365 days out', () => {
  assert.equal(core.grantEndMs('yearly', NOW), NOW + 365 * DAY);
});

test('grantEndMs gives a lifetime grant no end', () => {
  assert.equal(core.grantEndMs('lifetime', NOW), null);
});

test('codeExpiryMs lapses an unredeemed code after twelve months', () => {
  const expiry = new Date(core.codeExpiryMs(NOW));
  assert.equal(expiry.getUTCFullYear(), 2027);
  assert.equal(expiry.getUTCMonth(), 7);
  assert.equal(expiry.getUTCDate(), 20);
});

test('maxReclaimsFor leaves lifetime uncapped', () => {
  assert.equal(core.maxReclaimsFor('yearly'), core.MAX_RECLAIMS);
  assert.equal(core.maxReclaimsFor('lifetime'), Infinity);
});

// ─── Apple transaction validation ───────────────────────────────────────────

function payload(overrides = {}) {
  return {
    transactionId: '2000000900000001',
    productId: 'SpeakLifeGiftYear',
    quantity: 3,
    purchaseDate: NOW,
    ...overrides,
  };
}

test('validateTransaction accepts a well-formed gift purchase', () => {
  const result = core.validateTransaction(payload());
  assert.equal(result.ok, true);
  assert.deepEqual(result.value, {
    transactionId: '2000000900000001',
    productId: 'SpeakLifeGiftYear',
    quantity: 3,
    purchasedAtMs: NOW,
    duration: 'yearly',
  });
});

test('validateTransaction reads the duration from the product, not the request', () => {
  // The whole point: a payload cannot ask for lifetime by saying so.
  const result = core.validateTransaction(payload({ duration: 'lifetime' }));
  assert.equal(result.value.duration, 'yearly');
});

test('validateTransaction treats a missing quantity as one', () => {
  const result = core.validateTransaction(payload({ quantity: undefined }));
  assert.equal(result.value.quantity, 1);
});

test('validateTransaction refuses a quantity above Apple\'s ceiling', () => {
  assert.deepEqual(core.validateTransaction(payload({ quantity: 11 })), {
    ok: false,
    reason: 'invalid_quantity',
  });
});

test('validateTransaction refuses nonsense quantities', () => {
  for (const quantity of [0, -1, 2.5, '3', null, NaN, Infinity]) {
    const result = core.validateTransaction(payload({ quantity }));
    assert.equal(result.ok, false, `quantity ${quantity} should be rejected`);
    assert.equal(result.reason, 'invalid_quantity');
  }
});

test('validateTransaction refuses a product that is not a gift', () => {
  assert.deepEqual(core.validateTransaction(payload({ productId: 'SpeakLife1YR49' })), {
    ok: false,
    reason: 'not_a_gift_product',
  });
});

test('validateTransaction refuses a transaction id Firestore cannot hold', () => {
  for (const transactionId of ['a/b', '.', '..', '', 'x'.repeat(1501), null]) {
    const result = core.validateTransaction(payload({ transactionId }));
    assert.equal(result.ok, false, `id ${transactionId} should be rejected`);
    assert.equal(result.reason, 'invalid_transaction_id');
  }
});

test('validateTransaction refuses a missing or absurd purchase date', () => {
  for (const purchaseDate of [undefined, 0, -1, 'yesterday']) {
    const result = core.validateTransaction(payload({ purchaseDate }));
    assert.equal(result.ok, false, `date ${purchaseDate} should be rejected`);
    assert.equal(result.reason, 'invalid_purchase_date');
  }
});

test('validateTransaction refuses a non-object payload', () => {
  assert.equal(core.validateTransaction(null).reason, 'invalid_payload');
  assert.equal(core.validateTransaction('signed').reason, 'invalid_payload');
});

// ─── Redemption state machine ───────────────────────────────────────────────

function gift(overrides = {}) {
  return {
    status: 'unredeemed',
    purchaserAppUserId: 'buyer',
    redeemedByAppUserId: null,
    grantDuration: 'yearly',
    grantedUntilMs: null,
    expiresUnredeemedAtMs: NOW + 300 * DAY,
    reclaimCount: 0,
    ...overrides,
  };
}

test('an unknown code is not found', () => {
  assert.deepEqual(
    core.decideRedemption({ gift: null, appUserId: 'recipient', nowMs: NOW }),
    { ok: false, reason: 'not_found' }
  );
});

test('a fresh code redeems', () => {
  assert.deepEqual(
    core.decideRedemption({ gift: gift(), appUserId: 'recipient', nowMs: NOW }),
    { ok: true, kind: 'first' }
  );
});

test('a revoked code never redeems', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({ status: 'revoked' }),
      appUserId: 'recipient',
      nowMs: NOW,
    }),
    { ok: false, reason: 'revoked' }
  );
});

test('the buyer cannot redeem their own gift', () => {
  assert.deepEqual(
    core.decideRedemption({ gift: gift(), appUserId: 'buyer', nowMs: NOW }),
    { ok: false, reason: 'self_redeem' }
  );
});

test('the buyer is refused whatever state the code is in', () => {
  // Reads the same way before and after the code is used, so the message never
  // leaks whether somebody else already opened it.
  const used = gift({ status: 'redeemed', redeemedByAppUserId: 'recipient' });
  assert.deepEqual(
    core.decideRedemption({ gift: used, appUserId: 'buyer', nowMs: NOW }),
    { ok: false, reason: 'self_redeem' }
  );
});

test('a lapsed unredeemed code is refused', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({ expiresUnredeemedAtMs: NOW - DAY }),
      appUserId: 'recipient',
      nowMs: NOW,
    }),
    { ok: false, reason: 'expired' }
  );
});

test('a code redeemed a moment before its expiry still counts', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({ expiresUnredeemedAtMs: NOW }),
      appUserId: 'recipient',
      nowMs: NOW,
    }),
    { ok: true, kind: 'first' }
  );
});

test('the same recipient asking twice is a retry, not a second claim', () => {
  // The client may repeat itself after a dropped response; that must not spend
  // a re-claim.
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({
        status: 'redeemed',
        redeemedByAppUserId: 'recipient',
        grantedUntilMs: NOW + 300 * DAY,
      }),
      appUserId: 'recipient',
      nowMs: NOW,
    }),
    { ok: true, kind: 'idempotent' }
  );
});

test('a new device re-claims an active gift', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({
        status: 'redeemed',
        redeemedByAppUserId: 'old-device',
        grantedUntilMs: NOW + 100 * DAY,
      }),
      appUserId: 'new-device',
      nowMs: NOW,
    }),
    { ok: true, kind: 'reclaim' }
  );
});

test('re-claims run out after the cap', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({
        status: 'redeemed',
        redeemedByAppUserId: 'old-device',
        grantedUntilMs: NOW + 100 * DAY,
        reclaimCount: core.MAX_RECLAIMS,
      }),
      appUserId: 'new-device',
      nowMs: NOW,
    }),
    { ok: false, reason: 'reclaim_limit' }
  );
});

test('a lifetime gift re-claims without limit', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({
        status: 'redeemed',
        redeemedByAppUserId: 'old-device',
        grantDuration: 'lifetime',
        grantedUntilMs: null,
        reclaimCount: 99,
      }),
      appUserId: 'new-device',
      nowMs: NOW,
    }),
    { ok: true, kind: 'reclaim' }
  );
});

test('a gift whose year has run out cannot be re-claimed', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({
        status: 'redeemed',
        redeemedByAppUserId: 'old-device',
        grantedUntilMs: NOW - DAY,
      }),
      appUserId: 'new-device',
      nowMs: NOW,
    }),
    { ok: false, reason: 'grant_expired' }
  );
});

test('an unrecognized status is refused rather than assumed safe', () => {
  assert.deepEqual(
    core.decideRedemption({
      gift: gift({ status: 'something_new' }),
      appUserId: 'recipient',
      nowMs: NOW,
    }),
    { ok: false, reason: 'unknown_status' }
  );
});

// ─── RevenueCat grant body ──────────────────────────────────────────────────

test('a first claim starts now', () => {
  assert.deepEqual(
    core.promotionalGrantBody({ duration: 'yearly', kind: 'first', grantedUntilMs: null }),
    { duration: 'yearly' }
  );
});

test('a re-claim grants only the time still remaining', () => {
  // RevenueCat takes named durations only, so the window is shifted by
  // back-dating the start until start + a year lands on the original end.
  const endsAt = NOW + 100 * DAY;
  const body = core.promotionalGrantBody({
    duration: 'yearly',
    kind: 'reclaim',
    grantedUntilMs: endsAt,
  });
  assert.equal(body.duration, 'yearly');
  assert.equal(body.start_time_ms + core.DURATION_MS.yearly, endsAt);
  assert.ok(body.start_time_ms < NOW, 'the start must be back-dated');
});

test('a lifetime grant has no window at all', () => {
  assert.deepEqual(
    core.promotionalGrantBody({
      duration: 'lifetime',
      kind: 'reclaim',
      grantedUntilMs: null,
    }),
    { duration: 'lifetime' }
  );
});

// ─── Notes and ids ──────────────────────────────────────────────────────────

test('sanitizeNote keeps an ordinary message', () => {
  assert.equal(core.sanitizeNote('  Praying for you, sis.  '), 'Praying for you, sis.');
});

test('sanitizeNote caps the length', () => {
  assert.equal(core.sanitizeNote('x'.repeat(500)).length, 200);
});

test('sanitizeNote strips control characters', () => {
  assert.equal(core.sanitizeNote('hello\u0000world'), 'hello world');
  assert.equal(core.sanitizeNote('line\nbreak'), 'line break');
  assert.equal(core.sanitizeNote('tab\there'), 'tab here');
  assert.equal(core.sanitizeNote('del\u007Fchar'), 'del char');
});

test('sanitizeNote treats empty and non-strings as no note', () => {
  assert.equal(core.sanitizeNote(''), null);
  assert.equal(core.sanitizeNote('   '), null);
  assert.equal(core.sanitizeNote(null), null);
  assert.equal(core.sanitizeNote({ text: 'hi' }), null);
});

test('isSafeDocId rejects ids Firestore would choke on', () => {
  assert.equal(core.isSafeDocId('$RCAnonymousID:abc123'), true);
  assert.equal(core.isSafeDocId('a/b'), false);
  assert.equal(core.isSafeDocId('.'), false);
  assert.equal(core.isSafeDocId('..'), false);
  assert.equal(core.isSafeDocId(''), false);
  assert.equal(core.isSafeDocId('x'.repeat(1501)), false);
  assert.equal(core.isSafeDocId(undefined), false);
});
