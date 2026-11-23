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
		"backLab": "◀ Lab", "backSky": "◀ Observatory",
		"labHello": "The lab. Four benches, four questions.",
		"hintField": "click to place · drag to move · [k]E[/k] sign · [k]Q[/k] dipole · [k]V[/k] potential · [k]X[/k] clear · [k]ESC[/k] menu",
		"hintFou": "[k]E[/k] change place · [k]Q[/k] speed · [k]X[/k] restart · [k]ESC[/k] menu",
		"hintAur": "[k]E[/k] launch particles · [k]Q[/k] solar wind energy · [k]ESC[/k] menu",
		"hintPho": "[k]E[/k] one · [k]Q[/k] a hundred · [k]R[/k] a thousand · [k]T[/k] slits · [k]V[/k] detector · [k]X[/k] clear · [k]ESC[/k] menu",
		"hintCof": "[k]E[/k] next star · [k]ESC[/k] menu",
		"fieldHello": "Place charges on the snow: the field lines draw themselves. Tap a charge to remove it.", "fieldFull": "Eight charges are enough: remove one.", "fieldPlus": "PLACING: +", "fieldMinus": "PLACING: −", "fieldDip": "DIPOLE", "fieldPot": "POTENTIAL", "fieldClear": "CLEAR",
		"fouHello": "The pendulum always swings in the same plane: it's the floor that turns beneath it, together with the Earth.", "fouRos": "ROSIGNANO, 43.4° N", "fouPole": "NORTH POLE", "fouPisa": "PISA, 43.7° N", "fouEq": "EQUATOR", "fouSouth": "CAPE TOWN, 33.9° S", "fouSpeed": "TIME × %d", "fouReset": "RESTART", "fouTurn": "turned by %s°", "fouHours": "in %s hours", "fouPeriod": "one turn: %s hours", "fouNever": "here it never turns",
		"aurHello": "Launch the Sun's particles: the Earth's field catches them and leads them to the poles. There the air lights up.", "aurFire": "LAUNCH", "aurEn": ["WEAK WIND", "NORMAL WIND", "SOLAR STORM"], "aurInfo": ["Weak wind: little light, close to the poles.", "Green: oxygen at 557.7 nanometres, between 100 and 150 kilometres.", "Storm: red above, violet below, and the aurora moves down towards us."], "aurLat": "aurora at %d° magnetic latitude",
		"phoHello": "One photon at a time, and each leaves a single dot. Fire, and see what they draw together.", "phoOne": "One slit: a broad patch, no fringes.", "phoTwo": "Two slits: the fringes are back, even though photons go one by one.", "phoSpy": "Now someone is watching which way they go. And the fringes vanish.", "phoNoSpy": "Nobody is watching: the fringes are back.", "phoS1": "ONE SLIT", "phoS2": "TWO SLITS", "phoOn": "DETECTOR ON", "phoOff": "DETECTOR OFF", "phoCount": "%d photons",
		"sky1610": "7 January 1610, Padua. Galileo points his telescope at Jupiter and sees three little stars: two to the east, one to the west. Go forward one day: they'll all be to the west.", "skyNowBack": "TODAY", "skyCoffee": "COFFEES", "skyScope": "TELESCOPE",
		"cofHello": "Every star is a coffee someone bought me. There are %d. Thank you.", "cofNone": "A star lights up here for every coffee. The sky is still waiting.", "cofName": "NAME YOUR STAR", "cofNext": "NEXT ONE", "cofStar": "This one was lit by: %s. Thank you.", "starNone": "Stars are lit with a coffee: copy your donation code from the shop and paste it in the message.", "starAsk": "You lit a star. What should it be called? The name shows once Cristiano has read it.", "starSend": "GIVE IT THE NAME", "starOk": "Done. It will appear once approved.",
		"weather": {"sereno": "clear", "nuvole": "cloudy", "nebbia": "fog", "pioggia": "rain", "neve": "snow", "temporale": "storm"}, "weatherOn": "REAL", "weatherT": "Weather", "ghostsT": "Other visitors",
		"secretFound": "A paper crane: %d of 10", "secretAll": "You found all ten! There's a Vespa for you in the shop.", "shopPrize": "You need all ten paper cranes.", "shopPrizeN": "PRIZE · CRANES %d/10",
		"photoTitle": "Photo", "photoShot": "SHOOT", "photoFilter": "FILTER", "photoNone": "none", "photoExit": "EXIT", "photoSaved": "Postcard saved",
		"radioNames": ["RADIO OFF", "Tirreno Lo-fi 98.4", "Electric Wave 101.7", "Aurelia Bossa", "Radio Physics"],
		"radioNews": ["a second is 9,192,631,770 oscillations of the light of a caesium atom.", "the Moon drifts away from us by almost four centimetres a year. No hard feelings.", "a teaspoon of neutron star holds the mass of a mountain.", "cosmic-ray muons reach the ground only because, for them, time runs slower.", "the sunlight you see now left eight minutes ago.", "a lightning bolt is hotter than the surface of the Sun, but lasts much less.", "the vacuum is never quite empty: the Casimir effect measures it.", "in Cascina, near Pisa, the Virgo detector listens to gravitational waves.", "Enrico Fermi studied in Pisa. They say he explored the city's rooftops too.", "traffic is light on the Aurelia, with some slowing down at the speed of light."],
		"coffeeBtn": "BUY ME A COFFEE", "coffeeTitle": "Buy me a coffee", "coffeeTokens": "Get coins", "coffeeText": "I build all of this one idea at a time, between one exam and the next. If it made you smile, a coffee helps me keep the lights on in the little room. And a star with your name lights up in the sky.", "coffeeFree": "The road is free, and it always will be: no place here asks you to pay.", "nudge": "Enjoying the walk? A coffee keeps the lights on.", "resume": "CONTINUE", "restart": "START AGAIN FROM THE STREET", "visit": "60-SECOND VISIT", "visitHello": "Who I am", "visitEnd": "What now?", "visitPause": "PAUSE", "visitPlay": "RESUME",
		"map": "MAP", "mapTitle": "Where to?", "season": "Season", "seasonAuto": "REAL", "seasons": {"inverno": "WINTER", "primavera": "SPRING", "estate": "SUMMER", "autunno": "AUTUMN"},
		"streetTitles": {"inverno": "A SNOWY NIGHT", "primavera": "A NIGHT OF PETALS", "estate": "A NIGHT OF FIREFLIES", "autunno": "A NIGHT OF LEAVES"},
		"places": {"street": "The street", "room": "My little room", "ride": "The Vespa ride", "grove": "The temples", "sky": "The observatory", "train": "The night train", "arcade": "The arcade", "tower": "The Tower of Pisa", "light": "The Livorno lighthouse", "pier": "The Quercianella pier", "bottles": "Bottles in the sea", "lab": "The physics lab", "field": "Living fields", "foucault": "Foucault pendulum", "aurora": "Aurora on demand", "photon": "Double slit", "coffee": "The coffee sky"},
		"placeInfo": {"street": "Where it all begins.", "room": "My projects, object by object.", "ride": "The seafront, from night to dawn.", "grove": "Star Wars, Harry Potter and Dune.", "sky": "The real sky over Rosignano, tonight.", "train": "My road, one carriage at a time.", "arcade": "One cabinet per project.", "tower": "Which one lands first?", "light": "Waves, lamps and fringes.", "pier": "Fish for something to read.", "bottles": "Leave a message for whoever comes next.", "lab": "Fields, pendulum, aurora, photons.", "coffee": "A star for every coffee."},
		"go": {"lab": "Enter the lab", "train": "Board the train", "sky": "Go up to the observatory", "arcade": "Enter the arcade", "light": "Climb the lighthouse", "pier": "Go fishing", "bottles": "Look at the bottles"},
		"backSea": "◀ Seafront", "towerGo": "To the Tower of Pisa",
		"hintSky": "[k]←[/k][k]→[/k][k]W[/k][k]S[/k] look · [k]E[/k] what is it? · [k]Q[/k][k]R[/k] hours · [k]+[/k][k]−[/k] zoom · [k]L[/k] lines · [k]ESC[/k] menu",
		"hintTower": "[k]E[/k] drop · [k]←[/k][k]→[/k] change object · [k]Q[/k] air or vacuum · [k]ESC[/k] menu",
		"hintLight": "[k]←[/k][k]→[/k] wavelength · [k]W[/k][k]S[/k] distance between lamps · [k]E[/k] one or two · [k]ESC[/k] menu",
		"hintPier": "[k]E[/k] cast, and pull when it bites · [k]ESC[/k] menu",
		"hintPlace": "[k]←[/k][k]→[/k] walk · [k]E[/k] look · [k]ESC[/k] menu",
		"skyHello": "This is the real sky above Rosignano. Look around, and point at whatever makes you curious.", "skyTonight": "Tonight", "skyNow": "NOW", "skyLines": "LINES", "skyNone": "Only darkness here. Almost.",
		"skyDirs": ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"], "skyStar": "A star of magnitude %.1f.", "skyWhere": "It's towards the %s, %d° high.",
		"skyBodies": {"sole": "Sun", "luna": "Moon", "mercurio": "Mercury", "venere": "Venus", "marte": "Mars", "giove": "Jupiter", "saturno": "Saturn"},
		"skyWhat": {"sole": "Our star: its light takes a little over eight minutes.", "luna": "%d%% lit.", "mercurio": "The closest to the Sun: a year lasts 88 days.", "venere": "The brightest after the Moon. A day there is longer than a year.", "marte": "Red with rust: iron oxides.", "giove": "Galileo saw its four moons in January 1610.", "saturno": "Its rings are ice, wide and very thin."},
		"towerHello": "They say Galileo dropped them from up here. Maybe it didn't quite happen, but it's the right question: which one lands first?",
		"towerDrop": "DROP", "towerAir": "WITH AIR", "towerVoid": "IN A VACUUM", "towerObj": {"ball_iron": "iron", "ball_wood": "wood", "ball_cork": "cork", "feather": "feather"},
		"towerTie": "%s seconds for both. Without air, mass doesn't matter: it cancels out of the equation.", "towerWin": "Iron: %s s. The other: %s s. It isn't weight in itself: it's the air, which slows down more whatever is light for its size (%s).",
		"lightHello": "The lighthouse from above. Two lamps beat together: where the waves arrive in phase the light doubles, where they are opposite it goes out.", "lightOne": "One lamp only: no fringes. The light just spreads.", "lightTwo": "Two lamps: there are the fringes. The further apart, the tighter they get.", "lightW": "WAVE", "lightD": "DISTANCE", "lightF": "between fringes", "lightB1": "ONE LAMP", "lightB2": "TWO LAMPS",
		"fishHello": "The pier is frozen and quiet. Cast, wait, and pull when you see the sign.", "fishCast": "CAST", "fishStop": "REEL IN", "fishPull": "PULL!", "fishEarly": "Too early: nobody was there yet.", "fishLost": "It got away. It was thinking too.",
		"fishNames": {"fish0": "A sardine", "fish1": "A red mullet", "fish2": "A sea bream", "fish3": "A purple fish, very rare"},
		"trainRead": "Read", "trainEmpty": "The last carriage is still empty. We'll see.",
		"arcadeHello": "One cabinet per project. Tokens are on the house.", "arcadePlay": "Play",
		"bottleTitle": "Bottles in the sea", "bottleNone": "No bottles yet. The first one could be yours.", "bottleOther": "ANOTHER BOTTLE", "bottleWrite": "Write a message: whoever comes by may find it. Cristiano reads it before it sets off.", "bottleText": "Your message (200 characters at most)", "bottleName": "Your name (if you like)", "bottleSend": "THROW THE BOTTLE", "bottleSent": "The bottle is off. It will surface once it's been read.", "bottleErr": "The sea brought it back. Try again later.", "bottleShort": "Write at least a few words.", "bottleAnon": "no name", "bottleOff": "The sea isn't answering tonight: try again when you're online.",
		"grove": "the temples", "toGrove": "Go to the temples", "templesHello": "Three temples: Star Wars to the left, Harry Potter to the right, and further on, at the end of the path, Dune.", "pray": {"stelle": "Pray", "magia": "Pray", "dune": "Pray"},
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
		"shopPlayT": "Play", "shopPlay": "Every day you drop by: %d. Each new stop on the Vespa ride: %d. Each object in the room: %d. Dawn at the end of the road: %d. A prayer at each temple, once a day: %d. The first catch of the day: %d.",
		"shopGiveT": "Support me on KO-FI", "shopGive": "1 unit donated = %d coins. Copy your donation code (it only receives, so it can be public) and paste it in the message: the coins land here by themselves, usually within a minute.", "shopSoon": "Donations aren't open yet. In the meantime, coins are earned by playing.", "shopThanks": "If you like this place you can buy me a coffee. Coins for donations aren't active yet, so this one would be just a kind thought: thank you.",
		"shopCopy": "COPY %s", "shopCopied": "Code copied: paste it in the donation message.", "shopCoffee": "OPEN KO-FI ↗", "shopCheck": "CHECK MY COINS", "shopIn": "%d coins have arrived. Thank you!", "shopNotYet": "Nothing yet. It can take a minute.",
		"shopCodeT": "Your wallet", "shopCode": "Your code is [color=#f2b85b]%s[/color]. Keep it to yourself, like a password: it brings coins and items to any other device. No name, no email.", "shopEnter": "USE A CODE", "shopCodeOk": "Wallet found.", "shopCodeBad": "No wallet with that code.", "coinsIn": "+%d coins",
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
		"hintRide": "[k]→[/k] throttle · [k]←[/k] brake · [k]SHIFT[/k] faster · [k]E[/k] stop and look · [k]H[/k] horn · [k]R[/k] radio · [k]ESC[/k] menu",
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
		"helpItems": ["Walk down the snowy street with [k]←[/k] [k]→[/k] (or [k]A[/k] [k]D[/k]). Hold [k]SHIFT[/k] to run. On a phone, use the arrows or tap where you want to go.", "Read the bubbles along the way: they tell you who I am.", "Halfway down the street a lit path goes down to the sea. There's a Vespa: put on the helmet and ride, [k]→[/k] throttle, [k]←[/k] brake, [k]E[/k] to stop and look, [k]H[/k] for the horn.", "At the house, and near the TV, the fireplace and the glowing door, press [k]E[/k] (or the yellow button).", "In my room every object opens a part of my portfolio. You can walk around or point and click: the current mode is always shown at the top, and you can switch it in Settings.", "Another path, lit in violet, enters the woods: three temples where you can sit and pray with [k]E[/k].", "Playing earns coins to spend in the shop (the coin at the top): themes, clothes, Vespa, furniture.", "[k]P[/k] takes a photo, [k]G[/k] waves to other visitors (the blue silhouettes). Ten paper cranes are hidden around: find them all.", "The menu is a pause: [k]ESC[/k] or CONTINUE brings you back exactly where you were.", "Press [k]F[/k] for full screen.", "[k]ESC[/k] goes back."],
		"noServer": "Offline copy: start the server to load fresh content",
	},
	"it": {
		"tips": ["Suggerimento: [k]←[/k] [k]→[/k] per camminare, tieni premuto [k]SHIFT[/k] per correre.", "Suggerimento: premi [k]E[/k] vicino a una porta per entrare.", "Suggerimento: in cameretta clicca gli oggetti per aprirli.", "Suggerimento: nel menu, la finestra accesa ti porta subito dentro."],
		"loading": "CARICAMENTO", "start": "INIZIA", "room": "VAI SUBITO IN CAMERETTA", "settings": "IMPOSTAZIONI", "help": "COME SI GIOCA",
		"language": "Lingua", "langName": "Italiano", "audio": "Audio", "on": "ON", "off": "OFF",
		"backLab": "◀ Laboratorio", "backSky": "◀ Osservatorio",
		"labHello": "Il laboratorio. Quattro banchi, quattro domande.",
		"hintField": "clicca per posare · trascina per spostare · [k]E[/k] segno · [k]Q[/k] dipolo · [k]V[/k] potenziale · [k]X[/k] pulisci · [k]ESC[/k] menu",
		"hintFou": "[k]E[/k] cambia posto · [k]Q[/k] velocità · [k]X[/k] da capo · [k]ESC[/k] menu",
		"hintAur": "[k]E[/k] lancia particelle · [k]Q[/k] energia del vento solare · [k]ESC[/k] menu",
		"hintPho": "[k]E[/k] uno · [k]Q[/k] cento · [k]R[/k] mille · [k]T[/k] fenditure · [k]V[/k] rivelatore · [k]X[/k] pulisci · [k]ESC[/k] menu",
		"hintCof": "[k]E[/k] la prossima stella · [k]ESC[/k] menu",
		"fieldHello": "Posa le cariche sulla neve: le linee di forza si disegnano da sole. Tocca una carica per toglierla.", "fieldFull": "Otto cariche bastano: togline una.", "fieldPlus": "POSO: +", "fieldMinus": "POSO: −", "fieldDip": "DIPOLO", "fieldPot": "POTENZIALE", "fieldClear": "PULISCI",
		"fouHello": "Il pendolo oscilla sempre nello stesso piano: è il pavimento che gira sotto, insieme alla Terra.", "fouRos": "ROSIGNANO, 43,4° N", "fouPole": "POLO NORD", "fouPisa": "PISA, 43,7° N", "fouEq": "EQUATORE", "fouSouth": "CITTÀ DEL CAPO, 33,9° S", "fouSpeed": "TEMPO × %d", "fouReset": "DA CAPO", "fouTurn": "girato di %s°", "fouHours": "in %s ore", "fouPeriod": "un giro: %s ore", "fouNever": "qui non gira mai",
		"aurHello": "Lancia le particelle del Sole: il campo della Terra le cattura e le accompagna ai poli. Lì l'aria si accende.", "aurFire": "LANCIA", "aurEn": ["VENTO DEBOLE", "VENTO NORMALE", "TEMPESTA SOLARE"], "aurInfo": ["Vento debole: poca luce, vicino ai poli.", "Verde: ossigeno a 557,7 nanometri, tra i 100 e i 150 chilometri.", "Tempesta: rosso in alto, viola in basso, e l'aurora scende verso di noi."], "aurLat": "aurora a %d° di latitudine magnetica",
		"phoHello": "Un fotone alla volta, e ognuno lascia un puntino solo. Spara, e guarda che cosa viene fuori insieme.", "phoOne": "Una fenditura: una macchia larga, niente frange.", "phoTwo": "Due fenditure: le frange tornano, anche se i fotoni passano uno per volta.", "phoSpy": "Adesso qualcuno guarda da che parte passano. E le frange spariscono.", "phoNoSpy": "Nessuno guarda: le frange tornano.", "phoS1": "UNA FENDITURA", "phoS2": "DUE FENDITURE", "phoOn": "RIVELATORE ACCESO", "phoOff": "RIVELATORE SPENTO", "phoCount": "%d fotoni",
		"sky1610": "7 gennaio 1610, Padova. Galileo punta il cannocchiale su Giove e vede tre stelline: due a est, una a ovest. Vai avanti di un giorno: saranno tutte a ovest.", "skyNowBack": "OGGI", "skyCoffee": "CAFFÈ", "skyScope": "CANNOCCHIALE",
		"cofHello": "Ogni stella è un caffè che qualcuno mi ha offerto. Sono %d. Grazie.", "cofNone": "Qui si accende una stella per ogni caffè offerto. Il cielo è ancora tutto da accendere.", "cofName": "DAI UN NOME ALLA TUA STELLA", "cofNext": "LA PROSSIMA", "cofStar": "Questa l'ha accesa: %s. Grazie.", "starNone": "Le stelle si accendono con un caffè: copia il tuo codice per le donazioni dal negozio e incollalo nel messaggio.", "starAsk": "Hai acceso una stella. Come vuoi che si chiami? Il nome si vede dopo che Cristiano l'ha letto.", "starSend": "DAI IL NOME", "starOk": "Fatto. Comparirà appena approvato.",
		"weather": {"sereno": "sereno", "nuvole": "nuvoloso", "nebbia": "nebbia", "pioggia": "pioggia", "neve": "neve", "temporale": "temporale"}, "weatherOn": "VERO", "weatherT": "Meteo", "ghostsT": "Altri visitatori",
		"secretFound": "Una gru di carta: %d su 10", "secretAll": "Le hai trovate tutte e dieci! Nel negozio c'è una Vespa per te.", "shopPrize": "Servono tutte le dieci gru di carta.", "shopPrizeN": "PREMIO · GRU %d/10",
		"photoTitle": "Foto", "photoShot": "SCATTA", "photoFilter": "FILTRO", "photoNone": "nessuno", "photoExit": "ESCI", "photoSaved": "Cartolina salvata",
		"radioNames": ["RADIO SPENTA", "Tirreno Lo-fi 98.4", "Onda Elettrica 101.7", "Bossa dell'Aurelia", "Radio Fisica"],
		"radioNews": ["un secondo è la durata di 9.192.631.770 oscillazioni della luce di un atomo di cesio.", "la Luna si allontana da noi di quasi quattro centimetri l'anno. Nessun rancore.", "in un cucchiaino di stella di neutroni c'è la massa di una montagna.", "i muoni dei raggi cosmici arrivano a terra solo perché, per loro, il tempo scorre più piano.", "la luce del Sole che vedi ora è partita otto minuti fa.", "un fulmine è più caldo della superficie del Sole, ma dura molto meno.", "il vuoto non è mai del tutto vuoto: lo misura l'effetto Casimir.", "a Cascina, vicino a Pisa, il rivelatore Virgo ascolta le onde gravitazionali.", "Enrico Fermi ha studiato a Pisa. Si dice che esplorasse anche i tetti della città.", "traffico regolare sull'Aurelia, qualche rallentamento alla velocità della luce."],
		"coffeeBtn": "OFFRIMI UN CAFFÈ", "coffeeTitle": "Offrimi un caffè", "coffeeTokens": "Prendi monete", "coffeeText": "Costruisco tutto questo un'idea alla volta, tra un esame e l'altro. Se ti ha fatto sorridere, un caffè mi aiuta a tenere accesa la luce in cameretta. E in cielo si accende una stella col tuo nome.", "coffeeFree": "La strada è gratis, e lo sarà sempre: qui nessun posto ti chiede di pagare.", "nudge": "Ti piace la passeggiata? Un caffè tiene accesa la luce.", "resume": "CONTINUA", "restart": "RICOMINCIA DALLA STRADA", "visit": "VISITA IN 60 SECONDI", "visitHello": "Chi sono", "visitEnd": "E adesso?", "visitPause": "PAUSA", "visitPlay": "CONTINUA",
		"map": "MAPPA", "mapTitle": "Dove vuoi andare?", "season": "Stagione", "seasonAuto": "VERA", "seasons": {"inverno": "INVERNO", "primavera": "PRIMAVERA", "estate": "ESTATE", "autunno": "AUTUNNO"},
		"streetTitles": {"inverno": "UNA NOTTE DI NEVE", "primavera": "UNA NOTTE DI PETALI", "estate": "UNA NOTTE DI LUCCIOLE", "autunno": "UNA NOTTE DI FOGLIE"},
		"places": {"street": "La strada", "room": "La cameretta", "ride": "Il giro in Vespa", "grove": "I templi", "sky": "L'osservatorio", "train": "Il treno notturno", "arcade": "La sala giochi", "tower": "La Torre di Pisa", "light": "Il faro di Livorno", "pier": "Il molo di Quercianella", "bottles": "Bottiglie nel mare", "lab": "Il laboratorio", "field": "Campi vivi", "foucault": "Pendolo di Foucault", "aurora": "Aurora su richiesta", "photon": "Doppia fenditura", "coffee": "Il cielo dei caffè"},
		"placeInfo": {"street": "Da qui comincia tutto.", "room": "I miei progetti, oggetto per oggetto.", "ride": "Il lungomare, dalla notte all'alba.", "grove": "Star Wars, Harry Potter e Dune.", "sky": "Il cielo vero di Rosignano, stanotte.", "train": "La mia strada, una carrozza alla volta.", "arcade": "Un cabinato per ogni progetto.", "tower": "Chi arriva prima a terra?", "light": "Onde, lampade e frange.", "pier": "Pesca qualcosa da leggere.", "bottles": "Lascia un messaggio a chi verrà.", "lab": "Campi, pendolo, aurora, fotoni.", "coffee": "Una stella per ogni caffè."},
		"go": {"lab": "Entra in laboratorio", "train": "Sali sul treno", "sky": "Sali all'osservatorio", "arcade": "Entra in sala giochi", "light": "Sali sul faro", "pier": "Vai a pescare", "bottles": "Guarda le bottiglie"},
		"backSea": "◀ Lungomare", "towerGo": "Alla Torre di Pisa",
		"hintSky": "[k]←[/k][k]→[/k][k]W[/k][k]S[/k] guarda · [k]E[/k] che cos'è? · [k]Q[/k][k]R[/k] ore · [k]+[/k][k]−[/k] zoom · [k]L[/k] linee · [k]ESC[/k] menu",
		"hintTower": "[k]E[/k] lascia cadere · [k]←[/k][k]→[/k] cambia oggetto · [k]Q[/k] aria o vuoto · [k]ESC[/k] menu",
		"hintLight": "[k]←[/k][k]→[/k] lunghezza d'onda · [k]W[/k][k]S[/k] distanza tra le lampade · [k]E[/k] una o due · [k]ESC[/k] menu",
		"hintPier": "[k]E[/k] lancia, e tira quando abbocca · [k]ESC[/k] menu",
		"hintPlace": "[k]←[/k][k]→[/k] cammina · [k]E[/k] guarda · [k]ESC[/k] menu",
		"skyHello": "Questo è il cielo vero sopra Rosignano. Spostati, e punta quello che ti incuriosisce.", "skyTonight": "Stasera", "skyNow": "ADESSO", "skyLines": "LINEE", "skyNone": "Qui c'è solo buio. O quasi.",
		"skyDirs": ["nord", "nord-est", "est", "sud-est", "sud", "sud-ovest", "ovest", "nord-ovest"], "skyStar": "Una stella di magnitudine %.1f.", "skyWhere": "È verso %s, a %d° di altezza.",
		"skyBodies": {"sole": "Sole", "luna": "Luna", "mercurio": "Mercurio", "venere": "Venere", "marte": "Marte", "giove": "Giove", "saturno": "Saturno"},
		"skyWhat": {"sole": "La nostra stella: la sua luce ci mette poco più di otto minuti.", "luna": "Illuminata al %d%%.", "mercurio": "Il più vicino al Sole: un anno dura 88 giorni.", "venere": "La più brillante dopo la Luna. Lì il giorno dura più dell'anno.", "marte": "Rosso di ruggine: ossidi di ferro.", "giove": "Galileo vide le sue quattro lune nel gennaio del 1610.", "saturno": "Gli anelli sono ghiaccio, larghi e sottilissimi."},
		"towerHello": "Si racconta che Galileo li lasciò cadere da qui. Forse non andò proprio così, ma la domanda è quella giusta: chi arriva prima?",
		"towerDrop": "LASCIA CADERE", "towerAir": "CON L'ARIA", "towerVoid": "NEL VUOTO", "towerObj": {"ball_iron": "ferro", "ball_wood": "legno", "ball_cork": "sughero", "feather": "piuma"},
		"towerTie": "%s secondi tutti e due. Senza aria, la massa non conta: nell'equazione si semplifica.", "towerWin": "Ferro: %s s. L'altro: %s s. Non è il peso in sé: è l'aria, che rallenta di più chi è leggero per la sua misura (%s).",
		"lightHello": "Il faro, visto dall'alto. Due lampade battono insieme: dove le onde arrivano in fase la luce raddoppia, dove sono opposte si spegne.", "lightOne": "Una lampada sola: niente frange. La luce si allarga e basta.", "lightTwo": "Due lampade: ecco le frange. Più le allontani, più si stringono.", "lightW": "ONDA", "lightD": "DISTANZA", "lightF": "tra le frange", "lightB1": "UNA LAMPADA", "lightB2": "DUE LAMPADE",
		"fishHello": "Il molo è gelato e silenzioso. Lancia, aspetta, e tira quando vedi il segnale.", "fishCast": "LANCIA", "fishStop": "RITIRA", "fishPull": "TIRA!", "fishEarly": "Troppo presto: non c'era ancora nessuno.", "fishLost": "È scappato. Ci pensava anche lui.",
		"fishNames": {"fish0": "Una sardina", "fish1": "Una triglia", "fish2": "Un'orata", "fish3": "Un pesce viola, rarissimo"},
		"trainRead": "Leggi", "trainEmpty": "L'ultima carrozza è ancora vuota. Si vedrà.",
		"arcadeHello": "Un cabinato per ogni progetto. Il gettone lo offre la casa.", "arcadePlay": "Gioca",
		"bottleTitle": "Bottiglie nel mare", "bottleNone": "Nessuna bottiglia, per ora. La prima potrebbe essere la tua.", "bottleOther": "UN'ALTRA BOTTIGLIA", "bottleWrite": "Scrivi un messaggio: chi passerà di qui potrà trovarlo. Cristiano lo legge prima che prenda il largo.", "bottleText": "Il tuo messaggio (massimo 200 caratteri)", "bottleName": "Come ti chiami? (se vuoi)", "bottleSend": "LANCIA LA BOTTIGLIA", "bottleSent": "La bottiglia è partita. Tornerà a galla dopo essere stata letta.", "bottleErr": "Il mare l'ha riportata indietro. Riprova più tardi.", "bottleShort": "Scrivi almeno qualche parola.", "bottleAnon": "senza nome", "bottleOff": "Il mare stasera non risponde: riprova quando c'è rete.",
		"grove": "i templi", "toGrove": "Vai ai templi", "templesHello": "Tre templi: a sinistra Star Wars, a destra Harry Potter e, più avanti, in fondo al sentiero, Dune.", "pray": {"stelle": "Prega", "magia": "Prega", "dune": "Prega"},
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
		"shopPlayT": "Giocando", "shopPlay": "Ogni giorno che passi di qui: %d. Ogni nuova tappa in Vespa: %d. Ogni oggetto della cameretta: %d. L'alba in fondo alla strada: %d. Una preghiera a ogni tempio, una volta al giorno: %d. Il primo pesce del giorno: %d.",
		"shopGiveT": "Offrendo un caffè su KO-FI", "shopGive": "Ogni unità donata vale %d monete. Copia il tuo codice per le donazioni (serve solo a ricevere, può essere pubblico) e incollalo nel messaggio: le monete arrivano qui da sole, di solito entro un minuto.", "shopSoon": "Le donazioni non sono ancora aperte. Intanto le monete si guadagnano giocando.", "shopThanks": "Se ti piace questo posto puoi offrirmi un caffè. Le monete per chi dona non sono ancora attive: per ora sarebbe solo un pensiero gentile. Grazie.",
		"shopCopy": "COPIA %s", "shopCopied": "Codice copiato: incollalo nel messaggio della donazione.", "shopCoffee": "APRI KO-FI ↗", "shopCheck": "CONTROLLA LE MONETE", "shopIn": "Sono arrivate %d monete. Grazie!", "shopNotYet": "Ancora niente. Può volerci un minuto.",
		"shopCodeT": "Il tuo portafoglio", "shopCode": "Il tuo codice è [color=#f2b85b]%s[/color]. Tienilo per te, come una password: porta monete e acquisti su qualunque altro dispositivo. Nessun nome, nessuna email.", "shopEnter": "USA UN CODICE", "shopCodeOk": "Portafoglio trovato.", "shopCodeBad": "Nessun portafoglio con questo codice.", "coinsIn": "+%d monete",
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
		"hintRide": "[k]→[/k] gas · [k]←[/k] freno · [k]SHIFT[/k] più veloce · [k]E[/k] fermati · [k]H[/k] clacson · [k]R[/k] radio · [k]ESC[/k] menu",
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
		"helpItems": ["Percorri la strada innevata con [k]←[/k] [k]→[/k] (o [k]A[/k] [k]D[/k]). Tieni [k]SHIFT[/k] per correre. Da telefono usa le frecce o tocca dove vuoi andare.", "Leggi le bolle lungo la strada: ti raccontano chi sono.", "A metà strada un sentiero illuminato scende al mare. C'è una Vespa: metti il casco e parti, [k]→[/k] gas, [k]←[/k] freno, [k]E[/k] per fermarti a guardare, [k]H[/k] per il clacson.", "Davanti a casa, e vicino a TV, camino e porta luminosa, premi [k]E[/k] (o il pulsante giallo).", "In cameretta ogni oggetto apre una parte del portfolio. Puoi camminare o puntare e cliccare: la modalità attuale è sempre indicata in alto e la cambi nelle Impostazioni.", "Un altro sentiero, illuminato di viola, entra nel bosco: ci sono tre templi dove sedersi a pregare con [k]E[/k].", "Giocando si guadagnano monete da spendere nel negozio (la moneta in alto): temi, vestiti, Vespa, arredi.", "[k]P[/k] scatta una foto, [k]G[/k] saluta gli altri visitatori (le sagome azzurre). In giro sono nascoste dieci gru di carta: trovale tutte.", "Il menu è una pausa: con [k]ESC[/k] o CONTINUA torni esattamente dov'eri.", "Premi [k]F[/k] per lo schermo intero.", "[k]ESC[/k] torna indietro."],
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
var season := "auto"
var real_weather := true
var ghosts := true
var secrets: Dictionary = {}       # gru di carta trovate
var fish: Dictionary = {}          # pescato al molo
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
	fish = prefs.get_value("p", "fish", {})
	season = prefs.get_value("p", "season", "auto")
	real_weather = prefs.get_value("p", "weather", true)
	ghosts = prefs.get_value("p", "ghosts", true)
	for k in prefs.get_value("p", "secrets", []): secrets[k] = true
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
	prefs.set_value("p", "fish", fish)
	prefs.set_value("p", "season", season)
	prefs.set_value("p", "weather", real_weather)
	prefs.set_value("p", "ghosts", ghosts)
	prefs.set_value("p", "secrets", secrets.keys())
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
	J.places = JSON.parse_string(FileAccess.get_file_as_string("res://store/places.json"))
	J.grove = JSON.parse_string(FileAccess.get_file_as_string("res://store/grove.json"))
	for k in ["room", "mask", "far", "mid", "near", "living", "player", "menu_sky"]:
		var f := {"room": "room", "mask": "mask", "far": "street_far", "mid": "street_mid", "near": "street_near", "living": "living", "player": "player", "menu_sky": "menu_sky"}[k] as String
		tex[k] = load("res://assets/img/%s.png" % f)
	for k in ["sea_sky", "sea_near", "sea_fore", "sea_beach", "sea_props", "sea_emblems", "shop", "grove_far", "grove_near", "grove_props", "place_pisa", "place_train", "place_arcade", "place_pier", "place_props", "place_lab"]: tex[k] = load("res://assets/img/%s.png" % k)
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
