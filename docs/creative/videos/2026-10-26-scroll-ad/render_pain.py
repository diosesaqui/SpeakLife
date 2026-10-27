"""Hook + two real App Store reviews typed out + free-trial end card.

Usage: python3 render_pain.py <variant> [out.mp4] [--still SECONDS out.png]
Variants live in VARIANTS below. Reviews are verbatim from the App Store
(trimmed only with an ellipsis). Output includes a synthesized ocean bed.
"""
import subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
from render import (W, H, FPS, THEMES, LOGO, font, load_bg, zoom_frame,
                    ease, with_alpha, app_store_badge)

SERIF = "/System/Library/Fonts/Supplemental/Georgia Bold Italic.ttf"
VARIANTS = {
    "pain": dict(
        out="SL-pain-reviews.mp4",
        bg="pinkHueMountain",
        hook=["When the pain", "won't quiet down,", "let His Word", "speak louder."],
        verse=["“By his wounds we are healed.”  Isaiah 53:5"],
        reviews=[
            ("It has taught me in the midst of wanting to speak death or despair "
             "to instead speak life… and it has produced good fruit in my healing.",
             "MamaKBex, App Store review"),
            ("…every time I’ve read something I just feel lighter, more "
             "encouraged and excited what God has in store for my day.",
             "chevonne818, App Store review"),
        ],
    ),
    "mind": dict(
        out="SL-mind-reviews.mp4",
        bg="sunsetmountains3",
        hook=["When your thoughts", "won't slow down,", "fix them on", "what God says."],
        verse=["“You will keep in perfect peace those",
               "whose minds are steadfast.”  Isaiah 26:3"],
        reviews=[
            ("I’ve been using this app for a few weeks now, and God has moved in "
             "such a noticeable way in my thought life that I’m at a loss for words.",
             "ladfm0613, App Store review"),
            ("Resets your thinking and makes you focus on our only Source of help "
             "as we deal with situations in our daily lives.",
             "Keeps me accountable, App Store review"),
        ],
    ),
}
# Same ads on the top two themes in the app's theme picker, lightly blurred.
VARIANTS["pain-top"] = dict(VARIANTS["pain"], out="SL-pain-reviews-mountain.mp4",
                            bg="mountainonboarding", blur=2.5)
VARIANTS["mind-top"] = dict(VARIANTS["mind"], out="SL-mind-reviews-night.mp4",
                            bg="nightaurora", blur=2.5)
CPS = 34          # typing speed, characters per second
HOOK_END = 5.4


def serif(size):
    return ImageFont.truetype(SERIF, size)


def shadowed(size, draw_fn, blur=9, alpha=200):
    """draw_fn(draw, fill) draws onto a full-frame layer; returns text+shadow."""
    lay = Image.new("RGBA", size, (0, 0, 0, 0))
    sh = Image.new("RGBA", size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(sh), (0, 0, 0, alpha), 3)
    draw_fn(ImageDraw.Draw(lay), (255, 255, 255, 255), 0)
    return Image.alpha_composite(sh.filter(ImageFilter.GaussianBlur(blur)), lay)


def wrap(draw, text, f, maxw):
    lines, cur = [], ""
    for w in text.split():
        t = (cur + " " + w).strip()
        if draw.textlength(t, font=f) <= maxw:
            cur = t
        else:
            lines.append(cur)
            cur = w
    return lines + [cur]


def star_layer():
    """Five white stars, drawn as polygons."""
    import math
    lay = Image.new("RGBA", (W, 160), (0, 0, 0, 0))
    stars = []
    for i in range(5):
        cx, cy, R, r = W / 2 + (i - 2) * 118, 80, 50, 21
        pts = [(cx + (R if k % 2 == 0 else r) * math.sin(k * math.pi / 5),
                cy - (R if k % 2 == 0 else r) * math.cos(k * math.pi / 5)) for k in range(10)]
        s = Image.new("RGBA", (W, 160), (0, 0, 0, 0))
        sh = Image.new("RGBA", (W, 160), (0, 0, 0, 0))
        ImageDraw.Draw(sh).polygon([(x, y + 3) for x, y in pts], fill=(0, 0, 0, 170))
        ImageDraw.Draw(s).polygon(pts, fill="white")
        stars.append(Image.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)), s))
    return stars


