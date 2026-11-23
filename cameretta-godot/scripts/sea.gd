extends Node2D
## Bonus: il giro in Vespa sul lungomare innevato, da Rosignano verso Pisa, dalla notte all'alba.
## Si arriva a piedi, si mette il casco, si guida. Ogni voce del portfolio è una tappa che spunta dalla neve.
## Si guarda a ovest e si va a nord: il mare resta a sinistra della strada, la luna tramonta e l'alba arriva da dietro.

signal open_stop(i: int)
signal chapter(i: int)
signal mode_changed
signal visit(id: String)
signal finished

const SLOT := 200.0            # passo del lungomare: un lampione ogni SLOT, una tappa a metà fra due lampioni
const VESPA_X := 236.0
const MOUNT_HOP := 0.34            # il saltello…
const MOUNT_SIT := 0.3             # …e la discesa sulla sella
const MAX_V := 118.0
const TURBO_V := 172.0
const ORDER := ["libreria", "letto", "scrivania", "lavagna", "finestra"]
const LIGHTS := [Color("ff605a"), Color("ffd664"), Color("6edc8c"), Color("6eb4ff")]
const ORION := [[0, 0, 2], [17, 3, 1], [8, 14, 1], [10, 13, 1], [12, 12, 1], [3, 27, 1], [20, 25, 2], [9, 19, 0], [9, 22, 0]]

# emblema scelto in base alle parole della voce (titolo, categoria, etichette); il primo che corrisponde vince
const EMBLEM_RULES := [
	["telescope", ["astro"]], ["grades", ["provia"]], ["trend", ["unitrend", "trend"]], ["vault", ["vault", "password", "cassaforte"]],
	["gallery", ["gallery", "galler", "foto", "photo"]], ["candles", ["trader", "trading", "algo"]], ["field", ["linee di forza", "force line", "campo elettr", "electric", "magnet"]],
	["dream", ["freud", "sogni", "dream"]], ["butterfly", ["fanciullin", "pascoli"]], ["book", ["joyce", "dublin", "romanzo", "novel"]],
	["parabola", ["cinematica", "kinemat"]], ["integral", ["analisi mat", "calculus"]], ["vectors", ["geometria", "algebra", "linear", "gal"]],
	["flask", ["laborator", "lab 1", "lab 2"]], ["chat", ["forum", "blog"]], ["diploma", ["diploma", "maturit"]], ["code", ["full-stack", "svilupp", "developer"]],
	["tools", ["con cosa lavoro", "work with", "stack", "strument"]], ["branch", ["github", "cbattini"]], ["tower", ["pisa", "studente", "student", "universit"]],
	["pendulum", ["fisica", "physics"]], ["cert", ["attestat", "certific", "corso", "course"]],
]
const EMBLEM_DEFAULT := {"libreria": "book", "letto": "pen", "scrivania": "code", "lavagna": "pendulum", "finestra": "star"}

var P: Player
var state := "walk"            # walk, helmet, mount, start, ride, parking, parked, ending, end
var st := 0.0                  # secondi nello stato corrente
var x := VESPA_X               # centro della Vespa
var sit_bump := 0.0
var spots: Array = []          # luoghi da visitare lungo la strada: [x, id]
var _quiet := 0.0               # da quanto la voce tace
var _quotes_n := 0
var v := 0.0
var dist := 0.0
var cam := 0.0
var last_cam := 0.0
var time := 0.0
var input_dir := 0
var run := false
var locked := false
var paused := false            # una scheda è aperta: la voce narrante aspetta
var prompt: Dictionary = {}
var chapters: Array = []       # {sec, x0, x1, num, place, km}
var stops: Array = []          # {x, it, sec, kind, emblem, state, t, seen, ch}
var world_len := 2000.0
var end_x := 1800.0
var engine := false
var cur_chapter := -1
var park_i := -1
var target_x := -1.0
var target_stop := -1
var narr: Dictionary = {}      # battuta in corso {lines, i, shown, t, hold}
var pose := "stop"

var _dt := 0.0
var _rects: Dictionary = {}
var _J: Dictionary = {}
var _props: Array = []
var _gulls: Array = []
var _flakes: Array = []
var _puffs: Array = []         # gas di scarico, respiro, neve spostata
var _glints: Array = []
var _stars: Array = []
var _shoot := {"t": -1.0, "x": 0.0, "y": 0.0}
var _shoot_wait := 4.0
var _moon: ImageTexture
var _said: Dictionary = {}
var _kick_n := 0
var _flicker := 0.0
var _horn_t := 0.0
var _idle_t := 0.0
var _breath := 2.0
var _brake := false
var _snow_on := true
var _helmet_on := false
var _end_lines := false
var _dip := 0.0
var _last_v := 0.0

var back_l: Layer
var glow1_l: Layer
var near_l: Layer
var glow2_l: Layer
var front_l: Layer
var glow3_l: Layer
var fore_l: Layer

func _ready() -> void:
	P = Player.new()
	back_l = Layer.make(self, _draw_back)
	glow1_l = Layer.make(self, _draw_glow_back, true)
	near_l = Layer.make(self, _draw_near)
	glow2_l = Layer.make(self, _draw_glow_near, true)
	front_l = Layer.make(self, _draw_front)
	glow3_l = Layer.make(self, _draw_glow_front, true)
	fore_l = Layer.make(self, _draw_fore)

# ================================================================== costruzione
func build() -> void:
	_J = G.J.sea
	_rects = _J.rects
	_make_moon()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1909
	chapters.clear(); stops.clear(); _props.clear(); spots.clear()
	var ids: Array = []
	for id in ORDER:
		if G.by_id.has(id): ids.append(id)
	for s in G.sections:
		if not ids.has(s.id): ids.append(s.id)
	var slot := 3                  # le prime tre "caselle": scalinata, Vespa, partenza
	_prop("stairs", 46, 178)
	_prop("bench", 345, 163)
	_prop("tamarisk", 432, 163)
	var num := 0
	for id in ids:
		var sec: Dictionary = G.by_id[id]
		var items: Array = sec.get("items", [])
		if items.is_empty(): continue
		num += 1
		var ch := {"sec": sec, "id": id, "num": num, "x0": slot * SLOT + 100.0, "x1": 0.0}
		ch.lm = ch.x0 + SLOT       # casella del luogo
		_prop("roadsign", ch.x0, 162)
		match id:
			"libreria":
				_prop("kiosk", ch.lm, 162)
				_prop("bench", ch.lm + 160, 163)
			"letto":
				for k in 7: _prop("hut%d" % (k % 4), ch.lm - 130 + k * 42, 149, 0.6, ch.lm)
				_prop("snowman", ch.lm + 24, 163)
			"scrivania":
				_prop("boat0", ch.lm - 84, 141, 0.5, ch.lm, true)
				spots.append([ch.lm + 4, "pier"])
				_prop("boat1", ch.lm + 4, 144, 0.5, ch.lm, true)
				_prop("boat0", ch.lm + 92, 140, 0.5, ch.lm, true)
			"lavagna":
				_prop("lighthouse", ch.lm + 30, 130, 0.4, ch.lm)
				spots.append([ch.lm + 20, "light"])
			"finestra":
				for k in 3: _prop("pine%d" % (k % 2), ch.lm - 96 + k * 100, 153, 1.0, 0.0, false, "mid")
		slot += 2
		for it in items:
			var sx := slot * SLOT + 100.0
			stops.append({"x": sx, "it": it, "sec": sec, "kind": id if _J.stops.has(id) else "scrivania", "emblem": emblem_for(it, id), "state": "hidden", "t": 0.0, "seen": G.ride_seen.has(str(it.id)), "ch": chapters.size()})
			# qualche dettaglio tra una tappa e l'altra, sempre uguale a ogni giro
			var r := rng.randf()
			if r < 0.22: _prop("bench", sx + 62, 163)
			elif r < 0.36: _prop("tamarisk", sx + 60, 162)
			elif r < 0.5: _prop("pine%d" % (slot % 2), sx + 70, 153, 1.0, 0.0, false, "mid")
			slot += 1
		ch.x1 = slot * SLOT
		chapters.append(ch)
	end_x = slot * SLOT + 100.0
	_prop("scope", end_x + 46, 163)
	_prop("bench", end_x + 84, 163)
	_prop("pine1", end_x - 104, 153, 1.0, 0.0, false, "mid")
	world_len = end_x + 260.0
	_glints.clear()
	for i in 46: _glints.append([rng.randf_range(0, 320), _J.horizon + 2 + 34 * pow(rng.randf(), 1.4), rng.randf_range(0, TAU), rng.randf_range(1.2, 3.0)])
	_stars.clear()
	for i in 110: _stars.append([rng.randf_range(0, 340), 84 * pow(rng.randf(), 1.2), rng.randf_range(0, TAU), rng.randf_range(0.35, 1.0)])

