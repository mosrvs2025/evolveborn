#!/usr/bin/env python3
"""Synthesises every sound in EVOLVEBORN. No sample libraries, no licences.

    python3 tools/make_audio.py

Writes 16-bit mono WAVs into audio/sfx and audio/music. Music loops are cut to
a whole number of bars so they repeat without a seam.
"""
import math, os, struct, wave
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SR = 22050
MSR = 16000          # music is lower rate; it is all low-passed pads anyway
rng = np.random.default_rng(20260921)

# --------------------------------------------------------------------------- #
# toolkit
# --------------------------------------------------------------------------- #
def t(n, sr=SR):
    return np.arange(n) / sr

def sine(freq, n, sr=SR, phase=0.0):
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * t(n, sr) + phase)
    ph = np.cumsum(2 * np.pi * np.asarray(freq) / sr)
    return np.sin(ph + phase)

def saw(freq, n, sr=SR):
    ph = np.cumsum(np.full(n, freq) / sr) if np.isscalar(freq) else np.cumsum(np.asarray(freq) / sr)
    return 2.0 * (ph % 1.0) - 1.0

def square(freq, n, sr=SR, duty=0.5):
    ph = np.cumsum(np.full(n, freq) / sr) if np.isscalar(freq) else np.cumsum(np.asarray(freq) / sr)
    return np.where((ph % 1.0) < duty, 1.0, -1.0)

def noise(n):
    return rng.uniform(-1.0, 1.0, n)

def env(n, attack=0.005, decay=0.2, sustain=0.0, release=0.1, sr=SR):
    a = max(1, int(attack * sr)); d = max(1, int(decay * sr)); r = max(1, int(release * sr))
    s = max(0, n - a - d - r)
    return np.concatenate([
        np.linspace(0, 1, a), np.linspace(1, sustain, d),
        np.full(s, sustain), np.linspace(sustain, 0, r)])[:n]

def expdec(n, k=6.0):
    return np.exp(-k * np.linspace(0, 1, n))

def sweep(f0, f1, n, sr=SR, curve=1.0):
    x = np.linspace(0, 1, n) ** curve
    return f0 + (f1 - f0) * x

def lowpass(x, cutoff, sr=SR):
    """One-pole, applied twice for a gentler slope."""
    a = math.exp(-2 * math.pi * cutoff / sr)
    out = np.empty_like(x); y = 0.0
    for i in range(len(x)):
        y = (1 - a) * x[i] + a * y
        out[i] = y
    y = 0.0
    for i in range(len(out)):
        y = (1 - a) * out[i] + a * y
        out[i] = y
    return out

def highpass(x, cutoff, sr=SR):
    return x - lowpass(x, cutoff, sr)

def delay(x, seconds, feedback=0.35, mix=0.3, sr=SR):
    d = int(seconds * sr)
    out = x.copy()
    if d <= 0 or d >= len(x):
        return out
    buf = np.zeros(len(x) + d)
    buf[:len(x)] = x
    for i in range(d, len(buf)):
        buf[i] += buf[i - d] * feedback
    return (1 - mix) * x + mix * buf[:len(x)]

def norm(x, peak=0.85):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 1e-9 else x

