#!/usr/bin/env node
/**
 * SpeakLife Declare Angle Renderer — v2 (2026-03-16)
 *
 * Fixes:
 *   1. Rotating backgrounds from 12-image library (no more single AI image)
 *   2. Dynamic, curiosity-driven swipe prompt (not "DECLARE THESE SWIPE ->")
 *   3. Declaration slides = declarations ONLY (no scripture ref mixed in)
 *   4. Verse slide gets solo scripture focus
 *   5. Logo only on CTA slide; others get subtle wordmark watermark
 *   6. Alternating slide contrast for visual variety
 *
 * Format: 8 slides (hook + 5 declarations + verse + CTA)
 * Output: 1080x1350 PNGs (4:5 feed)
 */
import { createCanvas, loadImage, GlobalFonts } from "@napi-rs/canvas";
import { writeFileSync, mkdirSync, readFileSync, existsSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const STUDIO = resolve(__dirname, "..");
const FONTS  = resolve(STUDIO, "public/fonts");
const LOGO   = resolve(STUDIO, "public/logo.png");
const ANGLES = resolve(STUDIO, "public/ad-angles.json");
const BG_MANIFEST = resolve(STUDIO, "public/backgrounds/MANIFEST.json");
const BG_DIR      = resolve(STUDIO, "public/backgrounds");
// Fallback to old single BG if manifest missing
const BG_FALLBACK = resolve(STUDIO, "public/bg-main.jpg");

GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-ExtraBold.ttf"), "Display");
GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-Bold.ttf"),      "DisplayBold");
GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-SemiBold.ttf"),  "DisplaySemi");
GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-Regular.ttf"),   "DisplayReg");

const W = 1080, H = 1350;

const THEMES = {
  anxiety:   { accent: "#8B5CF6", glow: "rgba(139,92,246,0.20)" },
  healing:   { accent: "#3B82F6", glow: "rgba(59,130,246,0.20)"  },
  strength:  { accent: "#EF4444", glow: "rgba(239,68,68,0.20)"   },
  purpose:   { accent: "#F59E0B", glow: "rgba(245,158,11,0.20)"  },
  peace:     { accent: "#10B981", glow: "rgba(16,185,129,0.20)"  },
  belonging: { accent: "#EC4899", glow: "rgba(236,72,153,0.20)"  },
  grief:     { accent: "#94A3B8", glow: "rgba(148,163,184,0.20)" },
  default:   { accent: "#F5A623", glow: "rgba(245,166,35,0.20)"  },
};

// Curiosity-driven swipe prompts — forces the swipe, not just an instruction
const SWIPE_PROMPTS = {
  anxiety:   "SWIPE TO TAKE YOUR PEACE BACK",
  healing:   "SWIPE AND DECLARE YOUR HEALING",
  strength:  "SWIPE — DECLARE YOUR STRENGTH NOW",
  purpose:   "SWIPE INTO YOUR PURPOSE",
  peace:     "SWIPE AND SILENCE THE NOISE",
  belonging: "SWIPE — YOU WERE CHOSEN",
  grief:     "SWIPE — GOD SEES YOU RIGHT NOW",
  default:   "SWIPE TO SPEAK LIFE OVER THIS",
};

// ── Background selection ──────────────────────────────────────
const BG_HISTORY_FILE = resolve(BG_DIR, "usage-history.json");
const BG_AVOID_LAST_N = 2; // never repeat hook bg within last 2 posts

let _bgManifest = null;
function getBgManifest() {
  if (_bgManifest) return _bgManifest;
  if (existsSync(BG_MANIFEST)) {
    _bgManifest = JSON.parse(readFileSync(BG_MANIFEST, "utf-8"));
  } else {
    _bgManifest = [];
  }
  return _bgManifest;
}

function loadBgHistory() {
  if (existsSync(BG_HISTORY_FILE)) {
    try { return JSON.parse(readFileSync(BG_HISTORY_FILE, "utf-8")); } catch {}
  }
  return [];
}

function saveBgHistory(history) {
  writeFileSync(BG_HISTORY_FILE, JSON.stringify(history, null, 2));
}

/** Get the last N hook background names used (to avoid repeating them) */
function recentHookBgs(n = BG_AVOID_LAST_N) {
  const history = loadBgHistory();
  return history.slice(-n).map(h => h.hookBg).filter(Boolean);
}

/**
 * Pick a set of 3 backgrounds for this pillar + date.
 * Returns { hook, declarations, verse } — different bg for each section.
 * Deterministic by date so re-renders are consistent.
 */
function selectBackgrounds(pillar, dateStr, slotOffset = 0) {
  const manifest = getBgManifest();
  if (!manifest.length) return { hook: null, hookName: null, declarations: null, verse: null, cta: null };

  // slotOffset shifts the seed so morning/evening/midday never land on same images
  const seed = parseInt(dateStr.replace(/-/g, "").slice(-5), 10) + slotOffset * 1000;

  const pick = (pool, offset) => {
    const idx = (seed + offset) % pool.length;
    return pool[idx];
  };

  // ── Hook pool: people/intimate backgrounds (hooks are personal moments) ──
  // Tier 1 (preferred): devotional/reading/bible — intimate, quiet
  // Tier 2 (fallback): women worship — still people-focused, warm
  // Never use pure landscape/nature on hook (mismatch with emotional copy)
  const recentHooks = recentHookBgs(); // names to avoid
  const tier1 = manifest.filter(b =>
    b.name.includes("reading") || b.name.includes("bible") ||
    b.name.includes("devotional") || b.name.includes("window")
  );
  const tier2 = manifest.filter(b => b.name.includes("worship") || b.name.includes("woman"));
  let hookCandidates = tier1.length ? tier1 : (tier2.length ? tier2 : manifest);
  // Add tier2 as supplement so pool is large enough to avoid repeats
  const fullHookPool = [...new Map([...tier1, ...tier2].map(b => [b.name, b])).values()];

  // Remove recently used from hook pool — try tier1 first, then full pool
  let freshHookPool = tier1.filter(b => !recentHooks.includes(b.name));
  if (!freshHookPool.length) freshHookPool = fullHookPool.filter(b => !recentHooks.includes(b.name));
  if (!freshHookPool.length) freshHookPool = fullHookPool; // last resort: allow repeat

  const hookBg   = pick(freshHookPool, 0);

  // ── Declarations pool: nature/landscape ──
  const natureBgs = manifest.filter(b =>
    b.name.includes("sunrise") || b.name.includes("ocean") ||
    b.name.includes("forest") || b.name.includes("mountain") ||
    b.name.includes("wheat") || b.name.includes("cross") || b.name.includes("fog")
  );
  const declBg = pick(natureBgs.length ? natureBgs : manifest, 1);

  // ── Verse pool: Bible/devotional ──
  const verseBgs = manifest.filter(b =>
    b.name.includes("bible") || b.name.includes("devotional") || b.name.includes("reading")
  );
  // Verse bg should differ from hook bg
  const versePool = (verseBgs.length ? verseBgs : manifest).filter(b => b.name !== hookBg.name);
  const verseBg  = pick(versePool.length ? versePool : verseBgs, 2);

  // ── CTA pool: worship/community ──
  const worshipBgs = manifest.filter(b => b.name.includes("worship"));
  const ctaBg = pick(worshipBgs.length ? worshipBgs : manifest, 3);

  const toPath = b => resolve(BG_DIR, b.file.replace("backgrounds/", ""));

  return {
    hookName:     hookBg.name,        // stored in history
    hook:         toPath(hookBg),
    declarations: toPath(declBg),
    verse:        toPath(verseBg),
    cta:          toPath(ctaBg),
  };
}

// ── Helpers ───────────────────────────────────────────────────
function wrapText(ctx, text, maxW) {
  const words = text.split(" ");
  const lines = [];
  let line = "";
  for (const w of words) {
    const t = line ? `${line} ${w}` : w;
    if (ctx.measureText(t).width > maxW && line) {
      lines.push(line); line = w;
    } else line = t;
  }
  if (line) lines.push(line);
  return lines;
}

async function drawBase(ctx, theme, bgPath, overlayOpacity = 0.70) {
  // Try selected background → fall back to bg-main.jpg → solid color
  let loaded = false;
  for (const p of [bgPath, BG_FALLBACK]) {
    if (!p || !existsSync(p)) continue;
    try {
      const bg = await loadImage(p);
      // Fill canvas first, then draw image to cover
      ctx.fillStyle = "#000";
      ctx.fillRect(0, 0, W, H);
      // Draw with slight scale for visual breathing room
      const scale = 1.06;
      const sw = W * scale, sh = H * scale;
      ctx.drawImage(bg, -(sw - W) / 2, -(sh - H) / 2, sw, sh);
      loaded = true;
      break;
    } catch {}
  }
  if (!loaded) {
    ctx.fillStyle = "#08061A";
    ctx.fillRect(0, 0, W, H);
  }

  // Dark overlay
  ctx.fillStyle = `rgba(0,0,0,${overlayOpacity})`;
  ctx.fillRect(0, 0, W, H);

  // Subtle accent glow — bottom-left (varied position keeps slides distinct)
  const glow = ctx.createRadialGradient(W * 0.25, H * 0.7, 0, W * 0.25, H * 0.7, W * 0.7);
  glow.addColorStop(0, theme.glow);
  glow.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, W, H);
}

