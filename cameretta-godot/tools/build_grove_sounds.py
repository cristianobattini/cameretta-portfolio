"""Suoni delle preghiere nella radura, sintetizzati da zero: CC0.
Uso: python build_grove_sounds.py [cartella sounds]   (serve: pip install numpy soundfile)"""
import os, sys
import numpy as np, soundfile as sf
SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sounds")

def save(name, x, peak):
    x = (x / np.max(np.abs(x)) * peak).astype(np.float32)
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", SR, 1, format="OGG", subtype="VORBIS") as f:
        for a in range(0, len(x), 4096): f.write(x[a:a + 4096])

t = np.arange(int(4.2 * SR)) / SR
# stelle: un ronzio di luce che si accende, e un accordo lontano
hum = sum(np.sin(2 * np.pi * f * t + 2.2 * np.sin(2 * np.pi * .9 * t + f)) / k for k, f in enumerate((92, 138.5, 184, 277), 1))
env = np.clip(t / .35, 0, 1) * np.clip((4.2 - t) / 1.6, 0, 1)
pad = sum(np.sin(2 * np.pi * f * t) * np.clip((t - .5 - i * .28) / .9, 0, 1) for i, f in enumerate((220, 329.6, 440, 554.4)))
save("pray_stelle", (hum * .55 * (1 + .15 * np.sin(2 * np.pi * 5.5 * t)) + pad * .5) * env, .5)
# magia: campanelle che salgono, ognuna accende una candela
x = np.zeros_like(t)
for i, f in enumerate((523.3, 622.3, 784, 932.3, 1046.5, 1244.5)):
    q = np.clip(t - .2 - i * .34, 0, None); on = t > .2 + i * .34
    x += on * (np.sin(2 * np.pi * f * q) + .5 * np.sin(2 * np.pi * 2.76 * f * q) * np.exp(-q * 5) + .25 * np.sin(2 * np.pi * 5.4 * f * q) * np.exp(-q * 12)) * np.exp(-q * 2.1)
save("pray_magia", x * np.clip((4.2 - t) / .8, 0, 1), .45)
# dune: vento basso, e quattro colpi lontani sotto la sabbia
rng = np.random.default_rng(10191)
w = np.convolve(rng.normal(0, 1, len(t)), np.ones(160) / 160, "same") * (1 + .6 * np.sin(2 * np.pi * .45 * t)) * 4
drone = sum(np.sin(2 * np.pi * f * t + .8 * np.sin(2 * np.pi * .7 * t)) / k for k, f in enumerate((65.4, 98, 130.8, 155.6), 1))
x = w * .5 + drone * .5
for a in (.5, 1.3, 2.1, 2.9):
    q = np.clip(t - a, 0, None); x += (t > a) * np.sin(2 * np.pi * (48 * q + 30 * (1 - np.exp(-q * 18)) / 18)) * np.exp(-q * 7) * 1.6
save("pray_dune", x * np.clip(t / .4, 0, 1) * np.clip((4.2 - t) / 1.2, 0, 1), .55)
print("ok")
