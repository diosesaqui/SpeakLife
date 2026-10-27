"""Soaking-worship background pieces (spontaneous / prophetic worship style).

What they take from that style:
- A pad that never stops, held in one worship key the whole time.
- Free, improvised-feeling piano instead of a fixed pattern.
- Two slow waves of intensity per track: quiet, build, peak, settle.
- Guitar volume swells with echo, a shimmer layer, and a low bass that
  rises with the waves.

Each piece is written as separate MIDI stems so post-processing can treat
them differently (echo on guitar, long shimmer reverb, and so on).
"""
import json
import math
import sys

import mido
import numpy as np

from compose import NAMES, PPQ, m

STEMS = {"pad": [0, 1, 2, 3], "piano": [4], "guitar": [5, 6, 7, 10], "shimmer": [8]}
PROGRAMS = {0: 89, 1: 49, 2: 52, 3: 89, 4: 0, 5: 27, 6: 27, 7: 27, 10: 27, 8: 94}
MAJOR = [0, 2, 4, 5, 7, 9, 11]


def name_to_pc(n):
    return NAMES[n]


class Soak:
    def __init__(self, key, bpm, seed, seconds, curve):
        self.key = name_to_pc(key)
        self.bpm = bpm
        self.rng = np.random.default_rng(seed)
        self.ev = []
        self.total_beats = seconds * bpm / 60
        self.curve = curve  # [(fraction, intensity), ...]
        self.timeline = []  # for post: (start_s, root_midi, intensity)
        self.gch = 0

    # ---- helpers
    def sec(self, beat):
        return beat * 60 / self.bpm

    def intensity(self, beat):
        x = beat / self.total_beats
        pts = self.curve
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            if x0 <= x <= x1:
                u = (x - x0) / (x1 - x0)
                return y0 + (y1 - y0) * (1 - math.cos(math.pi * u)) / 2
        return pts[-1][1]

    def tick(self, beat):
        return max(0, int(round(beat * PPQ)))

    def note(self, ch, beat, dur, pitch, vel, jitter_s=0.012):
        b = beat + self.rng.normal(0, jitter_s) * self.bpm / 60
        v = int(np.clip(vel + self.rng.normal(0, 2.5), 1, 127))
        s = self.tick(b)
        self.ev.append((s, 1, ch, mido.Message("note_on", channel=ch, note=int(pitch), velocity=v)))
        self.ev.append((max(s + 1, self.tick(b + dur)), 0, ch, mido.Message("note_off", channel=ch, note=int(pitch), velocity=0)))

    def cc(self, ch, beat, ctrl, val):
        self.ev.append((self.tick(beat), 0, ch, mido.Message("control_change", channel=ch, control=ctrl, value=int(np.clip(val, 0, 127)))))

    def scale_pitches(self, lo, hi, pent=False):
        degs = [0, 2, 4, 7, 9] if pent else MAJOR
        return [p for p in range(lo, hi + 1) if (p - self.key) % 12 in degs]

    # ---- parts
    def pads(self, beat, span, chord, inten):
        """chord: list of semitone offsets from key root (absolute midi built here)."""
        root = chord[0]
        base = 36 + (self.key + root) % 12  # C2..B2
        if base > 43:
            base -= 12
        upper = [48 + ((self.key + c) % 12) for c in chord[1:]]
        upper = [v if v >= 52 else v + 12 for v in upper]
        voicing = sorted(set([base + 12, base + 19] + upper))
        for p in voicing:
            self.note(0, beat, span + 2.5, p, 58)
        if inten > 0.35:
            for p in voicing[:3]:
                self.note(1, beat, span + 2.0, p + 12 if p < 60 else p, 60)
        if inten > 0.7:
            for p in voicing[1:3]:
                self.note(2, beat, span + 2.0, p + 12 if p < 64 else p, 52)
        # shimmer: top of the chord an octave up, very soft
        for p in voicing[-2:]:
            self.note(8, beat + 0.5, span + 2, p + 12, 40)
        self.timeline.append((self.sec(beat), base - 12, inten))

    def drone(self, end):
        """The never-ending ground: key root and fifth, restruck with overlap."""
        r = 36 + self.key if 36 + self.key <= 43 else 24 + self.key
        b = 0.0
        while b < end:
            for p in (r, r + 7, r + 12):
                self.note(3, b, 34, p, 50)
            b += 32

    def expression(self, end):
        b = 0.0
        while b < end:
            i = self.intensity(b)
            breath = 0.5 + 0.5 * math.sin(2 * math.pi * self.sec(b) / 10.0)
            self.cc(0, b, 11, 70 + 40 * i + 10 * breath)
            self.cc(1, b, 11, 40 + 85 * i)
            self.cc(2, b, 11, 30 + 90 * i)
            self.cc(3, b, 11, 85 + 20 * breath)
            self.cc(8, b, 11, 60 + 50 * i)
            b += 0.25

    def piano(self, beat, span, chord, inten, phrase_state):
        chord_pcs = {(self.key + c) % 12 for c in chord}
        root_pc = (self.key + chord[0]) % 12
        # pedal per chord
        self.cc(4, beat + 0.03, 64, 127)
        self.cc(4, beat + span - 0.05, 64, 0)
        # left hand: low octave, open fifth, more motion when intense
        lb = 36 + root_pc if 36 + root_pc <= 43 else 24 + root_pc
        self.note(4, beat, span, lb, 34 + 16 * inten)
        self.note(4, beat + 0.02, span, lb + 12, 28 + 14 * inten)
        self.note(4, beat + 0.5, span - 0.5, lb + 19, 26 + 12 * inten)
        if inten > 0.5:
            self.note(4, beat + span / 2, span / 2, lb + 12, 30 + 12 * inten)
            third = [p for p in range(lb + 14, lb + 30) if p % 12 in chord_pcs][0]
            self.note(4, beat + span / 2 + 0.5, span / 2, third, 28 + 10 * inten)
        # right hand: an improvised phrase, denser and higher as intensity rises
        if inten < 0.18 and self.rng.random() < 0.5:
            return
        center = 70 + int(10 * inten)
        pool = self.scale_pitches(center - 9, center + 10, pent=self.rng.random() < 0.6)
        n_notes = int(np.clip(round(1 + inten * 6 + self.rng.normal(0, 1)), 1, 8))
        grid = np.arange(0, span - 1.0, 0.5)
        weights = np.array([2.0 if g % 1 == 0 else 1.0 for g in grid])
        weights[0] *= 2
        pos = np.sort(self.rng.choice(grid, size=min(n_notes, len(grid)), replace=False, p=weights / weights.sum()))
        idx = phrase_state.get("idx", len(pool) // 2)
        idx = int(np.clip(idx, 0, len(pool) - 1))
        for k, p0 in enumerate(pos):
            step = self.rng.choice([-2, -1, -1, 0, 1, 1, 2, 3 if inten > 0.6 else 1])
            idx = int(np.clip(idx + step, 0, len(pool) - 1))
            pitch = pool[idx]
            last = k == len(pos) - 1
            if last:  # land the phrase on a chord tone
                cands = [i for i, p in enumerate(pool) if p % 12 in chord_pcs]
                idx = min(cands, key=lambda i: abs(i - idx))
                pitch = pool[idx]
            nxt = pos[k + 1] if not last else span
            dur = max(0.5, nxt - p0) + (1.5 if last else 0.3)
            contour = math.sin(math.pi * (k + 0.5) / len(pos))
            vel = 38 + 26 * inten + 8 * contour
            drag = 0.04 * k  # rubato: lean back across the phrase
            self.note(4, beat + p0 + drag, dur, pitch, vel, jitter_s=0.025)
            if inten > 0.45 and self.rng.random() < 0.35:  # a sixth or third below
                below = [p for p in range(pitch - 9, pitch - 2) if p % 12 in chord_pcs]
                if below:
                    self.note(4, beat + p0 + drag, dur, below[-1], vel - 12, jitter_s=0.025)
            if last and self.rng.random() < 0.6:
                self.note(8, beat + p0 + drag + 0.2, dur + 3, pitch + 12, 34)
        phrase_state["idx"] = idx

    def guitar(self, beat, span, chord, inten):
        if inten < 0.25:
            return
        chord_pcs = [(self.key + c) % 12 for c in chord]
        count = 1 if inten < 0.55 else 2 if inten < 0.8 else 3
        starts = sorted(self.rng.choice(np.arange(0, span - 1, 1.0), size=count, replace=False))
        for s in starts:
            pc = self.rng.choice(chord_pcs + [(self.key + 2) % 12])
            pitch = 60 + pc + (12 if self.rng.random() < 0.5 else 0)
            ch = [5, 6, 7, 10][self.gch % 4]
            self.gch += 1
            b = beat + s
            dur = self.rng.uniform(3, 6)
            swell = self.rng.uniform(0.8, 1.6)
            target = 70 + 50 * inten
            self.cc(ch, b - 0.05, 11, 0)
            steps = 12
            for j in range(1, steps + 1):
                self.cc(ch, b + swell * j / steps, 11, target * (j / steps) ** 1.6)
            self.note(ch, b, dur, pitch, 70, jitter_s=0.0)

    def stem_midi(self, path, chans):
        mid = mido.MidiFile(ticks_per_beat=PPQ)
        tr = mido.MidiTrack()
        mid.tracks.append(tr)
        tr.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm), time=0))
        for ch in chans:
            tr.append(mido.Message("program_change", channel=ch, program=PROGRAMS[ch], time=0))
            for ctrl, val in ((7, 100), (91, 0), (93, 0), (11, 100)):
                tr.append(mido.Message("control_change", channel=ch, control=ctrl, value=val, time=0))
            pan = {0: 64, 1: 40, 2: 88, 3: 64, 4: 66, 5: 30, 6: 98, 7: 44, 10: 84, 8: 64}[ch]
            tr.append(mido.Message("control_change", channel=ch, control=10, value=pan, time=0))
        last = 0
        for t, order, ch, msg in sorted((e for e in self.ev if e[2] in chans), key=lambda e: (e[0], e[1])):
            tr.append(msg.copy(time=t - last))
            last = t
        mid.save(path)


