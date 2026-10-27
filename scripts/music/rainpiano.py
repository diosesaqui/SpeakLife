"""Gentle Rain: solo piano over steady rainfall.

C major at 60 BPM, tuned so C = 528 Hz (A = 444) when mastered. The piano
breathes like a person playing: it slows at the end of each phrase and
drifts a little from bar to bar. The rain is built from individual drops in
layers (distant, middle, close), puddle plinks, the odd heavier drip and a
quiet roof rumble. No smooth noise, which is what reads as static.

    python3 rainpiano.py compose OUT_DIR          -> gentlerain.piano.mid
    python3 rainpiano.py mix PIANO_WAV OUT_WAV    -> piano + rain, mixed
"""
import sys

import mido
import numpy as np

from compose import PPQ, m

BASE_BPM = 60
BAR = 4
PIANO = 0

C, G_B, Am7, Fmaj7, C_E, Dm7, Gsus, G, Em7, Am, Em_G = (
    ("C2", ["G2", "C3", "E3", "G3"]), ("B1", ["G2", "B2", "D3", "G3"]), ("A1", ["E2", "A2", "C3", "G3"]),
    ("F1", ["C2", "F2", "A2", "E3"]), ("E2", ["G2", "C3", "E3", "G3"]), ("D2", ["A2", "D3", "F3", "C4"]),
    ("G1", ["D2", "G2", "C3", "D3"]), ("G1", ["D2", "G2", "B2", "D3"]), ("E2", ["B2", "E3", "G3", "D4"]),
    ("A1", ["E2", "A2", "C3", "E3"]), ("G1", ["D2", "G2", "B2", "E3"]),
)

A_CH = [C, G_B, Am7, Fmaj7, C_E, Fmaj7, Dm7, Gsus]
B_CH = [Fmaj7, G, Em7, Am7, Fmaj7, G, Am7, Gsus]
BR_CH = [Am, Em_G, Fmaj7, C_E, Dm7, C_E, Fmaj7, Gsus]

A_MEL = [
    [(0, 1.5, "E5"), (1.5, 0.5, "D5"), (2, 1, "E5"), (3, 1, "G5")],
    [(0, 3, "D5"), (3, 1, "B4")],
    [(0, 1.5, "C5"), (1.5, 0.5, "B4"), (2, 1, "C5"), (3, 1, "E5")],
    [(0, 4, "A4")],
    [(0, 1, "G4"), (1, 1, "C5"), (2, 1, "E5"), (3, 1, "G5")],
    [(0, 2, "A5"), (2, 1, "G5"), (3, 1, "E5")],
    [(0, 1.5, "F5"), (1.5, 0.5, "E5"), (2, 1, "D5"), (3, 1, "C5")],
    [(0, 4, "D5")],
]
B_MEL = [
    [(0, 2, "C6"), (2, 1, "A5"), (3, 1, "G5")],
    [(0, 2, "B5"), (2, 1, "D6"), (3, 1, "B5")],
    [(0, 3, "G5"), (3, 1, "E5")],
    [(0, 2, "A5"), (2, 1, "G5"), (3, 1, "E5")],
    [(0, 1, "F5"), (1, 1, "A5"), (2, 2, "C6")],
    [(0, 1.5, "B5"), (1.5, 0.5, "A5"), (2, 2, "G5")],
    [(0, 1, "E5"), (1, 1, "G5"), (2, 1, "A5"), (3, 1, "C6")],
    [(0, 2, "D6"), (2, 2, "B5")],
]
BR_MEL = [
    [(0, 2, "E5"), (2, 2, "A5")],
    [(0, 2, "G5"), (2, 2, "B4")],
    [(0, 2, "C5"), (2, 1, "F5"), (3, 1, "E5")],
    [(0, 3, "E5"), (3, 1, "G5")],
    [(0, 2, "F5"), (2, 1, "A5"), (3, 1, "F5")],
    [(0, 2, "E5"), (2, 1, "G5"), (3, 1, "C6")],
    [(0, 2, "A5"), (2, 1, "G5"), (3, 1, "F5")],
    [(0, 2, "D5"), (2, 2, "G5")],
]

# (section, chords, melody, style)
FORM = [
    ("intro", A_CH[:4], None, "intro"),
    ("A", A_CH, A_MEL, "plain"),
    ("B", B_CH, B_MEL, "plain"),
    ("A2", A_CH, A_MEL, "high"),
    ("bridge", BR_CH, BR_MEL, "low"),
    ("A3", A_CH, A_MEL, "full"),
    ("B2", B_CH, B_MEL, "full"),
    ("A4", A_CH, A_MEL, "soft"),
    ("outro", [C, Fmaj7, C, Gsus], None, "intro"),
]


def up(n, k=1):
    return n[:-1] + str(int(n[-1]) + k)


