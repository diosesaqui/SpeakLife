/**
 * emailCapture.test.js
 * Unit tests for onboarding email collection.
 *
 *   npm run test:email
 *
 * No emulator needed. Everything here is either a pure helper or the Klaviyo
 * call driven through a stubbed `fetch`, which is where the real risk lives:
 * the request shape (consent block, list relationship, pinned revision) is the
 * difference between a subscriber who receives mail and a profile that sits in
 * Klaviyo unsubscribed, and neither shows up as an error at the call site.
 *
 * The Firestore paths in collectEmail are covered by the rules test and by
 * standTogether's emulator suite; what is asserted here is everything that can
 * be wrong while still returning 200.
 */

process.env.GCLOUD_PROJECT ||= 'speaklife-email-test';

const assert = require('node:assert');
const { test } = require('node:test');

const H = require('../emailCapture').__test;

// ─── Validation ─────────────────────────────────────────────────────────────

test('isValidEmail accepts the addresses real users actually have', () => {
  const good = [
    'a@b.co',
    'first.last@example.com',
    // Plus-addressing and long TLDs are the two things an over-strict regex
    // usually rejects, and every rejection is a subscriber lost at the only
    // moment we get to ask.
    'someone+speaklife@gmail.com',
    'pastor@church.ministry',
    'user_name-123@sub.domain.co.uk',
  ];
  for (const e of good) {
    assert.strictEqual(H.isValidEmail(e), true, `should accept ${e}`);
  }
});

test('isValidEmail rejects what cannot be delivered to', () => {
  const bad = [
    '', '   ', 'plainstring', 'no@domain', '@nothing.com', 'two@@at.com',
    'spaces in@email.com', 'trailing@space .com', null, undefined, 42, {},
  ];
  for (const e of bad) {
    assert.strictEqual(H.isValidEmail(e), false, `should reject ${JSON.stringify(e)}`);
  }
});

test('isValidEmail enforces the RFC length ceiling', () => {
  // '@example.com' is 12 chars, so the boundary sits at a 242-char local part.
  assert.strictEqual(H.isValidEmail('a'.repeat(242) + '@example.com'), true, 'exactly 254 is valid');
  assert.strictEqual(H.isValidEmail('a'.repeat(243) + '@example.com'), false, '255 is over');
  assert.strictEqual(H.isValidEmail('a'.repeat(60) + '@example.com'), true);
});

test('isValidEmail tolerates surrounding whitespace', () => {
  assert.strictEqual(H.isValidEmail('  me@example.com  '), true);
});

// ─── Normalizing and doc ids ────────────────────────────────────────────────

test('normalizeEmail collapses case and whitespace so one person is one doc', () => {
  assert.strictEqual(H.normalizeEmail('  Me@Example.COM '), 'me@example.com');
});

test('docIdFor is stable, hex, and derived from the normalized address', () => {
  const id = H.docIdFor('me@example.com');
  assert.match(id, /^[0-9a-f]{64}$/);
  assert.strictEqual(id, H.docIdFor('me@example.com'));
  assert.notStrictEqual(id, H.docIdFor('other@example.com'));
});

test('docIdFor survives local parts that would break Firestore .doc()', () => {
  // A slash or a bare dot segment in a document id throws synchronously. The
  // hash is what makes that impossible, so this is the case that matters.
  for (const weird of ['a/b@example.com', '.@example.com', '..@example.com']) {
    assert.match(H.docIdFor(H.normalizeEmail(weird)), /^[0-9a-f]{64}$/);
  }
});

// ─── Field cleaning ─────────────────────────────────────────────────────────

test('cleanField trims, caps, and nulls out empties', () => {
  assert.strictEqual(H.cleanField('  warfare  '), 'warfare');
  assert.strictEqual(H.cleanField(''), null);
  assert.strictEqual(H.cleanField('   '), null);
  assert.strictEqual(H.cleanField(undefined), null);
  assert.strictEqual(H.cleanField(null), null);
  assert.strictEqual(H.cleanField(12345), null);
  assert.strictEqual(H.cleanField('x'.repeat(500)).length, 120);
});

// ─── Klaviyo request shape ──────────────────────────────────────────────────

/** Swap in a fake fetch for one call and hand back what it was sent. */
async function captureKlaviyoCall(response, args = {}) {
  const calls = [];
  const original = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    if (response instanceof Error) throw response;
    return response;
  };
  try {
    const result = await H.subscribeToKlaviyo({
      apiKey: 'pk_test',
      listId: 'WaeTSA',
      email: 'me@example.com',
      properties: { speaklife_source: 'onboarding' },
      ...args,
    });
    return { result, calls };
  } finally {
    globalThis.fetch = original;
  }
}

const accepted = { status: 202, text: async () => '' };

test('subscribeToKlaviyo posts to the pinned endpoint with the private key', async () => {
  const { calls } = await captureKlaviyoCall(accepted);
  assert.strictEqual(calls.length, 1);
  const { url, init } = calls[0];
  assert.strictEqual(url, H.KLAVIYO_SUBSCRIBE_URL);
  assert.strictEqual(init.method, 'POST');
  assert.strictEqual(init.headers.Authorization, 'Klaviyo-API-Key pk_test');
  // Unpinned, Klaviyo moves us onto breaking changes with no deploy on our side.
  assert.strictEqual(init.headers.revision, H.KLAVIYO_REVISION);
});

