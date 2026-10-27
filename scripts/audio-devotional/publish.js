#!/usr/bin/env node
/**
 * publish.js — the SpeakLife audio devotional pipeline.
 *
 * Steps, each its own command so a failure never leaves things half-done
 * without you knowing where it stopped:
 *
 *   next     Read the live catalog and print the next free episode slot.
 *   tts      Turn a script text file into an mp3 with ElevenLabs.
 *   publish  Upload the mp3, add the episode to the live catalog, and bump
 *            Remote Config `audioRemoteVersion` so apps refetch it.
 *   notify   Push a notification that opens the new episode.
 *   restore  Put a backed-up catalog back live (undo a bad publish).
 *
 * How the app picks up new audio (no app release needed):
 *   - mp3s live at the root of the Storage bucket; an episode's `id` is its
 *     filename (AudioDeclarationViewModel.downloadAudio).
 *   - The catalog is `audioDevotionals.json` at the bucket root
 *     (LocalAPIClient.downloadAudioDeclarations).
 *   - The app only refetches the catalog when Remote Config
 *     `audioRemoteVersion` goes up. It listens for Remote Config updates in
 *     real time, so open apps refresh within seconds of the bump.
 *   - A push with data { deepLink: "audio", audioId } opens the Audio tab and
 *     plays that episode once the catalog has loaded (SpeakLifeApp.swift).
 *
 * Credentials (env vars, never committed):
 *   FIREBASE_SERVICE_ACCOUNT   service-account JSON, raw or base64.
 *                              (Or GOOGLE_APPLICATION_CREDENTIALS = path.)
 *   ELEVENLABS_API_KEY         only for the `tts` command.
 *
 * Run `node publish.js help` for flags.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const PROJECT_ID = 'speaklife-3e5c4';
const BUCKET = process.env.FIREBASE_STORAGE_BUCKET || 'speaklife-3e5c4.appspot.com';
const CATALOG_PATH = 'audioDevotionals.json';
const RC_KEY = 'audioRemoteVersion';
const PUSH_TOPIC = 'allUsers';
const DEFAULT_VOICE_ID = 'hg9PG9Wl6NW6CGaI2HBu'; // "Franchiz" cloned voice
const DEFAULT_MODEL = 'eleven_multilingual_v2';
const BACKUP_DIR = path.join(__dirname, 'backups');
const MAX_TTS_CHARS = 4500; // eleven_multilingual_v2 caps a request near 5,000 chars

// ── tiny arg parser ──────────────────────────────────────────────────────
function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) out[key] = true;
      else { out[key] = next; i++; }
    } else out._.push(a);
  }
  return out;
}

function die(msg) {
  console.error(`\n✖ ${msg}\n`);
  process.exit(1);
}

// ── Firebase ─────────────────────────────────────────────────────────────
let _admin;
function admin() {
  if (_admin) return _admin;
  const a = require('firebase-admin');
  let credential;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (raw) {
    const text = raw.trim().startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
    let json;
    try { json = JSON.parse(text); } catch { die('FIREBASE_SERVICE_ACCOUNT is not valid JSON (raw or base64).'); }
    credential = a.credential.cert(json);
  } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    credential = a.credential.applicationDefault();
  } else {
    die('No Firebase credentials. Set FIREBASE_SERVICE_ACCOUNT (service-account JSON, raw or base64).');
  }
  a.initializeApp({ credential, projectId: PROJECT_ID, storageBucket: BUCKET });
  _admin = a;
  return a;
}

const bucket = () => admin().storage().bucket();

// The live catalog has historically carried trailing commas, which strict
// JSON rejects. Strip them so we can read it; we always write strict JSON.
function parseLenient(text) {
  try { return JSON.parse(text); } catch {
    return JSON.parse(text.replace(/,(\s*[\]}])/g, '$1'));
  }
}

async function readCatalog() {
  const [buf] = await bucket().file(CATALOG_PATH).download();
  const text = buf.toString('utf8');
  return { text, catalog: parseLenient(text) };
}

function backupCatalog(text) {
  fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, '-');
  const file = path.join(BACKUP_DIR, `audioDevotionals.${stamp}.json`);
  fs.writeFileSync(file, text);
  return file;
}

async function writeCatalog(catalog) {
  const body = JSON.stringify(catalog, null, 4) + '\n';
  await bucket().file(CATALOG_PATH).save(body, {
    contentType: 'application/json',
    resumable: false,
    // The app downloads with getData(); stop CDN caches serving the old copy.
    metadata: { cacheControl: 'no-cache, max-age=0' },
  });
}

async function bumpRemoteVersion(minVersion) {
  const rc = admin().remoteConfig();
  const template = await rc.getTemplate();
  const param = template.parameters[RC_KEY];
  if (!param) die(`Remote Config has no "${RC_KEY}" parameter. Not creating one blindly; check the console.`);
  const current = Number(param.defaultValue && param.defaultValue.value) || 0;
  const next = Math.max(current + 1, minVersion || 0);
  param.defaultValue = { value: String(next) };
  // Conditional values (e.g. a debug-device override) must move too, or the
  // devices they match would never see the new catalog.
  for (const [cond, v] of Object.entries(param.conditionalValues || {})) {
    if (v && v.value !== undefined) {
      const cv = Number(v.value) || 0;
      if (cv < next) param.conditionalValues[cond] = { value: String(next) };
    }
  }
  await rc.publishTemplate(template); // etag on the template guards races
  return { from: current, to: next };
}

async function currentRemoteVersion() {
  const template = await admin().remoteConfig().getTemplate();
  const p = template.parameters[RC_KEY];
  return Number(p && p.defaultValue && p.defaultValue.value) || 0;
}

// ── helpers ──────────────────────────────────────────────────────────────
function nextSlot(catalog, tag) {
  const eps = catalog.audios.filter((a) => a.tag === tag && Number.isInteger(a.season));
  // Tags without season numbers (e.g. newcreation-ep1..3): count what is there.
  if (!eps.length) return { season: 1, episode: catalog.audios.filter((a) => a.tag === tag).length + 1 };
  const season = Math.max(...eps.map((a) => a.season));
  const episode = Math.max(0, ...eps.filter((a) => a.season === season).map((a) => a.episode || 0)) + 1;
  return { season, episode };
}

function mp3Minutes(file) {
  try {
    const secs = parseFloat(execFileSync('ffprobe', [
      '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file,
    ]).toString().trim());
    if (secs > 0) return { secs, label: `${Math.max(1, Math.round(secs / 60))}m` };
  } catch { /* ffprobe missing: caller falls back */ }
  return null;
}

