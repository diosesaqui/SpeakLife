/**
 * bibleChat.js
 * Firebase Cloud Function (v2 HTTPS) — Bible Chat AI proxy.
 *
 * Why a proxy and not a direct device → Anthropic call:
 *   - The Anthropic API key never ships to the device (lives in Secret Manager).
 *   - Premium is verified server-side via RevenueCat (not spoofable).
 *   - Free-tier message limit + token usage are metered in Firestore.
 *   - The on-topic system prompt is cached (cache_control) for ~90% cheaper reads.
 *
 * ─── Setup ──────────────────────────────────────────────────────────────────
 *  1. npm install  (adds @anthropic-ai/sdk)
 *  2. Set secrets:
 *       firebase functions:secrets:set ANTHROPIC_API_KEY
 *       firebase functions:secrets:set REVENUECAT_SECRET_KEY   # RC v1 secret key
 *     (If REVENUECAT_SECRET_KEY is unset the function falls back to the client's
 *      isPremium claim — fine for a first deploy, less secure. Add it to harden.)
 *  3. firebase deploy --only functions:bibleChat
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const Anthropic = require('@anthropic-ai/sdk');

// prayerWallNotifications.js also calls initializeApp() at module load. When both
// are pulled in via index.js, guard against double-init.
if (getApps().length === 0) initializeApp();

const db = getFirestore();

// ─── Secrets ──────────────────────────────────────────────────────────────
const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');
const REVENUECAT_SECRET_KEY = defineSecret('REVENUECAT_SECRET_KEY');

// ─── Constants ──────────────────────────────────────────────────────────────
const MODEL = 'claude-haiku-4-5-20251001';
const MAX_TOKENS = 600;
const FREE_MESSAGE_LIMIT = 3;   // non-premium users get this many lifetime, then paywall
const WINDOW = 8;               // rolling window: last 8 messages (~4 exchanges)
const MAX_CHARS = 2000;         // per-message hard truncation (anti-abuse, bounds tokens)
const PREMIUM_ENTITLEMENT = 'premium';

// The on-topic biblical-counselor prompt. Cached server-side so repeat reads are
// ~10% of input cost. The strict topic guardrail keeps the model on faith/life
// challenges (no sports/trivia/chit-chat) — this is the real cost governor.
const SYSTEM_PROMPT = `You are a warm, biblically-grounded companion inside the SpeakLife app, used by over a million believers. You help people with real-life challenges — anxiety, fear, relationships, marriage, parenting, grief, purpose, identity, temptation, finances, loneliness, faith — always through the lens of Scripture.

HOW YOU RESPOND:
- Ground every answer in the Bible. Cite specific verses with references (NIV preferred). Quote the verse text when it helps.
- Be warm, encouraging, direct, and pastoral. Speak to the person's heart.
- Keep replies under ~220 words. Short and clear is powerful. Use a short prayer or a single reflective question when it fits.
- Meet people where they are. Acknowledge their pain before pointing to truth.

FORMATTING (this renders in a small chat bubble — keep it clean):
- Write in short, natural paragraphs. Do NOT use headings, bullet lists, or horizontal rules (no lines of dashes like "---").
- You may bold at most one or two key phrases with **double asterisks**. Don't over-format.
- Never use em dashes (—) or en dashes (–). Use periods or commas instead.

STRICT TOPIC BOUNDARY:
- You ONLY discuss faith, Scripture, prayer, God, and real-life struggles viewed through a biblical lens.
- If asked about off-topic subjects (sports, celebrities, coding, math, trivia, current events, politics, product help, or general chit-chat), gently decline in one sentence and redirect to how God's Word might speak to what they're really carrying. Do not answer the off-topic question.

SAFETY:
- Never give professional medical, legal, or financial advice. Point to prayer, Scripture, and a qualified professional.
- If someone expresses intent to harm themselves or others, respond with compassion, urge them to reach out to a crisis line or emergency services immediately, and remind them they are loved by God.

THE DECLARATION (what makes this app different):
Other Bible apps end with an answer. This one ends with something the person SAYS. Scripture works when it is spoken, not just understood, so when someone is carrying something real, close by handing them one line to speak out loud over it.

WHEN TO GIVE ONE:
- Give a declaration when the person is CARRYING something: fear, anxiety, sickness, grief, lack, temptation, a hard marriage, a wayward child, a decision, loneliness, shame, a closed door. Anything where Scripture speaks over their actual life.
- Do NOT give one when they are asking to UNDERSTAND something: what a passage means, who someone in the Bible was, historical or cultural context, the difference between two ideas, how a doctrine works, a translation question. Answer the question well and stop. Tacking a declaration onto "what does Melchizedek mean" is strange, and it cheapens the ones that matter.
- When a study question has a real situation underneath it ("what does the Bible say about divorce" from someone whose marriage is failing), answer the question FIRST. Offer the declaration only if they have made it personal.
- Never give one in a crisis or self-harm response. That moment needs presence and a real number to call, not a line to recite.
- At most one per conversation on the same subject. If you have already given them a declaration, do not close every following reply with another one. Give a fresh one only when the subject genuinely changes.

HOW TO WRITE ONE:
- Introduce it plainly, then give the line on its own. Something like: "Say this out loud over your day:"
- It must stand on the verse you just cited. Never promise what Scripture does not.
- First person, present tense, spoken as already true: "I have", "I am", "God has". Never "I will one day" or "I hope".
- ONE sentence, 10 to 18 words. Built for the mouth, not the eye. Say it out loud in your head before you write it.
- Plain words that land the first time. No poetry, no riddles, nothing the person has to decode.
- Never name the problem in the declaration. Do not mention the fear, the sickness, the lack. Declare the higher reality that displaces it, aimed at the place it lives: a racing mind gets a sound mind, a sick body gets healing, tight finances get provision.
- Two things Scripture never promises, so a declaration never claims them: that another free person will change or return, and any specific outcome no verse states. Declare God's faithfulness toward them and their own standing instead.

TAGGING THE DECLARATION (required whenever you give one):
After your reply, on its very last line and nothing after it, repeat the declaration as one line of JSON behind this exact marker:
[[SL_DECL]]{"text":"the declaration, word for word as written above","verse":"the verse text it stands on","reference":"Book Chapter:Verse","category":"one value from the list"}
- category is exactly one of: faith, fear, hope, health, wealth, wisdom, grace, addiction, confidence, godsprotection, rest, joy, hardtimes, parenting, identity, marriage, relationship, love, gratitude, purity, warfare, destiny, general. Pick the closest; use general when none fits.
- The marker line is stripped before the person ever sees it, so it is never part of what you write to them. It exists so the app can offer to save the declaration and speak it back to them every day.
- Omit the marker entirely when you did not give a declaration. Never emit it on an understanding question, and never on a crisis reply.`;

// ─── RevenueCat entitlement check (server-side, authoritative when reachable) ─
// Returns true/false when RC gives a definitive answer, or null when RC is
// unreachable/misconfigured (bad key, outage) so the caller can fall back to the
// client's premium claim instead of wrongly locking a paying user out.
async function isPremiumViaRevenueCat(appUserId, secretKey) {
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      { headers: { Authorization: `Bearer ${secretKey}` } }
    );
    if (!resp.ok) {
      console.warn(`RC lookup ${resp.status} for ${appUserId} — falling back to client claim`);
      return null;
    }
    const data = await resp.json();
    const ent = data && data.subscriber && data.subscriber.entitlements
      ? data.subscriber.entitlements[PREMIUM_ENTITLEMENT]
      : null;
    if (!ent) return false;
    // No expiry → lifetime/non-expiring. Otherwise active if expiry is future.
    if (!ent.expires_date) return true;
    return new Date(ent.expires_date).getTime() > Date.now();
  } catch (err) {
    console.error('RC check failed:', err.message);
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// bibleChat — POST { appUserId, messages:[{role,content}], isPremiumClaim? }
//   → { reply, needsPaywall, remainingFree, usage }
// ═══════════════════════════════════════════════════════════════════════════
exports.bibleChat = onRequest(
  {
    region: 'us-central1',
    cors: true,
    secrets: [ANTHROPIC_API_KEY, REVENUECAT_SECRET_KEY],
    timeoutSeconds: 30,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const body = req.body || {};
    const appUserId = typeof body.appUserId === 'string' ? body.appUserId.trim() : '';
    const rawMessages = Array.isArray(body.messages) ? body.messages : null;

    if (!appUserId || !rawMessages) {
      res.status(400).json({ error: 'missing appUserId or messages' });
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

    // Clamp to the rolling window, sanitize roles, hard-truncate each message.
    const messages = rawMessages
      .slice(-WINDOW)
      .map((m) => ({
        role: m && m.role === 'assistant' ? 'assistant' : 'user',
        content: String((m && m.content) || '').slice(0, MAX_CHARS).trim(),
      }))
      .filter((m) => m.content.length > 0);

    if (messages.length === 0 || messages[messages.length - 1].role !== 'user') {
      res.status(400).json({ error: 'last message must be a non-empty user message' });
      return;
    }

    // ─── Entitlement ─────────────────────────────────────────────────────
    // RevenueCat is authoritative when it answers; if it's unset, down, or the
    // secret is misconfigured, fall back to the client's premium flag rather
    // than locking out paying users.
    const rcKey = REVENUECAT_SECRET_KEY.value();
    let isPremium = body.isPremiumClaim === true;
    if (rcKey) {
      const rc = await isPremiumViaRevenueCat(appUserId, rcKey);
      if (rc !== null) isPremium = rc;
    }

    const usageRef = db.collection('bibleChatUsage').doc(appUserId);

    // ─── Free-tier gate (non-premium only) ───────────────────────────────
    let freeUsedBefore = 0;
    if (!isPremium) {
      const snap = await usageRef.get();
      freeUsedBefore = snap.exists ? snap.data().freeMessagesUsed || 0 : 0;
      if (freeUsedBefore >= FREE_MESSAGE_LIMIT) {
        res.json({ needsPaywall: true, remainingFree: 0 });
        return;
      }
    }

    // ─── Claude call ─────────────────────────────────────────────────────
    let reply = '';
    let usage = {};
    try {
      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      const completion = await client.messages.create({
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: [
          { type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } },
        ],
        messages,
      });
      reply = (completion.content || [])
        .filter((b) => b.type === 'text')
        .map((b) => b.text)
        .join('\n')
        .trim();
      usage = completion.usage || {};
    } catch (err) {
      console.error('Anthropic error:', err.message);
      res.status(502).json({ error: 'ai_unavailable' });
      return;
    }

    // ─── Pull the tagged declaration out of the reply ────────────────────
    // The model appends a machine-readable copy of any declaration it gave, so
    // the app can offer to save it as a real personal declaration instead of
    // leaving it as text in a bubble. Stripped here so the marker can never
    // reach a chat bubble, including when parsing fails.
    // Deliberately NOT anchored to the end of the reply. An end-anchored match
    // fails the moment the model writes one more sentence after the marker, and
    // the failure mode is the raw `[[SL_DECL]]{...}` rendered in a chat bubble.
    // Cut the matched span out wherever it lands, then scrub any residual
    // marker, so a mangled tag costs the save button and never the reply.
    let declaration = null;
    const declMatch = reply.match(/\[\[SL_DECL\]\]\s*(\{[\s\S]*?\})/);
    if (declMatch) {
      reply = (reply.slice(0, declMatch.index)
        + reply.slice(declMatch.index + declMatch[0].length)).trim();
      try {
        const parsed = JSON.parse(declMatch[1]);
        const text = typeof parsed.text === 'string' ? parsed.text.trim() : '';
        // A declaration with no line to speak is not a declaration. Everything
        // else degrades: the app falls back to `general` on an unknown category
        // and simply shows no verse when one is missing.
        if (text) {
          declaration = {
            text,
            verse: typeof parsed.verse === 'string' ? parsed.verse.trim() : '',
            reference: typeof parsed.reference === 'string' ? parsed.reference.trim() : '',
            category: typeof parsed.category === 'string' ? parsed.category.trim() : 'general',
          };
        }
      } catch (err) {
        // Malformed JSON costs the save button, not the answer.
        console.warn('Declaration tag parse failed:', err.message);
      }
    }
    reply = reply.replace(/\[\[SL_DECL\]\]/g, '').trim();

    if (!reply) {
      res.status(502).json({ error: 'empty_reply' });
      return;
    }

    // ─── Meter usage (and burn a free message only on success) ────────────
    const update = {
      lastUsedAt: FieldValue.serverTimestamp(),
      totalMessages: FieldValue.increment(1),
      inputTokens: FieldValue.increment(usage.input_tokens || 0),
      outputTokens: FieldValue.increment(usage.output_tokens || 0),
      cacheReadTokens: FieldValue.increment(usage.cache_read_input_tokens || 0),
      cacheWriteTokens: FieldValue.increment(usage.cache_creation_input_tokens || 0),
    };
    if (!isPremium) update.freeMessagesUsed = FieldValue.increment(1);
    await usageRef.set(update, { merge: true });

    // Derive remaining count from the value we already read — avoids a second
    // round-trip (and a crash if the doc were deleted in between).
    const remainingFree = isPremium
      ? null
      : Math.max(0, FREE_MESSAGE_LIMIT - (freeUsedBefore + 1));

    res.json({
      reply,
      declaration,
      needsPaywall: false,
      remainingFree,
      usage: {
        inputTokens: usage.input_tokens || 0,
        outputTokens: usage.output_tokens || 0,
        cacheReadTokens: usage.cache_read_input_tokens || 0,
      },
    });
  }
);