def build(spec):
    s = Soak(spec["key"], spec["bpm"], spec["seed"], spec["seconds"], spec["curve"])
    span = spec["span"]
    end = s.total_beats
    s.drone(end + 8)
    state = {}
    b, i = 0.0, 0
    while b < end:
        inten = s.intensity(b)
        prog = spec["lift"] if inten > spec.get("lift_at", 0.62) else spec["prog"]
        chord = prog[i % len(prog)]
        s.pads(b, span, chord, inten)
        s.piano(b, span, chord, inten, state)
        s.guitar(b, span, chord, inten)
        b += span
        i += 1
    # resolve home and let it ring
    home = spec["prog"][0]
    s.pads(b, 12, home, 0.15)
    s.cc(4, b + 0.03, 64, 127)
    root = 48 + s.key if 48 + s.key <= 55 else 36 + s.key
    for k, off in enumerate([0, 7, 12, 16, 19, 24]):
        s.note(4, b + k * 0.22, 12, root + off, 34 - k)
    s.expression(b + 14)
    return s, b + 14


# Chords are scale-degree offsets in semitones from the key root: [root, other tones...]
I, ii, iii, IV, V, vi = [0, 4, 7, 14], [2, 5, 9, 12], [4, 7, 11, 14], [5, 9, 12, 16], [7, 11, 14, 17], [9, 12, 16, 19]
Vsus = [7, 12, 14, 19]
Imaj9 = [0, 4, 11, 14]
IVadd9 = [5, 9, 12, 19]
vi7 = [9, 12, 16, 19]

