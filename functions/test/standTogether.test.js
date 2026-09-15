/**
 * standTogether.test.js
 * Cloud Function tests for Stand With Me, run against the Firestore emulator.
 *
 *   npm run test:functions
 *
 * Two halves:
 *
 *   1. Pure helpers (code generation, timezone math, name sanitizing, campaign
 *      validation) called directly through the module's __test seam. Most of
 *      the sharp edges in standTogether.js live here and none of them need a
 *      Firestore round trip.
 *
 *   2. Callable and trigger handlers driven through `.run()` against the
 *      emulator, covering every failure branch of joinStand, the fan-out
 *      policy, and merge idempotency.
 *
 * FCM is stubbed: the emulator has no messaging, and what these tests need to
 * assert is HOW MANY pushes a room produces, not that Google delivered them.
 */

process.env.FIRESTORE_EMULATOR_HOST ||= '127.0.0.1:8080';
process.env.GCLOUD_PROJECT ||= 'speaklife-fn-test';

const assert = require('node:assert');
const { test } = require('node:test');

// Stub messaging BEFORE standTogether.js is required, since it grabs
// getMessaging() at module load.
const admin = require('firebase-admin/messaging');
const sent = [];
const originalGetMessaging = admin.getMessaging;
admin.getMessaging = () => ({
  send: async (msg) => { sent.push(msg); return 'stub'; },
});

const adminAuth = require('firebase-admin/auth');
adminAuth.getAuth = () => ({ deleteUser: async () => {} });

const fns = require('../standTogether');
const H = fns.__test;

const { getFirestore, Timestamp, FieldValue } = require('firebase-admin/firestore');
const db = getFirestore();

// ─── Helpers ────────────────────────────────────────────────────────────────

const req = (uid, data = {}) => ({ auth: { uid }, data });

async function wipe() {
  sent.length = 0;
  for (const c of ['standRooms', 'standInvites', 'standNudges', 'users',
                   'accountMerges', 'standRateLimits']) {
    const snap = await db.collection(c).get();
    await Promise.all(snap.docs.map((d) => d.ref.delete()));
  }
}

function campaign(id = 'peace') {
  return {
    id, title: 'Enforcing Peace', tagline: 'Seven days.', theme: 'peace',
    days: Array.from({ length: 7 }, (_, i) => ({
      dayNumber: i + 1,
      anchorText: `Day ${i + 1} anchor.`,
      anchorVerse: 'You will keep in perfect peace those whose minds are steadfast.',
      anchorBook: 'Isaiah 26:3',
      anchorTranslation: 'NIV',
      audioId: `a${i}`, audioTitle: 'Peace', audioMinutes: 10,
    })),
  };
}

/** Gives a user an FCM token so push() actually attempts a send. */
async function withToken(uid) {
  await db.collection('users').doc(uid).set({ uid, fcmToken: `tok_${uid}` }, { merge: true });
}

async function createStand(uid = 'owner', name = 'Sarah') {
  return fns.createStand.run(req(uid, {
    enforcement: campaign(), name, tz: 'America/New_York',
  }));
}

async function expectCode(fn, code) {
  try {
    await fn();
    assert.fail(`expected ${code}, but the call succeeded`);
  } catch (err) {
    assert.strictEqual(err.code, code, `expected ${code}, got ${err.code}: ${err.message}`);
  }
}

test.beforeEach(wipe);
test.after(() => { admin.getMessaging = originalGetMessaging; });

// ═══ Pure helpers ═══════════════════════════════════════════════════════════

test('invite codes are unique and uniform over 20k draws', () => {
  const seen = new Set();
  const freq = Object.fromEntries([...H.CODE_ALPHABET].map((c) => [c, 0]));
  const N = 20000;
  for (let i = 0; i < N; i++) {
    const code = H.generateCode();
    assert.strictEqual(code.length, H.CODE_LENGTH);
    seen.add(code);
    for (const ch of code) {
      assert.ok(ch in freq, `'${ch}' is outside the alphabet`);
      freq[ch] += 1;
    }
  }
  assert.strictEqual(seen.size, N, 'collision in 20k codes');

  // Rejection sampling should hold every character within ~20% of even. A
  // modulo-biased generator skews the first few characters well past this.
  const expected = (N * H.CODE_LENGTH) / H.CODE_ALPHABET.length;
  for (const [ch, n] of Object.entries(freq)) {
    const drift = Math.abs(n - expected) / expected;
    assert.ok(drift < 0.2, `'${ch}' drifted ${(drift * 100).toFixed(1)}% from even`);
  }
});

