/**
 * Cloud Functions entry point.
 * Aggregates every function module so `firebase deploy` discovers them all.
 */
module.exports = {
  ...require('./prayerWallNotifications'),
  ...require('./bibleChat'),
  // Fork of bibleChat that additionally renders the user's SoulProfile into
  // the prompt. Separate function, not an edit, so the live chat path is never
  // redeployed to ship personalization — the client picks between them on
  // Remote Config `bibleChatPersonalized`.
  ...require('./bibleChatPersonal'),
  ...require('./declarationMatch'),
  // Retrieval only — picks and sequences 30 declaration IDs out of the shipped
  // library. Nothing it returns was written by a model.
  ...require('./declarationArc'),
  // weeklyFocus + weeklyFocusDevotional. Both premium-gated server-side, so a
  // free caller costs nothing but a RevenueCat lookup.
  ...require('./weeklyFocus'),
  ...require('./personalMessage'),
};
