/**
 * forYouLib.test.js
 * The building blocks of the weekly For You set: reference parsing, verse
 * verification, the declaration linter, Sunday scheduling, the bundled verse
 * library, and the two model calls (against a fake Anthropic client).
 *
 *   npm run test:foryou
 */

const assert = require('node:assert');
const { test, describe } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');

const { parseReference } = require('../lib/verseRef');
const { verifyVerse, makeWebFetcher, containment, cleanWebText } = require('../lib/verseVerifier');
const { lintDeclaration, isNearDuplicate, overlap } = require('../lib/declarationLint');
const { nextDrop, isValidTimeZone } = require('../lib/forYouSchedule');
const { buildLibrary, loadLibrary } = require('../lib/verseLibrary');
const {
  makeModelDeps, buildWriterPrompt, buildJudgePrompt, callJson, ModelError,
  WRITER_MODEL, JUDGE_MODEL, WRITER_SCHEMA,
} = require('../lib/forYouModels');
const { CATEGORIES } = require('../lib/lifeCategories');

const DECLARATIONS_PATH = path.join(__dirname, '../../SpeakLife/SpeakLife/Preview Content/AffirmationData/declarationsv10.json');

// ─── verseRef ───────────────────────────────────────────────────────────────

describe('parseReference', () => {
  test('parses a single verse and a short range', () => {
    assert.deepStrictEqual(parseReference('John 3:16'),
      { book: 'John', chapter: 3, verseStart: 16, verseEnd: 16, key: 'John 3:16' });
    assert.strictEqual(parseReference('Isaiah 41:10-11').key, 'Isaiah 41:10-11');
  });

  test('canonicalises book spellings', () => {
    assert.strictEqual(parseReference('Psalms 23:1').key, 'Psalm 23:1');
    assert.strictEqual(parseReference('psalm 23:1').key, 'Psalm 23:1');
    assert.strictEqual(parseReference('Song of Songs 2:4').key, 'Song of Solomon 2:4');
    assert.strictEqual(parseReference('II Corinthians 5:17').key, '2 Corinthians 5:17');
    assert.strictEqual(parseReference('1 John 4:4').key, '1 John 4:4');
    assert.strictEqual(parseReference('1John 4:4').key, '1 John 4:4');
    assert.strictEqual(parseReference('First Peter 5:7').key, '1 Peter 5:7');
    assert.strictEqual(parseReference('Revelations 21:4').key, 'Revelation 21:4');
  });

  test('treats an en or em dash in a range as a hyphen', () => {
    assert.strictEqual(parseReference('Romans 8:38–39').key, 'Romans 8:38-39');
    assert.strictEqual(parseReference('Romans 8:38—39').key, 'Romans 8:38-39');
  });

  test('rejects anything that is not one book, chapter and verse', () => {
    for (const bad of [
      'Psalm 23',            // whole chapter
      'John 3:16a',          // part verse
      'Romans 8:28,31',      // scattered verses
      'Jesus',               // the red-letter entries
      'Hezekiah 3:1',        // not a book
      'John 3:17-16',        // backwards
      'John 0:1',
      'Psalm 119:1-20',      // longer than MAX_VERSE_SPAN
      '',
      null,
      42,
    ]) {
      assert.strictEqual(parseReference(bad), null, `expected null for ${JSON.stringify(bad)}`);
    }
  });
});

// ─── verseVerifier ──────────────────────────────────────────────────────────

const NIV_JOHN_3_16 = 'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.';
const WEB_JOHN_3_16 = '\nFor God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.\n\n';
const NIV_PSALM_23_1 = 'The LORD is my shepherd, I lack nothing.';
const WEB_PSALM_23_1 = 'Yahweh is my shepherd:\nI shall lack nothing.\n';

function fetcher(table) {
  const calls = [];
  const fn = async (key) => {
    calls.push(key);
    if (table[key] instanceof Error) throw table[key];
    return table[key] === undefined ? null : { text: table[key] };
  };
  fn.calls = calls;
  return fn;
}

