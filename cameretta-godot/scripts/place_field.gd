extends Place
## Campi vivi: si posano cariche sulla neve e le linee di forza si disegnano da sole.

var Q: Array = []              # {p, q}
var sign := 1
var held := -1
var moved := false
var pot := false
var lines: Array = []
var _dirty := true

func _enter() -> void:
	dipole()
	say(G.t("fieldHello"))

func dipole() -> void:
	Q = [{"p": Vector2(110, 100), "q": 1}, {"p": Vector2(210, 100), "q": -1}]
	_dirty = true
	Sfx.move()

func clear() -> void:
	Q = []
	_dirty = true
	Sfx.toggle()

func flip_sign() -> void:
	sign = -sign
	Sfx.move()
	bar_changed.emit()

func flip_pot() -> void:
	pot = not pot
	_dirty = true
	Sfx.toggle()

func E_at(p: Vector2) -> Vector2:
	var e := Vector2.ZERO
	for c in Q:
		var d: Vector2 = p - c.p
		e += d * (c.q / pow(maxf(d.length_squared(), 4.0), 1.5))
	return e

func V_at(p: Vector2) -> float:
	var v := 0.0
	for c in Q: v += c.q / maxf((p - c.p).length(), 3.0)
	return v

func _near(p: Vector2) -> int:
	for i in Q.size(): if Q[i].p.distance_to(p) < 12: return i
	return -1

func hold(p: Vector2) -> void:
	held = _near(p)
	moved = false

func move_to(p: Vector2) -> void:
	if held < 0: return
	moved = true
	Q[held].p = Vector2(clampf(p.x, 8, 312), clampf(p.y, 22, 178))
	_dirty = true

func release() -> void:
	held = -1
	_dirty = true

func tap(p: Vector2) -> void:
	var i := _near(p)
	if i >= 0: Q.remove_at(i)
	elif Q.size() < 8: Q.append({"p": Vector2(clampf(p.x, 8, 312), clampf(p.y, 22, 178)), "q": sign})
	else:
		say(G.t("fieldFull"))
		return
	_dirty = true
	Sfx.step_snow()

func press(k: int) -> bool:
	match k:
		KEY_E, KEY_ENTER, KEY_SPACE: flip_sign()
		KEY_Q: dipole()
		KEY_X, KEY_BACKSPACE: clear()
		KEY_V: flip_pot()
		_: return false
	return true

func bar() -> Array:
	return [[G.t("fieldPlus") if sign > 0 else G.t("fieldMinus"), flip_sign], [G.t("fieldDip"), dipole], [G.t("fieldPot"), flip_pot], [G.t("fieldClear"), clear]]

func _trace() -> void:
	lines.clear()
	var n := 10 if held >= 0 else 16
	var plus := Q.filter(func(c): return c.q > 0)
	var from: Array = plus if not plus.is_empty() else Q
	for c in from:
		for k in n:
			var a := TAU * (k + 0.5) / n
			var p: Vector2 = c.p + Vector2(cos(a), sin(a)) * 5
			var pts: PackedVector2Array = [p]
			var s := 1.0 if c.q > 0 else -1.0
			for i in 150:
				var e := E_at(p)
				if e.length() < 1e-9: break
				var m := p + e.normalized() * s * 1.5
				var e2 := E_at(m)
				if e2.length() < 1e-9: break
				p += e2.normalized() * s * 3.0
				pts.append(p)
				if p.x < -20 or p.x > 340 or p.y < -20 or p.y > 220: break
				var hit := false
				for o in Q: if o.q * c.q < 0 and o.p.distance_to(p) < 5: hit = true
				if hit: break
			lines.append([pts, s])

func _tick(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_trace()
		if pot and held < 0: _potential()

func _draw_back(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 320, 200), Color("dfe6f6"))
	for k in 160: ci.draw_rect(Rect2((k * 53) % 320, (k * 97) % 200, 2 + k % 3, 1), Color("c6d0ea") if k % 2 else Color("eef3ff"))
	if pot and _ptex: ci.draw_texture_rect(_ptex, Rect2(0, 0, 320, 200), false)

var _ptex: ImageTexture
## Le curve equipotenziali: rosse dove V è positivo, azzurre dove è negativo.
func _potential() -> void:
	var im := Image.create(160, 100, false, Image.FORMAT_RGBA8)
	for y in 100:
		for x in 160:
			var v := V_at(Vector2(x * 2 + 1, y * 2 + 1)) * 60.0
			if absf(v) < 0.25: continue
			var f := absf(v) - floorf(absf(v))
			var w := clampf(0.06 + absf(v) * 0.045, 0.06, 0.4)
			if f < w: im.set_pixel(x, y, Color(0.86, 0.3, 0.26, 0.5) if v > 0 else Color(0.22, 0.42, 0.9, 0.5))
	_ptex = ImageTexture.create_from_image(im)

func _draw_light(_ci: CanvasItem) -> void: pass

func _draw_front(ci: CanvasItem) -> void:
	for l in lines:
		var pts: PackedVector2Array = l[0]
		if pts.size() < 2: continue
		ci.draw_polyline(pts, Color("7482b4"), 1.0)
		# granelli di limatura che scorrono lungo la linea
		var n := pts.size()
		for k in range(0, n, 16):
			var i := int(fposmod(k + time * 9.0 * l[1], n))
			ci.draw_rect(Rect2(pts[i].round(), Vector2(2, 2)), Color("2a2f5c"))
	for i in Q.size():
		var c: Dictionary = Q[i]
		var p: Vector2 = (c.p as Vector2).round()
		ci.draw_circle(p + Vector2(0, 1), 8, Color(0.2, 0.25, 0.45, 0.35))
		ci.draw_circle(p, 7, Color("18121e"))
		ci.draw_circle(p, 6, Color("d84a44") if c.q > 0 else Color("3f74d8"))
		ci.draw_rect(Rect2(p.x - 3, p.y - 0.5, 6, 1.5), Color.WHITE)
		if c.q > 0: ci.draw_rect(Rect2(p.x - 0.75, p.y - 3, 1.5, 6), Color.WHITE)
