extends Control
## Modalità foto: la scena si ferma, si sceglie un filtro e si salva una cartolina.

const FILTERS := ["", "th_alba", "th_aurora", "th_estate", "th_seppia", "th_neon", "th_noir", "th_cristalli"]
var main
var fi := 0
var bar: HBoxContainer
var card: Control
var cap: Label
var lname: Button
var _old: Material
var shooting := false

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	card = Control.new()
	card.set_anchors_preset(PRESET_FULL_RECT)
	card.mouse_filter = MOUSE_FILTER_IGNORE
	card.draw.connect(_paint)
	add_child(card)
	cap = UI.label("", 30, Color("3a3040"), UI.f_head)
	cap.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(cap)
	bar = UI.hbox(8)
	add_child(bar)

func open() -> void:
	visible = true
	fi = 0
	_old = main.view.material
	get_tree().paused = false
	main.hud.visible = false
	main.prompt_node.visible = false
	main.stage.visible = false
	for n in [main.dialog, main.sheet, main.pad]: n.visible = false
	for c in bar.get_children(): c.queue_free()
	bar.add_child(UI.button(G.t("photoShot"), shoot, "solid", 22))
	lname = UI.button("", next, "tool", 22)
	bar.add_child(lname)
	bar.add_child(UI.button(G.t("photoExit"), close, "tool", 22))
	_label()
	_layout.call_deferred()

func close() -> void:
	if not visible: return
	visible = false
	main.view.material = Shop.theme_material()
	main.stage.visible = true
	main._layout()
	Sfx.close()

func next(d := 1) -> void:
	fi = posmod(fi + d, FILTERS.size())
	main.view.material = _old if FILTERS[fi] == "" else Shop.theme_material({"theme": FILTERS[fi]})
	Sfx.move()
	_label()
	_layout.call_deferred()

func _label() -> void:
	lname.text = G.t("photoFilter") + ": " + (G.t("photoNone") if FILTERS[fi] == "" else G.L(Shop.by_id[FILTERS[fi]], "name"))

## Il riquadro fotografato, in coordinate dello schermo.
func frame() -> Rect2:
	var r: Rect2 = Rect2(Vector2.ZERO, main.size).intersection(main.world_rect)
	var m := minf(r.size.x, r.size.y) * 0.05
	return r.grow(-m)

func _layout() -> void:
	if not visible: return
	var r := frame()
	cap.add_theme_font_size_override("font_size", int(clampf(r.size.y * 0.045, 18, 40)))
	var d := Time.get_date_dict_from_system()
	cap.text = "%s · %s · %02d/%02d/%d" % [str(G.S.get("site_name", "CRI's CAMERETTA")), _place(), d.day, d.month, d.year]
	cap.reset_size()
	cap.position = Vector2(r.get_center().x - cap.size.x / 2, r.end.y - _b() + (_b() - cap.size.y) / 2)
	bar.reset_size()
	bar.position = Vector2((main.size.x - bar.size.x) / 2, 14.0 if not main.portrait else r.end.y + 24)
	card.queue_redraw()

func _b() -> float: return frame().size.y * 0.11

func _place() -> String:
	return main.place_name()

func _paint() -> void:
	var r := frame()
	var e := r.size.y * 0.035
	var c := Color("f6efe0")
	card.draw_rect(Rect2(r.position, Vector2(r.size.x, e)), c)
	card.draw_rect(Rect2(r.position, Vector2(e, r.size.y)), c)
	card.draw_rect(Rect2(r.end.x - e, r.position.y, e, r.size.y), c)
	card.draw_rect(Rect2(r.position.x, r.end.y - _b(), r.size.x, _b()), c)

func shoot() -> void:
	if shooting: return
	shooting = true
	bar.visible = false
	main.toast_node.visible = false
	for i in 3: await get_tree().process_frame     # il tempo di ridisegnare senza pulsanti
	var img := get_viewport().get_texture().get_image()
	var k: float = float(img.get_width()) / get_viewport_rect().size.x
	var r := frame()
	var o: Vector2 = main.global_position
	img = img.get_region(Rect2i(Vector2i((r.position + o) * k), Vector2i(r.size * k)))
	# sui telefoni la cartolina viene ingrandita a pixel netti
	var up := int(ceilf(1000.0 / maxf(1, img.get_width())))
	if up > 1: img.resize(img.get_width() * up, img.get_height() * up, Image.INTERPOLATE_NEAREST)
	bar.visible = true
	shooting = false
	var png := img.save_png_to_buffer()
	var name := "cameretta-%d.png" % int(Time.get_unix_time_from_system())
	Sfx.play("key_2", 0.8, 0.8)
	if G.is_web: JavaScriptBridge.download_buffer(png, name, "image/png")
	else:
		var f := FileAccess.open("user://" + name, FileAccess.WRITE)
		if f: f.store_buffer(png)
	last = img
	# il lampo
	var fl := ColorRect.new()
	fl.color = Color(1, 1, 1, 0.9)
	fl.set_anchors_preset(PRESET_FULL_RECT)
	fl.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fl)
	var tw := create_tween()
	tw.tween_property(fl, "color:a", 0.0, 0.4)
	tw.tween_callback(fl.queue_free)
	main.toast(G.t("photoSaved"))

var last: Image
