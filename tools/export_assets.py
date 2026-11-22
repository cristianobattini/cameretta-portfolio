"""Esporta gli asset del gioco a partire dal render v3:
- mask.png: canale R = gruppo cliccabile (1 letto, 2 scrivania, 3 lavagna, 4 libreria, 5 finestra)
- anim.json: pixel di lucine e stelle della finestra, posizione della tazza, ancoraggi dei cartelli
- room_hover_<gruppo>_x4.png: stanza con contorno luminoso sull'oggetto (per il design)
- menu_sky.png / menu_sky_x4.png: cielo stellato del menu
"""
import json, math
import numpy as np
from PIL import Image

exec(open("build_room_v3.py").read())

GROUPS = ["letto", "scrivania", "lavagna", "libreria", "finestra"]
Hh, Ww = H, W
idb2 = idb
objr = obj.reshape(H, W)
Xr, Yr, Zr = X.reshape(H, W), Y.reshape(H, W), Z.reshape(H, W)
mask = np.zeros((H, W), np.uint8)
groups = {}
for i, b in enumerate(BOXES):
    groups.setdefault(b[1], []).append(i)
for gi, g in enumerate(GROUPS, start=1):
    m = np.isin(idb2, groups[g]) | (idb2 == SPR_ID.get(g, -999))
    if g == "finestra":
        m |= (objr == -5) & (np.abs(Xr) < 60) & (Yr < 222)
    if g == "lavagna":
        pm = np.zeros((H, W), bool)
        for (px, pz, pw, ph) in papers:
            pm |= (objr == -3) & (Xr > px) & (Xr < px + pw) & (Zr > pz) & (Zr < pz + ph)
        m |= pm
    mask[m & (mask == 0)] = gi
# priorita': cio' che e' davanti vince gia' grazie a idb (pixel visibile)
Image.fromarray(np.stack([mask, mask * 0, mask * 0], -1), "RGB").save("mask.png")

# lucine: pixel delle lampadine visibili
bulb_r = bulb.reshape(H, W) & (objr == -1) & (idb2 == -1)
bi_r = bi.reshape(H, W)
bulbs = [[int(x), int(y), int(bi_r[y, x])] for y, x in zip(*np.nonzero(bulb_r))]
# stelle della finestra
star_r = star.reshape(H, W) & (idb2 == -5)
stars = [[int(x), int(y)] for y, x in zip(*np.nonzero(star_r))]
mx_, my_, _ = proj(102, 86, 180)

anchors = {}
for gi, g in enumerate(GROUPS, start=1):
    ys, xs = np.nonzero(mask == gi)
    anchors[g] = {"bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
                  "cx": int(np.median(xs)), "top": int(ys.min())}
json.dump({"w": W, "h": H, "groups": GROUPS, "bulbs": bulbs, "stars": stars,
           "mug": [round(mx_, 1), round(my_, 1)], "anchors": anchors},
          open("anim.json", "w"))
print({g: anchors[g] for g in GROUPS}, len(bulbs), len(stars))

# contorni luminosi per il design
room_img = np.array(Image.open("room_v3.png").convert("RGB")).astype(float)
def hover(gi):
    m = mask == gi
    dil = m.copy()
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        dil |= np.roll(np.roll(m, dy, 0), dx, 1)
    ring = dil & ~m
    ring[0, :] = ring[-1, :] = False; ring[:, 0] = ring[:, -1] = False
    im = room_img * 0.62
    im[m] = room_img[m] * 1.08 + 10
    im[ring] = [255, 232, 160]
    return np.clip(im, 0, 255).astype(np.uint8)
for gi, g in enumerate(GROUPS, start=1):
    Image.fromarray(hover(gi)).resize((W * 4, H * 4), Image.NEAREST).save(f"room_hover_{g}_x4.png")

# ---------------- cielo stellato del menu ----------------
SW, SH = 320, 200
rng = np.random.default_rng(42)
sky = np.zeros((SH, SW, 3))
top, mid, low = np.array([10, 11, 32.]), np.array([30, 28, 72.]), np.array([92, 58, 98.])
bay = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
for y in range(SH):
    t = y / 150
    c = top + (mid - top) * min(1, t) if t < 1 else mid + (low - mid) * min(1, (y - 150) / 30)
    for x in range(SW):
        sky[y, x] = c
# posterizza con dithering
for y in range(SH):
    for x in range(SW):
        sky[y, x] = np.floor(sky[y, x] / 10 + bay[y % 4, x % 4]) * 10
# via lattea: banda diagonale di puntini tenui
for k in range(1400):
    t = rng.uniform(0, 1)
    x = int(-20 + t * 360 + rng.normal(0, 14))
    y = int(150 - t * 150 + rng.normal(0, 12))
    if 0 <= x < SW and 0 <= y < 150:
        sky[y, x] = np.minimum(255, sky[y, x] + rng.choice([18, 28, 40]))
