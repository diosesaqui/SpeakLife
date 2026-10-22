/**
 * The weekly For You service: storage, scheduling and delivery around
 * lib/forYouGenerator.js. weeklyForYou.js wires it to Firebase; the tests
 * wire it to fakes. Everything external comes in through `deps`.
 */

const { nextDrop, isValidTimeZone, DEFAULT_TIME_ZONE } = require('./forYouSchedule');
const { generateWeeklySet, pickFavorites, NotEnoughDeclarationsError } = require('./forYouGenerator');

const COLLECTION = 'forYou';
const VERSE_CACHE = 'verseCache';

// Free users see this many of the ten, and the rest behind the paywall.
const FREE_PREVIEW = 3;
// Nobody who has not opened the app in this long gets a set written.
const ACTIVE_WINDOW_DAYS = 30;
// A failed run retries an hour later, this many times, then waits a week.
const MAX_ATTEMPTS = 3;
// Earlier weeks fed back to the writer so it does not repeat itself.
const HISTORY_WEEKS = 4;
const MAX_FAVORITES_STORED = 100;
// Users written per scheduler run, and how many at once.
const RUN_BATCH = 200;
const RUN_CONCURRENCY = 4;
// Stop picking up new users this long into a run, well inside the timeout.
const RUN_BUDGET_MS = 7 * 60 * 1000;
// bible-api.com allows 15 requests per 30 seconds per IP.
const VERSE_FETCH_SPACING_MS = 2100;

// A run this late is for a Sunday that has passed (the switch was off, or
// the scheduler was down). Writing it now would label it the wrong week and
// push on a weekday, so it waits for the coming Sunday instead.
const STALE_AFTER_MS = 2 * 24 * 3600 * 1000;

const HOUR = 3600 * 1000;
const DAY = 24 * HOUR;

// ─── Small helpers ──────────────────────────────────────────────────────────

function isValidDocId(id) {
  return typeof id === 'string' && id.length > 0 && id.length <= 1500
    && !id.includes('/') && id !== '.' && id !== '..';
}

function str(value, max) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

/** Accepts epoch milliseconds or an ISO string. Anything else is null. */
function toMillis(value) {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) return Math.floor(value);
  if (typeof value === 'string') {
    const t = Date.parse(value);
    return Number.isNaN(t) ? null : t;
  }
  return null;
}

function cleanFavorites(raw) {
  if (!Array.isArray(raw)) return [];
  const seen = new Set();
  const out = [];
  for (const f of raw) {
    if (!f || typeof f !== 'object') continue;
    const text = str(f.text, 400);
    if (!text || seen.has(text)) continue;
    seen.add(text);
    out.push({
      text,
      book: str(f.book, 60),
      category: str(f.category, 40),
      favoritedAt: toMillis(f.favoritedAt),
    });
    if (out.length >= MAX_FAVORITES_STORED) break;
  }
  return out;
}

/** Runs `fn` over `items`, `limit` at a time, until `shouldStop()` says so. */
async function mapLimit(items, limit, fn, shouldStop = () => false) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length && !shouldStop()) {
      const item = items[next];
      next += 1;
      await fn(item);
    }
  });
  await Promise.all(workers);
}

/** Spaces calls to `fn` at least `gapMs` apart, across all callers. */
function spaced(fn, gapMs, sleep = (ms) => new Promise((r) => setTimeout(r, ms))) {
  let chain = Promise.resolve();
  let last = 0;
  return (...args) => {
    const run = chain.then(async () => {
      const wait = last + gapMs - Date.now();
      if (wait > 0) await sleep(wait);
      last = Date.now();
    });
    chain = run.catch(() => {});
    return run.then(() => fn(...args));
  };
}

/**
 * Wraps a verse fetcher with the Firestore cache. Definite answers (found,
 * or no such verse) are cached for good; a failed lookup is not.
 */
function cachedVerseFetcher(db, fetchVerse) {
  return async (key) => {
    const ref = db.collection(VERSE_CACHE).doc(key);
    const hit = await ref.get().catch(() => null);
    if (hit && hit.exists) {
      const data = hit.data();
      return data.missing ? null : { text: data.text };
    }
    const result = await fetchVerse(key);
    await ref.set(result
      ? { text: result.text, fetchedAt: Date.now() }
      : { missing: true, fetchedAt: Date.now() }).catch(() => {});
    return result;
  };
}

