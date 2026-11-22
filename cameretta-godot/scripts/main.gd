extends Control
## Regia del gioco: caricamento, menu, scene, HUD, schede, input (tastiera, mouse, touch).

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
	for n in ["menu", "street", "living", "room"]:
		var w := Node2D.new()
		w.set_script(load("res://scripts/%s.gd" % n))
		w.visible = false
		sv.add_child(w)
		worlds[n] = w
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
	worlds.room.open_section.connect(func(id): open_section(id))
	worlds.room.hover_changed.connect(func(_g): _render_sign())
	_layout()
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
	sign_node = Control.new()
	sign_node.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(sign_node)
	title_lbl = UI.label("", 64, G.C_CREAM, UI.f_head)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_color_override("font_shadow_color", G.C_INK)
	title_lbl.add_theme_constant_override("shadow_offset_x", 5)
	title_lbl.add_theme_constant_override("shadow_offset_y", 5)
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
	if quote: v.add_child(UI.label("“", 44, G.gold, UI.f_head))
	var r := UI.rich("", 25, G.C_CREAM if quote else G.C_INK)
	r.name = "T"
	r.custom_minimum_size.x = 300
	r.mouse_filter = MOUSE_FILTER_IGNORE
	v.add_child(r)
	if quote and str(B.data.get("author", "")) != "":
		var a := UI.label("— " + str(B.data.author), 21, G.gold)
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
		if a: a.modulate.a = 1.0 if B.state == "done" else 0.0
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
		last_auth = str(B.data.get("author", "")) if B.state == "done" else ""
	if portrait and dialog:
		var bb := G.esc_bb(last_text)
		if last_quote and last_auth != "": bb += "\n[color=#f2b85b]— %s[/color]" % G.esc_bb(last_auth)
		if dialog_txt.text != bb:
			dialog_txt.text = bb
			dialog.visible = scene == "street" and bb != "" and not modal.visible
		dialog.get_node("Inner").add_theme_stylebox_override("panel", UI.box(Color("26204a") if last_quote else G.C_CREAM, G.gold if last_quote else G.C_INK, 4, 14, 10))
		dialog_txt.add_theme_color_override("default_color", G.C_CREAM if last_quote else G.C_INK)

