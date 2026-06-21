# TODO — Cloud Functions upkeep (deferred)

Not urgent. Everything currently deploys and runs fine. These are maintenance
items flagged by warnings during `firebase deploy`. Knock them out before the
Oct 2026 deadline below.

---

## 1. Upgrade Cloud Functions runtime to Node.js 22

- **Why:** Node.js 20 is deprecated. Deploys keep working until **2026-10-30**,
  after which you can't deploy without upgrading.
- **Risk:** Low (one-line change).
- **Steps:**
  1. In `functions/package.json`, change `"engines": { "node": "20" }` → `"22"`.
  2. `cd functions && npm install`
  3. `firebase deploy --only functions` and confirm all functions deploy clean.
- **Status:** ☐ not started

## 2. Upgrade `firebase-functions` SDK to latest

- **Why:** `functions/package.json` pins `firebase-functions@^5.0.0`; newer
  versions have fixes/features. Firebase nudges this on every deploy.
- **Risk:** Medium — the maintainers warn of **breaking changes** across major
  versions. Treat as its own task with a careful diff + test deploy, not a blind
  bump.
- **Steps:**
  1. `cd functions && npm install --save firebase-functions@latest`
  2. Review the migration guide for breaking changes; adjust function code as
     needed (v2 APIs, params/secrets usage, etc.).
  3. Test each function with a deploy (and a real invocation where possible):
     `sendPersonalMessage`, `bibleChat`, and the prayer-wall triggers.
- **Status:** ☐ not started

---

## Related: release build number (App Store)

- When cutting the 4.34 App Store build, only `MARKETING_VERSION` was bumped to
  4.34. If your Xcode archive doesn't auto-increment the build number
  (`CURRENT_PROJECT_VERSION`), bump it before uploading to App Store Connect.
- **Status:** ☐ check before next upload
