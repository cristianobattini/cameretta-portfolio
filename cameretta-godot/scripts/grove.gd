extends Node2D
## I templi: tre luoghi nel bosco, omaggi a tre saghe, dove ci si può sedere a pregare.

signal prayed(id: String)

const PRAY := 4.0
const IDS := ["stelle", "magia", "dune"]
var P: Player
var cam := 0.0
var last_cam := 0.0
var time := 0.0
var input_dir := 0
var run := false
var locked := false
var prompt: Dictionary = {}
var state := "walk"            # walk | go | pray
var st := 0.0
var who := ""
var line := ""                 # la risposta, scritta lettera per lettera
var shown := 0
var _tt := 0.0
var _hold := 0.0
var flakes: Array = []
var sparks: Array = []
var glow := {"stelle": 0.0, "magia": 0.0, "dune": 0.0}
var _last := {"stelle": -1, "magia": -1, "dune": -1}
var _read := ""                # la targa già letta
var _J: Dictionary = {}
var _dt := 0.0
var back_l: Layer
var glow_l: Layer
var front_l: Layer
var glow2_l: Layer

func _ready() -> void:
	P = Player.new()
	flakes = load("res://scripts/street.gd").make_flakes(70)
	_J = JSON.parse_string(FileAccess.get_file_as_string("res://store/grove.json"))
	back_l = Layer.make(self, _draw_back)
	glow_l = Layer.make(self, _draw_glow, true)
	front_l = Layer.make(self, _draw_front)
	glow2_l = Layer.make(self, _draw_glow2, true)

func enter() -> void:
	P = Player.new()
	P.x = 296
	_read = ""
	cam = clampf(P.x - 160, 0, float(_J.world) - 320)
	last_cam = roundf(cam)
	state = "walk"; st = 0.0; line = ""; shown = 0
	sparks.clear()

func at(id: String) -> float:
	return float(_J[id])

func update(dt: float) -> void:
	time += dt; st += dt; _dt = dt
	prompt = {}
	match state:
		"walk":
			P.update(dt, input_dir, run, 24, float(_J.world) - 24, Sfx.step_snow, locked)
			for id in IDS:
				if absf(P.x - at(id)) < 74:
					prompt = {"x": at(id) - cam, "y": 108.0, "label": G.t("pray")[id], "action": kneel.bind(id)}
					if _read != id:           # avvicinandosi si legge la targa
						_read = id
						_say(G.t("temples")[id])
		"go":
			var tx := at(who) - 56
			if absf(P.x - tx) > 2.2 and st < 14:
				P.target = tx
				P.update(dt, 0, false, 24, float(_J.world) - 24, Sfx.step_snow)
			else:
				P.target = -1.0
				P.dir = 1
				state = "pray"; st = 0.0
				Sfx.step_snow()
				Sfx.play("pray_" + who, 0.8)
		"pray":
			glow[who] = minf(1.0, glow[who] + dt * 0.8)
			if randf() < dt * 26: _spark(who)
			if st > PRAY:
				state = "walk"
				G.prayers[who] = int(G.prayers.get(who, 0)) + 1
				G.save_prefs()
				_answer(who)
				Shop.earn("pray:" + who)
				prayed.emit(who)
			elif st > 1.0 and input_dir != 0 and not locked:     # ci si può alzare prima
				state = "walk"
	for id in glow: if not (state == "pray" and who == id): glow[id] = maxf(0.0, glow[id] - dt * 0.12)
	cam = lerpf(cam, clampf(P.x - 160 + P.dir * 12, 0, float(_J.world) - 320), minf(1, dt * 3.5))
	for s in sparks:
		s.x += s.vx * dt + sin(time * 3 + s.ph) * 6 * dt; s.y += s.vy * dt; s.a -= dt * 0.42
	sparks = sparks.filter(func(s): return s.a > 0)
	if line != "":
		if shown < line.length():
			_tt -= dt
			while _tt <= 0 and shown < line.length():
				shown += 1
				var ch := line.substr(shown - 1, 1)
				if shown % 2 == 0: Sfx.key(ch)
				_tt += 0.24 if ".!?".contains(ch) else 0.12 if ",;:".contains(ch) else 0.035
		else:
			_hold += dt
			if _hold > 3.0 + line.length() * 0.03: line = ""
	for l in [back_l, glow_l, front_l, glow2_l]: l.queue_redraw()

