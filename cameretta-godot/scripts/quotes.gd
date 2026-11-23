class_name Quotes
extends RefCounted
## Citazioni di fisici (e qualche altro curioso): in strada, sul lungomare, nel menu, alla lavagna e durante il caricamento.
## Le bolle dell'admin restano come sono; queste si aggiungono, diverse ogni volta.
## `sea`: sta bene guardando il mare (ha la precedenza durante il giro in Vespa).

const ALL := [
	{"text": "[L'universo] è scritto in lingua matematica, e i caratteri son triangoli, cerchi, ed altre figure geometriche.", "text_en": "[The universe] is written in the language of mathematics, and its characters are triangles, circles and other geometric figures.", "author": "Galileo Galilei, Il Saggiatore", "author_en": "Galileo Galilei, The Assayer"},
	{"text": "La filosofia è scritta in questo grandissimo libro che continuamente ci sta aperto innanzi a gli occhi, io dico l'universo.", "text_en": "Philosophy is written in this grand book which stands continually open before our eyes: I mean the universe.", "author": "Galileo Galilei, Il Saggiatore", "author_en": "Galileo Galilei, The Assayer"},
	{"text": "Noi viviamo sommersi nel fondo d'un pelago d'aria.", "text_en": "We live submerged at the bottom of an ocean of air.", "author": "Evangelista Torricelli, 1644", "sea": true},
	{"text": "Dove c'è materia, lì c'è geometria.", "text_en": "Where there is matter, there is geometry.", "author": "Johannes Kepler"},
	{"text": "Datemi un punto d'appoggio e solleverò la Terra.", "text_en": "Give me a place to stand, and I shall move the Earth.", "author": "Archimede (secondo Pappo)", "author_en": "Archimedes (as told by Pappus)"},
	{"text": "Il silenzio eterno di questi spazi infiniti mi sgomenta.", "text_en": "The eternal silence of these infinite spaces frightens me.", "author": "Blaise Pascal, Pensieri", "author_en": "Blaise Pascal, Pensées", "sea": true},
	{"text": "Se ho visto più lontano, è perché stavo sulle spalle di giganti.", "text_en": "If I have seen further, it is by standing on the shoulders of giants.", "author": "Isaac Newton, 1675"},
	{"text": "Mi sembra di essere stato solo un ragazzo che gioca sulla riva del mare, mentre il grande oceano della verità giaceva inesplorato davanti a me.", "text_en": "I seem to have been only like a boy playing on the sea-shore, whilst the great ocean of truth lay all undiscovered before me.", "author": "attribuita a Isaac Newton", "author_en": "attributed to Isaac Newton", "sea": true},
	{"text": "Non invento ipotesi.", "text_en": "I feign no hypotheses.", "author": "Isaac Newton, Principia"},
	{"text": "Niente è troppo bello per essere vero, se è coerente con le leggi della natura.", "text_en": "Nothing is too wonderful to be true, if it be consistent with the laws of nature.", "author": "Michael Faraday, diario, 1849", "author_en": "Michael Faraday, diary, 1849"},
	{"text": "Difficilmente possiamo evitare di concludere che la luce consista nelle ondulazioni trasversali dello stesso mezzo che causa i fenomeni elettrici e magnetici.", "text_en": "We can scarcely avoid the inference that light consists in the transverse undulations of the same medium which is the cause of electric and magnetic phenomena.", "author": "James Clerk Maxwell, 1862", "sea": true},
	{"text": "Non si può studiare questa teoria meravigliosa senza sentire, a volte, che le formule abbiano vita propria: più sagge di noi, perfino di chi le ha scoperte.", "text_en": "One cannot study this wonderful theory without feeling, at times, that the formulae have a life of their own: wiser than we are, wiser even than their discoverer.", "author": "Heinrich Hertz, sulla teoria di Maxwell", "author_en": "Heinrich Hertz, on Maxwell's theory"},
	{"text": "Quando puoi misurare ciò di cui parli, ed esprimerlo in numeri, ne sai qualcosa.", "text_en": "When you can measure what you are speaking about, and express it in numbers, you know something about it.", "author": "Lord Kelvin, 1883"},
	{"text": "Lo scienziato non studia la natura perché è utile: la studia perché ne prova piacere, e ne prova piacere perché è bella.", "text_en": "The scientist does not study nature because it is useful; he studies it because he delights in it, and he delights in it because it is beautiful.", "author": "Henri Poincaré, 1908"},
	{"text": "Il pensiero è solo un lampo in mezzo a una lunga notte. Ma è questo lampo che è tutto.", "text_en": "Thought is only a flash in the middle of a long night. But this flash is everything.", "author": "Henri Poincaré, 1905", "sea": true},
	{"text": "Uno scienziato nel suo laboratorio non è solo un tecnico: è anche un bambino davanti a fenomeni naturali che lo impressionano come una fiaba.", "text_en": "A scientist in his laboratory is not only a technician: he is also a child placed before natural phenomena which impress him like a fairy tale.", "author": "Marie Curie"},
	{"text": "Un esperimento è una domanda che la scienza pone alla natura, e una misura è la registrazione della risposta.", "text_en": "An experiment is a question which science poses to Nature, and a measurement is the recording of Nature's answer.", "author": "Max Planck, 1949"},
	{"text": "L'eterno mistero del mondo è la sua comprensibilità.", "text_en": "The eternal mystery of the world is its comprehensibility.", "author": "Albert Einstein, 1936", "sea": true},
	{"text": "L'immaginazione è più importante della conoscenza.", "text_en": "Imagination is more important than knowledge.", "author": "Albert Einstein, 1929"},
	{"text": "Sottile è il Signore, ma malizioso non è.", "text_en": "Subtle is the Lord, but malicious He is not.", "author": "Albert Einstein"},
	{"text": "Non ho talenti particolari. Sono solo appassionatamente curioso.", "text_en": "I have no special talents. I am only passionately curious.", "author": "Albert Einstein, 1952"},
	{"text": "L'importante è non smettere di fare domande.", "text_en": "The important thing is not to stop questioning.", "author": "Albert Einstein, 1955"},
	{"text": "Era incredibile quasi quanto sparare un proiettile da quindici pollici contro un foglio di carta velina e vederselo tornare indietro.", "text_en": "It was almost as incredible as if you fired a 15-inch shell at a piece of tissue paper and it came back and hit you.", "author": "Ernest Rutherford"},
	{"text": "L'opposto di una verità profonda può benissimo essere un'altra verità profonda.", "text_en": "The opposite of a profound truth may well be another profound truth.", "author": "Niels Bohr"},
	{"text": "Quello che osserviamo non è la natura in sé, ma la natura esposta ai nostri metodi di indagine.", "text_en": "What we observe is not nature in itself but nature exposed to our method of questioning.", "author": "Werner Heisenberg, 1958"},
	{"text": "Il mondo mi è dato una volta sola: non uno che esiste e uno che è percepito.", "text_en": "The world is given to me only once, not one existing and one perceived.", "author": "Erwin Schrödinger, Mente e materia", "author_en": "Erwin Schrödinger, Mind and Matter"},
	{"text": "Nelle proprie equazioni è più importante la bellezza che l'accordo con l'esperimento.", "text_en": "It is more important to have beauty in one's equations than to have them fit experiment.", "author": "Paul Dirac, 1963"},
	{"text": "Non è nemmeno sbagliato.", "text_en": "It is not even wrong.", "author": "Wolfgang Pauli (secondo Peierls)", "author_en": "Wolfgang Pauli (as told by Peierls)"},
	{"text": "Dove sono tutti?", "text_en": "Where is everybody?", "author": "Enrico Fermi, 1950, sugli alieni", "author_en": "Enrico Fermi, 1950, on aliens", "sea": true},
	{"text": "E questo chi l'ha ordinato?", "text_en": "Who ordered that?", "author": "Isidor Rabi, sul muone", "author_en": "Isidor Rabi, on the muon"},
	{"text": "La scienza porta a cercare con disinteresse la verità e l'oggettività; insegna ad accettare la realtà, con meraviglia e ammirazione.", "text_en": "Science makes people reach selflessly for truth and objectivity; it teaches people to accept reality, with wonder and admiration.", "author": "Lise Meitner, 1953"},
	{"text": "Qualcosa di ignoto sta facendo non sappiamo cosa.", "text_en": "Something unknown is doing we don't know what.", "author": "Arthur Eddington, 1928", "sea": true},
	{"text": "Il miracolo per cui la matematica si presta a formulare le leggi della fisica è un dono meraviglioso che non capiamo e non meritiamo.", "text_en": "The miracle of the appropriateness of the language of mathematics for the formulation of the laws of physics is a wonderful gift which we neither understand nor deserve.", "author": "Eugene Wigner, 1960"},
	{"text": "Il primo principio è non ingannare se stessi. E tu sei la persona più facile da ingannare.", "text_en": "The first principle is that you must not fool yourself, and you are the easiest person to fool.", "author": "Richard Feynman, 1974"},
	{"text": "C'è un sacco di spazio, laggiù in fondo.", "text_en": "There's plenty of room at the bottom.", "author": "Richard Feynman, 1959"},
	{"text": "Penso di poter dire tranquillamente che nessuno capisce la meccanica quantistica.", "text_en": "I think I can safely say that nobody understands quantum mechanics.", "author": "Richard Feynman, 1964"},
	{"text": "La natura tesse i suoi disegni solo con i fili più lunghi.", "text_en": "Nature uses only the longest threads to weave her patterns.", "author": "Richard Feynman, 1964"},
	{"text": "La natura non si può ingannare.", "text_en": "Nature cannot be fooled.", "author": "Richard Feynman, 1986"},
	{"text": "Lo spaziotempo dice alla materia come muoversi; la materia dice allo spaziotempo come curvarsi.", "text_en": "Spacetime tells matter how to move; matter tells spacetime how to curve.", "author": "John Archibald Wheeler"},
	{"text": "Viviamo su un'isola circondata da un mare di ignoranza. Più cresce l'isola del sapere, più si allunga la riva della nostra ignoranza.", "text_en": "We live on an island surrounded by a sea of ignorance. As our island of knowledge grows, so does the shore of our ignorance.", "author": "John Archibald Wheeler, 1992", "sea": true},
	{"text": "Di più è diverso.", "text_en": "More is different.", "author": "Philip W. Anderson, 1972"},
	{"text": "Lo sforzo di capire l'universo è una delle pochissime cose che sollevano la vita umana un po' sopra il livello della farsa, e le danno un po' della grazia della tragedia.", "text_en": "The effort to understand the universe is one of the very few things that lifts human life a little above the level of farce, and gives it some of the grace of tragedy.", "author": "Steven Weinberg, 1977"},
	{"text": "Il cosmo è dentro di noi. Siamo fatti di materia di stelle.", "text_en": "The cosmos is within us. We are made of star-stuff.", "author": "Carl Sagan, Cosmos", "sea": true},
	{"text": "Guardate le stelle, non i vostri piedi.", "text_en": "Look up at the stars and not down at your feet.", "author": "Stephen Hawking, 2012", "sea": true},
	# la curiosità e la scoperta (in strada e al caricamento escono per prime)
	{"text": "La curiosità ha la sua ragione di esistere.", "text_en": "Curiosity has its own reason for existing.", "author": "Albert Einstein, 1955", "cur": true},
	{"text": "È quasi un miracolo che i metodi moderni d'insegnamento non abbiano ancora soffocato del tutto la sacra curiosità della ricerca.", "text_en": "It is nothing short of a miracle that the modern methods of instruction have not yet entirely strangled the holy curiosity of inquiry.", "author": "Albert Einstein, 1949", "cur": true},
	{"text": "L'esperienza più bella che possiamo avere è il mistero: è l'emozione da cui nascono la vera arte e la vera scienza.", "text_en": "The most beautiful experience we can have is the mysterious: the emotion which stands at the cradle of true art and true science.", "author": "Albert Einstein, 1930", "cur": true, "sea": true},
	{"text": "Non smettiamo mai di stare, come bambini curiosi, davanti al grande mistero in cui siamo nati.", "text_en": "We never cease to stand like curious children before the great mystery into which we were born.", "author": "Albert Einstein, 1942", "cur": true, "sea": true},
	{"text": "Dietro le cose doveva esserci qualcosa di profondamente nascosto.", "text_en": "Something deeply hidden had to be behind things.", "author": "Albert Einstein, sulla bussola vista da bambino", "author_en": "Albert Einstein, on the compass he saw as a child", "cur": true},
	{"text": "Guardavo la neve con occhi nuovi: intorno alla mia porta, grandi cumuli di protoni in tranquilla precessione nel campo magnetico terrestre.", "text_en": "Looking on snow with new eyes: there the snow lay around my doorstep, great heaps of protons quietly precessing in the earth's magnetic field.", "author": "Edward Purcell, discorso per il Nobel, 1952", "author_en": "Edward Purcell, Nobel lecture, 1952", "cur": true},
	{"text": "Vedere per un attimo il mondo come qualcosa di ricco e strano: è il premio privato di molte scoperte.", "text_en": "To see the world for a moment as something rich and strange is the private reward of many a discovery.", "author": "Edward Purcell, 1952", "cur": true},
	{"text": "Il premio è il piacere di scoprire la cosa, il brivido della scoperta.", "text_en": "The prize is the pleasure of finding the thing out, the kick in the discovery.", "author": "Richard Feynman, 1981", "cur": true},
	{"text": "Trovo molto più interessante vivere senza sapere che avere risposte che potrebbero essere sbagliate.", "text_en": "I think it's much more interesting to live not knowing than to have answers which might be wrong.", "author": "Richard Feynman, 1981", "cur": true},
	{"text": "Non mi spaventa non sapere le cose.", "text_en": "I don't feel frightened by not knowing things.", "author": "Richard Feynman, 1981", "cur": true},
	{"text": "Al mistero non fa nessun male saperne un po' di più.", "text_en": "It does no harm to the mystery to know a little about it.", "author": "Richard Feynman, 1963", "cur": true, "sea": true},
	{"text": "Anch'io vedo le stelle, in una notte nel deserto, e le sento. Ma vedo di meno o di più?", "text_en": "I too can see the stars on a desert night, and feel them. But do I see less or more?", "author": "Richard Feynman, 1963", "cur": true, "sea": true},
	{"text": "Infinitamente rendo grazie a Dio, che si sia compiaciuto di far me solo primo osservatore di cosa ammiranda, e tenuta a tutti i secoli occulta.", "text_en": "I render infinite thanks to God for being so kind as to make me alone the first observer of marvels kept hidden in obscurity for all previous centuries.", "author": "Galileo Galilei, dopo il cannocchiale, 1610", "author_en": "Galileo Galilei, after the telescope, 1610", "cur": true},
	{"text": "È bellissimo, e quanto mai piacevole a vedersi, il corpo della Luna.", "text_en": "It is a most beautiful and delightful sight to behold the body of the Moon.", "author": "Galileo Galilei, Sidereus Nuncius", "cur": true, "sea": true},
	{"text": "Ma come funziona, questo? Come funziona di preciso?", "text_en": "What's the go o' that? What's the particular go of that?", "author": "James Clerk Maxwell, da bambino", "author_en": "James Clerk Maxwell, as a child", "cur": true},
	{"text": "Non c'è porta più aperta, per entrare nello studio della natura, dei fenomeni fisici di una candela.", "text_en": "There is no more open door by which you can enter into the study of natural philosophy, than by considering the physical phenomena of a candle.", "author": "Michael Faraday, 1861", "cur": true},
	{"text": "Non pensai. Investigai.", "text_en": "I did not think; I investigated.", "author": "Wilhelm Röntgen, sui raggi X, 1896", "author_en": "Wilhelm Röntgen, on X-rays, 1896", "cur": true},
	{"text": "Andavamo di notte nel laboratorio: da ogni parte vedevamo le sagome appena luminose delle nostre provette, come deboli luci fatate.", "text_en": "We went into our workroom at night: on all sides we perceived the feebly luminous silhouettes of our tubes, like faint, fairy lights.", "author": "Marie Curie, sul radio, 1923", "author_en": "Marie Curie, on radium, 1923", "cur": true, "sea": true},
	{"text": "Sono tra quelli che pensano che la scienza abbia una grande bellezza.", "text_en": "I am among those who think that science has great beauty.", "author": "Marie Curie", "cur": true},
	{"text": "Ebbi la sensazione di guardare, attraverso la superficie dei fenomeni atomici, un interno di una strana bellezza.", "text_en": "I had the feeling that, through the surface of atomic phenomena, I was looking at a strangely beautiful interior.", "author": "Werner Heisenberg, sull'isola di Helgoland", "author_en": "Werner Heisenberg, on the island of Helgoland", "cur": true, "sea": true},
	{"text": "Abbiamo trovato una strana impronta sulla riva dell'ignoto. Alla fine abbiamo ricostruito la creatura che l'ha lasciata. Ed ecco: è la nostra.", "text_en": "We have found a strange footprint on the shores of the unknown. At last, we have reconstructed the creature that made it. And lo! it is our own.", "author": "Arthur Eddington, 1920", "cur": true, "sea": true},
	{"text": "Izzy, hai fatto una buona domanda oggi?", "text_en": "Izzy, did you ask a good question today?", "author": "la mamma di Isidor Rabi, dopo scuola", "author_en": "Isidor Rabi's mother, after school", "cur": true},
	{"text": "Con la logica si dimostra, con l'intuizione si inventa.", "text_en": "It is by logic that we prove, but by intuition that we invent.", "author": "Henri Poincaré, 1908", "cur": true},
	{"text": "Dotato dei suoi cinque sensi, l'uomo esplora l'universo che lo circonda, e chiama l'avventura scienza.", "text_en": "Equipped with his five senses, man explores the universe around him and calls the adventure Science.", "author": "Edwin Hubble, 1929", "cur": true, "sea": true},
	{"text": "Ho guardato nello spazio più lontano di quanto avesse mai fatto un essere umano prima di me.", "text_en": "I have looked further into space than ever human being did before me.", "author": "William Herschel, 1813", "cur": true},
	{"text": "Non chiediamo che guadagno speri l'uccellino cantando. Così non serve chiedere perché la mente si affanni a cercare i segreti del cielo.", "text_en": "We do not ask what gain makes a little bird warble. So there is no need to ask why the human mind toils to seek out the secrets of the heavens.", "author": "Johannes Kepler, 1596", "cur": true},
	{"text": "Esplorare è nella nostra natura. Abbiamo cominciato come viandanti, e viandanti siamo ancora.", "text_en": "Exploration is in our nature. We began as wanderers, and we are wanderers still.", "author": "Carl Sagan, Cosmos", "cur": true, "sea": true},
	{"text": "La superficie della Terra è la riva dell'oceano cosmico.", "text_en": "The surface of the Earth is the shore of the cosmic ocean.", "author": "Carl Sagan, Cosmos", "cur": true, "sea": true},
	{"text": "Cercate di dare un senso a ciò che vedete, e chiedetevi che cosa fa esistere l'universo. Siate curiosi.", "text_en": "Try to make sense of what you see, and wonder about what makes the universe exist. Be curious.", "author": "Stephen Hawking, 2012", "cur": true},
	{"text": "Non c'è niente come l'attimo dell'eureka, scoprire qualcosa che nessuno sapeva prima.", "text_en": "There's nothing like the eureka moment of discovering something that no one knew before.", "author": "Stephen Hawking, 2011", "cur": true},
	{"text": "Andate dove c'è confusione: è lì che succedono le cose.", "text_en": "Go for the messes: that's where the action is.", "author": "Steven Weinberg, 2003", "cur": true},
	{"text": "Preferirei trovare una sola spiegazione che diventare re di Persia.", "text_en": "I would rather discover a single explanation than become king of Persia.", "author": "Democrito", "author_en": "Democritus", "cur": true},
	{"text": "Verrà un tempo in cui i nostri posteri si meraviglieranno che ignorassimo cose tanto evidenti.", "text_en": "There will come a time when our descendants will be amazed that we did not know things so plain to them.", "author": "Seneca, Questioni naturali", "author_en": "Seneca, Natural Questions", "cur": true},
	{"text": "La sapienza è figliola della sperienza.", "text_en": "Wisdom is the daughter of experience.", "author": "Leonardo da Vinci", "cur": true},
	{"text": "Fatti non foste a viver come bruti, ma per seguir virtute e canoscenza.", "text_en": "You were not made to live like beasts, but to follow virtue and knowledge.", "author": "Dante, Inferno XXVI", "cur": true, "sea": true},
]

