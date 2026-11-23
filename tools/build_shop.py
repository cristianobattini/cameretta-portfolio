"""Oggetti del negozio: portapacchi della Vespa, angolo e parete della cameretta.
Uso: python tools/build_shop.py   ->  cameretta-godot/assets/img/shop.png + cameretta-godot/store/shop.json
"""
import json, math, os
import numpy as np
from PIL import Image
from pix import Spr

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "cameretta-godot")
P = {}
def add(n, s, line=True): P[n] = s.outline() if line else s

WOOD, WOOD_HI, WOOD_SH = (138, 92, 58), (178, 126, 84), (96, 62, 44)
METAL, METAL_HI, METAL_SH = (150, 158, 178), (226, 232, 246), (92, 98, 122)
FUR, FUR_HI, FUR_SH = (214, 136, 58), (240, 172, 92), (160, 92, 44)

# ------------------------------------------------ portapacchi (28x34, appoggio in basso al centro)
def cat():
    s = Spr(28, 34); s.ell(6, 16, 21, 32, FUR); s.ell(8, 18, 14, 30, FUR_HI)
    s.ell(8, 5, 22, 18, FUR); s.poly([(9, 8), (9, 1), (14, 6)], FUR); s.poly([(16, 6), (21, 1), (21, 8)], FUR); s.p(10, 5, (236, 160, 150)); s.p(20, 5, (236, 160, 150))
    for x in (13, 15, 17): s.r(x, 6, x, 8, FUR_SH)
    for y in (21, 24, 27): s.r(17, y, 20, y, FUR_SH)
    s.r(9, 9, 21, 12, (60, 44, 44)); s.r(10, 10, 14, 11, (150, 206, 236)); s.r(16, 10, 20, 11, (150, 206, 236)); s.p(11, 10, (236, 250, 255)); s.p(17, 10, (236, 250, 255))
    s.p(15, 14, (90, 50, 50)); s.p(14, 15, FUR_SH); s.p(16, 15, FUR_SH); s.r(10, 14, 11, 14, (250, 230, 200)); s.r(19, 14, 20, 14, (250, 230, 200))
    s.limb([(7, 29), (2, 27), (2, 20)], 3, FUR); s.r(9, 31, 12, 32, (250, 230, 200)); s.r(16, 31, 19, 32, (250, 230, 200)); return s
add("po_gatto", cat())
def books():
    s = Spr(28, 34)
    for k, (w, c) in enumerate([(18, (122, 54, 38)), (16, (47, 93, 72)), (18, (35, 64, 110)), (14, (168, 100, 46)), (16, (91, 63, 120))]):
        y = 32 - k * 4; x = 14 - w // 2 + (k % 2)
        s.r(x, y - 3, x + w, y, c); s.r(x + w - 1, y - 2, x + w, y - 1, (240, 230, 206)); s.r(x, y - 3, x + w - 2, y - 3, tuple(min(255, v + 40) for v in c)); s.r(x + 3, y - 2, x + 4, y - 1, (242, 200, 100))
    s.r(13, 12, 15, 33, (110, 72, 52)); return s
add("po_libri", books())
def guitarcase():
    s = Spr(28, 34); c, hi = (52, 44, 60), (92, 80, 104)
    s.ell(6, 18, 20, 33, c); s.ell(8, 11, 18, 23, c); s.r(11, 0, 15, 14, c); s.r(10, 0, 16, 3, c); s.limb([(8, 22), (9, 30)], 1, hi); s.limb([(12, 2), (12, 13)], 1, hi)
    for y in (14, 20, 29): s.r(18, y, 20, y + 1, (242, 200, 100))
    s.ell(11, 22, 16, 27, (200, 70, 56)); s.p(13, 24, (255, 230, 200)); return s
