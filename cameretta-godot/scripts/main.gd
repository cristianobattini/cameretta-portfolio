extends Control
## Regia del gioco: caricamento, menu, scene, HUD, schede, input (tastiera, mouse, touch).

## Proporzione massima del gioco: 16:9 come 1920x1080.
const MAX_ASPECT := 16.0 / 9.0
## I luoghi costruiti sulla base comune (place.gd).
const PLACES := ["sky", "train", "arcade", "tower", "light", "pier", "lab", "field", "foucault", "aurora", "photon", "coffee"]
const LAB := ["field", "foucault", "aurora", "photon"]

var sv: SubViewport
var view: TextureRect
var sky_custom: TextureRect
var stage: Control              # sovrapposizione in coordinate "palco" 1280x800 (= mondo x4)
var worlds: Dictionary = {}
var scene := "loading"
var busy := false
var world_rect := Rect2()
var portrait := false
var compact := false

# interfaccia
var menu_ui: Control
var menu_items: Array = []
var menu_sel := 0
var menu_mode_lbl: Button
var menu_full: Button
var menu_quote: Dictionary = {}
var menu_quote_t := 0.0
var hud: Control
var hud_top: Control
var crumb: Label
var mode_badge: Button
var tools: HBoxContainer
var b_back: Button
var b_skip: Button
var b_lang: Button
var b_audio: Button
var b_settings: Button
var b_full: Button
var b_shop: Button
var b_photo: Button
var place_bar: HFlowContainer
var place_host: Control
var place_labels: Array = []
var place_from := "street"
var paused_scene := ""          # dove si era quando si è aperto il menu
var paused_x := 0.0
var paused_dirty := false
var ghosts
var secrets
var photo
var visit
var b_menu: Button
var hint: RichTextLabel
var prog: Control
var prog_lbl: Label
var prog_pips: HBoxContainer
var pad: Control
var pad_a: Button
var dialog: PanelContainer
var dialog_txt: RichTextLabel
var sheet: PanelContainer
var sheet_box: VBoxContainer
var bubbles_host: Control
var bubble_nodes: Array = []
var sea_host: Control
var sea_labels: Array = []
var sea_signs: Array = []
var narr_node: PanelContainer
var narr_txt: RichTextLabel
var route: Control
var prompt_node: Button
var prompt_action: Callable
var sign_node: Control
var title_lbl: Label
var modal: Control
var modal_kind := ""
var open_id := ""
var fade_rect: ColorRect
var toast_node: PanelContainer
var loading: Control
var ld_fill: ColorRect
var ld_pct: Label
var ld_text: Label
var pad_dir := 0
var pad_up := 0
var after_choose: Callable

func _ready() -> void:
	UI.init()
	theme = UI.theme
	set_anchors_preset(PRESET_FULL_RECT)
	clip_contents = true
	mouse_filter = MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = G.C_NIGHT
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	sky_custom = TextureRect.new()
	sky_custom.set_anchors_preset(PRESET_FULL_RECT)
	sky_custom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_custom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky_custom.visible = false
	sky_custom.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(sky_custom)
	sv = SubViewport.new()
	sv.size = Vector2i(G.W, G.H)
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.disable_3d = true
	add_child(sv)
	for n in ["menu", "street", "living", "room", "sea", "grove"] + PLACES:
		var w := Node2D.new()
		w.set_script(load("res://scripts/%s%s.gd" % ["place_" if n in PLACES else "", n]))
		w.visible = false
		sv.add_child(w)
		worlds[n] = w
	ghosts = Node2D.new()
	ghosts.set_script(load("res://scripts/ghosts.gd"))
	ghosts.main = self
	sv.add_child(ghosts)
	secrets = Node2D.new()
	secrets.set_script(load("res://scripts/secrets.gd"))
	secrets.main = self
	sv.add_child(secrets)
	secrets.found.connect(func(_id):
		toast(G.t("secretFound") % secrets.count() if secrets.count() < 10 else G.t("secretAll")))
	view = TextureRect.new()
	view.texture = sv.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = MOUSE_FILTER_STOP
	view.gui_input.connect(_on_view_input)
	view.mouse_exited.connect(func(): if scene == "room" and G.room_mode != "walk": worlds.room.set_hover(""))
	add_child(view)
	stage = Control.new()
	stage.size = Vector2(1280, 800)
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	stage.clip_contents = true
	add_child(stage)
	_build_stage()
	_build_menu()
	_build_hud()
	_build_mobile()
	modal = Control.new()
	modal.set_anchors_preset(PRESET_FULL_RECT)
	modal.visible = false
	add_child(modal)
	toast_node = UI.px_panel(G.C_PANEL, G.gold, 10)
	toast_node.visible = false
	toast_node.mouse_filter = MOUSE_FILTER_IGNORE
	toast_node.get_node("Inner").add_child(UI.label("", 20, G.C_CREAM, UI.f_ui))
	add_child(toast_node)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(G.C_NIGHT, 0)
	fade_rect.set_anchors_preset(PRESET_FULL_RECT)
	fade_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	_build_loading()
	get_viewport().size_changed.connect(_layout)
	G.lang_changed.connect(_apply_texts)
	G.settings_changed.connect(_apply_texts)
	worlds.street.go_inside.connect(func(): _transition(_enter_living.bind(false), true))
	worlds.living.go_room.connect(_go_room)
	worlds.street.go.connect(func(id): if scene == "street": _transition(_enter_path.bind(id)))
	worlds.sea.visit.connect(_sea_visit)
	for n in PLACES:
		worlds[n].open_item.connect(_open_item)
		worlds[n].goto.connect(_goto)
		worlds[n].bar_changed.connect(func(): if scene == n: _rebuild_bar())
	worlds.sea.open_stop.connect(func(i): get_tree().create_timer(0.25).timeout.connect(func(): if scene == "sea" and worlds.sea.state == "parked": open_stop(i)))
	worlds.sea.chapter.connect(_on_chapter)
	worlds.sea.mode_changed.connect(func(): if scene == "sea": _sea_mode())
	worlds.sea.finished.connect(func(): if scene == "sea": open_ride_end())
	worlds.room.open_section.connect(func(id): open_section(id))
	worlds.room.hover_changed.connect(func(_g): _render_sign())
	photo = Control.new()
	photo.set_script(load("res://scripts/photo.gd"))
	photo.main = self
	add_child(photo)
	visit = Control.new()
	visit.set_script(load("res://scripts/visit.gd"))
	visit.main = self
	add_child(visit)
	for c in [modal, toast_node, fade_rect]: if c: move_child(c, -1)
	if loading: move_child(loading, -1)
	_layout()
	Shop.coins_in.connect(func(n): toast(G.t("coinsIn") % n))
	Shop.changed.connect(func(): if modal.visible and modal_kind == "shop": open_shop(true))
	Shop.theme_changed.connect(_apply_theme)
	_boot()
	if OS.get_environment("CAMERETTA_TOUR") != "":
		var t := Node.new()
		t.set_script(load("res://scripts/tour.gd"))
		add_child(t)

# ================================================================== avvio
func _boot() -> void:
	var t0 := Time.get_ticks_msec()
	G.load_all()
	while G.progress < 1.0:
		_ld_update()
		await get_tree().process_frame
	_ld_update()
	Season.apply()
	Shop.apply()
	worlds.room.build()
	Sfx.levels()
	Sfx.apply_volumes()
	Sfx.load_music()
	if G.custom_sky:
		sky_custom.texture = G.tex.menu_custom
		sky_custom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if str(G.S.get("menu_background_pixelated", "1")) != "0" else CanvasItem.TEXTURE_FILTER_LINEAR
	_apply_texts()
	_set_scene("menu")
	var h := G.get_hash()
	if h == "stanza" or G.by_id.has(h):
		_enter_room()
		if G.by_id.has(h): open_section(h, true)
	elif h == "salotto": _enter_living(false)
	elif h == "strada": _enter_street()
	elif h == "lungomare": _enter_sea()
	elif h == "templi": _enter_grove()
	elif h in PLACES: _enter_place(h, "sea" if h in ["tower", "light", "pier"] else "street")
	if G.offline: toast(G.t("noServer"))
	var left := 1500 - (Time.get_ticks_msec() - t0)
	if left > 0: await get_tree().create_timer(left / 1000.0).timeout
	ld_fill.size.x = ld_fill.get_parent().size.x
	ld_pct.text = "100%"
	var tw := create_tween()
	tw.tween_property(loading, "modulate:a", 0.0, 0.5)
	await tw.finished
	loading.queue_free()
	loading = null

func _ld_update() -> void:
	if loading == null: return
	var p := G.progress
	var pct := int(round(p * 20)) * 5
	ld_pct.text = "%d%%" % pct
	ld_fill.size.x = ld_fill.get_parent().size.x * pct / 100.0

func _build_loading() -> void:
	loading = Control.new()
	loading.set_anchors_preset(PRESET_FULL_RECT)
	loading.mouse_filter = MOUSE_FILTER_STOP
	add_child(loading)
	var bgt := TextureRect.new()
	bgt.texture = load("res://assets/img/menu_sky.png")
	bgt.set_anchors_preset(PRESET_FULL_RECT)
	bgt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bgt.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bgt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float r = 3.0;
void fragment(){
	vec4 c = vec4(0.0); float n = 0.0;
	for(float x = -3.0; x <= 3.0; x += 1.0){ for(float y = -3.0; y <= 3.0; y += 1.0){
		c += texture(TEXTURE, UV + vec2(x, y) * TEXTURE_PIXEL_SIZE * r); n += 1.0; } }
	COLOR = c / n * vec4(0.7, 0.7, 0.85, 1.0);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	bgt.material = mat
	loading.add_child(bgt)
	var dim := ColorRect.new()
	dim.color = Color(G.C_NIGHT, 0.45)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	loading.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(PRESET_FULL_RECT)
	loading.add_child(c)
	var v := UI.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	ld_text = UI.label("LOADING", 52, G.C_CREAM, UI.f_head)
	ld_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ld_text.add_theme_color_override("font_shadow_color", G.C_TERRA)
	ld_text.add_theme_constant_override("shadow_offset_x", 4)
	ld_text.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(ld_text)
	var bar := UI.px_panel(G.C_INK, G.C_CREAM, 0)
	bar.custom_minimum_size = Vector2(420, 34)
	var track := Control.new()
	track.custom_minimum_size = Vector2(404, 18)
	track.clip_contents = true
	bar.get_node("Inner").add_child(track)
	ld_fill = ColorRect.new()
	ld_fill.color = G.gold
	ld_fill.size = Vector2(0, 18)
	track.add_child(ld_fill)
	v.add_child(bar)
	ld_pct = UI.label("0%", 22, G.C_MUTED, UI.f_ui)
	ld_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ld_pct)
	var tips: Array = G.t("tips")
	var tip := UI.rich("[center]" + G.kbd(tips[randi() % tips.size()]) + "[/center]", 22, G.C_MUTED)
	tip.custom_minimum_size.x = 520
	v.add_child(tip)
	menu_quote = Quotes.next()     # la stessa frase poi resta nel menu
	var q := UI.rich("[center]«%s»\n[color=#f2b85b]— %s[/color][/center]" % [G.esc_bb(G.L(menu_quote, "text")), G.esc_bb(Quotes.author(menu_quote))], 24, G.C_CREAM)
	q.custom_minimum_size.x = 520
	v.add_child(q)

# ================================================================== palco (bolle, prompt, cartello, titolo)
func _build_stage() -> void:
	bubbles_host = Control.new()
	bubbles_host.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(bubbles_host)
	prompt_node = Button.new()
	prompt_node.focus_mode = Control.FOCUS_NONE
	prompt_node.add_theme_font_override("font", UI.f_ui)
	prompt_node.add_theme_font_size_override("font_size", 26)
	prompt_node.add_theme_stylebox_override("normal", UI.box(G.C_INK, G.C_CREAM, 4, 14, 6))
	prompt_node.add_theme_stylebox_override("hover", UI.box(G.gold, G.C_INK, 4, 14, 6))
	prompt_node.add_theme_stylebox_override("pressed", UI.box(G.gold, G.C_INK, 4, 14, 6))
	prompt_node.add_theme_color_override("font_color", G.C_CREAM)
	prompt_node.add_theme_color_override("font_hover_color", G.C_INK)
	prompt_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt_node.visible = false
	prompt_node.pressed.connect(_do_action)
	stage.add_child(prompt_node)
	sea_host = Control.new()
	sea_host.mouse_filter = MOUSE_FILTER_IGNORE
	sea_host.visible = false
	stage.add_child(sea_host)
	stage.move_child(sea_host, 0)
	sign_node = Control.new()
	sign_node.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(sign_node)
	title_lbl = UI.label("", 64, G.C_CREAM, UI.f_head)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_shadow_color", G.C_INK)
	title_lbl.add_theme_constant_override("shadow_offset_x", 5)
	title_lbl.add_theme_constant_override("shadow_offset_y", 5)
	title_lbl.add_theme_constant_override("line_spacing", -26)
	title_lbl.size = Vector2(1280, 90)
	title_lbl.position = Vector2(0, 300)
	title_lbl.modulate.a = 0
	title_lbl.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(title_lbl)

