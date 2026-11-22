"""Sprite dell'omino: felpa nera, sciarpa rossa, pantaloni baggy, sneakers bianche.
Output: player.png (sprite sheet orizzontale: 4 idle + 6 walk, frame 24x40, guarda a destra)
        player.json (metadati dei frame)
"""
import json, math
import numpy as np
from PIL import Image

FW, FH = 24, 42
OUT = (24, 18, 30)
SKIN, SKIN_SH = (240, 200, 166), (212, 162, 130)
HAIR, HAIR_HI = (54, 38, 32), (88, 62, 48)
HOOD, HOOD_HI, HOOD_SH = (36, 34, 44), (60, 56, 72), (24, 22, 30)
STRING = (230, 226, 220)
SCARF, SCARF_SH, SCARF_ST = (200, 70, 56), (156, 50, 42), (238, 186, 82)
PANTS, PANTS_SH, PANTS_HI = (156, 150, 142), (122, 118, 112), (182, 176, 168)
SHOE, SOLE = (242, 240, 234), (176, 172, 176)
EYE = (30, 22, 30)


class F:
    def __init__(self):
        self.a = np.zeros((FH, FW, 4), np.uint8)

    def p(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < FW and 0 <= y < FH:
            self.a[y, x] = (*c, 255)

    def r(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.p(x, y, c)

    def outline(self):
        m = self.a[:, :, 3] > 0
        o = np.zeros_like(m)
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            o |= np.roll(np.roll(m, dy, 0), dx, 1)
        o &= ~m
        self.a[o] = (*OUT, 255)


def leg(f, hip_x, off, lift, near, bob):
    """gamba baggy: dall'anca (y=25) alla caviglia (y=34), con il piede spostato di 'off'"""
    top, bot = 25 + bob, 34 - lift
    for y in range(top, bot + 1):
        t = (y - top) / max(1, bot - top)
        cx = hip_x + off * t
        w = 2.4 + 0.9 * t                     # si allarga verso il basso (baggy)
        for x in range(int(math.floor(cx - w)), int(math.ceil(cx + w)) + 1):
            if abs(x - cx) <= w:
                c = PANTS if near else PANTS_SH
                if near and x >= cx + w - 1:
                    c = PANTS_SH
                if near and x <= cx - w + 1 and y < bot - 1:
                    c = PANTS_HI
                f.p(x, y, c)
        if y in (top + 5, top + 7) and near:  # pieghe che si accumulano sulla scarpa
            f.p(cx - 1, y, PANTS_SH); f.p(cx + 1, y, PANTS_SH)
    # scarpa
    sx = hip_x + off
    sy = 35 - lift
    f.r(sx - 2, sy, sx + 3, sy + 2, SHOE if near else (216, 214, 210))
    f.r(sx - 2, sy + 2, sx + 3, sy + 2, SOLE)
    f.p(sx + 3, sy, SHOE if near else (216, 214, 210))


def arm(f, sh_x, sh_y, swing, near):
    """manica larga della felpa con la mano"""
    for i in range(9):
        t = i / 8
        x = sh_x + swing * t
        y = sh_y + i
        c = HOOD if near else HOOD_SH
        f.p(x, y, c); f.p(x + 1, y, c if not near else HOOD_HI if i < 6 else HOOD)
        if i > 1:
            f.p(x - 1, y, c)
    hx, hy = sh_x + swing, sh_y + 9
    if near or abs(swing) >= 2:
        f.r(hx - 1, hy, hx + 1, hy + 1, SKIN if near else SKIN_SH)


def frame(kind, i):
    f = F()
    if kind == "idle":
        bob = 1 if i in (1, 2) else 0          # respiro
        lo = [0, 0]; lift = [0, 0]; sw = [0, 0]
        tail = [0, 1, 1, 0][i]
    else:
        ph = i / 6 * 2 * math.pi
        s = math.sin(ph)
        lo = [round(3.2 * s), round(-3.2 * s)]  # [vicina, lontana]
        lift = [1 if (i in (2,)) else 0, 1 if (i in (5,)) else 0]
        bob = -1 if i in (1, 4) else 0
        sw = [round(-2.2 * s), round(2.2 * s)]
        tail = [0, 1, 2, 1, 0, -1][i]
    hip = 11
    # --- dietro: braccio lontano, gamba lontana, coda sciarpa
    arm(f, 9, 15 + bob, sw[1], False)
    leg(f, hip - 1, lo[1], lift[1], False, bob)
    # coda della sciarpa che svolazza dietro
    for k in range(6):
        x = 8 - k
        y = 13 + bob + round(k * 0.45 + tail * 0.35 * k / 5)
        c = SCARF_ST if k in (2, 4) else SCARF
        f.p(x, y, c); f.p(x, y + 1, SCARF_SH if k % 2 else SCARF)
    fx, fy = 2, 13 + bob + round(5 * 0.45 + tail * 0.35)
    f.p(fx, fy + 2, SCARF_ST); f.p(fx + 1, fy + 2, SCARF_SH)
    # --- gamba vicina
    leg(f, hip + 1, lo[0], lift[0], True, bob)
    # --- busto (felpa nera oversize)
    by = 14 + bob
    f.r(7, by, 16, by + 11, HOOD)
    f.r(7, by, 8, by + 11, HOOD_SH)           # lato in ombra (dietro)
    f.r(15, by + 1, 16, by + 10, HOOD_HI)     # luce dei lampioni davanti
    f.r(9, by + 6, 15, by + 6, HOOD_SH)       # tasca a marsupio
    f.r(10, by + 7, 14, by + 7, HOOD_SH)
    f.r(7, by + 10, 16, by + 11, (46, 44, 56))  # elastico in fondo
    f.p(13, by + 2, STRING); f.p(13, by + 3, STRING); f.p(14, by + 2, STRING); f.p(14, by + 4, STRING)
    # cappuccio dietro il collo
    f.r(6, by - 2, 8, by + 1, HOOD); f.p(6, by - 2, HOOD_SH)
    # --- testa
    hy = 3 + bob
    f.r(9, hy + 1, 16, hy + 9, SKIN)
    f.r(9, hy + 7, 16, hy + 9, SKIN)
    f.p(16, hy + 9, SKIN_SH); f.p(15, hy + 9, SKIN_SH)
    # capelli spettinati
    f.r(8, hy - 1, 15, hy + 2, HAIR)
    f.r(8, hy + 2, 10, hy + 6, HAIR)
    f.p(16, hy, HAIR); f.p(16, hy + 1, HAIR); f.p(12, hy - 2, HAIR); f.p(13, hy - 2, HAIR); f.p(8, hy, HAIR); f.p(7, hy + 1, HAIR)
    f.p(15, hy + 3, HAIR)                     # ciuffo sulla fronte
    f.r(11, hy - 1, 13, hy - 1, HAIR_HI); f.p(9, hy + 1, HAIR_HI)
    f.p(11, hy + 4, SKIN_SH)                  # orecchio
    f.p(15, hy + 5, EYE)                      # occhio
    f.p(16, hy + 7, (232, 150, 140))          # guancia rossa dal freddo
    f.p(17, hy + 6, SKIN)                     # naso
    # --- sciarpa avvolta al collo
    sy = by - 2
    f.r(9, sy, 17, sy + 3, SCARF)
    f.r(9, sy + 3, 17, sy + 3, SCARF_SH)
    f.p(11, sy + 1, SCARF_ST); f.p(14, sy + 1, SCARF_ST); f.p(17, sy + 1, SCARF_ST)
    # lembo davanti
    f.r(14, sy + 4, 15, sy + 7, SCARF); f.p(15, sy + 7, SCARF_SH); f.p(14, sy + 6, SCARF_ST)
    f.p(14 + (1 if tail > 0 else 0), sy + 8, SCARF_SH)
    # --- braccio vicino
    arm(f, 15, 15 + bob, sw[0], True)
    a = np.zeros_like(f.a); a[1:] = f.a[:-1]; f.a = a   # un pixel di margine sopra
    f.outline()
    return f.a


frames = [frame("idle", i) for i in range(4)] + [frame("walk", i) for i in range(6)]
sheet = np.concatenate(frames, axis=1)
Image.fromarray(sheet, "RGBA").save("player.png")
Image.fromarray(sheet, "RGBA").resize((sheet.shape[1] * 6, sheet.shape[0] * 6), Image.NEAREST).save("player_x6.png")
json.dump({"fw": FW, "fh": FH, "idle": [0, 1, 2, 3], "walk": [4, 5, 6, 7, 8, 9], "footY": 39}, open("player.json", "w"))
print("ok", sheet.shape)
