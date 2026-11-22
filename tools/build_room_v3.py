"""Cameretta v2 — prospettiva centrale (vista dalla porta verso la portafinestra).
Piccolo raycaster a scatole + texture procedurali, poi posterizzazione con dithering
e contorni, per ottenere un look pixel art. Output: room_v2.png (320x200),
room_v2_x4.png, hotspots_v2.json (bounding box in pixel degli oggetti cliccabili).
"""
import json, math
import numpy as np
from PIL import Image

W, H = 320, 200
F = 188.0                  # focale in pixel
CX, CY = W / 2, 70.0       # centro ottico (orizzonte alla riga 90)
CAM = np.array([-20.0, 168.0, -110.0])
RX, RY, RZ = 150.0, 260.0, 450.0   # stanza: x in [-150,150], y in [0,260], z in [0,450]

u, v = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
D = np.stack([(u - CX) / F, (CY - v) / F, np.ones_like(u)], -1).reshape(-1, 3)
N = D.shape[0]

def h2(a, b, seed=0):
    """hash deterministico -> [0,1)"""
    x = np.sin(a * 12.9898 + b * 78.233 + seed * 37.719) * 43758.5453
    return x - np.floor(x)

# ---------------- scena ----------------
# (nome, gruppo hotspot, x0,x1, y0,y1, z0,z1)
BOXES = [
    # letto (testa verso la finestra, piedi verso il centro)
    ("bed_frame", "letto", 60, 150, 0, 36, 250, 446),
    ("mattress", "letto", 62, 150, 36, 52, 252, 444),
    ("pillow", "letto", 74, 142, 52, 63, 402, 438),
    ("headboard", "letto", 60, 150, 0, 112, 444, 450),
    # scrivania davanti ai piedi del letto
    ("desk", "scrivania", 85, 150, 0, 75, 112, 248),
    ("monitor_stand", "scrivania", 130, 137, 75, 96, 178, 190),
    ("monitor", "scrivania", 121, 127, 92, 138, 140, 228),
    ("laptop_base", "scrivania", 94, 118, 75, 77, 205, 238),
    ("laptop_lid", "scrivania", 116, 118, 77, 98, 205, 238),
    ("book1", "scrivania", 92, 114, 75, 79, 122, 148),
    ("book2", "scrivania", 94, 113, 79, 83, 124, 147),
    ("book3", "scrivania", 93, 115, 83, 87, 123, 149),
    ("mug", "scrivania", 98, 106, 75, 85, 176, 184),
    ("lamp_base", "scrivania", 136, 146, 75, 77, 116, 128),
    ("lamp_pole", "scrivania", 140, 142, 77, 122, 121, 123),
    ("lamp_shade", "scrivania", 120, 142, 114, 125, 114, 130),
    # sedia
    ("chair_base", "scrivania", 46, 82, 4, 8, 132, 170),
    ("chair_pole", "scrivania", 61, 67, 8, 44, 148, 154),
    ("chair_seat", "scrivania", 44, 84, 44, 51, 128, 174),
    ("chair_back", "scrivania", 39, 45, 51, 96, 130, 172),
    # parete sinistra: lavagna (di fronte alla scrivania) e libreria (di fronte al letto)
    ("blackboard", "lavagna", -150, -146, 92, 188, 120, 262),
    ("chalk_tray", "lavagna", -146, -140, 89, 92, 120, 262),
    ("bookcase", "libreria", -150, -112, 0, 205, 292, 412),
    # tende ai lati della portafinestra
    ("curtain_l", "finestra", -92, -62, 0, 232, 436, 446),
    ("curtain_r", "finestra", 62, 90, 112, 232, 436, 446),
]

# ---------------- intersezioni ----------------
t_best = np.full(N, np.inf)
obj = np.full(N, -1)          # -1..-5 = superfici della stanza
nax = np.zeros(N, int)
nsg = np.zeros(N)

# stanza (raggio esce dalla scatola-stanza)
bounds_hi = np.array([RX, RY, RZ]); bounds_lo = np.array([-RX, 0.0, 0.0])
tt = np.where(D > 0, (bounds_hi - CAM) / D, (bounds_lo - CAM) / D)
ax = np.argmin(tt, 1)
t_best = tt[np.arange(N), ax]
nax = ax.copy()
nsg = -np.sign(D[np.arange(N), ax])
room_id = np.where(ax == 0, np.where(D[:, 0] < 0, -1, -2), np.where(ax == 1, np.where(D[:, 1] < 0, -3, -4), -5))
obj = room_id.copy()   # -1 sx, -2 dx, -3 pavimento, -4 soffitto, -5 fondo

