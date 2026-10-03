#!/usr/bin/env node
/**
 * resetReferralTestDevice.js
 * QA ONLY. Makes a test phone and test accounts usable again for the referral
 * device checklist (docs/REFERRAL_FE_TDD.md §11).
 *
 * Why it exists: DeviceCheck bits survive deleting the app and even erasing
 * the phone. That is the whole anti-farming guarantee in production, and it
 * means every QA phone can be counted as a referred friend exactly once,
 * ever, unless its bits are cleared.
 *
 *   node functions/scripts/resetReferralTestDevice.js --confirm-qa \
 *     [--token <deviceCheckToken>] [--development] \
 *     [--uid <friendUid>] [--referrer <referrerUid>] \
 *     [--dry-run] [--project <firebaseProjectId>]
 *
 *   --token       Clear both DeviceCheck bits for this phone. Copy the token
 *                 from the app's debug panel (Referral QA section).
 *   --development The phone runs an Xcode debug build (development
 *                 DeviceCheck environment). TestFlight builds do not.
 *   --uid         Delete this friend's final claim, so the same Firebase
 *                 account can be credited again.
 *   --referrer    Delete this referrer's record, credits and codes, so they
 *                 start again at 0. An assigned reward code is LEFT in the
 *                 pool, marked assigned: it may already have been redeemed.
 *   --dry-run     Read and report, write nothing.
 *   --confirm-qa  Required. There is no reason to run this against a real
 *                 user, and it refuses to run without saying so.
 *
 * Credentials:
 *   Firestore: Application Default Credentials, or FIRESTORE_EMULATOR_HOST.
 *   DeviceCheck: DEVICECHECK_KEY_P8 (the .p8 contents, or a path to the file),
 *                DEVICECHECK_KEY_ID, DEVICECHECK_TEAM_ID.
 *
 * Never prints a device token or reward code in full: last four characters only.
 */

const FLAGS = ['--confirm-qa', '--development', '--dry-run'];
const VALUES = ['--token', '--uid', '--referrer', '--project'];

const mask = (s) => {
  const str = String(s ?? '');
  return str.length ? `…${str.slice(-4)}` : '(empty)';
};

/** Returns { ok: true, ... } or { ok: false, error }. */
function parseArgs(argv) {
  const args = { confirmQa: false, development: false, dryRun: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (FLAGS.includes(a)) {
      if (a === '--confirm-qa') args.confirmQa = true;
      if (a === '--development') args.development = true;
      if (a === '--dry-run') args.dryRun = true;
      continue;
    }
    if (VALUES.includes(a)) {
      const v = argv[++i];
      if (!v || v.startsWith('--')) return { ok: false, error: `${a} needs a value` };
      args[a.slice(2)] = v;
      continue;
    }
    return { ok: false, error: `Unknown argument: ${a}` };
  }
  if (!args.token && !args.uid && !args.referrer) {
    return { ok: false, error: 'Nothing to reset: pass --token, --uid and/or --referrer' };
  }
  return { ok: true, ...args };
}

async function resetBits(dc, token, { development, dryRun }, out) {
  const opts = { isDevelopment: development };
  const before = await dc.queryBits(token, opts);
  out(`Device ${mask(token)} (${development ? 'development' : 'production'}): bit0=${before.bit0} bit1=${before.bit1}`);
  if (dryRun) { out('  dry run: bits left as they are'); return; }
  await dc.setBits(token, { bit0: false, bit1: false }, opts);
  const after = await dc.queryBits(token, opts);
  out(`  cleared: bit0=${after.bit0} bit1=${after.bit1}`);
}

async function resetClaim(db, uid, { dryRun }, out) {
  const ref = db.collection('referralClaims').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) { out(`Friend ${uid}: no claim on record`); return; }
  out(`Friend ${uid}: claim on record (${snap.data().outcome || 'unknown'})`);
  if (dryRun) { out('  dry run: claim kept'); return; }
  await ref.delete();
  out('  claim deleted');
}

async function resetReferrer(db, uid, { dryRun }, out) {
  const recRef = db.collection('referrals').doc(uid);
  const rec = await recRef.get();
  const credits = await recRef.collection('credits').get();
  const codes = await db.collection('referralCodes').where('uid', '==', uid).get();
  if (!rec.exists && codes.docs.length === 0) { out(`Referrer ${uid}: no record`); return; }

  const data = rec.exists ? rec.data() : {};
  out(`Referrer ${uid}: count=${data.count ?? 0}, ${credits.docs.length} credit(s), ${codes.docs.length} code(s)`);
  if (data.reward?.code) {
    out(`  reward code ${mask(data.reward.code)} stays in the pool, assigned: it may already be redeemed`);
  }
  if (dryRun) { out('  dry run: record kept'); return; }
  for (const d of credits.docs) await d.ref.delete();
  for (const d of codes.docs) await d.ref.delete();
  if (rec.exists) await recRef.delete();
  out('  record, credits and codes deleted');
}

/** Exit code: 0 done, 1 failed, 2 refused. */
async function main(argv, { dc, db, out }) {
  const args = parseArgs(argv);
  if (!args.ok) { out(`Error: ${args.error}`); return 2; }
  if (!args.confirmQa) {
    out('Refusing to run without --confirm-qa. This script is for test phones and test accounts only.');
    return 2;
  }
  // Factories in the real run (built only if needed), plain fakes in tests.
  const getDc = typeof dc === 'function' ? dc : () => dc;
  const getDb = typeof db === 'function' ? db : () => db;
  try {
    if (args.token) await resetBits(getDc(), args.token, args, out);
    if (args.uid) await resetClaim(getDb(), args.uid, args, out);
    if (args.referrer) await resetReferrer(getDb(), args.referrer, args, out);
    return 0;
  } catch (err) {
    out(`Failed: ${err.message}`);
    return 1;
  }
}

module.exports = { parseArgs, main, mask };

if (require.main === module) {
  const fs = require('node:fs');
  const argv = process.argv.slice(2);
  const projectIdx = argv.indexOf('--project');
  const project = projectIdx >= 0 ? argv[projectIdx + 1] : undefined;

  // Built lazily, so a --uid-only run needs no DeviceCheck key and a
  // --token-only run touches no Firestore.
  let dbInstance;
  const db = () => {
    if (!dbInstance) {
      const { initializeApp } = require('firebase-admin/app');
      const { getFirestore } = require('firebase-admin/firestore');
      initializeApp(project ? { projectId: project } : undefined);
      dbInstance = getFirestore();
    }
    return dbInstance;
  };
  const dc = () => {
    const { createAppleDeviceCheck } = require('../deviceCheck');
    let keyP8 = process.env.DEVICECHECK_KEY_P8 || '';
    if (keyP8 && !keyP8.includes('BEGIN') && fs.existsSync(keyP8)) keyP8 = fs.readFileSync(keyP8, 'utf8');
    return createAppleDeviceCheck({
      keyP8, keyId: process.env.DEVICECHECK_KEY_ID, teamId: process.env.DEVICECHECK_TEAM_ID,
      now: () => Date.now(),
    });
  };

  main(argv, { dc, db, out: (l) => console.log(l) }).then((code) => process.exit(code));
}
