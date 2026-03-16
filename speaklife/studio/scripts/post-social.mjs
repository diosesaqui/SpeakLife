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

// Hook-first captions per pillar — rotates daily so every post is unique
const CAPTION_HOOKS = {
  anxiety:   ["If you woke up with dread this morning, read these slowly.", "Your mind was spiraling before your feet hit the floor. This is what God says.", "That heavy feeling in your chest before the day starts? God sees it.", "You've been white-knuckling something God never asked you to carry.", "If your brain won't stop racing — read this out loud."],
  healing:   ["You've been waiting for your body — or heart — to catch up to your faith.", "Healing isn't always instant. But God is always moving.", "Say this over yourself today. Your healing is already bought.", "The wound is real. So is the One who restores.", "You didn't come this far to stay broken. Declare this."],
  strength:  ["You're not tired because you're weak. You're carrying too much.", "If you feel like you have nothing left — God's strength is for this exact moment.", "The thing trying to knock you down doesn't know Who's holding you up.", "Tired is temporary. God's strength in you is not.", "You've made it through 100% of your hardest days. Declare what got you here."],
  purpose:   ["You've been wondering if you're in the wrong life. You're not.", "Your purpose wasn't an afterthought. God planned it before you were born.", "Stop waiting to feel ready. Your calling doesn't require confidence — just your yes.", "You weren't placed here by accident. Every detail of you was intentional.", "The world needs what only you carry. Declare this today."],
  peace:     ["Peace isn't the absence of chaos. It's knowing Who holds it all.", "You don't have to figure everything out today. Declare this instead.", "Stop trying to manufacture calm. Receive it.", "If you can't seem to slow down, this is what God says about rest.", "Your mind doesn't have to race just because the world does."],
  belonging: ["You've walked into rooms and felt invisible. God has never once not seen you.", "If rejection has been following you — this breaks its power.", "Chosen. Called. Placed on purpose. Declare it.", "The world may have made you feel like an afterthought. God made you a priority.", "You are not too much. You are not too little. You are exactly who God made."],
  grief:     ["If you're walking through the darkest season of your life, these are yours.", "God doesn't ask you to pretend it doesn't hurt. He meets you in it.", "You're allowed to mourn. And you're allowed to still believe.", "Even in the valley — especially in the valley — God is here.", "The loss is real. So is the God who collects every tear."],
};

const CAPTION_CTAS = [
  "Save this for when you need it 🙏",
  "Type AMEN if you needed this today.",
  "Which one hit you? Drop it below 👇",
  "Share with someone who's struggling right now.",
  "Tag someone who needs to hear this.",
  "If this is for you, save it. Don't scroll past.",
];

const CAPTION_HASHTAGS = {
  anxiety:   "#SpeakLife #FaithOverFear #AnxietyRelief #ChristianWomen #MorningMotivation",
  healing:   "#SpeakLife #HealingJourney #GodsRestoration #ChristianWomen #MorningMotivation",
  strength:  "#SpeakLife #GodsStrength #OvercomerFaith #ChristianWomen #MorningMotivation",
  purpose:   "#SpeakLife #ChristianPurpose #ChosenByGod #ChristianWomen #MorningMotivation",
  peace:     "#SpeakLife #GodsPeace #InnerPeace #ChristianWomen #MorningMotivation",
  belonging: "#SpeakLife #ChosenByGod #ChristianIdentity #ChristianWomen #MorningMotivation",
  grief:     "#SpeakLife #GriefFaith #HopeInDarkness #ChristianWomen #MorningMotivation",
};

