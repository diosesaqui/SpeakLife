/**
 * forYouService.test.js
 * Storage, scheduling and delivery for the weekly For You set, against an
 * in-memory Firestore, a fake FCM and fake models. Covers the three entry
 * points the app and the scheduler hit: sync, get and runDue, plus the
 * Remote Config kill switch and the verse cache.
 *
 *   npm run test:foryou
 */

const assert = require('node:assert');
const { test, describe, beforeEach } = require('node:test');

const { createFakeFirestore } = require('./support/fakeFirestore');
const {
  createForYouService, cachedVerseFetcher, cleanFavorites, spaced, mapLimit,
  FREE_PREVIEW, MAX_ATTEMPTS,
} = require('../lib/forYouService');
const { makeRemoteFlag } = require('../lib/remoteFlag');

// Thursday 22 Oct 2026, noon UTC. The coming drop in New York is
// Sunday 25 Oct, 6pm EDT = 22:00Z.
const THURSDAY = new Date('2026-10-22T12:00:00Z');
const SUNDAY_DROP = new Date('2026-10-25T22:00:00Z');
const NEXT_DROP = new Date('2026-11-01T23:00:00Z'); // after US clocks fall back
const DAY = 24 * 3600 * 1000;

const VERSES = [
  ['Philippians 4:19', 'And my God will meet all your needs according to the riches of his glory in Christ Jesus.', 'My God supplies every need I have from His riches in glory.'],
  ['Isaiah 26:3', 'You will keep in perfect peace those whose minds are steadfast, because they trust in you.', 'My mind stays fixed on God, and His perfect peace guards it.'],
  ['2 Timothy 1:7', 'For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.', 'I carry power, love, and a sound mind from the Spirit of God.'],
  ['Psalm 23:1', 'The LORD is my shepherd, I lack nothing.', 'The Lord shepherds my life, and I lack no good thing today.'],
  ['Joshua 1:9', 'Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the LORD your God will be with you wherever you go.', 'I am strong and courageous because my God walks beside me.'],
  ['Romans 8:37', 'No, in all these things we are more than conquerors through him who loved us.', 'I am more than a conqueror through Christ who loves me.'],
  ['Proverbs 3:6', 'In all your ways submit to him, and he will make your paths straight.', 'I trust Him in every decision, and He makes my road straight.'],
  ['Psalm 91:11', 'For he will command his angels concerning you to guard you in all your ways.', 'Angels guard my coming and going, wherever my feet step.'],
  ['John 14:27', 'Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.', 'Jesus hands me His own peace, and my heart stands untroubled.'],
  ['Psalm 103:3', 'Who forgives all your sins and heals all your diseases.', 'He forgives every sin I carry and heals every disease in my body.'],
  ['Isaiah 40:31', 'But those who hope in the LORD will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.', 'I hope in the Lord, so I soar, run, and never grow faint.'],
  ['Romans 8:1', 'Therefore, there is now no condemnation for those who are in Christ Jesus.', 'No condemnation touches me, because I stand in Christ Jesus.'],
];
const LIBRARY = Object.fromEntries(VERSES.map(([k, v]) => [k, [v]]));
const GOOD_WRITE = {
  title: 'Peace and Provision',
  declarations: VERSES.map(([reference, verseText, text]) => ({ text, reference, verseText, category: 'rest' })),
};

function favorites(n, at) {
  const texts = [
    'I have the mind of Christ, sound and at rest.',
    'God is my provider, and I lack nothing.',
    'I am healed and whole in every part.',
    'His favor surrounds me like a shield.',
  ];
  return texts.slice(0, n).map((text, i) => ({ text, book: 'Psalm 5:12', category: 'favor', favoritedAt: at - i * 1000 }));
}

let db;
let clock;
let pushes;
let pushError;
let writeResponses;
let enabled;
let premium;
let service;

beforeEach(() => {
  db = createFakeFirestore();
  clock = THURSDAY;
  pushes = [];
  pushError = null;
  writeResponses = null;
  enabled = true;
  premium = false;
  service = createForYouService({
    db,
    now: () => clock,
    library: LIBRARY,
    fetchVerse: async () => { throw new Error('network not expected'); },
    isEnabled: async () => enabled,
    isPremium: async (_id, claim) => premium || claim,
    messaging: {
      async send(message) {
        if (pushError) throw pushError;
        pushes.push(message);
        return 'msg-id';
      },
    },
    modelDeps: () => ({
      usage: { inputTokens: 10, outputTokens: 5, calls: 2 },
      async write() {
        const next = writeResponses ? writeResponses.shift() : structuredClone(GOOD_WRITE);
        if (next instanceof Error) throw next;
        return next;
      },
      async judge(items) { return items.map((it) => ({ id: it.id, supported: true, reason: 'ok' })); },
    }),
  });
});