func _prop(n: String, px: float, base: float, par := 1.0, ref := 0.0, bob := false, layer := "") -> void:
	_props.append({"n": n, "x": px, "base": base, "par": par, "ref": ref, "bob": bob, "layer": layer if layer != "" else ("near" if par == 1.0 else "mid")})

static func emblem_for(it: Dictionary, sec_id: String) -> String:
	# prima il titolo, poi la categoria
	for hay in [(str(it.get("title", "")) + " " + str(it.get("title_en", ""))).to_lower(), str(it.get("kicker", "")).to_lower()]:
		for r in EMBLEM_RULES:
			for w in r[1]:
				if hay.contains(w): return r[0]
	return EMBLEM_DEFAULT.get(sec_id, "star")

func emblem_tex(n: String) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = G.tex.sea_emblems
	a.region = Rect2(maxi(0, (_J.emblems as Array).find(n)) * 16, 0, 16, 16)
	return a

func _make_moon() -> void:
	var img := Image.create(27, 27, false, Image.FORMAT_RGBA8)
	for py in 27:
		for px in 27:
			var d := Vector2(px - 13, py - 13)
			if d.length() > 12.4: continue
			var c := Color(1, 0.955, 0.84) * (1.0 - 0.14 * maxf(0, (d.x + d.y) / 24))
			for k in [[-5, -3, 3.4], [4, 4, 2.6], [-1, 7, 2.0], [5, -5, 1.7], [-7, 4, 1.5]]:
				if (d - Vector2(k[0], k[1])).length() < k[2]: c = c * 0.88
			c.a = 1
			img.set_pixel(px, py, c)
	_moon = ImageTexture.create_from_image(img)

func enter() -> void:
	if chapters.is_empty(): build()
	P = Player.new()
	P.x = 52
	x = VESPA_X
	v = 0; dist = 0; cam = 0; last_cam = 0
	engine = false; _helmet_on = false; _snow_on = true; _kick_n = 0; _end_lines = false
	cur_chapter = -1; park_i = -1; target_x = -1; target_stop = -1
	narr = {}; _quiet = 0.0; _said.clear(); _puffs.clear()
	for s in stops:
		s.state = "hidden"; s.t = 0.0
		s.seen = G.ride_seen.has(str(s.it.id))
	_flakes = []
	for i in 100:
		var z := 0.5 if randf() < 0.6 else 1.1
		_flakes.append({"x": randf_range(0, 320), "y": randf_range(-20, 200), "z": z, "vy": z * randf_range(10, 18), "ph": randf_range(0, 6)})
	_gulls.clear()
	var gx := 520.0
	while gx < world_len - 200:
		for k in randi_range(1, 3): _gulls.append({"x": gx + k * 17, "y": 121.0, "st": "sit", "vx": 0.0, "vy": 0.0, "t": randf() * 3, "dir": -1 if randf() < 0.5 else 1})
		gx += randf_range(420, 760)
	_set_state("walk")
	P.target = 96.0                # scende l'ultimo gradino da solo

func _set_state(s: String) -> void:
	state = s
	st = 0.0
	prompt = {}
	if s == "ride": _idle_t = 0.0
	mode_changed.emit()

func riding() -> bool:
	return state in ["ride", "parking", "parked", "ending", "end"]

func progress() -> float:
	return clampf((x - VESPA_X) / (end_x - VESPA_X), 0, 1)

func focus_x() -> float:
	return (P.x if state in ["walk", "helmet"] else x + 20) - cam

func seen_count() -> int:
	var n := 0
	for s in stops: if s.seen: n += 1
	return n

## Chilometri che mancano a Pisa: circa 45 da Rosignano, una decina da Marina di Pisa.
func km_at(wx: float) -> int:
	return int(roundf(lerpf(45.0, 11.0, clampf((wx - VESPA_X) / (end_x - VESPA_X), 0, 1))))

# ================================================================== narrazione
func say(key: String, lines: Array, delay := 0.2) -> void:
	if _said.has(key) or lines.is_empty(): return
	_said[key] = true
	narr = {"lines": lines, "i": 0, "shown": 0, "t": delay, "hold": 0.0}

func narr_text() -> String:
	return "" if narr.is_empty() else str(narr.lines[narr.i]).substr(0, narr.shown)

func narr_done() -> bool:
	return narr.is_empty() or narr.shown >= str(narr.lines[narr.i]).length()

## Se la lingua cambia, la battuta in corso si chiude (la prossima è già nella lingua nuova).
func drop_narr() -> void:
	narr = {}

func _narrate(dt: float) -> void:
	if narr.is_empty() or paused: return
	var full := str(narr.lines[narr.i])
	if narr.shown < full.length():
		narr.t -= dt
		while narr.t <= 0 and narr.shown < full.length():
			narr.shown += 1
			var ch := full.substr(narr.shown - 1, 1)
			if narr.shown % 2 == 0: Sfx.key(ch)
			narr.t += 0.24 if ".!?".contains(ch) else 0.12 if ",;:".contains(ch) else 0.03
		return
	narr.hold += dt
	if narr.hold < 1.4 + full.length() * 0.022: return
	narr.i += 1
	narr.shown = 0; narr.t = 0.15; narr.hold = 0.0
	if narr.i >= narr.lines.size(): narr = {}

# ================================================================== aggiornamento
func update(dt: float) -> void:
	time += dt
	_dt = dt
	st += dt
	_horn_t = maxf(0, _horn_t - dt)
	_flicker = maxf(0, _flicker - dt)
	prompt = {}
	match state:
		"walk": _up_walk(dt)
		"helmet": _up_helmet(dt)
		"mount": _up_mount(dt)
		"start": _up_start(dt)
		"ride": _up_ride(dt)
		"parking": _up_parking(dt)
		"ending": _up_ending(dt)
		"end", "parked": v = 0.0
	_dip = lerpf(_dip, clampf((_last_v - v) / maxf(dt, 0.001) / 90.0, -1, 1.4), minf(1, dt * 8))
	_last_v = v
	_narrate(dt)
	_camera(dt)
	_stops(dt)
	_particles(dt)
	_birds(dt)
	Sfx.ride(engine, absf(v) / MAX_V if input_dir > 0 or absf(v) > 4 else 0.0, state in ["parked", "end"])
	for l in [back_l, glow1_l, near_l, glow2_l, front_l, glow3_l, fore_l]: l.queue_redraw()

