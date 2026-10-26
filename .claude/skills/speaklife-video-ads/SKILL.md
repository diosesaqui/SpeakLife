---
name: speaklife-video-ads
description: Make a SpeakLife talking-head video ad end to end with an AI character (Sofia, Grace or Naomi) — script, start frame, lip-synced Higgsfield video, word-by-word captions with an Instagram-style hook, ad copy, upload to Meta and the ad itself. Use when asked for "a video ad", "a FaceTime video", "make a Sofia video", "a Grace/Naomi video", "a talking video about X", "another one like FT-04", "caption this video", "upload the video to the ad set", or any request to turn an angle, verse or story into a short vertical video ad for Meta/Instagram/TikTok.
---

# SpeakLife Video Ads (AI character, FaceTime style)

A 15 or 30 second vertical video of one of our AI characters talking straight into her front
camera like she is on FaceTime with a friend, captioned, with copy, running as a Meta ad.
Examples that shipped: FT-01 to FT-05, UV-01, UV-02 in
`docs/creative/videos/2026-10-25-sofia/facetime/` (scripts and copy in `SCRIPTS.md` there).

## 0 · Before anything

- **Copy:** use the `faith-ad-formulas` skill (Copy Vault) and `speaklife-personas` for the angle and
  the `ob=` code. For a pray-vs-speak angle, `speaklife-ad-primary-text` has the six-beat spine.
- **Credits:** check Higgsfield `balance`. Costs: image 1.5 credits, video at 720p ≈ 7 credits per
  second (15s = 105, 30s = 210). Say the cost before generating.
- **Character:** default to **Sofia** unless the user names another. IDs below.

## 1 · Characters

| Name | Look | Master image job (use as `image_references`) | Soul ID | Element ID |
|---|---|---|---|---|
| Sofia | Latina, golden bronze skin, long black hair | `53c3e5a8-4d89-4bde-8768-00006af94781` | `dda4be43-fe1f-4482-b610-0925260ce57c` | `715e401f-55af-4bb6-b6ef-2a991f5a1e38` |
| Grace | White, blue eyes, long blonde hair, freckles | `10ef258a-0dcc-4ace-9d2d-3ecda957b8d3` | `2c8cc992-3181-440e-bb8d-49e926e41cf8` | `436f784c-765b-4a7f-9fd0-c83c7c1b1d0b` |
| Naomi | Deep brown skin, long straight black hair | `6b3fa90f-bd40-4797-b7cb-2f123f997055` | `19564973-fad2-4d8a-a25a-96fc3cedbbaf` | `37822e0b-7d52-4e2d-a191-28c87d409d80` |

Masters and training photos: `docs/creative/characters/`. Always start from the master job, never a
text-only prompt, or the face drifts.

## 2 · Script rules

- **She is an AI character.** Second person ("you know that feeling…"), or she retells someone
  else's real story ("the guy who built SpeakLife…"). Never a first-person testimony of her own.
- **Length:** 30s ≈ 75–80 spoken words, 15s ≈ 35–40. One idea. Hook in the first sentence.
- **Meta personal attributes:** never "you + a condition" ("struggling with anxiety?"). Phrase
  situations as moments: "When fear gets loud…", "When money's tight…".