async function syncUser(id = 'u1', overrides = {}) {
  return service.sync({
    appUserId: id,
    favorites: favorites(4, clock.getTime() - DAY),
    fcmToken: 'token-1',
    timeZone: 'America/New_York',
    ...overrides,
  });
}

// ─── sync ───────────────────────────────────────────────────────────────────

describe('sync', () => {
  test('stores favorites, token and zone, and schedules the coming Sunday', async () => {
    const res = await syncUser();
    assert.strictEqual(res.status, 200);
    assert.deepStrictEqual(res.json, { ok: true, nextRunAt: SUNDAY_DROP.toISOString(), latestWeekId: null });

    const doc = db.read('forYou/u1');
    assert.strictEqual(doc.favorites.length, 4);
    assert.strictEqual(doc.fcmToken, 'token-1');
    assert.strictEqual(doc.timeZone, 'America/New_York');
    assert.strictEqual(doc.nextRunAt, SUNDAY_DROP.getTime());
    assert.strictEqual(doc.nextWeekId, '2026-10-25');
    assert.strictEqual(doc.updatedAt, THURSDAY.getTime());
  });

  test('a later sync does not push the schedule back', async () => {
    await syncUser();
    clock = new Date(SUNDAY_DROP.getTime() - 60 * 1000); // Sunday 5:59pm
    await syncUser();
    assert.strictEqual(db.read('forYou/u1').nextRunAt, SUNDAY_DROP.getTime());
  });

  test('a time zone change reschedules', async () => {
    await syncUser();
    await syncUser('u1', { timeZone: 'America/Los_Angeles' });
    assert.strictEqual(db.read('forYou/u1').nextRunAt, new Date('2026-10-26T01:00:00Z').getTime());
  });

  test('an invalid zone falls back to New York', async () => {
    await syncUser('u1', { timeZone: 'Not/AZone' });
    assert.strictEqual(db.read('forYou/u1').timeZone, 'America/New_York');
  });

  test('keeps the old token when the app sends none', async () => {
    await syncUser();
    await syncUser('u1', { fcmToken: '' });
    assert.strictEqual(db.read('forYou/u1').fcmToken, 'token-1');
  });

  test('replaces the favorites list with the latest snapshot', async () => {
    await syncUser();
    await syncUser('u1', { favorites: [{ text: 'Only this one.' }] });
    assert.deepStrictEqual(db.read('forYou/u1').favorites.map((f) => f.text), ['Only this one.']);
  });

  test('rejects a bad user id or a missing favorites array', async () => {
    for (const body of [
      { appUserId: '', favorites: [] },
      { appUserId: 'a/b', favorites: [] },
      { appUserId: 'u1' },
      { appUserId: 'u1', favorites: 'x' },
      null,
    ]) {
      const res = await service.sync(body || {});
      assert.strictEqual(res.status, 400, JSON.stringify(body));
    }
    assert.strictEqual(db.docs.size, 0);
  });

  test('does nothing while the switch is off', async () => {
    enabled = false;
    const res = await syncUser();
    assert.deepStrictEqual(res, { status: 200, json: { ok: false, disabled: true } });
    assert.strictEqual(db.docs.size, 0);
  });
});

describe('cleanFavorites', () => {
  test('keeps valid entries, trims, dedupes and parses dates', () => {
    const out = cleanFavorites([
      { text: '  I am loved.  ', book: 'John 3:16', category: 'love', favoritedAt: '2026-10-20T10:00:00Z' },
      { text: 'I am loved.' },
      { text: '' },
      null,
      'string',
      { text: 'Second.', favoritedAt: 1760000000000 },
      { text: 'Bad date.', favoritedAt: 'yesterday' },
    ]);
    assert.deepStrictEqual(out, [
      { text: 'I am loved.', book: 'John 3:16', category: 'love', favoritedAt: Date.parse('2026-10-20T10:00:00Z') },
      { text: 'Second.', book: '', category: '', favoritedAt: 1760000000000 },
      { text: 'Bad date.', book: '', category: '', favoritedAt: null },
    ]);
  });

  test('caps the list and the length of each field', () => {
    const many = Array.from({ length: 300 }, (_, i) => ({ text: `line ${i} ${'x'.repeat(1000)}` }));
    const out = cleanFavorites(many);
    assert.strictEqual(out.length, 100);
    assert.ok(out.every((f) => f.text.length <= 400));
    assert.deepStrictEqual(cleanFavorites('nope'), []);
  });
});

