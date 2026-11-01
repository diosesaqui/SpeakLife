"""Text-over-nature video ad (Abide-style): paragraphs fade in over a slow
zoom on an app theme background, then a crossfade to a logo + App Store card.

Usage: python3 render.py [out.mp4] [--firstwords] [--still SECONDS out.png]

--firstwords: SL-SCROLL-03 (2026-10-30 autopilot), "Before the news..." hook,
opener matches the Promises onboarding, starrySunrise background.
"""
import subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[4]
THEMES = ROOT / "SpeakLife/SpeakLife/Assets.xcassets/themes"
LOGO = ROOT / "SpeakLife/SpeakLife/Assets.xcassets/appIconDisplay.imageset/DivineWisdomLogo.png"
W, H, FPS = 1080, 1920, 30

BG1 = THEMES / "oceansunrise2.imageset"
BG2 = THEMES / "flowingRiver.imageset"

# (start second, text). Blank line between blocks, like the inspo.
BLOCKS = [
    (0.3, "What if the first words out of your mouth every morning were God's promises?"),
    (2.6, "With the SpeakLife app, trade the morning scroll for Scripture-rooted declarations, guided audio, and a daily devotional that set your heart and mind on Him."),
    (7.0, "Less scrolling. More speaking life."),
    (9.0, "Build a daily habit of speaking God's Word over your mind, your family, and your future."),
]
FIRSTWORDS_BG1 = THEMES / "starrySunrise.imageset"
FIRSTWORDS_BLOCKS = [
    (0.3, "Before the news.\nBefore the group chat.\nBefore the to-do list."),
    (3.0, "God's promises.\nOut loud. Every morning."),
    (5.6, "Five minutes speaking what Scripture says over your mind, your body and your home."),
    (9.4, "One less scroll.\nOne more moment with God."),
]
SCENE1_END = 13.5      # crossfade to end card starts
XFADE = 0.8
END_LEN = 4.0
TOTAL = SCENE1_END + END_LEN


def font(size, weight="Semibold"):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f


def load_bg(folder):
    p = next(x for x in folder.iterdir() if x.suffix.lower() in (".png", ".jpg", ".jpeg"))
    im = Image.open(p).convert("RGB")
    s = max(W / im.width, H / im.height) * 1.12  # headroom for the zoom
    return im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)


def zoom_frame(big, t, dur, z0=1.0, z1=1.08, drift=(0, -30)):
    """Slow push-in. big already carries 12% headroom."""
    p = min(max(t / dur, 0), 1)
    p = p * p * (3 - 2 * p)
    z = z0 + (z1 - z0) * p
    cw, ch = W * 1.12 / z, H * 1.12 / z
    cx = big.width / 2 + drift[0] * p
    cy = big.height / 2 + drift[1] * p
    cw, ch = min(cw, big.width), min(ch, big.height)
    cx = min(max(cx, cw / 2), big.width - cw / 2)
    cy = min(max(cy, ch / 2), big.height - ch / 2)
    box = (cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2)
    return big.resize((W, H), Image.BILINEAR, box=box)


def wrap(draw, text, f, maxw):
    if "\n" in text:  # explicit breaks: wrap each phrase on its own
        return [ln for part in text.split("\n") for ln in wrap(draw, part, f, maxw)]
    lines, cur = [], ""
    for w in text.split():
        trial = (cur + " " + w).strip()
        if draw.textlength(trial, font=f) <= maxw:
            cur = trial
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    return lines


def text_layer(lines_blocks, f, line_h, gap):
    """Returns per-block RGBA layers (text + soft shadow) already positioned."""
    total = sum(len(l) * line_h for l in lines_blocks) + gap * (len(lines_blocks) - 1)
    y = (H - total) // 2 - 60
    layers = []
    for lines in lines_blocks:
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d, ds = ImageDraw.Draw(lay), ImageDraw.Draw(sh)
        for i, ln in enumerate(lines):
            x = W / 2
            yy = y + i * line_h
            ds.text((x, yy + 3), ln, font=f, fill=(0, 0, 0, 200), anchor="mt")
            d.text((x, yy), ln, font=f, fill=(255, 255, 255, 255), anchor="mt")
        sh = sh.filter(ImageFilter.GaussianBlur(9))
        layers.append(Image.alpha_composite(sh, lay))
        y += len(lines) * line_h + gap
    return layers


def ease(x):
    x = min(max(x, 0), 1)
    return 1 - (1 - x) ** 3