function drawPill(ctx, label, theme, y = 80) {
  const text = label.toUpperCase();
  ctx.font = "700 22px DisplayBold";
  const tw = ctx.measureText(text).width;
  const pw = tw + 48, ph = 38, px = (W - pw) / 2;
  ctx.fillStyle = theme.accent + "33";
  ctx.strokeStyle = theme.accent + "88";
  ctx.lineWidth = 1.5;
  const r = ph / 2;
  ctx.beginPath();
  ctx.moveTo(px + r, y);
  ctx.lineTo(px + pw - r, y);
  ctx.arcTo(px + pw, y, px + pw, y + ph, r);
  ctx.lineTo(px + pw, y + ph - r);
  ctx.arcTo(px + pw, y + ph, px + pw - r, y + ph, r);
  ctx.lineTo(px + r, y + ph);
  ctx.arcTo(px, y + ph, px, y + ph - r, r);
  ctx.lineTo(px, y + r);
  ctx.arcTo(px, y, px + r, y, r);
  ctx.closePath();
  ctx.fill(); ctx.stroke();
  ctx.fillStyle = theme.accent;
  ctx.textAlign = "center";
  ctx.fillText(text, W / 2, y + ph / 2 + 8);
}

function drawDots(ctx, activeIdx, total, theme, yPos) {
  for (let i = 0; i < total; i++) {
    ctx.beginPath();
    ctx.arc(W / 2 - ((total - 1) * 14) + i * 28, yPos, i === activeIdx ? 6 : 4, 0, Math.PI * 2);
    ctx.fillStyle = i === activeIdx ? theme.accent : "rgba(255,255,255,0.25)";
    ctx.fill();
  }
}

