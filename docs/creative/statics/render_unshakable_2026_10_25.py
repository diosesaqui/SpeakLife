"""Unshakable pack: 2 statics on staying unshaken when the world or your circumstances shake,
because speaking God's promises is how believers reign (Romans 5:17).

Copy is from the Copy Vault (faith-ad-formulas) and lives next to its image, so the copy doc and
the Meta specs come from one source. Videos for this angle: docs/creative/videos/2026-10-25-sofia/facetime/.

Run: python3 docs/creative/statics/render_unshakable_2026_10_25.py
"""
import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "2026-10-25-unshakable")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LINK = "http://itunes.apple.com/app/id1617492998"
PAGE_ID = "104027662277976"

BASE = """<!doctype html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:-apple-system,'SF Pro Display',Helvetica,sans-serif;-webkit-font-smoothing:antialiased;position:relative}
.foot{position:absolute;bottom:38px;left:0;right:0;text-align:center;font-size:20px;letter-spacing:8px;font-weight:600}
%s</style></head><body>%s</body></html>"""

ADS = [
    dict(
        key="US-01", slug="thirddoor", ob="hardtimes", formula="Third Door",
        visual="black poster, \"UNSHAKEN.\" + Psalm 112:7",
        css="""
body{background:#0b0b0c;color:#fff}
.wrap{position:absolute;left:96px;right:96px;top:150px}
.big{font-size:158px;font-weight:900;letter-spacing:-5px;line-height:.95}
.bar{width:420px;height:16px;background:#e0a100;margin:26px 0 56px}
.v{font-size:46px;line-height:1.32;color:#e8e8e8}
.v b{color:#fff}
.r{font-size:26px;font-weight:700;color:#e0a100;margin-top:22px;letter-spacing:1px}
.foot{color:#4a4a4f}
""",
        body="""
<div class="wrap">
<div class="big">UNSHAKEN.</div>
<div class="bar"></div>
<div class="v">&ldquo;They will have no fear of bad news; <b>their hearts are steadfast, trusting in the LORD.</b>&rdquo;</div>
<div class="r">PSALM 112:7</div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
        long="""What do you do when the news gets louder than your faith?

You could keep scrolling and hope it calms down.
You could pray about it and still lie awake.

Or you could do what Jesus did in the storm. He didn't wait for the wind to stop. He spoke to it.

Here's what's written about you: "They will have no fear of bad news; their hearts are steadfast, trusting in the LORD." Psalm 112:7

• Not fearless because nothing bad happens.
• Steady because of who you trust.
• Unshakable because His Word doesn't move.

Say it out loud before you open the news tomorrow.

SpeakLife puts God's promises in your mouth every morning, before the world gets the first word.

Try it free 👇""",
        short="""the news is loud. His Word is louder.
"They will have no fear of bad news; their hearts are steadfast, trusting in the LORD." Psalm 112:7
SpeakLife puts it in your mouth every morning 👇""",
        headline="Unshaken by bad news", description="Psalm 112:7, out loud daily",
    ),
    dict(
        key="US-02", slug="menu", ob="hardtimes", formula="Menu",
        visual="iPhone Notes, what to say when everything is shaking",
        css="""
body{background:#fff;color:#1c1c1e}
.bar{height:70px;display:flex;justify-content:space-between;align-items:center;padding:0 56px;font-size:28px;font-weight:600}
.nav{height:90px;display:flex;align-items:center;justify-content:space-between;padding:0 44px;color:#e0a100;font-size:32px}
.wrap{padding:0 64px}
.date{color:#8e8e93;font-size:26px;text-align:center;margin:6px 0 28px}
h1{font-size:54px;font-weight:700;line-height:1.12;margin-bottom:24px}
.q{font-size:32px;color:#8e8e93;margin-top:22px}
.a{font-size:36px;line-height:1.3;margin-top:4px;font-weight:600}
.ref{color:#e0a100;font-weight:600;font-size:28px;white-space:nowrap}
.foot{color:#c7c7cc}
""",
        body="""
<div class="bar"><span>6:41</span><span>&#9679;&#9679;&#9679;</span></div>
<div class="nav"><span>&lsaquo; Notes</span><span>&#8943;</span></div>
<div class="wrap">
<div class="date">Sunday, 6:41 AM</div>
<h1>what I say when everything is shaking</h1>
<div class="q">when the news is loud</div>
<div class="a">&ldquo;They will have no fear of bad news.&rdquo; <span class="ref">Psalm 112:7</span></div>
<div class="q">when the ground moves</div>
<div class="a">&ldquo;Therefore we will not fear, though the earth give way.&rdquo; <span class="ref">Psalm 46:2</span></div>
<div class="q">when circumstances talk</div>
<div class="a">&ldquo;&hellip;reign in life through the one man, Jesus Christ!&rdquo; <span class="ref">Romans 5:17</span></div>
<div class="q">when I feel too small for it</div>
<div class="a">&ldquo;I can do all this through him who gives me strength.&rdquo; <span class="ref">Philippians 4:13</span></div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
        long="""Looking for something to stand on when everything around you is shaking?

The people who stay steady aren't the ones with easy lives. They're the ones with the right words ready.

Here's the list worth saving:
• When the news is loud: "They will have no fear of bad news." Psalm 112:7
• When the ground moves: "God is our refuge and strength, an ever-present help in trouble. Therefore we will not fear, though the earth give way." Psalm 46:1-2
• When circumstances talk: "Those who receive God's abundant provision of grace and of the gift of righteousness reign in life through the one man, Jesus Christ!" Romans 5:17
• When you feel too small for it: "I can do all this through him who gives me strength." Philippians 4:13

Say them out loud. Every morning. Before the day argues with them.

SpeakLife is where these live: God's promises, ready to speak, for whatever you're facing.

Why people keep it:
✓ Rooted: every declaration comes with its verse
✓ Quick: a few minutes a morning
✓ Out loud: you hear yourself agree with God

You weren't saved to survive this. You were saved to reign in it. Save this 👇""",
        short="""save this. what to say when everything is shaking:
news → Psalm 112:7. the ground moving → Psalm 46:1-2. circumstances talking → Romans 5:17.
SpeakLife has them ready every morning 👇""",
        headline="Unshakable when it's shaking", description="God's promises, spoken daily",
    ),
]


def name(ad, v):
    return f"{ad['key']}-{ad['slug']}-{v}-{ad['ob']}"


def write_copy_doc():
    lines = ["# Unshakable Pack (statics) — 2026-10-25", "",
             "Angle: stay unshaken when the world or your circumstances shake, because speaking God's",
             "promises is how believers reign (Romans 5:17). Copy from the Copy Vault. CTA is Download.",
             "Generated by `render_unshakable_2026_10_25.py`; edit copy there.", "",
             "| Ad | Formula | Visual |", "|---|---|---|"]
    for a in ADS:
        lines.append(f"| {a['key']} | {a['formula']} | {a['visual']} |")
    for a in ADS:
        lines += ["", "---", "", f"## {a['key']} · {a['formula']}", "", "**Primary text (long)**"]
        lines += ["> " + l if l else ">" for l in a["long"].split("\n")]
        lines += ["", "**Primary text (short)**"]
        lines += ["> " + l if l else ">" for l in a["short"].split("\n")]
        lines += ["", f"**Headline:** {a['headline']} · **Description:** {a['description']} · **CTA:** Download"]
    open(os.path.join(OUT, "UNSHAKABLE_AD_COPY.md"), "w").write("\n".join(lines) + "\n")


def write_specs(hashes):
    specs = []
    for a in ADS:
        h = hashes.get(a["key"])
        for v, msg in (("L", a["long"]), ("S", a["short"])):
            spec = {"object_story_spec": {"page_id": PAGE_ID, "link_data": {
                "link": LINK, "image_hash": h, "message": msg, "name": a["headline"],
                "description": a["description"],
                "call_to_action": {"type": "DOWNLOAD", "value": {"link": LINK}}}}}
            specs.append({"name": name(a, v), "creative": json.dumps(spec, ensure_ascii=False)})
    json.dump(specs, open(os.path.join(OUT, "specs.json"), "w"), ensure_ascii=False, indent=1)


def main():
    os.makedirs(OUT, exist_ok=True)
    for a in ADS:
        stem = f"{a['key']}-{a['slug']}"
        html = os.path.join(OUT, f"{stem}.html")
        png = os.path.join(OUT, f"{stem}.png")
        with open(html, "w") as fh:
            fh.write(BASE % (a["css"], a["body"]))
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=1", "--window-size=1080,1080",
                        f"--screenshot={png}", f"file://{html}"],
                       check=True, capture_output=True)
        os.remove(html)
        print(png)
    write_copy_doc()


if __name__ == "__main__":
    main()
