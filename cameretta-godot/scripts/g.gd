extends Node
## Stato globale: testi, lingue, dati dal server, impostazioni salvate, utilità.

signal data_ready
signal lang_changed
signal settings_changed

const GROUPS := ["letto", "scrivania", "lavagna", "libreria", "finestra"]
const W := 320
const H := 200

# palette (uguale alla versione web)
const C_NIGHT := Color("0f0f26")
const C_INK := Color("1a1733")
const C_PANEL := Color("221d3d")
const C_PANEL2 := Color("2b2550")
const C_LINE := Color("4a3f78")
const C_CREAM := Color("f6e9c8")
const C_TERRA := Color("d97a4b")
const C_SAGE := Color("a3bb8c")
const C_SKY := Color("8fb2ee")
const C_MUTED := Color("c9c3e6")
const C_DIM := Color("8a84b0")
const C_CHALK := Color("2f5d48")
var gold := Color("f2b85b")

const T := {
	"en": {
		"tips": ["Tip: use [k]←[/k] [k]→[/k] to walk, hold [k]SHIFT[/k] to run.", "Tip: press [k]E[/k] near a door to go inside.", "Tip: in my room, click the objects to open them.", "Tip: the lit window on the menu takes you straight in."],
		"loading": "LOADING", "start": "START", "room": "GO STRAIGHT TO MY ROOM", "settings": "SETTINGS", "help": "HOW TO PLAY",
		"language": "Language", "langName": "English", "audio": "Audio", "on": "ON", "off": "OFF",
		"music": "Music", "effects": "Effects", "roomMode": "My room", "walk": "WALK", "point": "POINT & CLICK",
		"modeWalk": "WALK MODE", "modePoint": "POINT & CLICK MODE", "modeHint": "change it any time in Settings",
		"chooseTitle": "How do you want to explore my room?",
		"chooseWalk": "Walk around with the little guy and press [k]E[/k] near the objects.",
		"choosePoint": "The classic way: point at the objects and click them.",
		"street": "the street", "living": "the living room",
		"hintWalk": "[k]←[/k][k]→[/k] walk · [k]SHIFT[/k] run · [k]E[/k] interact · [k]ESC[/k] menu",
		"hintRoom": "click an object · [k]←[/k][k]→[/k] choose · [k]ENTER[/k] open · [k]ESC[/k] back",
		"hintRoomWalk": "[k]←[/k][k]→[/k] walk · [k]E[/k] open · click an object to walk there · [k]ESC[/k] back",
		"enterHouse": "Go inside", "tv": "Change channel", "fire": "Warm your hands", "door": "Enter my room", "warm": "Ahh, much better.", "open": "Open",
		"back": "◀ Living room", "skip": "Skip ▸", "menu": "Menu", "explored": "OBJECTS EXPLORED", "sheet": "What do you want to explore?", "close": "CLOSE",
		"empty": "Nothing here yet. Come back soon.", "find": "Where to find me", "cv": "Open my CV", "openLink": "open ↗", "details": "details ↗", "physics": "physics",
		"titles": {"street": "A SNOWY NIGHT", "living": "HOME, SWEET HOME", "room": "MY LITTLE ROOM"},
		"helpTitle": "How to play",
		"helpItems": ["Walk down the snowy street with [k]←[/k] [k]→[/k] (or [k]A[/k] [k]D[/k]). Hold [k]SHIFT[/k] to run. On a phone, use the arrows or tap where you want to go.", "Read the bubbles along the way: they tell you who I am.", "At the house, and near the TV, the fireplace and the glowing door, press [k]E[/k] (or the yellow button).", "In my room every object opens a part of my portfolio. You can walk around or point and click: the current mode is always shown at the top, and you can switch it in Settings.", "[k]ESC[/k] goes back."],
		"noServer": "Offline copy: start the server to load fresh content",
	},
	"it": {
		"tips": ["Suggerimento: [k]←[/k] [k]→[/k] per camminare, tieni premuto [k]SHIFT[/k] per correre.", "Suggerimento: premi [k]E[/k] vicino a una porta per entrare.", "Suggerimento: in cameretta clicca gli oggetti per aprirli.", "Suggerimento: nel menu, la finestra accesa ti porta subito dentro."],
		"loading": "CARICAMENTO", "start": "INIZIA", "room": "VAI SUBITO IN CAMERETTA", "settings": "IMPOSTAZIONI", "help": "COME SI GIOCA",
		"language": "Lingua", "langName": "Italiano", "audio": "Audio", "on": "ON", "off": "OFF",
		"music": "Musica", "effects": "Effetti", "roomMode": "Cameretta", "walk": "CAMMINA", "point": "PUNTA E CLICCA",
		"modeWalk": "MODALITÀ CAMMINA", "modePoint": "MODALITÀ PUNTA E CLICCA", "modeHint": "puoi cambiarla quando vuoi nelle Impostazioni",
		"chooseTitle": "Come vuoi esplorare la mia cameretta?",
		"chooseWalk": "Muoviti con l'omino e premi [k]E[/k] vicino agli oggetti.",
		"choosePoint": "Il modo classico: punta gli oggetti e cliccali.",
		"street": "la strada", "living": "il salotto",
		"hintWalk": "[k]←[/k][k]→[/k] cammina · [k]SHIFT[/k] corri · [k]E[/k] interagisci · [k]ESC[/k] menu",
		"hintRoom": "clicca un oggetto · [k]←[/k][k]→[/k] scegli · [k]INVIO[/k] apri · [k]ESC[/k] indietro",
		"hintRoomWalk": "[k]←[/k][k]→[/k] cammina · [k]E[/k] apri · clicca un oggetto per andarci · [k]ESC[/k] indietro",
		"enterHouse": "Entra in casa", "tv": "Cambia canale", "fire": "Scaldati le mani", "door": "Entra in cameretta", "warm": "Ahh, molto meglio.", "open": "Apri",
		"back": "◀ Salotto", "skip": "Salta ▸", "menu": "Menu", "explored": "OGGETTI ESPLORATI", "sheet": "Cosa vuoi esplorare?", "close": "CHIUDI",
		"empty": "Qui non c'è ancora niente. Torna presto.", "find": "Dove trovarmi", "cv": "Apri il CV", "openLink": "apri ↗", "details": "scheda ↗", "physics": "fisica",
		"titles": {"street": "UNA NOTTE DI NEVE", "living": "CASA, DOLCE CASA", "room": "LA MIA CAMERETTA"},
		"helpTitle": "Come si gioca",
		"helpItems": ["Percorri la strada innevata con [k]←[/k] [k]→[/k] (o [k]A[/k] [k]D[/k]). Tieni [k]SHIFT[/k] per correre. Da telefono usa le frecce o tocca dove vuoi andare.", "Leggi le bolle lungo la strada: ti raccontano chi sono.", "Davanti a casa, e vicino a TV, camino e porta luminosa, premi [k]E[/k] (o il pulsante giallo).", "In cameretta ogni oggetto apre una parte del portfolio. Puoi camminare o puntare e cliccare: la modalità attuale è sempre indicata in alto e la cambi nelle Impostazioni.", "[k]ESC[/k] torna indietro."],
		"noServer": "Copia offline: avvia il server per caricare i contenuti aggiornati",
	},
}

