/**
 * Bible reference parsing for the weekly For You set.
 *
 * The model chooses its own verse for each declaration. Before that verse can
 * ship, its reference has to be something we can look up: one book, one
 * chapter, one verse or a short run of verses. "Psalm 23", "John 3:16a" and
 * "Romans 8:28,31" are rejected rather than guessed at.
 */

// Canonical book names, in canon order, with the spellings people (and the
// model) actually use. Keys of ALIASES are lowercased with spaces removed.
const BOOKS = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua', 'Judges',
  'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings', '1 Chronicles',
  '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalm', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations',
  'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
  'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans', '1 Corinthians',
  '2 Corinthians', 'Galatians', 'Ephesians', 'Philippians', 'Colossians',
  '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus',
  'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John',
  '3 John', 'Jude', 'Revelation',
];

const ALIASES = {};
for (const book of BOOKS) ALIASES[squash(book)] = book;
Object.assign(ALIASES, {
  psalms: 'Psalm',
  songofsongs: 'Song of Solomon',
  song: 'Song of Solomon',
  songs: 'Song of Solomon',
  revelations: 'Revelation',
});

function squash(s) {
  return String(s).toLowerCase().replace(/[\s.]/g, '');
}

// "I John", "II Corinthians", "First Peter" → "1 John", "2 Corinthians", "1 Peter"
function normalizeOrdinal(book) {
  return book
    .replace(/^(iii|third)\s+/i, '3 ')
    .replace(/^(ii|second)\s+/i, '2 ')
    .replace(/^(i|first)\s+/i, '1 ');
}

const REF_PATTERN = /^\s*((?:[1-3]|i{1,3}|first|second|third)?\s*[A-Za-z][A-Za-z .]*?)\s+(\d{1,3}):(\d{1,3})(?:\s*-\s*(\d{1,3}))?\s*$/i;

// The longest run of verses we accept for one declaration. Longer passages
// stop being "the verse it stands on".
const MAX_VERSE_SPAN = 4;

/**
 * Parses "Book Chapter:Verse" or "Book Chapter:Verse-Verse".
 * Returns { book, chapter, verseStart, verseEnd, key } or null.
 * `key` is the canonical spelling ("Psalm 23:1-2") used for lookups.
 */
function parseReference(raw) {
  if (typeof raw !== 'string') return null;
  const match = raw.replace(/[–—]/g, '-').match(REF_PATTERN);
  if (!match) return null;

  const book = ALIASES[squash(normalizeOrdinal(match[1].trim()))];
  if (!book) return null;

  const chapter = Number(match[2]);
  const verseStart = Number(match[3]);
  const verseEnd = match[4] ? Number(match[4]) : verseStart;
  if (chapter < 1 || verseStart < 1 || verseEnd < verseStart) return null;
  if (verseEnd - verseStart + 1 > MAX_VERSE_SPAN) return null;

  const key = verseEnd === verseStart
    ? `${book} ${chapter}:${verseStart}`
    : `${book} ${chapter}:${verseStart}-${verseEnd}`;
  return { book, chapter, verseStart, verseEnd, key };
}

module.exports = { parseReference, BOOKS, MAX_VERSE_SPAN };