for i, b in enumerate(BOXES):
    lo = np.array([b[2], b[4], b[6]], float); hi = np.array([b[3], b[5], b[7]], float)
    t1 = (lo - CAM) / D; t2 = (hi - CAM) / D
    tmn = np.minimum(t1, t2); tmx = np.maximum(t1, t2)
    tnear = tmn.max(1); tfar = tmx.min(1)
    hit = (tfar >= tnear) & (tnear > 0) & (tnear < t_best)
    a = np.argmax(tmn, 1)
    t_best[hit] = tnear[hit]
    obj[hit] = i
    nax[hit] = a[hit]
    nsg[hit] = -np.sign(D[hit, a[hit]])

P = CAM + D * t_best[:, None]
X, Y, Z = P[:, 0], P[:, 1], P[:, 2]
NRM = np.zeros((N, 3)); NRM[np.arange(N), nax] = nsg
depth = Z - CAM[2]

alb = np.zeros((N, 3))
emi = np.zeros(N, bool)

def setc(mask, col):
    alb[mask] = col

def mix(a, b, t):
    return a + (np.array(b, float) - a) * t

def C(*c):
    return np.array(c, float)

# ---------------- materiali ----------------
names = [b[0] for b in BOXES]
def M(name):
    return obj == names.index(name)

# pareti: bicolore con battiscopa e boiserie bassa
wall = (obj == -1) | (obj == -2) | (obj == -5)
WALL_TOP, WALL_LOW, RAIL = C(196, 200, 160), C(150, 104, 70), C(236, 214, 170)
setc(wall, WALL_TOP)
setc(wall & (Y < 92), WALL_LOW)
setc(wall & (Y >= 92) & (Y < 96), RAIL)
setc(wall & (Y < 8), C(240, 232, 214))
# carta da parati a rombi tenui (parte alta)
lateral = np.where(obj == -5, X, Z)
pat = wall & (Y > 96) & (((np.abs((lateral % 24) - 12) + np.abs((Y % 24) - 12)) < 1.6))
setc(pat, C(206, 210, 172))
# pannelli verticali nella boiserie
setc(wall & (Y > 10) & (Y < 88) & ((lateral % 40) < 1.5), C(120, 80, 54))

# striscia LED magenta sotto al soffitto + bagliore
led = wall & (Y > 248) & (Y < 253)
setc(led, C(176, 124, 84))

# soffitto
setc(obj == -4, C(226, 206, 170))
beam = (obj == -4) & ((Z % 70) < 9)
setc(beam, C(150, 100, 64))
led_c = (obj == -4) & ((np.abs(X) > RX - 4) | (Z > RZ - 4))
setc(led_c, C(176, 124, 84))

# pavimento: listoni verso la finestra
fl = obj == -3
plank = np.floor((X + 300) / 16)
hp = h2(plank, 3.0)
wood = mix(np.tile(C(176, 112, 66), (N, 1)), (150, 90, 52), hp[:, None])
setc(fl, wood[fl])
seam = fl & (((X + 300) % 16 < 0.9) | (((Z + hp * 200) % 110) < 0.9))
setc(seam, C(104, 62, 40))
# tappeto
ex, ez = X / 92.0, (Z - 262) / 70.0
dr = np.sqrt(ex ** 2 + ez ** 2)
rug = fl & (dr < 1)
setc(rug, C(236, 222, 196))
setc(rug & (dr > 0.86), C(196, 106, 70))
setc(rug & (dr > 0.66) & (dr < 0.74), C(214, 160, 80))
dia = rug & (dr < 0.5) & ((np.abs((X % 30) - 15) + np.abs((Z % 30) - 15)) < 8)
setc(dia, C(196, 106, 70))
setc(rug & (dr < 0.16), C(214, 160, 80))
# fogli di calcoli sparsi a terra
papers = [(-140, 128, 22, 30), (-118, 150, 30, 21), (-138, 182, 21, 30), (-100, 200, 22, 30),
          (-128, 225, 30, 22), (-92, 168, 21, 29), (-84, 236, 22, 30), (-140, 250, 28, 20), (-66, 196, 20, 28)]
