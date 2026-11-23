class_name Panels
extends RefCounted
## Contenuto delle schede delle sezioni (scorre con il dito e con la rotella).

const SPINES := ["7a3626", "2f5d48", "23406e", "8a5a36", "5b3f78", "a8642e"]

static func section_body(s: Dictionary, narrow: bool) -> VBoxContainer:
	var v := UI.vbox(18)
	var intro := G.L(s, "intro")
	if intro != "":
		v.add_child(UI.rich(G.esc_bb(intro), 24, G.C_CREAM))
	# raggruppa le voci per gruppo, nell'ordine in cui arrivano
	var groups: Array = []
	for it in s.get("items", []):
		var g = null
		for x in groups:
			if x.key == it.get("grp", ""): g = x
		if g == null:
			g = {"key": it.get("grp", ""), "name": G.L(it, "grp"), "items": []}
			groups.append(g)
		g.items.append(it)
	if groups.is_empty():
		v.add_child(UI.label(G.t("empty"), 22, G.C_DIM, null, true))
	var chalk: bool = s.id == "lavagna"
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		var sec := UI.vbox(10)
		if g.name != "":
			var h := UI.label(str(g.name).to_upper(), 20, G.gold, UI.f_head)
			sec.add_child(h)
		if s.id == "finestra" and gi == 0:
			sec.add_child(timeline(g.items, narrow))
		elif s.id == "libreria" and gi == 0:
			sec.add_child(books(g.items))
		else:
			sec.add_child(cards(g.items, chalk, narrow))
		v.add_child(sec)
	# in fondo alla lavagna, la frase di un fisico scritta col gesso
	if chalk:
		var q := Quotes.next()
		var board := PanelContainer.new()
		board.add_theme_stylebox_override("panel", UI.box(Color("24493a"), Color("8a5a36"), 4, 20, 14))
		var qv := UI.vbox(4)
		qv.add_child(UI.rich(G.esc_bb("«%s»" % G.L(q, "text")), 25, Color("f4f7ef")))
		qv.add_child(UI.label("— " + Quotes.author(q), 20, Color("b9cdb5"), null, true))
		board.add_child(qv)
		v.add_child(board)
	# link della sezione e contatti
	var bits := HFlowContainer.new()
	bits.add_theme_constant_override("h_separation", 10)
	bits.add_theme_constant_override("v_separation", 10)
	if G.safe_url(str(s.get("link_url", ""))):
		var lu: String = s.link_url
		var lab := G.L(s, "link_label")
		bits.add_child(UI.button(lab if lab != "" else lu, func(): G.open_url(lu), "solid", 20))
	if s.id == "finestra":
		var S := G.S
		if G.safe_url(str(S.get("cv_url", ""))):
			bits.add_child(UI.button(G.t("cv"), func(): G.open_url(str(S.cv_url)), "solid", 20))
		if G.safe_url(str(S.get("github_url", ""))):
			bits.add_child(UI.button("GitHub ↗", func(): G.open_url(str(S.github_url)), "ghost", 20))
		if G.safe_url(str(S.get("github_physics_url", ""))):
			bits.add_child(UI.button("GitHub · %s ↗" % G.t("physics"), func(): G.open_url(str(S.github_physics_url)), "ghost", 20))
		if Shop.donate_url() != "": bits.add_child(ShopUI.cup_button("KO-FI ↗", func(): G.open_url(Shop.donate_url()), "ghost", 20))
		if str(S.get("email", "")) != "":
			var em: String = S.email
			bits.add_child(UI.button(em, func(): G.open_url("mailto:" + em), "ghost", 20))
		if G.L(S, "location") != "":
			var loc := UI.label(G.L(S, "location"), 20, G.C_DIM)
			loc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bits.add_child(loc)
	if bits.get_child_count() > 0:
		var sec2 := UI.vbox(10)
		if s.id == "finestra": sec2.add_child(UI.label(G.t("find").to_upper(), 20, G.gold, UI.f_head))
		sec2.add_child(bits)
		v.add_child(sec2)
	return v

static func _link(it: Dictionary, def: String) -> Control:
	if not G.safe_url(str(it.get("url", ""))): return null
	var u: String = it.url
	var lab := G.L(it, "link_label")
	var b := UI.button(lab if lab != "" else def, func(): G.open_url(u), "link", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b

static func _tags(it: Dictionary, chalk := false) -> Control:
	var tags: Array = it.get("tags", [])
	if tags.is_empty(): return null
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	for tg in tags:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UI.box(Color("1a3a2e") if chalk else G.C_INK, Color("d6e2d2") if chalk else G.C_LINE, 2, 6, 1))
		p.add_child(UI.label(str(tg), 18, G.C_SKY if not chalk else Color("f4f7ef")))
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		f.add_child(p)
	return f

