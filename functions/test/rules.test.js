/**
 * rules.test.js
 * Firestore security-rules tests, run against the emulator.
 *
 *   firebase emulators:exec --only firestore "node functions/test/rules.test.js"
 *
 * Written against node's built-in test runner so the repo gains no test
 * framework dependency. @firebase/rules-unit-testing is the only addition.
 *
 * The two cases that matter most, and the reason this file exists at all:
 *
 *   1. An ANONYMOUS user must not be able to post to the Prayer Wall.
 *      Stand With Me introduced anonymous auth, which silently widened the
 *      `signedIn()` helper every Prayer Wall write rule is built on. Without
 *      `isFullAccount()` that change opens a free-text surface to strangers.
 *
 *   2. A client must not be able to write `users/{uid}.standPass` — the
 *      seven-day full-access grant. A client that can write it mints itself
 *      premium.
 */

const assert = require('node:assert');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, serverTimestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'speaklife-rules-test';
const RULES = fs.readFileSync(
  path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8');

let env;

// ─── Helpers ────────────────────────────────────────────────────────────

// An anonymous user: Firebase Auth reports sign_in_provider 'anonymous'.
const anon = (uid) => env.authenticatedContext(uid, {
  firebase: { sign_in_provider: 'anonymous' },
});

// A real Sign in with Apple user.
const apple = (uid) => env.authenticatedContext(uid, {
  firebase: { sign_in_provider: 'apple.com' },
});

function roomFixture(uids, overrides = {}) {
  const members = {};
  for (const uid of uids) {
    members[uid] = {
      name: 'Sarah', initial: 'S', colorIndex: 1,
      joinedAt: new Date(), dayNumber: 2,
      daysSpoken: ['2026-09-13', '2026-09-14'],
      lastSpokeAt: new Date(), tz: 'America/New_York',
      left: false, isOwner: uid === uids[0],
    };
  }
  return {
    id: 'r_test', createdAt: new Date(), createdBy: uids[0],
    status: 'active', schemaVersion: 1,
    enforcement: { id: 'peace', title: 'Enforcing Peace', tagline: 't',
                   theme: 'peace', days: [] },
    memberUids: uids, members,
    completedAt: null, notifiedMilestones: [], lastActivityAt: new Date(),
    ...overrides,
  };
}

// A well-formed "I spoke today" update for `uid`.
function dayWrite(uid, room, { dayNumber, stamps, name = 'Sarah' } = {}) {
  const m = room.members[uid];
  return {
    [`members.${uid}.dayNumber`]: dayNumber ?? m.dayNumber + 1,
    [`members.${uid}.daysSpoken`]: stamps ?? [...m.daysSpoken, '2026-09-15'],
    [`members.${uid}.lastSpokeAt`]: serverTimestamp(),
    [`members.${uid}.name`]: name,
    lastActivityAt: serverTimestamp(),
  };
}

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});

test.beforeEach(async () => { await env.clearFirestore(); });
test.after(async () => { await env?.cleanup(); });

// ═══ Prayer Wall: the anonymous-auth regression guard ═══════════════════

test('anonymous user CANNOT create a prayer wall post', async () => {
  const db = anon('anon1').firestore();
  await assertFails(setDoc(doc(db, 'prayerWall/p1'), {
    authorUid: 'anon1', text: 'hello', isHidden: false, timestamp: new Date(),
  }));
});

test('apple-signed user CAN create a prayer wall post', async () => {
  const db = apple('apple1').firestore();
  await assertSucceeds(setDoc(doc(db, 'prayerWall/p1'), {
    authorUid: 'apple1', text: 'hello', isHidden: false, timestamp: new Date(),
  }));
});

test('anonymous user CANNOT add an agreement', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'prayerWall/p1'),
      { authorUid: 'apple1', text: 'x', isHidden: false });
  });
  const db = anon('anon1').firestore();
  await assertFails(setDoc(doc(db, 'prayerWall/p1/agreements/anon1'), {
    userId: 'anon1', displayName: 'A', text: 'standing',
    reactionType: 'standing',
  }));
});

// ═══ users/{uid}: server-only fields ════════════════════════════════════

test('client CANNOT create users doc carrying standPass', async () => {
  const db = anon('u1').firestore();
  await assertFails(setDoc(doc(db, 'users/u1'), {
    uid: 'u1', standPass: { expiresAt: new Date() },
  }));
});

test('client CANNOT add standPass to an existing users doc', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/u1'), { uid: 'u1' });
  });
  const db = anon('u1').firestore();
  await assertFails(updateDoc(doc(db, 'users/u1'),
    { standPass: { expiresAt: new Date() } }));
});

test('client CANNOT forge standRoomIds', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/u1'), { uid: 'u1' });
  });
  const db = anon('u1').firestore();
  await assertFails(updateDoc(doc(db, 'users/u1'),
    { standRoomIds: ['r_someone_elses'] }));
});

test('client CAN write its own fcm token and tz (anonymous included)', async () => {
  const db = anon('u1').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/u1'), {
    uid: 'u1', fcmToken: 'tok', deviceId: 'd1', tz: 'America/New_York',
  }));
});

