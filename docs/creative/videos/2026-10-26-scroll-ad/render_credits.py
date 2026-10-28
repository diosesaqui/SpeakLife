"""Calm-style "movie credits" ad: one long column of text scrolls up over a
slow-zooming night background, then an audio player card and the App Store badge.

Usage: python3 render_credits.py [--promise] [out.mp4] [--still SECONDS out.png]
"""
import subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
from render import (THEMES, W, H, FPS, font, load_bg, zoom_frame, ease, with_alpha,
                    app_store_badge)

ROOT = Path(__file__).resolve().parents[4]
ART = ROOT / "SpeakLife/SpeakLife/Assets.xcassets/AudioStories/restMeditations.imageset/restMeditations.png"
BG = THEMES / "moonlight2.imageset"
OUT = Path(__file__).with_name("SL-credits-night.mp4")

# ("caps", text) = heavy uppercase hook. ("body", label, rest) = bold label + regular text.
COPY = [
    ("caps", "YOU'VE PRAYED ABOUT IT FOR YEARS."),
    ("caps", "THIS WEEK, START SPEAKING TO IT."),
    ("caps", "WE'RE LOOKING FOR BELIEVERS"),
    ("body", "ready to try", ""),
    ("body", "Scripture-rooted declarations", "you speak out loud over your mind, your home and your future."),
    ("body", "Guided audio", "that makes His Word the last thing you hear at night."),
    ("body", "When thoughts race:", "His peace guards your heart and mind."),
    ("body", "When money runs short:", "God supplies every need you have."),
    ("body", "When fear gets loud:", "You have power, love and a sound mind."),
    ("body", "Keep praying.", "Start speaking."),
    ("body", "Start tonight.", ""),
]

# --promise: hook matches the Promises onboarding. Verses: 2 Cor 1:20, Psalm 30:5,
# Philippians 4:19, Isaiah 53:5, Isaiah 26:3, Isaiah 41:10.
PROMISE_BG = THEMES / "lakeSunrise2.imageset"
PROMISE_OUT = Path(__file__).with_name("SL-promise-credits-dawn.mp4")
PROMISE_COPY = [
    ("caps", "DO YOU NEED A PROMISE FROM GOD?"),
    ("caps", "HE'S GIVEN YOU HUNDREDS."),
    ("body", "When the night feels long:", "joy comes in the morning."),
    ("body", "When money runs short:", "God supplies every need you have."),
    ("body", "When the body aches:", "by His wounds we are healed."),
    ("body", "When thoughts won't rest:", "perfect peace for the mind that trusts Him."),
    ("body", "When fear gets loud:", "\"Do not fear, for I am with you.\""),
    ("body", "Every one of them", "is yes in Christ."),
    ("body", "SpeakLife", "puts His promises in your mouth every morning."),
    ("body", "Find yours tonight.", ""),
]
if "--promise" in sys.argv:
    sys.argv.remove("--promise")
    COPY, BG, OUT = PROMISE_COPY, PROMISE_BG, PROMISE_OUT

MARGIN = 110
SPEED = 4               # px per frame (120 px/s), integer so the scroll never jitters
START_Y = 430           # hook is on screen from frame one
STOP_Y = 820            # where the last line settles
HOLD = 1.2
PLAYER_LEN = 6.5

CAPS_F, CAPS_LH = font(66, "Heavy"), 80
BOLD_F, REG_F, BODY_LH = font(52, "Bold"), font(52, "Regular"), 80
GAP = 72


