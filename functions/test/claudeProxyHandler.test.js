const test = require('node:test');
const assert = require('node:assert');
const { createClaudeProxyHandler, clientIp } = require('../lib/claudeProxyHandler');

const validBody = { max_tokens: 100, messages: [{ role: 'user', content: 'User need: peace' }] };
const silent = { warn() {}, error() {} };

function fakeRes() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) { this.statusCode = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

function req({ method = 'POST', body = validBody, headers = {}, ip = '10.0.0.1' } = {}) {
  return { method, body, headers, ip };
}

function handler(overrides = {}) {
  const calls = { claude: [], limitIps: [] };
  const h = createClaudeProxyHandler({
    verifyAppCheck: async (t) => t === 'good',
    enforceAppCheck: () => false,
    overRateLimit: async (ip) => { calls.limitIps.push(ip); return false; },
    callClaude: async (params) => { calls.claude.push(params); return { content: [{ type: 'text', text: 'ok' }] }; },
    log: silent,
    ...overrides,
  });
  return { h, calls };
}

test('clientIp uses the right-most X-Forwarded-For entry, which the client cannot forge', () => {
  assert.strictEqual(clientIp(req({ headers: { 'x-forwarded-for': '6.6.6.6, 203.0.113.9' } })), '203.0.113.9');
  assert.strictEqual(clientIp(req({ headers: { 'x-forwarded-for': '203.0.113.9' } })), '203.0.113.9');
  assert.strictEqual(clientIp(req({ headers: {} })), '10.0.0.1');
});

test('spoofed left-hand X-Forwarded-For values all land in the same bucket', async () => {
  const { h, calls } = handler();
  for (const fake of ['1.1.1.1', '2.2.2.2', '3.3.3.3']) {
    await h(req({ headers: { 'x-forwarded-for': `${fake}, 198.51.100.7` } }), fakeRes());
  }
  assert.deepStrictEqual(calls.limitIps, ['198.51.100.7', '198.51.100.7', '198.51.100.7']);
});

test('a valid request returns the Anthropic response unchanged', async () => {
  const { h, calls } = handler();
  const res = fakeRes();
  await h(req({ headers: { 'x-firebase-appcheck': 'good' } }), res);
  assert.strictEqual(res.statusCode, 200);
  assert.deepStrictEqual(res.body, { content: [{ type: 'text', text: 'ok' }] });
  assert.strictEqual(calls.claude.length, 1);
});

test('rejects non-POST and malformed bodies before any check runs', async () => {
  const { h, calls } = handler();
  const getRes = fakeRes();
  await h(req({ method: 'GET' }), getRes);
  assert.strictEqual(getRes.statusCode, 405);
  const badRes = fakeRes();
  await h(req({ body: {} }), badRes);
  assert.strictEqual(badRes.statusCode, 400);
  assert.strictEqual(calls.limitIps.length, 0);
  assert.strictEqual(calls.claude.length, 0);
});

test('over the limit returns 429 and never calls Claude', async () => {
  const { h, calls } = handler({ overRateLimit: async () => true });
  const res = fakeRes();
  await h(req(), res);
  assert.strictEqual(res.statusCode, 429);
  assert.strictEqual(calls.claude.length, 0);
});

test('a rate-limit failure fails closed', async () => {
  const { h, calls } = handler({ overRateLimit: async () => { throw new Error('contention'); } });
  const res = fakeRes();
  await h(req(), res);
  assert.strictEqual(res.statusCode, 503);
  assert.strictEqual(calls.claude.length, 0);
});

test('App Check: missing or bad tokens pass while not enforced, and are refused when enforced', async () => {
  for (const headers of [{}, { 'x-firebase-appcheck': 'bad' }]) {
    const open = handler();
    const openRes = fakeRes();
    await open.h(req({ headers }), openRes);
    assert.strictEqual(openRes.statusCode, 200);

    const strict = handler({ enforceAppCheck: () => true });
    const strictRes = fakeRes();
    await strict.h(req({ headers }), strictRes);
    assert.strictEqual(strictRes.statusCode, 401);
    assert.strictEqual(strict.calls.claude.length, 0);
  }
  const strict = handler({ enforceAppCheck: () => true });
  const okRes = fakeRes();
  await strict.h(req({ headers: { 'x-firebase-appcheck': 'good' } }), okRes);
  assert.strictEqual(okRes.statusCode, 200);
});

test('a verifier that throws counts as an invalid token, not a crash', async () => {
  const { h } = handler({ enforceAppCheck: () => true, verifyAppCheck: async () => { throw new Error('expired'); } });
  const res = fakeRes();
  await h(req({ headers: { 'x-firebase-appcheck': 'whatever' } }), res);
  assert.strictEqual(res.statusCode, 401);
});

test('an Anthropic error maps to 502', async () => {
  const { h } = handler({ callClaude: async () => { throw new Error('overloaded'); } });
  const res = fakeRes();
  await h(req(), res);
  assert.strictEqual(res.statusCode, 502);
  assert.deepStrictEqual(res.body, { error: 'ai_unavailable' });
});
