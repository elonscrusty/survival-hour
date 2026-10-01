"""Original synthesized sound effects and a calm music loop for Egg Farm.

    python3 assets/audio/make_audio.py   # writes assets/audio/*.wav (44.1 kHz, mono, 16-bit)

Everything is generated from oscillators, noise and envelopes in numpy; no samples or
third-party recordings are used. The music bed is an original four-chord progression
(C - Am - F - G) rendered so that its tail wraps around: the file loops seamlessly.
"""

import os
import wave

import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
RNG = np.random.default_rng(20261001)


# ---------------------------------------------------------------- building blocks
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def note_hz(n):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def env_ad(n, attack, decay_tau):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(t - attack, 0) / decay_tau)


def sine_sweep(dur, f0, f1, curve=1.0):
    t = t_axis(dur)
    k = (t / dur) ** curve
    f = f0 + (f1 - f0) * k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def bell(freq, dur, decay=0.35, partials=((1, 1.0), (2.76, 0.35), (5.4, 0.18), (8.93, 0.08))):
    """Inharmonic struck-metal tone."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp in partials:
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * ratio ** 0.5 / decay)
    return out * env_ad(len(t), 0.002, 10.0)


def pluck(freq, dur, bright=6, decay=0.6):
    """Soft plucked string: harmonics with faster decay for higher partials."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for h in range(1, bright + 1):
        out += (1 / h ** 1.3) * np.sin(2 * np.pi * freq * h * t) * np.exp(-t * h / decay)
    return out * env_ad(len(t), 0.004, 10.0)


def lowpass(x, cutoff):
    """Windowed-sinc FIR low-pass."""
    taps = 101
    n = np.arange(taps) - (taps - 1) / 2
    h = np.sinc(2 * cutoff / SR * n) * np.hamming(taps)
    h /= h.sum()
    return np.convolve(x, h, mode="same")


def noise(dur):
    return RNG.uniform(-1, 1, int(dur * SR))


