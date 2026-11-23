extends Node
## Il negozio: catalogo, portafoglio di monete (sul server), guardaroba indossato e sprite ricolorati.

signal changed                 # monete, acquisti o guardaroba

var CAT: Dictionary = {}       # store/catalog.json
var by_id: Dictionary = {}
var code := ""                 # password del portafoglio: non va mai scritta in pubblico
var deposit := ""              # codice per le donazioni: serve solo a ricevere
var balance := 0
var owned: Dictionary = {}
var earned: Dictionary = {}
var worn: Dictionary = {}      # categoria -> id
var ups: Dictionary = {}       # potenziamenti accesi
var star_names: Array = []     # le stelle accese da questo portafoglio
var online := false
var busy := false
var _src: Dictionary = {}      # immagini originali
var _queue: Array = []         # premi da mandare al server
var _rects: Dictionary = {}

const BASE := {
	"vespa": ["7ec4b0", "d6f4e4", "9edac6", "56968c", "386a6c"],
	"seat": ["864e32", "b07048", "5c3428"],
	"helmet": ["f0e8d4", "fffcf0", "c4b8a8", "c84638"],
	"hood": ["24222c", "3c3848", "18161e", "2e2c38"],
	"pants": ["9c968e", "7a7670", "b6b0a8"],
	"scarf": ["c84638", "9c322a", "eeba52"],
}
const RIDERS := ["ride0", "ride1", "stop", "sea", "horn", "kick"]
const CARGO_AT := Vector2(8, 18)         # dove poggia il carico, nello sprite della Vespa
const CORNER_AT := Vector2(30, 186)      # base dell'oggetto nell'angolo della cameretta
const POSTER_AT := Vector2(27, 92)       # centro dell'oggetto alla parete

func _ready() -> void:
	CAT = JSON.parse_string(FileAccess.get_file_as_string("res://store/catalog.json"))
	_rects = JSON.parse_string(FileAccess.get_file_as_string("res://store/shop.json")).rects
	for it in CAT.items: by_id[it.id] = it
	code = G.prefs.get_value("shop", "code", "")
	balance = G.prefs.get_value("shop", "balance", 0)
	for k in G.prefs.get_value("shop", "owned", []): owned[k] = true
	for k in G.prefs.get_value("shop", "ups", []): ups[k] = true
	worn = G.prefs.get_value("shop", "worn", {})
	_queue = G.prefs.get_value("shop", "queue", [])
	for k in worn.keys():
		if not by_id.has(worn[k]): worn.erase(k)

func save() -> void:
	G.prefs.set_value("shop", "code", code)
	G.prefs.set_value("shop", "balance", balance)
	G.prefs.set_value("shop", "owned", owned.keys())
	G.prefs.set_value("shop", "ups", ups.keys())
	G.prefs.set_value("shop", "worn", worn)
	G.save_prefs()

func enabled() -> bool:
	return str(G.S.get("store_enabled", "1")) != "0"

func items(cat: String) -> Array:
	return CAT.items.filter(func(i): return i.cat == cat)

func has(id: String) -> bool:
	return owned.has(id) or (by_id.has(id) and int(by_id[id].price) == 0 and not by_id[id].has("prize"))

## L'articolo indossato in una categoria (il primo, gratuito, se non si è scelto altro).
func cur(cat: String, look: Dictionary = {}) -> Dictionary:
	var id: String = look.get(cat, worn.get(cat, ""))
	if by_id.has(id): return by_id[id]
	for i in CAT.items:
		if i.cat == cat and int(i.price) == 0 and not i.has("prize"): return i
	return {}

func up(id: String) -> bool:
	return ups.has(id) and has(id)

func wear(id: String) -> void:
	if not has(id): return
	var it: Dictionary = by_id[id]
	if it.cat == "up":
		if ups.has(id): ups.erase(id)
		else: ups[id] = true
	else:
		worn[it.cat] = id
	save()
	apply()
	changed.emit()

# ------------------------------------------------------------------ server
func _call(path: String, body = null) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	http.accept_gzip = not G.is_web
	add_child(http)
	var err := http.request(G.base_url + path, ["Content-Type: application/json"], HTTPClient.METHOD_GET if body == null else HTTPClient.METHOD_POST, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return [0, null]
	var res = await http.request_completed
	http.queue_free()
	return [res[1], JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())]

func _take(w) -> void:
	if typeof(w) != TYPE_DICTIONARY or not w.has("balance"): return
	online = true
	code = str(w.code)
	deposit = str(w.get("deposit", ""))
	balance = int(w.balance)
	star_names = w.get("stars", [])
	owned.clear(); earned.clear()
	for k in w.owned: owned[str(k)] = true
	for k in w.earned: earned[str(k)] = true
	# se un acquisto è stato stornato, si torna al modello di serie
	for k in worn.keys():
		if not has(worn[k]):
			worn.erase(k)
	save()
	changed.emit()

