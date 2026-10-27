"""Shoreline, played on sampled instruments (the soaking pieces live in soak.py).

Each piece is written as MIDI, rendered with FluidSynth through the MuseScore
General HQ SoundFont (MIT / public-domain piano), then mixed in post.py.

Calm-by-design: 54-60 BPM (resting heart rate), consonant major harmony,
soft velocities, no percussion, and pad/strings swells on a 10-second cycle
(6 breaths per minute).
"""
import math
import sys
import numpy as np
import mido

PPQ = 480
NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
         "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def m(name):
    return 12 * (int(name[-1]) + 1) + NAMES[name[:-1]]


class Song:
    def __init__(self, bpm, seed):
        self.bpm = bpm
        self.ev = []  # (tick, order, msg)
        self.rng = np.random.default_rng(seed)
        self.programs = {}

    def program(self, ch, prog, vol=100, pan=64):
        self.programs[ch] = (prog, vol, pan)

    def tick(self, beat):
        return max(0, int(round(beat * PPQ)))

    def note(self, ch, beat, dur, name, vel, humanize=0.015):
        jitter = self.rng.normal(0, humanize) * self.bpm / 60  # seconds -> beats
        v = int(np.clip(vel + self.rng.normal(0, 3), 1, 127))
        p = m(name) if isinstance(name, str) else name
        s = self.tick(beat + jitter)
        self.ev.append((s, 1, mido.Message("note_on", channel=ch, note=p, velocity=v)))
        self.ev.append((max(s + 1, self.tick(beat + dur)), 0, mido.Message("note_off", channel=ch, note=p, velocity=0)))

    def cc(self, ch, beat, ctrl, val):
        self.ev.append((self.tick(beat), 0, mido.Message("control_change", channel=ch, control=ctrl, value=int(np.clip(val, 0, 127)))))

    def pedal(self, ch, beat_down, beat_up):
        self.cc(ch, beat_down + 0.02, 64, 127)
        self.cc(ch, beat_up - 0.02, 64, 0)

    def breathe(self, ch, start, end, lo, hi, phase=0.0, period_s=10.0):
        """Expression swell on a breathing cycle."""
        b = start
        while b < end:
            sec = b * 60 / self.bpm
            x = 0.5 + 0.5 * math.sin(2 * math.pi * sec / period_s + phase)
            self.cc(ch, b, 11, lo + (hi - lo) * x)
            b += 0.25

    def save(self, path):
        mid = mido.MidiFile(ticks_per_beat=PPQ)
        tr = mido.MidiTrack()
        mid.tracks.append(tr)
        tr.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm), time=0))
        for ch, (prog, vol, pan) in self.programs.items():
            tr.append(mido.Message("program_change", channel=ch, program=prog, time=0))
            tr.append(mido.Message("control_change", channel=ch, control=7, value=vol, time=0))
            tr.append(mido.Message("control_change", channel=ch, control=10, value=pan, time=0))
            tr.append(mido.Message("control_change", channel=ch, control=91, value=0, time=0))
            tr.append(mido.Message("control_change", channel=ch, control=93, value=0, time=0))
        last = 0
        for t, _, msg in sorted(self.ev, key=lambda e: (e[0], e[1])):
            tr.append(msg.copy(time=t - last))
            last = t
        mid.save(path)


def up(name, k=1):
    return name[:-1] + str(int(name[-1]) + k)


PIANO, HARP, STRINGS, SLOWSTR, CHOIR, CELLO, CELESTA, WARMPAD, FLUTE = 0, 46, 48, 49, 52, 42, 8, 89, 73


# ------------------------------------------------------------------
# Shoreline: sparse piano and soft strings, F major, 56 BPM (ocean added in post)
# ------------------------------------------------------------------
def shoreline():
    s = Song(56, 303)
    s.program(0, PIANO, 108, 70)
    s.program(1, SLOWSTR, 80, 50)
    s.program(2, WARMPAD, 62, 64)
    prog = [
        ("F2", ["C3", "F3", "A3"], [(0, 3, "C5"), (3, 1, "A4"), (4, 4, "F4")]),
        ("D2", ["A2", "D3", "F3"], [(0, 2, "A4"), (2, 2, "C5"), (4, 4, "D5")]),
        ("Bb1", ["F2", "Bb2", "D3"], [(0, 3, "D5"), (3, 1, "C5"), (4, 4, "Bb4")]),
        ("C2", ["G2", "C3", "E3"], [(0, 4, "G4"), (4, 2, "A4"), (6, 2, "C5")]),
        ("F2", ["C3", "F3", "A3"], [(0, 2, "F5"), (2, 2, "E5"), (4, 4, "C5")]),
        ("A1", ["E2", "A2", "C3"], [(0, 4, "E5"), (4, 4, "C5")]),
        ("Bb1", ["F2", "Bb2", "D3"], [(0, 2, "D5"), (2, 2, "C5"), (4, 4, "A4")]),
        ("C2", ["G2", "Bb2", "E3"], [(0, 6, "G4"), (6, 2, "A4")]),
    ]
    beat = 0
    passes = ["pad", "piano", "piano_str", "piano_str", "sparse"]
    for p in passes:
        for bass, tones, mel in prog:
            for nm in [bass] + tones:
                s.note(2, beat, 9, nm, 60)
            if p in ("piano_str", "sparse"):
                for nm in tones:
                    s.note(1, beat, 8.5, up(nm), 54)
            if p != "pad":
                s.pedal(0, beat, beat + 8)
                s.note(0, beat, 8, bass, 34)
                s.note(0, beat + 1, 4, tones[1], 28)
                s.note(0, beat + 1.5, 4, tones[2], 26)
                for b, d, nm in mel:
                    if p == "sparse" and b != 0:
                        continue
                    s.note(0, beat + b, d, nm, 44)
            beat += 8
    for nm in ["F2", "C3", "F3", "A3", "C4"]:
        s.note(2, beat, 10, nm, 54)
    s.pedal(0, beat, beat + 10)
    s.note(0, beat, 10, "F4", 34)
    s.note(0, beat + 0.3, 10, "A4", 32)
    s.note(0, beat + 0.6, 10, "C5", 30)
    s.breathe(1, 0, beat + 10, 70, 115, 0.0)
    s.breathe(2, 0, beat + 10, 60, 105, 1.6)
    return s, beat + 14



PIECES = {"shoreline": shoreline}

if __name__ == "__main__":
    out = sys.argv[1]
    for name, fn in PIECES.items():
        song, end_beat = fn()
        song.save(f"{out}/{name}.mid")
        print(name, round(end_beat * 60 / song.bpm), "s")
