extends Node2D
## Fantasmi gentili: le sagome di chi sta visitando adesso la stessa scena. Niente nomi, solo un saluto.

const SCENES := {"street": 168.0, "grove": 177.0, "arcade": 186.0, "train": 186.0, "lab": 186.0}
var main
var me := ""
var others: Dictionary = {}    # k -> {x, tx, dir, wave, hi, a, seen}
var wave := 0
var hi := 0.0                  # sto salutando
var t := 0.0
var _busy := false
var last_scene := ""

func _ready() -> void:
	const ABC := "abcdefghijklmnopqrstuvwxyz0123456789"
	for i in 20: me += ABC[randi() % ABC.length()]

func greet() -> void:
	if hi > 0: return
	wave += 1
	hi = 1.6
	t = minf(t, 0.2)
	Sfx.play("stop_pop", 0.4, 1.5)

func _process(dt: float) -> void:
	var sc: String = main.scene
	visible = SCENES.has(sc) and G.ghosts
	hi = maxf(0, hi - dt)
	if sc != last_scene:
		last_scene = sc
		others.clear()
		t = 0.4
	if not visible: return
	var w = main.worlds[sc]
	t -= dt
	if t <= 0 and not _busy and not main.busy:
		t = 2.5
		_poll(sc, w)
	for k in others.keys():
		var o: Dictionary = others[k]
		var old: float = o.x
		o.x = move_toward(o.x, o.tx, maxf(41.0, absf(o.tx - o.x) * 0.9) * dt)
		o.mov = absf(o.x - old) > 0.02
		o.an += dt * 6.7
		o.hi = maxf(0, o.hi - dt)
		o.seen += dt
		o.a = move_toward(o.a, 0.0 if o.seen > 7.0 else 1.0, dt)
		if o.seen > 7.0 and o.a <= 0.01: others.erase(k)
	queue_redraw()

func _poll(sc: String, w) -> void:
	_busy = true
	var r: Array = await Shop._call("/api/presence", {"id": me, "scene": sc, "x": w.P.x, "dir": w.P.dir, "wave": wave})
	_busy = false
	if r[0] != 200 or typeof(r[1]) != TYPE_ARRAY:
		t = 20.0               # senza server si riprova con calma
		return
	if main.scene != sc: return
	for g in r[1]:
		var k := str(g.k)
		if not others.has(k): others[k] = {"x": float(g.x), "tx": float(g.x), "dir": int(g.dir), "wave": int(g.wave), "hi": 0.0, "a": 0.0, "seen": 0.0, "an": randf() * 6, "mov": false}
		var o: Dictionary = others[k]
		if int(g.wave) != o.wave:
			o.wave = int(g.wave)
			o.hi = 2.4
			Sfx.play("stop_pop", 0.3, 1.8)
		o.tx = float(g.x); o.dir = int(g.dir); o.seen = 0.0

func _draw() -> void:
	if not SCENES.has(main.scene): return
	var w = main.worlds[main.scene]
	var feet: float = SCENES[main.scene]
	var J: Dictionary = G.J.player
	for o in others.values():
		var sx := roundf(o.x - w.cam)
		if sx < -30 or sx > 350: continue
		var f := int(J.walk[int(o.an) % 6]) if o.mov else int(J.idle[int(o.an * 0.5) % 4])
		var fw: int = J.fw
		var d := 1.0 if o.dir > 0 else -1.0
		draw_set_transform(Vector2(sx - d * fw / 2.0, feet - float(J.footY)), 0, Vector2(d, 1))
		draw_texture_rect_region(G.tex.player, Rect2(0, 0, fw, J.fh), Rect2(f * fw, 0, fw, J.fh), Color(0.62, 0.78, 1.0, 0.38 * o.a))
		draw_set_transform(Vector2.ZERO)
		if o.hi > 0: _hand(Vector2(sx, feet - 68), o.hi)
	if hi > 0: _hand(Vector2(roundf(w.P.x - w.cam), feet - 68), hi)

## La manina che saluta.
func _hand(p: Vector2, k: float) -> void:
	draw_set_transform(p + Vector2(0, -4 * sin(minf(1, k) * PI)), sin(k * 12) * 0.3)
	draw_rect(Rect2(-6, -7, 13, 13), Color("18121e")); draw_rect(Rect2(-5, -6, 11, 11), Color("f6e9c8"))
	for i in 4: draw_rect(Rect2(-3 + i * 2, -4 + (1 if i in [0, 3] else 0), 1, 4), Color("8a5a36"))
	draw_rect(Rect2(-3, 0, 7, 3), Color("8a5a36"))
	draw_set_transform(Vector2.ZERO)
