"""Original peaceful compositions for SpeakLife, played on sampled instruments.

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
# 1. Still Waters: solo grand piano, D major, 60 BPM
# ------------------------------------------------------------------
def still_waters():
    s = Song(60, 101)
    s.program(0, PIANO, 110, 54)   # left hand slightly left
    s.program(1, PIANO, 112, 74)   # right hand slightly right
    A = [  # (bass, chord tones for the broken figure, melody [(beat, dur, note)])
        ("D2", ["A2", "D3", "F#3", "A3"], [(0, 2, "F#5"), (2, 1, "E5"), (3, 1, "D5")]),
        ("C#2", ["A2", "C#3", "E3", "A3"], [(0, 3, "E5"), (3, 1, "A4")]),
        ("B1", ["F#2", "B2", "D3", "F#3"], [(0, 2, "D5"), (2, 1, "C#5"), (3, 1, "B4")]),
        ("G1", ["D2", "G2", "B2", "D3"], [(0, 2, "B4"), (2, 2, "A4")]),
        ("F#2", ["A2", "D3", "F#3", "A3"], [(0, 1, "A4"), (1, 1, "D5"), (2, 2, "F#5")]),
        ("G1", ["D2", "G2", "B2", "D3"], [(0, 2, "G5"), (2, 1, "F#5"), (3, 1, "E5")]),
        ("E2", ["B2", "D3", "G3", "B3"], [(0, 1, "D5"), (1, 1, "E5"), (2, 2, "B4")]),
        ("A1", ["E2", "A2", "C#3", "E3"], [(0, 3, "C#5"), (3, 1, "E5")]),
    ]
    B = [
        ("G1", ["D2", "G2", "B2", "D3"], [(0, 1.5, "B4"), (1.5, 0.5, "C#5"), (2, 2, "D5")]),
        ("A1", ["E2", "A2", "C#3", "E3"], [(0, 1.5, "C#5"), (1.5, 0.5, "D5"), (2, 2, "E5")]),
        ("F#2", ["C#3", "F#3", "A3", "C#4"], [(0, 2, "F#5"), (2, 1, "E5"), (3, 1, "C#5")]),
        ("B1", ["F#2", "B2", "D3", "F#3"], [(0, 3, "D5"), (3, 1, "B4")]),
        ("G1", ["D2", "G2", "B2", "D3"], [(0, 1, "B4"), (1, 1, "D5"), (2, 2, "G5")]),
        ("F#2", ["A2", "D3", "F#3", "A3"], [(0, 2, "F#5"), (2, 2, "A5")]),
        ("E2", ["G2", "B2", "D3", "G3"], [(0, 2, "G5"), (2, 1, "F#5"), (3, 1, "E5")]),
        ("A1", ["E2", "G2", "C#3", "E3"], [(0, 4, "E5")]),
    ]
    form = [("intro", A[:4]), ("mel", A), ("mel", B), ("high", A), ("mel", B), ("soft", A), ("outro", A[:3])]
    beat = 0.0
    for kind, bars in form:
        for bass, tones, mel in bars:
            s.pedal(0, beat, beat + 4)
            s.pedal(1, beat, beat + 4)
            lv = 34 if kind in ("intro", "outro", "soft") else 40
            s.note(0, beat, 4, bass, lv + 6)
            fig = [0, 1, 2, 3, 2, 1, 2, 1]
            for i, f in enumerate(fig[1:], start=1):
                s.note(0, beat + i * 0.5, 1.0, tones[f], lv - 4 + (4 if f == 3 else 0))
            if kind in ("mel", "high", "soft"):
                for b, d, nm in mel:
                    if kind == "high":
                        nm = up(nm)
                        if b not in (0, 2):
                            continue
                    v = 50 if kind == "mel" else 44
                    s.note(1, beat + b, d, nm, v)
                    if kind == "mel" and b == 0:  # soft lower third/sixth support
                        s.note(1, beat + b, d, tones[3] if m(tones[3]) < m(nm) - 2 else tones[2], 30)
            beat += 4
    s.pedal(0, beat, beat + 8)
    for i, nm in enumerate(["D2", "A2", "D3", "F#3", "A3", "D4", "F#4", "A4"]):
        s.note(0 if i < 5 else 1, beat + i * 0.18, 8, nm, 38 - i)
    return s, beat + 10


# ------------------------------------------------------------------
# 2. Dwelling: strings, choir and warm pad that breathe, C major, 60 BPM
# ------------------------------------------------------------------
def dwelling():
    s = Song(60, 202)
    s.program(0, SLOWSTR, 96, 40)
    s.program(1, CHOIR, 70, 88)
    s.program(2, WARMPAD, 80, 64)
    s.program(3, CELESTA, 64, 92)
    s.program(4, CELLO, 92, 52)
    chords = [
        (["C2", "G2"], ["E3", "G3", "B3", "D4"], ["G4", "D5"]),   # Cmaj9
        (["A1", "E2"], ["C3", "E3", "G3", "B3"], ["E4", "B4"]),   # Am9
        (["F1", "C2"], ["A2", "C3", "E3", "G3"], ["C4", "G4"]),   # Fmaj9
        (["G1", "D2"], ["B2", "D3", "E3", "A3"], ["D4", "A4"]),   # G6/9
    ]
    span = 12
    cello_lines = [
        [(0, 6, "E3"), (6, 6, "G3")], [(0, 6, "C3"), (6, 6, "E3")],
        [(0, 8, "A2"), (8, 4, "C3")], [(0, 6, "B2"), (6, 6, "D3")],
    ]
    beat = 0
    total_cycles = 4
    for cyc in range(total_cycles):
        for ci, (low, mid, top) in enumerate(chords):
            for nm in low:
                s.note(2, beat, span + 1.5, nm, 70)
            for nm in mid:
                s.note(0, beat, span + 1.0, nm, 64)
            if cyc >= 1:
                for nm in top:
                    s.note(1, beat, span + 1.0, nm, 56)
            if cyc in (1, 2):
                for b, d, nm in cello_lines[ci]:
                    s.note(4, beat + b, d, nm, 70)
            if cyc >= 1:
                for b in (2, 7):
                    if s.rng.random() < 0.6:
                        s.note(3, beat + b, 3, up(s.rng.choice(top + mid[2:]), 1), 40)
            beat += span
    end = beat
    for nm in ["C2", "G2"]:
        s.note(2, end, 12, nm, 66)
    for nm in ["E3", "G3", "C4", "D4"]:
        s.note(0, end, 12, nm, 56)
    s.note(3, end + 2, 6, "G5", 36)
    for ch, ph in ((0, 0.0), (1, 1.4), (2, 0.6), (4, 0.3)):
        s.breathe(ch, 0, end + 12, 70, 120, ph)
    return s, end + 16


# ------------------------------------------------------------------
# 3. Shoreline: sparse piano and soft strings, F major, 56 BPM (ocean added in post)
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


# ------------------------------------------------------------------
# 4. Lanterns: harp, celesta and strings, G major pentatonic, 54 BPM
# ------------------------------------------------------------------
def lanterns():
    s = Song(54, 404)
    s.program(0, HARP, 104, 48)
    s.program(1, CELESTA, 84, 84)
    s.program(2, SLOWSTR, 70, 64)
    s.program(3, FLUTE, 72, 76)
    prog = [
        (["G2", "D3", "G3", "B3", "D4"], [(0, 1, "D5"), (1, 1, "B4"), (2, 2, "G4")]),
        (["E2", "B2", "E3", "G3", "B3"], [(0, 1, "B4"), (1, 1, "G4"), (2, 2, "E4")]),
        (["C2", "G2", "C3", "E3", "G3"], [(0, 1, "G4"), (1, 1, "E4"), (2, 1, "D4"), (3, 1, "E4")]),
        (["D2", "A2", "D3", "F#3", "A3"], [(0, 3, "D4")]),
        (["C2", "G2", "C3", "E3", "G3"], [(0, 1, "E4"), (1, 1, "G4"), (2, 2, "A4")]),
        (["B1", "G2", "B2", "D3", "G3"], [(0, 2, "B4"), (2, 2, "D5")]),
        (["A1", "E2", "A2", "C3", "E3"], [(0, 1, "E5"), (1, 1, "D5"), (2, 2, "B4")]),
        (["D2", "A2", "D3", "F#3", "A3"], [(0, 3, "A4")]),
    ]
    flute = [(0, 4, "B4"), (4, 4, "G4"), (8, 4, "E4"), (12, 4, "F#4"), (16, 4, "G4"), (20, 4, "D5"), (24, 4, "C5"), (28, 4, "A4")]
    beat = 0
    passes = ["harp", "harp_cel", "full", "harp_cel", "full", "harp"]
    for pi, p in enumerate(passes):
        for bi, (tones, mel) in enumerate(prog):
            fig = [0, 1, 2, 3, 4, 3, 2, 1]
            for i, f in enumerate(fig):
                s.note(0, beat + i * 0.5, 2.5, tones[f], 46 if i == 0 else 36)
            if p in ("full",):
                for nm in tones[1:4]:
                    s.note(2, beat, 4.2, up(nm), 56)
            if p in ("harp_cel", "full"):
                for b, d, nm in mel:
                    s.note(1, beat + b, d, nm, 48)
            if p == "full" and pi == 4:
                for b, d, nm in flute:
                    if bi * 4 <= b < bi * 4 + 4:
                        s.note(3, beat + (b - bi * 4), d, nm, 58)
            beat += 4
    for i, nm in enumerate(["G2", "D3", "G3", "B3", "D4", "G4"]):
        s.note(0, beat + i * 0.2, 8, nm, 40)
    s.note(1, beat + 1.3, 6, "B4", 40)
    s.breathe(2, 0, beat + 8, 70, 115)
    return s, beat + 12


# ------------------------------------------------------------------
# 5. Morning Light: piano hymn with cello and strings, Eb major, 56 BPM
# ------------------------------------------------------------------
def morning_light():
    s = Song(56, 505)
    s.program(0, PIANO, 110, 58)
    s.program(1, CELLO, 90, 46)
    s.program(2, SLOWSTR, 84, 80)
    prog = [
        ("Eb2", ["Bb2", "Eb3", "G3"], [(0, 2, "G4"), (2, 2, "Bb4")]),
        ("D2", ["Bb2", "D3", "F3"], [(0, 1, "Ab4"), (1, 1, "G4"), (2, 2, "F4")]),
        ("C2", ["G2", "C3", "Eb3"], [(0, 2, "G4"), (2, 2, "C5")]),
        ("Ab1", ["Eb2", "Ab2", "C3"], [(0, 3, "Bb4"), (3, 1, "Ab4")]),
        ("G1", ["Bb2", "Eb3", "G3"], [(0, 2, "G4"), (2, 1, "Bb4"), (3, 1, "Eb5")]),
        ("Ab1", ["Eb2", "Ab2", "C3"], [(0, 2, "C5"), (2, 1, "Bb4"), (3, 1, "Ab4")]),
        ("Bb1", ["F2", "Bb2", "D3"], [(0, 1, "G4"), (1, 1, "F4"), (2, 2, "Ab4")]),
        ("Eb2", ["Bb2", "Eb3", "G3"], [(0, 2, "G4"), (2, 2, "Eb4")]),
    ]
    beat = 0
    passes = ["piano", "cello", "strings", "piano_high", "close"]
    for p in passes:
        for bass, tones, mel in prog:
            s.pedal(0, beat, beat + 4)
            s.note(0, beat, 4, bass, 40)
            for k in (1, 2, 3):
                for j, nm in enumerate(tones):
                    s.note(0, beat + k + j * 0.04, 0.9, nm, 28 if k != 2 else 32)
            if p in ("piano", "piano_high", "close", "strings"):
                for b, d, nm in mel:
                    nm2 = up(nm) if p == "piano_high" else nm
                    if p == "close" and b not in (0,):
                        continue
                    s.note(0, beat + b, d, nm2, 48 if p != "close" else 40)
            if p == "cello":
                for b, d, nm in mel:
                    s.note(1, beat + b, d + 0.1, up(nm, -1), 74)
            if p in ("strings", "piano_high"):
                for nm in tones:
                    s.note(2, beat, 4.1, up(nm), 54)
                s.note(1, beat, 4.1, up(bass), 52)
            beat += 4
    s.pedal(0, beat, beat + 10)
    for i, nm in enumerate(["Eb2", "Bb2", "Eb3", "G3", "Bb3", "Eb4"]):
        s.note(0, beat + i * 0.15, 10, nm, 36)
    s.note(2, beat, 8, "G4", 40)
    s.breathe(1, 0, beat + 10, 80, 120, 0.4)
    s.breathe(2, 0, beat + 10, 70, 118, 1.1)
    return s, beat + 14


PIECES = {"stillwaters": still_waters, "dwelling": dwelling, "shoreline": shoreline,
          "lanterns": lanterns, "morninglight": morning_light}

if __name__ == "__main__":
    out = sys.argv[1]
    for name, fn in PIECES.items():
        song, end_beat = fn()
        song.save(f"{out}/{name}.mid")
        print(name, round(end_beat * 60 / song.bpm), "s")
