"""Strada innevata a parallasse (320x200 di vista, mondo largo 1600).
Output: street_far.png, street_mid.png, street_near.png, street.json
"""
import json, math, random
import numpy as np
from PIL import Image, ImageDraw

H, VIEW, WORLD = 200, 320, 1600
PFAR, PMID = 0.15, 0.45
WFAR = int(VIEW + (WORLD - VIEW) * PFAR)
WMID = int(VIEW + (WORLD - VIEW) * PMID)
FEET = 168
rnd = random.Random(11)
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5


def blend(img, x, y, c, a):
    if 0 <= x < img.shape[1] and 0 <= y < img.shape[0]:
        if img[y, x, 3] == 0:
            return
        img[y, x, :3] = (img[y, x, :3] * (1 - a) + np.array(c) * a).astype(np.uint8)


def glow(img, cx, cy, rx, ry, c, amax):
    for y in range(int(cy - ry), int(cy + ry) + 1):
        for x in range(int(cx - rx), int(cx + rx) + 1):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d < 1:
                blend(img, x, y, c, amax * (1 - d) ** 1.5)


# ---------------------------------------------------------------- lontano
far = np.zeros((H, WFAR, 4), np.uint8)
for y in range(H):
    if y < 110:
        t = y / 110; c = np.array([10, 12, 34]) * (1 - t) + np.array([40, 36, 86]) * t
    else:
        t = min(1, (y - 110) / 30); c = np.array([40, 36, 86]) * (1 - t) + np.array([96, 70, 118]) * t
    for x in range(WFAR):
        cc = np.floor(c / 8 + BAY[y % 4, x % 4] + 0.5) * 8
        far[y, x] = (*np.clip(cc, 0, 255), 255)
# stelle
for k in range(260):
    x, y = rnd.randrange(WFAR), rnd.randrange(0, 105)
    b = rnd.choice([0.5, 0.7, 1.0, 1.0])
    col = np.array(rnd.choice([[255, 248, 220], [210, 222, 255], [255, 224, 190]])) * b
    far[y, x, :3] = col
    if b == 1.0 and rnd.random() < 0.25:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if 0 <= x + dx < WFAR and 0 <= y + dy < H:
                far[y + dy, x + dx, :3] = col * 0.5
# luna
mcx, mcy, mr = 250, 34, 11
for y in range(mcy - mr - 8, mcy + mr + 9):
    for x in range(mcx - mr - 8, mcx + mr + 9):
        d = math.hypot(x - mcx, y - mcy)
        if d <= mr:
            c = np.array([255, 242, 206]) * (1 - 0.2 * max(0, (x - mcx + y - mcy) / (2 * mr)))
            for (ox, oy, r) in ((-4, -3, 3), (4, 3, 2), (-1, 6, 1.6)):
                if math.hypot(x - mcx - ox, y - mcy - oy) < r:
                    c = c * 0.87
            far[y, x, :3] = c
        elif d <= mr + 8:
            blend(far, x, y, (255, 230, 190), 0.25 * (1 - (d - mr) / 8))
# montagne
def ridge(base, amp, f1, f2, ph):
    return [base - amp * (0.6 * math.sin(x / f1 + ph) + 0.4 * math.sin(x / f2 + ph * 2)) for x in range(WFAR)]
r1 = ridge(100, 22, 41, 17, 0.4)
r2 = ridge(118, 10, 29, 11, 1.7)
for x in range(WFAR):
    top = int(r1[x])
    for y in range(top, H):
        snow = y < top + 4 + 2 * math.sin(x / 5)
        far[y, x, :3] = (196, 206, 236) if snow else (72, 74, 124)
        if not snow and (x + y) % 7 == 0:
            far[y, x, :3] = (64, 66, 114)
    top2 = int(r2[x])
    for y in range(top2, H):
        far[y, x, :3] = (176, 188, 224) if y < top2 + 2 else (50, 52, 96)
# luci di un paese lontano
for k in range(70):
    x = rnd.randrange(WFAR); y = int(r2[x]) + rnd.randrange(3, 14)
    if y < H:
        far[y, x, :3] = rnd.choice([(255, 210, 130), (255, 190, 110), (255, 236, 170)])