# stelle
menu_stars = []
for k in range(170):
    x, y = int(rng.uniform(0, SW)), int(rng.uniform(0, 150))
    kind = rng.choice([0, 0, 0, 0, 1, 1, 2], p=None)
    col = np.array(rng.choice([[255, 248, 220], [220, 230, 255], [255, 226, 180]]), float)
    if kind == 0:
        sky[y, x] = col * rng.uniform(0.5, 1.0)
    elif kind == 1:
        sky[y, x] = col
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < SW and 0 <= y + dy < SH:
                sky[y + dy, x + dx] = col * 0.55
    else:
        sky[y, x] = col
        for d in (1, 2):
            for dx, dy in ((d, 0), (-d, 0), (0, d), (0, -d)):
                if 0 <= x + dx < SW and 0 <= y + dy < SH:
                    sky[y + dy, x + dx] = col * (0.7 if d == 1 else 0.35)
    menu_stars.append([x, y, int(kind)])
# luna grande
mcx, mcy, mr = 252, 46, 17
for y in range(mcy - mr - 6, mcy + mr + 7):
    for x in range(mcx - mr - 6, mcx + mr + 7):
        d = math.hypot(x - mcx, y - mcy)
        if d <= mr:
            shade = 1 - 0.25 * max(0, (x - mcx + y - mcy) / (2 * mr))
            c = np.array([255, 240, 200]) * shade
            for (cx_, cy_, cr) in ((-6, -4, 4), (5, 3, 3), (-2, 8, 2.5), (7, -6, 2)):
                if math.hypot(x - mcx - cx_, y - mcy - cy_) < cr:
                    c = c * 0.86
            sky[y, x] = c
        elif d <= mr + 6:
            a = 0.22 * (1 - (d - mr) / 6)
            sky[y, x] = sky[y, x] * (1 - a) + np.array([255, 230, 180]) * a
# mare
SEA = 160
for y in range(SEA, SH):
    for x in range(SW):
        base = np.array([16, 22, 58.]) + (y - SEA) * np.array([0.3, 0.3, 0.6])
        if (x * 7 + y * 13) % 23 == 0:
            base = base + 14
        sky[y, x] = base
# riflesso della luna sul mare
for y in range(SEA + 1, SH):
    w = 2 + (y - SEA) * 0.25
    off = 3 * math.sin(y * 1.3)
    if (y // 2) % 2 == 0:
        for x in range(int(mcx - w + off), int(mcx + w + off)):
            if 0 <= x < SW:
                sky[y, x] = [250, 226, 170]
# costa con colline e casa con finestra accesa (a sinistra)
def land_top(x):
    return 134 + 5 * math.sin(x / 17) + 3 * math.sin(x / 7 + 1) - 22 * math.exp(-((x - 70) / 45) ** 2) + 40 * max(0, (x - 120) / 80) ** 2
for x in range(0, SW):
    hy = int(land_top(x))
    if hy >= SEA + 2:
        continue
    for y in range(max(0, hy), SH):
        sky[y, x] = [36, 30, 62] if y <= hy + 1 else [14, 12, 30]
# casa
hx0, hx1, hy0 = 52, 92, 96
for y in range(hy0, 132):
    for x in range(hx0, hx1):
        sky[y, x] = [24, 20, 44]
for i in range(0, 16):  # tetto
    for x in range(hx0 - 4 + i, hx1 + 4 - i):
        sky[hy0 - i, x] = [30, 24, 52]
for y in range(hy0 - 18, hy0 - 6):  # comignolo
    for x in range(80, 85):
        sky[y, x] = [30, 24, 52]
# finestra accesa (la cameretta)
for y in range(104, 118):
    for x in range(60, 72):
        sky[y, x] = [255, 200, 110] if (x != 65 and y != 110) else [150, 96, 60]
# alone caldo della finestra
for y in range(94, 130):
    for x in range(48, 86):
        d = math.hypot(x - 66, y - 111) / 18
        if d < 1 and not (60 <= x < 72 and 104 <= y < 118):
            sky[y, x] = sky[y, x] * (1 - 0.25 * (1 - d)) + np.array([255, 180, 90]) * 0.25 * (1 - d)
# altra finestra spenta
for y in range(104, 118):
    for x in range(76, 86):
        sky[y, x] = [40, 36, 70]
sky = np.clip(sky, 0, 255).astype(np.uint8)
Image.fromarray(sky).save("menu_sky.png")
Image.fromarray(sky).resize((SW * 4, SH * 4), Image.NEAREST).save("menu_sky_x4.png")
json.dump({"stars": menu_stars, "moon": [mcx, mcy, mr], "window": [60, 104, 72, 118]}, open("menu_anim.json", "w"))
print("menu ok")