func kneel(id: String) -> void:
	if state != "walk": return
	who = id
	line = ""
	state = "go"; st = 0.0

func tap(wx: float) -> void:
	if state != "walk": return
	for id in IDS:
		if absf(wx + cam - at(id)) < 66:
			kneel(id)
			return
	P.target = clampf(wx + cam, 24, float(_J.world) - 24)

func _answer(id: String) -> void:
	var a: Array = G.t("prayers")[id]
	var i := randi() % a.size()
	if i == _last[id]: i = (i + 1) % a.size()
	_last[id] = i
	_say(a[i])

func _say(s: String) -> void:
	line = s; shown = 0; _tt = 0.3; _hold = 0.0

func text() -> String:
	return line.substr(0, shown)

func done() -> bool:
	return shown >= line.length()

func _spark(id: String) -> void:
	var c: Color
	if id == "stelle": c = [Color("8ad8ff"), Color("ffffff"), Color("ffe0a0")][randi() % 3]
	elif id == "magia": c = [Color("ffd878"), Color("fff4c8"), Color("c8a0ff")][randi() % 3]
	else: c = [Color("ffb060"), Color("ffd8a0"), Color("6ab8ff")][randi() % 3]
	sparks.append({"x": at(id) + randf_range(-62, 62), "y": randf_range(110, 174), "vx": randf_range(-4, 4), "vy": -randf_range(12, 34), "a": randf_range(0.7, 1.2), "c": c, "ph": randf() * 6})

# ------------------------------------------------------------------ disegno
func _spr(ci: CanvasItem, n: String, left: float, top: float, mod := Color.WHITE) -> void:
	var r: Array = _J.rects[n]
	ci.draw_texture_rect_region(G.tex.grove_props, Rect2(roundf(left), roundf(top), r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), mod)

func _draw_back(ci: CanvasItem) -> void:
	var c := roundf(cam)
	ci.draw_texture(G.tex.grove_far, Vector2(-roundf(c * 0.36), 0))
	ci.draw_texture(G.tex.grove_near, Vector2(-c, 0))
	var sx := at("stelle") - c
	var mx := at("magia") - c
	for id in IDS: _spr(ci, "shrine_" + id, at(id) - c - 70, 171 - float(_J.rects["shrine_" + id][3]))
	# la lama di luce, piantata nell'altare
	var g: float = glow.stelle
	var n := int(G.prayers.get("stelle", 0))
	var bc: Color = [Color("6ac8ff"), Color("78f08c"), Color("c08cff")][n % 3]
	var h := 8.0 + 30.0 * smoothstep(0.0, 0.6, g) + randf() * 0.8
	var by := 171 - 124 + 85.0
	ci.draw_rect(Rect2(roundf(sx) - 1, by - h, 3, h), Color(bc, 0.9))
	ci.draw_rect(Rect2(roundf(sx), by - h + 1, 1, h - 1), Color.WHITE)
	# le offerte di chi ha pregato: cristalli, candele, scodelle d'acqua
	for id in IDS:
		var k := mini(10, int(G.prayers.get(id, 0)))
		for i in k:
			var off := (74 + (i / 2) * 9) * (1 if i % 2 else -1)
			var ox := at(id) - c + off
			var oy := 160 + (i / 2) % 2 * 3
			if id == "stelle": _spr(ci, "crystal%d" % (i % 3), ox - 3, oy + 2)
			elif id == "dune": _spr(ci, "bowl", ox - 5, oy + 8)
			else:
				_spr(ci, "candle", ox - 3, oy)
				_flame(ci, Vector2(ox - 0.5, oy + 3), i)
	# candele sospese
	for i in 7:
		var x := mx - 84 + i * 28.0
		var y := 58 + 16 * sin(i * 1.9) + 2.5 * sin(time * 1.2 + i * 1.3) - (46 if i == 3 else 0) - 10 * smoothstep(0, 1, glow.magia)
		_spr(ci, "candle", x - 3, y, Color(1, 1, 1, 0.95))
		_flame(ci, Vector2(x - 0.5, y + 3), i + 20)