function loadCaption(pillar, type, date) {
  const captionPath = resolve(WORKSPACE, "speaklife/output/captions", date, `${type}-${pillar}.txt`);
  if (existsSync(captionPath)) {
    return readFileSync(captionPath, "utf-8").trim();
  }

  // Generate a real hook-first caption on the fly — never use the generic fallback
  const now = date ? new Date(date) : new Date();
  const start = new Date(now.getFullYear(), 0, 0);
  const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));

  const hooks = CAPTION_HOOKS[pillar] || CAPTION_HOOKS.anxiety;
  const hook = hooks[dayOfYear % hooks.length];
  const cta = CAPTION_CTAS[dayOfYear % CAPTION_CTAS.length];
  const hashtags = CAPTION_HASHTAGS[pillar] || CAPTION_HASHTAGS.anxiety;

  return [
    hook,
    "",
    cta,
    "",
    hashtags,
  ].join("\n");
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
    const p = spawn(process.execPath, [renderer, "--pillar", pillar, "--slug", slug, "--out", outDir, "--slot", slot], {
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

  if (files.length < 8) throw new Error(`Expected 5 slides, got ${files.length} for ${pillar}/${slug}`);
  return files.map(f => resolve(outDir, f));
}

// ── Posted Log (dedup guard) ──────────────────────────────────
const POSTED_LOG = resolve(WORKSPACE, "speaklife/output/posted-log.json");

function loadPostedLog() {
  if (!existsSync(POSTED_LOG)) return {};
  try { return JSON.parse(readFileSync(POSTED_LOG, "utf-8")); }
  catch { return {}; }
}

function markPosted(date, slot, data) {
  const log = loadPostedLog();
  if (!log[date]) log[date] = {};
  log[date][slot] = { postedAt: new Date().toISOString(), ...data };
  writeFileSync(POSTED_LOG, JSON.stringify(log, null, 2));
}

function alreadyPosted(date, slot) {
  const log = loadPostedLog();
  return !!(log[date] && log[date][slot]);
}

// ── Slot Handlers ─────────────────────────────────────────────

async function postSlot(slotName, date, dryRun) {
  if (!dryRun && alreadyPosted(date, slotName)) {
    console.log(`⚠️  Already posted ${slotName} for ${date} — skipping to prevent duplicate.`);
    console.log(`    To force re-post, delete entry from ${POSTED_LOG}`);
    return { skipped: true, reason: "already-posted" };
  }

  const pillar  = getTodaysPillar(date);
  const slides  = await buildCarousel(pillar, slotName, date);
  const caption = loadCaption(pillar, "declaration", date);

  console.log(`${slotName} post — ${pillar} (${slides.length} slides)`);
  slides.forEach(s => console.log(`  ${basename(s)}`));

  if (dryRun) { console.log("[DRY RUN] Would post:", slides.map(s => basename(s))); return; }

  // Upload all 5 slides
  const mediaUrls = [];
  for (const s of slides) { mediaUrls.push(await ayrshareUploadMedia(s)); }

  // Twitter needs a shorter caption (280 char limit) — truncate at last full word before limit
  function truncateForTwitter(text, limit = 275) {
    if (text.length <= limit) return text;
    const cut = text.lastIndexOf(" ", limit);
    return text.slice(0, cut > 0 ? cut : limit) + "…";
  }
  const twitterCaption = truncateForTwitter(caption);

  // Post to all platforms in parallel so no single platform can time out the others
  const [igResult, twitterResult, tiktokResult] = await Promise.all([
    ayrsharePost({
      post: caption,
      platforms: ["instagram"],
      mediaUrls,
      instagramOptions: { type: "carousel" },
    }).then(r => { console.log(`IG posted:`, (r.postIds || [r]).map(p => p.postUrl || p.id)); return r; }),

    ayrsharePost({
      post: twitterCaption,
      platforms: ["twitter"],
      mediaUrls: mediaUrls.slice(0, 4),
    }).then(r => { console.log(`Twitter posted:`, (r.postIds || [r]).map(p => p.postUrl || p.id)); return r; }),

    ayrsharePost({
      post: caption,
      platforms: ["tiktok"],
      mediaUrls,
      tikTokOptions: { autoAddMusic: true },
    }).then(r => { console.log(`TikTok draft:`, (r.postIds || [r]).map(p => p.id)); return r; }),
  ]);

  if (!dryRun) markPosted(date, slotName, { pillar, igResult, twitterResult, tiktokResult });

  return { igResult, twitterResult, tiktokResult };
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