test('confusable characters are rejected, not guessed', () => {
  assert.strictEqual(H.normalizeCode('abcd-2345'), 'ABCD2345');
  assert.strictEqual(H.normalizeCode('ABCD 2345'), 'ABCD2345');
  // 0/O and 1/I/L are both excluded from the alphabet, so a typed one cannot
  // be valid under any reading. Landing someone in the wrong family's stand is
  // the failure this prevents.
  for (const bad of ['ABCD234O', 'ABCD234I', 'ABCD234L', 'ABCD2340', 'ABCD2341']) {
    assert.strictEqual(H.normalizeCode(bad), null, `${bad} should be rejected`);
  }
  assert.strictEqual(H.normalizeCode('ABCD234'), null);   // too short
  assert.strictEqual(H.normalizeCode(null), null);
});

test('a hostile timezone never throws', () => {
  assert.strictEqual(H.safeTz('Mars/Olympus'), 'UTC');
  assert.strictEqual(H.safeTz(''), 'UTC');
  assert.strictEqual(H.safeTz(null), 'UTC');
  assert.strictEqual(H.safeTz('America/New_York'), 'America/New_York');
  assert.doesNotThrow(() => H.localDayStamp('Mars/Olympus'));
});

test('day stamps are local, so the date line does not make anyone late', () => {
  // 03:00 UTC on the 15th. Already the 15th in Auckland, still the 14th in LA.
  const t = new Date('2026-09-15T03:00:00Z');
  assert.strictEqual(H.localDayStamp('Pacific/Auckland', t), '2026-09-15');
  assert.strictEqual(H.localDayStamp('America/Los_Angeles', t), '2026-09-14');
  assert.strictEqual(H.localDayStamp('UTC', t), '2026-09-15');
});

test('nextLocalHour lands on 19:00 local, including across DST', () => {
  const check = (tz, from) => {
    const at = H.nextLocalHour(tz, 19, new Date(from));
    assert.ok(at > new Date(from), 'must be in the future');
    const local = new Intl.DateTimeFormat('en-US', {
      timeZone: tz, hour12: false, hour: '2-digit',
    }).format(at);
    assert.strictEqual(local.replace('24', '00'), '19', `${tz} from ${from}`);
    // Never more than a day out.
    assert.ok(at - new Date(from) <= 86400000 + 3600000);
  };
  check('America/New_York', '2026-09-15T12:00:00Z');   // before 19:00 local
  check('America/New_York', '2026-09-16T02:00:00Z');   // after 19:00 local
  check('Pacific/Auckland', '2026-09-15T12:00:00Z');
  check('Asia/Kolkata',     '2026-09-15T12:00:00Z');   // +05:30 half-hour zone
  check('America/New_York', '2026-11-01T02:00:00Z');   // US DST fall back
  check('America/New_York', '2026-03-08T02:00:00Z');   // US DST spring forward
  check('Australia/Lord_Howe', '2026-04-05T12:00:00Z'); // +10:30/+11 zone
});

test('names are first-name-only, bounded, and stripped of control characters', () => {
  assert.strictEqual(H.sanitizeName('Sarah Jane Smith'), 'Sarah');
  assert.strictEqual(H.sanitizeName('  Mom  '), 'Mom');
  assert.strictEqual(H.sanitizeName(''), 'Friend');
  assert.strictEqual(H.sanitizeName(null), 'Friend');
  assert.strictEqual(H.sanitizeName('x'.repeat(100)).length, 24);
  // A zero-width run is how you forge a blank or spoofed name in a member list.
  assert.strictEqual(H.sanitizeName('A\u200BB'), 'AB');
  assert.strictEqual(H.sanitizeName('A\u0000B'), 'AB');
  assert.ok(!H.sanitizeName('Line\u2028Break').includes('\u2028'));
});

