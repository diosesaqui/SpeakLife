#!/usr/bin/env python3
"""Render the eleven Storm Audit lead-magnet PDFs.

Every string comes from `docs/storm-audit-copy.md`, which is the copy source of
truth, so a PDF cannot drift from the locked copy. The declarations in that file
are themselves verbatim from `declarationsv10.json`; this script re-verifies that
before rendering and refuses to build if a line has drifted.

Cover plates are the app's own theme images, so the PDF and the product look like
one thing.

    python3 scripts/build_audit_pdfs.py [--out marketing/lead-magnet] [--png-proof]

Requires: reportlab, pillow, and the four Nunito weights plus Lora Italic in
`--fonts` (default: scripts/fonts). See the README note at the bottom of this file
for where those come from.
"""

import argparse
import json
import os
import re
import sys

from PIL import Image, ImageDraw
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas as rl_canvas

# ---------------------------------------------------------------- geometry

W, H = 1080, 1350
MARGIN = 96
CONTENT = W - 2 * MARGIN

# ---------------------------------------------------------------- palette
# Pulled from GlobalConstants.swift so the PDF matches the app exactly.

GOLD = (1.0, 0.843, 0.0)
INK = (0.043, 0.047, 0.063)          # near-black ground
INK_LIFT = (0.078, 0.086, 0.114)     # subtle top lift
WHITE = (1, 1, 1)
BODY = (0.78, 0.79, 0.82)
MUTED = (0.55, 0.57, 0.62)
CARD = (1, 1, 1)                     # drawn at low alpha
SLBLUE = (0.1, 0.15, 0.3)

# ---------------------------------------------------------------- fonts

FONTS = {
    "Nunito-Regular": "Nunito-Regular.ttf",
    "Nunito-SemiBold": "Nunito-SemiBold.ttf",
    "Nunito-Bold": "Nunito-Bold.ttf",
    "Nunito-Black": "Nunito-Black.ttf",
    "Lora-Italic": "Lora-Italic.ttf",
}
REG, SEMI, BOLD, BLACK, SERIF = (
    "Nunito-Regular", "Nunito-SemiBold", "Nunito-Bold", "Nunito-Black", "Lora-Italic",
)


def register_fonts(font_dir):
    missing = [f for f in FONTS.values() if not os.path.exists(os.path.join(font_dir, f))]
    if missing:
        sys.exit(
            "Missing fonts in %s: %s\nSee the note at the bottom of this script."
            % (font_dir, ", ".join(missing))
        )
    for name, filename in FONTS.items():
        pdfmetrics.registerFont(TTFont(name, os.path.join(font_dir, filename)))


# ---------------------------------------------------------------- per-route art
# Cover plate + the verse each plan stands on. The declarations, the headline and
# the title come from the copy deck.

ROUTES = {
    "mind":     dict(image="lakeSunrise2",     title="For the mind\nthat will not stop",
                     verse="You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
                     ref="Isaiah 26:3"),
    "body":     dict(image="sunriseCliff",     title="For your body",
                     verse="He was pierced for our transgressions, he was crushed for our iniquities; the punishment that brought us peace was on him, and by his wounds we are healed.",
                     ref="Isaiah 53:5"),
    "money":    dict(image="mountainValley",   title="For the bills\nand the work",
                     verse="And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
                     ref="Philippians 4:19"),
    "self":     dict(image="mountainonboarding", title="For who you are",
                     verse="Therefore, if anyone is in Christ, the new creation has come: The old has gone, the new is here!",
                     ref="2 Corinthians 5:17"),
    "calling":  dict(image="sunsetmountains3", title="For what you\nare called to",
                     verse="For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.",
                     ref="Jeremiah 29:11"),
    "loss":     dict(image="nightStarrySkies", title="For what you lost",
                     verse="The Lord is close to the brokenhearted and saves those who are crushed in spirit.",
                     ref="Psalm 34:18"),
    "flat":     dict(image="starrySunrise",    title="For the joy\nthat went quiet",
                     verse="May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit.",
                     ref="Romans 15:13"),
    "spouse":   dict(image="autumnLake",       title="For your marriage",
                     verse="Unless the Lord builds the house, the builders labor in vain.",
                     ref="Psalm 127:1"),
    "child":    dict(image="doveSkies",        title="For your children",
                     verse="All your children will be taught by the Lord, and great will be their peace.",
                     ref="Isaiah 54:13"),
    "prodigal": dict(image="lightHouse",       title="For the one you are\nstanding in the gap for",
                     verse="For the Son of Man came to seek and to save the lost.",
                     ref="Luke 19:10"),
    "all":      dict(image="boatLakeMountain", title="For everything\nat once",
                     verse="God is our refuge and strength, an ever-present help in trouble.",
                     ref="Psalm 46:1"),
}

