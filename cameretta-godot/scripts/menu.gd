extends Node2D
## Cielo del menu: stelle che brillano, finestra accesa che tremola, stelle cadenti.

var time := 0.0
var shooting = null
var base_l: Layer
var fx_l: Layer

func _ready() -> void:
	base_l = Layer.make(self, _draw_base)
	fx_l = Layer.make(self, _draw_fx, true)

func update(dt: float) -> void:
	time += dt
	if str(G.S.get("menu_shooting_stars", "1")) != "0":
		if shooting == null and randf() < 0.006 * dt * 60:
			shooting = {"x": randf_range(80, 280), "y": randf_range(6, 56), "l": 0.0}
		if shooting != null:
			shooting.l += dt * 60
			if shooting.l > 26: shooting = null
	base_l.queue_redraw(); fx_l.queue_redraw()

func _draw_base(ci: CanvasItem) -> void:
	if G.custom_sky: return
	ci.draw_texture(G.tex.menu_sky, Vector2.ZERO)
	var ma: Dictionary = G.J.menu
	var i := 0
	for st in ma.stars:
		var k: int = st[2]
		if k != 0:
			var tw := sin(time / 0.6 + i * 1.7)
			var x: float = st[0]
			var y: float = st[1]
			if tw > 0.55:
				var c := Color("fffbe6")
				ci.draw_rect(Rect2(x - 1, y, 3, 1), c); ci.draw_rect(Rect2(x, y - 1, 1, 3), c)
				if k == 2 and tw > 0.85:
					ci.draw_rect(Rect2(x - 2, y, 5, 1), c); ci.draw_rect(Rect2(x, y - 2, 1, 5), c)
			elif tw < -0.6:
				ci.draw_rect(Rect2(x, y, 1, 1), Color(0.06, 0.06, 0.15, 0.75))
		i += 1

func _draw_fx(ci: CanvasItem) -> void:
	if not G.custom_sky:
		var w: Array = G.J.menu.window
		var f := 0.10 + 0.06 * sin(time / 0.3) + (0.08 if randf() < 0.03 else 0.0)
		ci.draw_rect(Rect2(float(w[0]) - 2, float(w[1]) - 2, float(w[2]) - float(w[0]) + 4, float(w[3]) - float(w[1]) + 4), Color(1, 0.86, 0.55, f))
		Layer.glow(ci, Vector2((float(w[0]) + float(w[2])) / 2, (float(w[1]) + float(w[3])) / 2), 30, Color(1, 0.8, 0.5, f * 0.8))
	if shooting != null:
		var l: float = shooting.l
		for k in 10:
			ci.draw_rect(Rect2(roundf(shooting.x + l * 3 - k * 2), roundf(shooting.y + l * 1.4 - k * 0.9), 1, 1), Color(1, 0.97, 0.86, 1.0 - k / 10.0))

func on_window(p: Vector2) -> bool:
	if G.custom_sky: return false
	var w: Array = G.J.menu.window
	return p.x > float(w[0]) - 8 and p.x < float(w[2]) + 8 and p.y > float(w[1]) - 8 and p.y < float(w[3]) + 8