func _make_bubble(B: Dictionary) -> PanelContainer:
	var quote: bool = B.data.get("kind", "") == "quote"
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color("26204a") if quote else G.C_CREAM, G.gold if quote else G.C_INK, 4, 20, 16))
	p.custom_minimum_size.x = 340
	p.size = Vector2(340, 10)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	var v := UI.vbox(6)
	if quote:
		var mk := Control.new()     # le virgolette, senza lo spazio vuoto sotto
		mk.custom_minimum_size.y = 22
		mk.mouse_filter = MOUSE_FILTER_IGNORE
		var ql := UI.label("“", 44, G.gold, UI.f_head)
		ql.position.y = -10
		mk.add_child(ql)
		v.add_child(mk)
	var r := UI.rich("", 25, G.C_CREAM if quote else G.C_INK)
	r.name = "T"
	r.custom_minimum_size.x = 300
	r.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(r)
	if quote and str(B.data.get("author", "")) != "":
		var a := UI.label("— " + G.L(B.data, "author"), 21, G.gold, null, true)
		a.name = "A"
		a.modulate.a = 0
		v.add_child(a)
	p.add_child(v)
	# codina del fumetto
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(30, 0), Vector2(58, 0), Vector2(30, 24)])
	tail.color = G.gold if quote else G.C_INK
	tail.name = "Tail"
	p.add_child(tail)
	var tail2 := Polygon2D.new()
	tail2.polygon = PackedVector2Array([Vector2(34, -4), Vector2(54, -4), Vector2(34, 14)])
	tail2.color = Color("26204a") if quote else G.C_CREAM
	tail2.name = "Tail2"
	p.add_child(tail2)
	p.visible = false
	bubbles_host.add_child(p)
	return p

func _rebuild_bubbles() -> void:
	for n in bubble_nodes: n.queue_free()
	bubble_nodes.clear()
	for B in worlds.street.bub: bubble_nodes.append(_make_bubble(B))

func _update_bubbles() -> void:
	var st = worlds.street
	var cam: float = st.cam
	var last_text := ""
	var last_quote := false
	var last_auth := ""
	for i in bubble_nodes.size():
		var B: Dictionary = st.bub[i]
		var p: PanelContainer = bubble_nodes[i]
		if B.state == "idle":
			p.visible = false
			continue
		var full := G.L(B.data, "text")
		var shown: String = full.substr(0, B.shown)
		var caret := "" if B.state == "done" else ("[color=#%s]▌[/color]" % ("f6e9c8" if B.data.get("kind", "") == "quote" else "1a1733"))
		var r: RichTextLabel = p.get_node("VBoxContainer/T") if p.has_node("VBoxContainer/T") else p.find_child("T", true, false)
		var txt := G.esc_bb(shown) + caret
		if r.text != txt: r.text = txt
		var a = p.find_child("A", true, false)
		if a:
			a.text = "— " + G.L(B.data, "author")
			a.modulate.a = 1.0 if B.state == "done" else 0.0
		if not p.visible:
			p.visible = true
			p.modulate.a = 0
			p.pivot_offset = Vector2(170, 60)
			p.scale = Vector2(0.9, 0.9)
			var tw := create_tween().set_parallel()
			tw.tween_property(p, "modulate:a", 1.0, 0.25)
			tw.tween_property(p, "scale", Vector2.ONE, 0.25)
		p.reset_size()
		p.position = Vector2(B.x * 4 - 60 - cam * 4, B.top)
		var tail: Polygon2D = p.get_node("Tail")
		var tail2: Polygon2D = p.get_node("Tail2")
		tail.position = Vector2(0, p.size.y)
		tail2.position = Vector2(0, p.size.y)
		last_text = shown
		last_quote = B.data.get("kind", "") == "quote"
		last_auth = G.L(B.data, "author") if B.state == "done" else ""
	if portrait and dialog:
		var bb := G.esc_bb(last_text)
		if last_quote and last_auth != "": bb += "\n[color=#f2b85b]— %s[/color]" % G.esc_bb(last_auth)
		if dialog_txt.text != bb:
			dialog_txt.text = bb
			dialog.visible = scene == "street" and bb != "" and not modal.visible
		dialog.get_node("Inner").add_theme_stylebox_override("panel", UI.box(Color("26204a") if last_quote else G.C_CREAM, G.gold if last_quote else G.C_INK, 4, 14, 10))
		dialog_txt.add_theme_color_override("default_color", G.C_CREAM if last_quote else G.C_INK)

# ================================================================== lungomare: etichette delle tappe, narrazione, percorso
func _rebuild_sea() -> void:
	for n in sea_labels: n.queue_free()
	sea_labels.clear()
	for s in worlds.sea.stops:
		var chalk: bool = s.sec.id == "lavagna"
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.box(Color("24493a") if chalk else G.C_CREAM, Color("8a5a36") if chalk else G.C_INK, 4, 16, 8))
		p.mouse_filter = MOUSE_FILTER_IGNORE
		var v := UI.vbox(0)
		var k := UI.label("", 20, Color("b9cdb5") if chalk else Color("8a5a36"), UI.f_ui)
		k.name = "K"
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(k)
		var t := UI.label("", 29, Color("f4f7ef") if chalk else G.C_INK, UI.f_head, true)
		t.name = "T"
		t.add_theme_constant_override("line_spacing", -14)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		p.add_child(v)
		var tail := Polygon2D.new()
		tail.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(0, 16)])
		tail.color = Color("8a5a36") if chalk else G.C_INK
		tail.name = "Tail"
		p.add_child(tail)
		p.visible = false
		sea_host.add_child(p)
		sea_labels.append(p)
	# cartelli stradali: il testo sta nel palco, così resta nitido
	for n in sea_signs: n.queue_free()
	sea_signs.clear()
	for ch in worlds.sea.chapters:
		var b := Control.new()
		b.mouse_filter = MOUSE_FILTER_IGNORE
		b.size = Vector2(236, 88)
		var pl := UI.label("", 30, Color("1e1e2e"), UI.f_ui)
		pl.name = "P"
		pl.size = Vector2(236, 40)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(pl)
		var blue := ColorRect.new()
		blue.color = Color("2f5fa8")
		blue.position = Vector2(34, 44)
		blue.size = Vector2(168, 36)
		blue.mouse_filter = MOUSE_FILTER_IGNORE
		b.add_child(blue)
		var kl := UI.label("PISA  %d" % worlds.sea.km_at(ch.x0), 26, Color.WHITE, UI.f_ui)
		kl.position = Vector2(34, 44)
		kl.size = Vector2(168, 36)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(kl)
		for x in [pl, kl]: x.mouse_filter = MOUSE_FILTER_IGNORE
		b.visible = false
		sea_host.add_child(b)
		sea_host.move_child(b, 0)
		sea_signs.append(b)
	_sea_texts()

func _sea_texts() -> void:
	for i in sea_signs.size():
		var ch: Dictionary = worlds.sea.chapters[i]
		var pl: Label = sea_signs[i].get_node("P")
		pl.text = str(G.t("ridePlaces").get(ch.id, G.L(ch.sec, "sign_label"))).to_upper()
		var fs := 30
		while fs > 14 and UI.f_ui.get_string_size(pl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 226: fs -= 1
		pl.add_theme_font_size_override("font_size", fs)
	for i in sea_labels.size():
		var s: Dictionary = worlds.sea.stops[i]
		var p: PanelContainer = sea_labels[i]
		var k: Label = p.find_child("K", true, false)
		var t: Label = p.find_child("T", true, false)
		k.text = G.L(s.it, "kicker")
		k.visible = k.text != ""
		t.text = G.L(s.it, "title")
		var w := UI.f_head.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 29).x + 4
		w = maxf(w, UI.f_ui.get_string_size(k.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 4)
		t.custom_minimum_size.x = clampf(w, 150, 400)

func _update_sea() -> void:
	var sea = worlds.sea
	sea.paused = modal.visible
	for i in sea_signs.size():
		var cx: float = float(sea.chapters[i].x0) - roundf(sea.cam)
		sea_signs[i].visible = cx > -40 and cx < 360
		sea_signs[i].position = Vector2(cx * 4 - 118, 107 * 4)
		# il cartello sta dietro alla Vespa: quando le passa davanti il testo si attenua
		sea_signs[i].modulate = sea._mod()
		sea_signs[i].modulate.a = clampf((absf(cx - (sea.x - sea.cam) + 2) - 34) / 22.0, 0.0, 1.0) if sea.riding() else 1.0
	var near: int = sea.near_stop() if sea.state in ["ride", "parking", "parked"] else -1
	for i in sea_labels.size():
		var s: Dictionary = sea.stops[i]
		var p: PanelContainer = sea_labels[i]
		var sx: float = float(s.x) - sea.cam
		var show: bool = s.state == "up" and not portrait and sx > -30 and sx < 345 and not modal.visible and sea.state != "ending" and sea.state != "end"
		if show and not p.visible:
			p.visible = true
			p.reset_size()
			p.pivot_offset = Vector2(p.size.x / 2, p.size.y)
			p.scale = Vector2(0.4, 0.4)
			p.modulate.a = 0
			var tw := create_tween().set_parallel()
			tw.tween_property(p, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 1.0, 0.18)
		elif not show: p.visible = false
		if not p.visible: continue
		p.reset_size()
		p.position = Vector2(roundf(sx * 4 - p.size.x / 2), 366 - p.size.y + sin(Time.get_ticks_msec() / 420.0 + i) * 3)
		(p.get_node("Tail") as Polygon2D).position = Vector2(p.size.x / 2, p.size.y)
		p.self_modulate = Color.WHITE if i == near else Color(0.86, 0.86, 0.9)
	var txt: String = sea.narr_text()
	var on: bool = txt != "" and not modal.visible
	if portrait:
		narr_node.visible = false
		var bb := G.esc_bb(txt)
		if bb == "" and near >= 0: bb = "[color=#8a5a36]%s[/color]\n%s" % [G.esc_bb(G.L(sea.stops[near].it, "kicker")), G.esc_bb(G.L(sea.stops[near].it, "title"))]
		if dialog_txt.text != bb:
			dialog_txt.text = bb
			dialog.get_node("Inner").add_theme_stylebox_override("panel", UI.box(G.C_CREAM, G.C_INK, 4, 14, 10))
			dialog_txt.add_theme_color_override("default_color", G.C_INK)
		dialog.visible = bb != "" and not modal.visible
	else:
		if on:
			var caret := "" if sea.narr_done() else "[color=#f2b85b]▌[/color]"
			if narr_txt.text != G.esc_bb(txt) + caret: narr_txt.text = G.esc_bb(txt) + caret
			if not narr_node.visible:
				narr_node.visible = true
				narr_node.modulate.a = 0
			# tiene il posto per tutta la battuta, così il riquadro non cresce mentre si scrive
			var full: String = str(sea.narr.lines[sea.narr.i])
			var nw := minf(520, size.x * 0.42)
			narr_node.custom_minimum_size = Vector2(nw, 0)
			var hh := UI.f_body.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, nw - 56, 27).y
			narr_txt.custom_minimum_size = Vector2(nw - 48, hh)
			narr_node.reset_size()
			narr_node.position = Vector2(14 if world_rect.position.x < 0 else world_rect.position.x + 14, 72)
		narr_node.modulate.a = move_toward(narr_node.modulate.a, 1.0 if on else 0.0, get_process_delta_time() * 5)
		if not on and narr_node.modulate.a <= 0.01: narr_node.visible = false
	route.visible = sea.riding() and not modal.visible
	route.queue_redraw()

## Riquadro della voce nei templi (in verticale usa il fumetto in basso).
func _say_box(txt: String, full: String, done: bool) -> void:
	var on := txt != "" and not modal.visible
	if portrait:
		narr_node.visible = false
		var bb := G.esc_bb(txt)
		if dialog_txt.text != bb:
			dialog_txt.text = bb
			dialog.get_node("Inner").add_theme_stylebox_override("panel", UI.box(G.C_CREAM, G.C_INK, 4, 14, 10))
			dialog_txt.add_theme_color_override("default_color", G.C_INK)
		dialog.visible = on
		return
	if on:
		var tx := G.esc_bb(txt) + ("" if done else "[color=#f2b85b]▌[/color]")
		if narr_txt.text != tx: narr_txt.text = tx
		if not narr_node.visible:
			narr_node.visible = true
			narr_node.modulate.a = 0
		var nw := minf(470, size.x * 0.37) if scene in PLACES else minf(560, size.x * 0.46)
		narr_node.custom_minimum_size = Vector2(nw, 0)
		narr_txt.custom_minimum_size = Vector2(nw - 48, UI.f_body.get_multiline_string_size(full, HORIZONTAL_ALIGNMENT_LEFT, nw - 56, 27).y)
		narr_node.reset_size()
		narr_node.position = Vector2(maxf(14, world_rect.position.x + 14) if scene in PLACES else (size.x - narr_node.size.x) / 2, 66)
	narr_node.modulate.a = move_toward(narr_node.modulate.a, 1.0 if on else 0.0, get_process_delta_time() * 5)
	if not on and narr_node.modulate.a <= 0.01: narr_node.visible = false

