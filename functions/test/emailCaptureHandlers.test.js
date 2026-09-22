/**
 * emailCaptureHandlers.test.js
 * Tests for the two DEPLOYED functions — `collectEmail` and `retryKlaviyoSync`.
 *
 *   npm run test:email-handlers
 *
 * emailCapture.test.js covers the pure helpers and the Klaviyo request body.
 * That left the two things that actually run in production untested: the HTTP
 * handler's validation and response contract, and the retry sweep's bookkeeping.
 * Line coverage of emailCapture.js was 61% with both of them uncovered.
 *
 * Firestore is stubbed rather than emulated, following the pattern
 * standTogether.test.js uses for messaging: replace the module export BEFORE
 * emailCapture.js is required, since it grabs `getFirestore()` at module load.
 * That keeps these runnable on plain Node in CI with no emulator and no JVM.
 *
 * What the stub is asserting is not "Firestore works" — it is the contract this
 * module has with it: which document id, which field names, and which fields
 * are written once versus on every submission. Those are the things that
 * silently fork the list if they regress.
 */

process.env.GCLOUD_PROJECT ||= 'speaklife-email-test';

const assert = require('node:assert');
const { test, beforeEach } = require('node:test');
const { EventEmitter } = require('node:events');

// ─── Firestore stub, installed before the module under test loads ───────────

const store = new Map();          // docId -> data
const writes = [];                // every set/update, in order
let getShouldThrow = false;
let updateShouldThrow = false;

function makeDoc(collection, docId) {
  const key = `${collection}/${docId}`;
  return {
    async get() {
      if (getShouldThrow) throw new Error('firestore unavailable');
      const data = store.get(key);
      return { exists: data !== undefined, data: () => data, ref: makeDoc(collection, docId) };
    },
    async set(payload, options) {
      writes.push({ collection, docId, payload, options, kind: 'set' });
      store.set(key, { ...(store.get(key) || {}), ...payload });
    },
    async update(payload) {
      if (updateShouldThrow) throw new Error('update rejected');
      writes.push({ collection, docId, payload, kind: 'update' });
      store.set(key, { ...(store.get(key) || {}), ...payload });
    },
  };
}

/** Writes to the list itself, ignoring rate-limit bookkeeping. */
const listWrites = () => writes.filter((w) => w.collection === 'email_list');
/** The stored list document for an address. */
const listDoc = (docId) => store.get(`email_list/${docId}`);

// The sweep's query is chainable: .where().where().limit().get()
let sweepDocs = [];
function makeQuery(collection) {
  const q = {
    where: () => q,
    limit: () => q,
    async get() {
      return {
        empty: sweepDocs.length === 0,
        size: sweepDocs.length,
        docs: sweepDocs.map((d) => ({
          data: () => d,
          ref: makeDoc(collection, d.__id || 'swept'),
        })),
      };
    },
  };
  return q;
}

const fakeDb = {
  collection(name) {
    const col = makeQuery(name);
    col.doc = (docId) => makeDoc(name, docId);
    return col;
  },
};

const firestore = require('firebase-admin/firestore');
const originalGetFirestore = firestore.getFirestore;
let requestedDatabaseId;
firestore.getFirestore = (dbId) => {
  requestedDatabaseId = dbId;
  return fakeDb;
};

const fns = require('../emailCapture');
firestore.getFirestore = originalGetFirestore;

// ─── Fake req/res ───────────────────────────────────────────────────────────

/**
 * Minimal Express-ish response.
 *
 * It has to be an EventEmitter: the v2 `onRequest` wrapper resolves its promise
 * on `res.on('finish')`, so a plain object hangs the call. The header methods
 * are there for the `cors: true` middleware the handler is declared with.
 */
function mockRes() {
  const res = new EventEmitter();
  const headers = {};
  res.statusCode = 200;
  res.body = undefined;
  res.finished = false;
  res.status = (code) => { res.statusCode = code; return res; };
  res.setHeader = (k, v) => { headers[k] = v; return res; };
  res.getHeader = (k) => headers[k];
  res.removeHeader = (k) => { delete headers[k]; return res; };
  res.finish = () => {
    if (res.finished) return res;
    res.finished = true;
    res.emit('finish');
    return res;
  };
  res.json = (payload) => { res.body = payload; return res.finish(); };
  res.send = res.json;
  res.end = () => res.finish();
  return res;
}