## Legge il portafoglio (lo crea la prima volta). true se il server risponde.
func sync(make := true) -> bool:
	var r: Array
	if code != "":
		r = await _call("/api/wallet/" + code)
		if r[0] == 404 and typeof(r[1]) == TYPE_DICTIONARY and r[1].get("detail", "") == "Portafoglio non trovato" and make:
			code = ""                # il server non lo conosce più: se ne fa uno nuovo
	if code == "":
		if not make: return false
		r = await _call("/api/wallet", {})
	online = r[0] == 200
	if online: _take(r[1])
	else: changed.emit()
	if online: _flush()
	return online

func use_code(c: String) -> bool:
	c = c.strip_edges().to_upper()
	if c == "": return false
	var r := await _call("/api/wallet/" + c.uri_encode())
	if r[0] != 200: return false
	_take(r[1])
	apply()
	return true

## "" se va bene, altrimenti la chiave del messaggio da mostrare.
func buy(id: String) -> String:
	if busy: return "shopWait"
	if has(id): return ""
	if balance < int(by_id[id].price): return "shopPoor"
	busy = true
	var r := await _call("/api/wallet/%s/buy" % code, {"id": id})
	busy = false
	if r[0] == 200:
		_take(r[1])
		return "" if has(id) else "shopErr"
	if r[0] == 402: return "shopPoor"
	if r[0] == 403: return "shopPrize"
	online = false
	changed.emit()
	return "shopErr"

## Un premio guadagnato giocando: si manda al server senza fermare il gioco.
func earn(what: String) -> void:
	if not enabled() or earned.has(what) or _queue.has(what): return
	_queue.append(what)
	G.prefs.set_value("shop", "queue", _queue)
	if code != "": _flush()        # senza portafoglio i premi aspettano: si incassano entrando nel negozio

var _flushing := false
func _flush() -> void:
	if _flushing or _queue.is_empty(): return
	_flushing = true
	if code == "" or not online: await sync()
	while online and not _queue.is_empty():
		var w: String = _queue[0]
		var r := await _call("/api/wallet/%s/earn" % code, {"id": w})
		if r[0] == 200:
			_take(r[1])
			earned[w] = true
			if int(r[1].get("got", 0)) > 0: coins_in.emit(int(r[1].got))
		elif r[0] == 0 or r[0] >= 500 or r[0] == 429:
			break
		_queue.pop_front()
	G.prefs.set_value("shop", "queue", _queue)
	G.save_prefs()
	_flushing = false

signal coins_in(n: int)

# ------------------------------------------------------------------ sprite
func _image(k: String) -> Image:
	if not _src.has(k):
		var t: Texture2D = G.tex[k]
		var im: Image = t.get_image()
		if im.is_compressed(): im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		_src[k] = im
	return _src[k]

func _map(cat: String, look: Dictionary) -> Dictionary:
	var it := cur(cat, look)
	var m := {}
	if it.has("pal"):
		for i in BASE[cat].size(): m[Color(BASE[cat][i]).to_rgba32()] = Color(it.pal[i])
	return m

func _swap(im: Image, r: Rect2i, m: Dictionary) -> void:
	if m.is_empty(): return
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := im.get_pixel(x, y)
			if c.a > 0.5:
				var n = m.get(c.to_rgba32())
				if n != null: im.set_pixel(x, y, n)

func _rect(a: Array) -> Rect2i:
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))

## Le due immagini dell'omino e della Vespa con un certo guardaroba addosso.
func dress(look: Dictionary = {}) -> Dictionary:
	var pl: Image = _image("player").duplicate()
	var body := _map("hood", look)
	body.merge(_map("pants", look))
	body.merge(_map("scarf", look))
	_swap(pl, Rect2i(0, 0, pl.get_width(), pl.get_height()), body)
	var sea: Image = _image("sea_props").duplicate()
	var R: Dictionary = G.J.sea.rects
	for k in RIDERS:
		_swap(sea, _rect(R["rider_" + k]), body)
		_swap(sea, _rect(R["rider_back_" + k]), body)
	for k in ["kneel0", "kneel1"]:
		if R.has(k): _swap(sea, _rect(R[k]), body)
	var ve := _map("vespa", look)
	ve.merge(_map("seat", look))
	var vr := _rect(R.vespa)
	# senza il pacco regalo, al suo posto va un altro carico
	var cg := cur("cargo", look)
	if cg.has("spr"): sea.fill_rect(Rect2i(vr.position + Vector2i(2, 6), Vector2i(11, 12)), Color(0, 0, 0, 0))
	_swap(sea, vr, ve)
	var hm := _map("helmet", look)
	for k in ["helmet", "helmet_back"]: _swap(sea, _rect(R[k]), hm)
	if cur("helmet", look).get("id", "") == "ca_notte":     # stelle sul casco
		for k in ["helmet", "helmet_back"]:
			var hr := _rect(R[k])
			for q in [[6, 6], [8, 12], [13, 4], [5, 10], [15, 12], [7, 3]]:
				var px := hr.position + Vector2i(q[0], q[1])
				if sea.get_pixelv(px) == Color("222a5c"): sea.set_pixelv(px, Color("fff0b0"))
	Season.tint_sea(sea)
	return {"player": pl, "sea_props": sea}