class Piece:
    def __init__(self, seed=528):
        self.rng = np.random.default_rng(seed)
        self.notes = []  # (tick, order, msg)
        self.tempos = []  # (tick, bpm)

    def t(self, beat):
        return max(0, int(round(beat * PPQ)))

    def note(self, beat, dur, name, vel, jitter=0.02):
        b = beat + self.rng.normal(0, jitter)
        v = int(np.clip(vel + self.rng.normal(0, 2.5), 1, 127))
        p = m(name) if isinstance(name, str) else name
        s = self.t(b)
        self.notes.append((s, 1, mido.Message("note_on", channel=PIANO, note=p, velocity=v)))
        self.notes.append((max(s + 1, self.t(b + dur)), 0, mido.Message("note_off", channel=PIANO, note=p, velocity=0)))

    def pedal(self, a, b):
        self.notes.append((self.t(a + 0.04), 0, mido.Message("control_change", channel=PIANO, control=64, value=127)))
        self.notes.append((self.t(b - 0.03), 0, mido.Message("control_change", channel=PIANO, control=64, value=0)))

    def tempo(self, beat, bpm):
        self.tempos.append((self.t(beat), bpm))

    def left_hand(self, beat, chord, style):
        bass, tones = chord
        lv = {"intro": 32, "soft": 32, "low": 36, "plain": 38, "high": 36, "full": 42}[style]
        self.note(beat, BAR, bass, lv + 8)
        if style == "low":  # bridge: deep octave and a held chord, more space
            self.note(beat + 0.02, BAR, up(bass), lv)
            for j, n in enumerate(tones[1:]):
                self.note(beat + 1 + j * 0.06, 3, n, lv - 6)
            return
        fig = [0, 1, 2, 3, 2, 1, 2, 1] if style != "full" else [0, 1, 2, 3, 2, 3, 2, 1]
        for i, f in enumerate(fig[1:], start=1):
            if style in ("intro", "soft") and i % 2 == 0 and i not in (2, 4):
                continue
            self.note(beat + i * 0.5, 1.2, tones[f], lv - 4 + (4 if f == 3 else 0))

    def melody(self, beat, line, style, k):
        if not line:
            return
        for b, d, n in line:
            name = n
            vel = {"plain": 50, "high": 44, "low": 46, "full": 54, "soft": 42}[style]
            if style == "high":
                if b not in (0, 2):
                    continue
                name = up(n)
            if style == "soft" and b not in (0, 2):
                continue
            self.note(beat + b, d + 0.15, name, vel)
            if style == "full" and b == 0:  # a sixth below, for warmth
                lower = m(name) - 9 if m(name) - 9 > m("G4") else m(name) - 5
                self.note(beat + b + 0.01, d, lower, vel - 14)


def compose():
    p = Piece()
    beat = 0.0
    for sec, chords, mel, style in FORM:
        for k, chord in enumerate(chords):
            last = k == len(chords) - 1
            drift = p.rng.normal(0, 1.2)
            p.tempo(beat, BASE_BPM + drift)
            if last:  # lean into the end of each phrase
                p.tempo(beat + 2, BASE_BPM - 5 + drift)
                p.tempo(beat + 3, BASE_BPM - 9 + drift)
            if sec == "outro":
                p.tempo(beat, BASE_BPM - 3 - 3 * k)
            p.pedal(beat, beat + BAR)
            p.left_hand(beat, chord, style)
            p.melody(beat, mel[k] if mel else None, style, k)
            beat += BAR
    # final chord, rolled and left to ring
    p.tempo(beat, 46)
    p.pedal(beat, beat + 10)
    for j, n in enumerate(["C2", "G2", "C3", "E3", "G3", "C4", "E4", "G4", "C5"]):
        p.note(beat + j * 0.16, 10, n, 40 - j * 1.5, 0.004)
    return p, beat + 12


def save(p, path):
    mid = mido.MidiFile(ticks_per_beat=PPQ)
    tr = mido.MidiTrack()
    mid.tracks.append(tr)
    head = [mido.Message("program_change", channel=PIANO, program=0)]
    for ctrl, val in ((7, 110), (10, 64), (91, 0), (93, 0)):
        head.append(mido.Message("control_change", channel=PIANO, control=ctrl, value=val))
    events = [(0, -1, h) for h in head]
    events += [(t, -2, mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(b))) for t, b in p.tempos]
    events += p.notes
    last = 0
    for t, _, msg in sorted(events, key=lambda e: (e[0], e[1])):
        tr.append(msg.copy(time=t - last))
        last = t
    mid.save(path)


# ------------------------------------------------------------------ rain

