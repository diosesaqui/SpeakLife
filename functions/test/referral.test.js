/**
 * referral.test.js
 * Cloud Function tests for "Invite friends, get a year free", run against the
 * Firestore emulator.
 *
 *   npm run test:referral
 *
 * Every test is named after its row in docs/REFERRAL_BE_TDD.md (BE-HLP-01 and
 * so on), so a failing name points straight at the case it covers.
 *
 * Same harness as standTogether.test.js, plus three injection seams on the
 * module's __test export:
 *
 *   H.setNow(fn)            the clock every function in referral.js reads.
 *                           Windows and caps are tested by moving it, never
 *                           by sleeping.
 *   H.setDeviceCheck(fake)  Apple's DeviceCheck. The fake keeps two bits per
 *                           token and can be told to fail like Apple does.
 *   H.setCodeGenerator(fn)  forced collisions for BE-ENR-05/06.
 *
 * FCM and Auth are stubbed before either module loads.
 */

process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ||= 'speaklife-fn-test';

const assert = require('node:assert');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// Stub messaging BEFORE the modules are required, since they grab
// getMessaging() at module load.
const admin = require('firebase-admin/messaging');
const sent = [];
let failPush = false;
const originalGetMessaging = admin.getMessaging;
admin.getMessaging = () => ({
  send: async (msg) => {
    if (failPush) throw new Error('fcm down');
    sent.push(msg);
    return 'stub';
  },
});

// Auth: deleteUser is a no-op; getUser answers from `accounts` so a test can
// give a friend an account creation time (the "link captured on a previous
// install" check). An unknown uid behaves like Firebase: user-not-found.
const accounts = new Map();
const adminAuth = require('firebase-admin/auth');
adminAuth.getAuth = () => ({
  deleteUser: async () => {},
  getUser: async (uid) => {
    if (!accounts.has(uid)) {
      const err = new Error('no user'); err.code = 'auth/user-not-found'; throw err;
    }
    return { uid, metadata: { creationTime: new Date(accounts.get(uid)).toUTCString() } };
  },
});

const fns   = require('../referral');
const stand = require('../standTogether');
const DC    = require('../deviceCheck');
const H     = fns.__test;

const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const db = getFirestore();

const DAY  = 86400000;
const HOUR = 3600000;
const T0   = Date.UTC(2026, 9, 1, 12, 0, 0);   // a fixed "now" for every test

// ─── Fakes ──────────────────────────────────────────────────────────────────

/**
 * Apple's DeviceCheck, in memory. Two bits per token. `down` makes every call
 * throw the way an unreachable Apple does; `invalid` holds tokens Apple rejects
 * as malformed; `failUpdate` makes only the bit write fail.
 */
function makeFakeDeviceCheck() {
  const fake = {
    bits: new Map(),
    invalid: new Set(),
    down: false,
    failUpdate: false,
    queries: 0,
    updates: 0,
    reset() {
      this.bits.clear(); this.invalid.clear();
      this.down = false; this.failUpdate = false;
      this.queries = 0; this.updates = 0;
    },
    async queryBits(token) {
      this.queries += 1;
      if (this.down) throw new DC.DeviceCheckError('unavailable', 'apple down');
      if (this.invalid.has(token)) throw new DC.DeviceCheckError('invalid_token', 'bad token');
      return { ...(this.bits.get(token) || { bit0: false, bit1: false }) };
    },
    async setBit(token, which) {
      this.updates += 1;
      if (this.down || this.failUpdate) throw new DC.DeviceCheckError('unavailable', 'apple down');
      if (this.invalid.has(token)) throw new DC.DeviceCheckError('invalid_token', 'bad token');
      const cur = this.bits.get(token) || { bit0: false, bit1: false };
      this.bits.set(token, { ...cur, [`bit${which}`]: true });
    },
  };
  return fake;
}
const dc = makeFakeDeviceCheck();
H.setDeviceCheck(dc);

let now = T0;
H.setNow(() => now);
const advance = (ms) => { now += ms; };

// ─── Helpers ────────────────────────────────────────────────────────────────

const req = (uid, data = {}) => ({ auth: uid ? { uid } : undefined, data });

async function expectCode(fn, code) {
  try {
    await fn();
    assert.fail(`expected ${code}, but the call succeeded`);
  } catch (err) {
    assert.strictEqual(err.code, code, `expected ${code}, got ${err.code}: ${err.message}`);
  }
}

const DEFAULT_CONFIG = {
  enabled: true, target: 5, windowDays: 14, dailyCap: 5, minCodeValidityDays: 30,
};

async function setConfig(overrides = {}) {
  await db.collection('referralConfig').doc('current').set({ ...DEFAULT_CONFIG, ...overrides });
}

async function deleteCollection(ref) {
  const snap = await ref.get();
  await Promise.all(snap.docs.map(async (d) => {
    for (const sub of await d.ref.listCollections()) await deleteCollection(sub);
    await d.ref.delete();
  }));
}

async function wipe() {
  sent.length = 0;
  failPush = false;
  accounts.clear();
  dc.reset();
  H.setCodeGenerator(null);
  now = T0;
  for (const c of ['referrals', 'referralCodes', 'referralClaims', 'referralRewardCodes',
                   'referralConfig', 'referralRateLimits', 'referralBitRetries', 'users',
                   'accountMerges', 'standRooms', 'standInvites', 'standNudges',
                   'standRateLimits']) {
    await deleteCollection(db.collection(c));
  }
  await setConfig();
}

/** Gives a user an FCM token so a push is actually attempted. */
async function withToken(uid) {
  await db.collection('users').doc(uid).set({ uid, fcmToken: `tok_${uid}` }, { merge: true });
}

async function enroll(uid = 'R', data = {}) {
  return fns.getOrCreateReferral.run(req(uid, data));
}

/** A claim from `friendUid` with sane defaults: fresh capture, own device. */
async function claim(friendUid, code, overrides = {}) {
  return fns.claimReferral.run(req(friendUid, {
    code,
    capturedAt: now - 60000,
    source: 'deferred',
    deviceToken: `dev_${friendUid}`,
    ...overrides,
  }));
}

/** `n` distinct friends on `n` distinct devices, each claiming `code`. */
let friendSeq = 0;
async function creditN(code, n, { prefix = 'f' } = {}) {
  const out = [];
  for (let i = 0; i < n; i++) {
    friendSeq += 1;
    out.push(await claim(`${prefix}${friendSeq}`, code));
  }
  return out;
}

/** `n` offer codes in the pool, all expiring `expiresInDays` from now. */
async function seedPool(n, { expiresInDays = 180, prefix = 'OFFER' } = {}) {
  const codes = [];
  const batch = db.batch();
  for (let i = 0; i < n; i++) {
    const code = `${prefix}${String(i).padStart(4, '0')}`;
    codes.push(code);
    batch.set(db.collection('referralRewardCodes').doc(code), {
      code, batchId: 'test', expiresAt: Timestamp.fromMillis(now + expiresInDays * DAY),
      assignedTo: null, assignedAt: null,
    });
  }
  await batch.commit();
  return codes;
}

const referral = async (uid) => (await db.collection('referrals').doc(uid).get()).data();
const claimDoc = async (uid) => db.collection('referralClaims').doc(uid).get();
const countDocs = async (c) => (await db.collection(c).get()).size;

/** Captures console output for log assertions. */
async function captureLogs(fn) {
  const logs = { warn: [], error: [], log: [] };
  const orig = { warn: console.warn, error: console.error, log: console.log };
  console.warn  = (...a) => logs.warn.push(a.join(' '));
  console.error = (...a) => logs.error.push(a.join(' '));
  console.log   = (...a) => logs.log.push(a.join(' '));
  try { await fn(); } finally { Object.assign(console, orig); }
  return logs;
}

test.beforeEach(wipe);
test.after(() => { admin.getMessaging = originalGetMessaging; });

// ═══ 2. Pure helpers (BE-HLP) ════════════════════════════════════════════════

test('BE-HLP-01 generateCode: 20k draws, unique, in alphabet, uniform', () => {
  const seen = new Set();
  const freq = Object.fromEntries([...H.CODE_ALPHABET].map((c) => [c, 0]));
  const N = 20000;
  for (let i = 0; i < N; i++) {
    const code = H.generateCode();
    assert.strictEqual(code.length, 8);
    seen.add(code);
    for (const ch of code) {
      assert.ok(ch in freq, `'${ch}' is outside the alphabet`);
      freq[ch] += 1;
    }
  }
  assert.strictEqual(seen.size, N, 'collision in 20k codes');
  const expected = (N * 8) / H.CODE_ALPHABET.length;
  for (const [ch, n] of Object.entries(freq)) {
    const drift = Math.abs(n - expected) / expected;
    assert.ok(drift < 0.2, `'${ch}' drifted ${(drift * 100).toFixed(1)}% from even`);
  }
});

test('BE-HLP-02 normalizeCode lowercases and strips a dash', () => {
  assert.strictEqual(H.normalizeCode('k7mq-2xpa'), 'K7MQ2XPA');
});

test('BE-HLP-03 normalizeCode rejects confusables, bad lengths and non-strings', () => {
  for (const bad of ['K7MQ0XPA', 'K7MQOXPA', 'K7MQ1XPA', 'K7MQIXPA', 'K7MQLXPA',
                     'K7MQ2XP', 'K7MQ2XPAB', null, 12345678, '']) {
    assert.strictEqual(H.normalizeCode(bad), null, `${bad} should be rejected`);
  }
});

test('BE-HLP-04 normalizeCode strips spaces, dashes and unicode separators, then validates', () => {
  assert.strictEqual(H.normalizeCode(' K7MQ 2XPA '), 'K7MQ2XPA');
  assert.strictEqual(H.normalizeCode('K7MQ—2XPA'), 'K7MQ2XPA');   // em dash
  assert.strictEqual(H.normalizeCode('K7MQ 2XPA'), 'K7MQ2XPA');   // nbsp
  assert.strictEqual(H.normalizeCode('K7MQ ​2XPA'), 'K7MQ2XPA');
  assert.strictEqual(H.normalizeCode('--------'), null);
});

