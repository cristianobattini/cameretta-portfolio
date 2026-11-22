extends Node2D
## La strada innevata: parallasse, neve, lampioni, fumo dal comignolo, bolle che si scrivono.

signal go_inside

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
	build_bubbles()

func build_bubbles() -> void:
	bub.clear()
	var s: Dictionary = G.J.street
	var n := G.bubbles.size()
	if n == 0: return
	var x0 := 210.0
	var x1 := float(s.stop) - 200.0
	var step := (x1 - x0) / (n - 1) if n > 1 else 0.0
	for i in n:
		bub.append({"x": x0 + i * step, "top": 196.0 if i % 2 else 128.0, "data": G.bubbles[i], "state": "idle", "shown": 0, "t": 0.26})

func update(dt: float) -> void:
	time += dt
	var s: Dictionary = G.J.street
	P.update(dt, input_dir, run, 14, s.stop, Sfx.step_snow, locked)
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

## Rifinisce le bolle già comparse quando cambia la lingua.
func finish_bubbles() -> void:
	for B in bub:
		if B.state != "idle":
			B.state = "done"
			B.shown = G.L(B.data, "text").length()

func _snow(ci: CanvasItem, dx: float, front: bool) -> void:
	for f in flakes:
		if (f.z > 1) != front: continue
		f.y += f.vy * _dt
		f.x += (sin(f.y / 14 + f.ph) * 6 - 4) * _dt * f.z - dx * f.z
		if f.y > 200:
			f.y = -4; f.x = randf_range(0, 320)
		if f.x < -4: f.x += 328
		if f.x > 324: f.x -= 328
		var big: bool = f.z > 1
		ci.draw_rect(Rect2(roundf(f.x), roundf(f.y), 2 if big else 1, 2 if big else 1), Color(1, 1, 1, 0.95) if big else Color(0.86, 0.9, 1, 0.6))

func _draw_back(ci: CanvasItem) -> void:
	var s: Dictionary = G.J.street
	var c := roundf(cam)
	var dcam := c - last_cam
	ci.draw_texture(G.tex.far, Vector2(-roundf(c * float(s.pfar)), 0))
	ci.draw_texture(G.tex.mid, Vector2(-roundf(c * float(s.pmid)), 0))
	_snow(ci, dcam * 0.4, false)
	ci.draw_texture(G.tex.near, Vector2(-c, 0))
	for p in smoke:
		ci.draw_circle(Vector2(roundf(p.x - c), roundf(p.y)), p.r, Color(0.82, 0.84, 0.93, maxf(0, p.a)))

func _draw_glow(ci: CanvasItem) -> void:
	var s: Dictionary = G.J.street
	var c := roundf(cam)
	for l in s.lamps:
		var x := float(l.x) - c
		if x < -40 or x > 360: continue
		var a := 0.07 + 0.02 * sin(time * 2 + float(l.x))
		Layer.glow(ci, Vector2(x, 64), 24, Color(1, 0.82, 0.55, a * 2.2))
	for w in s.windows:
		var x := float(w[0]) - c
		if x > -40 and x < 360:
			ci.draw_rect(Rect2(x, w[1], float(w[2]) - float(w[0]), float(w[3]) - float(w[1])), Color(1, 0.745, 0.43, 0.05 + 0.03 * sin(time * 3.8 + float(w[0]))))

func _draw_front(ci: CanvasItem) -> void:
	var s: Dictionary = G.J.street
	var c := roundf(cam)
	P.draw(ci, P.x - c, float(s.feet))
	for p in puffs:
		if p.d > 0: continue
		ci.draw_rect(Rect2(roundf(p.x - c), roundf(p.y), 1, 1), Color(0.94, 0.96, 1, p.a))
	_snow(ci, c - last_cam, true)
	last_cam = c

func tap(world_x: float) -> void:
	P.target = clampf(world_x + cam, 10, 1e5)