var lang := "en"
var S: Dictionary = {}            # impostazioni dal server
var sections: Array = []
var by_id: Dictionary = {}
var bubbles: Array = []
var offline := false
var base_url := ""

# file del gioco (pixel art di base, sostituibili da admin)
var tex: Dictionary = {}          # room, mask, far, mid, near, living, player, menu_custom
var J: Dictionary = {}            # anim, menu, street, living, player
var default_room := true
var custom_sky := false

# preferenze del visitatore
var prefs := ConfigFile.new()
const PREFS := "user://cameretta.cfg"
var explored: Dictionary = {}
var audio_on := true
var room_mode := ""               # "walk" | "point" | "" (non ancora scelta)
var music_user := 1.0
var effects_user := 1.0
var tv_channel := 0

var is_web := false
var touch := false

func _ready() -> void:
	is_web = OS.has_feature("web")
	touch = DisplayServer.is_touchscreen_available()
	prefs.load(PREFS)
	for g in prefs.get_value("p", "explored", []): explored[g] = true
	room_mode = prefs.get_value("p", "room_mode", "")
	if touch: room_mode = "point"   # su telefono e tablet solo punta e clicca
	music_user = prefs.get_value("p", "music_user", 1.0)
	effects_user = prefs.get_value("p", "effects_user", 1.0)
	tv_channel = prefs.get_value("p", "tv", 0)
	if is_web:
		base_url = str(JavaScriptBridge.eval("location.origin", true))
	else:
		base_url = OS.get_environment("CAMERETTA_URL")
		if base_url == "": base_url = "http://127.0.0.1:8000"

