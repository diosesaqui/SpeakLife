#!/usr/bin/env node
// SpeakLife Daily Carousel Delivery
// Generates today's carousel and sends all slides via Telegram

import { PILLARS, CONTENT } from './content.mjs';
import { renderCarousel } from './render.mjs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));

const dow = new Date().getDay();
const pillarKey = process.argv[2] || PILLARS[dow];
const pillarContent = CONTENT[pillarKey];

if (!pillarContent) {
  console.error(`Unknown pillar: ${pillarKey}`);
  process.exit(1);
}

const today = new Date().toISOString().slice(0, 10);
const outputDir = join(__dirname, 'output', `${today}-${pillarKey}`);

console.log(`Generating ${pillarContent.label} carousel for ${today}...`);
const paths = renderCarousel(pillarKey, pillarContent, outputDir);

// Output paths as JSON for the delivery agent to pick up
const result = {
  date: today,
  pillar: pillarKey,
  label: pillarContent.label,
  hashtags: pillarContent.hashtags,
  paths
};

console.log('DELIVERY_READY:' + JSON.stringify(result));
