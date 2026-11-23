extends Node
## Suoni: registrazioni CC0 (vedi licenses/), bus separati per musica, ambiente, passi ed effetti.

var _snd: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _scene := "menu"
var music: AudioStreamPlayer
var engine: AudioStreamPlayer
var waves: AudioStreamPlayer
var _engine_v := 0.0
var _sea_near := 0.0
var fire: AudioStreamPlayer
var tv_voice: AudioStreamPlayer
var tv_static: AudioStreamPlayer
var _music_tween: Tween
var _gust_t := 4.0
var _clock_t := 0.0
var _clock_tock := false
var _prox := {"fire": 0.0, "tv": 0.0}
var _amb := 0.5
var _steps := 0.7
var _music_vol := 0.35
var _music_ready := false

func _ready() -> void:
	for b in ["Music", "Ambience", "Steps", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var dir := DirAccess.open("res://sounds")
	if dir:
		for f in dir.get_files():
			f = f.trim_suffix(".import").trim_suffix(".remap")
			if f.ends_with(".ogg"):
				_snd[f.get_basename()] = load("res://sounds/" + f)
	print("Sfx: %d suoni caricati, bus: %d" % [_snd.size(), AudioServer.bus_count])
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	music = _loop_player("Music")
	fire = _loop_player("Ambience", "fire_loop")
	tv_voice = _loop_player("Ambience", "tv_voices")
	tv_static = _loop_player("Ambience", "tv_static")
	engine = _loop_player("SFX", "engine_loop")
	waves = _loop_player("Ambience", "waves_loop")

func _loop_player(bus: String, name := "") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.volume_db = -80
	if name != "" and _snd.has(name):
		var s: AudioStream = _snd[name].duplicate()
		if s is AudioStreamOggVorbis: s.loop = true
		p.stream = s
	add_child(p)
	return p

func levels() -> void:
	_amb = G.fnum("ambience_volume", 0.5)
	_steps = G.fnum("steps_volume", 0.7)
	_music_vol = G.fnum("music_volume", 0.35)
	apply_volumes()

func apply_volumes() -> void:
	var on := G.audio_on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)
	_set_bus("Ambience", _amb * G.effects_user)
	_set_bus("Steps", _steps * G.effects_user)
	_set_bus("SFX", G.effects_user)
	_set_bus("Music", _music_vol * G.music_user)

func _set_bus(n: String, v: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(n), linear_to_db(maxf(v, 0.0001)))

func set_enabled(on: bool) -> void:
	G.audio_on = on
	G.save_prefs()
	apply_volumes()
	if on: start_music()

# ------------------------------------------------------------------ effetti
func play(name: String, vol := 1.0, pitch := 1.0, bus := "SFX") -> void:
	if not _snd.has(name): return
	var p: AudioStreamPlayer = null
	for q in _pool:
		if not q.playing:
			p = q
			break
	if p == null: p = _pool[0]
	p.stream = _snd[name]
	p.bus = bus
	p.volume_db = linear_to_db(maxf(vol, 0.0001))
	p.pitch_scale = pitch
	p.play()

func key(ch: String) -> void:
	if ch == " " or ch == "": return
	play("key_%d" % randi_range(0, 3), randf_range(0.35, 0.55), randf_range(0.92, 1.12))

func step_snow() -> void: play("step_snow_%d" % randi_range(0, 4), randf_range(0.5, 0.75), randf_range(0.9, 1.08), "Steps")
func step_wood() -> void: play("step_wood_%d" % randi_range(0, 4), randf_range(0.45, 0.65), randf_range(0.92, 1.06), "Steps")
func hover() -> void: play("ui_hover", 0.45, randf_range(0.97, 1.05))
func move() -> void: play("ui_move", 0.5)
func select() -> void: play("ui_select", 0.7)
func click() -> void: play("ui_click", 0.6)
func open() -> void: play("ui_open", 0.8); play("ui_click", 0.35, 0.8)
func close() -> void: play("ui_close", 0.55)
func page() -> void: play("ui_page", 0.6)
func start() -> void: play("ui_start", 0.75)
func toggle() -> void: play("ui_toggle", 0.6)
func door_open() -> void: play("door_open", 0.75)
func door_close() -> void: play("door_close", 0.65)
func channel() -> void:
	play("ui_toggle", 0.7, 0.8)
	tv_static.volume_db = linear_to_db(0.6 * maxf(_prox.tv, 0.25))
	if not tv_static.playing: tv_static.play()
	_static_burst = 0.35