TWO_WAVES = [(0, 0.08), (0.10, 0.18), (0.36, 0.78), (0.50, 0.32), (0.76, 0.96), (0.90, 0.35), (1.0, 0.1)]

SPECS = {
    # F# major, 66 BPM: the closest to a live soaking room
    "secretplace": dict(key="F#", bpm=66, seed=11, seconds=262, span=8, curve=TWO_WAVES,
                        prog=[Imaj9, vi7, IVadd9, Vsus], lift=[IVadd9, V, vi7, IVadd9]),
    # Ab major, 62 BPM, with soft rain added in post
    "gloryrain": dict(key="Ab", bpm=62, seed=23, seconds=258, span=8,
                      curve=[(0, 0.1), (0.12, 0.22), (0.4, 0.72), (0.55, 0.3), (0.8, 0.9), (0.92, 0.32), (1.0, 0.1)],
                      prog=[I, vi7, IVadd9, Vsus], lift=[IVadd9, I, V, vi7]),
    # Db major, 58 BPM: deep and low, strings and choir carry the peaks
    "holyground": dict(key="Db", bpm=58, seed=37, seconds=268, span=8,
                       curve=[(0, 0.1), (0.15, 0.25), (0.42, 0.85), (0.56, 0.35), (0.8, 1.0), (0.92, 0.35), (1.0, 0.1)],
                       prog=[Imaj9, IVadd9, vi7, IVadd9], lift=[IVadd9, Vsus, vi7, V]),
    # E major, 68 BPM: the brightest, guitar swells up front
    "abide": dict(key="E", bpm=68, seed=53, seconds=255, span=8, curve=TWO_WAVES,
                  prog=[I, iii, vi7, IVadd9], lift=[IVadd9, I, Vsus, vi7]),
}

if __name__ == "__main__":
    out = sys.argv[1]
    names = sys.argv[2:] or list(SPECS)
    for name in names:
        s, end = build(SPECS[name])
        for stem, chans in STEMS.items():
            s.stem_midi(f"{out}/{name}.{stem}.mid", chans)
        with open(f"{out}/{name}.json", "w") as f:
            json.dump({"bpm": s.bpm, "timeline": s.timeline, "end_s": s.sec(end)}, f)
        print(name, round(s.sec(end)), "s")
