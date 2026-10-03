/**
 * deviceCheck.js
 * A minimal client for Apple's DeviceCheck two-bit API, with no dependencies.
 *
 * Apple keeps two bits per device per developer team. They survive deleting
 * the app and erasing the phone, which is the whole reason the referral
 * feature uses them (docs/REFERRAL_YEAR_FREE_SPEC.md §7):
 *
 *   bit 0 = "this device has been counted as a referred friend"
 *   bit 1 = "this device has enrolled as a referrer"
 *
 * No other app on this developer account may use DeviceCheck bits without
 * coordinating with that table.
 *
 * Auth is an ES256 JWT signed with the team's DeviceCheck .p8 key, built with
 * node:crypto. Requests go through the global fetch (Node 22).
 *
 * Two Apple quirks this file exists to absorb:
 *
 *  1. query_two_bits answers HTTP 200 with the PLAIN TEXT body
 *     "Failed to find bit state" for a device whose bits were never set. That
 *     is the common case (every new friend), not an error: both bits false.
 *
 *  2. update_two_bits writes BOTH bits. Sending only bit0 would be read by
 *     Apple as a write of bit0 alone, but to stay safe across API versions
 *     setBit() reads the current pair first and writes it back with one bit
 *     raised, so setting "counted" can never clear "is a referrer".
 */

const crypto = require('node:crypto');

const PRODUCTION_HOST  = 'https://api.devicecheck.apple.com';
const DEVELOPMENT_HOST = 'https://api.development.devicecheck.apple.com';
const JWT_LIFETIME_SEC = 50 * 60;   // Apple accepts up to an hour; renew early

/**
 * kind is 'invalid_token' (Apple rejected the device token itself, so the
 * device cannot be verified and retrying will not help) or 'unavailable'
 * (Apple, the network or our credentials failed: retry later).
 */
class DeviceCheckError extends Error {
  constructor(kind, message) {
    super(message);
    this.name = 'DeviceCheckError';
    this.kind = kind;
  }
}

const b64url = (buf) => Buffer.from(buf).toString('base64url');

/**
 * The .p8 as stored in Secret Manager. Pasting a multi-line key into a single
 * line field is a common way to end up with literal "\n" sequences, so they
 * are turned back into newlines rather than failing at the first claim.
 */
function normalizePem(keyP8) {
  return String(keyP8 || '').replace(/\\n/g, '\n').trim() + '\n';
}

/** ES256 JWT for DeviceCheck: header {alg, kid}, claims {iss, iat}. */
function buildJwt({ keyP8, keyId, teamId, nowSec }) {
  const header  = b64url(JSON.stringify({ alg: 'ES256', kid: keyId }));
  const payload = b64url(JSON.stringify({ iss: teamId, iat: nowSec }));
  const signingInput = `${header}.${payload}`;
  // ieee-p1363: JOSE wants the raw 64-byte r||s, not the DER node defaults to.
  const sig = crypto.sign('sha256', Buffer.from(signingInput), {
    key: crypto.createPrivateKey(normalizePem(keyP8)),
    dsaEncoding: 'ieee-p1363',
  });
  return `${signingInput}.${b64url(sig)}`;
}

/**
 * Only Apple's bad-device-token 400 is a verdict on the device. Every other
 * 400 (malformed timestamp or payload, a development token sent to the
 * production host) is a problem on OUR side, and treating it as final would
 * permanently burn real friends, so it is `unavailable` and retried.
 */
function failure(status, text) {
  if (status === 400 && /device token/i.test(String(text))) {
    return new DeviceCheckError('invalid_token', `DeviceCheck 400: ${String(text).slice(0, 120)}`);
  }
  return new DeviceCheckError('unavailable', `DeviceCheck ${status}: ${String(text).slice(0, 120)}`);
}

/** query_two_bits response → {bit0, bit1}, or throws DeviceCheckError. */
function parseQueryResponse(status, text) {
  if (status !== 200) throw failure(status, text);
  const body = String(text ?? '').trim();
  if (/^failed to find bit state$/i.test(body)) return { bit0: false, bit1: false };
  let json;
  try { json = JSON.parse(body); } catch {
    throw new DeviceCheckError('unavailable', `DeviceCheck: unexpected body "${body.slice(0, 60)}"`);
  }
  if (!json || typeof json !== 'object') {
    throw new DeviceCheckError('unavailable', 'DeviceCheck: unexpected body');
  }
  return { bit0: json.bit0 === true, bit1: json.bit1 === true };
}

/** update_two_bits response → true, or throws DeviceCheckError. */
function parseUpdateResponse(status, text) {
  if (status !== 200) throw failure(status, text);
  return true;
}

/**
 * The production client. Construct lazily (only when a request needs it) so
 * tests and emulators never need the key.
 *
 *   now:   () => epoch millis. Apple wants the request timestamp in ms.
 *   fetch: injectable for tests; defaults to the global fetch.
 */
function createAppleDeviceCheck({ keyP8, keyId, teamId, fetch: doFetch = globalThis.fetch, now }) {
  if (!keyP8 || !keyId || !teamId) {
    throw new DeviceCheckError('unavailable', 'DeviceCheck credentials are not configured');
  }
  let cached = null;   // { jwt, iat }

  function jwt() {
    const nowSec = Math.floor(now() / 1000);
    if (!cached || nowSec - cached.iat > JWT_LIFETIME_SEC) {
      cached = { jwt: buildJwt({ keyP8, keyId, teamId, nowSec }), iat: nowSec };
    }
    return cached.jwt;
  }

  async function call(endpoint, body, isDevelopment) {
    const host = isDevelopment ? DEVELOPMENT_HOST : PRODUCTION_HOST;
    let res;
    try {
      res = await doFetch(`${host}/v1/${endpoint}`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${jwt()}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          device_token: body.device_token,
          transaction_id: crypto.randomUUID(),
          timestamp: now(),
          ...body,
        }),
      });
    } catch (err) {
      throw new DeviceCheckError('unavailable', `DeviceCheck unreachable: ${err.message}`);
    }
    return { status: res.status, text: await res.text() };
  }

  async function queryBits(token, { isDevelopment = false } = {}) {
    const r = await call('query_two_bits', { device_token: token }, isDevelopment);
    return parseQueryResponse(r.status, r.text);
  }

  async function setBit(token, which, { isDevelopment = false } = {}) {
    const current = await queryBits(token, { isDevelopment });
    const next = { ...current, [`bit${which}`]: true };
    const r = await call('update_two_bits',
      { device_token: token, bit0: next.bit0, bit1: next.bit1 }, isDevelopment);
    return parseUpdateResponse(r.status, r.text);
  }

  /**
   * Writes both bits exactly. Only the QA reset script uses this: production
   * code never clears a bit, because a cleared bit is a phone that can be
   * counted again.
   */
  async function setBits(token, { bit0, bit1 }, { isDevelopment = false } = {}) {
    const r = await call('update_two_bits',
      { device_token: token, bit0: bit0 === true, bit1: bit1 === true }, isDevelopment);
    return parseUpdateResponse(r.status, r.text);
  }

  return { queryBits, setBit, setBits };
}

module.exports = {
  DeviceCheckError, buildJwt, parseQueryResponse, parseUpdateResponse,
  createAppleDeviceCheck, PRODUCTION_HOST, DEVELOPMENT_HOST,
};