func _camera(dt: float) -> void:
	var tc: float
	if state in ["walk", "helmet", "mount", "start"]: tc = (P.x if state == "walk" else x) - 130
	elif state in ["parking", "parked"]: tc = x - 112
	elif state in ["ending", "end"]: tc = x - 120
	else: tc = x - 112 + clampf(v, -30, 130) * 0.2
	cam = lerpf(cam, clampf(tc, 0, world_len - 320), minf(1, dt * 4.0))

func _up_walk(dt: float) -> void:
	if not _said.has("intro") and st > 0.8: say("intro", G.t("rideIntro"))
	P.update(dt, input_dir, run, 30, VESPA_X + 70, Sfx.step_snow, locked)
	if absf(P.x - 112) < 24:
		prompt = {"x": 112 - cam, "y": 108.0, "label": G.t("go")["bottles"], "action": visit.emit.bind("bottles")}
	if absf(P.x - (x - 4)) < 34:
		prompt = {"x": x - cam, "y": 108.0, "label": G.t("rideHelmet"), "action": take_helmet}

func take_helmet() -> void:
	if state != "walk": return
	narr = {}
	P.target = -1.0
	_set_state("helmet")

## Cammina fino alla sella, prende il casco e se lo mette.
func _up_helmet(dt: float) -> void:
	var tx := x - 38
	if absf(P.x - tx) >= 2.0:       # (Player si ferma a 2 px dal bersaglio)
		P.target = tx
		P.update(dt, 0, false, 30, VESPA_X + 70, Sfx.step_snow)
		st = 0.0
		return
	P.dir = 1
	P.moving = false
	P.animate(dt, false, Sfx.step_snow)
	if st > 0.95 and not _helmet_on:
		_helmet_on = true
		Sfx.play("helmet", 0.8)
		_burst(P.x, 128, 6, 14)
	if st > 1.75: _set_state("mount")

func _up_mount(_d: float) -> void:
	if st > 0.12 and _snow_on:
		_snow_on = false
		for k in 26: _puff(x - 30 + randf() * 56, 140 + randf() * 14, randf_range(-14, 14), randf_range(-26, 4), 0.95, Color("f0f5ff"), 60.0)
		Sfx.step_snow()
	if st > MOUNT_HOP + MOUNT_SIT:
		sit_bump = 0.14
		_set_state("start")
		pose = "stop"

func _up_start(d: float) -> void:
	sit_bump = maxf(0, sit_bump - d)
	# due pedalate a vuoto, alla terza parte
	var times := [0.45, 1.35, 2.25]
	pose = "stop"
	for i in 3:
		if st > times[i] and st < times[i] + 0.26: pose = "kick"
		if st > times[i] and _kick_n == i:
			_kick_n += 1
			Sfx.play("vespa_kick" if i < 2 else "vespa_start", 0.8, randf_range(0.97, 1.03))
			if i < 2:
				for k in 3: _puff(x - 37, 178, randf_range(-14, -6), randf_range(-8, -2), 0.5, Color(0.8, 0.82, 0.9), -4)
			else:
				for k in 12: _puff(x - 37, 178, randf_range(-34, -8), randf_range(-14, -1), 0.7, Color(0.8, 0.82, 0.9), -5)
	if st > 2.55 and not engine:
		engine = true
		_flicker = 0.55
	if st > 3.4:
		_set_state("ride")
		if not G.ride_found:
			G.ride_found = true
			G.save_prefs()
		say("go", G.t("rideGo"))

func _up_ride(dt: float) -> void:
	var d := 0 if locked else input_dir
	if d != 0:
		target_x = -1.0; target_stop = -1
	elif target_x >= 0:
		var gap := target_x - x
		if gap > 6 + v * v / 260.0: d = 1
		elif gap < -8: d = -1
		else:
			if target_stop >= 0:
				var i := target_stop
				target_x = -1; target_stop = -1
				stop_at(i)
				return
			target_x = -1
	var top := (TURBO_V if run else MAX_V) * (1.24 if Shop.up("up_marmitta") else 1.0)
	_brake = false
	if d > 0:
		v += (72.0 if v < 60 else 46.0) * (1.5 if Shop.up("up_gomme") else 1.0) * dt * (1.35 if run else 1.0)
		if v > top: v = maxf(top, v - 60 * dt)
	elif d < 0:
		if v > 2:
			if v > 55 and not _brake and fmod(time, 0.5) < dt: Sfx.play("brake_snow", 0.4, randf_range(0.9, 1.1), "Steps")
			_brake = true
			v = maxf(0, v - (290 if Shop.up("up_gomme") else 165) * dt)
		else:
			v = maxf(-24, v - 40 * dt)      # indietro si spinge coi piedi
	else:
		v = move_toward(v, 0, (30.0 if v > 0 else 60.0) * dt)
	_advance(dt)
	if x >= end_x and v > 0:
		v = maxf(0, v - 240 * dt)
	if x > end_x + 16: x = end_x + 16; v = 0
	pose = "ride1" if int(dist / 9.0) % 7 == 3 else "ride0"
	if absf(v) < 3 or v < 0:
		pose = "stop"
		_idle_t += dt
		if _idle_t > 4.0 and fmod(_idle_t, 9.0) > 4.0 and fmod(_idle_t, 9.0) < 7.5: pose = "sea"   # se si ferma, ogni tanto guarda il mare
	else: _idle_t = 0.0
	if _horn_t > 0: pose = "horn" if absf(v) > 3 else pose
	# capitoli
	for i in chapters.size():
		var ch: Dictionary = chapters[i]
		if x > ch.x0 - 60 and x < ch.x1 and cur_chapter < i:
			cur_chapter = i
			chapter.emit(i)
			say("ch_" + str(ch.id), G.t("rideStory").get(ch.id, [G.L(ch.sec, "intro")]), 1.7)
	_ride_quote(dt)
	# belvedere
	if x > end_x - 70:
		prompt = {"x": end_x + 46 - cam, "y": 112.0, "label": G.t("rideDawn"), "action": look_dawn}
		return
	var n := near_stop()
	if n >= 0:
		prompt = {"x": x - cam - 28, "y": 104.0, "label": G.t("rideStop"), "action": stop_at.bind(n)}
		return
	for s in spots:
		if absf(float(s[0]) - x - 30) < 70:
			prompt = {"x": float(s[0]) - cam, "y": 100.0, "label": G.t("go")[s[1]], "action": _visit.bind(s[1])}

## Quando la strada è libera e la voce tace, torna in mente una frase di un fisico.
func _ride_quote(dt: float) -> void:
	if not narr.is_empty() or v < 24 or x > end_x - 420:
		_quiet = 0.0
		return
	_quiet += dt
	if _quiet < 2.8: return
	for ch in chapters:
		if float(ch.x0) > x and float(ch.x0) - x < 480: return     # sta per cominciare un capitolo
	_quiet = 0.0
	_quotes_n += 1
	say("quote_%d" % _quotes_n, [Quotes.line(Quotes.next(true))], 0.1)