def place(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


def finish(x, peak_db=-1.0, fade=0.01):
    x = x - np.mean(x)
    nf = int(fade * SR)
    if nf and len(x) > 2 * nf:
        x[-nf:] *= np.linspace(1, 0, nf)
        x[:32] *= np.linspace(0, 1, 32)
    peak = np.max(np.abs(x)) or 1.0
    return x / peak * 10 ** (peak_db / 20)


def write(name, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    path = os.path.join(HERE, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(x) / SR:5.2f}s")


# ---------------------------------------------------------------- effects
def sfx_click():
    buf = np.zeros(int(0.06 * SR))
    n = noise(0.004) * np.linspace(1, 0, int(0.004 * SR))
    place(buf, lowpass(n, 6000) * 0.6, 0)
    tone = np.sin(2 * np.pi * 1800 * t_axis(0.05)) * env_ad(int(0.05 * SR), 0.001, 0.012)
    place(buf, tone, 0)
    return finish(buf, -3)


def sfx_buy():
    """Cha-ching: a short brushed-metal 'cha', then two bright bells."""
    buf = np.zeros(int(0.95 * SR))
    cha = lowpass(noise(0.08), 9000) - lowpass(noise(0.08), 2500) * 0.5
    cha *= env_ad(len(cha), 0.002, 0.025)
    place(buf, cha * 0.7, 0)
    place(buf, bell(note_hz(88), 0.8, decay=0.25) * 0.55, 0.07)  # E7-ish
    place(buf, bell(note_hz(93), 0.8, decay=0.3) * 0.6, 0.13)  # A7
    place(buf, bell(note_hz(81), 0.6, decay=0.3) * 0.25, 0.13)
    return finish(buf, -1)


def sfx_coin():
    buf = np.zeros(int(0.32 * SR))
    for k, (n, at) in enumerate(((83, 0.0), (88, 0.07))):
        t = t_axis(0.25)
        f = note_hz(n)
        wave_ = np.sign(np.sin(2 * np.pi * f * t)) * 0.3 + np.sin(2 * np.pi * f * t)
        wave_ = lowpass(wave_, 7000) * env_ad(len(t), 0.002, 0.07 if k == 0 else 0.1)
        place(buf, wave_, at)
    return finish(buf, -2)


def sfx_collect():
    """Bubbly pop: two quick upward sine sweeps."""
    buf = np.zeros(int(0.25 * SR))
    for f0, f1, at, amp in ((320, 980, 0.0, 1.0), (520, 1400, 0.06, 0.6)):
        s = sine_sweep(0.09, f0, f1, curve=0.6) * env_ad(int(0.09 * SR), 0.003, 0.03)
        place(buf, s * amp, at)
    return finish(buf, -2)


def sfx_deposit():
    """Soft thud, then a two-note chime."""
    buf = np.zeros(int(0.85 * SR))
    thud = sine_sweep(0.25, 120, 50, curve=0.5) * env_ad(int(0.25 * SR), 0.003, 0.07)
    thud += lowpass(noise(0.25), 400) * env_ad(int(0.25 * SR), 0.001, 0.03) * 0.8
    place(buf, thud, 0)
    place(buf, bell(note_hz(84), 0.6, decay=0.35) * 0.35, 0.08)  # C7
    place(buf, bell(note_hz(88), 0.6, decay=0.4) * 0.35, 0.16)  # E7
    return finish(buf, -1)


def sfx_error():
    buf = np.zeros(int(0.38 * SR))
    for at in (0.0, 0.18):
        t = t_axis(0.16)
        sq = np.sign(np.sin(2 * np.pi * 110 * t)) + np.sign(np.sin(2 * np.pi * 116.5 * t))
        sq = lowpass(sq, 1800) * env_ad(len(t), 0.004, 0.2)
        sq[-int(0.02 * SR):] *= np.linspace(1, 0, int(0.02 * SR))
        place(buf, sq, at)
    return finish(buf, -3)


def sfx_rebirth():
    """Rising major arpeggio with a shimmering tail."""
    buf = np.zeros(int(1.9 * SR))
    notes = [72, 76, 79, 84, 88, 91, 96]
    for k, n in enumerate(notes):
        at = k * 0.09
        place(buf, pluck(note_hz(n), 1.0, bright=5, decay=0.5) * 0.5, at)
        place(buf, bell(note_hz(n + 12), 0.9, decay=0.3) * 0.18, at)
    # final chord swell
    t = t_axis(1.2)
    pad = sum(np.sin(2 * np.pi * note_hz(n) * t) for n in (72, 76, 79, 84))
    pad *= np.clip(t / 0.25, 0, 1) * np.exp(-t / 0.5)
    place(buf, pad * 0.25, 0.6)
    return finish(buf, -1, fade=0.15)


def sfx_claim():
    """Sparkle: a cascade of high bell pings."""
    buf = np.zeros(int(1.0 * SR))
    scale = [84, 86, 88, 91, 93, 96, 98, 100]
    rng = np.random.default_rng(7)
    for k in range(14):
        at = k * 0.045 + rng.uniform(0, 0.02)
        n = scale[min(len(scale) - 1, int(k / 14 * len(scale) + rng.integers(0, 2)))]
        place(buf, bell(note_hz(n), 0.5, decay=0.18) * (0.25 + 0.2 * rng.random()), at)
    return finish(buf, -2, fade=0.1)


def sfx_spawn():
    """Chick chirp: two fast upward warbles."""
    buf = np.zeros(int(0.36 * SR))
    for at, f0, f1 in ((0.0, 2600, 4200), (0.15, 2800, 4600)):
        d = 0.11
        t = t_axis(d)
        f = f0 + (f1 - f0) * (t / d) ** 0.7 + 220 * np.sin(2 * np.pi * 38 * t)
        s = np.sin(2 * np.pi * np.cumsum(f) / SR)
        s *= np.sin(np.pi * t / d) ** 1.5
        place(buf, s, at)
    return finish(buf, -4)


# ---------------------------------------------------------------- music loop
def music_loop():
    bpm = 80
    beat = 60 / bpm
    bar = beat * 4
    # C - Am - F - G, two bars each = 8 bars (24 s at 80 bpm)
    chords = [(48, (60, 64, 67)), (45, (57, 60, 64)), (41, (57, 60, 65)), (43, (59, 62, 67))]
    length = bar * 8
    n = int(length * SR)
    tail = int(3.0 * SR)
    buf = np.zeros(n + tail)

    for ci, (root, triad) in enumerate(chords):
        start = ci * bar * 2
        # warm pad: sine + a little 2nd harmonic, slow swell, per chord
        t = t_axis(bar * 2 + 1.0)
        pad = np.zeros_like(t)
        for k, m in enumerate(triad):
            f = note_hz(m)
            vib = 1 + 0.002 * np.sin(2 * np.pi * (4.5 + k * 0.3) * t)
            pad += np.sin(2 * np.pi * f * vib * t) + 0.15 * np.sin(4 * np.pi * f * t)
        envp = np.clip(t / 0.8, 0, 1) * np.clip((bar * 2 + 1.0 - t) / 1.0, 0, 1)
        place(buf, pad * envp * 0.07, start)
        # bass: root on beats 1 and 3
        for b in range(8):
            if b % 2 == 0:
                place(buf, pluck(note_hz(root), beat * 1.8, bright=3, decay=0.5) * 0.28, start + b * beat)
        # arpeggio: eighth notes up and down the triad an octave up
        pattern = [0, 1, 2, 1, 0, 2, 1, 2]
        for e in range(16):
            m = triad[pattern[e % 8]] + 12
            if e % 8 == 7:
                m = triad[0] + 24
            amp = 0.13 if e % 2 == 0 else 0.09
            place(buf, pluck(note_hz(m), 1.2, bright=4, decay=0.35) * amp, start + e * beat / 2)
        # little melody bell on the first beat of each chord
        place(buf, bell(note_hz(triad[2] + 12), 1.5, decay=0.5) * 0.06, start)
        place(buf, bell(note_hz(triad[1] + 12), 1.5, decay=0.5) * 0.05, start + bar + beat * 2)

    # wrap the tail into the start so the file loops without a click or gap
    out = buf[:n].copy()
    out[:tail] += buf[n:]
    out = out - np.mean(out)
    return out / np.max(np.abs(out)) * 10 ** (-6 / 20)


EFFECTS = {
    "click": sfx_click,
    "buy": sfx_buy,
    "coin": sfx_coin,
    "collect": sfx_collect,
    "deposit": sfx_deposit,
    "error": sfx_error,
    "rebirth": sfx_rebirth,
    "claim": sfx_claim,
    "spawn": sfx_spawn,
}


def main():
    for name, fn in EFFECTS.items():
        write(name, fn())
    write("music_loop", music_loop())


if __name__ == "__main__":
    main()