for k, (px, pz, pw, ph) in enumerate(papers):
    m = fl & (X > px) & (X < px + pw) & (Z > pz) & (Z < pz + ph)
    setc(m, C(250, 248, 238))
    setc(m & (((Z - pz) % 4.5) < 1.0) & (X > px + 3) & (X < px + pw - 3), C(120, 140, 220))
    if k % 3 == 0:
        setc(m & (np.abs(X - (px + pw - 5)) < 2.2) & (np.abs(Z - (pz + 5)) < 2.2), C(232, 60, 80))
# ombra ai piedi delle pareti e sotto i mobili (AO finto)
ao = fl & ((X < -RX + 6) | (X > RX - 6) | (Z > RZ - 6))
alb[ao] *= 0.8

# portafinestra sul muro di fondo
win = (obj == -5) & (np.abs(X) < 60) & (Y < 222)
frame = win & ((np.abs(X) > 54) | (Y > 214) | (np.abs(X) < 3.5) | (np.abs(Y - 72) < 2.5) | (np.abs(Y - 150) < 2.5) | (Y < 6))
glass = win & ~frame
setc(frame, C(170, 118, 76))
# vista: cielo, stelle, luna, mare con riflesso, ringhiera del balcone
tt_ = np.clip((Y - 60) / 160, 0, 1)
sky = mix(np.tile(C(70, 80, 140), (N, 1)), (22, 30, 72), tt_[:, None])
g = glass.copy()
setc(g, sky[g])
star = g & (Y > 80) & (h2(np.floor(X / 4), np.floor(Y / 4), 9) > 0.93)
setc(star, C(255, 250, 210))
mx, my = 26, 182
moon = g & ((X - mx) ** 2 + (Y - my) ** 2 < 13 ** 2)
setc(moon, C(255, 244, 200))
setc(moon & ((X - mx - 6) ** 2 + (Y - my - 3) ** 2 < 10 ** 2), C(240, 220, 170))
sea = g & (Y < 66)
setc(sea, C(24, 44, 110))
setc(sea & (Y > 63), C(60, 70, 120))
refl = sea & (np.abs(X - mx + 3 * np.sin(Y * 1.7)) < (1.5 + (66 - Y) * 0.09)) & ((np.floor(Y / 2.5) % 2) == 0)
setc(refl, C(250, 230, 170))
rail = g & (((Y > 40) & (Y < 44)) | ((Y < 42) & ((X % 12) < 1.6)))
setc(rail, C(30, 22, 52))
emi |= g

# letto
setc(M("bed_frame"), C(168, 116, 74))
mt = M("mattress")
setc(mt, C(244, 242, 250))
blanket = mt & (Z < 388)
setc(blanket, C(240, 228, 204))
setc(blanket & ((Z % 34) < 6), C(214, 160, 80))
setc(blanket & ((Z % 34) >= 6) & ((Z % 34) < 8), C(140, 160, 110))
setc(blanket & (((X + Z) % 6) < 1) & ((Z % 34) >= 8), C(222, 206, 178))
setc(mt & (Z >= 388) & (Z < 396), C(250, 244, 230))   # risvolto
setc(M("pillow"), C(250, 242, 226))
setc(M("pillow") & (nax == 1) & (np.abs(X - 108) < 1.5), C(220, 200, 170))
hb = M("headboard")
setc(hb, C(150, 100, 64))
setc(hb & (Y > 106), C(184, 132, 88))
setc(hb & ((X % 18) < 2), C(120, 78, 50))