// `headers` is not optional: the `cors: true` middleware the handler is
// declared with reads `req.headers.origin` before the handler ever runs.
const post = (body) => ({ method: 'POST', body, headers: {} });

/** Drive the deployed handler. */
async function callCollect(req) {
  const res = mockRes();
  await fns.collectEmail(req, res);
  return res;
}

/** Klaviyo stub for the duration of one call. */
async function withKlaviyo(response, fn) {
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    if (response instanceof Error) throw response;
    return response;
  };
  try {
    return { result: await fn(), calls };
  } finally {
    globalThis.fetch = original;
  }
}

const accepted = { status: 202, text: async () => '' };

beforeEach(() => {
  store.clear();
  writes.length = 0;
  sweepDocs = [];
  getShouldThrow = false;
  updateShouldThrow = false;
  delete process.env.KLAVIYO_API_KEY;
  delete process.env.KLAVIYO_LIST_ID;
});

// ─── Wiring ─────────────────────────────────────────────────────────────────

test('writes to the named speaklife database, not the default one', () => {
  // The legacy list lives in a second database. Defaulting here would fork the
  // list: the same person would land in a different database from their own
  // existing record.
  assert.strictEqual(requestedDatabaseId, 'speaklife');
});

// ─── Request validation ─────────────────────────────────────────────────────

test('collectEmail rejects anything but POST', async () => {
  const res = await callCollect({ method: 'GET', body: {}, headers: {} });
  assert.strictEqual(res.statusCode, 405);
  assert.strictEqual(res.body.error, 'method_not_allowed');
  assert.strictEqual(listWrites().length, 0);
});

test('collectEmail rejects a missing or blank address', async () => {
  for (const body of [{}, { email: '' }, { email: '   ' }, { email: 42 }]) {
    const res = await callCollect(post(body));
    assert.strictEqual(res.statusCode, 400, JSON.stringify(body));
    assert.strictEqual(res.body.error, 'missing_email');
  }
  assert.strictEqual(listWrites().length, 0, 'nothing should be written');
});

test('collectEmail rejects a malformed address', async () => {
  const res = await callCollect(post({ email: 'not-an-address' }));
  assert.strictEqual(res.statusCode, 400);
  assert.strictEqual(res.body.error, 'invalid_email');
  assert.strictEqual(listWrites().length, 0);
});

test('collectEmail reports a storage failure as 500 and writes nothing', async () => {
  // The one case where the request SHOULD fail: if Firestore did not accept the
  // address, telling the client it is saved would lose it silently.
  getShouldThrow = true;
  const res = await callCollect(post({ email: 'me@example.com' }));
  assert.strictEqual(res.statusCode, 500);
  assert.strictEqual(res.body.error, 'storage_failed');
});

// ─── The write itself ───────────────────────────────────────────────────────

test('collectEmail writes to email_list under the legacy document id', async () => {
  await callCollect(post({ email: '  Me@Example.COM ' }));
  assert.strictEqual(listWrites()[0].collection, 'email_list');
  assert.strictEqual(listWrites()[0].docId, 'me_at_example_com');
  assert.strictEqual(listWrites()[0].payload.email, 'me@example.com');
});

test('collectEmail keys on the Firebase UID when the client sends one', async () => {
  await callCollect(post({ email: 'me@example.com', userId: 'uid-123' }));
  assert.strictEqual(listWrites()[0].docId, 'uid-123');
  assert.strictEqual(listWrites()[0].payload.user_id, 'uid-123');
});

test('collectEmail merges rather than overwriting', async () => {
  // A blind set() would wipe fields an earlier submission or the sweep wrote.
  await callCollect(post({ email: 'me@example.com' }));
  assert.strictEqual(listWrites()[0].options.merge, true);
});

test('collectEmail writes the legacy field names', async () => {
  await callCollect(post({
    email: 'me@example.com',
    source: 'settings',
    appVersion: '4.65',
    firstName: 'Riccardo',
  }));
  const p = listWrites()[0].payload;
  assert.strictEqual(p.source, 'settings');
  assert.strictEqual(p.platform, 'iOS');
  assert.strictEqual(p.app_version, '4.65');
  assert.strictEqual(p.first_name, 'Riccardo');
});

