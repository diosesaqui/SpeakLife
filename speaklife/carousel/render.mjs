// SpeakLife Carousel Renderer v2
// Rules: centered text, ≤10 words per slide, white bg always, Caveat Bold, character lower 40%

import { createCanvas, registerFont, loadImage } from 'canvas';
import { writeFileSync, mkdirSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));

registerFont(join(__dirname, 'fonts/Caveat-Variable.ttf'), { family: 'Caveat', weight: 'bold' });

const W = 1080;
const H = 1080;
const WHITE = '#FFFFFF';
const BLACK = '#111111';
const RED = '#8B1A1A';

let characterImg = null;
const charPath = join(__dirname, 'assets/character.png');
if (existsSync(charPath)) {
  try { characterImg = await loadImage(charPath); } catch(e) {}
}

function wrapText(ctx, text, centerX, startY, maxWidth, lineHeight) {
  const lines = text.split('\n');
  let y = startY;
  for (const rawLine of lines) {
    if (rawLine.trim() === '') { y += lineHeight * 0.5; continue; }
    // word-wrap within maxWidth
    const words = rawLine.split(' ');
    let line = '';
    for (const word of words) {
      const test = line ? line + ' ' + word : word;
      if (ctx.measureText(test).width > maxWidth && line) {
        ctx.fillText(line, centerX, y);
        line = word;
        y += lineHeight;
      } else {
        line = test;
      }
    }
    if (line) { ctx.fillText(line, centerX, y); y += lineHeight; }
  }
  return y;
}

function measureWrappedHeight(ctx, text, maxWidth, lineHeight) {
  const lines = text.split('\n');
  let totalH = 0;
  for (const rawLine of lines) {
    if (rawLine.trim() === '') { totalH += lineHeight * 0.5; continue; }
    const words = rawLine.split(' ');
    let line = '';
    let rowCount = 1;
    for (const word of words) {
      const test = line ? line + ' ' + word : word;
      if (ctx.measureText(test).width > maxWidth && line) {
        rowCount++;
        line = word;
      } else {
        line = test;
      }
    }
    totalH += rowCount * lineHeight;
  }
  return totalH;
}

function drawCharacter(ctx, isDark = false) {
  const charAreaY = H * 0.60;
  const charAreaH = H * 0.40;
  if (characterImg) {
    const scale = Math.min(W / characterImg.width, charAreaH / characterImg.height) * 0.82;
    const cw = characterImg.width * scale;
    const ch = characterImg.height * scale;
    ctx.drawImage(characterImg, (W - cw) / 2, charAreaY + (charAreaH - ch) / 2, cw, ch);
  } else {
    // Soft placeholder silhouette
    ctx.save();
    ctx.fillStyle = isDark ? 'rgba(255,255,255,0.07)' : 'rgba(0,0,0,0.05)';
    const cx = W / 2, cy = charAreaY + charAreaH * 0.45, r = charAreaH * 0.36;
    ctx.beginPath(); ctx.arc(cx, cy - r * 0.58, r * 0.33, 0, Math.PI * 2); ctx.fill();
    ctx.beginPath();
    ctx.moveTo(cx - r * 0.48, cy + r * 0.18);
    ctx.bezierCurveTo(cx - r * 0.48, cy - r * 0.28, cx + r * 0.48, cy - r * 0.28, cx + r * 0.48, cy + r * 0.18);
    ctx.bezierCurveTo(cx + r * 0.48, cy + r * 0.62, cx - r * 0.48, cy + r * 0.62, cx - r * 0.48, cy + r * 0.18);
    ctx.fill();
    ctx.restore();
  }
}

function drawDivider(ctx) {
  ctx.save();
  ctx.strokeStyle = RED;
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.moveTo(80, H * 0.60 - 16);
  ctx.lineTo(W - 80, H * 0.60 - 16);
  ctx.stroke();
  ctx.restore();
}

function drawHeader(ctx, pillarLabel, slideNum, total, isDark = false) {
  ctx.save();
  ctx.font = 'bold 30px Caveat';
  ctx.fillStyle = isDark ? 'rgba(255,255,255,0.30)' : 'rgba(0,0,0,0.20)';
  ctx.textAlign = 'left';
  ctx.fillText(`SpeakLife · ${pillarLabel}`, 50, 58);
  ctx.textAlign = 'right';
  ctx.fillText(`${slideNum} / ${total}`, W - 50, 58);
  ctx.restore();
}

export function renderSlide(slideData, slideIndex, totalSlides, pillarLabel, outputPath) {
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');

  const isCta = slideData.type === 'cta';
  const isDark = isCta;

  // Background: black for CTA, white for all others
  ctx.fillStyle = isDark ? BLACK : WHITE;
  ctx.fillRect(0, 0, W, H);

  // Red top bar on hook slide
  if (slideData.type === 'hook') {
    ctx.fillStyle = RED;
    ctx.fillRect(0, 0, W, 8);
  }

  drawHeader(ctx, pillarLabel, slideIndex + 1, totalSlides, isDark);
  drawDivider(ctx);
  drawCharacter(ctx, isDark);

  // Text zone: upper 60%, padded
  const textZoneTop = 80;
  const textZoneBottom = H * 0.60 - 30;
  const textZoneH = textZoneBottom - textZoneTop;
  const padX = 80;
  const maxTextW = W - padX * 2;

  // Font size — bigger since text is short
  const isHook = slideData.type === 'hook';
  const isWhy = slideData.type === 'why';

  let fontSize = isHook ? 100 : 82;
  const lineHeight = fontSize * 1.22;

  // Shrink if needed to fit
  ctx.font = `bold ${fontSize}px Caveat`;
  let textH = measureWrappedHeight(ctx, slideData.text, maxTextW, lineHeight);
  while (textH > textZoneH - 20 && fontSize > 44) {
    fontSize -= 4;
    ctx.font = `bold ${fontSize}px Caveat`;
    textH = measureWrappedHeight(ctx, slideData.text, maxTextW, fontSize * 1.22);
  }
  const finalLineH = fontSize * 1.22;

  // Color
  if (isWhy || slideData.accent) {
    ctx.fillStyle = isDark ? '#E8A0A0' : RED;
  } else {
    ctx.fillStyle = isDark ? '#F5F5F5' : BLACK;
  }

  ctx.textAlign = 'center';
  ctx.font = `bold ${fontSize}px Caveat`;

  // Vertically center text in upper zone
  const startY = textZoneTop + (textZoneH - textH) / 2 + finalLineH;
  wrapText(ctx, slideData.text, W / 2, startY, maxTextW, finalLineH);

  writeFileSync(outputPath, canvas.toBuffer('image/png'));
}

export function renderCarousel(pillarKey, pillarContent, outputDir) {
  mkdirSync(outputDir, { recursive: true });
  const slides = pillarContent.slides;
  const total = slides.length;
  const paths = [];
  for (let i = 0; i < slides.length; i++) {
    const outPath = join(outputDir, `slide-${String(i + 1).padStart(2, '0')}.png`);
    renderSlide(slides[i], i, total, pillarContent.label, outPath);
    paths.push(outPath);
    console.log(`  ✓ Slide ${i + 1}/${total}`);
  }
  return paths;
}