Image.fromarray(far, "RGBA").save("street_far.png")

# ---------------------------------------------------------------- medio: case dall'altra parte della strada
mid = Image.new("RGBA", (WMID, H), (0, 0, 0, 0))
d = ImageDraw.Draw(mid)
BASE = 128
d.rectangle([0, BASE - 2, WMID, BASE + 12], fill=(206, 216, 238))
for x in range(0, WMID, 3):
    d.point((x, BASE - 2 - (1 if (x // 3) % 5 == 0 else 0)), fill=(226, 234, 250))
WALLS = [(150, 70, 58), (196, 150, 82), (118, 140, 110), (210, 196, 170), (86, 104, 150), (160, 104, 76)]
lights_m = []
x = 6
while x < WMID - 30:
    if rnd.random() < 0.3:
        # abete innevato
        tw = rnd.randint(16, 24); th = rnd.randint(30, 44); cx = x + tw // 2
        for i in range(4):
            yy = BASE - 4 - i * th // 5
            w = tw // 2 - i * 2
            d.polygon([(cx - w, yy), (cx + w, yy), (cx, yy - th // 3)], fill=(30, 72, 66))
            d.line([(cx - w + 1, yy - 1), (cx, yy - th // 3 + 1)], fill=(220, 230, 248))
            d.line([(cx - w + 2, yy), (cx + w - 2, yy)], fill=(206, 218, 244))
        d.rectangle([cx - 1, BASE - 4, cx + 1, BASE - 1], fill=(70, 48, 40))
        for k in range(6):
            lights_m.append((cx + rnd.randint(-tw // 3, tw // 3), BASE - 8 - rnd.randint(0, th - 12)))
        x += tw + rnd.randint(4, 10)
        continue
    w = rnd.randint(40, 64); h = rnd.randint(28, 44)
    wall = rnd.choice(WALLS)
    top = BASE - h
    d.rectangle([x, top, x + w, BASE - 1], fill=wall)
    dark = tuple(int(c * 0.78) for c in wall)
    for yy in range(top + 3, BASE, 4):
        d.line([(x, yy), (x + w, yy)], fill=dark)
    # tetto con neve spessa
    rh = rnd.randint(14, 20)
    d.polygon([(x - 5, top + 1), (x + w + 5, top + 1), (x + w // 2, top - rh)], fill=(64, 48, 60))
    d.polygon([(x - 6, top + 1), (x + w + 6, top + 1), (x + w // 2 + 1, top - rh - 2), (x + w // 2 - 1, top - rh - 2)], outline=None, fill=(232, 238, 252))
    d.polygon([(x - 2, top - 1), (x + w + 2, top - 1), (x + w // 2, top - rh + 2)], fill=(64, 48, 60))
    d.polygon([(x - 6, top + 1), (x + w + 6, top + 1), (x + w + 6, top + 3), (x - 6, top + 3)], fill=(214, 224, 246))
    # comignolo
    if rnd.random() < 0.7:
        chx = x + rnd.randint(8, w - 12)
        d.rectangle([chx, top - rh + 2, chx + 5, top - 4], fill=(120, 70, 60))
        d.rectangle([chx - 1, top - rh, chx + 6, top - rh + 2], fill=(236, 240, 252))
    # finestre calde
    nwin = max(1, w // 18)
    for i in range(nwin):
        wx = x + 6 + i * (w - 12) // max(1, nwin) + 2
        wy = top + 8
        lit = rnd.random() < 0.8
        col = (255, 204, 120) if lit else (44, 46, 80)
        d.rectangle([wx, wy, wx + 8, wy + 9], fill=(52, 36, 34))
        d.rectangle([wx + 1, wy + 1, wx + 7, wy + 8], fill=col)
        if lit:
            d.line([(wx + 4, wy + 1), (wx + 4, wy + 8)], fill=(214, 150, 80)); d.line([(wx + 1, wy + 4), (wx + 7, wy + 4)], fill=(214, 150, 80))
            d.rectangle([wx + 1, wy + 1, wx + 2, wy + 8], fill=(200, 90, 70))
        d.rectangle([wx - 1, wy + 10, wx + 9, wy + 11], fill=(236, 240, 252))
    # porta
    dx = x + w // 2 - 4
    d.rectangle([dx, BASE - 14, dx + 8, BASE - 1], fill=(90, 54, 42)); d.point((dx + 6, BASE - 7), fill=(240, 200, 90))
    d.ellipse([dx + 2, BASE - 13, dx + 6, BASE - 9], outline=(60, 130, 80))
    # lucine di natale sotto la gronda
    for k in range(x - 2, x + w + 3, 4):
        lights_m.append((k, top + 4 + (1 if (k // 4) % 2 else 0)))
    x += w + rnd.randint(10, 22)
mid_a = np.array(mid)
LCOL = [(255, 96, 90), (255, 214, 100), (110, 220, 140), (110, 180, 255)]
for i, (lx, ly) in enumerate(lights_m):
    if 0 <= lx < WMID and 0 <= ly < H:
        mid_a[ly, lx] = (*LCOL[i % 4], 255)
Image.fromarray(mid_a, "RGBA").save("street_mid.png")

# ---------------------------------------------------------------- vicino: strada, marciapiede, lampioni, casa
near = Image.new("RGBA", (WORLD, H), (0, 0, 0, 0))
d = ImageDraw.Draw(near)
d.rectangle([0, 134, WORLD, 151], fill=(146, 156, 190))       # strada battuta
for x in range(0, WORLD, 2):
    if (x * 13) % 7 == 0:
        d.point((x, 136 + (x % 13)), fill=(132, 142, 178))
d.line([(0, 140), (WORLD, 140)], fill=(124, 134, 172))        # solchi delle gomme
d.line([(0, 141), (WORLD, 141)], fill=(160, 170, 204))
d.line([(0, 146), (WORLD, 146)], fill=(124, 134, 172))
d.rectangle([0, 152, WORLD, 154], fill=(236, 242, 255))       # cordolo innevato
d.line([(0, 155), (WORLD, 155)], fill=(170, 180, 214))
d.rectangle([0, 156, WORLD, 178], fill=(224, 232, 248))       # marciapiede
for x in range(0, WORLD, 3):
    if (x * 7) % 11 == 0:
        d.point((x, 158 + (x * 5) % 18), fill=(208, 218, 240))
# impronte
for k in range(60):
    fx = rnd.randrange(0, 1380); fy = rnd.choice([162, 165, 168, 171])
    d.ellipse([fx, fy, fx + 3, fy + 1], fill=(198, 208, 234)); d.ellipse([fx + 6, fy + 2, fx + 9, fy + 3], fill=(198, 208, 234))
# cumuli di neve in primo piano
for x in range(0, WORLD):
    top = 180 + 3 * math.sin(x / 11) + 2 * math.sin(x / 4.3 + 1)
    for y in range(int(top), H):
        c = (244, 248, 255) if y < top + 2 else (214, 224, 246) if y < top + 8 else (190, 202, 232)
        near.putpixel((x, y), (*c, 255))
for x in range(0, WORLD, 2):
    top = 178 + 3 * math.sin(x / 11) + 2 * math.sin(x / 4.3 + 1)
    near.putpixel((x, int(top) + 1), (255, 255, 255, 255))
# cespugli innevati
for k in range(22):
    bx = rnd.randrange(20, 1360); by = 184
    for j in range(3):
        ox = bx + j * 5 - 5
        d.ellipse([ox, by - 6, ox + 9, by + 4], fill=(40, 80, 70))
        d.ellipse([ox + 1, by - 7, ox + 8, by - 3], fill=(236, 242, 255))
    if k % 3 == 0:
        for j in range(4):
            near.putpixel((bx + rnd.randint(-4, 12), by - rnd.randint(0, 4)), (*LCOL[j], 255))

lamps = []
for lx in range(110, 1300, 210):
    lamps.append({"x": lx, "y": 64})
    d.rectangle([lx - 1, 70, lx + 1, 158], fill=(40, 40, 58))
    d.line([(lx - 1, 70), (lx - 1, 158)], fill=(70, 70, 92))
    d.rectangle([lx - 3, 156, lx + 3, 160], fill=(40, 40, 58))
    d.rectangle([lx - 4, 159, lx + 4, 161], fill=(54, 54, 74))
    # lanterna
    d.polygon([(lx - 5, 58), (lx + 5, 58), (lx + 3, 54), (lx - 3, 54)], fill=(40, 40, 58))
    d.rectangle([lx - 4, 59, lx + 4, 68], fill=(40, 40, 58))
    d.rectangle([lx - 3, 60, lx + 3, 67], fill=(255, 216, 140))
    d.line([(lx, 60), (lx, 67)], fill=(220, 160, 90))
    d.rectangle([lx - 5, 68, lx + 5, 69], fill=(40, 40, 58))
    d.rectangle([lx - 4, 52, lx + 4, 54], fill=(238, 244, 255))   # neve sopra
    d.point((lx, 51), fill=(238, 244, 255))
    # fiocco rosso sul palo
    d.polygon([(lx - 4, 80), (lx, 83), (lx - 4, 86)], fill=(196, 56, 52)); d.polygon([(lx + 4, 80), (lx, 83), (lx + 4, 86)], fill=(196, 56, 52))
    d.line([(lx, 83), (lx - 2, 92)], fill=(160, 40, 40)); d.line([(lx, 83), (lx + 2, 92)], fill=(160, 40, 40))
    d.line([(lx - 2, 76), (lx + 2, 76)], fill=(40, 120, 70))
    for k in range(-6, 7, 2):
        d.point((lx + k, 75 + abs(k) // 3), fill=(46, 110, 70))

# panchina
for bx in (330, 980):
    d.rectangle([bx, 154, bx + 22, 155], fill=(110, 72, 48)); d.rectangle([bx, 158, bx + 22, 159], fill=(130, 86, 56))
    d.rectangle([bx + 2, 160, bx + 3, 166], fill=(40, 40, 58)); d.rectangle([bx + 19, 160, bx + 20, 166], fill=(40, 40, 58))
    d.rectangle([bx, 153, bx + 22, 153], fill=(236, 242, 255)); d.rectangle([bx, 157, bx + 22, 157], fill=(236, 242, 255))
# pupazzo di neve
sx = 760
d.ellipse([sx, 150, sx + 18, 166], fill=(244, 248, 255), outline=(190, 202, 232))
d.ellipse([sx + 3, 138, sx + 15, 151], fill=(244, 248, 255), outline=(190, 202, 232))
d.ellipse([sx + 5, 128, sx + 13, 139], fill=(244, 248, 255), outline=(190, 202, 232))
d.point((sx + 7, 132), fill=(30, 30, 40)); d.point((sx + 10, 132), fill=(30, 30, 40))
d.polygon([(sx + 9, 134), (sx + 15, 135), (sx + 9, 136)], fill=(240, 130, 50))
d.rectangle([sx + 4, 137, sx + 14, 139], fill=(70, 140, 120)); d.rectangle([sx + 12, 139, sx + 14, 145], fill=(70, 140, 120))
d.rectangle([sx + 5, 125, sx + 13, 127], fill=(40, 36, 50)); d.rectangle([sx + 7, 120, sx + 11, 125], fill=(40, 36, 50))
d.point((sx + 9, 143), fill=(30, 30, 40)); d.point((sx + 9, 146), fill=(30, 30, 40))
d.line([(sx + 2, 142), (sx - 5, 136)], fill=(100, 70, 50)); d.line([(sx + 16, 142), (sx + 23, 137)], fill=(100, 70, 50))
# slittino appoggiato
d.rectangle([548, 162, 568, 164], fill=(176, 60, 50)); d.line([(546, 166), (570, 166)], fill=(80, 80, 96)); d.line([(570, 166), (572, 163)], fill=(80, 80, 96))

# ---- casa in fondo alla strada
HX0, HX1, HB = 1388, 1588, 158
d.rectangle([HX0, 78, HX1, HB], fill=(138, 86, 58))
for y in range(80, HB, 4):
    d.line([(HX0, y), (HX1, y)], fill=(112, 68, 46))
for x in range(HX0, HX1, 23):
    d.line([(x, 78), (x, HB)], fill=(120, 74, 50))
# tetto
d.polygon([(HX0 - 14, 80), (HX1 + 14, 80), ((HX0 + HX1) // 2, 22)], fill=(70, 44, 52))
d.polygon([(HX0 - 16, 81), (HX1 + 16, 81), ((HX0 + HX1) // 2 + 2, 18), ((HX0 + HX1) // 2 - 2, 18)], fill=(234, 240, 254))
d.polygon([(HX0 - 8, 78), (HX1 + 8, 78), ((HX0 + HX1) // 2, 28)], fill=(70, 44, 52))
for k in range(8):
    y = 36 + k * 6
    hw = (y - 28) * ((HX1 - HX0 + 16) / 2) / 50
    d.line([((HX0 + HX1) // 2 - hw, y), ((HX0 + HX1) // 2 + hw, y)], fill=(84, 54, 62))
d.rectangle([HX0 - 16, 80, HX1 + 16, 84], fill=(226, 234, 252))
for x in range(HX0 - 14, HX1 + 14, 5):                          # ghiaccioli
    d.line([(x, 85), (x, 85 + (x * 7) % 5)], fill=(200, 224, 250))
# comignolo
CHX = 1548
d.rectangle([CHX, 34, CHX + 12, 60], fill=(150, 70, 56))
for y in range(36, 60, 4):
    d.line([(CHX, y), (CHX + 12, y)], fill=(124, 56, 46))
d.rectangle([CHX - 2, 30, CHX + 14, 34], fill=(236, 242, 255))
# finestra tonda nel sottotetto
cx = (HX0 + HX1) // 2
d.ellipse([cx - 9, 46, cx + 9, 64], fill=(52, 36, 34)); d.ellipse([cx - 7, 48, cx + 7, 62], fill=(255, 206, 120))
d.line([(cx, 48), (cx, 62)], fill=(200, 140, 80)); d.line([(cx - 7, 55), (cx + 7, 55)], fill=(200, 140, 80))
# finestre grandi con tende
wins = []
for wx in (HX0 + 18, HX1 - 52):
    d.rectangle([wx, 96, wx + 34, 126], fill=(60, 40, 34))
    d.rectangle([wx + 2, 98, wx + 32, 124], fill=(255, 204, 118))
    d.rectangle([wx + 2, 98, wx + 7, 124], fill=(196, 70, 56)); d.rectangle([wx + 27, 98, wx + 32, 124], fill=(196, 70, 56))
    d.line([(wx + 17, 98), (wx + 17, 124)], fill=(196, 140, 80)); d.line([(wx + 2, 111), (wx + 32, 111)], fill=(196, 140, 80))
    d.rectangle([wx - 2, 126, wx + 36, 128], fill=(236, 242, 255))
    d.rectangle([wx + 1, 129, wx + 33, 134], fill=(110, 70, 50))      # fioriera
    for k in range(wx + 3, wx + 32, 4):
        d.point((k, 128), fill=(60, 120, 70))
    wins.append([wx + 2, 98, wx + 32, 124])
# porta con ghirlanda
DX = (HX0 + HX1) // 2
d.rectangle([DX - 13, 104, DX + 13, HB], fill=(60, 36, 30))
d.rectangle([DX - 11, 106, DX + 11, HB], fill=(150, 56, 48))
d.rectangle([DX - 9, 108, DX + 9, 118], fill=(255, 206, 120))
d.line([(DX, 108), (DX, 118)], fill=(150, 56, 48))
d.rectangle([DX - 9, 122, DX - 1, 152], outline=(124, 44, 40)); d.rectangle([DX + 1, 122, DX + 9, 152], outline=(124, 44, 40))
d.point((DX + 7, 136), fill=(250, 210, 100)); d.point((DX + 7, 137), fill=(250, 210, 100))
d.ellipse([DX - 7, 120, DX + 7, 134], outline=(40, 110, 66), width=3)
d.point((DX, 134), fill=(210, 50, 50)); d.point((DX - 1, 135), fill=(210, 50, 50)); d.point((DX + 1, 135), fill=(210, 50, 50))
for a in range(0, 360, 45):
    d.point((DX + round(6 * math.cos(math.radians(a))), 127 + round(6 * math.sin(math.radians(a)))), fill=(255, 220, 120))
# lanterna del portico
d.rectangle([DX + 18, 104, DX + 22, 112], fill=(40, 40, 58)); d.rectangle([DX + 19, 105, DX + 21, 111], fill=(255, 220, 140))
# gradini innevati
d.rectangle([DX - 16, HB, DX + 16, HB + 3], fill=(150, 150, 170)); d.rectangle([DX - 18, HB + 3, DX + 18, HB + 6], fill=(170, 170, 190))
d.rectangle([DX - 16, HB - 1, DX + 16, HB], fill=(240, 246, 255)); d.rectangle([DX - 18, HB + 2, DX + 18, HB + 3], fill=(240, 246, 255))
# cassetta delle lettere
d.rectangle([HX0 - 22, 140, HX0 - 12, 147], fill=(46, 90, 150)); d.rectangle([HX0 - 18, 147, HX0 - 16, 162], fill=(70, 50, 40))
d.rectangle([HX0 - 23, 138, HX0 - 11, 139], fill=(240, 246, 255)); d.rectangle([HX0 - 12, 141, HX0 - 11, 144], fill=(210, 60, 50))
# abete illuminato accanto alla casa
tx = HX0 - 40
for i in range(5):
    yy = 158 - i * 14; w = 22 - i * 4
    d.polygon([(tx - w, yy), (tx + w, yy), (tx, yy - 22)], fill=(28, 70, 62))
    d.line([(tx - w + 2, yy - 1), (tx + w - 2, yy - 1)], fill=(226, 236, 252))
d.polygon([(tx - 3, 70), (tx + 3, 70), (tx, 64)], fill=(255, 220, 90))
tree_lights = [(tx + rnd.randint(-16, 16), rnd.randint(86, 154)) for _ in range(26)]
near_a = np.array(near)
for (x, y) in tree_lights:
    if abs(x - tx) < (y - 64) * 0.24:
        near_a[y, x] = (*LCOL[(x + y) % 4], 255)
# luce calda sotto i lampioni e davanti alla casa
for L in lamps:
    glow(near_a, L["x"], 166, 38, 9, (255, 206, 140), 0.32)
    glow(near_a, L["x"], 64, 14, 14, (255, 220, 160), 0.35)
for w in wins:
    glow(near_a, (w[0] + w[2]) / 2, 168, 28, 7, (255, 200, 120), 0.25)
glow(near_a, DX, 168, 30, 8, (255, 200, 120), 0.3)
Image.fromarray(near_a, "RGBA").save("street_near.png")

json.dump({"view": VIEW, "h": H, "world": WORLD, "pfar": PFAR, "pmid": PMID, "feet": FEET, "start": 36,
           "door": {"x": DX, "y": 104}, "stop": DX + 4, "chimney": {"x": CHX + 6, "y": 30}, "lamps": lamps,
           "windows": wins, "moon": [mcx, mcy]}, open("street.json", "w"))

# anteprima composita (tre punti della camminata)
def compose(cam):
    img = Image.new("RGBA", (VIEW, H))
    img.alpha_composite(Image.fromarray(far).crop((int(cam * PFAR), 0, int(cam * PFAR) + VIEW, H)))
    img.alpha_composite(Image.open("street_mid.png").crop((int(cam * PMID), 0, int(cam * PMID) + VIEW, H)))
    img.alpha_composite(Image.open("street_near.png").crop((int(cam), 0, int(cam) + VIEW, H)))
    return img
prev = Image.new("RGBA", (VIEW, H * 3))
for i, cam in enumerate((0, 620, WORLD - VIEW)):
    prev.paste(compose(cam), (0, i * H))
prev.resize((VIEW * 3, H * 9), Image.NEAREST).save("/tmp/street_prev.png")
print("ok", WFAR, WMID)