def build_column():
    """Renders the whole credits column once. Returns (rgba, y of last line's top)."""
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    maxw = W - 2 * MARGIN
    rows = []  # list of (kind, [(word, font)]) per line, plus gaps
    for block in COPY:
        if block[0] == "caps":
            words = [(w, CAPS_F) for w in block[1].split()]
            lh = CAPS_LH
        else:
            words = [(w, BOLD_F) for w in block[1].split()] + [(w, REG_F) for w in block[2].split()]
            lh = BODY_LH
        line, x = [], 0
        lines = []
        for w, f in words:
            ww = probe.textlength(w, font=f)
            sp = probe.textlength(" ", font=f) if line else 0
            if line and x + sp + ww > maxw:
                lines.append(line)
                line, x, sp = [], 0, 0
            line.append((x + sp, w, f))
            x += sp + ww
        lines.append(line)
        rows.append((lh, lines))

    height = sum(lh * len(ls) for lh, ls in rows) + GAP * (len(rows) - 1) + 40
    col = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    sh = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    d, ds = ImageDraw.Draw(col), ImageDraw.Draw(sh)
    y = 0
    last_top = 0
    for lh, lines in rows:
        for ln in lines:
            for x, w, f in ln:
                ds.text((MARGIN + x, y + 3), w, font=f, fill=(0, 0, 0, 210))
                d.text((MARGIN + x, y), w, font=f, fill=(255, 255, 255, 255))
            last_top = y
            y += lh
        y += GAP
    return Image.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10)), col), last_top


def rounded(im, r):
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width - 1, im.height - 1), r, fill=255)
    im = im.convert("RGBA")
    im.putalpha(m)
    return im


def player_card(progress_s):
    """iOS-style now-playing card. progress_s = elapsed seconds into the 8 min track."""
    cw, chh = 760, 360
    card = Image.new("RGBA", (cw, chh), (0, 0, 0, 0))
    d = ImageDraw.Draw(card)
    d.rounded_rectangle((0, 0, cw - 1, chh - 1), 44, fill=(242, 240, 246, 238))
    art = rounded(Image.open(ART).convert("RGB").resize((132, 132), Image.LANCZOS), 22)
    card.alpha_composite(art, (34, 34))
    tf = font(40, "Semibold")
    d.text((190, 46), "Resting in God's Peace", font=tf, fill=(28, 28, 32))
    d.text((190, 96), "and Strength", font=tf, fill=(28, 28, 32))
    d.text((190, 146), "SpeakLife", font=font(28, "Regular"), fill=(120, 120, 128))
    # progress bar
    total = 8 * 60
    p = progress_s / total
    x0, x1, by = 140, cw - 140, 210
    d.rounded_rectangle((x0, by - 5, x1, by + 5), 5, fill=(205, 203, 212))
    d.rounded_rectangle((x0, by - 5, x0 + (x1 - x0) * p, by + 5), 5, fill=(110, 108, 118))
    sf = font(24, "Medium")
    el, rem = int(progress_s), total - int(progress_s)
    d.text((x0 - 16, by), f"{el // 60}:{el % 60:02d}", font=sf, fill=(120, 120, 128), anchor="rm")
    d.text((x1 + 16, by), f"-{rem // 60}:{rem % 60:02d}", font=sf, fill=(120, 120, 128), anchor="lm")
    # controls: back 10, pause, forward 10
    cy = 290
    for cx, start, end in [(cw / 2 - 150, 120, 420), (cw / 2 + 150, -240, 60)]:
        d.arc((cx - 32, cy - 32, cx + 32, cy + 32), start, end, fill=(30, 30, 34), width=5)
        d.text((cx, cy + 1), "10", font=font(22, "Bold"), fill=(30, 30, 34), anchor="mm")
    px = cw / 2
    d.rounded_rectangle((px - 24, cy - 34, px - 8, cy + 34), 4, fill=(20, 20, 24))
    d.rounded_rectangle((px + 8, cy - 34, px + 24, cy + 34), 4, fill=(20, 20, 24))
    shadow = Image.new("RGBA", (cw + 120, chh + 120), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((60, 70, cw + 60, chh + 70), 44, fill=(0, 0, 0, 120))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    shadow.alpha_composite(card, (60, 60))
    return shadow


def text_img(txt, f, w=W, h=140):
    lay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((w / 2, h / 2 + 3), txt, font=f, fill=(0, 0, 0, 200), anchor="mm")
    ImageDraw.Draw(lay).text((w / 2, h / 2), txt, font=f, fill="white", anchor="mm")
    return Image.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)), lay)


