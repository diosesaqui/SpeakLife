#!/usr/bin/env python3
"""SL-USE-01: silent morning routine + SpeakLife app card (remix of the Bend UGC format).

Captions only, no voice. Under 20 seconds. One cut per hook in HOOKS.
  python3 render.py            # all hooks
  python3 render.py --still    # one frame per scene into stills/
"""
import subprocess, sys, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "../tools/fonts/Fraunces.ttf")
MUSIC = os.path.join(HERE, "../../../../SpeakLife/SpeakLife/Audio/washed.mp3")
MUSIC_START = 30  # the track fills out here
W, H, FPS = 1080, 1920, 30
TMP = os.path.join(HERE, "build")
os.makedirs(TMP, exist_ok=True)

HOOKS = {
    "week": "It's not a bad week.\nYou just haven't\nspoken over it yet.",
    "7days": "Speak these over\nyour morning\nfor 7 days.",
    "phone": "Say these out loud\nbefore you check\nyour phone.",
}

AI = os.path.join(HERE, "clips")
SRC = os.path.join(HERE, "src")

# Each hook gets the feed recording whose declarations match it:
# (recording, scene-2 start, scene-3 start, car-card start)
FEEDS = {
    "week": (f"{SRC}/IMG_1126.MOV", 0.0, 6.0, 3.0),    # Hard Times: "This battle is God's"
    # Grace: the screen recording composited into her own hand (make_hand.py), so no
    # mismatched hand shows; both floating cards use the plain screen recording.
    "7days": (f"{AI}/grace-hand.mp4", 0.0, 2.8, 13.0, f"{SRC}/screen-destiny.mov"),
    "phone": (f"{SRC}/IMG_1125.MOV", 9.0, 5.8, 1.0),   # Gratitude: "call on Your name out loud"
}


# Each cut is one woman's morning, start to finish, so the three ads share no
# people or rooms. (clip, start) per scene; the opening also sets the hook's y.
CAST = {
    "week": dict(open=(f"{AI}/kitchen.mp4", 1.7, 640), mid=(f"{AI}/car.mp4", 1.2),       # Sofia
                 walk=(f"{AI}/walk.mp4", 0.5), end=(f"{AI}/window.mp4", 0.5)),
    "7days": dict(open=(f"{AI}/grace-bed.mp4", 1.0, 700), mid=(f"{AI}/grace-couch.mp4", 1.0),  # Grace
                  walk=(f"{AI}/grace-walk.mp4", 0.0), end=(f"{AI}/grace-balcony.mp4", 0.5)),
    "phone": dict(open=(f"{AI}/naomi-bed.mp4", 0.8, 1180), mid=(f"{AI}/naomi-table.mp4", 1.0),  # Naomi
                  walk=(f"{AI}/naomi-walk.mp4", 2.0, 3.0), end=(f"{AI}/naomi-window.mp4", 0.5)),  # stray tripod before 2s
}


def scenes(name):
    """(source, start, duration, pip_source, pip_start, caption, caption_y); caption None = hook."""
    feed, s2, s3, pip = FEEDS[name][:4]
    pipsrc = FEEDS[name][4] if len(FEEDS[name]) > 4 else feed
    walkpip = (pipsrc, 16.6) if len(FEEDS[name]) > 4 else (f"{SRC}/IMG_1119.MOV", 6.6)
    c = CAST[name]
    return [
        (c["open"][0], c["open"][1], 3.2, None, 0, None, c["open"][2]),
        (feed, s2, 2.8, None, 0, "Open SpeakLife", 1300),
        (feed, s3, 3.2, None, 0, "Say each one\nout loud", 1300),
        (c["mid"][0], c["mid"][1], 3.2, pipsrc, pip, "God's promises,\nevery morning", 1040),
        (c["walk"][0], c["walk"][1], c["walk"][2] if len(c["walk"]) > 2 else 3.2, walkpip[0], walkpip[1], "Over your body,\nmind and home", 1040),
        (c["end"][0], c["end"][1], 1.8, None, 0, "Keep praying.\nStart speaking.", 640),
        (c["end"][0], c["end"][1] + 1.8, 2.2, None, 0, "END", 0),
    ]


def font(size):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([72, 800, 50, 0])
    return f


def wrap(text, f, maxw):
    if "\n" in text:
        return text.split("\n")
    lines, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if f.getlength(t) <= maxw:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def caption_png(text, y, path, size=76):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(size)
    lh = int(size * 1.18)
    for i, line in enumerate(wrap(text, f, W - 140)):
        d.text((W / 2, y + i * lh), line, font=f, fill="white", anchor="ma",
               stroke_width=6, stroke_fill=(20, 20, 20))
    img.save(path)


def endcard_png(path):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(84)
    d.text((W / 2, 330), "Download SpeakLife", font=f, fill="white", anchor="ma",
           stroke_width=6, stroke_fill=(20, 20, 20))
    store = Image.open(f"{SRC}/appstore.jpg").convert("RGBA")
    store = store.crop((30, 170, store.width, store.height))
    cw = 960
    store = store.resize((cw, int(store.height * cw / store.width)), Image.LANCZOS)
    mask = Image.new("L", store.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *store.size), 40, fill=255)
    img.paste(store, ((W - cw) // 2, 460), mask)
    img.save(path)


def pip_mask(path, w, h, r=34):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w, h), r, fill=255)
    m.save(path)


