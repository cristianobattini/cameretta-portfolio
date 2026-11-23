# La cameretta — versione Godot

CRI's CAMERETTA, il portfolio di Cristiano Battini come gioco in pixel art, rifatto in **Godot 4.7** (GDScript, renderer *Compatibility*, export Web).
I contenuti arrivano sempre dal server FastAPI del portfolio (`/api/public`): la dashboard admin resta quella di prima.

## Cosa c'è

- **Caricamento** stile gioco (sfondo sfocato, barra, suggerimenti) → **menu** sul cielo stellato (la finestra accesa porta dritto in cameretta).
- **Strada innevata** con parallasse, neve, lampioni, fumo dal comignolo, respiro nel freddo e bolle che si scrivono con il suono dei tasti.
- **Salotto**: camino che fuma e scoppietta, TV con 4 canali, lucine, pendolo, porta luminosa.
- **Cameretta** con **due modalità**, scelte al primo avvio e cambiabili nelle Impostazioni:
  - **Cammina**: l'omino si muove sul pavimento in prospettiva (frecce/WASD, oppure tocca un punto o un oggetto) e con **E** apri l'oggetto vicino;
  - **Punta e clicca**: passa sopra gli oggetti e cliccali (frecce + Invio da tastiera).
  La modalità attiva è **sempre indicata**: badge in alto nell'HUD (cliccabile per cambiarla) e nel menu.
- **Bonus, il giro in Vespa**: a metà strada un sentiero scende al mare. Casco, tre pedalate e via sul lungomare innevato, da Rosignano verso Pisa, dalla notte all'alba. Cinque capitoli (uno per oggetto della cameretta) e una tappa per ogni voce dell'admin: spunta dalla neve e ci si ferma a guardarla. Una volta scoperto compare nel menu.
- **Formato 16:9** (come 1920×1080): sugli schermi più larghi il gioco resta centrato, con due bande ai lati.
- **Schede delle sezioni** che scorrono con rotella, trascinamento e dito (provato su telefono emulato).
- **Impostazioni**: lingua EN/IT, audio on/off, modalità cameretta, volume musica ed effetti (salvati nel browser).
- **Telefono in verticale**: barra in alto, mondo ingrandito che segue l'omino, riquadro grande per le bolle, pulsanti ◀ ▶ ★, elenco degli oggetti sotto la cameretta.
- Link diretti: `#strada`, `#lungomare`, `#salotto`, `#stanza`, `#scrivania`, `#finestra`, …

## Aprire e modificare

1. Scarica **Godot 4.7.x standard** (non .NET) da godotengine.org.
2. *Import* → scegli `project.godot`.
3. Avvia il server del portfolio (`python server.py`): premendo ▶ nell'editor il gioco legge i contenuti da `http://127.0.0.1:8000` (si cambia con la variabile d'ambiente `CAMERETTA_URL`). Senza server usa la copia `assets/data/data.json`.

Dove mettere le mani:

| File | Cosa contiene |
|---|---|
| `scripts/main.gd` | regia: layout, HUD, menu, schede, impostazioni, input, transizioni |
| `scripts/g.gd` | testi EN/IT, dati dal server, preferenze salvate |
| `scripts/sfx.gd` | suoni, bus audio (Music, Ambience, Steps, SFX), ambiente per scena |
| `scripts/street.gd`, `living.gd`, `room.gd`, `menu.gd` | le quattro scene (disegnate a 320×200) |
| `scripts/sea.gd` | il giro in Vespa: luoghi, tappe, guida, cielo (testi in `g.gd`: `rideStory`, `rideIntro`, `rideEnd`…) |
| `scripts/player.gd` | l'omino (animazione, passi, ombra, scala in prospettiva) |
| `scripts/panels.gd` | contenuto delle schede (card, timeline, libreria, lavagna) |
| `scripts/ui.gd` | font, riquadri pixel, pulsanti, icone |
| `assets/img`, `assets/data` | pixel art e coordinate (generate dai tool del portfolio) |
| `sounds/` | effetti (vedi CREDITS.md) — rigenerabili con `tools/build_sounds.py` |

## Esportare per il sito

1. In Godot: *Editor → Manage Export Templates → Download and Install* (una volta sola).
2. *Project → Export → Web → Export Project* → `build/web/index.html` (il preset è già pronto: senza thread, quindi non servono header speciali).
3. Copia **tutto** il contenuto di `build/web/` in `cameretta-portfolio/public/game/` sul server Windows (sovrascrivi).
4. Riavvia il servizio solo se hai cambiato `server.py`; per il gioco basta ricaricare la pagina.

Da riga di comando: `godot --headless --export-release "Web" build/web/index.html`.

Il file `index.wasm` pesa ~40 MB non compresso (~9 MB con gzip): nel `Caddyfile` aggiungi `encode zstd gzip` dentro il blocco del sito.

## Prove automatiche

`CAMERETTA_TOUR=/cartella godot --path .` fa il giro del gioco e salva gli screenshot (`CAMERETTA_SIZE=1920x1080` per la finestra). Con `CAMERETTA_RIDE=it` fa solo il giro in Vespa, con `CAMERETTA_RIDE=check` esegue i controlli.

Pixel art e suoni del lungomare si rigenerano con `tools/build_sea.py` (nella cartella del portfolio) e `cameretta-godot/tools/build_sea_sounds.py`.

## Contenuti offline

Prima di esportare puoi aggiornare `assets/data/data.json` con quello scaricato dall'admin (Backup → data.json): è la copia usata quando il server non risponde.

## Prove automatiche

`CAMERETTA_TOUR=/cartella CAMERETTA_RIDE=<prova> godot --path cameretta-godot`, con `<prova>` = `check` (giro in Vespa), `menu` (menu, citazioni, schermo intero), `shop` (negozio; con `CAMERETTA_URL` compra su un server di prova), `grove` (templi).