# scrivania
dk = M("desk")
setc(dk, C(206, 150, 96))
top = dk & (nax == 1)
setc(top, C(224, 172, 112))
setc(top & ((Z % 13) < 1), C(200, 148, 92))
front = dk & (nax == 0)
knee = front & (Z < 198) & (Z > 116) & (Y < 66)
setc(knee, C(74, 52, 58))
drw = front & (Z >= 198)
setc(drw & ((np.abs(Y - 46) < 0.8) | (np.abs(Y - 22) < 0.8)), C(150, 100, 62))
setc(drw & (np.abs(Z - 223) < 4) & ((np.abs(Y - 58) < 1.2) | (np.abs(Y - 34) < 1.2) | (np.abs(Y - 11) < 1.2)), C(250, 196, 70))
setc(M("monitor_stand"), C(54, 54, 68))
mon = M("monitor")
setc(mon, C(40, 40, 52))
scr = mon & (nax == 0) & (nsg < 0) & (Z > 143) & (Z < 225) & (Y > 95) & (Y < 135)
setc(scr, C(44, 36, 34))
line_row = np.floor((135 - Y) / 3.2)
indent = np.floor(h2(line_row, 1.0) * 4) * 6
ln_len = 20 + h2(line_row, 2.0) * 45
tok = np.floor((Z - 146 - indent) / 7)
code = scr & (((135 - Y) % 3.2) < 1.6) & (Z > 146 + indent) & (Z < 146 + indent + ln_len) & (h2(line_row, 5.0) > 0.12)
cols = np.array([[236, 170, 110], [170, 200, 140], [240, 210, 150], [200, 150, 130], [230, 220, 200]], float)
ci = np.floor(h2(line_row, tok) * 5).astype(int) % 5
alb[code] = cols[ci[code]]
setc(scr & (Z < 150), C(60, 50, 44))
emi |= scr
setc(M("laptop_base"), C(204, 206, 214))
lid = M("laptop_lid")
setc(lid, C(190, 192, 202))
lscr = lid & (nax == 0) & (nsg < 0) & (Z > 207) & (Z < 236) & (Y > 79) & (Y < 96)
setc(lscr, C(240, 230, 210))
setc(lscr & (Y > 90), C(200, 150, 110))
setc(lscr & (Y < 90) & (Y > 82) & (Z > 212) & (Z < 222), C(170, 190, 140))
setc(lscr & (Y < 90) & (Y > 82) & (Z > 224) & (Z < 233), C(220, 180, 130))
emi |= lscr
setc(M("book1"), C(110, 130, 90)); setc(M("book2"), C(214, 160, 80)); setc(M("book3"), C(170, 70, 60))
for bname in ("book1", "book2", "book3"):
    m = M(bname) & (nax == 2) & (nsg < 0)
    setc(m, C(250, 246, 230))
mug = M("mug")
setc(mug, C(250, 250, 255))
setc(mug & (Y > 79) & (Y < 82), C(196, 106, 70))
setc(mug & (nax == 1), C(140, 80, 40))
setc(M("lamp_base"), C(60, 60, 80)); setc(M("lamp_pole"), C(60, 60, 80))
shade = M("lamp_shade")
setc(shade, C(250, 196, 70))
setc(shade, C(250, 200, 80)); emi |= shade
setc(shade & (nsg < 0) & (nax == 1), C(255, 250, 220))
setc(M("chair_base"), C(120, 80, 54)); setc(M("chair_pole"), C(120, 80, 54))
setc(M("chair_seat"), C(200, 140, 90)); setc(M("chair_back"), C(168, 116, 74))
setc(M("chair_seat") & (nax == 1), C(140, 160, 110))
setc(M("chair_back") & (nax == 0), C(184, 132, 88))

# lavagna con calcoli di fisica
bb = M("blackboard")
setc(bb, C(176, 120, 74))
face = bb & (nax == 0) & (Z > 124) & (Z < 258) & (Y > 96) & (Y < 184)
setc(face, C(34, 92, 70))
chalk = C(236, 246, 236)
row_y = np.floor((184 - Y) / 9)
txt = face & (row_y < 4) & (((184 - Y) % 9) > 3) & (((184 - Y) % 9) < 7.5) & (Z > 132) & (Z < 200 - row_y * 8) & (h2(np.floor(Z / 2.6), row_y, 4) > 0.42)
setc(txt, chalk)
wave = face & (Z > 132) & (Z < 200) & (np.abs(Y - (112 + 6 * np.sin((Z - 132) / 5))) < 1.3)
setc(wave, chalk)
orb = face & (np.abs(np.sqrt(((Z - 232) / 1.4) ** 2 + (Y - 150) ** 2) - 14) < 1.4)
setc(orb, C(255, 230, 140))
setc(face & ((Z - 232) ** 2 + (Y - 150) ** 2 < 9), C(255, 200, 80))
setc(face & ((Z - 251) ** 2 + (Y - 150) ** 2 < 6), C(120, 220, 255))
arrow = face & (np.abs(Z - 251) < 1.0) & (Y > 152) & (Y < 166)
setc(arrow, C(255, 130, 150))
setc(face & (Z > 214) & (Z < 252) & (np.abs(Y - 112) < 1.1), chalk)
setc(face & (Z > 216) & (Z < 250) & (np.abs(Y - 120) < 1.1) & (h2(np.floor(Z / 2.5), 9.0) > 0.35), chalk)
setc(M("chalk_tray"), C(150, 100, 62))