func near_stop() -> int:
	var best := -1
	for i in stops.size():
		var s: Dictionary = stops[i]
		if s.state == "hidden": continue
		var dx: float = float(s.x) - x
		if dx > -34 and dx < 104 and (best < 0 or absf(dx - 40) < absf(float(stops[best].x) - x - 40)): best = i
	return best

func _advance(dt: float) -> void:
	var nx := clampf(x + v * dt, VESPA_X - 30, end_x + 20)
	dist += absf(nx - x)
	if is_equal_approx(nx, x) and absf(v) > 0 and v < 0: v = 0
	x = nx

func stop_at(i: int) -> void:
	if state != "ride": return
	park_i = i
	target_x = -1; target_stop = -1
	if v > 50: Sfx.play("brake_snow", 0.5, randf_range(0.9, 1.1), "Steps")
	_set_state("parking")

## Frena dolcemente e si accosta con la tappa davanti al faro.
func _up_parking(dt: float) -> void:
	var tx: float = float(stops[park_i].x) - 46 if park_i >= 0 else end_x
	var gap := tx - x
	_brake = v > 4
	var want := signf(gap) * minf(maxf(absf(v), 46.0), sqrt(2 * 95.0 * absf(gap)))
	if gap < 0 and v > 0: want = maxf(0, v - 260 * dt)
	elif gap < 0: want = maxf(want, -40)
	v = move_toward(v, want, 260 * dt)
	_advance(dt)
	pose = "ride0" if v > 12 else "stop"
	if absf(gap) < 1.2 or st > 5.0:
		v = 0; pose = "stop"
		_set_state("parked")
		if park_i >= 0:
			var s: Dictionary = stops[park_i]
			s.seen = true
			G.ride_seen[str(s.it.id)] = true
			Shop.earn("stop:%d" % int(s.it.id))
			G.save_prefs()
			open_stop.emit(park_i)
		else:
			_set_state("ending")

func resume() -> void:
	if state == "end":             # finestra finale chiusa: si può ancora girare sul lungomare
		Sfx.play("vespa_start", 0.7)
		engine = true
		_flicker = 0.5
	if state == "parked" or state == "end":
		_set_state("ride")
		pose = "stop"

func _visit(id: String) -> void:
	v = 0.0
	narr = {}
	visit.emit(id)

func look_dawn() -> void:
	if state != "ride": return
	park_i = -1
	_set_state("parking")

func _up_ending(_d: float) -> void:
	v = 0
	pose = "stop" if st < 0.9 else "sea"
	if st > 0.5 and engine:
		engine = false
		Sfx.play("vespa_stop", 0.6)
	if st > 1.4 and not _end_lines:
		_end_lines = true
		say("end", G.t("rideEnd"))
	if _end_lines and st > 2.0 and narr.is_empty():
		_set_state("end")
		finished.emit()

## Da capo: si torna alla scalinata.
func restart() -> void:
	enter()

func horn() -> void:
	if not (riding() and state in ["ride", "parking"]) or _horn_t > 0: return
	_horn_t = 0.45
	Sfx.play("horn", 0.6, randf_range(0.98, 1.02))
	if Shop.up("up_clacson"):
		for k in 34: _puff(x + 18 + randf_range(-4, 4), 140, randf_range(-70, 90), randf_range(-95, -20), 1.5, Color.from_hsv(randf(), 0.7, 1.0), 95.0)
	for g in _gulls:
		if g.st == "sit" and absf(g.x - x) < 260: _fly(g)

func tap(p: Vector2) -> void:
	var wx := p.x + cam
	match state:
		"walk":
			if absf(wx - x) < 34 and p.y > 100:
				P.target = x - 38
				P.on_arrive = take_helmet
			else:
				P.target = clampf(wx, 34, VESPA_X + 66)
		"ride":
			for i in stops.size():
				if stops[i].state != "hidden" and absf(float(stops[i].x) - wx) < 26 and p.y > 92 and p.y < 168:
					target_stop = i
					target_x = float(stops[i].x) - 46
					return
			if absf(wx - x) < 30 and p.y > 106: horn()
			else:
				target_x = clampf(wx, VESPA_X, end_x)
				target_stop = -1

func _stops(dt: float) -> void:
	for s in stops:
		match s.state:
			"hidden":
				if riding() and float(s.x) - x < 178 and float(s.x) - cam > -60 and float(s.x) - cam < 330:
					s.state = "rise"; s.t = 0.0
					Sfx.play("stop_pop", 0.5, randf_range(0.94, 1.08))
					for k in 16: _puff(float(s.x) + randf_range(-18, 18), 160, randf_range(-26, 26), randf_range(-44, -10), 0.95, Color("f0f5ff"), 90.0)
			"rise":
				s.t += dt * 1.9
				if s.t >= 1.0:
					s.t = 1.0
					s.state = "up"

func _puff(px: float, py: float, vx: float, vy: float, a: float, col: Color, grav := 0.0) -> void:
	if _puffs.size() < 160: _puffs.append({"x": px, "y": py, "vx": vx, "vy": vy, "a": a, "c": col, "g": grav, "r": 0.8})

func _burst(px: float, py: float, n: int, sp: float) -> void:
	for k in n: _puff(px + randf_range(-6, 6), py, randf_range(-sp, sp), randf_range(-sp, 0), 0.9, Color("f0f5ff"), 70.0)

func _particles(dt: float) -> void:
	if engine and randf() < dt * (5.0 + absf(v) * 0.05 + (10.0 if input_dir > 0 else 0.0)):
		_puff(x - 37, 178, -10 - v * 0.15 + randf_range(-5, 2), randf_range(-9, -3), 0.42, Color(0.82, 0.84, 0.93), -3)
	if v > 40 and randf() < dt * v * 0.35:              # la neve alzata dalla ruota dietro
		_puff(x - 24, 181, -randf_range(10, 40), -randf_range(8, 30), 0.85, Color("e6edfc"), 110.0)
	if Shop.up("up_scia") and v > 55 and randf() < dt * v * 0.4:
		_puff(x - 26, randf_range(140, 176), -v * 0.35 + randf_range(-8, 8), randf_range(-10, 6), 1.3, Color.from_hsv(randf_range(0.08, 0.18) if randf() < 0.7 else 0.55, 0.4, 1.0), 6.0)
	if _brake and v > 30 and randf() < dt * 40: _puff(x + 22, 181, randf_range(10, 50), -randf_range(4, 18), 0.8, Color("e6edfc"), 110.0)
	_breath -= dt
	if _breath <= 0:
		_breath = randf_range(2.2, 3.4)
		var h := Vector2(P.x + 9, 134)
		if state in ["start", "ride", "parked", "ending", "end", "parking"]: h = Vector2(x + 0, 128)
		if absf(v) < 40:
			for k in 4: _puff(h.x + k, h.y, randf_range(5, 10), randf_range(-5, -2), 0.5, Color(0.94, 0.96, 1), -2)
	for p in _puffs:
		p.x += p.vx * dt; p.y += p.vy * dt; p.vy += p.g * dt
		p.a -= dt * (0.5 if p.g <= 0 else 1.1)
		p.r += dt * (1.6 if p.g <= 0 else 0.0)
	_puffs = _puffs.filter(func(p): return p.a > 0 and p.y < 190)
	# stelle cadenti, finché è notte
	if _shoot.t >= 0:
		_shoot.t += dt
		if _shoot.t > 0.7: _shoot.t = -1.0
	else:
		_shoot_wait -= dt
		if _shoot_wait <= 0:
			_shoot_wait = randf_range(0.1, 0.8) if Shop.up("up_comete") else randf_range(6, 13)
			if progress() < 0.6: _shoot = {"t": 0.0, "x": randf_range(30, 250), "y": randf_range(16, 40)}

