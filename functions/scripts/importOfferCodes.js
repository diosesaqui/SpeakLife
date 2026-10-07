#!/usr/bin/env node
/**
 * importOfferCodes.js
 * Loads App Store Connect one-time offer codes into the referral reward pool
 * (Firestore `referralRewardCodes`). Runbook: docs/REFERRAL_YEAR_FREE_SPEC.md §10.
 *
 *   node functions/scripts/importOfferCodes.js \
 *     --file codes.csv --batch 2026Q4 --expires 2027-03-31 [--dry-run] [--project <id>]
 *
 * Credentials: Application Default Credentials (`gcloud auth application-default
 * login`) or GOOGLE_APPLICATION_CREDENTIALS. Set FIRESTORE_EMULATOR_HOST to aim
 * it at an emulator instead.
 *
 * Safe to re-run. A code already in the pool is skipped and never touched, so
 * re-importing a file can never reset a code that has been handed to someone.
 *
 * EVERY LINE OF THE CSV IS A WORKING FREE YEAR. The script never prints a code
 * in full: only counts, line numbers and the last four characters.
 */

const POOL = 'referralRewardCodes';
const BATCH_LIMIT = 500;                     // Firestore's limit per batched write
const CODE_PATTERN = /^[A-Z0-9]{6,64}$/;     // App Store offer codes: alphanumeric

/** The last four characters, so a code can be identified but not used. */
function mask(code) {
  const s = String(code ?? '');
  return s.length ? `…${s.slice(-4)}` : '(empty)';
}

/**
 * --file, --batch, --expires (YYYY-MM-DD, read as 23:59:59 UTC that day and
 * required to be in the future), --dry-run, --project.
 * Returns { ok: true, ... } or { ok: false, error }.
 */
function parseArgs(argv, nowMs) {
  const args = { dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') { args.dryRun = true; continue; }
    if (['--file', '--batch', '--expires', '--project'].includes(a)) {
      args[a.slice(2)] = argv[++i];
      continue;
    }
    return { ok: false, error: `Unknown argument: ${a}` };
  }
  if (!args.file) return { ok: false, error: '--file is required' };
  if (!args.batch || !/^[\w.-]{1,64}$/.test(args.batch)) {
    return { ok: false, error: '--batch is required (letters, digits, . _ -), e.g. 2026Q4' };
  }
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(args.expires || '');
  if (!m) return { ok: false, error: '--expires is required as YYYY-MM-DD' };
  const [y, mo, d] = [+m[1], +m[2], +m[3]];
  const expiresAt = Date.UTC(y, mo - 1, d, 23, 59, 59);
  const check = new Date(expiresAt);
  if (check.getUTCFullYear() !== y || check.getUTCMonth() !== mo - 1 || check.getUTCDate() !== d) {
    return { ok: false, error: `--expires ${args.expires} is not a real date` };
  }
  if (expiresAt <= nowMs) return { ok: false, error: `--expires ${args.expires} is in the past` };
  return {
    ok: true, file: args.file, batch: args.batch, expiresAt,
    dryRun: args.dryRun, project: args.project || null,
  };
}

/** One CSV row → cells, honouring double quotes. */
function splitRow(line) {
  const cells = [];
  let cur = '';
  let quoted = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (quoted) {
      if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; }
      else if (ch === '"') quoted = false;
      else cur += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { cells.push(cur); cur = ''; }
    else cur += ch;
  }
  cells.push(cur);
  return cells.map((c) => c.trim());
}

/**
 * The CSV as App Store Connect downloads it, or a plain list. A first row that
 * is not a code but names a code column ("Code", "Offer Code") is a header,
 * and decides which column is read. Returns
 *   { codes, duplicates, rejected: [{ line, value }] }
 * with `codes` unique, in file order, uppercased.
 */
function parseCodes(text) {
  const lines = String(text ?? '').replace(/^﻿/, '').split(/\r?\n/);
  const codes = [];
  const seen = new Set();
  const duplicates = [];
  const rejected = [];
  let column = 0;
  let sawFirst = false;

  lines.forEach((raw, idx) => {
    const lineNo = idx + 1;
    if (!raw.trim()) return;                         // blank lines, trailing or not
    const cells = splitRow(raw);

    if (!sawFirst) {
      sawFirst = true;
      // "OfferCode" would pass as a code itself, so the word decides, not
      // the shape. A real offer code reading "...CODE..." in row one is a
      // risk worth one rejected row; importing a header as a free year is not.
      const headerCol = cells.findIndex((c) => /code/i.test(c));
      if (headerCol >= 0) { column = headerCol; return; }
    }

    const value = (cells[column] ?? '').trim();
    const code = value.toUpperCase();
    if (!CODE_PATTERN.test(code)) { rejected.push({ line: lineNo, value }); return; }
    if (seen.has(code)) { duplicates.push(code); return; }
    seen.add(code);
    codes.push(code);
  });
  return { codes, duplicates, rejected };
}

