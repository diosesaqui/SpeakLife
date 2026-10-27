"""Grace pack: 8 statics, 2 per topic.

Topics: a promise for your situation (PR), free from condemnation (NC), new identity in Christ
(ID), grace over your past (GR). Copy is from the Copy Vault (faith-ad-formulas) and lives in
this file next to its image, so the copy doc and the Meta specs come from one source.

Run: python3 docs/creative/statics/render_grace_pack_2026_10_24.py
Writes PNGs + GRACE_PACK_AD_COPY.md + specs.json (needs image hashes) to 2026-10-24-grace-pack/.
"""
import json
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "2026-10-24-grace-pack")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LINK = "http://itunes.apple.com/app/id1617492998"
PAGE_ID = "104027662277976"

BASE = """<!doctype html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:-apple-system,'SF Pro Display',Helvetica,sans-serif;-webkit-font-smoothing:antialiased;position:relative}
.foot{position:absolute;bottom:38px;left:0;right:0;text-align:center;font-size:20px;letter-spacing:8px;font-weight:600}
%s</style></head><body>%s</body></html>"""

NOTES_LIGHT = """
body{background:#fff;color:#1c1c1e}
.bar{height:70px;display:flex;justify-content:space-between;align-items:center;padding:0 56px;font-size:28px;font-weight:600}
.nav{height:90px;display:flex;align-items:center;justify-content:space-between;padding:0 44px;color:#e0a100;font-size:32px}
.wrap{padding:0 64px}
.date{color:#8e8e93;font-size:26px;text-align:center;margin:6px 0 30px}
h1{font-size:54px;font-weight:700;line-height:1.12;margin-bottom:28px}
.q{font-size:32px;color:#8e8e93;margin-top:22px}
.a{font-size:36px;line-height:1.3;margin-top:4px;font-weight:600}
.ref{color:#e0a100;font-weight:600;font-size:28px}
.foot{color:#c7c7cc}
"""

ADS = []

# ---------------------------------------------------------------- PROMISE (PR)
ADS.append(dict(
    key="PR-09", slug="menu", ob="promises", topic="A promise for your situation", formula="Menu",
    visual="iPhone Notes, a promise per situation",
    css=NOTES_LIGHT,
    body="""
<div class="bar"><span>7:02</span><span>&#9679;&#9679;&#9679;</span></div>
<div class="nav"><span>&lsaquo; Notes</span><span>&#8943;</span></div>
<div class="wrap">
<div class="date">Monday, 7:02 AM</div>
<h1>a promise for whatever I&rsquo;m facing</h1>
<div class="q">the bills</div>
<div class="a">&ldquo;My God will meet all your needs.&rdquo; <span class="ref">Philippians 4:19</span></div>
<div class="q">my body</div>
<div class="a">&ldquo;I will restore you to health.&rdquo; <span class="ref">Jeremiah 30:17</span></div>
<div class="q">my mind at 3am</div>
<div class="a">&ldquo;You will keep in perfect peace&hellip;&rdquo; <span class="ref">Isaiah 26:3</span></div>
<div class="q">my kids</div>
<div class="a">&ldquo;Great will be their peace.&rdquo; <span class="ref">Isaiah 54:13</span></div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""Looking for what God actually promised about the thing you're facing?

Most of us know He keeps His promises. Fewer of us know which promise is ours this week.

Here's a short list worth saving:
• The bills: "My God will meet all your needs according to the riches of his glory in Christ Jesus." Philippians 4:19
• Your body: "I will restore you to health and heal your wounds." Jeremiah 30:17
• Your mind at 3am: "You will keep in perfect peace those whose minds are steadfast, because they trust in you." Isaiah 26:3
• Your kids: "All your children will be taught by the LORD, and great will be their peace." Isaiah 54:13

Pick the one that's yours. Say it out loud every morning, before the day argues with it.

SpeakLife builds this for you. Tell it what you're facing and it hands you the promise, ready to speak.

Why people keep it:
✓ Rooted: every declaration comes with its verse
✓ Personal: built around what you name
✓ Quick: a few minutes a morning

Every promise He made is still yes. Save this 👇""",
    short="""save this. a promise for whatever you're facing:
bills → Philippians 4:19. body → Jeremiah 30:17. mind → Isaiah 26:3. kids → Isaiah 54:13.
SpeakLife hands you yours every morning 👇""",
    headline="A promise for your situation", description="Find it. Say it. Every morning.",
))