def with_alpha(layer, a):
    if a >= 1:
        return layer
    r, g, b, al = layer.split()
    al = al.point(lambda v: int(v * a))
    return Image.merge("RGBA", (r, g, b, al))


def app_store_badge():
    bw, bh = 520, 156
    b = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle((0, 0, bw - 1, bh - 1), 30, fill=(0, 0, 0, 255), outline=(166, 166, 166, 255), width=3)
    apple = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 92)
    d.text((40, bh / 2 + 4), "", font=apple, fill="white", anchor="lm")
    d.text((150, 46), "Download on the", font=font(32, "Medium"), fill="white", anchor="lm")
    d.text((148, 102), "App Store", font=font(64, "Semibold"), fill="white", anchor="lm")
    return b


def build_end_card():
    logo = Image.open(LOGO).convert("RGBA").resize((300, 300), Image.LANCZOS)
    m = Image.new("L", logo.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 299, 299), 68, fill=255)
    logo.putalpha(m)
    parts = {"logo": logo}
    for key, txt, f in [("name", "SpeakLife", font(118, "Bold")),
                        ("tag", "Speak Life Every Day", font(64, "Regular"))]:
        lay = Image.new("RGBA", (W, 200), (0, 0, 0, 0))
        sh = Image.new("RGBA", (W, 200), (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((W / 2, 103), txt, font=f, fill=(0, 0, 0, 190), anchor="mm")
        ImageDraw.Draw(lay).text((W / 2, 100), txt, font=f, fill="white", anchor="mm")
        parts[key] = Image.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)), lay)
    parts["badge"] = app_store_badge()
    return parts


def main():
    args = sys.argv[1:]
    still = None
    if "--still" in args:
        i = args.index("--still")
        still = (float(args[i + 1]), args[i + 2])
        del args[i:i + 3]
    global BLOCKS, BG1
    default_out = "SL-scroll-moment.mp4"
    if "--firstwords" in args:
        args.remove("--firstwords")
        BLOCKS, BG1 = FIRSTWORDS_BLOCKS, FIRSTWORDS_BG1
        default_out = "SL-scroll-firstwords.mp4"
    out = args[0] if args else str(Path(__file__).with_name(default_out))

    bg1, bg2 = load_bg(BG1), load_bg(BG2)
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    f = font(62, "Semibold")
    blocks = [wrap(probe, t, f, W - 150) for _, t in BLOCKS]
    layers = text_layer(blocks, f, line_h=78, gap=78)
    end = build_end_card()

    # Gentle darkening so white text reads on the bright sky.
    shade1 = Image.new("RGBA", (W, H), (0, 0, 0, 70))
    shade2 = Image.new("RGBA", (W, H), (0, 0, 0, 110))

    def frame(t):
        s1 = zoom_frame(bg1, t, SCENE1_END + XFADE).convert("RGBA")
        s1 = Image.alpha_composite(s1, shade1)
        for (start, _), lay in zip(BLOCKS, layers):
            a = ease((t - start) / 0.9)
            if a <= 0:
                continue
            rise = int((1 - a) * 28)
            moved = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            moved.paste(lay, (0, rise))
            s1 = Image.alpha_composite(s1, with_alpha(moved, a))
        if t < SCENE1_END:
            return s1.convert("RGB")

        te = t - SCENE1_END
        s2 = zoom_frame(bg2, te, END_LEN, 1.04, 1.0, (0, 20)).convert("RGBA")
        s2 = Image.alpha_composite(s2, shade2)
        def put(img, cy, start, dy=30):
            nonlocal s2
            a = ease((te - start) / 0.7)
            if a <= 0:
                return
            lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            lay.paste(img, ((W - img.width) // 2, int(cy - img.height / 2 + (1 - a) * dy)))
            s2 = Image.alpha_composite(s2, with_alpha(lay, a))
        put(end["logo"], 560, 0.35)
        put(end["name"], 820, 0.6)
        put(end["tag"], 1010, 0.9)
        put(end["badge"], 1380, 1.3)
        return Image.blend(s1, s2, min(te / XFADE, 1)).convert("RGB")

    if still:
        frame(still[0]).save(still[1])
        return

    n = int(TOTAL * FPS)
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
         "-f", "lavfi", "-t", str(TOTAL), "-i", "anullsrc=r=44100:cl=stereo",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium",
         "-c:a", "aac", "-shortest", "-movflags", "+faststart", out],
        stdin=subprocess.PIPE)
    for k in range(n):
        ff.stdin.write(frame(k / FPS).tobytes())
    ff.stdin.close()
    ff.wait()
    print(out)


if __name__ == "__main__":
    main()
