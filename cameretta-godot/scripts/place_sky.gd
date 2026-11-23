extends Place
## L'osservatorio: il cielo vero di Rosignano, adesso (o stasera, se è giorno).

var sky: Dictionary = {}
var az := 180.0
var alt := 35.0
var fov := 95.0
var t0 := 0.0                  # istante di partenza (tempo Unix)
var off := 0.0                 # ore spostate a mano
var lines_on := true
var sel: Dictionary = {}
var tonight := false
var _v: PackedVector3Array = []
var _lv: Array = []
var _cv: PackedVector3Array = []
var _bodies: Array = []
var _built := -1e9
var _pts: PackedVector2Array = []
var _view := Vector4.ZERO
var _sun := -90.0
var f := Vector3.ZERO
var r := Vector3.ZERO
var u := Vector3.ZERO
var k := 1.0

const COL := {"mercurio": "c8b8a8", "venere": "fff6d8", "marte": "ff9a6a", "giove": "ffe6c0", "saturno": "f2d890"}

func _enter() -> void:
	if sky.is_empty(): sky = JSON.parse_string(FileAccess.get_file_as_string("res://store/sky.json"))
	t0 = Time.get_unix_time_from_system()
	off = 0.0; sel = {}
	az = 180.0; alt = 35.0; fov = 95.0
	# di giorno si aspetta il buio
	tonight = false
	for i in 200:
		if _sun_alt(t0) < -13.0: break
		t0 += 600.0
		tonight = true
	_built = -1e9
	# si guarda dove c'è qualcosa di bello: un pianeta alto, o la Luna
	_compute()
	var best := 12.0
	for b in _bodies:
		if b.id != "sole" and b.h.y > best:
			best = b.h.y
			az = b.h.x
			alt = clampf(b.h.y, 22, 60)
	say(G.t("skyHello"))

func _sun_alt(t: float) -> float:
	var s := Astro.sun(t)
	return Astro.horiz(s.x, s.y, Astro.lst(t)).y

func now() -> float:
	return t0 + off * 3600.0

static func vec(h: Vector2) -> Vector3:
	var a := deg_to_rad(h.x)
	var b := deg_to_rad(h.y)
	return Vector3(sin(a) * cos(b), cos(a) * cos(b), sin(b))    # est, nord, zenit

func _compute() -> void:
	var t := now()
	if absf(t - _built) < 20.0: return
	_built = t
	var sid := Astro.lst(t)
	_v.clear(); _lv.clear(); _cv.clear(); _bodies.clear()
	for s in sky.stars:
		var q := Astro.precess(s[0], s[1], t)
		_v.append(vec(Astro.horiz(q.x, q.y, sid)))
	for seg in sky.lines:
		var a: PackedVector3Array = []
		for p in seg: a.append(vec(Astro.horiz(p[0], p[1], sid)))
		_lv.append(a)
	for c in sky.cons: _cv.append(vec(Astro.horiz(c[2], c[3], sid)))
	var sn := Astro.sun(t)
	var sh := Astro.horiz(sn.x, sn.y, sid)
	_sun = sh.y
	_bodies.append({"id": "sole", "h": sh, "v": vec(sh)})
	var m := Astro.moon(t)
	var mh := Astro.horiz(m[0], m[1], sid)
	mh.y -= 0.95 * cos(deg_to_rad(mh.y))           # parallasse
	_bodies.append({"id": "luna", "h": mh, "v": vec(mh), "ph": m[2], "wax": m[3]})
	for id in Astro.EL:
		var p := Astro.planet(id, t)
		var h := Astro.horiz(p.x, p.y, sid)
		_bodies.append({"id": id, "h": h, "v": vec(h)})
	_view = Vector4.ZERO

func _camera() -> void:
	f = vec(Vector2(az, alt))
	r = vec(Vector2(az + 90.0, 0))
	u = r.cross(f)
	k = 80.0 / tan(deg_to_rad(fov / 4.0))

func proj(v: Vector3) -> Vector2:
	var d := 1.0 + v.dot(f)
	if d < 0.15: return Vector2(-999, -999)
	return Vector2(160.0 + k * v.dot(r) / d, 100.0 - k * v.dot(u) / d)

func _tick(dt: float) -> void:
	var sp := fov * 0.5 * dt * (2.0 if run else 1.0)
	if not locked:
		az = fposmod(az + input_dir * sp, 360.0)
		alt = clampf(alt - input_up * sp, 4, 86)
	if not G.is_web or int(time * 2) % 2 == 0: _compute()
	_camera()
	var nv := Vector4(az, alt, fov, _built)
	if nv != _view:
		_view = nv
		_pts.resize(_v.size())
		for i in _v.size(): _pts[i] = proj(_v[i])

