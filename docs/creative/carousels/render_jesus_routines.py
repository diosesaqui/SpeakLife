"""Render the two "Jesus routine" carousel ads (night + morning), 10 slides each.

Follows the speaklife-carousel skill layout (1080x1080, white, red #8B1A1A,
counter, divider, logo bottom-center, black CTA slide). The skill's Caveat
font is not installed here, so it falls back to Bradley Hand Bold, a system
handwritten face.

Run: python3 docs/creative/carousels/render_jesus_routines.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(HERE, "2026-10-15")
LOGO = os.path.join(REPO, "SpeakLife", "SpeakLife", "Assets.xcassets",
                    "appIconDisplay.imageset", "DivineWisdomLogo.png")
FONT_CANDIDATES = [
    os.path.join(HERE, "Caveat-Bold.ttf"),
    "/System/Library/Fonts/Supplemental/Bradley Hand Bold.ttf",
]

W = H = 1080
RED = "#8B1A1A"
RED_ON_DARK = "#E0584F"  # brand red is unreadable on #111111
BLACK = "#111111"
GRAY = "#777777"
LIGHT = "#AAAAAA"
WHITE = "#FFFFFF"
MAX_W = 900
ZONE_TOP, ZONE_BOTTOM = 110, 860


def font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def wrap(draw, text, f, max_w=MAX_W):
    words, lines, line = text.split(), [], []
    for word in words:
        test = " ".join(line + [word])
        if draw.textlength(test, font=f) <= max_w:
            line.append(word)
        else:
            if line:
                lines.append(" ".join(line))
            line = [word]
    if line:
        lines.append(" ".join(line))
    return lines


def logo_image():
    icon = Image.open(LOGO).convert("RGBA")
    # The source has a soft backdrop around the rounded tile; keep the tile.
    w, h = icon.size
    tile = icon.crop((int(w * 0.085), int(h * 0.085), int(w * 0.915), int(h * 0.915)))
    tile = tile.resize((160, 160), Image.LANCZOS)
    mask = Image.new("L", (160, 160), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 159, 159), radius=36, fill=255)
    tile.putalpha(mask)
    return tile


LOGO_IMG = None


def render(blocks, index, total, path, dark=False):
    """blocks: list of (text, size, color, space_after)."""
    global LOGO_IMG
    if LOGO_IMG is None:
        LOGO_IMG = logo_image()
    canvas = Image.new("RGB", (W, H), BLACK if dark else WHITE)
    draw = ImageDraw.Draw(canvas)

    counter = f"{index} / {total}"
    cf = font(32)
    draw.text((1020 - draw.textlength(counter, font=cf), 30), counter, font=cf, fill=LIGHT)
    draw.line((60, 85, 1020, 85), fill=RED, width=2)

    laid = []
    for text, size, color, after in blocks:
        f = font(size)
        lines = wrap(draw, text, f)
        line_h = int(size * 1.12)
        laid.append((lines, f, line_h, color, after))
    total_h = sum(len(l) * lh + a for l, _, lh, _, a in laid) - laid[-1][4]
    assert total_h <= ZONE_BOTTOM - ZONE_TOP, f"{path}: text block {total_h}px overflows"

    y = ZONE_TOP + (ZONE_BOTTOM - ZONE_TOP - total_h) // 2
    for lines, f, line_h, color, after in laid:
        for line in lines:
            draw.text(((W - draw.textlength(line, font=f)) // 2, y), line, font=f, fill=color)
            y += line_h
        y += after

    canvas.paste(LOGO_IMG, (460, 880), LOGO_IMG)
    canvas.save(path)


def hook(a, b, c):
    return [(a, 74, BLACK, 10), (b, 96, RED, 40), (c, 46, GRAY, 0)]


def story(label, lines):
    return [(label, 54, RED, 34)] + [(l, 50, BLACK, 18) for l in lines]


def turn(main, emphasis, ref):
    return [("But here's the truth:", 56, RED, 40), (main, 78, BLACK, 26),
            (emphasis, 64, RED, 34), (ref, 44, GRAY, 0)]


def step(label, quote, note, ref):
    return [(label, 56, RED, 32), (quote, 64, BLACK, 28), (note, 46, GRAY, 26), (ref, 46, RED, 0)]


def landing(label, declaration, subline):
    return [(label, 56, RED, 34), (declaration, 74, BLACK, 28), (subline, 48, GRAY, 22),
            ("Speak it until you believe it.", 44, GRAY, 0)]


def cta(lead, tagline):
    return [(lead, 56, RED_ON_DARK, 40), ("SPEAKLIFE", 128, WHITE, 22),
            ("7 days free on the App Store", 62, WHITE, 30), (tagline, 44, LIGHT, 0)]


NIGHT = [
    ("hook", hook("What you should be doing", "every night before bed.",
                  "4 steps. Step 2 is the key.")),
    ("turn", turn("Jesus didn't pray about the storm.",
                  "He spoke to it. Then He slept.", "Mark 4:38-39")),
    ("step-1", step("Step 1: Hand it over",
                    "“Cast all your anxiety on him because he cares for you.”",
                    "Name what is heavy, out loud. Then give it to Him. You don't carry it to bed.",
                    "1 Peter 5:7")),
    ("step-2", step("Step 2: Answer the 1am thought out loud",
                    "“He got up, rebuked the wind and said to the waves, ‘Quiet! Be still!’”",
                    "A thought fought silently wins. SpeakLife puts the verse in your hand at 1am.",
                    "Mark 4:39")),
    ("step-3", step("Step 3: Let it go before you sleep",
                    "“Do not let the sun go down while you are still angry.”",
                    "Release the offense tonight. Forgiveness is how your heart lies down.",
                    "Ephesians 4:26")),
    ("step-4", step("Step 4: Declare your sleep",
                    "“In peace I will lie down and sleep, for you alone, LORD, make me dwell in safety.”",
                    "Say it last, every night. Let it be the final word over your mind.",
                    "Psalm 4:8")),
    ("declare", landing("Declare this tonight:",
                        "I lie down in peace and my sleep is sweet, because the Lord keeps me safe.",
                        "My mind is at rest. He watches over me all night.")),
    ("cta", cta("The 1am thought doesn't get the last word. His does.",
                "Bedtime declarations and Scripture audio for sleep.")),
]

MORNING = [
    ("hook", hook("What you should be doing", "first thing every morning.",
                  "4 steps for victory. Step 2 is the key.")),
    ("turn", turn("Jesus didn't wait to see how the day went.",
                  "While it was still dark, He prayed.", "Mark 1:35")),
    ("step-1", step("Step 1: Your first words go to God",
                    "“In the morning, LORD, you hear my voice; in the morning I lay my requests before you and wait expectantly.”",
                    "Before the phone. Before the news. He gets your first words.",
                    "Psalm 5:3")),
    ("step-2", step("Step 2: Answer the first lie out loud",
                    "“It is written: ‘Man shall not live on bread alone, but on every word that comes from the mouth of God.’”",
                    "A thought fought silently wins. SpeakLife's Daily Burst gives you 7 to speak first thing.",
                    "Matthew 4:4")),
    ("step-3", step("Step 3: Speak to the mountain",
                    "“If anyone says to this mountain, ‘Go, throw yourself into the sea,’ and does not doubt… it will be done for them.”",
                    "Don't just pray about what's in front of you today. Speak to it.",
                    "Mark 11:23")),
    ("step-4", step("Step 4: Receive new mercy",
                    "“His compassions never fail. They are new every morning; great is your faithfulness.”",
                    "Yesterday doesn't get the first word. Today is brand new.",
                    "Lamentations 3:22–23")),
    ("declare", landing("Declare this today:",
                        "His mercies are new this morning, and I walk into this day more than a conqueror.",
                        "No weapon formed against me today will prosper.")),
    ("cta", cta("The day doesn't get the first word. His does.",
                "7 Scripture declarations, every morning.")),
]


def build(name, slides):
    folder = os.path.join(OUT, name)
    os.makedirs(folder, exist_ok=True)
    for i, (kind, blocks) in enumerate(slides, start=1):
        path = os.path.join(folder, f"slide-{i:02d}-{kind}.png")
        render(blocks, i, len(slides), path, dark=(kind == "cta"))
    print(folder)


if __name__ == "__main__":
    build("night-before-bed", NIGHT)
    build("morning-victory", MORNING)