## Striscia del percorso: capitoli, tappe viste, Vespa, chilometri per Pisa.
func _draw_route() -> void:
	var sea = worlds.sea
	var w := route.size.x
	route.draw_rect(Rect2(Vector2.ZERO, route.size), G.C_INK)
	route.draw_rect(Rect2(Vector2(3, 3), route.size - Vector2(6, 6)), G.C_PANEL)
	var head := "%s %d/%d" % [G.t("rideStops"), sea.seen_count(), sea.stops.size()]
	route.draw_string(UI.f_ui, Vector2(14, 24), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, G.C_CREAM)
	var km := "PISA %d km" % sea.km_at(sea.x)
	route.draw_string(UI.f_ui, Vector2(w - 14 - UI.f_ui.get_string_size(km, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x, 24), km, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, G.gold)
	var x0 := 16.0
	var x1 := w - 18.0
	var at := func(wx: float) -> float: return roundf(lerpf(x0, x1, clampf((wx - sea.VESPA_X) / (sea.end_x - sea.VESPA_X), 0, 1)))
	route.draw_rect(Rect2(x0, 43, x1 - x0, 2), G.C_LINE)
	route.draw_rect(Rect2(x0, 43, float(at.call(sea.x)) - x0, 2), G.gold)
	for ch in sea.chapters: route.draw_rect(Rect2(at.call(ch.x0) - 1, 36, 2, 16), G.C_SKY)
	for s in sea.stops:
		var sx: float = at.call(s.x)
		route.draw_rect(Rect2(sx - 3, 41, 6, 6), G.C_INK)
		route.draw_rect(Rect2(sx - 2, 42, 4, 4), G.C_SAGE if s.seen else G.C_MUTED)
	var vx: float = at.call(sea.x)
	route.draw_rect(Rect2(vx - 6, 34, 12, 12), G.C_INK)
	route.draw_rect(Rect2(vx - 4, 36, 8, 8), Color("7ec4b0"))
	route.draw_rect(Rect2(vx - 4, 44, 3, 3), G.C_CREAM)
	route.draw_rect(Rect2(vx + 1, 44, 3, 3), G.C_CREAM)

func _sea_mode() -> void:
	hint.text = G.kbd(G.t("hintRide" if worlds.sea.riding() else "hintSeaWalk"))
	_layout_hud()

func _on_chapter(i: int) -> void:
	var ch: Dictionary = worlds.sea.chapters[i]
	_show_title((G.t("rideChapter") % int(ch.num)) + "\n" + str(G.t("rideTitles").get(ch.id, G.L(ch.sec, "title").to_upper())))
	G.mark_explored(ch.id)
	Sfx.page()

func _show_title(text: String) -> void:
	if visit and visit.visible: return
	title_lbl.text = text
	title_lbl.size = Vector2(1280, 90)
	title_lbl.position.y = 300 if not text.contains("\n") else 250
	var tw := create_tween()
	title_lbl.modulate.a = 0
	tw.tween_property(title_lbl, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.6)
	tw.tween_property(title_lbl, "modulate:a", 0.0, 0.5)

func _render_sign() -> void:
	for c in sign_node.get_children(): c.queue_free()
	var room = worlds.room
	if scene != "room" or room.hover == "" or not room.boxes.has(room.hover) or modal.visible: return
	var b: Dictionary = room.boxes[room.hover]
	var s: Dictionary = G.by_id[room.hover]
	var board := PanelContainer.new()
	var sb := UI.box(Color("8a5a36"), Color("3d2616"), 4, 26, 10)
	board.add_theme_stylebox_override("panel", sb)
	board.mouse_filter = MOUSE_FILTER_IGNORE
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var o := UI.label(G.L(s, "object_name").to_upper(), 22, Color("f2d9a6"), UI.f_ui)
	o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var l := UI.label(G.L(s, "sign_label"), 30, Color("fff4dc"), UI.f_head)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color("3d2616"))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(o)
	v.add_child(l)
	board.add_child(v)
	sign_node.add_child(board)
	board.reset_size()
	var w := board.size.x
	var cx := clampf(float(b.cx) * 4, 130, 1150)
	var top := maxf(16, float(b.y0) * 4 - 128)
	board.position = Vector2(cx - w / 2, top)
	for k in 2:
		var post := ColorRect.new()
		post.color = Color("5e3b22")
		post.size = Vector2(8, 36)
		post.position = Vector2(cx - 59 + k * 110, top + board.size.y)
		post.mouse_filter = MOUSE_FILTER_IGNORE
		sign_node.add_child(post)
	board.position.y -= 10
	create_tween().tween_property(board, "position:y", top, 0.15)

# ================================================================== menu
func _build_menu() -> void:
	menu_ui = Control.new()
	menu_ui.set_anchors_preset(PRESET_FULL_RECT)
	menu_ui.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(menu_ui)

func _rebuild_menu() -> void:
	for c in menu_ui.get_children():
		menu_ui.remove_child(c)
		c.queue_free()
	menu_items.clear()
	var S := G.S
	var back := PanelContainer.new()
	back.name = "Col"
	back.add_theme_stylebox_override("panel", UI.box(Color(G.C_NIGHT, 0.0 if portrait else 0.5), Color(0, 0, 0, 0), 0, 0 if portrait else 26))
	back.mouse_filter = MOUSE_FILTER_IGNORE
	menu_ui.add_child(back)
	var col := UI.vbox(8)
	col.mouse_filter = MOUSE_FILTER_IGNORE
	back.add_child(col)
	var roomy := not compact and paused_scene == ""      # in pausa c'è una voce in più: via le scritte decorative
	if roomy: col.add_child(UI.label(G.L(S, "menu_kicker"), 22, G.C_SKY, UI.f_ui))
	var site := str(S.get("site_name", "CRI's CAMERETTA"))
	var avail := (size.x - 48) if portrait else 520.0
	var fs := 64 if portrait or compact else 96
	while fs > 28 and UI.f_head.get_string_size(site, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail - 8: fs -= 2
	var nm := UI.label(site, fs, G.C_CREAM, UI.f_head)
	nm.add_theme_color_override("font_shadow_color", G.C_TERRA)
	nm.add_theme_constant_override("shadow_offset_x", 6)
	nm.add_theme_constant_override("shadow_offset_y", 6)
	col.add_child(nm)
	col.add_child(UI.label(G.L(S, "menu_subtitle"), 28, G.gold, UI.f_ui, true))
	if roomy:
		col.add_child(UI.label(G.L(S, "menu_tagline"), 24, G.C_MUTED, null, true))
		var gap := Control.new()
		gap.custom_minimum_size.y = 14
		col.add_child(gap)
	var nav := PanelContainer.new()
	nav.add_theme_stylebox_override("panel", UI.box(Color(G.C_NIGHT, 0.82), G.C_CREAM, 4, 4))
	var nv := UI.vbox(2)
	nav.add_child(nv)
	col.add_child(nav)
	var enter_lbl := G.L(S, "menu_enter_label")
	var items := [
		["enter", enter_lbl if enter_lbl != "" else G.t("start"), ""],
		["visit", G.t("visit"), ""],
		["room", G.t("room"), ""],
		["map", G.t("map"), "★"],
		["shop", G.t("shop"), str(Shop.balance) if Shop.code != "" else ""],
		["settings", G.t("settings"), G.t("walk") if G.room_mode == "walk" else G.t("point") if G.room_mode == "point" else ""],
		["lang", G.t("language").to_upper(), G.t("langName").to_upper()],
		["audio", G.t("audio").to_upper(), G.t("on") if G.audio_on else G.t("off")],
		["help", G.t("help"), ""],
	]
	if paused_scene != "":
		items[0][1] = G.t("restart")
		items.push_front(["resume", G.t("resume"), str(_place_label(paused_scene))])
	if not Shop.enabled(): items = items.filter(func(q): return q[0] != "shop")
	# schermi bassi: lingua e audio stanno già nelle impostazioni, così il resto rimane grande
	if compact: items = items.filter(func(q): return q[0] != "lang" and q[0] != "audio" and q[0] != "help")
	for i in items.size():
		var it: Array = items[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(440 if not portrait else 0, 39 if compact else 43)
		b.add_theme_font_override("font", UI.f_ui)
		b.add_theme_font_size_override("font_size", 24 if not portrait else 22)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.set_meta("act", it[0])
		b.set_meta("label", it[1])
		b.set_meta("val", it[2])
		var act: String = it[0]
		var idx := i
		b.pressed.connect(func(): _menu_sel(idx); _menu_act(act))
		b.mouse_entered.connect(func(): if menu_sel != idx: _menu_sel(idx); Sfx.move())
		nv.add_child(b)
		menu_items.append(b)
	_menu_sel(menu_sel)
	if not G.touch and roomy:
		var press := UI.label(G.L(S, "press_text"), 20, G.C_DIM, UI.f_ui, true)
		col.add_child(press)
	# modalità della cameretta: sempre indicata
	menu_mode_lbl = _mode_button()
	var row := UI.hbox(10)
	row.add_child(menu_mode_lbl)
	menu_full = _full_button(18)
	row.add_child(menu_full)
	col.add_child(row)
	var foot: BoxContainer = UI.vbox(2) if portrait else UI.hbox(14)
	foot.name = "Foot"
	menu_ui.add_child(foot)
	foot.add_child(UI.label(G.L(S, "footer_text"), 18, G.C_DIM))
	if G.safe_url(str(S.get("github_url", ""))):
		var gh: String = S.github_url
		var gb := UI.button(gh.replace("https://", "").replace("http://", ""), func(): G.open_url(gh), "link", 18)
		foot.add_child(gb)
	_build_menu_quote()
	_layout_menu()

# --- la citazione del menu: cambia da sola ogni tanto
func _build_menu_quote() -> void:
	if menu_quote.is_empty(): menu_quote = Quotes.next()
	var p := PanelContainer.new()
	p.name = "Quote"
	p.mouse_filter = MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UI.box(Color("26204a", 0.9), G.gold, 4, 18, 12))
	var v := UI.vbox(4)
	v.mouse_filter = MOUSE_FILTER_IGNORE
	var tx := UI.label("", 25, G.C_CREAM, null, true)
	tx.name = "T"
	tx.add_theme_constant_override("line_spacing", -8)
	var au := UI.label("", 20, G.gold, null, true)
	au.name = "A"
	for l in [tx, au]:
		l.mouse_filter = MOUSE_FILTER_IGNORE
		v.add_child(l)
	p.add_child(v)
	menu_ui.add_child(p)
	_fill_menu_quote()

func _fill_menu_quote() -> void:
	var p: PanelContainer = menu_ui.get_node("Quote")
	(p.find_child("T", true, false) as Label).text = "«%s»" % G.L(menu_quote, "text")
	(p.find_child("A", true, false) as Label).text = "— " + Quotes.author(menu_quote)

func _layout_menu_quote() -> void:
	var p: PanelContainer = menu_ui.get_node_or_null("Quote")
	if p == null: return
	var col: Control = menu_ui.get_node("Col")
	var w := minf(480, col.position.x - 48)
	p.visible = not portrait and not compact and w >= 300
	if not p.visible: return
	for l in [p.find_child("T", true, false), p.find_child("A", true, false)]:
		l.custom_minimum_size.x = w - 44
		l.size.x = w - 44
		l.update_minimum_size()
	p.custom_minimum_size.x = w
	p.size = Vector2(w, 0)
	var foot: Control = menu_ui.get_node("Foot")
	p.position = Vector2(24, size.y - foot.get_combined_minimum_size().y - 34 - p.get_combined_minimum_size().y)

func _next_menu_quote() -> void:
	var p: Control = menu_ui.get_node_or_null("Quote")
	if p == null: return
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		menu_quote = Quotes.next()
		if not is_instance_valid(p) or not p.is_inside_tree(): return
		_fill_menu_quote()
		_layout_menu_quote())
	tw.tween_property(p, "modulate:a", 1.0, 0.4)

func _menu_sel(i: int) -> void:
	if menu_items.is_empty(): return
	menu_sel = posmod(i, menu_items.size())
	for k in menu_items.size():
		var b: Button = menu_items[k]
		var sel := k == menu_sel
		var val: String = b.get_meta("val")
		b.text = ("▶ " if sel else "   ") + str(b.get_meta("label")) + (("   " + val) if val != "" else "")
		var sb := UI.box(G.gold if sel else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 12, 4)
		for st in ["normal", "hover", "pressed"]: b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(c, G.C_INK if sel else G.C_CREAM)