func press(key: int) -> bool:
	match key:
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: pick(Vector2(160, 100))
		KEY_Q: shift(-1)
		KEY_R: shift(1)
		KEY_L: lines_on = not lines_on; Sfx.toggle()
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD: zoom(1)
		KEY_MINUS, KEY_KP_SUBTRACT: zoom(-1)
		_: return false
	return true

func shift(h: float) -> void:
	off = 0.0 if h == 0 else off + h
	Sfx.move()
	_built = -1e9
	bar_changed.emit()

func zoom(d: float) -> void: fov = clampf(fov * (0.86 if d > 0 else 1.16), 22, 130)

func drag(rel: Vector2) -> void:
	az = fposmod(az - rel.x * fov / 330.0, 360.0)
	alt = clampf(alt + rel.y * fov / 330.0, 4, 86)

func tap(p: Vector2) -> void: pick(p)

func pick(p: Vector2) -> void:
	var bd := 15.0
	sel = {}
	for b in _bodies:
		var d := proj(b.v).distance_to(p) - 5.0
		if b.h.y > -1 and d < bd: bd = d; sel = {"b": b, "n": G.t("skyBodies")[b.id]}
	for i in _v.size():
		if sky.stars[i][4] == "" or _v[i].z < -0.01: continue
		var d2 := _pts[i].distance_to(p)
		if d2 < bd: bd = d2; sel = {"i": i, "n": sky.stars[i][4]}
	if sel.is_empty():
		say(G.t("skyNone"))
		return
	Sfx.select()
	var v: Vector3 = sel.b.v if sel.has("b") else _v[sel.i]
	var a := rad_to_deg(asin(v.z))
	var z := fposmod(rad_to_deg(atan2(v.x, v.y)), 360.0)
	var dirs: Array = G.t("skyDirs")
	var what: String = G.t("skyWhat")[sel.b.id] if sel.has("b") else G.t("skyStar") % sky.stars[sel.i][2]
	if sel.has("b") and sel.b.id == "luna": what = what % int(round(sel.b.ph * 100))
	say("%s. %s %s" % [sel.n, what, G.t("skyWhere") % [dirs[int(round(z / 45.0)) % 8], int(round(a))]])

func bar() -> Array:
	return [["◀ 1 h", shift.bind(-1)], [G.t("skyNow"), shift.bind(0)], ["1 h ▶", shift.bind(1)], ["+", zoom.bind(1)], ["−", zoom.bind(-1)], [G.t("skyLines"), func(): lines_on = not lines_on; Sfx.toggle()]]

func clock() -> String:
	var bias: int = Time.get_time_zone_from_system().bias
	var d := Time.get_datetime_dict_from_unix_time(int(now()) + bias * 60)
	return "%02d/%02d/%d  %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]

func labels() -> Array:
	var o: Array = []
	o.append({"x": 160 if tall else 206, "y": 34, "t": ("%s · " % G.t("skyTonight") if tonight and off == 0 else "") + clock() + " · Rosignano", "c": G.gold, "s": 26})
	var dirs: Array = G.t("skyDirs")
	for i in 8:
		var p := proj(vec(Vector2(i * 45.0, 0)))
		if p.x > 4 and p.x < 316 and p.y > 8 and p.y < 158 and not (p.x > 225 and p.y > 110): o.append({"x": p.x, "y": p.y + 5, "t": str(dirs[i]).to_upper(), "c": Color("f2b85b") if i % 2 == 0 else Color("a89878"), "s": 24})
	for b in _bodies:
		var p2 := proj(b.v)
		if b.h.y > 0 and _in(p2): o.append({"x": p2.x, "y": p2.y - 13, "t": G.t("skyBodies")[b.id], "c": Color("ffe6c0"), "s": 24})
	if lines_on and fov < 125:
		for i in _cv.size():
			if o.size() > 26: break
			if int(sky.cons[i][4]) > (1 if fov > 80 else 3) or _cv[i].z < 0.05: continue
			var p3 := proj(_cv[i])
			if _in(p3): o.append({"x": p3.x, "y": p3.y, "t": str(sky.cons[i][0 if G.lang == "it" else 1]).to_upper(), "c": Color(0.6, 0.7, 1, 0.75), "s": 20})
	if sel.has("i"):
		var p4 := _pts[sel.i]
		if _in(p4): o.append({"x": p4.x, "y": p4.y - 11, "t": sel.n, "c": Color.WHITE, "s": 24})
	return o

func _in(p: Vector2) -> bool:
	return p.x > 12 and p.x < 308 and p.y > 42 and p.y < 160

func _draw_back(ci: CanvasItem) -> void:
	var tw := clampf((_sun + 16.0) / 16.0, 0, 1)
	var top := Color("070a24").lerp(Color("2a4a90"), tw)
	var low := Color("1c2450").lerp(Color("e0a070"), tw)
	for y in range(0, 200, 4): ci.draw_rect(Rect2(0, y, 320, 4), top.lerp(low, y / 200.0))
	if lines_on:
		for seg in _lv:
			var a := Vector2(-999, 0)
			for v in seg:
				var b := proj(v)
				if a.x > -60 and b.x > -60 and a.x < 380 and b.x < 380 and a.distance_to(b) < 160: ci.draw_line(a, b, Color(0.45, 0.58, 1, 0.2 * (1 - tw)))
				a = b

