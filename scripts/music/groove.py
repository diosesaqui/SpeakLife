"""Living Water: brushed drums, piano and flute over the soaking pad.

C major (written in D, transposed), C = 528 Hz, 72 BPM, worship-ballad feel.
The drums are a soft brush kit and come and go with the waves: they enter
after the flute, build to a peak, drop out for a breakdown, return fuller,
then fall away for the ending.
"""
import json
import sys

import mido
import numpy as np

from compose import PPQ, m
from soak import IVadd9, Soak, V, Vsus, vi7, I

BPM = 72
# Written in D, played a step lower in C so that, tuned to A = 444,
# its home note C sits at exactly 528 Hz.
TRANSPOSE = -2
BAR = 4

# Section map: (name, bars, intensity)
FORM = [("intro", 8, 0.15), ("theme", 16, 0.35), ("build", 16, 0.7), ("breakdown", 8, 0.25),
        ("theme2", 8, 0.6), ("build2", 16, 0.95), ("outro", 10, 0.2)]

ii7 = [4, 7, 11, 14]          # F#m7 in D (iii)
D_F = [0, 4, 7, 14]           # D/F# feel (voiced like I)
THEME_CHORDS = [I, vi7, [7, 11, 14, 19], Vsus]          # D  Bm7  Gmaj7  Asus
BUILD_CHORDS = [IVadd9, V, ii7, vi7, IVadd9, V, D_F, Vsus]  # G A F#m7 Bm7 G A D/F# Asus

# Flute lines as (beat in bar, length, note) per bar
THEME_A = [
    [(0, 1.5, "A5"), (1.5, 0.5, "F#5"), (2, 1, "A5"), (3, 1, "B5")],
    [(0, 2, "D6"), (2, 1, "C#6"), (3, 1, "B5")],
    [(0, 1.5, "B5"), (1.5, 0.5, "A5"), (2, 1, "G5"), (3, 1, "F#5")],
    [(0, 3, "E5")],
    [(0, 1.5, "A5"), (1.5, 0.5, "F#5"), (2, 1, "A5"), (3, 1, "D6")],
    [(0, 2, "F#6"), (2, 1, "E6"), (3, 1, "D6")],
    [(0, 1, "B5"), (1, 1, "D6"), (2, 1, "C#6"), (3, 1, "B5")],
    [(0, 2, "A5"), (2, 1, "G5"), (3, 1, "E5")],
]
THEME_B_END = [[(0, 4, "F#5")]]  # resolves home on the next downbeat
BUILD_MEL = [
    [(0, 2, "D6"), (2, 2, "B5")],
    [(0, 2, "C#6"), (2, 2, "E6")],
    [(0, 3, "F#6"), (3, 1, "E6")],
    [(0, 4, "D6")],
    [(0, 1, "B5"), (1, 1, "D6"), (2, 2, "E6")],
    [(0, 1, "F#6"), (1, 1, "E6"), (2, 2, "C#6")],
    [(0, 2, "D6"), (2, 2, "A5")],
    [(0, 3, "E6")],
]
BREAK_MEL = [[(0, 4, "F#5")], [], [(0, 4, "E5")], [], [(0, 3, "D5"), (3, 1, "E5")], [(0, 4, "F#5")], [], [(1, 3, "A5")]]

KICK, TAP, SLAP, SWIRL, RIDE, BELL, CRASH, PEDAL_HH = 36, 38, 39, 40, 51, 53, 49, 44
TOMS = [50, 48, 47, 45, 43]


def down(line, k=12):
    return [[(b, d, m(n) - k) for b, d, n in bar] for bar in line]


def as_midi(line):
    return [[(b, d, m(n) if isinstance(n, str) else n) for b, d, n in bar] for bar in line]


