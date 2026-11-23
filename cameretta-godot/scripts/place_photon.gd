extends Place
## La doppia fenditura, un fotone alla volta.

var hits: Array = []
var bins := PackedInt32Array()
var two := true
var spy := false
var fly: Array = []
var n := 0
var queue := 0
const SCR := 262.0

func _enter() -> void:
	two = true; spy = false
	clear()
	say(G.t("phoHello"))

func clear() -> void:
	hits.clear(); fly.clear()
	n = 0; queue = 0
	bins.resize(60); bins.fill(0)
	bar_changed.emit()

## Intensità (normalizzata a 1) alla coordinata u, da -1 a 1.
func inten(u: float) -> float:
	var a := u * 5.2
	var env := 1.0 if absf(a) < 1e-4 else pow(sin(a) / a, 2)
	if not two: return env
	return env if spy else env * pow(cos(u * 22.0), 2)

func sample() -> float:
	while true:
		var u := randf_range(-1, 1)
		if randf() < inten(u): return u
	return 0.0

func shoot(k: int) -> void:
	queue = mini(queue + k, 6000)
	Sfx.move()

func flip_two() -> void:
	two = not two
	if not two: spy = false
	Sfx.toggle(); clear()
	say(G.t("phoTwo" if two else "phoOne"))

func flip_spy() -> void:
	if not two: return
	spy = not spy
	Sfx.toggle(); clear()
	say(G.t("phoSpy" if spy else "phoNoSpy"))

func press(k: int) -> bool:
	match k:
		KEY_E, KEY_ENTER, KEY_SPACE: shoot(1)
		KEY_Q: shoot(100)
		KEY_R: shoot(1000)
		KEY_F2, KEY_X: clear()
		KEY_T: flip_two()
		KEY_V: flip_spy()
		_: return false
	return true

func tap(_p: Vector2) -> void: shoot(1)

func bar() -> Array:
	return [["1", shoot.bind(1)], ["100", shoot.bind(100)], ["1000", shoot.bind(1000)], [G.t("phoS2") if two else G.t("phoS1"), flip_two], [G.t("phoOn") if spy else G.t("phoOff"), flip_spy], [G.t("fieldClear"), clear]]

func _land(u: float) -> void:
	n += 1
	bins[clampi(int((u + 1) / 2 * 60), 0, 59)] += 1
	if hits.size() < 2600: hits.append(Vector2(SCR + randf_range(2, 26), 98 + u * 70))

func _tick(dt: float) -> void:
	var k := mini(queue, 1 if queue < 12 and fly.size() < 1 else 0 if queue < 12 else maxi(3, queue / 40))
	for i in k:
		queue -= 1
		if queue < 12 or i == 0: fly.append({"t": 0.0, "u": sample(), "s": randi() % 2})
		else: _land(sample())
	for f in fly:
		f.t += dt * 1.6
		if f.t >= 1.0:
			_land(f.u)
			Sfx.play("key_1", 0.15, 1.8)
	fly = fly.filter(func(f): return f.t < 1.0)

func labels() -> Array:
	return [{"x": 276, "y": 40, "t": G.t("phoCount") % n, "c": G.gold, "s": 24}]

func _draw_back(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 320, 200), Color("0c0e1c"))
	for x in range(0, 320, 20): ci.draw_rect(Rect2(x, 0, 1, 200), Color("12152a"))
	ci.draw_rect(Rect2(8, 88, 40, 20), Color("3a3f58")); ci.draw_rect(Rect2(48, 94, 8, 8), Color("ff5a5a")); ci.draw_rect(Rect2(8, 88, 40, 2), Color("6a7090"))
	var g := 6.0 if two else 0.0
	ci.draw_rect(Rect2(138, 22, 5, 152), Color("565c78"))
	for s in ([-1, 1] if two else [0]): ci.draw_rect(Rect2(138, 98 + s * g * 1.6 - 2, 5, 4), Color("0c0e1c"))
	ci.draw_rect(Rect2(SCR, 24, 30, 148), Color("171a2c")); ci.draw_rect(Rect2(SCR, 24, 2, 148), Color("c8d0e8"))
	if spy:
		ci.draw_circle(Vector2(156, 78), 7, Color("e8ecf8")); ci.draw_circle(Vector2(156, 78), 4, Color("3f74d8")); ci.draw_circle(Vector2(156, 78), 2, Color("0c0e1c"))

func _draw_light(ci: CanvasItem) -> void:
	for h in hits: ci.draw_rect(Rect2(h.round(), Vector2.ONE), Color(1, 0.85, 0.5, 0.8))
	Layer.glow(ci, Vector2(54, 98), 9, Color(1, 0.3, 0.3, 0.6))
	for f in fly:
		var t: float = f.t
		if t < 0.4: Layer.glow(ci, Vector2(lerpf(56, 138, t / 0.4), 98), 6, Color(1, 0.8, 0.5, 0.9))
		elif spy or not two:
			var y0: float = 98 + ((-1 if f.s == 0 else 1) * 9.6 if two else 0.0)
			var k := (t - 0.4) / 0.6
			Layer.glow(ci, Vector2(lerpf(142, SCR, k), lerpf(y0, 98 + f.u * 70, k)), 6, Color(1, 0.8, 0.5, 0.9))
			if spy and k < 0.25: Layer.glow(ci, Vector2(142, y0), 12, Color(0.4, 0.7, 1, 0.8))
		else:
			# finché nessuno guarda, passa come un'onda da tutte e due
			var k2 := (t - 0.4) / 0.6
			for s in [-1, 1]: ci.draw_arc(Vector2(142, 98 + s * 9.6), k2 * 118, -1.1, 1.1, 24, Color(1, 0.8, 0.5, 0.4 * (1 - k2 * 0.6)), 2.0)

func _draw_front(ci: CanvasItem) -> void:
	var mx := 1
	for b in bins: mx = maxi(mx, b)
	for i in 60:
		var w := 22.0 * bins[i] / mx if n > 5 else 0.0
		ci.draw_rect(Rect2(SCR - 2 - w, 28 + i * 2.333, w, 2), Color(0.5, 0.75, 1, 0.75))
