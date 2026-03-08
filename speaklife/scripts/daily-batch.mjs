#!/usr/bin/env node
/**
 * SpeakLife Daily Batch — 10 static ads
 * Runs Mon–Fri, delivers here (topic 2) for Franchiz review before posting
 *
 * Output:
 *   - 7 Scripture Quote Cards (social proof PAUSED — no new reviews yet)
 *   - 3 Slideshows (carousel format, 5 slides each)
 *
 * Social proof: PAUSED until Franchiz provides new reviews
 */
import { execSync } from "child_process";
import { createReadStream, readFileSync, mkdirSync, writeFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";
import FormData from "form-data";
import https from "https";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT    = resolve(__dirname, "..");
const STUDIO  = resolve(ROOT, "studio");
const OUT_BASE = resolve(ROOT, "output");

// ── Telegram ──────────────────────────────────────────────
const CONFIG_PATH = "/home/node/.openclaw/openclaw.json";
const TG_CHAT    = "-1003748448073";
const TG_THREAD  = 292;

function getBotToken() {
  const cfg = JSON.parse(readFileSync(CONFIG_PATH, "utf-8"));
  return cfg.channels?.telegram?.botToken;
}

function tgPost(endpoint, body) {
  const token = getBotToken();
  const url = `https://api.telegram.org/bot${token}/${endpoint}`;
  const data = JSON.stringify(body);
  return new Promise((res, rej) => {
    const req = https.request(url, { method: "POST", headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(data) } }, (r) => {
      let s = ""; r.on("data", d => s += d); r.on("end", () => res(JSON.parse(s)));
    });
    req.on("error", rej); req.write(data); req.end();
  });
}

function tgSendText(text) {
  return tgPost("sendMessage", { chat_id: TG_CHAT, message_thread_id: TG_THREAD, text, parse_mode: "HTML" });
}

