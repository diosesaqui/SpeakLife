/**
 * forYouGenerator.test.js
 * The pipeline that turns a writer's candidates into a shippable set: every
 * gate, the top-up round, and the point at which it refuses to ship.
 * Both models and the verse lookup are fakes.
 *
 *   npm run test:foryou
 */

const assert = require('node:assert');
const { test, describe } = require('node:test');

const {
  generateWeeklySet, pickFavorites, NotEnoughDeclarationsError,
  SET_SIZE, MIN_TO_SHIP, FIRST_ROUND,
} = require('../lib/forYouGenerator');

// Twenty real, distinct verses with library wording, so verification passes
// without the network unless a test wants otherwise.
const VERSES = [
  ['Philippians 4:19', 'And my God will meet all your needs according to the riches of his glory in Christ Jesus.'],
  ['Isaiah 26:3', 'You will keep in perfect peace those whose minds are steadfast, because they trust in you.'],
  ['2 Timothy 1:7', 'For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.'],
  ['Isaiah 53:5', 'But he was pierced for our transgressions, he was crushed for our iniquities; the punishment that brought us peace was on him, and by his wounds we are healed.'],
  ['Psalm 23:1', 'The LORD is my shepherd, I lack nothing.'],
  ['Joshua 1:9', 'Have I not commanded you? Be strong and courageous. Do not be afraid; do not be discouraged, for the LORD your God will be with you wherever you go.'],
  ['Romans 8:37', 'No, in all these things we are more than conquerors through him who loved us.'],
  ['Proverbs 3:6', 'In all your ways submit to him, and he will make your paths straight.'],
  ['Psalm 91:11', 'For he will command his angels concerning you to guard you in all your ways.'],
  ['John 14:27', 'Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid.'],
  ['Deuteronomy 28:12', 'The LORD will open the heavens, the storehouse of his bounty, to send rain on your land in season and to bless all the work of your hands.'],
  ['Psalm 103:3', 'Who forgives all your sins and heals all your diseases.'],
  ['Isaiah 40:31', 'But those who hope in the LORD will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.'],
  ['Jeremiah 29:11', 'For I know the plans I have for you, declares the LORD, plans to prosper you and not to harm you, plans to give you hope and a future.'],
  ['Psalm 121:7', 'The LORD will keep you from all harm, he will watch over your life.'],
  ['Romans 8:1', 'Therefore, there is now no condemnation for those who are in Christ Jesus.'],
  ['Galatians 5:1', 'It is for freedom that Christ has set us free. Stand firm, then, and do not let yourselves be burdened again by a yoke of slavery.'],
  ['Psalm 34:4', 'I sought the LORD, and he answered me; he delivered me from all my fears.'],
  ['Nehemiah 8:10', 'Do not grieve, for the joy of the LORD is your strength.'],
  ['Hebrews 13:5', 'Never will I leave you; never will I forsake you.'],
];
const LIBRARY = Object.fromEntries(VERSES.map(([k, v]) => [k, [v]]));

// Distinct, lint-clean lines. Each uses different key words so none is a
// near-duplicate of another.
const LINES = [
  'My God supplies every need I have from His riches in glory.',
  'My mind stays fixed on God, and His perfect peace guards it.',
  'I carry power, love, and a sound mind from the Spirit of God.',
  'By His wounds this body is healed, and strength rises in me.',
  'The Lord shepherds my life, and I lack no good thing today.',
  'I am strong and courageous because my God walks beside me.',
  'I am more than a conqueror through Christ who loves me.',
  'I trust Him in every decision, and He makes my road straight.',
  'Angels guard my coming and going, wherever my feet step.',
  'Jesus hands me His own peace, and my heart stands untroubled.',
  'Heaven opens over my work, and blessing pours on everything I build.',
  'He forgives every sin I carry and heals every disease in my body.',
  'I hope in the Lord, so I soar, run, and never grow faint.',
  'God holds a hopeful future for me, and His plans prosper me.',
  'The Lord keeps me from harm and watches over my whole life.',
  'No condemnation touches me, because I stand in Christ Jesus.',
  'Christ set me free, and I stand firm in that freedom today.',
  'I sought the Lord, and He delivered me from every fear.',
  'The joy of the Lord is my strength this very morning.',
  'God never leaves me and never forsakes me, not for one moment.',
];

