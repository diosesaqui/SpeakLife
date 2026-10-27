"""Four quiet-time statics: build the relationship with Jesus by setting time aside for His Word.

Each ad runs a different Copy Vault formula (Third Door, Confession, Gut Check, Invite) and a
different look, so the test can tell whether the angle or the packaging is doing the work.
Copy lives in 2026-10-24-quiet-time/QUIET_TIME_AD_COPY.md.

Run: python3 docs/creative/statics/render_quiettime_2026_10_24.py
"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "2026-10-24-quiet-time")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BASE = """<!doctype html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:-apple-system,'SF Pro Display',Helvetica,sans-serif;-webkit-font-smoothing:antialiased;position:relative}
.foot{position:absolute;bottom:38px;left:0;right:0;text-align:center;font-size:20px;letter-spacing:8px;font-weight:600}
%s</style></head><body>%s</body></html>"""

ADS = {}

# 1. THIRD DOOR. iPhone Notes screenshot: the three-step quiet time that a friend would save.
ADS["01-thirddoor-notes"] = ("""
body{background:#fff;color:#1c1c1e}
.bar{height:70px;display:flex;justify-content:space-between;align-items:center;padding:0 56px;font-size:28px;font-weight:600}
.nav{height:90px;display:flex;align-items:center;justify-content:space-between;padding:0 44px;color:#e0a100;font-size:32px}
.wrap{padding:0 64px}
.date{color:#8e8e93;font-size:26px;text-align:center;margin:10px 0 34px}
h1{font-size:56px;font-weight:700;line-height:1.12;margin-bottom:34px}
.s{font-size:38px;line-height:1.32;margin-bottom:26px}
.s b{font-weight:700}
.n{color:#e0a100;font-weight:700;margin-right:8px}
.ref{color:#e0a100;font-weight:600;font-size:30px}
.foot{color:#c7c7cc}
""", """
<div class="bar"><span>6:04</span><span>&#9679;&#9679;&#9679;</span></div>
<div class="nav"><span>&lsaquo; Notes</span><span>&#8943;</span></div>
<div class="wrap">
<div class="date">Sunday, 6:04 AM</div>
<h1>how I finally got to know Jesus, not just facts about Him</h1>
<div class="s"><span class="n">1.</span><b>same time, same chair.</b> He went to a quiet place before daylight. <span class="ref">Mark 1:35</span></div>
<div class="s"><span class="n">2.</span><b>read less, slower.</b> one passage. ask: what does this show me about Him?</div>
<div class="s"><span class="n">3.</span><b>say one line back to Him out loud.</b> that's where it stops being homework.</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 2. CONFESSION. Cream editorial serif, founder voice.
ADS["02-confession-editorial"] = ("""
body{background:#f4ece0;color:#2b2420;font-family:Georgia,'Times New Roman',serif}
.wrap{position:absolute;left:96px;right:96px;top:250px}
.k{font-family:-apple-system,Helvetica,sans-serif;font-size:22px;letter-spacing:5px;font-weight:700;color:#9a6b2f;margin-bottom:46px}
.big{font-size:74px;line-height:1.14;margin-bottom:28px}
.big i{color:#9a6b2f}
.rule{width:90px;height:3px;background:#9a6b2f;margin:44px 0}
.v{font-size:40px;line-height:1.35;font-style:italic}
.r{font-family:-apple-system,Helvetica,sans-serif;font-size:26px;font-weight:700;color:#9a6b2f;margin-top:22px}
.foot{color:#b9a88f}
""", """
<div class="wrap">
<div class="k">AN HONEST ONE</div>
<div class="big">I knew a lot <i>about</i> Jesus.<br>I didn&rsquo;t really know Him.</div>
<div class="rule"></div>
<div class="v">&ldquo;Teach me your ways so I may know you.&rdquo;</div>
<div class="r">Exodus 33:13</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 3. GUT CHECK. The organic navy text card (static-ads Style B), mixed weight, nothing else.
ADS["03-gutcheck-navy"] = ("""
body{background:#121630;color:#fff;display:flex;align-items:center;justify-content:center}
.t{width:860px;text-align:center;font-size:60px;line-height:1.42;font-weight:400}
.t b{font-weight:700}
.foot{color:#50556b;font-size:20px}
""", """
<div class="t">When was the last time you sat with Jesus and <b>didn&rsquo;t ask Him for anything?</b></div>
<div class="foot">SPEAKLIFE</div>
""")

# 4. INVITE. iOS Focus mode card: the phone is set aside for Him.
ADS["04-invite-focus"] = ("""
body{background:linear-gradient(180deg,#1b1f3a 0%,#2e2346 55%,#5a3a4a 100%);color:#fff}
.time{position:absolute;top:110px;left:0;right:0;text-align:center;font-size:190px;font-weight:200;letter-spacing:-4px}
.day{position:absolute;top:80px;left:0;right:0;text-align:center;font-size:32px;font-weight:600;opacity:.9}
.card{position:absolute;left:110px;right:110px;top:430px;background:rgba(255,255,255,.14);border-radius:44px;padding:44px 48px}
.row{display:flex;align-items:center;gap:26px}
.ico{width:84px;height:84px;border-radius:24px;background:#f2b84b;display:flex;align-items:center;justify-content:center;font-size:46px}
.name{font-size:44px;font-weight:700}
.on{font-size:28px;opacity:.75;margin-top:4px}
.line{height:1px;background:rgba(255,255,255,.2);margin:34px 0}
.v{font-size:36px;line-height:1.35;font-weight:500}
.r{font-size:26px;font-weight:700;color:#f2b84b;margin-top:14px}
.foot{color:rgba(255,255,255,.45)}
""", """
<div class="day">Monday, October 26</div>
<div class="time">6:00</div>
<div class="card">
<div class="row"><div class="ico">&#9749;</div><div><div class="name">Time with Jesus</div><div class="on">Focus on &middot; everything else can wait</div></div></div>
<div class="line"></div>
<div class="v">&ldquo;Come near to God and he will come near to you.&rdquo;</div>
<div class="r">James 4:8</div>
</div>
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
