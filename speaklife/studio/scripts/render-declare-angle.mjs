#!/usr/bin/env node
/**
 * SpeakLife Declare Angle Renderer
 * Format: "If you need X, declare these" → 4 slides (hook + 3 declarations)
 * Output: 1080x1350 PNGs (4:5 feed) or 1080x1920 (9:16 stories/reels)
 */
import { createCanvas, loadImage, GlobalFonts } from "@napi-rs/canvas";
import { writeFileSync, mkdirSync, readFileSync } from "fs";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const STUDIO = resolve(__dirname, "..");
const FONTS  = resolve(STUDIO, "public/fonts");
const LOGO   = resolve(STUDIO, "public/logo.png");
const BG     = resolve(STUDIO, "public/bg-main.jpg");
const ANGLES = resolve(STUDIO, "public/ad-angles.json");

GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-ExtraBold.ttf"), "Display");
GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-Bold.ttf"),      "DisplayBold");
GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-SemiBold.ttf"),  "DisplaySemi");
GlobalFonts.registerFromPath(resolve(FONTS, "Montserrat-Regular.ttf"),   "DisplayReg");

const W = 1080, H = 1350;

const THEMES = {
  anxiety:    { accent: "#8B5CF6", glow: "rgba(139,92,246,0.22)"  },
  healing:    { accent: "#3B82F6", glow: "rgba(59,130,246,0.22)"  },
  strength:   { accent: "#EF4444", glow: "rgba(239,68,68,0.22)"   },
  purpose:    { accent: "#F59E0B", glow: "rgba(245,158,11,0.22)"  },
  peace:      { accent: "#10B981", glow: "rgba(16,185,129,0.22)"  },
  belonging:  { accent: "#EC4899", glow: "rgba(236,72,153,0.22)"  },
  grief:      { accent: "#6B7280", glow: "rgba(107,114,128,0.22)" },
  default:    { accent: "#F5A623", glow: "rgba(245,166,35,0.22)"  },
};

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

async function drawBase(ctx, theme) {
  // BG image
  try {
    const bg = await loadImage(BG);
    ctx.drawImage(bg, -40, -80, W + 80, H + 80);
  } catch {
    ctx.fillStyle = "#08061A"; ctx.fillRect(0, 0, W, H);
  }
  // Dark overlay
  const ov = ctx.createLinearGradient(0, 0, 0, H);
  ov.addColorStop(0,   "rgba(5,3,16,0.90)");
  ov.addColorStop(0.5, "rgba(8,5,22,0.93)");
  ov.addColorStop(1,   "rgba(3,2,10,0.97)");
  ctx.fillStyle = ov;
  ctx.fillRect(0, 0, W, H);
  // Glow
  const glow = ctx.createRadialGradient(W/2, H*0.5, 0, W/2, H*0.5, W*0.6);
  glow.addColorStop(0, theme.glow);
  glow.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, W, H);
}

async function drawLogo(ctx) {
  const ls = 100;
  const logoY = H - 190;
  try {
    const logo = await loadImage(LOGO);
    ctx.drawImage(logo, (W - ls) / 2, logoY, ls, ls);
  } catch {}
  ctx.font = "700 34px DisplayBold";
  ctx.fillStyle = "rgba(255,255,255,0.80)";
  ctx.textAlign = "center";
  ctx.fillText("SpeakLife", W/2, logoY + ls + 40);
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
  ctx.moveTo(px + r, y); ctx.lineTo(px + pw - r, y);
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
  ctx.fillText(text, W/2, y + ph/2 + 8);
}

// SLIDE 1 — Hook card: "If you need X, declare these"
async function renderHookSlide(angle, pillar, outPath) {
  const canvas = createCanvas(W, H);
  const ctx    = canvas.getContext("2d");
  const theme  = THEMES[pillar] || THEMES.default;

  await drawBase(ctx, theme);
  drawPill(ctx, pillar, theme, 80);

  // Full hook as one statement — split into two parts visually
  // Part 1: the "IF" condition (white)
  const fullHook = angle.hook.replace(/, declare these$/i, "").toUpperCase();
  ctx.font = "800 64px Display";
  ctx.fillStyle = "#FFFFFF";
  const hookLines = wrapText(ctx, fullHook, W - 100);
  const lineH = 78;
  const totalH = hookLines.length * lineH + 30 + 80; // hook + divider + cta
  const startY = H/2 - totalH / 2 + 40;

  hookLines.forEach((line, i) => {
    ctx.fillText(line, W/2, startY + i * lineH);
  });

  // Accent divider
  const divY = startY + hookLines.length * lineH + 30;
  ctx.strokeStyle = theme.accent;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(W/2 - 80, divY);
  ctx.lineTo(W/2 + 80, divY);
  ctx.stroke();

  // "DECLARE THESE  SWIPE ->" in accent color
  ctx.font = "800 46px Display";
  ctx.fillStyle = theme.accent;
  ctx.fillText("DECLARE THESE  SWIPE ->", W/2, divY + 66);

  // Slide indicator dots (5 slides)
  const dotY = H - 220;
  [0,1,2,3,4].forEach(i => {
    ctx.beginPath();
    ctx.arc(W/2 - 48 + i * 24, dotY, i === 0 ? 6 : 4, 0, Math.PI * 2);
    ctx.fillStyle = i === 0 ? theme.accent : "rgba(255,255,255,0.25)";
    ctx.fill();
  });

  await drawLogo(ctx);
  writeFileSync(outPath, canvas.toBuffer("image/png"));
  console.log(`  Hook slide -> ${outPath}`);
}

