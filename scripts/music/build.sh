#!/usr/bin/env bash
# Rebuild the SpeakLife background music from source.
# Needs: python3 (numpy, scipy, mido), fluidsynth, ffmpeg, and the
# MuseScore General soundfont (apt: fluidsynth musescore-general-soundfont-lossless).
set -euo pipefail
cd "$(dirname "$0")"
SF2=${SF2:-/usr/share/sounds/sf2/MuseScore_General_Full.sf2}
OUT=../../SpeakLife/SpeakLife/Audio
W=$(mktemp -d)
python3 compose.py "$W"
for n in stillwaters dwelling shoreline lanterns morninglight; do
  fluidsynth -ni -q -R 0 -C 0 -g 0.35 -r 44100 -F "$W/$n.raw.wav" "$SF2" "$W/$n.mid"
  python3 post.py "$n" "$W/$n.raw.wav" "$W/$n.wav"
  # Dwelling is tuned so C = 528 Hz; everything else to A = 432 Hz.
  if [ "$n" = dwelling ]; then ratio=444; else ratio=432; fi
  ffmpeg -hide_banner -loglevel error -y -i "$W/$n.wav" \
    -af "asetrate=44100*$ratio/440,aresample=44100:resampler=soxr,loudnorm=I=-16:TP=-1.5:LRA=11" \
    -ar 44100 -c:a libmp3lame -b:a 192k "$OUT/$n.mp3"
  echo "built $n"
done
rm -rf "$W"
