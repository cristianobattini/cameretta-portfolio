class_name Player
extends RefCounted
## L'omino: felpa nera, sciarpa e pantaloni larghi. 10 frame da 24x42 (0-3 fermo, 4-9 cammina).

const WALK := 41.0
const RUN := 69.0

var x := 40.0
var dir := 1
var moving := false
var anim := 0.0
var idle := 0.0
var frame := 0
var last_step := -1
var target := -1.0            # punto toccato/cliccato verso cui camminare
var on_arrive: Callable       # azione da fare all'arrivo (cameretta, modalità cammina)

func update(dt: float, input_dir: int, run: bool, min_x: float, max_x: float, step_sound: Callable, locked := false) -> void:
	var d := input_dir
	if d != 0:
		target = -1.0
		on_arrive = Callable()
	elif target >= 0:
		if absf(target - x) < 2.0:
			target = -1.0
			if on_arrive.is_valid():
				var cb := on_arrive
				on_arrive = Callable()
				cb.call()
		else:
			d = int(signf(target - x))
	var J: Dictionary = G.J.player
	if d != 0 and not locked:
		dir = d
		moving = true
		var nx := clampf(x + d * (RUN if run else WALK) * dt, min_x, max_x)
		if is_equal_approx(nx, x):
			moving = false
			if target >= 0 and on_arrive.is_valid():
				var cb2 := on_arrive
				on_arrive = Callable()
				cb2.call()
			target = -1.0
		else:
			x = nx
	else:
		moving = false
	animate(dt, run, step_sound)

func animate(dt: float, run: bool, step_sound: Callable) -> void:
	var J: Dictionary = G.J.player
	if moving:
		anim += dt * (10.0 if run else 6.7)
		var f := int(anim) % 6
		if f != last_step and (f == 2 or f == 5): step_sound.call()
		last_step = f
		frame = int(J.walk[f])
	else:
		idle += dt * 3.0
		last_step = -1
		frame = int(J.idle[int(idle) % 4])

func draw(ci: CanvasItem, sx: float, feet: float, shadow := Color(0.08, 0.09, 0.24, 0.35), sc := 1.0) -> void:
	var J: Dictionary = G.J.player
	var fw: int = J.fw
	var fh: int = J.fh
	# ombra
	var rw := int(roundf(8 * sc * float(G.J.player.get("scale", 1.0))))
	for k in range(-rw, rw + 1):
		var hh := 2.0 * sc * sqrt(maxf(0.0, 1.0 - pow(float(k) / rw, 2)))
		ci.draw_rect(Rect2(roundf(sx) + k, feet + 1 - roundf(hh * 0.5), 1, maxf(1.0, roundf(hh))), shadow)
	var src := Rect2(frame * fw, 0, fw, fh)
	var px := roundf(sx - fw * sc / 2.0)
	var py := roundf(feet - float(J.footY) * sc)
	if dir < 0:
		ci.draw_set_transform(Vector2(px + fw * sc, py), 0.0, Vector2(-sc, sc))
	else:
		ci.draw_set_transform(Vector2(px, py), 0.0, Vector2(sc, sc))
	ci.draw_texture_rect_region(G.tex.player, Rect2(0, 0, fw, fh), src)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
