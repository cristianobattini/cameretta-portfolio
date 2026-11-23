extends Node2D
## Dieci gru di carta nascoste nei luoghi. Si raccolgono passandoci accanto o toccandole.

const AT := {
	"street1": ["street", 168.0, 150.0], "street2": ["street", 1436.0, 92.0], "living": ["living", 60.0, 150.0], "room": ["room", 128.0, 124.0], "grove": ["grove", 862.0, 152.0],
	"sea": ["sea", 206.0, 152.0], "train": ["train", 610.0, 24.0], "arcade": ["arcade", 640.0, 126.0], "lab": ["lab", 366.0, 46.0], "pier": ["pier", 300.0, 76.0],
}
var main
var time := 0.0
signal found(id: String)

func count() -> int:
	return G.secrets.size()

func _here() -> Array:
	var o := []
	for id in AT:
		if AT[id][0] == main.scene and not G.secrets.has(id): o.append(id)
	return o

func _pos(id: String) -> Vector2:
	var w = main.worlds[main.scene]
	var cam: float = w.cam if "cam" in w and main.scene != "living" else 0.0
	return Vector2(AT[id][1] - cam, AT[id][2])

func _process(dt: float) -> void:
	time += dt
	queue_redraw()
	if main.modal.visible or main.busy: return
	if main.scene in ["street", "grove", "train", "arcade", "lab", "living", "sea"]:
		var w = main.worlds[main.scene]
		if main.scene == "sea" and w.state != "walk": return
		for id in _here():
			if absf(w.P.x - AT[id][1]) < 9 and AT[id][2] > 130: take(id)

## true se il tocco ha preso una gru.
func tap(p: Vector2) -> bool:
	for id in _here():
		if _pos(id).distance_to(p) < 13:
			take(id)
			return true
	return false

func take(id: String) -> void:
	if G.secrets.has(id): return
	G.secrets[id] = true
	G.save_prefs()
	Sfx.play("stop_pop", 0.9, 1.2)
	Shop.earn("secret:" + id)
	found.emit(id)

func _draw() -> void:
	if not G.J.has("places"): return
	var r: Array = G.J.places.rects.crane
	for id in _here():
		var p := _pos(id)
		if p.x < -20 or p.x > 340: continue
		var y := p.y + sin(time * 1.6 + p.x) * 1.5
		draw_texture_rect_region(G.tex.place_props, Rect2(roundf(p.x - 8), roundf(y - 7), r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), Color(1, 1, 1, 0.92))
		var k := fposmod(time * 0.7 + p.x * 0.1, 2.0)
		if k < 0.5:
			var s := sin(k / 0.5 * PI) * 3
			draw_rect(Rect2(roundf(p.x + 5) - s, roundf(y - 6), s * 2 + 1, 1), Color(1, 0.95, 0.7)); draw_rect(Rect2(roundf(p.x + 5), roundf(y - 6) - s, 1, s * 2 + 1), Color(1, 0.95, 0.7))