static func cards(items: Array, chalk: bool, narrow: bool) -> Control:
	var grid := GridContainer.new()
	grid.columns = 1 if narrow else 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for it in items:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		if chalk:
			card.add_theme_stylebox_override("panel", UI.box(Color("24493a"), Color("8a5a36"), 4, 14, 12))
		else:
			card.add_theme_stylebox_override("panel", UI.box(Color("1d1937"), G.C_LINE, 2, 14, 12))
		var v := UI.vbox(6)
		v.mouse_filter = Control.MOUSE_FILTER_PASS
		if str(it.get("image", "")) != "" and G.safe_url(str(it.image)):
			var tr := TextureRect.new()
			tr.custom_minimum_size = Vector2(0, 140)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tr.clip_contents = true
			tr.mouse_filter = Control.MOUSE_FILTER_PASS
			v.add_child(tr)
			_load_into(tr, str(it.image))
		if G.L(it, "kicker") != "": v.add_child(UI.label(G.L(it, "kicker"), 18, G.C_DIM if not chalk else Color("b9cdb5"), null, true))
		v.add_child(UI.label(G.L(it, "title"), 22, G.C_CREAM if not chalk else Color("f4f7ef"), UI.f_head, true))
		if G.L(it, "status") != "":
			var bp := PanelContainer.new()
			bp.add_theme_stylebox_override("panel", UI.box(G.C_TERRA, Color(0, 0, 0, 0), 0, 6, 1))
			bp.add_child(UI.label(G.L(it, "status"), 17, G.C_INK))
			bp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bp.mouse_filter = Control.MOUSE_FILTER_PASS
			v.add_child(bp)
		if G.L(it, "description") != "":
			v.add_child(UI.rich(G.esc_bb(G.L(it, "description")), 21, G.C_MUTED if not chalk else Color("d6e2d2")))
		var tg := _tags(it, chalk)
		if tg: v.add_child(tg)
		var lk := _link(it, G.t("openLink"))
		if lk: v.add_child(lk)
		card.add_child(v)
		grid.add_child(card)
	return grid

static func timeline(items: Array, narrow: bool) -> Control:
	var v := UI.vbox(0)
	for it in items:
		var row: BoxContainer = UI.vbox(2) if narrow else UI.hbox(18)
		var when := UI.label(G.L(it, "kicker"), 18, G.gold, UI.f_ui, true)
		when.custom_minimum_size.x = 0 if narrow else 130
		row.add_child(when)
		var col := UI.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label(G.L(it, "title"), 22, G.C_CREAM, UI.f_head, true))
		if G.L(it, "description") != "": col.add_child(UI.rich(G.esc_bb(G.L(it, "description")), 21))
		var tg := _tags(it)
		if tg: col.add_child(tg)
		var lk := _link(it, G.t("openLink"))
		if lk: col.add_child(lk)
		row.add_child(col)
		var m := UI.margin(row, 0, 12, 0, 12)
		v.add_child(m)
		var sep := ColorRect.new()
		sep.color = G.C_LINE
		sep.custom_minimum_size = Vector2(0, 2)
		v.add_child(sep)
	return v

static func books(items: Array) -> Control:
	var shelf := PanelContainer.new()
	var sb := UI.box(Color("2a1a10"), Color(0, 0, 0, 0), 0, 16, 14)
	sb.border_color = Color("8a5a36")
	sb.border_width_bottom = 10
	shelf.add_theme_stylebox_override("panel", sb)
	shelf.mouse_filter = Control.MOUSE_FILTER_PASS
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 14)
	f.add_theme_constant_override("v_separation", 14)
	var i := 0
	for it in items:
		var b := UI.vbox(6)
		b.custom_minimum_size.x = 118
		var cover := PanelContainer.new()
		cover.custom_minimum_size = Vector2(118, 150)
		cover.mouse_filter = Control.MOUSE_FILTER_PASS
		var cb := UI.box(Color(SPINES[i % SPINES.size()]), Color(0, 0, 0, 0.25), 0, 8)
		cb.border_width_right = 6
		cb.border_color = Color(0, 0, 0, 0.25)
		cover.add_theme_stylebox_override("panel", cb)
		if str(it.get("image", "")) != "" and G.safe_url(str(it.image)):
			var tr := TextureRect.new()
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tr.mouse_filter = Control.MOUSE_FILTER_PASS
			cover.add_child(tr)
			_load_into(tr, str(it.image))
		else:
			var t := UI.label(G.L(it, "title"), 15, Color("fff4dc"), UI.f_head, true)
			t.size_flags_vertical = Control.SIZE_SHRINK_END
			t.custom_minimum_size.x = 100
			cover.add_child(t)
		b.add_child(cover)
		b.add_child(UI.label(G.L(it, "kicker"), 18, Color("f2d9a6"), null, true))
		var lk := _link(it, G.t("details"))
		if lk: b.add_child(lk)
		f.add_child(b)
		i += 1
	shelf.add_child(f)
	return shelf

static func _load_into(tr: TextureRect, url: String) -> void:
	var tx = await G.fetch_texture(url)
	if tx and is_instance_valid(tr): tr.texture = tx

## Una voce sola, in grande: la tappa del giro in Vespa.
static func item_body(it: Dictionary, chalk := false) -> VBoxContainer:
	var v := UI.vbox(14)
	if str(it.get("image", "")) != "" and G.safe_url(str(it.image)):
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(0, 240)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.clip_contents = true
		tr.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(tr)
		_load_into(tr, str(it.image))
	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 12)
	if G.L(it, "kicker") != "": top.add_child(UI.label(G.L(it, "kicker"), 24, G.gold, UI.f_ui))
	if G.L(it, "status") != "":
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", UI.box(G.C_TERRA, Color(0, 0, 0, 0), 0, 8, 2))
		bp.add_child(UI.label(G.L(it, "status"), 20, G.C_INK))
		bp.mouse_filter = Control.MOUSE_FILTER_PASS
		top.add_child(bp)
	if top.get_child_count() > 0: v.add_child(top)
	if G.L(it, "description") != "": v.add_child(UI.rich(G.esc_bb(G.L(it, "description")), 27, G.C_CREAM))
	elif G.L(it, "grp") != "": v.add_child(UI.label(G.L(it, "grp"), 24, G.C_MUTED))
	var tg := _tags(it, chalk)
	if tg: v.add_child(tg)
	if G.safe_url(str(it.get("url", ""))):
		var u: String = it.url
		var lab := G.L(it, "link_label")
		var b := UI.button(lab if lab != "" else G.t("openLink"), func(): G.open_url(u), "solid", 24)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(b)
	return v
