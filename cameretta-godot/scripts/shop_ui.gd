class_name ShopUI
extends RefCounted
## La finestra del negozio: anteprima a sinistra, categorie e articoli a destra.

static var cat := "theme"
static var sel := ""
static var getting := false        # pagina "ottieni monete"
static var msg := ""

static func coin_icon(i := 0) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = load("res://assets/img/shop.png")
	a.region = Rect2(Shop._rect(Shop._rects["coin%d" % i]))
	return a

static func build(m) -> Control:
	var v := UI.vbox(14)
	var narrow: bool = m.portrait or m.size.x < 900
	var top := UI.hbox(12)
	var ic := TextureRect.new()
	ic.texture = coin_icon()
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top.add_child(ic)
	var bal := UI.label(str(Shop.balance), 34, G.gold, UI.f_head)
	bal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(bal)
	top.add_child(UI.button(G.t("shopBack") if getting else G.t("shopGet"), func(): Sfx.select(); getting = not getting; msg = ""; m.open_shop(true), "ghost" if getting else "solid", 22))
	v.add_child(top)
	if not Shop.online: v.add_child(UI.label(G.t("shopOffline"), 20, G.C_TERRA, null, true))
	if msg != "": v.add_child(UI.label(msg, 22, G.gold, null, true))
	if getting:
		v.add_child(_coins_page(m))
		return v
	if sel == "" or not Shop.by_id.has(sel) or Shop.by_id[sel].cat != cat: sel = Shop.cur(cat).id if cat != "up" else Shop.items("up")[0].id
	var main: BoxContainer = UI.vbox(14) if narrow else UI.hbox(20)
	main.add_child(_preview(m, narrow))
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	for c in Shop.CAT.categories:
		var id: String = c.id
		tabs.add_child(UI.button(G.L(c, "name"), func(): Sfx.move(); cat = id; sel = ""; msg = ""; m.open_shop(true), "solid" if id == cat else "ghost", 18))
	right.add_child(tabs)
	var grid := GridContainer.new()
	grid.columns = 2 if narrow else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for it in Shop.items(cat): grid.add_child(_card(m, it))
	right.add_child(grid)
	main.add_child(right)
	v.add_child(main)
	return v

static func _state(it: Dictionary) -> String:
	if it.cat == "up": return G.t("on") if Shop.up(it.id) else (G.t("off") if Shop.has(it.id) else "")
	if Shop.cur(it.cat).get("id", "") == it.id: return G.t("shopWorn")
	return G.t("shopOwned") if Shop.has(it.id) else ""

static func _card(m, it: Dictionary) -> Control:
	var id: String = it.id
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 78)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := id == sel
	b.add_theme_stylebox_override("normal", UI.box(G.C_PANEL2 if on else G.C_INK, G.gold if on else G.C_LINE, 3, 8))
	for s in ["hover", "pressed"]: b.add_theme_stylebox_override(s, UI.box(G.C_PANEL2, G.gold, 3, 8))
	b.pressed.connect(func(): Sfx.move(); sel = id; msg = ""; m.open_shop(true))
	var v := UI.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10; v.offset_right = -10; v.offset_top = 7; v.offset_bottom = -7
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UI.label(G.L(it, "name"), 20, G.C_CREAM, UI.f_ui)
	n.clip_text = true
	v.add_child(n)
	var row := UI.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in it.get("pal", it.get("ramp", [])).slice(0, 4):
		var sw := ColorRect.new()
		sw.color = Color(str(c))
		sw.custom_minimum_size = Vector2(12, 12)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw)
	var st := _state(it)
	if st == "":
		var ic := TextureRect.new()
		ic.texture = coin_icon()
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(20, 20)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
	var l := UI.label(st if st != "" else ("%d/10" % G.secrets.size() if it.has("prize") else str(int(it.price))), 20, G.C_SAGE if st != "" else G.gold)
	row.add_child(l)
	v.add_child(row)
	b.add_child(v)
	for x in [n, l]: x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

