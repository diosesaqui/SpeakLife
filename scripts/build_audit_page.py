#!/usr/bin/env python3
"""Build the Storm Audit page from the copy deck.

`marketing/storm-audit/template.html` holds the markup and behaviour.
`docs/storm-audit-copy.md` holds every word. This script parses the deck, checks
it against the routing table, and writes a single deployable
`marketing/storm-audit/index.html` with the copy inlined.

    python3 scripts/build_audit_page.py

Edit the copy deck and re-run. Never hand-edit index.html, or the page stops
saying what the PDFs and the app say.
"""

import argparse
import json
import os
import re
import sys

# The routing contract. Mirrors storm-audit-web-spec.md section 3. `ob` values
# are OnboardingVariant cases in the iOS app; an unrecognised one is ignored by
# the app and silently drops the user into a random onboarding arm, so these are
# checked against the Swift enum below.
ROUTING = {
    "mind":     ("anxiety",    "peace"),
    "body":     ("healing",    "health"),
    "money":    ("provision",  "abundance"),
    "self":     ("renewal",    "identity"),
    "calling":  ("outcomes",   "purpose"),
    "loss":     ("grief",      "grief"),
    "flat":     ("depression", "joy"),
    "spouse":   ("marriage",   "marriage"),
    "child":    ("parenting",  "family"),
    "prodigal": ("prodigal",   "family"),
    "all":      ("hardtimes",  "more"),
}

SUBSTORMS = {"heart": ["loss", "flat"], "people": ["spouse", "child", "prodigal"]}

# key -> (answer key, eyebrow). The eyebrow is descriptive rather than "Question
# three", because the conditional Q1b shifts every later question by one and a
# hard-coded ordinal then contradicts the step counter on two of the routes.
QUESTION_META = {
    "q1":  ("storm",       "Your storm"),
    "q1b": ("substorm",    "Narrow it down"),
    "q2":  ("own_words",   "In your words"),
    "q3":  ("duration",    "How long"),
    "q4":  ("response",    "What you do"),
    "q5":  ("spoken",      "Out loud"),
    "q6":  ("first_hour",  "Your first hour"),
    "q7":  ("loudest",     "The loudest voice"),
    "q8":  ("knows_verse", "The verse"),
}

DURATIONS = {
    "weeks":  {"months": 0,  "phrase": "a few weeks"},
    "months": {"months": 4,  "phrase": "a few months"},
    "year":   {"months": 12, "phrase": "about a year"},
    "years":  {"months": 36, "phrase": "years"},
}

SWIFT_ENUM = ("SpeakLife/SpeakLife/Services/IAP/SubscriptionStore.swift")


# ------------------------------------------------------------------ parsing

def section(md, heading):
    """Text under a heading, up to the next heading of the same or higher level."""
    level = heading.count("#")
    pat = re.escape(heading) + r"\n(.*?)(?=\n#{1," + str(level) + r"} |\Z)"
    m = re.search(pat, md, re.S)
    if not m:
        sys.exit("Copy deck is missing the section %r" % heading)
    return m.group(1)


def value_table(block):
    """Rows of `| \\`value\\` | Label |` as an ordered list of (value, label)."""
    return [(v, lab.strip())
            for v, lab in re.findall(r"^\|\s*`(\w+)`\s*\|\s*([^|]+?)\s*\|\s*$", block, re.M)]


def inline_options(block):
    """The `\\`value\\` Label · \\`value\\` Label` form, which wraps across lines."""
    text = " ".join(
        line.strip() for line in block.split("\n")
        if line.strip() and not line.startswith((">", "|", "#"))
    )
    parts = re.split(r"\s*·\s*", text)
    out = []
    for p in parts:
        m = re.match(r"^`(\w+)`\s+(.+?)\s*$", p)
        if m:
            out.append((m.group(1), m.group(2)))
    return out


def clean(s):
    """Strip the deck's markdown so a string is ready to render."""
    s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)        # bold
    s = re.sub(r"(?<!\w)\*(.+?)\*(?!\w)", r"\1", s)  # italic
    s = s.replace("`", "")
    s = re.sub(r"^\[\s*|\s*\]$", "", s.strip())   # `[ Button ]`
    return s.strip()


