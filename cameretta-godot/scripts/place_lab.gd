extends Place
## Il laboratorio: quattro esperienze di fisica, ognuna sul suo banco.

const SPOTS := [[90.0, "field"], [189.0, "foucault"], [314.0, "aurora"], [444.0, "photon"]]
var at := 30.0

func _enter() -> void:
	walking = true
	feet = 186.0
	world = 520.0
	P.x = at
	if at < 40: say(G.t("labHello"))

func _tick(_dt: float) -> void:
	for s in SPOTS:
		if absf(P.x - s[0]) < 34:
			prompt = {"x": s[0] - cam, "y": 84.0, "label": G.t("places")[s[1]], "action": func(): at = s[0]; goto.emit(s[1])}

func _draw_back(ci: CanvasItem) -> void:
	var c := roundf(cam)
	ci.draw_texture(G.tex.place_lab, Vector2(-c, 0))
	# il pendolo appeso al soffitto oscilla piano
	var a := sin(time * 1.5) * 0.16
	var top := Vector2(189 - c, 22)
	var bob := top + Vector2(sin(a), cos(a)) * 128
	ci.draw_line(top, bob, Color("a8b0c4"))
	ci.draw_circle(bob.round(), 5, Color("c8a050")); ci.draw_circle(bob.round() - Vector2(1.5, 1.5), 1.6, Color("fff0c0"))

func _draw_light(ci: CanvasItem) -> void:
	var c := cam
	for x in [31, 261, 491]: Layer.glow(ci, Vector2(x - c, 22), 60, Color(0.8, 0.95, 1, 0.16))
	Layer.glow(ci, Vector2(314 - c, 115), 26, Color(0.3, 1, 0.6, 0.18 + 0.06 * sin(time * 2)))
	Layer.glow(ci, Vector2(418 - c, 131), 8, Color(1, 0.3, 0.3, 0.6))

func _draw_front(ci: CanvasItem) -> void:
	P.draw(ci, P.x - cam, feet)
