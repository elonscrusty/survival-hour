#!/usr/bin/env python3
"""Synthesise the game's short original sound effects into assets/audio/*.wav (16-bit mono, 44.1 kHz).
Pure Python (no samples, no third-party audio). Run: python3 tools/audio/gen_sfx.py"""
import math, os, random, struct, wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "audio")


def env(i, n, attack=0.01, release=0.6):
    t = i / n
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = max(0.0, 1 - max(0.0, t - (1 - release)) / release)
    return a * r


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(32000 * 0.8 * s / peak)) for s in samples))


def tone(freqs, dur, shape="sine", release=0.7):
    n = int(RATE * dur)
    out = []
    for i in range(n):
        t = i / RATE
        f = freqs[min(len(freqs) - 1, int(i / n * len(freqs)))]
        ph = 2 * math.pi * f * t
        v = math.sin(ph) if shape == "sine" else (1 if math.sin(ph) > 0 else -1) * 0.5
        out.append(v * env(i, n, 0.005, release))
    return out


random.seed(7)
write("click", tone([880], 0.06, release=0.9))
write("cash", tone([1318, 1760], 0.22) + tone([2637], 0.12))  # two-note "ching"
write("build", [s * 0.6 + 0.4 * (random.random() * 2 - 1) * env(i, 9000, 0.02, 0.9) for i, s in enumerate(tone([392, 523, 659, 784], 0.36))])
write("error", tone([220, 196], 0.18, shape="square"))
write("phone", tone([988, 0, 988, 0], 0.4))
write("cheer", [(random.random() * 2 - 1) * env(i, 13230, 0.05, 0.5) for i in range(13230)])
print("wrote", sorted(os.listdir(OUT)))