add("po_chitarra", guitarcase())
def scope(w=28, h=34, big=False):
    s = Spr(w, h)
    if big:
        for x in (6, 22, 36): s.limb([(22, 34), (x, h - 2)], 2.4, WOOD if x != 22 else WOOD_SH)
        s.limb([(5, 34), (39, 8)], 9, (226, 230, 240)); s.limb([(5, 37), (38, 12)], 2, METAL_SH); s.limb([(6, 31), (36, 8)], 1.4, (255, 255, 255)); s.limb([(35, 11), (41, 6)], 11, (60, 72, 120)); s.limb([(2, 36), (6, 33)], 5, (50, 46, 60)); s.limb([(12, 22), (22, 15)], 2.4, (50, 46, 60))
        s.ell(18, 27, 26, 35, METAL); s.ell(20, 29, 23, 32, METAL_HI)
    else:
        s.limb([(6, 30), (22, 8)], 7, (226, 230, 240)); s.limb([(8, 31), (23, 10)], 1.6, METAL_SH); s.limb([(5, 27), (19, 7)], 1.2, (255, 255, 255)); s.limb([(20, 10), (24, 5)], 8, (60, 72, 120)); s.limb([(3, 33), (6, 30)], 4, (50, 46, 60)); s.r(9, 24, 15, 26, (110, 72, 52))
    return s
add("po_telescopio", scope())
def surf():
    s = Spr(28, 34); m = s.curve([(12, 0), (17, 8), (18, 20), (16, 30), (12, 33), (8, 30), (6, 20), (7, 8)], (250, 236, 206)); s.r(11, 0, 12, 33, (200, 70, 56), only=m)
    s.r(0, 12, 27, 14, (90, 154, 216), only=m); s.r(0, 16, 27, 17, (242, 184, 91), only=m); s.limb([(8, 8), (7, 20)], 1, (255, 255, 250), only=m); return s
add("po_surf", surf())
def cactus():
    s = Spr(28, 34); g, hi, sh = (74, 140, 84), (126, 190, 116), (44, 94, 62)
    s.limb([(14, 8), (14, 24)], 9, g); s.limb([(6, 14), (6, 18), (12, 20)], 4, g); s.limb([(22, 11), (22, 16), (16, 18)], 4, g); s.limb([(12, 8), (12, 23)], 1, hi); s.limb([(17, 8), (17, 23)], 1, sh)
    for x, y in ((14, 6), (10, 12), (15, 16), (6, 13), (22, 10)): s.p(x, y, (250, 244, 220))
    s.ell(12, 2, 16, 5, (240, 110, 130)); s.poly([(7, 24), (21, 24), (19, 33), (9, 33)], (196, 104, 64)); s.r(6, 23, 22, 25, (216, 128, 84)); return s
add("po_pianta", cactus())

# ------------------------------------------------ angolo della cameretta (46x72)
add("an_telescopio", scope(46, 72, True))
def monstera():
    s = Spr(46, 72); g, hi, sh = (56, 128, 76), (110, 180, 100), (34, 84, 60)
    for (x, y, w) in ((10, 24, 16), (34, 20, 16), (22, 8, 18), (6, 40, 13), (40, 38, 13), (24, 28, 15)):
        s.limb([(23, 56), ((23 + x) / 2, (50 + y) / 2), (x, y)], 1.4, sh)
        m = s.curve([(x, y - w / 2), (x + w / 2, y - w / 5), (x + w / 3, y + w / 2.4), (x, y + w / 1.7), (x - w / 3, y + w / 2.4), (x - w / 2, y - w / 5)], g)
        s.limb([(x, y - w / 2), (x, y + w / 2)], 1, hi, only=m)
        for k in (-1, 1):
            s.limb([(x + k * w / 2, y - 1), (x + k * w / 5, y + 1)], 1, sh, only=m); s.limb([(x + k * w / 2.4, y + w / 4), (x + k * w / 6, y + w / 4)], 1, sh, only=m)
    s.poly([(13, 54), (33, 54), (30, 71), (16, 71)], (222, 206, 180)); s.r(12, 53, 34, 56, (242, 230, 206)); s.limb([(28, 58), (27, 70)], 2, (186, 166, 140)); return s
add("an_monstera", monstera())
def table(s, y):
    s.r(4, y, 41, y + 3, WOOD); s.r(4, y, 41, y, WOOD_HI)
    for x in (7, 36): s.r(x, y + 4, x + 2, 71, WOOD_SH)