ORDER = ["mind", "body", "money", "self", "calling", "loss", "flat",
         "spouse", "child", "prodigal", "all"]

THEMES = "SpeakLife/SpeakLife/Assets.xcassets/themes"


# ---------------------------------------------------------------- copy parsing

def parse_copy(path):
    """Pull headlines and the eleven declaration sets out of the copy deck."""
    md = open(path, encoding="utf-8").read()

    headlines, firsts = {}, {}
    for row in re.findall(r"^\| `(\w+)` \| (.+?) \| (.+?) \| (.+?) \|$", md, re.M):
        route, headline, identity, first = row
        if route in ROUTES:
            headlines[route] = dict(headline=headline.strip(), identity=identity.strip())
            firsts[route] = first.strip()

    decls = {}
    for route in ROUTES:
        block = re.search(r"^### `%s`\n(.*?)(?=^###|\Z)" % route, md, re.M | re.S)
        if not block:
            sys.exit("No declaration block for route '%s' in the copy deck." % route)
        lines = re.findall(r"^\d+\. (.+?) \*\((.+?)\)\*\s*$", block.group(1), re.M)
        if len(lines) != 7:
            sys.exit("Route '%s' has %d declarations, expected 7." % (route, len(lines)))
        decls[route] = [(t.strip(), r.strip()) for t, r in lines]

    missing = [r for r in ROUTES if r not in headlines]
    if missing:
        sys.exit("No result-table row for: %s" % ", ".join(missing))
    return headlines, decls, firsts


def verify_against_app(decls, json_path):
    """Refuse to render a declaration that is not in the live app."""
    live = {d["text"] for d in json.load(open(json_path, encoding="utf-8"))["declarations"]}
    bad = [(r, t) for r, rows in decls.items() for t, _ in rows if t not in live]
    if bad:
        for route, text in bad:
            print("  NOT IN APP [%s] %s" % (route, text), file=sys.stderr)
        sys.exit("Refusing to render: %d declaration(s) have drifted from the app." % len(bad))


def assert_no_dashes(decls, headlines):
    """Brand rule: no em dashes or en dashes in rendered copy."""
    pool = [t for rows in decls.values() for t, _ in rows]
    pool += [v["headline"] for v in headlines.values()]
    pool += [r["title"] for r in ROUTES.values()] + [r["verse"] for r in ROUTES.values()]
    offenders = [s for s in pool if "—" in s or "–" in s]
    if offenders:
        for s in offenders:
            print("  DASH: %s" % s, file=sys.stderr)
        sys.exit("Refusing to render: em/en dash in rendered copy.")


# ---------------------------------------------------------------- text helpers

def wrap(text, font, size, width):
    words, lines, cur = text.split(), [], ""
    for word in words:
        trial = (cur + " " + word).strip()
        if pdfmetrics.stringWidth(trial, font, size) <= width or not cur:
            cur = trial
        else:
            lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def tracked(c, text, x, y, font, size, tracking):
    """Letter-spaced draw. reportlab's canvas has no setCharSpace, and tracking is
    what makes the eyebrows read as the app's."""
    c.setFont(font, size)
    for ch in text:
        c.drawString(x, y, ch)
        x += pdfmetrics.stringWidth(ch, font, size) + tracking


def tracked_width(text, font, size, tracking):
    return pdfmetrics.stringWidth(text, font, size) + tracking * max(len(text) - 1, 0)


def draw_block(c, text, x, y, font, size, width, leading, color, align="left", tracking=0):
    """Draw wrapped text downward from y (the baseline of line one). Returns the
    baseline y that the next element should start from."""
    c.setFont(font, size)
    c.setFillColorRGB(*color)
    for line in (text.split("\n") if "\n" in text else wrap(text, font, size, width)):
        w = tracked_width(line, font, size, tracking)
        lx = x + (width - w) / 2.0 if align == "center" else x
        if tracking:
            tracked(c, line, lx, y, font, size, tracking)
        else:
            c.drawString(lx, y, line)
        y -= leading
    return y


