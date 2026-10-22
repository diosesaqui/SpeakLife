#!/usr/bin/env node
/**
 * Writes one real weekly For You set end to end: the real writer and judge
 * models, the real verse library and bible-api.com. Nothing is stored and no
 * push is sent. Use it to check prompt quality before turning the flag on.
 *
 *   ANTHROPIC_API_KEY=... node functions/scripts/forYouSmoke.js
 *
 * Costs a few cents per run.
 */

const Anthropic = require('@anthropic-ai/sdk');
const { generateWeeklySet } = require('../lib/forYouGenerator');
const { makeModelDeps } = require('../lib/forYouModels');
const { makeWebFetcher } = require('../lib/verseVerifier');
const { loadLibrary } = require('../lib/verseLibrary');

const FAVORITES = [
  { text: 'I have the mind of Christ, and it is clear, sound, and at rest.', book: '1 Corinthians 2:16', category: 'anxiety' },
  { text: 'My God supplies every need I have according to His riches in glory.', book: 'Philippians 4:19', category: 'wealth' },
  { text: 'By His wounds I am healed, and strength rises in this body every morning.', book: 'Isaiah 53:5', category: 'health' },
  { text: 'God has not given me a spirit of fear, but of power, love, and a sound mind.', book: '2 Timothy 1:7', category: 'fear' },
];

(async () => {
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('Set ANTHROPIC_API_KEY first.');
    process.exit(1);
  }
  const models = makeModelDeps(new Anthropic());
  const fetchVerse = makeWebFetcher();
  const started = Date.now();
  try {
    const set = await generateWeeklySet({
      favorites: FAVORITES,
      deps: {
        write: models.write,
        judge: models.judge,
        library: loadLibrary(),
        fetchVerse: async (key) => {
          const result = await fetchVerse(key);
          console.log(`  fetched ${key}: ${result ? 'found' : 'not found'}`);
          return result;
        },
      },
    });
    console.log(`\n${set.title}\n`);
    for (const d of set.declarations) {
      console.log(`• ${d.text}\n    ${d.book} [${d.category}]: ${d.bibleVerseText}\n`);
    }
    console.log('stats', JSON.stringify(set.stats));
  } catch (err) {
    console.error('Failed:', err.message, err.stats ? JSON.stringify(err.stats) : '');
    process.exitCode = 1;
  } finally {
    console.log('usage', JSON.stringify(models.usage), `${((Date.now() - started) / 1000).toFixed(1)}s`);
  }
})();
