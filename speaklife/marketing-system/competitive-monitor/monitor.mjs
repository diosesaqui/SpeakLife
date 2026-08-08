#!/usr/bin/env node
/**
 * SpeakLife Competitive Intelligence Monitor
 * Uses Firecrawl to scrape App Store pages, competitor websites, and review data.
 * Sends a daily digest to Telegram.
 *
 * Setup:
 *   1. Add FIRECRAWL_API_KEY to .env
 *   2. Run: node monitor.mjs
 *   3. Or schedule via cron
 */

import 'dotenv/config';
import FirecrawlApp from '@mendable/firecrawl-js';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CACHE_FILE = path.join(__dirname, '.cache.json');

const FIRECRAWL_API_KEY = process.env.FIRECRAWL_API_KEY;
if (!FIRECRAWL_API_KEY) {
  console.error('❌ FIRECRAWL_API_KEY not set. Add it to .env');
  process.exit(1);
}

const firecrawl = new FirecrawlApp({ apiKey: FIRECRAWL_API_KEY });

// ─── Targets ────────────────────────────────────────────────────────────────

const TARGETS = {
  speaklife: {
    name: 'SpeakLife (US)',
    appStoreUrl: 'https://apps.apple.com/us/app/speaklife/id1617492998',
    website: 'https://speaklife.app',
  },
  hallow: {
    name: 'Hallow',
    appStoreUrl: 'https://apps.apple.com/us/app/hallow-prayer-sleep-meditation/id1366070395',
    website: 'https://hallow.com',
    pricingUrl: 'https://hallow.com/pricing',
  },
  youversion: {
    name: 'YouVersion',
    appStoreUrl: 'https://apps.apple.com/us/app/bible-app-read-study-daily/id282935706',
    website: 'https://www.youversion.com',
  },
  abide: {
    name: 'Abide',
    appStoreUrl: 'https://apps.apple.com/us/app/abide-christian-meditation/id1056272839',
    website: 'https://abide.com',
    pricingUrl: 'https://abide.com/pricing',
  },
};

// ─── Scraper ─────────────────────────────────────────────────────────────────

async function scrapeUrl(url, label) {
  try {
    console.log(`  🔍 Scraping ${label}...`);
    const result = await firecrawl.scrapeUrl(url, {
      formats: ['markdown'],
      onlyMainContent: true,
    });
    if (result.success) {
      return result.markdown || result.content || '';
    }
    return `[Failed to scrape: ${result.error}]`;
  } catch (err) {
    return `[Error: ${err.message}]`;
  }
}

// ─── Extract Key Signals ─────────────────────────────────────────────────────

function extractRating(markdown) {
  const match = markdown.match(/(\d\.\d)\s*(?:out of 5|stars?|★)/i);
  return match ? match[1] : null;
}

function extractRatingCount(markdown) {
  const match = markdown.match(/([\d,]+)\s*(?:ratings?|reviews?)/i);
  return match ? match[1] : null;
}

function extractPrice(markdown) {
  // Look for subscription pricing patterns
  const monthly = markdown.match(/\$(\d+(?:\.\d+)?)\s*\/?\s*(?:mo|month)/i);
  const annual = markdown.match(/\$(\d+(?:\.\d+)?)\s*\/?\s*(?:yr|year|annual)/i);
  return {
    monthly: monthly ? `$${monthly[1]}/mo` : null,
    annual: annual ? `$${annual[1]}/yr` : null,
  };
}