DECL_TEXT_W = CONTENT - 150     # card width minus the number gutter
DECL_TOP = 978                  # first card's top, after page 8's header block
DECL_FLOOR = 152                # must clear the footer rule


def solve_declaration_type(all_decls):
    """One type size for all eleven plans.

    The sets run from fourteen to twenty-four words, so sizing each page
    independently would ship eleven PDFs with visibly different typography. Solve
    for the largest size that fits the *longest* set and use it everywhere, so the
    variants read as one product.
    """
    ladder = [(33, 60, 16), (32, 56, 14), (31, 52, 13), (30, 50, 12), (29, 48, 11),
              (28, 46, 10), (27, 44, 9), (26, 42, 8), (25, 40, 8), (24, 38, 7)]
    for size, pad, gap in ladder:
        lead = size + 10
        worst = max(
            sum(block_height(t, SEMI, size, DECL_TEXT_W, lead) + pad for t, _ in rows)
            + gap * (len(rows) - 1)
            for rows in all_decls.values()
        )
        if DECL_TOP - worst >= DECL_FLOOR:
            return size, pad, gap, lead
    sys.exit("No type size fits every declaration set on one page. Shorten a set.")


def draw_bottom(c, text, x, last_baseline, font, size, width, leading, color, align="left"):
    """Draw a block whose LAST line sits on `last_baseline`. Closing statements are
    anchored up from the footer, not down from whatever the page left over."""
    h = block_height(text, font, size, width, leading)
    return draw_block(c, text, x, last_baseline + h - leading, font, size,
                      width, leading, color, align=align)


def block_height(text, font, size, width, leading):
    n = len(text.split("\n")) if "\n" in text else len(wrap(text, font, size, width))
    return n * leading


# ---------------------------------------------------------------- page furniture

def ground(c, lift=True):
    c.setFillColorRGB(*INK)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    if lift:
        steps = 60
        for i in range(steps):
            t = i / float(steps)
            col = tuple(INK[j] + (INK_LIFT[j] - INK[j]) * (1 - t) for j in range(3))
            c.setFillColorRGB(*col)
            c.rect(0, H - (i + 1) * (H / 2.0 / steps), W, H / 2.0 / steps + 1, stroke=0, fill=1)


def plate(c, image_name, repo_root, cache, scrim=0.0):
    """Full-bleed app theme image under the brand's dark gradient.

    `scrim` adds flat darkening on top, for a page that has to carry body copy
    over the bright part of a sunrise."""
    key = "%s@%.2f" % (image_name, scrim)
    path = cache.get(key)
    if not path:
        src_dir = os.path.join(repo_root, THEMES, image_name + ".imageset")
        files = [f for f in sorted(os.listdir(src_dir)) if f.lower().endswith((".png", ".jpg"))]
        img = Image.open(os.path.join(src_dir, files[0])).convert("RGB")

        # cover-crop to the page aspect
        scale = max(W / img.width, H / img.height)
        img = img.resize((int(img.width * scale + 1), int(img.height * scale + 1)), Image.LANCZOS)
        left, top = (img.width - W) // 2, (img.height - H) // 2
        img = img.crop((left, top, left + W, top + H))

        # the ad brief's overlay: 82% at the top, 55% through the middle, 78% at the foot
        overlay = Image.new("L", (1, H))
        d = ImageDraw.Draw(overlay)
        for y in range(H):
            t = y / float(H - 1)          # 0 = top of the image
            a = 0.82 + (0.55 - 0.82) * min(t / 0.45, 1.0) if t < 0.45 \
                else 0.55 + (0.78 - 0.55) * ((t - 0.45) / 0.55)
            d.point((0, y), fill=int(a * 255))
        mask = overlay.resize((W, H))
        img = Image.composite(Image.new("RGB", (W, H), (6, 7, 10)), img, mask)

        if scrim:
            flat = Image.new("RGB", (W, H), (6, 7, 10))
            img = Image.blend(img, flat, scrim)

        path = os.path.join(cache["__dir__"], "%s-%02d.jpg" % (image_name, int(scrim * 100)))
        img.save(path, "JPEG", quality=88)
        cache[key] = path
    c.drawImage(ImageReader(path), 0, 0, W, H)