function tgSendPhoto(filePath, caption) {
  const token = getBotToken();
  return new Promise((res, rej) => {
    const form = new FormData();
    form.append("chat_id", TG_CHAT);
    form.append("message_thread_id", String(TG_THREAD));
    form.append("caption", caption || "");
    form.append("photo", createReadStream(filePath));
    const url = `https://api.telegram.org/bot${token}/sendPhoto`;
    const req = https.request(url, { method: "POST", headers: form.getHeaders() }, (r) => {
      let s = ""; r.on("data", d => s += d); r.on("end", () => res(JSON.parse(s)));
    });
    req.on("error", rej); form.pipe(req);
  });
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Date helpers ──────────────────────────────────────────
const DAY_NAMES = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
const PILLARS   = { 1:"identity", 2:"anxiety", 3:"destiny", 4:"joy", 5:"confidence", 6:"wisdom", 0:"anxiety" };

// ── Quote card verses by category ─────────────────────────
const VERSE_POOL = {
  anxiety: [
    { verse: "Do not be anxious about anything, but in every situation, by prayer and petition, present your requests to God.", reference: "Philippians 4:6" },
    { verse: "Cast all your anxiety on Him because He cares for you.", reference: "1 Peter 5:7" },
    { verse: "The Lord is my light and my salvation — whom shall I fear?", reference: "Psalm 27:1" },
  ],
  identity: [
    { verse: "I am fearfully and wonderfully made; your works are wonderful, I know that full well.", reference: "Psalm 139:14" },
    { verse: "You are a chosen people, a royal priesthood, a holy nation, God's special possession.", reference: "1 Peter 2:9" },
    { verse: "Before I formed you in the womb I knew you, before you were born I set you apart.", reference: "Jeremiah 1:5" },
  ],
  confidence: [
    { verse: "I can do all things through Christ who strengthens me.", reference: "Philippians 4:13" },
    { verse: "God has not given us a spirit of fear, but of power and of love and of a sound mind.", reference: "2 Timothy 1:7" },
    { verse: "Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you.", reference: "Joshua 1:9" },
  ],
  joy: [
    { verse: "The joy of the Lord is your strength.", reference: "Nehemiah 8:10" },
    { verse: "Rejoice in the Lord always. I will say it again: Rejoice!", reference: "Philippians 4:4" },
    { verse: "You make known to me the path of life; you will fill me with joy in your presence.", reference: "Psalm 16:11" },
  ],
  destiny: [
    { verse: "For I know the plans I have for you, plans to prosper you and not to harm you, plans to give you hope and a future.", reference: "Jeremiah 29:11" },
    { verse: "And we know that in all things God works for the good of those who love Him.", reference: "Romans 8:28" },
    { verse: "Many are the plans in a person's heart, but it is the Lord's purpose that prevails.", reference: "Proverbs 19:21" },
  ],
  wisdom: [
    { verse: "If any of you lacks wisdom, you should ask God, who gives generously to all without finding fault.", reference: "James 1:5" },
    { verse: "Trust in the Lord with all your heart and lean not on your own understanding.", reference: "Proverbs 3:5" },
    { verse: "Your word is a lamp for my feet, a light on my path.", reference: "Psalm 119:105" },
  ],
};

// ── Slideshow configs by category ─────────────────────────
// UPGRADED SLIDE CONFIGS — Virality DNA v2
// Hooks: revelation-style, not listicle. Truths: counterintuitive plot twist first.
// Slide 5 CTA: engagement trigger ("Type PEACE if this hit")
const SLIDE_CONFIGS = {
  anxiety: {
    category: "anxiety",
    hookText: "Why praying harder isn't fixing your anxiety",
    truths: [
      {
        title: "Anxiety is not a faith failure",
        explanation: "Scripture never says anxious people lack faith. Even Jesus was troubled in spirit. Anxiety is a signal, not a sin.",
        scripture: "John 11:33 — Jesus was deeply moved in spirit."
      },
      {
        title: "Peace isn't the absence of chaos",
        explanation: "Jesus gave His disciples peace in the same breath He promised tribulation. His peace coexists with the storm — it doesn't remove it.",
        scripture: "John 16:33 — In me you may have peace."
      },
      {
        title: "The weapon is your words",
        explanation: "Casting anxiety on God isn't passive. It's an active declaration. The mouth that names the fear is the mouth that silences it.",
        scripture: "1 Peter 5:7 — Cast all your anxiety on Him."
      },
    ],
    ctaText: "Speak God's Word over your anxiety every morning",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `You've been white-knuckling through something God never asked you to carry alone.

Swipe through — these 3 truths changed how I see anxiety.

Type PEACE in the comments if this hit you.

Download SpeakLife FREE and start speaking God's Word over your anxiety every single morning.
Link in bio.

Share this with someone who needs to hear it today.

#SpeakLife #AnxietyFaith #FaithOverFear #GodsPeace #ChristianWomen #BibleVerses`,
  },
  identity: {
    category: "identity",
    hookText: "The thing no one tells you about who God says you are",
    truths: [
      {
        title: "God chose you before you could earn it",
        explanation: "Your identity wasn't decided by your behavior. It was decided before the foundation of the world, before you did anything right or wrong.",
        scripture: "Ephesians 1:4 — Chosen before creation."
      },
      {
        title: "You can't disqualify yourself",
        explanation: "The enemy's biggest lie is that you've gone too far. But God's calling is irrevocable. Your worst chapter doesn't cancel your destiny.",
        scripture: "Romans 11:29 — His gifts are irrevocable."
      },
      {
        title: "Your opinion of yourself isn't the final word",
        explanation: "When you call yourself unworthy, you're contradicting the Creator. God said you're fearfully and wonderfully made — that's not up for debate.",
        scripture: "Psalm 139:14 — Fearfully and wonderfully made."
      },
    ],
    ctaText: "Start every morning knowing who God says you are",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `The world spent years building a case against who you are.

Swipe through — 3 things God says about you that are not up for debate.

Type CHOSEN in the comments if this landed.

Start every morning with declarations that remind you who God says you are. Download SpeakLife FREE.
Link in bio.

Share this with someone who needs to know they are chosen.

#SpeakLife #ChristianIdentity #YouAreEnough #ChosenByGod #ChristianWomen #BibleVerses`,
  },
  confidence: {
    category: "confidence",
    hookText: "What God actually says when you feel invisible",
    truths: [
      {
        title: "Timidity is not humility",
        explanation: "The church taught us that shrinking back is holy. But God said He gave you a spirit of power. Playing small isn't modesty — it wastes what He put in you.",
        scripture: "2 Timothy 1:7 — Power, love, sound mind."
      },
      {
        title: "The same power that raised Jesus lives in you",
        explanation: "This is not a metaphor. The resurrection power — the most violent force in all of creation — is active inside you right now.",
        scripture: "Romans 8:11 — His Spirit lives in you."
      },
      {
        title: "You are already more than a conqueror",
        explanation: "Not 'will be.' Not 'trying to be.' Romans says you ARE more than a conqueror — present tense. Walk into every room knowing that.",
        scripture: "Romans 8:37 — More than a conqueror."
      },
    ],
    ctaText: "Speak boldness over your life before you start your day",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `Playing small was never God's plan for you.

Swipe through — 3 truths about the power God placed inside you.

Type BOLD in the comments if this woke something up.

Speak boldness over your life every morning. Download SpeakLife FREE.
Link in bio.

Share this with someone who needs to walk into today knowing who they are.

#SpeakLife #FaithAndConfidence #ChristianWomen #PowerInChrist #BibleVerses #GodsPower`,
  },
  joy: {
    category: "joy",
    hookText: "The verse about joy that nobody reads in context",
    truths: [
      {
        title: "Paul wrote 'Rejoice always' from prison",
        explanation: "Philippians 4:4 wasn't written from a comfortable life. It was written in chains. That changes everything about what joy actually means.",
        scripture: "Philippians 4:4 — Rejoice in the Lord always."
      },
      {
        title: "Joy is not the same as happiness",
        explanation: "Happiness depends on what happens. Joy is a fruit — something grown in you by the Spirit, unaffected by your circumstances.",
        scripture: "Galatians 5:22 — Fruit of the Spirit is joy."
      },
      {
        title: "God is rejoicing over you right now",
        explanation: "While you're questioning if God is pleased with you, Zephaniah 3:17 says He's singing over you with joy. Let that land.",
        scripture: "Zephaniah 3:17 — He rejoices over you with singing."
      },
    ],
    ctaText: "Declare joy over your life — every single morning",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `Paul wrote "Rejoice always" from a prison cell. Let that change how you read that verse.

Swipe through — 3 truths about joy that your circumstances can't touch.

Type JOY in the comments if this hit you.

Declare joy over your life every single morning. Download SpeakLife FREE.
Link in bio.

Share this with someone who needs a reminder that joy runs deeper than their situation.

#SpeakLife #JoyInChrist #ChristianWomen #FruitOfTheSpirit #BibleVerses #ChooseJoy`,
  },
  destiny: {
    category: "destiny",
    hookText: "Your setback is not what it looks like",
    truths: [
      {
        title: "God uses detours on purpose",
        explanation: "Israel took a 40-year detour to a destination 11 days away. The detour WAS the preparation. Your delay is not rejection.",
        scripture: "Deuteronomy 8:2 — God led you through the wilderness."
      },
      {
        title: "What the enemy meant to end you is your testimony",
        explanation: "Joseph was sold by his brothers. That betrayal became the exact mechanism God used to save nations. Your pit is often the path.",
        scripture: "Genesis 50:20 — Meant for evil, God used for good."
      },
      {
        title: "God finishes what He starts",
        explanation: "He didn't bring you this far to abandon you. The same God who started the work has committed to completing it.",
        scripture: "Philippians 1:6 — He who began a good work."
      },
    ],
    ctaText: "Declare your destiny every morning with SpeakLife",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `Your delay is not your denial. Your setback is not your ending.

Swipe through — 3 truths about what God is actually doing in your waiting season.

Type PURPOSE in the comments if this hit home.

Declare your destiny every morning. Download SpeakLife FREE.
Link in bio.

Share this with someone in a season that doesn't make sense yet.

#SpeakLife #GodsPlan #FaithInTheWait #ChristianWomen #BibleVerses #TrustGod`,
  },
  wisdom: {
    category: "wisdom",
    hookText: "The one thing wise people do before they respond",
    truths: [
      {
        title: "Silence is often the most powerful answer",
        explanation: "Proverbs says even a fool seems wise when he holds his tongue. Strategic silence isn't weakness — it's one of the most underrated forms of strength.",
        scripture: "Proverbs 17:28 — Even a fool seems wise when silent."
      },
      {
        title: "God gives wisdom to those who ask — without shame",
        explanation: "James 1:5 is one of the most generous promises in scripture. Ask for wisdom. He won't remind you how many times you should have known better.",
        scripture: "James 1:5 — He gives generously, without finding fault."
      },
      {
        title: "Your life is the evidence",
        explanation: "Wisdom isn't what you know. It's what your life produces. Jesus said wisdom is proved right by her children — the fruit speaks.",
        scripture: "Matthew 11:19 — Wisdom is proved right by her deeds."
      },
    ],
    ctaText: "Start every day with God's Word guiding your decisions",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `Wisdom isn't what you know. It's what your life produces.

Swipe through — 3 things Scripture says about walking in real wisdom.

Type WISDOM in the comments if this landed.

Let God's Word guide every decision you make. Download SpeakLife FREE.
Link in bio.

Share this with someone who needs clarity right now.

#SpeakLife #BiblicalWisdom #ChristianWomen #BibleVerses #GodGivesWisdom #FaithAndLife`,
  },
  relationships: {
    category: "relationships",
    hookText: "Why God heals some relationships and lets others end",
    truths: [
      {
        title: "Not every connection is a covenant",
        explanation: "Jesus loved Judas, served him, washed his feet — and still let him go. Love doesn't always mean holding on. Discernment is also love.",
        scripture: "Proverbs 4:23 — Guard your heart above all else."
      },
      {
        title: "Forgiveness doesn't require reconciliation",
        explanation: "You can release someone in your spirit completely and still keep a safe distance. Forgiveness is for your freedom — not a guarantee of restoration.",
        scripture: "Colossians 3:13 — Forgive as the Lord forgave you."
      },
      {
        title: "God restores what belongs to your destiny",
        explanation: "The relationships God authored, He can restore. What He didn't design, He won't force. Trust His editing of your story.",
        scripture: "Joel 2:25 — I will restore what the locust has eaten."
      },
    ],
    ctaText: "Let God's Word guide every relationship in your life",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `Not every relationship is meant to be restored. Some endings are God's protection.

Swipe through — 3 hard truths about relationships that Scripture actually teaches.

Type RESTORE in the comments if this gave you clarity.

Let God's Word guide every relationship in your life. Download SpeakLife FREE.
Link in bio.

Share this with someone navigating a hard season in a relationship.

#SpeakLife #ChristianRelationships #Forgiveness #ChristianWomen #BibleVerses #GodHeals`,
  },
  renewal: {
    category: "renewal",
    hookText: "What God says when you feel like starting over is too late",
    truths: [
      {
        title: "His mercies are literally new every morning",
        explanation: "Lamentations 3:23 is not a comfort quote. It's a daily reset. Every single morning you wake up, the slate is clean. That is not a small thing.",
        scripture: "Lamentations 3:23 — New every morning."
      },
      {
        title: "Transformation starts in the mind, not the behavior",
        explanation: "Romans 12:2 says be transformed by the renewing of your mind — not by trying harder. Change the input, the output changes itself.",
        scripture: "Romans 12:2 — Renewing of the mind."
      },
      {
        title: "God specializes in making things new",
        explanation: "Revelation 21:5 says 'I am making everything new' — present tense, active. He's not waiting until heaven. He's doing it now, in you.",
        scripture: "Revelation 21:5 — I am making everything new."
      },
    ],
    ctaText: "Renew your mind every morning with God's Word",
    ctaSubtext: "Download FREE on App Store >> Share this with someone who needs it",
    postCaption: `It is not too late to start again. His mercies are new every single morning.

Swipe through — 3 truths about what God does with the things you thought were over.

Type NEW in the comments if this is your season.

Renew your mind every morning with God's Word. Download SpeakLife FREE.
Link in bio.

Share this with someone who needs a fresh start today.

#SpeakLife #RenewYourMind #NewBeginnings #ChristianWomen #BibleVerses #GodMakesNew`,
  },
};

// ── Social proof rotation ──────────────────────────────────
const SOCIAL_PROOF_FILES = [
  { file: "kyla-facebook.png",   caption: "⭐ Real user — Kyla Clark" },
  { file: "sandy-thoughts.png",  caption: "⭐ Real user — Sandy" },
  { file: "kathy-transforming.png", caption: "⭐ Real user — KathyAnn" },
  { file: "lissa-share.png",     caption: "⭐ Real user — Lissa" },
  { file: "veevee-heaven.png",   caption: "⭐ Real user — 12Veevee12" },
  { file: "crash-holyspirit.png", caption: "⭐ Real user — Crash 7371" },
  { file: "edgar-getthrough.png", caption: "⭐ Real user — Edgar" },
];

// ── Main ───────────────────────────────────────────────────
async function run() {
  const today = new Date();
  const dow   = today.getDay(); // 0=Sun
  const dateStr = today.toISOString().slice(0,10);
  const dayName = DAY_NAMES[dow];
  const pillar  = PILLARS[dow] || "anxiety";

  console.log(`\n🚀 SpeakLife Daily Batch — ${dayName} ${dateStr}`);
  console.log(`   Pillar: ${pillar}\n`);

  const outDir = resolve(OUT_BASE, `batch-${dateStr}`);
  const qcDir  = resolve(outDir, "quote-cards");
  const slDir  = resolve(outDir, "slides");
  mkdirSync(qcDir, { recursive: true });
  mkdirSync(slDir, { recursive: true });

  // ── 1. Pick 5 quote card verses (5 categories) ──────────
  const categories = ["anxiety","identity","confidence","joy","destiny"];
  const dayOffset  = Math.floor(today.getTime() / 86400000); // rotate by day
  const qcCards = categories.map((cat, i) => {
    const pool = VERSE_POOL[cat] || [];
    return { category: cat, ...pool[(dayOffset + i) % pool.length] };
  });

  // Write and render quote cards
  const qcJson = resolve(outDir, "quote-cards.json");
  writeFileSync(qcJson, JSON.stringify({ cards: qcCards }, null, 2));
  execSync(`node ${STUDIO}/scripts/render-quote-card.mjs --cards ${qcJson} --out ${qcDir}`, { stdio: "inherit" });

  // ── 2. Pick 3 slideshow themes ───────────────────────────
  const slideCategories = [pillar, categories[(categories.indexOf(pillar) + 1) % 5], categories[(categories.indexOf(pillar) + 2) % 5]];
  const slidePaths = [];

  for (const cat of slideCategories) {
    const cfg = { backgroundImage: "bg-main.jpg", ...SLIDE_CONFIGS[cat] };
    const cfgPath = resolve(outDir, `slide-${cat}.json`);
    const catDir  = resolve(slDir, cat);
    mkdirSync(catDir, { recursive: true });
    writeFileSync(cfgPath, JSON.stringify(cfg, null, 2));
    execSync(`node ${STUDIO}/scripts/render-canvas.mjs --config ${cfgPath} --out ${catDir} --prefix ${cat}`, { stdio: "inherit" });
    slidePaths.push({ cat, dir: catDir });
  }

  // ── 3. Pick 2 extra quote cards (wisdom + second pillar) — social proof PAUSED ──
  const extraCategories = ["wisdom", categories[(categories.indexOf(pillar) + 3) % 5]];
  const extraCards = extraCategories.map((cat, i) => {
    const pool = VERSE_POOL[cat] || VERSE_POOL["anxiety"];
    return { category: cat, ...pool[(dayOffset + i + 2) % pool.length] };
  });
  const allQcCards = [...qcCards, ...extraCards];
  const allQcJson = resolve(outDir, "quote-cards-all.json");
  writeFileSync(allQcJson, JSON.stringify({ cards: allQcCards }, null, 2));
  execSync(`node ${STUDIO}/scripts/render-quote-card.mjs --cards ${allQcJson} --out ${qcDir}`, { stdio: "inherit" });

  // ── 4. Deliver to Telegram (topic 2 — for Franchiz review) ──
  console.log("\n📤 Delivering to Operations for review...");

  await tgSendText(`📦 <b>Daily Batch — ${dayName} ${dateStr}</b>
Pillar: <b>${pillar.toUpperCase()}</b>
─────────────────────
📖 7 Quote Cards · 🎠 3 Carousels
⚠️ Social proof paused — awaiting new reviews from Franchiz
Review below before uploading to Facebook Ads.`);
  await sleep(1000);

  // Quote cards (7 total)
  await tgSendText("📖 <b>Quote Cards (single image ads)</b>");
  for (const card of allQcCards) {
    const slug = card.reference.replace(/[^a-z0-9]/gi, "-").toLowerCase();
    const file = resolve(qcDir, `${slug}.png`);
    await tgSendPhoto(file, `${card.category.toUpperCase()} — ${card.reference}`);
    await sleep(1500);
  }

  // Carousels
  for (const { cat, dir } of slidePaths) {
    const cfg = SLIDE_CONFIGS[cat] || {};
    const postCaption = cfg.postCaption || `Download SpeakLife FREE — link in bio.\nShare this with someone who needs it today.\n#SpeakLife`;

    await tgSendText(
      `🎠 <b>Carousel — ${cat.toUpperCase()}</b>\n` +
      `Upload all 5 slides as a carousel ad.\n\n` +
      `📝 <b>Post Caption (copy/paste):</b>\n` +
      `<pre>${postCaption}</pre>`
    );
    await sleep(1000);

    for (let i = 1; i <= 5; i++) {
      const label = i === 5 ? `Slide 5/5 — CTA (Download + Share)` : `Slide ${i}/5`;
      await tgSendPhoto(resolve(dir, `${cat}-slide-${i}.png`), label);
      await sleep(1500);
    }
  }

  await tgSendText("✅ <b>Batch complete.</b> Upload to Facebook and run 3–5 days. Kill &lt;1% CTR after $30 spend.");
  console.log("\n✅ Daily batch done.\n");
}

run().catch(e => { console.error(e); process.exit(1); });
