extends Place
## Il treno notturno: ogni carrozza è una tappa del percorso (le voci della finestra), l'ultima è ancora vuota.

var cars: Array = []
var _read := -1

func _enter() -> void:
	walking = true
	feet = 186.0
	cars.clear()
	var sec: Dictionary = G.by_id.get("finestra", {})
	var items: Array = sec.get("items", [])
	var grp: String = items[0].get("grp", "") if not items.is_empty() else ""
	for it in items:
		if it.get("grp", "") == grp: cars.push_front(it)      # la più recente sta verso la locomotiva
	world = 320.0 * (cars.size() + 1)
	P.x = 40
	_read = -1

func car() -> int:
	return clampi(int(P.x / 320.0), 0, cars.size())

func _tick(_dt: float) -> void:
	var c := car()
	if c != _read:
		_read = c
		if c < cars.size(): say("%s. %s." % [G.L(cars[c], "kicker"), G.L(cars[c], "title")])
		else: say(G.t("trainEmpty"))
	if c < cars.size(): prompt = {"x": c * 320.0 + 160 - cam, "y": 112.0, "label": G.t("trainRead"), "action": func(): open_item.emit(cars[c], G.by_id.finestra)}

func labels() -> Array:
	var o := []
	for i in cars.size() + 1:
		var x := i * 320.0 + 160 - cam
		if x > -40 and x < 360: o.append({"x": x, "y": 33, "t": G.L(cars[i], "kicker").to_upper() if i < cars.size() else "…", "c": G.gold, "s": 30})
	return o

func _draw_back(ci: CanvasItem) -> void:
	var w := fposmod(time * 26, 512)
	for k in 3: ci.draw_texture(G.tex.far, Vector2(k * 512 - w, -22))
	var m := fposmod(time * 120, 896)
	for k in 2: ci.draw_texture(G.tex.mid, Vector2(k * 896 - m, -28), Color(0.45, 0.48, 0.75))
	for k in 5:
		var x := fposmod(k * 110 - time * 300, 550) - 60
		ci.draw_rect(Rect2(roundf(x), 30, 3, 90), Color("15162c"))
	for k in 30:
		var y := (k * 41) % 120
		ci.draw_rect(Rect2(fposmod(k * 67 - time * 420, 340) - 10, y + sin(time + k) * 3, 4, 1), Color(1, 1, 1, 0.6))
	var c := roundf(cam)
	var jog := roundf(sin(time * 9) * 0.5)
	for i in cars.size() + 1:
		var sx := i * 320 - c
		if sx > -320 and sx < 320: ci.draw_texture(G.tex.place_train, Vector2(sx, jog))

func _draw_light(ci: CanvasItem) -> void:
	for i in cars.size() + 1:
		for k in 2: Layer.glow(ci, Vector2(i * 320 + 92 + k * 136 - cam, 26), 50, Color(1, 0.8, 0.5, 0.22))

func _draw_front(ci: CanvasItem) -> void:
	P.draw(ci, P.x - cam, feet)