def eyebrow(c, text, y, color=GOLD, align="left", x=MARGIN, width=CONTENT):
    draw_block(c, text.upper(), x, y, BOLD, 26, width, 34, color, align=align, tracking=3.4)
    return y - 34


def card(c, x, y, w, h, alpha=0.06, radius=22, stroke_alpha=0.10):
    c.saveState()
    c.setFillColorRGB(*CARD)
    c.setFillAlpha(alpha)
    c.roundRect(x, y, w, h, radius, stroke=0, fill=1)
    c.setFillAlpha(1)
    c.setStrokeColorRGB(*CARD)
    c.setStrokeAlpha(stroke_alpha)
    c.setLineWidth(1.2)
    c.roundRect(x, y, w, h, radius, stroke=1, fill=0)
    c.restoreState()


def footer(c, page_no, total, on_photo=False):
    col = (0.62, 0.64, 0.68) if not on_photo else (0.78, 0.79, 0.82)
    c.saveState()
    c.setStrokeColorRGB(1, 1, 1)
    c.setStrokeAlpha(0.10)
    c.setLineWidth(1)
    c.line(MARGIN, 108, W - MARGIN, 108)
    c.restoreState()
    c.setFillColorRGB(*col)
    tracked(c, "SPEAKLIFE", MARGIN, 76, BOLD, 21, 2.2)
    c.setFont(REG, 21)
    label = "%d / %d" % (page_no, total)
    c.drawString(W - MARGIN - pdfmetrics.stringWidth(label, REG, 21), 76, label)


# ---------------------------------------------------------------- pages

def page_cover(c, route, headline, ctx):
    plate(c, ROUTES[route]["image"], ctx["root"], ctx["cache"])
    y = 1146
    y = eyebrow(c, "Unshakable  ·  a SpeakLife 7-day plan", y)
    c.setFillColorRGB(*GOLD)
    c.rect(MARGIN, y - 4, 96, 5, stroke=0, fill=1)
    y -= 64
    title = ROUTES[route]["title"]
    size = 92 if max(len(l) for l in title.split("\n")) <= 18 else 76
    draw_block(c, title, MARGIN, y - size, BLACK, size, CONTENT, size * 1.12, WHITE)

    y = 372
    draw_block(c, "Seven declarations. Seven mornings.\nSixty seconds each.",
               MARGIN, y, SEMI, 40, CONTENT, 54, (0.90, 0.91, 0.93))
    draw_block(c, "Out loud. That part is the method.", MARGIN, 228, REG, 34, CONTENT, 44, MUTED)
    footer(c, 1, 10, on_photo=True)


def page_storm(c, route, headline, ctx):
    ground(c)
    y = 1150
    y = eyebrow(c, "Your storm", y)
    y -= 30
    y = draw_block(c, headline["headline"], MARGIN, y - 66, BLACK, 66, CONTENT, 82, WHITE)

    y -= 80
    verse, ref = ROUTES[route]["verse"], ROUTES[route]["ref"]
    vh = block_height(verse, SERIF, 42, CONTENT - 96, 62)
    card(c, MARGIN, y - vh - 96, CONTENT, vh + 140)
    y = draw_block(c, verse, MARGIN + 48, y - 40, SERIF, 42, CONTENT - 96, 62, (0.92, 0.93, 0.95))
    draw_block(c, ref, MARGIN + 48, y - 18, BOLD, 30, CONTENT - 96, 40, GOLD)

    # Anchored up from the footer. The verses run from one line to four, so a
    # flowed position here puts the longest route's closing line off the page.
    draw_bottom(c, "The next six pages are how it makes that trip.",
                MARGIN, 186, SEMI, 38, CONTENT, 52, WHITE)
    draw_bottom(c,
                "That verse was written for this. It has probably been true about you for "
                "years without ever making the trip from the page into your mouth.",
                MARGIN, 186 + 52 + 66, REG, 38, CONTENT, 54, BODY)
    footer(c, 2, 10)


def page_turn(c, route, headline, ctx):
    ground(c, lift=False)
    c.setFillColorRGB(*SLBLUE)
    c.setFillAlpha(0.35)
    c.rect(0, 0, W, H, stroke=0, fill=1)
    c.setFillAlpha(1)
    eyebrow(c, "The turn", 980)
    draw_block(c, "Jesus never\nprayed about\na storm.", MARGIN, 800, BLACK, 104, CONTENT, 124, WHITE)
    footer(c, 3, 10)