// Tiny "SpeakLife" wordmark watermark — used on all non-CTA slides
function drawWatermark(ctx) {
  ctx.font = "600 26px DisplaySemi";
  ctx.fillStyle = "rgba(255,255,255,0.35)";
  ctx.textAlign = "center";
  ctx.fillText("SpeakLife", W / 2, H - 40);
}

// ── SLIDE 0 — Hook ────────────────────────────────────────────
async function renderHookSlide(angle, pillar, bgPath, outPath) {
  const canvas = createCanvas(W, H);
  const ctx    = canvas.getContext("2d");
  const theme  = THEMES[pillar] || THEMES.default;

  await drawBase(ctx, theme, bgPath, 0.68);
  drawPill(ctx, pillar, theme, 80);

  // Hook text — strip trailing "declare these" if present, force CAPS
  const hookRaw = angle.hook.replace(/, declare these\.?$/i, "").trim();
  const fullHook = hookRaw.toUpperCase();

  ctx.font = "800 64px Display";
  ctx.fillStyle = "#FFFFFF";
  ctx.textAlign = "center";
  const hookLines = wrapText(ctx, fullHook, W - 100);
  const lineH = 78;
  const blockH = hookLines.length * lineH + 32 + 72; // hook + divider gap + swipe line
  const startY = H / 2 - blockH / 2 + 20;

  hookLines.forEach((line, i) => {
    ctx.fillText(line, W / 2, startY + i * lineH);
  });

  // Accent divider
  const divY = startY + hookLines.length * lineH + 26;
  ctx.strokeStyle = theme.accent;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(W / 2 - 80, divY);
  ctx.lineTo(W / 2 + 80, divY);
  ctx.stroke();

  // Dynamic swipe prompt — punchy, curiosity-driven
  const swipePrompt = SWIPE_PROMPTS[pillar] || SWIPE_PROMPTS.default;
  ctx.font = "800 42px Display";
  ctx.fillStyle = "#8FB5FF";
  ctx.fillText(swipePrompt, W / 2, divY + 62);

  drawDots(ctx, 0, 8, theme, H - 80);
  drawWatermark(ctx);

  writeFileSync(outPath, canvas.toBuffer("image/png"));
  console.log(`  Hook -> ${outPath}`);
}