function candidate(i, overrides = {}) {
  return {
    text: LINES[i],
    reference: VERSES[i][0],
    verseText: VERSES[i][1],
    category: 'faith',
    ...overrides,
  };
}

const FAVORITES = [
  { text: 'I have the mind of Christ, sound and at rest.', book: '1 Corinthians 2:16', category: 'anxiety' },
  { text: 'God is my provider, and I lack nothing.', book: 'Psalm 23:1', category: 'wealth' },
  { text: 'I am healed and whole in every part.', book: '1 Peter 2:24', category: 'health' },
];

/**
 * Fake deps. `rounds` is what write() returns on each call. judgeFn decides
 * each verdict; by default everything passes.
 */
function makeDeps({ rounds, judgeFn = () => true, fetchVerse } = {}) {
  const writeCalls = [];
  const judgeCalls = [];
  return {
    writeCalls,
    judgeCalls,
    deps: {
      library: LIBRARY,
      fetchVerse: fetchVerse || (async () => { throw new Error('network should not be needed'); }),
      async write(request) {
        writeCalls.push(request);
        const next = rounds.shift();
        if (next instanceof Error) throw next;
        return next || { title: '', declarations: [] };
      },
      async judge(items) {
        judgeCalls.push(items);
        return items.map((it) => ({ id: it.id, supported: judgeFn(it), reason: 'r' }));
      },
    },
  };
}