/**
 * Writes the codes not already in the pool, in batches under Firestore's
 * limit. `create`, never `set`: a code that appeared between the read and the
 * write fails the batch rather than being overwritten. `Timestamp` is passed
 * in so the pure tests need no Firestore.
 */
async function importCodes(db, codes, { batchId, expiresAt, dryRun, Timestamp, nowMs }) {
  let added = 0;
  let skipped = 0;
  for (let i = 0; i < codes.length; i += BATCH_LIMIT) {
    const chunk = codes.slice(i, i + BATCH_LIMIT);
    const refs = chunk.map((c) => db.collection(POOL).doc(c));
    const snaps = await db.getAll(...refs);
    const fresh = snaps.filter((s) => !s.exists).map((s) => s.id);
    skipped += chunk.length - fresh.length;
    added += fresh.length;
    if (dryRun || fresh.length === 0) continue;
    const batch = db.batch();
    for (const code of fresh) {
      batch.create(db.collection(POOL).doc(code), {
        code,
        batchId,
        expiresAt: Timestamp ? Timestamp.fromMillis(expiresAt) : new Date(expiresAt),
        assignedTo: null,
        assignedAt: null,
        importedAt: Timestamp ? Timestamp.fromMillis(nowMs) : new Date(nowMs),
      });
    }
    await batch.commit();
  }
  return { added, skipped };
}

/** Exit code: 0 success, 1 nothing importable, 2 bad arguments or unreadable file. */
async function main(argv, { db, readFile, out, now, Timestamp }) {
  const args = parseArgs(argv, now());
  if (!args.ok) {
    out(`error: ${args.error}`);
    out('usage: importOfferCodes.js --file codes.csv --batch 2026Q4 --expires 2027-03-31 [--dry-run]');
    return 2;
  }
  let text;
  try { text = readFile(args.file); } catch (err) {
    out(`error: cannot read ${args.file}: ${err.message}`);
    return 2;
  }

  const { codes, duplicates, rejected } = parseCodes(text);
  out(`Read ${codes.length} codes (${duplicates.length} duplicate in file, ${rejected.length} rejected)`);
  for (const d of duplicates) out(`  duplicate in file: ${mask(d)}`);
  for (const r of rejected) out(`  rejected line ${r.line}: ${mask(r.value)}`);
  if (codes.length === 0) {
    out('error: no valid codes to import');
    return 1;
  }

  const { added, skipped } = await importCodes(db, codes, {
    batchId: args.batch, expiresAt: args.expiresAt, dryRun: args.dryRun,
    Timestamp, nowMs: now(),
  });
  const expires = new Date(args.expiresAt).toISOString().slice(0, 10);
  if (args.dryRun) {
    out(`Dry run: ${added} new, ${skipped} already in the pool. Nothing written.`);
  } else {
    out(`Imported batch ${args.batch} (expires ${expires}): ${added} new, ${skipped} already in the pool.`);
  }
  return 0;
}

module.exports = { parseArgs, parseCodes, importCodes, main, mask, splitRow };

if (require.main === module) {
  const fs = require('node:fs');
  const argv = process.argv.slice(2);
  const projectIdx = argv.indexOf('--project');
  const projectId = projectIdx >= 0 ? argv[projectIdx + 1] : undefined;
  const { initializeApp } = require('firebase-admin/app');
  const { getFirestore, Timestamp } = require('firebase-admin/firestore');
  initializeApp(projectId ? { projectId } : undefined);
  main(argv, {
    db: getFirestore(),
    readFile: (p) => fs.readFileSync(p, 'utf8'),
    out: (l) => console.log(l),
    now: () => Date.now(),
    Timestamp,
  }).then((code) => { process.exitCode = code; }, (err) => {
    console.error(`error: ${err.message}`);
    process.exitCode = 1;
  });
}