test('a malformed campaign is rejected before it reaches other devices', () => {
  const bad = (mutate, why) => {
    const c = campaign();
    mutate(c);
    assert.throws(() => H.validateEnforcement(c), why);
  };
  bad((c) => { c.days = c.days.slice(0, 6); }, /7 days|argument/);
  bad((c) => { c.days[1].dayNumber = 1; }, /Duplicate|argument/);
  bad((c) => { c.days[0].anchorText = ''; }, /Malformed|argument/);
  bad((c) => { c.days[0].anchorText = 'x'.repeat(601); }, /Malformed|argument/);
  bad((c) => { c.title = ''; }, /Malformed|argument/);
  assert.throws(() => H.validateEnforcement(null));
  assert.throws(() => H.validateEnforcement({}));

  // Anything the client bolted on is dropped rather than stored.
  const withJunk = { ...campaign(), evil: '<script>', days: campaign().days };
  const clean = H.validateEnforcement(withJunk);
  assert.strictEqual(clean.evil, undefined);
  assert.strictEqual(clean.days.length, 7);
});

// ═══ createStand ════════════════════════════════════════════════════════════

test('createStand mints a room, an invite, and the owner', async () => {
  const { roomId, code } = await createStand('owner');
  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.strictEqual(room.status, 'active');
  assert.deepStrictEqual(room.memberUids, ['owner']);
  assert.strictEqual(room.members.owner.isOwner, true);
  assert.strictEqual(room.members.owner.dayNumber, 0);
  assert.strictEqual(room.members.owner.name, 'Sarah');

  const invite = (await db.collection('standInvites').doc(code).get()).data();
  assert.strictEqual(invite.roomId, roomId);
  assert.strictEqual(invite.uses, 0);
  assert.strictEqual(invite.revoked, false);

  const user = (await db.collection('users').doc('owner').get()).data();
  assert.deepStrictEqual(user.standRoomIds, [roomId]);
});

test('createStand caps concurrent rooms', async () => {
  await createStand('owner');
  await createStand('owner');
  await createStand('owner');
  await expectCode(() => createStand('owner'), 'resource-exhausted');
});

test('createStand rejects a malformed campaign', async () => {
  await expectCode(
    () => fns.createStand.run(req('owner', { enforcement: { id: 'x' }, name: 'S' })),
    'invalid-argument');
});

// ═══ joinStand ══════════════════════════════════════════════════════════════

test('joinStand: the happy path grants membership and a stand pass', async () => {
  const { roomId, code } = await createStand('owner');
  const res = await fns.joinStand.run(req('mom', { code, name: 'Mom', tz: 'America/Chicago' }));

  assert.strictEqual(res.roomId, roomId);
  assert.strictEqual(res.alreadyMember, false);
  assert.ok(res.enforcement, 'the joiner needs the campaign to run it');

  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.deepStrictEqual(room.memberUids.sort(), ['mom', 'owner']);
  assert.strictEqual(room.members.mom.dayNumber, 0);
  assert.strictEqual(room.members.mom.isOwner, false);

  const pass = (await db.collection('users').doc('mom').get()).data().standPass;
  assert.ok(pass.expiresAt.toMillis() > Date.now(), 'pass should be live');
  assert.strictEqual(pass.grantedBy, roomId);

  assert.strictEqual((await db.collection('standInvites').doc(code).get()).data().uses, 1);
});

