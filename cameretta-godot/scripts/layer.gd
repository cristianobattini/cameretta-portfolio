class_name Layer
extends Node2D
## Livello di disegno: chiama una funzione esterna in _draw. additive=true per luci e bagliori.

var fn: Callable
static var _glow: GradientTexture2D

static func make(parent: Node, f: Callable, additive := false) -> Layer:
	var l := Layer.new()
	l.fn = f
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = m
	parent.add_child(l)
	return l

func _draw() -> void:
	if fn.is_valid(): fn.call(self)

## Alone radiale morbido (centro c, raggio r).
static func glow(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.42))
		_glow = GradientTexture2D.new()
		_glow.gradient = g
		_glow.fill = GradientTexture2D.FILL_RADIAL
		_glow.fill_from = Vector2(0.5, 0.5)
		_glow.fill_to = Vector2(1.0, 0.5)
		_glow.width = 96
		_glow.height = 96
	ci.draw_texture_rect(_glow, Rect2(c - Vector2(r, r), Vector2(r, r) * 2), false, col)