test('subscribeToKlaviyo records marketing consent', async () => {
  // Without this block Klaviyo creates the profile and leaves it unsubscribed:
  // collected, stored, and unmailable, with no error anywhere to show for it.
  const { calls } = await captureKlaviyoCall(accepted);
  const body = JSON.parse(calls[0].init.body);
  const profile = body.data.attributes.profiles.data[0];
  assert.strictEqual(profile.attributes.email, 'me@example.com');
  assert.strictEqual(
    profile.attributes.subscriptions.email.marketing.consent,
    'SUBSCRIBED'
  );
});

test('subscribeToKlaviyo targets the configured list', async () => {
  const { calls } = await captureKlaviyoCall(accepted);
  const body = JSON.parse(calls[0].init.body);
  assert.deepStrictEqual(body.data.relationships.list.data, {
    type: 'list',
    id: 'WaeTSA',
  });
});

test('subscribeToKlaviyo opts in as a current signup, not a backdated import', async () => {
  // historical_import: true would skip the welcome flow, which is the entire
  // reason for collecting the address during onboarding.
  const { calls } = await captureKlaviyoCall(accepted);
  const body = JSON.parse(calls[0].init.body);
  assert.strictEqual(body.data.attributes.historical_import, false);
});

test('subscribeToKlaviyo stamps the properties it was given', async () => {
  const { calls } = await captureKlaviyoCall(accepted, {
    properties: { speaklife_source: 'onboarding', speaklife_burden: 'peace' },
  });
  const body = JSON.parse(calls[0].init.body);
  assert.deepStrictEqual(body.data.attributes.profiles.data[0].attributes.properties, {
    speaklife_source: 'onboarding',
    speaklife_burden: 'peace',
  });
});

test('subscribeToKlaviyo omits null properties rather than clearing good ones', async () => {
  // An object of nulls would overwrite the variant and burden recorded on an
  // earlier submission with nothing.
  const { calls } = await captureKlaviyoCall(accepted, {
    properties: { speaklife_source: 'onboarding', speaklife_burden: null },
  });
  const attrs = JSON.parse(calls[0].init.body).data.attributes.profiles.data[0].attributes;
  assert.deepStrictEqual(attrs.properties, { speaklife_source: 'onboarding' });
});

test('subscribeToKlaviyo sends no properties key when it has none', async () => {
  const { calls } = await captureKlaviyoCall(accepted, { properties: {} });
  const attrs = JSON.parse(calls[0].init.body).data.attributes.profiles.data[0].attributes;
  assert.strictEqual('properties' in attrs, false);
});

// ─── Klaviyo outcomes ───────────────────────────────────────────────────────

test('subscribeToKlaviyo treats 202 as success', async () => {
  const { result } = await captureKlaviyoCall(accepted);
  assert.deepStrictEqual(result, { ok: true });
});

test('subscribeToKlaviyo reports an API error without throwing', async () => {
  const { result } = await captureKlaviyoCall({
    status: 401,
    text: async () => 'invalid key',
  });
  assert.strictEqual(result.ok, false);
  assert.strictEqual(result.status, 401);
  assert.match(result.error, /invalid key/);
});

test('subscribeToKlaviyo reports a transport failure without throwing', async () => {
  // The contract the whole module rests on: Klaviyo being unreachable must
  // never propagate out and fail the user's request.
  const { result } = await captureKlaviyoCall(new Error('ECONNRESET'));
  assert.strictEqual(result.ok, false);
  assert.strictEqual(result.status, 0);
  assert.match(result.error, /ECONNRESET/);
});

test('subscribeToKlaviyo truncates a huge error body', async () => {
  const { result } = await captureKlaviyoCall({
    status: 500,
    text: async () => 'x'.repeat(5000),
  });
  assert.strictEqual(result.error.length, 500);
});

// ─── Status fields ──────────────────────────────────────────────────────────

test('klaviyoResultFields marks success synced and clears any prior error', () => {
  const fields = H.klaviyoResultFields({ ok: true });
  assert.strictEqual(fields.klaviyoStatus, 'synced');
  assert.ok(fields.klaviyoSyncedAt, 'should stamp a sync time');
  // A doc that failed, then succeeded, must not keep the stale error around.
  assert.ok(fields.klaviyoError, 'should carry a delete sentinel for the error');
});

test('klaviyoResultFields leaves a failure pending for the retry sweep', () => {
  const fields = H.klaviyoResultFields({ ok: false, status: 429, error: 'rate limited' });
  // 'pending' is what retryKlaviyoSync queries on. Any other value here and the
  // address is stored, unmailable, and never retried.
  assert.strictEqual(fields.klaviyoStatus, 'pending');
  assert.match(fields.klaviyoError, /429/);
  assert.strictEqual(fields.klaviyoSyncedAt, undefined);
});
