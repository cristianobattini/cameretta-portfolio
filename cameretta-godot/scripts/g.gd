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
		"grove": "the temples", "toGrove": "Go to the temples", "pray": {"stelle": "Pray", "magia": "Pray", "dune": "Pray"},
		"temples": {
			"stelle": "STAR WARS, the films. They've kept me company all my life: they made me look up, and wonder what lies beyond.",
			"magia": "HARRY POTTER, the films. They've kept me company all my life: they taught me that wonder is a serious thing, and that friends are home.",
			"dune": "DUNE, the books. They've kept me company all my life: pages as slow as the desert, where I learned patience.",
		},
		"prayers": {
			"stelle": ["Let go of fear. The rest follows.", "Even a horizon with two suns becomes home, if you look at it long enough.", "Those who want everything at once take the dark road. You, breathe.", "In the silence between the stars something holds it all together. Listen.", "The best teacher is the one who lets you get it wrong.", "One light is enough to give the dark an edge.", "You don't have to believe you'll make it. You have to begin.", "Wonder comes before the equation. Don't lose it along the way."],
			"magia": ["The right words light a lamp. Most times it's enough to say them.", "A place that made you happy stays yours even after you get off the train.", "Courage is small, and always cold. Bring it anyway.", "Those who loved us are still our shield.", "Talent doesn't say who you are: the choices you make when nobody is looking do.", "Every library has a forbidden room. It's usually the one you need.", "Even the longest night ends at breakfast with your friends.", "If you find a door where there wasn't one, knock."],
			"dune": ["The desert asks for nothing: it waits.", "Let fear go by like the wind: what remains is you.", "Every drop counts. Every word does too.", "Those who see every road still have to choose one.", "Walk without rhythm, if you don't want to wake what sleeps beneath.", "A book read in silence is an oasis: carry water away from it.", "Don't trust heroes. Read to the end.", "Even a planet can be changed, one seed at a time."],
		},
		"shop": "SHOP", "shopTitle": "The shop", "shopGet": "GET COINS", "shopBack": "◀ Items", "shopOffline": "The till can't be reached right now: you can look and try things on, but not buy.",
		"shopWorn": "IN USE", "shopOwned": "YOURS", "shopBuy": "BUY", "shopWear": "USE", "shopOn": "TURN ON", "shopOff": "TURN OFF", "shopGot": "It's yours: %s.", "shopPoor": "Not enough coins for this one, yet.", "shopErr": "Something went wrong, no coins were taken. Try again.", "shopWait": "One moment…",
		"shopPlayT": "Play", "shopPlay": "Every day you drop by: %d. Each new stop on the Vespa ride: %d. Each object in the room: %d. Dawn at the end of the road: %d. A prayer at each temple, once a day: %d.",
		"shopGiveT": "Buy me a coffee", "shopGive": "1 unit donated = %d coins. Copy your wallet code and paste it in the donation message: the coins land here by themselves, usually within a minute.", "shopSoon": "Coffee donations aren't open yet. In the meantime, coins are earned by playing.",
		"shopCopy": "COPY %s", "shopCopied": "Code copied: paste it in the donation message.", "shopCoffee": "BUY ME A COFFEE ↗", "shopCheck": "CHECK MY COINS", "shopIn": "%d coins have arrived. Thank you!", "shopNotYet": "Nothing yet. It can take a minute.",
		"shopCodeT": "Your wallet", "shopCode": "Your code is [color=#f2b85b]%s[/color]. Keep it: it brings coins and items to any other device. No name, no email.", "shopEnter": "USE A CODE", "shopCodeOk": "Wallet found.", "shopCodeBad": "No wallet with that code.", "coinsIn": "+%d coins",
		"full": "Full screen", "fullOn": "FULL SCREEN", "fullOff": "EXIT FULL SCREEN", "fullHint": "Press [k]F[/k] at any time to go full screen and back.",
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
		"toSea": "Take the path to the sea", "sea": "the seafront", "backStreet": "◀ Street", "rideMenu": "VESPA RIDE",
		"hintSeaWalk": "[k]←[/k][k]→[/k] walk · [k]E[/k] put on the helmet · [k]ESC[/k] menu",
		"hintRide": "[k]→[/k] throttle · [k]←[/k] brake · [k]SHIFT[/k] faster · [k]E[/k] stop and look · [k]H[/k] horn · [k]ESC[/k] menu",
		"rideHelmet": "Put on the helmet", "rideStop": "Stop and look", "rideDawn": "Look at the dawn", "rideStops": "STOPS", "rideStopN": "STOP %d OF %d", "rideGoOn": "Ride on ▶", "rideChapter": "CHAPTER %d",
		"ridePlaces": {"libreria": "Rosignano", "letto": "Castiglioncello", "scrivania": "Quercianella", "lavagna": "Livorno", "finestra": "Marina di Pisa"},
		"rideTitles": {"libreria": "THE BOOKS", "letto": "THE WORDS", "scrivania": "THE THINGS I BUILD", "lavagna": "THE QUESTIONS", "finestra": "THE ROAD"},
		"rideIntro": ["Listen: the sea.", "Someone left a Vespa here, under the snow. The helmet is on the saddle."],
		"rideGo": ["Third kick and she starts. She's always been like that.", "From here to Pisa it's one road, with the sea on the left. Stop whenever something catches your eye."],
		"rideStory": {
			"libreria": ["Rosignano. The newsstand is still lit, and every road starts with something you've read.", "These are some of my books."],
			"letto": ["Castiglioncello. The beach huts are closed for the winter, but somebody left a light on.", "They're the things I write in the evening, when the desk is off."],
			"scrivania": ["Quercianella. In the little harbour they mend boats even at night.", "I do the same with code: I write it, I break it, I put it back on its feet."],
			"lavagna": ["Livorno. The lighthouse flashes, and that flash is an electromagnetic wave.", "At some point making things work isn't enough: you want to know why they work."],
			"finestra": ["Marina di Pisa. The moon is setting on the sea, and the sun is rising behind us.", "This is the road so far, and the one ahead."],
		},
		"rideEnd": ["See that pink band over the sea? It's called the Belt of Venus. The blue strip beneath it is the shadow of the Earth.", "It's a whole planet's shadow, and it's sinking below the horizon while you watch.", "Thanks for the ride. Now home: it's warm inside."],
		"rideEndTitle": "The road goes on", "rideEndSeen": "You stopped %d times out of %d.", "rideEndAll": "You saw every stop. Really, all of them. Thank you.", "rideEndSome": "The others will be there, under the snow, whenever you feel like another ride.", "rideHome": "Go home ▶", "rideAgain": "Ride again",
		"back": "◀ Living room", "skip": "Skip ▸", "menu": "Menu", "explored": "OBJECTS EXPLORED", "sheet": "What do you want to explore?", "close": "CLOSE",
		"empty": "Nothing here yet. Come back soon.", "find": "Where to find me", "cv": "Open my CV", "openLink": "open ↗", "details": "details ↗", "physics": "physics",
		"titles": {"grove": "THE TEMPLES", "sea": "BY THE SEA", "street": "A SNOWY NIGHT", "living": "HOME, SWEET HOME", "room": "MY LITTLE ROOM"},
		"helpTitle": "How to play",
		"helpItems": ["Walk down the snowy street with [k]←[/k] [k]→[/k] (or [k]A[/k] [k]D[/k]). Hold [k]SHIFT[/k] to run. On a phone, use the arrows or tap where you want to go.", "Read the bubbles along the way: they tell you who I am.", "Halfway down the street a lit path goes down to the sea. There's a Vespa: put on the helmet and ride, [k]→[/k] throttle, [k]←[/k] brake, [k]E[/k] to stop and look, [k]H[/k] for the horn.", "At the house, and near the TV, the fireplace and the glowing door, press [k]E[/k] (or the yellow button).", "In my room every object opens a part of my portfolio. You can walk around or point and click: the current mode is always shown at the top, and you can switch it in Settings.", "Another path, lit in violet, enters the woods: three temples where you can sit and pray with [k]E[/k].", "Playing earns coins to spend in the shop (the coin at the top): themes, clothes, Vespa, furniture.", "Press [k]F[/k] for full screen.", "[k]ESC[/k] goes back."],
		"noServer": "Offline copy: start the server to load fresh content",
	},
	"it": {
		"tips": ["Suggerimento: [k]←[/k] [k]→[/k] per camminare, tieni premuto [k]SHIFT[/k] per correre.", "Suggerimento: premi [k]E[/k] vicino a una porta per entrare.", "Suggerimento: in cameretta clicca gli oggetti per aprirli.", "Suggerimento: nel menu, la finestra accesa ti porta subito dentro."],
		"loading": "CARICAMENTO", "start": "INIZIA", "room": "VAI SUBITO IN CAMERETTA", "settings": "IMPOSTAZIONI", "help": "COME SI GIOCA",
		"language": "Lingua", "langName": "Italiano", "audio": "Audio", "on": "ON", "off": "OFF",
		"grove": "i templi", "toGrove": "Vai ai templi", "pray": {"stelle": "Prega", "magia": "Prega", "dune": "Prega"},
		"temples": {
			"stelle": "STAR WARS, i film. Mi hanno accompagnato nella vita: mi hanno fatto alzare gli occhi al cielo, e chiedermi cosa c'è oltre.",
			"magia": "HARRY POTTER, i film. Mi hanno accompagnato nella vita: mi hanno insegnato che la meraviglia è una cosa seria, e che gli amici sono casa.",
			"dune": "DUNE, i libri. Mi hanno accompagnato nella vita: pagine lente come il deserto, dove ho imparato la pazienza.",
		},
		"prayers": {
			"stelle": ["Lascia andare la paura. Il resto viene da sé.", "Anche un orizzonte con due soli, a guardarlo abbastanza, diventa casa.", "Chi vuole tutto subito prende la strada buia. Tu respira.", "Nel silenzio tra una stella e l'altra qualcosa tiene insieme tutto. Ascoltalo.", "Il maestro migliore è quello che ti lascia sbagliare.", "Una luce accesa basta a dare un bordo al buio.", "Non serve credere di farcela. Serve cominciare.", "Prima dell'equazione viene la meraviglia. Non perderla per strada."],
			"magia": ["Le parole giuste accendono una luce. Quasi sempre basta dirle.", "Un posto che ti ha fatto felice resta tuo anche quando scendi dal treno.", "Il coraggio è piccolo, e ha sempre freddo. Portalo lo stesso.", "Chi ci ha voluto bene ci fa ancora da scudo.", "Non è il talento a dire chi sei: sono le scelte che fai quando nessuno guarda.", "Ogni biblioteca ha una stanza proibita. Di solito è quella che ti serve.", "Anche la notte più lunga finisce davanti a una colazione con gli amici.", "Se trovi una porta dove non c'era, bussa."],
			"dune": ["Il deserto non chiede niente: aspetta.", "Lascia passare la paura come il vento: quello che resta sei tu.", "Ogni goccia conta. Anche ogni parola.", "Chi vede tutte le strade deve comunque sceglierne una.", "Cammina senza ritmo, se non vuoi svegliare ciò che dorme sotto.", "Un libro letto in silenzio è un'oasi: portane via dell'acqua.", "Non fidarti degli eroi. Leggi fino in fondo.", "Anche un pianeta si può cambiare, un seme alla volta."],
		},
		"shop": "NEGOZIO", "shopTitle": "Il negozio", "shopGet": "OTTIENI MONETE", "shopBack": "◀ Articoli", "shopOffline": "La cassa ora non risponde: puoi guardare e provare, ma non comprare.",
		"shopWorn": "IN USO", "shopOwned": "TUO", "shopBuy": "COMPRA", "shopWear": "USA", "shopOn": "ACCENDI", "shopOff": "SPEGNI", "shopGot": "È tuo: %s.", "shopPoor": "Per questo non bastano ancora le monete.", "shopErr": "Qualcosa è andato storto, nessuna moneta spesa. Riprova.", "shopWait": "Un attimo…",
		"shopPlayT": "Giocando", "shopPlay": "Ogni giorno che passi di qui: %d. Ogni nuova tappa in Vespa: %d. Ogni oggetto della cameretta: %d. L'alba in fondo alla strada: %d. Una preghiera a ogni tempio, una volta al giorno: %d.",
		"shopGiveT": "Offrendo un caffè", "shopGive": "Ogni unità donata vale %d monete. Copia il codice del portafoglio e incollalo nel messaggio della donazione: le monete arrivano qui da sole, di solito entro un minuto.", "shopSoon": "Le donazioni non sono ancora aperte. Intanto le monete si guadagnano giocando.",
		"shopCopy": "COPIA %s", "shopCopied": "Codice copiato: incollalo nel messaggio della donazione.", "shopCoffee": "OFFRIMI UN CAFFÈ ↗", "shopCheck": "CONTROLLA LE MONETE", "shopIn": "Sono arrivate %d monete. Grazie!", "shopNotYet": "Ancora niente. Può volerci un minuto.",
		"shopCodeT": "Il tuo portafoglio", "shopCode": "Il tuo codice è [color=#f2b85b]%s[/color]. Conservalo: porta monete e acquisti su qualunque altro dispositivo. Nessun nome, nessuna email.", "shopEnter": "USA UN CODICE", "shopCodeOk": "Portafoglio trovato.", "shopCodeBad": "Nessun portafoglio con questo codice.", "coinsIn": "+%d monete",
		"full": "Schermo intero", "fullOn": "SCHERMO INTERO", "fullOff": "ESCI DA SCHERMO INTERO", "fullHint": "Premi [k]F[/k] in qualsiasi momento per lo schermo intero, e di nuovo per uscire.",
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
		"toSea": "Prendi il sentiero per il mare", "sea": "il lungomare", "backStreet": "◀ Strada", "rideMenu": "GIRO IN VESPA",
		"hintSeaWalk": "[k]←[/k][k]→[/k] cammina · [k]E[/k] mettiti il casco · [k]ESC[/k] menu",
		"hintRide": "[k]→[/k] gas · [k]←[/k] freno · [k]SHIFT[/k] più veloce · [k]E[/k] fermati · [k]H[/k] clacson · [k]ESC[/k] menu",
		"rideHelmet": "Mettiti il casco", "rideStop": "Fermati a guardare", "rideDawn": "Guarda l'alba", "rideStops": "TAPPE", "rideStopN": "TAPPA %d DI %d", "rideGoOn": "Riparti ▶", "rideChapter": "CAPITOLO %d",
		"ridePlaces": {"libreria": "Rosignano", "letto": "Castiglioncello", "scrivania": "Quercianella", "lavagna": "Livorno", "finestra": "Marina di Pisa"},
		"rideTitles": {"libreria": "I LIBRI", "letto": "LE PAROLE", "scrivania": "LE COSE COSTRUITE", "lavagna": "LE DOMANDE", "finestra": "LA STRADA"},
		"rideIntro": ["Senti? Il mare.", "Qualcuno ha lasciato una Vespa, qui sotto la neve. Il casco è sulla sella."],
		"rideGo": ["Alla terza pedalata parte. Ha sempre fatto così.", "Da qui a Pisa è una strada sola, col mare a sinistra. Fermati quando qualcosa ti incuriosisce."],
		"rideStory": {
			"libreria": ["Rosignano. L'edicola è ancora accesa, e ogni strada comincia da qualcosa che hai letto.", "Questi sono alcuni dei miei libri."],
			"letto": ["Castiglioncello. Le cabine sono chiuse per l'inverno, ma qualcuno ha lasciato la luce accesa.", "Sono le cose che scrivo la sera, quando la scrivania è spenta."],
			"scrivania": ["Quercianella. Al porticciolo si aggiustano le barche anche di notte.", "Io faccio lo stesso col codice: lo scrivo, lo rompo, lo rimetto in piedi."],
			"lavagna": ["Livorno. Il faro manda un lampo, e quel lampo è un'onda elettromagnetica.", "A un certo punto far funzionare le cose non basta più: vuoi sapere perché funzionano."],
			"finestra": ["Marina di Pisa. La luna tramonta sul mare, e il sole sta sorgendo alle nostre spalle.", "Questa è la strada fatta finora, e quella che ho davanti."],
		},
		"rideEnd": ["La vedi quella fascia rosa sul mare? Si chiama cintura di Venere. La striscia blu lì sotto è l'ombra della Terra.", "È l'ombra di un pianeta intero, e sta scendendo sotto l'orizzonte mentre la guardi.", "Grazie per il passaggio. Adesso a casa: dentro fa caldo."],
		"rideEndTitle": "La strada continua", "rideEndSeen": "Tappe viste: %d su %d.", "rideEndAll": "Le hai viste tutte. Davvero tutte. Grazie.", "rideEndSome": "Le altre restano lì, sotto la neve, per quando avrai voglia di un altro giro.", "rideHome": "Torna a casa ▶", "rideAgain": "Rifai il giro",
		"back": "◀ Salotto", "skip": "Salta ▸", "menu": "Menu", "explored": "OGGETTI ESPLORATI", "sheet": "Cosa vuoi esplorare?", "close": "CHIUDI",
		"empty": "Qui non c'è ancora niente. Torna presto.", "find": "Dove trovarmi", "cv": "Apri il CV", "openLink": "apri ↗", "details": "scheda ↗", "physics": "fisica",
		"titles": {"grove": "I TEMPLI", "sea": "IL LUNGOMARE", "street": "UNA NOTTE DI NEVE", "living": "CASA, DOLCE CASA", "room": "LA MIA CAMERETTA"},
		"helpTitle": "Come si gioca",
		"helpItems": ["Percorri la strada innevata con [k]←[/k] [k]→[/k] (o [k]A[/k] [k]D[/k]). Tieni [k]SHIFT[/k] per correre. Da telefono usa le frecce o tocca dove vuoi andare.", "Leggi le bolle lungo la strada: ti raccontano chi sono.", "A metà strada un sentiero illuminato scende al mare. C'è una Vespa: metti il casco e parti, [k]→[/k] gas, [k]←[/k] freno, [k]E[/k] per fermarti a guardare, [k]H[/k] per il clacson.", "Davanti a casa, e vicino a TV, camino e porta luminosa, premi [k]E[/k] (o il pulsante giallo).", "In cameretta ogni oggetto apre una parte del portfolio. Puoi camminare o puntare e cliccare: la modalità attuale è sempre indicata in alto e la cambi nelle Impostazioni.", "Un altro sentiero, illuminato di viola, entra nel bosco: ci sono tre templi dove sedersi a pregare con [k]E[/k].", "Giocando si guadagnano monete da spendere nel negozio (la moneta in alto): temi, vestiti, Vespa, arredi.", "Premi [k]F[/k] per lo schermo intero.", "[k]ESC[/k] torna indietro."],
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
var ride_seen: Dictionary = {}     # tappe del giro in Vespa già viste (id delle voci)
var prayers: Dictionary = {}       # preghiere fatte in ogni tempio
var ride_found := false            # il giro è stato scoperto: compare nel menu

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
	for k in prefs.get_value("p", "ride_seen", []): ride_seen[k] = true
	ride_found = prefs.get_value("p", "ride_found", false)
	prayers = prefs.get_value("p", "prayers", {})
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
	prefs.set_value("p", "ride_seen", ride_seen.keys())
	prefs.set_value("p", "ride_found", ride_found)
	prefs.set_value("p", "prayers", prayers)
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

## Schermo intero: su iPhone il browser non lo concede ai giochi, quindi lì il pulsante non c'è.
var _can_full := -1
func can_fullscreen() -> bool:
	if _can_full < 0:
		_can_full = 1
		if is_web: _can_full = 1 if JavaScriptBridge.eval("!!(document.fullscreenEnabled||document.webkitFullscreenEnabled)", true) else 0
	return _can_full == 1

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

func toggle_fullscreen() -> void:
	if not can_fullscreen(): return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)

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
	for k in ["anim", "menu", "street", "living", "player", "sea"]:
		var f := {"anim": "anim", "menu": "menu_anim", "street": "street", "living": "living", "player": "player", "sea": "sea"}[k] as String
		J[k] = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/%s.json" % f))
	J.grove = JSON.parse_string(FileAccess.get_file_as_string("res://store/grove.json"))
	for k in ["room", "mask", "far", "mid", "near", "living", "player", "menu_sky"]:
		var f := {"room": "room", "mask": "mask", "far": "street_far", "mid": "street_mid", "near": "street_near", "living": "living", "player": "player", "menu_sky": "menu_sky"}[k] as String
		tex[k] = load("res://assets/img/%s.png" % f)
	for k in ["sea_sky", "sea_near", "sea_fore", "sea_beach", "sea_props", "sea_emblems", "shop", "grove_far", "grove_near", "grove_props"]: tex[k] = load("res://assets/img/%s.png" % k)
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
