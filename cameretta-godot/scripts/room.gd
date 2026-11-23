extends Node2D
## La cameretta. Due modalità: "point" (punta e clicca) e "walk" (l'omino cammina sul pavimento in prospettiva).

signal open_section(id: String)
signal hover_changed(id: String)

var mask := PackedByteArray()
var dims: Dictionary = {}
var rings: Dictionary = {}
var boxes: Dictionary = {}
var hover := ""
var time := 0.0
var rsteam: Array = []
var P: Player
var py := 180.0
var input_dir := Vector2i.ZERO
var run := false
var locked := false
var prompt: Dictionary = {}
var walk_target := Vector2(-1, -1)
var walk_goal := ""
var base_l: Layer
var glow_l: Layer
var top_l: Layer

# pavimento percorribile (trapezio in prospettiva)
const FY0 := 140.0
const FY1 := 196.0

func _ready() -> void:
	P = Player.new()
	base_l = Layer.make(self, _draw_base)
	glow_l = Layer.make(self, _draw_glow, true)
	top_l = Layer.make(self, _draw_top)

func build() -> void:
	var img: Image = G.tex.mask.get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != 320 or img.get_height() != 200: img.resize(320, 200, Image.INTERPOLATE_NEAREST)
	mask.resize(320 * 200)
	for y in 200:
		for x in 320:
			mask[y * 320 + x] = int(roundf(img.get_pixel(x, y).r * 255))
	boxes.clear(); dims.clear(); rings.clear()
	var dimg := {}
	var rimg := {}
	var acc := {}
	for gi in G.GROUPS.size():
		var d := Image.create(320, 200, false, Image.FORMAT_RGBA8)
		d.fill(Color8(10, 8, 24, 105))
		dimg[gi + 1] = d
		rimg[gi + 1] = Image.create(320, 200, false, Image.FORMAT_RGBA8)
		acc[gi + 1] = {"x0": 320, "y0": 200, "x1": -1, "y1": -1, "xs": []}
	var ring := Color8(255, 232, 160, 255)
	var clear := Color(0, 0, 0, 0)
	for y in 200:
		for x in 320:
			var v := mask[y * 320 + x]
			if v < 1 or v > 5: continue
			var A: Dictionary = acc[v]
			A.x0 = mini(A.x0, x); A.x1 = maxi(A.x1, x); A.y0 = mini(A.y0, y); A.y1 = maxi(A.y1, y)
			if A.xs.size() < 6000: A.xs.append(x)
			dimg[v].set_pixel(x, y, clear)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var xx := x + dx; var yy := y + dy
					if xx >= 0 and yy >= 0 and xx < 320 and yy < 200 and mask[yy * 320 + xx] != v:
						rimg[v].set_pixel(xx, yy, ring)
	for gi in G.GROUPS.size():
		var A: Dictionary = acc[gi + 1]
		if A.x1 < 0: continue
		var xs: Array = A.xs
		xs.sort()
		var g: String = G.GROUPS[gi]
		boxes[g] = {"x0": A.x0, "y0": A.y0, "x1": A.x1, "y1": A.y1, "cx": xs[xs.size() >> 1]}
		dims[g] = ImageTexture.create_from_image(dimg[gi + 1])
		rings[g] = ImageTexture.create_from_image(rimg[gi + 1])

func order() -> Array:
	var a := G.GROUPS.filter(func(g): return G.by_id.has(g) and boxes.has(g))
	a.sort_custom(func(a1, b1): return boxes[a1].cx < boxes[b1].cx)
	return a

func group_at(p: Vector2) -> String:
	var x := int(floor(p.x)); var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= 320 or y >= 200: return ""
	var v := mask[y * 320 + x]
	if v < 1 or v > 5: return ""
	var g: String = G.GROUPS[v - 1]
	return g if G.by_id.has(g) and boxes.has(g) else ""

func set_hover(g: String) -> void:
	if g == hover: return
	hover = g
	if g != "": Sfx.hover()
	hover_changed.emit(g)

# ------------------------------------------------------------------ modalità cammina
static func floor_x(y: float) -> Vector2:
	var t := clampf((y - FY0) / (FY1 - FY0), 0, 1)
	return Vector2(lerpf(128, 66, t), lerpf(190, 202, t))

static func depth(_y: float) -> float:
	# stessa misura dappertutto (sprite x1.5), anche in cameretta
	return 1.0

func stand_point(g: String) -> Vector2:
	var b: Dictionary = boxes[g]
	var y := clampf(float(b.y1) + 4, FY0, FY1)
	var fx := floor_x(y)
	return Vector2(clampf(float(b.cx), fx.x + 4, fx.y - 4), y)

func enter() -> void:
	P = Player.new()
	P.x = 150
	py = 190
	P.dir = 1
	walk_target = Vector2(-1, -1)
	walk_goal = ""
	prompt = {}

func update(dt: float) -> void:
	time += dt
	if G.room_mode == "walk":
		_update_walk(dt)
	else:
		prompt = {}
	base_l.queue_redraw(); glow_l.queue_redraw(); top_l.queue_redraw()

