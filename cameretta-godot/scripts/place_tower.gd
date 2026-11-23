extends Place
## La Torre di Pisa: due oggetti lasciati cadere insieme, con o senza aria. La fisica è quella vera.

const H := 55.0
const G0 := 9.80665
const TOP := 34.0
const GROUND := 163.0
const OBJ := {
	"ball_iron": {"m": 43.9, "cda": 0.0179},         # ferro, raggio 11 cm
	"ball_wood": {"m": 3.9, "cda": 0.0179},          # legno, stesso raggio
	"ball_cork": {"m": 0.0271, "cda": 0.00133},      # sughero, raggio 3 cm
	"feather": {"m": 0.002, "cda": 0.0095},          # piuma: scende a circa 1,8 m/s
}
const OTHER := ["ball_wood", "ball_cork", "feather"]
var which := 0
var air := true
var falling := false
var a := {}
var b := {}
var dust: Array = []
var _fast := 1.0

func _enter() -> void:
	which = 0; air = true
	_reset()
	P.x = 120
	say(G.t("towerHello"))

func _reset() -> void:
	falling = false
	a = {"n": "ball_iron", "y": 0.0, "v": 0.0, "t": 0.0, "end": false}
	b = {"n": OTHER[which], "y": 0.0, "v": 0.0, "t": 0.0, "end": false}
	bar_changed.emit()

func drop() -> void:
	if falling: return
	_reset()
	falling = true
	Sfx.play("stop_pop", 0.6)

func next_obj(d := 1) -> void:
	if falling and not (a.end and b.end): return
	which = posmod(which + d, OTHER.size())
	Sfx.move()
	_reset()

func toggle_air() -> void:
	if falling and not (a.end and b.end): return
	air = not air
	Sfx.toggle()
	_reset()

## Un passo di caduta, con la resistenza dell'aria (densità 1,225 kg/m³).
static func step(o: Dictionary, dt: float, with_air: bool) -> void:
	if o.end: return
	var n := 8
	for i in n:
		var h := dt / n
		var q: Dictionary = OBJ[o.n]
		var acc: float = G0 - (0.5 * 1.225 * float(q.cda) * o.v * o.v / float(q.m) if with_air else 0.0)
		var v1: float = o.v + acc * h
		var y1: float = o.y + (o.v + v1) / 2.0 * h
		if y1 >= H:
			o.t += h * (H - o.y) / maxf(1e-6, y1 - o.y)
			o.y = H; o.end = true
			return
		o.v = v1; o.y = y1; o.t += h

func _tick(dt: float) -> void:
	if falling:
		# la piuma ci mette davvero mezzo minuto: atterrato il ferro, il tempo corre
		_fast = minf(8.0, _fast + dt * 5.0) if a.end and not b.end else 1.0
		for o in [a, b]:
			var was: bool = o.end
			step(o, dt * _fast, air)
			if o.end and not was:
				Sfx.step_snow()
				if o.n == "ball_iron": Sfx.play("brake_snow", 0.5, 0.7)
				for k in 14: dust.append({"x": _x(o), "y": GROUND, "vx": randf_range(-26, 26), "vy": randf_range(-34, -4), "a": 1.0})
		if a.end and b.end and falling:
			falling = false
			var d: float = b.t - a.t
			say(G.t("towerTie") % _num(a.t) if d < 0.02 else G.t("towerWin" if air else "towerTie") % ([_num(a.t), _num(b.t), G.t("towerObj")[b.n]] if air else [_num(a.t)]))
	for p in dust: p.x += p.vx * dt; p.y += p.vy * dt; p.vy += 90 * dt; p.a -= dt * 1.4
	dust = dust.filter(func(p): return p.a > 0)
	P.animate(dt, false, Sfx.step_snow)

func _num(x: float) -> String:
	return ("%.2f" % x).replace(".", "," if G.lang == "it" else ".")

func _x(o: Dictionary) -> float:
	return 190.0 if o.n == a.n and o == a else 204.0

func press(k: int) -> bool:
	match k:
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: drop()
		KEY_LEFT, KEY_A: next_obj(-1)
		KEY_RIGHT, KEY_D: next_obj(1)
		KEY_Q: toggle_air()
		_: return false
	return true

func tap(_p: Vector2) -> void: drop()

func bar() -> Array:
	return [[G.t("towerDrop"), drop], [G.t("towerObj")["ball_iron"] + " / " + G.t("towerObj")[OTHER[which]], next_obj], [G.t("towerAir") if air else G.t("towerVoid"), toggle_air]]

func labels() -> Array:
	var o := [{"x": 262, "y": 48, "t": G.t("towerObj")["ball_iron"], "c": Color("c8ccdc"), "s": 24}, {"x": 262, "y": 70, "t": G.t("towerObj")[b.n], "c": Color("e0b888"), "s": 24}]
	o.append({"x": 262, "y": 56, "t": _num(a.t) + " s", "c": G.gold, "s": 34})
	o.append({"x": 262, "y": 78, "t": _num(b.t) + " s", "c": G.gold, "s": 34})
	o.append({"x": 262, "y": 96, "t": "%d m · %s" % [int(H), G.t("towerAir") if air else G.t("towerVoid")], "c": Color("a8b4e0"), "s": 22})
	return o

func _draw_back(ci: CanvasItem) -> void:
	ci.draw_texture(G.tex.place_pisa, Vector2.ZERO)
	for m in range(0, 56, 5):
		var y := GROUND - (GROUND - TOP) * m / H
		ci.draw_rect(Rect2(222, roundf(y), 5 if m % 10 == 0 else 3, 1), Color(0.8, 0.86, 1, 0.5))
	ci.draw_rect(Rect2(222, TOP, 1, GROUND - TOP), Color(0.8, 0.86, 1, 0.35))

func _draw_front(ci: CanvasItem) -> void:
	P.dir = 1
	P.draw(ci, 84, 178)
	for o in [a, b]:
		var y: float = TOP + (GROUND - TOP) * float(o.y) / H
		var r: Array = G.J.places.rects[o.n]
		var sway := sin(time * 5) * 4.0 if o.n == "feather" and air and falling and not o.end else 0.0
		spr(ci, o.n, _x(o) - float(r[2]) / 2 + sway, y - float(r[3]) + 1)
	for p in dust: ci.draw_rect(Rect2(roundf(p.x), roundf(p.y), 2, 2), Color(1, 1, 1, p.a))