ADS.append(dict(
    key="PR-10", slug="zoomin", ob="promises", topic="A promise for your situation", formula="Zoom In",
    visual="black poster, \"YES.\"",
    css="""
body{background:#0b0b0c;color:#fff}
.wrap{position:absolute;left:96px;right:96px;top:170px}
.big{font-size:300px;font-weight:900;letter-spacing:-10px;line-height:.9}
.bar{width:360px;height:16px;background:#e0a100;margin:26px 0 60px}
.v{font-size:44px;line-height:1.34;color:#e8e8e8}
.v b{color:#fff}
.r{font-size:26px;font-weight:700;color:#e0a100;margin-top:22px;letter-spacing:1px}
.foot{color:#4a4a4f}
""",
    body="""
<div class="wrap">
<div class="big">YES.</div>
<div class="bar"></div>
<div class="v">&ldquo;For no matter how many promises God has made, <b>they are &lsquo;Yes&rsquo; in Christ.</b>&rdquo;</div>
<div class="r">2 CORINTHIANS 1:20</div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""One word sums up every promise God ever made: yes.

"For no matter how many promises God has made, they are 'Yes' in Christ." 2 Corinthians 1:20

Not maybe.
Not someday, if you're good enough.
Yes, in Christ. Which means yes for you.

The only question left is whether you'll stand on it out loud.

SpeakLife: the promise for your situation, ready to speak every morning. A few minutes. Rooted in a verse.

Start speaking yes 👇""",
    short="""not maybe. not someday. yes. (2 Corinthians 1:20)
SpeakLife puts the promise for your situation in your mouth every morning 👇""",
    headline="Every promise is yes", description="The promise for your situation",
))

# ---------------------------------------------------------------- NO CONDEMNATION (NC)
ADS.append(dict(
    key="NC-11", slug="thirddoor", ob="renewal", topic="Free from condemnation", formula="Third Door",
    visual="navy organic text card",
    css="""
body{background:#121630;color:#fff;display:flex;align-items:center;justify-content:center;flex-direction:column}
.t{width:860px;text-align:center;font-size:64px;line-height:1.38;font-weight:400}
.t b{font-weight:700}
.r{margin-top:40px;font-size:28px;font-weight:600;letter-spacing:2px;color:#8f96c4}
.foot{color:#50556b}
""",
    body="""
<div class="t">There is now <b>no condemnation</b> for those who are in Christ Jesus.</div>
<div class="r">ROMANS 8:1</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""What do you do when an old mistake replays in your head at night?

You could replay it again and try to feel sorry enough.
You could try to make up for it by being extra good tomorrow.

Or you could do what Jesus did in the wilderness. He didn't argue with the accusation in His head. He answered it out loud: "It is written."

Here's what's written about you: "Therefore, there is now no condemnation for those who are in Christ Jesus." Romans 8:1

• Not less condemnation. None.
• Not once you've earned it back. Now.
• Not for the good ones. For those in Christ.

Say it out loud the next time the replay starts. The voice that condemns you is not His.

SpeakLife gives you the verse the moment the thought shows up, ready to speak.

Try it free tonight 👇""",
    short="""the replay isn't God's voice.
"There is now no condemnation for those who are in Christ Jesus." Romans 8:1
say it out loud. SpeakLife hands you the verse when the thought shows up 👇""",
    headline="No condemnation. None.", description="A verse for the replay",
))