test('collectEmail defaults source and app version rather than writing null', async () => {
  await callCollect(post({ email: 'me@example.com' }));
  assert.strictEqual(listWrites()[0].payload.source, 'onboarding');
  assert.strictEqual(listWrites()[0].payload.app_version, 'unknown');
});

test('collectEmail omits first_name and user_id when absent', async () => {
  // Writing them as null would blank values a previous submission had set.
  await callCollect(post({ email: 'me@example.com' }));
  assert.strictEqual('first_name' in listWrites()[0].payload, false);
  assert.strictEqual('user_id' in listWrites()[0].payload, false);
});

test('collectEmail stamps the legacy creation timestamp only on the first write', async () => {
  // A returning subscriber must not look like a brand new one.
  await callCollect(post({ email: 'me@example.com' }));
  assert.ok('timestamp' in listWrites()[0].payload, 'first write sets timestamp');

  writes.length = 0;
  await callCollect(post({ email: 'me@example.com' }));
  assert.strictEqual('timestamp' in listWrites()[0].payload, false, 're-submit must not restamp');
  assert.ok('updatedAt' in listWrites()[0].payload, 'but updatedAt moves every time');
});

// ─── Klaviyo is best effort ─────────────────────────────────────────────────

test('collectEmail returns 200 pending when Klaviyo is unconfigured', async () => {
  const res = await callCollect(post({ email: 'me@example.com' }));
  assert.strictEqual(res.statusCode, 200);
  assert.deepStrictEqual(res.body, { ok: true, klaviyo: 'pending' });
  assert.strictEqual(listDoc('me_at_example_com').klaviyoStatus, 'pending');
});

test('collectEmail marks the doc synced once Klaviyo accepts', async () => {
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  const { result } = await withKlaviyo(accepted, () =>
    callCollect(post({ email: 'me@example.com' })));
  assert.deepStrictEqual(result.body, { ok: true, klaviyo: 'synced' });
  assert.strictEqual(listDoc('me_at_example_com').klaviyoStatus, 'synced');
});

test('a Klaviyo failure still returns 200 and leaves the address stored', async () => {
  // The contract the whole module rests on. An address rejected at the door
  // because Klaviyo was down is gone for good — the user is already past the
  // screen.
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  const { result } = await withKlaviyo(new Error('ECONNRESET'), () =>
    callCollect(post({ email: 'me@example.com' })));
  assert.strictEqual(result.statusCode, 200);
  assert.strictEqual(result.body.klaviyo, 'pending');
  assert.strictEqual(listDoc('me_at_example_com').email, 'me@example.com');
  assert.match(listDoc('me_at_example_com').klaviyoError, /ECONNRESET/);
});

test('a failed status update does not fail an already-saved address', async () => {
  // By this point the address is in Firestore and the user is past the screen.
  // Failing the request over a bookkeeping write would make the client retry
  // and report a loss that did not happen.
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  updateShouldThrow = true;
  const { result } = await withKlaviyo(accepted, () =>
    callCollect(post({ email: 'me@example.com' })));
  assert.strictEqual(result.statusCode, 200);
  assert.strictEqual(result.body.ok, true);
  assert.strictEqual(listDoc('me_at_example_com').email, 'me@example.com');
});

test('collectEmail passes the onboarding arm through to Klaviyo', async () => {
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  const { calls } = await withKlaviyo(accepted, () =>
    callCollect(post({ email: 'me@example.com', variant: 'warfare', burden: 'peace' })));
  const attrs = JSON.parse(calls[0].init.body).data.attributes.profiles.data[0].attributes;
  assert.strictEqual(attrs.properties.speaklife_onboarding_variant, 'warfare');
  assert.strictEqual(attrs.properties.speaklife_burden, 'peace');
});

// ─── Rate limiting ──────────────────────────────────────────────────────────

test('collectEmail counts submissions per caller IP', async () => {
  const req = () => ({ method: 'POST', body: { email: 'me@example.com' }, headers: { 'x-forwarded-for': '9.9.9.9' } });
  for (let i = 0; i < 10; i += 1) {
    assert.strictEqual((await callCollect(req())).statusCode, 200, `submission ${i + 1}`);
  }
  const blocked = await callCollect(req());
  assert.strictEqual(blocked.statusCode, 429);
  assert.strictEqual(blocked.body.error, 'rate_limited');
});

