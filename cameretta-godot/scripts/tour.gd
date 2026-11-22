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
