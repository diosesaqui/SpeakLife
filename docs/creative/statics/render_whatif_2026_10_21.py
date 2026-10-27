"""Eight what-if statics, one per strongest pain, each in a different visual style.

Breeds PAIN-06 "fever what-if" ($10.90 per trial over 14 days, the account's best). The
mechanic stays the same (the what-if, then the verse to speak back at it) and the look changes
on every ad, so the test tells us whether the navy text card is doing the work or the angle is.

Run: python3 docs/creative/statics/render_whatif_2026_10_21.py
"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "2026-10-21-whatif")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

BASE = """<!doctype html><html><head><meta charset="utf-8"><style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1080px;overflow:hidden}
body{font-family:-apple-system,'SF Pro Display',Helvetica,sans-serif;-webkit-font-smoothing:antialiased}
.foot{position:absolute;bottom:38px;left:0;right:0;text-align:center;font-size:20px;letter-spacing:8px;font-weight:600}
%s</style></head><body>%s</body></html>"""

ADS = {}

# 1. HEALTH: waiting on results. iPhone Notes screenshot.
ADS["01-health-results-notes"] = ("""
body{background:#fff;color:#1c1c1e}
.bar{height:70px;display:flex;justify-content:space-between;align-items:center;padding:0 56px;font-size:28px;font-weight:600}
.nav{height:90px;display:flex;align-items:center;justify-content:space-between;padding:0 44px;color:#e0a100;font-size:32px}
.wrap{padding:6px 64px}
.date{color:#8e8e93;font-size:26px;text-align:center;margin:20px 0 40px}
h1{font-size:58px;font-weight:700;margin-bottom:30px;line-height:1.12}
.q{font-size:38px;color:#8e8e93;margin-top:40px}
.a{font-size:42px;line-height:1.3;margin-top:10px;font-weight:500}
.a b{font-weight:700}
.ref{color:#e0a100;font-weight:600;font-size:32px}
.foot{color:#c7c7cc}
""", """
<div class="bar"><span>11:48</span><span>&#9679;&#9679;&#9679;</span></div>
<div class="nav"><span>&lsaquo; Notes</span><span>&#8943;</span></div>
<div class="wrap">
<div class="date">Tuesday, 11:48 PM</div>
<h1>what to say while I wait for the results</h1>
<div class="q">what if it's bad news?</div>
<div class="a"><b>&ldquo;They will have no fear of bad news; their hearts are steadfast, trusting in the LORD.&rdquo;</b> <span class="ref">Psalm 112:7</span></div>
<div class="q">what if they call tomorrow?</div>
<div class="a">&ldquo;He sent out his word and healed them.&rdquo; <span class="ref">Psalm 107:20</span></div>
<div class="q">what if I can't sleep tonight?</div>
<div class="a">&ldquo;In peace I will lie down and sleep.&rdquo; <span class="ref">Psalm 4:8</span></div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 2. HEALTH: pain at night. Apple Notes in dark mode (01 is light), the what-if struck through.
ADS["02-health-pain-notes"] = ("""
body{background:#1c1c1e;color:#fff}
.bar{height:70px;display:flex;justify-content:space-between;align-items:center;padding:0 56px;font-size:28px;font-weight:600}
.nav{height:90px;display:flex;align-items:center;justify-content:space-between;padding:0 44px;color:#ffc30b;font-size:32px}
.wrap{padding:6px 64px}
.date{color:#8e8e93;font-size:26px;text-align:center;margin:20px 0 40px}
h1{font-size:58px;font-weight:700;line-height:1.12;margin-bottom:44px}
.x{font-size:44px;color:#8e8e93;text-decoration:line-through;text-decoration-color:#ff453a;text-decoration-thickness:4px}
.n{font-size:38px;color:#ff9f0a;margin-top:12px}
.v{font-size:52px;font-weight:700;line-height:1.22;margin-top:48px}
.r{font-size:34px;color:#ffc30b;font-weight:600;margin-top:14px}
.s{font-size:40px;color:#d1d1d6;margin-top:48px;line-height:1.3}
.foot{color:#48484a}
""", """
<div class="bar"><span>2:41</span><span>&#9679;&#9679;&#9679;</span></div>
<div class="nav"><span>&lsaquo; Notes</span><span>&#8943;</span></div>
<div class="wrap">
<div class="date">Thursday, 2:41 AM</div>
<h1>when the pain wakes me up</h1>
<div class="x">what if this pain never leaves?</div>
<div class="n">&rarr; not mine. that's fear talking.</div>
<div class="v">&ldquo;I will restore you to health and heal your wounds.&rdquo;</div>
<div class="r">Jeremiah 30:17</div>
<div class="s">said it out loud. saying it again in the morning.</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 3. HEALTH: a child with a fever. iMessage thread.
ADS["03-health-child-imessage"] = ("""
body{background:#fff}
.top{height:190px;border-bottom:1px solid #e5e5ea;display:flex;flex-direction:column;align-items:center;justify-content:flex-end;padding-bottom:16px;background:#f9f9fb}
.av{width:92px;height:92px;border-radius:50%;background:linear-gradient(#a0a6b8,#7d8396);color:#fff;font-size:32px;font-weight:600;display:flex;align-items:center;justify-content:center}
.nm{font-size:28px;color:#1c1c1e;margin-top:8px}
.th{padding:40px 40px;display:flex;flex-direction:column;gap:22px}
.t{align-self:center;color:#8e8e93;font-size:26px;margin-bottom:8px}
.b{max-width:820px;padding:24px 34px;border-radius:44px;font-size:41px;line-height:1.28}
.in{background:#e9e9eb;color:#000;align-self:flex-start}
.out{background:#0a84ff;color:#fff;align-self:flex-end}
.out i{font-style:normal;font-weight:700}
.foot{color:#c7c7cc}
""", """
<div class="top"><div class="av">M</div><div class="nm">Mom</div></div>
<div class="th">
<div class="t">Today 2:14 AM</div>
<div class="b in">she's still burning up. what if it's something serious</div>
<div class="b out">don't google it. speak over her. Jesus did.</div>
<div class="b out"><i>&ldquo;He bent over her and rebuked the fever, and it left her.&rdquo;</i> Luke 4:39</div>
<div class="b in">ok. saying it over her right now &#128591;</div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 4. FEAR: losing the job. Lock screen at 3:07 with two notifications.
ADS["04-fear-job-lockscreen"] = ("""
body{background:radial-gradient(120% 90% at 50% 0%,#36406b 0%,#141831 55%,#090b18 100%);color:#fff;text-align:center}
.d{font-size:34px;font-weight:600;margin-top:70px;opacity:.85}
.c{font-size:210px;font-weight:200;line-height:1;margin-top:4px;letter-spacing:-4px}
.n{margin:26px 44px 0;background:rgba(255,255,255,.16);border-radius:34px;padding:24px 30px;text-align:left;backdrop-filter:blur(20px)}
.h{display:flex;justify-content:space-between;font-size:27px;opacity:.75;margin-bottom:6px}
.n b{font-size:36px;display:block;margin-bottom:6px}
.n p{font-size:35px;line-height:1.3;opacity:.95}
.g{color:#f2c46d;font-weight:600}
.foot{color:rgba(255,255,255,.35)}
""", """
<div class="d">Wednesday, October 22</div>
<div class="c">3:07</div>
<div class="n"><div class="h"><span>WORK</span><span>9h ago</span></div><b>All-hands moved to 9:00 AM</b><p>Attendance required. Agenda to follow.</p></div>
<div class="n"><div class="h"><span>SPEAKLIFE</span><span>now</span></div><b>what if I lose my job?</b><p>Speak this back: <span class="g">&ldquo;My God will meet all your needs according to the riches of his glory in Christ Jesus.&rdquo;</span> Philippians 4:19</p></div>
<div class="foot">SPEAKLIFE</div>
""")

# 5. MONEY: covering the month. Cream editorial serif.
ADS["05-money-bills-editorial"] = ("""
body{background:#f3ece0;color:#1f1a14;font-family:Georgia,'Times New Roman',serif}
.k{position:absolute;top:96px;left:96px;font-family:-apple-system,sans-serif;font-size:22px;letter-spacing:6px;color:#9b7b4a;font-weight:600}
.q{position:absolute;top:170px;left:96px;right:96px;font-style:italic;font-size:52px;color:#8c8273;line-height:1.2}
.q span{background:linear-gradient(transparent 50%,#1f1a14 50%,#1f1a14 54%,transparent 54%)}
.rule{position:absolute;top:330px;left:96px;width:120px;height:4px;background:#9b7b4a}
.v{position:absolute;top:380px;left:96px;right:96px;font-size:62px;line-height:1.18}
.r{position:absolute;top:792px;left:96px;font-family:-apple-system,sans-serif;font-size:28px;color:#9b7b4a;font-weight:600}
.s{position:absolute;top:850px;left:96px;right:96px;font-family:-apple-system,sans-serif;font-size:27px;color:#5e5446}
.foot{color:#b3a68f}
""", """
<div class="k">THE WHAT-IF</div>
<div class="q"><span>what if we can't cover it this month?</span></div>
<div class="rule"></div>
<div class="v">&ldquo;I was young and now I am old, yet I have never seen the righteous forsaken or their children begging bread.&rdquo;</div>
<div class="r">Psalm 37:25</div>
<div class="s">Say it over the bills. Out loud. Before the math does the talking.</div>
<div class="foot">SPEAKLIFE</div>
""")

# 6. FEAR: family on the road. Bold black/white/red poster.
ADS["06-fear-family-poster"] = ("""
body{background:#fff;color:#0b0b0b}
.w{position:absolute;top:80px;left:70px;font-size:205px;font-weight:900;letter-spacing:-8px;line-height:.9}
.w:after{content:"";position:absolute;left:-14px;right:-14px;top:50%;height:28px;background:#e0261b;transform:rotate(-4deg)}
.sub{position:absolute;top:320px;left:76px;right:70px;font-size:38px;font-weight:600;color:#6b6b6b}
.l{position:absolute;top:440px;left:76px;font-size:30px;font-weight:800;letter-spacing:5px;color:#e0261b}
.v{position:absolute;top:494px;left:76px;right:80px;font-size:66px;font-weight:800;line-height:1.08;letter-spacing:-1px}
.r{position:absolute;top:880px;left:76px;font-size:30px;font-weight:700;color:#e0261b}
.foot{color:#bdbdbd}
""", """
<div class="w">WHAT IF</div>
<div class="sub">something happens to them on the drive home?</div>
<div class="l">WHAT GOD SAID</div>
<div class="v">&ldquo;The LORD will watch over your coming and going both now and forevermore.&rdquo;</div>
<div class="r">Psalm 121:8</div>
<div class="foot">SPEAKLIFE</div>
""")

# 7. MIND: the 3am heart. Giant thin clock on black, step 2 in gold.
ADS["07-mind-3am-clock"] = ("""
body{background:#000;color:#fff;text-align:center}
.c{font-size:300px;font-weight:100;letter-spacing:-8px;margin-top:70px;line-height:1;color:#f5f5f5}
.t{font-size:30px;letter-spacing:7px;color:#7a7a7a;margin-top:6px;font-weight:600}
.st{text-align:left;margin:60px auto 0;width:880px;font-size:39px;line-height:1.32}
.st div{margin-bottom:20px;color:#a9a9a9}
.st div b{color:#fff}
.st .k{color:#e9b949;font-weight:700}
.v{color:#fff}
.r{color:#e9b949;font-size:31px;font-weight:600}
.foot{color:#444}
""", """
<div class="c">3:07</div>
<div class="t">THE WHAT-IF HOUR</div>
<div class="st">
<div>1. &nbsp;name it. <b>that's fear talking, not God.</b></div>
<div class="k">2. &nbsp;find what God says about it.</div>
<div>3. &nbsp;<b>say it out loud.</b> <span class="v">&ldquo;You will keep in perfect peace those whose minds are steadfast.&rdquo;</span><br><span class="r">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Isaiah 26:3</span></div>
</div>
<div class="foot">SPEAKLIFE</div>
""")

# 8. GROWING OLDER: the quiet house. Warm sunrise gradient, rounded type.
ADS["08-aging-alone-sunrise"] = ("""
body{background:linear-gradient(180deg,#fbe3c4 0%,#f6c58f 48%,#e99a6b 100%);color:#3b2416;text-align:center;font-family:'SF Pro Rounded',-apple-system,sans-serif}
.sun{position:absolute;left:50%;top:640px;width:560px;height:560px;margin-left:-280px;border-radius:50%;background:radial-gradient(#fff6e3 0%,rgba(255,240,214,.55) 45%,rgba(255,240,214,0) 70%)}
.q{position:relative;font-size:38px;color:#8a5a3c;margin-top:150px;font-weight:500}
.v{position:relative;font-size:72px;font-weight:700;line-height:1.14;margin:46px 80px 0}
.r{position:relative;font-size:30px;font-weight:600;color:#8a4a24;margin-top:38px}
.s{position:relative;font-size:30px;color:#6b4026;margin-top:46px}
.foot{color:rgba(59,36,22,.45)}
""", """
<div class="sun"></div>
<div class="q">what if I end up alone?</div>
<div class="v">&ldquo;Even to your old age and gray hairs I am he, I am he who will sustain you.&rdquo;</div>
<div class="r">Isaiah 46:4</div>
<div class="s">Say it out loud in the quiet house. He hears it.</div>
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
