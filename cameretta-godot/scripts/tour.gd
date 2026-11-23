extends Node
## Giro automatico di prova (solo sviluppo): CAMERETTA_TOUR=/cartella/screenshot godot ...

var m
var out := ""
var n := 0

func _ready() -> void:
	m = get_parent()
	AudioServer.set_bus_mute(0, true)      # le prove sono sempre mute
	out = OS.get_environment("CAMERETTA_TOUR")
	DirAccess.make_dir_recursive_absolute(out)
	_run()

func shot(name: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()       # anche se la finestra è coperta da altre
	var img := get_viewport().get_texture().get_image()
	n += 1
	img.save_png("%s/%02d_%s.png" % [out, n, name])
	print("SHOT ", name, " scene=", m.scene)

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _run() -> void:
	var size_env := OS.get_environment("CAMERETTA_SIZE")
	if size_env != "":
		var p := size_env.split("x")
		get_window().size = Vector2i(int(p[0]), int(p[1]))
	while m.loading != null: await get_tree().process_frame
	await wait(0.6)
	if OS.get_environment("CAMERETTA_DIRECT") != "":
		G.room_mode = "point"
		m._menu_act("room")
		for i in 8:
			await wait(0.25)
			await shot("direct_%d" % i)
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "shop":
		await _shop_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "grove":
		await _grove_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "places":
		await _places_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "addons":
		await _addons_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "pause":
		await _pause_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "coffee":
		await _coffee_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "menu":
		await _menu_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") == "check":
		await _ride_check()
		get_tree().quit()
		return
	if OS.get_environment("CAMERETTA_RIDE") != "":
		await _ride()
		get_tree().quit()
		return
	await shot("menu")
	m.open_settings()
	await wait(0.3)
	await shot("settings")
	m.close_modal()
	G.room_mode = ""
	m._start_game(false)
	await wait(0.4)
	await shot("choose")
	m._choose("walk")
	await wait(1.6)
	await shot("street_start")
	m.pad_dir = 1
	await wait(5.0)
	await shot("street_walk")
	m.pad_dir = 0
	m.worlds.street.P.x = 700
	await wait(4.0)
	await shot("street_bubbles")
	m.worlds.street.P.x = float(G.J.street.door.x) - 4
	await wait(0.6)
	await shot("street_door")
	m._do_action()
	await wait(1.6)
	await shot("living")
	m.worlds.living.P.x = float(G.J.living.spots.fire)
	await wait(0.4)
	m._do_action()
	await wait(0.3)
	await shot("living_fire")
	m.worlds.living.P.x = float(G.J.living.spots.tv)
	await wait(0.3)
	m._do_action()
	await wait(0.5)
	await shot("living_tv")
	m.worlds.living.P.x = float(G.J.living.spots.door)
	await wait(0.4)
	await shot("living_door")
	m._do_action()
	await wait(1.8)
	await shot("room_walk")
	m.worlds.room.walk_to("libreria")
	await wait(4.0)
	await shot("room_walk_open")
	m.close_modal()
	m._set_mode("point")
	await wait(0.4)
	m.worlds.room.set_hover("lavagna")
	await wait(0.3)
	await shot("room_point_hover")
	for id in ["scrivania", "finestra", "libreria", "lavagna", "letto"]:
		m.open_section(id)
		await wait(0.8)
		await shot("panel_" + id)
		var sc0: ScrollContainer = m._panel.find_child("Scroll", true, false)
		print(id, " panel=", m._panel.size, " min=", m._panel.get_combined_minimum_size(), " sc=", sc0.size, " scmin=", sc0.get_combined_minimum_size(), " vbox=", sc0.get_parent().get_combined_minimum_size(), " size=", m.size)
	var sc: ScrollContainer = m._panel.find_child("Scroll", true, false)
	sc.scroll_vertical = 400
	await wait(0.3)
	await shot("panel_scrolled")
	m.close_modal()
	m.open_help()
	await wait(0.3)
	await shot("help")
	m.close_modal()
	G.set_lang("it")
	await wait(0.4)
	await shot("room_it")
	print("TOUR DONE")
	get_tree().quit()

## Solo il giro in Vespa: CAMERETTA_RIDE=1
func _ride() -> void:
	var sea = m.worlds.sea
	G.set_lang("en" if OS.get_environment("CAMERETTA_RIDE") == "en" else "it")
	G.room_mode = "walk"
	m._start_game(false)
	await wait(1.6)
	m.worlds.street.enter_at(m.worlds.street.FORK_X - 6)
	await wait(1.2)
	await shot("fork")
	m._do_action()
	await wait(0.9)
	await shot("fork_down")
	await wait(2.4)
	await shot("sea_arrive")
	m.pad_dir = 1
	await wait(2.6)
	m.pad_dir = 0
	await wait(0.3)
	await shot("sea_vespa")
	m._do_action()
	await wait(0.6)
	await shot("helmet_a")
	await wait(0.6)
	await shot("helmet_b")
	while sea.state == "helmet": await get_tree().process_frame
	await wait(0.2)
	await shot("mount")
	await wait(0.2)
	await shot("mount_sit")
	while sea.state == "mount": await get_tree().process_frame
	await wait(0.55)
	await shot("kick")
	while sea.state == "start": await get_tree().process_frame
	m.pad_dir = 1
	await wait(1.8)
	await shot("ride_go")
	var ch := -1
	var t := 0.0
	var parked := 0
	while sea.state != "ending" and t < 260:
		await get_tree().process_frame
		t += get_process_delta_time()
		if sea.cur_chapter != ch:
			ch = sea.cur_chapter
			await wait(1.0)
			await shot("chapter_%d" % ch)
			await wait(2.2)
			await shot("landmark_%d" % ch)
			m.pad_dir = 1
			parked = 0
		var n: int = sea.near_stop()
		if sea.state == "ride" and n >= 0 and parked < 1 and sea.stops[n].ch == ch and absf(float(sea.stops[n].x) - sea.x - 60) < 8:
			parked += 1
			await shot("near_%d" % ch)
			m._do_action()
			m.pad_dir = 0
			while not m.modal.visible: await get_tree().process_frame
			await wait(0.5)
			await shot("stop_%d" % ch)
			m.close_modal()
			await wait(0.5)
			await shot("parked_%d" % ch)
			m.pad_dir = 1
		if sea.state == "ride" and sea.x > sea.end_x - 30:
			m.pad_dir = 0
			await shot("belvedere")
			m._do_action()
			m.worlds.sea.horn()
			await wait(3.2)
	await wait(1.0)
	await shot("ending")
	while not m.modal.visible and t < 400:
		await get_tree().process_frame
		t += get_process_delta_time()
	await wait(0.5)
	await shot("end_modal")
	print("seen=", sea.seen_count(), "/", sea.stops.size(), " emblems=", sea.stops.map(func(s): return s.emblem + ":" + str(s.it.title)))
	m._transition(m._enter_street.bind(float(G.J.street.door.x) - 52))
	await wait(1.6)
	await shot("home")
	m._to_menu()
	await wait(1.2)
	await shot("menu_unlocked")
	print("RIDE DONE")

func ok(cond: bool, what: String) -> void:
	print("OK   " if cond else "FAIL ", what)

func until(f: Callable, secs := 15.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not f.call():
		if Time.get_ticks_msec() - t0 > secs * 1000: return false
		await get_tree().process_frame
	return true

func key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame

## Controlli automatici del giro: CAMERETTA_RIDE=check
func _ride_check() -> void:
	var sea = m.worlds.sea
	G.set_lang("it"); G.room_mode = "walk"
	m._start_game(false)
	await until(func(): return m.scene == "street" and not m.busy)
	m.worlds.street.enter_at(m.worlds.street.FORK_X)
	await wait(0.3)
	await key(KEY_DOWN)
	ok(await until(func(): return m.scene == "sea" and not m.busy), "freccia giu' porta al mare")
	var tot := 0
	for s in G.sections: tot += s.get("items", []).size()
	ok(sea.stops.size() == tot and tot > 0, "una tappa per ogni voce (%d)" % tot)
	sea.tap(Vector2(sea.x - sea.cam, 160))
	ok(await until(func(): return sea.state == "ride", 20), "tocco sulla Vespa: cammina, casco, parte")
	m.pad_dir = -1
	await wait(1.5)
	ok(sea.v <= 0 and sea.x >= sea.VESPA_X - 31, "freno e retro: non esce dalla strada (x=%.0f)" % sea.x)
	m.pad_dir = 1
	await wait(1.0)
	sea.horn()
	ok(sea._horn_t > 0, "clacson")
	ok(await until(func(): return sea.stops[0].state == "up", 25), "la prima tappa spunta")
	m.pad_dir = 0
	sea.tap(Vector2(float(sea.stops[0].x) - sea.cam, 130))
	ok(await until(func(): return m.modal.visible and m.modal_kind == "ride", 12), "tocco sulla tappa: si ferma e apre la scheda")
	ok(absf(float(sea.stops[0].x) - 46 - sea.x) < 3, "parcheggia al punto giusto")
	G.set_lang("en"); await wait(0.2)
	ok(m.modal.visible and m.modal_kind == "ride", "cambio lingua con la scheda aperta")
	G.set_lang("it"); await wait(0.1)
	await key(KEY_E)
	ok(not m.modal.visible and sea.state == "ride", "E chiude e riparte")
	await key(KEY_E)
	ok(await until(func(): return m.modal.visible, 8), "E riapre la stessa tappa")
	await key(KEY_ESCAPE)
	ok(not m.modal.visible and m.scene == "sea", "ESC chiude solo la scheda")
	m.open_settings(); await wait(0.2)
	m.close_modal(); ok(sea.state == "ride", "impostazioni durante il giro")
	# tutta velocita' fino in fondo senza fermarsi
	Engine.time_scale = 4.0
	m.pad_dir = 1
	ok(await until(func(): return sea.x >= sea.end_x, 60), "si arriva al belvedere")
	await wait(2.0)
	m.pad_dir = 0
	ok(sea.x <= sea.end_x + 21, "e ci si ferma (x-end=%.1f)" % (sea.x - sea.end_x))
	ok(sea.cur_chapter == sea.chapters.size() - 1, "capitoli tutti passati")
	await key(KEY_E)
	ok(await until(func(): return m.modal_kind == "rideend", 60), "alba e finestra finale")
	Engine.time_scale = 1.0
	await key(KEY_ESCAPE)
	ok(sea.state == "ride" and sea.engine, "chiusa la finestra finale si puo' ancora guidare")
	await key(KEY_E)
	ok(await until(func(): return m.modal_kind == "rideend", 20), "la finestra finale si riapre")
	m._transition(m._enter_sea)
	ok(await until(func(): return m.scene == "sea" and sea.state == "walk" and not m.busy), "rifai il giro riparte dalla scalinata")
	ok(sea.stops[0].seen, "le tappe viste restano viste")
	m.b_back.pressed.emit()
	ok(await until(func(): return m.scene == "street" and not m.busy), "indietro torna in strada")
	ok(absf(m.worlds.street.P.x - m.worlds.street.FORK_X) < 40, "vicino al bivio")
	m._to_menu()
	ok(await until(func(): return m.scene == "menu" and not m.busy), "menu")
	ok(m.menu_items.any(func(b): return b.get_meta("act") == "map"), "voce MAPPA nel menu")
	m._menu_act("map"); await wait(0.3); m.close_modal(true)
	m._go_to("ride")
	ok(await until(func(): return m.scene == "sea" and not m.busy), "dal menu si va alla Vespa")
	print("CHECK DONE")

## Il menu non deve mai rimpicciolirsi da solo: CAMERETTA_RIDE=menu
func _menu_scale(what: String, frames := 30) -> void:
	var lo := 9.0
	var first := 0.0
	var last := 0.0
	for i in frames:
		var c = m.menu_ui.get_node_or_null("Col")
		if c != null:
			lo = minf(lo, c.scale.x)
			if i == 0: first = c.scale.x
			last = c.scale.x
			if m.menu_ui.is_visible_in_tree() and not m.portrait:
				var h: float = c.size.y * c.scale.y
				if i == frames - 1: ok(c.position.y + h <= m.size.y + 1, "%s: sta nello schermo (%.0f+%.0f su %.0f)" % [what, c.position.y, h, m.size.y])
		await get_tree().process_frame
	if not what.begins_with("finestra"): ok(lo >= last - 0.001, "%s: scala primo=%.2f min=%.2f fine=%.2f" % [what, first, lo, last])
	ok(last > 0.75, "%s: leggibile" % what)

func _menu_check() -> void:
	for found in [false, true]:
		G.ride_found = found
		m._apply_texts()
		await _menu_scale("ricostruito, giro %s" % found)
	for l in ["it", "en", "it"]:
		G.set_lang(l)
		await _menu_scale("lingua " + l)
	m._menu_act("audio"); await _menu_scale("audio")
	m._menu_act("audio"); await _menu_scale("audio")
	G.room_mode = "walk"
	for go in ["street", "sea"]:
		if go == "sea": m._start_ride()
		else: m._start_game(false)
		await until(func(): return m.scene != "menu" and not m.busy)
		await wait(0.3)
		G.set_lang("en"); G.set_lang("it")
		await wait(0.2)
		m._to_menu()
		await until(func(): return m.scene == "menu")
		await _menu_scale("ritorno da %s dopo cambio lingua" % go, 90)
	for s in [Vector2i(1280, 800), Vector2i(1920, 800), Vector2i(1280, 640), Vector2i(1000, 560), Vector2i(844, 390), Vector2i(430, 900), Vector2i(1280, 720)]:
		get_window().size = s
		await _menu_scale("finestra %s" % s)
		await shot("menu_%dx%d" % [s.x, s.y])
	m._next_menu_quote(); await wait(1.2)
	await shot("menu_altra_frase")
	m.open_settings(); await wait(0.3); await shot("impostazioni"); m.close_modal()
	ok(Quotes.ALL.size() > 40, "citazioni: %d" % Quotes.ALL.size())
	Quotes._deck.clear()
	var seen := {}
	for i in Quotes.ALL.size(): seen[Quotes.next().text] = true
	ok(seen.size() == Quotes.ALL.size(), "il mazzo non si ripete (%d)" % seen.size())
	# la citazione più lunga deve stare nel riquadro del menu
	for l in ["it", "en"]:
		G.set_lang(l)
		for q in Quotes.ALL:
			m.menu_quote = q
			m._fill_menu_quote(); m._layout_menu_quote()
			await get_tree().process_frame
			var b: Control = m.menu_ui.get_node("Quote")
			var c: Control = m.menu_ui.get_node("Col")
			if b.position.x + b.size.x > c.position.x or b.position.y + b.size.y > m.size.y: ok(false, "citazione fuori posto: " + str(q.text))
	G.set_lang("it")
	m._start_game(false)
	await until(func(): return m.scene == "street" and not m.busy)
	var st = m.worlds.street
	ok(st.bub.size() == st.MAX_BUBBLES, "bolle in strada: %d" % st.bub.size())
	for x in [300.0, 620.0, 1000.0, 1300.0]:
		st.P.x = x
		await wait(7.0)
		await shot("strada_%d" % int(x))
		var vis: Array = m.bubble_nodes.filter(func(b): return b.visible)
		for i in vis.size() - 1:
			ok(not vis[i].get_rect().intersects(vis[i + 1].get_rect()), "bolle non accavallate a %d" % int(x))
	var f0 := G.is_fullscreen()
	await key(KEY_F); await wait(2.0)
	ok(G.is_fullscreen() != f0, "F: schermo intero")
	await shot("schermo_intero")
	await key(KEY_F); await wait(2.0)
	ok(G.is_fullscreen() == f0, "F: di nuovo finestra")
	print("MENU DONE")

## Il negozio: CAMERETTA_RIDE=shop (con il server acceso compra davvero, su un portafoglio nuovo)
func _shop_check() -> void:
	G.set_lang("it"); G.room_mode = "walk"
	Shop.code = ""; Shop.owned.clear(); Shop.worn.clear(); Shop.ups.clear(); Shop._queue.clear(); Shop.balance = 0; Shop.online = false
	Shop.apply()
	m.open_shop()
	var net: bool = await until(func(): return Shop.online, 6)
	print("server: ", net)
	await wait(0.6)
	if net: ok(Shop.code.begins_with("CRI-"), "portafoglio " + Shop.code)
	if net: ok(await until(func(): return Shop.balance >= 5, 6), "premio del giorno: %d" % Shop.balance)
	for c in ["theme", "vespa", "helmet", "hood", "cargo", "wall", "rug", "corner", "poster", "up"]:
		ShopUI.cat = c
		ShopUI.sel = Shop.items(c)[mini(2, Shop.items(c).size() - 1)].id
		m.open_shop(true)
		await wait(0.35)
		await shot("shop_" + c)
		ok(m._panel.size.y <= m.size.y and m._panel.position.y >= 0, "il pannello sta nello schermo: " + c)
	ShopUI.getting = true; m.open_shop(true); await wait(0.3); ok(m._panel.size.x <= m.size.x, "la pagina delle monete sta in larghezza"); await shot("shop_monete"); ShopUI.getting = false
	if net:
		ShopUI.cat = "vespa"; ShopUI.sel = "ve_oro"
		await ShopUI.act(m)
		ok(not Shop.has("ve_oro") and ShopUI.getting, "senza monete non si compra e si spiega come averle")
		var r: Array = await Shop._call("/api/store/gift", {"code": Shop.code, "coins": 9000})
		ok(r[0] == 200, "regalo di prova")
		await Shop.sync()
		for id in ["ve_rosso", "se_nera", "ca_notte", "fe_gialla", "pa_jeans", "sc_blu", "po_gatto", "ta_blu", "pr_verde", "te_rosse", "an_lava", "mu_neon", "th_aurora", "up_marmitta", "up_gomme", "up_faro", "up_clacson", "up_scia", "up_aurora", "up_comete"]:
			ShopUI.cat = Shop.by_id[id].cat; ShopUI.sel = id
			await ShopUI.act(m)
			ok(Shop.has(id) and (Shop.up(id) if Shop.by_id[id].cat == "up" else Shop.cur(Shop.by_id[id].cat).id == id), "comprato e in uso: " + id)
		await wait(0.2); await shot("shop_dopo")
		var b := Shop.balance
		var keep := Shop.code
		Shop.code = ""; Shop.owned.clear(); Shop.balance = 0
		ok(await Shop.use_code(keep.to_lower()) and Shop.balance == b and Shop.has("ve_rosso"), "il codice riporta tutto")
		ok(not await Shop.use_code("CRI-ZZZZ-ZZZZ"), "codice inventato respinto")
	else:
		for id in ["ve_rosso", "ca_notte", "fe_gialla", "sc_blu", "po_gatto", "pr_verde", "ta_blu", "an_lava", "mu_neon", "th_aurora"]:
			Shop.owned[id] = true; Shop.wear(id)
	m.close_modal()
	await shot("menu_tema")
	m._start_game(false)
	await until(func(): return m.scene == "street" and not m.busy)
	await wait(1.0); await shot("strada_tema")
	m._to_menu(); await until(func(): return m.scene == "menu" and not m.busy); await wait(0.5)
	m._start_game(true)
	await until(func(): return m.scene == "room" and not m.busy)
	await wait(1.2); await shot("camera_tema")
	m._to_menu(); await until(func(): return m.scene == "menu" and not m.busy); await wait(0.5)
	m._start_ride()
	await until(func(): return m.scene == "sea" and not m.busy)
	await wait(0.6); await shot("mare_fermo")
	var sea = m.worlds.sea
	sea.take_helmet()
	await until(func(): return sea.state == "ride", 20)
	m.pad_dir = 1
	await wait(3.2); sea.horn(); await wait(0.35); await shot("mare_corsa")
	if net: await wait(2.0); ok(sea.v > sea.MAX_V + 4, "la marmitta si sente (%.0f)" % sea.v)
	Shop.worn["theme"] = "th_neve"; Shop.apply(); await wait(0.3); await shot("mare_senza_tema")
	ok(m.view.material == null, "tema di serie: nessun filtro")
	print("SHOP DONE")

## I templi: CAMERETTA_RIDE=grove
func _grove_check() -> void:
	G.set_lang("it"); G.room_mode = "walk"; G.prayers = {}
	m._start_game(false)
	await until(func(): return m.scene == "street" and not m.busy)
	# dai due lati di ogni insegna: si gira dalla parte giusta e la scena cambia subito
	for q in [["GROVE_X", "grove", 32.0], ["GROVE_X", "grove", -32.0], ["FORK_X", "sea", 32.0], ["FORK_X", "sea", -32.0]]:
		var st = m.worlds.street
		m._enter_street(st.get_script().get_script_constant_map()[q[0]] + q[2])
		st.P.dir = int(signf(q[2]))          # guarda dalla parte opposta al sentiero
		await wait(0.3)
		var t0 := Time.get_ticks_msec()
		await key(KEY_E)
		await wait(0.1)
		ok(st.P.dir == -int(signf(q[2])), "%s %+d: si gira verso il sentiero" % [q[1], int(q[2])])
		await until(func(): return m.scene == q[1], 5)
		ok(Time.get_ticks_msec() - t0 < 1150, "%s %+d: cambia scena in %d ms" % [q[1], int(q[2]), Time.get_ticks_msec() - t0])
		await until(func(): return not m.busy)
	m._enter_street(m.worlds.street.GROVE_X - 4)
	await wait(1.6); await shot("bivio")
	await key(KEY_DOWN)
	ok(await until(func(): return m.scene == "grove" and not m.busy), "freccia giu' porta ai templi")
	await wait(1.4); ok(m.worlds.grove.line == G.t("templesHello"), "indicazioni all'arrivo"); await wait(2.6); await shot("templi")
	m.worlds.grove.P.x = 520; await wait(1.6); await shot("cartello_dune")
	var g = m.worlds.grove
	for id in ["stelle", "magia", "dune"]:
		g.P.x = g.at(id) - 70; await wait(1.6); await shot("targa_" + id)
		ok(g.line == G.t("temples")[id], "targa: " + g.line)
		g.tap(g.at(id) - g.cam)
		ok(await until(func(): return g.state == "pray", 12), "si siede: " + id)
		ok(absf(g.P.x - g.at(id) + 56) < 4, "davanti all'altare: " + id)
		await wait(2.6); await shot("prega_" + id)
		ok(await until(func(): return g.state == "walk", 8) and int(G.prayers.get(id, 0)) == 1, "preghiera contata: " + id)
		ok(await until(func(): return g.line != "" and g.line != G.t("temples")[id] and g.done(), 12), "risposta: " + g.line)
		await shot("risposta_" + id)
	g.P.x = g.at("stelle"); await wait(0.2)
	await key(KEY_E); await until(func(): return g.state == "pray", 8); await wait(1.2)
	m.pad_dir = 1; await wait(0.3); m.pad_dir = 0
	ok(g.state == "walk" and int(G.prayers.stelle) == 1, "ci si puo' alzare prima: non conta")
	G.prayers.stelle = 8; G.prayers.magia = 5; G.prayers.dune = 6; await wait(1.0); await shot("candele")
	m.b_back.pressed.emit()
	ok(await until(func(): return m.scene == "street" and not m.busy), "indietro torna in strada")
	ok(absf(m.worlds.street.P.x - m.worlds.street.GROVE_X) < 40, "vicino al bivio")
	if Shop.code == "": ok(Shop._queue.has("pray:stelle"), "il premio aspetta il portafoglio")
	print("GROVE DONE")

## I luoghi da scoprire: CAMERETTA_RIDE=places
func _places_check() -> void:
	G.set_lang("it"); G.room_mode = "walk"; G.season = "auto"; G.fish = {}
	for ch in "−◀▶·×°…é":
		ok(UI.f_ui.has_char(ch.unicode_at(0)) and UI.f_body.has_char(ch.unicode_at(0)), "carattere " + ch)
	m.open_map(); await wait(0.3); await shot("mappa")
	ok(m._panel.size.y <= m.size.y, "la mappa sta nello schermo")
	m.close_modal(true)
	# dalla strada, a piedi
	m._start_game(false)
	await until(func(): return m.scene == "street" and not m.busy)
	for id in ["train", "sky", "arcade"]:
		m._enter_street(m.worlds.street.path_x(id) - 20); await wait(0.6)
		await shot("strada_" + id)
		await key(KEY_E)
		ok(await until(func(): return m.scene == id and not m.busy, 5), "dalla strada: " + id)
		await wait(1.8); await shot(id)
		var w = m.worlds[id]
		if id == "sky":
			var t0: float = w.off
			await key(KEY_R); ok(w.off == t0 + 1, "avanti di un'ora")
			await key(KEY_Q)
			var best: Dictionary = {}
			for b in w._bodies: if b.h.y > 8 and b.id != "sole": best = b
			if not best.is_empty():
				w.az = best.h.x; w.alt = clampf(best.h.y, 5, 85); await wait(0.2)
				await key(KEY_E); ok(w.sel.has("b"), "riconosce: " + w.line)
				await wait(2.5); await shot("sky_scelto")
			w.drag(Vector2(40, 0)); w.zoom(1)
			w.az = 180; w.alt = 40; w.fov = 70; await wait(0.4); await shot("sky_sud")
			w.az = 270; w.alt = 14; w.fov = 95; await wait(0.4); await shot("sky_ovest")
			var t1 := Time.get_ticks_msec(); var fr := Engine.get_process_frames()
			await wait(2.0); print("sky fps ", (Engine.get_process_frames() - fr) * 1000.0 / (Time.get_ticks_msec() - t1))
		elif id == "train":
			ok(w.cars.size() > 0 and w.world == 320.0 * (w.cars.size() + 1), "una carrozza per tappa (%d)" % w.cars.size())
			await key(KEY_E); ok(await until(func(): return m.modal_kind == "item", 3), "si legge la tappa")
			await wait(0.3); await shot("train_voce"); await key(KEY_ESCAPE)
			w.P.x = w.world - 60; await wait(2.5); await shot("train_fine")
		else:
			ok(w.games.size() >= 6, "cabinati: %d" % w.games.size())
			w.P.x = w._x(1); await wait(1.2); await shot("arcade_gioco")
			await key(KEY_E); ok(await until(func(): return m.modal_kind == "item", 3), "il cabinato apre la scheda"); await key(KEY_ESCAPE)
		m.b_back.pressed.emit()
		ok(await until(func(): return m.scene == "street" and not m.busy, 5) and absf(m.worlds.street.P.x - m.worlds.street.path_x(id)) < 40, "si torna al cartello: " + id)
	# dal lungomare
	var sea = m.worlds.sea
	m._enter_sea(); await wait(0.5)
	sea.P.x = 112; sea.P.target = -1; await wait(0.3); await shot("bottiglie_spiaggia")
	m._do_action(); ok(await until(func(): return m.modal_kind == "bottles", 10), "bottiglie"); await wait(0.4); await shot("bottiglie")
	if m._bottle_on:
		await m._send_bottle("Ciao dal futuro [b]x[/b] <i>", "Ada"); ok(m._bottle_msg == G.t("bottleSent"), "bottiglia lanciata")
		var all: Array = await Shop._call("/api/bottles/all")
		ok(all[1].size() == 1 and (await Shop._call("/api/bottles"))[1].is_empty(), "invisibile finche' non e' approvata")
	m.close_modal()
	sea.take_helmet(); await until(func(): return sea.state == "ride", 20)
	for q in [["pier", 0], ["light", 1]]:
		for s in sea.spots:
			if s[1] != q[0]: continue
			sea.x = s[0] - 20; sea.v = 0; sea.stops.map(func(z): z.state = "hidden"); await wait(0.5); await shot("sosta_" + q[0])
			ok(sea.prompt.get("label", "") == G.t("go")[q[0]], "sosta: " + str(sea.prompt.get("label", "")))
			m._do_action(); ok(await until(func(): return m.scene == q[0] and not m.busy, 5), "si entra: " + q[0])
			var w = m.worlds[q[0]]
			await wait(1.2); await shot(q[0])
			if q[0] == "pier":
				await key(KEY_E); ok(w.state == "wait", "lancia"); await wait(0.8); await shot("pier_attesa")
				ok(await until(func(): return w.state == "bite", 8), "abbocca"); await shot("pier_abbocca")
				await key(KEY_E); ok(w.state == "show" and G.fish.size() == 1, "preso: " + w.line)
				await wait(2.5); await shot("pier_preso")
			else:
				var f0: float = w.fringe(); w._add(0, 16); ok(w.fringe() < f0, "piu' distanti, frange piu' strette"); await wait(0.5); await shot("light_frange")
				await key(KEY_E); ok(not w.two, "una lampada sola"); await wait(0.5); await shot("light_una")
			m.b_back.pressed.emit()
			ok(await until(func(): return m.scene == "sea" and not m.busy, 5) and sea.state == "ride" and absf(sea.x - s[0]) < 60, "si torna in sella: " + q[0])
	# la torre: i tempi devono essere quelli giusti
	m._go_to("tower"); ok(await until(func(): return m.scene == "tower" and not m.busy, 5), "torre")
	var w = m.worlds.tower
	await wait(1.5); await shot("tower")
	var free := sqrt(2 * 55.0 / 9.80665)
	for which in 3:
		for air in [false, true]:
			w.which = which; w.air = air; w._reset()
			await key(KEY_E); await wait(1.4)
			if which == 2 and air: await shot("tower_piuma")
			Engine.time_scale = 6.0
			await until(func(): return w.a.end and w.b.end, 20); Engine.time_scale = 1.0
			if not air: ok(absf(w.a.t - free) < 0.005 and absf(w.b.t - free) < 0.005, "vuoto: %.3f e %.3f (teoria %.3f)" % [w.a.t, w.b.t, free])
			else: ok(w.b.t > w.a.t, "aria: ferro %.2f, %s %.2f" % [w.a.t, w.b.n, w.b.t])
	await wait(2.0); await shot("tower_fine")
	m.b_back.pressed.emit(); ok(await until(func(): return m.scene == "sea" and not m.busy, 5), "dalla torre al lungomare")
	for s in Season.IDS:
		m._set_season(s); m._enter_street(560.0); await wait(1.2); await shot("stagione_" + s)
	m.open_settings(); await wait(0.3); await shot("impostazioni"); ok(m._panel.size.y <= m.size.y, "impostazioni nello schermo"); m.close_modal()
	m._set_season("auto")
	print("PLACES DONE")

## Laboratorio, 1610, meteo, fantasmi, caffè, gru, foto, gatto, radio, visita: CAMERETTA_RIDE=addons
func _addons_check() -> void:
	G.set_lang("it"); G.room_mode = "walk"; G.season = "inverno"; G.secrets = {}; G.real_weather = true; G.ghosts = true
	Shop.code = ""; Shop.owned.clear(); Shop.worn.clear(); Shop._queue.clear(); Shop.balance = 0; Shop.online = false
	Season.apply(); Shop.apply()
	m._apply_texts(); await wait(0.4); await shot("menu")
	# --- visita in 60 secondi
	m._menu_act("visit"); await wait(1.2); await shot("visita_0")
	ok(m.visit.visible and m.visit.steps.size() >= 5 and absf(m.visit.each * m.visit.steps.size() - 60.0) < 0.1, "visita: %d tappe in 60 s" % m.visit.steps.size())
	for i in range(1, m.visit.steps.size()):
		await key(KEY_RIGHT); await wait(0.9); await shot("visita_%d" % i)
		ok(m.visit.box.position.y > 0 and m.visit.box.position.y + m.visit.box.size.y <= m.size.y + 1, "tappa %d nello schermo" % i)
	await key(KEY_ESCAPE); await wait(0.3); ok(not m.visit.visible and m.scene == "menu" and m.menu_ui.visible, "ESC torna al menu")
	m.open_map(); await wait(0.3); await shot("mappa"); ok(m._panel.size.y <= m.size.y, "mappa nello schermo"); m.close_modal(true)
	# --- laboratorio
	m._enter_street(m.worlds.street.path_x("lab") - 20); await wait(0.8); await shot("strada_lab")
	await key(KEY_E); ok(await until(func(): return m.scene == "lab" and not m.busy, 5), "si entra in laboratorio"); await wait(1.4); await shot("lab")
	var lab = m.worlds.lab
	for s in lab.SPOTS:
		lab.P.x = s[0]; await wait(0.3); await key(KEY_E)
		ok(await until(func(): return m.scene == s[1] and not m.busy, 5), "esperimento " + s[1]); await wait(1.0)
		var w = m.worlds[s[1]]
		match s[1]:
			"field":
				await shot("field")
				ok(w.lines.size() == 16, "linee del dipolo: %d" % w.lines.size())
				var arrive := 0
				for l in w.lines: if (l[0] as PackedVector2Array)[-1].distance_to(Vector2(210, 100)) < 7: arrive += 1
				ok(arrive >= 10, "vanno dal + al − (%d su 16)" % arrive)
				var mid: Vector2 = w.E_at(Vector2(160, 100)); ok(mid.x > 0 and absf(mid.y) < 1e-6, "campo al centro lungo l'asse")
				w.tap(Vector2(160, 50)); w.flip_sign(); w.tap(Vector2(60, 150)); ok(w.Q.size() == 4 and w.Q[3].q == -1, "si posano cariche")
				w.hold(Vector2(160, 50)); w.move_to(Vector2(170, 60)); w.release(); ok(w.Q[2].p == Vector2(170, 60), "si trascinano")
				w.flip_pot(); await wait(0.4); await shot("field_4"); w.tap(Vector2(60, 150)); ok(w.Q.size() == 3, "si tolgono")
			"foucault":
				ok(absf(w.rate() - 10.33) < 0.02 and absf(w.period() - 34.8) < 0.1, "Rosignano: %.2f gradi/ora, giro in %.1f ore" % [w.rate(), w.period()])
				await wait(3.0); await shot("foucault")
				w.li = 3; ok(w.period() == 0.0, "all'equatore non gira"); w.li = 1; ok(absf(w.period() - 23.93) < 0.02, "al polo un giorno siderale: %.2f" % w.period())
				w.li = 4; ok(w.rate() < 0, "a sud gira al contrario")
			"aurora":
				var l0: float = w.lat_deg(); w.energy = 2; ok(w.lat_deg() < l0, "tempesta: l'aurora scende (%.0f -> %.0f)" % [l0, w.lat_deg()])
				for k in 3: w.fire()
				await wait(4.6); await shot("aurora"); ok(w.lights.size() > 5, "il cielo si accende (%d)" % w.lights.size())
			"photon":
				w.shoot(1); await wait(0.5); await shot("photon_1")
				w.shoot(3000); ok(await until(func(): return w.n >= 3000, 12), "tremila fotoni"); await wait(0.2); await shot("photon_frange")
				var vis := func() -> float:
					var hi := 0; var lo := 1 << 30
					for i in range(24, 36): hi = maxi(hi, w.bins[i]); lo = mini(lo, w.bins[i])
					return float(hi - lo) / maxf(1, hi + lo)
				var v1: float = vis.call(); ok(v1 > 0.7, "frange ben visibili (contrasto %.2f)" % v1)
				w.flip_spy(); w.shoot(3000); await until(func(): return w.n >= 3000, 12); await shot("photon_spia")
				var v2: float = vis.call(); ok(v2 < 0.4, "col rivelatore spariscono (contrasto %.2f)" % v2)
		m.b_back.pressed.emit(); ok(await until(func(): return m.scene == "lab" and not m.busy, 5) and absf(lab.P.x - s[0]) < 5, "si torna al banco")
	m.b_back.pressed.emit(); ok(await until(func(): return m.scene == "street" and not m.busy, 5), "e dal laboratorio in strada")
	# --- 1610
	m._go_to("sky"); await until(func(): return m.scene == "sky" and not m.busy, 5); await wait(0.6)
	var sky = m.worlds.sky
	await key(KEY_T); await wait(0.6); await shot("sky_1610")
	var east := 0; var west := 0
	for q in Astro.jupiter_moons(sky.now()):
		if q[1] < -1: east += 1
		else: west += 1
	ok(sky.galileo and east == 3 and west == 1, "1610: Io ed Europa insieme e Callisto a est, Ganimede a ovest")
	for k in 24: await key(KEY_R)
	west = 0
	for q in Astro.jupiter_moons(sky.now()): if q[1] > 1: west += 1
	ok(west == 3, "il giorno dopo tre a ovest, come scrisse Galileo")
	# --- caffe'
	sky.goto.emit("coffee"); ok(await until(func(): return m.scene == "coffee" and not m.busy, 5), "cielo dei caffe'"); await until(func(): return m.worlds.coffee.loaded, 8); await wait(2.0); await shot("caffe")
	m._goto("starname"); await until(func(): return m.modal_kind == "star", 8); await wait(0.3); await shot("caffe_nome"); m.close_modal()
	m.b_back.pressed.emit(); ok(await until(func(): return m.scene == "sky" and not m.busy, 5), "si torna all'osservatorio")
	# --- meteo
	m._enter_street(560.0); await wait(0.5)
	Weather._next = 9999
	for k in ["pioggia", "neve", "nebbia", "temporale", "nuvole", "sereno"]:
		Weather.kind = k; Weather.temp = 9; m._apply_texts()
		if k == "temporale": Weather.flash = 0.8
		await wait(0.7 if k != "temporale" else 0.12); await shot("meteo_" + k)
		ok(m.crumb.text.contains("9°"), "in alto: " + m.crumb.text)
	Weather.kind = ""
	# --- fantasmi
	var other := {"id": "prova0prova0prova0", "scene": "street", "x": 600.0, "dir": -1, "wave": 0}
	if Shop.online or (await Shop._call("/api/stars"))[0] == 200:
		await Shop._call("/api/presence", other)
		m.ghosts.t = 0.0
		ok(await until(func(): return m.ghosts.others.size() == 1, 8), "si vede un altro visitatore")
		other.wave = 1; await Shop._call("/api/presence", other); m.ghosts.t = 0.0
		await until(func(): return m.ghosts.others.values()[0].hi > 0, 6)
		await key(KEY_G); await wait(0.4); await shot("fantasma"); ok(m.ghosts.hi > 0 and m.ghosts.others.values()[0].hi > 0, "ci si saluta")
	# --- gatto
	Shop.owned["pe_nero"] = true; Shop.wear("pe_nero"); m.pad_dir = 1; await wait(1.6); await shot("gatto_cammina"); m.pad_dir = 0; await wait(1.6); await shot("gatto_seduto")
	ok(absf(m.worlds.street.P.pet_x - m.worlds.street.P.x) < 45 and not m.worlds.street.P.pet_mov, "il gatto segue e si ferma")
	ShopUI.cat = "pet"; ShopUI.sel = "pe_bianco"; m.open_shop(); await wait(1.4); await shot("negozio_gatto"); m.close_modal()
	# --- foto
	await key(KEY_P); await wait(0.4); await shot("foto"); ok(m.photo.visible and not m.hud.visible, "modalita' foto")
	await key(KEY_RIGHT); await key(KEY_RIGHT); await wait(0.2)
	await key(KEY_ENTER); await until(func(): return m.photo.last != null, 4); await wait(0.2)
	if m.photo.last: m.photo.last.save_png(out + "/zz_cartolina.png")
	ok(m.photo.last != null and m.photo.last.get_width() > 400, "cartolina salvata (%s, scatto %s)" % [m.photo.last.get_size() if m.photo.last else "niente", m.photo.shooting])
	await key(KEY_ESCAPE); await wait(0.2); ok(not m.photo.visible and m.hud.visible and m.view.material == null, "si esce e il filtro sparisce")
	# --- gru
	for id in m.secrets.AT:
		var a: Array = m.secrets.AT[id]
		match a[0]:
			"street": m._enter_street(a[1] - 60)
			"living": m._enter_living(false)
			"room": m._enter_room()
			"grove": m._enter_grove()
			"sea": m._enter_sea()
			_: m._enter_place(a[0])
		await wait(0.5)
		var w = m.worlds[a[0]]
		if a[0] in ["train", "arcade", "lab", "grove"]: w.P.x = clampf(a[1] - 50, 20, 5000); w.cam = clampf(a[1] - 160, 0, 2000); await wait(0.3)
		var c: float = w.cam if "cam" in w and a[0] != "living" else 0.0
		ok(a[1] - c > 2 and a[1] - c < 318, "gru raggiungibile: " + id)
		await shot("gru_" + id)
		if not G.secrets.has(id): ok(m.secrets.tap(Vector2(a[1] - c, a[2])), "presa: " + id)
	ok(G.secrets.size() == 10, "dieci gru")
	# --- radio
	m._enter_sea(); await wait(0.4); var sea = m.worlds.sea
	sea.take_helmet(); await until(func(): return sea.state == "ride", 20)
	m.pad_dir = 1; await key(KEY_R); await wait(0.4); ok(Sfx.station == 1 and Sfx.radio.playing, "radio: " + G.t("radioNames")[1]); await shot("radio")
	for k in 3: await key(KEY_R)
	ok(Sfx.station == 4 and not Sfx.radio.playing and sea.narr_text() != null and not sea.narr.is_empty(), "notizie di fisica"); await wait(2.5); await shot("radio_notizie")
	await key(KEY_R); ok(Sfx.station == 0, "spenta"); m.pad_dir = 0
	m.open_settings(); await wait(0.3); await shot("impostazioni"); ok(m._panel.size.y <= m.size.y, "impostazioni nello schermo"); m.close_modal()
	print("ADDONS DONE")

## Il menu come pausa: CAMERETTA_RIDE=pause
func _pause_check() -> void:
	G.set_lang("it"); G.room_mode = "walk"; G.real_weather = false
	m._apply_texts(); await wait(0.3)
	ok(not m.menu_items.any(func(b): return b.get_meta("act") == "resume"), "all'inizio niente CONTINUA")
	var pause := func() -> void:
		m._to_menu(); await until(func(): return m.scene == "menu" and not m.busy, 5); await wait(0.4)
	var back := func(sc: String) -> bool:
		await key(KEY_ESCAPE); return await until(func(): return m.scene == sc and not m.busy, 5)
	# strada: posizione e bolle
	m._start_game(false); await until(func(): return m.scene == "street" and not m.busy)
	var st = m.worlds.street
	st.P.x = 720; await wait(3.0)
	var read: int = st.bub.filter(func(b): return b.state != "idle").size()
	var txt: Array = st.bub.map(func(b): return b.data.text)
	await pause.call(); await shot("pausa_strada")
	ok(m.menu_items[0].get_meta("act") == "resume" and m.menu_sel == 0, "CONTINUA e' la prima voce")
	var cl: Control = m.menu_ui.get_node("Col")
	ok(cl.scale.x > 0.88 or m.compact, "menu leggibile (%.2f)" % cl.scale.x)
	ok(cl.position.y + cl.size.y * cl.scale.y <= m.size.y + 1 and (not m.portrait or cl.position.y + cl.size.y <= m.menu_ui.get_node("Foot").position.y + 1), "menu senza sovrapposizioni")
	await wait(1.0)
	print("X prima ", st.P.x, " letti ", read)
	var bk: bool = await back.call("street"); print("X ", st.P.x, " scena ", m.scene, " ", bk, " letti ", st.bub.filter(func(b): return b.state != "idle").size(), " testi ", st.bub.map(func(b): return b.data.text) == txt)
	ok(bk and absf(st.P.x - 720) < 1 and st.bub.filter(func(b): return b.state != "idle").size() >= read and st.bub.map(func(b): return b.data.text) == txt, "strada: stesso punto, stesse bolle")
	await wait(0.5); await shot("ripresa_strada")
	# dopo la visita in 60 secondi
	await pause.call(); m._menu_act("visit"); await wait(0.8); await key(KEY_RIGHT); await wait(0.5); await key(KEY_ESCAPE); await wait(0.4)
	ok(m.menu_items[0].get_meta("act") == "resume", "dopo la visita si puo' ancora continuare")
	ok(await back.call("street") and absf(st.P.x - 720) < 1, "e si torna allo stesso punto")
	# cambio lingua in pausa
	await pause.call(); G.set_lang("en"); await wait(0.3); m._menu_act("resume"); ok(await until(func(): return m.scene == "street" and not m.busy, 5), "CONTINUA con un clic, in inglese"); G.set_lang("it")
	# mentre scende un sentiero non si va in pausa a meta'
	# cameretta
	m._enter_room(); await wait(0.4); m.worlds.room.P.x = 120; m.worlds.room.py = 180.0; await wait(0.2)
	await pause.call(); ok(await back.call("room") and absf(m.worlds.room.P.x - 120) < 1 and absf(m.worlds.room.py - 180) < 1, "cameretta: stesso punto")
	m._enter_living(false); await wait(0.3); m.worlds.living.P.x = 150; await pause.call(); ok(await back.call("living") and absf(m.worlds.living.P.x - 150) < 2, "salotto: stesso punto")
	m._enter_grove(); await wait(0.3); m.worlds.grove.P.x = 730; await wait(0.3); await pause.call(); ok(await back.call("grove") and absf(m.worlds.grove.P.x - 730) < 1, "templi: stesso punto")
	# in Vespa, in corsa
	m._enter_sea(); await wait(0.4); var sea = m.worlds.sea
	sea.take_helmet(); await until(func(): return sea.state == "ride", 20)
	m.pad_dir = 1; await wait(3.0); m.pad_dir = 0
	var x0: float = sea.x; var v0: float = sea.v
	await pause.call(); var xp: float = sea.x; await wait(1.5)
	ok(absf(sea.x - xp) < 0.01, "in pausa la Vespa non si muove")
	ok(await back.call("sea") and sea.state == "ride" and sea.engine and absf(sea.x - xp) < 90, "in Vespa: stesso tratto (x %.0f -> %.0f, v %.0f)" % [xp, sea.x, v0])
	await wait(0.3); await shot("ripresa_vespa")
	# fermo a una tappa
	var s: Dictionary = sea.stops[0]; sea.x = float(s.x) - 60; sea.v = 0; s.state = "up"; await wait(0.3); sea.stop_at(0)
	await until(func(): return m.modal.visible and m.modal_kind == "ride", 10)
	sea.state = "parked"; m.close_modal(true); sea.state = "parked"
	m._to_menu(); await until(func(): return m.scene == "menu" and not m.busy, 5); await wait(0.3)
	ok(await back.call("sea") and await until(func(): return m.modal_kind == "ride", 3), "fermo a una tappa: la scheda si riapre"); m.close_modal(); ok(sea.state == "ride", "e si riparte")
	# luoghi: il laboratorio dentro un esperimento
	m._enter_place("lab"); m.worlds.lab.at = 90.0; m._goto("field"); await until(func(): return m.scene == "field" and not m.busy, 5); await wait(0.5)
	m.worlds.field.tap(Vector2(60, 60)); await wait(0.2); await pause.call(); await shot("pausa_campi")
	ok(await back.call("field") and m.worlds.field.Q.size() == 3 and m.place_bar.visible, "campi: le cariche restano, i comandi pure")
	m.b_back.pressed.emit(); ok(await until(func(): return m.scene == "lab" and not m.busy, 5), "e indietro porta al laboratorio")
	# ricominciare davvero
	await pause.call(); m._menu_act("enter"); ok(await until(func(): return m.scene == "street" and not m.busy, 6) and m.worlds.street.P.x < 60 and m.paused_scene == "", "RICOMINCIA riparte dall'inizio")
	print("PAUSE DONE")

## Gli inviti a offrire un caffè: CAMERETTA_RIDE=coffee
func _coffee_check() -> void:
	G.set_lang("it"); G.room_mode = "walk"; G.real_weather = false; G.ride_found = true
	Shop.code = ""; Shop.deposit = ""; Shop._queue.clear(); Shop.online = false
	m._apply_texts(); await wait(0.5); await shot("menu")
	var cb = m.menu_ui.find_child("Coffee", true, false)
	ok(cb != null and cb.get_global_rect().end.x <= m.get_viewport_rect().size.x, "pulsante nel menu")
	cb.pressed.emit(); ok(await until(func(): return m.modal_kind == "coffee", 8), "si apre la finestra"); await wait(0.4); await shot("finestra")
	ok(m._panel.size.y <= m.size.y and m._panel.size.x <= m.size.x, "finestra nello schermo"); print("pronte: ", Shop.donate_ready(), " ", Shop.deposit)
	if Shop.donate_ready():
		var btn = m._panel.find_children("*", "Button", true, false).filter(func(b): return b.text.begins_with("1 ·"))[0]
		ok(btn.text.contains("DON-") and not btn.text.contains("CRI-"), "si copia il codice pubblico")
		btn.pressed.emit(); await wait(0.2); ok(m.modal_kind == "coffee" and ShopUI.msg == G.t("shopCopied"), "copiato, resta la stessa finestra")
	m.close_modal()
	m._enter_street(m.worlds.street.CART_X - 30); await wait(0.6); await shot("chiosco")
	ok(m.worlds.street.prompt.get("label", "") == G.t("coffeeBtn"), "chiosco in strada")
	ok(m.tools.position.x >= 0, "i pulsanti in alto ci stanno (x %.0f)" % m.tools.position.x)
	await key(KEY_E); ok(await until(func(): return m.modal_kind == "coffee", 8), "E al chiosco"); m.close_modal()
	m._enter_place("arcade"); await wait(0.4); m.worlds.arcade.P.x = m.worlds.arcade._coins_x(); await wait(1.4); await shot("gettoniera")
	await key(KEY_E); ok(await until(func(): return m.modal_kind == "shop" and ShopUI.getting, 8), "la gettoniera porta alle monete"); await wait(0.3); await shot("monete"); m.close_modal()
	m._enter_place("coffee", "sky"); await wait(1.0); await shot("cielo"); ok(m.worlds.coffee.bar().any(func(q): return q[0] == G.t("coffeeBtn")), "nel cielo dei caffe'")
	m.open_ride_end(); await wait(0.3); await shot("fine_giro"); m.close_modal(true)
	m.open_help(); await wait(0.3); await shot("aiuto"); ok(m._panel.size.y <= m.size.y, "aiuto nello schermo"); m.close_modal(true)
	m._enter_room(); await wait(0.4); m.open_section("finestra"); await wait(0.5); m.close_modal(true)
	m._enter_street(300.0); await wait(0.6); m.show_nudge(); await wait(0.9); await shot("invito")
	var r: Rect2 = m.nudge_node.get_rect(); ok(r.position.x >= 0 and r.end.x <= m.size.x + 1 and r.position.y >= 0, "invito nello schermo")
	m._hide_nudge(); await wait(0.6); m._nudge_t = 400.0; await wait(0.3); ok(m.nudge_node == null, "l'invito non torna per un mese")
	G.S.erase("donate_url"); m._apply_texts(); await wait(0.5)
	ok(m.menu_ui.find_child("Coffee", true, false) == null and not m.b_cup.visible, "senza pagina non compare niente"); m.open_coffee(); await wait(0.2); ok(not m.modal.visible, "e la finestra non si apre")
	print("COFFEE DONE")