ADS.append(dict(
    key="NC-12", slug="gutcheck", ob="renewal", topic="Free from condemnation", formula="Gut Check",
    visual="cream editorial serif",
    css="""
body{background:#f4ece0;color:#2b2420;font-family:Georgia,'Times New Roman',serif}
.wrap{position:absolute;left:96px;right:96px;top:200px}
.big{font-size:76px;line-height:1.14}
.big i{color:#9a6b2f}
.ans{font-family:-apple-system,Helvetica,sans-serif;font-size:44px;font-weight:800;color:#9a6b2f;margin-top:30px}
.rule{width:90px;height:3px;background:#9a6b2f;margin:44px 0}
.v{font-size:38px;line-height:1.38;font-style:italic}
.r{font-family:-apple-system,Helvetica,sans-serif;font-size:26px;font-weight:700;color:#9a6b2f;margin-top:20px}
.foot{color:#b9a88f}
""",
    body="""
<div class="wrap">
<div class="big">How long has He been holding it <i>against</i> you?</div>
<div class="ans">He hasn&rsquo;t.</div>
<div class="rule"></div>
<div class="v">&ldquo;As far as the east is from the west, so far has he removed our transgressions from us.&rdquo;</div>
<div class="r">Psalm 103:12</div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""How long do you think God has been holding that one thing against you?

He hasn't.

"As far as the east is from the west, so far has he removed our transgressions from us." Psalm 103:12

SpeakLife is built for the moment you remember it again:
✓ A verse ready to speak back, not a feeling to argue with
✓ Declarations about who you are in Christ, said out loud every morning
✓ Bible Chat for the question you'd never ask in church: am I really forgiven?

You're not on probation. You're His.

Start your morning forgiven 👇""",
    short="""how long has He been holding it against you?
He hasn't. (Psalm 103:12)
SpeakLife reminds you every morning 👇""",
    headline="He's not holding it against you", description="Psalm 103:12, out loud daily",
))

# ---------------------------------------------------------------- NEW IDENTITY (ID)
ADS.append(dict(
    key="ID-13", slug="revivalreel", ob="renewal", topic="New identity in Christ", formula="Revival Reel",
    visual="white editorial, red \"new\"",
    css="""
body{background:#fbfaf7;color:#111}
.wrap{position:absolute;left:96px;right:96px;top:230px}
.big{font-size:104px;font-weight:800;line-height:1.06;letter-spacing:-2px}
.big span{color:#c8281f;text-decoration:underline;text-decoration-thickness:10px;text-underline-offset:14px}
.r{font-size:28px;font-weight:700;color:#c8281f;margin-top:46px;letter-spacing:1px}
.s{font-size:36px;color:#555;margin-top:18px}
.foot{color:#c9c6bf}
""",
    body="""
<div class="wrap">
<div class="big">&ldquo;The old has gone, the <span>new</span> is here!&rdquo;</div>
<div class="r">2 CORINTHIANS 5:17</div>
<div class="s">You&rsquo;re not who you were.</div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""For the mornings the old version of you speaks first.

Imagine waking up and the first voice you hear tells you who you are now, not who you used to be.

The truth is, that's already settled. "If anyone is in Christ, the new creation has come: The old has gone, the new is here!" 2 Corinthians 5:17

You can say it out loud every morning until it sounds more like you than the old voice does.

SpeakLife gives you:
✓ Declarations about who you are in Christ, each rooted in a verse
✓ Audio to hear them on the drive, on repeat
✓ A few minutes a morning, no blank page

This isn't self-talk. It's what He already said about you.

Start as the new you tomorrow 👇""",
    short="""the old version of you doesn't get the first word.
"The old has gone, the new is here!" 2 Corinthians 5:17
SpeakLife puts it in your mouth every morning 👇""",
    headline="You're not who you were", description="Who you are in Christ, daily",
))

