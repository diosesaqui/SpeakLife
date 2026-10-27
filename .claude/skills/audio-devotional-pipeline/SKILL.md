---
name: audio-devotional-pipeline
description: End-to-end pipeline that turns a topic into a live SpeakLife audio devotional — writes the script, records it in the ElevenLabs "Daniel - Steady Broadcaster" voice, uploads the mp3 and the updated catalog to Firebase Storage, bumps Remote Config so every app picks it up with no release, and pushes a notification that opens the new episode. Trigger when the user gives a topic and wants a new audio devotional, episode, or "audio" made and published, or says "new episode on…", "make an audio devotional about…", "record a devotional", "publish an audio", or "run the audio pipeline".
---

# Audio Devotional Pipeline

Topic in, live episode out. Five steps, each a command in
`scripts/audio-devotional/publish.js`:

1. **Slot** — read the live catalog, find the next episode number.
2. **Script** — write the devotional (you, following the rules below).
3. **Voice** — record it with ElevenLabs in the Daniel voice.
4. **Publish** — upload mp3 → update `audioDevotionals.json` → bump `audioRemoteVersion`.
5. **Notify** — push to every user, opening the new episode.

## How the app picks up new audio (why this works with no app release)

| Piece | Where | Code |
|---|---|---|
| mp3 file | Storage bucket root, filename = episode `id` | `AudioDeclarationViewModel.downloadAudio` |
| Catalog | `audioDevotionals.json` at bucket root | `LocalAPIClient.downloadAudioDeclarations` |
| Refetch trigger | Remote Config `audioRemoteVersion` must go **up** | `SubscriptionStore` real-time listener → `fetchAudio(version:)` |
| Push deep link | data `{deepLink: "audio", audioId}` opens the Audio tab and plays it | `SpeakLifeApp.swift` `case "audio"` |

The app only re-downloads the catalog when `audioRemoteVersion` rises. The
script bumps it through the Remote Config API, so you never touch the console.
Apps that are open refresh within seconds (real-time listener); the rest
refresh on next launch. The push waits for the catalog to load before playing.

## Setup (once per environment)

Credentials come from environment variables. Never write them to a file in
the repo, never echo them.

- `FIREBASE_SERVICE_ACCOUNT` — the Firebase Admin service-account JSON for
  `speaklife-3e5c4` (raw JSON or base64). Firebase console → Project settings →
  Service accounts → Generate new private key. The default
  `firebase-adminsdk` account already has Storage, Remote Config and FCM rights.
- `ELEVENLABS_API_KEY` — optional. Without it, record through the ElevenLabs
  connector instead (see step 3).

In a cloud session these go in the environment's secrets / env vars. If either
is missing when you need it, call `read_documentation` with topic
`environment.secrets` so the user gets the settings button, then stop and ask.

Install deps once per session:

```bash
cd scripts/audio-devotional && npm install --no-audit --no-fund
```

## Step 1 — Find the slot

```bash
node publish.js next --tag speaklife
```

Prints the next season/episode, a suggested `id`, the current Remote Config
version, the available filters, and the last 15 titles in that tag. **Read
those titles** — the new episode must not repeat one.

Tag choice: default `speaklife` (the flagship devotional series,
`imageUrl: "devotional"`, ids `speaklife-s{S}e{E}.mp3`). Only use another tag
when the topic plainly belongs to that series (e.g. `divineHealth`,
`psalm91`, `newcreation`); copy that series' id pattern and `imageUrl` from
its existing episodes. Never invent an `imageUrl` — it must be an image
already bundled in the app, or the card renders blank.

New season? Only when the user says so. Otherwise continue the current season.

## Step 2 — Write the script

Write it to `scripts/audio-devotional/work/<id-without-.mp3>/script.txt`
(gitignored). This text is read **word for word** by the voice, so it contains
only what should be spoken: no headings, no stage directions, no markdown, no
emoji.

**Voice.** The founder speaking to one person: warm, direct, grace-first,
identity-first, Jesus speaking to storms rather than begging heaven to move.
Theological DNA: finished work of the cross, righteousness as a gift, the
believer's authority, healing and provision as already paid for. Never
condemning, never religious performance.

**Length.** 450–650 words (≈3–4 minutes). Existing episodes are 3–4m.

**Shape.**
1. **Hook (1–3 sentences).** Name what the listener is living in, in their words. No "Welcome back to SpeakLife".
2. **Scripture.** One anchor verse, quoted (NIV preferred) and said the way a person says it out loud: "Isaiah fifty-three, verse five", not "Isa 53:5".
3. **Teaching.** 2–3 short movements unpacking what the verse says is already true. Concrete, embodied, plain words. One idea per paragraph.
4. **Turn.** The shift from hearing to speaking: Jesus spoke to the fig tree, the wind, the fever. So do we.
5. **Declarations.** 4–6 lines the listener repeats. Introduce them with "Say this with me." Each one obeys `CLAUDE.md` declaration rules: first person, present tense, one sentence, no dashes, calls higher (never names the low thing as present), never softer than the verse, never claims another person will change.
6. **Close.** One or two sentences that send them into their day. No sign-off boilerplate.

