extends Place
## La sala giochi: un cabinato per ogni progetto.

const GAP := 74.0
var games: Array = []          # [voce, sezione]

func _enter() -> void:
	walking = true
	feet = 186.0
	games.clear()
	for id in ["scrivania", "lavagna"]:
		var sec: Dictionary = G.by_id.get(id, {})
		for it in sec.get("items", []):
			if id == "scrivania" or str(it.get("url", "")) != "": games.append([it, sec])
	world = maxf(320, 90 + GAP * games.size() + 60)
	P.x = 36
	say(G.t("arcadeHello"))

func _x(i: int) -> float:
	return 100 + i * GAP

func _tick(_dt: float) -> void:
	var best := -1
	for i in games.size():
		if absf(P.x - _x(i)) < 30: best = i
	if best >= 0:
		var g: Array = games[best]
		prompt = {"x": _x(best) - cam, "y": 69.0, "label": G.t("arcadePlay") + ": " + G.L(g[0], "title"), "action": func(): Sfx.play("stop_pop", 0.6); open_item.emit(g[0], g[1])}

func tap(p: Vector2) -> void:
	for i in games.size():
		if absf(p.x + cam - _x(i)) < 24 and p.y > 70 and p.y < 170:
			P.target = _x(i)
			P.on_arrive = func(): if not prompt.is_empty(): prompt.action.call()
			return
	super(p)

func _draw_back(ci: CanvasItem) -> void:
	var c := roundf(cam)
	var x := -fposmod(c, 160)
	while x < 320:
		ci.draw_texture(G.tex.place_arcade, Vector2(x, 0))
		x += 160
	for i in games.size():
		var sx := _x(i) - c
		if sx < -40 or sx > 360: continue
		spr(ci, "cab%d" % (i % 6), sx - 25, 164 - 92)
		# lo schermo: l'emblema del progetto che rimbalza
		var em: String = load("res://scripts/sea.gd").emblem_for(games[i][0], games[i][1].id)
		var idx := maxi(0, (G.J.sea.emblems as Array).find(em))
		var ox := roundf(sin(time * 1.3 + i) * 6)
		var oy := roundf(absf(sin(time * 2.1 + i * 0.7)) * -7)
		var on := absf(P.x - _x(i)) < 30
		ci.draw_rect(Rect2(sx - 14, 97, 28, 26), Color.from_hsv(fposmod(i * 0.17 + (time * 0.15 if on else 0.0), 1.0), 0.6, 0.3 if on else 0.18))
		for k in 5: ci.draw_rect(Rect2(sx - 14, 97 + fposmod(k * 6 + time * 9, 26), 28, 1), Color(1, 1, 1, 0.06))
		ci.draw_texture_rect_region(G.tex.sea_emblems, Rect2(sx - 8 + ox * 0.8, 106 + oy, 16, 16), Rect2(idx * 16, 0, 16, 16), Color.WHITE if on else Color(0.75, 0.75, 0.85))

func _draw_light(ci: CanvasItem) -> void:
	var c := roundf(cam)
	for i in games.size():
		var sx := _x(i) - c
		if sx < -60 or sx > 380: continue
		Layer.glow(ci, Vector2(sx, 110), 34, Color.from_hsv(fposmod(i * 0.17, 1.0), 0.6, 1.0, 0.3 if absf(P.x - _x(i)) < 30 else 0.14))
		Layer.glow(ci, Vector2(sx, 176), 26, Color.from_hsv(fposmod(i * 0.17, 1.0), 0.6, 1.0, 0.12))
	ci.draw_rect(Rect2(0, 14, 320, 2), Color(1, 0.4, 0.75, 0.3 + 0.1 * sin(time * 8)))

func _draw_front(ci: CanvasItem) -> void:
	P.draw(ci, P.x - cam, feet, Color(0, 0, 0, 0.4))