test('joinStand is idempotent — the same link twice is a no-op, not an error', async () => {
  const { code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  const second = await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  assert.strictEqual(second.alreadyMember, true);
  // The seat is not charged twice.
  assert.strictEqual((await db.collection('standInvites').doc(code).get()).data().uses, 1);
});

test('joinStand: every failure branch reports its own reason', async () => {
  const { roomId, code } = await createStand('owner');

  await expectCode(() => fns.joinStand.run(req('u', { code: 'ZZZZZZZZ' })), 'not-found');
  await expectCode(() => fns.joinStand.run(req('u', { code: 'nope' })), 'invalid-argument');

  await db.collection('standInvites').doc(code).update({ revoked: true });
  await expectCode(() => fns.joinStand.run(req('u1', { code })), 'permission-denied');

  await db.collection('standInvites').doc(code)
    .update({ revoked: false, expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
  await expectCode(() => fns.joinStand.run(req('u2', { code })), 'deadline-exceeded');

  await db.collection('standInvites').doc(code)
    .update({ expiresAt: Timestamp.fromMillis(Date.now() + 86400000) });
  await db.collection('standRooms').doc(roomId).update({ status: 'completed' });
  await expectCode(() => fns.joinStand.run(req('u3', { code })), 'failed-precondition');

  await db.collection('standRooms').doc(roomId).update({ status: 'active' });
  await db.collection('standInvites').doc(code).update({ uses: 99, maxUses: 1 });
  await expectCode(() => fns.joinStand.run(req('u4', { code })), 'resource-exhausted');
});

test('joinStand refuses a full room', async () => {
  const { roomId, code } = await createStand('owner');
  const members = {};
  const uids = ['owner'];
  for (let i = 1; i < H.MAX_MEMBERS; i++) {
    const uid = `m${i}`;
    uids.push(uid);
    members[`members.${uid}`] = {
      name: `M${i}`, initial: 'M', colorIndex: 1, joinedAt: Timestamp.now(),
      dayNumber: 0, daysSpoken: [], lastSpokeAt: null, tz: 'UTC',
      left: false, isOwner: false,
    };
  }
  await db.collection('standRooms').doc(roomId)
    .update({ memberUids: uids, ...members });
  await db.collection('standInvites').doc(code).update({ maxUses: 99 });

  await expectCode(() => fns.joinStand.run(req('one_too_many', { code })), 'resource-exhausted');
});

test('joinStand throttles brute-force code guessing', async () => {
  // The guard on an 8-character code. Throttling runs BEFORE the lookup, so a
  // miss costs the attacker an attempt just like a hit does.
  for (let i = 0; i < 20; i++) {
    await fns.joinStand.run(req('attacker', { code: 'ZZZZZZZZ' })).catch(() => {});
  }
  await expectCode(() => fns.joinStand.run(req('attacker', { code: 'ZZZZZZZZ' })),
    'resource-exhausted');
});

test('a paying subscriber is not handed a redundant stand pass', async () => {
  const { code } = await createStand('owner');
  const far = Timestamp.fromMillis(Date.now() + 365 * 86400000);
  await db.collection('users').doc('mom')
    .set({ standPass: { expiresAt: far, grantedBy: 'existing' } });
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  const pass = (await db.collection('users').doc('mom').get()).data().standPass;
  assert.strictEqual(pass.grantedBy, 'existing', 'an existing pass must not be overwritten');
});

test('rejoining keeps the days already spoken', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  await db.collection('standRooms').doc(roomId).update({
    'members.mom.dayNumber': 3,
    'members.mom.daysSpoken': ['2026-09-13', '2026-09-14', '2026-09-15'],
  });
  await fns.leaveStand.run(req('mom', { roomId }));
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));

  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.strictEqual(room.members.mom.left, false);
  assert.strictEqual(room.members.mom.dayNumber, 3, 'progress must survive a rejoin');
  assert.strictEqual(room.members.mom.daysSpoken.length, 3);
});

// ═══ leaveStand ═════════════════════════════════════════════════════════════

test('leaving hands ownership to the earliest remaining member', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  await fns.joinStand.run(req('dad', { code, name: 'Dad' }));

  await fns.leaveStand.run(req('owner', { roomId }));
  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.strictEqual(room.members.owner.isOwner, false);
  assert.strictEqual(room.members.mom.isOwner, true, 'mom joined first');
  assert.ok(!room.memberUids.includes('owner'));
  // The row survives so the remaining week strip does not renumber.
  assert.ok('owner' in room.members);
  assert.strictEqual(room.members.owner.name, '');
});

test('the last member leaving deletes the room', async () => {
  const { roomId } = await createStand('owner');
  await fns.leaveStand.run(req('owner', { roomId }));
  assert.strictEqual((await db.collection('standRooms').doc(roomId).get()).exists, false);
  const user = (await db.collection('users').doc('owner').get()).data();
  assert.deepStrictEqual(user.standRoomIds, []);
});

// ═══ Fan-out policy ═════════════════════════════════════════════════════════

/** Drives onStandRoomUpdated with a before/after pair. */
async function fireUpdate(roomId, before, after) {
  await fns.onStandRoomUpdated.run({
    params: { roomId },
    data: {
      before: { data: () => before },
      after:  { data: () => after },
    },
  });
}

