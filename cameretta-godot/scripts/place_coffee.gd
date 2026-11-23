extends Place
## Il cielo dei caffè: una stella per ogni donazione, col nome che ha scelto chi l'ha accesa.

var stars: Array = []
var sel := -1
var loaded := false

func _enter() -> void:
	sel = -1
	loaded = false
	stars.clear()
	_load()

func _load() -> void:
	var r: Array = await Shop._call("/api/stars")
	loaded = true
	if r[0] == 200 and typeof(r[1]) == TYPE_ARRAY:
		for s in r[1]:
			var h := hash(str(s.id))
			stars.append({"n": str(s.name), "p": Vector2(14 + h % 292, 16 + (h / 331) % 118), "ph": (h / 7) % 628 / 100.0, "b": 1.0 + (h / 13) % 3})
	say(G.t("cofNone") if stars.is_empty() else G.t("cofHello") % stars.size())
	bar_changed.emit()

func bar() -> Array:
	var o := []
	if Shop.enabled(): o.append([G.t("cofName"), func(): goto.emit("starname")])
	if not stars.is_empty(): o.append([G.t("cofNext"), next_star])
	return o

func next_star() -> void:
	if stars.is_empty(): return
	sel = (sel + 1) % stars.size()
	Sfx.select()
	say(G.t("cofStar") % (stars[sel].n if stars[sel].n != "" else G.t("bottleAnon")))

func press(k: int) -> bool:
	if k in [KEY_E, KEY_ENTER, KEY_SPACE, KEY_RIGHT, KEY_D]:
		next_star()
		return true
	return false

func tap(p: Vector2) -> void:
	for i in stars.size():
		if stars[i].p.distance_to(p) < 9:
			sel = i - 1
			next_star()
			return

func labels() -> Array:
	var o := []
	if sel >= 0 and sel < stars.size(): o.append({"x": stars[sel].p.x, "y": stars[sel].p.y - 10, "t": stars[sel].n if stars[sel].n != "" else "★", "c": G.gold, "s": 26})
	return o

func _draw_back(ci: CanvasItem) -> void:
	for y in range(0, 200, 4): ci.draw_rect(Rect2(0, y, 320, 4), Color("0a0c28").lerp(Color("34306c"), y / 200.0))
	for k in 70: ci.draw_rect(Rect2((k * 83) % 320, (k * 47) % 150, 1, 1), Color(0.6, 0.65, 0.9, 0.25))

func _draw_light(ci: CanvasItem) -> void:
	for i in stars.size():
		var s: Dictionary = stars[i]
		var a := 0.7 + 0.3 * sin(time * 2 + s.ph)
		Layer.glow(ci, s.p, 6 + s.b * 2 + (6 if i == sel else 0), Color(1, 0.82, 0.45, 0.4 * a))
		ci.draw_rect(Rect2(s.p - Vector2(1, 0), Vector2(3, 1)), Color(1, 0.95, 0.8, a)); ci.draw_rect(Rect2(s.p - Vector2(0, 1), Vector2(1, 3)), Color(1, 0.95, 0.8, a))

func _draw_front(ci: CanvasItem) -> void:
	var hill: PackedVector2Array = [Vector2(0, 200)]
	for x in range(0, 324, 4): hill.append(Vector2(x, 168 - 14 * sin(x * 0.011 + 0.6) - 3 * sin(x * 0.05)))
	hill.append(Vector2(320, 200))
	ci.draw_colored_polygon(hill, Color("0c0e22"))
	P.frame = 0; P.dir = 1
	P.draw(ci, 150, 162)
	# una tazzina fumante sul muretto
	ci.draw_rect(Rect2(180, 150, 9, 7), Color("f6e9c8")); ci.draw_rect(Rect2(189, 152, 2, 3), Color("f6e9c8")); ci.draw_rect(Rect2(178, 157, 13, 2), Color("c8b890"))
	for k in 3: ci.draw_rect(Rect2(182 + k * 2 + sin(time * 2 + k) * 1.2, 148 - fposmod(time * 6 + k * 4, 12), 1, 2), Color(1, 1, 1, 0.4))
