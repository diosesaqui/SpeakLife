#!/usr/bin/env bash
# Rebuild the SpeakLife background music from source.
# Needs: python3 (numpy, scipy, mido), fluidsynth, ffmpeg, and the
# MuseScore General soundfont (apt: fluidsynth musescore-general-soundfont-lossless).
set -euo pipefail
cd "$(dirname "$0")"
SF2=${SF2:-/usr/share/sounds/sf2/MuseScore_General_Full.sf2}
OUT=../../SpeakLife/SpeakLife/Audio
W=$(mktemp -d)
render() { fluidsynth -ni -q -R 0 -C 0 -g "$3" -r 44100 -F "$2" "$SF2" "$1" >/dev/null; }

# Two-pass loudness match to -16 LUFS that keeps the build-ups intact,
# tuned from A = 440 to A = 432 Hz on the way.
master() {
  local pre="asetrate=44100*432/440,aresample=44100:resampler=soxr" js
  js=$(ffmpeg -hide_banner -nostats -i "$1" -af "$pre,loudnorm=I=-16:TP=-1.5:LRA=20:print_format=json" -f null - 2>&1 | sed -n '/^{/,/^}/p')
  g() { echo "$js" | python3 -c "import json,sys;print(json.load(sys.stdin)['$1'])"; }
  ffmpeg -hide_banner -loglevel error -y -i "$1" \
    -af "$pre,loudnorm=I=-16:TP=-1.5:LRA=20:linear=true:measured_I=$(g input_i):measured_TP=$(g input_tp):measured_LRA=$(g input_lra):measured_thresh=$(g input_thresh):offset=$(g target_offset)" \
    -ar 44100 -c:a libmp3lame -b:a 192k "$2"
}

# Shoreline: piano and strings over ocean waves
python3 compose.py "$W"
render "$W/shoreline.mid" "$W/shoreline.raw.wav" 0.35
python3 post.py shoreline "$W/shoreline.raw.wav" "$W/shoreline.wav"
# Shoreline keeps the single-pass mastering it shipped with.
ffmpeg -hide_banner -loglevel error -y -i "$W/shoreline.wav" \
  -af "asetrate=44100*432/440,aresample=44100:resampler=soxr,loudnorm=I=-16:TP=-1.5:LRA=11" \
  -ar 44100 -c:a libmp3lame -b:a 192k "$OUT/shoreline.mp3"
echo "built shoreline"

# Soaking pieces, rendered as stems then mixed
python3 soak.py "$W"
for n in secretplace gloryrain holyground abide; do
  render "$W/$n.pad.mid" "$W/$n.pad.wav" 0.35
  render "$W/$n.piano.mid" "$W/$n.piano.wav" 1.2
  render "$W/$n.guitar.mid" "$W/$n.guitar.wav" 4
  render "$W/$n.shimmer.mid" "$W/$n.shimmer.wav" 2.5
  python3 mixsoak.py "$n" "$W" "$W/$n.mix.wav"
  master "$W/$n.mix.wav" "$OUT/$n.mp3"
  echo "built $n"
done
rm -rf "$W"
