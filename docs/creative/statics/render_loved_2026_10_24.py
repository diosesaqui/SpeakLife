"""Four 'radically loved by Jesus' statics.

Each ad runs a different Copy Vault formula (Revival Reel, Zoom In, Menu, Triple Threat) and a
look that differs from the quiet-time pack, so the two batches can be read apart.
Copy lives in 2026-10-24-loved/LOVED_AD_COPY.md.

Run: python3 docs/creative/statics/render_loved_2026_10_24.py
"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "2026-10-24-loved")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BASE = """<!doctype html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:-apple-system,'SF Pro Display',Helvetica,sans-serif;-webkit-font-smoothing:antialiased;position:relative}
.foot{position:absolute;bottom:38px;left:0;right:0;text-align:center;font-size:20px;letter-spacing:8px;font-weight:600}
%s</style></head><body>%s</body></html>"""

ADS = {}

# 5. REVIVAL REEL. Warm dawn gradient, the verse as the dream.
ADS["05-revivalreel-dawn"] = ("""
body{background:linear-gradient(180deg,#2a1d3a 0%,#7a3f4f 45%,#e08a5a 78%,#f6c27a 100%);color:#fff;text-align:center}
.sun{position:absolute;left:340px;top:760px;width:400px;height:400px;border-radius:50%;background:radial-gradient(circle,rgba(255,236,190,.95) 0%,rgba(255,214,150,.4) 45%,rgba(255,214,150,0) 70%)}
.wrap{position:absolute;left:100px;right:100px;top:210px}
.k{font-size:24px;letter-spacing:6px;font-weight:700;opacity:.8;margin-bottom:40px}
.big{font-size:88px;font-weight:800;line-height:1.06;letter-spacing:-1px}
.sub{font-size:40px;line-height:1.35;margin-top:34px;font-weight:500;opacity:.95}
.r{font-size:26px;font-weight:700;margin-top:26px;color:#ffe2a8}
.foot{color:rgba(60,30,20,.55)}
""", """
<div class="sun"></div>
<div class="wrap">
<div class="k">HOW HE FEELS ABOUT YOU</div>
<div class="big">He takes great delight in you.</div>
<div class="sub">&ldquo;In his love he will no longer rebuke you, but will rejoice over you with singing.&rdquo;</div>
<div class="r">Zephaniah 3:17</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 6. ZOOM IN. Black poster, one word.
ADS["06-zoomin-heran"] = ("""
body{background:#0b0b0c;color:#fff}
.wrap{position:absolute;left:96px;right:96px;top:170px}
.big{font-size:230px;font-weight:900;letter-spacing:-8px;line-height:.95}
.bar{width:440px;height:16px;background:#d6332b;margin:18px 0 60px}
.v{font-size:40px;line-height:1.36;color:#e8e8e8}
.v b{color:#fff}
.r{font-size:26px;font-weight:700;color:#d6332b;margin-top:22px;letter-spacing:1px}
.foot{color:#4a4a4f}
""", """
<div class="wrap">
<div class="big">HE RAN.</div>
<div class="bar"></div>
<div class="v">&ldquo;While he was still a long way off, his father saw him&hellip; <b>he ran to his son, threw his arms around him and kissed him.</b>&rdquo;</div>
<div class="r">LUKE 15:20</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 7. MENU. Apple Notes, dark mode: the list Romans 8 answers.
ADS["07-menu-notes-dark"] = ("""
body{background:#1c1c1e;color:#fff}
.bar{height:70px;display:flex;justify-content:space-between;align-items:center;padding:0 56px;font-size:28px;font-weight:600}
.nav{height:90px;display:flex;align-items:center;justify-content:space-between;padding:0 44px;color:#ffc30b;font-size:32px}
.wrap{padding:0 64px}
.date{color:#8e8e93;font-size:26px;text-align:center;margin:10px 0 34px}
h1{font-size:54px;font-weight:700;line-height:1.14;margin-bottom:30px}
.i{font-size:40px;line-height:1.5;color:#e5e5ea}
.i:before{content:"\\2014  ";color:#ffc30b}
.ref{margin-top:30px;font-size:34px;color:#ffc30b;font-weight:600}
.foot{color:#48484a}
""", """
<div class="bar"><span>11:12</span><span>&#9679;&#9679;&#9679;</span></div>
<div class="nav"><span>&lsaquo; Notes</span><span>&#8943;</span></div>
<div class="wrap">
<div class="date">Thursday, 11:12 PM</div>
<h1>things that can&rsquo;t separate me from His love</h1>
<div class="i">my worst day</div>
<div class="i">the prayers I skipped</div>
<div class="i">the days I don&rsquo;t feel it</div>
<div class="i">who I was before I knew Him</div>
<div class="i">whatever tomorrow brings</div>
<div class="ref">Romans 8:38&ndash;39</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 8. TRIPLE THREAT. White editorial, heavy type, one red word.
ADS["08-triplethreat-still"] = ("""
body{background:#fbfaf7;color:#111}
.wrap{position:absolute;left:96px;right:96px;top:220px}
.big{font-size:96px;font-weight:800;line-height:1.08;letter-spacing:-2px}
.big span{color:#c8281f;text-decoration:underline;text-decoration-thickness:10px;text-underline-offset:14px}
.r{font-size:28px;font-weight:700;color:#c8281f;margin-top:44px;letter-spacing:1px}
.s{font-size:34px;color:#555;margin-top:18px}
.foot{color:#c9c6bf}
""", """
<div class="wrap">
<div class="big">&ldquo;While we were <span>still</span> sinners, Christ died for us.&rdquo;</div>
<div class="r">ROMANS 5:8</div>
<div class="s">Not after you cleaned up. Still.</div>
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