describe('verifyVerse', () => {
  test('uses the shipped library wording when the quote matches it, without fetching', async () => {
    const fetchVerse = fetcher({});
    const result = await verifyVerse(
      { reference: 'Psalms 23:1', verseText: 'The Lord is my shepherd; I lack nothing.' },
      { library: { 'Psalm 23:1': [NIV_PSALM_23_1] }, fetchVerse }
    );
    assert.deepStrictEqual(result, { ok: true, key: 'Psalm 23:1', text: NIV_PSALM_23_1, source: 'library' });
    assert.strictEqual(fetchVerse.calls.length, 0);
  });

  test('picks the closest of several library wordings', async () => {
    const full = 'And if the Spirit of him who raised Jesus from the dead is living in you, he who raised Christ from the dead will also give life to your mortal bodies because of his Spirit who lives in you.';
    const partial = 'And if the Spirit of him who raised Jesus from the dead is living in you, he who raised Christ from the dead will also give life to your mortal bodies.';
    const result = await verifyVerse(
      { reference: 'Romans 8:11', verseText: full },
      { library: { 'Romans 8:11': [partial, full] }, fetchVerse: fetcher({}) }
    );
    assert.strictEqual(result.text, full);
  });

  test('falls back to the public-domain text when the library has no match', async () => {
    const fetchVerse = fetcher({ 'John 3:16': WEB_JOHN_3_16 });
    const result = await verifyVerse(
      { reference: 'John 3:16', verseText: NIV_JOHN_3_16 },
      { library: {}, fetchVerse }
    );
    assert.strictEqual(result.ok, true);
    assert.strictEqual(result.source, 'web');
    assert.strictEqual(result.text, 'For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.');
    assert.deepStrictEqual(fetchVerse.calls, ['John 3:16']);
  });

  test('ships the fetched text, never the model quote', async () => {
    const result = await verifyVerse(
      { reference: 'Psalm 23:1', verseText: NIV_PSALM_23_1 },
      { library: {}, fetchVerse: fetcher({ 'Psalm 23:1': WEB_PSALM_23_1 }) }
    );
    assert.strictEqual(result.ok, true);
    assert.strictEqual(result.text, 'The LORD is my shepherd: I shall lack nothing.');
  });

  test('accepts a correct NIV quote whose WEB wording differs a lot', async () => {
    // Live bible-api.com text, 2026-10-22. Scores about 0.5: this is the case
    // CROSS_TRANSLATION_MATCH was lowered for.
    const web = 'Don’t you be afraid, for I am with you.\nDon’t be dismayed, for I am your God.\nI will strengthen you.\nYes, I will help you.\nYes, I will uphold you with the right hand of my righteousness.\nBehold, all those who are incensed against you will be disappointed and confounded.\nThose who strive with you will be like nothing, and shall perish.\n';
    const result = await verifyVerse(
      { reference: 'Isaiah 41:10-11', verseText: 'So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand. All who rage against you will surely be ashamed and disgraced.' },
      { library: {}, fetchVerse: fetcher({ 'Isaiah 41:10-11': web }) }
    );
    assert.strictEqual(result.ok, true);
    assert.match(result.text, /^Don’t you be afraid/);
  });

  test('rejects a reference that does not exist', async () => {
    const result = await verifyVerse(
      { reference: 'Psalm 23:7', verseText: 'Surely goodness and mercy shall follow me all my days.' },
      { library: {}, fetchVerse: fetcher({}) }
    );
    assert.deepStrictEqual(result, { ok: false, reason: 'reference_not_found' });
  });

  test('rejects a real reference quoted wrongly (the model misremembered)', async () => {
    const result = await verifyVerse(
      { reference: 'John 3:16', verseText: 'I can do all things through Christ who strengthens me today.' },
      { library: {}, fetchVerse: fetcher({ 'John 3:16': WEB_JOHN_3_16 }) }
    );
    assert.deepStrictEqual(result, { ok: false, reason: 'quote_mismatch' });
  });

  test('a library entry for the reference does not rescue a wrong quote', async () => {
    const result = await verifyVerse(
      { reference: 'Psalm 23:1', verseText: 'Be strong and courageous, do not be afraid or terrified.' },
      { library: { 'Psalm 23:1': [NIV_PSALM_23_1] }, fetchVerse: fetcher({ 'Psalm 23:1': WEB_PSALM_23_1 }) }
    );
    assert.deepStrictEqual(result, { ok: false, reason: 'quote_mismatch' });
  });

  test('rejects an unparseable reference and a quote too short to check', async () => {
    const deps = { library: {}, fetchVerse: fetcher({}) };
    assert.deepStrictEqual(await verifyVerse({ reference: 'John 3', verseText: NIV_JOHN_3_16 }, deps),
      { ok: false, reason: 'bad_reference' });
    assert.deepStrictEqual(await verifyVerse({ reference: 'John 11:35', verseText: 'Jesus wept.' }, deps),
      { ok: false, reason: 'quote_too_short' });
    assert.deepStrictEqual(await verifyVerse(null, deps), { ok: false, reason: 'bad_reference' });
  });

  test('treats a failed lookup as unverified, not as verified', async () => {
    const result = await verifyVerse(
      { reference: 'John 3:16', verseText: NIV_JOHN_3_16 },
      { library: {}, fetchVerse: fetcher({ 'John 3:16': new Error('timeout') }) }
    );
    assert.deepStrictEqual(result, { ok: false, reason: 'lookup_failed' });
  });
});

