/**
 * weeklyForYou.js
 * Firebase Cloud Functions — every Sunday evening, ten new declarations
 * written from the ones the user favorited that week, and a push when
 * they are ready.
 *
 *   syncForYouFavorites  POST from the app whenever favorites change or the
 *                        app opens: the favorites, push token and time zone.
 *   weeklyForYouRunner   Hourly. Writes the set for everyone whose Sunday
 *                        6pm has arrived, then sends the push.
 *   getWeeklyForYou      POST from the app: the latest set, with all but a
 *                        preview locked for free users.
 *
 * How the set is written and checked lives in lib/forYouGenerator.js, and
 * storage, scheduling and delivery in lib/forYouService.js. This file only
 * connects them to Firebase.
 *
 * ─── Firestore ──────────────────────────────────────────────────────────────
 *  forYou/{appUserId}               favorites, fcmToken, timeZone, nextRunAt
 *  forYou/{appUserId}/weeks/{week}  one written set per week
 *  verseCache/{reference}           public-domain verse lookups
 *  All written by these functions only; clients have no direct access.
 *
 * ─── Kill switch ────────────────────────────────────────────────────────────
 *  Remote Config key `weeklyForYouEnabled` (boolean, unset = off). The app hides
 *  the feature and the server stops syncing, serving and writing whenever
 *  its default value is not true.
 *
 * ─── Setup ──────────────────────────────────────────────────────────────────
 *  Same secrets as generateCategoryDevotional (ANTHROPIC_API_KEY,
 *  REVENUECAT_SECRET_KEY).
 *    firebase deploy --only functions:syncForYouFavorites,functions:getWeeklyForYou,functions:weeklyForYouRunner
 * ─────────────────────────────────────────────────────────────────────────────
 */

const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getRemoteConfig } = require('firebase-admin/remote-config');
const Anthropic = require('@anthropic-ai/sdk');

const { isPremiumViaRevenueCat } = require('./lib/revenueCat');
const { createForYouService, cachedVerseFetcher, spaced, VERSE_FETCH_SPACING_MS } = require('./lib/forYouService');
const { makeModelDeps } = require('./lib/forYouModels');
const { makeWebFetcher } = require('./lib/verseVerifier');
const { loadLibrary } = require('./lib/verseLibrary');
const { makeRemoteFlag } = require('./lib/remoteFlag');

const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');
const REVENUECAT_SECRET_KEY = defineSecret('REVENUECAT_SECRET_KEY');

// ─── Production wiring ──────────────────────────────────────────────────────

let productionService = null;
function production() {
  if (productionService) return productionService;
  if (getApps().length === 0) initializeApp();
  const db = getFirestore();
  productionService = createForYouService({
    db,
    messaging: getMessaging(),
    now: () => new Date(),
    // The same Remote Config key the app reads. Off (or unset) stops syncs,
    // hides sets and skips the Sunday run, so it is the one kill switch.
    isEnabled: makeRemoteFlag({ getTemplate: () => getRemoteConfig().getTemplate(), key: 'weeklyForYouEnabled' }),
    library: loadLibrary(),
    fetchVerse: cachedVerseFetcher(db, spaced(makeWebFetcher(), VERSE_FETCH_SPACING_MS)),
    modelDeps: () => makeModelDeps(new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() })),
    isPremium: async (appUserId, claim) => {
      const key = REVENUECAT_SECRET_KEY.value();
      if (!key) return claim;
      const rc = await isPremiumViaRevenueCat(appUserId, key);
      return rc === null ? claim : rc;
    },
  });
  return productionService;
}

function httpHandler(method) {
  return async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'method_not_allowed' });
      return;
    }
    try {
      const { status, json } = await production()[method](req.body || {});
      res.status(status).json(json);
    } catch (err) {
      console.error(`For You ${method} failed:`, err && err.message);
      res.status(500).json({ error: 'internal' });
    }
  };
}

exports.syncForYouFavorites = onRequest(
  { region: 'us-central1', cors: true },
  httpHandler('sync')
);

exports.getWeeklyForYou = onRequest(
  { region: 'us-central1', cors: true, secrets: [REVENUECAT_SECRET_KEY] },
  httpHandler('get')
);

exports.weeklyForYouRunner = onSchedule(
  {
    schedule: 'every 60 minutes',
    region: 'us-central1',
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 540,
    memory: '512MiB',
  },
  async () => {
    const result = await production().runDue();
    console.log('weeklyForYouRunner:', JSON.stringify(result));
  }
);