test('BE-HLP-04 normalizeCode agrees with the client on the shared fixture, row for row', () => {
  const fixture = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..',
    'Packages/SpeakLifeKit/Tests/SpeakLifeCoreTests/Resources/referral_codes_fixture.json'), 'utf8'));
  assert.ok(fixture.length > 10);
  for (const { input, expected } of fixture) {
    assert.strictEqual(H.normalizeCode(input), expected, `input ${JSON.stringify(input)}`);
  }
});

test('BE-HLP-05 validateCapturedAt inside the window is ok', () => {
  assert.strictEqual(H.validateCapturedAt(T0 - 3 * DAY, T0 - 4 * DAY, T0, 14), 'ok');
  assert.strictEqual(H.validateCapturedAt(T0 - 1000, null, T0, 14), 'ok');
});

test('BE-HLP-06 validateCapturedAt exactly at the window edge is ok (inclusive)', () => {
  assert.strictEqual(H.validateCapturedAt(T0 - 14 * DAY, null, T0, 14), 'ok');
});

test('BE-HLP-07 validateCapturedAt one second past the window is expired', () => {
  assert.strictEqual(H.validateCapturedAt(T0 - 14 * DAY - 1000, null, T0, 14), 'expired');
});

test('BE-HLP-08 validateCapturedAt in the future beyond 5 minutes of skew is expired', () => {
  assert.strictEqual(H.validateCapturedAt(T0 + 5 * 60000, null, T0, 14), 'ok');
  assert.strictEqual(H.validateCapturedAt(T0 + 5 * 60000 + 1000, null, T0, 14), 'expired');
});

test('BE-HLP-09 validateCapturedAt more than 5 minutes before the account existed is expired', () => {
  const created = T0 - DAY;
  assert.strictEqual(H.validateCapturedAt(created - 5 * 60000, created, T0, 14), 'ok');
  assert.strictEqual(H.validateCapturedAt(created - 5 * 60000 - 1000, created, T0, 14), 'expired');
});

test('BE-HLP-10 validateCapturedAt missing, non-number or NaN is invalid_argument', () => {
  for (const bad of [undefined, null, '1700000000000', NaN, Infinity, {}]) {
    assert.strictEqual(H.validateCapturedAt(bad, null, T0, 14), 'invalid_argument', String(bad));
  }
});

const poolEntry = (code, expiresInDays, extra = {}) => ({
  code, expiresAt: T0 + expiresInDays * DAY, assignedTo: null, ...extra,
});

test('BE-HLP-11 pickRewardCode takes the soonest-expiring code still valid long enough', () => {
  const pool = [poolEntry('LATE', 300), poolEntry('SOON', 31), poolEntry('MID', 90),
                poolEntry('TOO_SOON', 29)];
  assert.strictEqual(H.pickRewardCode(pool, T0, 30).code, 'SOON');
  // Timestamps work as well as millis.
  const ts = pool.map((p) => ({ ...p, expiresAt: Timestamp.fromMillis(p.expiresAt) }));
  assert.strictEqual(H.pickRewardCode(ts, T0, 30).code, 'SOON');
});

test('BE-HLP-12 pickRewardCode returns null when every code expires within the minimum', () => {
  assert.strictEqual(H.pickRewardCode([poolEntry('A', 10), poolEntry('B', 29)], T0, 30), null);
  assert.strictEqual(H.pickRewardCode([], T0, 30), null);
});

test('BE-HLP-13 pickRewardCode skips assigned and retired codes', () => {
  const pool = [poolEntry('TAKEN', 31, { assignedTo: 'someone' }),
                poolEntry('RETIRED', 32, { retired: true }),
                poolEntry('FREE', 200)];
  assert.strictEqual(H.pickRewardCode(pool, T0, 30).code, 'FREE');
});

test('BE-HLP-14 readConfig with no document is the defaults, switched off', () => {
  assert.deepStrictEqual(H.readConfig(undefined), {
    enabled: false, target: 5, windowDays: 14, dailyCap: 5, minCodeValidityDays: 30,
  });
});

test('BE-HLP-15 readConfig fills missing fields and rejects a bad target', () => {
  assert.deepStrictEqual(H.readConfig({ enabled: true, target: 3 }), {
    enabled: true, target: 3, windowDays: 14, dailyCap: 5, minCodeValidityDays: 30,
  });
  for (const bad of [0, -1, 2.5, '3', null, NaN]) {
    assert.strictEqual(H.readConfig({ enabled: true, target: bad }).target, 5, `target ${bad}`);
  }
  // Only a literal true switches the feature on.
  assert.strictEqual(H.readConfig({ enabled: 'yes' }).enabled, false);
});

// BE-HLP-16: the merge rules on plain objects. The emulator versions are BE-MRG.
const side = (uid, code, friends, extra = {}) => ({
  record: {
    uid, code, target: 5, count: friends.length, status: 'active',
    createdAt: T0 - 10 * DAY, updatedAt: T0 - DAY, unlockedAt: null, reward: null, ...extra,
  },
  credits: Object.fromEntries(friends.map((f, i) =>
    [f, { friendUid: f, creditedAt: T0 - (10 - i) * HOUR, source: 'deferred', deviceVerified: true }])),
});

test('BE-HLP-16 mergeReferrals: neither side has one, no plan', () => {
  assert.strictEqual(H.mergeReferrals(null, null, 'P', T0), null);
});

test('BE-HLP-16 mergeReferrals: only the source, record re-keyed to the target', () => {
  const plan = H.mergeReferrals(side('A', 'AAAAAAAA', ['f1', 'f2']), null, 'P', T0);
  assert.strictEqual(plan.record.uid, 'P');
  assert.strictEqual(plan.record.code, 'AAAAAAAA');
  assert.strictEqual(plan.record.count, 2);
  assert.deepStrictEqual(Object.keys(plan.credits).sort(), ['f1', 'f2']);
  assert.strictEqual(plan.keepCode, 'AAAAAAAA');
  assert.strictEqual(plan.revokeCode, null);
});

test('BE-HLP-16 mergeReferrals: only the target, nothing to do', () => {
  assert.strictEqual(H.mergeReferrals(null, side('P', 'PPPPPPPP', ['f1']), 'P', T0), null);
});

test('BE-HLP-16 mergeReferrals: both, credits unioned, the code with more credits kept', () => {
  const plan = H.mergeReferrals(side('A', 'AAAAAAAA', ['f1', 'f2', 'f4']),
                                side('P', 'PPPPPPPP', ['f2', 'f3']), 'P', T0);
  assert.strictEqual(plan.record.count, 4);
  assert.deepStrictEqual(Object.keys(plan.credits).sort(), ['f1', 'f2', 'f3', 'f4']);
  assert.strictEqual(plan.keepCode, 'AAAAAAAA');
  assert.strictEqual(plan.revokeCode, 'PPPPPPPP');
  assert.strictEqual(plan.record.code, 'AAAAAAAA');
  assert.strictEqual(plan.record.uid, 'P');
  assert.strictEqual(plan.needsRewardCode, false);
  assert.strictEqual(plan.record.status, 'active');
});

test('BE-HLP-16 mergeReferrals: union reaching the target needs a reward code', () => {
  const plan = H.mergeReferrals(side('A', 'AAAAAAAA', ['f1', 'f2', 'f3']),
                                side('P', 'PPPPPPPP', ['f3', 'f4', 'f5']), 'P', T0);
  assert.strictEqual(plan.record.count, 5);
  assert.strictEqual(plan.needsRewardCode, true);
});

test('BE-HLP-16 mergeReferrals: one reward is kept, the lower target is kept', () => {
  const reward = { code: 'OFFER1', assignedAt: T0 - 2 * DAY, expiresAt: T0 + 100 * DAY, reissueCount: 0 };
  const plan = H.mergeReferrals(
    side('A', 'AAAAAAAA', ['f1', 'f2', 'f3'], { target: 3, status: 'unlocked', unlockedAt: T0 - 2 * DAY, reward }),
    side('P', 'PPPPPPPP', ['f9'], { target: 5 }), 'P', T0);
  assert.strictEqual(plan.record.target, 3);
  assert.strictEqual(plan.record.status, 'unlocked');
  assert.strictEqual(plan.record.reward.code, 'OFFER1');
  assert.strictEqual(plan.needsRewardCode, false);
  assert.deepStrictEqual(plan.releaseRewardCodes, []);
  assert.deepStrictEqual(plan.retireRewardCodes, []);
});

test('BE-HLP-16 mergeReferrals: two rewards, earlier kept, the other released or retired by age', () => {
  const r = (code, ageMs) => ({ code, assignedAt: T0 - ageMs, expiresAt: T0 + 100 * DAY, reissueCount: 0 });
  const unlocked = (reward) => ({ status: 'unlocked', unlockedAt: reward.assignedAt, reward, target: 3 });
  const fr = ['f1', 'f2', 'f3'];

  const fresh = H.mergeReferrals(side('A', 'AAAAAAAA', fr, unlocked(r('OLD', 5 * DAY))),
                                 side('P', 'PPPPPPPP', fr, unlocked(r('NEW', 2 * HOUR))), 'P', T0);
  assert.strictEqual(fresh.record.reward.code, 'OLD');
  assert.deepStrictEqual(fresh.releaseRewardCodes, ['NEW']);
  assert.deepStrictEqual(fresh.retireRewardCodes, []);

  const stale = H.mergeReferrals(side('A', 'AAAAAAAA', fr, unlocked(r('OLD', 5 * DAY))),
                                 side('P', 'PPPPPPPP', fr, unlocked(r('NEW', 2 * DAY))), 'P', T0);
  assert.strictEqual(stale.record.reward.code, 'OLD');
  assert.deepStrictEqual(stale.releaseRewardCodes, []);
  assert.deepStrictEqual(stale.retireRewardCodes, ['NEW']);
});