def blockquote(block):
    """The `> ` lines of a section, grouped into rendered strings.

    Markdown soft-wraps, so one sentence often spans three source lines. Naive
    line-per-item parsing truncated the CTA copy and shifted every index in the
    scripture blocks. The deck's own conventions decide the grouping:

    * a bare `>` ends the current item
    * a line that is entirely bold is its own item (a scripture reference, or a
      heading sitting directly above its paragraph)
    * a line starting with the bullet begins a new item, and indented lines under
      it continue that bullet
    * anything else continues the current item
    """
    items, cur = [], []

    def flush():
        if cur:
            items.append(clean(" ".join(cur)))
            cur.clear()

    for raw in block.split("\n"):
        if not raw.startswith(">"):
            flush()          # prose between two quote blocks separates them
            continue
        line = re.sub(r"^>\s?", "", raw).rstrip()
        if not line.strip():
            flush()
            continue
        stripped = line.strip()
        heading = stripped.startswith("#")
        standalone = heading or re.match(r"^\*\*[^*]+\*\*$", stripped)
        if standalone or stripped.startswith("·"):
            flush()
        cur.append(stripped.lstrip("#").lstrip("· ").strip())
        if standalone:
            flush()          # a heading or a lone bold line owns its own item
    flush()
    return [i for i in items if i]


def bullets(block):
    """`> · **Title** Body` rows, keeping the bold boundary blockquote() removes.

    The title and the body are two different things on the page, so this reads the
    raw lines rather than the cleaned ones."""
    rows, cur = [], []
    for raw in block.split("\n"):
        if not raw.startswith(">"):
            continue
        line = re.sub(r"^>\s?", "", raw).rstrip()
        if line.strip().startswith("·"):
            if cur:
                rows.append(" ".join(cur))
            cur = [line.strip().lstrip("· ").strip()]
        elif cur and line.strip():
            cur.append(line.strip())
        elif cur:
            rows.append(" ".join(cur))
            cur = []
    if cur:
        rows.append(" ".join(cur))

    out = []
    for r in rows:
        m = re.match(r"^\*\*(.+?)\*\*\s*(.+)$", r)
        if m:
            out.append([clean(m.group(1)), clean(m.group(2))])
    return out


