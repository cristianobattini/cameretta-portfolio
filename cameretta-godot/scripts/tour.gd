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
	await get_tree().process_frame
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
	await wait(0.25)
	await shot("mount")
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
