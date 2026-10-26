# Growth Loops: Build Plan (items 1–4 and 6)

Written 2026-10-25. Companion to `docs/GROWTH_LOOPS.md`, which ranks the loops
and explains why. This file says exactly what gets built, where, and how we
know it worked.

Baseline (PostHog, last 30 days, about 3,000 active users):

| Signal | Value |
|---|---|
| Installs credited to `referral` | 0 |
| Users sharing anything | ~200 |
| Stand: created → invite sent → opened → joined | 56 → 13 → 3 → 1 |

All five items ship as separate PRs from branches cut from
`claude/growth-loops-plan`. That branch already carries the shared pieces, so
no PR has to touch them:

- `ReferralLink.Feature` has a case for every surface below.
- `ReferralLink.url(_:campaign:extra:)` takes extra query items (item 4 uses them).
- `ReferralLink.referrerKey` (`sl_ref`) names the sharer key.

---

## File ownership (to keep five parallel PRs from colliding)

| Item | Owns | Must not touch |
|---|---|---|
| 1 Links | ProfileView, FavoritesView, TrackerView, AudioFavoritesView, DevotionalView (`:164`), DeclarationView (`:572`), BibleViewModel, DailyVerseDetailView, BibleChatAnswerView; `BranchAttribution.apply` (referrer only) | DailyDeclarationBurstView, DeclarationContentView, Stand*, YearInReview*, SpeakLifeApp |
| 2 Card | DailyDeclarationBurstView, DeclarationContentView, DeclarationStoryCard | Stand*, YearInReview*, AppDelegate |
| 3 Stand | Views/Stand/*, Services/Stand/* | ReferralLink, DeclarationContentView, AppDelegate (except Stand-only lines) |
| 4 Speak over | new `Views/SpeakOver/*`, SpeakLifeApp `onOpenURL`, AppState (one new field), `BranchAttribution.apply` (gift keys only) | DeclarationContentView beyond adding one menu entry |
| 6 Year in Review | Views/YearInReview/*, HomeView (window logic only) | everything else |

**`project.pbxproj`.** Each PR uses its own object-ID prefix (`LINK…`, `CARD…`,
`STND…`, `SPKO…`, `YIRV…`). New entries go next to an existing file in the
item's own area, never next to `AcquisitionAttribution` or
`DeclarationContentView`.

Universal rules for every item:

- Every share leaves with `ReferralLink.url(...)`. Never a bare App Store URL.
- Copy follows CLAUDE.md: first person, present tense, no dashes, never claims
  another person will change.
- No Xcode in the build environment, so CI is the compiler. Re-read every diff
  for compile errors before pushing.

---

## 1. Tracked link on every remaining share

**Goal.** No share leaves the app untraceable, and an install from a share is
credited to the person who shared it.

**Changes**
1. Replace bare `APP.Product.urlID` and untagged shares with `ReferralLink.url`:
   - `ProfileView.swift:65,172`, the "Share SpeakLife" row → `.profileInvite`
   - `FavoritesView.swift:83` → `.favorite` (campaign: category)
   - `TrackerView.swift:45` → `.tracker`
   - `AudioFavoritesView.swift:123` → `.audioFavorite`
   - `DevotionalView.swift:164` (the second devotional share) → `.devotional`
   - `DeclarationView.swift:572` → `.profileInvite`
   - `BibleViewModel.swift:531` → `.bibleVerse`
   - `DailyVerseDetailView.swift:130` → `.dailyVerse`
   - `BibleChatAnswerView.swift:211` → `.bibleChat`
   - Leave alone: the App Store review link (`ProfileView:728`), ForceUpdateGate.
2. Close the credit loop. In `BranchAttribution.apply`, when params carry
   `sl_ref`, set person property `referred_by` (first touch only, never
   overwritten) and track `referral_install_attributed` with `feature`. This is
   what makes a future sharer reward possible.
3. Tests: `referred_by` is set from `sl_ref`, ignored when absent, never
   overwritten.

**Measure.** Weekly `acquisition_channel = referral` persons, broken down by
`acquisition_source` / feature. Target in the first 30 days: more than 0, and
every surface shows up at least once.

---

## 2. Story card: put it where the feeling is

**Goal.** Shares happen at emotional peaks, not behind a share icon. The card
already exists (`DeclarationStoryCard`). This item places it.

**Changes**
1. **Daily Burst completion** (`DailyDeclarationBurstView`, share at about
   `:960`). Replace the text-only "I just completed my Daily Victory Burst"
   share with the story card of the burst's strongest declaration, plus a line
   and `ReferralLink.url(.dailyBurst)`. Add an Instagram Stories button using
   `shareToInstagramStories(image:)`.
2. **Declaration feed nudge** (`DeclarationContentView`). After the 5th
   declaration of the day, once per day at most, show a small dismissible
   inline chip: "Share today's word". Tapping it opens the existing share menu
   for the current declaration. Persist the last nudge day in `UserDefaults`.
3. **Card polish from the review.** Render the quote mark in a fixed
   `Canvas`/frame so its position no longer depends on font metrics, and add a
   SwiftUI `#Preview` with three lengths (short, median, 211 chars) and a
   Jesus-voice line.
4. Analytics: `share_prompt_shown` and `share_prompt_tapped` with `surface`
   (`burst_complete`, `feed_nudge`).

**Measure.** Declaration and burst shares per daily active user, before vs
after. Target: 2× within 30 days.

---

## 3. Fix the Stand invite loop

**Goal.** Most stands that get created reach a second person.

**Where it breaks (funnel above).**
- **Opened the sheet but never tapped Send (43 of 56).** The sheet stacks a
  privacy line, a remote "ask them to update to 4.65" warning, and a code box
  around the button. The warning targets builds that are now a small share of
  the base.
- **Sent but never opened (10 of 13).** Builds 4.59–4.64 claim
  `speaklife.app.link` and drop `/stand/` links (see
  `StandLink.shareHost`).

**Changes**
1. **Simplify the send screen** (`StandInviteSheet`). The card and one big
   "Send the invite" button lead. The code moves under a "Can't open the link?"
   disclosure. Default `standInviteRecipientNote` to empty (Remote Config can
   still turn it back on). Keep the privacy line, but shorter.
2. **Share sheet straight away.** When the sheet was opened from "Invite
   someone" and the room is ready, open the system share sheet automatically
   once, with no second tap.
3. **Make inviting the default when a stand starts.** Find where an
   Enforcement campaign starts (`StandDiscovery` prompt budget,
   `StandInvitePromptSheet`) and show the prompt on day 1 every time, not only
   when the prompt budget allows. Keep "Maybe later".
4. **Pair streak on Today.** `StandInviteRow` already shows a joined room.
   Make it show "You and {name}: day N" with both people's dots for today, so
   both come back.
5. **Diagnostics.** Track `stand_invite_sheet_ready` (room minted) and
   `stand_invite_sheet_failed` (with error), so the 56 → 13 gap can be
   separated into "failed to load" vs "chose not to send".
6. Do **not** change `standLinkDomain` (see the handoff doc, step 2d). List
   the Branch and DNS steps for the founder in the PR body instead.

**Measure.** Count a stand as sent when it has a
`stand_invite_share_completed` with `completed = true` and `sent = true`
(any activity except Copy or Save Image). That is the real "sent" signal.
Targets: sent / `stand_created` above 50%, and `stand_joined` / sent above
25%. Do not use `stand_invite_share_opened` for this: the share sheet now
opens by itself after "Invite someone", so that event fires on nearly every
stand and would meet the target by construction. `stand_invite_shared`
still counts real taps on "Send the invite" only, so it stays comparable
with the 13-of-56 baseline. Also watch `stand_invite_sheet_ready` /
`stand_invite_sheet_failed` (load vs failure) and `stand_code_entry_opened`.

---

## 4. "Speak it over someone"

**Goal.** A person sends a declaration to someone they love. The recipient
opens the app straight onto it, and that's an install from a personal message,
the best-converting kind of referral.

**Framing (CLAUDE.md).** Declarations are first person, spoken by the
recipient. The sender is standing with them, not speaking over their will. The
recipient sees: "**{Sender} is standing with you.** Speak this out loud today:"
and then the declaration. Never imply the recipient will change.

**Changes**
1. **Send** (new `Views/SpeakOver/SpeakOverSheet.swift`). Opened from a new
   entry, "Send to someone", in the declaration share menu
   (`DeclarationContentView`, one `Button` added to the existing `Menu`, no
   other edits). Fields: your first name (remembered), their first name
   (optional). Preview of the story card, then the share sheet with the card
   image plus a message and link.
2. **Link** (`ReferralLink.url(.speakOver, campaign: category, extra:)`). Extra
   keys: `so_t` (declaration text), `so_b` (book), `so_from` (sender first
   name, max 30 chars), `so_to` (optional). Text is URL-encoded and capped at
   280 chars.
3. **Receive, installed** (`SpeakLifeApp.onOpenURL`). Parse the `so_*` keys
   from the URL and store them in a new `AppState.pendingSpeakOver`.
   **Receive, fresh install** (`BranchAttribution.apply`). Read the same keys
   from Branch params, store them in `UserDefaults`, and present only after
   onboarding finishes (same pattern as `pendingStandCode`).
4. **Present** (new `Views/SpeakOver/SpeakOverReceivedView.swift`). Full-screen
   card with the declaration and verse, "Speak it out loud" (reuse the existing
   speak or verify flow if it is simple to call, otherwise a "Done" button),
   and "Send one back".
5. Validation: ignore links whose text is empty or over the cap. Strip control
   characters. Never execute or render anything but plain text.
6. Analytics: `speak_over_sent`, `speak_over_opened` (`source`: link or
   deferred), `speak_over_spoken`, `speak_over_sent_back`.
7. Tests: parse round-trip (build URL → parse back), the cap, and rejection of
   empty or oversized text.

**Measure.** Sends per sender, `speak_over_opened / speak_over_sent`, and
installs with feature `speak_over`.

---

## 6. Year in Review, built to be shared

**Goal.** A December moment people post, each post carrying a link.

**Fix first.** `presentShare` renders at `UIScreen.main.scale` (3240×5760)
with point-sized fonts inside a 1080-wide frame, so the text comes out tiny.
Render at scale 1 with type sized for a 1080×1920 canvas.

**Changes**
1. Rebuild `ShareCardWrapper` in the visual language of
   `DeclarationStoryCard`: graded dark background, gold label, serif headline
   number, the "Speak it with SpeakLife" badge, all inside Instagram's safe
   zones.
2. Share text gets `ReferralLink.url(.yearInReview, campaign: "\(year)")`.
3. An Instagram Stories button next to Share
   (`shareToInstagramStories(image:)`).
4. **Window.** Open on Dec 1 instead of Dec 15 (HomeView, about `:994–1032`)
   to ride the Spotify Wrapped wave. Close date unchanged. Keep the
   once-per-year auto-launch.
5. Analytics: `year_in_review_opened`, `year_in_review_slide_viewed`
   (`slide`), and `year_in_review_shared` (`slide`, `method`).
6. Founder to-do (in the PR body, not code): a push broadcast on Dec 1, "Your
   year of standing is ready."

**Measure.** Share rate (`year_in_review_shared / year_in_review_opened`,
target 15%) and referral installs with feature `year_in_review` in December.

---

## Review gate

Each PR gets a full code review before merge: correctness, compile risk (no
local Xcode), CLAUDE.md copy rules, analytics naming, and collisions with the
other four PRs.