async function roomWith(n, { day = 1, stamps = ['2026-09-15'] } = {}) {
  const { roomId, code } = await createStand('owner');
  for (let i = 1; i < n; i++) {
    await fns.joinStand.run(req(`m${i}`, { code, name: `M${i}` }));
    await withToken(`m${i}`);
  }
  await withToken('owner');
  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  const before = JSON.parse(JSON.stringify({ ...room, members: room.members }));
  for (const uid of Object.keys(before.members)) {
    before.members[uid].daysSpoken = [];
    before.members[uid].dayNumber = day - 1;
  }
  return { roomId, room, before, stamps };
}

test('a duo pushes exactly once when one partner speaks', async () => {
  const { roomId, room, before } = await roomWith(2);
  const after = JSON.parse(JSON.stringify(before));
  after.members.owner.daysSpoken = ['2026-09-15'];
  after.members.owner.dayNumber = 1;
  after.enforcement = room.enforcement;

  await fireUpdate(roomId, before, after);
  assert.strictEqual(sent.length, 1, 'the partner, and only the partner');
  assert.strictEqual(sent[0].token, 'tok_m1');
  assert.match(sent[0].notification.title, /spoke Day 1/);
});

test('a group of five pushes ZERO times when members speak', async () => {
  // The whole reason the policy exists. Immediate fan-out in a ten-person room
  // is ninety pushes a day, which is an uninstall, not accountability.
  const { roomId, room, before } = await roomWith(5);
  const after = JSON.parse(JSON.stringify(before));
  for (const uid of ['owner', 'm1', 'm2']) {
    after.members[uid].daysSpoken = ['2026-09-15'];
    after.members[uid].dayNumber = 1;
  }
  after.enforcement = room.enforcement;

  await fireUpdate(roomId, before, after);
  assert.strictEqual(sent.length, 0, 'groups get the daily digest instead');
});

test('a duo does not re-push when the same member writes twice in a day', async () => {
  const { roomId, room, before } = await roomWith(2);
  const after = JSON.parse(JSON.stringify(before));
  after.members.owner.daysSpoken = ['2026-09-15'];
  after.members.owner.dayNumber = 1;
  after.enforcement = room.enforcement;

  await fireUpdate(roomId, before, after);
  assert.strictEqual(sent.length, 1);

  // Replay the same transition — a retried offline write, or a second device.
  const reread = (await db.collection('standRooms').doc(roomId).get()).data();
  after.lastNotifiedDay = reread.lastNotifiedDay;
  await fireUpdate(roomId, before, after);
  assert.strictEqual(sent.length, 1, 'one push per speaker per day');
});

test('everyone reaching day 7 completes the room and pushes once each', async () => {
  const { roomId, room, before } = await roomWith(2);
  const after = JSON.parse(JSON.stringify(before));
  for (const uid of ['owner', 'm1']) {
    after.members[uid].dayNumber = 7;
    after.members[uid].daysSpoken = ['2026-09-15'];
  }
  after.enforcement = room.enforcement;
  after.notifiedMilestones = [];

  await fireUpdate(roomId, before, after);
  const saved = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.strictEqual(saved.status, 'completed');
  assert.ok(saved.notifiedMilestones.includes('all_day_7'));
  const completions = sent.filter((m) => /finished/.test(m.notification.title));
  assert.strictEqual(completions.length, 2, 'one each, no more');

  // Replaying must not congratulate them again. Both guards have to be carried
  // over from the saved document, the way a real trigger would see them: the
  // function wrote lastNotifiedDay and notifiedMilestones, and production
  // hands the next invocation the document those writes produced.
  const n = sent.length;
  after.notifiedMilestones = saved.notifiedMilestones;
  after.lastNotifiedDay = saved.lastNotifiedDay;
  await fireUpdate(roomId, before, after);
  assert.strictEqual(sent.length, n, 'a replayed event must be silent');
});

// ═══ Nudges ═════════════════════════════════════════════════════════════════

test('the nudge never fires into silence', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  await withToken('mom');

  // Nobody has spoken today. A push saying "your turn" here is an accusation.
  await db.collection('standNudges').doc('mom').set({
    uid: 'mom', tz: 'UTC', roomIds: [roomId],
    nextNudgeAt: Timestamp.fromMillis(Date.now() - 1000),
    consecutiveMisses: 0,
  });
  await fns.standDailyNudge.run({});
  assert.strictEqual(sent.length, 0);
});