def fade(x, ms=6, sr=SR):
    n = min(len(x) // 2, int(ms * sr / 1000))
    if n <= 0:
        return x
    x = x.copy()
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x

def write(path, data, sr=SR):
    data = np.clip(norm(data), -1.0, 1.0)
    pcm = (data * 32767).astype("<i2")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(sr)
        f.writeframes(pcm.tobytes())

def secs(s, sr=SR):
    return int(s * sr)

# --------------------------------------------------------------------------- #
# sound effects
# --------------------------------------------------------------------------- #
def sfx_thump(dur=0.3, f0=180, f1=45, punch=1.0, noise_amt=0.3, cutoff=1400):
    n = secs(dur)
    body = sine(sweep(f0, f1, n, curve=0.35), n) * expdec(n, 5.0 / punch)
    crack = lowpass(noise(n), cutoff) * expdec(n, 22.0) * noise_amt
    return fade(body + crack)

def sfx_swish(dur=0.26, low=600, high=4200, back=False):
    n = secs(dur)
    f = sweep(high, low, n) if back else sweep(low, high, n)
    x = noise(n)
    out = np.zeros(n)
    # cheap band-pass sweep: difference of two moving low-passes
    out = lowpass(x, float(np.mean(f)) * 1.6) - lowpass(x, float(np.mean(f)) * 0.5)
    return fade(out * env(n, 0.02, 0.1, 0.35, 0.14))

def sfx_chime(freqs, dur=0.9, detune=1.0, decay=4.0):
    n = secs(dur)
    out = np.zeros(n)
    for i, f in enumerate(freqs):
        out += sine(f * detune, n) * expdec(n, decay + i) * (1.0 / (i + 1.6))
        out += sine(f * 2.01 * detune, n) * expdec(n, decay * 1.8 + i) * 0.22
    return fade(delay(out, 0.11, 0.3, 0.28))

def sfx_crackle(dur=0.4, density=0.35, tone=2600):
    n = secs(dur)
    imp = (rng.uniform(0, 1, n) < density / 30.0).astype(float) * rng.uniform(-1, 1, n)
    x = highpass(imp, 900) * 6.0
    x += sine(sweep(tone, tone * 0.4, n), n) * expdec(n, 10.0) * 0.4
    return fade(x * env(n, 0.002, 0.12, 0.3, 0.16))

def sfx_growl(dur=1.0, f0=70, f1=110, rough=0.5):
    n = secs(dur)
    base = saw(sweep(f0, f1, n), n)
    wob = 1.0 + rough * sine(np.full(n, 17.0), n)
    x = lowpass(base * wob, 900)
    x += lowpass(noise(n), 500) * 0.35
    return fade(x * env(n, 0.06, 0.3, 0.6, 0.3))

def sfx_squelch(dur=0.45, f0=320):
    n = secs(dur)
    x = lowpass(noise(n), 1200) * expdec(n, 7.0)
    x += sine(sweep(f0, f0 * 0.3, n), n) * expdec(n, 6.0) * 0.7
    return fade(x)

def sfx_blip(freq=880, dur=0.09, kind="sine"):
    n = secs(dur)
    w = sine(freq, n) if kind == "sine" else square(freq, n, duty=0.3)
    return fade(w * env(n, 0.004, 0.03, 0.4, 0.05), 3)

def sfx_voice(f0, f1, dur, rough, bright):
    n = secs(dur)
    x = square(sweep(f0, f1, n), n, duty=0.35 + rough * 0.2)
    x = lowpass(x, bright)
    x += noise(n) * rough * 0.3
    return fade(x * env(n, 0.01, dur * 0.35, 0.3, dur * 0.4))

SFX = {}
def put(name, data):
    SFX[name] = data

put("slam", sfx_thump(0.28, 210, 55, 1.0, 0.45))
put("bash", sfx_thump(0.38, 160, 40, 0.8, 0.6, 900))
put("slash", sfx_swish(0.22, 900, 5200))
put("burst", sfx_thump(0.24, 300, 90, 1.4, 0.55, 2600))
put("burst_move", sfx_swish(0.2, 500, 3200))
put("leap", sfx_swish(0.3, 400, 2600) * 0.8 + np.pad(sfx_thump(0.12, 260, 120, 1.5, 0.2), (0, secs(0.3) - secs(0.12))))
put("phase", sfx_swish(0.42, 2600, 500, back=True))
put("meteor", sfx_thump(0.9, 140, 28, 0.6, 0.8, 600))
put("flame", fade(lowpass(noise(secs(0.5)), 1800) * env(secs(0.5), 0.03, 0.2, 0.35, 0.24)))
put("flame_long", fade(lowpass(noise(secs(1.9)), 1500) * env(secs(1.9), 0.12, 0.3, 0.75, 0.5)))
put("arc", sfx_crackle(0.42, 0.5, 3200))
put("web", sfx_swish(0.24, 1400, 380, back=True) * 0.8 + sfx_squelch(0.24, 220) * 0.5)
put("spit", sfx_squelch(0.3, 420))
put("spore", fade(lowpass(noise(secs(0.6)), 900) * env(secs(0.6), 0.05, 0.25, 0.3, 0.3)))
put("quake", sfx_thump(1.2, 90, 22, 0.5, 0.7, 400))
put("sweep", sfx_swish(0.55, 300, 1800))
put("charge", sfx_growl(1.0, 60, 150, 0.6))
put("wave", sfx_thump(1.0, 120, 34, 0.5, 0.4, 500))
put("hit", sfx_thump(0.14, 420, 140, 1.6, 0.7, 3200))
put("hurt", sfx_thump(0.3, 380, 120, 1.0, 0.5, 2200) + np.pad(sfx_blip(300, 0.12), (0, secs(0.3) - secs(0.12))) * 0.4)
put("land", sfx_thump(0.2, 140, 50, 1.2, 0.35, 700))
put("death", sfx_growl(1.3, 160, 40, 0.4) * 0.8 + np.pad(sfx_squelch(0.6), (0, secs(1.3) - secs(0.6))) * 0.6)
put("creature_die", sfx_squelch(0.6, 260) + np.pad(sfx_blip(180, 0.2), (0, secs(0.6) - secs(0.2))) * 0.3)
put("devour_start", sfx_chime([330, 495], 0.5, 1.0, 6.0) * 0.5)
put("devour", norm(sfx_chime([262, 392, 523], 1.3, 1.0, 2.6) + np.pad(sfx_swish(0.8, 300, 2400), (secs(0.2), secs(1.3) - secs(0.8) - secs(0.2))) * 0.5))
put("trait_gain", sfx_chime([523, 659, 784, 1047], 1.2, 1.0, 3.0))
put("synergy", sfx_chime([440, 660, 880, 1320], 1.6, 1.0, 2.2))
put("evolve", norm(sfx_chime([131, 196, 262, 330, 392], 2.6, 1.0, 1.2) + sfx_thump(2.6, 90, 45, 0.4, 0.3, 500) * 0.8))
put("pool", sfx_chime([392, 587, 784], 1.8, 1.0, 2.0) * 0.8)
put("gate", norm(sfx_growl(1.4, 55, 58, 0.15) * 0.6 + sfx_chime([196, 294], 1.4, 1.0, 2.0) * 0.6))
put("secret", sfx_chime([659, 880, 1319], 1.4, 1.0, 2.6))
put("boss_windup", sfx_growl(0.9, 45, 95, 0.7))
put("boss_phase", norm(sfx_thump(1.6, 110, 25, 0.5, 0.8, 500) + sfx_growl(1.6, 50, 80, 0.8) * 0.7))
put("echo", sfx_blip(1320, 0.07, "square") * 0.7)
put("ui_select", sfx_blip(880, 0.08))
put("ui_back", sfx_blip(440, 0.09))
put("ui_deny", sfx_blip(196, 0.14, "square"))

VOICES = {
    "grazer": (220, 180, 0.5, 0.25, 900),
    "mite": (900, 1400, 0.16, 0.5, 4000),
    "shell": (140, 110, 0.55, 0.45, 700),
    "spore": (420, 300, 0.45, 0.6, 1400),
    "bat": (1600, 2400, 0.18, 0.3, 5200),
    "hopper": (520, 760, 0.22, 0.4, 2600),
    "eel": (700, 500, 0.3, 0.7, 3400),
    "crawler": (190, 150, 0.5, 0.6, 800),
    "toad": (150, 230, 0.6, 0.5, 900),
    "weaver": (620, 420, 0.35, 0.5, 2200),
    "sentinel": (95, 78, 1.1, 0.35, 520),
}
for name, (f0, f1, dur, rough, bright) in VOICES.items():
    put("voice_" + name, sfx_voice(f0, f1, dur, rough, bright))

# --------------------------------------------------------------------------- #
# music
# --------------------------------------------------------------------------- #
def note(semitone, base=110.0):
    return base * (2 ** (semitone / 12.0))

def pad(scale, bars, bpm, sr=MSR, base=110.0, bright=900, voices=3, detune=0.004):
    beats = bars * 4
    n = int(beats * 60.0 / bpm * sr)
    out = np.zeros(n)
    per = n // len(scale)
    for i, chord in enumerate(scale):
        seg = np.zeros(per)
        for j, st in enumerate(chord):
            f = note(st, base)
            for v in range(voices):
                seg += saw(f * (1 + detune * (v - 1)), per, sr) / (voices * len(chord))
        a = int(per * 0.25)
        e = np.concatenate([np.linspace(0, 1, a), np.linspace(1, 0.35, per - a)])
        out[i * per:(i + 1) * per] += seg * e
    return lowpass(out, bright, sr) * 0.8

def arp(seq, bars, bpm, sr=MSR, base=220.0, dur=0.18, bright=2600, amp=0.5):
    beats = bars * 4
    n = int(beats * 60.0 / bpm * sr)
    out = np.zeros(n)
    step = int(60.0 / bpm / 2 * sr)      # eighth notes
    for k in range(n // step):
        st = seq[k % len(seq)]
        if st is None:
            continue
        ln = min(int(dur * sr), n - k * step)
        w = sine(note(st, base), ln, sr) * 0.7 + square(note(st, base), ln, sr, 0.25) * 0.3
        out[k * step:k * step + ln] += lowpass(w, bright, sr) * expdec(ln, 5.0) * amp
    return out

def pulse(bars, bpm, sr=MSR, freq=55, every=2, amp=0.8):
    beats = bars * 4
    n = int(beats * 60.0 / bpm * sr)
    out = np.zeros(n)
    step = int(60.0 / bpm * sr) * every
    for k in range(n // step):
        ln = min(int(0.3 * sr), n - k * step)
        out[k * step:k * step + ln] += sine(sweep(freq * 2.2, freq, ln, sr, 0.4), ln, sr) \
            * expdec(ln, 6.0) * amp
    return out

def shimmer(bars, bpm, sr=MSR, density=0.7, base=440.0, scale=(0, 3, 5, 7, 10)):
    beats = bars * 4
    n = int(beats * 60.0 / bpm * sr)
    out = np.zeros(n)
    count = int(bars * density * 4)
    for _ in range(count):
        p = rng.integers(0, max(1, n - sr))
        ln = int(rng.uniform(0.5, 1.4) * sr)
        ln = min(ln, n - p)
        f = note(int(rng.choice(scale)) + 12 * int(rng.integers(0, 2)), base)
        out[p:p + ln] += sine(f, ln, sr) * expdec(ln, 3.5) * rng.uniform(0.1, 0.3)
    return out

MINOR = [(0, 3, 7), (-2, 3, 8), (-4, 3, 7), (-5, 0, 7)]
BRIGHT = [(0, 4, 7), (-3, 4, 9), (2, 5, 9), (-5, 2, 7)]
TENSE = [(0, 1, 7), (0, 3, 6), (-1, 2, 6), (-3, 1, 8)]

MUSIC = {}
def music(name, data, sr=MSR):
    MUSIC[name] = fade(norm(data, 0.7), 40, sr)

music("title", pad(MINOR, 8, 56, base=82.0, bright=700) * 0.9
	+ shimmer(8, 56, base=330.0) * 0.8)
music("explore_cave", pad(MINOR, 8, 52, base=73.0, bright=520) * 0.95
	+ shimmer(8, 52, density=0.45, base=392.0) * 0.55)
music("explore_grotto", pad(MINOR, 8, 64, base=87.0, bright=760) * 0.85
	+ arp([0, 3, 7, 10, 7, 3, None, 5], 8, 64, base=175.0, amp=0.32) * 0.9
	+ shimmer(8, 64, density=0.4, base=440.0) * 0.4)
music("explore_ruins", pad([(0, 3, 7), (-4, 3, 8), (-2, 5, 9), (-7, 0, 5)], 8, 48,
	base=69.0, bright=600) + shimmer(8, 48, density=0.55, base=294.0) * 0.7
	+ arp([0, None, 7, None, 3, None, None, None], 8, 48, base=147.0, amp=0.22))
music("explore_basin", pad(BRIGHT, 8, 72, base=98.0, bright=1100) * 0.85
	+ arp([0, 4, 7, 12, 7, 4, 9, 7], 8, 72, base=196.0, amp=0.28)
	+ pulse(8, 72, freq=49, every=2, amp=0.35))
music("danger", pad(TENSE, 6, 88, base=73.0, bright=620) * 0.9
	+ pulse(6, 88, freq=55, every=1, amp=0.6))
music("boss", pad(TENSE, 8, 104, base=61.0, bright=560) * 0.95
	+ pulse(8, 104, freq=41, every=1, amp=0.85)
	+ arp([0, 0, 6, 0, 1, 0, 6, 7], 8, 104, base=123.0, amp=0.3, bright=1800))
music("evolution", pad([(0, 4, 7), (2, 7, 11), (4, 9, 12), (7, 11, 16)], 4, 60,
	base=98.0, bright=1400) + shimmer(4, 60, density=1.6, base=523.0))
music("ending", pad([(0, 4, 7), (-3, 4, 9), (-5, 2, 7), (-1, 4, 7)], 8, 46,
	base=87.0, bright=1000) * 0.95 + shimmer(8, 46, density=0.6, base=349.0) * 0.8
	+ arp([0, None, 4, None, 7, None, 11, None], 8, 46, base=175.0, amp=0.2))

# --------------------------------------------------------------------------- #
if __name__ == "__main__":
    print("EVOLVEBORN audio synthesis")
    for name, data in SFX.items():
        write(os.path.join(ROOT, "audio", "sfx", name + ".wav"), data, SR)
    print("  %d effects" % len(SFX))
    for name, data in MUSIC.items():
        write(os.path.join(ROOT, "audio", "music", name + ".wav"), data, MSR)
    print("  %d music loops" % len(MUSIC))
    total = 0
    for d in ["sfx", "music"]:
        p = os.path.join(ROOT, "audio", d)
        total += sum(os.path.getsize(os.path.join(p, f)) for f in os.listdir(p))
    print("  %.1f MB total" % (total / 1048576.0))