def lava():
    s = Spr(46, 72); table(s, 50)
    s.poly([(18, 40), (28, 40), (30, 49), (16, 49)], METAL); s.poly([(19, 40), (27, 40), (23, 44)], METAL_SH)
    m = s.poly([(20, 12), (26, 12), (29, 40), (17, 40)], (112, 44, 130))
    for x, y, r in ((23, 35, 5), (21, 26, 3), (25, 20, 2.5), (22, 15, 1.6)): s.ell(x - r, y - r, x + r, y + r, (255, 130, 80), only=m); s.ell(x - r * .5, y - r * .6, x + r * .2, y, (255, 206, 130), only=m)
    s.poly([(20, 12), (26, 12), (25, 6), (21, 6)], METAL); s.r(21, 6, 21, 11, METAL_HI); return s
add("an_lava", lava())
def turntable():
    s = Spr(46, 72); s.r(2, 36, 43, 70, WOOD); s.r(2, 36, 43, 37, WOOD_HI); s.r(5, 42, 40, 67, WOOD_SH)
    cols = [(200, 70, 56), (90, 154, 216), (242, 184, 91), (47, 93, 72), (156, 132, 196), (236, 154, 180), (236, 224, 196)]
    for k in range(17): s.r(6 + k * 2, 44 + (k * 5) % 3, 7 + k * 2, 66, cols[(k * 3) % 7])
    s.r(4, 30, 41, 35, (52, 46, 60)); s.r(4, 30, 41, 30, (92, 84, 104)); s.ell(8, 24, 32, 31, (24, 22, 30)); s.ell(11, 25, 29, 30, (44, 42, 54)); s.ell(17, 26, 23, 29, (200, 70, 56)); s.limb([(37, 24), (36, 28), (28, 27)], 1.2, METAL_HI); s.ell(35, 22, 39, 25, METAL); return s
add("an_giradischi", turntable())
def catbed():
    s = Spr(46, 72); s.ell(2, 56, 44, 71, (156, 60, 62)); s.ell(5, 57, 41, 66, (196, 92, 84)); s.ell(9, 46, 38, 65, FUR); s.ell(12, 48, 30, 58, FUR_HI)
    for x in (18, 23, 28): s.limb([(x, 46), (x + 1, 51)], 1.4, FUR_SH)
    s.ell(28, 48, 42, 61, FUR); s.poly([(29, 51), (30, 44), (34, 49)], FUR); s.poly([(37, 49), (41, 44), (41, 51)], FUR); s.r(31, 55, 33, 55, (70, 40, 40)); s.r(37, 55, 39, 55, (70, 40, 40)); s.p(35, 57, (230, 130, 130)); s.limb([(10, 60), (22, 64), (32, 63)], 3.4, FUR_SH); return s
add("an_gatto", catbed())

# ------------------------------------------------ parete (44x46)
def tube(s, pts, c): s.limb(pts, 1.6, c)
def neon():
    s = Spr(44, 46); c = (255, 120, 190); b = (110, 240, 255)
    for seg in ([(3, 16), (3, 30)], [(3, 16), (9, 16)], [(3, 23), (8, 23)], [(3, 30), (9, 30)]): tube(s, seg, c)
    tube(s, [(13, 21), (18, 21)], b); tube(s, [(13, 25), (18, 25)], b)
    tube(s, [(22, 30), (22, 22), (25, 21), (25, 30)], c); tube(s, [(25, 22), (28, 21), (28, 30)], c)
    tube(s, [(37, 22), (33, 21), (32, 26), (33, 30), (37, 29)], c); tube(s, [(39, 13), (41, 13), (41, 16), (39, 19), (42, 19)], b); return s