function pushCopy(set, basis) {
  const count = set.declarations.length;
  return {
    title: set.title,
    body: basis === 'week'
      ? `${count} new declarations, written from the ones you saved this week. Speak them over your week.`
      : `${count} new declarations, written from the ones you've saved. Speak them over your week.`,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// The service. Everything external comes in through `deps` so the tests run
// the real logic against fakes:
//   db, messaging, now() → Date, modelDeps() → { write, judge, usage },
//   fetchVerse(key), library, isPremium(appUserId, claim) → boolean,
//   isEnabled() → boolean (the weeklyForYou Remote Config switch)
// ═══════════════════════════════════════════════════════════════════════════

function createForYouService(deps) {
  const users = () => deps.db.collection(COLLECTION);

  /** POST { appUserId, favorites, fcmToken?, timeZone? } */
  async function sync(body) {
    const appUserId = str(body && body.appUserId, 1500);
    if (!isValidDocId(appUserId)) return { status: 400, json: { error: 'invalid appUserId' } };
    if (!Array.isArray(body.favorites)) return { status: 400, json: { error: 'favorites must be an array' } };
    if (!(await deps.isEnabled())) return { status: 200, json: { ok: false, disabled: true } };

    const now = deps.now();
    const timeZone = isValidTimeZone(body.timeZone) ? body.timeZone : DEFAULT_TIME_ZONE;
    const ref = users().doc(appUserId);
    const snap = await ref.get();
    const existing = snap.exists ? snap.data() : {};

    const update = {
      favorites: cleanFavorites(body.favorites),
      timeZone,
      updatedAt: now.getTime(),
    };
    const token = str(body.fcmToken, 4096);
    if (token) update.fcmToken = token;

    // Only (re)schedule when there is no schedule yet or the zone moved.
    // Rescheduling on every sync would let an app open on Sunday at 5:59pm
    // push the run back a week.
    if (!existing.nextRunAt || existing.timeZone !== timeZone) {
      const drop = nextDrop(now, timeZone);
      update.nextRunAt = drop.at.getTime();
      update.nextWeekId = drop.weekId;
      update.attempts = 0;
    }

    await ref.set(update, { merge: true });
    const nextRunAt = update.nextRunAt || existing.nextRunAt;
    return {
      status: 200,
      json: {
        ok: true,
        nextRunAt: new Date(nextRunAt).toISOString(),
        latestWeekId: existing.latestWeekId || null,
      },
    };
  }

  /** POST { appUserId, isPremiumClaim? } */
  async function get(body) {
    const appUserId = str(body && body.appUserId, 1500);
    if (!isValidDocId(appUserId)) return { status: 400, json: { error: 'invalid appUserId' } };
    if (!(await deps.isEnabled())) return { status: 200, json: { set: null, disabled: true } };

    const snap = await users().doc(appUserId).get();
    const weekId = snap.exists ? snap.data().latestWeekId : null;
    if (!weekId) return { status: 200, json: { set: null } };

    const weekSnap = await users().doc(appUserId).collection('weeks').doc(weekId).get();
    if (!weekSnap.exists) return { status: 200, json: { set: null } };
    const week = weekSnap.data();

    const premium = await deps.isPremium(appUserId, body.isPremiumClaim === true);
    const all = week.declarations || [];
    const visible = premium ? all : all.slice(0, FREE_PREVIEW);
    return {
      status: 200,
      json: {
        set: {
          weekId,
          title: week.title,
          basis: week.basis,
          createdAt: new Date(week.createdAt).toISOString(),
          declarations: visible,
          locked: all.length - visible.length,
        },
        isPremium: premium,
      },
    };
  }

  async function reschedule(ref, data, now, fields) {
    const drop = nextDrop(now, data.timeZone);
    await ref.set({
      ...fields,
      nextRunAt: drop.at.getTime(),
      nextWeekId: drop.weekId,
      attempts: 0,
      lastRunAt: now.getTime(),
    }, { merge: true });
  }

  async function sendPush(ref, data, set, basis, weekId) {
    if (!data.fcmToken) return 'no_token';
    const { title, body } = pushCopy(set, basis);
    try {
      await deps.messaging.send({
        token: data.fcmToken,
        notification: { title, body },
        // Strings only. notificationType is what the app routes on.
        data: { notificationType: 'forYou', weekId },
        apns: { payload: { aps: { sound: 'default' } } },
      });
      return 'sent';
    } catch (err) {
      if (err && (err.code === 'messaging/registration-token-not-registered'
        || err.code === 'messaging/invalid-registration-token')) {
        await ref.set({ fcmToken: null }, { merge: true });
        return 'stale_token';
      }
      console.error(`For You push failed for ${ref.id}:`, err && err.message);
      return 'failed';
    }
  }

  /** Writes and delivers one user's set. Returns what happened, for logs. */
  async function processUser(ref, data) {
    const now = deps.now();
    const weekId = data.nextWeekId;

    if (data.nextRunAt && data.nextRunAt < now.getTime() - STALE_AFTER_MS) {
      await reschedule(ref, data, now, { lastRunStatus: 'stale' });
      return 'stale';
    }
    if (!data.updatedAt || data.updatedAt < now.getTime() - ACTIVE_WINDOW_DAYS * DAY) {
      await reschedule(ref, data, now, { lastRunStatus: 'inactive' });
      return 'inactive';
    }
    // Written on an earlier attempt that died before rescheduling.
    if (weekId && data.latestWeekId === weekId) {
      await reschedule(ref, data, now, { lastRunStatus: 'ok' });
      return 'already_done';
    }

    const picked = pickFavorites(data.favorites, now);
    if (!picked) {
      await reschedule(ref, data, now, { lastRunStatus: 'too_few_favorites' });
      return 'too_few_favorites';
    }

    const history = await ref.collection('weeks').orderBy('createdAt', 'desc').limit(HISTORY_WEEKS).get()
      .catch(() => null);
    const avoidTexts = history
      ? history.docs.flatMap((d) => (d.data().declarations || []).map((x) => x.text))
      : [];

    const models = deps.modelDeps();
    let set;
    try {
      set = await generateWeeklySet({
        favorites: picked.favorites,
        avoidTexts,
        deps: { write: models.write, judge: models.judge, library: deps.library, fetchVerse: deps.fetchVerse },
      });
    } catch (err) {
      const attempts = (data.attempts || 0) + 1;
      const reason = err instanceof NotEnoughDeclarationsError ? 'not_enough' : 'error';
      console.warn(`For You generation failed for ${ref.id} (attempt ${attempts}):`, err.message,
        err.stats ? JSON.stringify(err.stats) : '');
      if (attempts >= MAX_ATTEMPTS) {
        await reschedule(ref, data, now, { lastRunStatus: `failed_${reason}` });
        return `failed_${reason}`;
      }
      await ref.set({
        attempts,
        nextRunAt: now.getTime() + HOUR,
        lastRunStatus: `retry_${reason}`,
        lastRunAt: now.getTime(),
      }, { merge: true });
      return `retry_${reason}`;
    }

    await ref.collection('weeks').doc(weekId).set({
      title: set.title,
      declarations: set.declarations,
      basis: picked.basis,
      createdAt: now.getTime(),
      stats: set.stats,
      usage: { ...models.usage },
    });
    await reschedule(ref, data, now, { latestWeekId: weekId, lastRunStatus: 'ok' });
    const push = await sendPush(ref, data, set, picked.basis, weekId);
    return `ok_${push}`;
  }

  /** One scheduler tick: everyone due by now, until the time budget runs out. */
  async function runDue() {
    if (!(await deps.isEnabled())) return { disabled: true };
    const started = Date.now();
    const snap = await users()
      .where('nextRunAt', '<=', deps.now().getTime())
      .orderBy('nextRunAt')
      .limit(RUN_BATCH)
      .get();
    const outcomes = {};
    await mapLimit(snap.docs, RUN_CONCURRENCY, async (doc) => {
      let outcome;
      try {
        outcome = await processUser(doc.ref, doc.data());
      } catch (err) {
        console.error(`For You run crashed for ${doc.id}:`, err && err.message);
        outcome = 'crashed';
      }
      outcomes[outcome] = (outcomes[outcome] || 0) + 1;
    }, () => Date.now() - started > RUN_BUDGET_MS);
    return { due: snap.docs.length, outcomes };
  }

  return { sync, get, processUser, runDue };
}

module.exports = {
  createForYouService,
  cachedVerseFetcher,
  cleanFavorites,
  spaced,
  mapLimit,
  FREE_PREVIEW,
  MAX_ATTEMPTS,
  ACTIVE_WINDOW_DAYS,
  VERSE_FETCH_SPACING_MS,
};
