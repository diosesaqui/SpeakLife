#!/usr/bin/env node
/**
 * Builds functions/data/verseLibrary.json from the app's declarationsv10.json.
 *
 * The library is every verse text the declarations already quote, keyed by
 * canonical reference. The weekly For You verifier prefers these texts over a
 * fetched one, because they are the wording SpeakLife already ships.
 *
 *   node functions/scripts/buildVerseLibrary.js
 *
 * Re-run after editing declarationsv10.json. A test fails if it drifts.
 */

const fs = require('fs');
const path = require('path');
const { buildLibrary } = require('../lib/verseLibrary');

const SOURCE = path.join(__dirname, '../../SpeakLife/SpeakLife/Preview Content/AffirmationData/declarationsv10.json');
const OUT = path.join(__dirname, '../data/verseLibrary.json');

const declarations = JSON.parse(fs.readFileSync(SOURCE, 'utf8')).declarations;
const library = buildLibrary(declarations);
fs.writeFileSync(OUT, JSON.stringify(library) + '\n');
console.log(`Wrote ${Object.keys(library).length} references to ${path.relative(process.cwd(), OUT)}`);