func _menu_act(a: String) -> void:
	match a:
		"resume": resume_game()
		"enter": _start_game(false)
		"room": _start_game(true)
		"ride": _start_ride()
		"map": open_map()
		"visit":
			Sfx.start(); Sfx.start_music()
			visit.start()
		"shop": open_shop()
		"settings": open_settings()
		"lang":
			Sfx.select()
			G.set_lang("it" if G.lang == "en" else "en")
		"audio":
			Sfx.set_enabled(not G.audio_on)
			Sfx.select()
			_apply_texts()
		"help": open_help()

func _layout_menu() -> void:
	if not menu_ui.has_node("Col"): return
	var sz := size
	var col: PanelContainer = menu_ui.get_node("Col")
	var foot: BoxContainer = menu_ui.get_node("Foot")
	# i testi che vanno a capo devono conoscere la larghezza prima di misurare l'altezza:
	# appena creati (o da nascosti) sono larghi zero e il menu risulterebbe altissimo, quindi minuscolo
	var inner: float = (sz.x - 48 if portrait else 572.0) - col.get_theme_stylebox("panel").get_minimum_size().x
	for l in col.get_child(0).get_children():
		if l is Label and l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size.x = inner
			l.size.x = inner
			l.update_minimum_size()
	if portrait:
		col.scale = Vector2.ONE
		col.custom_minimum_size.x = sz.x - 48
		col.size = Vector2(sz.x - 48, 0)
		col.position = Vector2(24, maxf(20, (sz.y - 70 - col.get_combined_minimum_size().y) * 0.45))
	else:
		col.custom_minimum_size.x = 572
		col.size = Vector2(572, 0)
		# sugli schermi bassi il menu si rimpicciolisce un po' invece di uscire dal bordo
		var fit := clampf((sz.y - 40) / maxf(1, col.get_combined_minimum_size().y), 0.55, 1.0)
		col.scale = Vector2(fit, fit)
		col.position = Vector2(sz.x - 572 * fit - maxf(30, sz.x * 0.05), maxf(20, (sz.y - col.get_combined_minimum_size().y * fit) / 2))
	_layout_menu_quote()
	foot.reset_size()
	foot.position = Vector2(24, sz.y - foot.size.y - 12)

# ================================================================== HUD
func _mode_button() -> Button:
	var b := UI.button("", func(): _toggle_mode(), "tool", 18)
	b.name = "Mode"
	_update_mode_button(b)
	return b

## Pulsante dello schermo intero: l'icona (quattro angoli) è disegnata, i font pixel non ce l'hanno.
func _full_button(fs: int) -> Button:
	var b := UI.button("    ", func(): Sfx.select(); G.toggle_fullscreen(), "tool", fs)
	b.name = "Full"
	b.visible = G.can_fullscreen()
	b.draw.connect(func():
		var c := (b.size / 2).round()
		var on := G.is_fullscreen()
		var ink: Color = G.C_INK if b.get_draw_mode() in [BaseButton.DRAW_HOVER, BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else G.C_CREAM
		for sx in [-1, 1]:
			for sy in [-1, 1]:
				var q := c + Vector2(sx, sy) * (3.0 if on else 9.0)
				var dir := Vector2(sx, sy) * (1.0 if on else -1.0)
				b.draw_rect(Rect2(q, Vector2(dir.x * 6, dir.y * 2)).abs(), ink)
				b.draw_rect(Rect2(q, Vector2(dir.x * 2, dir.y * 6)).abs(), ink))
	_update_full_button(b)
	return b

func _icon_button(cb: Callable, paint: Callable) -> Button:
	var b := UI.button("    ", func(): Sfx.select(); cb.call(), "tool", 20)
	b.draw.connect(func():
		var hot: bool = b.get_draw_mode() in [BaseButton.DRAW_HOVER, BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]
		paint.call(b, (b.size / 2).round(), G.C_INK if hot else G.C_CREAM))
	return b

func _paint_camera(b: Button, c: Vector2, ink: Color) -> void:
	b.draw_rect(Rect2(c + Vector2(-10, -5), Vector2(20, 13)), ink, false, 2.0)
	b.draw_rect(Rect2(c + Vector2(-4, -9), Vector2(8, 4)), ink)
	b.draw_arc(c + Vector2(0, 1.5), 3.5, 0, TAU, 16, ink, 2.0)

func _update_full_button(b: Button) -> void:
	if b == null or not is_instance_valid(b): return
	b.tooltip_text = G.t("fullOff" if G.is_fullscreen() else "fullOn") + " (F)"
	b.queue_redraw()

func _update_mode_button(b: Button) -> void:
	if b == null: return
	var m := G.room_mode
	var tx: String
	if m == "walk": tx = "◆ " + G.t("modeWalk")
	elif m == "point": tx = "◆ " + G.t("modePoint")
	else: tx = "◇ " + G.t("roomMode").to_upper() + ": ?"
	b.text = tx
	b.tooltip_text = G.t("modeHint")
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func _toggle_mode() -> void:
	if G.touch: return
	Sfx.toggle()
	G.set_room_mode("point" if G.room_mode == "walk" else "walk")
	if scene == "room": worlds.room.enter()
	toast(("◆ " + G.t("modeWalk") if G.room_mode == "walk" else "◆ " + G.t("modePoint")) + " · " + G.t("modeHint"))

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(PRESET_FULL_RECT)
	hud.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(hud)
	hud_top = Control.new()
	hud_top.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(hud_top)
	var left := UI.hbox(10)
	left.name = "Left"
	hud_top.add_child(left)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UI.box(G.C_PANEL, G.C_INK, 3, 12, 6))
	crumb = UI.label("", 20, G.C_CREAM, UI.f_ui)
	cp.add_child(crumb)
	left.add_child(cp)
	mode_badge = _mode_button()
	left.add_child(mode_badge)
	tools = UI.hbox(8)
	tools.name = "Tools"
	hud_top.add_child(tools)
	b_back = UI.button("", func():
		Sfx.select()
		if scene == "sea": _transition(_enter_street.bind(worlds.street.FORK_X + 20))
		elif scene == "grove": _transition(_enter_street.bind(worlds.street.GROVE_X + 20))
		elif scene in PLACES: _transition(_leave_place)
		else: _transition(_enter_living.bind(true), true))
	b_skip = UI.button("", func(): Sfx.select(); _transition(_enter_room, scene == "living"))
	b_settings = UI.button("✻", func(): open_settings())
	b_lang = UI.button("EN", func(): Sfx.select(); G.set_lang("it" if G.lang == "en" else "en"))
	b_audio = UI.button("♪", func(): Sfx.set_enabled(not G.audio_on); Sfx.select(); _apply_texts())
	b_menu = UI.button("", func(): Sfx.select(); _to_menu())
	b_full = _full_button(20)
	b_shop = UI.button("", func(): open_shop())
	b_shop.icon = ShopUI.coin_icon()
	b_shop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b_shop.add_theme_constant_override("icon_max_width", 24)
	b_photo = _icon_button(func(): if scene != "menu" and not busy: photo.open(), _paint_camera)
	for b in [b_back, b_skip, b_shop, b_settings, b_lang, b_audio, b_photo, b_full, b_menu]: tools.add_child(b)
	place_bar = HFlowContainer.new()
	place_bar.alignment = FlowContainer.ALIGNMENT_CENTER
	place_bar.add_theme_constant_override("h_separation", 8)
	place_bar.add_theme_constant_override("v_separation", 8)
	place_bar.visible = false
	hud.add_child(place_bar)
	place_host = Control.new()
	place_host.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(place_host)
	hint = UI.rich("", 20, G.C_CREAM)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.custom_minimum_size.x = 0
	hint.add_theme_stylebox_override("normal", UI.box(Color(G.C_INK, 0.78), Color(0, 0, 0, 0), 0, 10, 4))
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(hint)
	narr_node = UI.px_panel(Color(G.C_PANEL, 0.96), G.C_CREAM, 18)
	narr_node.mouse_filter = MOUSE_FILTER_IGNORE
	narr_node.get_node("Inner").mouse_filter = MOUSE_FILTER_IGNORE
	narr_txt = UI.rich("", 27, G.C_CREAM)
	narr_txt.mouse_filter = MOUSE_FILTER_IGNORE
	narr_node.get_node("Inner").add_child(narr_txt)
	narr_node.visible = false
	hud.add_child(narr_node)
	route = Control.new()
	route.mouse_filter = MOUSE_FILTER_IGNORE
	route.size = Vector2(400, 58)
	route.visible = false
	route.draw.connect(_draw_route)
	hud.add_child(route)
	prog = PanelContainer.new()
	prog.add_theme_stylebox_override("panel", UI.box(G.C_PANEL, G.C_INK, 3, 12, 6))
	var ph := UI.hbox(10)
	prog_lbl = UI.label("", 18, G.C_CREAM, UI.f_ui)
	prog_pips = UI.hbox(4)
	ph.add_child(prog_lbl)
	ph.add_child(prog_pips)
	prog.add_child(ph)
	prog.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(prog)

func _build_mobile() -> void:
	dialog = UI.px_panel(G.C_CREAM, G.C_INK, 0)
	dialog_txt = UI.rich("", 24, G.C_INK)
	dialog.get_node("Inner").add_child(dialog_txt)
	dialog.visible = false
	dialog.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(dialog)
	sheet = UI.px_panel(G.C_PANEL, G.C_CREAM, 12)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_box = UI.vbox(6)
	sheet_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(sheet_box)
	sheet.get_node("Inner").add_child(sc)
	sheet.visible = false
	add_child(sheet)
	pad = Control.new()
	pad.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(pad)
	var mk := func(txt: String, d: int) -> Button:
		var b := UI.button(txt, func(): pass, "tool", 34)
		b.custom_minimum_size = Vector2(96, 96)
		b.button_down.connect(func(): pad_dir = d)
		b.button_up.connect(func(): if pad_dir == d: pad_dir = 0)
		pad.add_child(b)
		return b
	var pl: Button = mk.call("◀", -1)
	pl.name = "L"
	var pr: Button = mk.call("▶", 1)
	pr.name = "R"
	pad_a = UI.button("★", func(): _do_action(), "solid", 34)
	pad_a.custom_minimum_size = Vector2(110, 110)
	pad_a.name = "A"
	pad.add_child(pad_a)
	pad.visible = false

# ================================================================== layout
var _was_full := false
var _press_at := Vector2.ZERO
var _dragged := 0.0
var _shape := ""                # disposizione attuale: se cambia (telefono ruotato) i testi si ricompongono

func _layout() -> void:
	var win := get_window()
	var px := Vector2(win.size)
	var dpr := DisplayServer.screen_get_scale() if G.is_web else 1.0
	if dpr <= 0: dpr = 1.0
	var css := px / dpr
	portrait = css.x < 760 and css.y > css.x
	compact = css.y < 520 and not portrait
	var shape := "%s%s" % [portrait, compact]
	var reshaped := _shape != "" and shape != _shape
	_shape = shape
	var f: float
	if portrait: f = css.x / 430.0
	elif compact: f = css.y / 540.0
	else: f = clampf(minf(css.x / 1280.0, css.y / 800.0), 0.62, 4.0)
	win.content_scale_factor = maxf(0.3, f * dpr)
	await get_tree().process_frame
	# schermi più larghi di 16:9: il gioco resta un 16:9 centrato (bande ai lati), altrimenti
	# il mondo verrebbe tagliato in alto e le bolle uscirebbero dallo schermo
	var full := get_viewport_rect().size
	var side := maxf(0, roundf((full.x - full.y * MAX_ASPECT) / 2))
	offset_left = side
	offset_right = -side
	var sz := size
	# rettangolo del mondo 320x200
	if scene == "menu" or scene == "loading":
		var s := maxf(sz.x / 320.0, sz.y / 200.0)
		var wsz := Vector2(320, 200) * s
		world_rect = Rect2(Vector2((sz.x - wsz.x) * (0.15 if portrait else 0.3), (sz.y - wsz.y) * 0.5), wsz)
	elif portrait:
		# in verticale il mondo è più grande dello schermo e la "telecamera" segue l'omino
		var s2 := maxf(sz.x / 320.0, minf(sz.y * 0.46 / 200.0, sz.x * 2.0 / 320.0))
		# le scene fisse si vedono tutte intere
		if scene in PLACES and not worlds[scene].walking: s2 = sz.x / 320.0
		world_rect = Rect2(Vector2(world_rect.position.x if world_rect.size.x > 0 else 0.0, 64), Vector2(320, 200) * s2)
		_follow(1.0)
	else:
		# riempie tutto il riquadro di gioco: il mondo può uscire un po' dai bordi
		var s3 := maxf(sz.x / 320.0, sz.y / 200.0)
		var wsz3 := Vector2(320, 200) * s3
		world_rect = Rect2((sz - wsz3) / 2, wsz3)
		_follow(1.0)
	view.position = world_rect.position
	view.size = world_rect.size
	view.pivot_offset = Vector2.ZERO
	stage.position = world_rect.position
	stage.scale = Vector2.ONE * (world_rect.size.x / 1280.0)
	var fl := G.is_fullscreen()
	if fl != _was_full:            # entrato o uscito (anche con ESC o dal browser)
		_was_full = fl
		_update_full_button(b_full)
		_update_full_button(menu_full)
		if modal.visible and modal_kind == "settings": open_settings(true)
	if reshaped and menu_ui.has_node("Col"):
		_apply_texts()              # richiama da sé _layout
		return
	_layout_hud()
	_layout_menu()
	_layout_modal()
	photo._layout()
	visit._layout()

