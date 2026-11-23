class_name Place
extends Node2D
## Base comune dei luoghi da scoprire: voce scritta a macchina, comandi in basso, scritte sul palco, scene dove si cammina.

signal open_item(it: Dictionary, sec: Dictionary)
signal bar_changed
signal goto(id: String)         # passa a un altro luogo

var time := 0.0
var st := 0.0
var cam := 0.0
var world := 320.0
var feet := 178.0
var tall := false              # schermo in verticale
var walking := false           # si cammina (tasti freccia) oppure è una scena fissa
var input_dir := 0
var input_up := 0
var run := false
var locked := false
var prompt: Dictionary = {}
var P: Player
var line := ""
var shown := 0
var _tt := 0.0
var _hold := 0.0

func _ready() -> void:
	P = Player.new()
	Layer.make(self, _draw_back)
	Layer.make(self, _draw_light, true)
	Layer.make(self, _draw_front)

func enter() -> void:
	st = 0.0; cam = 0.0; line = ""; shown = 0
	P = Player.new()
	_enter()

func update(dt: float) -> void:
	time += dt; st += dt
	prompt = {}
	if walking:
		P.update(dt, input_dir, run, 14, world - 14, Sfx.step_wood, locked)
		cam = lerpf(cam, clampf(P.x - 160 + P.dir * 10, 0, maxf(0, world - 320)), minf(1, dt * 4))
	_tick(dt)
	if line != "":
		if shown < line.length():
			_tt -= dt
			while _tt <= 0 and shown < line.length():
				shown += 1
				var ch := line.substr(shown - 1, 1)
				if shown % 2 == 0: Sfx.key(ch)
				_tt += 0.2 if ".!?".contains(ch) else 0.1 if ",;:".contains(ch) else 0.026
		else:
			_hold += dt
			if _hold > 3.5 + line.length() * 0.035: line = ""
	for l in get_children():
		if l is Layer: l.queue_redraw()

func say(s: String) -> void:
	line = s; shown = 0; _tt = 0.15; _hold = 0.0

func text() -> String:
	return line.substr(0, shown)

func done() -> bool:
	return shown >= line.length()

# da ridefinire
func _enter() -> void: pass
func _tick(_dt: float) -> void: pass
func _draw_back(_ci: CanvasItem) -> void: pass
func _draw_light(_ci: CanvasItem) -> void: pass
func _draw_front(_ci: CanvasItem) -> void: pass
## Un tasto: true se il luogo l'ha usato.
func press(_k: int) -> bool: return false
func tap(p: Vector2) -> void:
	if walking: P.target = clampf(p.x + cam, 14, world - 14)
func drag(_rel: Vector2) -> void: pass
## Il dito o il mouse si posa, si muove, si alza.
func hold(_p: Vector2) -> void: pass
func move_to(_p: Vector2) -> void: pass
func release() -> void: pass
func zoom(_d: float) -> void: pass
## I comandi in basso: [[scritta, azione], …]
func bar() -> Array: return []
## Le scritte sul palco: [{x, y, t, c, s}], in pixel del mondo.
func labels() -> Array: return []

func spr(ci: CanvasItem, n: String, left: float, top: float, mod := Color.WHITE) -> void:
	var r: Array = G.J.places.rects[n]
	ci.draw_texture_rect_region(G.tex.place_props, Rect2(roundf(left), roundf(top), r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), mod)