describe('verse text helpers', () => {
  test('containment ignores punctuation, case, stop words and Yahweh/LORD', () => {
    assert.ok(containment(NIV_PSALM_23_1, WEB_PSALM_23_1) >= 0.99);
    assert.ok(containment(NIV_JOHN_3_16, WEB_JOHN_3_16) >= 0.8);
    assert.ok(containment('Be strong and courageous.', WEB_JOHN_3_16) < 0.2);
    assert.strictEqual(containment('', WEB_JOHN_3_16), 0);
  });

  test('cleanWebText replaces Yahweh and collapses whitespace', () => {
    assert.strictEqual(cleanWebText('Yahweh is my shepherd:\nI shall lack nothing.\n'), 'The LORD is my shepherd: I shall lack nothing.');
    assert.strictEqual(cleanWebText('I will trust in Yahweh. Yahweh is good.'), 'I will trust in the LORD. The LORD is good.');
  });
});

describe('makeWebFetcher', () => {
  function fakeFetch(status, body) {
    const calls = [];
    const fn = async (url) => {
      calls.push(url);
      return { status, ok: status >= 200 && status < 300, json: async () => body };
    };
    fn.calls = calls;
    return fn;
  }

  test('requests the WEB translation and returns the text', async () => {
    const fetchImpl = fakeFetch(200, { verses: [{ verse: 16 }], text: WEB_JOHN_3_16 });
    const result = await makeWebFetcher({ fetchImpl })('John 3:16');
    assert.deepStrictEqual(result, { text: WEB_JOHN_3_16 });
    assert.strictEqual(fetchImpl.calls[0], 'https://bible-api.com/John%203%3A16?translation=web');
  });

  test('a 404 or an error body means the verse does not exist', async () => {
    assert.strictEqual(await makeWebFetcher({ fetchImpl: fakeFetch(404, { error: 'not found' }) })('Psalm 23:7'), null);
    assert.strictEqual(await makeWebFetcher({ fetchImpl: fakeFetch(200, { error: 'not found' }) })('Psalm 23:7'), null);
  });

  test('a range that comes back short means part of it does not exist', async () => {
    const fetchImpl = fakeFetch(200, { verses: [{ verse: 35 }, { verse: 36 }], text: 'x' });
    assert.strictEqual(await makeWebFetcher({ fetchImpl })('John 3:35-37'), null);
  });

  test('a server error throws, so it is never cached as missing', async () => {
    await assert.rejects(makeWebFetcher({ fetchImpl: fakeFetch(503, {}) })('John 3:16'), /bible-api 503/);
  });
});

