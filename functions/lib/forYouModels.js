/**
 * The two model calls behind the weekly For You set.
 *
 *   write  Sonnet 5.5 writes declarations modelled on the user's favorites,
 *          choosing and quoting its own verse for each.
 *   judge  Haiku 5.5 reads each line next to the verified verse text and
 *          passes only the ones the verse actually supports.
 *
 * Both return JSON through structured outputs, so nothing is parsed out of
 * prose. The writer's verse quote is only used to check the verse; the text
 * that ships comes from verseVerifier.
 */

const { CATEGORIES } = require('./lifeCategories');

const WRITER_MODEL = 'claude-sonnet-5-5';
const JUDGE_MODEL = 'claude-haiku-5-5';

// The CLAUDE.md declaration rules, condensed for the writer. Static so it
// caches across every user in a scheduler run.
const WRITER_SYSTEM = `You write declarations for SpeakLife, a Christian app used by over a million believers. A declaration is one line a person speaks out loud, in their own voice, over their own life. Faith to speak it is what lets God get to work, and the saying is the point.

Each week you write a fresh set for one person, modelled on the declarations they saved. Read what they saved as a picture of what they are believing God for right now, and write new lines for the same places in their life.

EVERY DECLARATION:
- First person: I, me, my. Never "you" or "your" addressed to the reader. Speaking to God mid-sentence is fine ("I bless You, Lord").
- Present tense, already done. "I am healed." "I have." Never "I will one day" or a request.
- One sentence, 10 to 18 words. Start on the strongest word. No filler: just, really, very, truly.
- Plain words that land the first time. No churchy jargon, no poetic riddles. If a line could make someone ask "what does that mean?", rewrite it.
- Bold. Never soften a promise the verse makes. If the verse says it, say it flat and finished. The only limit is what the verse actually promises.
- Call higher. Declare the reality God gives, in the exact place the issue lives: a sound mind for anxiety, a healed body for sickness, provision in the finances. Never name worry, fear, sickness, lack or shame as something the speaker has now. You may name it only as already carried, healed or defeated.
- Never claim another free person will change, return or believe, or any specific outcome no verse states. Declare God's faithfulness toward them instead.
- No dashes of any kind. No quotation marks, no markdown.
- Make the speaker feel something: courage, comfort, awe, holy defiance, joy. Concrete over abstract.

EVERY VERSE:
- Choose the verse the declaration stands on yourself. Use a single verse or at most four consecutive verses, written "Book Chapter:Verse" or "Book Chapter:Verse-Verse". No letters after verse numbers, no commas, no whole chapters.
- Quote it word for word in verseText, NIV wording. It will be checked against the real text, so quote only verses you know exactly.
- The verse must actually promise or state what the declaration says, read in its context. Never use a verse that undercuts the promise (for example "my flesh and my heart may fail" under a health line).
- Every declaration in the set uses a different verse.

THE SET:
- New words, not reworded copies of what they saved. Different verses from theirs where you can.
- Spread across the same themes they saved, weighted the way they weighted them.
- category is the theme the line belongs to.
- title: 2 to 5 words naming their week, plain and warm, for example "Peace and Provision".`;

const JUDGE_SYSTEM = `You check declarations for SpeakLife before they reach a believer. Each item is one first-person line and the Bible verse it stands on, quoted from a real translation.

Pass an item (supported: true) only if ALL of these hold:
1. The verse, read in its context, promises or states what the declaration claims. Applying a promise personally is fine. Claiming more than the verse says is not.
2. The verse does not undercut the declaration.
3. The declaration does not claim that another person will change, return or believe, or promise a specific outcome no verse states.
4. The declaration does not name fear, sickness, lack, worry or shame as the speaker's present condition. Naming it as already carried, healed or defeated is fine.
5. A first-time reader understands it instantly. No riddles.
6. It is spoken in first person, in present or finished tense.

When unsure, fail it. Give a short reason either way. Return a verdict for every id.`;

const WRITER_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    declarations: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          text: { type: 'string' },
          reference: { type: 'string' },
          verseText: { type: 'string' },
          category: { type: 'string', enum: Object.keys(CATEGORIES) },
        },
        required: ['text', 'reference', 'verseText', 'category'],
        additionalProperties: false,
      },
    },
  },
  required: ['title', 'declarations'],
  additionalProperties: false,
};