describe('generateWeeklySet', () => {
  test('ships ten verified declarations in the declarationsv10 shape', async () => {
    const { deps, writeCalls, judgeCalls } = makeDeps({
      rounds: [{ title: 'Peace and Provision', declarations: Array.from({ length: 14 }, (_, i) => candidate(i, { category: 'rest' })) }],
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, deps });

    assert.strictEqual(set.title, 'Peace and Provision');
    assert.strictEqual(set.declarations.length, SET_SIZE);
    assert.deepStrictEqual(set.declarations[0], {
      text: LINES[0],
      bibleVerseText: VERSES[0][1],
      book: 'Philippians 4:19',
      category: 'rest',
    });
    assert.strictEqual(writeCalls.length, 1, 'no top-up needed');
    assert.strictEqual(writeCalls[0].count, FIRST_ROUND);
    assert.strictEqual(judgeCalls.length, 1);
    assert.deepStrictEqual(set.stats, { generated: 14, accepted: 10, rejected: {} });
  });

  test('the verse text that ships is the verified one, not the model quote', async () => {
    const sloppy = candidate(0, { verseText: 'And my God will meet ALL your needs according to the riches of his glory in Christ Jesus!!' });
    const { deps } = makeDeps({
      rounds: [{ title: 't', declarations: [sloppy, ...Array.from({ length: 13 }, (_, i) => candidate(i + 1))] }],
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, deps });
    assert.strictEqual(set.declarations[0].bibleVerseText, VERSES[0][1]);
  });

  test('drops lint failures, duplicates, bad verses and judge rejections, and counts why', async () => {
    const declarations = [
      candidate(0),
      candidate(1, { text: 'Your mind stays fixed on God, and His peace guards it.' }),     // lint: second person
      candidate(2, { text: LINES[0] }),                                                       // duplicate of 0
      candidate(3, { text: FAVORITES[0].text }),                                              // copy of a favorite
      candidate(4, { reference: 'Psalm 23' }),                                                // bad reference
      candidate(5, { reference: 'Philippians 4:19', verseText: VERSES[0][1] }),               // verse already used
      candidate(6, { verseText: 'Something the verse never said about money and houses.' }),  // quote mismatch
      candidate(7),
      candidate(8),                                                                           // judge says no
      ...Array.from({ length: 5 }, (_, i) => candidate(i + 9)),
    ];
    const { deps } = makeDeps({
      rounds: [{ title: 't', declarations }, { title: '', declarations: [candidate(14), candidate(15), candidate(16), candidate(17)] }],
      judgeFn: (it) => it.text !== LINES[8],
      // The real verse exists, so the mismatched quote is what fails.
      fetchVerse: async (key) => (LIBRARY[key] ? { text: LIBRARY[key][0] } : null),
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, deps });
    assert.deepStrictEqual(set.stats.rejected, {
      'lint:second_person': 1,
      duplicate: 2,
      'verse:bad_reference': 1,
      'verse:repeated': 1,
      'verse:quote_mismatch': 1,
      judge: 1,
    });
    const texts = set.declarations.map((d) => d.text);
    assert.ok(!texts.includes(LINES[8]));
    assert.strictEqual(new Set(set.declarations.map((d) => d.book)).size, set.declarations.length, 'every verse unique');
  });

  test('tops up when the first round comes back short, asking for the gap plus spare', async () => {
    const { deps, writeCalls } = makeDeps({
      rounds: [
        { title: 'First', declarations: Array.from({ length: 6 }, (_, i) => candidate(i)) },
        { title: 'Second', declarations: Array.from({ length: 8 }, (_, i) => candidate(i + 6)) },
      ],
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, avoidTexts: ['Last week line.'], deps });
    assert.strictEqual(set.declarations.length, 10);
    assert.strictEqual(set.title, 'First', 'the first round names the set');
    assert.strictEqual(writeCalls.length, 2);
    assert.strictEqual(writeCalls[1].count, 10 - 6 + 4);
    // The second round is told about everything already tried.
    for (const t of [...LINES.slice(0, 6), 'Last week line.', FAVORITES[0].text]) {
      assert.ok(writeCalls[1].avoid.includes(t), `avoid should include ${t}`);
    }
  });

  test('never ships more than ten, even when the top-up over-delivers', async () => {
    const { deps } = makeDeps({
      rounds: [
        { title: 't', declarations: Array.from({ length: 9 }, (_, i) => candidate(i)) },
        { title: '', declarations: Array.from({ length: 8 }, (_, i) => candidate(i + 9)) },
      ],
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, deps });
    assert.strictEqual(set.declarations.length, 10);
  });

  test('ships a short set of at least seven rather than nothing', async () => {
    const { deps } = makeDeps({
      rounds: [{ title: 't', declarations: Array.from({ length: MIN_TO_SHIP }, (_, i) => candidate(i)) }, { title: '', declarations: [] }],
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, deps });
    assert.strictEqual(set.declarations.length, MIN_TO_SHIP);
  });

  test('refuses to ship fewer than seven, with the stats attached', async () => {
    const { deps } = makeDeps({
      rounds: [{ title: 't', declarations: Array.from({ length: 14 }, (_, i) => candidate(i)) }, { title: '', declarations: [] }],
      judgeFn: (it) => Number(it.id) < 3,
    });
    await assert.rejects(generateWeeklySet({ favorites: FAVORITES, deps }), (err) => {
      assert.ok(err instanceof NotEnoughDeclarationsError);
      assert.strictEqual(err.stats.accepted, 3);
      assert.ok(err.stats.rejected.judge > 0);
      return true;
    });
  });

  test('the judge fails closed: missing or malformed verdicts reject the line', async () => {
    const { deps } = makeDeps({ rounds: [{ title: 't', declarations: Array.from({ length: 14 }, (_, i) => candidate(i)) }] });
    deps.judge = async (items) => [
      ...items.slice(0, 3).map((it) => ({ id: it.id, supported: true })),
      { id: items[3].id, supported: 'yes' },
    ];
    await assert.rejects(generateWeeklySet({ favorites: FAVORITES, deps }), NotEnoughDeclarationsError);

    const again = makeDeps({ rounds: [{ title: 't', declarations: Array.from({ length: 14 }, (_, i) => candidate(i)) }] });
    again.deps.judge = async () => null;
    await assert.rejects(generateWeeklySet({ favorites: FAVORITES, deps: again.deps }), NotEnoughDeclarationsError);
  });

  test('an unknown category becomes faith', async () => {
    const { deps } = makeDeps({
      rounds: [{ title: 't', declarations: Array.from({ length: 10 }, (_, i) => candidate(i, { category: i === 0 ? 'nonsense' : 'health' })) }],
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, deps });
    assert.strictEqual(set.declarations[0].category, 'faith');
    assert.strictEqual(set.declarations[1].category, 'health');
  });

  test('a writer error propagates, so the caller can retry', async () => {
    const { deps } = makeDeps({ rounds: [new Error('overloaded')] });
    await assert.rejects(generateWeeklySet({ favorites: FAVORITES, deps }), /overloaded/);
  });

  test('a malformed writer response is treated as no candidates', async () => {
    const { deps } = makeDeps({ rounds: [{ title: 't', declarations: 'oops' }, { title: '', declarations: null }] });
    await assert.rejects(generateWeeklySet({ favorites: FAVORITES, deps }), NotEnoughDeclarationsError);
  });

  test('a dashed or overlong title is replaced', async () => {
    for (const [title, expected] of [
      ['Peace — and Provision', 'Peace , and Provision'],
      ['x'.repeat(61), 'Your Declarations This Week'],
      ['', 'Your Declarations This Week'],
    ]) {
      const { deps } = makeDeps({ rounds: [{ title, declarations: Array.from({ length: 10 }, (_, i) => candidate(i)) }] });
      const set = await generateWeeklySet({ favorites: FAVORITES, deps });
      assert.strictEqual(set.title, expected);
    }
  });

  test('verifies verses outside the library through the fetcher', async () => {
    const fetched = [];
    const { deps } = makeDeps({
      rounds: [{
        title: 't',
        declarations: [
          { text: 'God works every detail of my life together for good.', reference: 'Romans 8:28', verseText: 'And we know that in all things God works for the good of those who love him, who have been called according to his purpose.', category: 'faith' },
          ...Array.from({ length: 9 }, (_, i) => candidate(i)),
        ],
      }],
      fetchVerse: async (key) => {
        fetched.push(key);
        return { text: 'We know that all things work together for good for those who love God, for those who are called according to his purpose.' };
      },
    });
    const set = await generateWeeklySet({ favorites: FAVORITES, deps });
    assert.deepStrictEqual(fetched, ['Romans 8:28']);
    assert.strictEqual(set.declarations[0].book, 'Romans 8:28');
    assert.match(set.declarations[0].bibleVerseText, /^We know that all things work together/);
  });
});

