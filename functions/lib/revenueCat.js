/**
 * Server-side RevenueCat entitlement check, shared by every function that
 * gates on premium (bibleChat, generateCategoryDevotional).
 */

const PREMIUM_ENTITLEMENT = 'premium';

// Returns true/false when RC gives a definitive answer, or null when RC is
// unreachable/misconfigured (bad key, outage) so the caller can fall back to the
// client's premium claim instead of wrongly locking a paying user out.
async function isPremiumViaRevenueCat(appUserId, secretKey) {
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      { headers: { Authorization: `Bearer ${secretKey}` } }
    );
    if (!resp.ok) {
      console.warn(`RC lookup ${resp.status} for ${appUserId} — falling back to client claim`);
      return null;
    }
    const data = await resp.json();
    const ent = data && data.subscriber && data.subscriber.entitlements
      ? data.subscriber.entitlements[PREMIUM_ENTITLEMENT]
      : null;
    if (!ent) return false;
    // No expiry → lifetime/non-expiring. Otherwise active if expiry is future.
    if (!ent.expires_date) return true;
    return new Date(ent.expires_date).getTime() > Date.now();
  } catch (err) {
    console.error('RC check failed:', err.message);
    return null;
  }
}

module.exports = { isPremiumViaRevenueCat };