const REQUIRED = ['id', 'title', 'subtitle', 'duration', 'imageUrl', 'isPremium'];
const AUDIO_EXT = /\.(mp3|m4a|wav|aac|caf)$/i;

function validateEpisode(ep, catalog) {
  for (const k of REQUIRED) if (ep[k] === undefined || ep[k] === '') die(`episode.${k} is required.`);
  if (typeof ep.isPremium !== 'boolean') die('episode.isPremium must be true or false.');
  if (!AUDIO_EXT.test(ep.id)) die(`episode.id "${ep.id}" must end in .mp3 (the app hides anything else).`);
  if (!/^[A-Za-z0-9._-]+$/.test(ep.id)) die(`episode.id "${ep.id}" may only use letters, digits, dot, dash, underscore.`);
  if (catalog.audios.some((a) => a.id === ep.id)) die(`An episode with id "${ep.id}" is already in the catalog.`);
  const tags = new Set((catalog.filterConfigs || []).map((f) => f.id));
  if (ep.tag && !tags.has(ep.tag)) die(`Tag "${ep.tag}" is not a filter in the catalog (${[...tags].join(', ')}).`);
  const images = new Set(catalog.audios.map((a) => a.imageUrl));
  if (!images.has(ep.imageUrl)) {
    console.warn(`⚠ imageUrl "${ep.imageUrl}" is not used by any live episode. It must be an asset bundled in the app or the card shows blank.`);
  }
}

// ── ElevenLabs ───────────────────────────────────────────────────────────
function chunkScript(text) {
  const paras = text.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
  const chunks = [];
  let cur = '';
  for (const p of paras) {
    if (p.length > MAX_TTS_CHARS) die(`A paragraph is ${p.length} chars; split it below ${MAX_TTS_CHARS}.`);
    if (cur && (cur.length + p.length + 2) > MAX_TTS_CHARS) { chunks.push(cur); cur = p; }
    else cur = cur ? `${cur}\n\n${p}` : p;
  }
  if (cur) chunks.push(cur);
  return chunks;
}

