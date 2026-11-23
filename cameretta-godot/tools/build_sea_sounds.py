"""Suoni del giro in Vespa, sintetizzati da zero (nessuna registrazione): CC0.
Uso: python build_sea_sounds.py [cartella sounds]   (serve: pip install numpy soundfile)"""
import os, sys
import numpy as np, soundfile as sf
SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")
rng = np.random.default_rng(26)

def save(name, x, peak=.8):
    x = (x / (np.max(np.abs(x)) or 1) * peak).astype(np.float32)
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for a in range(0, len(x), 4096): f.write(x[a:a + 4096])


def band(x, lo, hi):
    """filtro circolare (FFT): i loop restano senza giunture"""
    f = np.fft.rfftfreq(len(x), 1 / SR); X = np.fft.rfft(x)
    X *= (1 / (1 + (f / hi) ** 4)) * (f ** 2 / (f ** 2 + lo ** 2))
    return np.fft.irfft(X, len(x))

def t(sec): return np.arange(int(sec * SR)) / SR

def putt(n, power, bright):
    """uno scoppio del due tempi"""
    tt = np.arange(n) / SR
    x = np.sin(2 * np.pi * (95 * tt + 26 * np.exp(-tt * 60) / 60)) * np.exp(-tt * 55)
    x += .45 * np.sin(2 * np.pi * 188 * tt + .4) * np.exp(-tt * 75) + bright * rng.normal(0, 1, n) * np.exp(-tt * 210)
    return x * power

# motore: 26 scoppi al secondo, loop esatto di 2 secondi
L = 2 * SR; eng = np.zeros(L); cnt = 52; step = L / cnt
for k in range(cnt):
    b = putt(int(.09 * SR), 1 + rng.normal(0, .07) - (.16 if k % 4 == 3 else 0), .35)
    at = int(k * step + rng.normal(0, 22)) % L
    idx = (at + np.arange(len(b))) % L; eng[idx] += b
eng += .05 * band(rng.normal(0, 1, L), 900, 3200) * (1 + .5 * np.sin(2 * np.pi * 26 * np.arange(L) / SR))
save("engine_loop", band(eng, 45, 3600), .75)

# pedivella: scatto metallico, frizione, due scoppi che non prendono
def kick(n_putt):
    x = np.zeros(int(.75 * SR)); tt = t(.75)
    for f, d, g in ((1320, 70, .25), (2110, 95, .18), (760, 40, .3)): x += g * np.sin(2 * np.pi * f * tt) * np.exp(-tt * d)
    w = band(rng.normal(0, 1, len(x)), 200, 1500); env = np.exp(-((tt - .16) / .09) ** 2); x += w * env * 2.2 * (1 + .7 * np.sign(np.sin(2 * np.pi * 34 * tt)))
    for k in range(n_putt):
        b = putt(int(.1 * SR), .9 * .7 ** k, .4); a = int((.26 + k * .085) * SR); x[a:a + len(b)] += b
    x[-2000:] *= np.linspace(1, 0, 2000); return x
save("vespa_kick", kick(2), .7)
x = np.concatenate([kick(1)[:int(.26 * SR)], np.zeros(int(1.5 * SR))]); pos = .26
for k in range(34):                                         # parte, sgasa e si calma
    b = putt(int(.09 * SR), .8 + .5 * np.exp(-((k - 9) / 7) ** 2), .5); a = int(pos * SR)
    if a + len(b) < len(x): x[a:a + len(b)] += b
    pos += .062 - .036 * np.exp(-((k - 11) / 8) ** 2)
x[-9000:] *= np.linspace(1, 0, 9000); save("vespa_start", band(x, 40, 5000), .8)
x = np.zeros(int(.9 * SR)); pos = 0                         # si spegne
for k in range(11):
    b = putt(int(.1 * SR), .9 * .86 ** k, .25); a = int(pos * SR)
    if a + len(b) < len(x): x[a:a + len(b)] += b
    pos += .038 + .009 * k
save("vespa_stop", x, .55)

# clacson: due note leggermente stonate, nasali
def horn(sec):
    tt = t(sec); x = np.zeros(len(tt))
    for f in (392, 396.5, 494):
        for h in range(1, 9): x += np.sin(2 * np.pi * f * h * tt + h) / h ** .8 * (1 if f < 450 else .4)
    e = np.minimum(1, tt / .012) * np.minimum(1, (sec - tt) / .05); return band(x * e, 350, 3000)
save("horn", np.concatenate([horn(.13), np.zeros(int(.06 * SR)), horn(.24)]), .5)

# casco: fruscio e clic del cinturino
tt = t(.42); x = band(rng.normal(0, 1, len(tt)), 300, 2400) * (np.exp(-((tt - .1) / .05) ** 2) * 1.4)
for a, f in ((.26, 1800), (.285, 2500)):
    q = np.clip(tt - a, 0, None); x += (tt > a) * np.sin(2 * np.pi * f * q) * np.exp(-q * 130) * .8
save("helmet", x, .6)

# risacca: tre onde che si rincorrono in 16 secondi, loop
L = 16 * SR; tt = np.arange(L) / SR; n = rng.normal(0, 1, L); lo, hi = band(n, 60, 420), band(rng.normal(0, 1, L), 700, 5200)
w = np.zeros(L); lo /= lo.std(); hi /= hi.std()
for c, wd, g in ((2.5, 1.5, 1.0), (8.1, 1.8, .85), (13.2, 1.4, .95)):
    d = (tt - c + 8) % 16 - 8
    rise = np.where(d < 0, np.exp(-(d / wd) ** 2), np.exp(-d / (wd * 1.1)))
    d2 = (tt - c - .55 + 8) % 16 - 8
    fiz = np.where(d2 < 0, np.exp(-(d2 / .45) ** 2), np.exp(-d2 / (wd * 1.5)))
    w += g * (lo * rise * .8 + hi * fiz * .42)
w += lo * .12 + hi * .035; save("waves_loop", w, .7)

# gabbiano: tre versi discendenti
def cry(sec, f0, f1):
    tt = t(sec); u = tt / sec; f = f0 + (f1 - f0) * u ** .7 + 90 * np.sin(np.pi * u); ph = 2 * np.pi * np.cumsum(f) / SR
    x = sum(np.sin(ph * h + .3 * np.sin(2 * np.pi * 31 * tt)) / h ** 1.15 for h in range(1, 6)); return x * np.sin(np.pi * np.clip(u, 0, 1)) ** .6
save("gull", np.concatenate([cry(.34, 1250, 900), np.zeros(2400), cry(.24, 1180, 880), np.zeros(1800), cry(.2, 1120, 840), np.zeros(2000)]), .4)

# la tappa che spunta dalla neve: tonfo morbido e due note
tt = t(.55); x = band(rng.normal(0, 1, len(tt)), 120, 1600) * np.exp(-tt * 22) * 1.1
for a, f in ((.06, 659.3), (.15, 987.8)):
    q = np.clip(tt - a, 0, None); x += (tt > a) * (np.sin(2 * np.pi * f * q) + .35 * np.sin(2 * np.pi * 2 * f * q)) * np.exp(-q * 9) * .5
x[-3000:] *= np.linspace(1, 0, 3000); save("stop_pop", x, .6)

# freni sulla neve
tt = t(.5); x = band(rng.normal(0, 1, len(tt)), 500, 3000) * np.exp(-((tt - .12) / .16) ** 2); save("brake_snow", x, .4)
print("ok")