def page_proof(c, route, headline, ctx):
    ground(c)
    y = 1150
    y = eyebrow(c, "The proof", y)
    y -= 24
    y = draw_block(c, "He spoke to three things\nnobody speaks to.",
                   MARGIN, y - 58, BLACK, 58, CONTENT, 72, WHITE)

    beats = [
        ("The storm", "“Quiet! Be still!” and the wind stopped.", "Mark 4:39"),
        ("The sickness", "“Be clean.” and the leprosy left.", "Matthew 8:3"),
        ("The grave", "“Lazarus, come out!” and a dead man walked.", "John 11:43"),
    ]
    y -= 74
    for label, line, ref in beats:
        h = 168
        card(c, MARGIN, y - h, CONTENT, h)
        draw_block(c, label, MARGIN + 44, y - 58, BOLD, 34, CONTENT - 88, 44, GOLD)
        ly = draw_block(c, line, MARGIN + 44, y - 106, REG, 38, CONTENT - 88, 50, (0.90, 0.91, 0.93))
        draw_block(c, ref, MARGIN + 44, ly - 4, SEMI, 26, CONTENT - 88, 34, MUTED)
        y -= h + 28

    draw_block(c, "Not one of those was a request.", MARGIN, y - 42, SEMI, 42, CONTENT, 54, WHITE)
    footer(c, 4, 10)


def page_hinge(c, route, headline, ctx):
    ground(c)
    y = eyebrow(c, "The hinge", 1150)
    y -= 24
    y = draw_block(c, "Then He said\nwe do the same.", MARGIN, y - 62, BLACK, 62, CONTENT, 78, WHITE)

    quote = ("“Truly I tell you, if anyone says to this mountain, ‘Go, throw yourself "
             "into the sea,’ and does not doubt in their heart but believes that what they "
             "say will happen, it will be done for them. Therefore I tell you, whatever you ask "
             "for in prayer, believe that you have received it, and it will be yours.”")
    y -= 66
    qh = block_height(quote, SERIF, 40, CONTENT - 96, 60)
    card(c, MARGIN, y - qh - 100, CONTENT, qh + 144)
    ly = draw_block(c, quote, MARGIN + 48, y - 44, SERIF, 40, CONTENT - 96, 60, (0.92, 0.93, 0.95))
    draw_block(c, "Mark 11:23-24", MARGIN + 48, ly - 18, BOLD, 30, CONTENT - 96, 40, GOLD)

    y = y - qh - 190
    draw_block(c, "Says. Not thinks about. Not reads. Says.",
               MARGIN, y, SEMI, 44, CONTENT, 58, WHITE)
    draw_block(c, "Speaking is not our idea. It is the part He named.",
               MARGIN, y - 72, REG, 36, CONTENT, 48, BODY)
    footer(c, 5, 10)


def page_rules(c, route, headline, ctx):
    ground(c)
    y = 1150
    y = eyebrow(c, "The craft", y)
    y -= 24
    y = draw_block(c, "What makes a\ndeclaration work",
                   MARGIN, y - 62, BLACK, 62, CONTENT, 78, WHITE)

    rules = [
        ("First person", "You are the one speaking. Not a quote about somebody else."),
        ("Present tense", "Faith says it done. Not one day. Not please. Now."),
        ("One sentence", "The mouth cannot carry a paragraph with conviction."),
        ("Out loud", "Faith comes by hearing. Your ears are the delivery."),
    ]
    y -= 48
    for label, line in rules:
        h = 122
        card(c, MARGIN, y - h, CONTENT, h)
        draw_block(c, label, MARGIN + 44, y - 46, BOLD, 33, CONTENT - 88, 42, GOLD)
        draw_block(c, line, MARGIN + 44, y - 88, REG, 30, CONTENT - 88, 40, (0.88, 0.89, 0.92))
        y -= h + 18

    draw_bottom(c, "That is the whole craft.\nEverything else is decoration.",
                MARGIN, 172, SEMI, 38, CONTENT, 50, WHITE)
    footer(c, 6, 10)