# libreria
bk = M("bookcase")
setc(bk, C(176, 124, 84))
bf = bk & (nax == 0)
inner = bf & (Z > 296) & (Z < 408) & (Y > 6) & (Y < 200)
shelf_h = 39
cell_y = (Y - 6) % shelf_h
cell_i = np.floor((Y - 6) / shelf_h)
board = inner & (cell_y < 3)
setc(inner & ~board, C(80, 52, 38))
slot = np.floor((Z - 296) / 4.2)
bh = 18 + h2(slot, cell_i, 2) * 15
has = h2(slot, cell_i, 3) > 0.13
book = inner & ~board & has & (cell_y < 3 + bh)
bcols = np.array([[170, 70, 60], [90, 110, 140], [214, 160, 80], [110, 130, 90], [140, 90, 110], [196, 106, 70], [150, 170, 120], [236, 222, 196]], float)
bci = np.floor(h2(slot, cell_i, 5) * 8).astype(int) % 8
alb[book] = bcols[bci[book]]
band = book & (np.abs(cell_y - (3 + bh * 0.75)) < 1.0)
alb[band] = alb[band] * 0.7 + 255 * 0.3
gapline = book & (((Z - 296) % 4.2) < 0.55)
alb[gapline] *= 0.6
setc(board, C(176, 124, 84))
setc(bk & (nax == 1), C(196, 144, 100))

# tende
for cname in ("curtain_l", "curtain_r"):
    m = M(cname)
    fold = 0.5 + 0.5 * np.sin(X / 3.2)
    col = mix(np.tile(C(246, 234, 210), (N, 1)), (206, 186, 150), (fold ** 2)[:, None])
    alb[m] = col[m]

# ---------------- lucine (fairy lights) sopra la libreria ----------------
lw = (obj == -1) & (Z > 120) & (Z < 448)
seg = (Z - 270) % 45
sag = 228 - 10 * np.sin(np.pi * seg / 45)
wire = lw & (np.abs(Y - sag) < 0.9)
setc(wire, C(40, 34, 50))
bulb_i = np.floor((Z - 270) / 11)
bulb = lw & (((Z - 270) % 11 - 5.5) ** 2 + (Y - (sag - 3)) ** 2 < 20)
bulb_cols = np.array([[255, 220, 140], [255, 200, 110], [255, 236, 170], [255, 190, 120]], float)
bi = (bulb_i.astype(int)) % 4
alb[bulb] = bulb_cols[bi[bulb]]
emi |= bulb

# ---------------- poster sulla parete destra (sopra la scrivania) ----------------
rw = obj == -2
p1 = rw & (Z > 136) & (Z < 196) & (Y > 132) & (Y < 214)
setc(p1, C(236, 224, 196))
sun = p1 & ((Z - 166) ** 2 + (Y - 170) ** 2 < 17 ** 2) & (Y > 160)
sun_t = np.clip((Y - 160) / 27, 0, 1)
sc = mix(np.tile(C(140, 160, 110), (N, 1)), (110, 130, 90), sun_t[:, None])
alb[sun] = sc[sun]
setc(sun & (((Y - 160) % 6) < 1.3) & (Y < 175), C(236, 224, 196))
grid = p1 & (Y < 158) & ((((Y - 132) % 7) < 1) | ((np.abs(Z - 166) % 9) < 1))
setc(grid & ((np.abs(Z - 166) % 9) < 1), C(120, 90, 60))
setc(p1 & ((Z < 139) | (Z > 193) | (Y < 135) | (Y > 211)), C(150, 100, 64))
p2 = rw & (Z > 204) & (Z < 244) & (Y > 140) & (Y < 200)
setc(p2, C(40, 52, 90))
for ang in (0, 60, 120):
    a = math.radians(ang)
    du = (Z - 224) * math.cos(a) + (Y - 170) * math.sin(a)
    dv = -(Z - 224) * math.sin(a) + (Y - 170) * math.cos(a)
    ring = p2 & (np.abs(np.sqrt((du / 1.0) ** 2 + (dv * 2.6) ** 2) - 14) < 1.3)
    setc(ring, C(230, 210, 160))
