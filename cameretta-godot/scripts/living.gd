extends Node2D
## Il salotto: camino che fuma e scoppietta, TV accesa (4 canali), lucine, pendolo, porta luminosa.

signal go_room
signal go_out

var P: Player
var time := 0.0
var sparks: Array = []
var flakes: Array = []
var steam: Array = []
var warm := 0.0
var input_dir := 0
var run := false
var locked := false
var prompt: Dictionary = {}
var _dt := 0.0
var base_l: Layer
var glow_l: Layer
var top_l: Layer
var smoke: Array = []

func _ready() -> void:
	P = Player.new()
	base_l = Layer.make(self, _draw_base)
	glow_l = Layer.make(self, _draw_glow, true)
	top_l = Layer.make(self, _draw_top)

func enter(from_room: bool) -> void:
	var l: Dictionary = G.J.living
	P = Player.new()
	P.x = float(l.spots.door) - 6 if from_room else float(l.start)
	P.dir = -1 if from_room else 1
	var w: Array = l.window
	flakes = []
	for f in preload("res://scripts/street.gd").make_flakes(14):
		f.x = randf_range(w[0], w[2]); f.y = randf_range(w[1], w[3]); f.vy = randf_range(6, 11)
		flakes.append(f)

func update(dt: float) -> void:
	time += dt
	_dt = dt
	var l: Dictionary = G.J.living
	P.update(dt, input_dir, run, 12, l.stop, Sfx.step_wood, locked)
	Sfx.proximity(clampf(1 - absf(P.x - float(l.spots.fire)) / 120, 0, 1), clampf(1 - absf(P.x - float(l.spots.tv)) / 110, 0, 1))
	var spots := [
		["door", float(l.spots.door), float(l.door[1]) - 20, G.t("door"), func(): go_room.emit()],
		["tv", float(l.spots.tv), float(l.tv[1]) - 22, G.t("tv"), change_channel],
		["fire", float(l.spots.fire), 46.0, G.t("warm") if warm > 0 else G.t("fire"), warm_hands],
	]
	var near = null
	for s in spots:
		if absf(P.x - s[1]) < 20 and (near == null or absf(P.x - s[1]) < absf(P.x - near[1])): near = s
	prompt = {"x": near[1], "y": near[2], "label": near[3], "action": near[4]} if near != null else {}
	warm = maxf(0, warm - dt)
	for p in sparks:
		p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 20 * dt; p.a -= dt * 0.9
	sparks = sparks.filter(func(p): return p.a > 0)
	if randf() < dt * 3: steam.append({"y": 0.0, "ph": randf_range(0, 6)})
	for p in steam: p.y += dt * 6
	steam = steam.filter(func(p): return p.y < 14)
	# fumo leggero che esce dalla bocca del camino
	var f: Array = l.fire
	if randf() < dt * 4:
		smoke.append({"x": randf_range(f[0] + 8, f[2] - 8), "y": float(f[1]) - 2, "r": 1.0, "a": 0.28, "vx": randf_range(-3, 3), "vy": randf_range(-8, -5)})
	for p in smoke:
		p.x += p.vx * dt; p.y += p.vy * dt; p.r += dt * 1.5; p.a -= dt * 0.12
	smoke = smoke.filter(func(p): return p.a > 0 and p.y > float(f[1]) - 26)
	base_l.queue_redraw(); glow_l.queue_redraw(); top_l.queue_redraw()

func change_channel() -> void:
	G.tv_channel = (G.tv_channel + 1) % 4
	G.save_prefs()
	Sfx.channel()

func warm_hands() -> void:
	warm = 2.4
	Sfx.pop()
	Sfx.play("ui_open", 0.25, 0.6)
	var f: Array = G.J.living.fire
	for k in 22:
		sparks.append({"x": randf_range(f[0] + 6, f[2] - 6), "y": float(f[3]) - 6, "vx": randf_range(-14, 14), "vy": randf_range(-46, -18), "a": 1.0})

