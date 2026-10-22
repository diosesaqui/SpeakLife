/**
 * categoryDevotional.js
 * Firebase Cloud Function (v2 HTTPS) — a fresh daily devotional in the
 * category the user picked (marriage, anxiety, health, ...).
 *
 * The bundled devotionals.json gives everyone the same devotional for the
 * calendar day. This gives each user one written for the thing they are
 * actually carrying, in the same shape: title, a verse line ("<verse> - Ref"),
 * and ~320 words that open on a hook, teach the verse, and close on a prayer.
 *
 * One devotional per user, per category, per local day:
 *   - The first request of the day generates it and stores it in Firestore.
 *   - Every later request that day (reopening the screen, a second device,
 *     a reinstall) returns the stored copy, so a day costs at most one call
 *     per category.
 *   - The last few titles and verses in that category are fed back to the
 *     model so the user does not get Philippians 4:6 five days running.
 *
 * ─── Setup ──────────────────────────────────────────────────────────────────
 *  Uses the same secrets as bibleChat (ANTHROPIC_API_KEY, REVENUECAT_SECRET_KEY).
 *    firebase deploy --only functions:generateCategoryDevotional
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const Anthropic = require('@anthropic-ai/sdk');
const { isPremiumViaRevenueCat } = require('./lib/revenueCat');

if (getApps().length === 0) initializeApp();

const db = getFirestore();

const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');
const REVENUECAT_SECRET_KEY = defineSecret('REVENUECAT_SECRET_KEY');

const MODEL = 'claude-opus-5-5';
const MAX_TOKENS = 16000;
// Free users get this many category devotionals, lifetime, then the paywall.
// The daily calendar devotional stays free exactly as before.
const FREE_LIMIT = 1;
// How many past devotionals in the same category to show the model.
const HISTORY_WINDOW = 14;

const COLLECTION = 'categoryDevotionals';

// Life-situation categories only. Keys match DeclarationCategory raw values on
// iOS. The focus line aims the devotional at the place the issue lives
// (CLAUDE.md rule 12): anxiety is the mind, sickness the body, lack the money.
const CATEGORIES = {
  faith:          { name: 'Faith',                     focus: 'growing, unshakeable faith that takes God at His word' },
  identity:       { name: 'Identity in Christ',        focus: 'who the reader is in Christ: chosen, loved, righteous, a new creation' },
  love:           { name: 'Love & Belonging',          focus: "the Father's love and the reader's secure place in His family" },
  grace:          { name: 'Grace & Forgiveness',       focus: 'grace that forgives completely and frees from guilt and condemnation' },
  rest:           { name: 'Peace & Rest',              focus: 'the peace of God guarding the heart and mind, and rest in Him' },
  anxiety:        { name: 'Anxiety & Worry',           focus: 'a sound, settled mind and the peace that guards it' },
  fear:           { name: 'Fear Not',                  focus: 'courage, boldness and safety in God' },
  hope:           { name: 'Hope & Endurance',          focus: 'living hope and strength to keep going' },
  joy:            { name: 'Joy',                       focus: 'the joy of the Lord as the reader\'s strength' },
  health:         { name: 'Healing & Health',          focus: 'healing in the body, by His wounds, and strength rising in it' },
  wealth:         { name: 'Provision & Finances',      focus: 'God as provider, and abundance in the reader\'s finances' },
  debt:           { name: 'Freedom from Debt',         focus: 'freedom from financial bondage and God\'s provision' },
  work:           { name: 'Work & Career',             focus: 'favor, excellence and purpose in the reader\'s work' },
  business:       { name: 'Business & Calling',        focus: 'wisdom, increase and calling in building a business' },
  wisdom:         { name: 'Wisdom & Decisions',        focus: 'wisdom from God for real decisions' },
  destiny:        { name: 'Purpose & Destiny',         focus: 'God\'s purpose and calling over the reader\'s life' },
  marriage:       { name: 'Marriage',                  focus: 'a strong, loving, Christ-centered marriage' },
  relationship:   { name: 'Dating & Relationships',    focus: 'God\'s wisdom and timing in dating and relationships' },
  parenting:      { name: 'Parenting',                 focus: 'raising children in God\'s ways, and His promises over them' },
  singleParent:   { name: 'Single Parent',             focus: 'God\'s strength, provision and presence for a parent raising kids alone' },
  friendship:     { name: 'Friendship',                focus: 'godly friendship and community' },
  forgiveness:    { name: 'Forgiving Others',          focus: 'the freedom of forgiving as Christ forgave' },
  grief:          { name: 'Comfort in Loss',           focus: 'God\'s comfort in loss and the hope of resurrection' },
  hardtimes:      { name: 'Hard Times',                focus: 'God\'s faithfulness and strength through hard seasons' },
  innerHealing:   { name: 'Inner Healing',             focus: 'God healing the broken heart and restoring the soul' },
  mentalHealth:   { name: 'Mental Health',             focus: 'a sound mind, the mind of Christ, and peace' },
  addiction:      { name: 'Freedom from Addiction',    focus: 'freedom in Christ and a new nature that is no longer enslaved' },
  purity:         { name: 'Purity',                    focus: 'holiness, a clean heart and freedom from temptation' },
  anger:          { name: 'Peace Over Anger',          focus: 'self-control, patience and the peace of Christ ruling the heart' },
  godsprotection: { name: "God's Protection",          focus: 'God as shield, refuge and protector' },
  warfare:        { name: 'Spiritual Warfare',         focus: 'victory and authority in Christ over the enemy' },
  favor:          { name: 'Favor & Blessing',          focus: 'God\'s favor surrounding the reader like a shield' },
  miracles:       { name: 'Miracles & Breakthrough',   focus: 'the God who still does the impossible' },
  gratitude:      { name: 'Gratitude',                 focus: 'thankfulness and praise' },
  fertility:      { name: 'Believing for a Child',     focus: 'God\'s promises over the womb and a family' },
  salvation:      { name: 'Loved Ones to Salvation',   focus: 'God\'s heart and faithfulness toward unsaved loved ones' },
  newSeason:      { name: 'New Season',                focus: 'a fresh start and the new thing God is doing' },
  wellness:       { name: 'Body & Wellness',           focus: 'honoring God with the body, strength and discipline' },
  divorce:        { name: 'Healing After Divorce',     focus: 'restoration, worth and a future after divorce' },
  education:      { name: 'School & Study',            focus: 'wisdom, understanding and diligence in study' },
  housing:        { name: 'Home & Housing',            focus: 'God\'s provision of a home and a secure dwelling' },
  obedience:      { name: 'Surrender & Obedience',     focus: 'surrender to God and the blessing of obedience' },
};

// Mirrors the house style of the bundled devotionals.json and the rules in
// CLAUDE.md. Kept static so it caches; the per-request parts (category, date,
// history) go in the user message.
const SYSTEM_PROMPT = `You write the daily devotional for SpeakLife, a Christian app used by over a million believers. Each devotional is written for one reader who chose a topic because they are living it right now.

SHAPE (match it exactly):
- title: 2 to 6 words, plain and strong. No colon subtitles.
- verse: one Bible verse, quoted word for word (NIV preferred).
- reference: "Book Chapter:Verse".
- devotionalText: 280 to 360 words in 6 to 8 short paragraphs separated by a blank line.
  1. Open with one bold sentence that names the truth of the day and makes the reader lean in.
  2. Show who God is in this verse: the setting, what the words actually say, why it matters.
  3. Bring it into the reader's real life in their topic, concretely. Speak to them as "you".
  4. Give them the reason they can trust it (the cross, God's character, His track record).
  5. A short paragraph calling them to receive it and act on it today.
  6. Close with a first-person prayer of 2 to 4 sentences that declares the verse as already true, then "Amen. 💜" at the end.

VOICE:
- Warm, direct, pastoral, faith-filled. Grace-based, never guilt-based.
- Never soften a promise Scripture makes. If the verse says it, say it as finished. The only limit is what the verse actually promises.
- Call higher. Do not describe the reader's problem as their identity or as something they will keep holding. Name it only as already carried, defeated or displaced, and spend the words on the higher reality God gives.
- Never promise that another free person will change, return or believe, or any specific outcome no verse states. Declare God's faithfulness toward them instead.
- Plain words that land the first time. No churchy jargon, no poetic riddles.
- Never use em dashes or en dashes. Use periods or commas.
- No headings, bullet points, bold or markdown in devotionalText.
- Never give medical, legal or financial instructions. Faith, Scripture and prayer only.

Return only the JSON object.`;

const OUTPUT_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    verse: { type: 'string' },
    reference: { type: 'string' },
    devotionalText: { type: 'string' },
  },
  required: ['title', 'verse', 'reference', 'devotionalText'],
  additionalProperties: false,
};

// Safety net for the no-dashes rule: the prompt asks, this guarantees.
function stripDashes(text) {
  return text.replace(/\s*[—–]\s*/g, ', ');
}