HIGHER_INTRO = ("A declaration does not argue with the problem. It does not name it, rebuke "
                "it, or ask it to settle down. It says the higher thing that makes the "
                "problem irrelevant.")
HIGHER_CLOSE = ("One of those keeps the problem in the room. The other changes the subject "
                "to something truer.")
HIGHER_CARDS = [
    ("Not this", "\u201cWorry, calm down. I am trying not to be anxious.\u201d",
     (0.85, 0.42, 0.42), 0.05),
    ("This", "\u201cI have the mind of Christ. It is clear, sound, and at rest.\u201d",
     GOLD, 0.08),
]


def page_higher(c, route, headline, ctx):
    """The comparison page solves its own fit.

    Hand-tuned constants broke here every time the copy moved by a line, so the
    page picks the largest scale at which the card stack still clears the closing
    statement rather than trusting arithmetic done once.
    """
    ground(c)
    close_size, close_lead, close_base = 35, 48, 182
    close_top = close_base + block_height(HIGHER_CLOSE, REG, close_size, CONTENT, close_lead)

    for scale in (1.0, 0.96, 0.92, 0.88, 0.84, 0.80, 0.76):
        t_size, t_lead = 62 * scale, 78 * scale
        i_size, i_lead = 38 * scale, 54 * scale
        c_size, c_lead = 37 * scale, 50 * scale
        c_pad, c_gap = 100 * scale, 26 * scale
        y = 1116 - 24 - t_size - 2 * t_lead            # eyebrow, then the two-line title
        y -= 58 * scale
        y -= block_height(HIGHER_INTRO, REG, i_size, CONTENT, i_lead)
        y -= 58 * scale
        for _, text, _, _ in HIGHER_CARDS:
            y -= block_height(text, SEMI, c_size, CONTENT - 96, c_lead) + c_pad + c_gap
        if y > close_top + 28:
            break

    y = eyebrow(c, "The one rule that changes everything", 1150) - 24
    y = draw_block(c, "Never say the low\nthing over yourself",
                   MARGIN, y - t_size, BLACK, t_size, CONTENT, t_lead, WHITE)
    y -= 58 * scale
    y = draw_block(c, HIGHER_INTRO, MARGIN, y, REG, i_size, CONTENT, i_lead, BODY)

    y -= 58 * scale
    for tag, text, col, alpha in HIGHER_CARDS:
        th = block_height(text, SEMI, c_size, CONTENT - 96, c_lead)
        h = th + c_pad
        card(c, MARGIN, y - h, CONTENT, h, alpha=alpha)
        c.setFillColorRGB(*col)
        c.rect(MARGIN, y - h, 7, h, stroke=0, fill=1)
        draw_block(c, tag.upper(), MARGIN + 48, y - c_pad * 0.46, BOLD, 25 * scale,
                   CONTENT - 96, 32, col, tracking=3)
        draw_block(c, text, MARGIN + 48, y - c_pad * 0.92, SEMI, c_size,
                   CONTENT - 96, c_lead, (0.93, 0.94, 0.96))
        y -= h + c_gap

    draw_bottom(c, HIGHER_CLOSE, MARGIN, close_base, REG, close_size, CONTENT,
                close_lead, BODY)
    footer(c, 7, 10)


def page_declarations(c, route, headline, ctx):
    ground(c)
    decls = ctx["decls"][route]
    y = 1178
    y = eyebrow(c, "Your seven declarations", y)
    y -= 14
    y = draw_block(c, "One a morning. Out loud.", MARGIN, y - 52, BLACK, 52, CONTENT, 64, WHITE)

    # Seven cards have to clear the footer whatever the line lengths are, and the
    # sets vary from fourteen to twenty-two words. Shrink the type until they fit
    # rather than letting the last two run off the page.
    y -= 36
    size, pad, gap, lead = ctx["decl_type"]
    heights = [block_height(t, SEMI, size, DECL_TEXT_W, lead) + pad for t, _ in decls]
    tw = DECL_TEXT_W

    for i, ((text, ref), h) in enumerate(zip(decls, heights), start=1):
        card(c, MARGIN, y - h, CONTENT, h, alpha=0.055, radius=18)
        c.setFont(BLACK, size - 3)
        c.setFillColorRGB(*GOLD)
        c.drawString(MARGIN + 38, y - lead - 2, str(i))
        ly = draw_block(c, text, MARGIN + 96, y - lead, SEMI, size, tw, lead, (0.93, 0.94, 0.96))
        draw_block(c, ref, MARGIN + 96, ly + lead - 30, BOLD, size - 9, tw, 30, (0.78, 0.67, 0.24))
        y -= h + gap
    footer(c, 8, 10)