// ─── declarationLint ────────────────────────────────────────────────────────

describe('lintDeclaration', () => {
  test('passes strong, rule-following declarations', () => {
    for (const good of [
      'I have the mind of Christ, and it is clear, sound, and at rest.',
      'My plans are diligent, and diligent plans lead to profit.',
      'I am a new creation in Christ. The old is gone for good.',
      'I bless You, Lord, and Your praise stays on my lips all day.',
      'I hope in the Lord, so I run without growing weary or faint.',
      'You took all my sickness, and strength rises in this body every morning.'.replace(/^You/, 'Jesus'),
    ]) {
      assert.deepStrictEqual(lintDeclaration(good), [], good);
    }
  });

  const cases = [
    ['God\'s banner over me is love—I live under His claim.', 'dash'],
    ['God\'s banner over me is love – I live under His claim.', 'dash'],
    ['Your steps are ordered by God, and He holds your future.', 'second_person'],
    ['I know that you are chosen and loved by God forever.', 'second_person'],
    ['The Lord is faithful, and His mercies are new every morning.', 'not_first_person'],
    ['Maybe I am healed and whole in every part of me.', 'hedge'],
    ['I hope to walk in peace and favor every single day.', 'hedge'],
    ['I will one day fulfill the calling God placed on my life.', 'future_tense'],
    ['I am chosen and loved by God', 'no_ending'],
    ['I am *chosen* and loved by God forever and always.', 'markup'],
    ['I am free.', 'too_short'],
    ['I am rooted and grounded in love and I am filled with all the fullness of God and His goodness surrounds me today.', 'too_long'],
    ['I am loved. I am chosen. I am free in Christ today.', 'too_many_sentences'],
  ];
  for (const [text, rule] of cases) {
    test(`flags ${rule}: ${text.slice(0, 40)}`, () => {
      assert.ok(lintDeclaration(text).includes(rule), `${JSON.stringify(lintDeclaration(text))} should include ${rule}`);
    });
  }

  test('flags empty input', () => {
    assert.deepStrictEqual(lintDeclaration(''), ['empty']);
    assert.deepStrictEqual(lintDeclaration(null), ['empty']);
  });

  // Calibration against content we already ship: the newest, tightest sets
  // should pass almost untouched, or the linter is throwing away good work.
  test('passes nearly all of the business and newSeason reference sets', () => {
    const all = JSON.parse(fs.readFileSync(DECLARATIONS_PATH, 'utf8')).declarations;
    // Jesus-voice entries speak to the reader on purpose (CLAUDE.md rule 1).
    const reference = all.filter((d) => ['business', 'newSeason'].includes(d.category) && d.book !== 'Jesus');
    const failing = reference.filter((d) => lintDeclaration(d.text).length > 0);
    assert.ok(reference.length >= 40);
    assert.ok(failing.length / reference.length < 0.05,
      `${failing.length}/${reference.length} fail: ${failing.slice(0, 3).map((d) => d.text).join(' | ')}`);
  });
});

describe('near duplicates', () => {
  test('catches identical and lightly reworded lines', () => {
    const saved = ['I am healed and whole, and strength rises in my body.'];
    assert.ok(isNearDuplicate('I am healed and whole, and strength rises in my body.', saved));
    assert.ok(isNearDuplicate('I am HEALED and whole and strength rises in my body!', saved));
    assert.ok(isNearDuplicate('I am healed and whole, strength rises in my body today.', saved));
  });

  test('lets genuinely different lines through', () => {
    const saved = ['I am healed and whole, and strength rises in my body.'];
    assert.ok(!isNearDuplicate('God supplies every need I have from His riches in glory.', saved));
    assert.ok(!isNearDuplicate('By His wounds this body is healed, and I walk in health.', saved));
    assert.strictEqual(isNearDuplicate('anything', []), false);
  });

  test('overlap is symmetric and bounded', () => {
    const a = 'I walk in peace that guards my heart';
    const b = 'Peace guards my heart as I walk';
    assert.strictEqual(overlap(a, b), overlap(b, a));
    assert.ok(overlap(a, b) > 0 && overlap(a, b) <= 1);
    assert.strictEqual(overlap('', b), 0);
  });
});