static func _preview(m, narrow: bool) -> Control:
	var it: Dictionary = Shop.by_id[sel]
	var box := UI.vbox(10)
	var look := {it.cat: sel}
	var d := Shop.dress(look)
	var tp := ImageTexture.create_from_image(d.player)
	var ts := ImageTexture.create_from_image(d.sea_props)
	var room: Texture2D = ImageTexture.create_from_image(Shop.furnish(look)) if it.cat in ["theme", "rug", "wall", "curtain", "corner", "poster"] else null
	var c := Control.new()
	c.custom_minimum_size = Vector2(320, 232)
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.material = Shop.theme_material(look)
	c.draw.connect(func(): _paint(c, it, look, tp, ts, room))
	var fr := PanelContainer.new()
	fr.add_theme_stylebox_override("panel", UI.box(G.C_INK, G.gold, 4, 4))
	fr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if narrow else Control.SIZE_FILL
	fr.add_child(c)
	box.add_child(fr)
	box.add_child(UI.label(G.L(it, "name"), 28, G.C_CREAM, UI.f_head, true))
	if G.L(it, "desc") != "": box.add_child(UI.label(G.L(it, "desc"), 22, G.C_MUTED, null, true))
	var has := Shop.has(sel)
	var txt: String
	var prize: bool = it.has("prize") and not has
	if prize: txt = G.t("shopPrizeN") % G.secrets.size()
	elif not has: txt = "%s  ·  %d" % [G.t("shopBuy"), int(it.price)]
	elif it.cat == "up": txt = G.t("shopOff") if Shop.up(sel) else G.t("shopOn")
	else: txt = G.t("shopWorn") if Shop.cur(it.cat).id == sel else G.t("shopWear")
	var b := UI.button(txt, func(): act(m), "solid", 24)
	b.disabled = has and it.cat != "up" and Shop.cur(it.cat).id == sel or (not has and not Shop.online) or (prize and G.secrets.size() < 10)
	box.add_child(b)
	return box

static func act(m) -> void:
	var id := sel
	if Shop.has(id):
		Sfx.toggle()
		Shop.wear(id)
		return
	Sfx.select()
	var e: String = await Shop.buy(id)
	if e == "":
		msg = G.t("shopGot") % G.L(Shop.by_id[id], "name")
		Sfx.play("stop_pop", 0.8)
		if Shop.by_id[id].cat != "up" or not Shop.up(id): Shop.wear(id)
	else:
		msg = G.t(e)
		if e == "shopPoor": getting = true
	if m.modal.visible and m.modal_kind == "shop": m.open_shop(true)

static func _paint(c: Control, it: Dictionary, look: Dictionary, tp: Texture2D, ts: Texture2D, room: Texture2D) -> void:
	var sz := c.size
	if room != null:
		var k := sz.x / 320.0
		c.draw_set_transform(Vector2(0, (sz.y - 200 * k) / 2), 0, Vector2(k, k))
		if it.cat in ["corner", "poster", "rug"]:       # più da vicino
			var z := 2.2
			var f: Vector2 = {"corner": Vector2(30, 152), "poster": Vector2(38, 92), "rug": Vector2(160, 150)}[it.cat]
			c.draw_set_transform(Vector2(clampf(sz.x / 2 - f.x * z, sz.x - 320 * z, 0), clampf(sz.y / 2 - f.y * z, sz.y - 200 * z, 0)), 0, Vector2(z, z))
		c.draw_texture(room, Vector2.ZERO)
		Shop.draw_room_items(c, 0.0, look)
		c.draw_set_transform(Vector2.ZERO)
		return
	c.draw_rect(Rect2(Vector2.ZERO, sz), Color("2a3266"))
	c.draw_rect(Rect2(0, sz.y - 46, sz.x, 46), Color("c9d4f2"))
	c.draw_rect(Rect2(0, sz.y - 46, sz.x, 4), Color("eef3ff"))
	if it.cat == "pet":
		var sp := 5.0
		if it.has("pal"):
			var r0 := Shop._rect(Shop._rects["pet3"])
			c.draw_texture_rect_region(Shop.pet_texture(look), Rect2(sz.x / 2 - r0.size.x * sp / 2, sz.y - 24 - r0.size.y * sp, r0.size.x * sp, r0.size.y * sp), Rect2(r0))
		c.draw_set_transform(Vector2.ZERO)
	elif it.cat in ["hood", "pants", "scarf"]:
		var s := 3.4
		c.draw_set_transform(Vector2(sz.x / 2 - 18 * s, sz.y - 26 - 58 * s), 0, Vector2(s, s))
		c.draw_texture_rect_region(tp, Rect2(0, 0, 36, 63), Rect2(0, 0, 36, 63))
	else:
		var s2 := 2.6
		var J: Dictionary = G.J.sea
		c.draw_set_transform(Vector2(sz.x / 2 - 38 * s2, sz.y - 20 - 50 * s2), 0, Vector2(s2, s2))
		var put := func(n: String, at: Vector2):
			var r: Array = J.rects[n]
			c.draw_texture_rect_region(ts, Rect2(at, Vector2(r[2], r[3])), Rect2(r[0], r[1], r[2], r[3]))
		var dy := Vector2(0, float(J.vespa.rider_dy))
		put.call("rider_back_ride0", dy)
		put.call("vespa_back", Vector2.ZERO)
		for w in ["rear", "front"]: put.call("wheel0", Vector2(J.vespa[w][0], J.vespa[w][1]) - Vector2(9, 9))
		Shop.draw_cargo(c, 0, 0, look)
		put.call("vespa", Vector2.ZERO)
		put.call("rider_ride0", dy)
		put.call("helmet", dy + Vector2(J.riders.ride0.head[0], J.riders.ride0.head[1]))
	c.draw_set_transform(Vector2.ZERO)