async function tts(args) {
  const key = process.env.ELEVENLABS_API_KEY;
  if (!key) die('ELEVENLABS_API_KEY is not set. Either set it, or generate the audio with the ElevenLabs connector and pass the mp3 to `publish --audio`.');
  if (!args.script || !args.out) die('Usage: tts --script script.txt --out episode.mp3 [--voice ID] [--model ID]');
  const text = fs.readFileSync(args.script, 'utf8');
  const voice = args.voice || process.env.ELEVENLABS_VOICE_ID || DEFAULT_VOICE_ID;
  const model = args.model || DEFAULT_MODEL;
  const chunks = chunkScript(text);
  const parts = [];
  for (let i = 0; i < chunks.length; i++) {
    const body = {
      text: chunks[i],
      model_id: model,
      voice_settings: {
        stability: Number(args.stability ?? 0.5),
        similarity_boost: Number(args.similarity ?? 0.8),
        style: Number(args.style ?? 0.2),
        use_speaker_boost: true,
      },
      // Neighbouring text keeps tone and pacing continuous across chunks.
      ...(i > 0 ? { previous_text: chunks[i - 1].slice(-1000) } : {}),
      ...(i < chunks.length - 1 ? { next_text: chunks[i + 1].slice(0, 1000) } : {}),
    };
    process.stdout.write(`ElevenLabs chunk ${i + 1}/${chunks.length} (${chunks[i].length} chars)… `);
    const res = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voice}?output_format=mp3_44100_128`,
      { method: 'POST', headers: { 'xi-api-key': key, 'Content-Type': 'application/json', Accept: 'audio/mpeg' }, body: JSON.stringify(body) },
    );
    if (!res.ok) die(`ElevenLabs HTTP ${res.status}: ${await res.text()}`);
    parts.push(Buffer.from(await res.arrayBuffer()));
    console.log('ok');
  }
  fs.writeFileSync(args.out, Buffer.concat(parts)); // mp3 frames concatenate cleanly
  const d = mp3Minutes(args.out);
  console.log(`\n✔ Wrote ${args.out}${d ? ` (${d.secs.toFixed(0)}s → "${d.label}")` : ''}`);
}

// ── commands ─────────────────────────────────────────────────────────────
async function cmdNext(args) {
  const tag = args.tag || 'speaklife';
  const { catalog } = await readCatalog();
  const slot = nextSlot(catalog, tag);
  const rv = await currentRemoteVersion();
  const recent = catalog.audios.filter((a) => a.tag === tag).slice(0, 15).map((a) => `  ${a.id}  "${a.title}"`);
  console.log(JSON.stringify({
    tag,
    nextSeason: slot.season,
    nextEpisode: slot.episode,
    suggestedId: tag === 'speaklife' ? `speaklife-s${slot.season}e${slot.episode}.mp3` : `${tag}-s${slot.season}e${slot.episode}.mp3`,
    remoteConfigVersion: rv,
    catalogVersionField: catalog.version,
    episodesInCatalog: catalog.audios.length,
    filters: (catalog.filterConfigs || []).map((f) => `${f.id} (${f.displayName})`),
  }, null, 2));
  console.log(`\nMost recent "${tag}" episodes (avoid repeating these):\n${recent.join('\n')}`);
}

async function cmdPublish(args) {
  if (!args.episode || !args.audio) die('Usage: publish --episode episode.json --audio episode.mp3 [--dry-run] [--force-upload]');
  const ep = JSON.parse(fs.readFileSync(args.episode, 'utf8'));
  if (!fs.existsSync(args.audio)) die(`No audio file at ${args.audio}`);
  const d = mp3Minutes(args.audio);
  if (d && !ep.duration) ep.duration = d.label;
  if (d && d.secs < 30) die(`Audio is only ${d.secs.toFixed(0)}s. That looks broken; refusing to publish.`);

  const { text, catalog } = await readCatalog();
  validateEpisode(ep, catalog);

  const entry = {};
  for (const k of ['id', 'title', 'subtitle', 'duration', 'imageUrl', 'isPremium', 'tag', 'season', 'episode']) {
    if (ep[k] !== undefined) entry[k] = ep[k];
  }

  const file = bucket().file(ep.id);
  const [exists] = await file.exists();
  if (exists && !args['force-upload']) die(`gs://${BUCKET}/${ep.id} already exists. Pick a new id, or pass --force-upload to overwrite it.`);

  console.log('Episode entry:\n' + JSON.stringify(entry, null, 2));
  if (args['dry-run']) { console.log('\n(dry run: nothing uploaded)'); return; }

  const backup = backupCatalog(text);
  console.log(`\n• Backed up live catalog → ${backup}`);

  // 1) audio first, so the catalog never points at a missing file
  await bucket().upload(args.audio, { destination: ep.id, resumable: false, metadata: { contentType: 'audio/mpeg' } });
  console.log(`• Uploaded gs://${BUCKET}/${ep.id}`);

  // 2) catalog: newest first, at the top
  const rvBefore = await currentRemoteVersion();
  catalog.audios.unshift(entry);
  catalog.version = Math.max(Number(catalog.version) || 0, rvBefore) + 1;
  await writeCatalog(catalog);
  console.log(`• Catalog updated (${catalog.audios.length} episodes)`);

  // 3) Remote Config bump → apps refetch the catalog
  const bump = await bumpRemoteVersion(catalog.version);
  console.log(`• Remote Config ${RC_KEY}: ${bump.from} → ${bump.to}`);
  if (bump.to !== catalog.version) {
    catalog.version = bump.to;
    await writeCatalog(catalog);
  }
  console.log(`\n✔ "${entry.title}" is live as ${entry.id}. Undo with: node publish.js restore --backup "${backup}"`);
}