// ─── forYouSchedule ─────────────────────────────────────────────────────────

describe('nextDrop', () => {
  test('is the coming Sunday at 6pm in the user\'s zone', () => {
    // Thursday 22 Oct 2026, noon UTC
    const drop = nextDrop(new Date('2026-10-22T12:00:00Z'), 'America/Los_Angeles');
    assert.strictEqual(drop.weekId, '2026-10-25');
    assert.strictEqual(drop.at.toISOString(), '2026-10-26T01:00:00.000Z'); // 6pm PDT
  });

  test('is later the same Sunday when it is Sunday before 6pm', () => {
    // UK clocks go back at 2am that same Sunday, so 6pm is GMT.
    const drop = nextDrop(new Date('2026-10-25T15:00:00Z'), 'Europe/London');
    assert.strictEqual(drop.weekId, '2026-10-25');
    assert.strictEqual(drop.at.toISOString(), '2026-10-25T18:00:00.000Z');
  });

  test('is next week once Sunday 6pm has passed, and never "now"', () => {
    const exactly = new Date('2026-10-25T22:00:00Z'); // 6pm EDT on the dot
    const drop = nextDrop(exactly, 'America/New_York');
    assert.strictEqual(drop.weekId, '2026-11-01');
    assert.ok(drop.at > exactly);
  });

  test('follows daylight saving: 6pm stays 6pm across the change', () => {
    // US clocks fall back on Sunday 1 Nov 2026, so that 6pm is EST (UTC-5).
    const before = nextDrop(new Date('2026-10-22T12:00:00Z'), 'America/New_York');
    const after = nextDrop(new Date('2026-10-26T12:00:00Z'), 'America/New_York');
    assert.strictEqual(before.at.toISOString(), '2026-10-25T22:00:00.000Z');
    assert.strictEqual(after.at.toISOString(), '2026-11-01T23:00:00.000Z');
    // Spring forward: Sunday 8 Mar 2026 is EDT (UTC-4) by 6pm.
    const spring = nextDrop(new Date('2026-03-05T12:00:00Z'), 'America/New_York');
    assert.strictEqual(spring.at.toISOString(), '2026-03-08T22:00:00.000Z');
  });

  test('handles zones ahead of UTC and a month rollover', () => {
    const drop = nextDrop(new Date('2026-12-28T00:00:00Z'), 'Asia/Tokyo'); // Mon 9am JST
    assert.strictEqual(drop.weekId, '2027-01-03');
    assert.strictEqual(drop.at.toISOString(), '2027-01-03T09:00:00.000Z');
  });

  test('handles half-hour zones', () => {
    const drop = nextDrop(new Date('2026-10-22T12:00:00Z'), 'Asia/Kolkata');
    assert.strictEqual(drop.at.toISOString(), '2026-10-25T12:30:00.000Z');
  });

  test('falls back to New York for an unknown zone', () => {
    assert.deepStrictEqual(
      nextDrop(new Date('2026-10-22T12:00:00Z'), 'Mars/Olympus'),
      nextDrop(new Date('2026-10-22T12:00:00Z'), 'America/New_York')
    );
    assert.strictEqual(isValidTimeZone('Mars/Olympus'), false);
    assert.strictEqual(isValidTimeZone(''), false);
    assert.strictEqual(isValidTimeZone(undefined), false);
    assert.strictEqual(isValidTimeZone('Europe/Paris'), true);
  });

  test('every drop over a year is a Sunday at 18:00 local, a week apart', () => {
    for (const tz of ['America/New_York', 'Europe/London', 'Australia/Sydney', 'America/Sao_Paulo']) {
      let cursor = new Date('2026-01-01T00:00:00Z');
      let previous = null;
      for (let i = 0; i < 53; i += 1) {
        const drop = nextDrop(cursor, tz);
        const local = new Intl.DateTimeFormat('en-US', { timeZone: tz, weekday: 'short', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(drop.at);
        assert.strictEqual(local, 'Sun 18:00', `${tz} ${drop.at.toISOString()}`);
        if (previous) {
          const gapHours = (drop.at - previous.at) / 3600000;
          assert.ok([167, 168, 169].includes(gapHours), `${tz} gap ${gapHours}`);
        }
        previous = drop;
        cursor = drop.at;
      }
    }
  });
});

// ─── verseLibrary ───────────────────────────────────────────────────────────

describe('verse library', () => {
  test('groups texts by canonical reference and skips unparseable ones', () => {
    const lib = buildLibrary([
      { book: 'Psalms 23:1', bibleVerseText: 'A' },
      { book: 'Psalm 23:1', bibleVerseText: 'B' },
      { book: 'Psalm 23:1', bibleVerseText: 'A' },
      { book: 'Jesus', bibleVerseText: 'C' },
      { book: 'John 3:16a', bibleVerseText: 'D' },
      { book: 'John 3:16', bibleVerseText: '' },
    ]);
    assert.deepStrictEqual(lib, { 'Psalm 23:1': ['A', 'B'] });
  });

  test('the bundled file matches declarationsv10.json (re-run scripts/buildVerseLibrary.js)', () => {
    const declarations = JSON.parse(fs.readFileSync(DECLARATIONS_PATH, 'utf8')).declarations;
    assert.deepStrictEqual(loadLibrary(), buildLibrary(declarations));
    assert.ok(Object.keys(loadLibrary()).length > 1500);
  });
});

// ─── forYouModels ───────────────────────────────────────────────────────────

function fakeClient(responses) {
  const requests = [];
  return {
    requests,
    messages: {
      async create(body, options) {
        requests.push({ body, options });
        const next = responses.shift();
        if (next instanceof Error) throw next;
        return next;
      },
    },
  };
}

function reply(obj, extra = {}) {
  return {
    stop_reason: 'end_turn',
    content: [{ type: 'text', text: JSON.stringify(obj) }],
    usage: { input_tokens: 100, output_tokens: 50, cache_read_input_tokens: 900 },
    ...extra,
  };
}

describe('model calls', () => {
  test('write uses Sonnet 5.5 with the schema, caching and refusal fallback', async () => {
    const client = fakeClient([reply({ title: 'Peace', declarations: [] })]);
    const deps = makeModelDeps(client);
    const out = await deps.write({ favorites: [{ text: 'I am at peace.', book: 'John 14:27', category: 'rest' }], avoid: [], count: 14 });
    assert.deepStrictEqual(out, { title: 'Peace', declarations: [] });

    const { body, options } = client.requests[0];
    assert.strictEqual(body.model, WRITER_MODEL);
    assert.strictEqual(WRITER_MODEL, 'claude-sonnet-5-5');
    assert.strictEqual(body.output_config.format.type, 'json_schema');
    assert.deepStrictEqual(body.output_config.format.schema, WRITER_SCHEMA);
    assert.strictEqual(body.system[0].cache_control.type, 'ephemeral');
    assert.strictEqual(body.fallbacks, 'default');
    assert.strictEqual(options.headers['anthropic-beta'], 'server-side-fallback-2026-07-01');
    assert.match(body.messages[0].content, /Write 14 new declarations/);
    assert.deepStrictEqual(deps.usage, { inputTokens: 1000, outputTokens: 50, calls: 1 });
  });

  test('judge uses Haiku 5.5 at low effort with no fallback, and returns verdicts', async () => {
    const verdicts = [{ id: '0', supported: true, reason: 'ok' }];
    const client = fakeClient([reply({ verdicts })]);
    const out = await makeModelDeps(client).judge([{ id: '0', text: 't', reference: 'John 3:16', verseText: 'v' }]);
    assert.deepStrictEqual(out, verdicts);
    const { body } = client.requests[0];
    assert.strictEqual(body.model, JUDGE_MODEL);
    assert.strictEqual(JUDGE_MODEL, 'claude-haiku-5-5');
    assert.strictEqual(body.output_config.effort, 'low');
    assert.strictEqual(body.fallbacks, undefined);
  });

  test('a refusal, truncation or bad JSON is an error, never an empty result', async () => {
    for (const bad of [
      reply({}, { stop_reason: 'refusal', stop_details: { category: 'general_harms' } }),
      reply({}, { stop_reason: 'max_tokens' }),
      { stop_reason: 'end_turn', content: [{ type: 'text', text: '{not json' }] },
    ]) {
      await assert.rejects(
        callJson(fakeClient([bad]), { model: 'm', system: 's', user: 'u', schema: {}, effort: 'low' }),
        ModelError
      );
    }
  });

  test('the writer schema only allows real category keys', () => {
    const enumKeys = WRITER_SCHEMA.properties.declarations.items.properties.category.enum;
    assert.deepStrictEqual(enumKeys, Object.keys(CATEGORIES));
  });

  test('the writer prompt lists favorites with verse and theme, and the avoid list', () => {
    const prompt = buildWriterPrompt({
      favorites: [
        { text: 'I have the mind of Christ.', book: '1 Corinthians 2:16', category: 'anxiety' },
        { text: 'My God supplies all I need.', book: '', category: 'not-a-category' },
      ],
      avoid: ['Old line one.', '', 'Old line two.'],
      count: 5,
    });
    assert.match(prompt, /- I have the mind of Christ\. \(1 Corinthians 2:16\) \[anxiety\]/);
    assert.match(prompt, /- My God supplies all I need\.\n/);
    assert.match(prompt, /Write 5 new declarations/);
    assert.match(prompt, /- Old line one\.\n- Old line two\./);
  });

  test('the writer prompt caps what one favorite can inject', () => {
    const prompt = buildWriterPrompt({ favorites: [{ text: 'x'.repeat(5000) }], avoid: [], count: 1 });
    assert.ok(prompt.length < 600);
  });

  test('the judge prompt shows every item with its id', () => {
    const prompt = buildJudgePrompt([
      { id: '0', text: 'A.', reference: 'John 3:16', verseText: 'V0' },
      { id: '1', text: 'B.', reference: 'Psalm 23:1', verseText: 'V1' },
    ]);
    assert.match(prompt, /id 0\nDeclaration: A\.\nVerse \(John 3:16\): V0/);
    assert.match(prompt, /id 1\nDeclaration: B\.\nVerse \(Psalm 23:1\): V1/);
  });
});

describe('categories', () => {
  // A set's declarations open in the app under these keys, so each one has
  // to be a real DeclarationCategory case or it silently becomes faith.
  test('every server category is a DeclarationCategory case in the app', () => {
    const swift = fs.readFileSync(path.join(__dirname, '../../Packages/SpeakLifeKit/Sources/SpeakLifeCore/DailyDeclaration.swift'), 'utf8');
    const body = swift.slice(swift.indexOf('public enum DeclarationCategory'));
    const cases = new Set();
    for (const line of body.split('\n')) {
      const m = line.match(/^\s*case\s+([A-Za-z0-9_,\s]+?)\s*(\/\/.*)?$/);
      if (m) m[1].split(',').forEach((c) => cases.add(c.trim()));
    }
    const missing = Object.keys(CATEGORIES).filter((k) => !cases.has(k));
    assert.deepStrictEqual(missing, []);
  });
});