func _shift(im: Image, inside: Callable, box: Rect2i, hsv: Array) -> void:
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c := im.get_pixel(x, y)
			if not inside.call(x, y, c): continue
			im.set_pixel(x, y, Color.from_hsv(fposmod(c.h + float(hsv[0]) / 360.0, 1.0), clampf(c.s * float(hsv[1]), 0, 1), clampf(c.v * float(hsv[2]), 0, 1)))

## La cameretta con tappeto, pareti e tende scelti (solo con la stanza di serie).
func furnish(look: Dictionary = {}) -> Image:
	var im: Image = _image("room").duplicate()
	var mask: Image = _image("mask")
	var free := func(x, y): return mask.get_pixel(x, y).r < 0.002
	var rug := cur("rug", look)
	if rug.has("hsv"):
		_shift(im, func(x, y, c):
			if pow((x - 168.0) / 44.0, 2) + pow((y - 157.5) / 15.5, 2) > 1.0: return false
			return free.call(x, y) and (c.v > 0.62 or (c.r > 0.66 and c.s < 0.75)), Rect2i(122, 141, 92, 34), rug.hsv)
	var wall := cur("wall", look)
	if wall.has("hsv"):
		_shift(im, func(x, y, c): return free.call(x, y) and _is_wall(x, y, c), Rect2i(0, 0, 320, 160), wall.hsv)
	var cu := cur("curtain", look)
	if cu.has("hsv"):
		_shift(im, func(x, y, _c): return (x >= 135 and x <= 146 and y >= 48 and y <= 122) or (x >= 188 and x <= 198 and y >= 48 and y <= 88), Rect2i(134, 47, 66, 78), cu.hsv)
	return im

func _is_wall(x: int, y: int, c: Color) -> bool:
	if c.v < 0.36 or c.s > 0.62: return false
	if y < 12 + absf(x - 160.0) * 0.0: return false
	if x < 116:                       # parete sinistra: sopra la boiserie e sotto la cornice
		return y > 3 + maxf(0, x - 50.0) * 0.56 and y < 157 - x * 0.46 and not (x > 52 and x < 116 and y > 22 and y < 54 and c.v > 0.72)
	if x >= 218:                      # parete destra, senza quadri né lampada
		if x >= 249 and x <= 263 and y >= 50 and y <= 87: return false
		if x >= 263 and x <= 291 and y >= 34 and y <= 98: return false
		return y > 3 + maxf(0, 270.0 - x) * 0.56 and y < 96 + (x - 218.0) * 0.46 and c.v < 0.97
	return y > 43 and y < 96 and (x < 135 or (x > 146 and x < 148) or (x > 198))

## Rimette in gioco gli sprite con quello che si indossa.
func apply() -> void:
	if not G.tex.has("player") or not G.J.has("sea"): return
	var d := dress()
	G.tex.player = ImageTexture.create_from_image(d.player)
	G.tex.sea_props = ImageTexture.create_from_image(d.sea_props)
	if G.default_room:
		G.tex.room = ImageTexture.create_from_image(furnish())
	theme_changed.emit()

signal theme_changed

func spr(ci: CanvasItem, n: String, at: Vector2) -> void:
	var r := _rect(_rects[n])
	ci.draw_texture_rect_region(G.tex.shop, Rect2(at, r.size), Rect2(r))

var _pet_tex: Dictionary = {}
## L'atlante con il gatto del colore scelto.
func pet_texture(look: Dictionary = {}) -> Texture2D:
	var it := cur("pet", look)
	if not _pet_tex.has(it.id):
		var im: Image = _image("shop").duplicate()
		var m := {}
		for i in 3: m[Color(["d6883a", "f0ac5c", "a05c2c"][i]).to_rgba32()] = Color(it.pal[i])
		for k in 4: _swap(im, _rect(_rects["pet%d" % k]), m)
		_pet_tex[it.id] = ImageTexture.create_from_image(im)
	return _pet_tex[it.id]

