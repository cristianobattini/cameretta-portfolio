"""Builds the game's sound set from CC0 recordings (Kenney, Ben Burnes/Abstraction, lavenderdotpet CC0 packs).
Usage: python build_sounds.py <kenney_root> <cc0_root> <out_dir>"""
import sys, subprocess, os, numpy as np
SR = 44100
K, C, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

def load(p):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', p, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy()

def save(name, x, q=4):
    x = np.clip(x, -1, 1).astype(np.float32)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '1', '-i', '-', '-c:a', 'libvorbis', '-q:a', str(q), os.path.join(OUT, name + '.ogg')], input=x.tobytes(), check=True)

def norm(x, peak=.9):
    m = np.max(np.abs(x)) or 1
    return x / m * peak

def fade(x, a=.004, b=.02):
    n = len(x); fa, fb = min(int(a * SR), n // 4), min(int(b * SR), n // 2)
    if fa: x[:fa] *= np.linspace(0, 1, fa)
    if fb: x[-fb:] *= np.linspace(1, 0, fb)
    return x

def trim(x, thr=.02):
    i = np.where(np.abs(x) > thr * np.max(np.abs(x)))[0]
    return x[max(0, i[0] - 40): i[-1] + 200] if len(i) else x

def onepole_lp(x, fc):
    a = np.exp(-2 * np.pi * fc / SR); y = np.empty_like(x); s = 0.0
    for i, v in enumerate(x): s = (1 - a) * v + a * s; y[i] = s
    return y

def lp(x, fc):  # 2 poles, vectorised enough for short clips
    return onepole_lp(onepole_lp(x, fc), fc)

def hp(x, fc): return x - lp(x, fc)

def resample(x, ratio):
    n = int(len(x) / ratio); idx = np.arange(n) * ratio
    return np.interp(idx, np.arange(len(x)), x).astype(np.float32)

ki = lambda *p: os.path.join(K, *p)
# --- passi
for i in range(5):
    s = trim(load(ki('kenney_impact-sounds', f'footstep_snow_00{i}.ogg')))
    save(f'step_snow_{i}', fade(norm(lp(s, 3200), .55)))
    w = trim(load(ki('kenney_impact-sounds', f'footstep_wood_00{i}.ogg')))
    save(f'step_wood_{i}', fade(norm(lp(w, 4200), .6)))
# --- tasti (bolle che si scrivono): solo il primo colpo di ciascun tasto
for i in range(4):
    s = trim(load(os.path.join(C, 'bb - Keyboard Sounds (Mar 2021)', f'Keyboard - Key {i+1}.wav')))
    s = s[:int(.075 * SR)]
    save(f'key_{i}', fade(norm(hp(s, 300), .5), .001, .03))
# --- interfaccia
ui = {'ui_move': 'tick_002', 'ui_hover': 'tick_001', 'ui_select': 'select_002', 'ui_click': 'click_003', 'ui_start': 'select_006', 'ui_close': 'switch_002', 'ui_toggle': 'switch_005'}
for name, src in ui.items():
    s = trim(load(ki('kenney_interface-sounds', src + '.ogg')))
    save(name, fade(norm(s, .7)))
for name, src in {'ui_open': 'bookFlip1', 'ui_page': 'bookFlip2', 'door_open': 'doorOpen_1', 'door_close': 'doorClose_2'}.items():
    s = trim(load(ki('kenney_rpg-audio', src + '.ogg')))
    save(name, fade(norm(s, .8)))
s = trim(load(ki('kenney_interface-sounds', 'tick_004.ogg')))
save('clock_tick', fade(norm(lp(s, 2500), .35)))
# --- fuoco: schiocchi di legno registrati sparsi su un ruggito morbido, loop senza giunture
cr = [trim(load(os.path.join(C, '100-CC0-wood-metal-SFX', f'wood_cracking_0{i}.ogg'))) for i in range(1, 5)]
L = 18 * SR
fire = np.zeros(L, np.float32)
br = np.cumsum(rng.normal(0, 1, L)).astype(np.float32); br -= onepole_lp(br, 2)  # brown noise without drift
br = lp(br, 380); br = norm(br, 1)
lfo = .75 + .25 * np.sin(np.linspace(0, 2 * np.pi * 3, L)) * np.sin(np.linspace(0, 2 * np.pi * 7, L))
fire += br * lfo * .16
def place(sig, at, g):
    n = len(sig); end = at + n
    if end <= L: fire[at:end] += sig * g
    else: k = L - at; fire[at:] += sig[:k] * g; fire[:n - k] += sig[k:] * g
t = 0.0
while t < 18:
    t += rng.exponential(1 / 4.2)
    if t >= 18: break
    c = cr[rng.integers(4)]
    seg = c[:int(rng.uniform(.03, .12) * SR)] if rng.random() < .7 else c
    seg = fade(resample(seg, rng.uniform(.8, 1.6)).copy(), .001, .01)
    g = rng.uniform(.08, .35) * (2.2 if rng.random() < .06 else 1)
    place(seg, int(t * SR), g)
    if rng.random() < .3:  # piccoli grappoli
        for k in range(rng.integers(1, 4)):
            place(seg[:int(.02 * SR)] * .6, int((t + .02 + .03 * k) * SR) % L, g * .7)
save('fire_loop', norm(fire, .8), 5)
# --- raffica di vento (one-shot, niente fruscio continuo)
wd = load(os.path.join(C, 'BB_2HTC Samples Vol 4', 'Weird', '2022-12-22 Snow Day - Windy.wav'))
wd = lp(wd, 1600); env = np.sin(np.linspace(0, np.pi, len(wd))) ** 1.5
save('wind_gust', norm(wd * env, .6))
# --- TV: voci ovattate (rumore formantico a sillabe) e statico
L = 12 * SR
tv = np.zeros(L, np.float32); t = 0.0
while t < 11.5:
    dur = rng.uniform(.08, .22); n = int(dur * SR); a = int(t * SR)
    noise = rng.normal(0, 1, n).astype(np.float32)
    f = rng.uniform(450, 1100)
    syl = lp(hp(noise, f * .6), f * 1.8) * np.sin(np.linspace(0, np.pi, n)) ** 2
    tv[a:a + n] += syl * rng.uniform(.5, 1)
    t += dur + (rng.uniform(.25, .6) if rng.random() < .18 else rng.uniform(.01, .06))
tv = lp(tv, 2200)
save('tv_voices', norm(tv, .5))
st = hp(rng.normal(0, 1, 4 * SR).astype(np.float32), 900)
save('tv_static', norm(lp(st, 7000), .35))
print('ok', len(os.listdir(OUT)))