// SLIDES 2-4 — Declaration cards
async function renderDeclarationSlide(declaration, slideIndex, totalSlides, reference, pillar, outPath) {
  const canvas = createCanvas(W, H);
  const ctx    = canvas.getContext("2d");
  const theme  = THEMES[pillar] || THEMES.default;

  await drawBase(ctx, theme);

  // Declaration number
  ctx.font = "700 24px DisplaySemi";
  ctx.fillStyle = theme.accent;
  ctx.textAlign = "center";
  ctx.fillText(`DECLARE #${slideIndex}`, W/2, 120);

  // Decorative accent bar (top-left corner)
  ctx.fillStyle = theme.accent + "88";
  ctx.fillRect(80, 180, 6, 80);

  // Declaration text (large, centered)
  ctx.font = "800 62px Display";
  ctx.fillStyle = "#FFFFFF";
  const lines = wrapText(ctx, declaration, W - 140);
  const lineH = 76;
  const startY = H/2 - (lines.length * lineH) / 2 + 30;
  lines.forEach((line, i) => {
    ctx.fillText(line, W/2, startY + i * lineH);
  });

  // Reference (last slide only)
  if (slideIndex === totalSlides && reference) {
    ctx.font = "600 26px DisplaySemi";
    ctx.fillStyle = theme.accent + "CC";
    ctx.fillText(`— ${reference}`, W/2, startY + lines.length * lineH + 52);
  }

  // Slide indicator dots
  const dotY = H - 220;
  [0,1,2,3].forEach(i => {
    ctx.beginPath();
    ctx.arc(W/2 - 36 + i * 24, dotY, i === slideIndex ? 6 : 4, 0, Math.PI * 2);
    ctx.fillStyle = i === slideIndex ? theme.accent : "rgba(255,255,255,0.25)";
    ctx.fill();
  });

  await drawLogo(ctx);
  writeFileSync(outPath, canvas.toBuffer("image/png"));
  console.log(`  Declaration ${slideIndex} -> ${outPath}`);
}