## Come si ottengono le monete: giocando, oppure offrendo un caffè.
static func _coins_page(m) -> Control:
	var v := UI.vbox(14)
	var url := str(G.S.get("donate_url", ""))
	var e: Dictionary = Shop.CAT.earn
	v.add_child(UI.label(G.t("shopPlayT"), 26, G.gold, UI.f_head, true))
	v.add_child(UI.rich(G.t("shopPlay") % [int(e.daily), int(e.stop), int(e.section), int(e.ride_end), int(e.pray), int(e.fish)], 24, G.C_CREAM))
	v.add_child(UI.label(G.t("shopGiveT"), 26, G.gold, UI.f_head, true))
	var ready := str(G.S.get("donations_ready", "0")) == "1" and Shop.deposit != ""
	if url.begins_with("https://") and not ready:
		v.add_child(UI.rich(G.t("shopThanks"), 24, G.C_CREAM))
		var b0 := UI.button(G.t("shopCoffee"), func(): G.open_url(url), "solid", 22)
		b0.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(b0)
	elif url.begins_with("https://"):
		v.add_child(UI.rich(G.t("shopGive") % int(float(str(G.S.get("coins_per_unit", "100")))), 24, G.C_CREAM))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
		row.add_child(UI.button(G.t("shopCopy") % Shop.deposit, func(): Sfx.select(); DisplayServer.clipboard_set(Shop.deposit); msg = G.t("shopCopied"); m.open_shop(true), "ghost", 22))
		row.add_child(UI.button(G.t("shopCoffee"), func(): G.open_url(url), "solid", 22))
		row.add_child(UI.button(G.t("shopCheck"), func(): check(m), "ghost", 22))
		v.add_child(row)
	else:
		v.add_child(UI.rich(G.t("shopSoon"), 24, G.C_MUTED))
	v.add_child(UI.label(G.t("shopCodeT"), 26, G.gold, UI.f_head, true))
	v.add_child(UI.rich(G.t("shopCode") % (Shop.code if Shop.code != "" else "—"), 22, G.C_MUTED))
	var r2 := HFlowContainer.new()
	r2.add_theme_constant_override("h_separation", 10)
	r2.add_theme_constant_override("v_separation", 10)
	if G.is_web and G.touch:
		r2.add_child(UI.button(G.t("shopEnter"), func():
			var x = JavaScriptBridge.eval("prompt(%s)||''" % JSON.stringify(G.t("shopEnter")), true)
			enter(m, str(x)), "ghost", 22))
	else:
		var le := LineEdit.new()
		le.placeholder_text = "CRI-XXXX-XXXX"
		le.max_length = 13
		le.custom_minimum_size = Vector2(250, 44)
		le.add_theme_font_size_override("font_size", 24)
		le.add_theme_stylebox_override("normal", UI.box(G.C_INK, G.C_LINE, 3, 10, 6))
		le.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), G.gold, 3, 10, 6))
		le.text_submitted.connect(func(x): enter(m, x))
		r2.add_child(le)
		r2.add_child(UI.button(G.t("shopEnter"), func(): enter(m, le.text), "ghost", 22))
	v.add_child(r2)
	return v

static func enter(m, c: String) -> void:
	if c.strip_edges() == "": return
	msg = G.t("shopCodeOk") if await Shop.use_code(c) else G.t("shopCodeBad")
	if m.modal.visible and m.modal_kind == "shop": m.open_shop(true)

static func check(m) -> void:
	var b := Shop.balance
	await Shop.sync()
	msg = G.t("shopIn") % (Shop.balance - b) if Shop.balance > b else G.t("shopNotYet")
	if Shop.balance > b: Sfx.play("stop_pop", 0.8)
	if m.modal.visible and m.modal_kind == "shop": m.open_shop(true)