add("mu_neon", neon(), False)
def starmap():
    s = Spr(44, 46); s.r(2, 2, 41, 43, (236, 220, 180)); s.r(4, 4, 39, 41, (26, 34, 84)); s.ell(7, 6, 36, 39, (34, 46, 108))
    pts = [(14, 14), (20, 17), (26, 12), (31, 20), (25, 26), (19, 24), (14, 31), (24, 34)]
    for a, b in ((0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 1), (5, 6), (4, 7)): s.line(*pts[a], *pts[b], (110, 130, 200))
    for x, y in pts: s.r(x, y, x + 1, y + 1, (255, 244, 200))
    for k in range(26): s.p(8 + (k * 11) % 28, 7 + (k * 17) % 31, (150, 170, 230))
    return s
add("mu_mappa", starmap())
def hungguitar():
    s = Spr(44, 46); c, hi = (190, 112, 56), (226, 156, 92)
    s.limb([(22, 2), (22, 22)], 3, (84, 54, 40)); s.r(20, 0, 24, 4, (60, 40, 34)); s.ell(12, 27, 32, 45, c); s.ell(14, 18, 30, 33, c); s.limb([(15, 24), (14, 38)], 1.2, hi); s.ell(18, 25, 26, 33, (50, 34, 34)); s.r(18, 39, 26, 40, (60, 40, 34))
    for x in (21, 22, 23): s.r(x, 3, x, 39, (226, 214, 190))
    return s
add("mu_chitarra", hungguitar())
def maxwell():
    s = Spr(44, 46); s.r(1, 3, 42, 42, (242, 234, 214)); s.r(1, 3, 42, 3, (255, 250, 236)); ink = (54, 48, 84)
    E = ["111", "100", "110", "100", "111"]; B = ["110", "101", "110", "101", "110"]; Z = ["111", "101", "101", "101", "111"]; R = ["011", "100", "010", "001", "110"]; J = ["001", "001", "001", "101", "010"]; T = ["010", "111", "010", "010", "011"]
    def gl(x, y, g, c=ink):
        for yy, row in enumerate(g):
            for xx, v in enumerate(row):
                if v == "1": s.p(x + xx, y + yy, c)
    def nabla(x, y): gl(x, y, ["11111", "10001", "01010", "01010", "00100"])
    for k, (op, f, rhs) in enumerate([(".", E, "r"), (".", B, "0"), ("x", E, "b"), ("x", B, "j")]):
        y = 7 + k * 9; nabla(5, y)
        if op == ".": s.p(12, y + 2, ink)
        else: s.p(11, y + 1, ink); s.p(13, y + 1, ink); s.p(12, y + 2, ink); s.p(11, y + 3, ink); s.p(13, y + 3, ink)
        gl(16, y, f, (176, 60, 52) if f is E else (44, 92, 160)); s.r(21, y + 1, 23, y + 1, ink); s.r(21, y + 3, 23, y + 3, ink)
        if rhs == "r": gl(27, y, ["011", "101", "110", "100", "100"])
        if rhs == "0": gl(27, y, Z)
        if rhs == "b": s.r(26, y + 2, 27, y + 2, ink); gl(29, y, B, (44, 92, 160)); s.p(33, y - 1, ink)
        if rhs == "j": gl(27, y, J); s.r(32, y + 2, 34, y + 2, ink); s.p(33, y + 1, ink); s.p(33, y + 3, ink); gl(36, y, E, (176, 60, 52)); s.p(40, y - 1, ink)
    s.p(21, 1, (200, 70, 56)); s.r(20, 2, 22, 4, (200, 70, 56)); return s
add("mu_onda", maxwell())