static var _deck: Array = []
static var _sea_deck: Array = []

## La prossima citazione da un mazzo mescolato: nessuna si ripete finché non sono uscite tutte.
static func next(sea := false) -> Dictionary:
	if sea:
		if _sea_deck.is_empty():
			var a := ALL.filter(func(q): return q.has("sea"))
			var b := ALL.filter(func(q): return not q.has("sea"))
			a.shuffle(); b.shuffle()
			_sea_deck = b + a              # si pesca dal fondo: prima quelle del mare
		return _sea_deck.pop_back()
	if _deck.is_empty():
		_deck = ALL.duplicate()
		_deck.shuffle()
		# si comincia con la curiosità e la scoperta: due su tre, finché durano
		var cur := _deck.filter(func(q): return q.has("cur"))
		var rest := _deck.filter(func(q): return not q.has("cur"))
		_deck = rest.slice(cur.size() / 2)
		_deck.append_array(_mix(cur, rest.slice(0, cur.size() / 2)))
	return _deck.pop_back()

## Due della curiosità e una delle altre, a partire dal fondo del mazzo (da dove si pesca).
static func _mix(a: Array, b: Array) -> Array:
	var out: Array = []
	while not a.is_empty() or not b.is_empty():
		for k in 2:
			if not a.is_empty(): out.push_front(a.pop_back())
		if not b.is_empty(): out.push_front(b.pop_back())
	return out

static func author(q: Dictionary) -> String:
	return G.L(q, "author")

## Tutta in un testo: «…» — autore.
static func line(q: Dictionary) -> String:
	return "«%s» — %s" % [G.L(q, "text"), author(q)]
