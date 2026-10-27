"""Two native Sofia slideshows (1080x1350), text over her photos, TikTok style.

CJ = growing closer to Jesus (ob=promises). PR = a promise from God for your situation
(ob=promises). LEARNINGS: native slideshows with a "step N is the key" hook are the account's
cheapest trials; carousels win with one-line post text.

Run: python3 docs/creative/videos/2026-10-25-sofia/render_slideshows.py
"""
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
STILLS = os.path.join(HERE, "stills")
OUT = os.path.join(HERE, "slideshows")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:1080px;height:1350px;overflow:hidden}
body{font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;position:relative;background:#000}
.bg{position:absolute;inset:0;background-size:cover;background-position:center %(pos)s}
.shade{position:absolute;left:0;right:0;%(shade)s}
.box{position:absolute;left:70px;right:70px;%(where)s;text-align:center}
.t{display:inline;background:#fff;color:#111;font-weight:700;font-size:%(size)spx;line-height:1.5;padding:6px 16px;
   box-decoration-break:clone;-webkit-box-decoration-break:clone;border-radius:10px}
.s{margin-top:26px;color:#fff;font-weight:600;font-size:38px;line-height:1.35;text-shadow:0 2px 10px rgba(0,0,0,.85),0 0 2px rgba(0,0,0,.9)}
.v{margin-top:26px;color:#fff;font-weight:700;font-size:44px;line-height:1.32;text-shadow:0 2px 12px rgba(0,0,0,.9),0 0 2px rgba(0,0,0,.9)}
.r{margin-top:14px;color:#ffd77a;font-weight:700;font-size:32px;text-shadow:0 2px 8px rgba(0,0,0,.9)}
.n{position:absolute;top:44px;right:52px;color:#fff;font-size:26px;font-weight:600;opacity:.85;text-shadow:0 1px 6px rgba(0,0,0,.8)}
"""

TOP = "top:120px"
BOTTOM = "bottom:150px"
SHADE_TOP = "top:0;height:640px;background:linear-gradient(rgba(0,0,0,.45),rgba(0,0,0,0))"
SHADE_BOTTOM = "bottom:0;height:760px;background:linear-gradient(rgba(0,0,0,0),rgba(0,0,0,.6))"


def slide(img, title, sub="", verse="", ref="", where="top", size=50, pos="30%"):
    w, shade = (TOP, SHADE_TOP) if where == "top" else (BOTTOM, SHADE_BOTTOM)
    css = CSS % {"pos": pos, "shade": shade, "where": w, "size": size}
    body = f'<div class="bg" style="background-image:url(\'file://{os.path.join(STILLS, img)}\')"></div>'
    body += '<div class="shade"></div><div class="box">'
    body += f'<span class="t">{title}</span>'
    if sub:
        body += f'<div class="s">{sub}</div>'
    if verse:
        body += f'<div class="v">{verse}</div>'
    if ref:
        body += f'<div class="r">{ref}</div>'
    body += "</div>"
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'


DECKS = {
    "CJ-closer-to-jesus": [
        slide("A1-dawn-reading.png", "i read my bible for years and still felt far from Jesus",
              "here&rsquo;s what changed it (step 2 is the key)", size=56),
        slide("S1-window-coffee.png", "1. same time, same place.",
              "before the phone gets a word in."),
        slide("A2-finger-on-page.png", "2. read less, slower.",
              "one passage. ask Him: what does this show me about You?<br>this is the one that changed everything.",
              where="bottom"),
        slide("A3-says-it-out-loud.png", "3. say one line back to Him out loud.",
              "that&rsquo;s when reading turns into a conversation.", where="bottom"),
        slide("A4-sunrise-peace.png", "Jesus did this too.",
              verse="&ldquo;Very early in the morning, while it was still dark, Jesus got up&hellip; and went off to a solitary place, where he prayed.&rdquo;",
              ref="Mark 1:35", where="bottom"),
        slide("S2-phone-smile.png", "miss a morning? He didn&rsquo;t move.",
              "i use SpeakLife for the quiet part. a devotional and the line to say, ready every morning.",
              where="bottom"),
    ],
    "PR-promise-for-you": [
        slide("S3-bible-hug.png", "if you need a promise from God right now, find yours 👇",
              "save this for the day you need it", size=54),
        slide("S4-kitchen-table.png", "for the bills:",
              verse="&ldquo;My God will meet all your needs according to the riches of his glory in Christ Jesus.&rdquo;",
              ref="Philippians 4:19", where="bottom"),
        slide("S5-walk-golden.png", "for your body:",
              verse="&ldquo;I will restore you to health and heal your wounds.&rdquo;",
              ref="Jeremiah 30:17", where="bottom"),
        slide("S6-bed-peace.png", "for your mind at 3am:",
              verse="&ldquo;You will keep in perfect peace those whose minds are steadfast, because they trust in you.&rdquo;",
              ref="Isaiah 26:3", where="bottom"),
        slide("S7-rooftop-future.png", "for your future:",
              verse="&ldquo;For I know the plans I have for you&hellip; plans to give you hope and a future.&rdquo;",
              ref="Jeremiah 29:11", where="bottom"),
        slide("B4-morning-curtains.png", "now say yours out loud.",
              "every promise He made is &ldquo;Yes&rdquo; in Christ (2&nbsp;Corinthians&nbsp;1:20).<br>SpeakLife hands me the promise for whatever i&rsquo;m facing, every morning.",
              where="bottom"),
    ],
}


def main():
    for deck, slides in DECKS.items():
        d = os.path.join(OUT, deck)
        os.makedirs(d, exist_ok=True)
        for i, html_src in enumerate(slides, 1):
            html = os.path.join(d, f"{i:02d}.html")
            png = os.path.join(d, f"{deck[:2]}-{i:02d}.png")
            open(html, "w").write(html_src)
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                            "--force-device-scale-factor=1", "--window-size=1080,1350",
                            "--allow-file-access-from-files", f"--screenshot={png}", f"file://{html}"],
                           check=True, capture_output=True)
            os.remove(html)
            print(png)


if __name__ == "__main__":
    main()