// ── SLIDES 1-5 — Declarations ────────────────────────────────
async function renderDeclarationSlide(declaration, slideIndex, pillar, bgPath, outPath) {
  const canvas = createCanvas(W, H);
  const ctx    = canvas.getContext("2d");
  const theme  = THEMES[pillar] || THEMES.default;
  const PAD    = 110; // generous padding = breathing room

  // Slightly lighter overlay on even slides for visual variation
  const overlayOpacity = slideIndex % 2 === 1 ? 0.70 : 0.75;
  await drawBase(ctx, theme, bgPath, overlayOpacity);

  // "DECLARE #N" — small, accent colored, top center
  ctx.font = "600 24px DisplaySemi";
  ctx.fillStyle = theme.accent + "CC";
  ctx.textAlign = "center";
  ctx.fillText(`DECLARE #${slideIndex}`, W / 2, 108);

  // Short accent line under the label
  ctx.strokeStyle = theme.accent + "55";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(W / 2 - 50, 122); ctx.lineTo(W / 2 + 50, 122);
  ctx.stroke();

  // Declaration text — slightly smaller, with breathing room
  let fontSize = 58;
  ctx.font = `800 ${fontSize}px Display`;
  let lines = wrapText(ctx, declaration, W - PAD * 2);
  while (lines.length > 5 && fontSize > 42) {
    fontSize -= 2;
    ctx.font = `800 ${fontSize}px Display`;
    lines = wrapText(ctx, declaration, W - PAD * 2);
  }

  ctx.fillStyle = "#FFFFFF";
  ctx.textAlign = "center";
  const lineH = fontSize * 1.30; // generous line spacing
  const textBlockH = lines.length * lineH;
  const startY = H / 2 - textBlockH / 2 + fontSize / 2;

  lines.forEach((line, i) => {
    ctx.fillText(line, W / 2, startY + i * lineH);
  });

  drawDots(ctx, slideIndex, 8, theme, H - 80);
  drawWatermark(ctx);

  writeFileSync(outPath, canvas.toBuffer("image/png"));
  console.log(`  Declaration ${slideIndex} -> ${outPath}`);
}

// ── SLIDE 6 — Verse spotlight ─────────────────────────────────
async function renderVerseSlide(verseText, reference, pillar, bgPath, outPath) {
  const canvas = createCanvas(W, H);
  const ctx    = canvas.getContext("2d");
  const theme  = THEMES[pillar] || THEMES.default;

  await drawBase(ctx, theme, bgPath, 0.74);

  // "ANCHOR SCRIPTURE" label
  ctx.font = "700 22px DisplayBold";
  ctx.fillStyle = "rgba(255,255,255,0.45)";
  ctx.textAlign = "center";
  ctx.fillText("ANCHOR SCRIPTURE", W / 2, 100);

  // Large decorative open-quote
  ctx.font = "800 160px Display";
  ctx.fillStyle = theme.accent + "33";
  ctx.fillText("\u201C", W / 2 - 260, H / 2 - 140);

  // Verse text — centered, italic feel with bold weight
  ctx.font = "700 52px DisplayBold";
  ctx.fillStyle = "#FFFFFF";
  const lines = wrapText(ctx, verseText, W - 140);
  const lineH = 68;
  const startY = H / 2 - (lines.length * lineH) / 2 + 20;
  lines.forEach((line, i) => ctx.fillText(line, W / 2, startY + i * lineH));

  // Reference — accent colored, clearly separated
  const refY = startY + lines.length * lineH + 52;
  ctx.font = "600 38px DisplaySemi";
  ctx.fillStyle = theme.accent;
  ctx.fillText(`\u2014 ${reference}`, W / 2, refY);

  drawDots(ctx, 6, 8, theme, H - 80);
  drawWatermark(ctx);

  writeFileSync(outPath, canvas.toBuffer("image/png"));
  console.log(`  Verse -> ${outPath}`);
}

