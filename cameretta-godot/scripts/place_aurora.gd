extends Place
## L'aurora su richiesta: particelle dal Sole, linee del campo terrestre, e il cielo che si accende ai poli.

const C := Vector2(190, 100)
const RE := 24.0
var parts: Array = []
var lights: Array = []
var energy := 1                # 0 debole, 1 media, 2 tempesta
var shots := 0

func _enter() -> void:
	parts.clear(); lights.clear()
	energy = 1; shots = 0
	say(G.t("aurHello"))

func next_energy() -> void:
	energy = (energy + 1) % 3
	Sfx.move()
	say(G.t("aurInfo")[energy])
	bar_changed.emit()

func fire() -> void:
	shots += 1
	Sfx.play("stop_pop", 0.4, 1.3)
	for k in [8, 16, 34][energy]:
		# più energia: si deposita su gusci più bassi, cioè a latitudini minori
		var L: float = [7.0, 5.6, 4.2][energy] + randf_range(-0.6, 0.6)
		parts.append({"st": "fly", "x": -10.0 - randf() * 70, "y": 100 + randf_range(-60, 60), "L": L, "n": 1 if randf() < 0.5 else -1, "th": 0.0, "ph": randf() * TAU, "sp": randf_range(0.8, 1.3)})

func press(k: int) -> bool:
	match k:
		KEY_E, KEY_ENTER, KEY_SPACE: fire()
		KEY_Q: next_energy()
		_: return false
	return true

func tap(_p: Vector2) -> void: fire()

func bar() -> Array:
	return [[G.t("aurFire"), fire], [G.t("aurEn")[energy], next_energy]]

## Punto su una linea di dipolo: r = L·cos²(latitudine).
static func dip(L: float, lat: float, side: float) -> Vector2:
	var r := RE * L * pow(cos(lat), 2)
	return C + Vector2(side * r * cos(lat), -r * sin(lat))

## Latitudine magnetica a cui la linea L tocca il suolo.
static func foot(L: float) -> float:
	return acos(sqrt(1.0 / L))

func _tick(dt: float) -> void:
	for p in parts:
		if p.st == "fly":
			p.x += dt * 130 * p.sp
			var entry: float = C.x - RE * float(p.L)
			if p.x >= entry - 14:
				p.st = "line"
				p.th = clampf((100.0 - p.y) / 60.0, -1, 1) * 0.25
		else:
			var f := foot(p.L)
			p.th += p.n * dt * 0.75 * p.sp
			if absf(p.th) >= f:
				p.st = "end"
				lights.append({"L": p.L, "n": signf(p.th), "a": 1.0, "e": energy, "ph": randf() * TAU})
	parts = parts.filter(func(p): return p.st != "end")
	for l in lights: l.a -= dt * 0.16
	lights = lights.filter(func(l): return l.a > 0)

func lat_deg() -> float:
	return rad_to_deg(foot([7.0, 5.6, 4.2][energy]))

func labels() -> Array:
	return [{"x": 60, "y": 168, "t": G.t("aurLat") % int(round(lat_deg())), "c": G.gold, "s": 24}]

