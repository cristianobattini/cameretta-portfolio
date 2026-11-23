"""Le stazioni della radio della Vespa, composte e sintetizzate da zero: CC0.
Uso: python build_radio.py [cartella sounds]   (serve: pip install numpy soundfile)"""
import os, sys
import numpy as np, soundfile as sf
SR = 32000
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")
rng = np.random.default_rng(984)
def save(name, x, peak):
    x = (x / np.max(np.abs(x)) * peak).astype(np.float32)
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", SR, 1, format="OGG", subtype="VORBIS", compression_level=.75) as f:
        for a in range(0, len(x), 4096): f.write(x[a:a + 4096])
hz = lambda m: 440 * 2 ** ((m - 69) / 12)
def add(buf, at, s, g=1.0):
    """somma con riavvolgimento: il giro si chiude senza stacchi"""
    i = (int(at * SR) + np.arange(len(s))) % len(buf); np.add.at(buf, i, s * g)
def tone(f, d, kind, a=.01, r=.2):
    t = np.arange(int((d + r) * SR)) / SR; env = np.clip(t / a, 0, 1) * np.where(t < d, 1, np.exp(-(t - d) / r * 4))
    if kind == "ep": x = (np.sin(2 * np.pi * f * t + 1.1 * np.exp(-t * 4) * np.sin(2 * np.pi * 2 * f * t)) + .15 * np.sin(2 * np.pi * f * 1.003 * t)) * np.exp(-t * 1.1)
    elif kind == "bass": x = np.sin(2 * np.pi * f * t) + .25 * np.sin(4 * np.pi * f * t)
    elif kind == "pluck": x = sum(np.sin(2 * np.pi * f * h * t) * np.exp(-t * (3 + h * 2.2)) / h for h in range(1, 7))
    elif kind == "saw": x = sum(np.sin(2 * np.pi * f * h * t * (1 + .001 * (h % 2))) / h for h in range(1, 9)) * .5
    return x * env
def noise(d, k, lo=.0):
    t = np.arange(int(d * SR)) / SR; n = rng.normal(0, 1, len(t)); n = n - np.convolve(n, np.ones(6) / 6, "same") * lo; return n * np.exp(-t * k)
def kick(): t = np.arange(int(.3 * SR)) / SR; return np.sin(2 * np.pi * (48 * t + 70 * (1 - np.exp(-t * 34)) / 34)) * np.exp(-t * 11)
def track(bpm, bars, chords, fn, swing=0.0):
    b = 60 / bpm; buf = np.zeros(int(b * 4 * bars * SR)); fn(buf, b, bars, chords, swing); return buf
def lofi(buf, b, bars, ch, sw):
    for k in range(bars):
        c = ch[k % len(ch)]; t0 = k * 4 * b
        for j, n in enumerate(c): add(buf, t0 + j * .018, tone(hz(n), 3.4 * b, "ep", .01, .5), .22); add(buf, t0 + 2.5 * b + j * .012, tone(hz(n), .9 * b, "ep"), .1)
        add(buf, t0, tone(hz(c[0] - 24), 1.4 * b, "bass"), .5); add(buf, t0 + 2.5 * b, tone(hz(c[0] - 24), 1.0 * b, "bass"), .4)
        for q in (0, 2.5): add(buf, t0 + q * b, kick(), .8)
        for q in (1, 3): add(buf, t0 + q * b + .01, noise(.2, 22, .4), .22)
        for q in range(8): add(buf, t0 + (q * .5 + (sw if q % 2 else 0)) * b, noise(.06, 70, .95), .07 + .03 * (q % 2 == 0))
        for q, d in ((.5, 4), (1.75, 2), (3, 3)): 
            if (k + int(q * 4)) % 3: add(buf, t0 + q * b, tone(hz(c[d % len(c)] + 12), .4 * b, "pluck"), .16)
    buf += .012 * np.convolve(rng.normal(0, 1, len(buf)), np.ones(5) / 5, "same")
def synth(buf, b, bars, ch, sw):
    for k in range(bars):
        c = ch[k % len(ch)]; t0 = k * 4 * b
        for n in c: add(buf, t0, tone(hz(n), 3.9 * b, "saw", .3, .6), .07)
        for q in range(8): add(buf, t0 + q * .5 * b, tone(hz(c[0] - 24), .35 * b, "saw", .005, .08), .3)
        for q in range(16): add(buf, t0 + q * .25 * b, tone(hz(c[(q * 3) % len(c)] + 12 + 12 * (q % 8 > 5)), .16 * b, "pluck", .004, .1), .16)
        for q in range(4): add(buf, t0 + q * b, kick(), .75)
        for q in (1, 3): add(buf, t0 + q * b, noise(.28, 15, .3), .26)
def bossa(buf, b, bars, ch, sw):
    for k in range(bars):
        c = ch[k % len(ch)]; t0 = k * 4 * b
        for q in (0, .75, 1.5, 2.5, 3.25):
            for j, n in enumerate(c[1:]): add(buf, t0 + q * b + j * .008, tone(hz(n), .5 * b, "pluck", .004, .2), .2)
        for q, n in ((0, 0), (1.5, 7), (2, 7), (3.5, 0)): add(buf, t0 + q * b, tone(hz(c[0] - 24 + n), .45 * b, "bass"), .45)
        for q in range(8): add(buf, t0 + q * .5 * b, noise(.05, 80, .95), .06)
        for q in (0, .75, 1.5, 2.5, 3.0): add(buf, t0 + q * b, noise(.03, 160, .6), .14)
        mel = [4, 3, 2, 3, 4, 2, 1, 2]; n = c[mel[k % 8] % len(c)] + 12
        add(buf, t0 + (.5 if k % 2 else 1) * b, tone(hz(n), 1.6 * b, "ep", .05, .5), .3); add(buf, t0 + 3 * b, tone(hz(n - 2), .6 * b, "ep", .03, .3), .18)
save("radio_lofi", track(76, 8, [[60, 64, 67, 71, 74], [57, 60, 64, 67, 71], [62, 65, 69, 72, 76], [55, 59, 62, 65, 69]], lofi, .08), .5)
save("radio_synth", track(102, 8, [[57, 60, 64, 69], [53, 57, 60, 65], [60, 64, 67, 72], [55, 59, 62, 67]], synth), .45)
save("radio_bossa", track(118, 8, [[62, 65, 69, 72, 76], [55, 65, 71, 74, 76], [60, 64, 67, 71, 74], [57, 61, 64, 67, 70]], bossa), .5)
print("ok")
