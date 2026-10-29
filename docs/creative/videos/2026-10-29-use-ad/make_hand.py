#!/usr/bin/env python3
"""Put the real SpeakLife screen recording into Grace's hand (AI still with a green screen).

Output: clips/grace-hand.mp4, two segments back to back (scene 2 then scene 3 of the 7days cut),
with a slow handheld drift so the still reads as video.
  python3 make_hand.py
"""
import os, subprocess
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
HAND = f"{HERE}/frames/grace-hand-b.png"
SCREEN = f"{HERE}/src/screen-destiny.mov"   # owner's screen recording (Hard Times feed)
OUT = f"{HERE}/clips/grace-hand.mp4"
TMP = f"{HERE}/build"
W, H, FPS = 1080, 1920, 30
SEGMENTS = [(0.0, 2.8), (5.2, 3.2)]  # (start, duration) in the screen recording
os.makedirs(TMP, exist_ok=True)

# Upscale the hand still and cut a soft mask from the green screen.
hand = Image.open(HAND).convert("RGB").resize((W, H), Image.LANCZOS)
hand.save(f"{TMP}/hand.png")
px = hand.load()
mask = Image.new("L", (W, H), 0)
mp = mask.load()
for y in range(H):
    for x in range(W):
        r, g, b = px[x, y]
        if g > 150 and g > r + 60 and g > b + 60:
            mp[x, y] = 255
mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
# Despill: pull any leftover green fringe on the bezel back to neutral.
for y in range(H):
    for x in range(W):
        r, g, b = px[x, y]
        if g > max(r, b) + 25:
            px[x, y] = (r, max(r, b), b)
hand.save(f"{TMP}/hand.png")
x0, y0, x1, y1 = mask.getbbox()
sw, sh = x1 - x0, y1 - y0
mask.crop((x0, y0, x1, y1)).save(f"{TMP}/screenmask.png")

parts = []
for i, (ss, dur) in enumerate(SEGMENTS):
    out = f"{TMP}/hand{i}.mp4"
    fc = (f"[1:v]trim=start={ss}:duration={dur},setpts=PTS-STARTPTS,fps={FPS},"
          f"scale={sw}:{sh}:force_original_aspect_ratio=increase,crop={sw}:{sh},format=rgba[s];"
          f"[2:v]format=gray,trim=duration={dur}[m];[s][m]alphamerge[sm];"
          f"[0:v]trim=duration={dur},fps={FPS}[bg];[bg][sm]overlay={x0}:{y0}[c];"
          # handheld drift: scale up 6%, then move the crop window slowly
          f"[c]scale={int(W*1.06)}:{int(H*1.06)},"
          f"crop={W}:{H}:x='(iw-{W})/2+14*sin(t*1.1+{i})+5*sin(t*3.7)':y='(ih-{H})/2+18*sin(t*0.8+{i})+5*sin(t*2.9)',"
          f"setsar=1,format=yuv420p[v]")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-loop", "1", "-i", f"{TMP}/hand.png", "-i", SCREEN,
                    "-loop", "1", "-i", f"{TMP}/screenmask.png", "-filter_complex", fc, "-map", "[v]",
                    "-t", str(dur), "-an", "-c:v", "libx264", "-crf", "16", out], check=True)
    parts.append(out)
open(f"{TMP}/hand.txt", "w").write("".join(f"file '{p}'\n" for p in parts))
subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", f"{TMP}/hand.txt",
                "-c", "copy", OUT], check=True)
print(OUT, f"screen area {sw}x{sh} at {x0},{y0}")