func _draw_fire(ci: CanvasItem) -> void:
	var f: Array = G.J.living.fire
	var x0: int = f[0]; var y0: int = f[1]; var x1: int = f[2]; var y1: int = f[3]
	var tick := int(time / 0.09)
	for x in range(x0, x1 + 1):
		var c := float(x - x0) / (x1 - x0)
		var base := sin(c * PI)
		var h := maxf(0, (y1 - y0) * (0.35 + 0.55 * base) * (0.75 + 0.25 * sin(tick * 1.7 + x * 0.9) + 0.15 * sin(tick * 0.6 + x * 2.3)) * (1 + warm * 0.12))
		for k in int(ceil(h)):
			var r := k / h
			if r > 0.85 and (x + k + tick) % 2 == 1: continue
			var col := Color("fff1b8") if r < 0.35 else Color("ffc04a") if r < 0.6 else Color("f0702a") if r < 0.85 else Color("b8321e")
			ci.draw_rect(Rect2(x, y1 - k, 1, 1), col)
	if tick % 3 == 0 and randf() < 0.5:
		sparks.append({"x": randf_range(x0 + 8, x1 - 8), "y": float(y1) - 14, "vx": randf_range(-6, 6), "vy": randf_range(-30, -16), "a": 0.9})

func _draw_tv(ci: CanvasItem) -> void:
	var tv: Array = G.J.living.tv
	var x0: int = tv[0]; var y0: int = tv[1]; var x1: int = tv[2]; var y1: int = tv[3]
	var w := x1 - x0 + 1
	var h := y1 - y0 + 1
	var tick := int(time / 0.1)
	match G.tv_channel:
		0:  # tramonto sul mare
			for yy in h:
				var r := float(yy) / h
				var col := Color("ff9a6b").lerp(Color("ffd28a"), r / 0.55) if r < 0.55 else Color("2c5d8f").lerp(Color("1b3557"), (r - 0.56) / 0.44)
				ci.draw_rect(Rect2(x0, y0 + yy, w, 1), col)
			var cx := x0 + w * 0.6
			var cy := y0 + h * 0.52
			for dy in range(-5, 1):
				var hw := sqrt(25.0 - dy * dy)
				ci.draw_rect(Rect2(roundf(cx - hw), roundf(cy + dy), roundf(hw * 2), 1), Color("fff1c2"))
			for k in 6:
				ci.draw_rect(Rect2(x0 + ((tick * (k + 1) * 2 + k * 9) % w), y0 + h * 0.6 + k * 2, 4, 1), Color(1, 0.86, 0.63, 0.6))
		1:  # telegiornale
			ci.draw_rect(Rect2(x0, y0, w, h), Color("20407a"))
			ci.draw_rect(Rect2(x0 + 4, y0 + 5, 14, 12), Color("d8e4ff"))
			ci.draw_rect(Rect2(x0 + 8, y0 + 7, 6, 5), Color("f2c79a"))
			ci.draw_rect(Rect2(x0 + 8, y0 + 6, 6, 2), Color("3a2a24"))
			ci.draw_rect(Rect2(x0 + 6, y0 + 12, 10, 5), Color("2b2550"))
			if int(time * 6) % 3 != 0: ci.draw_rect(Rect2(x0 + 10, y0 + 10, 2, 1), Color("7a3626"))
			for k in 3: ci.draw_rect(Rect2(x0 + 22, y0 + 6 + k * 4, 18 - k * 4, 2), Color.WHITE)
			ci.draw_rect(Rect2(x0, y1 - 5, w, 6), Color("c83a32"))
			for k in 9:
				var xx := posmod(k * 9 - tick * 2, w + 20) - 10
				var a0 := clampi(xx, 0, w)
				var a1 := clampi(xx + 5, 0, w)
				if a1 > a0: ci.draw_rect(Rect2(x0 + a0, y1 - 3, a1 - a0, 2), Color.WHITE)
		2:  # neve statica
			for yy in range(y0, y1 + 1):
				for xx in range(x0, x1 + 1):
					var v := randf() * 0.78
					ci.draw_rect(Rect2(xx, yy, 1, 1), Color(v, v, v + 0.04))
			ci.draw_rect(Rect2(x0, y0 + (tick * 2) % h, w, 3), Color(1, 1, 1, 0.15))
		_:  # pong
			ci.draw_rect(Rect2(x0, y0, w, h), Color("0c0c18"))
			var bx := x0 + 4 + absi(((tick * 2) % ((w - 8) * 2)) - (w - 8))
			var by := y0 + 3 + absi(((tick * 3) % ((h - 6) * 2)) - (h - 6))
			ci.draw_rect(Rect2(bx, by, 2, 2), Color.WHITE)
			ci.draw_rect(Rect2(x0 + 2, clampi(by - 4, y0 + 1, y1 - 8), 2, 8), Color.WHITE)
			ci.draw_rect(Rect2(x1 - 3, clampi(by - 3, y0 + 1, y1 - 8), 2, 8), Color.WHITE)
			for yy in range(y0, y1, 4): ci.draw_rect(Rect2(x0 + (w >> 1), yy, 1, 2), Color.WHITE)
	for yy in range(y0, y1 + 1, 2):
		ci.draw_rect(Rect2(x0, yy, w, 1), Color(0, 0, 0, 0.12))