func _flame(ci: CanvasItem, p: Vector2, i: int) -> void:
	var w := roundf(sin(time * 7 + i * 2.1) * 0.6)
	ci.draw_rect(Rect2(roundf(p.x) - 1, roundf(p.y) - 3, 2, 3), Color("ffb040"))
	ci.draw_rect(Rect2(roundf(p.x) - 1 + w, roundf(p.y) - 5, 1, 3), Color("ffe080"))

func _draw_glow(ci: CanvasItem) -> void:
	var c := roundf(cam)
	var sx := at("stelle") - c
	var mx := at("magia") - c
	var g: float = glow.stelle
	var m: float = glow.magia
	var bc: Color = [Color("6ac8ff"), Color("78f08c"), Color("c08cff")][int(G.prayers.get("stelle", 0)) % 3]
	Layer.glow(ci, Vector2(sx, 122), 26 + 44 * g, Color(bc, 0.22 + 0.4 * g + 0.03 * sin(time * 30)))
	Layer.glow(ci, Vector2(sx - 8, 108), 30, Color(1, 0.75, 0.4, 0.14 + 0.2 * g))
	Layer.glow(ci, Vector2(mx, 100), 44 + 20 * m, Color(0.75, 0.6, 1, 0.10 + 0.3 * m))
	for i in 7:
		var x := mx - 84 + i * 28.0
		Layer.glow(ci, Vector2(x, 60 + 16 * sin(i * 1.9) - (46 if i == 3 else 0)), 15, Color(1, 0.75, 0.35, 0.22 + 0.2 * m + 0.03 * sin(time * 6 + i)))
	for id in IDS:
		var k := mini(10, int(G.prayers.get(id, 0)))
		if k > 0:
			for sgn in [-1, 1]: Layer.glow(ci, Vector2(at(id) - c + sgn * 90, 166), 22, Color({"stelle": Color(0.5, 0.8, 1), "magia": Color(1, 0.7, 0.35), "dune": Color(0.4, 0.65, 1)}[id], 0.05 + 0.02 * k))
	# il calderone che bolle, e il respiro azzurro dentro la rupe
	Layer.glow(ci, Vector2(mx - 11, 124), 16 + 12 * m, Color(0.45, 1, 0.5, 0.25 + 0.35 * m + 0.04 * sin(time * 3)))
	var dx := at("dune") - c
	var dg: float = glow.dune
	Layer.glow(ci, Vector2(dx, 128), 30 + 40 * dg, Color(0.35, 0.6, 1, 0.22 + 0.45 * dg + 0.03 * sin(time * 1.7)))
	Layer.glow(ci, Vector2(dx, 142), 40, Color(1, 0.65, 0.3, 0.12 + 0.2 * dg))

func _draw_front(ci: CanvasItem) -> void:
	var c := roundf(cam)
	if state == "pray":
		var r: Array = G.J.sea.rects["kneel%d" % (int(time * 0.9) % 2)]
		for k in range(-15, 16): ci.draw_rect(Rect2(roundf(P.x - c) + k, 177, 1, 2), Color(0.08, 0.09, 0.24, 0.3))
		ci.draw_texture_rect_region(G.tex.sea_props, Rect2(roundf(P.x - c) - 18, 178 - 50, r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]))
	else:
		P.draw(ci, P.x - c, float(_J.feet))
	var dx := c - last_cam
	for f in flakes:
		f.y += f.vy * _dt; f.x += (sin(f.y / 14 + f.ph) * 6 - 4) * _dt * f.z - dx * f.z
		if f.y > 200:
			f.y = -4; f.x = randf_range(0, 320)
		f.x = fposmod(f.x + 4, 328) - 4
		var big: bool = f.z > 1
		ci.draw_rect(Rect2(roundf(f.x), roundf(f.y), 2 if big else 1, 2 if big else 1), Shop.flake(big))
	last_cam = c

func _draw_glow2(ci: CanvasItem) -> void:
	var c := roundf(cam)
	for s in sparks:
		ci.draw_rect(Rect2(roundf(s.x - c), roundf(s.y), 1, 1), Color(s.c, clampf(s.a, 0, 1)))
		if s.ph > 4: Layer.glow(ci, Vector2(s.x - c, s.y), 4, Color(s.c, clampf(s.a, 0, 1) * 0.5))
