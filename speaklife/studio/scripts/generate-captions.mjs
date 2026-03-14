#!/usr/bin/env node
/**
 * SpeakLife Caption Generator
 * Generates captions for organic content — hook-first, CTA-last, broad hashtags.
 *
 * Usage:
 *   node generate-captions.mjs --pillar <name> --type <declaration|god-speaks|pov> [--date YYYY-MM-DD]
 */
import { writeFileSync, mkdirSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const STUDIO    = resolve(__dirname, "..");
const WORKSPACE = resolve(STUDIO, "..", "..");

const PILLAR_NAMES = ["anxiety", "healing", "strength", "purpose", "peace", "belonging", "grief"];

// ── Engagement CTAs (rotate by day) ──────────────────────────
// Tip #6: Mid-thought entry — CTAs feel like they're in the middle of something
const CTAS = [
  "Save this. You'll need it at 2am.",
  "Which one hit you? Drop it below 👇",
  "Type AMEN if God sent this to your feed today.",
  "Share this with someone who's fighting their own mind right now.",
  "Save this. The enemy knows you'll forget it when you need it most.",
  "Tag someone who needs this — not tomorrow, right now 👇",
  "Which declaration are you taking into today? Tell me.",
  "Don't scroll past this one. Save it.",
  "Screenshot this. Put it somewhere you'll see it tomorrow morning.",
  "Reply PEACE if you're claiming this today.",
];

// ── Hashtags: max 5 (Instagram limit) ────────────────────────
const HASHTAGS = {
  anxiety:   "#SpeakLife #FaithOverFear #AnxietyRelief #ChristianWomen #MorningMotivation",
  healing:   "#SpeakLife #HealingJourney #GodsRestoration #ChristianWomen #MorningMotivation",
  strength:  "#SpeakLife #GodsStrength #OvercomerFaith #ChristianWomen #MorningMotivation",
  purpose:   "#SpeakLife #ChristianPurpose #ChosenByGod #ChristianWomen #MorningMotivation",
  peace:     "#SpeakLife #GodsPeace #InnerPeace #ChristianWomen #MorningMotivation",
  belonging: "#SpeakLife #ChosenByGod #ChristianIdentity #ChristianWomen #MorningMotivation",
  grief:     "#SpeakLife #GriefFaith #HopeInDarkness #ChristianWomen #MorningMotivation",
};

// ── Hooks: multiple per pillar, rotate by day ─────────────────
const HOOKS = {
  anxiety: [
    "If you woke up this morning and your first thought was dread — this is for you.",
    "That heavy feeling in your chest before the day even starts? God sees it.",
    "Your mind was spiraling before your feet hit the floor. This is what God says about that.",
    "You've been white-knuckling through something God never asked you to carry alone.",
    "The anxiety isn't a sign God abandoned you. It's an invitation to cast it.",
    "You've been fighting your own mind every morning. There's a better weapon.",
    "If your brain won't stop racing, read these slowly. Out loud if you can.",
  ],
  healing: [
    "You've been waiting for your body — or your heart — to catch up to your faith.",
    "Healing isn't always instant. But God is always moving.",
    "The wound is real. So is the One who restores.",
    "If you're in a season of recovery, these declarations are yours.",
    "Say this over yourself today. Your healing is already bought.",
    "God doesn't just forgive. He restores. Completely.",
    "You didn't come this far to stay broken. Declare this.",
  ],
  strength: [
    "You're not tired because you're weak. You're tired because you've been carrying too much.",
    "If you feel like you have nothing left — God's strength is specifically for this moment.",
    "The thing trying to knock you down doesn't know who's holding you up.",
    "You're still standing. That itself is a testimony. Now declare this.",
    "Strength isn't absence of fear. It's declaring the Word anyway.",
    "You've made it through 100% of your hardest days. Declare what got you here.",
    "Tired is temporary. God's strength in you is not.",
  ],
  purpose: [
    "You've been wondering if you're in the wrong life. You're not. Read this.",
    "Your purpose wasn't an afterthought. God planned it before you were born.",
    "If you feel invisible and unnecessary, this is what's actually true about you.",
    "You weren't created to just survive. You were made for something specific.",
    "God didn't make you by accident. Not one detail of you was random.",
    "Stop waiting to feel ready. Your calling doesn't require your confidence — it requires your yes.",
    "The world needs what only you carry. Declare this today.",
  ],
  peace: [
    "Peace isn't the absence of chaos. It's knowing Who holds it all.",
    "You don't have to figure everything out today. Declare this instead.",
    "The situation hasn't changed. But you have access to a peace that defies it.",
    "Your mind doesn't have to race just because the world does.",
    "If you can't seem to slow down, this is what God says about rest.",
    "Peace that passes understanding means it won't make sense — and it'll still be there.",
    "Stop trying to manufacture calm. Receive it. Declare it.",
  ],
  belonging: [
    "You've walked into rooms and felt invisible. God has never once not seen you.",
    "You were not an accident. You were chosen. Read this until it lands.",
    "If rejection has been following you — this is the truth that breaks its power.",
    "You belong to something no one can take from you.",
    "Chosen. Called. Placed on purpose. Declare it.",
    "The world may have made you feel like an afterthought. God made you a priority.",
    "You are not too much. You are not too little. You are exactly who God made.",
  ],
  grief: [
    "If you're walking through the darkest season of your life, these declarations are yours.",
    "God doesn't ask you to pretend it doesn't hurt. He meets you in the middle of it.",
    "Grief and faith aren't opposites. Declare this through both.",
    "You are allowed to mourn. And you are allowed to still believe.",
    "Even in the valley — especially in the valley — God is here.",
    "The loss is real. So is the God who collects every tear.",
    "You're not losing faith. You're discovering how deep it goes.",
  ],
};

// ── Bridges: pillar-specific ──────────────────────────────────
const BRIDGES = {
  anxiety: "God didn't create you to white-knuckle your way through life.\n\nHis peace isn't something you achieve. It's something you receive — and declare.",
  healing: "Healing is not just physical. It's the complete restoration of everything the enemy stole — your peace, your identity, your joy.\n\nDeclare it over yourself today.",
  strength: "God's strength doesn't wait until you feel strong.\n\nIt shows up most in the moments you're sure you have nothing left.",
  purpose: "You weren't placed here by accident. Every detail of your life — including the painful parts — is being woven into something purposeful.\n\nDeclare who you were made to be.",
  peace: "The peace God gives isn't dependent on your circumstances.\n\nIt guards your mind when everything is unraveling. Declare it until your body believes it.",
  belonging: "Before you performed, before you succeeded, before you had anything to show — God chose you.\n\nYou have always belonged to Him.",
  grief: "God is not distant from your pain. He entered it.\n\nYou don't have to be okay to declare the truth. Declare it especially when you're not.",
};

// ── Open Loops (Tip #2: end with a tease pointing to the next post) ──────────
// These replace the old FOLLOWS — creates anticipation, brings people back
const OPEN_LOOPS = {
  anxiety: [
    "Tomorrow I'm dropping the one for when it hits at 3am. Follow so you don't miss it.",
    "Next one is the declaration for when your brain won't let you sleep. Follow.",
    "Tomorrow: what to declare when the spiral starts before your feet hit the floor.",
    "Part of a series. If this helped, follow — there's one coming for every kind of fear.",
  ],
  healing: [
    "Tomorrow I'm sharing the declaration for when healing is taking longer than you expected.",
    "Next post: what to say over your body when the doctors' report says one thing and God says another.",
    "Follow for tomorrow's — it's for the ones healing from something they can't explain to anyone.",
    "Part of a series on restoration. Follow so you get every part.",
  ],
  strength: [
    "Tomorrow: the declaration for when you've already tried everything and still feel empty.",
    "Next one is for the people who are tired of being strong. Follow.",
    "Follow for tomorrow — it's the one for when the strength you had last week is gone.",
    "Part of a strength series. Each one builds on the last. Follow.",
  ],
  purpose: [
    "Tomorrow I'm posting the declaration for when you feel like you missed your window. Follow.",
    "Next post: what to declare when everyone around you seems to be walking in their calling and you're still waiting.",
    "Follow for tomorrow — it's for the ones who know they were made for something but can't see it yet.",
    "Part of a series on calling. This one gets deeper tomorrow.",
  ],
  peace: [
    "Tomorrow: the declaration for when peace feels impossible because the situation is genuinely bad.",
    "Next one is for the overthinkers who can't stop even when they want to. Follow.",
    "Follow for tomorrow — it's the one for when peace feels like a luxury you can't afford.",
    "Part of a peace series. Tomorrow we go deeper into what guarded means.",
  ],
  belonging: [
    "Tomorrow: the declaration for the person who has felt invisible their entire life.",
    "Next post is for anyone who's ever felt like they were born into the wrong family, city, life.",
    "Follow for tomorrow — it's for the ones rejection follows everywhere they go.",
    "Part of a belonging series. The next one is the hardest and the most important.",
  ],
  grief: [
    "Tomorrow I'm sharing what to declare when you're grieving something no one knows about.",
    "Next one is for the people who smile in public and fall apart in private. Follow.",
    "Follow for tomorrow — it's for grief that doesn't have a name or a timeline.",
    "Part of a grief series. Tomorrow: what to say when hope feels disrespectful to the loss.",
  ],
};

// ── Past-post callbacks (Tip #3: casual reference to previous content) ────────
const CALLBACKS = {
  anxiety: [
    "If you saved last week's anxiety declarations, this one picks up where that left off.",
    "If you've been here for the fear series, this is the next level.",
    "This builds on what I posted earlier this week about what to do at 3am.",
  ],
  healing: [
    "If you caught the healing post from earlier this week, this is the declaration that follows it.",
    "This one connects to the restoration series I've been running.",
    "Following up on the healing declarations — this one is specifically for the waiting.",
  ],
  strength: [
    "This is part of the strength series — if you missed Monday's, go find it on my page.",
    "Continuing from earlier this week on what to declare when you're running out of strength.",
    "This builds on the previous strength post. Worth going back to read both.",
  ],
  purpose: [
    "If you read the purpose post from earlier, this takes it further.",
    "Continuing the calling series — each post unlocks the next one.",
    "This is part 2 of what I started earlier this week about how God sees your purpose.",
  ],
  peace: [
    "This connects to the peace series I've been running all week.",
    "If you saved the peace declaration from earlier, declare this one right after it.",
    "Following up on the anxiety post — this is what you declare once you've cast it.",
  ],
  belonging: [
    "If you found the belonging post from earlier, this is what comes after it.",
    "Part of the identity series — they build on each other. Check my page for the full set.",
    "This continues from what I shared about rejection earlier this week.",
  ],
  grief: [
    "This is connected to the grief series — if you missed the earlier posts, they're on my page.",
    "Following up on the loss declaration from earlier this week.",
    "Part 2 of the grief series. The first one is still pinned on my page.",
  ],
};

// ── Build caption ─────────────────────────────────────────────
// Implements all 6 Netflix-binge retention tips:
// 1. Series naming (pillar + series day)
// 2. Open loop at the end (tease tomorrow's post)
// 3. Occasional callback to past posts
// 4. Signature mid-thought hook style
// 5. 5 declarations (more value per post)
// 6. Mid-thought entry — drop in like the conversation already started
function buildCaption(pillar, type, date) {
  const now = date ? new Date(date) : new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));

  const hooks = HOOKS[pillar] || HOOKS.anxiety;
  const hook = hooks[dayOfYear % hooks.length];

  const bridge = BRIDGES[pillar] || BRIDGES.anxiety;
  const hashtags = HASHTAGS[pillar] || HASHTAGS.anxiety;
  const cta = CTAS[dayOfYear % CTAS.length];

  // Tip #2: Open loop — rotate through pillar-specific teasers
  const loops = OPEN_LOOPS[pillar] || OPEN_LOOPS.anxiety;
  const openLoop = loops[Math.floor(dayOfYear / 3) % loops.length];

  // Tip #3: Callback — include ~every 3rd day to feel natural, not spammy
  const callbackSets = CALLBACKS[pillar] || CALLBACKS.anxiety;
  const callback = (dayOfYear % 3 === 0) ? callbackSets[Math.floor(dayOfYear / 3) % callbackSets.length] : null;

  // Tip #1: Series naming — pillar "day" within a 7-day cycle
  const pillarDayInCycle = (dayOfYear % 7) + 1;
  const SERIES_NAMES = {
    anxiety:   "THE ANXIETY SERIES",
    healing:   "THE HEALING SERIES",
    strength:  "THE STRENGTH SERIES",
    purpose:   "THE PURPOSE SERIES",
    peace:     "THE PEACE SERIES",
    belonging: "THE BELONGING SERIES",
    grief:     "THE GRIEF SERIES",
  };
  const seriesName = SERIES_NAMES[pillar] || "THE DECLARATION SERIES";
  const seriesTag = `${seriesName} · Part ${pillarDayInCycle}`;

  // Tip #5: 5 declarations per post (more value)
  const decl = getDeclarations(pillar, type === "god-speaks" ? dayOfYear + 1 : type === "pov" ? dayOfYear + 2 : dayOfYear, 5);

  const parts = [
    // Tip #4: Signature opening (hook is already mid-thought style)
    hook,
    "",
    // Tip #3: Callback (every 3rd day)
    ...(callback ? [callback, ""] : []),
    bridge,
    "",
    decl,
    "",
    cta,
    "",
    // Tip #2: Open loop
    openLoop,
    "",
    // Tip #1: Series tag
    seriesTag,
    "",
    hashtags,
  ];

  return parts.join("\n");
}

