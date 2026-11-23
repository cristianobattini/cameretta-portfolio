"""Cielo dell'osservatorio: stelle fino alla magnitudine 4,8, linee e nomi delle costellazioni.
Dati: d3-celestial di Olaf Frohn (licenza BSD 3), https://github.com/ofrohn/d3-celestial
Uso: python tools/build_sky.py <cartella con stars.6.json starnames.json constellations.lines.json constellations.json>
"""
import json, os, sys
D = sys.argv[1]; OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "cameretta-godot", "store", "sky.json")
L = lambda f: json.load(open(os.path.join(D, f), encoding="utf-8"))
names = L("starnames.json"); stars = []
for f in L("stars.6.json")["features"]:
    m = f["properties"]["mag"]
    if m > 4.8: continue
    ra, dec = f["geometry"]["coordinates"]
    if dec < -48: continue                                  # da Rosignano non sorgono mai
    try: bv = float(f["properties"]["bv"])
    except (ValueError, TypeError): bv = .6
    n = names.get(str(f["id"]), {}).get("name", "") if m < 3.3 else ""
    stars.append([round(ra % 360, 3), round(dec, 3), round(m, 2), round(bv, 2), n])
stars.sort(key=lambda s: s[2])
lines = [[[round(x % 360, 2), round(y, 2)] for x, y in seg] for f in L("constellations.lines.json")["features"] for seg in f["geometry"]["coordinates"]]
cons = [[f["properties"]["it"], f["properties"]["la"], round(f["properties"]["display"][0] % 360, 1), round(f["properties"]["display"][1], 1), int(f["properties"]["rank"])] for f in L("constellations.json")["features"] if f["properties"]["display"][1] > -50]
json.dump({"stars": stars, "lines": lines, "cons": cons}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
print(len(stars), "stelle", len(lines), "linee", len(cons), "costellazioni", os.path.getsize(OUT), "byte", [s[4] for s in stars[:8]])
