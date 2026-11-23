"""Bonus "giro in Vespa": lungomare innevato, Vespa, omino in sella, tappe ed emblemi.
Uso: python tools/build_sea.py [cartella_uscita]   (predefinita: cameretta-godot/assets)
Output: img/sea_sky.png, sea_near.png, sea_fore.png, sea_beach.png, sea_props.png, sea_emblems.png + data/sea.json
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "cameretta-godot", "assets")
IMG, DATA = os.path.join(ROOT, "img"), os.path.join(ROOT, "data")
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
rnd = random.Random(26)
OUT = (24, 18, 30)
SNOW, SNOW2, SNOW3 = (240, 245, 255), (214, 224, 246), (184, 196, 228)
LCOL = [(255, 96, 90), (255, 214, 100), (110, 220, 140), (110, 180, 255)]
HORIZON, SKY_H, SS = 92, 140, 8

# ================================================================ utilità
from pix import Spr   # noqa: E402

def mix(a, b, t): return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))
def dith(c, x, y, q=8): return tuple(int(v) for v in np.clip(np.floor(np.array(c, float) / q + BAY[y % 4, x % 4] + .5) * q, 0, 255))
def grad(stops, t):
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1: return mix(c0, c1, max(0, (t - t0) / (t1 - t0)))
    return stops[-1][1]


# ================================================================ cielo e mare: notte, ora blu, cintura di Venere, alba
PH = [
    dict(sky=[(0, (8, 10, 30)), (.6, (24, 25, 68)), (1, (58, 52, 104))], sea=[(0, (50, 50, 100)), (.3, (26, 32, 78)), (1, (14, 18, 50))]),
    dict(sky=[(0, (14, 24, 66)), (.55, (40, 62, 124)), (1, (104, 110, 168))], sea=[(0, (84, 96, 156)), (.3, (44, 64, 124)), (1, (24, 36, 84))]),
    # a ovest, prima dell'alba: sopra l'azzurro, poi la fascia rosa, in basso l'ombra azzurra della Terra
    dict(sky=[(0, (58, 88, 160)), (.38, (132, 142, 200)), (.62, (224, 160, 186)), (.8, (182, 148, 192)), (.88, (110, 120, 176)), (1, (104, 118, 172))],
         sea=[(0, (126, 130, 182)), (.3, (88, 108, 168)), (1, (46, 68, 124))]),
    dict(sky=[(0, (104, 150, 212)), (.4, (170, 184, 224)), (.68, (250, 198, 186)), (.85, (236, 172, 178)), (1, (196, 164, 194))],
         sea=[(0, (206, 172, 190)), (.3, (128, 152, 200)), (1, (70, 102, 160))]),
]
sky = np.zeros((SKY_H * len(PH), 320, 4), np.uint8)
for pi, ph in enumerate(PH):
    for y in range(SKY_H):
        c = grad(ph["sky"], y / (HORIZON - 1)) if y < HORIZON else grad(ph["sea"], (y - HORIZON) / (SKY_H - HORIZON))
        for x in range(320):
            sky[pi * SKY_H + y, x] = (*dith(c, x, y), 255)
    # linea d'orizzonte appena più chiara
    sky[pi * SKY_H + HORIZON, :, :3] = np.clip(sky[pi * SKY_H + HORIZON, :, :3].astype(int) + 14, 0, 255)
    # increspature ferme: danno grana al mare sotto i riflessi animati
    for k in range(150):
        y = HORIZON + 2 + int((SKY_H - HORIZON - 3) * rnd.random() ** 1.3); x = rnd.randrange(320); L = 1 + int((y - HORIZON) / 9) + rnd.randrange(3)
        s = rnd.choice((-9, 10))
        for i in range(L):
            q = sky[pi * SKY_H + y, (x + i) % 320, :3].astype(int) + s
            sky[pi * SKY_H + y, (x + i) % 320, :3] = np.clip(q, 0, 255)
Image.fromarray(sky).save(os.path.join(IMG, "sea_sky.png"))

# ================================================================ spiaggia e scogli oltre la balaustra (si ripete)
BW = 480
beach = Spr(BW, 34)
def wave(x, per): return math.sin(2 * math.pi * x * per / BW)
for x in range(BW):
    top = 7 + 2.2 * wave(x, 3) + 1.3 * wave(x + 40, 7) + .8 * wave(x, 17)
    for y in range(int(top), 34):
        c = SNOW if y < top + 2 else SNOW2 if y < top + 8 or (y < top + 10 and (x + y) % 2) else SNOW3
        beach.p(x, y, c)
for k in range(26):                                     # scogli con la neve sopra
    x = rnd.randrange(6, BW - 18); y = rnd.randrange(3, 9); w = rnd.randrange(5, 14); h = rnd.randrange(4, 8)
    beach.poly([(x, y + h), (x + w * .15, y + 1), (x + w * .55, y), (x + w * .9, y + 2), (x + w, y + h)], (58, 58, 88))
    beach.poly([(x + 1, y + h), (x + w * .3, y + 2), (x + w * .5, y + h)], (78, 78, 112))
    beach.poly([(x + w * .1, y + 2), (x + w * .5, y - 1), (x + w * .95, y + 2), (x + w * .6, y + 2)], SNOW)
for k in range(40):
    x, y = rnd.randrange(BW), rnd.randrange(16, 32); beach.p(x, y, SNOW); beach.p(x + 1, y, SNOW3)
Image.fromarray(beach.a).save(os.path.join(IMG, "sea_beach.png"))

# ================================================================ lungomare: balaustra, marciapiede, strada (si ripete)
NW = 640
near = Spr(NW, 200)
ST, ST_HI, ST_SH, ST_DK = (186, 184, 204), (214, 212, 228), (142, 140, 170), (104, 102, 138)
for x in range(0, NW, 10):                               # colonnine panciute
    for y, hw in zip(range(137, 149), (2, 1, 1, 1, 2, 2, 3, 3, 3, 2, 1, 2)):
        near.r(x + 4 - hw, y, x + 4 + hw, y, ST)
        near.p(x + 4 - hw, y, ST_HI); near.p(x + 4 + hw, y, ST_SH)
        if hw >= 2: near.p(x + 4 + hw - 1, y, ST_SH)
near.r(0, 133, NW, 136, ST); near.r(0, 136, NW, 136, ST_SH); near.r(0, 149, NW, 152, ST); near.r(0, 149, NW, 149, ST_HI); near.r(0, 152, NW, 152, ST_SH)
for x in range(0, NW, 80):                               # pilastrini
    near.r(x, 130, x + 9, 152, ST); near.r(x, 130, x, 152, ST_HI); near.r(x + 8, 130, x + 9, 152, ST_SH); near.r(x + 2, 137, x + 7, 147, ST_SH); near.r(x + 3, 138, x + 7, 147, ST)
    near.r(x - 1, 128, x + 10, 130, ST); near.r(x - 1, 130, x + 10, 130, ST_DK)
for x in range(NW):                                      # neve sul corrimano, con bordo irregolare e ghiaccioli
    h = 2 + (math.sin(2 * math.pi * x * 23 / NW) > .3) + (math.sin(2 * math.pi * x * 61 / NW + 1) > .6)
    pil = x % 80 <= 10 or x % 80 == 79
    base = 128 if pil else 133
    for k in range(h): near.p(x, base - 1 - k, SNOW if k else SNOW2)
    near.p(x, base, SNOW2)
    if (x * 7) % 23 == 0 and not pil:
        for k in range(2 + (x * 5) % 3): near.p(x, 137 + k, (206, 228, 252))
for y in range(153, 161):                                # marciapiede
    for x in range(NW): near.p(x, y, (228, 235, 250) if y < 158 else (218, 227, 246))
for x in range(0, NW, 3):
    if (x * 7) % 11 == 0: near.p(x, 154 + (x * 5) % 6, (204, 214, 238))
near.r(0, 153, NW, 153, (196, 206, 234))
near.r(0, 161, NW, 161, SNOW); near.r(0, 162, NW, 162, (150, 158, 192)); near.r(0, 163, NW, 163, (112, 118, 154))
for y in range(164, 200):                                # asfalto bagnato con la neve schiacciata
    for x in range(NW):
        t = (y - 164) / 24
        near.p(x, y, dith(mix((124, 132, 170), (104, 112, 152), t), x, y, 6))
for y, h in ((170, 1), (177, 3), (183, 2)):               # solchi lasciati dalle gomme
    for x in range(NW):
        if math.sin(2 * math.pi * x * 9 / NW + y) > -.8:
            for k in range(h): near.p(x, y + k, (88, 94, 132) if k == 0 else (96, 104, 142))
for x in range(0, NW, 40):                               # mezzeria tratteggiata, mezza coperta
    for i in range(18):
        if (x + i * 13) % 7: near.p(x + i, 174, (206, 208, 222)); near.p(x + i, 175, (176, 180, 206))
for k in range(170):                                     # chiazze di neve sulla strada
    x, y = rnd.randrange(NW), rnd.choice((165, 166, 167, 168, 172, 173, 186, 187)); L = rnd.randrange(2, 9)
    for i in range(L): near.p((x + i) % NW, y, rnd.choice((SNOW2, (196, 206, 234), (172, 182, 216))))
Image.fromarray(near.a).save(os.path.join(IMG, "sea_near.png"))

# ================================================================ cumuli in primo piano (scorrono più veloci)
FWD = 512
fore = Spr(FWD, 34)
for x in range(FWD):
    w = lambda n, p=0: math.sin(2 * math.pi * x * n / FWD + p)
    top = 21 + 3 * w(7) + 2 * w(19, 1) + 1 * w(43)
    for y in range(int(top), 34):
        fore.p(x, y, (255, 255, 255) if y <= int(top) else (240, 245, 255) if y < top + 3 else (214, 224, 246) if y < top + 8 else (190, 202, 232))
def tuft(x, n):                                           # ciuffi d'erba delle dune
    for i in range(n):
        dx = rnd.randint(-5, 5); hh = rnd.randint(6, 12)
        for k in range(hh):
            fore.p(x + i + dx * (k / hh) ** 2, 25 - k, (70, 92, 84) if i % 2 else (98, 114, 92))
        fore.p(x + i + dx, 25 - hh, SNOW)
    for i in range(n + 4): fore.p(x - 2 + i, 25 - (i % 3 == 0), SNOW); fore.p(x - 2 + i, 26, SNOW)
for x in (40, 150, 161, 300, 420, 428): tuft(x, rnd.randint(4, 7))
for bx in (90, 236, 366, 470):                            # cespugli con qualche lucina
    for j in range(3):
        fore.ell(bx + j * 6, 18 - (j == 1) * 3, bx + j * 6 + 10, 30, (36, 72, 66)); fore.ell(bx + j * 6 + 1, 16 - (j == 1) * 3, bx + j * 6 + 9, 21 - (j == 1) * 2, (238, 244, 255))
    for j in range(5): fore.p(bx + rnd.randint(1, 20), 23 + rnd.randint(0, 4), LCOL[j % 4])
Image.fromarray(fore.a).save(os.path.join(IMG, "sea_fore.png"))

# ================================================================ sprite
P = {}
def add(name, s): P[name] = s; return s

# ---------------------------------------------------------------- VESPA (60 px ~ 1,75 m, scala dell'omino)
MINT, MINT_HI, MINT_LT, MINT_SH, MINT_DK = (126, 196, 176), (214, 244, 228), (158, 218, 198), (86, 150, 140), (56, 106, 108)
CHR, CHR_HI, CHR_SH = (176, 184, 204), (244, 248, 255), (104, 110, 138)
SEAT, SEAT_HI, SEAT_SH = (134, 78, 50), (176, 112, 72), (92, 52, 40)
TYRE, TYRE_HI = (34, 30, 42), (70, 66, 84)
PAD = 4                                                   # margine a sinistra: tutte le x in sea.json lo comprendono
VW, VH = 68, 50                                           # ruote: (15,40) e (54,40), raggio 8

def wheel(i):
    s = Spr(19, 19)
    s.ell(1, 1, 17, 17, TYRE); s.ell(4, 4, 14, 14, (238, 234, 222)); s.ell(5, 5, 13, 13, CHR_SH); s.ell(6, 6, 12, 12, CHR)
    for k in range(4):                                    # fori del cerchio: fanno vedere la rotazione
        a = k * math.pi / 2 + i * math.pi / 8
        s.p(9 + 2.6 * math.cos(a), 9 + 2.6 * math.sin(a), (44, 42, 60))
        s.p(9 + 3.1 * math.cos(a), 9 + 3.1 * math.sin(a), (70, 70, 92))
    s.r(8, 8, 10, 10, CHR_HI); s.p(9, 9, CHR_SH)
    for k in range(10):                                   # tasselli invernali
        a = k * math.pi / 5 + i * math.pi / 20
        s.p(9 + 8 * math.cos(a), 9 + 8 * math.sin(a), TYRE_HI)
    return s.outline()
for i in range(4): add(f"wheel{i}", wheel(i))

def vespa_back():
    """ciò che sta dietro le ruote: forcella, motore, marmitta, cavalletto escluso"""
    s = Spr(VW, VH)
    s.limb([(50, 28), (54, 40)], 3, CHR_SH); s.limb([(51, 30), (54, 39)], 1, CHR)
    s.r(14, 33, 26, 41, (70, 70, 92)); s.r(16, 35, 24, 36, (96, 96, 122)); s.r(16, 38, 24, 38, (96, 96, 122))
    return s.padl(PAD).outline()
add("vespa_back", vespa_back())

def vespa_body():
    s = Spr(VW, VH)
    # marmitta
    s.limb([(24, 42), (9, 44)], 4, CHR_SH); s.limb([(23, 41), (10, 43)], 1, CHR); s.r(4, 43, 7, 45, (64, 60, 76)); s.p(4, 44, OUT)
    # pedana
    s.poly([(26, 36), (45, 37), (46, 40), (27, 41)], MINT_SH); s.r(28, 37, 44, 37, (60, 56, 70)); s.r(28, 36, 44, 36, (92, 86, 100))
    for x in range(29, 44, 3): s.p(x, 36, (130, 124, 140))
    s.r(28, 41, 44, 41, MINT_DK)
    # scudo: dalla pedana al manubrio, con la pancia in avanti
    sh = s.curve([(41, 40), (41, 34), (43, 25), (44, 16), (46, 10), (50, 10), (51, 16), (52, 23), (52, 29), (49, 35), (46, 40)], MINT)
    s.curve([(40, 40), (41, 33), (43, 25), (44, 15), (46, 11), (46, 17), (45, 26), (44, 34), (43, 40)], MINT_SH, only=sh)
    s.limb([(49, 13), (50, 20), (50, 27)], 1, MINT_HI, only=sh)
    s.limb([(51, 17), (52, 24)], 1, MINT_LT, only=sh)
    s.limb([(42, 39), (44, 27), (45, 14)], 1, CHR_HI)      # bordo cromato dello scudo
    s.r(51, 22, 52, 24, MINT_DK); s.p(51, 23, MINT_LT)     # clacson: la "cravatta"
    # parafango anteriore
    fm = s.curve([(44, 36), (45, 31), (49, 28), (55, 28), (60, 31), (63, 35), (62, 38), (60, 36), (57, 34), (54, 33), (50, 35), (47, 38)], MINT)
    s.limb([(48, 30), (54, 29), (59, 32)], 1, MINT_HI, only=fm); s.limb([(50, 34), (54, 32), (59, 35)], 1, MINT_SH, only=fm)
    s.p(56, 27, CHR_HI); s.p(57, 27, CHR_HI); s.p(58, 28, CHR)    # crestina cromata
    # carrozzeria posteriore: la "goccia"
    cm = s.curve([(2, 33), (4, 26), (9, 22), (17, 20), (26, 20), (30, 24), (31, 31), (31, 38), (27, 40), (24, 34), (19, 31), (13, 31), (8, 34), (6, 38), (3, 37)], MINT)
    s.curve([(3, 34), (6, 31), (12, 29), (19, 29), (25, 31), (29, 37), (27, 40), (24, 34), (19, 31), (13, 31), (8, 34), (6, 38), (3, 37)], MINT_SH, only=cm)
    s.limb([(6, 26), (12, 23), (20, 22), (25, 22)], 1, MINT_HI, only=cm); s.limb([(7, 27), (13, 24), (20, 23)], 1, MINT_LT, only=cm)
    s.limb([(5, 32), (9, 28), (17, 26), (24, 27), (28, 32)], 1, MINT_DK, only=cm)          # bordo della pancia
    s.limb([(6, 31), (10, 27), (17, 25), (24, 26)], 1, MINT_LT, only=cm)
    for k in range(3): s.r(20 + k * 2, 31, 20 + k * 2, 32, MINT_DK)                        # feritoie
    s.p(27, 24, CHR_HI); s.p(28, 24, CHR_HI)
    # fanalino e targa
    s.r(1, 27, 3, 30, (196, 40, 44)); s.p(1, 28, (255, 120, 110)); s.r(2, 26, 3, 26, CHR)
    s.r(0, 33, 2, 37, (236, 236, 244)); s.p(1, 34, (40, 40, 60)); s.p(1, 36, (40, 40, 60)); s.p(0, 33, (52, 92, 180)); s.p(0, 34, (52, 92, 180))
    # sella
    sm = s.curve([(6, 19), (8, 16), (14, 15), (20, 16), (24, 15), (30, 16), (32, 19), (29, 21), (18, 20), (9, 21)], SEAT)
    s.limb([(8, 17), (14, 16), (20, 17), (25, 16), (29, 17)], 1, SEAT_HI, only=sm); s.limb([(8, 20), (18, 20), (30, 20)], 1, SEAT_SH, only=sm)
    s.p(19, 17, SEAT_SH); s.p(19, 18, SEAT_SH)
    # portapacchi con un pacco regalo
    s.line(0, 18, 8, 18, CHR); s.p(0, 17, CHR_HI); s.line(3, 19, 6, 22, CHR_SH)
    s.r(0, 10, 7, 17, (196, 66, 56)); s.r(0, 10, 7, 11, (226, 96, 78)); s.r(3, 10, 4, 17, (242, 200, 100)); s.r(0, 13, 7, 14, (242, 200, 100)); s.r(6, 11, 7, 17, (156, 46, 44)); s.r(3, 13, 4, 14, (255, 230, 150))
    s.p(2, 9, (242, 200, 100)); s.p(5, 9, (242, 200, 100)); s.p(1, 8, (242, 200, 100)); s.p(6, 8, (242, 200, 100))
    # manubrio, strumento, faro, manopola
    hm = s.curve([(44, 9), (45, 5), (49, 4), (53, 5), (54, 9), (51, 12), (47, 12)], MINT)
    s.limb([(46, 6), (49, 5), (52, 6)], 1, MINT_HI, only=hm); s.limb([(46, 11), (50, 11)], 1, MINT_SH, only=hm)
    s.r(53, 5, 55, 10, CHR); s.r(55, 5, 55, 10, (255, 244, 196)); s.p(54, 5, CHR_HI); s.r(53, 4, 54, 4, CHR_HI)
    s.limb([(39, 9), (45, 8)], 2, (60, 54, 64)); s.p(38, 9, CHR); s.line(40, 11, 45, 11, CHR)                       # manopola e leva
    s.line(46, 4, 45, 0, CHR_SH); s.r(43, 0, 46, 1, CHR); s.p(44, 0, CHR_HI)                                        # specchietto
    # finiture: scritta corsiva sullo scudo (tre puntini chiari) e pedale del freno
    s.p(47, 20, MINT_HI); s.p(48, 20, MINT_HI); s.p(49, 19, MINT_HI); s.p(47, 21, MINT_HI)
    s.r(39, 35, 40, 35, CHR)
    return s.padl(PAD).outline()
add("vespa", vespa_body())

st = Spr(12, 12); st.limb([(3, 1), (7, 9)], 1.6, CHR_SH); st.r(5, 9, 9, 10, CHR); add("stand", st.outline())
sn = Spr(VW, VH)                                          # neve depositata quando è parcheggiata
for x0, x1, y in ((7, 31, 14), (1, 7, 8), (45, 53, 3), (49, 60, 27), (3, 12, 23)):
    for x in range(x0, x1 + 1):
        h = 1 + (math.sin(x * 1.3) > -.2) + (x0 + 1 < x < x1 - 1)
        yy = y + (abs(x - (x0 + x1) / 2) > (x1 - x0) * .4)
        for k in range(h): sn.p(x, yy - k + 1, SNOW if k else SNOW2)
add("vespa_snow", sn.padl(PAD))

# ---------------------------------------------------------------- omino in sella (stessi colori di build_player.py)
SKIN, SKIN_SH = (240, 200, 166), (212, 162, 130)
HAIR, HAIR_HI = (54, 38, 32), (88, 62, 48)
HOOD, HOOD_HI, HOOD_SH = (36, 34, 44), (60, 56, 72), (24, 22, 30)
SCARF, SCARF_SH, SCARF_ST = (200, 70, 56), (156, 50, 42), (238, 186, 82)
PANTS, PANTS_SH, PANTS_HI = (156, 150, 142), (122, 118, 112), (182, 176, 168)
SHOE, SOLE = (242, 240, 234), (176, 172, 176)
RW, RH = 60, 76                                           # la Vespa è disegnata a (0, 26): pedana y=62, sella y=42
def shoe(s, x, y, far=False):
    c = (214, 212, 208) if far else SHOE
    s.r(x - 3, y, x + 4, y + 3, c); s.r(x + 4, y + 1, x + 5, y + 3, c); s.r(x - 3, y + 3, x + 5, y + 3, SOLE); s.r(x, y, x + 1, y, SOLE)

def rider(kind):
    """due strati: 'back' (gamba e braccio lontani, dietro la carrozzeria) e 'front' (il resto), così sta a cavallo della sella"""
    b, s = Spr(RW, RH), Spr(RW, RH)
    dy = {"ride0": 0, "ride1": 1, "stop": 0, "sea": 0, "horn": 0, "kick": -5}[kind]
    lean = {"ride0": 2, "ride1": 2, "stop": 0, "sea": -1, "horn": 1, "kick": 4}[kind]
    hx, hy = 18 + (2 if kind == "kick" else 0), 38 + dy      # bacino: appoggia sulla sella (y 41-47), che resta visibile sotto
    sx, sy = hx + 3 + lean, 24 + dy                        # spalle
    # --- strato lontano
    b.limb([(sx + 2, sy + 2), (sx + 9, sy + 9), (42, 34)], 4, HOOD_SH); b.r(41, 33, 43, 35, SKIN_SH)
    if kind in ("stop", "sea"):                            # piede lontano a terra: spunta sotto la pedana
        b.limb([(hx + 3, hy + 2), (hx + 15, hy + 5), (hx + 14, 66)], 6, PANTS_SH); shoe(b, hx + 15, 69, True)
    elif kind == "kick":
        b.limb([(hx + 2, hy + 2), (hx + 10, hy + 14), (hx + 11, 66)], 6, PANTS_SH); shoe(b, hx + 12, 69, True)
    else:
        b.limb([(hx + 3, hy + 2), (37, 42 + dy * .5), (38, 56)], 6, PANTS_SH); shoe(b, 39, 58, True)
    # --- sedere, schiacciato sulla sella
    if kind != "kick":
        s.ell(hx - 7, 36 + dy, hx + 7, 43, PANTS); s.r(hx - 5, 42, hx + 5, 43, PANTS_SH)
    else:
        s.ell(hx - 6, hy - 1, hx + 6, hy + 6, PANTS); s.limb([(hx - 4, hy + 5), (hx + 1, hy + 6)], 1, PANTS_SH)
    # busto (felpa nera oversize)
    tm = s.curve([(hx - 6, hy + 1), (hx - 7, hy - 4), (sx - 7, sy + 3), (sx - 5, sy - 1), (sx + 4, sy - 1), (sx + 7, sy + 3), (hx + 8, hy - 4), (hx + 7, hy + 1)], HOOD)
    s.curve([(hx - 6, hy + 1), (hx - 7, hy - 4), (sx - 7, sy + 3), (sx - 5, sy), (sx - 3, sy + 5), (hx - 4, hy - 3), (hx - 3, hy + 1)], HOOD_SH, only=tm)
    s.limb([(sx + 6, sy + 4), (hx + 8, hy - 4)], 1.4, HOOD_HI, only=tm)
    s.r(hx - 6, hy, hx + 7, hy + 1, (46, 44, 56), only=tm)
    s.r(sx + 1, sy + 4, sx + 1, sy + 7, (230, 226, 220)); s.r(sx + 4, sy + 4, sx + 4, sy + 6, (230, 226, 220))
    # cappuccio
    s.ell(sx - 9, sy - 4, sx - 2, sy + 3, HOOD); s.ell(sx - 8, sy - 3, sx - 5, sy, HOOD_HI)
    # testa (il casco si disegna sopra nel gioco)
    ex, ey = sx - 6, sy - 17
    s.r(ex + 2, ey + 2, ex + 13, ey + 14, SKIN); s.r(ex, ey + 1, ex + 4, ey + 9, HAIR); s.r(ex + 1, ey, ex + 11, ey + 4, HAIR); s.r(ex + 5, ey, ex + 8, ey, HAIR_HI)
    if kind == "sea":                                      # testa girata verso il mare (di tre quarti da dietro)
        s.r(ex + 1, ey + 1, ex + 11, ey + 11, HAIR); s.r(ex + 12, ey + 6, ex + 13, ey + 12, SKIN); s.r(ex + 3, ey + 11, ex + 12, ey + 13, SKIN_SH)
    else:
        s.r(ex + 11, ey + 7, ex + 12, ey + 9, (30, 22, 30)); s.r(ex + 13, ey + 10, ex + 13, ey + 11, (232, 150, 140)); s.r(ex + 14, ey + 8, ex + 14, ey + 10, SKIN); s.r(ex + 5, ey + 7, ex + 5, ey + 8, SKIN_SH)
        s.r(ex + 11, ey + 13, ex + 12, ey + 13, (178, 108, 92))
    # sciarpa al collo
    s.r(sx - 5, sy - 4, sx + 8, sy + 1, SCARF); s.r(sx - 5, sy + 1, sx + 8, sy + 1, SCARF_SH)
    for k in (-3, 1, 5): s.r(sx + k, sy - 2, sx + k + 1, sy - 1, SCARF_ST)
    # gamba vicina: coscia lungo la sella, piede sulla pedana
    if kind == "kick":                                     # in piedi a cavallo, spinge la messa in moto
        s.limb([(23, 62), (28, 69)], 1.4, CHR_SH); s.r(26, 69, 31, 69, CHR)
        lm = s.limb([(hx, hy + 3), (hx + 9, hy + 13), (hx + 6, 60)], 7, PANTS)
        s.limb([(hx - 2, hy + 6), (hx + 6, hy + 15), (hx + 3, 60)], 1.3, PANTS_SH, only=lm); s.limb([(hx + 3, hy + 2), (hx + 11, hy + 11)], 1.2, PANTS_HI, only=lm); shoe(s, hx + 7, 64)
    else:
        ky = 41 + dy * .5
        lm = s.limb([(hx + 1, hy + 2), (33, ky), (35, 56)], 6.5, PANTS)
        s.limb([(hx + 4, hy + 5), (30, ky + 3), (32, ky + 6)], 1.3, PANTS_SH, only=lm); s.limb([(37, 46), (38, 56)], 1.2, PANTS_SH, only=lm); s.limb([(hx + 4, hy), (32, ky - 3)], 1.2, PANTS_HI, only=lm)
        s.r(31, 49, 34, 49, PANTS_SH); s.r(33, 53, 37, 53, PANTS_SH); shoe(s, 36, 58)
    # braccio vicino: mano sulla manopola (verso il mare: posata sul ginocchio)
    hand = (33, 37) if kind == "sea" else (41, 35)
    elbow = (sx + 5, sy + 11) if kind == "sea" else (sx + 7, sy + 11)
    am = s.limb([(sx, sy + 3), elbow, (hand[0] - 2, hand[1])], 5, HOOD)
    s.limb([(sx + 1, sy + 2), (elbow[0] + 1, elbow[1] - 2), (hand[0] - 2, hand[1] - 2)], 1.2, HOOD_HI, only=am); s.limb([(sx - 1, sy + 5), (elbow[0] - 1, elbow[1] + 2)], 1.2, HOOD_SH, only=am)
    s.r(hand[0] - 2, hand[1] - 2, hand[0] + 1, hand[1] + 1, SKIN); s.p(hand[0] + 1, hand[1] + 1, SKIN_SH)
    s.padl(PAD).outline(); b.padl(PAD).outline()
    s.head = (ex - 3 + PAD, ey - 3); s.neck = (sx - 6 + PAD, sy - 2)
    return b, s
riders = {}
for k in ("ride0", "ride1", "stop", "sea", "horn", "kick"):
    rb, s = rider(k); add("rider_back_" + k, rb); add("rider_" + k, s); riders[k] = {"head": list(s.head), "neck": list(s.neck)}

def kneel(i):
    """seduto a gambe incrociate, in meditazione (templi)"""
    s = Spr(40, 50); dy = i
    s.limb([(13, 40), (4, 45), (20, 47)], 7, PANTS_SH); shoe(s, 23, 45, True)
    s.limb([(17, 40), (31, 44), (16, 47)], 7, PANTS); s.limb([(18, 38), (29, 42)], 1.2, PANTS_HI); s.limb([(28, 47), (17, 49)], 1.2, PANTS_SH); shoe(s, 12, 46)
    m = s.curve([(8, 42), (8, 33 + dy), (10, 25 + dy), (13, 21 + dy), (22, 21 + dy), (24, 26 + dy), (23, 34 + dy), (22, 42)], HOOD)
    s.limb([(9, 41), (9, 32 + dy), (12, 24 + dy)], 2.4, HOOD_SH, only=m); s.limb([(23, 25 + dy), (22, 36)], 1.3, HOOD_HI, only=m); s.r(8, 40, 22, 41, (46, 44, 56), only=m)
    s.ell(8, 17 + dy, 15, 24 + dy, HOOD); s.ell(9, 18 + dy, 12, 21 + dy, HOOD_HI)
    ex, ey = 11, 3 + dy
    s.r(ex + 2, ey + 2, ex + 13, ey + 14, SKIN); s.r(ex, ey + 1, ex + 4, ey + 9, HAIR); s.r(ex + 1, ey, ex + 12, ey + 4, HAIR); s.r(ex + 5, ey, ex + 8, ey, HAIR_HI)
    s.r(ex + 10, ey + 8, ex + 12, ey + 8, (30, 22, 30)); s.p(ex + 13, ey + 10, (232, 150, 140)); s.r(ex + 14, ey + 8, ex + 14, ey + 10, SKIN); s.r(ex + 5, ey + 7, ex + 5, ey + 8, SKIN_SH); s.r(ex + 10, ey + 12, ex + 12, ey + 12, (178, 108, 92))
    s.r(11, 18 + dy, 25, 22 + dy, SCARF); s.r(11, 22 + dy, 25, 22 + dy, SCARF_SH)
    for k in (13, 17, 21): s.r(k, 19 + dy, k + 1, 20 + dy, SCARF_ST)
    s.r(9, 22 + dy, 11, 33 + dy, SCARF); s.r(9, 30 + dy, 11, 31 + dy, SCARF_ST); s.r(9, 34 + dy, 11, 34 + dy, SCARF_SH)
    s.limb([(17, 26 + dy), (20, 35), (27, 40)], 5, HOOD); s.limb([(18, 25 + dy), (22, 34)], 1.2, HOOD_HI); s.r(27, 38, 30, 41, SKIN); s.p(30, 41, SKIN_SH)
    return s.outline()
for i in (0, 1): add(f"kneel{i}", kneel(i))

def helmet(back=False):
    s = Spr(22, 19)
    CR, CR_HI, CR_SH = (240, 232, 212), (255, 252, 240), (196, 184, 168)
    m = s.curve([(2, 10), (3, 5), (7, 2), (12, 1), (17, 3), (19, 7), (19, 9), (14, 9), (12, 12), (11, 16), (6, 16), (3, 14)] if not back else [(2, 10), (3, 5), (7, 2), (12, 1), (17, 3), (19, 8), (18, 14), (14, 16), (6, 16), (3, 14)], CR)
    s.limb([(3, 12), (5, 15), (10, 15)], 2, CR_SH, only=m); s.limb([(6, 4), (10, 2)], 1.6, CR_HI, only=m)
    s.limb([(11, 1), (9, 8), (9, 16)], 2.4, (200, 70, 56), only=m)      # striscia rossa
    if not back:
        s.limb([(14, 8), (19, 8)], 2, (120, 78, 52)); s.r(15, 6, 20, 9, (60, 44, 44)); s.r(16, 7, 19, 8, (150, 206, 236)); s.p(17, 7, (236, 250, 255))   # occhialoni alzati
        s.limb([(9, 14), (12, 17)], 1.2, (90, 60, 44))                     # cinturino
    else:
        s.limb([(3, 8), (18, 8)], 1.6, (120, 78, 52), only=m)
    s.p(5, 12, CHR_SH)
    return s.outline()
add("helmet", helmet()); add("helmet_back", helmet(True))

# ---------------------------------------------------------------- arredo del lungomare
IRON, IRON_HI = (40, 40, 58), (70, 70, 92)
def lamp():
    s = Spr(23, 108); x = 11
    s.r(x - 1, 20, x + 1, 104, IRON); s.r(x - 1, 20, x - 1, 104, IRON_HI); s.r(x - 3, 101, x + 3, 106, IRON); s.r(x - 4, 105, x + 4, 107, (54, 54, 74)); s.r(x - 2, 60, x + 2, 61, IRON_HI)
    s.poly([(x - 6, 8), (x + 6, 8), (x + 3, 4), (x - 3, 4)], IRON); s.r(x - 4, 9, x + 4, 18, IRON); s.r(x - 3, 10, x + 3, 17, (255, 216, 140)); s.r(x, 10, x, 17, (220, 160, 90)); s.r(x - 5, 18, x + 5, 19, IRON)
    s.r(x - 4, 2, x + 4, 4, SNOW); s.p(x, 1, SNOW); s.r(x - 6, 7, x + 6, 7, SNOW2)
    for k in (-1, 1):                                       # riccioli
        s.limb([(x + k * 2, 24), (x + k * 6, 26), (x + k * 5, 30)], 1, IRON)
    s.poly([(x - 5, 37), (x, 40), (x - 5, 43)], (196, 56, 52)); s.poly([(x + 5, 37), (x, 40), (x + 5, 43)], (196, 56, 52)); s.line(x, 41, x - 2, 49, (160, 40, 40)); s.line(x, 41, x + 2, 49, (160, 40, 40))
    for k in range(-6, 7, 2): s.p(x + k, 32 + abs(k) // 3, (46, 110, 70)); s.p(x + k + 1, 33 + abs(k) // 3, (60, 136, 84))
    return s
add("lamp", lamp())

def bench():
    s = Spr(34, 22)
    for y in (4, 7): s.r(1, y, 32, y + 1, (126, 82, 54)); s.r(1, y, 32, y, (160, 108, 70))
    s.r(0, 12, 33, 13, (140, 92, 60)); s.r(0, 14, 33, 14, (92, 60, 44))
    for x in (4, 28): s.r(x, 3, x + 1, 20, IRON); s.r(x - 2, 20, x + 3, 20, IRON)
    s.r(1, 2, 32, 3, SNOW); s.r(0, 10, 33, 11, SNOW); s.r(6, 1, 18, 1, SNOW)
    return s
add("bench", bench())

def pine(seed):
    """pino a ombrello della costa"""
    r = random.Random(seed); s = Spr(108, 118); tx = 54
    s.limb([(tx + 2, 117), (tx - 2, 80), (tx + 1, 40)], 5, (84, 58, 48)); s.limb([(tx + 3, 116), (tx, 80), (tx + 3, 42)], 1.6, (116, 82, 62))
    for (a, b) in ((-26, 34), (-14, 28), (14, 27), (28, 33)): s.limb([(tx, 56), (tx + a * .5, 42), (tx + a, b)], 2.4, (74, 52, 46))
    for k in range(19):
        a = -38 + k * 4.2; yy = 27 + 8 * (abs(a) / 40) ** 2 + r.uniform(-2, 2); w = r.uniform(8, 12)
        s.ell(tx + a - w, yy - 7, tx + a + w, yy + 7, (22, 54, 54))
    for k in range(17):
        a = -35 + k * 4.4; yy = 23 + 8 * (abs(a) / 40) ** 2 + r.uniform(-2, 1); w = r.uniform(6, 9)
        s.ell(tx + a - w, yy - 5, tx + a + w, yy + 4, (34, 78, 70))
    for k in range(120):
        x, y = r.randrange(4, 104), r.randrange(14, 40)
        if s.a[y, x, 3]: s.p(x, y, r.choice(((48, 98, 84), (26, 62, 60), (60, 112, 92))))
    for x in range(108):
        ys = np.nonzero(s.a[:, x, 3])[0]
        if len(ys) and ys[0] < 40:
            for k in range(2 + r.randrange(3)): s.p(x, ys[0] + k - 1, SNOW if k < 2 else SNOW2)
            if r.random() < .5: s.r(x, ys[0] + 8, x + r.randrange(4), ys[0] + 8, (206, 218, 244), only=s.m)
    return s.outline((16, 22, 34))
add("pine0", pine(1)); add("pine1", pine(5))

def tamarisk():
    r = random.Random(3); s = Spr(50, 60)
    s.limb([(25, 59), (23, 40), (27, 24)], 3, (92, 70, 62)); s.limb([(24, 44), (14, 28)], 2, (92, 70, 62)); s.limb([(25, 38), (36, 24)], 2, (92, 70, 62))
    for k in range(44):
        a = r.uniform(-20, 20); b = r.uniform(4, 30)
        if (a / 22) ** 2 + ((b - 18) / 16) ** 2 < 1: s.ell(25 + a - 3, b - 2, 25 + a + 3, b + 3, r.choice(((118, 130, 132), (92, 110, 118), (146, 156, 156))))
    s.snowcap(3); return s.outline((20, 24, 40))
add("tamarisk", tamarisk())

def kiosk():
    """edicola"""
    s = Spr(86, 76)
    s.r(8, 22, 77, 74, (46, 92, 86)); s.r(8, 22, 11, 74, (62, 116, 106)); s.r(74, 22, 77, 74, (32, 68, 68))
    s.poly([(2, 23), (84, 23), (74, 12), (12, 12)], (38, 76, 74)); s.r(24, 4, 61, 13, (28, 56, 58)); s.r(26, 6, 59, 11, (250, 214, 132))
    G3 = {"E": ["111", "100", "110", "100", "111"], "D": ["110", "101", "101", "101", "110"], "I": ["1", "1", "1", "1", "1"], "C": ["111", "100", "100", "100", "111"], "O": ["111", "101", "101", "101", "111"], "L": ["100", "100", "100", "100", "111"], "A": ["010", "101", "111", "101", "101"]}
    x = 28
    for ch in "EDICOLA":
        for yy, row in enumerate(G3[ch]):
            for xx, b in enumerate(row):
                if b == "1": s.p(x + xx, 6 + yy, (120, 44, 40))
        x += len(G3[ch][0]) + 1 + (1 if ch == "I" else 0)
    s.r(16, 28, 69, 52, (255, 206, 120)); s.r(16, 28, 69, 30, (255, 230, 168))
    r = random.Random(9)
    for yy in (34, 43):
        x = 18
        while x < 66:
            w = r.choice((4, 5, 6)); s.r(x, yy, x + w - 1, yy + 6, r.choice(((200, 70, 56), (70, 110, 180), (240, 232, 212), (90, 150, 110), (150, 90, 160), (226, 160, 70)))); s.r(x + 1, yy + 1, x + w - 2, yy + 1, (255, 250, 236)); x += w + 1
        s.r(16, yy + 7, 69, yy + 7, (140, 92, 60))
    s.r(12, 53, 73, 56, (110, 74, 52)); s.r(12, 53, 73, 53, (156, 108, 72))
    for x in range(18, 70, 9): s.r(x, 60, x + 6, 70, (34, 72, 70)); s.r(x, 60, x + 6, 60, (72, 128, 116))
    for x in range(4, 82, 6):                                   # tendina a strisce
        c = (200, 70, 56) if (x // 6) % 2 else (240, 232, 212)
        s.poly([(x, 23), (x + 6, 23), (x + 5, 30), (x + 1, 30)], c)
    s.r(0, 21, 85, 23, SNOW); s.r(6, 18, 79, 20, SNOW2); s.poly([(2, 23), (84, 23), (76, 14), (10, 14)], SNOW2); s.poly([(2, 22), (84, 22), (75, 13), (11, 13)], SNOW)
    s.r(24, 4, 61, 13, (28, 56, 58)); s.r(26, 6, 59, 11, (250, 214, 132)); x = 28
    for ch in "EDICOLA":
        for yy, row in enumerate(G3[ch]):
            for xx, b in enumerate(row):
                if b == "1": s.p(x + xx, 6 + yy, (120, 44, 40))
        x += len(G3[ch][0]) + 1 + (1 if ch == "I" else 0)
    s.r(23, 2, 62, 4, SNOW); s.r(30, 1, 50, 1, SNOW)
    return s.outline()
add("kiosk", kiosk())

def beachhut(c, seed):
    """cabina da spiaggia a strisce"""
    s = Spr(30, 54)
    for x in range(4, 26): s.r(x, 18, x, 52, c if (x // 3) % 2 else (236, 230, 216))
    s.poly([(1, 19), (28, 19), (15, 5)], mix(c, (20, 20, 40), .35)); s.poly([(0, 18), (29, 18), (16, 3), (14, 3)], SNOW); s.poly([(4, 18), (25, 18), (15, 8)], mix(c, (20, 20, 40), .35))
    s.r(10, 28, 19, 52, (104, 72, 54)); s.r(11, 29, 18, 52, (132, 92, 66)); s.r(17, 40, 17, 41, (242, 200, 100))
    if seed % 2: s.r(12, 31, 17, 35, (255, 208, 120)); s.r(14, 31, 14, 35, (180, 120, 70))
    s.r(2, 51, 27, 53, SNOW); s.ell(13, 12, 16, 15, (255, 224, 150) if seed % 2 else (60, 56, 80))
    return s.outline()
for i, c in enumerate(((70, 120, 176), (196, 78, 64), (88, 150, 120), (214, 160, 70))): add(f"hut{i}", beachhut(c, i))

def boat(c, seed):
    """gozzo con albero e lucine"""
    s = Spr(66, 72)
    s.r(31, 4, 32, 52, (120, 86, 62)); s.line(32, 8, 60, 50, (90, 84, 110)); s.line(31, 8, 4, 50, (90, 84, 110))
    for k in range(9):
        t = k / 8; s.p(32 + 28 * t, 8 + 42 * t + 2, LCOL[(k + seed) % 4]); s.p(31 - 27 * t, 8 + 42 * t + 2, LCOL[(k + seed + 2) % 4])
    s.poly([(2, 50), (64, 48), (57, 64), (10, 64)], c); s.poly([(5, 58), (61, 57), (57, 64), (10, 64)], mix(c, (16, 16, 40), .35)); s.line(2, 51, 64, 49, (240, 232, 212), 2)
    s.r(38, 38, 52, 49, (226, 220, 206)); s.r(40, 40, 44, 45, (255, 210, 124)); s.r(47, 40, 50, 45, (255, 210, 124)); s.r(37, 36, 53, 38, SNOW)
    s.limb([(8, 47), (22, 45), (30, 48)], 3, SNOW); s.r(54, 54, 55, 56, (240, 130, 60))
    return s.outline()
add("boat0", boat((176, 62, 54), 0)); add("boat1", boat((60, 108, 160), 1))

def lighthouse():
    s = Spr(96, 108)
    for (x, y, w, h) in ((0, 92, 34, 16), (20, 84, 40, 24), (52, 88, 42, 20)):
        s.poly([(x, y + h), (x + w * .12, y + 3), (x + w * .5, y), (x + w * .88, y + 3), (x + w, y + h)], (54, 54, 84)); s.poly([(x + w * .1, y + h), (x + w * .3, y + 4), (x + w * .52, y + h)], (74, 74, 108)); s.poly([(x + w * .1, y + 4), (x + w * .5, y - 2), (x + w * .9, y + 4), (x + w * .5, y + 2)], SNOW)
    s.poly([(34, 88), (54, 88), (51, 24), (37, 24)], (236, 232, 226)); s.poly([(47, 88), (54, 88), (51, 24), (47, 24)], (188, 186, 202))
    for y0 in (34, 54, 74): s.r(33, y0, 54, y0 + 9, (192, 66, 56))
    # rifila le fasce al profilo della torre
    for y in range(24, 89):
        t = (y - 24) / 64; l, rr = 37 - 3 * t, 51 + 3 * t
        for x in range(28, 62):
            if (x < l or x > rr) and tuple(s.a[y, x, :3]) in ((192, 66, 56),): s.a[y, x] = 0
        for x in range(int(rr) - 4, int(rr) + 1):
            if tuple(s.a[y, x, :3]) == (192, 66, 56): s.p(x, y, (148, 46, 46))
    s.r(43, 46, 46, 50, (255, 210, 124)); s.r(43, 66, 46, 70, (60, 56, 84))
    s.r(33, 21, 55, 24, IRON); s.r(33, 20, 55, 20, SNOW)
    for x in range(34, 56, 4): s.r(x, 17, x, 20, IRON)
    s.r(38, 8, 50, 20, IRON); s.r(39, 10, 49, 18, (255, 236, 170)); s.r(44, 10, 44, 18, (220, 160, 90))
    s.poly([(36, 9), (52, 9), (44, 1)], (150, 52, 48)); s.poly([(37, 7), (51, 7), (44, 0)], SNOW); s.poly([(39, 9), (49, 9), (44, 4)], (150, 52, 48))
    s.r(60, 74, 80, 88, (214, 206, 196)); s.poly([(57, 75), (83, 75), (70, 65)], SNOW); s.r(66, 78, 70, 84, (255, 206, 120))
    return s.outline((20, 20, 40))
add("lighthouse", lighthouse())

def pisa():
    """skyline lontano: torre pendente, cupola del duomo, battistero"""
    s = Spr(120, 50); C, C2, C3 = (206, 190, 206), (176, 160, 188), (146, 134, 170)
    s.r(0, 44, 119, 49, C3)
    for x in range(0, 120, 5): s.r(x, 43 - (x * 7) % 4, x + 4, 49, (120, 116, 158))
    s.ell(8, 18, 38, 46, C2); s.ell(10, 18, 30, 46, C); s.r(6, 33, 40, 49, C2); s.r(8, 33, 30, 49, C); s.poly([(19, 20), (27, 20), (23, 9)], C); s.p(23, 7, C2)
    for x in range(9, 38, 4): s.r(x, 37, x + 1, 42, C3)
    s.r(48, 30, 84, 49, C2); s.r(48, 30, 76, 49, C); s.poly([(46, 31), (86, 31), (66, 23)], C2); s.ell(58, 14, 74, 32, C2); s.ell(59, 14, 70, 32, C); s.r(65, 10, 67, 14, C)
    for x in range(50, 84, 5): s.r(x, 36, x + 2, 46, C3)
    for k in range(8):                                            # torre: otto ordini, sempre più a destra
        y = 46 - k * 5; ox = 94 + k * .62; w = 11 if k < 7 else 8; ox += 1.5 if k == 7 else 0
        s.r(ox, y - 4, ox + w, y, C); s.r(ox + w - 3, y - 4, ox + w, y, C2); s.r(ox - 1, y, ox + w + 1, y, C3)
        for x in range(int(ox) + 1, int(ox + w), 2): s.p(x, y - 2, C3); s.p(x, y - 1, C3)
    s.r(98, 48, 112, 49, C3)
    return s
add("pisa", pisa())

def island(w, h, seed):
    r = random.Random(seed); s = Spr(w, h); a, b = r.uniform(.3, .5), r.uniform(.1, .2)
    for x in range(w):
        t = x / (w - 1); hh = h * (math.sin(math.pi * t) ** .8) * (.62 + a * math.sin(t * 7 + seed) * .5 + b * math.sin(t * 19))
        for y in range(int(h - max(0, hh)), h): s.p(x, y, (255, 255, 255, 255))
    return s
add("island0", island(64, 13, 2)); add("island1", island(104, 18, 5)); add("island2", island(150, 9, 9))

def ferry():
    s = Spr(46, 16); s.poly([(0, 9), (45, 9), (41, 15), (4, 15)], (54, 60, 96)); s.r(5, 5, 38, 8, (206, 210, 226)); s.r(10, 2, 32, 5, (206, 210, 226)); s.r(26, 0, 30, 2, (196, 70, 60))
    for x in range(7, 38, 3): s.p(x, 7, (255, 214, 130))
    for x in range(12, 32, 3): s.p(x, 4, (255, 214, 130))
    return s
add("ferry", ferry())
def sail():
    s = Spr(15, 20); s.poly([(7, 0), (7, 14), (14, 14)], (236, 236, 246)); s.poly([(6, 3), (6, 14), (1, 14)], (200, 206, 230)); s.poly([(0, 15), (14, 15), (11, 18), (3, 18)], (84, 60, 70)); return s
add("sail", sail())

def gull(i):
    s = Spr(15, 11); W_, G_ = (246, 248, 255), (176, 184, 212)
    if i == 0:                                                # posato
        s.ell(3, 4, 11, 8, W_); s.r(1, 5, 5, 6, G_); s.ell(9, 1, 12, 5, W_); s.p(11, 2, OUT); s.r(13, 3, 14, 3, (242, 180, 80)); s.r(6, 9, 6, 10, (242, 150, 70)); s.r(8, 9, 8, 10, (242, 150, 70)); s.r(1, 6, 2, 6, (70, 70, 96))
    elif i == 1:
        s.line(0, 1, 5, 5, W_, 2); s.line(14, 1, 9, 5, W_, 2); s.r(5, 5, 10, 6, W_); s.p(0, 1, (70, 70, 96)); s.p(14, 1, (70, 70, 96)); s.p(11, 5, (242, 180, 80))
    else:
        s.line(0, 8, 5, 5, W_, 2); s.line(14, 8, 9, 5, W_, 2); s.r(5, 4, 10, 6, W_); s.p(0, 9, (70, 70, 96)); s.p(14, 9, (70, 70, 96)); s.p(11, 5, (242, 180, 80))
    return s
for i in range(3): add(f"gull{i}", gull(i))

def cat(i):
    s = Spr(24, 22); C, D, L = (232, 150, 70), (190, 106, 46), (250, 214, 160)
    s.ell(5, 8, 16, 20, C); s.ell(11, 2, 21, 12, C); s.poly([(12, 4), (12, 0), (15, 3)], C); s.poly([(18, 3), (21, 0), (21, 5)], C); s.r(14, 15, 17, 20, C); s.r(13, 20, 18, 20, L); s.ell(11, 12, 15, 18, L)
    for y in (10, 13, 16): s.r(6, y, 9, y, D)
    s.r(15, 2, 15, 4, D); s.r(17, 2, 17, 4, D); s.p(15, 7, OUT) if i < 2 else s.r(14, 7, 15, 7, D); s.p(19, 7, OUT) if i < 2 else s.r(19, 7, 20, 7, D); s.p(17, 9, (220, 110, 110))
    tx = [(5, 18), (1, 16), (2, 11)] if i % 2 == 0 else [(5, 18), (1, 18), (0, 14)]
    s.limb(tx, 2, C); s.p(tx[2][0], tx[2][1], D)
    return s.outline()
for i in range(3): add(f"cat{i}", cat(i))

def snowman():
    s = Spr(32, 48)
    s.ell(6, 26, 26, 46, (240, 245, 255)); s.ell(9, 13, 23, 28, (244, 248, 255)); s.ell(10, 4, 21, 15, (248, 250, 255)); s.ell(17, 28, 26, 45, SNOW2, only=s.m); s.ell(19, 15, 23, 27, SNOW2, only=s.m)
    s.r(11, 8, 15, 10, (30, 28, 40)); s.r(17, 8, 21, 10, (30, 28, 40)); s.r(15, 8, 17, 8, (30, 28, 40)); s.p(12, 8, (130, 170, 220)); s.p(18, 8, (130, 170, 220)); s.poly([(16, 11), (23, 12), (16, 13)], (240, 130, 50))
    s.r(9, 2, 22, 4, (226, 190, 120)); s.r(12, -0, 19, 2, (226, 190, 120)); s.r(12, 2, 19, 2, (196, 70, 56)); s.r(10, 14, 21, 16, (90, 150, 190)); s.r(19, 16, 21, 22, (90, 150, 190))
    s.line(8, 20, 1, 13, (100, 70, 50)); s.line(24, 20, 30, 15, (100, 70, 50)); s.p(16, 20, OUT); s.p(16, 24, OUT); s.p(16, 32, OUT)
    s.ell(24, 34, 31, 41, (230, 80, 70)); s.ell(26, 34, 29, 41, (246, 240, 226))       # pallone da spiaggia
    return s.outline((60, 66, 104))
add("snowman", snowman())

def scope():
    """cannocchiale a gettone del belvedere"""
    s = Spr(26, 44); s.r(11, 18, 14, 42, (70, 90, 104)); s.r(11, 18, 11, 42, (112, 134, 146)); s.r(7, 41, 18, 43, (54, 66, 80)); s.poly([(3, 6), (20, 3), (22, 13), (5, 15)], (86, 112, 126)); s.poly([(3, 6), (20, 3), (20, 6), (4, 9)], (136, 162, 172)); s.r(20, 2, 23, 14, (54, 66, 80)); s.r(1, 7, 3, 14, (54, 66, 80)); s.r(22, 5, 23, 11, (170, 220, 250)); s.r(8, 15, 17, 18, (70, 90, 104)); s.p(13, 24, (242, 200, 100)); s.r(4, 4, 19, 5, SNOW); s.p(12, 3, SNOW); s.p(13, 3, SNOW)
    return s.outline()
add("scope", scope())

def stairs():
    """scalinata da cui si arriva dal paese"""
    s = Spr(96, 120); W1, W2, W3 = (112, 106, 138), (136, 130, 160), (86, 82, 116)
    s.r(0, 0, 48, 119, W1)
    for y in range(0, 120, 9):
        for x in range(-((y // 9) % 2) * 8, 48, 16): s.r(x, y, x + 14, y + 7, W2, only=s.m); s.r(x, y + 7, x + 14, y + 7, W3, only=s.m)
    for k in range(7):
        x = 48 + k * 6; y = 62 + k * 8
        s.r(0 if k == 0 else x - 6, y, x + 5, 119, W1); s.r(x - 6, y, x + 5, y, W2)
        for yy in range(y + 10, 119, 10): s.r(x - 4, yy, x + 3, yy, W3)
        s.r(x - 6, y - 3, x + 6, y - 1, SNOW); s.r(x - 6, y - 1, x + 6, y - 1, SNOW2); s.r(x + 5, y + 1, x + 5, 119, W3)
    s.r(0, 62, 48, 64, SNOW)
    s.limb([(46, 38), (88, 94)], 1.6, IRON)
    for k in range(5): s.r(46 + k * 10, 38 + k * 13, 46 + k * 10, 58 + k * 12, IRON)
    s.r(0, 0, 44, 2, SNOW); s.r(0, 3, 40, 4, SNOW2)
    return s.outline((30, 28, 54))
add("stairs", stairs())

# ---- nella strada: bivio per il mare
def fork():
    """sentiero che scende tra i cumuli, con lucine ai bordi"""
    s = Spr(84, 46)
    for k in range(6):
        y = 2 + k * 7; hw = 15 + k * 4
        s.poly([(42 - hw, y), (42 + hw, y), (42 + hw + 4, y + 7), (42 - hw - 4, y + 7)], (196, 202, 226) if k % 2 else (182, 190, 218)); s.r(42 - hw, y, 42 + hw, y + 1, (236, 242, 255)); s.r(42 - hw, y + 2, 42 + hw, y + 2, (150, 158, 196))
        for j in range(3): s.r(42 - hw + 6 + (j * 17 + k * 11) % (2 * hw - 10), y + 4, 42 - hw + 8 + (j * 17 + k * 11) % (2 * hw - 10), y + 4, (160, 168, 204))
    for sg in (-1, 1):
        for k in range(7):
            cx = 42 + sg * (21 + k * 4.2); y = 2 + k * 6.6
            s.ell(cx - 7, y - 3, cx + 7, y + 9, (236, 242, 255)); s.ell(cx - 6, y + 2, cx + 6, y + 9, (212, 222, 246))
        for k in range(6): s.p(42 + sg * (16 + k * 4.4), 3 + k * 7, LCOL[k % 4]); s.p(42 + sg * (16 + k * 4.4), 2 + k * 7, mix(LCOL[k % 4], (255, 255, 255), .5))
    return s
add("fork", fork())

def signpost():
    s = Spr(52, 56)
    s.r(24, 8, 27, 55, (104, 70, 48)); s.r(24, 8, 24, 55, (140, 98, 66)); s.r(27, 8, 27, 55, (76, 50, 38))
    s.poly([(4, 10), (40, 10), (48, 17), (40, 24), (4, 24)], (138, 92, 58)); s.r(5, 11, 39, 11, (172, 122, 80)); s.r(5, 23, 39, 23, (100, 66, 46))
    G = {"M": ["10001", "11011", "10101", "10001", "10001"], "A": ["010", "101", "111", "101", "101"], "R": ["110", "101", "110", "101", "101"], "E": ["111", "100", "110", "100", "111"]}
    x = 9
    for ch in "MARE":
        for yy, row in enumerate(G[ch]):
            for xx, b in enumerate(row):
                if b == "1": s.p(x + xx, 15 + yy, (255, 240, 206))
        x += len(G[ch][0]) + 1
    for k in range(6): s.p(31 + k, 17, (255, 224, 140)); 
    s.p(35, 15, (255, 224, 140)); s.p(36, 16, (255, 224, 140)); s.p(35, 19, (255, 224, 140)); s.p(36, 18, (255, 224, 140))
    s.r(9, 27, 42, 48, (60, 108, 160)); s.r(9, 27, 42, 27, (110, 160, 206)); s.r(10, 28, 41, 47, (44, 84, 136))
    ic = np.zeros((VH, VW + PAD), bool); ic |= P["vespa"].m; ic |= P["vespa_back"].m
    for wx in (15 + PAD, 54 + PAD): ic[31:50, wx - 9:wx + 10] |= P["wheel0"].m
    ic = np.asarray(Image.fromarray((ic * 255).astype(np.uint8)).resize((26, 18), Image.BOX)) > 110
    for yy, xx in zip(*np.nonzero(ic)): s.p(13 + xx, 29 + yy, (240, 244, 255))
    s.r(4, 8, 40, 9, SNOW); s.r(8, 7, 30, 7, SNOW); s.r(9, 25, 42, 26, SNOW); s.r(22, 6, 29, 8, SNOW)
    s.ell(19, 50, 33, 58, SNOW)
    return s.outline()
add("signpost", signpost())

def roadsign():
    """cartello stradale di località (il testo lo scrive il gioco)"""
    s = Spr(66, 60); s.r(14, 22, 16, 59, (120, 124, 148)); s.r(50, 22, 52, 59, (120, 124, 148)); s.r(14, 22, 14, 59, (170, 174, 196)); s.r(50, 22, 50, 59, (170, 174, 196))
    s.r(1, 3, 64, 29, (236, 238, 246)); s.r(2, 4, 63, 28, (30, 30, 46)); s.r(3, 5, 62, 27, (242, 244, 250)); s.r(0, 1, 65, 2, SNOW); s.r(10, 0, 50, 0, SNOW)
    return s.outline()
add("roadsign", roadsign())

# ---------------------------------------------------------------- tappe: un oggetto per sezione, con uno spazio 16x16 per l'emblema
stops = {}
def stop(name, s, ex, ey): add("stop_" + name, s.outline()); stops[name] = [ex, ey]

s = Spr(40, 58)                                              # libreria: casetta dei libri
s.r(18, 38, 21, 57, (104, 70, 48)); s.r(18, 38, 18, 57, (140, 98, 66)); s.r(5, 14, 34, 40, (120, 78, 50)); s.r(5, 14, 6, 40, (156, 106, 70)); s.r(33, 14, 34, 40, (88, 56, 40))
s.poly([(1, 15), (38, 15), (20, 3)], (70, 44, 52)); s.poly([(0, 14), (39, 14), (21, 1), (18, 1)], SNOW); s.poly([(6, 14), (33, 14), (20, 6)], (70, 44, 52))
s.r(8, 16, 31, 38, (60, 38, 30)); s.r(9, 17, 30, 33, (255, 206, 120)); s.r(11, 17, 28, 33, (84, 50, 42)); x = 9
for w, c in ((3, (200, 70, 56)), (2, (70, 110, 180)), (3, (90, 150, 110)), (2, (240, 232, 212)), (3, (150, 90, 160)), (2, (226, 160, 70)), (3, (60, 120, 150)), (4, (176, 62, 54))): s.r(x, 34, x + w - 1, 37, c); x += w
s.r(8, 38, 31, 38, (140, 92, 60)); s.r(31, 26, 32, 28, (242, 200, 100)); s.ell(13, 53, 27, 60, SNOW); stop("libreria", s, 12, 17)

s = Spr(40, 60)                                              # letto: cabina con la luce accesa
for x in range(4, 36): s.r(x, 18, x, 58, (200, 108, 78) if (x // 4) % 2 else (240, 228, 208))
s.poly([(1, 19), (38, 19), (20, 4)], (110, 52, 46)); s.poly([(0, 18), (39, 18), (21, 1), (18, 1)], SNOW); s.poly([(6, 18), (33, 18), (20, 7)], (110, 52, 46))
s.r(9, 22, 30, 45, (90, 60, 48)); s.r(10, 23, 29, 42, (255, 206, 120)); s.r(12, 25, 27, 40, (92, 54, 46)); s.r(9, 43, 30, 45, (140, 98, 70)); s.r(8, 46, 31, 47, SNOW); s.r(14, 50, 25, 58, (104, 70, 54)); s.r(23, 54, 23, 54, (242, 200, 100)); s.r(1, 57, 38, 59, SNOW); stop("letto", s, 12, 25)

s = Spr(44, 56)                                              # scrivania: monitor a tubo su un tavolino
s.r(2, 38, 41, 41, (134, 92, 60)); s.r(2, 38, 41, 38, (172, 124, 82)); s.r(5, 42, 7, 55, (100, 68, 48)); s.r(36, 42, 38, 55, (100, 68, 48)); s.r(6, 8, 37, 34, (206, 200, 186)); s.r(6, 8, 37, 9, (236, 230, 216)); s.r(36, 8, 37, 34, (160, 154, 148)); s.r(6, 33, 37, 34, (160, 154, 148))
s.r(10, 11, 33, 30, (30, 30, 46)); s.r(11, 12, 32, 29, (22, 40, 62)); s.r(33, 32, 34, 32, (110, 230, 140)); s.r(15, 35, 28, 37, (170, 164, 156)); s.r(8, 36, 12, 37, (60, 58, 76)); s.r(5, 7, 38, 8, SNOW); s.r(10, 6, 26, 6, SNOW); s.r(1, 37, 5, 37, SNOW); s.r(38, 37, 42, 37, SNOW); s.r(35, 34, 38, 37, (200, 70, 56)); s.p(39, 35, (200, 70, 56))
s.r(1, 54, 42, 55, SNOW); stop("scrivania", s, 14, 13)

s = Spr(44, 60)                                              # lavagna sul cavalletto
s.limb([(8, 30), (4, 58)], 2, (120, 80, 52)); s.limb([(35, 30), (39, 58)], 2, (120, 80, 52)); s.limb([(22, 30), (22, 56)], 2, (92, 60, 42)); s.r(3, 6, 40, 38, (138, 90, 54)); s.r(3, 6, 40, 7, (176, 122, 78)); s.r(5, 8, 38, 35, (38, 78, 62)); s.r(5, 8, 38, 9, (30, 64, 52))
for (x, y, l) in ((7, 12, 4), (7, 15, 3), (7, 30, 5), (32, 12, 4), (33, 30, 3), (31, 33, 5)): s.r(x, y, x + l - 1, y, (150, 186, 164))
s.r(5, 36, 38, 38, (120, 80, 52)); s.r(9, 36, 12, 36, (246, 244, 236)); s.r(14, 36, 16, 36, (242, 200, 100)); s.r(26, 35, 31, 36, (90, 70, 90)); s.r(2, 4, 41, 6, SNOW); s.r(8, 3, 28, 3, SNOW); s.r(1, 57, 8, 59, SNOW); s.r(36, 57, 43, 59, SNOW); stop("lavagna", s, 14, 13)

s = Spr(44, 60)                                              # finestra: aperta su un pezzo di cielo
s.r(20, 42, 23, 59, (104, 70, 48)); s.r(8, 6, 35, 42, (150, 98, 60)); s.r(8, 6, 35, 7, (190, 134, 86)); s.r(11, 9, 32, 39, (27, 35, 80)); s.r(11, 9, 32, 14, (20, 26, 62)); s.r(11, 34, 32, 39, (70, 66, 128))
for (x, y) in ((13, 11), (28, 12), (31, 20), (12, 28), (30, 31)): s.p(x, y, (255, 240, 200))
for x0 in (1, 36):
    s.r(x0, 7, x0 + 6, 41, (60, 120, 110)); s.r(x0, 7, x0 + 6, 7, (92, 160, 144))
    for y in range(10, 40, 3): s.r(x0 + 1, y, x0 + 5, y, (42, 92, 88))
s.r(6, 42, 37, 44, (176, 122, 78)); s.r(6, 4, 37, 6, SNOW); s.r(12, 3, 30, 3, SNOW); s.r(5, 41, 38, 42, SNOW); s.r(0, 6, 7, 6, SNOW); s.r(36, 6, 43, 6, SNOW); s.ell(13, 55, 30, 62, SNOW); stop("finestra", s, 14, 16)

# ================================================================ emblemi 16x16 (scelti dal gioco in base al titolo della voce)
EM = {}
K = (26, 23, 51); W_ = (246, 244, 236); GO = (242, 184, 91); RE = (208, 78, 64); BL = (96, 150, 220); GR = (110, 180, 130); PU = (150, 110, 190); BR = (138, 92, 58); GY = (150, 156, 180)
def em(name):
    s = Spr(16, 16); EM[name] = s; return s
s = em("telescope"); s.limb([(4, 9), (12, 4)], 4, W_); s.limb([(4, 9), (6, 8)], 4, GO); s.line(8, 9, 5, 15, GY); s.line(8, 9, 11, 15, GY); s.p(14, 1, GO); s.p(2, 2, BL); s.p(8, 1, W_); s.p(13, 10, BL); s.p(1, 13, W_)
s = em("grades"); s.poly([(0, 6), (8, 2), (15, 6), (8, 10)], GO); s.r(4, 9, 11, 12, RE); s.line(14, 6, 14, 11, W_); s.r(13, 11, 14, 13, W_)
s = em("trend"); s.line(1, 14, 15, 14, GY); s.line(1, 1, 1, 14, GY); s.line(2, 12, 6, 8, GR); s.line(6, 8, 9, 10, GR); s.line(9, 10, 14, 3, GR); s.r(12, 2, 14, 3, GO); s.r(14, 2, 14, 5, GO)
s = em("vault"); s.r(3, 7, 12, 14, GO); s.r(3, 14, 12, 14, BR); s.limb([(5, 7), (5, 4), (8, 2), (10, 4), (10, 7)], 1.6, GY); s.r(7, 9, 8, 12, K)
s = em("gallery"); s.r(1, 3, 10, 12, W_); s.r(4, 5, 14, 14, GY); s.r(5, 6, 13, 13, BL); s.poly([(5, 13), (8, 9), (10, 12), (11, 11), (13, 13)], GR); s.r(11, 7, 12, 8, GO)
s = em("candles")
for x, y0, y1, c in ((1, 8, 12, RE), (5, 6, 11, GR), (9, 7, 10, RE), (13, 2, 8, GR)): s.r(x, y0, x + 1, y1, c); s.r(x, y0 - 2, x, y1 + 2, c)
s = em("field"); s.ell(1, 6, 4, 9, RE); s.ell(11, 6, 14, 9, BL)
for dy in (-5, -3, 3, 5): s.line(3, 8 + dy * .4, 8, 8 + dy, GO); s.line(8, 8 + dy, 12, 8 + dy * .4, GO)
s.r(5, 8, 10, 8, W_); s.p(9, 7, W_); s.p(9, 9, W_)
s = em("pendulum"); s.r(2, 1, 13, 2, BR); s.line(7, 2, 12, 10, W_); s.ell(10, 9, 14, 13, GO); s.p(3, 12, GY); s.p(5, 14, GY); s.p(8, 15, GY); s.line(7, 2, 7, 6, GY)
s = em("integral"); s.limb([(6, 14), (4, 13)], 1, W_); s.limb([(6, 13), (8, 2)], 1.4, W_); s.limb([(8, 2), (10, 2)], 1, W_); s.line(11, 8, 14, 12, GO); s.line(14, 8, 11, 12, GO)
s = em("vectors"); s.line(2, 14, 15, 14, GY); s.line(2, 14, 2, 1, GY); s.line(2, 14, 12, 8, RE); s.line(2, 14, 7, 3, BL); s.r(11, 8, 12, 9, RE); s.r(6, 3, 7, 4, BL); s.p(13, 3, GO); s.line(7, 3, 13, 3, (90, 100, 140)); s.line(12, 8, 13, 3, (90, 100, 140))
s = em("flask"); s.poly([(6, 1), (9, 1), (9, 6), (14, 14), (1, 14), (6, 6)], W_); s.poly([(5, 9), (10, 9), (13, 14), (2, 14)], GR); s.r(5, 1, 10, 1, GY); s.p(7, 11, W_); s.p(9, 12, W_)
s = em("parabola"); s.line(0, 14, 15, 14, GY)
for k in range(15): s.p(k, 13 - 11 * (1 - ((k - 7) / 7) ** 2) if k < 15 else 13, GO)
s.ell(11, 5, 14, 8, RE)
s = em("branch"); s.line(4, 3, 4, 13, GY, 1); s.line(4, 9, 11, 6, GY); s.ell(2, 1, 5, 4, GR); s.ell(2, 11, 5, 14, GO); s.ell(10, 3, 13, 6, BL)
s = em("book"); s.poly([(0, 4), (7, 5), (7, 14), (0, 12)], W_); s.poly([(8, 5), (15, 4), (15, 12), (8, 14)], (226, 220, 206)); s.r(7, 5, 8, 14, RE)
for y in (7, 9): s.r(2, y, 5, y, GY); s.r(10, y, 13, y, GY)
s = em("butterfly"); s.ell(1, 2, 7, 8, GO); s.ell(9, 2, 15, 8, GO); s.ell(2, 8, 7, 13, RE); s.ell(9, 8, 14, 13, RE); s.r(8, 4, 8, 13, K); s.p(6, 1, W_); s.p(10, 1, W_); s.p(4, 5, W_); s.p(12, 5, W_)
s = em("dream"); m = s.ell(3, 3, 13, 13, GO); s.a[s._mask(lambda d: d.ellipse([7 * SS, 1 * SS, 16 * SS, 11 * SS], fill=255))] = 0; s.r(10, 3, 13, 3, W_); s.line(13, 4, 10, 6, W_); s.r(10, 6, 13, 6, W_); s.r(13, 9, 15, 9, BL); s.p(14, 10, BL); s.r(13, 11, 15, 11, BL)
s = em("chat"); s.r(1, 2, 10, 8, W_); s.poly([(2, 8), (6, 8), (2, 11)], W_); s.r(5, 6, 14, 12, BL); s.poly([(10, 12), (13, 12), (13, 15)], BL); s.r(7, 9, 7, 9, W_); s.r(9, 9, 9, 9, W_); s.r(11, 9, 11, 9, W_); s.r(3, 4, 8, 4, GY)
s = em("tower")
for k in range(6): s.r(4 + k * .6, 13 - k * 2 - 1, 10 + k * .6, 13 - k * 2, W_ if k % 2 else (214, 206, 196)); s.p(5 + k * .6, 13 - k * 2, GY); s.p(8 + k * .6, 13 - k * 2, GY)
s.r(1, 14, 14, 14, GR); s.p(10, 0, RE); s.p(9, 1, GY)
s = em("diploma"); s.r(2, 3, 13, 11, W_); s.r(1, 3, 2, 11, (214, 206, 190)); s.r(13, 3, 14, 11, (214, 206, 190)); s.r(4, 5, 11, 5, GY); s.r(4, 7, 9, 7, GY); s.ell(9, 8, 13, 12, RE); s.line(10, 12, 9, 15, RE); s.line(12, 12, 13, 15, RE)
s = em("code"); s.line(4, 4, 1, 8, GO); s.line(1, 8, 4, 12, GO); s.line(11, 4, 14, 8, GO); s.line(14, 8, 11, 12, GO); s.line(9, 2, 6, 14, BL)
s = em("tools"); s.limb([(4, 12), (11, 5)], 2, GY); s.ell(9, 1, 14, 6, GY); s.r(12, 1, 14, 3, (0, 0, 0, 0)); s.limb([(3, 3), (12, 13)], 1.4, GO); s.r(1, 1, 4, 4, RE)
s = em("pen"); s.limb([(4, 12), (12, 3)], 2.6, GO); s.poly([(1, 15), (3, 11), (6, 13)], W_); s.p(1, 15, K); s.limb([(11, 4), (13, 2)], 2.6, RE); s.r(7, 15, 14, 15, GY)
s = em("star"); s.poly([(8, 0), (10, 5), (15, 6), (11, 9), (12, 15), (8, 12), (3, 15), (4, 9), (0, 6), (5, 5)], GO)
s = em("cert"); s.ell(3, 1, 12, 10, GO); s.ell(5, 3, 10, 8, W_); s.line(5, 10, 3, 15, RE, 1); s.line(6, 10, 5, 15, RE); s.line(10, 10, 12, 15, BL); s.line(9, 10, 10, 15, BL)
names = list(EM)
sheet = np.concatenate([EM[n].a for n in names], axis=1)
Image.fromarray(sheet).save(os.path.join(IMG, "sea_emblems.png"))

# ================================================================ atlante
order = sorted(P, key=lambda n: -P[n].h)
AW = 512; x = y = rowh = 0; rects = {}
for n in order:
    s = P[n]
    if x + s.w + 1 > AW: x, y, rowh = 0, y + rowh + 1, 0
    rects[n] = [x, y, s.w, s.h]; x += s.w + 1; rowh = max(rowh, s.h)
atlas = np.zeros((y + rowh, AW, 4), np.uint8)
for n, (x, y, w, h) in rects.items(): atlas[y:y + h, x:x + w] = P[n].a
Image.fromarray(atlas).save(os.path.join(IMG, "sea_props.png"))
json.dump({"horizon": HORIZON, "sky_h": SKY_H, "phases": len(PH), "rects": rects, "riders": riders, "stops": stops, "emblems": names,
           "walk_feet": 180, "wheel_y": 182, "curb": 160, "vespa": {"w": VW + PAD, "h": VH, "rear": [15 + PAD, 40], "front": [54 + PAD, 40], "r": 9, "rider_dy": -26, "lamp": [56 + PAD, 7], "exhaust": [3 + PAD, 44], "tail": [1 + PAD, 28], "seat": [13 + PAD, -2]}},
          open(os.path.join(DATA, "sea.json"), "w"))
print("ok", atlas.shape, len(P), "sprite,", len(names), "emblemi")
