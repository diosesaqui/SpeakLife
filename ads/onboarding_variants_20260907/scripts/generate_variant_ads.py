from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1080, 1080
BG = (18, 22, 48)
WHITE = (255, 255, 255)
DARK_GREY = (80, 85, 105)
MAX_W = 860
FONT_DIR = "/root/.claude/skills/synced/6f09d0c0-9387-4451-9680-433a378aca94_bccac979-dca5-46b5-af8f-b53d6b0f5b1b/speaklife-quote-cards/assets/fonts"
REG = os.path.join(FONT_DIR, "Poppins-Regular.ttf")
BOLD = os.path.join(FONT_DIR, "Poppins-Bold.ttf")
OUT = "/home/user/SpeakLife/ads/onboarding_variants_20260907"

def tw(draw, text, font):
    bb = draw.textbbox((0, 0), text, font=font)
    return bb[2] - bb[0]

def tokenize(segments):
    """-> [(word, bold, space_before)] preserving real whitespace across segments."""
    out = []
    prev_trailing_space = False
    for text, bold in segments:
        boundary_space = prev_trailing_space or text.startswith(" ")
        parts = [w for w in text.split(" ") if w]
        for i, w in enumerate(parts):
            if not out:
                space_before = False
            elif i == 0:
                space_before = boundary_space
            else:
                space_before = True
            out.append((w, bold, space_before))
        prev_trailing_space = text.endswith(" ")
    return out


def wrap(draw, segments, reg_f, bold_f, max_w=MAX_W):
    """-> list of lines, each [(word, bold, space_before)]"""
    space_w = tw(draw, " ", reg_f)
    lines, cur, cur_w = [], [], 0
    for word, bold, space_before in tokenize(segments):
        f = bold_f if bold else reg_f
        ww = tw(draw, word, f)
        add = ww + (space_w if (space_before and cur) else 0)
        if cur and cur_w + add > max_w:
            lines.append(cur)
            cur, cur_w = [(word, bold, False)], ww
        else:
            cur.append((word, bold, space_before and bool(cur)))
            cur_w += add
    if cur:
        lines.append(cur)
    return lines


def make_ad(segments, filename, font_size=56):
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    reg_f = ImageFont.truetype(REG, font_size)
    bold_f = ImageFont.truetype(BOLD, font_size)
    brand_f = ImageFont.truetype(REG, 22)
    LINE_H = int(font_size * 1.45)
    space_w = tw(draw, " ", reg_f)

    lines = wrap(draw, segments, reg_f, bold_f)
    total_h = len(lines) * LINE_H
    y = (H - total_h) // 2

    for line in lines:
        line_w = 0
        for t, b, sp in line:
            line_w += tw(draw, t, bold_f if b else reg_f) + (space_w if sp else 0)
        x = (W - line_w) // 2
        for t, b, sp in line:
            f = bold_f if b else reg_f
            if sp:
                x += space_w
            draw.text((x, y), t, font=f, fill=WHITE)
            x += tw(draw, t, f)
        y += LINE_H

    brand = "SPEAKLIFE"
    bw = tw(draw, brand, brand_f)
    draw.text(((W - bw) // 2, H - 60), brand, font=brand_f, fill=DARK_GREY)
    path = os.path.join(OUT, filename)
    img.save(path)
    print("saved", path, len(lines), "lines")

ADS = [
    ("SpeakLife_Ad_healing.png", [
        ("If you're a Christian holding ", False),
        ("a diagnosis, a chronic pain, or a prayer for someone you love", True),
        (", this is for you.", False),
    ]),
    ("SpeakLife_Ad_provision.png", [
        ("If you're a Christian who is ", False),
        ("short at the end of every month", True),
        (" and tired of watching the bills win, this is for you.", False),
    ]),
    ("SpeakLife_Ad_anxiety.png", [
        ("If you're a Christian who loves God and ", False),
        ("still lies awake at 3am", True),
        (", this was made for you.", False),
    ]),
    ("SpeakLife_Ad_renewal.png", [
        ("If you're a Christian who knows the Word but ", False),
        ("can't stop the voice in your own head", True),
        (", this is for you.", False),
    ]),
    ("SpeakLife_Ad_purpose.png", [
        ("If you're a Christian who knows ", False),
        ("God called you to more", True),
        (" and you're still standing in the same spot, this is for you.", False),
    ]),
    ("SpeakLife_Ad_joy.png", [
        ("If you're a Christian ", False),
        ("carrying a heaviness you can't explain", True),
        (" to anybody, this is for you.", False),
    ]),
    ("SpeakLife_Ad_more.png", [
        ("If you're a Christian who isn't in crisis but knows ", False),
        ("there's more of God than you're living in", True),
        (", this is for you.", False),
    ]),
]

os.makedirs(OUT, exist_ok=True)
for filename, segs in ADS:
    make_ad(segs, filename)