async function cmdNotify(args) {
  if (!args.title || !args.body) die('Usage: notify --title "..." --body "..." [--audio-id id.mp3] (--test-token TOKEN | --broadcast) [--dry-run]');
  const token = args['test-token'];
  if (!token && !args.broadcast) die('Pick --test-token <FCM token> or --broadcast.');
  if (token && args.broadcast) die('--test-token and --broadcast are mutually exclusive.');
  if (args['audio-id']) {
    const [exists] = await bucket().file(args['audio-id']).exists();
    if (!exists) die(`Refusing to push: gs://${BUCKET}/${args['audio-id']} does not exist.`);
    const { catalog } = await readCatalog();
    if (!catalog.audios.some((a) => a.id === args['audio-id'])) die(`Refusing to push: ${args['audio-id']} is not in the live catalog.`);
  }
  const message = {
    notification: { title: args.title, body: args.body },
    data: { deepLink: 'audio', ...(args['audio-id'] ? { audioId: args['audio-id'] } : {}) },
    apns: { payload: { aps: { sound: 'default' } } },
    ...(token ? { token } : { topic: PUSH_TOPIC }),
  };
  console.log(JSON.stringify({ ...message, token: token ? '<test token>' : undefined }, null, 2));
  const id = await admin().messaging().send(message, Boolean(args['dry-run']));
  console.log(`\n✔ ${args['dry-run'] ? 'Validated (dry run, not sent)' : 'Sent'} → ${token ? 'test device' : `topic:${PUSH_TOPIC}`} (${id})`);
}

async function cmdRestore(args) {
  if (!args.backup) die('Usage: restore --backup backups/audioDevotionals.<stamp>.json');
  const { text } = await readCatalog();
  const safety = backupCatalog(text);
  const catalog = parseLenient(fs.readFileSync(args.backup, 'utf8'));
  const rv = await currentRemoteVersion();
  catalog.version = rv + 1;
  await writeCatalog(catalog);
  const bump = await bumpRemoteVersion(catalog.version);
  console.log(`✔ Restored ${args.backup} (current live copy saved to ${safety}). ${RC_KEY}: ${bump.from} → ${bump.to}`);
  console.log('  The uploaded mp3 was left in Storage; delete it in the console if it should go too.');
}

const HELP = `
SpeakLife audio devotional pipeline

  node publish.js next     [--tag speaklife]
  node publish.js tts      --script script.txt --out ep.mp3 [--voice ID] [--model ID]
                           [--stability 0.5] [--similarity 0.8] [--style 0.2]
  node publish.js publish  --episode episode.json --audio ep.mp3 [--dry-run] [--force-upload]
  node publish.js notify   --title "..." --body "..." --audio-id ep.mp3
                           (--test-token TOKEN | --broadcast) [--dry-run]
  node publish.js restore  --backup backups/audioDevotionals.<stamp>.json

Env: FIREBASE_SERVICE_ACCOUNT (JSON or base64), ELEVENLABS_API_KEY (tts only),
     ELEVENLABS_VOICE_ID (optional, defaults to the Franchiz voice).
`;

module.exports = { parseLenient, nextSlot, chunkScript, validateEpisode };

if (require.main === module) (async () => {
  const args = parseArgs(process.argv.slice(2));
  const cmd = args._[0];
  const run = { next: cmdNext, tts, publish: cmdPublish, notify: cmdNotify, restore: cmdRestore }[cmd];
  if (!run) { console.log(HELP); process.exit(cmd && cmd !== 'help' ? 1 : 0); }
  try { await run(args); } catch (e) { die(e && e.stack ? e.stack : String(e)); }
})();