func _draw_light(ci: CanvasItem) -> void:
	var dim := 1.0 - clampf((_sun + 14.0) / 12.0, 0, 1)
	for i in _pts.size():
		var p := _pts[i]
		if p.x < -2 or p.x > 322 or p.y < -2 or p.y > 202: continue
		var m: float = sky.stars[i][2]
		if m > 3.6 + (95.0 - fov) / 40.0 + 0.8: continue
		var bv: float = sky.stars[i][3]
		var c := Color("a8c4ff").lerp(Color("ffffff"), clampf(bv / 0.5, 0, 1)) if bv < 0.5 else Color("ffffff").lerp(Color("ffb070"), clampf((bv - 0.5) / 1.1, 0, 1))
		var a := clampf(1.45 - m * 0.2, 0.3, 1) * dim * (0.82 + 0.18 * sin(time * 5 + i * 1.7))
		p = p.round()
		ci.draw_rect(Rect2(p, Vector2.ONE), Color(c, a))
		if m < 2.3:
			for q in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: ci.draw_rect(Rect2(p + q, Vector2.ONE), Color(c, a * (0.8 if m < 0.8 else 0.5 if m < 1.6 else 0.25)))
			Layer.glow(ci, p, maxf(3.0, 8.0 - m * 2.0), Color(c, 0.35 * a))

func _draw_front(ci: CanvasItem) -> void:
	for b in _bodies:
		var p := proj(b.v).round()
		if b.id == "luna": _moon(ci, p, b)
		elif b.id == "sole":
			ci.draw_circle(p, 6, Color("fff2c0"))
		else:
			var big := 2.0 if b.id in ["venere", "giove"] else 1.0
			ci.draw_circle(p + Vector2(0.5, 0.5), big + 0.6, Color(COL[b.id]))
			if b.id == "saturno": ci.draw_line(p + Vector2(-4, 1), p + Vector2(5, -1), Color("f2d890"))
	# l'orizzonte: mare a ovest, colline a est
	var up: PackedVector2Array = []
	for i in range(-40, 41):
		var a := az + i * 2.6
		var sea := fposmod(a, 360.0) > 195 and fposmod(a, 360.0) < 345
		var h := 0.0 if sea else 1.2 + 1.1 * sin(deg_to_rad(a * 3.0)) + 0.7 * sin(deg_to_rad(a * 7.0 + 40))
		var p := proj(vec(Vector2(a, h)))
		if p.x > -900: up.append(p)
	if up.size() > 2:
		var poly := up.duplicate()
		poly.append(Vector2(maxf(330, up[up.size() - 1].x), 420)); poly.append(Vector2(minf(-10, up[0].x), 420))
		ci.draw_colored_polygon(poly, Color("0a0e22"))
		ci.draw_polyline(up, Color(0.4, 0.5, 0.8, 0.5))
	# mirino
	for q in [[Vector2(-7, 0), Vector2(-4, 0)], [Vector2(4, 0), Vector2(7, 0)], [Vector2(0, -7), Vector2(0, -4)], [Vector2(0, 4), Vector2(0, 7)]]:
		ci.draw_line(Vector2(160, 100) + q[0], Vector2(160, 100) + q[1], Color(1, 0.8, 0.4, 0.6))
	if not sel.is_empty():
		var ps: Vector2 = proj(sel.b.v) if sel.has("b") else _pts[sel.i]
		ci.draw_arc(ps, 8 + sin(time * 4), 0, TAU, 20, Color(1, 0.8, 0.4, 0.8))
	# il telescopio e l'omino, in controluce sul terrazzo
	ci.draw_rect(Rect2(0, 190, 320, 10), Color("05070f"))
	Shop.spr(ci, "an_telescopio", Vector2(266, 126))
	P.dir = 1; P.frame = 0
	P.draw(ci, 250, 196)

func _moon(ci: CanvasItem, p: Vector2, b: Dictionary) -> void:
	if p.x < -20: return
	var R := 7.0
	for y in range(-7, 8):
		var w := sqrt(maxf(0, R * R - y * y))
		ci.draw_rect(Rect2(p.x - roundf(w), p.y + y, roundf(w) * 2 + 1, 1), Color("2a3050"))
		var lit: float = 2.0 * w * float(b.ph)
		var x0 := p.x + w - lit if b.wax else p.x - w
		ci.draw_rect(Rect2(roundf(x0), p.y + y, maxf(0, roundf(lit)), 1), Color("f6f0d8"))