- **No outcome claims.** Quote what Scripture promises; never promise what the app does.
- **Don't speak verse numbers** unless the angle needs it. Quote the verse; the reference shows as
  an on-screen chip (step 5). If a number is spoken, write it as words in the prompt ("Psalm one
  twelve, seven").
- **Never knock prayer.** "Keep praying, and start speaking."
- End on SpeakLife in one line (what it gives, not a feature list).
- Add the script, long and short primary text, headline and description to the batch's
  `SCRIPTS.md` before generating.

## 3 · Start frame (Higgsfield `generate_image`)

```
model: gpt_image_2_5, aspect_ratio: 9:16, quality: high
medias: [{role: image_references, value: <master image job>}]
prompt: "The exact same young woman as the reference, same face and features. This image IS the
view from her phone's front camera during a video call while she <setting>: vertical close selfie
at arm's length, <light>, <background softly blurred>, <outfit>, <hair>, small gold cross necklace.
She looks straight into the lens with <emotion matching the script>, lips parted mid-sentence.
NO phone visible anywhere. Real iPhone front-camera look, slight wide angle, natural skin texture.
Absolutely no text, no captions, no interface, no icons, no status bar, no legible signs."
```

Pick a setting not used yet (used: bedroom, window, city sidewalk, balcony, parked car, kitchen).
Download and **look at it** before spending video credits: same face, no phone, no text.
`soul_2` frames tend to add a phone and fake UI, so use `gpt_image_2_5` as above.

## 4 · Video (Higgsfield `generate_video`)

```
model: seedance_2_5, mode: omni_reference, duration: 15 | 30, resolution: 720p,
aspect_ratio: 9:16, generate_audio: true, use_unlim: false
medias: [{role: start_image, value: <start frame job>}, {role: image_references, value: <master job>}]
prompt: "One continuous handheld front-camera selfie take, like a FaceTime call <setting>, no cuts.
The young woman from the start frame talks straight into the lens to a close friend with <energy>,
small natural head movements. Real lip-sync to her own voice. Same <outfit>, same <place>
throughout. Her voice: young American woman in her early twenties, warm, confident,
conversational. She says exactly, in English, at a natural pace: \"<SCRIPT>\" Only her voice and
faint room tone. No music, no other voices, no on-screen text, no captions, no phone visible."
```

- A 30s render takes about 9–15 minutes. Poll with `jobs_wait`; tell the user it's rendering.
- `429 not_enough_boost_credits` with enough credits: retry once with `use_unlim: false`.
- A `preset_recommendation` notice: retry with `declined_preset_id` (we want the literal prompt).
- Save the raw file next to the batch as `<id>-raw.mp4`.

## 5 · Captions (`docs/creative/videos/tools/caption_v2.py`)

The approved look: big condensed uppercase phrases, the spoken word on a yellow box, keywords in
gold, verse reference chips, and an Instagram-native hook (TikTok Sans SemiBold, white highlight,
sentence case). Do not use the old pill style (`caption_v1_pill.py`).

```bash
python3 docs/creative/videos/tools/caption_v2.py <raw.mp4> <ID-slug-character.mp4> \
  --hook "Prayer asks. Declaration enforces. Here's the difference 👇" \
  --keywords prayer,declaration,health,peace,provision,speak,speaklife \
  --refs '[["wounds","ISAIAH 53:5"],["my","JOHN 14:27"],["god","PHILIPPIANS 4:19"]]' \
  --fixes '{"health?":"health."}'
```

- **Hook:** sentence case, how a creator would type it, one emoji max. Avoid 🤍 on the white
  highlight (it disappears). Preview first: add `--still 1.0 preview.png`.
- **Refs:** each trigger is the first word of the quoted verse, matched after the previous chip.
- **Check the transcript** the script prints against the script. Whisper mistakes go in `--fixes`
  (seen: "SAM" → Psalm, "13914," → "139:14,", statements heard as questions).
- **Check frames:** grab 8–10 frames with ffmpeg into a contact sheet and look: phrases on one line,
  chips appear and clear with their sentence, hook readable.
- Thumbnail: `ffmpeg -ss 0.8 -i <final.mp4> -frames:v 1 <ID>-thumbnail.png` (shows the hook).
- Send the finished video to the user with `SendUserFile` before uploading.

## 6 · Upload to Meta

Meta cannot fetch Higgsfield URLs (robots.txt), and the local file picker often doesn't render.
The working route is a public GitHub raw URL on the media branch:

```bash
WT=<scratchpad>/media-wt
git fetch -q origin claude/sofia-facetime-media
git worktree add -q "$WT" origin/claude/sofia-facetime-media --detach
# copy <ID>-*.mp4 and <ID>-thumbnail.png into the same path under $WT, commit, then:
git push origin HEAD:claude/sofia-facetime-media && git worktree remove "$WT"
# URL: https://raw.githubusercontent.com/diosesaqui/SpeakLife/claude/sofia-facetime-media/<path>
```

Then with the Meta Ads tools (account `253451158661796`):

1. `ads_creative_upload_media` · `upload_source: URL`, `media_type: VIDEO` for the mp4, `IMAGE` for
   the thumbnail. Wait until `ads_get_ad_videos` shows `video_status: ready`.
2. `ads_create_creative` · `page_id 104027662277976`, `video_id`, `image_hash` (thumbnail),
   `link_url http://itunes.apple.com/app/id1617492998`, `call_to_action_type DOWNLOAD`,
   `headline`, `message` (primary text). Leave `self_ai_disclosure` for the user to decide.
3. `ads_create_ad` · `creative: {"creative_id": "..."}` in the ad set the user names. Created PAUSED.
4. `ads_activate_entity` (`publish_as_active: true`) **only if the user said to turn it on.**
5. Read back with `ads_get_ad_entities` (level ad, filter `adset.id`): new ads show `IN_PROCESS`
   until review clears.

| Thing | ID |
|---|---|
| Ad account ("Riccardo Washington") | `253451158661796` |
| Page | `104027662277976` |
| App (iOS) | `1617492998` · FB app `904572920975437` |
| Scale campaign "SL Scale \| Mind winners \| Oct 2026" | `120247236092730227` |
| Ad set "women 25-65 Videos \| Sofia" (all character videos) | `120247598207200227` |

New ad sets need `campaign_attribution: AEM`, `promoted_object` {application_id 904572920975437,
object_store_url http://itunes.apple.com/app/id1617492998, custom_event_type START_TRIAL}.

## 7 · Wrap up

Tell the user, in plain words: what the video says, the hook and headline, where it is running,
whether it is on or paused, credits spent. Add the finished files to the batch folder.
