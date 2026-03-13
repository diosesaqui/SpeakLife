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
const CTAS = [
  "Save this for 6am when your brain starts spiraling 🙏",
  "Which declaration hit you hardest? Drop it below 👇",
  "Type AMEN if you needed this today.",
  "Share this with someone who's struggling right now.",
  "Save this. Come back to it when you need it most.",
  "Tag someone who needs to hear this today 👇",
  "Which one hit different? Tell me below.",
  "If this is for you, save it. Don't scroll past this.",
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

// ── Follow lines (rotate) ─────────────────────────────────────
// NOTE: @mention CTAs removed — Instagram rate-limits @mentions to 1 per day.
// Using mention in morning post blocks evening retries. Non-mention CTAs below.
const FOLLOWS = [
  "Save this for when the doubt gets loud.",
  "Download the SpeakLife app — link in bio.",
  "Share with someone who needs this today.",
  "Make this the first thing you read every morning.",
];

// ── Build caption ─────────────────────────────────────────────
function buildCaption(pillar, type, date) {
  const now = date ? new Date(date) : new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));

  const hooks = HOOKS[pillar] || HOOKS.anxiety;
  const hook = hooks[dayOfYear % hooks.length];

  const bridge = BRIDGES[pillar] || BRIDGES.anxiety;

  const hashtags = HASHTAGS[pillar] || HASHTAGS.anxiety;

  const cta = CTAS[dayOfYear % CTAS.length];
  const follow = FOLLOWS[dayOfYear % FOLLOWS.length];

  // Declarations vary slightly by type
  const declarations = {
    declaration: getDeclarations(pillar, dayOfYear),
    "god-speaks": getDeclarations(pillar, dayOfYear + 1),
    pov: getDeclarations(pillar, dayOfYear + 2),
  };

  const decl = declarations[type] || declarations.declaration;

  return [
    hook,
    "",
    bridge,
    "",
    decl,
    "",
    cta,
    "",
    follow,
    "",
    hashtags,
  ].join("\n");
}

function getDeclarations(pillar, seed) {
  const sets = {
    anxiety: [
      "I CAST MY ANXIETY ON GOD.\nHIS PEACE GUARDS MY HEART AND MIND.",
      "I DO NOT FEAR.\nGOD IS WITH ME, FOR ME, AND IN ME.",
      "MY MIND IS RENEWED.\nI WALK IN DIVINE PEACE, NOT PANIC.",
    ],
    healing: [
      "BY HIS STRIPES I AM HEALED.\nRESTORATION IS MY INHERITANCE.",
      "GOD IS RESTORING EVERYTHING.\nMY BODY, MY MIND, MY HEART.",
      "HEALING IS MINE.\nGOD'S POWER IS AT WORK IN ME NOW.",
    ],
    strength: [
      "I CAN DO ALL THINGS THROUGH CHRIST.\nHIS STRENGTH IS MADE PERFECT IN MY WEAKNESS.",
      "I AM STRONG IN THE LORD.\nHIS MIGHTY POWER WORKS THROUGH ME.",
      "I DON'T GIVE UP.\nGOD RENEWS MY STRENGTH DAILY.",
    ],
    purpose: [
      "I AM CHOSEN AND CALLED.\nGOD CREATED ME WITH SPECIFIC PURPOSE.",
      "MY LIFE IS NOT AN ACCIDENT.\nGOD'S PLAN FOR ME IS GOOD.",
      "I WALK IN MY CALLING.\nWHAT GOD PURPOSED FOR ME WILL STAND.",
    ],
    peace: [
      "I HAVE THE PEACE THAT PASSES UNDERSTANDING.\nIT GUARDS MY MIND RIGHT NOW.",
      "I REST IN GOD.\nHIS PEACE IS MY PORTION TODAY.",
      "MY MIND IS STILL.\nGOD HOLDS EVERYTHING I CAN'T CONTROL.",
    ],
    belonging: [
      "I AM CHOSEN. I AM SEEN. I BELONG TO GOD.\nMY PLACE IS SECURE.",
      "I WAS WANTED BEFORE THE WORLD BEGAN.\nGOD CHOSE ME ON PURPOSE.",
      "I AM NOT REJECTED.\nI AM ACCEPTED, LOVED, AND CALLED HIS OWN.",
    ],
    grief: [
      "GOD MEETS ME IN MY PAIN.\nHE COLLECTS EVERY TEAR. I AM NOT ALONE.",
      "JOY IS COMING.\nGOD IS CLOSE TO THE BROKENHEARTED.",
      "I GRIEVE WITH HOPE.\nGOD RESTORES WHAT WAS LOST.",
    ],
  };

  const pillarSets = sets[pillar] || sets.anxiety;
  return pillarSets[seed % pillarSets.length];
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