func _fly(g: Dictionary) -> void:
	g.st = "fly"
	g.dir = 1 if randf() < 0.75 else -1
	g.vx = g.dir * randf_range(50, 95)
	g.vy = -randf_range(22, 44)
	if randf() < 0.6: Sfx.play("gull", randf_range(0.18, 0.35), randf_range(0.9, 1.12), "Ambience")

func _birds(dt: float) -> void:
	for g in _gulls:
		g.t += dt
		if g.st == "sit":
			if riding() and absf(g.x - x) < 64 and v > 30: _fly(g)
		else:
			g.x += (g.vx + v * 0.35) * dt; g.y += g.vy * dt; g.vy = lerpf(g.vy, -5, dt)
	_gulls = _gulls.filter(func(g): return g.st == "sit" or g.y > -14)

# ================================================================== disegno
func _ph() -> float:
	# 0 notte, 1 ora blu, 2 cintura di Venere, 3 alba
	return 2.35 * pow(progress(), 1.1)     # ci si ferma con la fascia rosa ancora sopra l'ombra della Terra

func _night() -> float:
	return clampf(1.0 - (_ph() - 1.0) / 1.4, 0, 1)

func _mod() -> Color:
	var p := _ph()
	if p < 1: return Color(0.86, 0.88, 1.0).lerp(Color(0.88, 0.92, 1.0), p)
	if p < 2: return Color(0.88, 0.92, 1.0).lerp(Color(1.0, 0.94, 0.98), p - 1)
	return Color(1.0, 0.94, 0.98).lerp(Color(1.0, 0.96, 0.94), p - 2)

func _far_col() -> Color:
	var p := _ph()
	var c: Array = [Color("1b1c46"), Color("33437c"), Color("6f74ae"), Color("a08db4")]
	var i := clampi(int(p), 0, 2)
	return (c[i] as Color).lerp(c[i + 1], p - i)

func _spr(ci: CanvasItem, n: String, left: float, top: float, mod := Color.WHITE) -> void:
	var r: Array = _rects[n]
	ci.draw_texture_rect_region(G.tex.sea_props, Rect2(roundf(left), roundf(top), r[2], r[3]), Rect2(r[0], r[1], r[2], r[3]), mod)

func _draw_back(ci: CanvasItem) -> void:
	var p := _ph()
	var i := clampi(int(p), 0, 2)
	var sh: int = _J.sky_h
	var hz: int = _J.horizon
	ci.draw_texture_rect_region(G.tex.sea_sky, Rect2(0, 0, 320, sh), Rect2(0, i * sh, 320, sh))
	if p - i > 0.004: ci.draw_texture_rect_region(G.tex.sea_sky, Rect2(0, 0, 320, sh), Rect2(0, (i + 1) * sh, 320, sh), Color(1, 1, 1, p - i))
	if Shop.up("up_aurora"): _draw_aurora(ci, clampf(1.0 - (p - 0.8) / 1.4, 0, 1))
	# stelle (Orione tramonta a ovest)
	var na := clampf(1.0 - (p - 0.6) / 1.5, 0, 1)
	if na > 0.02:
		for s in _stars:
			var sx := fposmod(s[0] - cam * 0.006, 340) - 10
			ci.draw_rect(Rect2(roundf(sx), roundf(s[1]), 1, 1), Color(0.95, 0.95, 1, na * s[3] * (0.65 + 0.35 * sin(time * 1.6 + s[2]))))
		for o in ORION:
			var ox := roundf(44 + o[0] * 1.25 - cam * 0.004); var oy := roundf(26 + o[1] * 1.25 + progress() * 40)
			if oy > hz - 2: continue
			var b := 0.7 + 0.3 * sin(time * 2 + o[0])
			var oc := Color(1, 0.78, 0.6) if o[0] == 0 and o[1] == 0 else Color(0.8, 0.9, 1)
			ci.draw_rect(Rect2(ox, oy, 1, 1), Color(oc, na * b if o[2] > 0 else na * 0.4))
			if o[2] == 2:
				for q in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]: ci.draw_rect(Rect2(Vector2(ox, oy) + q, Vector2.ONE), Color(oc, na * 0.35 * b))
		if _shoot.t >= 0:
			var k: float = _shoot.t / 0.7
			var hd := Vector2(_shoot.x + k * 62, _shoot.y + k * 24)
			for j in 14: ci.draw_rect(Rect2(roundf(hd.x - j * 1.6), roundf(hd.y - j * 0.62), 1, 1), Color(1, 1, 0.95, na * (1 - j / 14.0) * sin(k * PI)))
	# luna che scende sul mare
	var mp := _moon_pos()
	var mc := Color(1, 1, 1).lerp(Color(1, 0.86, 0.72), clampf(progress() * 1.1, 0, 1))
	mc.a = 1.0 - 0.25 * clampf(p - 2, 0, 1)
	var vis := clampf(hz - (mp.y - 13), 0, 27)
	if vis > 0: ci.draw_texture_rect_region(_moon, Rect2(roundf(mp.x) - 13, roundf(mp.y) - 13, 27, vis), Rect2(0, 0, 27, vis), mc)
	# isole all'orizzonte: Elba, Capraia, Gorgona
	var fc := _far_col()
	for isl in [["island2", 8.0, 0.0], ["island1", 196.0, 0.0], ["island0", 372.0, 0.0]]:
		var ix: float = isl[1] - cam * 0.028
		var r: Array = _rects[isl[0]]
		if ix > -float(r[2]) and ix < 320: _spr(ci, isl[0], ix, hz + 1 - float(r[3]), fc)
	# Pisa, lontano a nord
	var pp := clampf((progress() - 0.74) / 0.24, 0, 1)
	if pp > 0: _spr(ci, "pisa", 322 - smoothstep(0.0, 1.0, pp) * 128, hz - 46 + 3, Color(1, 1, 1).lerp(fc, 0.35))
	# traghetto e vele
	var fx := fposmod(time * 2.2 + 60 - cam * 0.03, 460) - 60
	_spr(ci, "ferry", fx, hz - 11, Color.WHITE.lerp(fc, 0.25 + 0.3 * _night()))
	if p > 1.2: _spr(ci, "sail", fposmod(250 - time * 1.3 - cam * 0.05, 420) - 40, hz - 10 + sin(time) * 0.6, Color(1, 1, 1, clampf(p - 1.2, 0, 1)))
	# riflesso della luna e luccichii
	var ga := clampf(1.0 - (p - 1.6) / 1.6, 0.18, 1)
	for y in range(hz + 1, 130):
		var dd := y - hz
		var hw := 3.0 + dd * 0.42 + 2.0 * sin(time * 1.7 + dd * 0.9)
		for k in 2:
			var ox := sin(time * (1.1 + k * 0.7) + dd * 1.9 + k * 2.1) * hw * 0.7
			var ln := maxf(1, hw * (0.5 + 0.5 * sin(time * 2.3 + dd * 2.7 + k)))
			ci.draw_rect(Rect2(roundf(mp.x + ox - ln / 2), y, roundf(ln), 1), Color(1, 0.93, 0.78, ga * 0.5 * (1 - dd / 52.0)))
	for g in _glints:
		var a := sin(time * g[3] + g[2])
		if a > 0.25: ci.draw_rect(Rect2(roundf(fposmod(g[0] - cam * 0.12, 324) - 2), roundf(g[1]), 1 + int((g[1] - hz) / 12), 1), Color(0.9, 0.94, 1, (a - 0.25) * 0.5))
	# faro e barche stanno nell'acqua, prima della spiaggia
	for q in _props: if q.layer == "mid" and (q.n == "lighthouse" or q.bob): _draw_prop(ci, q)
	# onde che salgono sulla neve
	var m := _mod()
	for k in 3:
		var tt := fposmod(time * 0.19 + k / 3.0, 1.0)
		var wy := 116.0 + 9.0 * sin(tt * PI * 0.62)
		var wa := sin(tt * PI) * 0.75
		for wx in range(0, 320, 2):
			var u := wx + cam * 0.5
			var yy := wy + 1.6 * sin(u * 0.045 + k * 2) + 1.0 * sin(u * 0.13 + time + k)
			if sin(u * 0.21 + k * 4) > -0.75: ci.draw_rect(Rect2(wx, roundf(yy), 2, 1), Color(0.94, 0.97, 1, wa))
	var bx := -fposmod(roundf(cam * 0.6), 480)
	while bx < 320:
		ci.draw_texture(G.tex.sea_beach, Vector2(bx, 118), m)
		bx += 480
	for q in _props: if q.layer == "mid" and not (q.n == "lighthouse" or q.bob): _draw_prop(ci, q)
	_snow(ci, false)