test('the nudge fires when someone else has spoken today', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  await withToken('mom');

  const today = H.localDayStamp('UTC');
  await db.collection('standRooms').doc(roomId).update({
    'members.owner.daysSpoken': [today],
    'members.owner.dayNumber': 3,
  });
  await db.collection('standNudges').doc('mom').set({
    uid: 'mom', tz: 'UTC', roomIds: [roomId],
    nextNudgeAt: Timestamp.fromMillis(Date.now() - 1000),
    consecutiveMisses: 0,
  });

  await fns.standDailyNudge.run({});
  assert.strictEqual(sent.length, 1);
  assert.match(sent[0].notification.title, /Sarah spoke Day 3/);
});

test('nudges back off, then stop, rather than nagging forever', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  await withToken('mom');
  const today = H.localDayStamp('UTC');
  await db.collection('standRooms').doc(roomId).update({
    'members.owner.daysSpoken': [today], 'members.owner.dayNumber': 3,
  });

  const runWith = async (misses) => {
    await db.collection('standNudges').doc('mom').set({
      uid: 'mom', tz: 'UTC', roomIds: [roomId],
      nextNudgeAt: Timestamp.fromMillis(Date.now() - 1000),
      consecutiveMisses: misses,
    });
    await fns.standDailyNudge.run({});
    return (await db.collection('standNudges').doc('mom').get());
  };

  const daily = await runWith(0);
  assert.ok(daily.data().nextNudgeAt.toMillis() - Date.now() <= 86400000 + 3600000);

  const slowed = await runWith(4);
  assert.ok(slowed.data().nextNudgeAt.toMillis() - Date.now() > 2 * 86400000,
    'after repeated misses the cadence should stretch');

  // Someone having the hardest week of their year stops being told about it.
  const stopped = await runWith(9);
  assert.strictEqual(stopped.exists, false, 'nudges should stop entirely');
});

test('one unusable row never stalls the nudge batch', async () => {
  await db.collection('standNudges').doc('broken').set({
    uid: 'broken', tz: 'Mars/Olympus', roomIds: ['does_not_exist'],
    nextNudgeAt: Timestamp.fromMillis(Date.now() - 1000),
    consecutiveMisses: 0,
  });
  await assert.doesNotReject(() => fns.standDailyNudge.run({}));
});

// ═══ Account merge ══════════════════════════════════════════════════════════

test('merge moves an anonymous membership onto the Apple account', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('anon1', { code, name: 'Mom' }));
  await db.collection('standRooms').doc(roomId).update({
    'members.anon1.dayNumber': 3,
    'members.anon1.daysSpoken': ['2026-09-13', '2026-09-14', '2026-09-15'],
  });

  const { ticket } = await fns.beginAccountMerge.run(req('anon1'));
  const res = await fns.completeAccountMerge.run(req('apple1', { ticket }));
  assert.strictEqual(res.merged, 1);

  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.ok(!('anon1' in room.members), 'the anonymous row should be gone');
  assert.strictEqual(room.members.apple1.dayNumber, 3, 'their days must follow them');
  assert.ok(room.memberUids.includes('apple1'));
  assert.ok(!room.memberUids.includes('anon1'));

  const user = (await db.collection('users').doc('apple1').get()).data();
  assert.ok(user.standRoomIds.includes(roomId));
});

test('merge unions the work when both identities are in one room', async () => {
  // Someone joined their own family's stand twice, once per account. Neither
  // side is discarded.
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('anon1', { code, name: 'Mom' }));
  await fns.joinStand.run(req('apple1', { code, name: 'Mom' }));
  await db.collection('standRooms').doc(roomId).update({
    'members.anon1.dayNumber': 5,
    'members.anon1.daysSpoken': ['2026-09-11', '2026-09-12'],
    'members.apple1.dayNumber': 2,
    'members.apple1.daysSpoken': ['2026-09-12', '2026-09-13'],
  });

  const { ticket } = await fns.beginAccountMerge.run(req('anon1'));
  await fns.completeAccountMerge.run(req('apple1', { ticket }));

  const m = (await db.collection('standRooms').doc(roomId).get()).data().members.apple1;
  assert.strictEqual(m.dayNumber, 5, 'the further progress wins');
  assert.deepStrictEqual(m.daysSpoken, ['2026-09-11', '2026-09-12', '2026-09-13']);
  assert.strictEqual(m.left, false);
});

