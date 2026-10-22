/**
 * Checks the verse the model chose for a declaration, and returns the verse
 * text that will actually ship.
 *
 * The model picks any verse it likes and quotes it. Its quote is never shown
 * to anyone. Instead:
 *   1. The reference must parse ("Book C:V" or "Book C:V-V").
 *   2. If SpeakLife already ships that verse (verseLibrary.json) and the
 *      model's quote matches it, the shipped wording is used.
 *   3. Otherwise the verse is fetched from a public-domain Bible (WEB). A
 *      reference that does not exist fails here, and the model's quote must
 *      share most of its words with the real verse, or it misremembered.
 *      The fetched text is what ships.
 *
 * Whether the verse actually supports what the declaration claims is a
 * separate check (the judge in forYouGenerator), since no word count can
 * answer that.
 */

const { parseReference } = require('./verseRef');

// Share of the model's content words that must appear in the real verse.
// Same translation (library) should match nearly word for word. Across
// translations (the model usually quotes NIV, the fetch is WEB) wording
// differs a lot, so the bar is lower. Measured on 40 shipped verses against
// live WEB text (2026-10-22): a quote next to the wrong verse never scored
// above 0.38, while correct NIV quotes mostly scored 0.45 or more.
const LIBRARY_MATCH = 0.85;
const CROSS_TRANSLATION_MATCH = 0.45;
const MIN_QUOTE_WORDS = 4;

const STOPWORDS = new Set((
  'a an and are as at be been but by for from has have he her him his i in ' +
  'into is it its me my of on or our shall she so that the their them they ' +
  'this those to us was we were which who whom will with you your yours ' +
  'thee thou thy thine ye unto o not no nor all also'
).split(' '));

// Spellings that differ between translations but mean the same word.
const SYNONYMS = {
  yahweh: 'lord',
  jehovah: 'lord',
  savior: 'saviour',
  honor: 'honour',
};

function stem(word) {
  return word
    .replace(/'s$/, '')
    .replace(/(ies)$/, 'y')
    .replace(/(ing|eth|est|ed|es|s)$/, '')
    .replace(/(.)\1$/, '$1');
}

function contentWords(text) {
  const words = String(text || '')
    .toLowerCase()
    .replace(/[’‘]/g, "'")
    .match(/[a-z']+/g) || [];
  return words
    .map((w) => w.replace(/^'+|'+$/g, ''))
    .filter((w) => w && !STOPWORDS.has(w))
    .map((w) => SYNONYMS[w] || w)
    .map(stem)
    .filter((w) => w.length > 1);
}

/** Share of the quote's distinct content words found in the reference text. */
function containment(quote, reference) {
  const q = new Set(contentWords(quote));
  if (q.size === 0) return 0;
  const r = new Set(contentWords(reference));
  let hits = 0;
  for (const w of q) if (r.has(w)) hits += 1;
  return hits / q.size;
}

/**
 * bible-api.com returns WEB with "Yahweh" for the divine name and newlines
 * between verses. Readers of an NIV-shaped app expect "the LORD".
 */
function cleanWebText(text) {
  return String(text || '')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/(^|[.!?]\s+|["“‘(]\s*)Yahweh\b/g, '$1The LORD')
    .replace(/\bYahweh\b/g, 'the LORD');
}

/**
 * candidate: { reference, verseText } from the model.
 * deps.library: { "Book C:V": [texts] }
 * deps.fetchVerse(key): resolves { text } for a real reference, null when the
 *   reference does not exist, and throws when the lookup itself failed.
 *
 * Resolves { ok: true, key, text, source } or { ok: false, reason }.
 */
async function verifyVerse(candidate, deps) {
  const ref = parseReference(candidate && candidate.reference);
  if (!ref) return { ok: false, reason: 'bad_reference' };

  const quote = String((candidate && candidate.verseText) || '');
  if (new Set(contentWords(quote)).size < MIN_QUOTE_WORDS) {
    return { ok: false, reason: 'quote_too_short' };
  }

  const shipped = (deps.library && deps.library[ref.key]) || [];
  let best = null;
  for (const text of shipped) {
    const score = containment(quote, text);
    if (score >= LIBRARY_MATCH && (!best || score > best.score)) best = { text, score };
  }
  if (best) return { ok: true, key: ref.key, text: best.text, source: 'library' };

  let fetched;
  try {
    fetched = await deps.fetchVerse(ref.key);
  } catch (err) {
    return { ok: false, reason: 'lookup_failed' };
  }
  if (!fetched || !fetched.text) return { ok: false, reason: 'reference_not_found' };

  const text = cleanWebText(fetched.text);
  if (containment(quote, text) < CROSS_TRANSLATION_MATCH) {
    return { ok: false, reason: 'quote_mismatch' };
  }
  return { ok: true, key: ref.key, text, source: 'web' };
}

/**
 * Default fetchVerse: bible-api.com, World English Bible (public domain).
 * A 404 or { error } means the reference does not exist.
 */
function makeWebFetcher({ fetchImpl = fetch, timeoutMs = 8000 } = {}) {
  return async function fetchVerse(key) {
    const url = `https://bible-api.com/${encodeURIComponent(key)}?translation=web`;
    const resp = await fetchImpl(url, { signal: AbortSignal.timeout(timeoutMs) });
    if (resp.status === 404) return null;
    if (!resp.ok) throw new Error(`bible-api ${resp.status}`);
    const data = await resp.json();
    if (!data || data.error || !Array.isArray(data.verses) || data.verses.length === 0) return null;
    // The API answers a range that runs past the chapter with whatever
    // verses exist. Demand every verse asked for, or the reference is wrong.
    const ref = parseReference(key);
    const wanted = ref.verseEnd - ref.verseStart + 1;
    if (data.verses.length !== wanted) return null;
    return { text: data.text };
  };
}

module.exports = {
  verifyVerse,
  makeWebFetcher,
  containment,
  contentWords,
  cleanWebText,
  LIBRARY_MATCH,
  CROSS_TRANSLATION_MATCH,
};
