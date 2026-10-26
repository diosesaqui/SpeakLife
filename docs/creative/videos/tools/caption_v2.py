"""Burn word-by-word captions onto a talking video (v2).

What the viewer sees:
- 1 to 3 words at a time, big condensed uppercase, white with a dark outline and soft shadow.
- The word being spoken sits on a yellow highlight box, so the eye follows the voice.
- Keywords stay gold the whole time (prayer, declaration, health...).
- Each new phrase pops in (a quick scale-up), so the captions feel alive, not pasted on.
- When a verse is quoted, a small reference chip ("ISAIAH 53:5") slides in above the caption.
- The hook looks like Instagram's own text tool: sentence case, TikTok Sans SemiBold, a white
  highlight hugging each line, colour emoji. It is on screen from frame 0 (the thumbnail).

Frames are drawn with PIL and piped through ffmpeg, because this ffmpeg has no drawtext/libass.

Usage:
  python3 caption_v2.py in.mp4 out.mp4 --hook "Prayer asks. Declaration enforces. Here's the difference 👇" \
      --keywords prayer,declaration,health,peace,provision,speaklife \
      --refs '[["wounds","ISAIAH 53:5"],["my","JOHN 14:27"]]' \
      --fixes '{"health?":"health."}'

  Preview one frame before the full render:  --still 1.0 preview.png
  Hook options: --hook-font tiktok (default) | avenir | helvetica | ...   --hook-style light | dark | plain

A --refs trigger fires on the first time that word is spoken after the previous chip.
--fixes rewrites whisper tokens (exact match, punctuation included), e.g. {"SAM": "Psalm"}.
"""
import argparse
import json
import os
import re
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--hook", default="")
ap.add_argument("--hook-secs", type=float, default=3.0)
ap.add_argument("--hook-font", default="tiktok", help="avenir, avenir-bold, helvetica, rounded, sf, sf-bold, tiktok-medium, tiktok, tiktok-bold")
ap.add_argument("--hook-style", default="light", choices=["light", "dark", "plain"])
ap.add_argument("--still", nargs=2, metavar=("SECONDS", "OUT_PNG"), help="render one frame and stop")
ap.add_argument("--keywords", default="")
ap.add_argument("--refs", default="[]")
ap.add_argument("--fixes", default="{}")
ap.add_argument("--y", type=float, default=0.66, help="caption centre, fraction of height")
args = ap.parse_args()

FONT_FILE = "/System/Library/Fonts/Avenir Next Condensed.ttc"
HEAVY, DEMI = 8, 2
YELLOW = (255, 214, 10)
GOLD = (255, 196, 46)
INK = (12, 12, 14)

probe = json.loads(subprocess.check_output(
    ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
     "stream=width,height,r_frame_rate", "-of", "json", args.src]))["streams"][0]
W, H = probe["width"], probe["height"]
num, den = map(int, probe["r_frame_rate"].split("/"))
FPS = num / den

# ---------- words ----------
tmp = tempfile.mkdtemp()
subprocess.run(["whisper", args.src, "--model", "small", "--language", "en", "--word_timestamps", "True",
                "--output_format", "json", "--output_dir", tmp], check=True, capture_output=True)
data = json.load(open(os.path.join(tmp, os.path.splitext(os.path.basename(args.src))[0] + ".json")))
raw = [dict(w) for seg in data["segments"] for w in seg.get("words", [])]

FIXES = json.loads(args.fixes)


def fix(ws):
    for w in ws:
        t = w["word"].strip()
        if t in FIXES:
            w["word"] = " " + FIXES[t]