const JUDGE_SCHEMA = {
  type: 'object',
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          supported: { type: 'boolean' },
          reason: { type: 'string' },
        },
        required: ['id', 'supported', 'reason'],
        additionalProperties: false,
      },
    },
  },
  required: ['verdicts'],
  additionalProperties: false,
};

// Caps what a user-supplied favorite can put into the prompt.
const MAX_LINE = 300;
const MAX_AVOID = 80;

function clip(s, n = MAX_LINE) {
  return String(s || '').replace(/\s+/g, ' ').trim().slice(0, n);
}

function buildWriterPrompt({ favorites, avoid, count }) {
  const saved = favorites.map((f) => {
    const theme = CATEGORIES[f.category] ? ` [${f.category}]` : '';
    const ref = f.book ? ` (${clip(f.book, 40)})` : '';
    return `- ${clip(f.text)}${ref}${theme}`;
  });
  const lines = [
    'The declarations this person saved:',
    ...saved,
    '',
    `Write ${count} new declarations for their week ahead.`,
  ];
  const avoidList = avoid.filter(Boolean).slice(-MAX_AVOID).map((t) => `- ${clip(t)}`);
  if (avoidList.length) {
    lines.push('', 'They already have these lines. Do not repeat or lightly reword any of them:', ...avoidList);
  }
  return lines.join('\n');
}

function buildJudgePrompt(items) {
  return items
    .map((it) => `id ${it.id}\nDeclaration: ${it.text}\nVerse (${it.reference}): ${it.verseText}`)
    .join('\n\n');
}

class ModelError extends Error {
  constructor(message, detail) {
    super(message);
    this.name = 'ModelError';
    this.detail = detail;
  }
}

async function callJson(client, { model, system, user, schema, effort, fallback }) {
  const body = {
    model,
    max_tokens: 16000,
    system: [{ type: 'text', text: system, cache_control: { type: 'ephemeral' } }],
    messages: [{ role: 'user', content: user }],
    output_config: { effort, format: { type: 'json_schema', schema } },
  };
  const options = {};
  if (fallback) {
    // On a safety-classifier decline, rerun on the fallback model in the
    // same call. Sonnet 5.5 takes the "default" form; Haiku has none.
    body.fallbacks = 'default';
    options.headers = { 'anthropic-beta': 'server-side-fallback-2026-07-01' };
  }
  const completion = await client.messages.create(body, options);
  if (completion.stop_reason !== 'end_turn') {
    throw new ModelError(`${model} stopped with ${completion.stop_reason}`, completion.stop_details);
  }
  const text = (completion.content || [])
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('');
  try {
    return { data: JSON.parse(text), usage: completion.usage || {} };
  } catch {
    throw new ModelError(`${model} returned invalid JSON`);
  }
}

/**
 * Wires both calls to an Anthropic client. `usage` accumulates token counts
 * across every call so the caller can store what a set cost.
 */
function makeModelDeps(client) {
  const usage = { inputTokens: 0, outputTokens: 0, calls: 0 };
  const track = (u) => {
    usage.inputTokens += (u.input_tokens || 0) + (u.cache_read_input_tokens || 0) + (u.cache_creation_input_tokens || 0);
    usage.outputTokens += u.output_tokens || 0;
    usage.calls += 1;
  };

  return {
    usage,
    async write(request) {
      const { data, usage: u } = await callJson(client, {
        model: WRITER_MODEL,
        system: WRITER_SYSTEM,
        user: buildWriterPrompt(request),
        schema: WRITER_SCHEMA,
        effort: 'medium',
        fallback: true,
      });
      track(u);
      return data;
    },
    async judge(items) {
      const { data, usage: u } = await callJson(client, {
        model: JUDGE_MODEL,
        system: JUDGE_SYSTEM,
        user: buildJudgePrompt(items),
        schema: JUDGE_SCHEMA,
        effort: 'low',
        fallback: false,
      });
      track(u);
      return data.verdicts;
    },
  };
}

module.exports = {
  makeModelDeps,
  buildWriterPrompt,
  buildJudgePrompt,
  callJson,
  ModelError,
  WRITER_MODEL,
  JUDGE_MODEL,
  WRITER_SCHEMA,
  JUDGE_SCHEMA,
};
