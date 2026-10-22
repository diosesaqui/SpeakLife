/**
 * The mechanical half of CLAUDE.md's declaration rules, for model-written
 * declarations. The prompt asks for all of them; this makes sure a line that
 * ignored one never reaches a user. Rules that need judgment (does the verse
 * promise this, does it call higher) are the judge's job, not this file's.
 */

const MIN_WORDS = 6;
// Rule 13 targets 10 to 18. A little headroom so a strong 20-word line is
// not thrown away over a count.
const MAX_WORDS = 22;
const MAX_SENTENCES = 2;

const RULES = [
  // Rule 7
  { id: 'dash', test: (t) => /[—–]/.test(t) || /\s-\s/.test(t) },
  // Rule 1: spoken by the user over themselves, never at them. A capital
  // "You" inside a sentence is the speaker talking to God ("I bless You,
  // Jesus"), which is allowed; lowercase, or opening a sentence, it is the
  // reader being addressed.
  {
    id: 'second_person',
    test: (t) => /\b(you|your|yours|yourself|yourselves)\b/.test(t)
      || /(^|[.!?]\s+)(You|Your|Yours)\b/.test(t),
  },
  { id: 'not_first_person', test: (t) => !/\bI\b/.test(t) && !/\b(me|my|mine|myself)\b/i.test(t) },
  // Rule 6. "I hope in the Lord" and "I think on what is true" are Scripture,
  // so only the hedging forms of hope and think count.
  { id: 'hedge', test: (t) => /\b(maybe|perhaps|hopefully|i wish|i try|try to|someday|i want to|i hope (to|that|so|it|i)|i think (that|so|it|i))\b/i.test(t) },
  // Rule 2: future wishes, not present possession.
  { id: 'future_tense', test: (t) => /\b(will one day|will someday|one day i|going to be)\b/i.test(t) },
  { id: 'no_ending', test: (t) => !/[.!]$/.test(t) },
  { id: 'markup', test: (t) => /[*_#`"“”]/.test(t) },
];

function wordCount(text) {
  return (String(text).match(/[A-Za-z0-9’']+/g) || []).length;
}

function sentenceCount(text) {
  return (String(text).match(/[.!?]+(\s|$)/g) || []).length;
}

/** Returns the ids of every rule the text breaks. Empty means it passes. */
function lintDeclaration(raw) {
  const text = String(raw || '').trim();
  if (!text) return ['empty'];
  const failures = RULES.filter((r) => r.test(text)).map((r) => r.id);
  const words = wordCount(text);
  if (words < MIN_WORDS) failures.push('too_short');
  if (words > MAX_WORDS) failures.push('too_long');
  if (sentenceCount(text) > MAX_SENTENCES) failures.push('too_many_sentences');
  return failures;
}

// ─── Near-duplicates (rule 4) ──────────────────────────────────────────────

function normalize(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/[’‘]/g, "'")
    .replace(/[^a-z' ]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const FILLER = new Set('a an and the of to in is am are my me i his he him god s'.split(' '));

function keyWords(text) {
  return new Set(normalize(text).split(' ').filter((w) => w && !FILLER.has(w)));
}

/** Jaccard overlap of meaningful words. 1 is identical, 0 shares nothing. */
function overlap(a, b) {
  const A = keyWords(a);
  const B = keyWords(b);
  if (A.size === 0 || B.size === 0) return 0;
  let shared = 0;
  for (const w of A) if (B.has(w)) shared += 1;
  return shared / (A.size + B.size - shared);
}

// Two lines sharing this much of their meaningful words are the same line.
const NEAR_DUPLICATE = 0.6;

function isNearDuplicate(text, others) {
  const n = normalize(text);
  return others.some((o) => normalize(o) === n || overlap(text, o) >= NEAR_DUPLICATE);
}

module.exports = {
  lintDeclaration,
  isNearDuplicate,
  overlap,
  wordCount,
  MIN_WORDS,
  MAX_WORDS,
  NEAR_DUPLICATE,
};