setc(p2 & ((Z - 224) ** 2 + (Y - 170) ** 2 < 9), C(250, 220, 140))
setc(p2 & ((Z < 206) | (Z > 242) | (Y < 142) | (Y > 198)), C(150, 100, 64))

# ---------------- illuminazione ----------------
LIGHTS = [
    (C(124, 108, 122), C(255, 190, 110), 1.9, 65),    # lampada da scrivania
    (C(112, 115, 185), C(255, 220, 170), 0.6, 50),    # monitor
    (C(0, 160, 520), C(140, 160, 230), 0.9, 280),     # luna dalla portafinestra
    (C(-135, 220, 300), C(255, 190, 110), 1.3, 140),  # lucine
    (C(0, 230, 120), C(255, 180, 110), 0.45, 220),      # LED
]
AMB = C(0.30, 0.25, 0.30)
light = np.tile(AMB, (N, 1))
for pos, col, inten, rng in LIGHTS:
    L = pos - P
    d = np.linalg.norm(L, axis=1) + 1e-6
    ndl = np.clip((NRM * (L / d[:, None])).sum(1), 0, 1)
    att = inten / (1 + (d / rng) ** 2)
    light += (ndl * att)[:, None] * (col / 255.0)[None, :]
# bagliore LED sulle pareti alte
gl = wall & (Y > 170) & ~led
light[gl] += ((np.clip((Y[gl] - 170) / 80, 0, 1) ** 2) * 0.0)[:, None] * C(1.0, 0.35, 0.85)
col = alb * light
col[emi] = alb[emi]
col = np.clip(col, 0, 255)

# ---------------- sprite (piante, racchetta, vapore) ----------------
img = col.reshape(H, W, 3)
zb = depth.reshape(H, W).copy()
idb = obj.reshape(H, W).copy()
SPR_ID = {"finestra": 1000, "libreria": 1001, "scrivania": 1002}

def proj(x, y, z):
    Zc = z - CAM[2]
    return CX + F * (x - CAM[0]) / Zc, CY - F * (y - CAM[1]) / Zc, Zc

def put(px, py, Zc, c, sid):
    px, py = int(px), int(py)
    if 0 <= px < W and 0 <= py < H and Zc < zb[py, px]:
        img[py, px] = c; zb[py, px] = Zc; idb[py, px] = sid

def plant(x, z, size, sid, seed):
    rng = np.random.default_rng(seed)
    # vaso
    for yy in np.arange(0, size * 0.45, 0.6):
        r = size * (0.26 + 0.06 * yy / (size * 0.45))
        for xx in np.arange(-r, r, 0.6):
            sx, sy, Zc = proj(x + xx, yy, z)
            shade = 0.75 + 0.25 * (xx + r) / (2 * r)
            c = np.array([210, 104, 66]) * shade
            if yy > size * 0.38:
                c = np.array([236, 130, 88])
            put(sx, sy, Zc, c, sid)
    # foglie
    for k in range(int(size * 1.6)):
        ang = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0, size * 0.55)
        lx = x + math.cos(ang) * rr
        ly = size * 0.45 + rng.uniform(0, size * 0.9) * (1 - rr / (size * 0.7))
        lr = rng.uniform(2.5, 4.5)
        cc = [np.array([70, 190, 90]), np.array([40, 140, 80]), np.array([140, 226, 110])][k % 3]
        for yy in np.arange(-lr, lr, 0.7):
            for xx in np.arange(-lr * 0.7, lr * 0.7, 0.7):
                if (xx / 0.7) ** 2 + yy ** 2 < lr ** 2:
                    sx, sy, Zc = proj(lx + xx, ly + yy, z - 3)
                    put(sx, sy, Zc, cc * (0.85 + 0.25 * light.reshape(H, W, 3)[min(H - 1, max(0, int(sy))), min(W - 1, max(0, int(sx)))].mean() / 1.4), sid)