fix(raw)
words = []
for w in raw:
    t = w["word"].strip()
    if words:
        prev = words[-1]["word"].strip()
        # whisper writes "Psalm 112:7" as "Psalm -112 -7": drop the stray dash after a word
        if t.startswith("-") and t[1:].rstrip(".,").isdigit() and not prev.rstrip(".,").isdigit():
            t = t[1:]
            w = {**w, "word": " " + t}
        if prev == "Speak" and t.lower().startswith("life"):
            words[-1] = {**words[-1], "word": "SpeakLife" + t[4:], "end": w["end"]}
            continue
        if prev.isdigit() and t[:1] in "-." and t[1:].rstrip(".,").isdigit():
            words[-1] = {**words[-1], "word": prev + ":" + t[1:], "end": w["end"]}
            continue
    words.append(w)
fix(words)
for w in words:
    w["raw"] = w["word"].strip()
    w["show"] = re.sub(r"[\"“”.,!;:]+$", "", re.sub(r"^[\"“”]+", "", w["raw"])).upper()
    w["show"] = w["show"].replace("“", "").replace("”", "").replace('"', "")

# ---------- chunks ----------
# Split into sentences (punctuation or a pause), then cut each sentence into evenly sized phrases
# of at most 3 words, with the bigger phrases last ("MY PEACE" / "I GIVE YOU"), so no word is
# left alone on screen.
sentences, cur = [], []
for i, w in enumerate(words):
    cur.append(w)
    nxt = words[i + 1] if i + 1 < len(words) else None
    pause = nxt and nxt["start"] - w["end"] > 0.28
    if w["raw"].endswith((".", "?", ",", "!")) or pause or not nxt:
        sentences.append(cur)
        cur = []
def split(sen, n):
    base, extra = divmod(len(sen), n)
    sizes = [base] * (n - extra) + [base + 1] * extra
    out, k = [], 0
    for sz in sizes:
        out.append(sen[k:k + sz])
        k += sz
    return out


