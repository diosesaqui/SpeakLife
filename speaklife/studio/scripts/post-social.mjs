#!/usr/bin/env node
/**
 * SpeakLife Social Auto-Poster — Ayrshare API
 * Posts to Instagram + TikTok automatically
 *
 * Slots:
 *   morning  (7:00 AM ET) — Declare angle carousel
 *   midday   (12:00 PM ET) — God Speaks or POV Hook video
 *   evening  (8:00 PM ET) — Quote card / scripture
 *
 * Usage:
 *   node post-social.mjs --slot morning|midday|evening [--date YYYY-MM-DD] [--dry-run]
 */
import { readFileSync, existsSync, readdirSync, writeFileSync } from "fs";
import { resolve, dirname, basename } from "path";
import { fileURLToPath } from "url";
import { createReadStream, statSync, mkdirSync } from "fs";
import { spawn } from "child_process";
import { tmpdir } from "os";

const __dirname = dirname(fileURLToPath(import.meta.url));
const STUDIO    = resolve(__dirname, "..");
const WORKSPACE = resolve(STUDIO, "..", "..");

// ── Config ────────────────────────────────────────────────────
const AYRSHARE_KEY = process.env.AYRSHARE_API_KEY || "";
const AYRSHARE_BASE = "https://app.ayrshare.com/api";
const PLATFORMS = ["instagram", "tiktok", "twitter"];

const FFMPEG = resolve(STUDIO, "node_modules/@ffmpeg-installer/linux-x64/ffmpeg");
const MUSIC_LIBRARY = JSON.parse(readFileSync(resolve(STUDIO, "public/music/LIBRARY.json"), "utf-8"));

function ffmpeg(args) {
  return new Promise((res, rej) => {
    const p = spawn(FFMPEG, args, { stdio: ["ignore", "pipe", "pipe"] });
    let err = "";
    p.stderr.on("data", d => err += d.toString());
    p.on("close", code => code === 0 ? res() : rej(new Error(err.slice(-800))));
  });
}

// aspect: "4:5" (1080x1350 for IG feed/reels) or "9:16" (1080x1920 for TikTok)
async function renderSlideshowVideo(slides, outPath, musicId = "ambient-worship", aspect = "9:16") {
  const tmp = tmpdir();
  const [W, H] = aspect === "9:16" ? [1080, 1920] : [1080, 1350];
  const concatFile = resolve(tmp, `concat-${Date.now()}.txt`);
  const lines = slides.map(s => `file '${s}'\nduration 2.5`).join("\n");
  writeFileSync(concatFile, lines + `\nfile '${slides[slides.length - 1]}'`);

  const musicTrack = MUSIC_LIBRARY.tracks.find(t => t.id === musicId);
  const musicPath  = musicTrack?.file ? resolve(STUDIO, "public", musicTrack.file) : null;
  const volume     = musicTrack?.volume ?? 0.28;
  const totalDuration = slides.length * 2.5;
  const vf = `scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2,setsar=1`;

  if (musicPath && existsSync(musicPath)) {
    await ffmpeg([
      "-f", "concat", "-safe", "0", "-i", concatFile,
      "-stream_loop", "-1", "-i", musicPath,
      "-c:v", "libx264", "-pix_fmt", "yuv420p",
      "-vf", vf,
      "-r", "24",
      "-c:a", "aac", "-b:a", "128k",
      "-filter:a", `volume=${volume}`,
      "-t", String(totalDuration),
      "-shortest",
      "-y", outPath,
    ]);
  } else {
    await ffmpeg([
      "-f", "concat", "-safe", "0", "-i", concatFile,
      "-c:v", "libx264", "-pix_fmt", "yuv420p",
      "-vf", vf,
      "-r", "24", "-an",
      "-t", String(totalDuration),
      "-y", outPath,
    ]);
  }
  console.log(`  Slideshow video (${aspect}) -> ${outPath}`);
  return outPath;
}

// Pillar rotation (7 pillars, matches render-declare-angle.mjs)
const PILLAR_ORDER = ["anxiety", "healing", "strength", "purpose", "peace", "belonging", "grief"];

// ── Helpers ───────────────────────────────────────────────────
function getTodaysPillar(date) {
  const now   = date ? new Date(date) : new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
  return PILLAR_ORDER[dayOfYear % 7];
}

function getToday(dateArg) {
  if (dateArg) return dateArg;
  return new Date().toISOString().slice(0, 10);
}