def parse(md):
    data = {"questions": {}, "routes": {}, "methods": {}, "gaps": [],
            "substorms": SUBSTORMS, "durations": DURATIONS}

    # ---- Q1 and the two conditional follow-ups
    q1 = value_table(section(md, "### Q1 — the storm"))
    heart = value_table(section(md, "### Q1b — only when `heart`"))
    people = value_table(section(md, "### Q1b — only when `people`"))
    sub_opts = {"heart": heart, "people": people}

    if [v for v, _ in q1] != list(ROUTING) [:5] + ["heart", "people", "all"]:
        # Q1 mixes routes and the two branch values, so compare explicitly.
        expected = ["mind", "body", "money", "self", "calling", "heart", "people", "all"]
        if [v for v, _ in q1] != expected:
            sys.exit("Q1 options are %s, expected %s" % ([v for v, _ in q1], expected))

    for parent, rows in sub_opts.items():
        if [v for v, _ in rows] != SUBSTORMS[parent]:
            sys.exit("Q1b (%s) options are %s, expected %s"
                     % (parent, [v for v, _ in rows], SUBSTORMS[parent]))

    key, eyebrow = QUESTION_META["q1"]
    data["questions"]["q1"] = {
        "key": key, "eyebrow": eyebrow, "type": "choice",
        "prompt": blockquote(section(md, "### Q1 — the storm"))[0],
        "options": [{"value": v, "label": l} for v, l in q1],
    }
    # Q1b is rendered from whichever branch Q1 selected; both option sets ship.
    data["questions"]["q1b"] = {
        "key": "substorm", "eyebrow": QUESTION_META["q1b"][1], "type": "choice",
        "prompt": blockquote(section(md, "### Q1b — only when `heart`"))[0],
        "options": [], "branches": {
            p: {"prompt": blockquote(section(
                    md, "### Q1b — only when `%s`" % p))[0],
                "options": [{"value": v, "label": l} for v, l in rows]}
            for p, rows in sub_opts.items()
        },
    }

    # ---- Q2, free text
    q2 = blockquote(section(md, "### Q2 — their words"))
    placeholder = re.search(r"`([^`]*\.\.\.)`", section(md, "### Q2 — their words"))
    data["questions"]["q2"] = {
        "key": "own_words", "eyebrow": QUESTION_META["q2"][1], "type": "text",
        "prompt": q2[0], "hint": q2[1] if len(q2) > 1 else "",
        "placeholder": placeholder.group(1) if placeholder else "",
    }

    # ---- Q3 to Q8
    headings = {
        "q3": "### Q3 — duration", "q4": "### Q4 — response", "q5": "### Q5 — the hinge",
        "q6": "### Q6 — first hour", "q7": "### Q7 — loudest voice",
        "q8": "### Q8 — verse knowledge",
    }
    for q, heading in headings.items():
        block = section(md, heading)
        quoted = blockquote(block)
        opts = inline_options(block)
        if not opts:
            sys.exit("No options parsed for %s" % q)
        data["questions"][q] = {
            "key": QUESTION_META[q][0], "eyebrow": QUESTION_META[q][1], "type": "choice",
            "prompt": quoted[0], "hint": quoted[1] if len(quoted) > 1 else "",
            "options": [{"value": v, "label": l} for v, l in opts],
        }

    if set(data["questions"]["q3"]["options"][i]["value"] for i in range(4)) != set(DURATIONS):
        sys.exit("Q3 values do not match the duration table used for the waiting cost.")

    # ---- method labels
    for row in re.findall(
            r"^\| `(\w+)` \| (.+?) \| (.+?) \| (.+?) \|$", section(md, "### 2a. Method labels (beat 2)"), re.M):
        name, line, label, reassurance = [x.strip() for x in row]
        if name not in ("Asker", "Reader", "Speaker"):
            continue                      # the table's own header row
        data["methods"][name] = {"line": line, "label": label, "reassurance": reassurance}
    if set(data["methods"]) != {"Asker", "Reader", "Speaker"}:
        sys.exit("Expected exactly the three method labels, got %s" % sorted(data["methods"]))

    # ---- the six gap cards, in the priority order the deck lists them
    block = section(md, "### 2b. The six gap cards (beat 3)")
    for m in re.finditer(r"\*\*\d+\. `(\w+)`\*\*\n((?:^>.*\n?)+)", block, re.M):
        gid, quoted = m.group(1), blockquote(m.group(2))
        head = quoted[0].lstrip("# ").strip()
        data["gaps"].append({"id": gid, "headline": head, "body": " ".join(quoted[1:])})
    if len(data["gaps"]) != 6:
        sys.exit("Expected six gap cards, parsed %d" % len(data["gaps"]))

    # ---- the ledger lines
    block = section(md, "### 2d. Input ledger")
    quotes = [q for q in blockquote(block)]
    if len(quotes) < 2:
        sys.exit("Expected two input-ledger lines.")
    data["ledger"] = {"voice": quotes[0], "hour": quotes[1]}

    # ---- the eleven result rows
    rows = re.findall(r"^\| `(\w+)` \| (.+?) \| (.+?) \| (.+?) \|$", section(md, "### The eleven"), re.M)
    for route, headline, identity, first in rows:
        m = re.match(r"^(.*?)\s*\*\((.+?)\)\*$", first.strip())
        if not m:
            sys.exit("Could not split the first declaration for '%s'" % route)
        ob, pain = ROUTING[route]
        data["routes"][route] = {
            "headline": headline.strip(), "identity": identity.strip(),
            "declaration": m.group(1).strip(), "declaration_ref": m.group(2).strip(),
            "ob": ob, "pain": pain,
        }
    missing = set(ROUTING) - set(data["routes"])
    if missing:
        sys.exit("The result table is missing: %s" % ", ".join(sorted(missing)))

    # ---- the shared blocks
    # Found by shape, not by index: the deck's line wrapping moves every position
    # the moment a sentence gets a word longer.
    turn = blockquote(section(md, "### The shared beat 4 block"))
    refs = [i for i, t in enumerate(turn) if re.match(r"^(Mark|Matthew|John|Luke) \d", t)]
    if len(refs) < 2:
        sys.exit("The beat 4 block should carry two scripture references.")
    last = refs[-1]
    data["turn"] = {
        "headline": turn[0],
        "body": turn[1],
        # The deck quotes scripture with straight marks in some places and curly
        # in others; the page supplies its own, so strip whichever is there.
        "quote": turn[last - 1].strip("\"'“” "),
        "ref": turn[last],
        "kicker": turn[-1],
    }
    if "Truly I tell you" not in data["turn"]["quote"]:
        sys.exit("Beat 4 quote parsed as %r, expected Mark 11:23." % data["turn"]["quote"][:40])

    wrapper = blockquote(section(md, "### Beat 5 wrapper (all routes)"))
    data["say"] = {
        "headline": next(w for w in wrapper if w.startswith("Say it")),
        "button": next(w for w in wrapper if w.lower().startswith("say it out loud")),
        "after": next(w for w in wrapper if w.startswith("Not in your head")),
        "note": next(w for w in wrapper if w.startswith("That is the whole method")),
    }

    cta_block = section(md, "### The CTA block")
    cta = blockquote(cta_block)
    rows_out = bullets(cta_block)
    data["cta"] = {
        "headline": cta[0],
        "body": cta[1],
        "rows": rows_out,
        "fine": cta[-1],
    }
    if len(rows_out) != 4:
        sys.exit("Expected four CTA rows, parsed %d" % len(rows_out))
    return data