## Verticale: sposta la vista in orizzontale per tenere al centro l'omino (o l'oggetto scelto).
func _follow(k: float) -> void:
	if scene == "menu" or scene == "loading": return
	if world_rect.size.x <= size.x + 1:
		# lo schermo è più largo che alto rispetto al 16:10: si taglia sopra e sotto, tenendo i piedi in vista
		world_rect.position.x = (size.x - world_rect.size.x) / 2
		var over := world_rect.size.y - size.y
		world_rect.position.y = -over * 0.7 if not portrait else 64.0
		view.position = world_rect.position
		view.size = world_rect.size
		stage.position = world_rect.position
		stage.scale = Vector2.ONE * (world_rect.size.x / 1280.0)
		return
	var fx := 160.0
	match scene:
		"street": fx = worlds.street.P.x - worlds.street.cam
		"living": fx = worlds.living.P.x
		"sea": fx = worlds.sea.focus_x()
		"grove": fx = worlds.grove.P.x - worlds.grove.cam
		"train", "arcade", "lab": fx = worlds[scene].P.x - worlds[scene].cam
		"pier": fx = 190.0
		"light": fx = 108.0
		"tower": fx = 205.0
		"room":
			var r = worlds.room
			if G.room_mode == "walk": fx = r.P.x
			elif r.hover != "" and r.boxes.has(r.hover): fx = float(r.boxes[r.hover].cx)
	var s := world_rect.size.x / 320.0
	var tx := clampf(size.x / 2 - fx * s, size.x - world_rect.size.x, 0)
	world_rect.position.x = lerpf(world_rect.position.x, tx, k)
	if not portrait: world_rect.position.y = (size.y - world_rect.size.y) / 2
	view.position = world_rect.position
	view.size = world_rect.size
	stage.position = world_rect.position
	stage.scale = Vector2.ONE * (world_rect.size.x / 1280.0)
	title_lbl.position.x = (size.x / 2 - stage.position.x) / stage.scale.x - 640

func content_scale() -> float:
	return get_window().content_scale_factor

func _layout_hud() -> void:
	var sz := size
	var walk: bool = scene == "street" or scene == "living" or scene == "sea" or scene == "grove" or (scene in PLACES and worlds[scene].walking) or (scene == "room" and G.room_mode == "walk")
	var left: HBoxContainer = hud_top.get_node("Left")
	if portrait:
		left.position = Vector2(8, 8)
		tools.position = Vector2(sz.x - tools.get_combined_minimum_size().x - 8, 8)
		mode_badge.visible = scene == "room"
		if scene == "room":
			if mode_badge.get_parent() != hud:
				mode_badge.get_parent().remove_child(mode_badge)
				hud.add_child(mode_badge)
			mode_badge.position = Vector2(8, world_rect.end.y + 8)
		var below := world_rect.end.y + (56 if scene == "room" else 10)
		hint.visible = false
		prog.visible = false
		dialog.visible = (scene == "street" or scene == "sea" or scene == "grove" or scene in PLACES) and dialog_txt.text != ""
		dialog.position = Vector2(10, below)
		dialog.size = Vector2(sz.x - 20, 0)
		dialog.custom_minimum_size = Vector2(sz.x - 20, 120)
		pad.visible = walk and G.touch or (walk and portrait)
		var pad_y := sz.y - 126
		pad.get_node("L").position = Vector2(14, pad_y + 8)
		pad.get_node("R").position = Vector2(122, pad_y + 8)
		pad_a.position = Vector2(sz.x - 124, pad_y)
		route.size = Vector2(sz.x - 20, 58)
		route.position = Vector2(10, pad_y - 74)
		sheet.visible = scene == "room"
		sheet.position = Vector2(10, below)
		sheet.size = Vector2(sz.x - 20, maxf(160, (pad_y - 26 if walk else sz.y - 10) - below))
		sheet.custom_minimum_size = sheet.size
	else:
		if mode_badge.get_parent() != left:
			mode_badge.get_parent().remove_child(mode_badge)
			left.add_child(mode_badge)
		mode_badge.visible = scene != "menu" and scene != "sea" and scene != "grove" and not scene in PLACES
		var top := maxf(10, world_rect.position.y + 10) if compact else 14.0
		left.position = Vector2(maxf(14, world_rect.position.x + 14), top)
		tools.position = Vector2(minf(sz.x, world_rect.end.x) - tools.get_combined_minimum_size().x - 14, top)
		dialog.visible = false
		sheet.visible = false
		hint.visible = not G.touch and not compact
		hint.reset_size()
		hint.position = Vector2(maxf(14, world_rect.position.x + 14), minf(sz.y, world_rect.end.y) - hint.size.y - 14)
		prog.visible = scene == "room"
		prog.reset_size()
		prog.position = Vector2(minf(sz.x, world_rect.end.x) - prog.size.x - 14, minf(sz.y, world_rect.end.y) - prog.size.y - 14)
		route.size = Vector2(minf(400, sz.x * 0.36), 58)
		route.position = Vector2(minf(sz.x, world_rect.end.x) - route.size.x - 14, minf(sz.y, world_rect.end.y) - 72)
		if G.touch: route.position.x = (sz.x - route.size.x) / 2
		pad.visible = walk and G.touch
		var py := minf(sz.y, world_rect.end.y) - 120
		pad.get_node("L").position = Vector2(world_rect.position.x + 16, py + 10)
		pad.get_node("R").position = Vector2(world_rect.position.x + 124, py + 10)
		pad_a.position = Vector2(world_rect.end.x - 130, py)
		if scene == "room": prog.position.x -= (140 if pad.visible else 0)
	hud.visible = scene != "menu" and scene != "loading"
	if scene != "sea": route.visible = false
	if scene != "sea" and scene != "grove" and not scene in PLACES: narr_node.visible = false
	menu_ui.visible = scene == "menu"
	_layout_bar()
	if not hud.visible:
		dialog.visible = false
		sheet.visible = false
		pad.visible = false

# ================================================================== testi
func _apply_texts() -> void:
	if loading and ld_text: ld_text.text = G.t("loading")
	if G.S.is_empty(): return
	_rebuild_menu()
	var name := str(G.S.get("site_name", "CRI's CAMERETTA"))
	var sc: String = G.t("street") if scene == "street" else G.t("living") if scene == "living" else G.t("sea") if scene == "sea" else G.t("grove") if scene == "grove" else str(G.t("places")[scene]).to_lower() if scene in PLACES else G.L(G.S, "room_crumb")
	crumb.text = name + " · " + sc + (" · " + Weather.label() if scene == "street" and Weather.active() else "")
	crumb.get_parent().visible = not portrait
	b_back.text = "◀" if portrait else G.t("backLab" if scene in LAB else "backSky" if scene in PLACES and place_from == "sky" else "backSea" if scene in PLACES and place_from == "sea" else "backStreet" if scene == "sea" or scene == "grove" or scene in PLACES else "back")
	b_skip.text = G.t("skip")
	b_lang.text = G.lang.to_upper()
	b_audio.text = "♪" if portrait else "♪ " + (G.t("on") if G.audio_on else G.t("off"))
	b_audio.modulate.a = 1.0 if G.audio_on else 0.55
	b_shop.visible = Shop.enabled()
	b_shop.tooltip_text = G.t("shopTitle")
	b_photo.tooltip_text = G.t("photoTitle") + " (P)"
	b_lang.visible = not portrait      # in verticale sta nelle impostazioni
	_update_full_button(b_full)
	b_menu.text = "☰ " + G.t("menu") if not portrait else "☰"
	b_back.visible = scene == "room" or scene == "sea" or scene == "grove" or scene in PLACES
	b_skip.visible = scene == "street" or scene == "living"
	_update_mode_button(mode_badge)
	var hk := "hintWalk"
	if scene == "room": hk = "hintRoomWalk" if G.room_mode == "walk" else "hintRoom"
	if scene == "sea":
		hk = "hintRide" if worlds.sea.riding() else "hintSeaWalk"
		_sea_texts()
	if scene in PLACES:
		hk = {"sky": "hintSky", "tower": "hintTower", "light": "hintLight", "pier": "hintPier", "field": "hintField", "foucault": "hintFou", "aurora": "hintAur", "photon": "hintPho", "coffee": "hintCof"}.get(scene, "hintPlace")
		_rebuild_bar()
	hint.text = G.kbd(G.t(hk))
	_render_progress()
	_render_sign()
	if scene == "street":
		worlds.street.finish_bubbles()
	if modal.visible:
		if modal_kind == "section": open_section(open_id, true)
		elif modal_kind == "help": open_help(true)
		elif modal_kind == "settings": open_settings(true)
		elif modal_kind == "shop": open_shop(true)
		elif modal_kind == "map": open_map(true)
		elif modal_kind == "bottles": open_bottles(true)
		elif modal_kind == "choose": _open_choose(true)
		elif modal_kind == "ride": open_stop(worlds.sea.park_i, true)
		elif modal_kind == "rideend": open_ride_end(true)
	_layout()

func _render_progress() -> void:
	var ids: Array = worlds.room.order()
	var n := 0
	for g in ids:
		if G.explored.has(g): n += 1
	prog_lbl.text = "%s %d/%d" % [G.t("explored"), n, ids.size()]
	for c in prog_pips.get_children(): c.queue_free()
	for g in ids:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.color = G.C_SAGE if G.explored.has(g) else G.C_LINE
		prog_pips.add_child(pip)
	for c in sheet_box.get_children(): c.queue_free()
	var h := UI.label("%s  %d/%d" % [G.t("sheet"), n, ids.size()], 22, G.C_CREAM, UI.f_head, true)
	sheet_box.add_child(h)
	for s in G.sections:
		if not worlds.room.boxes.has(s.id): continue
		var id: String = s.id
		var b := UI.button("%s   ·  %s %s" % [G.L(s, "object_name"), G.L(s, "sign_label").to_lower(), "✓" if G.explored.has(id) else "▶"], func(): _sheet_open(id), "ghost", 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 48
		sheet_box.add_child(b)

func _sheet_open(id: String) -> void:
	if G.room_mode == "walk":
		worlds.room.walk_to(id)
	else:
		open_section(id)

func toast(msg: String) -> void:
	var l: Label = toast_node.get_node("Inner").get_child(0)
	l.text = msg
	toast_node.visible = true
	toast_node.reset_size()
	toast_node.position = Vector2((size.x - toast_node.size.x) / 2, size.y - toast_node.size.y - 24)
	toast_node.modulate.a = 1
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(toast_node, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): toast_node.visible = false)

# ================================================================== scene
## `resume`: si torna da una pausa, quindi niente si azzera e il titolo non ricompare.
func _set_scene(sc: String, resume := false) -> void:
	if sc != "menu" and not visit.visible: paused_scene = ""     # si è ripartiti: la pausa è finita
	scene = sc
	for k in worlds: worlds[k].visible = k == sc
	view.visible = not (sc == "menu" and G.custom_sky)
	sky_custom.visible = sc == "menu" and G.custom_sky
	bubbles_host.visible = sc == "street"
	sea_host.visible = sc == "sea"
	place_host.visible = sc in PLACES
	place_bar.visible = sc in PLACES
	Sfx.radio_scene(sc == "sea")
	if sc == "sea": _rebuild_bar.call_deferred()
	dialog_txt.text = ""
	prompt_node.visible = false
	prompt_action = Callable()
	pad_dir = 0
	Sfx.scene(sc)
	if sc == "room" and not resume: worlds.room.enter()
	_apply_texts()
	if resume: return
	if sc != "menu" and sc != "loading": _show_title(G.t("streetTitles")[Season.now()] if sc == "street" else str(G.t("places")[sc]).to_upper() if sc in PLACES else G.t("titles")[sc])
	else: title_lbl.modulate.a = 0

func _enter_street(at := -1.0) -> void:
	if at >= 0: worlds.street.enter_at(at)
	else: worlds.street.enter()
	_rebuild_bubbles()
	_set_scene("street")
	G.set_hash("strada")

func _enter_sea() -> void:
	worlds.sea.enter()
	_rebuild_sea()
	_set_scene("sea")
	G.set_hash("lungomare")

func _sea_visit(id: String) -> void:
	if scene != "sea": return
	if id == "bottles": open_bottles()
	else: _transition(_enter_place.bind(id, "sea"))