async function ayrsharePost(payload) {
  const res = await fetch(`${AYRSHARE_BASE}/post`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${AYRSHARE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Ayrshare error: ${JSON.stringify(data)}`);
  return data;
}

async function ayrshareUploadMedia(filePath) {
  // Convert PNG to JPG for platform compatibility (TikTok rejects PNG)
  let uploadPath = filePath;
  let tempJpg = null;
  if (filePath.endsWith(".png")) {
    const { createCanvas, loadImage } = await import("@napi-rs/canvas");
    const img = await loadImage(filePath);
    const canvas = createCanvas(img.width, img.height);
    const ctx = canvas.getContext("2d");
    ctx.drawImage(img, 0, 0);
    const jpgBuf = canvas.toBuffer("image/jpeg", { quality: 92 });
    tempJpg = filePath.replace(".png", ".jpg");
    const { writeFileSync } = await import("fs");
    writeFileSync(tempJpg, jpgBuf);
    uploadPath = tempJpg;
  }

  const filename = basename(uploadPath);
  const mimeType = uploadPath.endsWith(".mp4") ? "video/mp4" : "image/jpeg";

  const formData = new FormData();
  const blob = new Blob([readFileSync(uploadPath)], { type: mimeType });
  formData.append("file", blob, filename);

  const res = await fetch(`${AYRSHARE_BASE}/media/upload`, {
    method: "POST",
    headers: { "Authorization": `Bearer ${AYRSHARE_KEY}` },
    body: formData,
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`Upload error: ${JSON.stringify(data)}`);
  return data.url;
}

function loadCaption(pillar, type, date) {
  const captionPath = resolve(WORKSPACE, "speaklife/output/captions", date, `${type}-${pillar}.txt`);
  if (existsSync(captionPath)) {
    return readFileSync(captionPath, "utf-8").trim();
  }
  // Fallback caption
  return `Declare this over your life today. #SpeakLife #${pillar} #faithdeclarations #christianwomen #morningdeclarations`;
}

// ── Pick angle slug for a slot ────────────────────────────────
function pickAngleSlug(pillar, slot, date) {
  const SLOT_OFFSETS = { morning: 0, midday: 1, evening: 2 };
  const now = date ? new Date(date) : new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
  const slotOffset = SLOT_OFFSETS[slot] || 0;

  const data = JSON.parse(readFileSync(resolve(STUDIO, "public/ad-angles.json"), "utf-8"));
  const angles = data.pillars[pillar] || [];
  if (!angles.length) throw new Error(`No angles for pillar: ${pillar}`);
  return angles[(dayOfYear + slotOffset) % angles.length].slug;
}

// ── Build carousel: render fresh 5-slide set, return paths ────
async function buildCarousel(pillar, slot, date) {
  const slug    = pickAngleSlug(pillar, slot, date);
  const dateStr = date || new Date().toISOString().slice(0, 10);
  const outDir  = resolve(WORKSPACE, "speaklife/output/declare-angles", `${dateStr}-${slot}`);
  mkdirSync(outDir, { recursive: true });

  // Always re-render so we get the latest template (5 slides, correct fonts)
  const renderer = resolve(STUDIO, "scripts/render-declare-angle.mjs");
  await new Promise((res, rej) => {
    const p = spawn(process.execPath, [renderer, "--pillar", pillar, "--slug", slug, "--out", outDir], {
      stdio: ["ignore", "pipe", "pipe"],
    });
    p.stdout.on("data", d => process.stdout.write(d));
    p.stderr.on("data", d => process.stderr.write(d));
    p.on("close", code => code === 0 ? res() : rej(new Error(`render-declare-angle exited ${code}`)));
  });

  // Return slides in order: slide-0 (hook), slide-1, slide-2, slide-3, slide-4 (cta)
  const files = readdirSync(outDir)
    .filter(f => f.startsWith(`${pillar}-${slug}-slide-`) && f.endsWith(".png"))
    .sort();

  if (files.length < 5) throw new Error(`Expected 5 slides, got ${files.length} for ${pillar}/${slug}`);
  return files.map(f => resolve(outDir, f));
}

// ── Slot Handlers ─────────────────────────────────────────────

async function postSlot(slotName, date, dryRun) {
  const pillar  = getTodaysPillar(date);
  const slides  = await buildCarousel(pillar, slotName, date);
  const caption = loadCaption(pillar, "declaration", date);

  console.log(`${slotName} post — ${pillar} (${slides.length} slides)`);
  slides.forEach(s => console.log(`  ${basename(s)}`));

  if (dryRun) { console.log("[DRY RUN] Would post:", slides.map(s => basename(s))); return; }

  // Upload all slides as images (carousel — swipeable on IG, TikTok, Twitter)
  const mediaUrls = [];
  for (const s of slides) { mediaUrls.push(await ayrshareUploadMedia(s)); }

  const result = await ayrsharePost({
    post: caption,
    platforms: PLATFORMS,
    mediaUrls,
    instagramOptions: { type: "carousel" },
    tiktokOptions: { autoAddMusic: true },
  });
  console.log(`Posted! IDs:`, result.postIds || result.id);
  return result;
}

// 7 AM ET
async function postMorning(date, dryRun) { return postSlot("morning", date, dryRun); }
// 12 PM ET
async function postMidday(date, dryRun)  { return postSlot("midday",  date, dryRun); }
// 8 PM ET
async function postEvening(date, dryRun) { return postSlot("evening", date, dryRun); }

// ── CLI ───────────────────────────────────────────────────────
const args  = process.argv.slice(2);
let slot    = null;
let date    = null;
let dryRun  = false;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--slot")    slot   = args[++i];
  if (args[i] === "--date")    date   = args[++i];
  if (args[i] === "--dry-run") dryRun = true;
}

if (!slot) {
  console.error("Usage: node post-social.mjs --slot morning|midday|evening [--date YYYY-MM-DD] [--dry-run]");
  process.exit(1);
}

if (!AYRSHARE_KEY && !dryRun) {
  console.error("Missing AYRSHARE_API_KEY env var. Run with --dry-run to test without key.");
  process.exit(1);
}

const TODAY = getToday(date);
console.log(`\n=== SpeakLife Social Poster ===`);
console.log(`Slot:    ${slot}`);
console.log(`Date:    ${TODAY}`);
console.log(`Pillar:  ${getTodaysPillar(TODAY)}`);
console.log(`DryRun:  ${dryRun}`);
console.log(`================================\n`);

try {
  if (slot === "morning") await postMorning(TODAY, dryRun);
  else if (slot === "midday") await postMidday(TODAY, dryRun);
  else if (slot === "evening") await postEvening(TODAY, dryRun);
  else throw new Error(`Unknown slot: ${slot}. Use morning|midday|evening`);
  console.log("\nDone.");
} catch (e) {
  console.error("Post failed:", e.message);
  process.exit(1);
}