// ── SLIDE 7 — CTA ─────────────────────────────────────────────
async function renderCtaSlide(pillar, bgPath, outPath) {
  const canvas = createCanvas(W, H);
  const ctx    = canvas.getContext("2d");
  const theme  = THEMES[pillar] || THEMES.default;
  const PAD    = 72;
  const maxW   = W - PAD * 2;

  // CTA uses lighter overlay so the background image shows through more
  await drawBase(ctx, theme, bgPath, 0.62);

  // Logo
  const ls   = 130;
  const logoY = H * 0.20;
  try {
    const logo = await loadImage(LOGO);
    ctx.drawImage(logo, (W - ls) / 2, logoY, ls, ls);
  } catch {}
  ctx.font = "700 38px DisplayBold";
  ctx.fillStyle = "rgba(255,255,255,0.90)";
  ctx.textAlign = "center";
  ctx.fillText("SpeakLife", W / 2, logoY + ls + 46);

  // Stars
  const starY   = logoY + ls + 104;
  const starOuter = 18, starInner = 8, starGap = starOuter * 2.8;
  const starSx  = W / 2 - ((5 - 1) * starGap) / 2;
  ctx.fillStyle = "#F5A623";
  for (let s = 0; s < 5; s++) {
    const ox = starSx + s * starGap;
    ctx.beginPath();
    for (let i = 0; i < 10; i++) {
      const a = (Math.PI / 5) * i - Math.PI / 2;
      const r = i % 2 === 0 ? starOuter : starInner;
      i === 0
        ? ctx.moveTo(ox + r * Math.cos(a), starY + r * Math.sin(a))
        : ctx.lineTo(ox + r * Math.cos(a), starY + r * Math.sin(a));
    }
    ctx.closePath(); ctx.fill();
  }
  ctx.font = "600 26px DisplaySemi";
  ctx.fillStyle = "rgba(255,255,255,0.55)";
  ctx.fillText("Rated 4.9/5 \u00B7 100K+ downloads", W / 2, starY + 40);

  // CTA headline
  ctx.font = "800 52px Display";
  ctx.fillStyle = "#FFFFFF";
  const ctaText = "SPEAK GOD'S WORD OVER YOUR LIFE EVERY MORNING";
  ctx.font = "800 52px Display";
  const ctaLines = wrapText(ctx, ctaText, maxW);
  const ctaLH = 64;
  const ctaStartY = H * 0.57 - (ctaLines.length * ctaLH) / 2;
  ctaLines.forEach((line, i) => ctx.fillText(line, W / 2, ctaStartY + i * ctaLH));

  // Download button — uses theme accent so it matches every pillar's palette
  const btnY = ctaStartY + ctaLines.length * ctaLH + 40;
  const btnW = maxW, btnH = 112, btnX = PAD;
  ctx.beginPath();
  ctx.roundRect(btnX, btnY, btnW, btnH, 22);
  // Build a gradient from the theme accent
  const btnGrad = ctx.createLinearGradient(btnX, btnY, btnX + btnW, btnY + btnH);
  btnGrad.addColorStop(0, theme.accent);
  btnGrad.addColorStop(1, theme.accent + "CC");
  ctx.fillStyle = btnGrad;
  ctx.fill();
  ctx.font = "700 36px DisplayBold";
  ctx.fillStyle = "#FFFFFF";
  ctx.fillText("Download FREE on App Store", W / 2, btnY + 44);
  ctx.font = "600 26px DisplaySemi";
  ctx.fillStyle = "rgba(255,255,255,0.80)";
  ctx.fillText("Share this with someone who needs it", W / 2, btnY + 82);

  // Dots
  drawDots(ctx, 7, 8, theme, H - 60);

  writeFileSync(outPath, canvas.toBuffer("image/png"));
  console.log(`  CTA -> ${outPath}`);
}