func _moon_pos() -> Vector2:
	return Vector2(lerpf(236, 112, progress()), lerpf(47, 87, pow(progress(), 1.3)))

func _prop_sx(q: Dictionary) -> float:
	if q.par == 1.0: return float(q.x) - roundf(cam)
	return (float(q.x) - float(q.ref)) + 160 + (float(q.ref) - cam - 160) * float(q.par)

func _draw_prop(ci: CanvasItem, q: Dictionary) -> void:
	var r: Array = _rects[q.n]
	var sx := _prop_sx(q) - float(r[2]) / 2
	if sx > 324 or sx + float(r[2]) < -4: return
	var by: float = q.base
	if q.bob: by += sin(time * 1.3 + float(q.x) * 0.1) * 1.4
	_spr(ci, q.n, sx, by - float(r[3]), _mod())

func _draw_glow_back(ci: CanvasItem) -> void:
	var mp := _moon_pos()
	Layer.glow(ci, mp, 40, Color(1, 0.88, 0.68, 0.16 + 0.10 * _night()))
	for q in _props:
		if q.n == "lighthouse":
			var sx := _prop_sx(q) - 4
			if sx < -320 or sx > 640: continue
			var ly := float(q.base) - 108 + 14
			var a := time * 0.9
			var dx := cos(a)
			var k := 0.35 + 0.65 * _night()
			var far := Vector2(sx + dx * 300, ly)
			var c0 := Color(1, 0.94, 0.72, 0.42 * k * absf(dx))
			ci.draw_polygon(PackedVector2Array([Vector2(sx, ly - 1), far + Vector2(0, -20 * absf(dx)), far + Vector2(0, 14 * absf(dx)), Vector2(sx, ly + 1)]), PackedColorArray([c0, Color(c0, 0), Color(c0, 0), c0]))
			Layer.glow(ci, Vector2(sx, ly), 16 + 26 * pow(maxf(0, sin(a)), 14), Color(1, 0.93, 0.7, (0.5 + 0.5 * pow(maxf(0, sin(a)), 14)) * k))
		elif str(q.n).begins_with("hut") and int(float(q.x)) % 2 == 0:
			var hx := _prop_sx(q)
			if hx > -20 and hx < 340: Layer.glow(ci, Vector2(hx, float(q.base) - 20), 14, Color(1, 0.75, 0.4, 0.18 * _night()))

func _draw_near(ci: CanvasItem) -> void:
	var m := _mod()
	var c := roundf(cam)
	var nx := -fposmod(c, 640)
	while nx < 320:
		ci.draw_texture(G.tex.sea_near, Vector2(nx, 0), m)
		nx += 640
	# gatto sul muretto, uno ogni tanto
	for k in range(int(c / 1480) , int(c / 1480) + 2):
		var cx := k * 1480 + 962 - c
		if cx > -30 and cx < 330:
			var fr := 2 if fmod(time, 4.3) < 0.14 else (0 if sin(time * 1.4) > 0 else 1)
			_spr(ci, "cat%d" % fr, cx, 108, m)
	for g in _gulls:
		var gx: float = g.x - c
		if gx < -20 or gx > 340: continue
		var n := "gull0"
		if g.st == "fly": n = "gull1" if int(g.t * 9) % 2 == 0 else "gull2"
		var r: Array = _rects[n]
		var gy: float = g.y + (0.0 if g.st == "fly" or fmod(g.t, 3.1) > 0.3 else 1.0)
		if g.dir < 0: ci.draw_texture_rect_region(G.tex.sea_props, Rect2(roundf(gx) + r[2], roundf(gy), -float(r[2]), r[3]), Rect2(r[0], r[1], r[2], r[3]), m)
		else: _spr(ci, n, gx, gy, m)
	# festone di lucine fra un lampione e l'altro
	var L0 := int(floor(c / SLOT))
	for k in range(L0, L0 + 3):
		var a := k * SLOT - c
		if k * SLOT < 190: continue
		var prev := Vector2(a, 78)
		for j in range(1, 21):
			var t := j / 20.0
			var q := Vector2(a + t * SLOT, 78 + 15 * (1 - pow(t * 2 - 1, 2)))
			ci.draw_line(prev, q, Color(0.1, 0.1, 0.18, 0.8), 1)
			prev = q
			if j < 20: ci.draw_rect(Rect2(roundf(q.x), roundf(q.y) + 1, 1, 2), (LIGHTS[(j + k) % 4] as Color) if sin(time * 2.2 + j * 1.7 + k) > -0.55 else Color("6a5a58"))
	for k in range(L0 - 1, L0 + 3):
		if k * SLOT < 190: continue
		_spr(ci, "lamp", k * SLOT - c - 11, 163 - 108, m)
	for q in _props: if q.layer == "near": _draw_prop(ci, q)
	for s in stops: _draw_stop(ci, s, c, m)

