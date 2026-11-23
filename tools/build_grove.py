"""I templi: cielo, bosco innevato e tre templi disegnati da zero, omaggi a tre saghe amate (Star Wars, Harry Potter, Dune).
Uso: python tools/build_grove.py  ->  cameretta-godot/assets/img/grove_far.png, grove_near.png, grove_props.png + store/grove.json
"""
import json, math, os, random
import numpy as np
from PIL import Image
from pix import Spr, SNOW, SNOW2, OUT, GL, carve

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "cameretta-godot")
rnd = random.Random(1977)
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
def mix(a, b, t): return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))

# ------------------------------------------------ cielo: a sinistra un tramonto d'ambra, a destra notte blu
FW, H = 560, 200
F = np.zeros((H, FW, 3), np.uint8)
L = [(0, (30, 24, 66)), (60, (86, 52, 104)), (110, (206, 106, 92)), (150, (250, 186, 112))]
D = [(0, (44, 26, 62)), (60, (112, 58, 74)), (110, (196, 112, 70)), (150, (236, 172, 104))]
R = [(0, (14, 16, 46)), (60, (24, 30, 80)), (110, (44, 60, 124)), (150, (78, 104, 168))]
def grad(stops, y):
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if y <= b: return mix(ca, cb, max(0, (y - a) / (b - a)))
    return stops[-1][1]
for y in range(H):
    cl, cr = grad(L, y), grad(R, y)
    for x in range(FW):
        t = min(1, max(0, (x - 120) / 190.0)); t = t * t * (3 - 2 * t)
        c = mix(cl, cr, t)
        u = min(1, max(0, (x - 340) / 130.0)); u = u * u * (3 - 2 * u); c = mix(c, grad(D, y), u); n = BAY[y % 4, x % 4] * 9
        F[y, x] = [int(min(255, max(0, round((v + n) / 7) * 7))) for v in c]
for _ in range(190):
    x, y = rnd.randrange(FW), int(105 * rnd.random() ** 1.5)
    if 110 < x < 400 or y < 36: F[y, x] = (255, 252, 230) if rnd.random() < .5 else (190, 200, 240)
def disc(cx, cy, r, c, ring):
    for y in range(int(cy - r - 2), int(cy + r + 3)):
        for x in range(int(cx - r - 2), int(cx + r + 3)):
            d = math.hypot(x - cx, y - cy)
            if 0 <= x < FW and 0 <= y < H:
                if d <= r: F[y, x] = c
                elif d <= r + 1.5 and (x + y) % 2: F[y, x] = ring
disc(58, 104, 13, (255, 240, 190), (255, 210, 140)); disc(88, 116, 9, (255, 206, 140), (250, 170, 110))     # due soli
def ridge(y0, amp, c, f, seed, x0=0, x1=FW):
    for x in range(x0, x1):
        y = y0 + amp * math.sin(x * f + seed) + amp * .5 * math.sin(x * f * 2.7 + seed * 2)
        F[int(y):, x] = c
ridge(134, 5, (126, 76, 104), .022, 1, 0, 230); ridge(128, 8, (40, 48, 104), .026, 4, 190, 400)
# un castello sulla rupe, lontano
cs, lt = (24, 26, 64), (255, 214, 120)
def rect(x0, y0, x1, y1, c): F[max(0, y0):y1 + 1, max(0, x0):x1 + 1] = c
def tower(x, w, top, base=132, roof=True):
    rect(x, top, x + w, base, cs)
    if roof:
        for k in range(w + 5):
            h = int((w + 5) / 2 - abs(k - (w + 4) / 2)) * 2
            rect(x - 2 + k, top - h, x - 2 + k, top, cs)
    else:
        for k in range(0, w + 1, 3): rect(x + k, top - 2, x + k + 1, top, cs)