func _update_walk(dt: float) -> void:
	var v := Vector2(input_dir)
	if v != Vector2.ZERO:
		walk_target = Vector2(-1, -1)
		walk_goal = ""
	elif walk_target.x >= 0:
		var d := walk_target - Vector2(P.x, py)
		if d.length() < 1.5:
			walk_target = Vector2(-1, -1)
			if walk_goal != "":
				var g := walk_goal
				walk_goal = ""
				P.dir = 1 if boxes[g].cx >= P.x else -1
				open_section.emit(g)
		else:
			v = d.normalized()
	var sc := depth(py)
	P.moving = false
	if v != Vector2.ZERO and not locked:
		if v.x != 0: P.dir = 1 if v.x > 0 else -1
		var sp := (Player.RUN if run else Player.WALK) * sc
		var ny := clampf(py + v.normalized().y * sp * 0.55 * dt, FY0, FY1)
		var fx := floor_x(ny)
		var nx := clampf(P.x + v.normalized().x * sp * dt, fx.x, fx.y)
		if absf(nx - P.x) > 0.001 or absf(ny - py) > 0.001:
			P.moving = true
			P.x = nx; py = ny
		elif walk_target.x >= 0:
			walk_target = Vector2(-1, -1)
			if walk_goal != "":
				var g2 := walk_goal
				walk_goal = ""
				open_section.emit(g2)
	P.animate(dt, run, Sfx.step_wood)
	# oggetto più vicino
	var best := ""
	var bd := 26.0
	for g in order():
		var sp2 := stand_point(g)
		var dd := Vector2(P.x, py).distance_to(sp2)
		if dd < bd:
			bd = dd; best = g
	set_hover(best)
	if best != "":
		var s = G.by_id[best]
		prompt = {"x": P.x, "y": py - (float(G.J.player.fh) + 4) * sc, "label": G.t("open") + ": " + G.L(s, "object_name"), "action": func(): open_section.emit(best)}
	else:
		prompt = {}

func walk_to(g: String) -> void:
	walk_target = stand_point(g)
	walk_goal = g

func tap(p: Vector2) -> void:
	if G.room_mode != "walk": return
	var g := group_at(p)
	if g != "":
		walk_to(g)
	else:
		var y := clampf(p.y, FY0, FY1)
		var fx := floor_x(y)
		walk_target = Vector2(clampf(p.x, fx.x, fx.y), y)
		walk_goal = ""

# ------------------------------------------------------------------ disegno
const BULB := [Color("ffdc8c"), Color("ffc86e"), Color("ffecaa"), Color("ffbe78")]

func _draw_base(ci: CanvasItem) -> void:
	ci.draw_texture(G.tex.room, Vector2.ZERO)
	var an: Dictionary = G.J.anim
	if G.default_room and not an.is_empty():
		for b in an.bulbs:
			var a := maxf(0.35, 0.62 + 0.38 * sin(time / 0.42 + float(b[0]) * 0.35 + float(b[2])))
			var c: Color = BULB[int(b[2]) % 4]
			c.a = a
			ci.draw_rect(Rect2(b[0], b[1], 1, 1), c)
		var i := 0
		for st in an.stars:
			var s := sin(time / 0.7 + i * 2.3)
			if s < -0.5: ci.draw_rect(Rect2(st[0], st[1], 1, 1), Color("1e2a60"))
			elif s > 0.8: ci.draw_rect(Rect2(st[0], st[1], 1, 1), Color.WHITE)
			i += 1
		if int(time / 0.5) % 2 == 1:
			ci.draw_rect(Rect2(roundf(an.cursor[0]), roundf(an.cursor[1]), 1, 2), Color("f0d6a0"))
		var m: Array = an.mug
		if rsteam.size() < 7 and randf() < 0.25: rsteam.append({"y": 0.0, "p": randf() * 6})
		for p in rsteam:
			p.y += 0.5
			ci.draw_rect(Rect2(roundf(m[0] + sin(p.y / 2.5 + p.p) * 1.3), roundf(m[1] - 2 - p.y), 1, 1), Color(0.98, 0.98, 1, maxf(0, 1 - p.y / 16) * 0.8))
		rsteam = rsteam.filter(func(p): return p.y < 16)
	if G.default_room: Shop.draw_room_items(ci, time)
	if hover != "" and dims.has(hover):
		ci.draw_texture(dims[hover], Vector2.ZERO)
		ci.draw_texture(rings[hover], Vector2.ZERO)

func _draw_glow(ci: CanvasItem) -> void:
	var an: Dictionary = G.J.anim
	if G.default_room and not an.is_empty():
		var fl := 0.10 + 0.025 * sin(time / 0.19) + (0.03 if randf() < 0.04 else 0.0)
		Shop.draw_room_glow(ci, time)
		Layer.glow(ci, Vector2(an.lamp[0], an.lamp[1]), 46, Color(1, 0.84, 0.55, fl * 1.6))

func _draw_top(ci: CanvasItem) -> void:
	# segnalini sugli oggetti (verde = già visto)
	for g in order():
		if g == hover: continue
		var b: Dictionary = boxes[g]
		var x := int(b.cx)
		var y := maxi(8, int(b.y0) - 7) + int(roundf(sin(time * 3 + x) * 1.0))
		var col: Color = G.C_SAGE if G.explored.has(g) else G.gold
		_diamond(ci, x, y, col)
	if G.room_mode == "walk":
		var sc := depth(py)
		P.draw(ci, P.x, py, Color(0.16, 0.08, 0.04, 0.35), sc)

func _diamond(ci: CanvasItem, x: int, y: int, col: Color) -> void:
	var ink := G.C_INK
	ci.draw_rect(Rect2(x, y - 2, 1, 5), ink)
	ci.draw_rect(Rect2(x - 2, y, 5, 1), ink)
	ci.draw_rect(Rect2(x - 1, y - 1, 3, 3), ink)
	ci.draw_rect(Rect2(x, y - 1, 1, 3), col)
	ci.draw_rect(Rect2(x - 1, y, 3, 1), col)
