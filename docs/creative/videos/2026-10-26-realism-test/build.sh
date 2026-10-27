#!/bin/bash
# Realism test: Seedance (one take) vs Veo 3.1 (two clips, jump cut).
# Both get the same 1080x1920 scale, light grain, phone-style compression and captions.
set -euo pipefail
cd "$(dirname "$0")"
CAP=../tools/caption_v2.py
HOOK="Praying about it isn't the same as speaking to it 👇"
KW=pray,speak,storm,promises,jesus,speaklife
LOOK="scale=1080:1920:flags=lanczos,noise=alls=7:allf=t,format=yuv420p"

# Trim each Veo clip 0.2s after her last word (whisper word timings: 6.64s and 7.26s;
# silencedetect can't find the gaps under the room tone), then join with a hard jump cut.
trim_to() {  # $1 in, $2 out, $3 seconds
  ffmpeg -y -v error -i "$1" -t "$3" -vf "$LOOK" -c:v libx264 -crf 18 -c:a aac -ar 48000 "$2"
}
trim_to veo-a-raw.mp4 veo-a.mp4 6.85
trim_to veo-b-raw.mp4 veo-b.mp4 7.5
printf "file 'veo-a.mp4'\nfile 'veo-b.mp4'\n" > veo-list.txt
ffmpeg -y -v error -f concat -safe 0 -i veo-list.txt -c copy veo-joined.mp4

ffmpeg -y -v error -i seedance-raw.mp4 -vf "$LOOK" -c:v libx264 -crf 18 -c:a aac -ar 48000 seedance-look.mp4

python3 "$CAP" seedance-look.mp4 RT-seedance.tmp.mp4 --hook "$HOOK" --keywords "$KW"
python3 "$CAP" veo-joined.mp4 RT-veo.tmp.mp4 --hook "$HOOK" --keywords "$KW"

# Phone-style compression on the final files.
for n in seedance veo; do
  ffmpeg -y -v error -i RT-$n.tmp.mp4 -c:v libx264 -preset slow -crf 26 -maxrate 4M -bufsize 8M \
    -c:a aac -b:a 128k -movflags +faststart RT-$n.mp4
  rm RT-$n.tmp.mp4
done
echo done

# Side-by-side (silent: the two takes have different timing, so watch the single files for sound).
python3 - <<'PY'
from PIL import Image, ImageDraw, ImageFont
f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 34)
for name, text in [("label-seedance.png", "A · Seedance 2.5"), ("label-veo.png", "B · Veo 3.1 + jump cut")]:
    w = int(f.getlength(text)) + 40
    im = Image.new("RGBA", (w, 60), (0, 0, 0, 170))
    ImageDraw.Draw(im).text((20, 10), text, font=f, fill="white")
    im.save(name)
PY
ffmpeg -y -v error -i RT-seedance.mp4 -i RT-veo.mp4 -i label-seedance.png -i label-veo.png -filter_complex \
 "[0:v]scale=720:1280,setsar=1[a0];[1:v]scale=720:1280,setsar=1[b0];[a0][2:v]overlay=20:H-90[a];[b0][3:v]overlay=20:H-90[b];[a][b]hstack=inputs=2:shortest=0[v]" \
 -map "[v]" -an -c:v libx264 -crf 22 -pix_fmt yuv420p -movflags +faststart RT-side-by-side.mp4
rm label-*.png
echo side-by-side done