function extractKeyFeatures(markdown, maxLines = 10) {
  // Extract bullet points / feature lines
  const lines = markdown.split('\n')
    .filter(l => l.match(/^[-*•]\s/) || l.match(/^#{1,3}\s/))
    .slice(0, maxLines)
    .map(l => l.trim());
  return lines;
}

// ─── Load / Save Cache ────────────────────────────────────────────────────────

async function loadCache() {
  try {
    const data = await fs.readFile(CACHE_FILE, 'utf-8');
    return JSON.parse(data);
  } catch {
    return {};
  }
}

async function saveCache(cache) {
  await fs.writeFile(CACHE_FILE, JSON.stringify(cache, null, 2));
}

// ─── Diff Detection ───────────────────────────────────────────────────────────

function detectChanges(prev, curr, field) {
  if (!prev || prev[field] !== curr[field]) {
    return { changed: true, from: prev?.[field] ?? 'N/A', to: curr[field] };
  }
  return { changed: false };
}

// ─── Main Runner ──────────────────────────────────────────────────────────────

async function runMonitor() {
  console.log('\n🚀 SpeakLife Competitive Monitor — Starting\n');

  const cache = await loadCache();
  const today = new Date().toISOString().split('T')[0];
  const report = {
    date: today,
    competitors: {},
    changes: [],
    insights: [],
  };

  for (const [key, target] of Object.entries(TARGETS)) {
    console.log(`\n📱 ${target.name}`);

    const appStoreMd = await scrapeUrl(target.appStoreUrl, 'App Store');
    const websiteMd = target.website ? await scrapeUrl(target.website, 'Website') : '';
    const pricingMd = target.pricingUrl ? await scrapeUrl(target.pricingUrl, 'Pricing') : '';

    const current = {
      rating: extractRating(appStoreMd),
      ratingCount: extractRatingCount(appStoreMd),
      pricing: extractPrice(pricingMd || websiteMd),
      features: extractKeyFeatures(websiteMd),
      scrapedAt: new Date().toISOString(),
    };

    report.competitors[key] = { ...target, ...current };

    // Diff against cache
    const prev = cache[key];
    if (prev) {
      const ratingChange = detectChanges(prev, current, 'rating');
      const ratingCountChange = detectChanges(prev, current, 'ratingCount');

      if (ratingChange.changed) {
        report.changes.push(`⭐ ${target.name} rating changed: ${ratingChange.from} → ${ratingChange.to}`);
      }
      if (ratingCountChange.changed) {
        report.changes.push(`📊 ${target.name} review count: ${ratingCountChange.from} → ${ratingCountChange.to}`);
      }
    }

    cache[key] = current;
  }

  await saveCache(cache);

  // ─── Build Digest ─────────────────────────────────────────────────────────

  const lines = [
    `🔍 *SpeakLife Competitive Intel — ${today}*\n`,
  ];

  // Ratings table
  lines.push('*App Store Ratings:*');
  for (const [key, data] of Object.entries(report.competitors)) {
    const star = key === 'speaklife' ? '🟢' : '⚪';
    const rating = data.rating ?? 'N/A';
    const count = data.ratingCount ?? '?';
    lines.push(`${star} ${data.name}: ⭐ ${rating} (${count} ratings)`);
  }

  // Pricing snapshot
  lines.push('\n*Competitor Pricing:*');
  for (const [key, data] of Object.entries(report.competitors)) {
    if (key === 'speaklife') continue;
    const mo = data.pricing?.monthly ?? '?';
    const yr = data.pricing?.annual ?? '?';
    lines.push(`• ${data.name}: ${mo} | ${yr}`);
  }
  lines.push('• SpeakLife: $10/mo | $50/yr ✅');

  // Changes detected
  if (report.changes.length > 0) {
    lines.push('\n*🚨 Changes Detected:*');
    report.changes.forEach(c => lines.push(`• ${c}`));
  } else {
    lines.push('\n✅ No major changes detected since last run.');
  }

  // Insights
  lines.push('\n_Powered by SpeakLife Marketing System_');

  const digest = lines.join('\n');

  console.log('\n─────────────────────────────────────');
  console.log(digest);
  console.log('─────────────────────────────────────\n');

  // Save report
  const reportPath = path.join(__dirname, `reports/report-${today}.json`);
  await fs.mkdir(path.join(__dirname, 'reports'), { recursive: true });
  await fs.writeFile(reportPath, JSON.stringify(report, null, 2));

  console.log(`✅ Report saved to ${reportPath}`);

  return digest;
}

runMonitor().catch(console.error);
