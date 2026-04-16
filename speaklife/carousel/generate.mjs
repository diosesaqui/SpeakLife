#!/usr/bin/env node
// SpeakLife Daily Carousel Generator
// Usage: node generate.mjs [pillar]
// If no pillar given, uses today's day-of-week rotation

import { PILLARS, CONTENT } from './content.mjs';
import { renderCarousel } from './render.mjs';
import { mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Get pillar
const arg = process.argv[2];
const dow = new Date().getDay();
const pillarKey = arg || PILLARS[dow];
const pillarContent = CONTENT[pillarKey];

if (!pillarContent) {
  console.error(`Unknown pillar: ${pillarKey}. Valid: ${Object.keys(CONTENT).join(', ')}`);
  process.exit(1);
}

// Output dir: speaklife/carousel/output/YYYY-MM-DD-pillar/
const today = new Date().toISOString().slice(0, 10);
const outputDir = join(__dirname, 'output', `${today}-${pillarKey}`);

console.log(`\n🙏 SpeakLife Carousel Generator`);
console.log(`   Pillar: ${pillarContent.label}`);
console.log(`   Output: ${outputDir}\n`);

const paths = renderCarousel(pillarKey, pillarContent, outputDir);

// Write metadata
import { writeFileSync } from 'fs';
const meta = {
  date: today,
  pillar: pillarKey,
  label: pillarContent.label,
  hashtags: pillarContent.hashtags,
  slideCount: paths.length,
  slides: paths.map((p, i) => ({ index: i + 1, path: p, type: pillarContent.slides[i].type }))
};
writeFileSync(join(outputDir, 'meta.json'), JSON.stringify(meta, null, 2));

console.log(`\n✅ Done! ${paths.length} slides generated.`);
console.log(`📁 ${outputDir}`);
console.log(`\n📣 Hashtags:\n${pillarContent.hashtags}`);
console.log(`\n📤 Output paths:`);
paths.forEach(p => console.log(`   ${p}`));