test('the limit is per IP, not global', async () => {
  const from = (ip) => ({ method: 'POST', body: { email: 'me@example.com' }, headers: { 'x-forwarded-for': ip } });
  for (let i = 0; i < 10; i += 1) await callCollect(from('1.1.1.1'));
  assert.strictEqual((await callCollect(from('1.1.1.1'))).statusCode, 429);
  // A different caller is unaffected.
  assert.strictEqual((await callCollect(from('2.2.2.2'))).statusCode, 200);
});

test('collectEmail takes the client IP from the front of x-forwarded-for', async () => {
  // Behind Google's front end the header is a list; the last entry is a proxy.
  // Keying on it would rate-limit every user behind that hop as one caller.
  const a = { method: 'POST', body: { email: 'a@example.com' }, headers: { 'x-forwarded-for': '5.5.5.5, 10.0.0.1' } };
  const b = { method: 'POST', body: { email: 'b@example.com' }, headers: { 'x-forwarded-for': '6.6.6.6, 10.0.0.1' } };
  for (let i = 0; i < 10; i += 1) await callCollect(a);
  assert.strictEqual((await callCollect(a)).statusCode, 429);
  assert.strictEqual((await callCollect(b)).statusCode, 200, 'shared proxy hop must not merge callers');
});

test('a rate-limit failure lets the submission through', async () => {
  // Fail open: a Firestore hiccup must never start rejecting real addresses at
  // the one moment we get to ask for them.
  getShouldThrow = true;
  const res = await callCollect(post({ email: 'me@example.com' }));
  // Still 500 from the storage write, but NOT 429 — the limiter did not block.
  assert.notStrictEqual(res.statusCode, 429);
});

// ─── Retry sweep ────────────────────────────────────────────────────────────

/** onSchedule handlers expose the body as `.run()`. */
const runSweep = () => fns.retryKlaviyoSync.run({});

test('the sweep does nothing while Klaviyo is unconfigured', async () => {
  sweepDocs = [{ __id: 'a', email: 'a@example.com', klaviyoStatus: 'pending' }];
  await runSweep();
  assert.strictEqual(writes.length, 0);
});

test('the sweep marks a recovered address synced', async () => {
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  sweepDocs = [{ __id: 'a', email: 'a@example.com', klaviyoStatus: 'pending', retryCount: 2 }];
  await withKlaviyo(accepted, runSweep);
  const update = writes.find((w) => w.kind === 'update');
  assert.strictEqual(update.payload.klaviyoStatus, 'synced');
  assert.strictEqual(update.payload.retryCount, undefined, 'a success must not bump the counter');
});

test('the sweep increments retryCount on a continued failure', async () => {
  // Without this the doc is retried forever and the ceiling never applies.
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  sweepDocs = [{ __id: 'a', email: 'a@example.com', klaviyoStatus: 'pending', retryCount: 2 }];
  await withKlaviyo({ status: 500, text: async () => 'boom' }, runSweep);
  const update = writes.find((w) => w.kind === 'update');
  assert.strictEqual(update.payload.klaviyoStatus, 'pending');
  assert.strictEqual(update.payload.retryCount, 3);
});

test('the sweep retires a doc with no email instead of retrying it forever', async () => {
  // Left `pending` it would occupy a slot in every future batch, crowding out
  // addresses that could actually be sent.
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  sweepDocs = [{ __id: 'a', klaviyoStatus: 'pending' }];
  const { calls } = await withKlaviyo(accepted, runSweep);
  assert.strictEqual(calls.length, 0, 'nothing to send');
  const update = writes.find((w) => w.kind === 'update');
  assert.strictEqual(update.payload.klaviyoStatus, 'unsendable');
});

test('the sweep re-sends the arm and burden it stored', async () => {
  process.env.KLAVIYO_API_KEY = 'pk_test';
  process.env.KLAVIYO_LIST_ID = 'WaeTSA';
  sweepDocs = [{
    __id: 'a', email: 'a@example.com', klaviyoStatus: 'pending',
    source: 'onboarding', variant: 'healing', burden: 'health', app_version: '4.65',
  }];
  const { calls } = await withKlaviyo(accepted, runSweep);
  const attrs = JSON.parse(calls[0].init.body).data.attributes.profiles.data[0].attributes;
  assert.strictEqual(attrs.properties.speaklife_onboarding_variant, 'healing');
  assert.strictEqual(attrs.properties.app_version, '4.65');
});
