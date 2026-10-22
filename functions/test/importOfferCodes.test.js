/**
 * importOfferCodes.test.js
 * The offer code import script's pure half: argument and CSV parsing, and
 * what it prints. No emulator needed.
 *
 *   npm run test:import
 *
 * The write path (re-runs, batching past 500, dry runs against Firestore) is
 * covered by the BE-IMP rows in referral.test.js, against the emulator.
 */

const assert = require('node:assert');
const { test } = require('node:test');
const imp = require('../scripts/importOfferCodes');

const NOW = Date.UTC(2026, 9, 2, 12, 0, 0);
const GOOD_ARGS = ['--file', 'codes.csv', '--batch', '2026Q4', '--expires', '2027-03-31'];

/**
 * A stand-in Firestore with just what the importer touches: doc refs, getAll
 * and batches. `existing` seeds codes already in the pool.
 */
function fakeDb(existing = []) {
  const store = new Map(existing.map((c) => [c, { code: c, assignedTo: 'someone' }]));
  const commits = [];
  const ref = (id) => ({ id, path: `referralRewardCodes/${id}` });
  return {
    store, commits,
    collection: () => ({ doc: ref }),
    getAll: async (...refs) => refs.map((r) => ({ id: r.id, exists: store.has(r.id) })),
    batch() {
      const ops = [];
      return {
        create(r, data) { ops.push([r.id, data]); },
        async commit() {
          if (ops.length > 500) throw new Error('batch over 500');
          commits.push(ops.length);
          for (const [id, data] of ops) store.set(id, data);
        },
      };
    },
  };
}

async function run(argv, { text = 'Code\nAAAAAA1111\nBBBBBB2222\n', db = fakeDb() } = {}) {
  const lines = [];
  const code = await imp.main(argv, {
    db, now: () => NOW, out: (l) => lines.push(String(l)),
    readFile: () => text,
  });
  return { code, lines, out: lines.join('\n'), db };
}

test('BE-IMP-01 an App Store Connect CSV with a header row: header skipped, codes imported', () => {
  const r = imp.parseCodes('Offer Code\nW7HKXJ4MAJFR\nQ2ZP9LM3KD7T\n');
  assert.deepStrictEqual(r.codes, ['W7HKXJ4MAJFR', 'Q2ZP9LM3KD7T']);
  assert.deepStrictEqual(r.rejected, []);
});

test('BE-IMP-01 a multi-column CSV reads the code column named in the header', () => {
  const r = imp.parseCodes('Reference Name,Offer Code,Expiration Date\n' +
    'Referral 1 Year Free,W7HKXJ4MAJFR,2027-03-31\n"Referral 1 Year Free","Q2ZP9LM3KD7T",2027-03-31\n');
  assert.deepStrictEqual(r.codes, ['W7HKXJ4MAJFR', 'Q2ZP9LM3KD7T']);
});

test('BE-IMP-01 a header shaped like a code ("OfferCode") is still a header', () => {
  assert.deepStrictEqual(imp.parseCodes('OfferCode\nW7HKXJ4MAJFR').codes, ['W7HKXJ4MAJFR']);
});

test('BE-IMP-01 a headerless file is all codes', () => {
  assert.deepStrictEqual(imp.parseCodes('W7HKXJ4MAJFR\nQ2ZP9LM3KD7T').codes,
    ['W7HKXJ4MAJFR', 'Q2ZP9LM3KD7T']);
});

test('BE-IMP-02 Windows line endings, trailing blank lines and whitespace are handled', () => {
  const r = imp.parseCodes('Code\r\n  W7HKXJ4MAJFR  \r\n\tQ2ZP9LM3KD7T\r\n\r\n\r\n   \r\n');
  assert.deepStrictEqual(r.codes, ['W7HKXJ4MAJFR', 'Q2ZP9LM3KD7T']);
  assert.deepStrictEqual(r.rejected, []);
  // A UTF-8 byte order mark on the first line is not part of the header.
  assert.deepStrictEqual(imp.parseCodes('﻿Code\nW7HKXJ4MAJFR').codes, ['W7HKXJ4MAJFR']);
});

test('BE-IMP-03 a code repeated within the file is imported once and reported', () => {
  const r = imp.parseCodes('Code\nW7HKXJ4MAJFR\nQ2ZP9LM3KD7T\nW7HKXJ4MAJFR\n');
  assert.deepStrictEqual(r.codes, ['W7HKXJ4MAJFR', 'Q2ZP9LM3KD7T']);
  assert.deepStrictEqual(r.duplicates, ['W7HKXJ4MAJFR']);
});

test('BE-IMP-03 duplicates are reported by the script, masked', async () => {
  const { code, out } = await run(GOOD_ARGS, { text: 'Code\nW7HKXJ4MAJFR\nW7HKXJ4MAJFR\n' });
  assert.strictEqual(code, 0);
  assert.match(out, /1 duplicate/);
  assert.match(out, /…AJFR/);
});

