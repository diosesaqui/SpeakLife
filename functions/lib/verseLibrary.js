/**
 * The verse texts SpeakLife already ships, keyed by canonical reference.
 * Built from declarationsv10.json by scripts/buildVerseLibrary.js.
 */

const { parseReference } = require('./verseRef');

/**
 * declarations: [{ book, bibleVerseText }] → { "Psalm 23:1": ["text", ...] }
 * Entries whose reference cannot be parsed ("Jesus", "John 3:16a") are left
 * out, since the model is never allowed to cite them that way either.
 */
function buildLibrary(declarations) {
  const library = {};
  for (const d of declarations) {
    const ref = parseReference(d.book);
    const text = typeof d.bibleVerseText === 'string' ? d.bibleVerseText.trim() : '';
    if (!ref || !text) continue;
    const texts = library[ref.key] || (library[ref.key] = []);
    if (!texts.includes(text)) texts.push(text);
  }
  // Sorted so the generated file diffs cleanly.
  return Object.fromEntries(Object.keys(library).sort().map((k) => [k, library[k]]));
}

let cached = null;
function loadLibrary() {
  if (!cached) cached = require('../data/verseLibrary.json');
  return cached;
}

module.exports = { buildLibrary, loadLibrary };
