"""Mix the soaking stems: room reverb, guitar echo, shimmer, sub bass, rain."""
import json
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

from post import SR, filt, reverb


def load(path):
    sr, x = wavfile.read(path)
    assert sr == SR
    return x.astype(np.float64) / 32768


def fit(x, n):
    return x[:n] if len(x) >= n else np.concatenate([x, np.zeros((n - len(x), 2))])


def rms(x):
    return np.sqrt(np.mean(x ** 2)) + 1e-12


def echo(x, bpm, rng):
    """Dotted-eighth ping-pong echo, each repeat darker than the last."""
    d = int(SR * 60 / bpm * 0.75)
    out = x.copy()
    tap = x.copy()
    for k in range(1, 7):
        tap = filt(tap, 3500, "low", 1) * 0.5
        sh = np.zeros_like(x)
        sh[d * k:] = tap[: len(x) - d * k]
        if k % 2:
            sh = sh[:, ::-1]  # bounce left/right
        out += sh
    return out


def sub_bass(meta, n, rng):
    t = np.arange(n) / SR
    out = np.zeros(n)
    tl = meta["timeline"]
    for j, (start, root, inten) in enumerate(tl):
        end = tl[j + 1][0] if j + 1 < len(tl) else start + 10
        f = 440 * 2 ** ((root - 69) / 12)
        while f < 40:
            f *= 2
        a, b = int(start * SR), min(n, int((end + 1.5) * SR))
        tt = t[a:b] - start
        env = np.minimum(1, tt / 1.2) * np.clip((end + 1.5 - start - tt) / 1.5, 0, 1)
        amp = max(0.0, inten - 0.25) ** 1.4
        out[a:b] += amp * env * (np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(4 * np.pi * f * tt))
    out = filt(out, 160, "low")
    return np.stack([out, out], axis=1)


def rain(n, rng):
    """Soft steady rain: a filtered hush plus scattered drops."""
    hush = np.stack([rng.normal(size=n), rng.normal(size=n)], axis=1)
    hush = filt(filt(hush, 500, "high"), 5000, "low")
    slow = filt(rng.normal(size=(n, 1)), 0.3, "low", 1)
    hush *= 1 + 0.6 * slow / (np.max(np.abs(slow)) + 1e-9)
    drops = np.zeros((n, 2))
    count = int(n / SR * 35)
    pos = rng.integers(0, n - 2000, count)
    for p in pos:
        L = 300
        d = rng.normal(size=L) * np.exp(-np.arange(L) / rng.uniform(25, 70)) * rng.uniform(0.2, 1.0)
        pan = rng.uniform(0, 1)
        drops[p:p + L, 0] += d * (1 - pan)
        drops[p:p + L, 1] += d * pan
    drops = filt(filt(drops, 1200, "high"), 6000, "low")
    return hush * 0.6 / rms(hush) + drops * 0.25 / rms(drops)


name, stems_dir, dst = sys.argv[1:4]
rng = np.random.default_rng(sum(map(ord, name)))
meta = json.load(open(f"{stems_dir}/{name}.json"))
n = int((meta["end_s"] + 8) * SR)

pad = fit(load(f"{stems_dir}/{name}.pad.wav"), n)
piano = fit(load(f"{stems_dir}/{name}.piano.wav"), n)
guitar = fit(load(f"{stems_dir}/{name}.guitar.wav"), n)
shim = fit(load(f"{stems_dir}/{name}.shimmer.wav"), n)

pad = reverb(filt(pad, 40, "high"), 5.5, 0.5, rng)
piano = reverb(filt(piano, 50, "high"), 3.6, 0.36, rng)
guitar = reverb(echo(filt(filt(guitar, 180, "high"), 6000, "low"), meta["bpm"], rng), 6.5, 0.65, rng)
shim = reverb(filt(shim, 300, "high"), 9.0, 0.95, rng)
sub = sub_bass(meta, n, rng)

ref = rms(pad)
mix = (pad
       + piano * (ref / rms(piano)) * 0.95
       + guitar * (ref / rms(guitar)) * 0.42
       + shim * (ref / rms(shim)) * 0.30
       + sub * (ref / rms(sub)) * 0.40)
if name == "gloryrain":
    mix += rain(n, rng) * ref * 0.22

mix = filt(mix, 9500, "low", 1)
alive = np.where(np.max(np.abs(mix), axis=1) > np.max(np.abs(mix)) * 0.002)[0]
mix = mix[: alive[-1] + int(0.5 * SR)]
t = np.arange(len(mix)) / SR
dur = t[-1]
env = np.clip(t / 4.0, 0, 1) ** 2 * np.clip((dur - t) / 9.0, 0, 1) ** 1.5
mix *= env[:, None]
mix /= np.max(np.abs(mix)) * 1.05
wavfile.write(dst, SR, (mix * 32767).astype(np.int16))
print(name, round(dur, 1), "s")
