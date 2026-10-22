/**
 * inviteCode.js
 * The 8-character code alphabet shared by Stand invites and referral codes.
 *
 * One module so the two features can never drift apart: the client normalises
 * both kinds of code with the same rules (see the shared fixture
 * Packages/SpeakLifeKit/Tests/SpeakLifeCoreTests/Resources/referral_codes_fixture.json),
 * and a server that disagreed with it would reject codes the app accepted.
 */

const crypto = require('node:crypto');

// No 0/O/1/I/L. Both halves of each confusable pair are excluded, so a typed
// `0` or `I` cannot be valid under any reading and is rejected outright rather
// than guessed at — guessing is how someone lands in the wrong family's stand.
const CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LENGTH   = 8;

/**
 * A cryptographically random code, uniformly distributed.
 *
 * Rejection sampling, not `% alphabet.length`: 256 is not a multiple of 31, so
 * modulo would make the first few characters of the alphabet measurably more
 * likely and shrink the real keyspace.
 */
function generateCode() {
  const max = 256 - (256 % CODE_ALPHABET.length);
  let out = '';
  while (out.length < CODE_LENGTH) {
    for (const byte of crypto.randomBytes(CODE_LENGTH * 2)) {
      if (byte >= max) continue;                    // reject, keep it uniform
      out += CODE_ALPHABET[byte % CODE_ALPHABET.length];
      if (out.length === CODE_LENGTH) break;
    }
  }
  return out;
}

/** Uppercase, strip separators, reject anything outside the alphabet. */
function normalizeCode(raw) {
  if (typeof raw !== 'string') return null;
  const cleaned = raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
  if (cleaned.length !== CODE_LENGTH) return null;
  for (const ch of cleaned) if (!CODE_ALPHABET.includes(ch)) return null;
  return cleaned;
}

module.exports = { CODE_ALPHABET, CODE_LENGTH, generateCode, normalizeCode };
