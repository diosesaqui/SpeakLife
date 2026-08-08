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
- [ ] [upkeep] Move `ClaudeDeclarationMatcher` behind a Cloud Function proxy — the Anthropic key currently reaches the device via Remote Config with no rate limit or spend cap; blocks all new generation work — see `docs/AI-PERSONALIZATION-PLAN.md` §A (added 2026-08-08)
- [ ] [feature] Capture onboarding answers into a persisted `SoulProfile` — 12+ collected fields are emitted as analytics params then dropped app-side — see `docs/AI-PERSONALIZATION-PLAN.md` §B (added 2026-08-08)
- [ ] [feature] Wire `hitsHardest` into notification scheduling — users tell us when they hurt during onboarding and we discard it; no AI required — see `docs/AI-PERSONALIZATION-PLAN.md` §B (added 2026-08-08)
- [ ] [bug] `personalDeclarationBelief` is in-memory only (`UserPreferencesTracker.swift:105`) — paywall personalization degrades to generic copy after any relaunch (added 2026-08-08)
- [ ] [bug] `IdentityOnboardingView` never writes `onboardingSegment` — that A/B arm is invisible to segment-based paywall copy (added 2026-08-08)
- [ ] [feature] Weekly Focus — Sunday check-in driving each week's declarations, audio, and devotionals — see `WEEKLY_FOCUS_SPEC.md` and `docs/AI-PERSONALIZATION-PLAN.md` §D (added 2026-08-08)
- [ ] [idea] Write real `confidence` declarations so `SurveyGoalWord.confidence` can point back at its own category instead of borrowing `identity` — "I refuse to settle" deserves its own voice. Same for `strength`, which is also empty but currently unreachable (nothing maps to it). See the `confidence → identity` note in `SurveyTypes.swift` (added 2026-08-08)
- [ ] [bug] Verify `declarationsv9.json` is actually bundled — `LocalAPIClient.swift:24` defaults to it and no such file is in `Preview Content/AffirmationData/`; a fresh install failing the Remote Config fetch may get an empty array (added 2026-08-08)

## Done

- [x] [bug] Users who picked "I refuse to settle" landed on `DeclarationCategory.confidence`, which has zero declarations — empty daily pushes and an empty-category feed branch. Mapped `confidence → identity` in `SurveyGoalWord`, removed it from the three `notificationCategories` sets that carried it, and added a one-shot `confidenceCategoryHealedV1` migration for users already stranded on the value (done 2026-08-08)

<!-- Move completed items here, e.g.:
- [x] Bump app version to 4.34 (done 2026-06-15)
-->
