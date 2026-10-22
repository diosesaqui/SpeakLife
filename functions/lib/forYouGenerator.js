/**
 * Writes one user's weekly For You set: ten new declarations in the themes of
 * what they favorited, each standing on a verse that has been checked.
 *
 * Every candidate the writer returns has to clear four gates, cheapest first:
 *   1. lint      the mechanical CLAUDE.md rules (declarationLint)
 *   2. novelty   not a near-copy of their favorites, past weeks, or this set
 *   3. verse     the reference is real and the quote matches (verseVerifier)
 *   4. judge     a second model agrees the verse promises what the line says
 * The writer is asked for more than ten so rejections do not leave the set
 * short. If it is still short, one top-up round asks for the difference.
 *
 * Everything that talks to the outside world (both models, the verse lookup)
 * comes in through `deps`, so the whole pipeline runs under unit tests.
 */

const { CATEGORIES } = require('./lifeCategories');
const { lintDeclaration, isNearDuplicate } = require('./declarationLint');
const { verifyVerse } = require('./verseVerifier');

const SET_SIZE = 10;
// Fewer than this and the set is not worth a notification; the caller
// retries later instead.
const MIN_TO_SHIP = 7;
const FIRST_ROUND = 14;
const TOP_UP_EXTRA = 4;

const CATEGORY_KEYS = Object.keys(CATEGORIES);

class NotEnoughDeclarationsError extends Error {
  constructor(stats) {
    super(`Only ${stats.accepted} of ${SET_SIZE} declarations passed`);
    this.name = 'NotEnoughDeclarationsError';
    this.stats = stats;
  }
}

function bump(counts, key) {
  counts[key] = (counts[key] || 0) + 1;
}

/**
 * favorites: [{ text, book, category }] the set is modelled on.
 * avoidTexts: earlier weeks' declarations, which must not come back.
 * deps: {
 *   write({ favorites, avoid, count }) → { title, declarations: [{ text, reference, verseText, category }] }
 *   judge([{ id, text, reference, verseText }]) → [{ id, supported, reason }]
 *   library, fetchVerse   (see verseVerifier)
 * }
 * → { title, declarations: [{ text, bibleVerseText, book, category }], stats }
 */
async function generateWeeklySet({ favorites, avoidTexts = [], deps }) {
  const accepted = [];
  const rejected = {};
  const triedTexts = [];
  let title = '';
  let generated = 0;

  const usedRefs = new Set();
  const priorTexts = [...favorites.map((f) => f.text), ...avoidTexts];

  for (const count of [FIRST_ROUND, null]) {
    const want = count || SET_SIZE - accepted.length + TOP_UP_EXTRA;
    if (accepted.length >= SET_SIZE) break;

    const written = await deps.write({
      favorites,
      avoid: [...priorTexts, ...triedTexts],
      count: want,
    });
    if (!title && written.title) title = String(written.title).trim();
    const candidates = Array.isArray(written.declarations) ? written.declarations : [];
    generated += candidates.length;

    // Gates 1 and 2, in order, so a duplicate inside this batch loses to
    // the earlier line rather than both surviving.
    const survivors = [];
    for (const c of candidates) {
      const text = String(c.text || '').trim();
      triedTexts.push(text);
      const lint = lintDeclaration(text);
      if (lint.length) {
        bump(rejected, `lint:${lint[0]}`);
        continue;
      }
      const taken = [...priorTexts, ...accepted.map((a) => a.text), ...survivors.map((s) => s.text)];
      if (isNearDuplicate(text, taken)) {
        bump(rejected, 'duplicate');
        continue;
      }
      survivors.push({ ...c, text });
    }

    // Gate 3, in parallel: most references hit the bundled library and
    // never touch the network.
    const verified = await Promise.all(survivors.map(async (c) => {
      const verse = await verifyVerse(c, deps);
      return { c, verse };
    }));
    const forJudge = [];
    for (const { c, verse } of verified) {
      if (!verse.ok) {
        bump(rejected, `verse:${verse.reason}`);
        continue;
      }
      // Rule 3: one verse, one declaration.
      if (usedRefs.has(verse.key) || forJudge.some((j) => j.book === verse.key)) {
        bump(rejected, 'verse:repeated');
        continue;
      }
      forJudge.push({
        text: c.text,
        bibleVerseText: verse.text,
        book: verse.key,
        category: CATEGORY_KEYS.includes(c.category) ? c.category : 'faith',
      });
    }
    if (forJudge.length === 0) continue;

    // Gate 4. Fails closed: a line the judge did not clearly pass is out.
    const verdicts = await deps.judge(forJudge.map((d, i) => ({
      id: String(i),
      text: d.text,
      reference: d.book,
      verseText: d.bibleVerseText,
    })));
    const passed = new Set(
      (Array.isArray(verdicts) ? verdicts : [])
        .filter((v) => v && v.supported === true)
        .map((v) => String(v.id))
    );
    forJudge.forEach((d, i) => {
      if (!passed.has(String(i))) {
        bump(rejected, 'judge');
        return;
      }
      if (accepted.length < SET_SIZE) {
        accepted.push(d);
        usedRefs.add(d.book);
      }
    });
  }

  const stats = { generated, accepted: accepted.length, rejected };
  if (accepted.length < MIN_TO_SHIP) throw new NotEnoughDeclarationsError(stats);

  return {
    title: cleanTitle(title),
    declarations: accepted,
    stats,
  };
}

function cleanTitle(raw) {
  const title = String(raw || '').replace(/[—–]/g, ',').replace(/\s+/g, ' ').trim();
  return title && title.length <= 60 ? title : 'Your Declarations This Week';
}

/**
 * Which favorites to model the set on: the ones saved in the last seven days
 * when there are enough, otherwise the most recent ones overall, so someone
 * who favorited before this feature shipped still gets a set.
 * → { basis: 'week' | 'recent', favorites } or null when there is too little.
 */
const MIN_FAVORITES = 3;
const MAX_FAVORITES_IN_PROMPT = 15;

function pickFavorites(all, now) {
  const weekAgo = now.getTime() - 7 * 24 * 3600 * 1000;
  const valid = (all || []).filter((f) => f && typeof f.text === 'string' && f.text.trim());
  const byNewest = [...valid].sort((a, b) => (b.favoritedAt || 0) - (a.favoritedAt || 0));
  const thisWeek = byNewest.filter((f) => f.favoritedAt && f.favoritedAt >= weekAgo);
  if (thisWeek.length >= MIN_FAVORITES) {
    return { basis: 'week', favorites: thisWeek.slice(0, MAX_FAVORITES_IN_PROMPT) };
  }
  if (byNewest.length >= MIN_FAVORITES) {
    return { basis: 'recent', favorites: byNewest.slice(0, MAX_FAVORITES_IN_PROMPT) };
  }
  return null;
}

module.exports = {
  generateWeeklySet,
  pickFavorites,
  NotEnoughDeclarationsError,
  SET_SIZE,
  MIN_TO_SHIP,
  FIRST_ROUND,
  MIN_FAVORITES,
  CATEGORY_KEYS,
};