func _show_title(text: String) -> void:
	title_lbl.text = text
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
	var kick := UI.label(G.L(S, "menu_kicker"), 22, G.C_SKY, UI.f_ui)
	col.add_child(kick)
	var nm := UI.label(str(S.get("site_name", "ERACUL")), 96 if not portrait else 64, G.C_CREAM, UI.f_head)
	nm.add_theme_color_override("font_shadow_color", G.C_TERRA)
	nm.add_theme_constant_override("shadow_offset_x", 6)
	nm.add_theme_constant_override("shadow_offset_y", 6)
	col.add_child(nm)
	col.add_child(UI.label(G.L(S, "menu_subtitle"), 28, G.gold, UI.f_ui, true))
	var tag := UI.label(G.L(S, "menu_tagline"), 24, G.C_MUTED, null, true)
	col.add_child(tag)
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
		["room", G.t("room"), ""],
		["settings", G.t("settings"), G.t("walk") if G.room_mode == "walk" else G.t("point") if G.room_mode == "point" else ""],
		["lang", G.t("language").to_upper(), G.t("langName").to_upper()],
		["audio", G.t("audio").to_upper(), G.t("on") if G.audio_on else G.t("off")],
		["help", G.t("help"), ""],
	]
	for i in items.size():
		var it: Array = items[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(440 if not portrait else 0, 50)
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
	if not G.touch:
		var press := UI.label(G.L(S, "press_text"), 20, G.C_DIM, UI.f_ui, true)
		col.add_child(press)
	# modalità della cameretta: sempre indicata
	menu_mode_lbl = _mode_button()
	col.add_child(menu_mode_lbl)
	var foot: BoxContainer = UI.vbox(2) if portrait else UI.hbox(14)
	foot.name = "Foot"
	menu_ui.add_child(foot)
	foot.add_child(UI.label(G.L(S, "footer_text"), 18, G.C_DIM))
	if G.safe_url(str(S.get("github_url", ""))):
		var gh: String = S.github_url
		var gb := UI.button(gh.replace("https://", "").replace("http://", ""), func(): G.open_url(gh), "link", 18)
		foot.add_child(gb)
	_layout_menu()

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
		"enter": _start_game(false)
		"room": _start_game(true)
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
	if portrait:
		col.custom_minimum_size.x = sz.x - 48
		col.size = Vector2(sz.x - 48, 0)
		col.position = Vector2(24, maxf(20, (sz.y - 70 - col.get_combined_minimum_size().y) * 0.45))
	else:
		col.custom_minimum_size.x = 572
		col.size = Vector2(572, 0)
		col.position = Vector2(sz.x - 572 - maxf(30, sz.x * 0.05), maxf(20, (sz.y - col.get_combined_minimum_size().y) / 2))
	foot.reset_size()
	foot.position = Vector2(24, sz.y - foot.size.y - 12)

# ================================================================== HUD
func _mode_button() -> Button:
	var b := UI.button("", func(): _toggle_mode(), "ghost", 18)
	b.name = "Mode"
	_update_mode_button(b)
	return b

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
	b_back = UI.button("", func(): Sfx.select(); _transition(_enter_living.bind(true), true))
	b_skip = UI.button("", func(): Sfx.select(); _transition(_enter_room, scene == "living"))
	b_settings = UI.button("✻", func(): open_settings())
	b_lang = UI.button("EN", func(): Sfx.select(); G.set_lang("it" if G.lang == "en" else "en"))
	b_audio = UI.button("♪", func(): Sfx.set_enabled(not G.audio_on); Sfx.select(); _apply_texts())
	b_menu = UI.button("", func(): Sfx.select(); _to_menu())
	for b in [b_back, b_skip, b_settings, b_lang, b_audio, b_menu]: tools.add_child(b)
	hint = UI.rich("", 20, G.C_CREAM)
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.custom_minimum_size.x = 0
	hint.add_theme_stylebox_override("normal", UI.box(Color(G.C_INK, 0.78), Color(0, 0, 0, 0), 0, 10, 4))
	hint.mouse_filter = MOUSE_FILTER_IGNORE
	hud.add_child(hint)
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
func _layout() -> void:
	var win := get_window()
	var px := Vector2(win.size)
	var dpr := DisplayServer.screen_get_scale() if G.is_web else 1.0
	if dpr <= 0: dpr = 1.0
	var css := px / dpr
	portrait = css.x < 760 and css.y > css.x
	compact = css.y < 520 and not portrait
	var f: float
	if portrait: f = css.x / 430.0
	elif compact: f = css.y / 540.0
	else: f = clampf(minf(css.x / 1280.0, css.y / 800.0), 0.62, 2.2)
	win.content_scale_factor = maxf(0.3, f * dpr)
	await get_tree().process_frame
	var sz := size
	# rettangolo del mondo 320x200
	if scene == "menu" or scene == "loading":
		var s := maxf(sz.x / 320.0, sz.y / 200.0)
		var wsz := Vector2(320, 200) * s
		world_rect = Rect2(Vector2((sz.x - wsz.x) * (0.15 if portrait else 0.3), (sz.y - wsz.y) * 0.5), wsz)
	elif portrait:
		# in verticale il mondo è più grande dello schermo e la "telecamera" segue l'omino
		var s2 := maxf(sz.x / 320.0, minf(sz.y * 0.46 / 200.0, sz.x * 2.0 / 320.0))
		world_rect = Rect2(Vector2(world_rect.position.x if world_rect.size.x > 0 else 0.0, 64), Vector2(320, 200) * s2)
		_follow(1.0)
	else:
		var s3 := minf(sz.x / 320.0, sz.y / 200.0)
		var real := s3 * content_scale()
		var fl := floorf(real)
		if fl >= 2 and fl / real >= 0.88: s3 = fl / content_scale()
		var wsz3 := Vector2(320, 200) * s3
		world_rect = Rect2((sz - wsz3) / 2, wsz3)
	view.position = world_rect.position
	view.size = world_rect.size
	view.pivot_offset = Vector2.ZERO
	stage.position = world_rect.position
	stage.scale = Vector2.ONE * (world_rect.size.x / 1280.0)
	_layout_hud()
	_layout_menu()
	_layout_modal()

## Verticale: sposta la vista in orizzontale per tenere al centro l'omino (o l'oggetto scelto).
func _follow(k: float) -> void:
	if not portrait or scene == "menu" or scene == "loading": return
	var fx := 160.0
	match scene:
		"street": fx = worlds.street.P.x - worlds.street.cam
		"living": fx = worlds.living.P.x
		"room":
			var r = worlds.room
			if G.room_mode == "walk": fx = r.P.x
			elif r.hover != "" and r.boxes.has(r.hover): fx = float(r.boxes[r.hover].cx)
	var s := world_rect.size.x / 320.0
	var tx := clampf(size.x / 2 - fx * s, size.x - world_rect.size.x, 0)
	world_rect.position.x = lerpf(world_rect.position.x, tx, k)
	view.position = world_rect.position
	view.size = world_rect.size
	stage.position = world_rect.position
	stage.scale = Vector2.ONE * (world_rect.size.x / 1280.0)
	title_lbl.position.x = (size.x / 2 - stage.position.x) / stage.scale.x - 640

func content_scale() -> float:
	return get_window().content_scale_factor

func _layout_hud() -> void:
	var sz := size
	var walk := scene == "street" or scene == "living" or (scene == "room" and G.room_mode == "walk")
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
		dialog.visible = scene == "street" and dialog_txt.text != ""
		dialog.position = Vector2(10, below)
		dialog.size = Vector2(sz.x - 20, 0)
		dialog.custom_minimum_size = Vector2(sz.x - 20, 120)
		pad.visible = walk and G.touch or (walk and portrait)
		var pad_y := sz.y - 126
		pad.get_node("L").position = Vector2(14, pad_y + 8)
		pad.get_node("R").position = Vector2(122, pad_y + 8)
		pad_a.position = Vector2(sz.x - 124, pad_y)
		sheet.visible = scene == "room"
		sheet.position = Vector2(10, below)
		sheet.size = Vector2(sz.x - 20, maxf(160, (pad_y - 14 if walk else sz.y - 10) - below))
		sheet.custom_minimum_size = sheet.size
	else:
		if mode_badge.get_parent() != left:
			mode_badge.get_parent().remove_child(mode_badge)
			left.add_child(mode_badge)
		mode_badge.visible = scene != "menu"
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
		pad.visible = walk and G.touch
		var py := minf(sz.y, world_rect.end.y) - 120
		pad.get_node("L").position = Vector2(world_rect.position.x + 16, py + 10)
		pad.get_node("R").position = Vector2(world_rect.position.x + 124, py + 10)
		pad_a.position = Vector2(world_rect.end.x - 130, py)
		if scene == "room": prog.position.x -= (140 if pad.visible else 0)
	hud.visible = scene != "menu" and scene != "loading"
	menu_ui.visible = scene == "menu"
	if not hud.visible:
		dialog.visible = false
		sheet.visible = false
		pad.visible = false

# ================================================================== testi
func _apply_texts() -> void:
	if loading and ld_text: ld_text.text = G.t("loading")
	if G.S.is_empty(): return
	_rebuild_menu()
	var name := str(G.S.get("site_name", "ERACUL"))
	var sc: String = G.t("street") if scene == "street" else G.t("living") if scene == "living" else G.L(G.S, "room_crumb")
	crumb.text = name if portrait else name + " · " + sc
	b_back.text = "◀" if portrait else G.t("back")
	b_skip.text = G.t("skip")
	b_lang.text = G.lang.to_upper()
	b_audio.text = "♪" if portrait else "♪ " + (G.t("on") if G.audio_on else G.t("off"))
	b_audio.modulate.a = 1.0 if G.audio_on else 0.55
	b_menu.text = "☰ " + G.t("menu") if not portrait else "☰"
	b_back.visible = scene == "room"
	b_skip.visible = scene == "street" or scene == "living"
	_update_mode_button(mode_badge)
	var hk := "hintWalk"
	if scene == "room": hk = "hintRoomWalk" if G.room_mode == "walk" else "hintRoom"
	hint.text = G.kbd(G.t(hk))
	_render_progress()
	_render_sign()
	if scene == "street":
		worlds.street.finish_bubbles()
	if modal.visible:
		if modal_kind == "section": open_section(open_id, true)
		elif modal_kind == "help": open_help(true)
		elif modal_kind == "settings": open_settings(true)
		elif modal_kind == "choose": _open_choose(true)
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
func _set_scene(sc: String) -> void:
	scene = sc
	for k in worlds: worlds[k].visible = k == sc
	view.visible = not (sc == "menu" and G.custom_sky)
	sky_custom.visible = sc == "menu" and G.custom_sky
	bubbles_host.visible = sc == "street"
	prompt_node.visible = false
	prompt_action = Callable()
	pad_dir = 0
	Sfx.scene(sc)
	if sc == "room": worlds.room.enter()
	_apply_texts()
	if sc != "menu" and sc != "loading": _show_title(G.t("titles")[sc])
	else: title_lbl.modulate.a = 0

func _enter_street() -> void:
	worlds.street.enter()
	_rebuild_bubbles()
	_set_scene("street")
	G.set_hash("strada")

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
		var tz := create_tween()
		tz.tween_property(view, "scale", Vector2(1.8, 1.8), 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await get_tree().create_timer(0.45).timeout
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.45)
	await tw.finished
	view.scale = Vector2.ONE
	if to_room: _enter_room()
	else: _enter_street()
	await get_tree().create_timer(0.1).timeout
	create_tween().tween_property(fade_rect, "color:a", 0.0, 0.4)
	busy = false

func _to_menu() -> void:
	if scene == "menu" or busy: return
	close_modal(true)
	busy = true
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, 0.4)
	await tw.finished
	_set_scene("menu")
	G.set_hash("")
	create_tween().tween_property(fade_rect, "color:a", 0.0, 0.4)
	busy = false
	_menu_sel(0)

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
	var blocked := busy or modal.visible
	if scene == "street" or scene == "living":
		w.input_dir = 0 if blocked else _held_dir()
		w.run = Input.is_physical_key_pressed(KEY_SHIFT)
		w.locked = busy
		w.update(dt)
		if scene == "street": _update_bubbles()
		_update_prompt(w.prompt, w.cam if scene == "street" else 0.0)
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
	if (scene == "street" or scene == "living") and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		worlds[scene].tap(pos.x)

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo and e.keycode != KEY_LEFT and e.keycode != KEY_RIGHT: return
	if loading: return
	var k: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	if modal.visible:
		if k == KEY_ESCAPE: close_modal()
		elif modal_kind == "section" and (k == KEY_LEFT or k == KEY_RIGHT) and not e.echo:
			var ids: Array = worlds.room.order()
			var i := ids.find(open_id)
			if i >= 0:
				Sfx.page()
				open_section(ids[posmod(i + (1 if k == KEY_RIGHT else -1), ids.size())])
		get_viewport().set_input_as_handled()
		return
	if e.echo: return
	match scene:
		"menu":
			if k == KEY_DOWN: _menu_sel(menu_sel + 1); Sfx.move()
			elif k == KEY_UP: _menu_sel(menu_sel - 1); Sfx.move()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE: _menu_act(menu_items[menu_sel].get_meta("act"))
		"street", "living":
			if k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_UP, KEY_W]: _do_action()
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
	modal.visible = false
	modal_kind = ""
	open_id = ""
	for c in modal.get_children(): c.queue_free()
	_panel = null
	if was_section: G.set_hash("stanza")
	if not quiet: Sfx.close()
	_render_sign()
	if after_choose.is_valid() and not quiet:
		after_choose = Callable()

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
	var v := UI.vbox(20)
	v.add_child(_row(G.t("language"), _seg([["en", "ENGLISH"], ["it", "ITALIANO"]], G.lang, func(x): Sfx.select(); G.set_lang(x))))
	v.add_child(_row(G.t("audio"), _seg([["on", G.t("on")], ["off", G.t("off")]], "on" if G.audio_on else "off", func(x): Sfx.set_enabled(x == "on"); Sfx.select(); open_settings(true))))
	var mode := _seg([["walk", G.t("walk")], ["point", G.t("point")]], G.room_mode, func(x): _set_mode(x))
	v.add_child(_row(G.t("roomMode"), mode))
	v.add_child(_row(G.t("music"), _slider(G.music_user, func(x): G.music_user = x; G.save_prefs(); Sfx.apply_volumes())))
	v.add_child(_row(G.t("effects"), _slider(G.effects_user, func(x): G.effects_user = x; G.save_prefs(); Sfx.apply_volumes())))
	_open_modal("settings", v, null, _title_row("", "", G.t("settings").capitalize()), 760)
	if not silent: Sfx.open()

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
