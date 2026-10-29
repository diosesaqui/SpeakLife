"""SL-SCROLL-01 remade with Ruth (55): same four lines, same timings, same end card as the
winning ocean cut (../2026-10-26-scroll-ad/render.py), but the background is a silent
Seedance clip of Ruth at her kitchen table at dawn instead of the ocean sunrise.

Her face sits in the middle of the frame, so the lines appear one at a time in the lower
third (over the table) instead of stacking down the whole screen like the ocean cut.

Usage: python3 render.py [--still SECONDS out.png]
Needs ruth-raw.mp4 (Seedance) and ../2026-10-26-scroll-ad/ocean.wav next to it.
"""
import importlib.util, subprocess, sys
from pathlib import Path
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("scroll", HERE.parent / "2026-10-26-scroll-ad/render.py")
S = importlib.util.module_from_spec(spec)
spec.loader.exec_module(S)
W, H, FPS = S.W, S.H, S.FPS

RAW = HERE / "ruth-raw.mp4"
OCEAN = HERE.parent / "2026-10-26-scroll-ad/ocean.wav"
OUT = HERE / "SL-SCROLL-02-ruth.mp4"

# Same words and start times as the winner. Each line holds until the next one starts.
BLOCKS = S.BLOCKS
SCENE1_END, XFADE, END_LEN = S.SCENE1_END, S.XFADE, S.END_LEN
TOTAL = SCENE1_END + END_LEN
CLIP_START = 0.0      # trim into the raw clip if its first frames are off
TEXT_CY = 1300        # vertical centre of each line: below her face, above the Reels caption zone


def read_clip():
    """All frames of the raw clip, scaled to 1080x1920, as PIL images."""
    p = subprocess.run(
        ["ffmpeg", "-v", "error", "-ss", str(CLIP_START), "-i", str(RAW),
         "-vf", f"scale={W}:{H}:flags=lanczos,fps={FPS}", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True)
    size = W * H * 3
    return [Image.frombytes("RGB", (W, H), p.stdout[i * size:(i + 1) * size])
            for i in range(len(p.stdout) // size)]


def bottom_shade():
    """Dark gradient over the lower half so white text reads on the table."""
    g = Image.new("L", (1, H), 0)
    for y in range(H):
        t = (y - H * 0.5) / (H * 0.5)
        g.putpixel((0, y), int(175 * max(0, min(1, t)) ** 1.3))
    shade = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    shade.putalpha(g.resize((W, H)))
    return shade


def line_layers(f):
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    layers = []
    for _, t in BLOCKS:
        lines = S.wrap(probe, t, f, W - 150)
        lay = S.text_layer([lines], f, line_h=76, gap=0)[0]
        # text_layer centres on the screen; move it to TEXT_CY
        bbox = lay.getbbox()
        dy = TEXT_CY - (bbox[1] + bbox[3]) // 2
        moved = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        moved.paste(lay, (0, dy))
        layers.append(moved)
    return layers


def main():
    args = sys.argv[1:]
    still = None
    if "--still" in args:
        i = args.index("--still")
        still = (float(args[i + 1]), args[i + 2])

    clip = read_clip()
    shade = bottom_shade()
    layers = line_layers(S.font(60, "Semibold"))
    end = S.build_end_card()
    bg2 = S.load_bg(S.BG2)
    shade2 = Image.new("RGBA", (W, H), (0, 0, 0, 110))
    starts = [s for s, _ in BLOCKS] + [SCENE1_END]

    def frame(t):
        k = min(int(t * FPS), len(clip) - 1)
        s1 = Image.alpha_composite(clip[k].convert("RGBA"), shade)
        for j, lay in enumerate(layers):
            a_in = S.ease((t - starts[j]) / 0.6)
            a_out = 1 - S.ease((t - starts[j + 1]) / 0.35) if j + 1 < len(BLOCKS) else 1
            a = min(a_in, a_out)
            if a <= 0:
                continue
            rise = int((1 - a_in) * 24)
            m = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            m.paste(lay, (0, rise))
            s1 = Image.alpha_composite(s1, S.with_alpha(m, a))
        if t < SCENE1_END:
            return s1.convert("RGB")
        te = t - SCENE1_END
        s2 = S.zoom_frame(bg2, te, END_LEN, 1.04, 1.0, (0, 20)).convert("RGBA")
        s2 = Image.alpha_composite(s2, shade2)

        def put(img, cy, start, dy=30):
            nonlocal s2
            a = S.ease((te - start) / 0.7)
            if a <= 0:
                return
            lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            lay.paste(img, ((W - img.width) // 2, int(cy - img.height / 2 + (1 - a) * dy)))
            s2 = Image.alpha_composite(s2, S.with_alpha(lay, a))
        put(end["logo"], 560, 0.35)
        put(end["name"], 820, 0.6)
        put(end["tag"], 1010, 0.9)
        put(end["badge"], 1380, 1.3)
        return Image.blend(s1, s2, min(te / XFADE, 1)).convert("RGB")

    if still:
        frame(still[0]).save(still[1])
        return

    tmp = HERE / "_tmp.mp4"
    ff = subprocess.Popen(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
         "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-i", str(OCEAN),
         "-vf", "noise=alls=6:allf=t,format=yuv420p",
         "-c:v", "libx264", "-preset", "slow", "-crf", "24", "-maxrate", "5M", "-bufsize", "10M",
         "-c:a", "aac", "-b:a", "128k", "-af", f"afade=t=out:st={TOTAL - 1.2}:d=1.2",
         "-t", str(TOTAL), "-movflags", "+faststart", str(tmp)],
        stdin=subprocess.PIPE)
    for k in range(int(TOTAL * FPS)):
        ff.stdin.write(frame(k / FPS).tobytes())
    ff.stdin.close()
    ff.wait()
    tmp.replace(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
