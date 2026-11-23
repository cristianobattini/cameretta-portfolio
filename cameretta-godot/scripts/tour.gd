extends Node
## Giro automatico di prova (solo sviluppo): CAMERETTA_TOUR=/cartella/screenshot godot ...

var m
var out := ""
var n := 0

func _ready() -> void:
	m = get_parent()
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
	ok(m.menu_items.any(func(b): return b.get_meta("act") == "ride"), "voce GIRO IN VESPA nel menu")
	m._menu_act("ride")
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
	await wait(2.6); await shot("templi")
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