func _draw_back(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 320, 200), Color("070a1c"))
	for k in 90: ci.draw_rect(Rect2((k * 71) % 320, (k * 37) % 200, 1, 1), Color(0.8, 0.85, 1, 0.3 + 0.3 * sin(time + k)))
	for L in [3.0, 4.2, 5.6, 7.0]:
		for side in [-1.0, 1.0]:
			var f := foot(L)
			var pts: PackedVector2Array = []
			for i in 41:
				var q := dip(L, lerpf(-f, f, i / 40.0), side)
				if side < 0: q.x = C.x + (q.x - C.x) * 0.78      # il vento solare schiaccia il lato di giorno…
				else: q.x = C.x + (q.x - C.x) * 1.12              # …e allunga quello di notte
				pts.append(q)
			ci.draw_polyline(pts, Color(0.35, 0.5, 0.9, 0.4))
	ci.draw_circle(C, RE, Color("1c3a7c")); ci.draw_circle(C + Vector2(-4, -2), RE - 5, Color("2f62b8"))
	for q in [[-12, -8, 6], [-4, -12, 5], [-8, 4, 7], [4, 8, 5]]: ci.draw_circle(C + Vector2(q[0], q[1]), q[2], Color("4f9a5c"))
	ci.draw_rect(Rect2(C.x - 10, C.y - RE, 20, 3), Color("eaf2ff")); ci.draw_rect(Rect2(C.x - 10, C.y + RE - 3, 20, 3), Color("eaf2ff"))
	for x in range(int(C.x), int(C.x + RE) + 1):
		var h := sqrt(maxf(0, RE * RE - pow(x - C.x, 2)))
		ci.draw_rect(Rect2(x, C.y - h, 1, h * 2), Color(0.02, 0.03, 0.12, 0.62))

func _draw_light(ci: CanvasItem) -> void:
	Layer.glow(ci, Vector2(-24, 100), 90, Color(1, 0.8, 0.35, 0.8))
	for l in lights:
		var f := foot(l.L)
		for side in [-1.0, 1.0]:
			var d := Vector2(side * cos(f), -l.n * sin(f))
			for k in 3:
				var h := RE + 2.0 + k * 3.0
				# verde: ossigeno a 557,7 nm (100-150 km); rosso: ossigeno a 630 nm, più in alto; viola: azoto, più in basso
				var col: Color = [Color("a050ff"), Color("50ff90"), Color("ff5060")][k]
				var w: float = [[0.1, 0.9, 0.3], [0.35, 1.0, 0.45], [0.9, 1.0, 0.95]][l.e][k]
				Layer.glow(ci, C + d * h, 6.0 + k, Color(col, l.a * w * (0.5 + 0.2 * sin(time * 5 + l.ph)) / maxf(1.0, sqrt(lights.size()) * 0.9)))

func _draw_front(ci: CanvasItem) -> void:
	for p in parts:
		var q: Vector2
		if p.st == "fly": q = Vector2(p.x, p.y + sin(time * 4 + p.ph) * 1.5)
		else:
			q = dip(p.L, p.th, -1.0)
			q.x = C.x + (q.x - C.x) * 0.78
			q += Vector2(sin(time * 26 + p.ph), cos(time * 26 + p.ph)) * 2.2      # la spirale attorno alla linea
		ci.draw_rect(Rect2(q.round(), Vector2.ONE), Color("fff2b0"))
		ci.draw_rect(Rect2(q.round() - Vector2(1, 0), Vector2(3, 1)), Color(1, 0.9, 0.5, 0.35))
	# la stessa aurora vista da terra
	ci.draw_rect(Rect2(8, 108, 96, 54), Color("0a1024")); ci.draw_rect(Rect2(8, 108, 96, 54), Color("f2b85b"), false, 1.0)
	var s := 0.0
	for l in lights: s += l.a
	s = clampf(s / 14.0, 0, 1)
	for x in range(10, 102, 2):
		var y := 128 + sin(x * 0.12 + time) * 7 + sin(x * 0.31 - time * 1.4) * 3
		var k := s * (0.5 + 0.5 * sin(x * 0.4 + time * 2))
		ci.draw_rect(Rect2(x, y - 12, 2, 12), Color(0.31, 1, 0.56, 0.75 * k))
		if energy > 0: ci.draw_rect(Rect2(x, y - 18, 2, 6), Color(1, 0.31, 0.38, 0.4 * k * energy))
		if energy > 1: ci.draw_rect(Rect2(x, y, 2, 4), Color(0.63, 0.31, 1, 0.7 * k))
	for x in range(9, 103): ci.draw_rect(Rect2(x, 154 - 3 * absf(sin(x * 0.21)) - 2 * absf(sin(x * 0.07)), 1, 8), Color("04060e"))
