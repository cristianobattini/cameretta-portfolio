extends Control
## La visita in 60 secondi: progetti, fisica, percorso e contatti, uno dopo l'altro.

var main
var steps: Array = []
var i := 0
var t := 0.0
var paused := false
var box: PanelContainer
var bars: HBoxContainer
var each := 8.0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	mouse_filter = MOUSE_FILTER_STOP

## Le tappe si costruiscono dai contenuti dell'admin.
func build() -> void:
	steps.clear()
	var S := G.S
	var hello := ""
	for b in G.bubbles:
		if b.get("kind", "") == "intro" and hello.length() < 150: hello += ("" if hello == "" else " ") + G.L(b, "text")
	steps.append({"scene": "street", "k": G.t("visitHello"), "t": str(S.get("site_name", "")), "d": hello})
	var desk: Dictionary = G.by_id.get("scrivania", {})
	var n := 0
	for it in desk.get("items", []):
		if n >= 3: break
		n += 1
		steps.append({"scene": "room", "hover": "scrivania", "k": "%s · %s" % [G.L(desk, "title"), G.L(it, "kicker")], "t": G.L(it, "title"), "d": G.L(it, "description"), "tags": it.get("tags", []), "url": str(it.get("url", ""))})
	for id in ["lavagna", "finestra"]:
		var s: Dictionary = G.by_id.get(id, {})
		if s.is_empty() or s.get("items", []).is_empty(): continue
		var names: Array = []
		for it in s.items: if names.size() < 6: names.append(G.L(it, "title"))
		steps.append({"scene": "room", "hover": id, "k": G.L(s, "object_name"), "t": G.L(s, "title"), "d": G.L(s, "intro"), "tags": names})
	steps.append({"scene": "menu", "k": G.t("visitEnd"), "t": G.t("find"), "d": G.L(S, "location"), "last": true})
	each = 60.0 / steps.size()

func start() -> void:
	build()
	main.close_modal(true)
	visible = true
	main.paused_dirty = true
	paused = false
	i = -1
	go(0)

func stop() -> void:
	if not visible: return
	for c in get_children(): c.queue_free()
	main._set_scene("menu")
	visible = false
	main.stage.visible = true
	main._layout()
	G.set_hash("")

func go(n: int) -> void:
	if n >= steps.size():
		stop()
		return
	n = maxi(0, n)
	var s: Dictionary = steps[n]
	if i < 0 or steps[i].scene != s.scene:
		if s.scene == "street": main._enter_street()
		elif s.scene == "room":
			main._set_scene("room")
		else: main._set_scene("menu")
	if s.scene == "room": main.worlds.room.set_hover(s.hover)
	i = n
	t = 0.0
	Sfx.page()
	_card()

func _card() -> void:
	for c in get_children(): c.queue_free()
	main.hud.visible = false
	main.menu_ui.visible = false
	var s: Dictionary = steps[i]
	bars = UI.hbox(6)
	add_child(bars)
	for k in steps.size():
		var bg := ColorRect.new()
		bg.color = Color(1, 1, 1, 0.25)
		bg.custom_minimum_size.y = 6
		bg.size_flags_horizontal = SIZE_EXPAND_FILL
		var f := ColorRect.new()
		f.color = G.gold
		f.size.y = 6
		bg.add_child(f)
		bars.add_child(bg)
	box = UI.px_panel(Color(G.C_PANEL, 0.97), G.C_CREAM, 24)
	add_child(box)
	var v := UI.vbox(8)
	box.get_node("Inner").add_child(v)
	v.add_child(UI.label(s.k.to_upper(), 19, G.C_SKY, UI.f_ui, true))
	v.add_child(UI.label(s.t, 34 if not main.portrait else 28, G.gold, UI.f_head, true))
	if s.d != "": v.add_child(UI.rich(G.esc_bb(s.d), 25 if not main.portrait else 23, G.C_CREAM))
	if not s.get("tags", []).is_empty():
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 8); fl.add_theme_constant_override("v_separation", 6)
		for tg in s.tags:
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", UI.box(G.C_INK, G.C_LINE, 2, 8, 2))
			p.add_child(UI.label(str(tg), 19, G.C_SKY))
			fl.add_child(p)
		v.add_child(fl)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10); row.add_theme_constant_override("v_separation", 8)
	if G.safe_url(s.get("url", "")): row.add_child(UI.button(G.t("openLink"), func(): paused = true; G.open_url(s.url), "solid", 20))
	if s.get("last", false):
		var S := G.S
		if G.safe_url(str(S.get("cv_url", ""))): row.add_child(UI.button(G.t("cv"), func(): paused = true; G.open_url(str(S.cv_url)), "solid", 22))
		if G.safe_url(str(S.get("github_url", ""))): row.add_child(UI.button("GitHub ↗", func(): paused = true; G.open_url(str(S.github_url)), "solid", 22))
		if str(S.get("email", "")) != "": row.add_child(UI.button(str(S.email), func(): paused = true; G.open_url("mailto:" + str(S.email)), "ghost", 22))
		row.add_child(UI.button(G.t("room"), func(): stop(); main._menu_act("room"), "ghost", 20))
	v.add_child(row)
	var nav := UI.hbox(8)
	nav.add_child(UI.button("◀", func(): go(i - 1), "tool", 20))
	nav.add_child(UI.button(G.t("visitPlay") if paused else G.t("visitPause"), func(): paused = not paused; _card(), "tool", 20))
	nav.add_child(UI.button("▶", func(): go(i + 1), "tool", 20))
	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	nav.add_child(sp)
	nav.add_child(UI.button("✕ " + G.t("photoExit"), stop, "tool", 20))
	v.add_child(nav)
	_layout()
	_layout.call_deferred()

func _layout() -> void:
	if not visible or not is_instance_valid(box): return
	var w: float = minf(920, main.size.x - 32)
	bars.position = Vector2(16, 14)
	bars.size = Vector2(main.size.x - 32, 6)
	for l in box.find_children("*", "Label", true, false):
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF: l.custom_minimum_size.x = 10
	box.custom_minimum_size.x = w
	box.size = Vector2(w, 0)
	box.position = Vector2((main.size.x - w) / 2, main.size.y - box.size.y - 22)

func _process(dt: float) -> void:
	if not visible: return
	main.hud.visible = false
	main.menu_ui.visible = false
	main.prompt_node.visible = false
	main.stage.visible = false
	for n in [main.dialog, main.sheet, main.pad]: n.visible = false
	_layout()
	if not paused: t += dt
	for k in bars.get_child_count():
		var b: ColorRect = bars.get_child(k)
		b.get_child(0).size.x = b.size.x * (1.0 if k < i else clampf(t / each, 0, 1) if k == i else 0.0)
	if t >= each:
		if i == steps.size() - 1: paused = true; t = each - 0.001
		else: go(i + 1)

func key(k: int) -> void:
	match k:
		KEY_ESCAPE: stop()
		KEY_RIGHT, KEY_D: go(i + 1)
		KEY_LEFT, KEY_A: go(i - 1)
		KEY_SPACE, KEY_P: paused = not paused; _card()
