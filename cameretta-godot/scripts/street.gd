extends Node2D
## La strada innevata: parallasse, neve, lampioni, fumo dal comignolo, bolle che si scrivono.

signal go_inside
signal go(id: String)
signal coffee

const CART_X := 985.0           # il chiosco del caffè
const MAX_BUBBLES := 12        # quante bolle stanno in strada senza accavallarsi
const GROVE_X := 640.0         # il sentiero che porta ai templi
const FORK_X := 866.0          # il sentiero che scende al mare
## Le deviazioni lungo la strada: [x, dove porta, cartello, atlante, colore]
const PATHS := [
	[200.0, "lab", "sign_lab", "place_props", "6ee6be"],
	[400.0, "train", "sign_train", "place_props", "ff9a70"],
	[GROVE_X, "grove", "signgrove", "grove_props", "c8a0ff"],
	[FORK_X, "sea", "signpost", "sea_props", "ffcc80"],
	[1100.0, "sky", "sign_sky", "place_props", "8ab4ff"],
	[1300.0, "arcade", "sign_game", "place_props", "ff80c8"],
]

var P: Player
var cam := 0.0
var last_cam := 0.0
var flakes: Array = []
var smoke: Array = []
var puffs: Array = []
var breath := 2.0
var time := 0.0
var bub: Array = []           # {x, top, data, state, shown, t}
var input_dir := 0
var run := false
var locked := false
var prompt: Dictionary = {}
var down_x := FORK_X
var _to := "sea"
var _left := false             # la scena sta già cambiando
var down := 0.0                # >0: sta scendendo il sentiero
var back_l: Layer
var glow_l: Layer
var front_l: Layer

static func make_flakes(n: int) -> Array:
	var f := []
	for i in n:
		var z := 0.5 if randf() < 0.6 else 1.1
		f.append({"x": randf_range(0, 320), "y": randf_range(-200, 200), "z": z, "vy": z * randf_range(9, 16), "ph": randf_range(0, 6)})
	return f

func _ready() -> void:
	P = Player.new()
	flakes = make_flakes(90)
	back_l = Layer.make(self, _draw_back)
	glow_l = Layer.make(self, _draw_glow, true)
	front_l = Layer.make(self, _draw_front)

func enter() -> void:
	var s: Dictionary = G.J.street
	P = Player.new()
	P.x = s.start
	cam = 0
	last_cam = 0
	smoke.clear()
	puffs.clear()
	down = 0.0
	build_bubbles()

func build_bubbles() -> void:
	bub.clear()
	var s: Dictionary = G.J.street
	var list := _with_quotes(G.bubbles)
	var n := list.size()
	if n == 0: return
	var x0 := 210.0
	var x1 := float(s.stop) - 200.0
	var step := (x1 - x0) / (n - 1) if n > 1 else 0.0
	for i in n:
		bub.append({"x": x0 + i * step, "top": 196.0 if i % 2 else 128.0, "data": list[i], "state": "idle", "shown": 0, "t": 0.26})

## Tra una bolla e l'altra infila citazioni di fisici, sempre diverse, finché c'è posto in strada.
func _with_quotes(src: Array) -> Array:
	var gaps := src.size() - 1
	var add := clampi(MAX_BUBBLES - src.size(), 0, maxi(gaps, 0))
	var texts: Array = src.map(func(b): return str(b.get("text", "")))
	var out: Array = []
	var put := 0
	for i in src.size():
		out.append(src[i])
		if i < gaps and put < add and (i + 1) * add / gaps > put:
			var q := Quotes.next()
			while texts.has(q.text) or q.text.length() > 105 or q.text_en.length() > 105: q = Quotes.next()   # corte: non devono coprire l'omino
			out.append({"kind": "quote", "text": q.text, "text_en": q.text_en, "author": q.author, "author_en": q.get("author_en", q.author)})
			put += 1
	return out