func pop() -> void: play("ui_click", 0.5, 0.6)

var _static_burst := 0.0

# ------------------------------------------------------------------ ambiente
func scene(name: String) -> void:
	_scene = name
	var living := name == "living"
	var room := name == "room"
	if living or room:
		if not fire.playing: fire.play(randf() * 10.0)
		if not tv_voice.playing: tv_voice.play(randf() * 8.0)
		if not tv_static.playing: tv_static.play()
	_engine_v = 0.0
	if name == "sea" and not waves.playing: waves.play(randf() * 12.0)
	_gust_t = randf_range(2.0, 5.0)

## Vicino al sentiero si sente già il mare.
func near_sea(p: float) -> void:
	_sea_near = 0.4 * p
	if p > 0 and not waves.playing: waves.play(randf() * 12.0)

## Motore della Vespa: level 0 = minimo, 1 = gas; quiet = fermi a guardare.
func ride(on: bool, level: float, quiet: bool) -> void:
	_engine_v = 0.0 if not on else 0.07 if quiet else 0.13 + 0.15 * clampf(level, 0, 1)
	if on and not engine.playing: engine.play()
	var p := 0.72 + 0.85 * clampf(level, 0, 1.4)
	engine.pitch_scale = lerpf(engine.pitch_scale, p, 0.08)

func proximity(fire_p: float, tv_p: float) -> void:
	_prox.fire = fire_p
	_prox.tv = tv_p

func _process(dt: float) -> void:
	var fv := 0.0
	var tvv := 0.0
	var stv := 0.0
	match _scene:
		"living":
			fv = 0.35 + 0.65 * _prox.fire
			var ch := G.tv_channel
			var tvn: float = 0.18 + 0.6 * _prox.tv
			tvv = tvn * (1.0 if ch == 1 else 0.55 if ch == 0 else 0.25 if ch == 3 else 0.0)
			stv = tvn * (0.8 if ch == 2 else 0.0)
		"room":
			fv = 0.1
			tvv = 0.04 if G.tv_channel != 2 else 0.0
	if _static_burst > 0:
		_static_burst -= dt
		stv = maxf(stv, 0.5)
	_fade_to(engine, _engine_v if _scene == "sea" else 0.0, dt)
	if engine.playing and _engine_v == 0.0 and engine.volume_db < -70: engine.stop()
	_fade_to(waves, 0.6 if _scene == "sea" else _sea_near if _scene == "street" else 0.0, dt)
	_fade_to(fire, fv, dt)
	_fade_to(tv_voice, tvv, dt)
	_fade_to(tv_static, stv, dt * 3)
	# raffiche di vento (niente fruscio continuo): solo in strada e nel menu, attenuate in casa
	_gust_t -= dt
	if _gust_t <= 0:
		_gust_t = randf_range(7.0, 14.0)
		var gv := {"street": 0.55, "sea": 0.4, "grove": 0.35, "menu": 0.3, "living": 0.08, "room": 0.06}.get(_scene, 0.0) as float
		if gv > 0: play("wind_gust", gv * randf_range(0.7, 1.0), randf_range(0.8, 1.1), "Ambience")
	# orologio a pendolo del salotto
	if _scene == "living":
		_clock_t -= dt
		if _clock_t <= 0:
			_clock_t = 1.0
			_clock_tock = not _clock_tock
			play("clock_tick", 0.22 if _clock_tock else 0.3, 0.85 if _clock_tock else 1.0, "Ambience")

func _fade_to(p: AudioStreamPlayer, lin: float, dt: float) -> void:
	var cur := db_to_linear(p.volume_db)
	var nv := move_toward(cur, lin, dt * 1.2)
	p.volume_db = linear_to_db(maxf(nv, 0.00001))

# ------------------------------------------------------------------ musica
func load_music() -> void:
	var u := str(G.S.get("music_url", ""))
	if not G.safe_url(u): return
	var st = await G.fetch_audio(u)
	if st == null: return
	if "loop" in st: st.loop = true
	music.stream = st
	_music_ready = true
	start_music()

func start_music() -> void:
	if not _music_ready or not G.audio_on: return
	if not music.playing:
		music.volume_db = -60
		music.play()
	_fade_music(0.0, 0.8)

func duck() -> void:
	if not music.playing: return
	_fade_music(-12.0, 0.3)
	get_tree().create_timer(0.9).timeout.connect(func(): _fade_music(0.0, 0.9))

func _fade_music(db: float, time: float) -> void:
	if _music_tween: _music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(music, "volume_db", db, time)
