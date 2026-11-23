extends Place
## Il faro di Livorno visto dall'alto: due lampade, un mare di onde, e le frange dell'interferenza.

var lam := 16.0
var sep := 48.0
var two := true
var quad: ColorRect
const SH := """shader_type canvas_item;
uniform float lam = 16.0; uniform float sep = 48.0; uniform float two = 1.0; uniform float t = 0.0;
void fragment(){
	vec2 p = floor(UV * vec2(320.0, 200.0)) + 0.5;
	float k = 6.28318 / lam;
	vec2 s1 = vec2(46.0, 96.0 - sep * 0.5), s2 = vec2(46.0, 96.0 + sep * 0.5);
	if (two < 0.5) { s1 = vec2(46.0, 96.0); }
	float r1 = distance(p, s1), r2 = distance(p, s2);
	float a1 = 1.0 / sqrt(1.0 + r1 * 0.012), a2 = two / sqrt(1.0 + r2 * 0.012);
	float w = a1 * cos(k * r1 - t * 5.0) + a2 * cos(k * r2 - t * 5.0);
	// intensità media nel tempo: |a1 e^{ikr1} + a2 e^{ikr2}|^2
	vec2 z = a1 * vec2(cos(k * r1), sin(k * r1)) + a2 * vec2(cos(k * r2), sin(k * r2));
	float I = dot(z, z);
	vec3 sea = mix(vec3(0.03, 0.06, 0.2), vec3(0.95, 0.86, 0.55), clamp(0.3 + 0.34 * w, 0.0, 1.0) * clamp(0.22 + I * 0.5, 0.0, 1.0));
	if (p.x > 286.0) {
		float m = p.x - 288.0;
		float b = clamp(I * 0.55, 0.0, 1.0);
		sea = m < 0.0 ? vec3(0.1, 0.1, 0.22) : m < 20.0 ? mix(vec3(0.02, 0.02, 0.07), vec3(1.0, 0.93, 0.62), b) : vec3(0.03, 0.04, 0.12);
	}
	sea = floor(sea * 14.0 + 0.5) / 14.0;
	COLOR = vec4(sea, 1.0);
}"""

func _ready() -> void:
	quad = ColorRect.new()
	quad.size = Vector2(320, 200)
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = SH
	quad.material = m
	add_child(quad)
	super()

func _enter() -> void:
	lam = 16.0; sep = 48.0; two = true
	say(G.t("lightHello"))

func _tick(dt: float) -> void:
	if not locked:
		lam = clampf(lam + input_dir * dt * 9.0, 8, 34)
		sep = clampf(sep - input_up * dt * 34.0, 10, 110)
	var m: ShaderMaterial = quad.material
	m.set_shader_parameter("lam", lam); m.set_shader_parameter("sep", sep); m.set_shader_parameter("two", 1.0 if two else 0.0); m.set_shader_parameter("t", time)

func press(k: int) -> bool:
	if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		flip()
		return true
	return k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_A, KEY_D, KEY_W, KEY_S]

func flip() -> void:
	two = not two
	Sfx.toggle()
	say(G.t("lightTwo" if two else "lightOne"))
	bar_changed.emit()

func _add(dl: float, ds: float) -> void:
	lam = clampf(lam + dl, 8, 34); sep = clampf(sep + ds, 10, 110)
	Sfx.move()

func bar() -> Array:
	return [[G.t("lightW") + " −", _add.bind(-2, 0)], [G.t("lightW") + " +", _add.bind(2, 0)], [G.t("lightD") + " −", _add.bind(0, -8)], [G.t("lightD") + " +", _add.bind(0, 8)], [G.t("lightB1") if two else G.t("lightB2"), flip]]

func tap(_p: Vector2) -> void: flip()

## Distanza tra due frange sullo schermo: λ·L/d.
func fringe() -> float:
	return lam * 242.0 / sep

func labels() -> Array:
	var o := [{"x": 84 if tall else 110, "y": 166, "t": "%s %d · %s %d" % [G.t("lightW").to_lower(), int(lam), G.t("lightD").to_lower(), int(sep)], "c": G.gold, "s": 28}]
	if two: o.append({"x": 172 if tall else 236, "y": 166, "t": "%s %d" % [G.t("lightF"), int(fringe())], "c": Color("ffeeb0"), "s": 28})
	return o

func _draw_light(ci: CanvasItem) -> void:
	for y in ([96.0 - sep / 2, 96.0 + sep / 2] if two else [96.0]): Layer.glow(ci, Vector2(46, y), 18, Color(1, 0.9, 0.55, 0.7))

func _draw_front(ci: CanvasItem) -> void:
	for y in ([96.0 - sep / 2, 96.0 + sep / 2] if two else [96.0]):
		ci.draw_circle(Vector2(46, y), 4, Color("c43840")); ci.draw_circle(Vector2(46, y), 2, Color("fff6d0"))
	# scogliera e lanterna
	ci.draw_rect(Rect2(0, 0, 14, 200), Color("1a1c30"))
	for y in range(0, 200, 7): ci.draw_rect(Rect2(14, y, 2 + (y * 5) % 9, 6), Color("1a1c30"))
	if two and sep > 12:
		ci.draw_line(Vector2(30, 96 - sep / 2), Vector2(30, 96 + sep / 2), Color(1, 0.85, 0.5, 0.7))
		for s in [-1, 1]: ci.draw_line(Vector2(27, 96 + s * sep / 2), Vector2(33, 96 + s * sep / 2), Color(1, 0.85, 0.5, 0.7))