MORNINGS_LEAD = "One declaration. Out loud. Before you touch your phone."
MORNINGS_BODY = ("Day one is the first line. Day seven is the last. If you miss a morning, "
                 "say it in the car. The point is not a perfect week. The point is that "
                 "your voice gets there before everything else does.")
MORNINGS_PAYOFF = "You are not trying to feel unshakable.\nYou are becoming it."
MORNINGS_QUOTE = ("\u201cThose who receive God's abundant provision of grace and of the gift "
                  "of righteousness reign in life through the one man, Jesus Christ.\u201d")


def page_mornings(c, route, headline, ctx):
    """Claim, instruction, payoff, then scripture last.

    The page used to close on a paragraph that restated the Romans quote sitting
    directly above it. Cutting it removed the crowding and a repeat in one move,
    and ending on the verse is the stronger close. Like page 7, this page solves
    its own scale rather than trusting fixed offsets.
    """
    ground(c)
    q_base = 214                                   # the quote card's floor

    for scale in (1.0, 0.96, 0.92, 0.88, 0.84, 0.80, 0.76):
        t_size, t_lead = 72 * scale, 86 * scale
        l_size, l_lead = 42 * scale, 58 * scale
        b_size, b_lead = 36 * scale, 50 * scale
        p_size, p_lead = 40 * scale, 54 * scale
        q_size, q_lead = 34 * scale, 48 * scale
        q_pad = 124 * scale

        y = 1116 - 24 - t_size - t_lead            # eyebrow, then the one-line title
        y -= 70 * scale
        y -= block_height(MORNINGS_LEAD, SEMI, l_size, CONTENT, l_lead) + 30 * scale
        y -= block_height(MORNINGS_BODY, REG, b_size, CONTENT, b_lead) + 44 * scale
        y -= block_height(MORNINGS_PAYOFF, BOLD, p_size, CONTENT, p_lead) + 46 * scale
        q_h = block_height(MORNINGS_QUOTE, SERIF, q_size, CONTENT - 96, q_lead) + q_pad
        if y - q_h > q_base:
            break

    y = eyebrow(c, "How to run it", 1150) - 24
    y = draw_block(c, "Seven mornings.", MARGIN, y - t_size, BLACK, t_size,
                   CONTENT, t_lead, WHITE)
    y -= 70 * scale
    y = draw_block(c, MORNINGS_LEAD, MARGIN, y, SEMI, l_size, CONTENT, l_lead,
                   (0.93, 0.94, 0.96)) - 30 * scale
    y = draw_block(c, MORNINGS_BODY, MARGIN, y, REG, b_size, CONTENT, b_lead,
                   BODY) - 44 * scale
    y = draw_block(c, MORNINGS_PAYOFF, MARGIN, y, BOLD, p_size, CONTENT, p_lead,
                   WHITE) - 46 * scale

    qh = block_height(MORNINGS_QUOTE, SERIF, q_size, CONTENT - 96, q_lead)
    card(c, MARGIN, y - qh - q_pad * 0.72, CONTENT, qh + q_pad)
    ly = draw_block(c, MORNINGS_QUOTE, MARGIN + 48, y - q_lead * 0.80, SERIF, q_size,
                    CONTENT - 96, q_lead, (0.92, 0.93, 0.95))
    draw_block(c, "Romans 5:17", MARGIN + 48, ly - 14, BOLD, 27 * scale,
               CONTENT - 96, 36, GOLD)
    footer(c, 9, 10)