describe('pickFavorites', () => {
  const now = new Date('2026-10-25T22:00:00Z');
  const daysAgo = (d) => now.getTime() - d * 24 * 3600 * 1000;

  test('uses this week\'s favorites, newest first, when there are at least three', () => {
    const picked = pickFavorites([
      { text: 'old', favoritedAt: daysAgo(20) },
      { text: 'a', favoritedAt: daysAgo(1) },
      { text: 'b', favoritedAt: daysAgo(6) },
      { text: 'c', favoritedAt: daysAgo(3) },
    ], now);
    assert.strictEqual(picked.basis, 'week');
    assert.deepStrictEqual(picked.favorites.map((f) => f.text), ['a', 'c', 'b']);
  });

  test('falls back to the most recent overall when the week has fewer than three', () => {
    const picked = pickFavorites([
      { text: 'undated' },
      { text: 'a', favoritedAt: daysAgo(1) },
      { text: 'old', favoritedAt: daysAgo(40) },
    ], now);
    assert.strictEqual(picked.basis, 'recent');
    assert.deepStrictEqual(picked.favorites.map((f) => f.text), ['a', 'old', 'undated']);
  });

  test('returns null with fewer than three usable favorites', () => {
    assert.strictEqual(pickFavorites([{ text: 'a' }, { text: '  ' }, null, { text: 5 }], now), null);
    assert.strictEqual(pickFavorites(undefined, now), null);
  });

  test('caps the prompt at fifteen favorites', () => {
    const many = Array.from({ length: 40 }, (_, i) => ({ text: `f${i}`, favoritedAt: daysAgo(i / 10) }));
    assert.strictEqual(pickFavorites(many, now).favorites.length, 15);
  });
});