PIP_W, PIP_H = 420, 822  # phone crop is ~0.51 aspect


def build_scene(i, scene, hook_text, out):
    src, ss, dur, pip, pss, cap, cy = scene
    cap_path = f"{TMP}/cap{i}.png"
    if cap == "END":
        endcard_png(cap_path)
    else:
        caption_png(hook_text if cap is None else cap, cy, cap_path, 80 if cap is None else 76)
    base = (f"[0:v]trim=start={ss}:duration={dur},setpts=PTS-STARTPTS,fps={FPS},"
            f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},setsar=1,"
            f"noise=alls=5:allf=t[bg]")
    inputs = ["-i", src]
    if pip:
        pip_mask(f"{TMP}/pipmask.png", PIP_W, PIP_H)
        # Oct 29 feed recordings are framed tighter, so take more of the frame.
        pipcrop = ("crop=iw*0.86:ih*0.947:iw*0.07:ih*0.02" if "IMG_112" in pip
                   else "crop=iw*0.60:ih*0.655:iw*0.20:ih*0.17")
        pipchain = f"scale={W}:{H},{pipcrop},scale={PIP_W}:{PIP_H}"
        if "screen-" in pip:  # plain screen recording: just fill the card
            pipchain = f"scale={PIP_W}:{PIP_H}:force_original_aspect_ratio=increase,crop={PIP_W}:{PIP_H}"
        inputs += ["-i", pip, "-loop", "1", "-i", f"{TMP}/pipmask.png", "-loop", "1", "-i", cap_path]
        fc = (base + ";"
              f"[1:v]trim=start={pss}:duration={dur},setpts=PTS-STARTPTS,fps={FPS},"
              f"{pipchain},format=rgba[p];"
              f"[2:v]format=gray,trim=duration={dur}[m];[p][m]alphamerge[pr];"
              f"color=white:s={PIP_W + 12}x{PIP_H + 12}:d={dur},format=rgba[wb];"
              f"[2:v]scale={PIP_W + 12}:{PIP_H + 12},format=gray,trim=duration={dur}[wm];[wb][wm]alphamerge[border];"
              f"[bg][border]overlay=42:114[b1];[b1][pr]overlay=48:120[b2];"
              f"[b2][3:v]overlay=0:0:shortest=1[v]")
    else:
        inputs += ["-loop", "1", "-i", cap_path]
        fc = base + ";[bg][1:v]overlay=0:0:shortest=1[v]"
    subprocess.run(["ffmpeg", "-v", "error", "-y", *inputs, "-filter_complex", fc,
                    "-map", "[v]", "-t", str(dur), "-an", "-c:v", "libx264", "-crf", "17",
                    "-pix_fmt", "yuv420p", out], check=True)


def render(name, hook_text):
    parts = []
    SCENES = scenes(name)
    for i, sc in enumerate(SCENES):
        p = f"{TMP}/{name}-s{i}.mp4"
        build_scene(i, sc, hook_text, p)
        parts.append(p)
    lst = f"{TMP}/{name}.txt"
    open(lst, "w").write("".join(f"file '{p}'\n" for p in parts))
    total = sum(s[2] for s in SCENES)
    out = os.path.join(HERE, f"SL-USE-01-{name}.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst,
                    "-ss", str(MUSIC_START), "-i", MUSIC, "-filter_complex",
                    f"[1:a]atrim=0:{total},afade=t=in:d=0.5,afade=t=out:st={total - 1.2}:d=1.2,volume=0.8[a]",
                    "-map", "0:v", "-map", "[a]", "-t", str(total),
                    "-c:v", "libx264", "-preset", "slow", "-crf", "24", "-maxrate", "5M", "-bufsize", "10M",
                    "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", out], check=True)
    print(out, f"{total:.1f}s")
    return out


if __name__ == "__main__":
    if "--still" in sys.argv:
        os.makedirs(f"{HERE}/stills", exist_ok=True)
        name = sys.argv[sys.argv.index("--still") + 1] if len(sys.argv) > 2 else "week"
        hook = HOOKS[name]
        SCENES = scenes(name)
        for i, sc in enumerate(SCENES):
            p = f"{TMP}/still-s{i}.mp4"
            build_scene(i, sc, hook, p)
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(sc[2] / 2), "-i", p,
                            "-frames:v", "1", "-vf", "scale=360:640", f"{HERE}/stills/s{i}.png"], check=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y", *sum([["-i", f"{HERE}/stills/s{i}.png"] for i in range(len(SCENES))], []),
                        "-filter_complex", f"hstack={len(SCENES)}", f"{HERE}/stills/sheet.jpg"], check=True)
        print(f"{HERE}/stills/sheet.jpg")
    else:
        for k in (sys.argv[1:] or HOOKS):
            render(k, HOOKS[k])
