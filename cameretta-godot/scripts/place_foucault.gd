extends Place
## Il pendolo di Foucault visto dall'alto: il piano d'oscillazione ruota di 15° l'ora per il seno della latitudine.

const LATS := [["fouRos", 43.39], ["fouPole", 90.0], ["fouPisa", 43.72], ["fouEq", 0.0], ["fouSouth", -33.9]]
const SPEED := [1.0, 600.0, 3600.0]
var li := 0
var sp := 2
var ang := 0.0                 # gradi ruotati
var hours := 0.0
var trail: Array = []
var pins: Array = []

func _enter() -> void:
	li = 0; sp = 2
	reset()
	say(G.t("fouHello"))

func reset() -> void:
	ang = 0.0; hours = 0.0
	trail.clear()
	pins.clear()
	for k in 36: pins.append({"a": k * 10.0, "up": true})

## Gradi all'ora (positivi = senso orario visto dall'alto).
func rate() -> float:
	return 15.041 * sin(deg_to_rad(LATS[li][1]))

func period() -> float:
	return 360.0 / absf(rate()) if absf(rate()) > 0.01 else 0.0

func next_lat() -> void:
	li = (li + 1) % LATS.size()
	Sfx.move()
	reset()
	bar_changed.emit()

func next_speed() -> void:
	sp = (sp + 1) % SPEED.size()
	Sfx.move()
	bar_changed.emit()

func press(k: int) -> bool:
	match k:
		KEY_E, KEY_ENTER, KEY_SPACE: next_lat()
		KEY_Q: next_speed()
		KEY_X: reset()
		_: return false
	return true

func tap(_p: Vector2) -> void: next_lat()

func bar() -> Array:
	return [[G.t(LATS[li][0]), next_lat], [G.t("fouSpeed") % int(SPEED[sp]), next_speed], [G.t("fouReset"), reset]]

func _pos() -> Vector2:
	var a := deg_to_rad(ang)
	return Vector2(160, 96) + Vector2(sin(a), -cos(a)) * 61.0 * sin(time * 1.9)

func _tick(dt: float) -> void:
	hours += dt * SPEED[sp] / 3600.0
	ang = rate() * hours
	trail.append(_pos())
	if trail.size() > 320: trail.pop_front()
	for p in pins:
		if p.up and _pos().distance_to(Vector2(160, 96) + Vector2(sin(deg_to_rad(p.a)), -cos(deg_to_rad(p.a))) * 59) < 4.0:
			p.up = false
			Sfx.play("key_0", 0.4, 1.4)

func labels() -> Array:
	var T := period()
	return [{"x": 268, "y": 44, "t": G.t("fouTurn") % _n(ang, 1), "c": G.gold, "s": 28}, {"x": 268, "y": 56, "t": G.t("fouHours") % _n(hours, 1), "c": G.C_CREAM, "s": 22},
		{"x": 268, "y": 68, "t": (G.t("fouPeriod") % _n(T, 1)) if T > 0 else G.t("fouNever"), "c": Color("a8b4e0"), "s": 22}]

func _n(x: float, d: int) -> String:
	var s := String.num(x, d)
	return s.replace(".", ",") if G.lang == "it" else s

func _draw_back(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 320, 200), Color("2a2438"))
	for y in range(0, 200, 10):
		for x in range(0, 320, 20): ci.draw_rect(Rect2(x + (y / 10 % 2) * 10, y, 19, 9), Color("322b42"))
	ci.draw_circle(Vector2(160, 96), 74, Color("6a4c38")); ci.draw_circle(Vector2(160, 96), 71, Color("e4d4b4")); ci.draw_circle(Vector2(160, 96), 65, Color("efe3c8"))
	for k in 72:
		var a := deg_to_rad(k * 5.0)
		var d := Vector2(sin(a), -cos(a))
		ci.draw_line(Vector2(160, 96) + d * (67 if k % 6 else 65), Vector2(160, 96) + d * 70, Color("6a4c38"))

func _draw_front(ci: CanvasItem) -> void:
	for i in range(1, trail.size()): ci.draw_line(trail[i - 1], trail[i], Color(0.55, 0.4, 0.28, 0.55 * i / trail.size()))
	for p in pins:
		var q := (Vector2(160, 96) + Vector2(sin(deg_to_rad(p.a)), -cos(deg_to_rad(p.a))) * 59).round()
		if p.up: ci.draw_circle(q, 2, Color("b83a34")); ci.draw_rect(Rect2(q, Vector2.ONE), Color.WHITE)
		else: ci.draw_line(q, q + Vector2(4, 1), Color("b83a34"))
	var b := _pos()
	ci.draw_line(Vector2(160, 96), b, Color(0.2, 0.2, 0.3, 0.3))
	ci.draw_circle(b + Vector2(2, 3), 8, Color(0, 0, 0, 0.25)); ci.draw_circle(b, 8, Color("5a4420")); ci.draw_circle(b, 7, Color("d0a448")); ci.draw_circle(b - Vector2(2, 2), 2.5, Color("fff2c4"))