func save_prefs() -> void:
	prefs.set_value("p", "explored", explored.keys())
	prefs.set_value("p", "room_mode", room_mode)
	prefs.set_value("p", "music_user", music_user)
	prefs.set_value("p", "effects_user", effects_user)
	prefs.set_value("p", "tv", tv_channel)
	prefs.set_value("p", "audio", audio_on)
	prefs.set_value("p", "lang", lang)
	prefs.save(PREFS)

# ------------------------------------------------------------------ testi
func t(k: String):
	return T.get(lang, T.en).get(k, T.en.get(k, k))

## Campo bilingue: in inglese usa *_en se presente.
func L(o, k: String) -> String:
	if o == null: return ""
	if lang == "en" and str(o.get(k + "_en", "")) != "": return str(o[k + "_en"])
	return str(o.get(k, ""))

func set_lang(l: String) -> void:
	lang = "it" if l == "it" else "en"
	save_prefs()
	lang_changed.emit()

func set_room_mode(m: String) -> void:
	room_mode = "point" if touch else m
	save_prefs()
	settings_changed.emit()

## Trasforma [k]X[/k] in un tasto disegnato (BBCode).
func kbd(s: String) -> String:
	return s.replace("[k]", "[bgcolor=#f6e9c8][color=#1a1733] ").replace("[/k]", " [/color][/bgcolor]")

func esc_bb(s: String) -> String:
	return s.replace("[", "[lb]")

func safe_url(u: String) -> bool:
	var l := u.strip_edges().to_lower()
	return l.begins_with("http://") or l.begins_with("https://") or l.begins_with("/") or l.begins_with("mailto:")

func abs_url(u: String) -> String:
	if u.begins_with("/"): return base_url + u
	return u

func open_url(u: String) -> void:
	if not safe_url(u): return
	Sfx.select()
	var full := abs_url(u)
	if is_web:
		JavaScriptBridge.eval("window.open(%s,'_blank','noopener')" % JSON.stringify(full))
	else:
		OS.shell_open(full)

func set_hash(h: String) -> void:
	if is_web:
		JavaScriptBridge.eval("try{history.replaceState(null,'',%s)}catch(e){}" % JSON.stringify(("#" + h) if h != "" else location_path()))

func location_path() -> String:
	return str(JavaScriptBridge.eval("location.pathname", true)) if is_web else "/"

func get_hash() -> String:
	if not is_web: return ""
	return str(JavaScriptBridge.eval("location.hash", true)).trim_prefix("#")

func mark_explored(id: String) -> void:
	explored[id] = true
	save_prefs()

# ------------------------------------------------------------------ caricamento
var _pending := 0
var progress := 0.0
var _total := 1