def rain(n, sr, rng):
    """Rain built from individual drops, not smooth noise (smooth noise reads as static)."""
    from scipy.signal import butter, oaconvolve, sosfilt

    def bp(x, lo, hi, order=2):
        return sosfilt(butter(order, [lo, hi], btype="band", fs=sr, output="sos"), x, axis=0)

    def lp(x, fc, order=1):
        return sosfilt(butter(order, fc, btype="low", fs=sr, output="sos"), x, axis=0)

    def norm(x):
        return x / (np.sqrt(np.mean(x ** 2)) + 1e-12)

    def drops(rate, amp_shape, kernels, stereo_spread):
        """Scatter drops at `rate` per second; each kernel is one kind of drop sound."""
        out = np.zeros((n, 2))
        for kern in kernels:
            count = int(n / sr * rate / len(kernels))
            pos = rng.integers(0, n, count)
            amps = rng.exponential(1.0, count) ** amp_shape  # mostly small, a few bigger
            pan = 0.5 + (rng.uniform(-0.5, 0.5, count) * stereo_spread)
            for ch, g in ((0, 1 - pan), (1, pan)):
                train = np.zeros(n)
                np.add.at(train, pos, amps * g)
                out[:, ch] += oaconvolve(train, kern)[:n]
        return out

    def kernel(ms, lo, hi):
        L = int(sr * ms / 1000)
        k = rng.normal(size=L) * np.exp(-np.arange(L) / (L / 5))
        return bp(k, lo, hi)

    # distant rain: thousands of tiny, soft, darker drops make the steady wash
    far = drops(2600, 1.6, [kernel(6, 500, 2500), kernel(8, 700, 3200), kernel(5, 400, 2000)], 1.0)
    # the middle: clearer drops on leaves and ground
    mid = drops(380, 1.8, [kernel(4, 1200, 4500), kernel(7, 900, 3500), kernel(3, 1500, 5000)], 0.9)
    # a few close drops, crisp and placed
    near = drops(28, 2.2, [kernel(3, 1800, 5500), kernel(5, 1200, 4200)], 0.7)
    # puddle drops: the small rising "plink" of a bubble
    plinks = np.zeros((n, 2))
    for _ in range(int(n / sr * 5)):
        p = rng.integers(0, n - 2000)
        L = int(sr * rng.uniform(0.02, 0.05))
        tt = np.arange(L) / sr
        f0 = rng.uniform(1100, 2600)
        phase = 2 * np.pi * np.cumsum(f0 * (1 + 2.0 * tt / tt[-1])) / sr
        d = np.sin(phase) * np.exp(-tt / (L / sr / 4)) * rng.uniform(0.2, 0.7)
        pan = rng.uniform(0.15, 0.85)
        plinks[p:p + L, 0] += d * (1 - pan)
        plinks[p:p + L, 1] += d * pan
    # heavier drips from an edge, lower and rounder
    drips = np.zeros((n, 2))
    for _ in range(int(n / sr * 0.7)):
        p = rng.integers(0, n - 4000)
        L = int(sr * 0.06)
        tt = np.arange(L) / sr
        d = np.sin(2 * np.pi * rng.uniform(450, 800) * tt) * np.exp(-tt / 0.012) * rng.uniform(0.4, 0.9)
        side = rng.choice([0, 1])
        drips[p:p + L, side] += d
        drips[p:p + L, 1 - side] += d * 0.4
    # body: a quiet, dark rumble, like rain on a roof overhead
    body = lp(rng.normal(size=(n, 2)), 700, 2)
    swell = lp(rng.normal(size=(n, 1)), 0.15)
    swell = 1 + 0.3 * swell / (np.max(np.abs(swell)) + 1e-9)

    out = (norm(far) * 1.0 + norm(mid) * 0.55 + norm(near) * 0.3
           + norm(plinks) * 0.16 + norm(drips) * 0.14 + norm(body) * 0.3) * swell
    out = sosfilt(butter(1, 120, btype="high", fs=sr, output="sos"), out, axis=0)
    return lp(out, 5000, 2)  # nothing bright enough to hiss


def mix(piano_wav, out_wav):
    from scipy.io import wavfile

    from post import SR, filt, reverb

    rng = np.random.default_rng(528)
    sr, x = wavfile.read(piano_wav)
    x = x.astype(np.float64) / 32768
    x = filt(x, 40, "high")
    nz = np.argmax(np.max(np.abs(x), axis=1) > 1e-4)
    x = x[max(0, nz - int(1.5 * SR)):]  # a little rain before the first note
    x = np.concatenate([x, np.zeros((int(4 * SR), 2))])
    piano = reverb(x, 3.4, 0.36, rng)
    piano = filt(piano, 9000, "low", 1)
    alive = np.where(np.max(np.abs(piano), axis=1) > np.max(np.abs(piano)) * 0.002)[0]
    n = alive[-1] + int(4 * SR)  # let the rain carry on a moment after the last note
    piano = np.concatenate([piano, np.zeros((max(0, n - len(piano)), 2))])[:n]
    r = rain(n, SR, rng)
    level = np.sqrt(np.mean(piano ** 2)) / np.sqrt(np.mean(r ** 2))
    mixed = piano + r * level * 0.34
    t = np.arange(n) / SR
    dur = t[-1]
    env = np.clip(t / 3.0, 0, 1) ** 2 * np.clip((dur - t) / 6.0, 0, 1) ** 1.5
    mixed *= env[:, None]
    mixed /= np.max(np.abs(mixed)) * 1.05
    wavfile.write(out_wav, SR, (mixed * 32767).astype(np.int16))
    print("gentlerain", round(dur, 1), "s")


if __name__ == "__main__":
    if sys.argv[1] == "compose":
        p, end = compose()
        save(p, f"{sys.argv[2]}/gentlerain.piano.mid")
        print("gentlerain composed")
    else:
        mix(sys.argv[2], sys.argv[3])
