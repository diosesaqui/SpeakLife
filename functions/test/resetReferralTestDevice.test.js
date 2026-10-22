/**
 * resetReferralTestDevice.test.js
 * The QA reset script, against fakes: no emulator, no Apple.
 *
 *   npm run test:reset
 *
 * DeviceCheck bits survive deleting the app and erasing the phone, so without
 * this script every test phone can be counted once, ever. These tests pin the
 * two things that make the script safe to keep in the repo: it refuses to run
 * without an explicit QA confirmation, and it never prints a token in full.
 */

const assert = require('node:assert');
const { test } = require('node:test');
const R = require('../scripts/resetReferralTestDevice');
const DC = require('../deviceCheck');

function fakeDc(initial = { bit0: true, bit1: true }) {
  const state = { ...initial };
  const calls = [];
  return {
    state, calls,
    async queryBits(token, opts) { calls.push(['query', token, opts]); return { ...state }; },
    async setBits(token, bits, opts) { calls.push(['set', token, bits, opts]); Object.assign(state, bits); return true; },
  };
}

function fakeDb(docs = {}) {
  const store = new Map(Object.entries(docs));
  const deleted = [];
  const ref = (path) => ({
    path,
    async get() { return { exists: store.has(path), data: () => store.get(path) }; },
    async delete() { deleted.push(path); store.delete(path); },
    collection: (sub) => col(`${path}/${sub}`),
  });
  const col = (path) => ({
    doc: (id) => ref(`${path}/${id}`),
    async get() {
      const prefix = `${path}/`;
      const docs = [...store.keys()].filter((k) => k.startsWith(prefix) && !k.slice(prefix.length).includes('/'));
      return { docs: docs.map((k) => ({ ref: ref(k), id: k.slice(prefix.length) })) };
    },
    where: (field, op, value) => ({
      async get() {
        const prefix = `${path}/`;
        const hits = [...store.entries()].filter(([k, v]) => k.startsWith(prefix) && v && v[field] === value);
        return { docs: hits.map(([k]) => ({ ref: ref(k), id: k.slice(prefix.length) })) };
      },
    }),
  });
  return { store, deleted, collection: col };
}

const TOKEN = 'AgAAAExampleDeviceCheckTokenXYZ1234';

function run(argv, deps = {}) {
  const lines = [];
  const dc = deps.dc || fakeDc();
  const db = deps.db || fakeDb();
  return R.main(argv, { dc, db, out: (l) => lines.push(l) }).then((code) => ({ code, lines, dc, db }));
}

// ─── Arguments ──────────────────────────────────────────────────────────────

test('RST-01 refuses without --confirm-qa, and writes nothing', async () => {
  const { code, dc, db } = await run(['--token', TOKEN]);
  assert.strictEqual(code, 2);
  assert.ok(!dc.calls.some((c) => c[0] === 'set'));
  assert.strictEqual(db.deleted.length, 0);
});

test('RST-02 needs at least one of --token, --uid, --referrer', () => {
  assert.strictEqual(R.parseArgs(['--confirm-qa']).ok, false);
  assert.strictEqual(R.parseArgs(['--confirm-qa', '--uid', 'u1']).ok, true);
});

test('RST-03 unknown arguments are rejected', () => {
  assert.strictEqual(R.parseArgs(['--confirm-qa', '--token', TOKEN, '--wipe-everything']).ok, false);
});

// ─── Device bits ────────────────────────────────────────────────────────────

test('RST-04 clears both DeviceCheck bits for the token', async () => {
  const { code, dc } = await run(['--confirm-qa', '--token', TOKEN]);
  assert.strictEqual(code, 0);
  assert.deepStrictEqual(dc.state, { bit0: false, bit1: false });
  const set = dc.calls.find((c) => c[0] === 'set');
  assert.deepStrictEqual(set[2], { bit0: false, bit1: false });
  assert.deepStrictEqual(set[3], { isDevelopment: false });
});

test('RST-05 --development targets Apple\'s development environment', async () => {
  const { dc } = await run(['--confirm-qa', '--token', TOKEN, '--development']);
  assert.ok(dc.calls.every((c) => c[c.length - 1].isDevelopment === true));
});