function isValidDocId(id) {
  return id.length > 0 && id.length <= 1500 && !id.includes('/') && id !== '.' && id !== '..';
}

// ═══════════════════════════════════════════════════════════════════════════
// generateCategoryDevotional — POST { appUserId, category, localDate, isPremiumClaim? }
//   localDate is the device's own calendar day, "YYYY-MM-DD", so "today"
//   rolls over at the user's midnight rather than UTC's.
//   → { devotional: { title, devotionalText, books, category, localDate },
//       needsPaywall, remainingFree }
// ═══════════════════════════════════════════════════════════════════════════
exports.generateCategoryDevotional = onRequest(
  {
    region: 'us-central1',
    cors: true,
    secrets: [ANTHROPIC_API_KEY, REVENUECAT_SECRET_KEY],
    timeoutSeconds: 120,
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }

    const body = req.body || {};
    const appUserId = typeof body.appUserId === 'string' ? body.appUserId.trim() : '';
    const category = typeof body.category === 'string' ? body.category.trim() : '';
    const localDate = typeof body.localDate === 'string' ? body.localDate.trim() : '';

    if (!isValidDocId(appUserId)) {
      res.status(400).json({ error: 'invalid appUserId' });
      return;
    }
    const meta = CATEGORIES[category];
    if (!meta) {
      res.status(400).json({ error: 'unknown category' });
      return;
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(localDate)) {
      res.status(400).json({ error: 'localDate must be YYYY-MM-DD' });
      return;
    }

    const userRef = db.collection(COLLECTION).doc(appUserId);
    const dayRef = userRef.collection('days').doc(`${localDate}_${category}`);

    // ─── Already written today? Hand it back, free, before any gating ────
    // A free user who used their one devotional can still reread it today.
    const existing = await dayRef.get();
    if (existing.exists) {
      res.json({ devotional: existing.data().devotional, needsPaywall: false, remainingFree: null });
      return;
    }

    // ─── Entitlement ─────────────────────────────────────────────────────
    const rcKey = REVENUECAT_SECRET_KEY.value();
    let isPremium = body.isPremiumClaim === true;
    if (rcKey) {
      const rc = await isPremiumViaRevenueCat(appUserId, rcKey);
      if (rc !== null) isPremium = rc;
    }

    let freeUsedBefore = 0;
    if (!isPremium) {
      const snap = await userRef.get();
      freeUsedBefore = snap.exists ? snap.data().freeUsed || 0 : 0;
      if (freeUsedBefore >= FREE_LIMIT) {
        res.json({ needsPaywall: true, remainingFree: 0 });
        return;
      }
    }

    // ─── Recent history in this category, so it does not repeat ──────────
    // Filtered in memory rather than with a where() + orderBy() pair, which
    // would need a composite index on the subcollection. A user's last 60
    // days across all categories is a small read.
    const recent = await userRef
      .collection('days')
      .orderBy('createdAt', 'desc')
      .limit(60)
      .get()
      .catch((err) => {
        // A failed lookup must not cost the user their devotional.
        console.warn('History lookup failed:', err.message);
        return null;
      });
    const avoid = recent
      ? recent.docs
          .filter((d) => d.data().category === category)
          .slice(0, HISTORY_WINDOW)
          .map((d) => {
            const v = d.data().devotional || {};
            return `- "${v.title}" (${d.data().reference || ''})`;
          })
      : [];

    const userPrompt = [
      `Topic: ${meta.name}`,
      `Aim it at: ${meta.focus}.`,
      `Today is ${localDate}.`,
      avoid.length
        ? `This reader already received these devotionals in this topic. Use a different verse and a different angle:\n${avoid.join('\n')}`
        : 'This is the first devotional this reader has received in this topic.',
    ].join('\n');

    // ─── Claude call ─────────────────────────────────────────────────────
    let parsed;
    let usage = {};
    try {
      const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
      const completion = await client.messages.create(
        {
          model: MODEL,
          max_tokens: MAX_TOKENS,
          system: [{ type: 'text', text: SYSTEM_PROMPT, cache_control: { type: 'ephemeral' } }],
          messages: [{ role: 'user', content: userPrompt }],
          output_config: {
            effort: 'medium',
            format: { type: 'json_schema', schema: OUTPUT_SCHEMA },
          },
          // On a safety-classifier decline, re-run on the fallback model in
          // the same call instead of failing the reader's devotional.
          fallbacks: 'default',
        },
        { headers: { 'anthropic-beta': 'server-side-fallback-2026-07-01' } }
      );
      usage = completion.usage || {};
      if (completion.stop_reason !== 'end_turn') {
        console.warn('Devotional stop_reason:', completion.stop_reason);
        res.status(502).json({ error: 'ai_incomplete' });
        return;
      }
      const text = (completion.content || [])
        .filter((b) => b.type === 'text')
        .map((b) => b.text)
        .join('');
      parsed = JSON.parse(text);
    } catch (err) {
      console.error('Devotional generation failed:', err.message);
      res.status(502).json({ error: 'ai_unavailable' });
      return;
    }

    const title = stripDashes(String(parsed.title || '').trim()).slice(0, 120);
    const verse = String(parsed.verse || '').trim().slice(0, 600);
    const reference = String(parsed.reference || '').trim().slice(0, 80);
    const devotionalText = stripDashes(String(parsed.devotionalText || '').trim()).slice(0, 6000);
    if (!title || !devotionalText) {
      res.status(502).json({ error: 'empty_devotional' });
      return;
    }

    // Same shape as a devotionals.json entry, so the app renders it with the
    // existing view: books is "<verse> - <reference>".
    const devotional = {
      title,
      devotionalText,
      books: reference ? `${verse} - ${reference}` : verse,
      category,
      localDate,
    };

    // ─── Store, and burn the free one only on success ─────────────────────
    await dayRef.set({
      devotional,
      category,
      reference,
      createdAt: FieldValue.serverTimestamp(),
    });
    const update = {
      lastGeneratedAt: FieldValue.serverTimestamp(),
      totalGenerated: FieldValue.increment(1),
      inputTokens: FieldValue.increment(usage.input_tokens || 0),
      outputTokens: FieldValue.increment(usage.output_tokens || 0),
    };
    if (!isPremium) update.freeUsed = FieldValue.increment(1);
    await userRef.set(update, { merge: true });

    res.json({
      devotional,
      needsPaywall: false,
      remainingFree: isPremium ? null : Math.max(0, FREE_LIMIT - (freeUsedBefore + 1)),
    });
  }
);