func load_all() -> void:
	_total = 14
	_pending = 0
	progress = 0.0
	# dati di base inclusi nel gioco
	for k in ["anim", "menu", "street", "living", "player"]:
		var f := {"anim": "anim", "menu": "menu_anim", "street": "street", "living": "living", "player": "player"}[k] as String
		J[k] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/%s.json" % f))
	for k in ["room", "mask", "far", "mid", "near", "living", "player", "menu_sky"]:
		var f := {"room": "room", "mask": "mask", "far": "street_far", "mid": "street_mid", "near": "street_near", "living": "living", "player": "player", "menu_sky": "menu_sky"}[k] as String
		tex[k] = load("res://assets/img/%s.png" % f)
	_step(6)
	var d = await fetch_json("/api/public")
	if typeof(d) != TYPE_DICTIONARY:
		offline = true
		d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/data.json"))
	_step(2)
	S = d.get("settings", {})
	sections = d.get("sections", [])
	bubbles = d.get("bubbles", [])
	by_id.clear()
	for s in sections: by_id[s.id] = s
	var saved_lang = prefs.get_value("p", "lang", "")
	lang = saved_lang if saved_lang != "" else ("it" if str(S.get("default_lang", "en")) == "it" else "en")
	audio_on = prefs.get_value("p", "audio", str(S.get("audio_default", "1")) != "0")
	var ac := str(S.get("accent_color", ""))
	if ac.begins_with("#") and Color.html_is_valid(ac): gold = Color.html(ac)
	# immagini sostituibili dall'admin
	default_room = not safe_url(str(S.get("room_image", "")))
	if not default_room:
		var img = await fetch_texture(str(S.room_image), true)
		if img: tex.room = img
		else: default_room = true
	_step(2)
	if safe_url(str(S.get("room_mask", ""))):
		var m = await fetch_texture(str(S.room_mask), true)
		if m: tex.mask = m
	_step(1)
	custom_sky = safe_url(str(S.get("menu_background", "")))
	if custom_sky:
		var sky = await fetch_texture(str(S.menu_background), false)
		if sky: tex.menu_custom = sky
		else: custom_sky = false
	_step(3)
	data_ready.emit()

func _step(n: int) -> void:
	_pending += n
	progress = clampf(float(_pending) / _total, 0, 1)

func _request(path: String) -> Array:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	# Sul web il browser decomprime già le risposte gzip ma lascia l'header Content-Encoding:
	# se Godot provasse a decomprimere di nuovo fallirebbe (corpo vuoto → copia offline).
	http.accept_gzip = not is_web
	add_child(http)
	var err := http.request(abs_url(path) if path.begins_with("/") else path)
	if err != OK:
		http.queue_free()
		return [-1, PackedByteArray(), PackedStringArray()]
	var res = await http.request_completed
	http.queue_free()
	return [res[1], res[3], res[2]]

func fetch_json(path: String):
	var r := await _request(path)
	if r[0] != 200: return null
	return JSON.parse_string((r[1] as PackedByteArray).get_string_from_utf8())

func fetch_bytes(path: String) -> PackedByteArray:
	var r := await _request(path)
	return r[1] if r[0] == 200 else PackedByteArray()

var _img_cache: Dictionary = {}
## Scarica un'immagine (png/jpg/webp). to_room: la ridimensiona a 320x200 in pixel netti.
func fetch_texture(url: String, to_room := false) -> Texture2D:
	var key := url + ("#r" if to_room else "")
	if _img_cache.has(key): return _img_cache[key]
	var b := await fetch_bytes(url)
	if b.is_empty(): return null
	var img := Image.new()
	var ok := img.load_png_from_buffer(b)
	if ok != OK: ok = img.load_jpg_from_buffer(b)
	if ok != OK: ok = img.load_webp_from_buffer(b)
	if ok != OK: return null
	if to_room and (img.get_width() != W or img.get_height() != H):
		img.resize(W, H, Image.INTERPOLATE_NEAREST)
	var tx := ImageTexture.create_from_image(img)
	_img_cache[key] = tx
	return tx

func fetch_audio(url: String) -> AudioStream:
	var b := await fetch_bytes(url)
	if b.is_empty(): return null
	var l := url.to_lower()
	if l.ends_with(".ogg") or l.ends_with(".oga"):
		return AudioStreamOggVorbis.load_from_buffer(b)
	if l.ends_with(".wav"):
		return AudioStreamWAV.load_from_buffer(b)
	var mp3 := AudioStreamMP3.new()
	mp3.data = b
	return mp3

func fnum(k: String, d: float) -> float:
	var v := str(S.get(k, ""))
	return clampf(v.to_float(), 0, 1) if v.is_valid_float() else d
