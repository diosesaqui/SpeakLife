# SpeakLife Backlog

A single, global running list of things to come back to. Add items here from any
chat or session as they come up, so nothing gets lost between conversations.

## How to use
- Add new items under **Open** as a checkbox line. Keep each item one or two
  lines; if it needs detail, link to a doc in `docs/`.
- Suggested format: `- [ ] <short title> — <why / context> (added YYYY-MM-DD)`
- When done, change `[ ]` to `[x]` and move it to **Done** with the date.
- Use the optional tags `[bug]`, `[feature]`, `[upkeep]`, `[release]`, `[idea]`
  to make scanning easier.

---

## Open

- [ ] [upkeep] Upgrade Cloud Functions to Node.js 22 before 2026-10-30 deadline — see `docs/TODO-functions-upkeep.md` (added 2026-06-15)
- [ ] [upkeep] Upgrade `firebase-functions` SDK to latest (has breaking changes) — see `docs/TODO-functions-upkeep.md` (added 2026-06-15)
- [ ] [release] Confirm App Store build number (`CURRENT_PROJECT_VERSION`) is bumped before the next upload (added 2026-06-15)
- [ ] [feature] Pray Like Jesus challenge — Phase 0: ship a 7-day prayer campaign in `enforcements.json` and generalize `Enforcement.length` off the hardcoded 7; see `docs/PRAY_LIKE_JESUS_CHALLENGE_RESEARCH.md` (added 2026-08-19)
- [ ] [idea] Anonymous Firebase auth + upgrade-to-Apple path — prerequisite for any pod/social challenge feature, `signInAnonymously` is absent today (added 2026-08-19)

## Done

<!-- Move completed items here, e.g.:
- [x] Bump app version to 4.34 (done 2026-06-15)
-->