func _draw_base(ci: CanvasItem) -> void:
	var l: Dictionary = G.J.living
	ci.draw_texture(G.tex.living, Vector2.ZERO)
	# neve oltre la finestra
	var w: Array = l.window
	for f in flakes:
		f.y += f.vy * _dt * 0.7
		f.x += sin(f.y / 9 + f.ph) * _dt * 4
		if f.y > float(w[3]) - 3:
			f.y = float(w[1]); f.x = randf_range(w[0], w[2])
		if f.x >= w[0] and f.x < w[2]:
			ci.draw_rect(Rect2(roundf(f.x), roundf(f.y), 1, 1), Color(0.94, 0.96, 1, 0.9))
	_draw_fire(ci)
	_draw_tv(ci)
	for p in smoke:
		ci.draw_circle(Vector2(roundf(p.x), roundf(p.y)), p.r, Color(0.7, 0.66, 0.66, maxf(0, p.a)))
	var cols := [Color("ff7a6e"), Color("ffd36a"), Color("8ce69e"), Color("8ec8ff")]
	var i := 0
	for pt in l.fairy:
		var on := sin(time / 0.38 + i * 1.3) > -0.3
		ci.draw_rect(Rect2(pt[0], pt[1], 1, 2), cols[i % 4] if on else Color("5a4a40"))
		i += 1
	# pendolo
	var cl: Array = l.clock
	var a := 0.32 * sin(time * PI)
	var ln := float(cl[2]) - float(cl[1]) - 4
	var px := float(cl[0]) + sin(a) * ln
	var py := float(cl[1]) + cos(a) * ln
	ci.draw_line(Vector2(float(cl[0]) + 0.5, cl[1]), Vector2(px + 0.5, py), Color("d9b46a"), 1)
	ci.draw_rect(Rect2(roundf(px) - 1, roundf(py) - 1, 3, 3), Color("f2c86a"))
	var m: Array = l.mug
	for p in steam:
		ci.draw_rect(Rect2(roundf(m[0] + sin(p.y / 2.5 + p.ph) * 1.3), roundf(m[1] - p.y), 1, 1), Color(0.98, 0.98, 1, maxf(0, 0.7 - p.y / 18)))

func _draw_glow(ci: CanvasItem) -> void:
	var fl := 0.09 + 0.03 * sin(time / 0.12) + 0.02 * sin(time / 0.047) + warm * 0.02
	Layer.glow(ci, Vector2(150, 130), 90, Color(1, 0.59, 0.27, fl * 1.6))
	var tvc: Color = [Color(1, 0.67, 0.43), Color(0.43, 0.59, 1), Color(0.78, 0.78, 0.86), Color(0.63, 0.63, 1)][G.tv_channel]
	tvc.a = (0.06 + 0.03 * randf()) * 1.6
	Layer.glow(ci, Vector2(230, 100), 50, tvc)
	Layer.glow(ci, Vector2(288, 110), 46, Color(1, 0.84, 0.55, (0.10 + 0.03 * sin(time / 0.7)) * 1.6))

func _draw_top(ci: CanvasItem) -> void:
	for p in sparks:
		ci.draw_rect(Rect2(roundf(p.x), roundf(p.y), 1, 1), Color(1, (180 + p.a * 60) / 255.0, 0.35, p.a))
	P.draw(ci, P.x, float(G.J.living.feet), Color(0.16, 0.08, 0.04, 0.35))

func tap(world_x: float) -> void:
	P.target = clampf(world_x, 10, 1e5)