func _draw_stop(ci: CanvasItem, s: Dictionary, c: float, m: Color) -> void:
	if s.state == "hidden": return
	var n: String = "stop_" + str(s.kind)
	var r: Array = _rects[n]
	var sx := roundf(float(s.x) - c - float(r[2]) / 2)
	if sx > 324 or sx + float(r[2]) < -4: return
	var k := 1.0
	if s.state == "rise":
		var t: float = s.t - 1.0                        # rimbalzo in uscita
		k = 1.0 + 2.4 * t * t * t + 1.4 * t * t
	var h := float(r[3])
	var vis := clampf(roundf(h * k), 0, h)
	var top := 163 - roundf(h * k)
	ci.draw_texture_rect_region(G.tex.sea_props, Rect2(sx, top, r[2], vis), Rect2(r[0], r[1], r[2], vis), m)
	# emblema sullo schermo, sulla lavagna, nella finestra…
	var e: Array = _J.stops[s.kind]
	var ey := top + float(e[1])
	var eh := clampf(163 - ey, 0, 16)
	if eh > 0:
		var src := Rect2(maxi(0, (_J.emblems as Array).find(s.emblem)) * 16, 0, 16, eh)
		var col := Color(0.9, 1, 0.94) if s.kind == "lavagna" else Color.WHITE
		if s.kind == "scrivania" and sin(time * 23 + float(s.x)) > 0.97: col = Color(0.7, 0.9, 1)
		ci.draw_texture_rect_region(G.tex.sea_emblems, Rect2(sx + float(e[0]), ey, 16, eh), src, col)
		if s.kind == "scrivania":
			for yy in range(0, int(eh), 2): ci.draw_rect(Rect2(sx + float(e[0]) - 2, ey + yy, 20, 1), Color(0, 0, 0, 0.16))
			ci.draw_rect(Rect2(sx + float(e[0]) - 2, ey + fmod(time * 9, 16), 20, 1), Color(0.6, 0.9, 1, 0.2))
		elif s.kind == "libreria" or s.kind == "letto":
			ci.draw_rect(Rect2(sx + float(e[0]) + 8, ey - 1, 1, eh), Color(0.4, 0.25, 0.15, 0.25))
	# mucchietto di neve ai piedi e lampadina: oro se è da vedere, verde se già vista
	for j in 5: ci.draw_rect(Rect2(sx + 2 + j * 8, 162 - (j % 2), 9, 3), Color(0.94, 0.96, 1) * m)
	if s.state == "up":
		var on: bool = s.seen or sin(time * 4 + float(s.x)) > -0.3
		var bc := G.C_SAGE if s.seen else G.gold
		ci.draw_rect(Rect2(sx + float(r[2]) / 2 - 1, top - 4, 3, 3), bc if on else Color("5a4a40"))
		ci.draw_rect(Rect2(sx + float(r[2]) / 2, top - 1, 1, 2), Color("3a3048"))

func _draw_glow_near(ci: CanvasItem) -> void:
	var c := roundf(cam)
	var k := 0.15 + 0.85 * _night()
	var L0 := int(floor(c / SLOT))
	for j in range(L0 - 1, L0 + 3):
		if j * SLOT < 190: continue
		var lx := j * SLOT - c
		var fl := 0.2 + 0.02 * sin(time * 2 + j)
		Layer.glow(ci, Vector2(lx, 69), 26, Color(1, 0.82, 0.55, fl * k))
		ci.draw_set_transform(Vector2(lx, 168), 0, Vector2(1, 0.24))
		Layer.glow(ci, Vector2.ZERO, 46, Color(1, 0.8, 0.5, 0.34 * k))
		ci.draw_set_transform(Vector2.ZERO)
		for q in range(1, 20, 2):
			var t := q / 20.0
			Layer.glow(ci, Vector2(lx + t * SLOT, 80 + 15 * (1 - pow(t * 2 - 1, 2))), 5, Color(LIGHTS[(q + j) % 4], 0.2 * k))
	for s in stops:
		if s.state != "up": continue
		var sx := float(s.x) - c
		if sx < -50 or sx > 370: continue
		var gc: Color = {"scrivania": Color(0.45, 0.75, 1), "lavagna": Color(0.6, 1, 0.8), "finestra": Color(0.7, 0.75, 1)}.get(s.kind, Color(1, 0.78, 0.45))
		Layer.glow(ci, Vector2(sx, 132), 30, Color(gc, (0.07 if s.seen else 0.12 + 0.04 * sin(time * 3)) * (0.4 + 0.6 * k)))
	for q in _props:
		if q.n == "kiosk":
			var kx := _prop_sx(q)
			if kx > -80 and kx < 400: Layer.glow(ci, Vector2(kx, 126), 52, Color(1, 0.78, 0.45, 0.28 * k))

func _draw_front(ci: CanvasItem) -> void:
	var c := roundf(cam)
	var vx := roundf(x - c)
	# solco delle ruote sulla neve
	var t0 := maxf(-4, VESPA_X - 23 - c)
	var t1 := vx - 23
	if t1 > t0:
		ci.draw_rect(Rect2(t0, 181, t1 - t0, 1), Color(0.33, 0.36, 0.54, 0.75))
		var dx := posmod(int(c), 3)
		var tx := t0
		while tx < t1:
			ci.draw_rect(Rect2(tx - (dx if tx > 0 else 0), 182, 1, 1), Color(0.8, 0.85, 0.96, 0.5))
			tx += 3
	for k in 3:                                      # bottiglie arenate sulla neve
		var br: Array = G.J.places.rects.bottle
		ci.draw_texture_rect_region(G.tex.place_props, Rect2(roundf(100 + k * 13 - c), 170 + (k % 2) * 5, br[2], br[3]), Rect2(br[0], br[1], br[2], br[3]))
	if state in ["walk", "helmet"]:
		_draw_vespa(ci, vx, "")
		P.draw(ci, P.x - c, 178.0)
		if state == "helmet": _draw_helmet_anim(ci, c)
	elif state == "mount":
		# un saltello, gamba oltre la sella, e giù a sedere
		var k := clampf(st / MOUNT_HOP, 0, 1)
		if k < 1:
			var hx := lerpf(P.x, x - 18, k)
			var fy := 178.0 - 15 * sin(k * PI * 0.5) - 5 * sin(k * PI)
			P.draw(ci, hx - c, fy, Color(0, 0, 0, 0))
			_spr(ci, "helmet", hx - c - 18 + 8, fy - 58 + 1)
			_draw_vespa(ci, vx, "")
		else:
			var q := clampf((st - MOUNT_HOP) / MOUNT_SIT, 0, 1)
			_draw_vespa(ci, vx, "kick" if q < 0.6 else "stop", roundf(lerpf(-5, 0, q * q)))
	else:
		_draw_vespa(ci, vx, pose)
	for p in _puffs:
		var px: float = p.x - c
		if p.g > 0: ci.draw_rect(Rect2(roundf(px), roundf(p.y), 1 if p.a < 0.5 else 2, 1 if p.a < 0.5 else 2), Color(p.c, clampf(p.a, 0, 1)))
		elif p.r < 1.2: ci.draw_rect(Rect2(roundf(px), roundf(p.y), 1, 1), Color(p.c, maxf(0, p.a)))
		else: ci.draw_circle(Vector2(roundf(px), roundf(p.y)), p.r, Color(p.c, maxf(0, p.a * 0.7)))
	_snow(ci, true)

func _draw_helmet_anim(ci: CanvasItem, c: float) -> void:
	var seat: Array = _J.vespa.seat
	var a := Vector2(x - c - 38 + float(seat[0]), 133 + float(seat[1]))
	var bob := 1.5 if P.frame in [1, 2] else 0.0
	var b := Vector2(P.x - c - 18 + 8, 178 - 58 + 1 + bob)
	var k := smoothstep(0.25, 0.95, st)
	var q := a.lerp(b, k)
	q.y -= sin(k * PI) * 20
	if st > 0.95: q.y = b.y + (-2.0 if st < 1.05 else 0.0)
	_spr(ci, "helmet", q.x, q.y)