for a in ((238, 9, 92), (254, 6, 74), (266, 13, 98, 132, False), (282, 7, 62), (294, 10, 88), (308, 5, 96), (228, 5, 106)): tower(*a)
rect(230, 108, 316, 134, cs)
for k in range(44):
    x, y = rnd.randint(232, 314), rnd.randint(80, 130)
    if tuple(F[y, x]) == cs and tuple(F[y - 2, x]) == cs and rnd.random() < .6: F[y - 1:y + 1, x] = lt
disc(330, 34, 11, (250, 246, 226), (170, 180, 220))
disc(486, 40, 10, (255, 236, 206), (220, 150, 120)); disc(516, 62, 6, (246, 206, 160), (220, 150, 120))      # due lune
ridge(126, 9, (176, 104, 74), .019, 2.2, 400); ridge(134, 6, (140, 78, 66), .027, .6, 392)                     # dune
ridge(142, 4, (66, 52, 98), .03, 2, 0, 250); ridge(141, 4, (28, 32, 78), .03, 5, 215, 400); ridge(143, 4, (98, 54, 60), .03, 1, 396)
for x in range(FW):                                                        # abeti lontani
    t = min(1, max(0, (x - 120) / 160.0)); c = mix(mix((52, 38, 78), (20, 24, 60), t), (74, 42, 56), min(1, max(0, (x - 350) / 110.0)))
    h = 10 * abs(math.sin(x * .37)) + 8 * abs(math.sin(x * .111 + 1)) + (x % 5 == 0) * 3
    F[int(152 - h):, x] = c
Image.fromarray(F).save(os.path.join(ROOT, "assets", "img", "grove_far.png"))

# ------------------------------------------------ primo piano: terreno e abeti innevati
W = 900
N = np.zeros((H, W, 4), np.uint8)
def put(s, x, y):
    h, w = s.a.shape[:2]
    for yy in range(h):
        for xx in range(w):
            if s.a[yy, xx, 3] and 0 <= y + yy < H and 0 <= x + xx < W: N[y + yy, x + xx] = s.a[yy, xx]
