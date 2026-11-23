"""Tela in pixel condivisa dagli script che disegnano gli sprite."""
import math

import numpy as np
from PIL import Image, ImageDraw

OUT = (24, 18, 30)
SS = 8
SNOW, SNOW2 = (240, 245, 255), (214, 224, 246)

class Spr:
    """Tela in pixel; i poligoni sono campionati 8x e sogliati: bordi netti, niente sfumature."""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)

    def _put(self, m, c):
        self.a[m] = (*c, 255) if len(c) == 3 else c

    def _mask(self, fn):
        im = Image.new("L", (self.w * SS, self.h * SS), 0)
        fn(ImageDraw.Draw(im))
        return np.asarray(im.resize((self.w, self.h), Image.BOX)) >= 128

    def poly(self, pts, c, only=None):
        m = self._mask(lambda d: d.polygon([((x + .5) * SS, (y + .5) * SS) for x, y in pts], fill=255))
        if only is not None: m &= only
        self._put(m, c); return m

    def ell(self, x0, y0, x1, y1, c, only=None):
        m = self._mask(lambda d: d.ellipse([x0 * SS, y0 * SS, (x1 + 1) * SS - 1, (y1 + 1) * SS - 1], fill=255))
        if only is not None: m &= only
        self._put(m, c); return m

    def curve(self, pts, c, only=None, n=10):
        """poligono chiuso con curve di Catmull-Rom"""
        out = []
        k = len(pts)
        for i in range(k):
            p0, p1, p2, p3 = (np.array(pts[(i + j) % k], float) for j in (-1, 0, 1, 2))
            for s in range(n):
                t = s / n
                out.append(tuple(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3)))
        return self.poly(out, c, only)

    def r(self, x0, y0, x1, y1, c, only=None):
        x0, y0, x1, y1 = (int(round(v)) for v in (x0, y0, x1, y1))
        m = np.zeros((self.h, self.w), bool)
        m[max(0, y0):max(0, y1 + 1), max(0, x0):max(0, x1 + 1)] = True
        if only is not None: m &= only
        self._put(m, c); return m

    def p(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h: self.a[y, x] = (*c, 255) if len(c) == 3 else c

    def line(self, x0, y0, x1, y1, c, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0), 1))
        for i in range(n + 1):
            x, y = x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n
            for k in range(w): self.p(x, y + k, c)

    def limb(self, pts, w, c, only=None):
        """segmento spesso con estremità tonde"""
        def fn(d):
            q = [((x + .5) * SS, (y + .5) * SS) for x, y in pts]
            d.line(q, fill=255, width=int(w * SS), joint="curve")
            for x, y in q: d.ellipse([x - w * SS / 2, y - w * SS / 2, x + w * SS / 2, y + w * SS / 2], fill=255)
        m = self._mask(fn)
        if only is not None: m &= only
        self._put(m, c); return m

    @property
    def m(self): return self.a[:, :, 3] > 0

    def padl(self, n):
        z = np.zeros((self.h, n, 4), np.uint8); self.a = np.concatenate([z, self.a], axis=1); self.w += n
        return self

    def outline(self, c=OUT):
        m = self.m
        o = np.zeros_like(m)
        o[1:] |= m[:-1]; o[:-1] |= m[1:]; o[:, 1:] |= m[:, :-1]; o[:, :-1] |= m[:, 1:]
        self.a[o & ~m] = (*c, 255)
        return self

    def snowcap(self, thick=2, c=SNOW):
        """neve sulle superfici rivolte in alto"""
        m = self.m
        for x in range(self.w):
            ys = np.nonzero(m[:, x])[0]
            if len(ys) and ys[0] > 0:
                for k in range(thick): self.p(x, ys[0] + k - 1, c)
        return self




GL = {"C": ["0111", "1000", "1000", "1000", "0111"], "G": ["0111", "1000", "1011", "1001", "0111"], "Z": ["1111", "0001", "0110", "1000", "1111"], "B": ["1110", "1001", "1110", "1001", "1110"], "F": ["1111", "1000", "1110", "1000", "1000"], "V": ["10001", "10001", "01010", "01010", "00100"], "S": ["0111", "1000", "0110", "0001", "1110"], "T": ["11111", "00100", "00100", "00100", "00100"], "A": ["0110", "1001", "1111", "1001", "1001"], "R": ["1110", "1001", "1110", "1010", "1001"], "W": ["10001", "10001", "10101", "10101", "01010"], "H": ["1001", "1001", "1111", "1001", "1001"], "Y": ["10001", "01010", "00100", "00100", "00100"], "P": ["1110", "1001", "1110", "1000", "1000"], "O": ["0110", "1001", "1001", "1001", "0110"], "E": ["1111", "1000", "1110", "1000", "1111"], "D": ["1110", "1001", "1001", "1001", "1110"], "U": ["1001", "1001", "1001", "1001", "0110"], "N": ["1001", "1101", "1011", "1001", "1001"], "M": ["10001", "11011", "10101", "10001", "10001"], "L": ["1000", "1000", "1000", "1000", "1111"], "I": ["1", "1", "1", "1", "1"], " ": ["00", "00", "00", "00", "00"]}
def carve(s, word, cx, y, c, sh, gap=1, big=False):
    """scritta incisa, centrata in cx (big: tratti alti il doppio)"""
    k = 2 if big else 1
    w = sum(len(GL[q][0]) * k + gap * k for q in word) - gap * k; x = int(cx - w / 2)
    for q in word:
        for yy, row in enumerate(GL[q]):
            for xx, v in enumerate(row):
                if v == "1":
                    s.r(x + xx * k + 1, y + yy * k + 1, x + xx * k + k, y + yy * k + k, sh); s.r(x + xx * k, y + yy * k, x + xx * k + k - 1, y + yy * k + k - 1, c)
        x += len(GL[q][0]) * k + gap * k