func update(dt: float) -> void:
	time += dt
	var s: Dictionary = G.J.street
	if down > 0:                   # sta scendendo verso il mare
		# prima raggiunge il sentiero di corsa, girandosi dalla parte giusta; poi scende
		var off := down_x - P.x
		if absf(off) > 1.0:
			P.dir = 1 if off > 0 else -1
			P.x = move_toward(P.x, down_x, 115 * dt)
		else:
			down += dt
			if not _left:
				_left = true
				go.emit(_to)
		P.moving = true
		P.animate(dt, absf(off) > 1.0, Sfx.step_snow)
	else:
		P.update(dt, input_dir, run, 14, s.stop, Sfx.step_snow, locked)
	Sfx.near_sea(clampf(1.0 - absf(P.x - FORK_X) / 150.0, 0, 1))
	cam = clampf(P.x - 120, 0, float(s.world) - 320)
	for B in bub:
		if B.state == "idle" and P.x > B.x - 150:
			B.state = "typing"
		if B.state == "typing":
			B.t -= dt
			var full := G.L(B.data, "text")
			while B.t <= 0 and B.state == "typing":
				B.shown += 1
				Sfx.key(full.substr(B.shown - 1, 1))
				if B.shown >= full.length():
					B.state = "done"
					break
				var ch := full.substr(B.shown - 1, 1)
				B.t += 0.22 if ".!?".contains(ch) else 0.12 if ",;:".contains(ch) else randf_range(0.024, 0.046)
	if absf(P.x - float(s.door.x)) < 26:
		prompt = {"x": float(s.door.x) - cam, "y": float(s.door.y) - 26, "label": G.t("enterHouse"), "action": func(): go_inside.emit()}
	else:
		prompt = {}
		for q in PATHS:
			if absf(P.x - q[0]) < 34 and down <= 0:
				var lb: String = G.t("toSea") if q[1] == "sea" else G.t("toGrove") if q[1] == "grove" else G.t("go")[q[1]]
				prompt = {"x": q[0] - cam, "y": 108.0, "label": lb, "action": take.bind(q[1]), "down": true}
		if prompt.is_empty() and Shop.donate_url() != "" and absf(P.x - CART_X) < 40:
			prompt = {"x": CART_X - cam, "y": 104.0, "label": G.t("coffeeBtn"), "action": coffee.emit}
	# fumo dal comignolo
	if randf() < dt * 6:
		smoke.append({"x": float(s.chimney.x) + randf_range(-2, 2), "y": float(s.chimney.y), "r": 1.5, "a": 0.5, "vx": randf_range(-7, -3), "vy": randf_range(-9, -6)})
	for p in smoke:
		p.x += p.vx * dt; p.y += p.vy * dt; p.r += dt * 2.2; p.a -= dt * 0.12
	smoke = smoke.filter(func(p): return p.a > 0)
	# respiro nel freddo
	breath -= dt
	if breath <= 0:
		breath = randf_range(2.2, 3.4)
		for k in 4:
			var ps: float = G.J.player.get("scale", 1.0)
			puffs.append({"x": P.x + P.dir * 7 * ps, "y": float(s.feet) - 31 * ps, "vx": P.dir * randf_range(5, 10), "vy": randf_range(-5, -2), "a": 0.55, "d": k * 0.06})
	for p in puffs:
		if p.d > 0:
			p.d -= dt
			continue
		p.x += p.vx * dt; p.y += p.vy * dt; p.a -= dt * 0.5
	puffs = puffs.filter(func(p): return p.a > 0)
	_dt = dt
	back_l.queue_redraw(); glow_l.queue_redraw(); front_l.queue_redraw()

var _dt := 0.0

## Rientra in strada in un punto preciso (tornando dal mare): le bolle già passate restano lette.
func enter_at(px: float) -> void:
	enter()
	P.x = px
	cam = clampf(P.x - 120, 0, float(G.J.street.world) - 320)
	last_cam = roundf(cam)
	for B in bub:
		if px > B.x - 150:
			B.state = "done"
			B.shown = G.L(B.data, "text").length()

static func path_x(id: String) -> float:
	for q in PATHS:
		if q[1] == id: return q[0]
	return FORK_X

## Prende una deviazione (animazione), poi si cambia scena.
func take(id: String) -> void:
	if down > 0: return
	down = 0.001
	_left = false
	_to = id
	down_x = path_x(id)
	P.target = -1.0

func take_path() -> void: take("sea")

## Rifinisce le bolle già comparse quando cambia la lingua.
func finish_bubbles() -> void:
	for B in bub:
		if B.state != "idle":
			B.state = "done"
			B.shown = G.L(B.data, "text").length()

func _snow(ci: CanvasItem, dx: float, front: bool) -> void:
	if Weather.rain():
		for f in flakes:
			if (f.z > 1) != front: continue
			f.y += f.vy * 17 * _dt; f.x -= 46 * _dt + dx * f.z
			if f.y > 190:
				if front: puffs.append({"x": f.x + cam, "y": 168 + randf() * 14, "vx": randf_range(-6, 6), "vy": -8.0, "a": 0.5, "d": 0.0})
				f.y = randf_range(-60, 0); f.x = randf_range(0, 360)
			f.x = fposmod(f.x + 4, 330) - 4
			ci.draw_line(Vector2(f.x, f.y).round(), Vector2(f.x - 1.5, f.y + (7 if front else 4)).round(), Color(0.7, 0.8, 1, 0.5 if front else 0.25))
		return
	for f in flakes:
		if (f.z > 1) != front: continue
		f.y += f.vy * _dt
		f.x += (sin(f.y / 14 + f.ph) * 6 - 4) * _dt * f.z - dx * f.z
		if f.y > 200:
			f.y = -4; f.x = randf_range(0, 320)
		if f.x < -4: f.x += 328
		if f.x > 324: f.x -= 328
		var big: bool = f.z > 1
		ci.draw_rect(Rect2(roundf(f.x), roundf(f.y), 2 if big else 1, 2 if big else 1), Shop.flake(big) if Weather.active() and Weather.kind == "neve" else Season.flake(big))

