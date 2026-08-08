/**
 * declarationMatch.js
 * Firebase Cloud Function (v2 HTTPS) — Personalized Declaration generator proxy.
 *
 * Why a proxy and not a direct device → Anthropic call:
 *   - The Anthropic API key never ships to the device (lives in Secret Manager).
 *     It used to arrive via Remote Config, which meant a usable key sat on every
 *     phone with no spend cap behind it.
 *   - The declaration-writing rules (CLAUDE.md) live server-side, so tightening
 *     the voice is a function deploy, not an App Store release.
 *   - Per-user call volume and token usage are metered in Firestore.
 *   - The rules prompt is cached (cache_control) for ~90% cheaper reads.
 *
 * Why this is a separate file from bibleChat.js and not a mode flag:
 *   The two need different abuse controls. Bible Chat gates on a RevenueCat
 *   entitlement plus a lifetime free-message cap. This matcher runs during
 *   ONBOARDING, before anyone has purchased anything, so every caller is free by
 *   definition and there is no entitlement to check. The bound here is a plain
 *   per-appUserId daily rate limit.
 *
 * ─── Setup ──────────────────────────────────────────────────────────────────
 *  1. npm install  (already has @anthropic-ai/sdk)
 *  2. Set the secret (shared with bibleChat — same Anthropic key, one place):
 *       firebase functions:secrets:set ANTHROPIC_API_KEY
 *  3. firebase deploy --only functions:declarationMatch
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const Anthropic = require('@anthropic-ai/sdk');

// bibleChat.js and prayerWallNotifications.js also call initializeApp() at
// module load. When all are pulled in via index.js, guard against double-init.
if (getApps().length === 0) initializeApp();

const db = getFirestore();

// ─── Secrets ──────────────────────────────────────────────────────────────
const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');

// ─── Constants ──────────────────────────────────────────────────────────────
const MODEL = 'claude-haiku-4-5-20251001';
const MAX_TOKENS = 512;
const MAX_CHARS = 1000;          // hard truncation of the user's need (bounds tokens)
const DAILY_LIMIT = 5;           // generations per appUserId per rolling 24h
const WINDOW_MS = 24 * 60 * 60 * 1000;

// Valid category rawValues. Must stay in sync with DeclarationCategory in
// Models/DailyDeclaration.swift — the client maps an unknown value to .faith,
// so a drift here degrades silently rather than crashing, but keep it exact.
const CATEGORIES = [
  'health', 'wealth', 'anxiety', 'fear', 'love', 'relationship', 'marriage',
  'parenting', 'destiny', 'identity', 'rest', 'joy', 'favor', 'grace',
  'godsprotection', 'warfare', 'addiction', 'confidence', 'wisdom',
  'innerHealing', 'spiritualGrowth', 'miracles', 'hardtimes', 'friendship',
  'purity', 'hope', 'grief', 'fertility', 'salvation', 'education', 'housing',
  'divorce', 'wellness', 'mentalHealth', 'forgiveness', 'newSeason',
  'singleParent', 'anger', 'faith', 'debt', 'business', 'work', 'praise',
  'gratitude',
];

// The declaration-writing rules, lifted from CLAUDE.md (the same standard every
// declaration in declarationsv10.json is held to) plus the bibleChat safety
// block. Cached server-side so repeat reads are ~10% of input cost, which is
// why the whole ruleset can live here instead of being trimmed for token cost.
const SYSTEM_PROMPT = `You are the declaration writer for SpeakLife, a Christian faith app used by over a million believers daily. Given a person's prayer need or spiritual struggle, you write ONE personalized declaration they will speak aloud over their own life every day, plus the scripture it stands on.

VOICE — speak it like Jesus:
- These are spoken out loud, with the authority Jesus carried when He healed and delivered. His words were short, direct, and final: "Be clean." "Get up." "Be opened."
- Built for the mouth, not the eye. Every line must be easy to say in one breath, with a rhythm the tongue wants to follow.
- Faith speaks it done. Say the outcome as finished and already possessed, never requested. "I have." "I am." "It is mine."

HARD RULES:
- First person ONLY: I / me / my / mine. Never "you" or "your". References to what God does toward the speaker are fine ("God knows the plans He has for me").
- Present and active tense: "I am", "I walk", "I have", "I receive". Never past memories, never future wishes.
- Bold and direct. No weak qualifiers: no "maybe", "I think", "I hope to", "I'm trying".
- No em dashes and no en dashes. Use periods to separate thoughts.
- NIV Bible preferred for the verse text. Quote it exactly. Never invent or paraphrase a verse, and never cite a reference you are not certain of.

BREVITY IS POTENCY:
- One or two sentences. Most declarations land at 12 to 18 words, hard ceiling around 21.
- Never say the same truth twice. If a closing sentence only rephrases the one before it, delete it.
- Land the image and stop. Do not explain a metaphor after it hits.
- Every word earns its place or dies. Strip filler and connective padding.

CALL HIGHER — declare the greater reality:
- Never name the low thing. Do not call out worry, fear, sickness, lack, or shame, even to overrule it. Skip straight to the higher reality that displaces it.
- Declare exactly what is to come to pass, as already true. Concrete and scriptural, never vague.
- Hit the exact domain the need lives in. Anxiety lives in the mind, so declare a sound mind. Sickness lives in the body. Provision lives in the finances.
- Bad: "Worry, settle down. My heart grows quiet in Him." Good: "I have the mind of Christ. It is clear, sound, and at rest."
- Exception: the warfare category may command the enemy directly, the way Jesus did in deliverance. Broad umbrella promises like "No weapon formed against me prospers" are allowed everywhere.

EMOTIONAL RESONANCE — never apathy:
- The one reaction a declaration must never produce is indifference. It must stir something real: awe, courage, comfort, holy defiance, joy, or gratitude that genuinely moves.
- Use concrete, vivid, embodied language over abstract theology. Let them feel the weight of the promise, not just read it.

VOCABULARY — rich, never obscure:
- Words that carry weight and stay clear: rooted, sealed, unshakeable, anchored, redeemed, radiant, dwelling, revive, breathe, whole, free, established, called.
- Cut anything churchy, academic, or seminary-only. The speaker must never stop to ask what a word means.

PERFECTLY CLEAR — say what you mean:
- Every declaration must be understood instantly, the first time, by anyone. This outranks cleverness and style.
- No poetry, no riddles. "I am undone", "grace saved me with empty hands", "lit from the inside" are fog. Name the real thing plainly.
- Plain beats pretty, every time.

SAFETY:
- Never give professional medical, legal, or financial advice, and never tell anyone to stop treatment or ignore a professional. Declare God's promise over the area and leave the counsel to prayer, Scripture, and a qualified professional.
- If the person expresses intent to harm themselves or others, do NOT return a declaration. Instead return the salvation category with declarationText urging them, with compassion, to contact a crisis line or emergency services right now, and reminding them they are loved by God and their life matters.

CATEGORIES — pick the single closest one and return the exact string, nothing else:
${CATEGORIES.join(', ')}

Respond ONLY with valid JSON. No markdown, no code fences, no explanation. Exact format:
{"category":"categoryname","declarationText":"First-person declaration here.","verseText":"Exact scripture text here.","verseReference":"Book Chapter:Verse"}`;

// Pulls the JSON object out of the model's text. The prompt forbids code fences,
// but a stray "Here you go:" preamble would otherwise break JSON.parse — mirror
// the client's old extractJSON and slice from the first { to the last }.
function extractJSON(text) {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end < start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch (err) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// declarationMatch — POST { appUserId, input }
//   → { category, declarationText, verseText, verseReference, remainingToday, usage }
//   → 429 { error: 'rate_limited', retryAfterSeconds } when the daily cap is hit
// ═══════════════════════════════════════════════════════════════════════════
exports.declarationMatch = onRequest(
  {
    region: 'us-central1',
    cors: true,
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const body = req.body || {};
    const appUserId = typeof body.appUserId === 'string' ? body.appUserId.trim() : '';
    const rawInput = typeof body.input === 'string' ? body.input : '';

    if (!appUserId || !rawInput.trim()) {
      res.status(400).json({ error: 'missing appUserId or input' });
      return;
    }

    // appUserId is used directly as a Firestore document ID. Reject anything
    // that would make .doc() throw synchronously (slashes, dot segments, or
    // oversized) before it reaches the collection call.
    if (appUserId.length > 1500 || appUserId.includes('/') ||
        appUserId === '.' || appUserId === '..') {
      res.status(400).json({ error: 'invalid appUserId' });
      return;
    }

    // Hard-truncate the need. Onboarding sends a sentence or two; anything past
    // MAX_CHARS is either a paste or an attempt to stuff the context window.
    const input = rawInput.slice(0, MAX_CHARS).trim();

    const usageRef = db.collection('declarationMatchUsage').doc(appUserId);
    const now = Date.now();

    // ─── Rate limit (rolling 24h, per appUserId) ─────────────────────────
    // No entitlement check exists here — this runs before any purchase. We keep
    // a bounded array of the last few call timestamps and count the ones inside
    // the window. A rolling window (rather than a UTC-day bucket) avoids the
    // midnight reset that would let someone burn 2x the cap back to back.
    //
    // Like bibleChat, the read-check happens before the model call and the write
    // after it, so two truly simultaneous requests can both pass a check at the
    // limit. Worst case is one extra generation, which is an acceptable trade
    // for not paying for a transaction on every call.
    const snap = await usageRef.get();
    const priorCalls = snap.exists && Array.isArray(snap.data().recentCallsAt)
      ? snap.data().recentCallsAt.filter((t) => typeof t === 'number' && now - t < WINDOW_MS)
      : [];

    if (priorCalls.length >= DAILY_LIMIT) {
      const oldest = Math.min(...priorCalls);
      const retryAfterSeconds = Math.max(1, Math.ceil((oldest + WINDOW_MS - now) / 1000));
      res.set('Retry-After', String(retryAfterSeconds));
      res.status(429).json({ error: 'rate_limited', retryAfterSeconds });
      return;
    }

    // ─── Claude call ─────────────────────────────────────────────────────
    let parsed = null;
    let usage = {};
    try {
      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      const completion = await client.messages.create({
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: [
          { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
        ],
        messages: [{ role: 'user', content: `User need: ${input}` }],
      });
      const text = (completion.content || [])
        .filter((b) => b.type === 'text')
        .map((b) => b.text)
        .join('\n')
        .trim();
      parsed = extractJSON(text);
      usage = completion.usage || {};
    } catch (err) {
      console.error('Anthropic error:', err.message);
      res.status(502).json({ error: 'ai_unavailable' });
      return;
    }

    // Shape check before anything reaches the device. The client falls back to
    // its local keyword matcher on any non-200, so a malformed generation is a
    // clean degrade rather than a broken declaration on someone's home screen.
    if (!parsed || typeof parsed.declarationText !== 'string' ||
        typeof parsed.verseText !== 'string' ||
        typeof parsed.verseReference !== 'string' ||
        !parsed.declarationText.trim()) {
      console.error('Unparseable declaration payload from model');
      res.status(502).json({ error: 'invalid_generation' });
      return;
    }

    // An off-list category would decode to .faith on the client anyway; pin it
    // here so the analytics we log server-side match what the app records.
    const category = CATEGORIES.includes(parsed.category) ? parsed.category : 'faith';

    // ─── Meter usage (and burn a call only on success) ────────────────────
    // recentCallsAt is rewritten (not incremented) because it's a windowed
    // array; the counters alongside it are lifetime totals, same as bibleChat.
    await usageRef.set({
      recentCallsAt: [...priorCalls, now].slice(-DAILY_LIMIT),
      lastUsedAt: FieldValue.serverTimestamp(),
      totalMatches: FieldValue.increment(1),
      inputTokens: FieldValue.increment(usage.input_tokens || 0),
      outputTokens: FieldValue.increment(usage.output_tokens || 0),
      cacheReadTokens: FieldValue.increment(usage.cache_read_input_tokens || 0),
      cacheWriteTokens: FieldValue.increment(usage.cache_creation_input_tokens || 0),
    }, { merge: true });

    res.json({
      category,
      declarationText: parsed.declarationText.trim(),
      verseText: parsed.verseText.trim(),
      verseReference: parsed.verseReference.trim(),
      remainingToday: Math.max(0, DAILY_LIMIT - (priorCalls.length + 1)),
      usage: {
        inputTokens: usage.input_tokens || 0,
        outputTokens: usage.output_tokens || 0,
        cacheReadTokens: usage.cache_read_input_tokens || 0,
      },
    });
  }
);
