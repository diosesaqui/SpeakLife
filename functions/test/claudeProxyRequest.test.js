const test = require('node:test');
const assert = require('node:assert');
const {
  buildClaudeParams, MODEL, MAX_OUTPUT_TOKENS, MAX_SYSTEM_CHARS, MAX_MESSAGE_CHARS, MAX_MESSAGES,
} = require('../lib/claudeProxyRequest');

const user = (content) => ({ role: 'user', content });

test('passes a normal app request through with the server model', () => {
  const r = buildClaudeParams({
    model: 'claude-opus-anything',
    max_tokens: 512,
    system: 'You write declarations.',
    messages: [user('User need: healing')],
  });
  assert.ok(r.ok);
  assert.strictEqual(r.params.model, MODEL, 'the client never picks the model');
  assert.strictEqual(r.params.max_tokens, 512);
  assert.strictEqual(r.params.system, 'You write declarations.');
  assert.deepStrictEqual(r.params.messages, [user('User need: healing')]);
});

test('clamps max_tokens and defaults it when missing', () => {
  assert.strictEqual(buildClaudeParams({ max_tokens: 100000, messages: [user('x')] }).params.max_tokens, MAX_OUTPUT_TOKENS);
  assert.strictEqual(buildClaudeParams({ max_tokens: 0, messages: [user('x')] }).params.max_tokens, 1);
  assert.strictEqual(buildClaudeParams({ messages: [user('x')] }).params.max_tokens, MAX_OUTPUT_TOKENS);
});

test('omits system when not sent', () => {
  const r = buildClaudeParams({ messages: [user('x')] });
  assert.ok(r.ok);
  assert.ok(!('system' in r.params));
});

test('rejects malformed and oversized requests', () => {
  const cases = [
    [null, 'invalid_body'],
    [{}, 'missing_messages'],
    [{ messages: [] }, 'missing_messages'],
    [{ messages: Array(MAX_MESSAGES + 1).fill(user('x')) }, 'too_many_messages'],
    [{ messages: [{ role: 'user', content: [{ type: 'image' }] }] }, 'invalid_message'],
    [{ messages: [{ role: 'system', content: 'x' }] }, 'invalid_role'],
    [{ messages: [user('   ')] }, 'empty_message'],
    [{ messages: [user('a'.repeat(MAX_MESSAGE_CHARS + 1))] }, 'message_too_long'],
    [{ messages: [user('x'), { role: 'assistant', content: 'y' }] }, 'last_message_must_be_user'],
    [{ system: { text: 'x' }, messages: [user('x')] }, 'invalid_system'],
    [{ system: 'a'.repeat(MAX_SYSTEM_CHARS + 1), messages: [user('x')] }, 'system_too_long'],
  ];
  for (const [body, error] of cases) {
    assert.deepStrictEqual(buildClaudeParams(body), { ok: false, error }, JSON.stringify(body)?.slice(0, 80));
  }
});
