/**
 * claudeProxyHandler.js
 * The claudeProxy request handler, with its dependencies injected so it can be
 * tested without Firebase or Anthropic. claudeProxy.js wires the real ones.
 */

const { buildClaudeParams } = require('./claudeProxyRequest');

/**
 * The caller's IP for rate limiting.
 *
 * Google's front end APPENDS the address it saw to X-Forwarded-For, so the
 * right-most entry is the one a client cannot forge. Anything to its left was
 * sent by the client and is ignored; reading entry [0] let a script put a new
 * value on every request and never hit the limit.
 */
function clientIp(req) {
  const forwarded = req.headers && req.headers['x-forwarded-for'];
  if (typeof forwarded === 'string' && forwarded.trim().length > 0) {
    const parts = forwarded.split(',').map((p) => p.trim()).filter(Boolean);
    if (parts.length > 0) return parts[parts.length - 1];
  }
  return req.ip || 'unknown';
}

/**
 * @param {object} deps
 * @param {(token: string) => Promise<boolean>} deps.verifyAppCheck
 * @param {() => boolean} deps.enforceAppCheck  refuse requests without a valid token
 * @param {(ip: string) => Promise<boolean>} deps.overRateLimit  counts the request
 * @param {(params: object) => Promise<object>} deps.callClaude
 * @param {{ warn: Function, error: Function }} [deps.log]
 */
function createClaudeProxyHandler(deps) {
  const log = deps.log || console;

  return async function handle(req, res) {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const built = buildClaudeParams(req.body);
    if (!built.ok) {
      res.status(400).json({ error: built.error });
      return;
    }

    const token = req.headers && req.headers['x-firebase-appcheck'];
    const appCheckPromise = typeof token === 'string' && token.length > 0
      ? deps.verifyAppCheck(token).catch(() => false)
      : Promise.resolve(false);

    // Run both checks at once so they cost one round trip, not two, in front
    // of a feature with an 8-second client timeout.
    let validAppCheck;
    let limited;
    try {
      [validAppCheck, limited] = await Promise.all([
        appCheckPromise,
        deps.overRateLimit(clientIp(req)),
      ]);
    } catch (err) {
      // Fail closed. A flood from one client is what causes transaction
      // contention, so failing open here would let the abuser switch the limit
      // off. The app falls back to its keyword answers on any non-200.
      log.error('Rate limit check failed:', err.message);
      res.status(503).json({ error: 'unavailable' });
      return;
    }

    if (!validAppCheck) {
      if (deps.enforceAppCheck()) {
        res.status(401).json({ error: 'app_check_required' });
        return;
      }
      log.warn('claudeProxy: request without a valid App Check token');
    }

    if (limited) {
      res.status(429).json({ error: 'rate_limited' });
      return;
    }

    try {
      // Same shape as api.anthropic.com/v1/messages, so the app's decoders
      // read it unchanged.
      res.json(await deps.callClaude(built.params));
    } catch (err) {
      log.error('Anthropic error:', err.message);
      res.status(502).json({ error: 'ai_unavailable' });
    }
  };
}

module.exports = { createClaudeProxyHandler, clientIp };