func _enter_path(id: String) -> void:
	match id:
		"sea": _enter_sea()
		"grove": _enter_grove()
		_: _enter_place(id, "street")

## Da un luogo a un altro.
func _goto(id: String) -> void:
	if id == "starname": open_star()
	elif id in LAB: _transition(_enter_place.bind(id, "lab"))
	else: _transition(_enter_place.bind(id, scene))

func _place_label(sc: String) -> String:
	if sc in PLACES or sc in ["street", "room", "grove"]: return G.t("places")[sc]
	return G.t("places")["ride"] if sc == "sea" else G.t("living") if sc == "living" else ""

func place_name() -> String:
	if scene in PLACES or scene in ["street", "room", "grove"]: return G.t("places")[scene]
	return G.t("places")["ride"] if scene == "sea" else G.t("living") if scene == "living" else G.t("menu")

## Il nome della propria stella nel cielo dei caffè.
func open_star(silent := false) -> void:
	var v := UI.vbox(16)
	if not silent: await Shop.sync(false)
	if _star_msg != "" and silent: v.add_child(UI.label(_star_msg, 24, G.gold, null, true))
	if Shop.star_names.is_empty():
		v.add_child(UI.rich(G.t("starNone"), 24, G.C_CREAM))
		if str(G.S.get("donate_url", "")).begins_with("https://"):
			var b := UI.button(G.t("shopCoffee"), func(): G.open_url(str(G.S.donate_url)), "solid", 22)
			b.size_flags_horizontal = SIZE_SHRINK_BEGIN
			v.add_child(b)
	else:
		v.add_child(UI.rich(G.t("starAsk"), 24, G.C_CREAM))
		var le := _line_edit(str(Shop.star_names[0]) if str(Shop.star_names[0]) != "" else G.t("bottleName"), 24)
		v.add_child(le)
		v.add_child(UI.button(G.t("starSend"), func(): _send_star(le.text), "solid", 24))
	_open_modal("star", v, null, _title_row("", "", G.t("places")["coffee"]), 760)
	if not silent: Sfx.open()

var _star_msg := ""
func _send_star(n: String) -> void:
	var r: Array = await Shop._call("/api/wallet/%s/star" % Shop.code, {"name": n})
	_star_msg = G.t("starOk") if r[0] == 200 else G.t("bottleErr")
	if r[0] == 200: Shop._take(r[1])
	if modal.visible and modal_kind == "star": open_star(true)

func _enter_place(id: String, from := "street") -> void:
	# dagli esperimenti si torna al laboratorio, e dal laboratorio in strada
	place_from = from
	worlds[id].enter()
	_set_scene(id)
	_rebuild_bar()
	G.set_hash(id)

## Si torna da dove si era venuti.
func _leave_place() -> void:
	if place_from in PLACES and place_from != scene:
		var back := place_from
		_enter_place(back, "street")
		return
	worlds.lab.at = 30.0
	if place_from == "sea" and not worlds.sea.chapters.is_empty() and worlds.sea.riding():
		_set_scene("sea")
		worlds.sea.resume()
		G.set_hash("lungomare")
	elif scene == "tower" or place_from == "sea": _enter_sea()
	else: _enter_street(worlds.street.path_x(scene) + 20)

func _rebuild_bar() -> void:
	for c in place_bar.get_children(): c.queue_free()
	var list: Array = worlds[scene].bar() if scene in PLACES else [["♪ " + str(G.t("radioNames")[Sfx.station]), func(): worlds.sea.next_station(); _rebuild_bar()]] if scene == "sea" and worlds.sea.riding() else []
	if list.is_empty():
		place_bar.visible = false
		return
	for q in list:
		var f: Callable = q[1]
		place_bar.add_child(UI.button(q[0], func(): f.call(); get_viewport().gui_release_focus(), "tool", 20))
	_layout_bar.call_deferred()

func _layout_bar() -> void:
	place_bar.visible = (scene in PLACES or (scene == "sea" and worlds.sea.riding() and worlds.sea.state in ["ride", "parking", "parked"])) and not modal.visible
	if not place_bar.visible: return
	var bw := -8.0
	for c in place_bar.get_children(): if not c.is_queued_for_deletion(): bw += c.get_combined_minimum_size().x + 8
	place_bar.custom_minimum_size.x = minf(size.x - 24, bw + 2)
	place_bar.reset_size()
	var y := world_rect.end.y + 150.0 if portrait else minf(size.y, world_rect.end.y) - place_bar.get_combined_minimum_size().y - (58 if hint.visible else 14)
	place_bar.position = Vector2((size.x - place_bar.size.x) / 2, y if scene != "sea" else (world_rect.end.y + 150.0 if portrait else 66.0))
	if scene == "sea" and not portrait: place_bar.position.x = minf(size.x, world_rect.end.x) - place_bar.size.x - 14

## Le scritte di un luogo, in coordinate del palco.
func _update_place() -> void:
	var w = worlds[scene]
	w.tall = portrait
	_say_box(w.text(), w.line, w.done())
	var ls: Array = w.labels() if not modal.visible else []
	while place_labels.size() < ls.size():
		var l := UI.label("", 24, G.C_CREAM, UI.f_ui)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.mouse_filter = MOUSE_FILTER_IGNORE
		place_host.add_child(l)
		place_labels.append(l)
	for i in place_labels.size():
		var l: Label = place_labels[i]
		l.visible = i < ls.size()
		if not l.visible: continue
		var q: Dictionary = ls[i]
		if l.text != str(q.t): l.text = str(q.t)
		l.add_theme_font_size_override("font_size", int(q.s * (1.55 if portrait and not w.walking else 1.0)))
		l.add_theme_color_override("font_color", q.c)
		l.reset_size()
		l.position = Vector2(q.x * 4 - l.size.x / 2, q.y * 4 - l.size.y / 2)
	_layout_bar()

func _open_item(it: Dictionary, sec: Dictionary) -> void:
	_open_modal("item", Panels.item_body(it, sec.id == "lavagna"), null, _title_row("", G.L(it, "kicker").to_upper(), G.L(it, "title")), 820)
	Sfx.open()

# ------------------------------------------------------------------ mappa
func open_map(silent := false) -> void:
	var grid := GridContainer.new()
	grid.columns = 1 if portrait else 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for id in ["street", "room", "ride", "grove", "lab", "train", "sky", "arcade", "light", "pier", "tower", "bottles", "coffee"]:
		var pid: String = id
		var b := Button.new()
		b.focus_mode = FOCUS_NONE
		b.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		b.custom_minimum_size.y = 74 if not compact else 66
		b.size_flags_horizontal = SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", UI.box(G.C_INK, G.C_LINE, 3, 8))
		for s in ["hover", "pressed"]: b.add_theme_stylebox_override(s, UI.box(G.C_PANEL2, G.gold, 3, 8))
		b.pressed.connect(func(): Sfx.start(); Sfx.start_music(); close_modal(true); _go_to(pid))
		var v := UI.vbox(0)
		v.set_anchors_preset(PRESET_FULL_RECT)
		v.offset_left = 14; v.offset_right = -10; v.offset_top = 4; v.offset_bottom = -4
		v.mouse_filter = MOUSE_FILTER_IGNORE
		for l in [UI.label(G.t("places")[id], 22, G.gold, UI.f_ui), UI.label(G.t("placeInfo")[id], 19, G.C_MUTED)]:
			l.clip_text = true
			l.mouse_filter = MOUSE_FILTER_IGNORE
			v.add_child(l)
		b.add_child(v)
		grid.add_child(b)
	_open_modal("map", grid, null, _title_row("", G.t("map"), G.t("mapTitle")), 940)
	if not silent: Sfx.open()

func _go_to(id: String) -> void:
	match id:
		"street": _transition(_enter_street)
		"room": _transition(_enter_room)
		"ride": _transition(_enter_sea)
		"grove": _transition(_enter_grove)
		"bottles": open_bottles()
		_: _transition(_enter_place.bind(id, "sea" if id in ["tower", "light", "pier"] else "street"))

# ------------------------------------------------------------------ bottiglie nel mare
var _bottles: Array = []
var _bottle_i := 0
var _bottle_msg := ""
var _bottle_on := true

func open_bottles(silent := false) -> void:
	if not silent:
		_bottle_msg = ""
		var r: Array = await Shop._call("/api/bottles")
		_bottle_on = r[0] == 200 and typeof(r[1]) == TYPE_ARRAY
		_bottles = r[1] if _bottle_on else []
		_bottles.shuffle()
		_bottle_i = 0
		Sfx.open()
	var v := UI.vbox(16)
	if _bottle_msg != "": v.add_child(UI.label(_bottle_msg, 24, G.gold, null, true))
	if not _bottle_on: v.add_child(UI.label(G.t("bottleOff"), 24, G.C_TERRA, null, true))
	elif _bottles.is_empty(): v.add_child(UI.label(G.t("bottleNone"), 24, G.C_CREAM, null, true))
	else:
		var b: Dictionary = _bottles[_bottle_i % _bottles.size()]
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.box(G.C_CREAM, Color("8a5a36"), 4, 22, 16))
		var bv := UI.vbox(6)
		bv.add_child(UI.rich(G.esc_bb(str(b.text)), 27, G.C_INK))
		bv.add_child(UI.label("— " + (str(b.name) if str(b.name) != "" else G.t("bottleAnon")), 21, Color("8a5a36")))
		box.add_child(bv)
		v.add_child(box)
		if _bottles.size() > 1: v.add_child(UI.button(G.t("bottleOther"), func(): Sfx.page(); _bottle_i += 1; open_bottles(true), "ghost", 22))
	if _bottle_on:
		v.add_child(UI.rich(G.t("bottleWrite"), 22, G.C_MUTED))
		if G.is_web and G.touch:
			v.add_child(UI.button(G.t("bottleSend"), func():
				var x := str(JavaScriptBridge.eval("prompt(%s)||''" % JSON.stringify(G.t("bottleText")), true))
				if x.strip_edges() != "": _send_bottle(x, str(JavaScriptBridge.eval("prompt(%s)||''" % JSON.stringify(G.t("bottleName")), true))), "solid", 24))
		else:
			var tx := _line_edit(G.t("bottleText"), 200)
			var nm := _line_edit(G.t("bottleName"), 24)
			v.add_child(tx)
			var row: BoxContainer = UI.vbox(10) if portrait else UI.hbox(10)
			nm.size_flags_horizontal = SIZE_EXPAND_FILL
			row.add_child(nm)
			row.add_child(UI.button(G.t("bottleSend"), func(): _send_bottle(tx.text, nm.text), "solid", 24))
			v.add_child(row)
	_open_modal("bottles", v, null, _title_row("", "", G.t("bottleTitle")), 860)

func _line_edit(ph: String, n: int) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = ph
	le.max_length = n
	le.custom_minimum_size.y = 48
	le.add_theme_font_size_override("font_size", 24)
	le.add_theme_stylebox_override("normal", UI.box(G.C_INK, G.C_LINE, 3, 12, 6))
	le.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), G.gold, 3, 12, 6))
	return le

func _send_bottle(tx: String, nm: String) -> void:
	if tx.strip_edges().length() < 4:
		_bottle_msg = G.t("bottleShort")
	else:
		var r: Array = await Shop._call("/api/bottles", {"text": tx, "name": nm})
		_bottle_msg = G.t("bottleSent") if r[0] == 200 else G.t("bottleErr")
		if r[0] == 200: Sfx.play("stop_pop", 0.7)
	if modal.visible and modal_kind == "bottles": open_bottles(true)

func _enter_grove() -> void:
	worlds.grove.enter()
	_set_scene("grove")
	G.set_hash("templi")

## Dal menu, una volta scoperto: si arriva dritti alla Vespa.
func _start_ride() -> void:
	if busy or scene != "menu": return
	Sfx.start()
	Sfx.start_music()
	_transition(_enter_sea)

func _enter_living(from_room: bool) -> void:
	worlds.living.enter(from_room)
	_set_scene("living")
	G.set_hash("salotto")

func _enter_room() -> void:
	_set_scene("room")
	G.set_hash("stanza")

func _go_room() -> void:
	if G.room_mode == "":
		_open_choose(false, func(): _transition(_enter_room, true))
	else:
		_transition(_enter_room, true)

func _transition(fn: Callable, door := false) -> void:
	if busy: return
	busy = true
	if door: Sfx.door_open()
	Sfx.duck()
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.45)
	await tw.finished
	close_modal(true)
	fn.call()
	await get_tree().create_timer(0.12).timeout
	var tw2 := create_tween()
	tw2.tween_property(fade_rect, "color:a", 0.0, 0.4)
	if door: get_tree().create_timer(0.25).timeout.connect(Sfx.door_close)
	busy = false

var _zoom_tw: Tween

