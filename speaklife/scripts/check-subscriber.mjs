#!/usr/bin/env node
/**
 * SpeakLife Subscriber Lookup
 *
 * Usage:
 *   node check-subscriber.mjs <support_id>
 *
 * <support_id> = the RC anonymous ID the user copies from Settings → "Copy Support ID"
 * Looks like: $RCAnonymousID:abc123...
 *
 * Returns: trial / paid / expired / never subscribed + a clear VERDICT
 */

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const secrets = JSON.parse(readFileSync(resolve(__dirname, '../secrets.json'), 'utf8'));
const RC_SECRET_KEY = secrets.RC_SECRET_KEY || process.env.RC_SECRET_KEY;
const PROJECT_ID = 'proj277bfd63';

const USER_ID = process.argv[2];

if (!USER_ID) {
  console.error('Usage: node check-subscriber.mjs <support_id>');
  console.error('Support ID looks like: $RCAnonymousID:abc123...');
  process.exit(1);
}

if (!RC_SECRET_KEY) {
  console.error('❌ RC_SECRET_KEY not found in secrets.json');
  process.exit(1);
}

async function getCustomer(userId) {
  const encoded = encodeURIComponent(userId);
  const res = await fetch(
    `https://api.revenuecat.com/v2/projects/${PROJECT_ID}/customers/${encoded}`,
    { headers: { Authorization: `Bearer ${RC_SECRET_KEY}` } }
  );
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`RC error ${res.status}: ${await res.text()}`);
  return res.json();
}

async function getActiveEntitlements(userId) {
  const encoded = encodeURIComponent(userId);
  const res = await fetch(
    `https://api.revenuecat.com/v2/projects/${PROJECT_ID}/customers/${encoded}/active_entitlements`,
    { headers: { Authorization: `Bearer ${RC_SECRET_KEY}` } }
  );
  if (!res.ok) return [];
  const data = await res.json();
  return data.items || [];
}

async function getPurchases(userId) {
  const encoded = encodeURIComponent(userId);
  const res = await fetch(
    `https://api.revenuecat.com/v2/projects/${PROJECT_ID}/customers/${encoded}/purchases?limit=5`,
    { headers: { Authorization: `Bearer ${RC_SECRET_KEY}` } }
  );
  if (!res.ok) return [];
  const data = await res.json();
  return data.items || [];
}

async function main() {
  console.log(`\n🔍 Looking up Support ID: ${USER_ID}\n`);

  const customer = await getCustomer(USER_ID);

  if (!customer) {
    console.log('❓ NOT FOUND in RevenueCat');
    console.log('   → ID is wrong, or user never opened the app');
    console.log('\n🔴 VERDICT: Cannot verify. Ask them to re-copy their Support ID from Settings.\n');
    return;
  }

  const [entitlements, purchases] = await Promise.all([
    getActiveEntitlements(USER_ID),
    getPurchases(USER_ID),
  ]);

  // ── Display customer basics ────────────────────────────────────────────────
  const firstSeen = customer.first_seen_at
    ? new Date(customer.first_seen_at).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
    : 'unknown';
  const lastSeen = customer.last_seen_at
    ? new Date(customer.last_seen_at).toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' })
    : 'unknown';

  console.log(`📱 Platform:   ${customer.last_seen_platform || 'unknown'} ${customer.last_seen_platform_version || ''}`);
  console.log(`🌍 Country:    ${customer.last_seen_country || 'unknown'}`);
  console.log(`📅 First seen: ${firstSeen}`);
  console.log(`📅 Last seen:  ${lastSeen}`);
  console.log(`📦 App version: ${customer.last_seen_app_version || 'unknown'}`);

  // ── Entitlement status ────────────────────────────────────────────────────
  console.log('');

  if (entitlements.length > 0) {
    const ent = entitlements[0];
    const expires = ent.expires_at ? new Date(ent.expires_at) : null;
    const expiresStr = expires ? expires.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' }) : 'never';

    // Detect trial from purchases
    const inTrial = purchases.some(p => p.period_type === 'trial' && p.is_sandbox === false);
    const isTrial = inTrial && expires && expires > new Date();

    if (isTrial) {
      console.log(`Status:  🔄 FREE TRIAL`);
      console.log(`Detail:  Trial active — expires ${expiresStr}`);
    } else {
      console.log(`Status:  ✅ PAID SUBSCRIBER`);
      console.log(`Detail:  Active — renews/expires ${expiresStr}`);
    }
    console.log(`Entitlement: ${ent.entitlement_identifier}`);
  } else if (purchases.length > 0) {
    // Had purchases but no active entitlement → expired/churned
    const last = purchases[0];
    const expiresAt = last.expires_at ? new Date(last.expires_at).toLocaleDateString() : 'unknown';
    console.log(`Status:  💸 CHURNED / EXPIRED`);
    console.log(`Detail:  Was subscribed, last expired ${expiresAt}`);
    console.log(`Product: ${last.product_identifier || 'unknown'}`);
  } else {
    console.log(`Status:  🆕 NEVER SUBSCRIBED`);
    console.log(`Detail:  No purchase history`);
  }

  // ── Verdict ───────────────────────────────────────────────────────────────
  console.log('\n─────────────────────────────────────────────');
  if (entitlements.length > 0) {
    console.log('🟢 VERDICT: Legitimate subscriber. OK to help.');
  } else if (purchases.length > 0) {
    console.log('🟡 VERDICT: Was a real subscriber, now inactive. Use judgment.');
  } else {
    console.log('🔴 VERDICT: No purchase history. Likely fishing for a free code.');
  }
  console.log('─────────────────────────────────────────────\n');
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