test('referral.js reads no clock or randomness directly (done checklist)', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'referral.js'), 'utf8')
    .replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/.*$/gm, '');
  assert.ok(!/Date\.now\(\)/.test(src), 'use now()');
  assert.ok(!/Math\.random\(\)/.test(src), 'use the crypto code generator');
  assert.ok(!/new Date\(\)/.test(src), 'use now()');
});

test('the DeviceCheck secrets are declared with defineSecret and never logged', () => {
  const src = fs.readFileSync(path.join(__dirname, '..', 'referral.js'), 'utf8');
  for (const name of ['DEVICECHECK_KEY_P8', 'DEVICECHECK_KEY_ID', 'DEVICECHECK_TEAM_ID']) {
    assert.match(src, new RegExp(`defineSecret\\('${name}'\\)`));
  }
  for (const line of src.split('\n').filter((l) => /console\./.test(l))) {
    assert.ok(!/DEVICECHECK|\.value\(\)|keyP8/.test(line), `logs a secret: ${line.trim()}`);
  }
});

test('index.js exports the referral functions for deploy', () => {
  // Read, not required: prayerWallNotifications.js initialises the default app
  // unconditionally, which only works when it loads first, as it does in
  // production through index.js.
  const index = fs.readFileSync(path.join(__dirname, '..', 'index.js'), 'utf8');
  assert.match(index, /\.\.\.require\('\.\/referral'\)/);
  for (const name of ['getOrCreateReferral', 'claimReferral', 'reissueReferralReward', 'referralSweep']) {
    assert.ok(fns[name]?.__endpoint, `${name} is not a Cloud Function`);
  }
  assert.ok(fns.referralSweep.__endpoint.scheduleTrigger, 'referralSweep is scheduled');
  // The account hooks are plain functions: deploy must not see them as triggers.
  assert.strictEqual(fns.__accountHooks.mergeReferralAccounts.__endpoint, undefined);
});

// ─── DeviceCheck client (no network) ────────────────────────────────────────

function p256() {
  const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  return { pem: privateKey.export({ type: 'pkcs8', format: 'pem' }), publicKey };
}
const b64urlJson = (s) => JSON.parse(Buffer.from(s, 'base64url').toString('utf8'));

test('DeviceCheck JWT is ES256, carries kid/iss/iat, and verifies with the public key', () => {
  const { pem, publicKey } = p256();
  const jwt = DC.buildJwt({ keyP8: pem, keyId: 'KEY123', teamId: 'TEAM456', nowSec: 1_800_000_000 });
  const [h, p, s] = jwt.split('.');
  assert.deepStrictEqual(b64urlJson(h), { alg: 'ES256', kid: 'KEY123' });
  assert.deepStrictEqual(b64urlJson(p), { iss: 'TEAM456', iat: 1_800_000_000 });
  const sig = Buffer.from(s, 'base64url');
  assert.strictEqual(sig.length, 64, 'ES256 signatures are raw r||s, not DER');
  assert.ok(crypto.verify('sha256', Buffer.from(`${h}.${p}`),
    { key: publicKey, dsaEncoding: 'ieee-p1363' }, sig));
});