func _start_game(direct: bool) -> void:
	if busy or scene != "menu": return
	if G.room_mode == "":
		_open_choose(false, func(): _start_game(direct))
		return
	Sfx.start()
	Sfx.start_music()
	var to_room := direct or str(G.S.get("skip_intro", "0")) == "1"
	busy = true
	if to_room and not G.custom_sky:
		# zoom nella finestra accesa
		var w: Array = G.J.menu.window
		var c := Vector2((float(w[0]) + float(w[2])) / 2, (float(w[1]) + float(w[3])) / 2) / Vector2(320, 200) * view.size
		view.pivot_offset = c
		_zoom_tw = create_tween()
		_zoom_tw.tween_property(view, "scale", Vector2(1.8, 1.8), 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(0.45).timeout
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.45)
	await tw.finished
	if _zoom_tw: _zoom_tw.kill()
	_zoom_tw = null
	view.scale = Vector2.ONE
	view.pivot_offset = Vector2.ZERO
	if to_room: _enter_room()
	else: _enter_street()
	await get_tree().create_timer(0.1).timeout
	create_tween().tween_property(fade_rect, "color:a", 0.0, 0.4)
	busy = false

func _to_menu() -> void:
	if scene == "menu" or busy: return
	close_modal(true)
	busy = true
	# il menu è una pausa: il mondo si ferma com'è e ci si può tornare
	paused_scene = scene
	paused_x = worlds[scene].P.x if "P" in worlds[scene] else 0.0
	paused_dirty = false
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.4)
	await tw.finished
	_set_scene("menu")
	G.set_hash("")
	create_tween().tween_property(fade_rect, "color:a", 0.0, 0.4)
	busy = false
	_menu_sel(0)

## Riprende esattamente da dove si era.
func resume_game() -> void:
	if scene != "menu" or busy or paused_scene == "": return
	var sc := paused_scene
	Sfx.start()
	Sfx.start_music()
	busy = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.25)
	await tw.finished
	close_modal(true)
	if sc == "street" and paused_dirty:           # la visita in 60 secondi è passata di qui
		worlds.street.enter_at(paused_x)
		_rebuild_bubbles()
	if sc == "room" and paused_dirty:
		worlds.room.enter()
		worlds.room.set_hover("")
	_set_scene(sc, true)
	if sc in PLACES: _rebuild_bar()
	G.set_hash({"street": "strada", "living": "salotto", "room": "stanza", "sea": "lungomare", "grove": "templi"}.get(sc, sc))
	create_tween().tween_property(fade_rect, "color:a", 0.0, 0.3)
	busy = false
	# se in Vespa si era fermi a leggere, la scheda si riapre
	if sc == "sea":
		if worlds.sea.state == "parked": open_stop(worlds.sea.park_i, true)
		elif worlds.sea.state == "end": open_ride_end(true)

# ================================================================== loop
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	if modal.visible and _panel and is_instance_valid(_panel):
		if modal_kind != "section" or _panel.size != _panel_rect.size: _layout_modal()
	if scene == "loading":
		_ld_update()
		if ld_text: ld_text.text = G.t("loading") + ".".repeat(int(Time.get_ticks_msec() / 400.0) % 4)
		return
	if loading and ld_text: ld_text.text = G.t("loading") + ".".repeat(int(Time.get_ticks_msec() / 400.0) % 4)
	var w = worlds.get(scene)
	if w == null: return
	_follow(minf(1.0, dt * 6))
	var blocked: bool = busy or modal.visible or photo.visible or visit.visible
	if scene == "street": Weather.poll(dt)
	if photo.visible: return
	if scene == "street" or scene == "living" or scene == "sea" or scene == "grove" or scene in PLACES:
		w.input_dir = 0 if blocked else _held_dir()
		if scene in PLACES: w.input_up = 0 if blocked else int(Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W))
		w.run = Input.is_physical_key_pressed(KEY_SHIFT)
		w.locked = busy
		w.update(dt)
		if scene == "street": _update_bubbles()
		elif scene == "sea":
			_update_sea()
			_layout_bar()
		elif scene == "grove": _say_box(w.text(), w.line, w.done())
		elif scene in PLACES: _update_place()
		_update_prompt(w.prompt, w.cam if scene != "living" else 0.0)
	elif scene == "room":
		var v := Vector2i.ZERO
		if not blocked and G.room_mode == "walk":
			v.x = _held_dir()
			if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W): v.y -= 1
			if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S): v.y += 1
			v.y += pad_up
		w.input_dir = v
		w.run = Input.is_physical_key_pressed(KEY_SHIFT)
		w.locked = busy or modal.visible
		w.update(dt)
		_update_prompt(w.prompt if G.room_mode == "walk" and not modal.visible else {}, 0.0)
	else:
		w.update(dt)
		if scene == "menu" and not modal.visible:
			menu_quote_t += dt
			if menu_quote_t > 4.5 + G.L(menu_quote, "text").length() * 0.05:
				menu_quote_t = 0.0
				_next_menu_quote()

func _held_dir() -> int:
	var d := 0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A): d -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D): d += 1
	return d if d != 0 else pad_dir

func _update_prompt(p: Dictionary, _cam: float) -> void:
	if p.is_empty() or modal.visible:
		if prompt_node.visible:
			prompt_node.visible = false
			prompt_action = Callable()
		pad_a.disabled = true
		pad_a.modulate.a = 0.45
		return
	var label: String = ("" if G.touch else "[E]  ") + str(p.label)
	if not prompt_node.visible or prompt_node.text != label:
		if not prompt_node.visible: Sfx.hover()
		prompt_node.text = label
		prompt_node.visible = true
		prompt_node.reset_size()
	prompt_action = p.action
	pad_a.disabled = false
	pad_a.modulate.a = 1.0
	var bob := sin(Time.get_ticks_msec() / 250.0) * 4
	prompt_node.position = Vector2(clampf(float(p.x) * 4 - prompt_node.size.x / 2, 8, 1272 - prompt_node.size.x), maxf(8, float(p.y) * 4 - prompt_node.size.y + bob))

func _do_action() -> void:
	if busy or modal.visible: return
	if prompt_action.is_valid(): prompt_action.call()

# ================================================================== input
func _on_view_input(e: InputEvent) -> void:
	if loading or busy: return
	var pos := Vector2.ZERO
	if e is InputEventMouse: pos = e.position / view.size * Vector2(320, 200)
	if scene == "menu":
		if e is InputEventMouseMotion:
			view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if worlds.menu.on_window(pos) else Control.CURSOR_ARROW
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and worlds.menu.on_window(pos):
			_start_game(true)
		return
	if modal.visible: return
	if scene == "room":
		var room = worlds.room
		if e is InputEventMouseMotion and G.room_mode != "walk":
			var g: String = room.group_at(pos)
			room.set_hover(g)
			view.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if g != "" else Control.CURSOR_ARROW
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var g2: String = room.group_at(pos)
			if G.room_mode == "walk":
				room.tap(pos)
			elif g2 != "":
				room.set_hover(g2)
				open_section(g2)
		return
	if scene == "sea" and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		worlds.sea.tap(pos)
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not modal.visible and secrets.tap(pos): return
	if scene in PLACES:
		var pl = worlds[scene]
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				_press_at = pos; _dragged = 0.0
				pl.hold(pos)
			elif e.button_index == MOUSE_BUTTON_WHEEL_UP: pl.zoom(1)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: pl.zoom(-1)
		elif e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pl.release()
			if _dragged < 5.0: pl.tap(pos)
		elif e is InputEventMouseMotion and e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var rel: Vector2 = e.relative * 320.0 / world_rect.size.x
			_dragged += rel.length()
			if _dragged >= 5.0:
				pl.drag(rel)
				pl.move_to(pos)
		return
	if (scene == "street" or scene == "living" or scene == "grove") and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		worlds[scene].tap(pos.x)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo and e.keycode != KEY_LEFT and e.keycode != KEY_RIGHT: return
	if loading: return
	var k: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	if visit.visible:
		if not e.echo: visit.key(k)
		get_viewport().set_input_as_handled()
		return
	if photo.visible:
		if not e.echo:
			if k in [KEY_ESCAPE, KEY_P]: photo.close()
			elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_E]: photo.shoot()
			elif k == KEY_RIGHT: photo.next(1)
			elif k == KEY_LEFT: photo.next(-1)
		get_viewport().set_input_as_handled()
		return
	if k == KEY_P and not e.echo and not modal.visible and not busy and scene != "menu":
		photo.open()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_G and not e.echo and not modal.visible and ghosts.SCENES.has(scene):
		ghosts.greet()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_F and not e.echo and not e.ctrl_pressed and not e.meta_pressed and not e.alt_pressed:
		G.toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if modal.visible:
		if k == KEY_ESCAPE: close_modal()
		elif modal_kind == "section" and (k == KEY_LEFT or k == KEY_RIGHT) and not e.echo:
			var ids: Array = worlds.room.order()
			var i := ids.find(open_id)
			if i >= 0:
				Sfx.page()
				open_section(ids[posmod(i + (1 if k == KEY_RIGHT else -1), ids.size())])
		elif modal_kind == "ride" and not e.echo and k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: close_modal()
		get_viewport().set_input_as_handled()
		return
	if e.echo: return
	match scene:
		"menu":
			if k == KEY_DOWN: _menu_sel(menu_sel + 1); Sfx.move()
			elif k == KEY_UP: _menu_sel(menu_sel - 1); Sfx.move()
			elif k == KEY_ESCAPE: resume_game()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE: _menu_act(menu_items[menu_sel].get_meta("act"))
		"street", "living", "grove":
			if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_UP, KEY_W]: _do_action()
			elif k == KEY_ESCAPE: _to_menu()
			elif (k == KEY_DOWN or k == KEY_S) and scene == "street" and worlds.street.prompt.has("down"): _do_action()
		"sky", "train", "arcade", "tower", "light", "pier", "lab", "field", "foucault", "aurora", "photon", "coffee":
			if k == KEY_ESCAPE: _to_menu()
			elif worlds[scene].press(k): pass
			elif k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_UP, KEY_W]: _do_action()
		"sea":
			if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_UP, KEY_W]: _do_action()
			elif k == KEY_H: worlds.sea.horn()
			elif k == KEY_R and worlds.sea.riding(): worlds.sea.next_station(); _rebuild_bar()
			elif k == KEY_ESCAPE: _to_menu()
		"room":
			var room = worlds.room
			if G.room_mode == "walk":
				if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: _do_action()
				elif k == KEY_ESCAPE: _transition(_enter_living.bind(true), true)
			else:
				var ids: Array = room.order()
				if (k == KEY_LEFT or k == KEY_RIGHT) and ids.size() > 0:
					var i := ids.find(room.hover)
					var n: String = ids[0] if i < 0 else ids[posmod(i + (1 if k == KEY_RIGHT else -1), ids.size())]
					room.set_hover(n)
				elif (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_E) and room.hover != "": open_section(room.hover)
				elif k == KEY_ESCAPE: _transition(_enter_living.bind(true), true)
	get_viewport().set_input_as_handled()

# ================================================================== finestre (schede, impostazioni, aiuto)
var _panel: PanelContainer
var _panel_max := Vector2(1060, 740)

func _open_modal(kind: String, content: Control, footer: Control, title_row: Control, maxw := 1060.0) -> void:
	for c in modal.get_children(): c.queue_free()
	modal_kind = kind
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.1, 0.72)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: close_modal())
	modal.add_child(dim)
	_panel = UI.px_panel(G.C_PANEL, G.C_CREAM, 0)
	_panel.mouse_filter = MOUSE_FILTER_STOP
	modal.add_child(_panel)
	var v := UI.vbox(0)
	_panel.get_node("Inner").add_child(v)
	var head := UI.margin(title_row, 22, 16, 16, 14)
	v.add_child(head)
	var line := ColorRect.new()
	line.color = G.C_LINE
	line.custom_minimum_size.y = 3
	v.add_child(line)
	var sc := ScrollContainer.new()
	sc.name = "Scroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.follow_focus = false
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(UI.margin(content, 24, 20, 24, 24))
	sc.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	if footer:
		var line2 := ColorRect.new()
		line2.color = G.C_LINE
		line2.custom_minimum_size.y = 3
		v.add_child(line2)
		v.add_child(UI.margin(footer, 16, 10, 16, 10))
	_panel_max = Vector2(maxw, 740)
	modal.visible = true
	_layout_modal()
	_render_sign()

func _layout_modal() -> void:
	if not modal.visible or _panel == null or not is_instance_valid(_panel): return
	var sz := size
	var w: float
	var h: float
	if portrait:
		w = sz.x
		h = sz.y
	else:
		w = minf(_panel_max.x, sz.x - 48)
		h = minf(_panel_max.y, sz.y - 48)
		if modal_kind != "section":
			var sc: ScrollContainer = _panel.find_child("Scroll", true, false)
			if sc and sc.get_child_count() > 0:
				_panel.custom_minimum_size = Vector2(w, 0)
				h = minf(h, _panel.get_combined_minimum_size().y + sc.get_child(0).get_combined_minimum_size().y + 4)
	_panel.custom_minimum_size = Vector2(w, h)
	_panel.size = Vector2(w, h)
	_panel.position = (sz - Vector2(w, h)) / 2
	_panel_rect = Rect2(_panel.position, Vector2(w, h))