func _draw_back(ci: CanvasItem) -> void:
	var s: Dictionary = G.J.street
	var c := roundf(cam)
	var dcam := c - last_cam
	ci.draw_texture(G.tex.far, Vector2(-roundf(c * float(s.pfar)), 0))
	Weather.clouds(ci, time)
	ci.draw_texture(G.tex.mid, Vector2(-roundf(c * float(s.pmid)), 0))
	_snow(ci, dcam * 0.4, false)
	ci.draw_texture(G.tex.near, Vector2(-c, 0))
	for q in PATHS: _draw_path(ci, c, q)
	if Shop.donate_url() != "":
		var cx := CART_X - c
		if cx > -50 and cx < 370:
			var cr: Array = G.J.places.rects.cart
			ci.draw_texture_rect_region(G.tex.place_props, Rect2(roundf(cx - 38), 164 - float(cr[3]), cr[2], cr[3]), Rect2(cr[0], cr[1], cr[2], cr[3]))
			for k in 4:                # il vapore della macchina
				var u := fposmod(time * 0.5 + k * 0.25, 1.0)
				ci.draw_rect(Rect2(roundf(cx - 12 + sin(time * 2 + k * 2) * 2), roundf(117 - u * 16), 2, 2), Color(1, 1, 1, 0.45 * (1 - u)))
	for p in smoke:
		ci.draw_circle(Vector2(roundf(p.x - c), roundf(p.y)), p.r, Color(0.82, 0.84, 0.93, maxf(0, p.a)))

func _draw_path(ci: CanvasItem, c: float, q: Array) -> void:
	var sx: float = q[0] - c
	if sx < -80 or sx > 400: return
	var f: Array = G.J.sea.rects.fork
	ci.draw_texture_rect_region(G.tex.sea_props, Rect2(roundf(sx - 42), 155, f[2], f[3]), Rect2(f[0], f[1], f[2], f[3]))
	var r: Array = G.J[{"sea_props": "sea", "grove_props": "grove", "place_props": "places"}[q[3]]].rects[q[2]]
	ci.draw_texture_rect_region(G.tex[q[3]], Rect2(roundf(sx - 76), 106, r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]))
	# freccia che invita a scendere
	if sin(time * 4) > -0.2:
		var ay := 160.0 + roundf(sin(time * 4) * 2)
		for k in 4: ci.draw_rect(Rect2(roundf(sx) - 3 + k, ay + k * 2, 7 - k * 2, 2), Color(str(q[4])))

func _draw_glow(ci: CanvasItem) -> void:
	var s: Dictionary = G.J.street
	var c := roundf(cam)
	for l in s.lamps:
		var x := float(l.x) - c
		if x < -40 or x > 360: continue
		var a := 0.07 + 0.02 * sin(time * 2 + float(l.x))
		Layer.glow(ci, Vector2(x, 64), 24, Color(1, 0.82, 0.55, a * 2.2))
	for q in PATHS: Layer.glow(ci, Vector2(q[0] - c, 178), 40, Color(Color(str(q[4])), 0.2 + 0.04 * sin(time * 2 + q[0])))
	if Shop.donate_url() != "": Layer.glow(ci, Vector2(CART_X - c, 112), 46, Color(1, 0.8, 0.5, 0.2))
	for w in s.windows:
		var x := float(w[0]) - c
		if x > -40 and x < 360:
			ci.draw_rect(Rect2(x, w[1], float(w[2]) - float(w[0]), float(w[3]) - float(w[1])), Color(1, 0.745, 0.43, 0.05 + 0.03 * sin(time * 3.8 + float(w[0]))))

func _draw_front(ci: CanvasItem) -> void:
	var s: Dictionary = G.J.street
	var c := roundf(cam)
	var dy := minf(down, 1.6) * 30.0
	P.draw(ci, P.x - c, float(s.feet) + dy)
	for p in puffs:
		if p.d > 0: continue
		ci.draw_rect(Rect2(roundf(p.x - c), roundf(p.y), 1, 1), Color(0.94, 0.96, 1, p.a))
	_snow(ci, c - last_cam, true)
	Weather.veil(ci, time)
	last_cam = c

func tap(world_x: float) -> void:
	P.target = clampf(world_x + cam, 10, 1e5)