// ─── runDue / processUser ───────────────────────────────────────────────────

describe('the Sunday run', () => {
  test('nobody is due before Sunday 6pm', async () => {
    await syncUser();
    clock = new Date(SUNDAY_DROP.getTime() - 1000);
    assert.deepStrictEqual(await service.runDue(), { due: 0, outcomes: {} });
  });

  test('writes the set, schedules next week, and sends the push', async () => {
    await syncUser();
    clock = new Date(SUNDAY_DROP.getTime() + 5 * 60 * 1000);
    const result = await service.runDue();
    assert.deepStrictEqual(result, { due: 1, outcomes: { ok_sent: 1 } });

    const week = db.read('forYou/u1/weeks/2026-10-25');
    assert.strictEqual(week.title, 'Peace and Provision');
    assert.strictEqual(week.declarations.length, 10);
    assert.strictEqual(week.basis, 'week');
    assert.deepStrictEqual(Object.keys(week.declarations[0]).sort(), ['bibleVerseText', 'book', 'category', 'text']);
    assert.deepStrictEqual(week.usage, { inputTokens: 10, outputTokens: 5, calls: 2 });

    const user = db.read('forYou/u1');
    assert.strictEqual(user.latestWeekId, '2026-10-25');
    assert.strictEqual(user.nextRunAt, NEXT_DROP.getTime());
    assert.strictEqual(user.nextWeekId, '2026-11-01');
    assert.strictEqual(user.attempts, 0);
    assert.strictEqual(user.lastRunStatus, 'ok');

    assert.strictEqual(pushes.length, 1);
    assert.deepStrictEqual(pushes[0], {
      token: 'token-1',
      notification: {
        title: 'Peace and Provision',
        body: '10 new declarations, written from the ones you saved this week. Speak them over your week.',
      },
      data: { notificationType: 'forYou', weekId: '2026-10-25' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    // FCM data values must all be strings.
    assert.ok(Object.values(pushes[0].data).every((v) => typeof v === 'string'));
  });

  test('running again in the same hour does nothing', async () => {
    await syncUser();
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    await service.runDue();
    clock = new Date(SUNDAY_DROP.getTime() + 2 * 60 * 1000);
    assert.deepStrictEqual(await service.runDue(), { due: 0, outcomes: {} });
    assert.strictEqual(pushes.length, 1);
  });

  test('older favorites still get a set, with honest push copy', async () => {
    await syncUser('u1', { favorites: favorites(4, THURSDAY.getTime() - 30 * DAY) });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    await service.runDue();
    assert.strictEqual(db.read('forYou/u1/weeks/2026-10-25').basis, 'recent');
    assert.match(pushes[0].notification.body, /from the ones you've saved\./);
  });

  test('too few favorites: no set, no push, try next week', async () => {
    await syncUser('u1', { favorites: favorites(2, THURSDAY.getTime()) });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual((await service.runDue()).outcomes, { too_few_favorites: 1 });
    assert.strictEqual(pushes.length, 0);
    assert.strictEqual(db.read('forYou/u1').nextRunAt, NEXT_DROP.getTime());
  });

  test('a user who has not opened the app in 30 days is skipped', async () => {
    await syncUser();
    db.put('forYou/u1', { ...db.read('forYou/u1'), updatedAt: SUNDAY_DROP.getTime() - 31 * DAY });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual((await service.runDue()).outcomes, { inactive: 1 });
    assert.strictEqual(pushes.length, 0);
  });

  test('a failed generation retries an hour later, then gives up for the week', async () => {
    await syncUser();
    writeResponses = Array.from({ length: 10 }, () => new Error('overloaded'));
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);

    for (let attempt = 1; attempt < MAX_ATTEMPTS; attempt += 1) {
      assert.deepStrictEqual((await service.runDue()).outcomes, { retry_error: 1 });
      const user = db.read('forYou/u1');
      assert.strictEqual(user.attempts, attempt);
      assert.strictEqual(user.nextRunAt, clock.getTime() + 3600 * 1000);
      clock = new Date(user.nextRunAt);
    }
    assert.deepStrictEqual((await service.runDue()).outcomes, { failed_error: 1 });
    const user = db.read('forYou/u1');
    assert.strictEqual(user.attempts, 0);
    assert.strictEqual(user.nextRunAt, NEXT_DROP.getTime());
    assert.strictEqual(user.lastRunStatus, 'failed_error');
    assert.strictEqual(pushes.length, 0);
  });

  test('a retry that succeeds still files under the Sunday it belongs to', async () => {
    await syncUser();
    writeResponses = [new Error('overloaded')];
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    await service.runDue();
    clock = new Date(clock.getTime() + 3600 * 1000);
    writeResponses = null;
    assert.deepStrictEqual((await service.runDue()).outcomes, { ok_sent: 1 });
    assert.ok(db.read('forYou/u1/weeks/2026-10-25'));
  });

  test('too few passing declarations counts as a retryable failure', async () => {
    await syncUser();
    writeResponses = [{ title: 't', declarations: [] }, { title: 't', declarations: [] }];
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual((await service.runDue()).outcomes, { retry_not_enough: 1 });
  });

  test('earlier weeks are fed back so they are not repeated', async () => {
    await syncUser();
    db.put('forYou/u1/weeks/2026-10-18', {
      title: 'Old', createdAt: 1, declarations: [{ text: 'Last week line one.' }, { text: 'Last week line two.' }],
    });
    const seen = [];
    const base = service;
    service = createForYouService({
      db,
      now: () => clock,
      library: LIBRARY,
      fetchVerse: async () => null,
      isEnabled: async () => true,
      isPremium: async () => false,
      messaging: { send: async () => 'ok' },
      modelDeps: () => ({
        usage: {},
        async write(req) { seen.push(req); return structuredClone(GOOD_WRITE); },
        async judge(items) { return items.map((it) => ({ id: it.id, supported: true })); },
      }),
    });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    await service.runDue();
    assert.ok(seen[0].avoid.includes('Last week line one.'));
    assert.ok(seen[0].avoid.includes('Last week line two.'));
    service = base;
  });

  test('a run days late (switch was off, scheduler down) waits for the coming Sunday', async () => {
    await syncUser();
    clock = new Date(SUNDAY_DROP.getTime() + 3 * DAY); // Wednesday
    assert.deepStrictEqual((await service.runDue()).outcomes, { stale: 1 });
    assert.strictEqual(pushes.length, 0);
    assert.strictEqual(db.read('forYou/u1').nextRunAt, NEXT_DROP.getTime());
  });

  test('a set already written for this week is not written twice', async () => {
    await syncUser();
    db.put('forYou/u1', { ...db.read('forYou/u1'), latestWeekId: '2026-10-25' });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual((await service.runDue()).outcomes, { already_done: 1 });
    assert.strictEqual(pushes.length, 0);
  });

  test('no token: the set is still written, no push', async () => {
    await syncUser('u1', { fcmToken: '' });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual((await service.runDue()).outcomes, { ok_no_token: 1 });
    assert.ok(db.read('forYou/u1/weeks/2026-10-25'));
  });

  test('a dead token is cleared so it is not retried every week', async () => {
    await syncUser();
    pushError = Object.assign(new Error('gone'), { code: 'messaging/registration-token-not-registered' });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual((await service.runDue()).outcomes, { ok_stale_token: 1 });
    assert.strictEqual(db.read('forYou/u1').fcmToken, null);
  });

  test('any other push failure keeps the token and the set', async () => {
    await syncUser();
    pushError = Object.assign(new Error('unavailable'), { code: 'messaging/internal-error' });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual((await service.runDue()).outcomes, { ok_failed: 1 });
    assert.strictEqual(db.read('forYou/u1').fcmToken, 'token-1');
    assert.strictEqual(db.read('forYou/u1').latestWeekId, '2026-10-25');
  });

  test('one user crashing does not stop the others', async () => {
    await syncUser('u1');
    await syncUser('u2');
    db.put('forYou/u1', { ...db.read('forYou/u1'), favorites: { not: 'an array' } });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    const result = await service.runDue();
    assert.strictEqual(result.due, 2);
    assert.strictEqual(result.outcomes.ok_sent, 1);
  });

  test('users in different zones come due at their own 6pm', async () => {
    await syncUser('ny', { timeZone: 'America/New_York' });
    await syncUser('la', { timeZone: 'America/Los_Angeles' });
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000); // 6:01pm NY, 3:01pm LA
    await service.runDue();
    assert.deepStrictEqual(pushes.map((p) => p.token), ['token-1']);
    assert.ok(db.read('forYou/ny').latestWeekId);
    assert.strictEqual(db.read('forYou/la').latestWeekId, undefined);
  });

  test('does nothing while the switch is off', async () => {
    await syncUser();
    enabled = false;
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    assert.deepStrictEqual(await service.runDue(), { disabled: true });
    assert.strictEqual(pushes.length, 0);
  });
});

// ─── get ────────────────────────────────────────────────────────────────────

describe('get', () => {
  async function userWithSet() {
    await syncUser();
    clock = new Date(SUNDAY_DROP.getTime() + 60 * 1000);
    await service.runDue();
  }

  test('no set yet returns null', async () => {
    assert.deepStrictEqual(await service.get({ appUserId: 'nobody' }), { status: 200, json: { set: null } });
    await syncUser();
    assert.deepStrictEqual((await service.get({ appUserId: 'u1' })).json, { set: null });
  });

  test('a free user sees the preview and a locked count', async () => {
    await userWithSet();
    const { json } = await service.get({ appUserId: 'u1' });
    assert.strictEqual(json.isPremium, false);
    assert.strictEqual(json.set.weekId, '2026-10-25');
    assert.strictEqual(json.set.title, 'Peace and Provision');
    assert.strictEqual(json.set.declarations.length, FREE_PREVIEW);
    assert.strictEqual(json.set.locked, 10 - FREE_PREVIEW);
    assert.strictEqual(json.set.createdAt, clock.toISOString());
  });

  test('a premium user sees all ten', async () => {
    await userWithSet();
    premium = true;
    const { json } = await service.get({ appUserId: 'u1' });
    assert.strictEqual(json.set.declarations.length, 10);
    assert.strictEqual(json.set.locked, 0);
  });

  test('the client premium claim is only a fallback the server decides on', async () => {
    await userWithSet();
    const { json } = await service.get({ appUserId: 'u1', isPremiumClaim: true });
    assert.strictEqual(json.isPremium, true); // the fake isPremium trusts the claim
    assert.strictEqual((await service.get({ appUserId: 'u1', isPremiumClaim: 'true' })).json.isPremium, false);
  });

  test('a missing week document returns null rather than failing', async () => {
    await syncUser();
    db.put('forYou/u1', { ...db.read('forYou/u1'), latestWeekId: '2026-01-04' });
    assert.deepStrictEqual((await service.get({ appUserId: 'u1' })).json, { set: null });
  });

  test('rejects a bad id, and hides everything while the switch is off', async () => {
    assert.strictEqual((await service.get({ appUserId: '' })).status, 400);
    await userWithSet();
    enabled = false;
    assert.deepStrictEqual(await service.get({ appUserId: 'u1' }), { status: 200, json: { set: null, disabled: true } });
  });
});

// ─── helpers ────────────────────────────────────────────────────────────────

describe('cachedVerseFetcher', () => {
  test('fetches once, then serves found and missing verses from Firestore', async () => {
    const cacheDb = createFakeFirestore();
    const calls = [];
    const fetchVerse = cachedVerseFetcher(cacheDb, async (key) => {
      calls.push(key);
      return key === 'John 3:16' ? { text: 'For God so loved' } : null;
    });
    assert.deepStrictEqual(await fetchVerse('John 3:16'), { text: 'For God so loved' });
    assert.deepStrictEqual(await fetchVerse('John 3:16'), { text: 'For God so loved' });
    assert.strictEqual(await fetchVerse('Psalm 23:7'), null);
    assert.strictEqual(await fetchVerse('Psalm 23:7'), null);
    assert.deepStrictEqual(calls, ['John 3:16', 'Psalm 23:7']);
    assert.strictEqual(cacheDb.read('verseCache/Psalm 23:7').missing, true);
  });

  test('does not cache a failed lookup', async () => {
    const cacheDb = createFakeFirestore();
    let fail = true;
    const fetchVerse = cachedVerseFetcher(cacheDb, async () => {
      if (fail) throw new Error('timeout');
      return { text: 'ok' };
    });
    await assert.rejects(fetchVerse('John 3:16'), /timeout/);
    fail = false;
    assert.deepStrictEqual(await fetchVerse('John 3:16'), { text: 'ok' });
  });
});

describe('spaced', () => {
  test('spaces calls by the gap, in order, across concurrent callers', async () => {
    const waits = [];
    const order = [];
    const fn = spaced(async (x) => { order.push(x); return x * 2; }, 2000, async (ms) => { waits.push(ms); });
    const results = await Promise.all([fn(1), fn(2), fn(3)]);
    assert.deepStrictEqual(results, [2, 4, 6]);
    assert.deepStrictEqual(order, [1, 2, 3]);
    assert.strictEqual(waits.length, 2, 'the first call goes straight through');
    assert.ok(waits.every((ms) => ms > 1900 && ms <= 2000));
  });

  test('one failing call does not block the next', async () => {
    let n = 0;
    const fn = spaced(async () => { n += 1; if (n === 1) throw new Error('boom'); return 'ok'; }, 0);
    await assert.rejects(fn(), /boom/);
    assert.strictEqual(await fn(), 'ok');
  });
});

describe('mapLimit', () => {
  test('runs everything with at most `limit` in flight', async () => {
    let inFlight = 0;
    let peak = 0;
    const seen = [];
    await mapLimit([1, 2, 3, 4, 5, 6, 7], 3, async (x) => {
      inFlight += 1;
      peak = Math.max(peak, inFlight);
      await new Promise((r) => setTimeout(r, 2));
      seen.push(x);
      inFlight -= 1;
    });
    assert.strictEqual(peak, 3);
    assert.deepStrictEqual(seen.sort(), [1, 2, 3, 4, 5, 6, 7]);
  });

  test('stops picking up new items once told to', async () => {
    const seen = [];
    await mapLimit([1, 2, 3, 4], 1, async (x) => { seen.push(x); }, () => seen.length >= 2);
    assert.deepStrictEqual(seen, [1, 2]);
  });
});

describe('makeRemoteFlag', () => {
  test('reads the default value of the key, and caches it', async () => {
    let reads = 0;
    let t = 0;
    const isOn = makeRemoteFlag({
      key: 'weeklyForYouEnabled',
      now: () => t,
      ttlMs: 1000,
      getTemplate: async () => { reads += 1; return { parameters: { weeklyForYouEnabled: { defaultValue: { value: 'true' } } } }; },
    });
    assert.strictEqual(await isOn(), true);
    t = 500;
    assert.strictEqual(await isOn(), true);
    assert.strictEqual(reads, 1);
    t = 1500;
    await isOn();
    assert.strictEqual(reads, 2);
  });

  test('anything but true is off, including an unset key', async () => {
    for (const template of [
      { parameters: { weeklyForYouEnabled: { defaultValue: { value: 'false' } } } },
      { parameters: { weeklyForYouEnabled: { defaultValue: { useInAppDefault: true } } } },
      { parameters: {} },
      {},
    ]) {
      const isOn = makeRemoteFlag({ key: 'weeklyForYouEnabled', getTemplate: async () => template });
      assert.strictEqual(await isOn(), false, JSON.stringify(template));
    }
  });

  test('fails closed with no earlier answer, and keeps the last answer on a later error', async () => {
    const broken = makeRemoteFlag({ key: 'k', getTemplate: async () => { throw new Error('403'); } });
    assert.strictEqual(await broken(), false);

    let t = 0;
    let fail = false;
    const flaky = makeRemoteFlag({
      key: 'k',
      ttlMs: 10,
      now: () => t,
      getTemplate: async () => {
        if (fail) throw new Error('503');
        return { parameters: { k: { defaultValue: { value: 'true' } } } };
      },
    });
    assert.strictEqual(await flaky(), true);
    fail = true;
    t = 100;
    assert.strictEqual(await flaky(), true);
  });
});

describe('deployment wiring', () => {
  test('index.js exports the three For You functions', () => {
    const index = require('../index');
    for (const name of ['syncForYouFavorites', 'getWeeklyForYou', 'weeklyForYouRunner']) {
      assert.strictEqual(typeof index[name], 'function', name);
    }
  });
});
