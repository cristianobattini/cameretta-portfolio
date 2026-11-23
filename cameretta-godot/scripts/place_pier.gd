extends Place
## Il molo: si pesca di notte, e quello che abbocca porta una frase.

var state := "idle"            # idle | wait | bite | show
var wait_t := 0.0
var got := ""
var rip: Array = []
const HOOK := Vector2(214, 150)

func _enter() -> void:
	state = "idle"
	say(G.t("fishHello"))

func act() -> void:
	match state:
		"idle", "show":
			state = "wait"; st = 0.0; wait_t = randf_range(1.8, 5.5)
			line = ""
			Sfx.play("helmet", 0.35, 1.5)
			rip.append({"t": 0.0})
		"wait":
			state = "idle"
			say(G.t("fishEarly"))
		"bite":
			state = "show"; st = 0.0
			var x := randf()
			got = "fish0" if x < 0.45 else "fish1" if x < 0.75 else "fish2" if x < 0.93 else "fish3"
			G.fish[got] = int(G.fish.get(got, 0)) + 1
			G.save_prefs()
			Sfx.play("stop_pop", 0.8)
			say("%s! %s" % [G.t("fishNames")[got], Quotes.line(Quotes.next(got == "fish3"))])
			Shop.earn("fish")
	bar_changed.emit()

func _tick(dt: float) -> void:
	P.animate(dt, false, Sfx.step_wood)
	P.frame = 0
	if state == "wait" and st > wait_t:
		state = "bite"; st = 0.0
		Sfx.play("stop_pop", 0.5, 1.6)
		for i in 3: rip.append({"t": -0.12 * i})
		bar_changed.emit()
	elif state == "bite" and st > 1.15:
		state = "idle"
		say(G.t("fishLost"))
		bar_changed.emit()
	for r in rip: r.t += dt
	rip = rip.filter(func(r): return r.t < 1.6)
	if state != "wait" and state != "bite": prompt = {}

func press(k: int) -> bool:
	if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		act()
		return true
	return false

func tap(_p: Vector2) -> void: act()

func bar() -> Array:
	return [[G.t("fishPull") if state == "bite" else G.t("fishStop") if state == "wait" else G.t("fishCast"), act]]

func labels() -> Array:
	var o := []
	var i := 0
	for k in ["fish0", "fish1", "fish2", "fish3"]:
		o.append({"x": 268, "y": 127 + i * 14, "t": "× %d" % int(G.fish.get(k, 0)), "c": G.C_CREAM, "s": 26})
		i += 1
	if state == "bite" and int(time * 8) % 2 == 0: o.append({"x": HOOK.x, "y": HOOK.y - 34, "t": "!", "c": G.gold, "s": 64})
	return o

func _draw_back(ci: CanvasItem) -> void:
	ci.draw_texture(G.tex.place_pier, Vector2.ZERO)
	for k in 40:                                                   # luccichii
		var y := 100 + (k * 37) % 98
		if sin(time * 1.6 + k * 2.3) > 0.5: ci.draw_rect(Rect2(fposmod(k * 53 + time * 4, 320), y, 2 + k % 3, 1), Color(0.7, 0.8, 1, 0.35))
	for k in 18:                                                   # strada della luna
		var y2 := 99 + k * 4
		ci.draw_rect(Rect2(118 + sin(time * 1.3 + k) * (2 + k * 0.4) - k * 0.3, y2, 6 + k * 0.6, 1), Color(1, 0.96, 0.8, 0.5 - k * 0.02))
	ci.draw_circle(Vector2(121, 34), 11, Color("f8f0d4"))
	for q in [[-4, -2, 3], [3, 4, 2], [4, -4, 1]]: ci.draw_circle(Vector2(121 + q[0], 34 + q[1]), q[2], Color("e0d4b4"))
	for b in [["boat0", 224.0], ["boat1", 284.0]]:
		var r: Array = G.J.sea.rects[b[0]]
		ci.draw_texture_rect_region(G.tex.sea_props, Rect2(roundf(b[1]), roundf(104 - float(r[3]) + 8 + sin(time * 1.2 + b[1])), r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), Color(0.6, 0.65, 0.9))

func _draw_light(ci: CanvasItem) -> void:
	Layer.glow(ci, Vector2(121, 34), 46, Color(1, 0.95, 0.8, 0.25))
	Layer.glow(ci, Vector2(11, 97), 34, Color(1, 0.8, 0.5, 0.4))

func _draw_front(ci: CanvasItem) -> void:
	P.dir = 1
	P.draw(ci, 126, 166)
	var tip := Vector2(172, 118)
	if state in ["wait", "bite"]:
		var dip := 4.0 + sin(time * 22) * 2 if state == "bite" else sin(time * 2) * 1.0
		var bob := HOOK + Vector2(0, dip)
		tip = Vector2(176, 122 + (3 if state == "bite" else 0))
		var mid := (tip + bob) / 2 + Vector2(0, 10 if state == "wait" else 2)
		var prev := tip
		for i in range(1, 13):
			var t := i / 12.0
			var p := tip.lerp(mid, t).lerp(mid.lerp(bob, t), t)
			ci.draw_line(prev, p, Color(0.9, 0.95, 1, 0.5))
			prev = p
		ci.draw_rect(Rect2(bob.x - 2, bob.y - 4, 4, 3), Color("d84840")); ci.draw_rect(Rect2(bob.x - 2, bob.y - 1, 4, 2), Color.WHITE)
	ci.draw_line(Vector2(140, 142), tip, Color("6a4630"), 2.0)
	ci.draw_line(Vector2(140, 141), tip + Vector2(0, -1), Color("a87848"))
	for r in rip:
		if r.t < 0: continue
		ci.draw_set_transform(HOOK, 0, Vector2(1, 0.35))
		ci.draw_arc(Vector2.ZERO, 3 + r.t * 16, 0, TAU, 24, Color(0.8, 0.9, 1, 0.5 * (1 - r.t / 1.6)))
		ci.draw_set_transform(Vector2.ZERO)
	var i := 0
	for k in ["fish0", "fish1", "fish2", "fish3"]:
		spr(ci, k, 226, 121 + i * 14, Color.WHITE if int(G.fish.get(k, 0)) > 0 else Color(0, 0, 0, 0.45))
		i += 1
	if state == "show":
		var kk := clampf(st / 0.5, 0, 1)
		spr(ci, got, lerpf(HOOK.x, 150, kk) - 12, lerpf(HOOK.y, 108, kk) - sin(kk * PI) * 30)