ADS.append(dict(
    key="ID-14", slug="featurebox", ob="renewal", topic="New identity in Christ", formula="Feature Box",
    visual="split panel, old voice vs what He says",
    css="""
body{background:#fff}
.l{position:absolute;left:0;top:0;bottom:0;width:470px;background:#17171a;color:#fff;padding:120px 52px}
.rt{position:absolute;left:470px;right:0;top:0;bottom:0;background:#f4ece0;color:#2b2420;padding:120px 56px}
.k{font-size:22px;letter-spacing:5px;font-weight:700;margin-bottom:44px}
.l .k{color:#8e8e93}
.rt .k{color:#9a6b2f}
.x{font-size:46px;line-height:1.6;color:#8e8e93;text-decoration:line-through;text-decoration-color:#d6332b;text-decoration-thickness:4px}
.y{font-size:46px;font-weight:800;line-height:1.1;margin-bottom:6px}
.yr{font-size:24px;color:#9a6b2f;font-weight:700;margin-bottom:30px}
.foot{color:#b9a88f;left:470px}
""",
    body="""
<div class="l">
<div class="k">THE OLD VOICE</div>
<div class="x">not enough</div>
<div class="x">too late</div>
<div class="x">always like this</div>
<div class="x">who you were</div>
</div>
<div class="rt">
<div class="k">WHAT HE SAYS</div>
<div class="y">chosen</div><div class="yr">1 Peter 2:9</div>
<div class="y">forgiven</div><div class="yr">Ephesians 1:7</div>
<div class="y">His handiwork</div><div class="yr">Ephesians 2:10</div>
<div class="y">new</div><div class="yr">2 Corinthians 5:17</div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""Tired of the voice in your head deciding who you are before breakfast?

SpeakLife puts what God says about you in your mouth every morning.

• Morning: "You are a chosen people… God's special possession." 1 Peter 2:9
• When the old voice starts: "We are God's handiwork, created in Christ Jesus." Ephesians 2:10
• At night: audio declarations of who you are, playing as you fall asleep

A few minutes a day. Every line comes from a verse. You never have to find the words.

Start free 👇""",
    short="""not enough. too late. always like this. that's the old voice.
He says chosen (1 Peter 2:9).
SpeakLife helps you say it back every morning 👇""",
    headline="What He says about you", description="Chosen. Forgiven. New.",
))

# ---------------------------------------------------------------- GRACE OVER THE PAST (GR)
ADS.append(dict(
    key="GR-15", slug="confession", ob="renewal", topic="Grace over your past", formula="Confession",
    visual="iMessage thread",
    css="""
body{background:#fff;color:#000}
.top{height:200px;background:#f6f6f6;border-bottom:1px solid #e5e5ea;display:flex;flex-direction:column;align-items:center;justify-content:center}
.av{width:84px;height:84px;border-radius:50%;background:linear-gradient(#a3a8b8,#7d8294);color:#fff;font-size:40px;display:flex;align-items:center;justify-content:center;font-weight:600}
.nm{font-size:24px;margin-top:10px}
.ts{text-align:center;color:#8e8e93;font-size:22px;margin:30px 0 20px}
.msgs{padding:0 40px;display:flex;flex-direction:column;gap:16px}
.m{max-width:760px;padding:22px 30px;border-radius:40px;font-size:34px;line-height:1.3}
.g{background:#e9e9eb;align-self:flex-start}
.b{background:#0b84fe;color:#fff;align-self:flex-end}
.foot{color:#c7c7cc}
""",
    body="""
<div class="top"><div class="av">J</div><div class="nm">Jess</div></div>
<div class="ts">Today 10:41 PM</div>
<div class="msgs">
<div class="m g">do you think God is still disappointed about what I did back then?</div>
<div class="m b">no. read this</div>
<div class="m b">&ldquo;Where sin increased, grace increased all the more.&rdquo; Romans 5:20</div>
<div class="m g">all the more. ok. saying it out loud right now</div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""Is it still grace if I keep bringing up the thing He already forgave?

I was so tired of carrying a past that God had already let go of.

Every time it came back, I'd apologize for it again. Like the cross needed my help.

Then I found the verse that ended that: "Where sin increased, grace increased all the more." Romans 5:20

Not grace that barely covers it. Grace that's bigger than it.

So now I don't argue with the memory. I answer it out loud with what He said.

That's what SpeakLife is for. Every morning, a line of His Word about His grace, ready to speak before the past gets a word in.

Come start your mornings with us 👇""",
    short="""your past isn't bigger than His grace.
"Where sin increased, grace increased all the more." Romans 5:20
SpeakLife puts it in your mouth every morning 👇""",
    headline="Grace bigger than your past", description="Romans 5:20, out loud daily",
))