**Built for the ear.**
- Short sentences. Read every line aloud in your head; cut anything you'd stumble on.
- No em or en dashes anywhere (TTS turns them into odd pauses). Use periods.
- Paragraph breaks are the pauses. Put a blank line between every paragraph, and after "Say this with me."
- Spell out numbers and references. Avoid parentheses, slashes, abbreviations.
- Plain words over church words (CLAUDE.md rule 8 and 15 apply to the whole script).

Also write `episode.json` next to it:

```json
{
  "id": "speaklife-s5e2.mp3",
  "title": "Short Title Case Hook",
  "subtitle": "SpeakLife",
  "imageUrl": "devotional",
  "isPremium": true,
  "tag": "speaklife",
  "season": 5,
  "episode": 2
}
```

`title` ≤ 5 words, punchy, matches the existing list's style ("Take Your
Dose", "The Higher Law"). `duration` is filled in from the mp3 automatically.
`isPremium: true` unless the user says free.

And the push copy (`push.json`):

```json
{ "title": "New: <episode title>", "body": "<one line, ≤ 90 chars, why tap now>" }
```

Push body follows the `speaklife-notifications` voice: speaks to the person,
no hype words, no exclamation pile-ups.

**Checkpoint.** Show the user the title, the full script, and the push copy
in one message and wait for a go. This is the one approval. (Recording costs
ElevenLabs credits and the push reaches every user and can't be unsent.) If
the user already said to run it end to end without checking in, skip the
wait.

## Step 3 — Record it

Voice: **Daniel - Steady Broadcaster** (`onwK4e9ZLuTAKqWW03F9`), the voice every existing episode uses.
Model `eleven_multilingual_v2`. Override with `--voice` only if the user asks.

**With `ELEVENLABS_API_KEY` set:**

```bash
node publish.js tts --script work/<slug>/script.txt --out work/<slug>/<id>
```

It splits long scripts on paragraph breaks, passes neighbouring text for
continuous tone, joins the mp3, and prints the length.

**Without the key — ElevenLabs connector:** load `creative_generate_speech`
via ToolSearch, generate with `voice_id: "onwK4e9ZLuTAKqWW03F9"` and the
script text, poll `creative_get_flow_run_status` until done, pick the better
of the takes, and download its audio URL with `curl -sSL -o work/<slug>/<id> "<url>"`.
Don't retry a generation call; it charges again.

Check the file: `ffprobe` duration should be roughly words ÷ 150 minutes. A
file under 30 seconds is broken and `publish` refuses it.

Send the mp3 to the user with `SendUserFile` so they can listen.

## Step 4 — Publish

Dry run first, then for real:

```bash
node publish.js publish --episode work/<slug>/episode.json --audio work/<slug>/<id> --dry-run
node publish.js publish --episode work/<slug>/episode.json --audio work/<slug>/<id>
```

What it does, in this order so the catalog never points at a missing file:
1. Validates the entry (required fields, `.mp3` id, unique id, real tag, known image).
2. Refuses if that mp3 already exists in Storage (`--force-upload` to replace audio on purpose).
3. Saves the live catalog to `backups/` (gitignored).
4. Uploads the mp3.
5. Inserts the episode at the top of `audios` and writes strict JSON back.
6. Bumps Remote Config `audioRemoteVersion` by one (and any conditional values below it).

It prints a `restore` command. If anything looks wrong after publishing:

```bash
node publish.js restore --backup backups/audioDevotionals.<stamp>.json
```

## Step 5 — Notify

Validate, then send. If the user gave an FCM token for their phone, send a
test there first and let them tap it before broadcasting.

```bash
node publish.js notify --title "..." --body "..." --audio-id <id> --broadcast --dry-run
node publish.js notify --title "..." --body "..." --audio-id <id> --test-token <TOKEN>   # optional
node publish.js notify --title "..." --body "..." --audio-id <id> --broadcast
```

Goes to the `allUsers` topic (every install subscribes on launch). It refuses
to send if the episode isn't live in Storage and the catalog. Wait at least a
minute after publishing before broadcasting so CDN and Remote Config settle.

## Report

One short message: the title, that it's live, Remote Config version from → to,
push sent (or not), and the `restore` command. Commit nothing for a normal
run — the episode lives in Firebase, not the repo.

## Don'ts

- Don't edit the bundled `Preview Content/AffirmationData/audioDevotionals.json` as part of a run; it's an offline fallback, not the live catalog.
- Don't hand-edit `audioRemoteVersion` in the console alongside the script; the script reads and bumps it.
- Don't broadcast a push for an episode that failed to upload.
- Don't reuse an existing `id`. Cached copies on devices are keyed by filename, so a reused name can play the old audio.