# ------------------------------------------------ tazza di Ko-fi a pixel (26x20): porta alla pagina delle donazioni
def kofi():
    K, WH, SH, RED, RH, RS = (32, 32, 40), (255, 255, 255), (222, 226, 236), (255, 90, 82), (255, 150, 140), (214, 58, 58)
    s = Spr(26, 20)
    s.ell(15, 5, 24, 13, K); s.ell(17, 7, 22, 11, (0, 0, 0, 0))                       # manico
    s.r(17, 8, 21, 10, (0, 0, 0, 0)); s.r(17, 7, 20, 11, (0, 0, 0, 0))
    s.r(2, 2, 18, 13, K); s.r(1, 3, 19, 11, K); s.r(3, 14, 17, 15, K); s.r(5, 16, 15, 16, K)
    s.r(3, 4, 17, 11, WH); s.r(4, 12, 16, 13, WH); s.r(5, 14, 15, 14, WH); s.r(15, 4, 17, 11, SH); s.r(14, 12, 16, 13, SH)
    for y, row in enumerate(["0110110", "1111111", "1111111", "0111110", "0011100", "0001000"]):
        for x, v in enumerate(row):
            if v == "1": s.p(6 + x, 6 + y, RED)
    s.p(7, 7, RH); s.p(8, 6, RH); s.p(11, 9, RS); s.p(10, 10, RS); s.p(12, 8, RS)
    return s.outline((255, 255, 255))        # bordo chiaro, da adesivo: si vede anche sui fondi scuri
add("kofi", kofi(), False)

# ------------------------------------------------ gatto al seguito (26x20): 0-2 cammina, 3 seduto
def petcat(i):
    s = Spr(28, 20)
    if i == 3:
        s.ell(7, 8, 17, 19, FUR); s.ell(8, 9, 12, 17, FUR_HI); s.limb([(7, 17), (3, 16), (2, 11)], 2, FUR); hx, hy = 12, 2
    else:
        legs = [((8, 10), (16, 18)), ((9, 9), (17, 17)), ((7, 11), (15, 19))][i]
        for x in legs[0] + legs[1]: s.limb([(x + .5, 13), (x + (.5 if i == 0 else (-1 if i == 1 else 1.5)), 18)], 2, FUR_SH)
        s.ell(5, 7, 20, 15, FUR); s.ell(7, 7, 16, 11, FUR_HI); s.limb([(6, 9), (2, 6), (3, 2)], 2, FUR); hx, hy = 16, 2
    s.ell(hx, hy, hx + 9, hy + 9, FUR); s.poly([(hx + 1, hy + 2), (hx + 1, hy - 2), (hx + 4, hy + 1)], FUR); s.poly([(hx + 6, hy + 1), (hx + 9, hy - 2), (hx + 9, hy + 2)], FUR)
    s.p(hx + 4, hy + 4, (40, 30, 40)); s.p(hx + 7, hy + 4, (40, 30, 40)); s.p(hx + 6, hy + 6, (230, 130, 130)); s.r(hx + 3, hy + 1, hx + 3, hy + 2, FUR_SH); s.r(hx + 6, hy + 1, hx + 6, hy + 2, FUR_SH)
    return s
for i in range(4): add(f"pet{i}", petcat(i))

# ------------------------------------------------ moneta (16x16, 4 fotogrammi)
def coin(i):
    s = Spr(16, 16); w = [6.5, 5, 2, 5][i]; s.ell(7.5 - w, 1, 7.5 + w, 14, (224, 160, 50))
    if w > 3: s.ell(7.5 - w + 1.5, 2.5, 7.5 + w - 1.5, 12.5, (250, 204, 94)); s.r(7, 5, 8, 10, (190, 120, 40)); s.p(int(7.5 - w + 2), 4, (255, 246, 206))
    else: s.r(7, 3, 7, 12, (255, 236, 170))
    return s
for i in range(4): add(f"coin{i}", coin(i))

W = 256; x = y = row = 0; rects = {}; pl = []
for n, s in sorted(P.items(), key=lambda q: -q[1].a.shape[0]):
    h, w = s.a.shape[:2]
    if x + w > W: x, y, row = 0, y + row + 1, 0
    rects[n] = [x, y, w, h]; pl.append((s, x, y)); x += w + 1; row = max(row, h)
A = np.zeros((y + row, W, 4), np.uint8)
for s, x, y in pl: A[y:y + s.a.shape[0], x:x + s.a.shape[1]] = s.a
Image.fromarray(A).save(os.path.join(ROOT, "assets", "img", "shop.png"))
json.dump({"rects": rects}, open(os.path.join(ROOT, "store", "shop.json"), "w"))
print("ok", A.shape, len(P))
