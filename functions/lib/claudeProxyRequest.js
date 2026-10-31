/**
 * claudeProxyRequest.js
 * Pure validation for the claudeProxy function, kept apart from the handler so
 * it can be tested without the emulator.
 *
 * The proxy exists so the Anthropic key never ships to devices. The app still
 * writes its own prompts, so what stops someone pointing a script at the proxy
 * and using it as a free Claude account is this file: one cheap model only,
 * short outputs, bounded input, plain-text messages. The handler adds a
 * per-IP rate limit on top.
 */

const MODEL = 'claude-haiku-4-5-20251001';
const MAX_OUTPUT_TOKENS = 600;   // callers ask for 256, 400 and 512
const MAX_SYSTEM_CHARS = 8000;   // the declaration prompt is ~3k
const MAX_MESSAGE_CHARS = 12000; // the campaign curator sends a numbered list
const MAX_MESSAGES = 4;

/**
 * @param {unknown} body the parsed JSON request body
 * @returns {{ ok: true, params: object } | { ok: false, error: string }}
 */
function buildClaudeParams(body) {
  if (!body || typeof body !== 'object') return { ok: false, error: 'invalid_body' };

  const rawMessages = Array.isArray(body.messages) ? body.messages : null;
  if (!rawMessages || rawMessages.length === 0) return { ok: false, error: 'missing_messages' };
  if (rawMessages.length > MAX_MESSAGES) return { ok: false, error: 'too_many_messages' };

  const messages = [];
  for (const m of rawMessages) {
    if (!m || typeof m.content !== 'string') return { ok: false, error: 'invalid_message' };
    if (m.role !== 'user' && m.role !== 'assistant') return { ok: false, error: 'invalid_role' };
    const content = m.content.trim();
    if (!content) return { ok: false, error: 'empty_message' };
    if (content.length > MAX_MESSAGE_CHARS) return { ok: false, error: 'message_too_long' };
    messages.push({ role: m.role, content });
  }
  if (messages[messages.length - 1].role !== 'user') {
    return { ok: false, error: 'last_message_must_be_user' };
  }

  let system;
  if (body.system !== undefined && body.system !== null) {
    if (typeof body.system !== 'string') return { ok: false, error: 'invalid_system' };
    if (body.system.length > MAX_SYSTEM_CHARS) return { ok: false, error: 'system_too_long' };
    system = body.system;
  }

  const requested = Number.isInteger(body.max_tokens) ? body.max_tokens : MAX_OUTPUT_TOKENS;
  const maxTokens = Math.min(Math.max(requested, 1), MAX_OUTPUT_TOKENS);

  // The model is the server's choice, whatever the client sent.
  const params = { model: MODEL, max_tokens: maxTokens, messages };
  if (system) params.system = system;
  return { ok: true, params };
}

module.exports = {
  buildClaudeParams,
  MODEL,
  MAX_OUTPUT_TOKENS,
  MAX_SYSTEM_CHARS,
  MAX_MESSAGE_CHARS,
  MAX_MESSAGES,
};