test('DeviceCheck JWT accepts a .p8 pasted with literal \\n escapes', () => {
  const { pem, publicKey } = p256();
  const flattened = pem.trim().replace(/\n/g, '\\n');
  const jwt = DC.buildJwt({ keyP8: flattened, keyId: 'K', teamId: 'T', nowSec: 1 });
  const [h, p, s] = jwt.split('.');
  assert.ok(crypto.verify('sha256', Buffer.from(`${h}.${p}`),
    { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url')));
});

test('DeviceCheck query parsing: never-set device answers plain text, read as both bits clear', () => {
  assert.deepStrictEqual(DC.parseQueryResponse(200, 'Failed to find bit state'),
    { bit0: false, bit1: false });
  assert.deepStrictEqual(DC.parseQueryResponse(200,
    '{"bit0":true,"bit1":false,"last_update_time":"2026-10"}'), { bit0: true, bit1: false });
  assert.deepStrictEqual(DC.parseQueryResponse(200, '{"bit1":true}'), { bit0: false, bit1: true });
});

test('DeviceCheck query parsing: 400 is an invalid token, anything else is Apple unavailable', () => {
  const kind = (status, text) => {
    try { DC.parseQueryResponse(status, text); return 'ok'; } catch (e) {
      assert.ok(e instanceof DC.DeviceCheckError); return e.kind;
    }
  };
  assert.strictEqual(kind(400, 'Missing or incorrectly formatted device token payload'), 'invalid_token');
  assert.strictEqual(kind(401, 'Unable to verify authorization token'), 'unavailable');
  assert.strictEqual(kind(500, ''), 'unavailable');
  assert.strictEqual(kind(200, 'something unexpected'), 'unavailable');
  assert.strictEqual(DC.parseUpdateResponse(200, ''), true);
  assert.throws(() => DC.parseUpdateResponse(400, 'bad'), (e) => e.kind === 'invalid_token');
  assert.throws(() => DC.parseUpdateResponse(503, ''), (e) => e.kind === 'unavailable');
});

test('DeviceCheck client: hosts, auth header, body, and setBit preserves the other bit', async () => {
  const { pem } = p256();
  const calls = [];
  const responses = [
    { status: 200, text: '{"bit0":false,"bit1":true}' },   // query before the update
    { status: 200, text: '' },                              // update
    { status: 200, text: 'Failed to find bit state' },      // development query
  ];
  const fakeFetch = async (url, init) => {
    calls.push({ url, init, body: JSON.parse(init.body) });
    const r = responses.shift();
    return { status: r.status, text: async () => r.text };
  };
  const client = DC.createAppleDeviceCheck({
    keyP8: pem, keyId: 'K', teamId: 'T', fetch: fakeFetch, now: () => 1_800_000_000_000,
  });

  await client.setBit('tokA', 0);
  assert.strictEqual(calls[0].url, 'https://api.devicecheck.apple.com/v1/query_two_bits');
  assert.strictEqual(calls[1].url, 'https://api.devicecheck.apple.com/v1/update_two_bits');
  assert.match(calls[0].init.headers.Authorization, /^Bearer [\w-]+\.[\w-]+\.[\w-]+$/);
  assert.strictEqual(calls[0].body.device_token, 'tokA');
  assert.strictEqual(calls[0].body.timestamp, 1_800_000_000_000);
  assert.ok(calls[0].body.transaction_id);
  assert.notStrictEqual(calls[0].body.transaction_id, calls[1].body.transaction_id);
  assert.strictEqual(calls[1].body.bit0, true);
  assert.strictEqual(calls[1].body.bit1, true, 'bit 1 was already set and must survive');

  const bits = await client.queryBits('tokB', { isDevelopment: true });
  assert.deepStrictEqual(bits, { bit0: false, bit1: false });
  assert.strictEqual(calls[2].url, 'https://api.development.devicecheck.apple.com/v1/query_two_bits');
});

test('DeviceCheck client: a network failure is Apple unavailable, not a bad token', async () => {
  const { pem } = p256();
  const client = DC.createAppleDeviceCheck({
    keyP8: pem, keyId: 'K', teamId: 'T',
    fetch: async () => { throw new TypeError('fetch failed'); }, now: () => 0,
  });
  await assert.rejects(() => client.queryBits('t'), (e) => e.kind === 'unavailable');
});

// ═══ 3. Config and kill switch (BE-CFG) ══════════════════════════════════════

test('BE-CFG-01 switch off, no record: failed-precondition and nothing written', async () => {
  await setConfig({ enabled: false });
  await expectCode(() => enroll('R'), 'failed-precondition');
  assert.strictEqual(await countDocs('referrals'), 0);
  assert.strictEqual(await countDocs('referralCodes'), 0);
});

test('BE-CFG-01 a missing config document means switched off', async () => {
  await db.collection('referralConfig').doc('current').delete();
  await expectCode(() => enroll('R'), 'failed-precondition');
});

test('BE-CFG-02 switch off, existing record: returned unchanged', async () => {
  const first = await enroll('R');
  await setConfig({ enabled: false });
  assert.deepStrictEqual(await enroll('R'), first);
});

test('BE-CFG-03 switch off, claim: rejected disabled and NOT final', async () => {
  const { code } = await enroll('R');
  await setConfig({ enabled: false });
  assert.deepStrictEqual(await claim('f1', code), { outcome: 'rejected', reason: 'disabled' });
  assert.strictEqual((await claimDoc('f1')).exists, false);
  assert.strictEqual((await referral('R')).count, 0);
});

test('BE-CFG-04 switch off, an unlocked referrer still sees their reward', async () => {
  const { code } = await enroll('R');
  await seedPool(3);
  await creditN(code, 5);
  await setConfig({ enabled: false });
  const res = await enroll('R');
  assert.strictEqual(res.status, 'unlocked');
  assert.ok(res.reward?.code, 'reward visible');
});

test('BE-CFG-05 a config target change never moves an enrolled referrer', async () => {
  await enroll('R1');
  await setConfig({ target: 3 });
  assert.strictEqual((await enroll('R1')).target, 5);
  assert.strictEqual((await enroll('R2')).target, 3);
});

// ═══ 4. Enrollment: getOrCreateReferral (BE-ENR) ═════════════════════════════

test('BE-ENR-01 no auth: unauthenticated', async () => {
  await expectCode(() => fns.getOrCreateReferral.run(req(null)), 'unauthenticated');
});

test('BE-ENR-02 first call creates the record and the code, pointing at each other', async () => {
  const res = await enroll('R');
  assert.deepStrictEqual(Object.keys(res).sort(), ['code', 'count', 'reward', 'status', 'target']);
  assert.strictEqual(H.normalizeCode(res.code), res.code);
  assert.deepStrictEqual({ ...res, code: 'x' },
    { code: 'x', count: 0, target: 5, status: 'active', reward: null });
  const rec = await referral('R');
  assert.strictEqual(rec.code, res.code);
  assert.strictEqual(rec.uid, 'R');
  const map = (await db.collection('referralCodes').doc(res.code).get()).data();
  assert.strictEqual(map.uid, 'R');
  assert.strictEqual(map.revoked, false);
});

test('BE-ENR-03 second call returns the same code and mints nothing', async () => {
  const a = await enroll('R');
  const b = await enroll('R');
  assert.strictEqual(b.code, a.code);
  assert.strictEqual(await countDocs('referralCodes'), 1);
});

test('BE-ENR-04 two concurrent calls: exactly one code, both get it', async () => {
  const [a, b] = await Promise.all([enroll('R'), enroll('R')]);
  assert.strictEqual(a.code, b.code);
  assert.strictEqual(await countDocs('referralCodes'), 1);
  assert.strictEqual((await referral('R')).code, a.code);
});

test('BE-ENR-05 a code collision retries with a fresh code, the first mapping untouched', async () => {
  const first = await enroll('R1');
  const queue = [first.code, 'BBBBBBBB'];
  H.setCodeGenerator(() => queue.shift());
  const second = await enroll('R2');
  assert.strictEqual(second.code, 'BBBBBBBB');
  assert.strictEqual((await db.collection('referralCodes').doc(first.code).get()).data().uid, 'R1');
});

test('BE-ENR-06 a generator that always collides gives up with internal, nothing written', async () => {
  const first = await enroll('R1');
  let calls = 0;
  H.setCodeGenerator(() => { calls += 1; return first.code; });
  await expectCode(() => enroll('R2'), 'internal');
  assert.strictEqual(calls, 5);
  assert.strictEqual((await db.collection('referrals').doc('R2').get()).exists, false);
  assert.strictEqual(await countDocs('referralCodes'), 1);
});

test('BE-ENR-07 with a device token, DeviceCheck bit 1 is set', async () => {
  await enroll('R', { deviceToken: 'devR' });
  assert.deepStrictEqual(dc.bits.get('devR'), { bit0: false, bit1: true });
});

test('BE-ENR-08 without a device token: enrolls, DeviceCheck not called, a warning logged', async () => {
  let res;
  const logs = await captureLogs(async () => { res = await enroll('R'); });
  assert.strictEqual(res.status, 'active');
  assert.strictEqual(dc.updates + dc.queries, 0);
  assert.ok(logs.warn.some((l) => /deviceToken/i.test(l)), logs.warn.join('\n'));
});

test('BE-ENR-09 DeviceCheck down during enrollment: still enrolls, retry queued', async () => {
  dc.down = true;
  let res;
  await captureLogs(async () => { res = await enroll('R', { deviceToken: 'devR' }); });
  assert.strictEqual(res.status, 'active');
  const q = (await db.collection('referralBitRetries').get()).docs.map((d) => d.data());
  assert.strictEqual(q.length, 1);
  assert.strictEqual(q[0].deviceToken, 'devR');
  assert.strictEqual(q[0].bit, 1);
});

test('BE-ENR-10 the 21st call in an hour is resource-exhausted', async () => {
  for (let i = 0; i < 20; i++) await enroll('R');
  await expectCode(() => enroll('R'), 'resource-exhausted');
  advance(HOUR + 1000);
  await assert.doesNotReject(() => enroll('R'));
});

test('BE-ENR-11 the response carries no friend uids and no credits', async () => {
  const { code } = await enroll('R');
  await creditN(code, 2, { prefix: 'secretfriend' });
  const res = await enroll('R');
  assert.deepStrictEqual(Object.keys(res).sort(), ['code', 'count', 'reward', 'status', 'target']);
  assert.strictEqual(res.count, 2);
  assert.ok(!/secretfriend|dev_/.test(JSON.stringify(res)));
});

test('BE-ENR-12 an anonymous auth uid may enroll', async () => {
  const res = await fns.getOrCreateReferral.run({
    auth: { uid: 'anonR', token: { firebase: { sign_in_provider: 'anonymous' } } }, data: {},
  });
  assert.strictEqual(res.status, 'active');
});

// ═══ 5. Claims: claimReferral (BE-CLM) ═══════════════════════════════════════

/** Asserts a rejection: reason, count unchanged, no push, and finality. */
async function expectRejected(res, reason, { friend, final = true, referrer = 'R', count = 0 } = {}) {
  assert.deepStrictEqual(res, { outcome: 'rejected', reason });
  assert.strictEqual((await referral(referrer))?.count ?? 0, count, 'count unchanged');
  assert.strictEqual(sent.length, 0, 'no push');
  if (friend) {
    const c = await claimDoc(friend);
    assert.strictEqual(c.exists, final, `final should be ${final}`);
    if (final) {
      assert.strictEqual(c.data().outcome, 'rejected');
      assert.strictEqual(c.data().reason, reason);
    }
  }
}

test('BE-CLM-01 a valid claim is credited, final, bit 0 set, one push', async () => {
  const { code } = await enroll('R');
  await withToken('R');
  const res = await claim('f1', code);
  assert.deepStrictEqual(res, { outcome: 'credited' });
  const rec = await referral('R');
  assert.strictEqual(rec.count, 1);
  const credit = (await db.collection('referrals').doc('R').collection('credits').doc('f1').get()).data();
  assert.strictEqual(credit.friendUid, 'f1');
  assert.strictEqual(credit.source, 'deferred');
  assert.strictEqual(credit.deviceVerified, true);
  const c = (await claimDoc('f1')).data();
  assert.strictEqual(c.outcome, 'credited');
  assert.strictEqual(c.referrerUid, 'R');
  assert.strictEqual(c.code, code);
  assert.strictEqual(dc.bits.get('dev_f1').bit0, true);
  assert.strictEqual(sent.length, 1);
  assert.strictEqual(sent[0].token, 'tok_R');
});

test('BE-CLM-02 each source is stored as sent; anything else is invalid-argument', async () => {
  const { code } = await enroll('R');
  for (const source of ['deferred', 'universal_link', 'manual']) {
    assert.strictEqual((await claim(`f_${source}`, code, { source })).outcome, 'credited');
    const credit = (await db.collection('referrals').doc('R')
      .collection('credits').doc(`f_${source}`).get()).data();
    assert.strictEqual(credit.source, source);
  }
  await expectCode(() => claim('f_bad', code, { source: 'sms' }), 'invalid-argument');
  await expectCode(() => claim('f_bad2', code, { source: undefined }), 'invalid-argument');
  assert.strictEqual((await claimDoc('f_bad')).exists, false);
});

test('BE-CLM-02 capturedAt that is not a number is invalid-argument, not final', async () => {
  const { code } = await enroll('R');
  await expectCode(() => claim('f1', code, { capturedAt: 'yesterday' }), 'invalid-argument');
  assert.strictEqual((await claimDoc('f1')).exists, false);
});

test('BE-CLM-03 a lower-case code with a dash is normalised and credited', async () => {
  const { code } = await enroll('R');
  const messy = `${code.slice(0, 4)}-${code.slice(4)}`.toLowerCase();
  assert.deepStrictEqual(await claim('f1', messy), { outcome: 'credited' });
});

test('BE-CLM-04 the same friend claiming twice: original outcome, counted once, one push', async () => {
  const { code } = await enroll('R');
  await withToken('R');
  await claim('f1', code);
  assert.deepStrictEqual(await claim('f1', code), { outcome: 'credited' });
  assert.strictEqual((await referral('R')).count, 1);
  assert.strictEqual(sent.length, 1);
});

test('BE-CLM-05 the same friend with a different referrer\'s code gets the first outcome', async () => {
  const { code } = await enroll('R');
  const { code: code2 } = await enroll('R2');
  await claim('f1', code);
  assert.deepStrictEqual(await claim('f1', code2), { outcome: 'credited' });
  assert.strictEqual((await referral('R2')).count, 0);
  assert.strictEqual((await claimDoc('f1')).data().referrerUid, 'R');
});

test('BE-CLM-06 five identical concurrent claims: one credit, one push', async () => {
  const { code } = await enroll('R');
  await withToken('R');
  const results = await Promise.all(Array.from({ length: 5 }, () => claim('f1', code)));
  for (const r of results) assert.strictEqual(r.outcome, 'credited');
  assert.strictEqual((await referral('R')).count, 1);
  assert.strictEqual((await db.collection('referrals').doc('R').collection('credits').get()).size, 1);
  assert.strictEqual(sent.length, 1);
});

test('BE-CLM-07 a friend rejected first stays rejected with a valid code', async () => {
  const { code } = await enroll('R');
  const { code: code2 } = await enroll('R2');
  await expectRejected(await claim('R', code), 'self_referral', { friend: 'R' });
  assert.deepStrictEqual(await claim('R', code2), { outcome: 'rejected', reason: 'self_referral' });
  assert.strictEqual((await referral('R2')).count, 0);
});

test('BE-CLM-08 captured 15 days ago: expired, final', async () => {
  const { code } = await enroll('R');
  await expectRejected(await claim('f1', code, { capturedAt: now - 15 * DAY }), 'expired', { friend: 'f1' });
});

test('BE-CLM-08 a link captured before the friend\'s account existed: expired', async () => {
  const { code } = await enroll('R');
  accounts.set('f1', now - DAY);
  await expectRejected(await claim('f1', code, { capturedAt: now - 2 * DAY }), 'expired', { friend: 'f1' });
});

test('BE-CLM-09 friend uid is the referrer: self_referral, final', async () => {
  const { code } = await enroll('R');
  await expectRejected(await claim('R', code), 'self_referral', { friend: 'R' });
});

test('BE-CLM-10 referrer already at target: target_reached, final', async () => {
  const { code } = await enroll('R');
  await creditN(code, 5);
  sent.length = 0;
  await expectRejected(await claim('late', code), 'target_reached', { friend: 'late', count: 5 });
});

test('BE-CLM-12 malformed code: invalid_code, final', async () => {
  await enroll('R');
  await expectRejected(await claim('f1', 'nope'), 'invalid_code', { friend: 'f1' });
});

test('BE-CLM-13 unknown code: unknown_code, final', async () => {
  await enroll('R');
  await expectRejected(await claim('f1', 'ZZZZZZZZ'), 'unknown_code', { friend: 'f1' });
});

test('BE-CLM-14 revoked code: unknown_code, final', async () => {
  const { code } = await enroll('R');
  await db.collection('referralCodes').doc(code).update({ revoked: true });
  await expectRejected(await claim('f1', code), 'unknown_code', { friend: 'f1' });
});

test('BE-CLM-15 device bit 0 already set: device_already_counted, final', async () => {
  const { code } = await enroll('R');
  dc.bits.set('dev_f1', { bit0: true, bit1: false });
  await expectRejected(await claim('f1', code), 'device_already_counted', { friend: 'f1' });
});

test('BE-CLM-16 device bit 1 set (a referrer\'s device): device_is_referrer, final', async () => {
  const { code } = await enroll('R');
  dc.bits.set('dev_f1', { bit0: false, bit1: true });
  await expectRejected(await claim('f1', code), 'device_is_referrer', { friend: 'f1' });
});

test('BE-CLM-17 no device token: device_unverifiable, final', async () => {
  const { code } = await enroll('R');
  await expectRejected(await claim('f1', code, { deviceToken: undefined }),
    'device_unverifiable', { friend: 'f1' });
});

test('BE-CLM-18 Apple rejects the token as invalid: device_unverifiable, final', async () => {
  const { code } = await enroll('R');
  dc.invalid.add('dev_f1');
  await expectRejected(await claim('f1', code), 'device_unverifiable', { friend: 'f1' });
});

test('BE-CLM-19 no auth: unauthenticated, not final', async () => {
  const { code } = await enroll('R');
  await expectCode(() => fns.claimReferral.run(req(null, {
    code, capturedAt: now, source: 'deferred', deviceToken: 'd',
  })), 'unauthenticated');
  assert.strictEqual(await countDocs('referralClaims'), 0);
});

test('BE-CLM-20 the 11th claim call in an hour is throttled before any code lookup', async () => {
  const { code } = await enroll('R');
  for (let i = 0; i < 10; i++) await claim('f1', 'ZZZZZZZZ');
  await expectCode(() => claim('f1', code), 'resource-exhausted');
  await expectCode(() => claim('f1', 'YYYYYYYY'), 'resource-exhausted');
  assert.strictEqual((await claimDoc('f1')).data().code, 'ZZZZZZZZ');
});

test('BE-CLM-11 referrer already credited the daily cap: retry_later, then credited after 24h', async () => {
  await setConfig({ target: 10 });
  const { code } = await enroll('R');
  await creditN(code, 5);
  const capturedAt = now - 60000;
  assert.deepStrictEqual(await claim('f6', code, { capturedAt }), { outcome: 'retry_later' });
  assert.strictEqual((await claimDoc('f6')).exists, false);
  assert.strictEqual((await referral('R')).count, 5);
  advance(DAY + 1000);
  assert.deepStrictEqual(await claim('f6', code, { capturedAt }), { outcome: 'credited' });
  assert.strictEqual((await referral('R')).count, 6);
});

test('BE-CLM-21 DeviceCheck down: retry_later, nothing written, credited after recovery', async () => {
  const { code } = await enroll('R');
  dc.down = true;
  let res;
  await captureLogs(async () => { res = await claim('f1', code); });
  assert.deepStrictEqual(res, { outcome: 'retry_later' });
  assert.strictEqual((await claimDoc('f1')).exists, false);
  assert.strictEqual((await referral('R')).count, 0);
  dc.down = false;
  assert.deepStrictEqual(await claim('f1', code), { outcome: 'credited' });
});

test('BE-CLM-22 the velocity window is rolling', async () => {
  await setConfig({ target: 10 });
  const { code } = await enroll('R');
  await creditN(code, 5);
  const capturedAt = now - 60000;
  advance(23 * HOUR + 59 * 60000);
  assert.deepStrictEqual(await claim('f6', code, { capturedAt }), { outcome: 'retry_later' });
  advance(60000 + 1000);   // t = 24h 00m 01s
  assert.deepStrictEqual(await claim('f6', code, { capturedAt }), { outcome: 'credited' });
});

test('BE-CLM-23 expired AND self-referral: self_referral wins (§7 #7 before #8)', async () => {
  const { code } = await enroll('R');
  await expectRejected(await claim('R', code, { capturedAt: now - 30 * DAY }), 'self_referral');
});

test('BE-CLM-24 unknown code AND device already counted: unknown_code, Apple never called', async () => {
  await enroll('R');
  dc.bits.set('dev_f1', { bit0: true, bit1: false });
  await expectRejected(await claim('f1', 'ZZZZZZZZ'), 'unknown_code');
  assert.strictEqual(dc.queries, 0);
});

test('BE-CLM-25 switch off AND everything else invalid: disabled', async () => {
  await setConfig({ enabled: false });
  assert.deepStrictEqual(await fns.claimReferral.run(req(null, {
    code: 'nope', capturedAt: 'x', source: 'sms',
  })), { outcome: 'rejected', reason: 'disabled' });
});

test('BE-CLM-26 setting bit 0 fails after the credit: still credited, retry queued', async () => {
  const { code } = await enroll('R');
  dc.failUpdate = true;
  let res;
  await captureLogs(async () => { res = await claim('f1', code); });
  assert.deepStrictEqual(res, { outcome: 'credited' });
  const q = (await db.collection('referralBitRetries').get()).docs.map((d) => d.data());
  assert.strictEqual(q.length, 1);
  assert.strictEqual(q[0].deviceToken, 'dev_f1');
  assert.strictEqual(q[0].bit, 0);
});

test('BE-CLM-27 referrer has no fcmToken: credited, no push, no error', async () => {
  const { code } = await enroll('R');
  assert.deepStrictEqual(await claim('f1', code), { outcome: 'credited' });
  assert.strictEqual(sent.length, 0);
});

test('BE-CLM-28 FCM throws: credited, logged, not passed back to the friend', async () => {
  const { code } = await enroll('R');
  await withToken('R');
  failPush = true;
  let res;
  const logs = await captureLogs(async () => { res = await claim('f1', code); });
  assert.deepStrictEqual(res, { outcome: 'credited' });
  assert.ok(logs.error.some((l) => /push/i.test(l)), logs.error.join('\n'));
});

test('BE-CLM-29 the push says "A friend joined. 2 of 5." and nothing about the friend', async () => {
  const { code } = await enroll('R');
  await withToken('R');
  await claim('friendA', code);
  await claim('friendB', code);
  assert.strictEqual(sent.length, 2);
  assert.strictEqual(sent[1].notification.body, 'A friend joined. 2 of 5.');
  const wire = JSON.stringify(sent);
  assert.ok(!/friendA|friendB|dev_/.test(wire), wire);
});

// ═══ 6. Unlocking and rewards (BE-RWD) ═══════════════════════════════════════

const pool = async (code) => (await db.collection('referralRewardCodes').doc(code).get()).data();
const UNLOCK_BODY = 'You did it. Your free year is ready.';

test('BE-RWD-01 the final credit unlocks and assigns a code; one combined unlock push', async () => {
  const [soonest] = await seedPool(2);
  const { code } = await enroll('R');
  await withToken('R');
  await creditN(code, 5);
  const rec = await referral('R');
  assert.strictEqual(rec.status, 'unlocked');
  assert.ok(rec.unlockedAt);
  assert.strictEqual(rec.reward.code, soonest);
  assert.strictEqual(rec.reward.reissueCount, 0);
  assert.ok(rec.reward.expiresAt && rec.reward.assignedAt);
  const p = await pool(soonest);
  assert.strictEqual(p.assignedTo, 'R');
  assert.ok(p.assignedAt);
  // Four credit pushes, then ONE push for the final credit: the unlock.
  assert.strictEqual(sent.length, 5);
  assert.deepStrictEqual(sent.map((m) => m.notification.body), [
    'A friend joined. 1 of 5.', 'A friend joined. 2 of 5.', 'A friend joined. 3 of 5.',
    'A friend joined. 4 of 5.', UNLOCK_BODY,
  ]);
});

test('BE-RWD-02 a credit that leaves count at target - 1 unlocks nothing', async () => {
  await seedPool(2);
  const { code } = await enroll('R');
  await creditN(code, 4);
  const rec = await referral('R');
  assert.strictEqual(rec.status, 'active');
  assert.strictEqual(rec.reward, null);
});

test('BE-RWD-03 the final credit with the pool empty: unlocked_pending_code, still credited', async () => {
  const { code } = await enroll('R');
  await withToken('R');
  const results = await creditN(code, 5);
  assert.deepStrictEqual(results[4], { outcome: 'credited' });
  const rec = await referral('R');
  assert.strictEqual(rec.status, 'unlocked_pending_code');
  assert.strictEqual(rec.reward, null);
  assert.ok(rec.unlockedAt);
  assert.strictEqual(sent.at(-1).notification.body, 'A friend joined. 5 of 5.');
});

test('BE-RWD-04 only codes expiring within 30 days left: same as an empty pool', async () => {
  await seedPool(3, { expiresInDays: 20 });
  const { code } = await enroll('R');
  await creditN(code, 5);
  const rec = await referral('R');
  assert.strictEqual(rec.status, 'unlocked_pending_code');
  assert.strictEqual(rec.reward, null);
});

test('BE-RWD-05 two concurrent unlocks, one code: assigned exactly once', async () => {
  const [only] = await seedPool(1);
  const { code: c1 } = await enroll('R1');
  const { code: c2 } = await enroll('R2');
  await creditN(c1, 4);
  await creditN(c2, 4);
  await Promise.all([claim('last1', c1), claim('last2', c2)]);
  const [r1, r2] = [await referral('R1'), await referral('R2')];
  const statuses = [r1.status, r2.status].sort();
  assert.deepStrictEqual(statuses, ['unlocked', 'unlocked_pending_code']);
  const winner = r1.status === 'unlocked' ? 'R1' : 'R2';
  assert.strictEqual((await pool(only)).assignedTo, winner);
  assert.strictEqual([r1.reward?.code, r2.reward?.code].filter(Boolean).length, 1);
});

test('BE-RWD-06 a referrer who already subscribed still unlocks and gets a code (D7)', async () => {
  await seedPool(1);
  const { code } = await enroll('R');
  await db.collection('users').doc('R').set({ isPremium: true, entitlement: 'premium' }, { merge: true });
  await creditN(code, 5);
  const rec = await referral('R');
  assert.strictEqual(rec.status, 'unlocked');
  assert.ok(rec.reward.code);
});

test('BE-RWD-07 a claim after unlocking is target_reached and the reward is untouched', async () => {
  await seedPool(2);
  const { code } = await enroll('R');
  await creditN(code, 5);
  const before = (await referral('R')).reward;
  assert.deepStrictEqual(await claim('late', code), { outcome: 'rejected', reason: 'target_reached' });
  assert.deepStrictEqual((await referral('R')).reward, before);
});

async function unlocked(uid = 'R', poolSize = 2) {
  const codes = await seedPool(poolSize);
  const { code } = await enroll(uid);
  await creditN(code, 5);
  return { codes, reward: (await referral(uid)).reward };
}

test('BE-RWD-08 reissue while unlocked: new code, old one retired forever, reissueCount 1', async () => {
  const { reward: old } = await unlocked('R', 2);
  const res = await fns.reissueReferralReward.run(req('R'));
  assert.ok(res.reward.code);
  assert.notStrictEqual(res.reward.code, old.code);
  assert.strictEqual(res.reward.reissueCount, 1);
  const rec = await referral('R');
  assert.strictEqual(rec.reward.code, res.reward.code);
  assert.strictEqual(rec.reward.reissueCount, 1);
  const retired = await pool(old.code);
  assert.strictEqual(retired.retired, true);
  assert.strictEqual((await pool(res.reward.code)).assignedTo, 'R');

  // The retired code never comes back: a later unlock with an otherwise empty
  // pool waits rather than receiving it.
  const { code: c2 } = await enroll('R2');
  await creditN(c2, 5);
  assert.strictEqual((await referral('R2')).status, 'unlocked_pending_code');
});

test('BE-RWD-09 a second reissue is resource-exhausted and changes nothing', async () => {
  await unlocked('R', 3);
  await fns.reissueReferralReward.run(req('R'));
  const before = (await referral('R')).reward;
  await expectCode(() => fns.reissueReferralReward.run(req('R')), 'resource-exhausted');
  assert.deepStrictEqual((await referral('R')).reward, before);
});

test('BE-RWD-10 reissue while not unlocked is failed-precondition', async () => {
  await enroll('R');
  await expectCode(() => fns.reissueReferralReward.run(req('R')), 'failed-precondition');
  await expectCode(() => fns.reissueReferralReward.run(req('nobody')), 'failed-precondition');
  await expectCode(() => fns.reissueReferralReward.run(req(null)), 'unauthenticated');
});

test('BE-RWD-11 reissue with the pool empty is unavailable and changes nothing', async () => {
  await unlocked('R', 1);
  const before = (await referral('R')).reward;
  await expectCode(() => fns.reissueReferralReward.run(req('R')), 'unavailable');
  const after = (await referral('R')).reward;
  assert.deepStrictEqual(after, before);
  assert.strictEqual(after.reissueCount, 0);
  assert.notStrictEqual((await pool(before.code)).retired, true, 'old code still the live one');
});

test('BE-RWD-12 pool selection end to end: soonest-expiring valid code', async () => {
  const mk = async (c, days) => db.collection('referralRewardCodes').doc(c).set({
    code: c, batchId: 't', expiresAt: Timestamp.fromMillis(now + days * DAY),
    assignedTo: null, assignedAt: null,
  });
  await mk('LATE', 200); await mk('PICKME', 40); await mk('TOOSOON', 25); await mk('MID', 100);
  const { code } = await enroll('R');
  await creditN(code, 5);
  assert.strictEqual((await referral('R')).reward.code, 'PICKME');
});

test('BE-CFG-04 / BE-RWD: reward view carries code, expiry and reissue count only', async () => {
  await unlocked('R', 1);
  const res = await enroll('R');
  assert.deepStrictEqual(Object.keys(res.reward).sort(),
    ['assignedAt', 'code', 'expiresAt', 'reissueCount']);
  assert.strictEqual(typeof res.reward.expiresAt, 'number');
});

// ═══ 7. Scheduled sweep: referralSweep (BE-SWP) ══════════════════════════════

/** A referrer who hit the target while the pool was empty. */
async function pendingReferrer(uid, unlockedAtMs) {
  await db.collection('referrals').doc(uid).set({
    uid, code: `C${uid}`.padEnd(8, 'X').slice(0, 8), target: 5, count: 5,
    status: 'unlocked_pending_code', createdAt: Timestamp.fromMillis(unlockedAtMs - DAY),
    updatedAt: Timestamp.fromMillis(unlockedAtMs), unlockedAt: Timestamp.fromMillis(unlockedAtMs),
    reward: null,
  });
  await withToken(uid);
}

const sweep = () => fns.referralSweep.run({});

test('BE-SWP-01 a refilled pool goes to the oldest pending unlocks first', async () => {
  await pendingReferrer('oldest', now - 3 * DAY);
  await pendingReferrer('newest', now - 1 * DAY);
  await pendingReferrer('middle', now - 2 * DAY);
  await seedPool(2);
  await captureLogs(sweep);
  assert.strictEqual((await referral('oldest')).status, 'unlocked');
  assert.strictEqual((await referral('middle')).status, 'unlocked');
  assert.ok((await referral('oldest')).reward.code);
  assert.strictEqual((await referral('newest')).status, 'unlocked_pending_code');
  assert.strictEqual((await referral('newest')).reward, null);
  assert.deepStrictEqual(sent.map((m) => m.token).sort(), ['tok_middle', 'tok_oldest']);
  for (const m of sent) assert.strictEqual(m.notification.body, UNLOCK_BODY);
});

test('BE-SWP-02 a second sweep assigns nothing new and pushes nothing', async () => {
  await pendingReferrer('a', now - 2 * DAY);
  await pendingReferrer('b', now - 1 * DAY);
  await seedPool(1);
  await captureLogs(sweep);
  const first = await referral('a');
  const pushes = sent.length;
  await captureLogs(sweep);
  assert.deepStrictEqual(await referral('a'), first);
  assert.strictEqual((await referral('b')).status, 'unlocked_pending_code');
  assert.strictEqual(sent.length, pushes);
});

test('BE-SWP-03 a queued bit 0 update is retried by the sweep and dequeued', async () => {
  const { code } = await enroll('R');
  dc.failUpdate = true;
  await captureLogs(() => claim('f1', code));
  assert.strictEqual(await countDocs('referralBitRetries'), 1);
  assert.notStrictEqual(dc.bits.get('dev_f1')?.bit0, true);
  dc.failUpdate = false;
  await captureLogs(sweep);
  assert.strictEqual(dc.bits.get('dev_f1').bit0, true);
  assert.strictEqual(await countDocs('referralBitRetries'), 0);
});

test('BE-SWP-03 a bit update that keeps failing stays queued, then is dropped after its attempts', async () => {
  const { code } = await enroll('R');
  dc.failUpdate = true;
  await captureLogs(() => claim('f1', code));
  await captureLogs(sweep);
  const q = (await db.collection('referralBitRetries').get()).docs.map((d) => d.data());
  assert.strictEqual(q.length, 1);
  assert.strictEqual(q[0].attempts, 1);
  for (let i = 0; i < 20; i++) await captureLogs(sweep);
  assert.strictEqual(await countDocs('referralBitRetries'), 0);
});

test('BE-SWP-04 a pool of 99 valid codes logs REFERRAL_POOL_LOW with the count', async () => {
  await seedPool(99);
  await seedPool(30, { expiresInDays: 10, prefix: 'SOON' });   // too close to expiry: not counted
  const logs = await captureLogs(sweep);
  const line = logs.warn.find((l) => l.includes('REFERRAL_POOL_LOW'));
  assert.ok(line, logs.warn.join('\n'));
  assert.match(line, /\b99\b/);
});

test('BE-SWP-05 a pool of 100 valid codes logs no warning', async () => {
  await seedPool(100);
  const logs = await captureLogs(sweep);
  assert.ok(!logs.warn.some((l) => l.includes('REFERRAL_POOL_LOW')), logs.warn.join('\n'));
});

test('BE-SWP-06 one malformed referrer document is logged and skipped', async () => {
  await db.collection('referrals').doc('broken').set({ status: 'unlocked_pending_code' });
  await pendingReferrer('good', now - DAY);
  await seedPool(2);
  let logs;
  await assert.doesNotReject(async () => { logs = await captureLogs(sweep); });
  assert.strictEqual((await referral('good')).status, 'unlocked');
  assert.ok(logs.error.some((l) => l.includes('broken')), logs.error.join('\n'));
  assert.strictEqual((await referral('broken')).reward, undefined);
});

// ═══ 8. Account merge (BE-MRG) ═══════════════════════════════════════════════

const A = 'anonA';
const P = 'appleP';

/**
 * Seeds a referral record directly, with exact friend sets. A friend can only
 * ever claim once, so overlapping sets ({f1,f2} and {f2,f3}) cannot be built
 * through claimReferral; they arise from two identities on one person.
 */
async function seedReferral(uid, code, friends, extra = {}) {
  const ref = db.collection('referrals').doc(uid);
  await ref.set({
    uid, code, target: 5, count: friends.length, status: 'active',
    createdAt: Timestamp.fromMillis(now - 10 * DAY), updatedAt: Timestamp.fromMillis(now - DAY),
    unlockedAt: null, reward: null, ...extra,
  });
  await db.collection('referralCodes').doc(code).set({
    uid, createdAt: Timestamp.fromMillis(now - 10 * DAY), revoked: false,
  });
  for (const [i, f] of friends.entries()) {
    await ref.collection('credits').doc(f).set({
      friendUid: f, creditedAt: Timestamp.fromMillis(now - (20 - i) * HOUR),
      source: 'deferred', deviceVerified: true,
    });
  }
}

/** A reward assigned `ageMs` ago, with its pool document. */
async function seedReward(code, uid, ageMs) {
  const expiresAt = Timestamp.fromMillis(now + 200 * DAY);
  const assignedAt = Timestamp.fromMillis(now - ageMs);
  await db.collection('referralRewardCodes').doc(code).set({
    code, batchId: 't', expiresAt, assignedTo: uid, assignedAt,
  });
  return { status: 'unlocked', unlockedAt: assignedAt,
           reward: { code, assignedAt, expiresAt, reissueCount: 0 } };
}

async function referralState() {
  const out = {};
  for (const c of ['referrals', 'referralCodes', 'referralRewardCodes']) {
    for (const d of (await db.collection(c).get()).docs) {
      out[`${c}/${d.id}`] = d.data();
      if (c === 'referrals') {
        for (const cr of (await d.ref.collection('credits').get()).docs) {
          out[`${c}/${d.id}/credits/${cr.id}`] = cr.data();
        }
      }
    }
  }
  return JSON.parse(JSON.stringify(out));
}

/**
 * Runs the real merge (anonymous A signs in as Apple P), then runs the
 * referral step again to prove it idempotent. The ticket is spent by the
 * first run, so the retry is the referral hook itself, which is what a killed
 * app's retry would re-execute.
 */
async function mergeTwice() {
  const { ticket } = await stand.beginAccountMerge.run(req(A));
  await stand.completeAccountMerge.run(req(P, { ticket }));
  const first = await referralState();
  await fns.__accountHooks.mergeReferralAccounts(A, P);
  assert.deepStrictEqual(await referralState(), first, 'a second merge must change nothing');
  return first;
}

const credits = async (uid) =>
  (await db.collection('referrals').doc(uid).collection('credits').get()).docs.map((d) => d.id).sort();

test('BE-MRG-01 only A has a referral: moved to P, code repointed, A gone', async () => {
  await seedReferral(A, 'AAAAAAAA', ['f1', 'f2']);
  await mergeTwice();
  const rec = await referral(P);
  assert.strictEqual(rec.uid, P);
  assert.strictEqual(rec.code, 'AAAAAAAA');
  assert.strictEqual(rec.count, 2);
  assert.deepStrictEqual(await credits(P), ['f1', 'f2']);
  assert.strictEqual((await db.collection('referralCodes').doc('AAAAAAAA').get()).data().uid, P);
  assert.strictEqual((await db.collection('referrals').doc(A).get()).exists, false);
  assert.deepStrictEqual(await credits(A), []);
});

test('BE-MRG-02 only P has one: unchanged', async () => {
  await seedReferral(P, 'PPPPPPPP', ['f1']);
  const before = await referralState();
  await mergeTwice();
  assert.deepStrictEqual(await referralState(), before);
});

test('BE-MRG-03 both, {f1,f2} and {f2,f3}: count 3, one code kept, the other revoked', async () => {
  await seedReferral(A, 'AAAAAAAA', ['f1', 'f2']);
  await seedReferral(P, 'PPPPPPPP', ['f2', 'f3']);
  await mergeTwice();
  const rec = await referral(P);
  assert.strictEqual(rec.count, 3, 'the union, not 4');
  assert.deepStrictEqual(await credits(P), ['f1', 'f2', 'f3']);
  // A tie keeps the signed-in account's own code.
  assert.strictEqual(rec.code, 'PPPPPPPP');
  assert.strictEqual((await db.collection('referralCodes').doc('AAAAAAAA').get()).data().revoked, true);
  assert.strictEqual((await db.collection('referralCodes').doc('PPPPPPPP').get()).data().revoked, false);
  assert.strictEqual((await db.collection('referrals').doc(A).get()).exists, false);
});

test('BE-MRG-03 both, A has more credits: A\'s code kept and repointed, P\'s revoked', async () => {
  await seedReferral(A, 'AAAAAAAA', ['f1', 'f2', 'f4']);
  await seedReferral(P, 'PPPPPPPP', ['f2', 'f3']);
  await mergeTwice();
  const rec = await referral(P);
  assert.strictEqual(rec.count, 4);
  assert.strictEqual(rec.code, 'AAAAAAAA');
  assert.strictEqual((await db.collection('referralCodes').doc('AAAAAAAA').get()).data().uid, P);
  assert.strictEqual((await db.collection('referralCodes').doc('PPPPPPPP').get()).data().revoked, true);
});

test('BE-MRG-04 the union reaches the target: unlocked and a code assigned in the merge', async () => {
  const [code] = await seedPool(2);
  await seedReferral(A, 'AAAAAAAA', ['f1', 'f2', 'f3']);
  await seedReferral(P, 'PPPPPPPP', ['f3', 'f4', 'f5']);
  await mergeTwice();
  const rec = await referral(P);
  assert.strictEqual(rec.count, 5);
  assert.strictEqual(rec.status, 'unlocked');
  assert.strictEqual(rec.reward.code, code);
  assert.strictEqual((await pool(code)).assignedTo, P);
});

test('BE-MRG-04 the union reaches the target with the pool empty: pending code', async () => {
  await seedReferral(A, 'AAAAAAAA', ['f1', 'f2', 'f3']);
  await seedReferral(P, 'PPPPPPPP', ['f4', 'f5']);
  await mergeTwice();
  const rec = await referral(P);
  assert.strictEqual(rec.status, 'unlocked_pending_code');
  assert.ok(rec.unlockedAt);
});

test('BE-MRG-05 A unlocked with a reward, P active: P is unlocked with A\'s reward', async () => {
  const unlockedA = await seedReward('OFFERA', A, 3 * DAY);
  await seedReferral(A, 'AAAAAAAA', ['f1', 'f2', 'f3', 'f4', 'f5'], unlockedA);
  await seedReferral(P, 'PPPPPPPP', ['f6']);
  await mergeTwice();
  const rec = await referral(P);
  assert.strictEqual(rec.status, 'unlocked');
  assert.strictEqual(rec.reward.code, 'OFFERA');
  assert.strictEqual((await pool('OFFERA')).assignedTo, P);
});

test('BE-MRG-06 both rewarded: earlier kept, the other back to the pool if under 24h old', async () => {
  const fr = ['f1', 'f2', 'f3', 'f4', 'f5'];
  await seedReferral(A, 'AAAAAAAA', fr, await seedReward('EARLY', A, 5 * DAY));
  await seedReferral(P, 'PPPPPPPP', fr, await seedReward('FRESH', P, 2 * HOUR));
  await mergeTwice();
  assert.strictEqual((await referral(P)).reward.code, 'EARLY');
  const fresh = await pool('FRESH');
  assert.strictEqual(fresh.assignedTo, null, 'released');
  assert.notStrictEqual(fresh.retired, true);
});

test('BE-MRG-06 both rewarded: the other is retired if assigned over 24h ago', async () => {
  const fr = ['f1', 'f2', 'f3', 'f4', 'f5'];
  await seedReferral(A, 'AAAAAAAA', fr, await seedReward('LATER', A, 2 * DAY));
  await seedReferral(P, 'PPPPPPPP', fr, await seedReward('EARLIEST', P, 5 * DAY));
  await mergeTwice();
  assert.strictEqual((await referral(P)).reward.code, 'EARLIEST');
  const later = await pool('LATER');
  assert.strictEqual(later.retired, true);
  assert.notStrictEqual(later.assignedTo, null, 'a retired code is never back in the pool');
});

test('BE-MRG-07 different targets (5 and 3): the lower one is kept', async () => {
  await seedReferral(A, 'AAAAAAAA', ['f1'], { target: 3 });
  await seedReferral(P, 'PPPPPPPP', ['f2'], { target: 5 });
  await mergeTwice();
  const rec = await referral(P);
  assert.strictEqual(rec.target, 3);
  assert.strictEqual(rec.count, 2);
  assert.strictEqual(rec.status, 'active');
});

test('BE-MRG-08 a friend claiming with A\'s old code after the merge is credited to P', async () => {
  await seedReferral(A, 'AAAAAAAA', ['f1']);
  await mergeTwice();
  assert.deepStrictEqual(await claim('newFriend', 'AAAAAAAA'), { outcome: 'credited' });
  assert.strictEqual((await referral(P)).count, 2);
  assert.strictEqual((await claimDoc('newFriend')).data().referrerUid, P);
});

test('BE-MRG-09 neither has a referral: no referral documents created', async () => {
  await mergeTwice();
  assert.strictEqual(await countDocs('referrals'), 0);
  assert.strictEqual(await countDocs('referralCodes'), 0);
});

// ═══ 9. Account deletion (BE-DEL) ════════════════════════════════════════════

test('BE-DEL-01 a referrer deleting their account: record and credits gone, code revoked', async () => {
  const { code } = await enroll('R');
  await creditN(code, 2);
  await stand.deleteAccount.run(req('R'));
  assert.strictEqual((await db.collection('referrals').doc('R').get()).exists, false);
  assert.deepStrictEqual(await credits('R'), []);
  assert.strictEqual((await db.collection('referralCodes').doc(code).get()).data().revoked, true);
});

test('BE-DEL-02 a friend claiming with a deleted referrer\'s code: unknown_code', async () => {
  const { code } = await enroll('R');
  await stand.deleteAccount.run(req('R'));
  assert.deepStrictEqual(await claim('f1', code), { outcome: 'rejected', reason: 'unknown_code' });
});

test('BE-DEL-03 a friend deleting their account keeps their claim; the count stands', async () => {
  const { code } = await enroll('R');
  await claim('f1', code);
  await stand.deleteAccount.run(req('f1'));
  assert.strictEqual((await claimDoc('f1')).exists, true);
  assert.strictEqual((await referral('R')).count, 1);
});

// ═══ 11. Offer code import, write path (BE-IMP) ══════════════════════════════
//
// Parsing and output are covered without the emulator in importOfferCodes.test.js.
// These rows run the same main() against real Firestore.

const imp = require('../scripts/importOfferCodes');

async function runImport(argv, text) {
  const lines = [];
  const code = await imp.main(argv, {
    db, Timestamp, now: () => now, out: (l) => lines.push(String(l)), readFile: () => text,
  });
  return { code, out: lines.join('\n') };
}
const IMPORT_ARGS = ['--file', 'codes.csv', '--batch', '2026Q4', '--expires', '2027-06-30'];

test('BE-IMP-01 import writes pool documents the referral functions can assign', async () => {
  const { code } = await runImport(IMPORT_ARGS, 'Code\nW7HKXJ4MAJFR\nQ2ZP9LM3KD7T\n');
  assert.strictEqual(code, 0);
  const p = await pool('W7HKXJ4MAJFR');
  assert.strictEqual(p.batchId, '2026Q4');
  assert.strictEqual(p.assignedTo, null);
  assert.strictEqual(p.expiresAt.toMillis(), Date.UTC(2027, 5, 30, 23, 59, 59));
});

test('BE-IMP-04 re-running the same file: 0 new, N skipped, assigned codes untouched', async () => {
  const text = 'Code\nW7HKXJ4MAJFR\nQ2ZP9LM3KD7T\n';
  await runImport(IMPORT_ARGS, text);
  await db.collection('referralRewardCodes').doc('W7HKXJ4MAJFR')
    .update({ assignedTo: 'R', assignedAt: Timestamp.fromMillis(now) });
  const before = await pool('W7HKXJ4MAJFR');
  const { code, out } = await runImport(IMPORT_ARGS, text);
  assert.strictEqual(code, 0);
  assert.match(out, /0 new, 2 already/);
  assert.deepStrictEqual(await pool('W7HKXJ4MAJFR'), before);
});

test('BE-IMP-05 --expires in the past writes nothing', async () => {
  const { code } = await runImport(
    ['--file', 'c', '--batch', 'b', '--expires', '2026-09-01'], 'Code\nW7HKXJ4MAJFR\n');
  assert.notStrictEqual(code, 0);
  assert.strictEqual(await countDocs('referralRewardCodes'), 0);
});

test('BE-IMP-08 more than 500 codes are all imported', async () => {
  const codes = Array.from({ length: 1101 }, (_, i) => `BULK${String(i).padStart(8, '0')}`);
  const { code } = await runImport(IMPORT_ARGS, `Code\n${codes.join('\n')}\n`);
  assert.strictEqual(code, 0);
  assert.strictEqual(await countDocs('referralRewardCodes'), 1101);
});

test('BE-IMP-09 --dry-run against Firestore writes nothing', async () => {
  const { code, out } = await runImport([...IMPORT_ARGS, '--dry-run'], 'Code\nW7HKXJ4MAJFR\n');
  assert.strictEqual(code, 0);
  assert.match(out, /1 new/);
  assert.strictEqual(await countDocs('referralRewardCodes'), 0);
});

test('BE-IMP-10 output during a real import never carries a full code', async () => {
  const { out } = await runImport(IMPORT_ARGS, 'Code\nW7HKXJ4MAJFR\nW7HKXJ4MAJFR\nBAD!\n');
  assert.ok(!out.includes('W7HKXJ4MAJFR'), out);
});

// ═══ 12. End to end (BE-E2E) ═════════════════════════════════════════════════

test('BE-E2E-01 target 10: ten friends over three days within the cap, unlock, an 11th is turned away', async () => {
  await setConfig({ target: 10 });
  await seedPool(3);
  const { code } = await enroll('R', { deviceToken: 'devR' });
  await withToken('R');

  // Day 1: five count, the sixth is told to come back.
  const day1 = await creditN(code, 5, { prefix: 'd1_' });
  assert.ok(day1.every((r) => r.outcome === 'credited'));
  const sixthCapturedAt = now - 60000;
  assert.deepStrictEqual(await claim('waiting', code, { capturedAt: sixthCapturedAt }),
    { outcome: 'retry_later' });

  // Day 2: the waiting friend's app retries, and four more join.
  advance(DAY + 1000);
  assert.deepStrictEqual(await claim('waiting', code, { capturedAt: sixthCapturedAt }),
    { outcome: 'credited' });
  const day2 = await creditN(code, 4, { prefix: 'd2_' });
  assert.ok(day2.every((r) => r.outcome === 'credited'));

  const res = await enroll('R');
  assert.strictEqual(res.count, 10);
  assert.strictEqual(res.status, 'unlocked');
  assert.ok(res.reward.code);
  assert.strictEqual(sent.at(-1).notification.body, 'You did it. Your free year is ready.');

  // Day 3: an eleventh friend.
  advance(DAY);
  assert.deepStrictEqual(await claim('eleventh', code),
    { outcome: 'rejected', reason: 'target_reached' });
  assert.strictEqual((await enroll('R')).count, 10);
});

test('BE-E2E-02 a farm: one device, ten uids, exactly one credited', async () => {
  const { code } = await enroll('R');
  const outcomes = [];
  for (let i = 0; i < 10; i++) {
    outcomes.push(await claim(`farm${i}`, code, { deviceToken: 'oneRealPhone' }));
  }
  assert.strictEqual(outcomes.filter((o) => o.outcome === 'credited').length, 1);
  assert.strictEqual(outcomes.filter((o) => o.reason === 'device_already_counted').length, 9);
  assert.strictEqual((await referral('R')).count, 1);
});

test('BE-E2E-03 a self-farm: the referrer\'s own device under ten new uids, zero credited', async () => {
  const { code } = await enroll('R', { deviceToken: 'devR' });
  for (let i = 0; i < 10; i++) {
    assert.deepStrictEqual(await claim(`me${i}`, code, { deviceToken: 'devR' }),
      { outcome: 'rejected', reason: 'device_is_referrer' });
  }
  assert.strictEqual((await referral('R')).count, 0);
});

test('BE-E2E-04 target 10: six credits anonymously, sign in with Apple, four more, unlocked under P', async () => {
  await setConfig({ target: 10 });
  await seedPool(2);
  const { code } = await enroll(A, { deviceToken: 'devA' });
  await creditN(code, 5, { prefix: 'pre' });
  advance(DAY + 1000);
  await creditN(code, 1, { prefix: 'pre' });

  const { ticket } = await stand.beginAccountMerge.run(req(A));
  await stand.completeAccountMerge.run(req(P, { ticket }));
  assert.strictEqual((await referral(P)).count, 6);
  assert.strictEqual((await db.collection('referrals').doc(A).get()).exists, false);

  // Friends still hold A's link; it now counts for P.
  const after = await creditN(code, 4, { prefix: 'post' });
  assert.ok(after.every((r) => r.outcome === 'credited'), JSON.stringify(after));
  const rec = await referral(P);
  assert.strictEqual(rec.count, 10);
  assert.strictEqual(rec.status, 'unlocked');
  assert.strictEqual((await pool(rec.reward.code)).assignedTo, P);
});

test('BE-E2E-05 pool empty at unlock, codes imported, sweep delivers the code and a push', async () => {
  const { code } = await enroll('R');
  await withToken('R');
  await creditN(code, 5);
  assert.strictEqual((await referral('R')).status, 'unlocked_pending_code');

  const { code: exit } = await runImport(IMPORT_ARGS, 'Code\nW7HKXJ4MAJFR\n');
  assert.strictEqual(exit, 0);
  sent.length = 0;
  await captureLogs(sweep);

  const rec = await referral('R');
  assert.strictEqual(rec.status, 'unlocked');
  assert.strictEqual(rec.reward.code, 'W7HKXJ4MAJFR');
  assert.strictEqual(sent.length, 1);
  assert.strictEqual(sent[0].notification.body, 'You did it. Your free year is ready.');
});

test('BE-E2E-06 kill switch off mid-campaign, then back on: the same claims count', async () => {
  const { code } = await enroll('R');
  await creditN(code, 2);
  await setConfig({ enabled: false });
  const capturedAt = now - HOUR;
  for (const f of ['late1', 'late2']) {
    assert.deepStrictEqual(await claim(f, code, { capturedAt }),
      { outcome: 'rejected', reason: 'disabled' });
    assert.strictEqual((await claimDoc(f)).exists, false, 'not final');
  }
  advance(3 * DAY);
  await setConfig({ enabled: true });
  for (const f of ['late1', 'late2']) {
    assert.deepStrictEqual(await claim(f, code, { capturedAt }), { outcome: 'credited' });
  }
  assert.strictEqual((await referral('R')).count, 4);
});

test('BE-DEL-04 an unredeemed reward is retired on deletion, not returned to the pool', async () => {
  const { reward } = await unlocked('R', 2);
  await stand.deleteAccount.run(req('R'));
  const p = await pool(reward.code);
  assert.strictEqual(p.retired, true);
  assert.strictEqual(p.assignedTo, 'R');
});
