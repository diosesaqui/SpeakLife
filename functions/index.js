/**
 * Cloud Functions entry point.
 * Aggregates every function module so `firebase deploy` discovers them all.
 */
module.exports = {
  ...require('./prayerWallNotifications'),
  ...require('./bibleChat'),
};
