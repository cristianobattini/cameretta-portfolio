# CRI's CAMERETTA — portfolio

Un portfolio a forma di videogioco 2D in pixel art, in inglese e in italiano (inglese di default, si cambia dal menu o dal pulsante EN/IT).

1. **Menu** sul cielo stellato, con la schermata di caricamento sfocata.
2. **La strada innevata**: muovi l'omino (frecce o A/D, SHIFT per correre, sul telefono le frecce a schermo o un tocco). Lungo la strada compaiono le bolle con la presentazione e le citazioni, scritte lettera per lettera con il suono della tastiera. In fondo c'è casa: **E** per entrare.
3. **Il salotto**: camino acceso, TV (con **E** cambi canale), orologio a pendolo, gatto sul divano. La porta luminosa porta in cameretta.
4. **La cameretta**: due modalità, *cammina* (l'omino si muove nella stanza) o *punta e clicca*; si sceglie all'inizio, si cambia nelle Impostazioni ed è sempre indicata a schermo.

**Due versioni del gioco**, stessi contenuti:

- `/game/` — **versione Godot** (principale). Il progetto sorgente è la cartella `cameretta-godot` (vedi il suo README); in `public/game/` c'è l'export Web. Suoni registrati CC0.
- `/classic/` — la versione HTML/JS precedente, con i suoni sintetizzati nel browser.

La musica di sottofondo si carica dall'admin e vale per entrambe.

| Oggetto   | Sezione                          |
|-----------|----------------------------------|
| Finestra  | Il mio percorso e CV             |
| Scrivania | Progetti di programmazione       |
| Lavagna   | Appunti di fisica e materiale    |
| Libreria  | I miei libri e attestati         |
| Letto     | Articoli ed elaborati personali  |

Tutti i contenuti stanno in un database **SQLite locale** e si gestiscono da una **dashboard admin**.

Lungo la strada ci sono due deviazioni: il **lungomare** con il giro in Vespa e i **templi** (omaggi a Star Wars, Harry Potter e Dune, arte originale) dove ci si siede a pregare. Dalla strada si raggiungono anche il **treno notturno**, l'**osservatorio** (cielo vero di Rosignano) e la **sala giochi**; dal lungomare il **molo**, il **faro** e, alla fine del giro, la **Torre di Pisa**. Sulla spiaggia ci sono le **bottiglie nel mare**: i messaggi dei visitatori si approvano in *Admin → Bottiglie*. La strada segue la stagione vera (Impostazioni → Stagione per cambiarla). La voce **Mappa** del menu porta ovunque. `F` = schermo intero.

## Password dell'admin

Senza password chiunque raggiunga `/admin/` può modificare il sito. Il server la legge all'avvio dalla variabile `CAMERETTA_ADMIN_TOKEN`. Con il servizio Windows (NSSM), da un prompt come amministratore:

```
C:\nssm\win64\nssm.exe get Cameretta AppEnvironmentExtra
C:\nssm\win64\nssm.exe set Cameretta AppEnvironmentExtra CAMERETTA_ADMIN_TOKEN=una-password-lunga CAMERETTA_KOFI_TOKEN=token-di-ko-fi
```

`set` sostituisce tutte le variabili: se `get` ne mostra altre, riscrivile nella stessa riga. Poi `riavvia-server.bat`.

## Il negozio

Le monete si guadagnano giocando oppure donando su Ko-fi; servono per temi, vestiti, Vespa, arredi e potenziamenti. Il catalogo (nomi, prezzi, colori) è `cameretta-godot/store/catalog.json`: lo leggono sia il gioco sia il server, quindi dopo averlo cambiato si riesporta il gioco e si riavvia il server.

Per attivare le donazioni:

1. In **Admin → Negozio** controlla l'indirizzo della pagina Ko-fi.
2. Su Ko-fi → *More → API → Webhooks* incolla `https://www.cristianobattini.com/api/kofi/webhook` e copia il *Verification Token* (sotto *Advanced*).
3. Avvia il server con `CAMERETTA_KOFI_TOKEN` uguale a quel token (mai nelle impostazioni: quelle sono pubbliche).

Finché manca il token il gioco mostra il link a Ko-fi senza promettere monete. Ko-fi non avvisa dei rimborsi: si stornano a mano da Admin → Negozio.

Ogni visitatore ha un portafoglio anonimo (`CRI-XXXX-XXXX`): chi dona incolla il codice nel messaggio. Non si salvano nomi né email.

## Avvio

**macOS**: doppio clic su `avvia.command`. Se macOS lo blocca, tasto destro → Apri.
**Windows**: doppio clic su `avvia.bat`.

Oppure da terminale:

```bash
python3 -m venv .venv
source .venv/bin/activate        # su Windows: .venv\Scripts\activate
pip install -r requirements.txt
python server.py
```

Poi apri:

- **Sito**: http://localhost:8000/
- **Admin**: http://localhost:8000/admin/
- **Documentazione API**: http://localhost:8000/api/docs

Al primo avvio viene creato `data/cameretta.db` con i contenuti iniziali. I file caricati finiscono in `data/uploads/`.

## La dashboard admin

- **Generale**: testi del menu iniziale, sfondo del menu (usato anche, sfocato, nella schermata di caricamento), immagine e maschera della stanza, contatti, CV, colore di accento, audio e **musica di sottofondo** (mp3/ogg in loop, con il suo volume).
- **Sezioni e voci**: per ogni oggetto puoi cambiare il cartello, il titolo, l'introduzione, il colore e il link in fondo al pannello (es. GitHub). Puoi aggiungere, modificare, nascondere, riordinare ed eliminare le voci. La ricerca trova le voci in tutte le sezioni.
- **Strada**: le bolle della passeggiata (presentazione o citazione con autore), con ordine e visibilità.

Ogni testo ha il campo **IT** e il campo **EN** affiancati: se l'inglese è vuoto, il sito mostra l'italiano. In "Generale" scegli la lingua predefinita e, se vuoi, puoi far saltare strada e salotto.
- **File**: carica dal PC (pulsante o trascinamento), cerca per nome, rinomina, copia il link, elimina. Un file in uso non si può eliminare.
- **Backup**: scarica tutto in JSON, oppure esporta `data.json` per una versione statica.

Ogni immagine si sceglie con **Scegli dal PC…**, che apre la finestra dei file del sistema (con la sua ricerca), oppure con **Dalla libreria…** tra i file già caricati.

### Come funzionano le voci

Ogni voce ha un **gruppo** (es. "Progetti", "Corsi", "Attestati"), e il pannello mostra un blocco per gruppo, nell'ordine delle voci. Il primo gruppo ha due layout speciali:

- nella **Finestra** diventa una linea del tempo, con la "riga piccola" usata come data;
- nella **Libreria** diventa uno scaffale di libri, che mostra la copertina se c'è un'immagine.

Gli altri gruppi sono schede con titolo, descrizione, tag, etichetta, link e immagine.

## Musica

Carica il brano da **Generale → Aspetto e audio → Musica di sottofondo**. Suona in loop sotto gli effetti sonori, si abbassa durante i passaggi tra menu e stanza e si ferma quando la scheda non è visibile. I browser non fanno partire l'audio da soli: la musica parte quando il visitatore attiva l'audio (o al primo clic, se l'audio è acceso di default). Usa brani con una licenza che ne permetta l'uso, per esempio CC0.

## Windows (anche server)

Doppio clic su `avvia.bat`. Su un server, prima di avviare:

```bat
set CAMERETTA_HOST=0.0.0.0
set CAMERETTA_ADMIN_TOKEN=una-password-lunga
python server.py
```

## Password per l'admin (facoltativa)

Il server ascolta solo su `127.0.0.1`, quindi è raggiungibile solo dal tuo PC. Se vuoi comunque una password:

```bash
CAMERETTA_ADMIN_TOKEN=lamiapassword python server.py
```

## Pubblicare il sito

- **Con il server** (VPS, Render, Railway…): carica tutta la cartella e avvia `server.py` con `CAMERETTA_HOST=0.0.0.0` e una `CAMERETTA_ADMIN_TOKEN`.
- **Windows + Caddy**: il sito è **www.cristianobattini.com**; il `Caddyfile` incluso fa già HTTPS, rimanda `cristianobattini.com` → `www` e usa `encode zstd gzip` nel blocco del sito, così il file `index.wasm` del gioco Godot (~40 MB) viaggia compresso (~9 MB). `server.py` registra già i tipi `.wasm` e `.pck`, che Windows a volte non conosce.
- **Solo statico**: esporta `data.json` dall'admin (Backup), mettilo in `cameretta-godot/assets/data/` prima dell'export (o in `public/classic/` per la versione HTML). Se il server non risponde, il gioco usa quella copia.

## Ripristinare i contenuti

- **`importa-backup.bat`** (sul server, con il servizio acceso): senza argomenti importa `contenuti.json`, cioè progetti, elaborati, appunti, libri, percorso e bolle originali. Puoi anche trascinarci sopra un backup scaricato dall'admin. Chiede se importare tutto o solo le impostazioni.
- Oppure dall'admin: scheda **Backup → Importa un backup**.
- Ogni importazione salva prima una copia del database in `data/backup-AAAAMMGG-HHMMSS.db`.

## Struttura

```
server.py              API + database (FastAPI, SQLite)
public/game/           il gioco Godot esportato per il Web (index.html, .wasm, .pck…)
public/classic/        la versione HTML/CSS/JS precedente (nessuna build)
  game.js              scene, omino, bolle, pannelli, lingue
  audio.js             tutti gli effetti sonori sintetizzati
  assets/street_*.png  strada a tre livelli di parallasse (+ street.json)
  assets/living.png    salotto (+ living.json con le zone animate)
  assets/player.png    l'omino: 4 frame da fermo + 6 di camminata
  assets/room.png      stanza 320×200
  assets/mask.png      maschera degli oggetti (canale R: 1 letto, 2 scrivania, 3 lavagna, 4 libreria, 5 finestra)
  assets/anim.json     posizioni di lucine, stelle, tazza, lampada
  assets/menu_sky.png  cielo del menu
public/admin/          dashboard admin
tools/                 script Python che generano stanza, maschera e cielo
data/                  database e file caricati (creata al primo avvio)
```

## Rigenerare la grafica

```bash
cd tools
pip install numpy pillow
python export_assets.py     # cameretta: room_v3.png, mask.png, anim.json, menu_sky.png…
python build_street.py      # strada: street_far/mid/near.png, street.json
python build_living.py      # salotto: living.png, living.json
python build_player.py      # omino: player.png, player.json
```

Poi copia i file in `public/game/assets/` (`room_v3.png` → `room.png`).