test('merge is idempotent — a killed app can retry safely', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('anon1', { code, name: 'Mom' }));
  const { ticket } = await fns.beginAccountMerge.run(req('anon1'));
  await fns.completeAccountMerge.run(req('apple1', { ticket }));

  const first = (await db.collection('standRooms').doc(roomId).get()).data();
  // The ticket is spent, so the retry reports it rather than half-migrating.
  await expectCode(() => fns.completeAccountMerge.run(req('apple1', { ticket })), 'not-found');
  const second = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.deepStrictEqual(Object.keys(second.members).sort(),
                        Object.keys(first.members).sort());
});

test('an expired merge ticket is refused', async () => {
  const { ticket } = await fns.beginAccountMerge.run(req('anon1'));
  await db.collection('accountMerges').doc(ticket)
    .update({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
  await expectCode(() => fns.completeAccountMerge.run(req('apple1', { ticket })),
    'deadline-exceeded');
});

test('a live stand pass follows the user through the merge', async () => {
  const { code } = await createStand('owner');
  await fns.joinStand.run(req('anon1', { code, name: 'Mom' }));
  const { ticket } = await fns.beginAccountMerge.run(req('anon1'));
  await fns.completeAccountMerge.run(req('apple1', { ticket }));
  const pass = (await db.collection('users').doc('apple1').get()).data().standPass;
  assert.ok(pass?.expiresAt.toMillis() > Date.now(), 'signing in must not cost access');
});

// ═══ deleteAccount ══════════════════════════════════════════════════════════

test('deleting an account clears the user from every stand', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));

  await fns.deleteAccount.run(req('mom', {}));

  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.ok(!('mom' in room.members), 'the row is removed, not tombstoned');
  assert.ok(!room.memberUids.includes('mom'));
  assert.strictEqual((await db.collection('users').doc('mom').get()).exists, false);
  assert.strictEqual((await db.collection('standNudges').doc('mom').get()).exists, false);
});

// ═══ standSweep ═════════════════════════════════════════════════════════════

test('sweep deletes an orphan room whose invite was never used', async () => {
  const { roomId } = await createStand('owner');
  await db.collection('standRooms').doc(roomId)
    .update({ lastActivityAt: Timestamp.fromMillis(Date.now() - 20 * 86400000) });

  await fns.standSweep.run({});
  assert.strictEqual((await db.collection('standRooms').doc(roomId).get()).exists, false);
  const user = (await db.collection('users').doc('owner').get()).data();
  assert.ok(!(user.standRoomIds || []).includes(roomId));
});

test('sweep marks a silent room dormant instead of deleting it', async () => {
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  await db.collection('standRooms').doc(roomId)
    .update({ lastActivityAt: Timestamp.fromMillis(Date.now() - 20 * 86400000) });

  await fns.standSweep.run({});
  const room = (await db.collection('standRooms').doc(roomId).get()).data();
  // Campaigns wait, they do not expire — that principle outlives the room.
  assert.strictEqual(room.status, 'dormant');
  assert.ok(room.members.mom, 'a dormant room keeps its members');
});

test('sweep archives past the first page instead of re-reading it', async () => {
  // The bug: no status filter, and archiving does not touch lastActivityAt, so
  // the same rooms came back every day forever and nothing new was archived.
  const { roomId, code } = await createStand('owner');
  await fns.joinStand.run(req('mom', { code, name: 'Mom' }));
  const longAgo = Timestamp.fromMillis(Date.now() - 90 * 86400000);
  await db.collection('standRooms').doc(roomId)
    .update({ status: 'dormant', lastActivityAt: longAgo });

  await fns.standSweep.run({});
  const first = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.strictEqual(first.status, 'archived');
  assert.strictEqual(first.members.mom.name, '', 'names are cleared on archive');

  // A second pass must not pick it up again — that is what starved the queue.
  await fns.standSweep.run({});
  const second = (await db.collection('standRooms').doc(roomId).get()).data();
  assert.strictEqual(second.status, 'archived');
});
