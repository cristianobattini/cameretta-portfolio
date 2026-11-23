class_name Season
extends RefCounted
## La strada cambia con la stagione vera (o con quella scelta nelle impostazioni). Mare e templi restano d'inverno.

const IDS := ["inverno", "primavera", "estate", "autunno"]
# ombra, mezzo, luce del terreno; tetti; colline
const COL := {
	"primavera": [["3a6a48", "62a05a", "a4d07a"], ["7a4a48", "a8685a", "c8887a"], ["3a5a6a", "4a7a6a"], "ffc4d8"],
	"estate": [["6a7a3c", "a0a84e", "dcd078"], ["7a4636", "a8603e", "cc8452"], ["4a5a60", "6a7a56"], "fff08a"],
	"autunno": [["6a4430", "a86a38", "dc9c4c"], ["5a3a3a", "84503e", "a86a4c"], ["4e4658", "7a5a50"], "e88a3c"],
}
static var _src := {}

static func now() -> String:
	if G.season != "auto": return G.season
	var m: int = Time.get_date_dict_from_system().month
	return "inverno" if m in [12, 1, 2] else "primavera" if m < 6 else "estate" if m < 9 else "autunno"

static func _img(k: String) -> Image:
	if not _src.has(k):
		var im: Image = (G.tex[k] as Texture2D).get_image()
		if im.is_compressed(): im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		_src[k] = im
	return _src[k]

static func _snow(c: Color) -> bool:
	return c.a > 0.5 and c.b >= c.g - 0.01 and c.g >= c.r - 0.01 and c.v > 0.62 and c.s < 0.3 and (c.v > 0.7 or c.s > 0.14) and c.b - c.r > 0.02

## Colora la neve di una zona (ramp: ombra, mezzo, luce).
static func tint(im: Image, r: Rect2i, ramp: Array, loose := false) -> void:
	var cache := {}
	for y in range(r.position.y, mini(r.end.y, im.get_height())):
		for x in range(r.position.x, mini(r.end.x, im.get_width())):
			var c := im.get_pixel(x, y)
			if c.a < 0.5: continue
			var key := c.to_rgba32()
			if not cache.has(key):
				var n: Color = c
				if _snow(c) or (c.v > 0.97 and c.s < 0.03) or (loose and c.v > 0.74 and c.s < 0.2):
					var l := clampf((c.get_luminance() - 0.6) / 0.38, 0, 1)
					n = Color(ramp[0]).lerp(Color(ramp[1]), l * 2) if l < 0.5 else Color(ramp[1]).lerp(Color(ramp[2]), l * 2 - 1)
				cache[key] = n
			if cache[key] != c: im.set_pixel(x, y, cache[key])

static func apply() -> void:
	var s := now()
	for k in ["near", "mid", "far"]:
		var im: Image = _img(k).duplicate()
		if s != "inverno":
			var q: Array = COL[s]
			if k == "near":
				# il pupazzo di neve resta: è l'unico che non si arrende
				var keep := im.duplicate()
				tint(im, Rect2i(0, 0, im.get_width(), 40), q[1])
				tint(im, Rect2i(0, 40, im.get_width(), 113), q[0])
				tint(im, Rect2i(0, 153, im.get_width(), 47), q[0], true)
				for y in range(120, 172):
					for x in range(752, 790):
						if Vector2(x - 769, y - 158).length() < 11.5 or Vector2(x - 769, y - 144).length() < 8.5 or Vector2(x - 769, y - 131).length() < 7.0: im.set_pixel(x, y, keep.get_pixel(x, y))
			elif k == "mid": tint(im, Rect2i(0, 0, im.get_width(), im.get_height()), q[1])
			else: tint(im, Rect2i(0, 60, im.get_width(), 140), [q[2][0], q[2][1], q[2][1]])
		G.tex[k] = ImageTexture.create_from_image(im)
	for q2 in [["grove_props", "grove", ["signgrove"]], ["place_props", "places", ["sign_sky", "sign_train", "sign_game", "sign_lab"]]]:
		var im2: Image = _img(q2[0]).duplicate()
		if s != "inverno":
			for n in q2[2]:
				var a: Array = G.J[q2[1]].rects[n]
				tint(im2, Rect2i(a[0], a[1], a[2], 12), COL[s][0]); tint(im2, Rect2i(a[0], int(a[1]) + 24, a[2], 3), COL[s][0]); tint(im2, Rect2i(a[0], int(a[1]) + 49, a[2], 8), COL[s][0])
		G.tex[q2[0]] = ImageTexture.create_from_image(im2)

## Sentiero e cartello del mare stanno nell'atlante del lungomare.
static func tint_sea(im: Image) -> void:
	var s := now()
	if s == "inverno": return
	for n in ["fork", "signpost"]:
		var a: Array = G.J.sea.rects[n]
		if n == "fork": tint(im, Rect2i(a[0], a[1], a[2], a[3]), COL[s][0])
		else:
			tint(im, Rect2i(a[0], a[1], a[2], 12), COL[s][0]); tint(im, Rect2i(a[0], int(a[1]) + 49, a[2], 8), COL[s][0])

static func flake(big: bool) -> Color:
	var s := now()
	if s == "inverno" or Shop.cur("theme").has("flake"): return Shop.flake(big)
	var c := Color(str(COL[s][3]))
	if s == "estate": c.a = (0.9 if big else 0.5) * (0.4 + 0.6 * absf(sin(Time.get_ticks_msec() / 420.0)))
	elif s == "autunno" and not big: c = Color("c8602c")
	c.a *= 1.0 if big else 0.75
	return c