// Tip #5: Expanded declaration pools — 7+ per pillar, return 5 at a time
function getDeclarations(pillar, seed, count = 5) {
  const sets = {
    anxiety: [
      "I CAST MY ANXIETY ON GOD.\nHIS PEACE GUARDS MY HEART AND MIND.",
      "I DO NOT FEAR.\nGOD IS WITH ME, FOR ME, AND IN ME.",
      "MY MIND IS RENEWED.\nI WALK IN DIVINE PEACE, NOT PANIC.",
      "ANXIETY HAS NO AUTHORITY OVER ME.\nI AM RULED BY THE SPIRIT, NOT MY THOUGHTS.",
      "I RECEIVE THE PEACE THAT PASSES UNDERSTANDING.\nIT IS MINE RIGHT NOW.",
      "I DO NOT CARRY WHAT GOD NEVER ASKED ME TO.\nI RELEASE IT. ALL OF IT.",
      "MY MIND BELONGS TO CHRIST.\nEVERY THOUGHT SUBMITS TO HIS TRUTH.",
    ],
    healing: [
      "BY HIS STRIPES I AM HEALED.\nRESTORATION IS MY INHERITANCE.",
      "GOD IS RESTORING EVERYTHING.\nMY BODY, MY MIND, MY HEART.",
      "HEALING IS MINE.\nGOD'S POWER IS AT WORK IN ME NOW.",
      "I AM NOT DEFINED BY THIS DIAGNOSIS.\nI AM DEFINED BY WHAT GOD SAYS.",
      "EVERY CELL IN MY BODY RESPONDS TO THE WORD OF GOD.\nI AM HEALED.",
      "THE SAME POWER THAT RAISED JESUS IS IN ME.\nIT IS HEALING ME NOW.",
      "I RECEIVE COMPLETE RESTORATION.\nNOTHING THE ENEMY STOLE STAYS STOLEN.",
    ],
    strength: [
      "I CAN DO ALL THINGS THROUGH CHRIST.\nHIS STRENGTH IS MADE PERFECT IN MY WEAKNESS.",
      "I AM STRONG IN THE LORD.\nHIS MIGHTY POWER WORKS THROUGH ME.",
      "I DON'T GIVE UP.\nGOD RENEWS MY STRENGTH DAILY.",
      "WHEN I AM WEAK, HE IS STRONG IN ME.\nI AM NOT DEPENDENT ON MY OWN RESERVES.",
      "I RISE ABOVE EVERY OBSTACLE.\nGOD'S STRENGTH IN ME IS LIMITLESS.",
      "I WILL NOT COLLAPSE UNDER THIS PRESSURE.\nGOD IS HOLDING ME UP.",
      "TIRED IS TEMPORARY.\nGOD'S STRENGTH IN ME IS PERMANENT.",
    ],
    purpose: [
      "I AM CHOSEN AND CALLED.\nGOD CREATED ME WITH SPECIFIC PURPOSE.",
      "MY LIFE IS NOT AN ACCIDENT.\nGOD'S PLAN FOR ME IS GOOD.",
      "I WALK IN MY CALLING.\nWHAT GOD PURPOSED FOR ME WILL STAND.",
      "I WAS MADE FOR THIS SEASON.\nGOD PLACED ME HERE ON PURPOSE.",
      "MY GIFTS ARE NOT WASTED.\nGOD IS USING EVERYTHING — EVEN THIS.",
      "I DO NOT COMPARE MY PATH TO ANYONE ELSE'S.\nMY CALLING IS MINE ALONE.",
      "THE DELAY IS NOT DENIAL.\nGOD'S TIMING IS PERFECT FOR MY LIFE.",
    ],
    peace: [
      "I HAVE THE PEACE THAT PASSES UNDERSTANDING.\nIT GUARDS MY MIND RIGHT NOW.",
      "I REST IN GOD.\nHIS PEACE IS MY PORTION TODAY.",
      "MY MIND IS STILL.\nGOD HOLDS EVERYTHING I CAN'T CONTROL.",
      "I RELEASE CONTROL AND RECEIVE PEACE.\nGOD IS WORKING IN WHAT I CANNOT SEE.",
      "PEACE IS MY INHERITANCE.\nI WALK IN IT REGARDLESS OF MY CIRCUMSTANCES.",
      "I CHOOSE PEACE OVER PANIC.\nGOD'S PRESENCE IS MY ANCHOR.",
      "I AM NOT MOVED BY WHAT I SEE.\nI AM ANCHORED IN WHAT GOD SAYS.",
    ],
    belonging: [
      "I AM CHOSEN. I AM SEEN. I BELONG TO GOD.\nMY PLACE IS SECURE.",
      "I WAS WANTED BEFORE THE WORLD BEGAN.\nGOD CHOSE ME ON PURPOSE.",
      "I AM NOT REJECTED.\nI AM ACCEPTED, LOVED, AND CALLED HIS OWN.",
      "I DO NOT NEED HUMAN APPROVAL TO KNOW MY WORTH.\nGOD SETTLED IT.",
      "I BELONG TO THE MOST HIGH GOD.\nNO REJECTION CAN CHANGE THAT.",
      "I AM FULLY KNOWN AND FULLY LOVED.\nTHERE IS NOTHING I NEED TO HIDE.",
      "I WALK INTO EVERY ROOM KNOWING I AM CHOSEN.\nGOD SENT ME HERE.",
    ],
    grief: [
      "GOD MEETS ME IN MY PAIN.\nHE COLLECTS EVERY TEAR. I AM NOT ALONE.",
      "JOY IS COMING.\nGOD IS CLOSE TO THE BROKENHEARTED.",
      "I GRIEVE WITH HOPE.\nGOD RESTORES WHAT WAS LOST.",
      "MY MOURNING WILL TURN TO DANCING.\nGOD PROMISED IT AND HE KEEPS HIS WORD.",
      "THE LOSS IS REAL.\nSO IS THE GOD WHO REDEEMS EVERY PAINFUL THING.",
      "I AM NOT CONSUMED BY THIS GRIEF.\nGOD'S MERCIES ARE NEW EVERY MORNING.",
      "BEAUTY WILL COME FROM THESE ASHES.\nI BELIEVE IT EVEN WHEN I CAN'T SEE IT.",
    ],
  };

  const all = sets[pillar] || sets.anxiety;
  // Rotate through the pool, returning `count` consecutive declarations
  const start = seed % all.length;
  const result = [];
  for (let i = 0; i < count; i++) {
    result.push(all[(start + i) % all.length]);
  }
  return result.join("\n\n");
}

