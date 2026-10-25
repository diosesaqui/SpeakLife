# Growth Loops: Priority List

Written 2026-10-25. Ranked by expected installs per hour of build work. Each
loop names the app that proved it, what it looks like in SpeakLife, and the
number that says whether it worked.

## Where we start (PostHog, last 30 days, ~3,000 active users)

- **Referral installs: 0.** About 200 people shared something, but no share
  carried a tracked link. The burst share had no link at all; the devotional
  share used a bare App Store URL.
- **Shares by surface (users):** devotional 102, daily burst 54, declaration 33.
- **Stand funnel:** 56 created → 23 shown the invite prompt → 13 sent → 3
  opened → 1 joined. It breaks at both ends: few people send, and almost no
  one who gets the invite joins.

The rule for everything below: **no share leaves the app without a tracked
link** (`ReferralLink`). Otherwise none of it can be measured.

---

## Priority

| # | Loop | Proven by | Effort | Status |
|---|------|-----------|--------|--------|
| 1 | Tracked link on every share | Dropbox | ½ day | **Shipping** (declaration, burst, devotional) |
| 2 | Declaration story card | YouVersion Verse Images | 1–2 days | **Shipping** |
| 3 | Fix the Stand invite loop | Duolingo Friend Streaks | 3–5 days | Next |
| 4 | "Speak it over someone" | YouVersion verse to a friend | 3 days | Next |
| 5 | Guest passes for subscribers | Headspace Buddy Pass, Calm, Spotify | 3–4 days | Later |
| 6 | Year in Review (Wrapped) | Spotify Wrapped | 2 days polish | **Ship by Dec 1** |
| 7 | Church / group leader campaigns | Hallow parishes, YouVersion church plans | 1–2 weeks | Later |
| 8 | Shared widget | Locket | 1 week | Explore |

### 1. Tracked link on every share (done in this PR)
Branch long link on the `speaklife.app.link` root, tagged `channel=share`,
`feature=<surface>`, plus the sharer's anonymous id (`sl_ref`) for credit
later. `BranchAttribution` already files `share` as `referral`.
**Still to tag:** the Profile "Share SpeakLife" row, Bible verse share,
audio favourite share, streak card.
**Measure:** `acquisition_channel = referral` installs per week.

### 2. Declaration story card (done in this PR)
1080×1920 card on the user's own theme photo: "I DECLARE" (or "JESUS SAYS"
for Jesus-voice lines), the declaration in serif, the verse and reference in
gold, and a "Speak it with SpeakLife" badge. Instagram Stories now opens
straight into the story editor instead of saving to Photos.
**Next:** put the card *in front of* the user after they speak a
declaration ("Share today's word"), not only behind the share button.
Prompted shares beat buried ones.
**Measure:** `share_tapped` with `share_method = story_card | instagram_stories`
per declaration viewer; referral installs with `feature = declaration_card`.

### 3. Fix the Stand invite loop
The feature exists and people want it (56 stands in a month); the plumbing
loses them. In order:
1. Make inviting the default step when a stand starts, not an optional
   prompt (only 23 of 56 even saw it).
2. Confirm the no-app path works end to end (link → App Store → install →
   join), since 13 sends produced 3 opens. See `StandLink.shareHost` and
   `docs/STAND_TOGETHER_HANDOFF.md` step 2d.
3. Show the pair streak on Today ("You and Mom: day 5") so it pulls both
   people back daily.
**Measure:** `stand_invite_shared / stand_created` and
`stand_joined / stand_invite_shared`.

### 4. "Speak it over someone"
Pick a declaration, add a name, send it. The link opens the app on that
declaration with "Sarah declared this over you." It's a gift, not an ad,
and it fits the brand: it declares God's promise toward someone without
claiming they will change (CLAUDE.md rule 6).
**Measure:** sends per sender, installs per send.

### 5. Guest passes
Every subscriber gets two 7-day premium passes to give. The friend gets
premium, and the sharer gets a reason to invite that has nothing to do with
being a fan. Needs a RevenueCat promotional entitlement and a redeem link.
**Measure:** passes sent, redeemed, and redeemer → paid conversion.

### 6. Year in Review
`YearInReviewView` already exists. Make it a story-format, share-first
experience (same card system as #2) and launch it with a push in early
December, when everyone is sharing their Wrapped.
**Measure:** share rate on the screen; referral installs in December.

### 7. Church and group leaders
One pastor sharing a 7-day stand reaches a congregation. Needs a leader view
(group size, who has spoken today) and a bigger room limit than 12. Highest
reach per invite, and the longest build.

### 8. Shared widget
A friend's declaration of the day on your home screen. Strong daily pull,
but lower priority until 3 and 4 show people will invite at all.