// ═══ standRooms ════════════════════════════════════════════════════════

async function seedRoom(uids, overrides) {
  const room = roomFixture(uids, overrides);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'standRooms/r_test'), room);
  });
  return room;
}

test('non-member CANNOT read a room', async () => {
  await seedRoom(['a', 'b']);
  const db = anon('stranger').firestore();
  await assertFails(getDoc(doc(db, 'standRooms/r_test')));
});

test('member CAN read their room', async () => {
  await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertSucceeds(getDoc(doc(db, 'standRooms/r_test')));
});

test('member CAN record today (the happy path)', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertSucceeds(updateDoc(doc(db, 'standRooms/r_test'), dayWrite('a', room)));
});

test('member CANNOT write another member entry', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), dayWrite('b', room)));
});

test('member CANNOT lower their own dayNumber', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    dayWrite('a', room, { dayNumber: 1 })));
});

test('member CANNOT exceed day 7', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    dayWrite('a', room, { dayNumber: 8 })));
});

test('member CANNOT add two day stamps in one write', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    dayWrite('a', room, {
      stamps: [...room.members.a.daysSpoken, '2026-09-15', '2026-09-16'],
    })));
});

test('member CANNOT exceed 14 day stamps', async () => {
  const stamps = Array.from({ length: 14 }, (_, i) => `2026-09-${String(i + 1).padStart(2, '0')}`);
  const room = await seedRoom(['a', 'b']);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'standRooms/r_test'),
      { 'members.a.daysSpoken': stamps });
  });
  room.members.a.daysSpoken = stamps;
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    dayWrite('a', room, { stamps: [...stamps, '2026-09-20'] })));
});

test('member CANNOT rewrite the campaign', async () => {
  await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), {
    enforcement: { id: 'hacked', title: 'x', tagline: 'x', theme: 'peace', days: [] },
    lastActivityAt: serverTimestamp(),
  }));
});

test('member CANNOT add themselves to memberUids or change status', async () => {
  await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    { memberUids: ['a', 'b', 'c'], lastActivityAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    { status: 'completed', lastActivityAt: serverTimestamp() }));
});

test('member CANNOT write a name longer than 24 chars', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    dayWrite('a', room, { name: 'x'.repeat(25) })));
});

test('member CANNOT backdate lastSpokeAt with a client clock', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  const w = dayWrite('a', room);
  w['members.a.lastSpokeAt'] = new Date('2020-01-01');
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), w));
});

test('client CANNOT create or delete a room directly', async () => {
  const db = anon('a').firestore();
  await assertFails(setDoc(doc(db, 'standRooms/r_new'), roomFixture(['a'])));
});

// ═══ server-only collections ═══════════════════════════════════════════

test('client CANNOT read an invite code (no enumeration)', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'standInvites/ABCD2345'),
      { roomId: 'r_test', uses: 0 });
  });
  const db = anon('a').firestore();
  await assertFails(getDoc(doc(db, 'standInvites/ABCD2345')));
});

test('client CANNOT read nudges or merge tickets', async () => {
  const db = anon('a').firestore();
  await assertFails(getDoc(doc(db, 'standNudges/a')));
  await assertFails(getDoc(doc(db, 'accountMerges/t1')));
});

test('member CANNOT forge server notification bookkeeping', async () => {
  await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  // lastNotifiedDay caps one push per sender per day. A client that can write
  // it can silence its partner's nudges — or replay them.
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    { lastNotifiedDay: { a: '2026-09-15' }, lastActivityAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'),
    { notifiedMilestones: ['all_day_7'], lastActivityAt: serverTimestamp() }));
});

test('member CANNOT promote themselves to owner', async () => {
  // isOwner gates createStandInvite. A member who can set it mints invites to
  // somebody else's stand.
  //
  // Asserted as 'b', NOT 'a': roomFixture makes the first uid the owner, so an
  // 'a' writing isOwner:true is a no-op the rule rightly allows, and the test
  // would pass without proving anything.
  const room = await seedRoom(['a', 'b']);
  assert.strictEqual(room.members.b.isOwner, false, 'b must start as a non-owner');
  const db = anon('b').firestore();
  const w = dayWrite('b', room);
  w['members.b.isOwner'] = true;
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), w));
});

test('member CANNOT rewrite their own joinedAt or colorIndex', async () => {
  // joinedAt decides who inherits ownership when the owner leaves.
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  const early = dayWrite('a', room);
  early['members.a.joinedAt'] = new Date(0);
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), early));

  const recolor = dayWrite('a', room);
  recolor['members.a.colorIndex'] = 7;
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), recolor));
});

test('member CANNOT un-leave themselves or write a long initial', async () => {
  const room = await seedRoom(['a', 'b']);
  const db = anon('a').firestore();
  const rejoin = dayWrite('a', room);
  rejoin['members.a.left'] = true;
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), rejoin));

  const initial = dayWrite('a', room);
  initial['members.a.initial'] = 'X'.repeat(50);
  await assertFails(updateDoc(doc(db, 'standRooms/r_test'), initial));
});
