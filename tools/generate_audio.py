#!/usr/bin/env python3
"""MYCELIA procedural audio generator.

Synthesizes every sound effect, ambience loop and music loop used by the game
into assets/audio/*.wav (16-bit mono). All audio is original, generated from
math only, so the project ships with no third-party audio licenses.

Usage:  python3 tools/generate_audio.py
Requires: numpy
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(20261029)


# ---------------------------------------------------------------- helpers
def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env_adsr(n, a=0.01, d=0.1, s=0.6, r=0.2):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([
        np.linspace(0, 1, max(a_n, 1)),
        np.linspace(1, s, max(d_n, 1)),
        np.full(s_n, s),
        np.linspace(s, 0, max(r_n, 1)),
    ])
    return np.pad(e, (0, max(0, n - len(e))))[:n]


def env_exp(n, decay):
    return np.exp(-np.arange(n) / SR / decay)


def lowpass(x, cutoff):
    # One-pole low pass; cutoff may be scalar or array.
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = 1.0 - np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def noise(n):
    return rng.uniform(-1, 1, n)


def sine(freq, dur, phase=0.0):
    t = t_axis(dur)
    if np.ndim(freq) == 0:
        return np.sin(2 * np.pi * freq * t + phase)
    ph = 2 * np.pi * np.cumsum(freq) / SR
    return np.sin(ph + phase)


def fm_bell(freq, dur, ratio=3.5, index=2.5, decay=0.6):
    t = t_axis(dur)
    mod_env = env_exp(len(t), decay * 0.5)
    mod = np.sin(2 * np.pi * freq * ratio * t) * index * mod_env
    return np.sin(2 * np.pi * freq * t + mod) * env_exp(len(t), decay)


def pluck(freq, dur, bright=0.5):
    # Karplus-Strong string.
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    buf = noise(period) * 0.8
    out = np.zeros(n)
    damp = 0.994 - (1 - bright) * 0.01
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out


def reverb(x, seconds=1.8, mix=0.35, damp=3000):
    n_ir = int(seconds * SR)
    ir = noise(n_ir) * np.exp(-np.arange(n_ir) / SR / (seconds / 5.0))
    ir = lowpass(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    size = 1
    while size < len(x) + n_ir:
        size *= 2
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + n_ir]
    dry = np.pad(x, (0, n_ir))
    return dry * (1 - mix) + wet * mix


def loopify(x, loop_len):
    """Fold the tail beyond loop_len back to the start for a seamless loop."""
    n = int(loop_len * SR)
    out = x[:n].copy()
    tail = x[n:]
    while len(tail) > 0:
        k = min(len(tail), n)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def write(name, x, peak=0.85, do_fade=True):
    x = normalize(np.asarray(x, dtype=float), peak)
    if do_fade:
        x = fade(x)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {name}.wav  {len(x) / SR:.2f}s")


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def add(*sigs):
    n = max(len(x) for x in sigs)
    out = np.zeros(n)
    for x in sigs:
        out[: len(x)] += x
    return out


def mix_at(buf, sig, start):
    i = int(start * SR)
    end = min(len(buf), i + len(sig))
    if end > i:
        buf[i:end] += sig[: end - i]


# ---------------------------------------------------------------- UI
def ui_sounds():
    n = int(0.08 * SR)
    f = np.linspace(1400, 900, n)
    write("ui_click", sine(f, 0.08) * env_exp(n, 0.02), 0.6)
    n = int(0.06 * SR)
    write("ui_hover", sine(np.linspace(1800, 2000, n), 0.06) * env_exp(n, 0.015), 0.35)
    x = fm_bell(note(84), 0.5, 2.0, 1.2, 0.25) + fm_bell(note(91), 0.5, 2.0, 1.0, 0.2) * 0.6
    write("ui_open", reverb(x, 0.8, 0.3), 0.5)
    x = fm_bell(note(79), 0.4, 2.0, 1.0, 0.2) + fm_bell(note(72), 0.4, 2.0, 0.8, 0.2) * 0.6
    write("ui_close", reverb(x, 0.6, 0.3), 0.45)
    n = int(0.25 * SR)
    sq = np.sign(sine(np.linspace(220, 160, n), 0.25)) * env_exp(n, 0.08)
    write("ui_error", lowpass(sq, 1800), 0.45)


# ---------------------------------------------------------------- world
def world_sounds():
    # Soft mossy footstep.
    n = int(0.16 * SR)
    x = lowpass(noise(n), np.linspace(900, 250, n)) * env_exp(n, 0.035)
    x += sine(np.linspace(140, 70, n), 0.16) * env_exp(n, 0.03) * 0.5
    write("footstep", x, 0.6)
    n = int(0.25 * SR)
    x = lowpass(noise(n), 1200) * env_exp(n, 0.05) * 0.5 + sine(np.linspace(300, 520, n), 0.25) * env_exp(n, 0.08) * 0.4
    write("jump", x, 0.45)
    n = int(0.3 * SR)
    x = lowpass(noise(n), np.linspace(700, 150, n)) * env_exp(n, 0.06) + sine(np.linspace(110, 50, n), 0.3) * env_exp(n, 0.07)
    write("land", x, 0.7)
    # Pickup: bright rising arpeggio.
    buf = np.zeros(int(1.2 * SR))
    for i, m in enumerate([76, 81, 88, 93]):
        mix_at(buf, fm_bell(note(m), 0.6, 3.0, 1.5, 0.25), i * 0.06)
    write("pickup", reverb(buf, 1.2, 0.35), 0.6)
    buf = np.zeros(int(1.0 * SR))
    for i, m in enumerate([69, 76]):
        mix_at(buf, fm_bell(note(m), 0.8, 1.5, 2.0, 0.4), i * 0.1)
    write("inspect", reverb(buf, 1.5, 0.45), 0.5)
    # Mechanism: deep stone hum swelling with harmonics.
    dur = 2.4
    t = t_axis(dur)
    hum = sum(np.sin(2 * np.pi * f * t) / (k + 1) for k, f in enumerate([55, 110, 165, 247.5, 330]))
    hum *= env_adsr(len(t), 0.3, 0.6, 0.7, 1.2) * (1 + 0.3 * np.sin(2 * np.pi * 5 * t))
    hum += lowpass(noise(len(t)), 400) * env_adsr(len(t), 0.05, 0.5, 0.3, 1.0) * 0.6
    write("mechanism", reverb(hum, 2.0, 0.4), 0.75)
    n = int(0.5 * SR)
    x = lowpass(noise(n), 500) * env_exp(n, 0.06) + sine(np.linspace(90, 70, n), 0.5) * env_exp(n, 0.12)
    write("locked", x, 0.6)
    # Discovery: shimmering chord swell.
    dur = 3.0
    buf = np.zeros(int(dur * SR))
    for i, m in enumerate([62, 69, 74, 78, 81, 86]):
        tone = fm_bell(note(m), 2.6, 2.0, 1.0, 1.4) * 0.6
        mix_at(buf, tone, i * 0.09)
    write("discovery", reverb(buf, 2.5, 0.5), 0.6)
    n = int(0.6 * SR)
    f = np.linspace(180, 620, n)
    x = sine(f, 0.6) * env_exp(n, 0.2) + lowpass(noise(n), 800) * env_exp(n, 0.04) * 0.4
    write("bounce", x, 0.6)
    buf = np.zeros(int(2.0 * SR))
    for i, m in enumerate([72, 76, 79, 84]):
        mix_at(buf, sine(note(m), 1.5) * env_adsr(int(1.5 * SR), 0.2, 0.4, 0.5, 0.8) * 0.4, i * 0.12)
    write("heal", reverb(buf, 1.8, 0.5), 0.55)
    buf = np.zeros(int(1.8 * SR))
    for i, m in enumerate([67, 74, 79]):
        mix_at(buf, fm_bell(note(m), 1.2, 2.0, 1.4, 0.6), i * 0.14)
    write("quest", reverb(buf, 1.6, 0.4), 0.6)
    buf = np.zeros(int(1.0 * SR))
    for i, m in enumerate([79, 86]):
        mix_at(buf, fm_bell(note(m), 0.7, 3.0, 1.2, 0.3), i * 0.08)
    write("objective", reverb(buf, 1.0, 0.35), 0.5)
    buf = np.zeros(int(3.2 * SR))
    for i, m in enumerate([60, 64, 67, 72, 76, 79, 84]):
        mix_at(buf, fm_bell(note(m), 2.0, 2.0, 1.6, 0.9) * 0.7, i * 0.1)
    write("quest_complete", reverb(buf, 2.2, 0.45), 0.65)
    buf = np.zeros(int(3.0 * SR))
    for i, m in enumerate([60, 67, 72, 76, 79, 84, 88]):
        mix_at(buf, pluck(note(m), 1.6, 0.8) * 0.6 + fm_bell(note(m + 12), 1.6, 2.0, 0.8, 0.8) * 0.3, i * 0.07)
    write("level_up", reverb(buf, 2.0, 0.45), 0.65)


# ---------------------------------------------------------------- combat
def combat_sounds():
    # Fungal: soft pop + spore puff.
    n = int(0.7 * SR)
    x = sine(np.linspace(260, 90, n), 0.7) * env_exp(n, 0.08)
    x += lowpass(noise(n), np.linspace(2500, 300, n)) * env_adsr(n, 0.05, 0.2, 0.3, 0.4) * 0.6
    write("cast_fungal", reverb(x, 0.8, 0.3), 0.7)
    n = int(0.6 * SR)
    x = lowpass(noise(n), np.linspace(1800, 200, n)) * env_exp(n, 0.12) + sine(np.linspace(120, 50, n), 0.6) * env_exp(n, 0.1)
    write("impact_fungal", x, 0.8)
    # Crystal: glassy FM tinkles.
    buf = np.zeros(int(1.0 * SR))
    for i in range(6):
        mix_at(buf, fm_bell(note(88 + rng.integers(-5, 6)), 0.5, 3.7, 2.0, 0.15) * 0.5, i * 0.04)
    write("cast_crystal", reverb(buf, 1.0, 0.35), 0.6)
    n = int(0.7 * SR)
    x = highpass(noise(n), 2500) * env_exp(n, 0.06)
    for i in range(5):
        x[: int(0.5 * SR)] += fm_bell(note(84 + rng.integers(0, 12)), 0.5, 4.1, 3.0, 0.08) * 0.4
    write("impact_crystal", reverb(x, 0.8, 0.25), 0.7)
    # Nature: rustling sweep + woody tone.
    n = int(0.9 * SR)
    rustle = highpass(lowpass(noise(n), 4000), 800) * env_adsr(n, 0.15, 0.3, 0.5, 0.3) * (0.6 + 0.4 * np.sin(np.arange(n) / SR * 2 * np.pi * 14))
    x = rustle * 0.6 + pluck(note(55), 0.9, 0.3) * 0.7
    write("cast_nature", reverb(x, 0.9, 0.3), 0.7)
    n = int(0.5 * SR)
    x = lowpass(noise(n), 1500) * env_exp(n, 0.05) + pluck(note(43), 0.5, 0.2)
    write("impact_nature", x, 0.75)
    # Cosmic: rising sweep with shimmer.
    n = int(1.2 * SR)
    f = np.geomspace(200, 1600, n)
    x = sine(f, 1.2) * env_adsr(n, 0.3, 0.3, 0.6, 0.4) * 0.6
    x += sum(sine(f * k, 1.2) * 0.15 / k for k in (1.5, 2.0, 3.0)) * env_adsr(n, 0.4, 0.2, 0.5, 0.4)
    write("cast_cosmic", reverb(x, 1.6, 0.45), 0.6)
    n = int(1.0 * SR)
    x = sine(np.linspace(90, 35, n), 1.0) * env_exp(n, 0.25) + lowpass(noise(n), 3000) * env_exp(n, 0.1) * 0.7
    write("impact_cosmic", reverb(x, 1.2, 0.3), 0.85)
    # Chaos: detuned glitchy arps.
    buf = np.zeros(int(1.0 * SR))
    for i in range(10):
        m = 60 + rng.integers(0, 30)
        tone = np.sign(sine(note(m) * (1 + rng.uniform(-0.03, 0.03)), 0.12)) * env_exp(int(0.12 * SR), 0.04)
        mix_at(buf, lowpass(tone, 3000) * 0.4, i * 0.07)
    write("cast_chaos", reverb(buf, 1.0, 0.35), 0.6)
    n = int(0.7 * SR)
    t = t_axis(0.7)
    x = np.sin(2 * np.pi * 80 * t + 6 * np.sin(2 * np.pi * 37 * t)) * env_exp(n, 0.15) + noise(n) * env_exp(n, 0.05) * 0.5
    write("impact_chaos", x, 0.75)
    n = int(0.25 * SR)
    write("hit", lowpass(noise(n), 1200) * env_exp(n, 0.04) + sine(np.linspace(200, 80, n), 0.25) * env_exp(n, 0.05), 0.7)
    buf = fm_bell(note(76), 1.2, 1.0, 0.5, 0.6) + fm_bell(note(83), 1.2, 1.0, 0.5, 0.5) * 0.6
    write("shield", reverb(buf, 1.2, 0.4), 0.55)
    n = int(0.35 * SR)
    write("miss", highpass(noise(n), 1500) * env_adsr(n, 0.08, 0.1, 0.4, 0.15) * 0.6, 0.4)
    n = int(0.12 * SR)
    write("card_draw", highpass(noise(n), 3000) * env_exp(n, 0.03), 0.3)
    write("card_select", fm_bell(note(86), 0.25, 2.0, 1.0, 0.08), 0.4)
    n = int(0.5 * SR)
    write("enemy_attack", lowpass(noise(n), np.linspace(400, 2400, n)) * env_adsr(n, 0.2, 0.1, 0.5, 0.15), 0.6)
    write("turn", reverb(fm_bell(note(74), 0.6, 2.0, 0.8, 0.3) * 0.6, 0.8, 0.3), 0.4)
    buf = np.zeros(int(3.5 * SR))
    for i, m in enumerate([67, 71, 74, 79, 83, 86]):
        mix_at(buf, fm_bell(note(m), 2.5, 2.0, 1.4, 1.2) * 0.6 + pluck(note(m - 12), 2.5, 0.7) * 0.3, i * 0.11)
    write("victory", reverb(buf, 2.5, 0.45), 0.7)
    buf = np.zeros(int(3.5 * SR))
    for i, m in enumerate([62, 58, 55, 50]):
        mix_at(buf, sine(note(m), 1.6) * env_adsr(int(1.6 * SR), 0.1, 0.4, 0.5, 0.8) * 0.5, i * 0.4)
    write("defeat", reverb(buf, 2.5, 0.5), 0.6)
    # Creature voices.
    n = int(0.3 * SR)
    f = 900 + 400 * np.sin(np.arange(n) / SR * 2 * np.pi * 18)
    write("sporeling_chirp", sine(f, 0.3) * env_adsr(n, 0.02, 0.1, 0.5, 0.1), 0.45)
    buf = np.zeros(int(0.4 * SR))
    for i in range(4):
        k = int(0.02 * SR)
        mix_at(buf, highpass(noise(k), 2000) * env_exp(k, 0.005), i * 0.07)
    write("beetle_click", buf, 0.5)
    n = int(0.35 * SR)
    write("fox_yip", sine(np.linspace(700, 1300, n) * (1 + 0.02 * np.sin(np.arange(n) / SR * 2 * np.pi * 30)), 0.35) * env_adsr(n, 0.02, 0.1, 0.4, 0.15), 0.45)
    n = int(1.2 * SR)
    write("guardian_groan", lowpass(sine(np.linspace(110, 80, n), 1.2) + 0.5 * sine(np.linspace(165, 120, n), 1.2), 900) * env_adsr(n, 0.2, 0.3, 0.6, 0.4), 0.6)
    n = int(1.8 * SR)
    write("golem_rumble", lowpass(noise(n), 180) * env_adsr(n, 0.3, 0.3, 0.8, 0.6) + sine(np.linspace(45, 38, n), 1.8) * env_adsr(n, 0.3, 0.3, 0.7, 0.6) * 0.6, 0.85)


# ---------------------------------------------------------------- loops
def ambience():
    dur = 20.0
    n = int(dur * SR)
    t = t_axis(dur)
    # Wind: slowly modulated filtered noise (loop-continuous modulation).
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / dur * 2)
    wind = lowpass(noise(n), 300 + 500 * lfo) * (0.35 + 0.4 * lfo)
    # Magical humming: just-intonation drone; frequencies with integer cycles per loop.
    hum = np.zeros(n)
    for f, a in [(110.0, 0.25), (165.0, 0.18), (220.0, 0.12), (275.0, 0.08), (330.0, 0.06)]:
        f = round(f * dur) / dur
        hum += np.sin(2 * np.pi * f * t) * a * (0.6 + 0.4 * np.sin(2 * np.pi * t / dur * (1 + a * 4)))
    buf = wind * 0.7 + hum * 0.5
    # Distant chimes and creature trills.
    chimes = np.zeros(n + int(3 * SR))
    for _ in range(9):
        start = rng.uniform(0, dur)
        m = rng.choice([81, 84, 86, 88, 91, 93])
        mix_at(chimes, fm_bell(note(m), 2.0, 3.0, 1.0, 0.9) * 0.18, start)
    for _ in range(5):
        start = rng.uniform(0, dur)
        k = int(0.25 * SR)
        f = 1800 + 600 * np.sin(np.arange(k) / SR * 2 * np.pi * 25)
        mix_at(chimes, sine(f, 0.25) * env_adsr(k, 0.02, 0.1, 0.4, 0.1) * 0.06, start)
    chimes = loopify(reverb(chimes, 2.5, 0.6), dur)
    write("meadow_ambience", buf + chimes[:n], 0.6, do_fade=False)


def chord_pad(midis, dur, amp=0.15):
    t = t_axis(dur)
    out = np.zeros(len(t))
    for m in midis:
        f = note(m)
        for det in (-0.004, 0.0, 0.004):
            out += np.sin(2 * np.pi * f * (1 + det) * t + rng.uniform(0, 6.28)) * amp / 3
    return out * env_adsr(len(t), dur * 0.3, dur * 0.2, 0.8, dur * 0.35)


def music_meadow():
    bpm = 72
    beat = 60.0 / bpm
    bars = 16
    dur = bars * 4 * beat
    n = int(dur * SR)
    buf = np.zeros(n + int(4 * SR))
    # Dreamy progression in D Lydian-ish.
    prog = [[50, 57, 62, 66, 69], [52, 59, 64, 67, 71], [47, 54, 59, 62, 66], [48, 55, 60, 64, 67]]
    for bar in range(bars):
        ch = prog[(bar // 2) % len(prog)]
        if bar % 2 == 0:
            mix_at(buf, chord_pad(ch, beat * 8.5, 0.16), bar * 4 * beat)
        scale = [62, 64, 66, 69, 71, 74, 76, 78, 81]
        for step in range(8):
            if rng.random() < 0.55:
                m = scale[rng.integers(0, len(scale))]
                tm = (bar * 8 + step) * beat * 0.5
                mix_at(buf, add(pluck(note(m), 1.8, 0.65) * 0.22, fm_bell(note(m + 12), 1.2, 2.0, 0.6, 0.6) * 0.06), tm)
        mix_at(buf, pluck(note(ch[0] - 12), 3.0, 0.3) * 0.25, bar * 4 * beat)
    buf = reverb(buf, 3.2, 0.5)
    write("music_meadow", loopify(buf, dur), 0.55, do_fade=False)


def music_menu():
    dur = 24.0
    n = int(dur * SR)
    buf = np.zeros(n + int(4 * SR))
    prog = [[45, 52, 57, 60, 64, 71], [41, 48, 53, 57, 64, 67], [43, 50, 55, 59, 62, 69], [40, 47, 52, 55, 59, 66]]
    for i, ch in enumerate(prog):
        mix_at(buf, chord_pad(ch, 7.5, 0.18), i * 6.0)
        for k in range(6):
            m = ch[rng.integers(2, len(ch))] + 12
            mix_at(buf, fm_bell(note(m), 3.0, 2.0, 0.8, 1.6) * 0.07, i * 6.0 + k * 1.0 + rng.uniform(0, 0.3))
    buf = reverb(buf, 4.0, 0.6)
    write("music_menu", loopify(buf, dur), 0.55, do_fade=False)


def music_combat(name="music_combat", root=45, tempo=118, boss=False):
    beat = 60.0 / tempo
    bars = 8
    dur = bars * 4 * beat
    n = int(dur * SR)
    buf = np.zeros(n + int(3 * SR))
    prog = [0, 0, 3, 3, 5, 5, 2, 7] if not boss else [0, 1, 0, 1, 5, 6, 3, 7]
    for bar in range(bars):
        r = root + prog[bar]
        for s in range(16):
            tm = (bar * 16 + s) * beat / 4
            if s % 4 == 0:
                k = int(0.25 * SR)
                kick = sine(np.linspace(120, 40, k), 0.25) * env_exp(k, 0.08)
                mix_at(buf, kick * 0.6, tm)
            if s % 8 == 4:
                k = int(0.2 * SR)
                mix_at(buf, highpass(noise(k), 1200) * env_exp(k, 0.05) * 0.25, tm)
            if s % 2 == 1:
                k = int(0.05 * SR)
                mix_at(buf, highpass(noise(k), 6000) * env_exp(k, 0.01) * 0.08, tm)
            # Arp.
            arp = [0, 7, 12, 15, 19, 15, 12, 7]
            m = r + 12 + arp[s % 8] + (1 if boss and s % 5 == 0 else 0)
            mix_at(buf, pluck(note(m), 0.4, 0.8) * 0.12, tm)
        k = int(beat * 4 * SR)
        bass = lowpass(np.sign(sine(note(r - 12), beat * 4)), 500) * env_adsr(k, 0.01, 0.2, 0.7, 0.2) * 0.18
        mix_at(buf, bass, bar * 4 * beat)
        if bar % 2 == 0:
            mix_at(buf, chord_pad([r + 12, r + 15, r + 19, r + 24], beat * 8, 0.09), bar * 4 * beat)
    buf = reverb(buf, 1.6, 0.3)
    write(name, loopify(buf, dur), 0.6, do_fade=False)


if __name__ == "__main__":
    print("Generating MYCELIA audio into", os.path.abspath(OUT))
    ui_sounds()
    world_sounds()
    combat_sounds()
    ambience()
    music_menu()
    music_meadow()
    music_combat()
    music_combat("music_boss", root=40, tempo=128, boss=True)
    print("done")
