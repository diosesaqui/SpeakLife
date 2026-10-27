"""Single-image ad in the PAIN-06 "fever what-if" layout ($8.56 CPT, the
cheapest trial in the account): navy square, two-weight headline, three
numbered steps with step 2 in gold, gold verse reference, SPEAKLIFE footer.

Concept: don't wait for the crisis to find out who you are in Christ.

Run: python3 docs/creative/statics/render_identity_static.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "2026-10-15")
FONTS = os.path.expanduser("~/Library/Fonts")

W = H = 1080
NAVY = (18, 22, 49)
WHITE = (255, 255, 255)
BODY = (195, 199, 224)
NUM = (170, 176, 210)
GOLD = (212, 168, 80)
FOOT = (76, 80, 105)


def f(weight, size):
    return ImageFont.truetype(os.path.join(FONTS, f"SF-Pro-Display-{weight}.otf"), size)



def wrap_runs(d, runs, max_w):
    """Word-wrap a list of (text, font, color) runs into lines of runs."""
    words = []
    for text, fo, col in runs:
        for i, w in enumerate(text.split(" ")):
            if w == "":
                continue
            words.append((w, fo, col))
    lines, line = [], []
    for w in words:
        trial = line + [w]
        width = sum(d.textlength(x[0], font=x[1]) for x in trial) + d.textlength(" ", font=w[1]) * (len(trial) - 1)
        if line and width > max_w:
            lines.append(line)
            line = [w]
        else:
            line = trial
    if line:
        lines.append(line)
    return lines


def draw_line(d, line, x, y, center=False, width=None):
    total = sum(d.textlength(w, font=fo) for w, fo, _ in line) + sum(
        d.textlength(" ", font=fo) for _, fo, _ in line[1:])
    if center:
        x = (W - total) / 2
    for i, (w, fo, col) in enumerate(line):
        d.text((x, y), w, font=fo, fill=col)
        x += d.textlength(w, font=fo) + (d.textlength(" ", font=fo) if i < len(line) - 1 else 0)


def render(path, headline, steps, verse):
    im = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(im)

    # Headline: centered, two weights, like "the fever. He spoke to it."
    hl = wrap_runs(d, headline, 760)
    hsize = headline[0][1].size
    y = 260
    for line in hl:
        draw_line(d, line, 0, y, center=True)
        y += int(hsize * 1.2)

    # Steps: left-aligned list with hanging numbers
    y += 70
    nx, tx, max_w = 212, 264, 600
    for n, runs, hl_gold in steps:
        nf = f("Bold", 34)
        d.text((nx, y), f"{n}.", font=nf, fill=GOLD if hl_gold else NUM)
        lines = wrap_runs(d, runs, max_w)
        for line in lines:
            draw_line(d, line, tx, y)
            y += 52
        y += 22
    d.text((tx, y - 10), verse, font=f("Regular", 30), fill=GOLD)

    footer = "S P E A K L I F E"
    ff = f("Medium", 22) if os.path.exists(os.path.join(FONTS, "SF-Pro-Display-Medium.otf")) else f("Regular", 22)
    d.text(((W - d.textlength(footer, font=ff)) / 2, 1026), footer, font=ff, fill=FOOT)
    im.save(path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    R, B = f("Regular", 58), f("Bold", 58)
    s_r, s_b = f("Regular", 34), f("Bold", 34)
    s_g = f("Bold", 34)
    render(
        os.path.join(OUT, "identity-before-crisis-static.png"),
        headline=[("The crisis is the worst time to find out", R, WHITE),
                  ("who you are in Christ.", B, WHITE)],
        steps=[
            (1, [("learn what Jesus already paid for.", s_r, BODY)], False),
            (2, [("renew your mind to it every day.", s_g, GOLD)], True),
            (3, [("say it out loud while it\u2019s calm.", s_b, WHITE),
                 ("“He has given me everything I need.”", s_r, BODY)], False),
        ],
        verse="2 Peter 1:3",
    )
    print(OUT)