class Groove(Soak):
    def __init__(self):
        bars = sum(b for _, b, _ in FORM)
        super().__init__("D", BPM, 72, bars * BAR * 60 / BPM, [(0, 0.1), (1, 0.1)])
        self.sections = []
        start = 0
        for name, bars_, inten in FORM:
            self.sections.append((name, start, start + bars_, inten))
            start += bars_

    def section(self, bar):
        for s in self.sections:
            if s[1] <= bar < s[2]:
                return s
        return self.sections[-1]

    def intensity(self, beat):
        """Section intensity, eased so changes glide over about two bars."""
        bar = beat / BAR
        name, a, b, inten = self.section(int(bar))
        prev = self.section(a - 1)[3] if a > 0 else inten
        ramp = min(1.0, (bar - a) / 2)
        return prev + (inten - prev) * ramp

    # ---- parts
    def piano_bar(self, beat, chord, inten, name):
        pcs = [(self.key + c) % 12 for c in chord]
        root = 38 + (pcs[0] - 2) % 12
        if root > 45:
            root -= 12
        self.cc(4, beat + 0.03, 64, 127)
        self.cc(4, beat + BAR - 0.05, 64, 0)
        self.note(4, beat, BAR, root, 40 + 12 * inten, 0.006)
        self.note(4, beat, BAR, root + 12, 32 + 10 * inten, 0.006)
        if inten > 0.5:
            self.note(4, beat + 2.5, 1.5, root + 12, 30 + 10 * inten, 0.006)
        # right hand: flowing eighths through the chord, lighter when the flute sings
        tones = sorted({60 + (p - 60) % 12 for p in [60 + pc for pc in pcs]})
        figure = [tones[0], tones[1], tones[2], tones[1] + 12 if tones[1] + 12 < 79 else tones[3 % len(tones)],
                  tones[2], tones[1], tones[3 % len(tones)], tones[1]]
        vel = 30 + 14 * inten
        for i, p in enumerate(figure):
            if name in ("intro", "outro", "breakdown") and i % 2:
                continue
            accent = 6 if i in (0, 4) else 0
            self.note(4, beat + i * 0.5, 1.0 if i % 2 == 0 else 0.6, p, vel + accent, 0.008)

    def flute_bar(self, beat, line, vel=72):
        for b, d, p in line:
            start = beat + b
            # breath (CC2 drives this expressive flute): swell in, ease off at the end
            self.cc(11, start, 2, 62)
            for j in range(1, 7):
                self.cc(11, start + d * 0.15 * j, 2, 62 + 40 * min(1, j / 4) - (14 if j == 6 else 0))
            self.note(11, start, d * 0.94, p, vel, 0.01)

    def drums_bar(self, beat, inten, bar_in_sec, sec_len, name):
        r = self.rng
        h = lambda b, n, v, d=0.25: self.note(9, beat + b, d, n, v + r.normal(0, 3), 0.006)
        if name in ("intro",) or (name == "theme" and bar_in_sec < 8):
            return
        if name == "breakdown":
            if bar_in_sec == sec_len - 1:  # soft cymbal roll swelling into the return
                for j in range(32):
                    self.note(9, beat + j * 0.125, 0.1, RIDE, 12 + 66 * (j / 32) ** 1.5, 0.003)
            return
        if name == "outro":
            if bar_in_sec < 6:
                h(0, SWIRL, 34, 4)
                h(0, KICK, 34)
                if bar_in_sec % 2 == 1:
                    h(2, TAP, 26)
            return
        soft = name == "theme"
        full = name in ("build2",)
        if bar_in_sec == 0 and name in ("build", "theme2", "build2"):
            h(0, CRASH, 50 + 20 * inten, 2)
        h(0, KICK, 52 + 18 * inten)
        if not soft:
            h(2.5 if full else 3, KICK, 38 + 14 * inten)
            if full:
                h(1.75, KICK, 30)
        h(0, SWIRL, 26 + 18 * inten, 2)
        h(2, SWIRL, 24 + 18 * inten, 2)
        h(1, TAP if soft else SLAP, 40 + 22 * inten)
        h(3, TAP if soft else SLAP, 42 + 22 * inten)
        step = 1.0 if soft else 0.5
        b = 0.0
        while b < BAR:
            h(b, RIDE, (24 if soft else 30) + 14 * inten + (6 if b % 1 == 0 else 0))
            b += step
        if not soft:
            h(1, PEDAL_HH, 30)
            h(3, PEDAL_HH, 30)
        # a gentle tom fill closing every 8 bars of the full sections
        if not soft and bar_in_sec % 8 == 7:
            for j, t in enumerate(TOMS[:4]):
                h(3 + j * 0.25, t, 40 + 8 * j + 14 * inten)

    def stems(self, out, name):
        chans = {"pad": [0, 1, 2, 3], "piano": [4], "flute": [11], "drums": [9], "shimmer": [8]}
        programs = {0: (0, 89), 1: (0, 49), 2: (0, 52), 3: (0, 89), 4: (0, 0), 11: (17, 73), 9: (128, 40), 8: (0, 94)}
        pans = {0: 64, 1: 40, 2: 88, 3: 64, 4: 60, 11: 72, 9: 64, 8: 64}
        for stem, cs in chans.items():
            mid = mido.MidiFile(ticks_per_beat=PPQ)
            tr = mido.MidiTrack()
            mid.tracks.append(tr)
            tr.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm), time=0))
            for ch in cs:
                bank, prog = programs[ch]
                if ch != 9:
                    tr.append(mido.Message("control_change", channel=ch, control=0, value=bank, time=0))
                tr.append(mido.Message("program_change", channel=ch, program=prog, time=0))
                for ctrl, val in ((7, 100), (91, 0), (93, 0), (11, 100), (10, pans[ch])):
                    tr.append(mido.Message("control_change", channel=ch, control=ctrl, value=val, time=0))
            last = 0
            for t, order, ch, msg in sorted((e for e in self.ev if e[2] in cs), key=lambda e: (e[0], e[1])):
                if msg.type in ("note_on", "note_off") and ch != 9:
                    msg = msg.copy(note=msg.note + TRANSPOSE)
                tr.append(msg.copy(time=t - last))
                last = t
            mid.save(f"{out}/{name}.{stem}.mid")