// ── CLI Args ─────────────────────────────────────────────────
function parseArgs() {
  const args = process.argv.slice(2);
  const r = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--pillar" && args[i+1]) r.pillar = args[++i];
    if (args[i] === "--type"   && args[i+1]) r.type   = args[++i];
    if (args[i] === "--out"    && args[i+1]) r.out    = args[++i];
    if (args[i] === "--date"   && args[i+1]) r.date   = args[++i];
  }
  return r;
}

function resolvePillar(input) {
  if (!input) return "anxiety";
  const n = input.toLowerCase().replace(/[^a-z]/g, "");
  return PILLAR_NAMES.find(p => p === n || n.startsWith(p.slice(0, 4))) || "anxiety";
}

function resolveType(input) {
  if (!input) return "declaration";
  const t = input.toLowerCase();
  if (t.includes("god") || t.includes("speak")) return "god-speaks";
  if (t.includes("pov")) return "pov";
  return "declaration";
}

// ── Main ─────────────────────────────────────────────────────
const args       = parseArgs();
const pillarName = resolvePillar(args.pillar);
const typeName   = resolveType(args.type);
const TODAY      = args.date || new Date().toISOString().slice(0, 10);

const baseDir = resolve(WORKSPACE, "speaklife/output/captions", TODAY);
mkdirSync(baseDir, { recursive: true });
const outPath = args.out || resolve(baseDir, `${typeName}-${pillarName}.txt`);

try {
  const caption = buildCaption(pillarName, typeName, TODAY);
  writeFileSync(outPath, caption, "utf-8");
  console.log(`Caption written: ${outPath}`);
  console.log(`\nPreview:\n${"─".repeat(60)}\n${caption}\n${"─".repeat(60)}`);
  process.exit(0);
} catch (e) {
  console.error("Failed:", e.message);
  process.exit(1);
}
