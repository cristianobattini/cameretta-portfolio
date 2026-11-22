"""Salotto cozy (vista frontale, 320x200): camino, TV, divano di spalle con gatto,
finestra sulla neve, lampada, orologio a pendolo e porta socchiusa con il bagliore della cameretta.
Output: living.png, living.json (zone animate e punti di interazione)
"""
import json, math, random
import numpy as np
from PIL import Image, ImageDraw

W, H = 320, 200
rnd = random.Random(5)
img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
d = ImageDraw.Draw(img)
BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
FLOOR = 142

# parete: carta da parati verde bosco con motivo
d.rectangle([0, 0, W, FLOOR], fill=(58, 84, 72))
for x in range(0, W, 12):
    for y in range(14, 104, 12):
        o = 6 if (y // 12) % 2 else 0
        d.point((x + o, y), fill=(76, 104, 88)); d.point((x + o - 1, y + 1), fill=(70, 98, 82)); d.point((x + o + 1, y + 1), fill=(70, 98, 82)); d.point((x + o, y + 2), fill=(76, 104, 88))
d.rectangle([0, 0, W, 7], fill=(40, 58, 52))
d.rectangle([0, 8, W, 10], fill=(150, 104, 66)); d.line([(0, 10), (W, 10)], fill=(112, 74, 48))
# boiserie
d.rectangle([0, 104, W, FLOOR], fill=(118, 76, 50))
d.rectangle([0, 104, W, 106], fill=(166, 116, 74)); d.line([(0, 107), (W, 107)], fill=(90, 56, 38))
for x in range(4, W, 30):
    d.rectangle([x, 112, x + 24, 136], outline=(96, 60, 40)); d.line([(x + 1, 113), (x + 23, 113)], fill=(136, 90, 58))
d.rectangle([0, FLOOR - 3, W, FLOOR - 1], fill=(84, 52, 36))
# pavimento in parquet con un po' di prospettiva
y = FLOOR; rowh = 4; k = 0
while y < H:
    for x in range(0, W):
        c = (150, 98, 62) if k % 2 == 0 else (138, 90, 56)
        if (x + k * 37) % 46 == 0:
            c = (104, 66, 42)
        img.putpixel((x, y), (*c, 255))
        for yy in range(y + 1, min(H, y + rowh)):
            img.putpixel((x, yy), (*c, 255))
    d.line([(0, y + rowh - 1), (W, y + rowh - 1)], fill=(110, 70, 46))
    y += rowh; rowh += 1; k += 1

# tappeto davanti al camino
d.ellipse([92, 146, 212, 168], fill=(150, 60, 52)); d.ellipse([98, 148, 206, 166], outline=(230, 180, 100))
d.ellipse([118, 152, 186, 162], outline=(230, 180, 100))

# ---- finestra con la neve
WX0, WY0, WX1, WY1 = 20, 30, 72, 98
d.rectangle([WX0 - 3, WY0 - 3, WX1 + 3, WY1 + 3], fill=(230, 220, 200))
d.rectangle([WX0, WY0, WX1, WY1], fill=(26, 34, 80))
for yy in range(WY0, WY1):
    t = (yy - WY0) / (WY1 - WY0)
    c = (int(22 + 30 * t), int(28 + 26 * t), int(70 + 30 * t))
    d.line([(WX0, yy), (WX1, yy)], fill=c)
for s in range(18):
    d.point((rnd.randint(WX0 + 1, WX1 - 1), rnd.randint(WY0 + 1, WY0 + 40)), fill=(255, 250, 220))
# paesaggio fuori: colline innevate e una casetta con la luce
for x in range(WX0, WX1 + 1):
    top = int(84 - 6 * math.sin((x - WX0) / 9))
    d.line([(x, top), (x, WY1)], fill=(214, 224, 246))
d.rectangle([52, 72, 62, 80], fill=(70, 50, 60)); d.polygon([(50, 72), (64, 72), (57, 66)], fill=(230, 236, 250)); d.rectangle([55, 75, 58, 78], fill=(255, 200, 110))
d.line([((WX0 + WX1) // 2, WY0), ((WX0 + WX1) // 2, WY1)], fill=(230, 220, 200)); d.line([(WX0, 64), (WX1, 64)], fill=(230, 220, 200))
d.rectangle([WX0 - 6, WY1 + 3, WX1 + 6, WY1 + 6], fill=(240, 232, 214))     # davanzale
# neve accumulata agli angoli del vetro
for x in range(WX0, WX1 + 1):
    h = 2 + int(1.5 * math.sin(x / 3))
    d.line([(x, WY1 - h), (x, WY1)], fill=(240, 246, 255))
# tende senape
d.rectangle([WX0 - 12, 22, WX1 + 12, 24], fill=(70, 50, 40))
for (x0, x1) in ((WX0 - 12, WX0 + 2), (WX1 - 2, WX1 + 12)):
    for x in range(x0, x1 + 1):
        f = 0.5 + 0.5 * math.sin(x * 1.3)
        c = (int(226 - 50 * f), int(170 - 46 * f), int(64 - 20 * f))
        d.line([(x, 25), (x, 104)], fill=c)
# pianta in vaso sotto la finestra
d.polygon([(30, FLOOR - 2), (46, FLOOR - 2), (44, FLOOR + 8), (32, FLOOR + 8)], fill=(186, 98, 66))
for k in range(9):
    a = -math.pi / 2 + (k - 4) * 0.33
    for r in range(4, 22):
        x = int(38 + r * math.cos(a) * 0.8); yy = int(FLOOR - 3 + r * math.sin(a))
        d.point((x, yy), fill=(64, 140, 76) if r % 5 else (100, 180, 96))
        d.point((x + 1, yy), fill=(48, 112, 62))

# ---- lampada a stelo
LX = 88
d.rectangle([LX - 5, FLOOR + 4, LX + 5, FLOOR + 6], fill=(50, 40, 40))
d.line([(LX, 54), (LX, FLOOR + 4)], fill=(60, 48, 44))
d.polygon([(LX - 10, 56), (LX + 10, 56), (LX + 6, 40), (LX - 6, 40)], fill=(240, 200, 120))
d.line([(LX - 10, 56), (LX + 10, 56)], fill=(255, 236, 180))

# ---- camino
FX0, FX1 = 108, 190
d.rectangle([FX0, 66, FX1, FLOOR], fill=(150, 82, 64))
for yy in range(68, FLOOR, 5):
    off = 0 if (yy // 5) % 2 else 6
    d.line([(FX0, yy), (FX1, yy)], fill=(116, 60, 48))
    for x in range(FX0 + off, FX1, 12):
        d.line([(x, yy), (x, yy + 4)], fill=(116, 60, 48))
d.rectangle([FX0 - 6, 60, FX1 + 6, 66], fill=(110, 70, 46)); d.line([(FX0 - 6, 60), (FX1 + 6, 60)], fill=(160, 112, 72))
FB = [126, 94, 172, FLOOR]
d.rectangle(FB, fill=(30, 20, 24))
d.pieslice([FB[0], FB[1] - 8, FB[2], FB[1] + 10], 180, 360, fill=(30, 20, 24))
d.rectangle([FX0 + 2, FLOOR - 1, FX1 - 2, FLOOR + 5], fill=(120, 116, 120)); d.line([(FX0 + 2, FLOOR - 1), (FX1 - 2, FLOOR - 1)], fill=(160, 156, 160))
# ciocchi
d.rectangle([134, FLOOR - 8, 164, FLOOR - 4], fill=(96, 62, 40)); d.rectangle([138, FLOOR - 12, 160, FLOOR - 8], fill=(116, 76, 48))
d.ellipse([132, FLOOR - 8, 137, FLOOR - 4], fill=(200, 160, 110))
# ghirlanda con luci sulla mensola
for x in range(FX0 - 6, FX1 + 7):
    yy = 67 + int(3 * abs(math.sin((x - FX0) / 10)))
    d.point((x, yy), fill=(46, 104, 64)); d.point((x, yy + 1), fill=(36, 84, 54))
# calze
for i, (sx, col) in enumerate(((118, (196, 56, 50)), (144, (50, 120, 80)), (170, (196, 56, 50)))):
    d.rectangle([sx, 68, sx + 7, 82], fill=col); d.rectangle([sx, 80, sx + 12, 86], fill=col)
    d.rectangle([sx - 1, 66, sx + 8, 70], fill=(244, 244, 240))
# candele e foto sulla mensola
for cx in (114, 184):
    d.rectangle([cx, 50, cx + 3, 59], fill=(240, 232, 210))
d.rectangle([150, 48, 162, 59], fill=(70, 50, 40)); d.rectangle([152, 50, 160, 57], fill=(160, 190, 220))
# quadro sopra il camino: mare di notte
d.rectangle([124, 16, 174, 44], fill=(150, 104, 66))
d.rectangle([127, 19, 171, 41], fill=(28, 36, 84))
d.rectangle([127, 32, 171, 41], fill=(22, 52, 110))
d.ellipse([156, 22, 163, 29], fill=(250, 236, 190))
for yy in range(33, 41, 2):
    d.line([(158 - (yy - 32) // 2, yy), (161 + (yy - 32) // 2, yy)], fill=(230, 210, 160))

# ---- mobile TV
TX0, TX1 = 202, 258
d.rectangle([TX0, 118, TX1, FLOOR - 1], fill=(128, 84, 54))
d.rectangle([TX0 + 3, 121, (TX0 + TX1) // 2 - 1, FLOOR - 4], outline=(98, 62, 40)); d.rectangle([(TX0 + TX1) // 2 + 1, 121, TX1 - 3, FLOOR - 4], outline=(98, 62, 40))
d.point(((TX0 + TX1) // 2 - 3, 130), fill=(220, 190, 120)); d.point(((TX0 + TX1) // 2 + 3, 130), fill=(220, 190, 120))
d.line([(TX0, 118), (TX1, 118)], fill=(160, 112, 72))
TV = [206, 84, 254, 113]
d.rectangle([TV[0] - 2, TV[1] - 2, TV[2] + 2, TV[3] + 2], fill=(20, 20, 26))
d.rectangle(TV, fill=(40, 50, 80))
d.rectangle([228, 115, 232, 117], fill=(20, 20, 26))
# pianta piccola e console sul mobile
d.rectangle([TX1 - 9, 112, TX1 - 3, 117], fill=(186, 98, 66))
for k in range(6):
    d.point((TX1 - 6 + rnd.randint(-3, 3), 108 + rnd.randint(0, 4)), fill=(70, 150, 80))

# ---- orologio a pendolo
CX = 236
d.rectangle([CX - 7, 22, CX + 7, 58], fill=(110, 70, 46)); d.rectangle([CX - 6, 23, CX + 6, 57], outline=(150, 104, 66))
d.ellipse([CX - 5, 25, CX + 5, 35], fill=(240, 232, 210)); d.line([(CX, 30), (CX, 27)], fill=(40, 30, 30)); d.line([(CX, 30), (CX + 3, 30)], fill=(40, 30, 30))
d.rectangle([CX - 4, 38, CX + 4, 55], fill=(60, 40, 30))

# ---- porta socchiusa con il bagliore della cameretta
DX0, DX1, DY0 = 270, 306, 50
d.rectangle([DX0 - 4, DY0 - 4, DX1 + 4, FLOOR], fill=(150, 104, 66))
d.rectangle([DX0, DY0, DX1, FLOOR], fill=(255, 214, 140))           # stanza illuminata oltre la porta
for yy in range(DY0, FLOOR):
    t = (yy - DY0) / (FLOOR - DY0)
    d.line([(DX0, yy), (DX0 + 10, yy)], fill=(255, int(226 - 20 * t), int(160 - 40 * t)))
# anta aperta verso di noi (in prospettiva)
d.polygon([(DX0 + 12, DY0), (DX1, DY0 - 3), (DX1, FLOOR + 3), (DX0 + 12, FLOOR)], fill=(132, 84, 56))
d.polygon([(DX0 + 15, DY0 + 6), (DX1 - 3, DY0 + 4), (DX1 - 3, 90), (DX0 + 15, 90)], outline=(104, 64, 42))
d.polygon([(DX0 + 15, 96), (DX1 - 3, 96), (DX1 - 3, FLOOR - 4), (DX0 + 15, FLOOR - 6)], outline=(104, 64, 42))
d.rectangle([DX0 + 14, 98, DX0 + 16, 100], fill=(240, 200, 100))
# cartellino appeso alla maniglia
d.rectangle([DX0 + 11, 101, DX0 + 19, 107], fill=(240, 232, 210)); d.line([(DX0 + 15, 99), (DX0 + 15, 101)], fill=(120, 90, 60))
d.point((DX0 + 14, 104), fill=(196, 70, 56)); d.point((DX0 + 16, 104), fill=(196, 70, 56)); d.point((DX0 + 15, 105), fill=(196, 70, 56))

# ---- lucine lungo il soffitto
fairy = []
for x in range(4, W - 4, 7):
    yy = 13 + int(5 * abs(math.sin(x / 26 * math.pi / 2)))
    d.point((x, yy - 1), fill=(40, 34, 30))
    fairy.append([x, yy])

# ---- divano di spalle in primo piano, con plaid e gatto
SX0, SX1, SY0 = 102, 236, 150
d.rounded_rectangle([SX0, SY0 + 4, SX1, 190], radius=6, fill=(170, 88, 62))
d.rounded_rectangle([SX0 - 8, SY0 + 12, SX0 + 8, 192], radius=4, fill=(150, 76, 54))     # bracciolo
d.rounded_rectangle([SX1 - 8, SY0 + 12, SX1 + 8, 192], radius=4, fill=(150, 76, 54))
d.line([(SX0 + 6, SY0 + 5), (SX1 - 6, SY0 + 5)], fill=(196, 112, 80))
d.line([((SX0 + SX1) // 2, SY0 + 6), ((SX0 + SX1) // 2, 188)], fill=(140, 70, 50))
for x in range(SX0 + 4, SX1 - 4, 9):
    for yy in range(SY0 + 12, 188, 9):
        d.point((x + (yy // 9) % 2 * 4, yy), fill=(150, 76, 54))
# cuscini che spuntano
d.rounded_rectangle([SX0 + 10, SY0 - 6, SX0 + 34, SY0 + 8], radius=4, fill=(236, 186, 82))
d.rounded_rectangle([SX1 - 40, SY0 - 4, SX1 - 18, SY0 + 8], radius=4, fill=(236, 226, 206))
# plaid a righe appoggiato
d.polygon([(SX1 - 52, SY0 + 2), (SX1 - 20, SY0 + 2), (SX1 - 16, 186), (SX1 - 44, 186)], fill=(236, 224, 196))
for yy in range(SY0 + 8, 186, 7):
    d.line([(SX1 - 50 + (yy - SY0) * 0.2, yy), (SX1 - 18, yy)], fill=(140, 160, 110))
for x in range(SX1 - 44, SX1 - 15, 3):
    d.line([(x, 186), (x, 189)], fill=(226, 212, 184))
# gatto arancione acciambellato sullo schienale
CATX = SX0 + 52
d.ellipse([CATX, SY0 - 8, CATX + 22, SY0 + 6], fill=(230, 150, 70))
d.ellipse([CATX + 16, SY0 - 10, CATX + 28, SY0 + 1], fill=(230, 150, 70))
d.polygon([(CATX + 18, SY0 - 9), (CATX + 20, SY0 - 14), (CATX + 22, SY0 - 9)], fill=(230, 150, 70))
d.polygon([(CATX + 23, SY0 - 9), (CATX + 26, SY0 - 13), (CATX + 27, SY0 - 8)], fill=(230, 150, 70))
for x in range(CATX + 3, CATX + 16, 4):
    d.line([(x, SY0 - 7), (x + 1, SY0 - 2)], fill=(200, 118, 50))
d.line([(CATX + 20, SY0 - 5), (CATX + 22, SY0 - 5)], fill=(90, 50, 30)); d.line([(CATX + 24, SY0 - 5), (CATX + 26, SY0 - 5)], fill=(90, 50, 30))
d.ellipse([CATX - 6, SY0 - 1, CATX + 6, SY0 + 5], fill=(230, 150, 70))  # coda
# tavolino con la tazza
d.rectangle([62, 164, 90, 167], fill=(120, 78, 50)); d.rectangle([64, 167, 66, 192], fill=(96, 62, 40)); d.rectangle([86, 167, 88, 192], fill=(96, 62, 40))
d.rectangle([72, 157, 79, 163], fill=(240, 236, 228)); d.point((80, 159), fill=(240, 236, 228)); d.point((80, 161), fill=(240, 236, 228)); d.point((81, 160), fill=(240, 236, 228))
d.line([(73, 157), (78, 157)], fill=(150, 90, 50))
d.rectangle([82, 160, 88, 163], fill=(60, 110, 160))   # un libro

# ---- luce calda: lampada, camino, porta
a = np.array(img).astype(float)
def glow(cx, cy, rx, ry, c, amax):
    for yy in range(max(0, int(cy - ry)), min(H, int(cy + ry) + 1)):
        for xx in range(max(0, int(cx - rx)), min(W, int(cx + rx) + 1)):
            dd = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
            if dd < 1:
                t = amax * (1 - dd) ** 1.6
                a[yy, xx, :3] = a[yy, xx, :3] * (1 - t) + np.array(c) * t
glow(LX, 60, 46, 40, (255, 210, 140), 0.32)
glow(149, 120, 70, 50, (255, 170, 90), 0.28)
glow(292, 150, 40, 14, (255, 214, 140), 0.45)
glow(DX0 + 6, 96, 22, 50, (255, 214, 140), 0.25)
glow(230, 100, 34, 26, (140, 180, 240), 0.12)
# vignetta morbida
for yy in range(H):
    for xx in range(W):
        v = (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 1.6)) ** 2) * 0.22
        a[yy, xx, :3] *= max(0.7, 1 - v)
img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")
img.save("living.png")
img.resize((W * 3, H * 3), Image.NEAREST).save("/tmp/living_prev.png")

json.dump({"w": W, "h": H, "feet": 194, "start": 22, "stop": 296,
           "fire": [130, 104, 170, FLOOR - 6], "tv": TV, "window": [WX0, WY0, WX1, WY1], "door": [DX0, DY0, DX1, FLOOR],
           "lamp": [LX, 50], "fairy": fairy, "mug": [75, 155], "clock": [CX, 38, 55],
           "spots": {"tv": 230, "fire": 149, "door": 286}}, open("living.json", "w"))
print("ok")
