"""Ocean waves on a 10-second breathing cycle, mixed under Shoreline."""
import numpy as np
from scipy.signal import butter, sosfilt

SR = 44100


def lowpass(x, fc, order=2):
    return sosfilt(butter(order, fc, btype="low", fs=SR, output="sos"), x, axis=0)


def highpass(x, fc, order=2):
    return sosfilt(butter(order, fc, btype="high", fs=SR, output="sos"), x, axis=0)


def ocean(dur, rng=None, period=10.0):
    """Waves on a breathing cycle: brown-ish noise swelling every ~10 s."""
    length = int(SR * dur)
    out = np.zeros((length, 2))
    t = np.arange(length) / SR
    for ch in range(2):
        noise = rng.normal(size=length)
        brown = lowpass(noise, 500, order=1)
        hiss = highpass(lowpass(noise, 4000), 800) * 0.25
        # irregular wave timing, average ~period
        env = np.zeros(length)
        pos = rng.uniform(0, 2)
        while pos < dur:
            p = period * rng.uniform(0.8, 1.2)
            seg = (t - pos) / p
            mask = (seg >= 0) & (seg < 1.4)
            s = seg[mask]
            env[mask] += np.where(s < 0.45, (s / 0.45) ** 2, np.exp(-(s - 0.45) * 3.2)) * rng.uniform(0.7, 1.0)
            pos += p
        out[:, ch] = (brown * 2.2 + hiss * env) * (0.25 + env)
    return out