test('BE-IMP-05 --expires missing, malformed or in the past: non-zero, nothing written', async () => {
  for (const argv of [
    ['--file', 'c.csv', '--batch', 'b'],
    ['--file', 'c.csv', '--batch', 'b', '--expires', 'next year'],
    ['--file', 'c.csv', '--batch', 'b', '--expires', '2026-10-01'],
    ['--file', 'c.csv', '--batch', 'b', '--expires', '2027-02-30'],
  ]) {
    const { code, db } = await run(argv);
    assert.notStrictEqual(code, 0, argv.join(' '));
    assert.strictEqual(db.store.size, 0);
    assert.strictEqual(db.commits.length, 0);
  }
  assert.ok(!imp.parseArgs(['--file', 'c', '--batch', 'b', '--expires', '2026-10-01'], NOW).ok);
});

test('BE-IMP-05 --expires is read as the end of that day, UTC', () => {
  const a = imp.parseArgs(GOOD_ARGS, NOW);
  assert.ok(a.ok);
  assert.strictEqual(a.expiresAt, Date.UTC(2027, 2, 31, 23, 59, 59));
});

test('BE-IMP-06 --batch missing: non-zero', async () => {
  const { code, db } = await run(['--file', 'c.csv', '--expires', '2027-03-31']);
  assert.notStrictEqual(code, 0);
  assert.strictEqual(db.store.size, 0);
  assert.notStrictEqual((await run(['--batch', 'b', '--expires', '2027-03-31'])).code, 0,
    '--file missing too');
});

test('BE-IMP-07 empty or malformed rows are rejected and reported, the rest imported', () => {
  const r = imp.parseCodes('Code\nW7HKXJ4MAJFR\n,\nnot a code!\nAB\nQ2ZP9LM3KD7T\n');
  assert.deepStrictEqual(r.codes, ['W7HKXJ4MAJFR', 'Q2ZP9LM3KD7T']);
  assert.strictEqual(r.rejected.length, 3);
  assert.deepStrictEqual(r.rejected.map((x) => x.line), [3, 4, 5]);
});

test('BE-IMP-07 the script reports rejected rows by line and still imports the rest', async () => {
  const { code, out, db } = await run(GOOD_ARGS,
    { text: 'Code\nW7HKXJ4MAJFR\nbad!\nQ2ZP9LM3KD7T\n' });
  assert.strictEqual(code, 0);
  assert.match(out, /1 rejected/);
  assert.match(out, /line 3/);
  assert.ok(db.store.has('W7HKXJ4MAJFR') && db.store.has('Q2ZP9LM3KD7T'));
});

test('BE-IMP-08 more than 500 codes are written in batches of at most 500', async () => {
  const codes = Array.from({ length: 1203 }, (_, i) => `CODE${String(i).padStart(8, '0')}`);
  const { code, db } = await run(GOOD_ARGS, { text: `Code\n${codes.join('\n')}\n` });
  assert.strictEqual(code, 0);
  assert.strictEqual(db.store.size, 1203);
  assert.ok(db.commits.length >= 3);
  assert.ok(db.commits.every((n) => n <= 500));
});

test('BE-IMP-04 a re-run adds nothing and leaves assigned codes alone', async () => {
  const db = fakeDb(['W7HKXJ4MAJFR']);
  const before = { ...db.store.get('W7HKXJ4MAJFR') };
  const { code, out } = await run(GOOD_ARGS, { text: 'Code\nW7HKXJ4MAJFR\nQ2ZP9LM3KD7T\n', db });
  assert.strictEqual(code, 0);
  assert.match(out, /1 new/);
  assert.match(out, /1 already/);
  assert.deepStrictEqual(db.store.get('W7HKXJ4MAJFR'), before);
});

test('BE-IMP-09 --dry-run prints counts and writes nothing', async () => {
  const { code, out, db } = await run([...GOOD_ARGS, '--dry-run']);
  assert.strictEqual(code, 0);
  assert.match(out, /dry run/i);
  assert.match(out, /2 new/);
  assert.strictEqual(db.commits.length, 0);
  assert.strictEqual(db.store.size, 0);
});

test('BE-IMP-10 the script never prints a full code, only counts and last 4 characters', async () => {
  const codes = ['W7HKXJ4MAJFR', 'Q2ZP9LM3KD7T', 'ZZTOPSECRET9'];
  const text = `Code\n${codes.join('\n')}\nW7HKXJ4MAJFR\nBADCODE!!\n`;
  for (const argv of [GOOD_ARGS, [...GOOD_ARGS, '--dry-run']]) {
    const { out } = await run(argv, { text });
    for (const c of [...codes, 'BADCODE!!']) {
      assert.ok(!out.includes(c), `printed ${c} in full:\n${out}`);
      assert.ok(!out.includes(c.slice(0, 6)), `printed the start of ${c}:\n${out}`);
    }
  }
  assert.strictEqual(imp.mask('W7HKXJ4MAJFR'), '…AJFR');
});