var _panel_rect := Rect2()

func _title_row(id: String, kicker: String, title: String) -> HBoxContainer:
	var row := UI.hbox(16)
	if id != "": row.add_child(UI.icon(id, 4))
	var col := UI.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if kicker != "": col.add_child(UI.label(kicker, 18, G.C_DIM, UI.f_ui))
	var tl := UI.label(title, 34 if not portrait else 25, G.C_CREAM, UI.f_head, true)
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(tl)
	row.add_child(col)
	var close := UI.button("✕" if portrait else "✕ " + G.t("close") + ("" if G.touch else "  ESC"), func(): close_modal(), "tool", 22 if portrait else 18)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(close)
	return row

func open_section(id: String, silent := false) -> void:
	if not G.by_id.has(id): return
	var s: Dictionary = G.by_id[id]
	open_id = id
	G.mark_explored(id)
	Shop.earn("section:" + id)
	var ids: Array = worlds.room.order()
	if ids.is_empty():
		for x in G.sections: ids.append(x.id)
	var k := ids.find(id)
	var prev: Dictionary = G.by_id[ids[posmod(k - 1, ids.size())]]
	var next: Dictionary = G.by_id[ids[posmod(k + 1, ids.size())]]
	var body := Panels.section_body(s, portrait or size.x < 900)
	var foot := UI.hbox(10)
	var pid: String = prev.id
	var nid: String = next.id
	var bp := UI.button("◀ " + G.L(prev, "object_name"), func(): _page(pid), "ghost", 20)
	var bn := UI.button(G.L(next, "object_name") + " ▶", func(): _page(nid), "ghost", 20)
	var pips := UI.hbox(6)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	for g in ids:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.color = G.gold if g == id else (G.C_SAGE if G.explored.has(g) else G.C_LINE)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
	foot.add_child(bp)
	foot.add_child(pips)
	foot.add_child(bn)
	var accent := Color(str(s.get("color", "#f2b85b"))) if Color.html_is_valid(str(s.get("color", ""))) else G.gold
	var tr := _title_row(id, G.L(s, "object_name").to_upper(), G.L(s, "title"))
	_open_modal("section", body, foot, tr)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size.y = 6
	_panel.get_node("Inner").get_child(0).add_child(bar)
	_panel.get_node("Inner").get_child(0).move_child(bar, 0)
	if not silent: Sfx.open()
	G.set_hash(id)
	_render_progress()

func _page(id: String) -> void:
	Sfx.page()
	open_section(id, true)

func close_modal(quiet := false) -> void:
	if not modal.visible: return
	var was_section := modal_kind == "section"
	var was_ride := modal_kind == "ride" or (modal_kind == "rideend" and not quiet)
	modal.visible = false
	modal_kind = ""
	open_id = ""
	for c in modal.get_children(): c.queue_free()
	_panel = null
	if was_section: G.set_hash("stanza")
	if was_ride and scene == "sea": worlds.sea.resume()
	if not quiet: Sfx.close()
	_render_sign()
	if after_choose.is_valid() and not quiet:
		after_choose = Callable()

## Tappa del giro in Vespa: una voce sola, raccontata in grande.
func open_stop(i: int, silent := false) -> void:
	var sea = worlds.sea
	if i < 0 or i >= sea.stops.size(): return
	var s: Dictionary = sea.stops[i]
	var ch: Dictionary = sea.chapters[s.ch]
	var place: String = G.t("ridePlaces").get(ch.id, G.L(ch.sec, "sign_label"))
	var row := _title_row("", "%s · %s" % [G.t("rideStopN") % [i + 1, sea.stops.size()], place.to_upper()], G.L(s.it, "title"))
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color("24493a") if ch.id == "lavagna" else G.C_INK, G.C_LINE, 3, 10))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var em := TextureRect.new()
	em.texture = sea.emblem_tex(s.emblem)
	em.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.custom_minimum_size = Vector2(80, 80) if not portrait else Vector2(48, 48)
	frame.add_child(em)
	row.add_child(frame)
	row.move_child(frame, 0)
	var foot := UI.hbox(10)
	var cnt := UI.label("%s %d/%d" % [G.t("rideStops"), sea.seen_count(), sea.stops.size()], 20, G.C_MUTED, UI.f_ui)
	cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(cnt)
	var pips := UI.hbox(5)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	for j in sea.stops.size():
		if sea.stops[j].ch != s.ch: continue
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.color = G.gold if j == i else (G.C_SAGE if sea.stops[j].seen else G.C_LINE)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.add_child(pip)
	foot.add_child(pips)
	foot.add_child(UI.button(G.t("rideGoOn"), func(): close_modal(), "solid", 22))
	_open_modal("ride", Panels.item_body(s.it, ch.id == "lavagna"), foot, row, 820)
	var bar := ColorRect.new()
	bar.color = Color(str(ch.sec.get("color", "#f2b85b"))) if Color.html_is_valid(str(ch.sec.get("color", ""))) else G.gold
	bar.custom_minimum_size.y = 6
	_panel.get_node("Inner").get_child(0).add_child(bar)
	_panel.get_node("Inner").get_child(0).move_child(bar, 0)
	if not silent: Sfx.open()

## Fine del giro, al belvedere.
func open_ride_end(silent := false) -> void:
	Shop.earn("ride_end")
	var sea = worlds.sea
	var n: int = sea.seen_count()
	var v := UI.vbox(16)
	v.add_child(UI.label(G.t("rideEndSeen") % [n, sea.stops.size()], 28, G.gold, UI.f_head, true))
	v.add_child(UI.rich(G.t("rideEndAll") if n >= sea.stops.size() else G.t("rideEndSome"), 26, G.C_CREAM))
	var bits := HFlowContainer.new()
	bits.add_theme_constant_override("h_separation", 10)
	bits.add_theme_constant_override("v_separation", 10)
	bits.add_child(UI.button(G.t("rideHome"), func(): Sfx.select(); _transition(_enter_street.bind(float(G.J.street.door.x) - 52)), "solid", 24))
	bits.add_child(UI.button(G.t("rideAgain"), func(): Sfx.select(); _transition(_enter_sea), "ghost", 22))
	bits.add_child(UI.button(G.t("towerGo"), func(): Sfx.select(); _transition(_enter_place.bind("tower", "sea")), "ghost", 22))
	if G.safe_url(str(G.S.get("cv_url", ""))): bits.add_child(UI.button(G.t("cv"), func(): G.open_url(str(G.S.cv_url)), "ghost", 22))
	if G.safe_url(str(G.S.get("github_url", ""))): bits.add_child(UI.button("GitHub ↗", func(): G.open_url(str(G.S.github_url)), "ghost", 22))
	v.add_child(bits)
	_open_modal("rideend", v, null, _title_row("finestra", "", G.t("rideEndTitle")), 760)
	if not silent: Sfx.open()

func open_shop(silent := false) -> void:
	if not Shop.enabled(): return
	if not silent:
		ShopUI.getting = false
		ShopUI.msg = ""
	var keep := 0
	if modal.visible and modal_kind == "shop":
		var old: ScrollContainer = _panel.find_child("Scroll", true, false)
		if old: keep = old.scroll_vertical
	_open_modal("shop", ShopUI.build(self), null, _title_row("", "", G.t("shopTitle")), 1080)
	if not silent:
		Sfx.open()
		if await Shop.sync(): Shop.earn("daily")
	elif keep > 0:
		var sc: ScrollContainer = _panel.find_child("Scroll", true, false)
		await get_tree().process_frame
		if is_instance_valid(sc): sc.scroll_vertical = keep

## Il tema scelto nel negozio: colora il mondo e gli accenti dell'interfaccia.
func _apply_theme() -> void:
	view.material = Shop.theme_material()
	G.gold = Shop.accent()
	if scene != "loading": _apply_texts()

func open_help(silent := false) -> void:
	var v := UI.vbox(14)
	for x in G.t("helpItems"):
		v.add_child(UI.rich("[color=#f2b85b]◆[/color]  " + G.kbd(x), 23, G.C_CREAM))
	_open_modal("help", v, null, _title_row("", "", G.t("helpTitle")), 780)
	if not silent: Sfx.open()

func _seg(options: Array, current: String, cb: Callable) -> HBoxContainer:
	var h := UI.hbox(8)
	for o in options:
		var val: String = o[0]
		var b := UI.button(o[1], func(): cb.call(val), "solid" if val == current else "ghost", 20)
		h.add_child(b)
	return h

func _row(label: String, ctl: Control) -> Control:
	var r: BoxContainer = UI.vbox(6) if portrait else UI.hbox(18)
	var l := UI.label(label, 24, G.C_CREAM, UI.f_ui)
	l.custom_minimum_size.x = 0 if portrait else 200
	r.add_child(l)
	ctl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(ctl)
	return r

func _slider(val: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 1
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(240, 34)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(cb)
	s.drag_ended.connect(func(_c): Sfx.click())
	return s

func open_settings(silent := false) -> void:
	var v := UI.vbox(12)
	v.add_child(_row(G.t("language"), _seg([["en", "ENGLISH"], ["it", "ITALIANO"]], G.lang, func(x): Sfx.select(); G.set_lang(x))))
	v.add_child(_row(G.t("audio"), _seg([["on", G.t("on")], ["off", G.t("off")]], "on" if G.audio_on else "off", func(x): Sfx.set_enabled(x == "on"); Sfx.select(); open_settings(true))))
	var ss: Array = [["auto", G.t("seasonAuto")]]
	for q in Season.IDS: ss.append([q, G.t("seasons")[q]])
	v.add_child(_row(G.t("season"), _seg_flow(ss, G.season, func(x): Sfx.select(); _set_season(x))))
	v.add_child(_row(G.t("weatherT"), _seg([["on", G.t("weatherOn")], ["off", G.t("off")]], "on" if G.real_weather else "off", func(x): Sfx.select(); G.real_weather = x == "on"; G.save_prefs(); open_settings(true))))
	v.add_child(_row(G.t("ghostsT"), _seg([["on", G.t("on")], ["off", G.t("off")]], "on" if G.ghosts else "off", func(x): Sfx.select(); G.ghosts = x == "on"; G.save_prefs(); open_settings(true))))
	if G.can_fullscreen():
		v.add_child(_row(G.t("full"), _seg([["on", G.t("on")], ["off", G.t("off")]], "on" if G.is_fullscreen() else "off", func(x): Sfx.select(); if (x == "on") != G.is_fullscreen(): G.toggle_fullscreen())))
	if not G.touch:
		var mode := _seg([["walk", G.t("walk")], ["point", G.t("point")]], G.room_mode, func(x): _set_mode(x))
		v.add_child(_row(G.t("roomMode"), mode))
	v.add_child(_row(G.t("music"), _slider(G.music_user, func(x): G.music_user = x; G.save_prefs(); Sfx.apply_volumes())))
	v.add_child(_row(G.t("effects"), _slider(G.effects_user, func(x): G.effects_user = x; G.save_prefs(); Sfx.apply_volumes())))
	_open_modal("settings", v, null, _title_row("", "", G.t("settings").capitalize()), 760)
	if not silent: Sfx.open()

## Come _seg, ma va a capo se non c'è posto.
func _seg_flow(options: Array, current: String, cb: Callable) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 8)
	for o in options:
		var val: String = o[0]
		h.add_child(UI.button(o[1], func(): cb.call(val), "solid" if val == current else "ghost", 20))
	return h

func _set_season(x: String) -> void:
	G.season = x
	G.save_prefs()
	Season.apply()
	Shop.apply()
	if modal.visible and modal_kind == "settings": open_settings(true)

func _set_mode(m: String) -> void:
	Sfx.toggle()
	G.set_room_mode(m)
	if scene == "room": worlds.room.enter()

func _open_choose(silent := false, then := Callable()) -> void:
	if then.is_valid(): after_choose = then
	var v := UI.vbox(16)
	for o in [["walk", G.t("walk"), G.t("chooseWalk")], ["point", G.t("point"), G.t("choosePoint")]]:
		var val: String = o[0]
		var card := UI.vbox(8)
		var b := UI.button(o[1], func(): _choose(val), "solid", 26)
		b.custom_minimum_size.y = 60
		card.add_child(b)
		card.add_child(UI.rich(G.kbd(o[2]), 22, G.C_MUTED))
		v.add_child(card)
	v.add_child(UI.label(G.t("modeHint"), 19, G.C_DIM, null, true))
	_open_modal("choose", v, null, _title_row("", G.t("roomMode").to_upper(), G.t("chooseTitle")), 720)
	if not silent: Sfx.open()

func _choose(m: String) -> void:
	Sfx.select()
	G.set_room_mode(m)
	var cb := after_choose
	after_choose = Callable()
	close_modal(true)
	if cb.is_valid(): cb.call()