func draw_pet(ci: CanvasItem, n: String, x: float, feet: float, dir: int, a := 1.0) -> void:
	var r := _rect(_rects[n])
	ci.draw_set_transform(Vector2(x - dir * r.size.x / 2.0, feet - r.size.y), 0, Vector2(dir, 1))
	ci.draw_texture_rect_region(pet_texture(), Rect2(Vector2.ZERO, r.size), Rect2(r), Color(1, 1, 1, a))
	ci.draw_set_transform(Vector2.ZERO)

func spr_size(n: String) -> Vector2:
	return Vector2(_rects[n][2], _rects[n][3])

## Il carico sul portapacchi (angolo in alto a sinistra dello sprite della Vespa).
func draw_cargo(ci: CanvasItem, left: float, top: float, look: Dictionary = {}) -> void:
	var it := cur("cargo", look)
	if not it.has("spr"): return
	var s := spr_size(it.spr)
	spr(ci, it.spr, Vector2(left, top) + CARGO_AT - Vector2(s.x / 2, s.y - 1))

func draw_room_items(ci: CanvasItem, time: float, look: Dictionary = {}) -> void:
	var c := cur("corner", look)
	if c.has("spr"):
		var s := spr_size(c.spr)
		spr(ci, c.spr, CORNER_AT - Vector2(s.x / 2, s.y))
		if c.id == "an_lava":
			for k in 3: ci.draw_rect(Rect2(29 + k % 2, 186 - 34 - fposmod(time * (2.0 + k) + k * 9, 24), 2, 2), Color("ffce82"))
	var p := cur("poster", look)
	if p.has("spr"):
		var s2 := spr_size(p.spr)
		spr(ci, p.spr, POSTER_AT - s2 / 2)

func draw_room_glow(ci: CanvasItem, time: float, look: Dictionary = {}) -> void:
	if cur("poster", look).get("id", "") == "mu_neon":
		var f := 0.28 + (0.0 if randf() > 0.02 else -0.12)
		Layer.glow(ci, POSTER_AT, 34, Color(1, 0.35, 0.7, f))
	if cur("corner", look).get("id", "") == "an_lava":
		Layer.glow(ci, CORNER_AT - Vector2(0, 44), 30, Color(1, 0.45, 0.25, 0.22 + 0.04 * sin(time * 1.3)))

func scarf_cols() -> Array:
	var it := cur("scarf")
	var p: Array = it.get("pal", BASE.scarf)
	return [Color(p[0]), Color(p[1]), Color(p[2])]

func flake(big: bool) -> Color:
	var t := cur("theme")
	if not t.has("flake"): return Color(1, 1, 1, 0.95) if big else Color(0.86, 0.9, 1, 0.6)
	var c := Color(str(t.flake))
	if t.id == "th_estate": c.a = (0.95 if big else 0.55) * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0))
	else: c.a = 0.95 if big else 0.6
	return c

const SHADER := """shader_type canvas_item;
uniform vec3 c0; uniform vec3 c1; uniform vec3 c2; uniform vec3 c3;
uniform float amount = 0.0; uniform float sat = 1.0; uniform float steps = 0.0;
void fragment(){
	vec4 t = texture(TEXTURE, UV);
	float l = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float q = steps > 0.5 ? floor(min(l * 1.15, 0.999) * steps) / (steps - 1.0) : l;
	vec3 r = q < 0.333 ? mix(c0, c1, q * 3.0) : q < 0.666 ? mix(c1, c2, (q - 0.333) * 3.0) : mix(c2, c3, (q - 0.666) * 3.0);
	vec3 b = mix(vec3(l), t.rgb, sat);
	COLOR = vec4(mix(b, r, amount), t.a);
}"""

var _shader: Shader
## Il materiale che colora tutto il mondo secondo il tema (null con quello di serie).
func theme_material(look: Dictionary = {}) -> ShaderMaterial:
	var t := cur("theme", look)
	if not t.has("ramp"): return null
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var _mat := ShaderMaterial.new()
	_mat.shader = _shader
	for i in 4:
		var c := Color(str(t.ramp[i]))
		_mat.set_shader_parameter("c%d" % i, Vector3(c.r, c.g, c.b))
	_mat.set_shader_parameter("amount", float(t.mix))
	_mat.set_shader_parameter("sat", float(t.sat))
	_mat.set_shader_parameter("steps", 4.0 if t.id == "th_cristalli" else 0.0)
	return _mat

func accent() -> Color:
	var t := cur("theme")
	if t.has("accent"): return Color(str(t.accent))
	var ac := str(G.S.get("accent_color", ""))
	return Color.html(ac) if ac.begins_with("#") and Color.html_is_valid(ac) else Color("f2b85b")