def main():
    args = sys.argv[1:]
    still = None
    if "--still" in args:
        i = args.index("--still")
        still = (float(args[i + 1]), args[i + 2])
        del args[i:i + 3]
    out = args[0] if args else str(OUT)

    col, last_top = build_column()
    travel = (START_Y + last_top) - STOP_Y
    scroll_frames = travel // SPEED + 1
    scroll_end = scroll_frames / FPS
    fade_start = scroll_end + HOLD
    total = fade_start + PLAYER_LEN

    bg = load_bg(BG)
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 95))
    # soft fade where text exits at the top
    top_mask = Image.new("L", (1, H), 255)
    for y in range(260):
        top_mask.putpixel((0, y), int(255 * (y / 260) ** 1.5))
    top_mask = top_mask.resize((W, H))
    badge = app_store_badge()
    cta = text_img("Try SpeakLife free", font(64, "Bold"))

    def frame(t):
        k = int(round(t * FPS))
        base = zoom_frame(bg, t, total, 1.0, 1.10, (0, -40)).convert("RGBA")
        base = Image.alpha_composite(base, shade)

        y = START_Y - min(k, scroll_frames) * SPEED
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        lay.paste(col, (0, y))
        a = lay.split()[3]
        a = Image.composite(a, Image.new("L", (W, H), 0), top_mask)
        lay.putalpha(a)
        text_a = 1 - ease((t - fade_start) / 0.6)
        if text_a > 0:
            base = Image.alpha_composite(base, with_alpha(lay, text_a))

        tp = t - fade_start - 0.3
        if tp > 0:
            a = ease(tp / 0.7)
            card = player_card(161 + tp)
            sc = 0.94 + 0.06 * a
            card = card.resize((int(card.width * sc), int(card.height * sc)), Image.LANCZOS)
            l2 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            l2.paste(card, ((W - card.width) // 2, 760 - card.height // 2))
            base = Image.alpha_composite(base, with_alpha(l2, a))
            for img, cy, st in [(cta, 1180, 1.4), (badge, 1380, 1.8)]:
                a2 = ease((tp - st) / 0.6)
                if a2 > 0:
                    l3 = Image.new("RGBA", (W, H), (0, 0, 0, 0))
                    l3.paste(img, ((W - img.width) // 2, int(cy - img.height / 2 + (1 - a2) * 24)))
                    base = Image.alpha_composite(base, with_alpha(l3, a2))
        return base.convert("RGB")

    if still:
        frame(still[0]).save(still[1])
        print(f"total {total:.2f}s, scroll ends {scroll_end:.2f}s")
        return

    # Ocean bed, same as render_pain.py.
    d = total + 0.5
    noise = []
    for c, s in [("brown", 7), ("pink", 11), ("brown", 23), ("pink", 31)]:
        noise += ["-f", "lavfi", "-i", f"anoisesrc=d={d}:c={c}:r=44100:a={0.9 if c == 'brown' else 0.6}:seed={s}"]
    swell = "0.35+0.65*pow(max(0,sin(2*PI*t/{p}+{ph})),2)"
    surf = "0.12+0.88*pow(max(0,sin(2*PI*t/{p}+{ph})),3)"
    fc = (f"[1]lowpass=f=400,volume='{swell.format(p=7.3, ph=0.4)}':eval=frame[l1];"
          f"[2]highpass=f=300,lowpass=f=2600,volume='{surf.format(p=7.3, ph=-0.5)}':eval=frame[l2];"
          f"[3]lowpass=f=400,volume='{swell.format(p=8.9, ph=2.1)}':eval=frame[r1];"
          f"[4]highpass=f=300,lowpass=f=2600,volume='{surf.format(p=8.9, ph=1.2)}':eval=frame[r2];"
          "[l1][l2]amix=inputs=2:normalize=0[L];[r1][r2]amix=inputs=2:normalize=0[R];"
          "[L][R]join=inputs=2:channel_layout=stereo,lowpass=f=5000,"
          "loudnorm=I=-18:TP=-2:LRA=11,afade=t=in:d=1.2,"
          f"afade=t=out:st={total - 2.5:.2f}:d=2.5[a]")
    n = int(total * FPS)
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", *noise,
         "-filter_complex", fc, "-map", "0:v", "-map", "[a]", "-t", f"{total:.3f}",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium",
         "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out], stdin=subprocess.PIPE)
    for k in range(n):
        ff.stdin.write(frame(k / FPS).tobytes())
    ff.stdin.close()
    ff.wait()
    print(out, f"{total:.2f}s")


if __name__ == "__main__":
    main()