## `lift`: di quanto l'omino è ancora sollevato dalla sella (mentre sale).
func _draw_vespa(ci: CanvasItem, vx: float, rider: String, lift := 0.0) -> void:
	var J: Dictionary = _J.vespa
	var left := vx - 38
	var top := 133.0
	var bob := 0.0
	if engine:
		if absf(v) < 4: bob = 1.0 if int(time * 22) % 4 == 0 else 0.0
		else: bob = 1.0 if sin(dist * 0.22) > 0.72 else 0.0
	# ombra
	for k in range(-34, 35):
		var hh := 2.2 * sqrt(maxf(0.0, 1.0 - pow(k / 34.0, 2)))
		ci.draw_rect(Rect2(vx + k, 182 - roundf(hh * 0.4), 1, maxf(1, roundf(hh))), Color(0.08, 0.09, 0.24, 0.4))
	if sit_bump > 0: bob += 1.0                           # le sospensioni cedono quando si siede
	if rider != "":
		var bl := 1.0 if clampf(roundf(_dip), -1, 1) > 0 else 0.0
		_spr(ci, "rider_back_" + rider, left + bl, top + float(J.rider_dy) + bob + lift)
	_spr(ci, "vespa_back", left, top + bob)
	var fr := int(dist / 3.4) % 4
	var rear: Array = J.rear
	var fro: Array = J.front
	_spr(ci, "wheel%d" % fr, left + float(rear[0]) - 9, top + float(rear[1]) - 9)
	_spr(ci, "wheel%d" % fr, left + float(fro[0]) - 9, top + float(fro[1]) - 9)
	Shop.draw_cargo(ci, left, top + bob)
	var dip := clampf(roundf(_dip), -1, 1)                # in frenata il muso si abbassa
	_spr(ci, "vespa", left, top + bob)
	if state in ["walk", "helmet", "mount"]:
		_spr(ci, "stand", left + 30, top + 38)
	if _snow_on: _spr(ci, "vespa_snow", left, top)
	if rider == "":
		if state == "walk": _spr(ci, "helmet", left + float(J.seat[0]), top + float(J.seat[1]))
		return
	var rt := top + float(J.rider_dy) + bob + lift
	var R: Dictionary = _J.riders[rider]
	var lean := 1.0 if dip > 0 else 0.0
	var sc := Shop.scarf_cols()
	# la sciarpa che vola: più si corre più si tende
	var sp := clampf(v / MAX_V, 0, 1.2)
	var nk := Vector2(left + float(R.neck[0]) + 2 + lean, rt + float(R.neck[1]) + 1)
	for k in 11:
		var t := k / 10.0
		var px := nk.x - k * lerpf(1.0, 2.1, sp)
		var py := nk.y + k * lerpf(1.7, 0.12, sp) + sin(time * lerpf(2.5, 15, sp) - k * 0.75) * (0.4 + 2.3 * sp) * t
		ci.draw_rect(Rect2(roundf(px) - 1, roundf(py) - 1, 4, 5), Color("18121e"))
	for k in 11:
		var t := k / 10.0
		var px := nk.x - k * lerpf(1.0, 2.1, sp)
		var py := nk.y + k * lerpf(1.7, 0.12, sp) + sin(time * lerpf(2.5, 15, sp) - k * 0.75) * (0.4 + 2.3 * sp) * t
		ci.draw_rect(Rect2(roundf(px), roundf(py), 2, 3), sc[2] if k in [4, 5, 8] else sc[0])
		ci.draw_rect(Rect2(roundf(px), roundf(py) + 2, 2, 1), sc[1])
	_spr(ci, "rider_" + rider, left + lean, rt)
	_spr(ci, "helmet_back" if rider == "sea" else "helmet", left + float(R.head[0]) + lean, rt + float(R.head[1]))
	if _brake: ci.draw_rect(Rect2(left + float(J.tail[0]), top + float(J.tail[1]) - 1 + bob, 3, 4), Color(1, 0.35, 0.3))

func _draw_glow_front(ci: CanvasItem) -> void:
	if not engine: return
	var J: Dictionary = _J.vespa
	var left := roundf(x - roundf(cam)) - 38
	var lp := Vector2(left + float(J.lamp[0]), 133 + float(J.lamp[1]))
	var k := (0.35 + 0.65 * _night())
	if _flicker > 0: k *= 0.15 if int(_flicker * 22) % 2 == 0 else 1.0
	k *= 0.94 + 0.06 * sin(time * 31)
	if state in ["parked", "ending"]: k *= 0.55
	var fw := 1.45 if Shop.up("up_faro") else 1.0
	var c0 := Color(1, 0.92, 0.66, 0.23 * k * fw)
	ci.draw_polygon(PackedVector2Array([lp + Vector2(0, -2), lp + Vector2(150, -16) * fw, lp + Vector2(165, 44) * fw, lp + Vector2(0, 3)]), PackedColorArray([c0, Color(c0, 0), Color(c0, 0), c0]))
	Layer.glow(ci, lp, 13, Color(1, 0.94, 0.74, 0.75 * k))
	ci.draw_set_transform(Vector2(lp.x + 76, 182), 0, Vector2(1, 0.15))
	Layer.glow(ci, Vector2.ZERO, 72, Color(1, 0.9, 0.62, 0.26 * k))
	ci.draw_set_transform(Vector2.ZERO)
	Layer.glow(ci, Vector2(left + float(J.tail[0]) + 1, 133 + float(J.tail[1])), 14 if _brake else 8, Color(1, 0.2, 0.15, 0.8 if _brake else 0.4))

## Tende di luce verde e viola (potenziamento del negozio).
func _draw_aurora(ci: CanvasItem, a: float) -> void:
	if a <= 0.02: return
	for b in 2:
		for sx in range(0, 320, 2):
			var u := (sx + cam * 0.01) * 0.02
			var y0 := 18.0 + b * 14 + sin(u * 1.3 + time * 0.22 + b * 2.0) * 9 + sin(u * 3.1 - time * 0.31) * 4
			var h := 26.0 + sin(u * 2.2 + time * 0.5 + b) * 12
			var k := (0.5 + 0.5 * sin(u * 4.0 + time * 0.8 + b * 1.7)) * a
			for j in 5:
				ci.draw_rect(Rect2(sx, y0 + h * j / 5.0, 2, h / 5.0 + 1), Color(Color("5cf0a8").lerp(Color("a060f0"), (4 - j) / 4.0 if b == 0 else j / 5.0), 0.17 * k * (0.35 + 0.65 * sin((j + 0.5) / 5.0 * PI))))

func _draw_fore(ci: CanvasItem) -> void:
	var fx := -fposmod(roundf(cam * 1.22), 512)
	while fx < 320:
		ci.draw_texture(G.tex.sea_fore, Vector2(fx, 168), _mod())
		fx += 512
	last_cam = roundf(cam)

func _snow(ci: CanvasItem, front: bool) -> void:
	var dx := roundf(cam) - last_cam
	var n := int(_flakes.size() * lerpf(1.0, 0.35, clampf(_ph() / 3.0, 0, 1)))
	for i in n:
		var f: Dictionary = _flakes[i]
		if (f.z > 1) != front: continue
		f.y += f.vy * _dt
		f.x += (sin(f.y / 14 + f.ph) * 6 - 6) * _dt * f.z - dx * f.z * (1.0 if front else 0.5)
		if f.y > 200:
			f.y = -4; f.x = randf_range(0, 320)
		f.x = fposmod(f.x + 4, 328) - 4
		if front: ci.draw_rect(Rect2(roundf(f.x), roundf(f.y), 2 + int(clampf(v / 70.0, 0, 2)), 2), Shop.flake(true))
		else: ci.draw_rect(Rect2(roundf(f.x), roundf(f.y), 1, 1), Shop.flake(false))
