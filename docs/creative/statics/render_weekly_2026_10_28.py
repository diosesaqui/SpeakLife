"""Weekly breeds, 2026-10-28. Six statics from two parents, each changing ONE thing.

Parent 1, "demo ugc" (video "Scripture you speak, not read"): $16.62 per trial over 14 days,
the only ad that cleared the scale bar this week. It shows the product doing the work
("type the thought, get the verse"). Breeds: static visual, 3 a.m. hook, health thought.

Parent 2, "One less scroll" (video SL-SCROLL-01): $14.16 per trial on $42, best live watch ad.
Breeds: static lockscreen visual, "first words" hook, Promises frame.

Run: python3 docs/creative/statics/render_weekly_2026_10_28.py
"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "2026-10-28-weekly")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BASE = """<!doctype html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:-apple-system,'SF Pro Display',Helvetica,sans-serif;-webkit-font-smoothing:antialiased}
.foot{position:absolute;bottom:38px;left:0;right:0;text-align:center;font-size:20px;letter-spacing:8px;font-weight:600}
%s</style></head><body>%s</body></html>"""

# Shared "app" look for the three demo breeds: a typed thought, then the verse card.
APP_CSS = """
.lab{font-size:24px;letter-spacing:5px;font-weight:700;margin-bottom:22px}
.in{border-radius:34px;padding:34px 40px;font-size:44px;line-height:1.25}
.arrow{text-align:center;font-size:44px;margin:26px 0}
.card{border-radius:34px;padding:40px 44px}
.v{font-size:48px;font-weight:700;line-height:1.22}
.r{font-size:30px;font-weight:600;margin-top:18px}
.say{font-size:30px;margin-top:26px;font-weight:600;letter-spacing:1px}
"""

ADS = {}

# A. Parent 1, change = visual style (video demo -> static app card). Mind thought, ob=renewal.
ADS["A-demo-static-renewal"] = (APP_CSS + """
body{background:#0f1a2e;color:#fff}
.wrap{position:absolute;top:96px;left:84px;right:84px}
h1{font-size:64px;font-weight:800;line-height:1.08;margin-bottom:52px}
.lab{color:#8fa3c7}
.in{background:#1d2b47;color:#dfe6f3}
.arrow{color:#f2c46d}
.card{background:#fff;color:#0f1a2e}
.r{color:#b07a1c}
.say{color:#5a6b8a}
.foot{color:#4a5a7a}
""", """
<div class="wrap">
<h1>Type the thought.<br>Get the verse. Say it.</h1>
<div class="lab">THE THOUGHT</div>
<div class="in">I keep replaying what I said today.</div>
<div class="arrow">&darr;</div>
<div class="card">
<div class="v">&ldquo;We take captive every thought to make it obedient to Christ.&rdquo;</div>
<div class="r">2 Corinthians 10:5</div>
<div class="say">SAY IT OUT LOUD</div>
</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# B. Parent 1, change = hook (3 a.m. moment up front). ob=anxiety.
ADS["B-demo-3am-anxiety"] = (APP_CSS + """
body{background:#05070d;color:#fff}
.wrap{position:absolute;top:80px;left:84px;right:84px}
.t{font-size:150px;font-weight:200;letter-spacing:-4px;line-height:1}
.sub{font-size:44px;font-weight:700;margin:20px 0 48px;color:#cdd3df}
.lab{color:#6f7a90}
.in{background:#161b27;color:#cdd3df}
.arrow{color:#9ab4ff}
.card{background:#1c2540;color:#fff}
.r{color:#9ab4ff}
.say{color:#9aa3b8}
.foot{color:#3a4256}
""", """
<div class="wrap">
<div class="t">3:12 AM</div>
<div class="sub">The thought won't stop. The verse is already waiting.</div>
<div class="in">what if tomorrow goes wrong?</div>
<div class="arrow">&darr;</div>
<div class="card">
<div class="v">&ldquo;You will keep in perfect peace those whose minds are steadfast.&rdquo;</div>
<div class="r">Isaiah 26:3</div>
</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# C. Parent 1, change = pain (health what-if, the PAIN-06 storm). ob=healing.
ADS["C-demo-health-healing"] = (APP_CSS + """
body{background:#fbf8f2;color:#1f2a24}
.wrap{position:absolute;top:96px;left:84px;right:84px}
h1{font-size:62px;font-weight:800;line-height:1.08;margin-bottom:50px}
.lab{color:#7a8a7f}
.in{background:#e9efe9;color:#2f3d34}
.arrow{color:#2e7d5b}
.card{background:#1f3d30;color:#fff}
.r{color:#9fd8b8}
.say{color:#c7e3d3}
.foot{color:#a9b5ac}
""", """
<div class="wrap">
<h1>For the what-if you<br>type at midnight.</h1>
<div class="lab">THE THOUGHT</div>
<div class="in">what if the results come back bad?</div>
<div class="arrow">&darr;</div>
<div class="card">
<div class="v">&ldquo;They will have no fear of bad news; their hearts are steadfast, trusting in the LORD.&rdquo;</div>
<div class="r">Psalm 112:7</div>
<div class="say">SAY IT OUT LOUD</div>
</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# D. Parent 2, change = visual style (video -> static lockscreen). ob=command.
ADS["D-scroll-lockscreen-command"] = ("""
body{background:linear-gradient(180deg,#1b3a5c 0%,#3f6f8f 55%,#d9a97a 100%);color:#fff;text-align:center}
.d{font-size:36px;font-weight:600;margin-top:80px;opacity:.9}
.c{font-size:200px;font-weight:200;line-height:1;letter-spacing:-4px}
.n{position:absolute;left:70px;right:70px;top:400px;background:rgba(255,255,255,.22);border-radius:38px;padding:34px 40px;text-align:left;backdrop-filter:blur(10px)}
.h{display:flex;justify-content:space-between;font-size:27px;opacity:.85;margin-bottom:10px}
.n b{font-size:38px;display:block;margin-bottom:8px}
.n p{font-size:38px;line-height:1.28}
.big{position:absolute;left:70px;right:70px;top:760px;font-size:56px;font-weight:800;line-height:1.12;text-shadow:0 2px 14px rgba(0,0,0,.25)}
.foot{color:rgba(255,255,255,.7)}
""", """
<div class="d">Wednesday, October 28</div>
<div class="c">6:42</div>
<div class="n">
<div class="h"><span>SPEAKLIFE</span><span>now</span></div>
<b>Before you scroll</b>
<p>&ldquo;Man shall not live on bread alone, but on every word that comes from the mouth of God.&rdquo; Matthew 4:4</p>
</div>
<div class="big">One less scroll.<br>One more moment with God.</div>
<div class="foot">SPEAKLIFE</div>
""")

# E. Parent 2, change = hook ("first words"). ob=command.
ADS["E-scroll-firstwords-command"] = ("""
body{background:#fff;color:#111}
.w{position:absolute;top:110px;left:80px;right:80px;font-size:118px;font-weight:900;letter-spacing:-4px;line-height:.98}
.w span{color:#c8102e}
.v{position:absolute;top:640px;left:84px;right:84px;font-size:44px;line-height:1.28;font-weight:500;color:#333}
.r{position:absolute;top:842px;left:84px;font-size:30px;font-weight:700;letter-spacing:3px;color:#c8102e}
.foot{color:#bbb}
""", """
<div class="w">Your first words today.<br><span>Make them His.</span></div>
<div class="v">&ldquo;In the morning, LORD, you hear my voice.&rdquo;</div>
<div class="r">PSALM 5:3</div>
<div class="foot">SPEAKLIFE</div>
""")

# F. Parent 2, change = copy formula / frame (Promises frame). ob=promises.
ADS["F-scroll-promises-promises"] = ("""
body{background:#f3ece0;color:#1f1a14;font-family:Georgia,'Times New Roman',serif}
.k{position:absolute;top:100px;left:96px;font-family:-apple-system,sans-serif;font-size:24px;letter-spacing:6px;color:#9b7b4a;font-weight:700}
.v{position:absolute;top:180px;left:96px;right:96px;font-size:76px;line-height:1.14}
.r{position:absolute;top:560px;left:96px;font-family:-apple-system,sans-serif;font-size:32px;color:#9b7b4a;font-weight:600}
.s{position:absolute;top:680px;left:96px;right:96px;font-family:-apple-system,sans-serif;font-size:50px;font-weight:700;line-height:1.18;color:#1f1a14}
.foot{color:#b8a98f;font-family:-apple-system,sans-serif}
""", """
<div class="k">BEFORE THE PHONE</div>
<div class="v">&ldquo;No matter how many promises God has made, they are &lsquo;Yes&rsquo; in Christ.&rdquo;</div>
<div class="r">2 Corinthians 1:20</div>
<div class="s">Say one promise out loud before you scroll.</div>
<div class="foot">SPEAKLIFE</div>
""")


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, (css, body) in ADS.items():
        html = os.path.join(OUT, f"{name}.html")
        png = os.path.join(OUT, f"{name}.png")
        with open(html, "w") as fh:
            fh.write(BASE % (css, body))
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                        "--force-device-scale-factor=1", "--window-size=1080,1080",
                        f"--screenshot={png}", f"file://{html}"],
                       check=True, capture_output=True)
        os.remove(html)
        print(png)


if __name__ == "__main__":
    main()