def fir(h, seed):
    r = random.Random(seed); w = int(h * .56) | 1; s = Spr(w + 4, h + 2); cx = w // 2 + 2
    s.r(cx - 2, h - 9, cx + 2, h, (70, 46, 44))
    n = max(4, h // 17)
    for k in range(n):
        y0 = int(k * (h - 10) / n * .92); y1 = y0 + int((h - 10) / n * 1.55); ww = (k + 1) / n * w / 2
        m = s.poly([(cx, y0), (cx + ww, y1), (cx + ww * .5, y1 - 3), (cx, y1 + 1), (cx - ww * .5, y1 - 3), (cx - ww, y1)], (30, 70, 70))
        s.poly([(cx + 1, y0), (cx + ww, y1), (cx + ww * .35, y1 - 3)], (22, 52, 58), only=m)
        s.limb([(cx, y0 + 1), (cx - ww * .8, y1 - 2)], 2.2, SNOW, only=m); s.limb([(cx + 1, y0 + 1), (cx + ww * .5, y1 - (y1 - y0) * .42)], 1.4, SNOW2, only=m)
        for _ in range(3): s.p(cx + r.uniform(-ww, ww) * .6, y1 - r.randint(2, 5), SNOW2)
    return s.outline()
for x in range(0, W):
    y = 150 + int(round(2 * math.sin(x * .02) + 1.5 * math.sin(x * .071)))
    N[y:, x] = (*SNOW2, 255); N[y:y + 2, x] = (*SNOW, 255)
for x in range(W):
    for y in range(158, H):
        if N[y, x, 3]:
            c = mix((222, 230, 250), (186, 198, 232), (y - 158) / 42); v = BAY[y % 4, x % 4] * 10
            N[y, x] = [int(min(255, max(0, round((q + v) / 8) * 8))) for q in c] + [255]
for x, h, sd in ((-14, 120, 1), (22, 92, 2), (236, 88, 3), (262, 116, 4), (300, 84, 5), (560, 92, 12), (588, 120, 6), (626, 86, 13), (846, 104, 7), (872, 138, 14)): put(fir(h, sd), x, 160 - h)
for _ in range(340):                                                       # impronte e grumi di neve
    x, y = rnd.randrange(W - 4), rnd.randint(162, 197); N[y, x:x + rnd.randint(2, 4)] = (*mix((160, 174, 214), (200, 210, 238), rnd.random()), 255)
for x in range(30, 870):                                                   # il sentiero battuto
    for y in range(173, 181):
        if (x * 7 + y * 13) % 5: N[y, x] = (*mix((176, 188, 222), (196, 206, 234), ((x + y) % 4) / 4), 255)
Image.fromarray(N).save(os.path.join(ROOT, "assets", "img", "grove_near.png"))

# ------------------------------------------------ i due santuari
P = {}
def add(n, s): P[n] = s.outline()
SAND, SAND_HI, SAND_SH, SAND_DK = (206, 170, 124), (240, 214, 166), (160, 122, 92), (112, 82, 72)
def stars_shrine():
    """cupola del deserto, mezza sepolta, con la porta rotonda aperta sullo spazio"""
    s = Spr(140, 124)
    s.ell(2, 34, 137, 168, SAND); s.ell(10, 40, 86, 130, SAND_HI); s.ell(17, 45, 132, 168, SAND)
    for x in (4, 116):                                                     # moduli laterali
        s.r(x, 62, x + 20, 107, SAND_SH); s.r(x, 62, x + 2, 107, SAND_HI); s.ell(x, 54, x + 20, 70, SAND_SH); s.ell(x + 2, 55, x + 12, 64, SAND)
        for y in (74, 82, 90, 98): s.r(x + 7, y, x + 13, y + 3, (60, 50, 70)); s.r(x + 8, y + 1, x + 12, y + 2, (90, 190, 220))
    s.ell(34, 42, 105, 113, SAND_DK); s.ell(37, 45, 102, 110, (128, 124, 146)); m = s.ell(41, 49, 98, 106, (26, 20, 56))
    for k in range(12):                                                    # denti della porta
        a = k * math.pi / 6; s.r(69.5 + 31 * math.cos(a) - 1, 77.5 + 31 * math.sin(a) - 1, 69.5 + 31 * math.cos(a) + 1, 77.5 + 31 * math.sin(a) + 1, (214, 214, 232))
    for k in range(60): s.p(42 + (k * 23) % 56, 50 + (k * 37) % 56, (150, 130, 190) if k % 3 else (255, 240, 200))
    s.ell(50, 56, 66, 72, (255, 224, 150), only=m); s.ell(52, 58, 60, 66, (255, 244, 200), only=m); s.ell(72, 64, 82, 74, (250, 164, 100), only=m)
    s.poly([(38, 108), (54, 88), (66, 98), (82, 84), (102, 108)], (92, 58, 88), only=m)
    s.r(64, 22, 75, 36, SAND_SH); s.r(64, 22, 66, 36, SAND_HI); s.r(70, 14, 71, 22, (110, 110, 130)); s.ell(60, 4, 76, 16, (150, 152, 172)); s.ell(63, 3, 79, 13, (206, 208, 224)); s.r(72, 7, 76, 8, (110, 110, 130)); s.p(77, 7, (255, 90, 80))
    s.r(26, 30, 27, 48, (110, 110, 130)); s.r(25, 40, 28, 47, (150, 152, 172)); s.r(111, 42, 114, 49, (150, 152, 172)); s.p(26, 29, (90, 220, 255)); s.r(112, 34, 113, 50, (110, 110, 130)); s.p(112, 33, (90, 220, 255))      # vaporizzatori
    for x, y in ((30, 92), (104, 62), (110, 74), (22, 60)): s.r(x, y, x + 6, y + 2, SAND_SH)
    for x in range(14, 126):
        y = 100 - math.sqrt(max(0, 1 - ((x - 69.5) / 67) ** 2)) * 66
        if y < 72: s.r(x, y, x, y + 2 + (math.sin(x * .9) > .2), SNOW)
    s.poly([(55, 97), (84, 97), (89, 107), (50, 107)], (128, 124, 146)); s.r(57, 95, 82, 98, (168, 166, 188)); s.r(57, 95, 82, 95, (214, 214, 232))
    s.r(68, 85, 71, 95, (176, 180, 198)); s.r(68, 87, 71, 87, (60, 58, 74)); s.r(68, 90, 71, 90, (60, 58, 74)); s.p(71, 92, (220, 60, 60))   # elsa
    s.r(0, 106, 139, 123, SAND_SH); s.r(0, 106, 139, 107, SAND_HI); s.r(0, 122, 139, 123, SAND_DK)
    carve(s, "STAR WARS", 70, 110, (255, 236, 170), SAND_DK, 1, True); return s
add("shrine_stelle", stars_shrine())
HAT, HAT_HI, HAT_SH = (74, 56, 132), (116, 94, 178), (48, 36, 92)
BRK, BRK_HI, BRK_SH = (122, 82, 60), (164, 116, 82), (82, 54, 46)
def magic_shrine():
    """bottega di magia: un cappello a punta gigante, storto, su quattro pali di legno; dentro libri e calderone"""
    s = Spr(140, 150)
    s.r(18, 72, 121, 133, (44, 30, 44))
    cols = [(176, 50, 52), (228, 172, 64), (52, 104, 180), (54, 128, 84), (110, 72, 160), (200, 190, 170), (150, 88, 50)]
    for r_, y in enumerate((84, 98, 112)):                                # scaffali
        s.r(20, y, 119, y + 1, BRK_SH); x = 21
        while x < 117:
            k = (x * 3 + x // 4 + r_ * 5) % 7; h = 7 + (x * 3 + r_) % 5; w = 2 + (x + r_) % 2
            if (x * 11 + r_ * 3) % 13: s.r(x, y - h, x + w - 1, y - 1, cols[k]); s.p(x, y - h + 2, (250, 230, 160))
            x += w + 1
    for x in (14, 40, 96, 122):
        s.r(x, 70, x + 5, 133, BRK); s.r(x, 70, x + 1, 133, BRK_HI); s.r(x + 5, 70, x + 5, 133, BRK_SH)
    # cappello
    m = s.curve([(8, 70), (30, 62), (44, 40), (54, 18), (70, 5), (92, 8), (98, 20), (90, 22), (84, 16), (80, 22), (92, 44), (106, 62), (132, 70), (126, 77), (70, 80), (14, 77)], HAT)
    s.limb([(50, 30), (40, 52), (28, 66)], 4, HAT_HI, only=m); s.limb([(84, 26), (96, 50), (112, 68)], 5, HAT_SH, only=m); s.limb([(70, 8), (88, 12)], 2.4, HAT_HI, only=m)
    s.poly([(30, 62), (108, 62), (112, 70), (26, 70)], (150, 104, 52), only=m); s.r(62, 61, 76, 71, (242, 200, 100)); s.r(65, 64, 73, 68, (150, 104, 52))
    for x, y in ((54, 46), (76, 36), (90, 54), (64, 24), (44, 58)):
        s.r(x - 1, y, x + 1, y, (255, 230, 140)); s.r(x, y - 1, x, y + 1, (255, 230, 140))
    s.ell(92, 18, 98, 24, (255, 224, 120))
    for x0, x1 in ((10, 34), (104, 130)): s.r(x0, 69 - (x0 > 100), x1, 70, SNOW)
    s.limb([(56, 16), (68, 5), (84, 6)], 2, SNOW); s.limb([(34, 60), (44, 42)], 2, SNOW)
    # bancone, calderone, libro, bacchetta, civetta
    s.r(46, 116, 94, 121, BRK_HI); s.r(46, 121, 94, 133, BRK); s.r(46, 121, 94, 121, BRK_SH)
    s.ell(50, 100, 68, 117, (46, 46, 60)); s.r(48, 102, 70, 104, (86, 86, 104)); s.ell(51, 100, 67, 104, (110, 220, 120)); s.p(55, 99, (190, 255, 180)); s.p(62, 97, (190, 255, 180))
    s.poly([(72, 114), (81, 111), (81, 115)], (240, 230, 204)); s.poly([(91, 114), (82, 111), (82, 115)], (222, 208, 176)); s.limb([(71, 115), (92, 115)], 1.6, (122, 54, 46)); s.limb([(86, 109), (95, 102)], 1.4, (190, 130, 84))
    s.ell(104, 92, 116, 110, (214, 206, 196)); s.ell(104, 86, 116, 98, (236, 230, 222)); s.ell(106, 90, 109, 93, (250, 200, 80)); s.ell(111, 90, 114, 93, (250, 200, 80)); s.p(107, 91, OUT); s.p(112, 91, OUT); s.p(110, 94, (214, 150, 60)); s.limb([(106, 98), (107, 107)], 1.4, (170, 158, 150)); s.r(100, 110, 120, 112, BRK_HI)
    s.poly([(30, 96), (26, 106), (30, 106), (27, 115), (36, 103), (32, 103), (35, 96)], (255, 224, 100))                # saetta
    s.r(0, 132, 139, 149, BRK_SH); s.r(0, 132, 139, 133, BRK_HI); s.r(0, 148, 139, 149, (54, 36, 34))
    carve(s, "HARRY POTTER", 70, 137, (255, 226, 140), (54, 36, 34), 1, True); return s
add("shrine_magia", magic_shrine())
RK, RK_HI, RK_SH, RK_DK = (178, 112, 74), (222, 160, 104), (134, 78, 60), (84, 46, 46)
def dune_shrine():
    """rupe scavata nella roccia, con la sagoma di un verme gigante che le fa da arco"""
    s = Spr(140, 140)
    s.poly([(2, 124), (8, 92), (16, 84), (20, 60), (32, 52), (38, 34), (54, 28), (62, 16), (84, 14), (94, 30), (106, 36), (112, 58), (124, 66), (130, 92), (137, 124)], RK)
    s.poly([(2, 124), (8, 92), (16, 84), (20, 60), (32, 52), (38, 34), (54, 28), (62, 16), (66, 16), (58, 34), (46, 42), (42, 60), (30, 70), (26, 96), (18, 124)], RK_HI)
    s.poly([(94, 30), (106, 36), (112, 58), (124, 66), (130, 92), (137, 124), (116, 124), (112, 90), (102, 72), (98, 50)], RK_SH)
    for y, x0, x1 in ((46, 48, 92), (64, 40, 104), (82, 26, 116), (102, 16, 124)): s.limb([(x0, y), ((x0 + x1) / 2, y + 2), (x1, y - 1)], 1.2, RK_SH)
    m = s.poly([(44, 124), (54, 58), (86, 58), (96, 124)], RK_DK)                   # porta a trapezio
    s.poly([(49, 124), (58, 63), (82, 63), (91, 124)], (34, 22, 40))
    for k in range(6): s.r(46 + k, 116 - k * 10, 47 + k, 119 - k * 10, RK_HI); s.r(93 - k, 116 - k * 10, 94 - k, 119 - k * 10, RK_HI)
    s.ell(64, 68, 72, 76, (255, 232, 190)); s.ell(74, 74, 79, 79, (240, 190, 140))                       # due lune
    s.poly([(50, 124), (57, 104), (68, 110), (80, 100), (90, 124)], (190, 116, 66)); s.poly([(57, 104), (68, 110), (60, 124), (50, 124)], (226, 156, 92))
    # il verme: anelli che escono dalla sabbia a sinistra e rientrano a destra
    pts = [(math.pi * (1 - k / 22.0)) for k in range(23)]
    ring = [(70 - 62 * math.cos(math.pi - a) * -1 if False else 70 + 62 * math.cos(a), 126 - 112 * math.sin(a)) for a in pts]
    s.limb(ring, 13, (142, 96, 78)); s.limb([(x - 2, y - 2) for x, y in ring], 4, (190, 140, 108))
    for k, (x, y) in enumerate(ring):
        a = pts[k]; nx, ny = 62 * math.cos(a) / 70, -112 * math.sin(a) / 90
        n = math.hypot(nx, ny) or 1; s.limb([(x - nx / n * 6, y - ny / n * 6), (x + nx / n * 6, y + ny / n * 6)], 1.2, (96, 62, 58))
    s.ell(122, 108, 139, 126, (96, 62, 58)); s.ell(125, 111, 137, 124, (50, 26, 34))
    for k in range(10):
        a = k * math.pi / 5; s.limb([(131 + 7 * math.cos(a), 117.5 + 7 * math.sin(a)), (131 + 4 * math.cos(a), 117.5 + 4 * math.sin(a))], 1.2, (246, 230, 206))
    # leggio con i libri
    s.r(60, 112, 80, 115, RK_HI); s.poly([(63, 116), (77, 116), (80, 123), (60, 123)], RK_SH)
    s.poly([(60, 110), (70, 106), (70, 111)], (246, 236, 210)); s.poly([(80, 110), (70, 106), (70, 111)], (226, 210, 176)); s.limb([(59, 111), (81, 111)], 1.6, (60, 110, 190))
    for k, c in enumerate(((60, 110, 190), (214, 132, 60), (120, 60, 90))): s.r(34 + k, 119 - k * 4, 45 - k, 122 - k * 4, c); s.r(34 + k, 119 - k * 4, 45 - k, 119 - k * 4, tuple(min(255, v + 50) for v in c))
    for x in range(56, 96):
        if s.m[:, x].any() and x < 88: pass
    s.limb([(60, 17), (84, 14)], 2.4, SNOW); s.limb([(38, 34), (54, 28)], 2, SNOW); s.limb([(96, 31), (106, 36)], 2, SNOW)
    s.r(0, 122, 139, 139, RK_SH); s.r(0, 122, 139, 123, RK_HI); s.r(0, 138, 139, 139, RK_DK)
    carve(s, "DUNE", 70, 126, (150, 216, 255), RK_DK, 2, True); return s
add("shrine_dune", dune_shrine())
def candle():
    s = Spr(6, 14); s.r(1, 4, 4, 12, (242, 232, 208)); s.r(4, 4, 4, 12, (206, 190, 160)); s.r(1, 4, 2, 6, (255, 250, 236)); s.p(2, 3, (70, 50, 40)); return s
add("candle", candle())
def crystal(c, hi):
    s = Spr(6, 14); s.poly([(2, 3), (3, 3), (5, 7), (4, 13), (1, 13), (0, 7)], c); s.limb([(2, 5), (2, 11)], 1, hi); return s
for k, (c, hi) in enumerate((((80, 160, 235), (200, 240, 255)), ((80, 200, 110), (210, 255, 210)), ((150, 100, 220), (230, 210, 255)))): add(f"crystal{k}", crystal(c, hi))
def bowl():
    s = Spr(10, 8); s.ell(0, 0, 9, 7, RK_SH); s.r(0, 0, 9, 2, (0, 0, 0, 0)); s.r(0, 2, 9, 3, RK_HI); s.r(1, 2, 8, 2, (70, 150, 230)); s.p(3, 2, (190, 230, 255)); return s
add("bowl", bowl())
def sign():
    s = Spr(52, 56); s.r(24, 8, 27, 55, (104, 70, 48)); s.r(24, 8, 24, 55, (140, 98, 66))
    s.poly([(4, 10), (40, 10), (48, 17), (40, 24), (4, 24)], (138, 92, 58)); s.r(5, 11, 39, 11, (172, 122, 80))
    carve(s, "TEMPLI", 23, 15, (255, 240, 206), (100, 66, 46))
    s.r(9, 27, 42, 48, (94, 64, 140)); s.r(9, 27, 42, 27, (150, 116, 196)); s.r(10, 28, 41, 47, (66, 44, 108))
    w = (240, 244, 255); s.r(14, 31, 15, 42, (140, 210, 255)); s.r(13, 39, 16, 45, w)                          # spada di luce
    s.poly([(26, 30), (22, 38), (25, 38), (23, 45), (30, 36), (26, 36), (29, 30)], (255, 224, 130))           # saetta
    for k in range(4): s.ell(33 + k, 44 - k * 4, 37 + k, 46 - k * 4, (226, 156, 92))                          # verme
    s.ell(36, 29, 41, 34, (226, 156, 92)); s.ell(37, 30, 40, 33, (60, 30, 40))
    s.r(4, 8, 40, 9, SNOW); s.r(8, 7, 30, 7, SNOW); s.r(9, 25, 42, 26, SNOW); s.ell(19, 50, 33, 58, SNOW); return s
add("signgrove", sign())
def arrow(s, word, y, right, w, c):
    """una tavola di legno a freccia, con la scritta"""
    cx = 42; x0, x1 = cx - w // 2, cx + w // 2
    s.poly([(x0, y), (x1, y), (x1 + 8, y + 6), (x1, y + 12), (x0, y + 12)] if right else [(x0, y), (x1, y), (x1, y + 12), (x0, y + 12), (x0 - 8, y + 6)], (138, 92, 58))
    s.r(x0 + 1, y + 1, x1 - 1, y + 1, (172, 122, 80)); s.r(x0 + 1, y + 11, x1 - 1, y + 11, (100, 66, 46)); carve(s, word, cx, y + 4, c, (84, 54, 40)); s.r(x0 + 2, y - 1, x1 - 4, y, SNOW)
def guide():
    s = Spr(86, 70); s.r(40, 2, 44, 69, (104, 70, 48)); s.r(40, 2, 40, 69, (140, 98, 66)); s.r(39, 0, 45, 2, SNOW)
    arrow(s, "STAR WARS", 5, False, 50, (255, 226, 140)); arrow(s, "HARRY POTTER", 21, True, 62, (214, 190, 255)); arrow(s, "DUNE", 37, True, 34, (150, 216, 255)); s.ell(34, 64, 50, 73, SNOW); return s
add("guide", guide())
def guide2():
    s = Spr(86, 50); s.r(40, 2, 44, 49, (104, 70, 48)); s.r(40, 2, 40, 49, (140, 98, 66)); s.r(39, 0, 45, 2, SNOW); arrow(s, "DUNE", 6, True, 34, (150, 216, 255)); s.ell(34, 44, 50, 53, SNOW); return s
add("guide2", guide2())
A = np.zeros((164, 622, 4), np.uint8); rects = {}; x = 0; small = 0
for n, s in P.items():
    h, w = s.a.shape[:2]
    if n.startswith("shrine"): x0, y = x, 0; x += w + 2
    elif n == "signgrove": x0, y = 440, 0
    elif n.startswith("guide"): x0, y = 440 + (92 if n == "guide2" else 0), 90
    else: x0, y = 440 + small, 70; small += w + 2
    A[y:y + h, x0:x0 + w] = s.a; rects[n] = [x0, y, w, h]
Image.fromarray(A).save(os.path.join(ROOT, "assets", "img", "grove_props.png"))
json.dump({"rects": rects, "world": W, "feet": 177, "stelle": 150, "magia": 440, "dune": 730}, open(os.path.join(ROOT, "store", "grove.json"), "w"))
print("ok", x)