ADS.append(dict(
    key="GR-16", slug="straightshot", ob="renewal", topic="Grace over your past", formula="Straight Shot",
    visual="warm dawn gradient",
    css="""
body{background:linear-gradient(180deg,#1f2a44 0%,#5b4a6b 42%,#d9875f 78%,#f7c77e 100%);color:#fff;text-align:center}
.sun{position:absolute;left:340px;top:780px;width:400px;height:400px;border-radius:50%;background:radial-gradient(circle,rgba(255,238,195,.95) 0%,rgba(255,214,150,.4) 45%,rgba(255,214,150,0) 70%)}
.wrap{position:absolute;left:100px;right:100px;top:200px}
.k{font-size:24px;letter-spacing:6px;font-weight:700;opacity:.8;margin-bottom:40px}
.big{font-size:96px;font-weight:800;line-height:1.04;letter-spacing:-1px}
.sub{font-size:40px;line-height:1.35;margin-top:34px;font-weight:500}
.r{font-size:26px;font-weight:700;margin-top:26px;color:#ffe2a8}
.foot{color:rgba(60,30,20,.55)}
""",
    body="""
<div class="sun"></div>
<div class="wrap">
<div class="k">EVERY SINGLE MORNING</div>
<div class="big">His mercy is new today.</div>
<div class="sub">&ldquo;His compassions never fail. They are new every morning; great is your faithfulness.&rdquo;</div>
<div class="r">Lamentations 3:22&ndash;23</div>
</div>
<div class="foot">SPEAKLIFE</div>
""",
    long="""Yesterday doesn't get to decide today.

SpeakLife: a few minutes every morning of God's Word about His grace, spoken out loud over your own life.

• Mercy that's new before you open your eyes (Lamentations 3:22-23)
• A past that's forgiven, not filed away
• A verse ready when the old memory shows up

Free to start 👇""",
    short="""yesterday doesn't get to decide today.
His mercies are new every morning (Lamentations 3:22-23).
SpeakLife helps you start there 👇""",
    headline="His mercy is new today", description="Grace for your past, every morning",
))


def name(ad, v):
    return f"{ad['key']}-{ad['slug']}-{v}-{ad['ob']}"


def write_copy_doc():
    lines = ["# Grace Pack — 2026-10-24", "",
             "Four topics, two ads each. Copy from the Copy Vault (`faith-ad-formulas`). Identity is the",
             "payoff, never the cold hook (LEARNINGS 2026-10-01: \"new identity in Christ\" ran $217 per trial).",
             "Condemnation, identity and grace land on `ob=renewal` (\"Who I am\"); promises on `ob=promises`.",
             "CTA button is Download on every ad. Generated by `render_grace_pack_2026_10_24.py`; edit copy there.",
             "", "| Ad | Topic | Formula | Visual | `ob=` |", "|---|---|---|---|---|"]
    for a in ADS:
        lines.append(f"| {a['key']} | {a['topic']} | {a['formula']} | {a['visual']} | `{a['ob']}` |")
    for a in ADS:
        lines += ["", "---", "", f"## {a['key']} · {a['topic']} · {a['formula']}", "",
                  "**Primary text (long)**"]
        lines += ["> " + l if l else ">" for l in a["long"].split("\n")]
        lines += ["", "**Primary text (short)**"]
        lines += ["> " + l if l else ">" for l in a["short"].split("\n")]
        lines += ["", f"**Headline:** {a['headline']} · **Description:** {a['description']} · **CTA:** Download"]
    open(os.path.join(OUT, "GRACE_PACK_AD_COPY.md"), "w").write("\n".join(lines) + "\n")


def write_specs(hashes):
    specs = []
    for a in ADS:
        h = hashes.get(f"{a['key'][3:]}-{a['slug']}")
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
        stem = f"{a['key'][3:]}-{a['slug']}"
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
