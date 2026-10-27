"""Burn TikTok-style captions onto a talking video.

Whisper gives word timestamps; words are grouped into short chunks, each chunk is drawn as a
transparent PNG and overlaid for its time window (this ffmpeg build has no drawtext/libass).
A hook banner sits at the top for the first 2.5 seconds.

Usage: python3 caption.py in.mp4 out.mp4 "hook text"
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

FONT = "/System/Library/Fonts/HelveticaNeue.ttc"
src, dst, hook = sys.argv[1], sys.argv[2], sys.argv[3]

probe = json.loads(subprocess.check_output(
    ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
     "-of", "json", src]))
W, H = probe["streams"][0]["width"], probe["streams"][0]["height"]

tmp = tempfile.mkdtemp()
subprocess.run(["whisper", src, "--model", "small", "--language", "en", "--word_timestamps", "True",
                "--output_format", "json", "--output_dir", tmp], check=True, capture_output=True)
data = json.load(open(os.path.join(tmp, os.path.splitext(os.path.basename(src))[0] + ".json")))
raw = [dict(w) for seg in data["segments"] for w in seg.get("words", [])]

# Optional per-video fixes, e.g. '{"SAM": "Psalm"}' as a 4th argument. Applied to raw tokens
# before the merges below, so a fixed "112" can still join "-7" into "112:7".
FIXES = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
for w in raw:
    t = w["word"].strip()
    if t in FIXES:
        w["word"] = " " + FIXES[t]

# Merge tokens whisper splits: "Speak" + "Life" -> "SpeakLife", "54" + "-17" -> "54:17".
words = []
for w in raw:
    t = w["word"].strip()
    if words:
        prev = words[-1]["word"].strip()
        if prev == "Speak" and t.lower().startswith("life"):
            words[-1] = {**words[-1], "word": "SpeakLife" + t[4:], "end": w["end"]}
            continue
        if prev.isdigit() and t.startswith("-") and t[1:].rstrip(".,").isdigit():
            words[-1] = {**words[-1], "word": prev + ":" + t[1:], "end": w["end"]}
            continue
        # "43" + ".4." -> "43:4."
        if prev.isdigit() and t.startswith(".") and t[1:].rstrip(".,").isdigit():
            words[-1] = {**words[-1], "word": prev + ":" + t[1:], "end": w["end"]}
            continue
        # "139," + "14." -> "139:14."  (chapter, verse spoken with a pause)
        if prev.endswith(",") and prev[:-1].isdigit() and t.rstrip(".,").isdigit():
            words[-1] = {**words[-1], "word": prev[:-1] + ":" + t, "end": w["end"]}
            continue
    words.append(w)

# Fixes can also target a merged token (e.g. "13914," -> "139:14,").
for w in words:
    t = w["word"].strip()
    if t in FIXES:
        w["word"] = " " + FIXES[t]

chunks, cur = [], []
for w in words:
    cur.append(w)
    text = w["word"].strip()
    if len(cur) >= 3 or text.endswith((".", "?", ",", "!")):
        chunks.append(cur)
        cur = []
if cur:
    chunks.append(cur)


def font(size, bold=True):
    return ImageFont.truetype(FONT, size, index=1 if bold else 0)


def pill(text, size, path, y_frac, fg=(17, 17, 17), bg=(255, 255, 255, 255)):
    f = font(size)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if d.textlength(trial, font=f) > W * 0.82 and line:
            lines.append(line)
            line = word
        else:
            line = trial
    lines.append(line)
    lh = int(size * 1.35)
    y = int(H * y_frac) - lh * len(lines) // 2
    for ln in lines:
        tw = d.textlength(ln, font=f)
        x = (W - tw) / 2
        d.rounded_rectangle([x - 18, y - 6, x + tw + 18, y + lh - 2], radius=14, fill=bg)
        d.text((x, y), ln, font=f, fill=fg)
        y += lh
    img.save(path)


inputs, filters, last = [], [], "[0:v]"
hook_png = os.path.join(tmp, "hook.png")
pill(hook, int(W * 0.055), hook_png, 0.16)
inputs += ["-i", hook_png]
filters.append(f"{last}[1:v]overlay=0:0:enable='between(t,0,2.5)'[v1]")
last = "[v1]"
for i, ch in enumerate(chunks):
    text = " ".join(w["word"].strip() for w in ch)
    start, end = ch[0]["start"], ch[-1]["end"]
    if i + 1 < len(chunks):
        # Hold each caption until the next begins, but never overlap it.
        end = chunks[i + 1][0]["start"] - 0.02
        start = min(start, end - 0.05)
    p = os.path.join(tmp, f"c{i}.png")
    pill(text, int(W * 0.062), p, 0.70, fg=(255, 255, 255), bg=(0, 0, 0, 150))
    inputs += ["-i", p]
    n = i + 2
    filters.append(f"{last}[{n}:v]overlay=0:0:enable='between(t,{start:.2f},{end:.2f})'[v{n}]")
    last = f"[v{n}]"

subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, *inputs,
                "-filter_complex", ";".join(filters), "-map", last, "-map", "0:a?",
                "-c:v", "libx264", "-crf", "18", "-preset", "medium", "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-b:a", "192k", dst], check=True)
print(dst)
print("TRANSCRIPT:", " ".join(w["word"].strip() for w in words))