test('RST-06 --dry-run reads the bits but writes nothing', async () => {
  const { code, dc, db } = await run(['--confirm-qa', '--dry-run', '--token', TOKEN, '--uid', 'u1'],
    { db: fakeDb({ 'referralClaims/u1': { outcome: 'credited' } }) });
  assert.strictEqual(code, 0);
  assert.ok(dc.calls.some((c) => c[0] === 'query'));
  assert.ok(!dc.calls.some((c) => c[0] === 'set'));
  assert.strictEqual(db.deleted.length, 0);
});

test('RST-07 never prints the token in full', async () => {
  const { lines } = await run(['--confirm-qa', '--token', TOKEN]);
  const all = lines.join('\n');
  assert.ok(!all.includes(TOKEN), 'full token leaked');
  assert.ok(all.includes(TOKEN.slice(-4)), 'last four shown for identification');
});

// ─── Firestore records ──────────────────────────────────────────────────────

test('RST-08 --uid deletes that friend\'s final claim so they can claim again', async () => {
  const db = fakeDb({ 'referralClaims/u1': { outcome: 'credited' } });
  const { code } = await run(['--confirm-qa', '--uid', 'u1'], { db });
  assert.strictEqual(code, 0);
  assert.deepStrictEqual(db.deleted, ['referralClaims/u1']);
});

test('RST-09 --referrer deletes the record, its credits and its codes', async () => {
  const db = fakeDb({
    'referrals/R': { code: 'K7MQ2XPA', count: 2 },
    'referrals/R/credits/f1': { friendUid: 'f1' },
    'referrals/R/credits/f2': { friendUid: 'f2' },
    'referralCodes/K7MQ2XPA': { uid: 'R' },
    'referralCodes/ALIAS234': { uid: 'R', aliasOf: 'K7MQ2XPA' },
    'referralCodes/OTHER234': { uid: 'someoneElse' },
  });
  await run(['--confirm-qa', '--referrer', 'R'], { db });
  assert.deepStrictEqual([...db.store.keys()], ['referralCodes/OTHER234']);
});

test('RST-10 --referrer leaves an assigned reward code in the pool untouched', async () => {
  const db = fakeDb({
    'referrals/R': { code: 'K7MQ2XPA', reward: { code: 'OFFER1' } },
    'referralRewardCodes/OFFER1': { assignedTo: 'R' },
  });
  const { lines } = await run(['--confirm-qa', '--referrer', 'R'], { db });
  assert.ok(db.store.has('referralRewardCodes/OFFER1'), 'a possibly redeemed code is never recycled');
  assert.ok(lines.some((l) => /reward code/i.test(l) && l.includes('FER1')), 'says which reward it left');
  assert.ok(!lines.join('\n').includes('OFFER1'), 'never prints the reward code in full');
});

test('RST-11 a missing record is reported, not an error', async () => {
  const { code, lines } = await run(['--confirm-qa', '--uid', 'ghost']);
  assert.strictEqual(code, 0);
  assert.ok(lines.some((l) => /no claim/i.test(l)));
});

// ─── DeviceCheck client: exact write ────────────────────────────────────────

test('RST-12 deviceCheck.setBits writes both bits exactly in one update', async () => {
  const { generateKeyPairSync } = require('node:crypto');
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const keyP8 = privateKey.export({ type: 'pkcs8', format: 'pem' });
  const sent = [];
  const client = DC.createAppleDeviceCheck({
    keyP8, keyId: 'KID', teamId: 'TEAM', now: () => 1_790_000_000_000,
    fetch: async (url, init) => { sent.push({ url, body: JSON.parse(init.body) }); return { status: 200, text: async () => '' }; },
  });
  await client.setBits('tok', { bit0: false, bit1: false }, { isDevelopment: true });
  assert.strictEqual(sent.length, 1, 'no read-modify-write');
  assert.ok(sent[0].url.startsWith(DC.DEVELOPMENT_HOST));
  assert.ok(sent[0].url.endsWith('/v1/update_two_bits'));
  assert.strictEqual(sent[0].body.bit0, false);
  assert.strictEqual(sent[0].body.bit1, false);
});