# ---------------------------------------------------------------- checking

def check_ob_codes(root):
    """An unrecognised ob= is ignored by the app, so a typo fails silently."""
    path = os.path.join(root, SWIFT_ENUM)
    if not os.path.exists(path):
        print("  note: %s not found, skipping ob= validation" % SWIFT_ENUM)
        return
    src = open(path, encoding="utf-8").read()
    block = re.search(r"enum OnboardingVariant: String, CaseIterable \{(.*?)\n    \}", src, re.S)
    if not block:
        print("  note: could not read OnboardingVariant, skipping ob= validation")
        return
    cases = set(re.findall(r"\b([a-z][A-Za-z]*)\b",
                           " ".join(re.findall(r"^\s*case (.+)$", block.group(1), re.M))))
    bad = [(r, ob) for r, (ob, _) in ROUTING.items() if ob not in cases]
    if bad:
        for r, ob in bad:
            print("  INVALID ob=%s for route '%s'" % (ob, r), file=sys.stderr)
        sys.exit("Refusing to build: an ob= code is not an OnboardingVariant case.")
    print("  ob= codes: all %d valid against OnboardingVariant" % len(ROUTING))


def check_no_dashes(data):
    flat = json.dumps(data, ensure_ascii=False)
    bad = [s for s in re.findall(r'"([^"]*[—–][^"]*)"', flat)]
    if bad:
        for s in bad:
            print("  DASH: %s" % s, file=sys.stderr)
        sys.exit("Refusing to build: em or en dash in rendered copy.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--copy", default="docs/storm-audit-copy.md")
    ap.add_argument("--template", default="marketing/storm-audit/template.html")
    ap.add_argument("--out", default="marketing/storm-audit/index.html")
    args = ap.parse_args()

    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    md = open(args.copy, encoding="utf-8").read()
    data = parse(md)
    check_no_dashes(data)
    check_ob_codes(root)

    tpl = open(args.template, encoding="utf-8").read()
    if "/*__AUDIT_DATA__*/" not in tpl:
        sys.exit("Template has no /*__AUDIT_DATA__*/ placeholder.")
    blob = json.dumps(data, ensure_ascii=False, indent=2)
    # </script> inside a string literal would close the tag early.
    blob = blob.replace("</", "<\\/")
    html = tpl.replace("/*__AUDIT_DATA__*/", blob)

    open(args.out, "w", encoding="utf-8").write(html)
    print("  routes: %d, questions: %d, gaps: %d" %
          (len(data["routes"]), len(data["questions"]), len(data["gaps"])))
    print("  wrote %s (%.1f KB)" % (args.out, os.path.getsize(args.out) / 1024.0))


if __name__ == "__main__":
    main()