plant(-108, 420, 46, SPR_ID["finestra"], 1)
plant(-48, 432, 30, SPR_ID["finestra"], 2)
plant(-76, 404, 24, SPR_ID["finestra"], 3)
plant(-132, 214 + 0, 0.1, SPR_ID["finestra"], 4)  # no-op (spazio riservato)

# racchetta da tennis appoggiata alla libreria
def racket(x, z):
    for k in np.arange(0, 1, 0.004):
        # manico
        sx, sy, Zc = proj(x + 6 * k, 30 * k, z)
        put(sx, sy, Zc, np.array([60, 60, 80]), SPR_ID["libreria"])
    for a in np.linspace(0, 2 * math.pi, 220):
        sx, sy, Zc = proj(x + 6 + 11 * math.cos(a) + 3, 30 + 15 + 15 * math.sin(a), z)
        put(sx, sy, Zc, np.array([196, 106, 70]), SPR_ID["libreria"])
    for s in np.arange(-9, 10, 4):
        for t in np.linspace(-13, 13, 40):
            if (s / 11) ** 2 + (t / 15) ** 2 < 0.9:
                sx, sy, Zc = proj(x + 9 + s, 45 + t, z + 0.5)
                put(sx, sy, Zc, np.array([236, 236, 236]), SPR_ID["libreria"])
racket(-100, 280)

# vapore dal te'
for i in range(26):
    yy = 86 + i * 1.1
    xx = 102 + 2.2 * math.sin(i * 0.55)
    sx, sy, Zc = proj(xx, yy, 180)
    ix, iy = int(sx), int(sy)
    if 0 <= ix < W and 0 <= iy < H:
        a = 0.75 * (1 - i / 26)
        img[iy, ix] = img[iy, ix] * (1 - a) + np.array([255, 255, 255]) * a

# ---------------- posterizzazione con dithering + contorni ----------------
bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
STEP = 18.0
thr = np.tile(bayer, (H // 4 + 1, W // 4 + 1))[:H, :W][:, :, None]
q = np.floor(img / STEP + 0.5 + thr * 0.9) * STEP
q = np.clip(q, 0, 255)

# contorni: dove cambia oggetto, scurisci il pixel piu' vicino
out = q.copy()
fid = idb * 8 + nax.reshape(H, W) * 2 + (nsg.reshape(H, W) > 0)
for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
    nb_id = np.roll(np.roll(idb, dy, 0), dx, 1)
    nb_z = np.roll(np.roll(zb, dy, 0), dx, 1)
    edge = (nb_id != idb) & (zb <= nb_z - 2)
    out[edge] = q[edge] * 0.45 + np.array([46, 26, 20]) * 0.55
    nb_f = np.roll(np.roll(fid, dy, 0), dx, 1)
    fedge = (nb_f != fid) & (nb_id == idb) & (idb >= 0) & ~edge
    out[fedge] = out[fedge] * 0.8
out[0, :] = out[1, :]; out[:, 0] = out[:, 1]

im = Image.fromarray(out.astype(np.uint8), "RGB")
im.save("room_v3.png")
im.resize((W * 4, H * 4), Image.NEAREST).save("room_v3_x4.png")

# ---------------- hotspot (bbox in pixel, risoluzione 320x200) ----------------
groups = {}
for i, b in enumerate(BOXES):
    groups.setdefault(b[1], []).append(i)
spr_rev = {v: k for k, v in SPR_ID.items()}
hs = {}
for gname, ids in groups.items():
    m = np.isin(idb, ids) | (idb == SPR_ID.get(gname, -999))
    if gname == "finestra":
        m |= (obj.reshape(H, W) == -5) & (np.abs(X.reshape(H, W)) < 60) & (Y.reshape(H, W) < 222)
    if gname == "lavagna":
        fl2 = (obj.reshape(H, W) == -3) & (X.reshape(H, W) < -60) & (Z.reshape(H, W) > 120) & (Z.reshape(H, W) < 290)
        m |= fl2
    ys, xs = np.nonzero(m)
    hs[gname] = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
json.dump({"width": W, "height": H, "hotspots": hs}, open("hotspots_v3.json", "w"), indent=2)
print(hs)