def build():
    g = Groove()
    total_bars = g.sections[-1][2]
    g.drone(total_bars * BAR + 8)
    theme = as_midi(THEME_A)
    theme_resolve = as_midi(THEME_A[:7]) + as_midi(THEME_B_END)
    for bar in range(total_bars):
        beat = bar * BAR
        name, a, b, _ = g.section(bar)
        k = bar - a
        inten = g.intensity(beat)
        chords = BUILD_CHORDS if name.startswith("build") else THEME_CHORDS
        chord = chords[k % len(chords)]
        g.pads(beat, BAR, chord, inten)
        g.piano_bar(beat, chord, inten, name)
        g.drums_bar(beat, inten, k, b - a, name)
        line = None
        if name == "theme":
            line = (theme if k < 8 else theme_resolve)[k % 8]
        elif name == "theme2":
            line = theme_resolve[k % 8]
        elif name == "build":
            line = down(BUILD_MEL)[k % 8] if k < 8 else as_midi(BUILD_MEL)[k % 8]
        elif name == "build2":
            line = as_midi(BUILD_MEL)[k % 8]
        elif name == "breakdown":
            line = as_midi(BREAK_MEL)[k % 8]
        elif name == "outro" and k < 8:
            line = down(THEME_A)[k] if k < 7 else [(0, 4, m("D5"))]
        if line:
            vel = 64 if name in ("breakdown", "outro") else 76 if name != "build2" else 84
            g.flute_bar(beat, line, vel)
    end = total_bars * BAR
    g.pads(end, 12, I, 0.12)
    g.cc(4, end + 0.03, 64, 127)
    for k, off in enumerate([0, 7, 12, 16, 19, 24]):
        g.note(4, end + k * 0.2, 12, 50 + off, 34 - k)
    g.flute_bar(end + 1, [(0, 6, m("A5"))], 58)
    g.expression(end + 14)
    return g, end + 14


if __name__ == "__main__":
    out = sys.argv[1]
    g, end = build()
    g.stems(out, "livingwater")
    with open(f"{out}/livingwater.json", "w") as f:
        timeline = [(t, root + TRANSPOSE, i) for t, root, i in g.timeline]
        json.dump({"bpm": g.bpm, "timeline": timeline, "end_s": g.sec(end)}, f)
    print("livingwater", round(g.sec(end)), "s")