// SLIDE 5 — CTA
async function renderCtaSlide(pillar, outPath) {
  const canvas = createCanvas(W, H);
  const ctx    = canvas.getContext("2d");
  const theme  = THEMES[pillar] || THEMES.default;
  const PAD    = 72;
  const maxW   = W - PAD * 2;

  await drawBase(ctx, theme);

  // Logo centered upper section
  const ls = 120;
  const logoY = H * 0.22;
  try {
    const logo = await loadImage(LOGO);
    ctx.drawImage(logo, (W - ls) / 2, logoY, ls, ls);
  } catch {}
  ctx.font = "700 38px DisplayBold";
  ctx.fillStyle = "rgba(255,255,255,0.85)";
  ctx.textAlign = "center";
  ctx.fillText("SpeakLife", W / 2, logoY + ls + 46);

  // Stars
  const starY = logoY + ls + 100;
  const starColor = "#F5A623";
  const starOuter = 18, starInner = 8, starGap = starOuter * 2.8;
  const starSx = W / 2 - ((5 - 1) * starGap) / 2;
  ctx.fillStyle = starColor;
  for (let s = 0; s < 5; s++) {
    const ox = starSx + s * starGap;
    ctx.beginPath();
    for (let i = 0; i < 10; i++) {
      const a = (Math.PI / 5) * i - Math.PI / 2;
      const r = i % 2 === 0 ? starOuter : starInner;
      i === 0 ? ctx.moveTo(ox + r * Math.cos(a), starY + r * Math.sin(a))
              : ctx.lineTo(ox + r * Math.cos(a), starY + r * Math.sin(a));
    }
    ctx.closePath(); ctx.fill();
  }
  ctx.font = "600 26px DisplaySemi";
  ctx.fillStyle = "rgba(255,255,255,0.55)";
  ctx.fillText("Rated 4.9/5 · 100K+ downloads", W / 2, starY + 40);

  // CTA headline
  ctx.font = "800 56px Display";
  ctx.fillStyle = "#FFFFFF";
  const ctaText = "SPEAK GOD'S WORD OVER YOUR LIFE EVERY MORNING";
  const ctaLines = (() => {
    const words = ctaText.split(" "), lines = [];
    let line = "";
    for (const w of words) {
      const t = line ? `${line} ${w}` : w;
      if (ctx.measureText(t).width > maxW && line) { lines.push(line); line = w; }
      else line = t;
    }
    if (line) lines.push(line);
    return lines;
  })();
  const ctaLH = 68;
  const ctaTotalH = ctaLines.length * ctaLH;
  const ctaStartY = H * 0.58 - ctaTotalH / 2;
  ctaLines.forEach((line, i) => ctx.fillText(line, W / 2, ctaStartY + i * ctaLH));

  // Download button
  const btnY = ctaStartY + ctaTotalH + 44;
  const btnW = maxW, btnH = 112, btnX = PAD;
  ctx.beginPath();
  ctx.roundRect(btnX, btnY, btnW, btnH, 22);
  const btnGrad = ctx.createLinearGradient(btnX, btnY, btnX + btnW, btnY);
  btnGrad.addColorStop(0, "#F5A623"); btnGrad.addColorStop(1, "#F07C2A");
  ctx.fillStyle = btnGrad; ctx.fill();
  ctx.font = "700 36px DisplayBold";
  ctx.fillStyle = "#FFFFFF";
  ctx.fillText("Download FREE on App Store", W / 2, btnY + 44);
  ctx.font = "600 26px DisplaySemi";
  ctx.fillStyle = "rgba(255,255,255,0.80)";
  ctx.fillText("Share this with someone who needs it", W / 2, btnY + 82);

  // Slide indicator dots
  const dotY = H - 100;
  [0,1,2,3,4].forEach(i => {
    ctx.beginPath();
    ctx.arc(W/2 - 48 + i * 24, dotY, i === 4 ? 6 : 4, 0, Math.PI * 2);
    ctx.fillStyle = i === 4 ? theme.accent : "rgba(255,255,255,0.25)";
    ctx.fill();
  });

  writeFileSync(outPath, canvas.toBuffer("image/png"));
  console.log(`  CTA slide -> ${outPath}`);
}

// ── Main ──────────────────────────────────────────────────────
const args = process.argv.slice(2);
let pillar = null, slug = null, outDir = resolve(STUDIO, "../output/declare-angles");
let randomMode = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--pillar") pillar = args[++i];
  else if (args[i] === "--slug")   slug   = args[++i];
  else if (args[i] === "--out")    outDir = args[++i];
  else if (args[i] === "--random") randomMode = true;
}

const data = JSON.parse(readFileSync(ANGLES, "utf-8"));

// Pick pillar
const pillarNames = Object.keys(data.pillars);
let activePillar = pillar?.toLowerCase();
if (!activePillar || !data.pillars[activePillar]) {
  // Auto-rotate by day of year (matches daily-organic.mjs)
  const PILLAR_ORDER = ["anxiety", "healing", "strength", "purpose", "peace", "belonging", "grief"];
  const now   = new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
  activePillar = PILLAR_ORDER[dayOfYear % 5];
}

const angles = data.pillars[activePillar];

// Pick angle (slug or random/sequential by day)
let angle;
if (slug) {
  angle = angles.find(a => a.slug === slug);
  if (!angle) throw new Error(`Slug "${slug}" not found in pillar "${activePillar}"`);
} else {
  const now   = new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
  const angleIndex = Math.floor(dayOfYear / 5) % angles.length;
  angle = angles[angleIndex];
}

mkdirSync(outDir, { recursive: true });

const prefix = `${activePillar}-${angle.slug}`;
console.log(`\n=== Declare Angle Renderer ===`);
console.log(`Pillar: ${activePillar} | Angle: ${angle.slug}`);
console.log(`Hook: "${angle.hook}"`);

// Render all 5 slides
await renderHookSlide(angle, activePillar, resolve(outDir, `${prefix}-slide-0-hook.png`));
for (let i = 0; i < angle.declarations.length; i++) {
  await renderDeclarationSlide(
    angle.declarations[i],
    i + 1,
    angle.declarations.length,
    i === angle.declarations.length - 1 ? angle.reference : null,
    activePillar,
    resolve(outDir, `${prefix}-slide-${i+1}-decl.png`)
  );
}
await renderCtaSlide(activePillar, resolve(outDir, `${prefix}-slide-4-cta.png`));

console.log(`\nDone — 5 slides for "${angle.hook}"`);
console.log(`Output: ${outDir}`);