MAX_CHARS = 14  # longest phrase that still fits on one line at this font size
chunks = []
for sen in sentences:
    n = -(-len(sen) // 3)
    while n < len(sen) and max(len(" ".join(x["show"] for x in c)) for c in split(sen, n)) > MAX_CHARS:
        n += 1
    chunks += split(sen, n)
for i, ch in enumerate(chunks):
    ch_start = ch[0]["start"] - 0.04
    if i + 1 < len(chunks):
        nstart = chunks[i + 1][0]["start"] - 0.04
        end = nstart if nstart - ch[-1]["end"] < 0.7 else ch[-1]["end"] + 0.35
    else:
        end = ch[-1]["end"] + 0.6
    chunks[i] = {"words": ch, "start": max(0.0, ch_start), "end": end}

KEY = {k.strip().upper() for k in args.keywords.split(",") if k.strip()}


def is_key(show):
    return show in KEY or (show.endswith("'S") and show[:-2] in KEY)


# ---------- drawing ----------
def font(size, idx=HEAVY):
    return ImageFont.truetype(FONT_FILE, size, index=idx)


CAP = font(int(W * 0.105))
GAP = int(W * 0.042)
PADX, PADY = int(W * 0.018), int(W * 0.006)
STROKE = max(3, int(W * 0.008))


def layout(ch):
    """Split a chunk into at most 2 lines that fit 88% of the width."""
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    widths = [d.textlength(w["show"], font=CAP) for w in ch["words"]]
    lines, line, lw = [], [], 0
    for i, wd in enumerate(widths):
        add = wd + (GAP if line else 0)
        if line and lw + add > W * 0.88:
            lines.append(line)
            line, lw = [], 0
            add = wd
        line.append(i)
        lw += add
    lines.append(line)
    return widths, lines


def render_chunk(ch, active):
    """Full-frame RGBA of one chunk with word `active` highlighted (-1 for none)."""
    widths, lines = layout(ch)
    asc, desc = CAP.getmetrics()
    lh = int((asc + desc) * 1.02)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d, sd = ImageDraw.Draw(img), ImageDraw.Draw(shadow)
    y = int(H * args.y) - lh * len(lines) // 2
    for line in lines:
        total = sum(widths[i] for i in line) + GAP * (len(line) - 1)
        x = (W - total) / 2
        for i in line:
            w = ch["words"][i]
            box = [x - PADX, y + PADY, x + widths[i] + PADX, y + lh - PADY]
            if i == active:
                sd.rounded_rectangle(box, radius=int(W * 0.018), fill=(0, 0, 0, 120))
                d.rounded_rectangle(box, radius=int(W * 0.018), fill=YELLOW)
                d.text((x, y), w["show"], font=CAP, fill=INK)
            else:
                sd.text((x, y), w["show"], font=CAP, fill=(0, 0, 0, 170), stroke_width=STROKE + 2,
                        stroke_fill=(0, 0, 0, 170))
                fill = GOLD if is_key(w["show"]) else (255, 255, 255)
                d.text((x, y), w["show"], font=CAP, fill=fill, stroke_width=STROKE, stroke_fill=INK)
            x += widths[i] + GAP
        y += lh
    shadow = shadow.filter(ImageFilter.GaussianBlur(W * 0.012))
    out = Image.alpha_composite(shadow, img)
    return out.crop(out.getbbox()), out.getbbox()


def wrap(text, f, maxw):
    """Even line breaks: try every split into 1-3 lines and keep the one whose longest line is
    shortest, breaking after a period or comma whenever possible. No word is left alone on a line."""
    from itertools import combinations
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    ws = text.split()
    best = None
    for nl in range(1, min(3, len(ws)) + 1):
        for cuts in combinations(range(1, len(ws)), nl - 1):
            parts = [" ".join(ws[i:j]) for i, j in zip((0,) + cuts, cuts + (len(ws),))]
            widest = max(d.textlength(p, font=f) for p in parts)
            if widest > W * maxw or (nl > 1 and min(len(p.split()) for p in parts) < 2):
                continue
            punct = sum(not parts[k].endswith((".", ",")) for k in range(nl - 1))
            score = (punct, nl, widest)  # sentence-end breaks first, then fewest lines
            if best is None or score < best[0]:
                best = (score, parts)
    return best[1] if best else [text]


EMOJI_RE = re.compile("([\U0001F000-\U0001FAFF\u2600-\u27BF\u2B00-\u2BFF\uFE0F\u200D]+)")
EMOJI_FONT = "/System/Library/Fonts/Apple Color Emoji.ttc"


def emoji_img(seq, height):
    """Apple colour emoji (the font only ships bitmap strikes, so draw at 160px and scale)."""
    ef = ImageFont.truetype(EMOJI_FONT, 160)
    im = Image.new("RGBA", (400, 220), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((10, 10), seq, font=ef, embedded_color=True)
    im = im.crop(im.getbbox())
    return im.resize((max(1, int(im.width * height / im.height)), height), Image.LANCZOS)


TIKTOK_SANS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../fonts/TikTokSans.ttf")
HOOK_FONTS = {
    # name: (file, ttc index or variable-font instance name)
    "avenir": ("/System/Library/Fonts/Avenir Next.ttc", 2),          # Avenir Next Demi Bold
    "avenir-bold": ("/System/Library/Fonts/Avenir Next.ttc", 0),
    "helvetica": ("/System/Library/Fonts/HelveticaNeue.ttc", 10),    # Helvetica Neue Medium
    "rounded": ("/System/Library/Fonts/SFNSRounded.ttf", "Semibold"),
    "sf": ("/System/Library/Fonts/SFNS.ttf", "Semibold"),
    "sf-bold": ("/System/Library/Fonts/SFNS.ttf", "Bold"),
    # TikTok's own app font (free, OFL), kept in docs/creative/fonts/
    "tiktok-medium": (TIKTOK_SANS, "Medium"),
    "tiktok": (TIKTOK_SANS, "SemiBold"),
    "tiktok-bold": (TIKTOK_SANS, "Bold"),
}


def hook_font(name, size):
    path, which = HOOK_FONTS[name]
    if isinstance(which, int):
        return ImageFont.truetype(path, size, index=which)
    f = ImageFont.truetype(path, size)
    f.set_variation_by_name(which)
    return f


def ig_hook(text, style="light"):
    """Hook drawn like Instagram's own text tool: sentence case, SF Pro Bold, and a background
    that hugs each line (the 'highlight' look), so it reads as native, not as an ad overlay.
    Colour emoji work. style: light = white highlight, black text · dark = black highlight,
    white text · plain = white text with a soft outline and no background."""
    size = int(W * 0.061)
    f = hook_font(args.hook_font, size)
    d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    eh = int(size * 0.95)

    def segs(line):
        return [x for x in EMOJI_RE.split(line) if x]

    def seg_w(line):
        return sum((emoji_img(x, eh).width + size * 0.14) if EMOJI_RE.fullmatch(x) else d0.textlength(x, font=f)
                   for x in segs(line))

    # wrap() measures with the text font; emoji are about one em wide, close enough for breaking.
    lines = wrap(text, f, 0.86)
    asc, desc = f.getmetrics()
    lh = int((asc + desc) * 1.08)
    px = int(size * 0.42)
    r = int(lh * 0.32)
    widths = [seg_w(l) for l in lines]
    Wimg = int(max(widths) + 2 * px + 8)
    img = Image.new("RGBA", (Wimg, lh * len(lines) + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    bg, fg = {"light": ((255, 255, 255, 255), (0, 0, 0)),
              "dark": ((0, 0, 0, 215), (255, 255, 255)),
              "plain": (None, (255, 255, 255))}[style]
    boxes = []
    for k, w in enumerate(widths):
        x0 = (Wimg - w) / 2 - px
        boxes.append((x0, 4 + k * lh, x0 + w + 2 * px, 4 + (k + 1) * lh))
    if bg:
        for bx in boxes:
            d.rounded_rectangle(bx, radius=r, fill=bg)
        # Fill the seams between stacked lines so the highlight reads as one shape.
        for a, bx in zip(boxes, boxes[1:]):
            x0, x1 = max(a[0], bx[0]), min(a[2], bx[2])
            d.rectangle((x0, a[3] - r, x1, a[3] + r), fill=bg)
    for k, l in enumerate(lines):
        x = (Wimg - widths[k]) / 2
        # Baseline placed so capital letters sit dead centre in the line box, whatever the font metrics.
        cap = -f.getbbox("H", anchor="ls")[1]
        y = 4 + k * lh + lh / 2 + cap / 2
        for sg in segs(l):
            if EMOJI_RE.fullmatch(sg):
                em = emoji_img(sg, eh)
                img.alpha_composite(em, (int(x + size * 0.1), int(4 + k * lh + (lh - eh) / 2)))
                x += em.width + size * 0.14
                continue
            if style == "plain":
                d.text((x, y), sg, font=f, fill=fg, anchor="ls", stroke_width=max(2, size // 14), stroke_fill=(0, 0, 0, 200))
            else:
                d.text((x, y), sg, font=f, fill=fg, anchor="ls")
            x += d.textlength(sg, font=f)
    return img


def card(text, size, fg, bg, idx=HEAVY, maxw=0.84, radius=0.03):
    f = font(size, idx)
    d = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    lines = wrap(text, f, maxw)
    asc, desc = f.getmetrics()
    lh = int((asc + desc) * 1.05)
    tw = max(d.textlength(l, font=f) for l in lines)
    px, py = int(size * 0.55), int(size * 0.35)
    img = Image.new("RGBA", (int(tw + 2 * px), lh * len(lines) + 2 * py), (0, 0, 0, 0))
    dd = ImageDraw.Draw(img)
    dd.rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=int(W * radius), fill=bg)
    for k, l in enumerate(lines):
        dd.text(((img.width - dd.textlength(l, font=f)) / 2, py + k * lh), l, font=f, fill=fg)
    pad = int(W * 0.03)
    sh = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([pad, pad + 6, pad + img.width, pad + img.height + 6],
                                         radius=int(W * radius), fill=(0, 0, 0, 110))
    sh = sh.filter(ImageFilter.GaussianBlur(pad / 2))
    sh.alpha_composite(img, (pad, pad))
    return sh


# Pre-render every chunk state.
for ch in chunks:
    ch["states"] = [render_chunk(ch, a) for a in range(len(ch["words"]))]

hook_img = ig_hook(args.hook, args.hook_style) if args.hook else None

# Reference chips.
chips, last_end = [], -1
for trig, ref in json.loads(args.refs):
    for w in words:
        if w["start"] > last_end and re.sub(r"[^a-z']", "", w["raw"].lower()) == trig.lower():
            sen = next(x for x in sentences if w in x)
            chips.append({"start": w["start"], "end": min(w["start"] + 3.0, sen[-1]["end"] + 0.25),
                          "img": card(ref, int(W * 0.045), INK, GOLD + (255,),
                                      idx=HEAVY, radius=0.02)})
            last_end = w["start"]
            break


def ease_out(p):
    p = min(1.0, max(0.0, p))
    return 1 - (1 - p) ** 3


def paste(frame, img, cx, cy, scale=1.0, alpha=1.0):
    if scale != 1.0:
        img = img.resize((max(1, int(img.width * scale)), max(1, int(img.height * scale))), Image.BILINEAR)
    if alpha < 1.0:
        a = img.getchannel("A").point(lambda v: int(v * alpha))
        img = img.copy()
        img.putalpha(a)
    frame.alpha_composite(img, (int(cx - img.width / 2), int(cy - img.height / 2)))


# ---------- draw ----------
def draw(buf, t):
    frame = Image.frombytes("RGB", (W, H), buf).convert("RGBA")

    if hook_img and t < args.hook_secs:
        pop = 0.94 + 0.06 * ease_out(t / 0.15)
        paste(frame, hook_img, W / 2, H * 0.20, scale=pop, alpha=ease_out((args.hook_secs - t) / 0.2))

    for c in chips:
        if c["start"] <= t < c["end"]:
            p_in, p_out = ease_out((t - c["start"]) / 0.2), ease_out((c["end"] - t) / 0.2)
            paste(frame, c["img"], W / 2, H * args.y - H * 0.115 + (1 - p_in) * H * 0.02, alpha=min(p_in, p_out))

    for ch in chunks:
        if ch["start"] <= t < ch["end"]:
            active = 0
            for k, w in enumerate(ch["words"]):
                if t >= w["start"] - 0.03:
                    active = k
            img, bbox = ch["states"][active]
            pop = 0.86 + 0.14 * ease_out((t - ch["start"]) / 0.12)
            cx, cy = (bbox[0] + bbox[2]) / 2, (bbox[1] + bbox[3]) / 2
            paste(frame, img, cx, cy, scale=pop)
            break
    return frame


if args.still:
    at = float(args.still[0])
    buf = subprocess.check_output(["ffmpeg", "-loglevel", "error", "-ss", str(at), "-i", args.src, "-frames:v", "1",
                                   "-f", "rawvideo", "-pix_fmt", "rgb24", "-"])
    draw(buf, at).convert("RGB").save(args.still[1])
    print(args.still[1])
    raise SystemExit

# ---------- encode ----------
dec = subprocess.Popen(["ffmpeg", "-loglevel", "error", "-i", args.src, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                       stdout=subprocess.PIPE)
enc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
                        "-s", f"{W}x{H}", "-r", probe["r_frame_rate"], "-i", "-", "-i", args.src,
                        "-map", "0:v", "-map", "1:a?", "-c:v", "libx264", "-crf", "18", "-preset", "medium",
                        "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-shortest", args.dst],
                       stdin=subprocess.PIPE)
size = W * H * 3
n = 0
while True:
    buf = dec.stdout.read(size)
    if len(buf) < size:
        break
    enc.stdin.write(draw(buf, n / FPS).convert("RGB").tobytes())
    n += 1

enc.stdin.close()
enc.wait()
dec.wait()
print(args.dst)
print("TRANSCRIPT:", " ".join(w["raw"] for w in words))