def main():
    args = sys.argv[1:]
    still = None
    if "--still" in args:
        i = args.index("--still")
        still = (float(args[i + 1]), args[i + 2])
        del args[i:i + 3]
    v = VARIANTS[args.pop(0) if args else "pain"]
    HOOK, VERSE, REVIEWS = v["hook"], v["verse"], v["reviews"]
    out = args[0] if args else str(Path(__file__).with_name(v["out"]))

    bg = load_bg(THEMES / f"{v['bg']}.imageset").filter(ImageFilter.GaussianBlur(v.get("blur", 7)))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 80))
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))

    # Hook: four short serif lines, each fading up in turn, then the verse.
    hf = serif(92)
    hook_layers = []
    y0 = 700
    for k, ln in enumerate(HOOK):
        y = y0 + k * 118 + (30 if k >= 2 else 0)
        hook_layers.append(shadowed((W, H), lambda d, fill, o, ln=ln, y=y:
                                    d.text((W / 2, y + o), ln, font=hf, fill=fill, anchor="mm")))
    vf = font(40, "Medium")
    verse_layer = shadowed((W, H), lambda d, fill, o: [
        d.text((W / 2, y0 + 4 * 118 + 70 + i * 54 + o), ln, font=vf, fill=fill, anchor="mm")
        for i, ln in enumerate(VERSE)])

    # Reviews: pre-wrap so words never jump while typing.
    qf = font(58, "Medium")
    af = font(38, "Regular")
    stars = star_layer()
    reviews = []
    t = HOOK_END + 0.2
    for text, who in REVIEWS:
        full = "“" + text + "”"
        lines = wrap(probe, full, qf, W - 170)
        type_start = t + 0.7
        type_end = type_start + len(full) / CPS
        hold = 2.2 if len(full) < 100 else 1.8
        end = type_end + hold + 0.4
        reviews.append(dict(lines=lines, who=who, start=t, ts=type_start, te=type_end, end=end))
        t = end + 0.15
    END_START = t
    TOTAL = END_START + 4.6

    logo = Image.open(LOGO).convert("RGBA").resize((280, 280), Image.LANCZOS)
    m = Image.new("L", logo.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 279, 279), 62, fill=255)
    logo.putalpha(m)
    ef = serif(84)
    end_text = shadowed((W, 300), lambda d, fill, o: (
        d.text((W / 2, 90 + o), "Try a Free Trial", font=ef, fill=fill, anchor="mm"),
        d.text((W / 2, 200 + o), "of SpeakLife", font=ef, fill=fill, anchor="mm")))
    badge = app_store_badge()

    def place(canvas, img, cx, cy, a, dy=0):
        if a <= 0:
            return canvas
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        lay.paste(img, (int(cx - img.width / 2), int(cy - img.height / 2 + dy)), img)
        return Image.alpha_composite(canvas, with_alpha(lay, min(a, 1)))

    def review_frame(c, r, t):
        out_a = 1 - ease((t - (r["end"] - 0.4)) / 0.4)
        lh = 76
        block_h = len(r["lines"]) * lh
        top = H / 2 - block_h / 2 + 40
        # stars pop in one by one
        for i, s in enumerate(stars):
            a = ease((t - r["start"] - i * 0.09) / 0.35) * out_a
            c = place(c, s, W / 2, top - 130, a, dy=(1 - min(a, 1)) * 18)
        n = int(max(0, t - r["ts"]) * CPS)
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d, ds = ImageDraw.Draw(lay), ImageDraw.Draw(sh)
        left = n
        caret_xy = None
        for i, ln in enumerate(r["lines"]):
            if left <= 0:
                break
            part = ln[:left]
            left -= len(ln) + 1
            y = top + i * lh
            x0 = W / 2 - probe.textlength(ln, font=qf) / 2  # centered on the full line
            ds.text((x0, y + 3), part, font=qf, fill=(0, 0, 0, 200))
            d.text((x0, y), part, font=qf, fill="white")
            caret_xy = (x0 + probe.textlength(part, font=qf) + 4, y)
        typing = t < r["te"]
        if caret_xy and (typing or int(t * 2.5) % 2 == 0):
            x, y = caret_xy
            d.rectangle((x, y + 8, x + 4, y + 62), fill="white")
        txt = Image.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)), lay)
        c = Image.alpha_composite(c, with_alpha(txt, out_a))
        who = shadowed((W, 80), lambda dd, fill, o:
                       dd.text((W / 2, 40 + o), "— " + r["who"], font=af, fill=fill, anchor="mm"))
        c = place(c, who, W / 2, top + block_h + 70, ease((t - r["te"] - 0.2) / 0.5) * out_a)
        return c

    def frame(t):
        c = zoom_frame(bg, t, TOTAL, 1.0, 1.07, (0, -20)).convert("RGBA")
        c = Image.alpha_composite(c, shade)
        if t < HOOK_END + 0.1:
            out_a = 1 - ease((t - (HOOK_END - 0.5)) / 0.5)
            for k, lay in enumerate(hook_layers):
                a = ease((t - 0.3 - k * 0.55) / 0.8) * out_a
                c = place(c, lay, W / 2, H / 2, a, dy=(1 - min(a / max(out_a, 1e-3), 1)) * 24)
            c = place(c, verse_layer, W / 2, H / 2, ease((t - 2.8) / 0.8) * out_a)
        for r in reviews:
            if r["start"] <= t < r["end"]:
                c = review_frame(c, r, t)
        if t >= END_START:
            te = t - END_START
            c = place(c, logo, W / 2, 620, ease((te - 0.1) / 0.6), dy=(1 - ease((te - 0.1) / 0.6)) * 30)
            c = place(c, end_text, W / 2, 960, ease((te - 0.5) / 0.7))
            c = place(c, badge, W / 2, 1290, ease((te - 1.0) / 0.6), dy=(1 - ease((te - 1.0) / 0.6)) * 30)
        return c.convert("RGB")

    if still:
        frame(still[0]).save(still[1])
        print(f"total {TOTAL:.2f}s, reviews at", [(round(r['start'], 1), round(r['end'], 1)) for r in reviews])
        return

    # Ocean bed: brown-noise swell + pink-noise surf per channel, slow wave envelopes.
    d = TOTAL + 0.5
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
          f"afade=t=out:st={TOTAL - 2.5:.2f}:d=2.5[a]")
    n = int(TOTAL * FPS)
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", *noise,
         "-filter_complex", fc, "-map", "0:v", "-map", "[a]", "-t", f"{TOTAL:.3f}",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-preset", "medium",
         "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out], stdin=subprocess.PIPE)
    for k in range(n):
        ff.stdin.write(frame(k / FPS).tobytes())
    ff.stdin.close()
    ff.wait()
    print(out, f"{TOTAL:.2f}s")


if __name__ == "__main__":
    main()