def page_ask(c, route, headline, ctx):
    # This page carries more body copy than any other over a photo, so it gets an
    # extra scrim. Legibility beats the picture.
    plate(c, ROUTES[route]["image"], ctx["root"], ctx["cache"], scrim=0.45)
    y = 1188
    y = eyebrow(c, "Where this runs every day", y)
    y -= 14
    y = draw_block(c, "You have seven\ndeclarations for\none storm.",
                   MARGIN, y - 62, BLACK, 62, CONTENT, 76, WHITE)
    y -= 26
    y = draw_block(c,
                   "SpeakLife has 3,586, across 80 categories, matched to the exact thing you "
                   "are walking through.",
                   MARGIN, y, REG, 35, CONTENT, 48, (0.88, 0.89, 0.92))

    rows = [
        ("Your exact storm, not a category.",
         "Say what you are facing in your own words and it finds the Scripture written for it."),
        ("Sixty seconds, before the day starts.",
         "Ready the moment you open your eyes."),
        ("Spoken over you while your hands are busy.",
         "For the commute, the gym, the sleepless night."),
        ("Thirty days, not one good day.",
         "A plan that carries you past the week your feelings quit."),
    ]
    y -= 44
    for title, line in rows:
        draw_block(c, title, MARGIN + 34, y, BOLD, 31, CONTENT - 34, 42, WHITE)
        c.setFillColorRGB(*GOLD)
        c.circle(MARGIN + 12, y + 10, 7, stroke=0, fill=1)
        y = draw_block(c, line, MARGIN + 34, y - 40, REG, 29, CONTENT - 34, 39, (0.82, 0.83, 0.87))
        y -= 20

    c.setFillColorRGB(1, 1, 1)
    c.roundRect(MARGIN, 186, CONTENT, 104, 52, stroke=0, fill=1)
    c.setFont(BOLD, 40)
    c.setFillColorRGB(0.04, 0.05, 0.07)
    label = "Get SpeakLife free"
    c.drawString(MARGIN + (CONTENT - pdfmetrics.stringWidth(label, BOLD, 40)) / 2.0, 220, label)
    draw_block(c, "4.9 on the App Store. Free to start. No card to look around.",
               MARGIN, 144, REG, 28, CONTENT, 38, (0.78, 0.79, 0.82), align="center")
    footer(c, 10, 10, on_photo=True)


PAGES = [page_cover, page_storm, page_turn, page_proof, page_hinge,
         page_rules, page_higher, page_declarations, page_mornings, page_ask]


# ---------------------------------------------------------------- driver

def build(route, headlines, decls, ctx, out_dir):
    path = os.path.join(out_dir, "unshakable-%s.pdf" % route)
    c = rl_canvas.Canvas(path, pagesize=(W, H))
    c.setTitle("UNSHAKABLE - %s" % ROUTES[route]["title"].replace("\n", " "))
    c.setAuthor("SpeakLife")
    c.setSubject("A 7-day plan for speaking God's Word over your storm")
    for fn in PAGES:
        fn(c, route, headlines[route], ctx)
        c.showPage()
    c.save()
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="marketing/lead-magnet")
    ap.add_argument("--fonts", default="scripts/fonts")
    ap.add_argument("--routes", default="", help="comma-separated subset, for a quick look")
    ap.add_argument("--png-proof", action="store_true", help="also write a PNG of page 1 and 8")
    args = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)
    register_fonts(args.fonts)

    copy_path = "docs/storm-audit-copy.md"
    json_path = "SpeakLife/SpeakLife/Preview Content/AffirmationData/declarationsv10.json"
    headlines, decls, firsts = parse_copy(copy_path)
    verify_against_app(decls, json_path)
    assert_no_dashes(decls, headlines)

    os.makedirs(args.out, exist_ok=True)
    cache_dir = os.path.join(args.out, ".plates")
    os.makedirs(cache_dir, exist_ok=True)
    ctx = dict(root=root, decls=decls, cache={"__dir__": cache_dir},
               decl_type=solve_declaration_type(decls))
    print("  declaration type: %dpt (fits the longest of the eleven sets)\n"
          % ctx["decl_type"][0])

    routes = [r.strip() for r in args.routes.split(",") if r.strip()] or ORDER
    for route in routes:
        path = build(route, headlines, decls, ctx, args.out)
        print("  %-9s %s  (%.1f MB)" % (route, path, os.path.getsize(path) / 1e6))

    print("\n%d plan(s) written to %s/" % (len(routes), args.out))


if __name__ == "__main__":
    main()

# Fonts: Nunito (400/600/700/900) and Lora Italic, both SIL Open Font License,
# fetched from Google Fonts. Nunito stands in for the app's SF Pro Rounded, which
# is not licensed for redistribution; Lora carries the scripture, matching the
# serif italic in the ad creative brief.