// ── Main ──────────────────────────────────────────────────────
const args = process.argv.slice(2);
let pillar = null, slug = null, outDir = resolve(STUDIO, "../output/declare-angles");
let dateArg = null, slotArg = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--pillar") pillar  = args[++i];
  else if (args[i] === "--slug")   slug    = args[++i];
  else if (args[i] === "--out")    outDir  = args[++i];
  else if (args[i] === "--date")   dateArg = args[++i];
  else if (args[i] === "--slot")   slotArg = args[++i]; // morning|midday|evening
}

const TODAY = dateArg || new Date().toISOString().slice(0, 10);
// Slot offsets so each slot gets distinct backgrounds on the same day
const SLOT_SEED_OFFSET = { morning: 0, midday: 3, evening: 7 };
const slotOffset = SLOT_SEED_OFFSET[slotArg] ?? 0;
const data  = JSON.parse(readFileSync(ANGLES, "utf-8"));

// Pick pillar
const PILLAR_ORDER = ["anxiety", "healing", "strength", "purpose", "peace", "belonging", "grief"];
let activePillar = pillar?.toLowerCase();
if (!activePillar || !data.pillars[activePillar]) {
  const now   = new Date(TODAY);
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
  activePillar = PILLAR_ORDER[dayOfYear % PILLAR_ORDER.length];
}

const angles = data.pillars[activePillar];

// Pick angle
let angle;
if (slug) {
  angle = angles.find(a => a.slug === slug);
  if (!angle) throw new Error(`Slug "${slug}" not found in pillar "${activePillar}"`);
} else {
  const now   = new Date(TODAY);
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
  const angleIndex = Math.floor(dayOfYear / PILLAR_ORDER.length) % angles.length;
  angle = angles[angleIndex];
}

// Select 3 distinct backgrounds for this carousel (slot offset ensures morning ≠ evening)
const bgs = selectBackgrounds(activePillar, TODAY, slotOffset);

mkdirSync(outDir, { recursive: true });

const prefix = `${activePillar}-${angle.slug}`;
console.log(`\n=== Declare Angle Renderer v2 ===`);
console.log(`Date:          ${TODAY}`);
console.log(`Pillar:        ${activePillar}`);
console.log(`Angle:         ${angle.slug}`);
console.log(`Hook:          "${angle.hook}"`);
console.log(`BG hook:       ${bgs.hook?.split("/").slice(-1)[0] ?? "fallback"}`);
console.log(`BG decl:       ${bgs.declarations?.split("/").slice(-1)[0] ?? "fallback"}`);
console.log(`BG verse:      ${bgs.verse?.split("/").slice(-1)[0] ?? "fallback"}`);
console.log(`Swipe CTA:     "${SWIPE_PROMPTS[activePillar] || SWIPE_PROMPTS.default}"`);
console.log("=".repeat(44));

// Render all 8 slides — each section gets its own background
await renderHookSlide(angle, activePillar, bgs.hook, resolve(outDir, `${prefix}-slide-0-hook.png`));

for (let i = 0; i < 5; i++) {
  await renderDeclarationSlide(
    angle.declarations[i],
    i + 1,
    activePillar,
    bgs.declarations,
    resolve(outDir, `${prefix}-slide-${i + 1}-decl.png`)
  );
}

await renderVerseSlide(
  angle.verseText,
  angle.reference,
  activePillar,
  bgs.verse,
  resolve(outDir, `${prefix}-slide-6-verse.png`)
);

await renderCtaSlide(activePillar, bgs.cta, resolve(outDir, `${prefix}-slide-7-cta.png`));

// Log used hook background so future renders avoid it
const history = loadBgHistory();
history.push({ date: TODAY, slot: slotArg || "manual", hookBg: bgs.hookName });
saveBgHistory(history.slice(-20)); // keep last 20 entries max

console.log(`\nDone — 8 slides`);
console.log(`Output: ${outDir}`);
