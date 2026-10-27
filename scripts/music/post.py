import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt, fftconvolve
from ocean import ocean

SR = 44100


def filt(x, fc, kind, order=2):
    return sosfilt(butter(order, fc, btype=kind, fs=SR, output="sos"), x, axis=0)


def hall_ir(seconds, rng):
    """Stereo hall: early reflections + band-split tail (highs die first, like a real room)."""
    n = int(SR * seconds)
    t = np.arange(n) / SR
    irs = []
    for ch in range(2):
        noise = rng.normal(size=n)
        lo = filt(noise, 400, "low") * np.exp(-t * 6.9 / seconds)
        mid = filt(filt(noise, 400, "high"), 3000, "low") * np.exp(-t * 6.9 / (seconds * 0.8))
        hi = filt(noise, 3000, "high") * np.exp(-t * 6.9 / (seconds * 0.4)) * 0.5
        tail = (lo + mid + hi) * np.minimum(1, t / 0.06)  # soft onset
        er = np.zeros(n)
        for d in rng.uniform(0.008, 0.07, 9):
            er[int(d * SR)] += rng.uniform(0.2, 0.5) * rng.choice([-1, 1])
        ir = np.concatenate([np.zeros(int(0.025 * SR)), tail * 0.9 + er])[:n]
        irs.append(ir / np.sqrt(np.sum(ir ** 2)))
    return irs


def reverb(x, seconds, wet, rng):
    irs = hall_ir(seconds, rng)
    dry = x.copy()
    wet_sig = np.zeros_like(x)
    for ch in range(2):
        wet_sig[:, ch] = fftconvolve(x[:, ch], irs[ch])[: len(x)]
    wet_sig *= np.sqrt(np.mean(dry ** 2) / (np.mean(wet_sig ** 2) + 1e-12))
    return dry * (1 - wet) + wet_sig * wet


SETTINGS = {
    #             reverb s, wet, low-pass,  fade in, fade out
    "stillwaters": (3.2, 0.32, 9000, 2.0, 7.0),
    "dwelling": (5.0, 0.45, 7000, 6.0, 12.0),
    "shoreline": (4.0, 0.40, 8000, 6.0, 12.0),
    "lanterns": (3.6, 0.38, 10000, 2.0, 8.0),
    "morninglight": (3.4, 0.34, 9000, 2.0, 8.0),
}

name, src, dst = sys.argv[1:4]
rng = np.random.default_rng(sum(map(ord, name)))
sr, x = wavfile.read(src)
x = x.astype(np.float64) / 32768
rev_s, wet, lp, fin, fout = SETTINGS[name]

x = filt(x, 35, "high")
x = filt(x, lp, "low", 1)  # gentle top roll-off: warm, never harsh
# trim leading silence to 0.3 s
nz = np.argmax(np.max(np.abs(x), axis=1) > 1e-4)
x = x[max(0, nz - int(0.3 * SR)):]
x = np.concatenate([x, np.zeros((int(rev_s * SR), 2))])
x = reverb(x, rev_s, wet, rng)

if name == "shoreline":
    waves = ocean(len(x) / SR + 1, rng, 10.0)[: len(x)]
    waves = filt(waves, 6000, "low")
    waves *= np.sqrt(np.mean(x ** 2) / np.mean(waves ** 2)) * 0.55
    x = x + waves

# trim trailing silence
alive = np.where(np.max(np.abs(x), axis=1) > np.max(np.abs(x)) * 0.002)[0]
x = x[: alive[-1] + int(0.5 * SR)]
t = np.arange(len(x)) / SR
dur = t[-1]
env = np.clip(t / fin, 0, 1) ** 2 * np.clip((dur - t) / fout, 0, 1) ** 1.5
x *= env[:, None]
x /= np.max(np.abs(x)) * 1.05
wavfile.write(dst, SR, (x * 32767).astype(np.int16))
print(name, round(dur, 1), "s")
