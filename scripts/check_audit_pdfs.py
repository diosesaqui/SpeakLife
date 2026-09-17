#!/usr/bin/env python3
"""Proof the rendered lead-magnet PDFs.

Catches the two failures that are invisible in a thumbnail and obvious in a
reader: text that collides with other text, and text that runs past the footer
rule off the bottom of the page. Run it after every render.

    python3 scripts/check_audit_pdfs.py [--dir marketing/lead-magnet]
"""

import argparse
import glob
import os
import sys

import pymupdf

W, H = 1080, 1350
FOOTER_RULE_Y = H - 108      # in top-left coordinates, the hairline above the footer
FOOTER_TEXT_TOP = H - 100    # the wordmark and page number live below this
TOP_SAFE = 40
PAD = 2.0                    # ignore hairline touches from font bounding boxes


def line_boxes(page):
    """Every rendered line as (block_index, text, rect), skipping footer furniture.

    The block index matters: lines inside one paragraph are allowed to overlap,
    because tight display leading makes consecutive glyph boxes touch and that is
    not a defect. Only collisions BETWEEN paragraphs are real.
    """
    out = []
    for bi, block in enumerate(page.get_text("dict")["blocks"]):
        if block.get("type") != 0:
            continue
        for line in block["lines"]:
            text = "".join(s["text"] for s in line["spans"]).strip()
            if not text:
                continue
            x0, y0, x1, y1 = line["bbox"]
            out.append((bi, text, pymupdf.Rect(x0, y0, x1, y1)))
    return out


def is_footer(text, rect):
    return rect.y0 >= FOOTER_TEXT_TOP and (text == "SPEAKLIFE" or "/" in text)


def check_page(page, page_no):
    problems = []
    body = [(bi, t, r) for bi, t, r in line_boxes(page) if not is_footer(t, r)]

    for _, text, rect in body:
        if rect.y1 > FOOTER_RULE_Y - PAD:
            problems.append("p%d overruns the footer: %r (bottom %.0f, rule %.0f)"
                            % (page_no, text[:52], rect.y1, FOOTER_RULE_Y))
        if rect.y0 < TOP_SAFE:
            problems.append("p%d above the top margin: %r" % (page_no, text[:52]))

    for i in range(len(body)):
        bi, ti, ri = body[i]
        for j in range(i + 1, len(body)):
            bj, tj, rj = body[j]
            if bi == bj:
                continue          # same paragraph, see line_boxes
            inter = ri & rj
            if inter.is_empty:
                continue
            if inter.height > 3 and inter.width > 6:
                problems.append("p%d text collision: %r  x  %r"
                                % (page_no, ti[:40], tj[:40]))
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", default="marketing/lead-magnet")
    args = ap.parse_args()

    paths = sorted(glob.glob(os.path.join(args.dir, "unshakable-*.pdf")))
    if not paths:
        sys.exit("No PDFs found in %s" % args.dir)

    total = 0
    for path in paths:
        doc = pymupdf.open(path)
        problems = []
        if doc.page_count != 10:
            problems.append("%d pages, expected 10" % doc.page_count)
        for i, page in enumerate(doc, start=1):
            if tuple(round(v) for v in (page.rect.width, page.rect.height)) != (W, H):
                problems.append("p%d is %.0fx%.0f, expected %dx%d"
                                % (i, page.rect.width, page.rect.height, W, H))
            problems += check_page(page, i)

        name = os.path.basename(path)
        if problems:
            total += len(problems)
            print("FAIL %s" % name)
            for p in problems:
                print("     %s" % p)
        else:
            print("ok   %s" % name)

    print()
    if total:
        sys.exit("%d layout problem(s). Fix the renderer, do not ship these." % total)
    print("All %d plans clean." % len(paths))


if __name__ == "__main__":
    main()
