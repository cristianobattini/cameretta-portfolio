# Un portfolio che si gioca

### Tutorial passo passo: pixel art, FastAPI, Godot e messa online su Windows

> Questo tutorial ricostruisce, nell'ordine in cui conviene farle, tutte le scelte dietro **La cameretta**: un portfolio personale che si esplora come un piccolo videogioco 2D. Dal menu sotto il cielo stellato si passa a una strada innevata e a un salotto, poi alla cameretta, dove ogni oggetto apre una sezione del portfolio. Ogni capitolo ha una parte **"Fallo"** (i passi pratici) e una parte **"Approfondimento"** (il perché, le alternative, gli errori da evitare). Il codice è quello vero del progetto, a volte accorciato.

---

## Indice

0. [L'idea e l'architettura](#0-lidea-e-larchitettura)
1. [Strumenti (tutti gratuiti)](#1-strumenti-tutti-gratuiti)
2. [Progettare il gioco prima del codice](#2-progettare-il-gioco-prima-del-codice)
3. [La pixel art generata con Python](#3-la-pixel-art-generata-con-python)
4. [La maschera degli oggetti cliccabili](#4-la-maschera-degli-oggetti-cliccabili)
5. [Lo sprite dell'omino](#5-lo-sprite-dellomino)
6. [Il backend: FastAPI + SQLite](#6-il-backend-fastapi--sqlite)
7. [La dashboard admin](#7-la-dashboard-admin)
8. [Il gioco in Godot: struttura del progetto](#8-il-gioco-in-godot-struttura-del-progetto)
9. [Disegnare a 320×200: SubViewport, livelli e luci](#9-disegnare-a-320200-subviewport-livelli-e-luci)
10. [Le scene: menu, strada, salotto](#10-le-scene-menu-strada-salotto)
11. [La cameretta: punta e clicca e modalità cammina](#11-la-cameretta-punta-e-clicca-e-modalità-cammina)
12. [Interfaccia: HUD, schede che scorrono, impostazioni](#12-interfaccia-hud-schede-che-scorrono-impostazioni)
13. [Telefono, tablet e schermi diversi](#13-telefono-tablet-e-schermi-diversi)
14. [Due lingue](#14-due-lingue)
15. [Il suono](#15-il-suono)
16. [Esportare per il web](#16-esportare-per-il-web)
17. [Mettere online su Windows (Azure + Aruba)](#17-mettere-online-su-windows-azure--aruba)
18. [Testare senza cliccare a mano](#18-testare-senza-cliccare-a-mano)
19. [Errori che abbiamo incontrato davvero](#19-errori-che-abbiamo-incontrato-davvero)
20. [Idee per andare oltre](#20-idee-per-andare-oltre)

---

## 0. L'idea e l'architettura

Un portfolio classico è una pagina con delle sezioni. Qui le sezioni diventano **oggetti di una stanza**:

| Oggetto   | Sezione                          |
|-----------|----------------------------------|
| Finestra  | Percorso e CV                    |
| Scrivania | Progetti di programmazione       |
| Lavagna   | Appunti di fisica e materiale    |
| Libreria  | Libri e attestati                |
| Letto     | Articoli ed elaborati personali  |

Il percorso del visitatore è una piccola storia: **menu → strada → salotto → cameretta**. Lungo la strada delle bolle di testo raccontano chi sei. Chi ha fretta può saltare direttamente in cameretta.

### Architettura

```
                ┌───────────────────────── server Windows ─────────────────────────┐
 browser ──443──►  Caddy (HTTPS automatico)  ──►  FastAPI (uvicorn, 127.0.0.1:8000)│
                │                                   ├─ /api/public   contenuti      │
                │                                   ├─ /api/*        admin (token)  │
                │                                   ├─ /game/        gioco Godot    │
                │                                   ├─ /admin/       dashboard      │
                │                                   └─ /uploads/     file caricati  │
                │                                SQLite: data/cameretta.db          │
                └───────────────────────────────────────────────────────────────────┘
```

**Le tre idee guida**

1. **Separare contenuti e gioco.** Il gioco non contiene testi del portfolio: li chiede a `/api/public`. Per cambiare un progetto apri la dashboard, non Godot.
2. **Tutto sostituibile.** Lo sfondo del menu, l'immagine della stanza, la musica, il CV e le copertine si scelgono dalla dashboard con un selettore di file.
3. **Fallback offline.** Se il server non risponde, il gioco usa una copia `data.json` inclusa al momento dell'export.

> **Approfondimento — perché non un sito statico?** Un sito statico sarebbe più semplice da ospitare, ma ogni modifica richiederebbe di rifare la build. Con un database locale e una dashboard aggiorni il portfolio dal telefono in trenta secondi. Il fallback `data.json` ti lascia comunque la possibilità di pubblicare solo i file statici.

---

## 1. Strumenti (tutti gratuiti)

| A cosa serve | Strumento |
|---|---|
| Motore di gioco | **Godot 4.7** standard (GDScript, non .NET) |
| Backend | **Python 3.12+**, FastAPI, uvicorn, SQLite (incluso in Python) |
| Generare la grafica | Python + **NumPy** + **Pillow** |
| Ritocchi a mano (facoltativo) | **Pixelorama** o **LibreSprite** |
| Suoni | pacchetti **CC0** (Kenney, Ben Burnes…) + **ffmpeg** |
| Font | **Pixelify Sans**, **VT323**, Noto Symbols (licenza OFL) |
| Server | Windows + **NSSM** (servizi) + **Caddy** (HTTPS) |
| Test | **Xvfb** (schermo virtuale), **Playwright** + Chrome |

```bash
pip install fastapi uvicorn python-multipart numpy pillow
```

> **Approfondimento — perché Godot?** La prima versione era in HTML/JS con un `<canvas>`: è leggera e non richiede build, ma ogni effetto (luci, particelle, scorrimento touch, audio) va scritto a mano. Godot ti dà gratis i nodi di interfaccia, l'audio a bus, le animazioni con `Tween`, l'export web e soprattutto un editor in cui vedere le scene. Il prezzo è un file `.wasm` da circa 40 MB, che con gzip scende a circa 9 MB.

---

## 2. Progettare il gioco prima del codice

**Fallo**

1. **Scegli la risoluzione logica.** Qui è **320×200** (16:10, come un vecchio PC). Tutto il mondo vive in questa griglia e viene ingrandito a pixel netti.
2. **Scegli la palette.** Pochi colori, scelti una volta e usati ovunque:

   ```
   notte   #0f0f26   inchiostro #1a1733   pannello #221d3d
   crema   #f6e9c8   oro        #f2b85b   terracotta #d97a4b
   salvia  #a3bb8c   cielo      #8fb2ee   lavanda    #c9c3e6
   ```
3. **Disegna la mappa del percorso** su carta: le scene, cosa si fa in ognuna, come si esce.
4. **Scrivi i testi delle bolle** prima di programmare: sono la tua presentazione, ed è più facile scriverli quando non sei immerso nel codice.

> **Approfondimento — la prospettiva.** Per la stanza abbiamo provato una vista dall'alto 3/4 e poi una **vista frontale dalla porta verso la finestra**. La seconda è più "cinematografica": il punto di fuga al centro porta l'occhio verso la finestra stellata. In compenso complica la camminata, perché il pavimento è un trapezio (vedi §11).

> **Approfondimento — "cozy" vs "punk".** I primi tentativi avevano colori saturi e contrasti forti. Per un'atmosfera accogliente: luci calde (lampada, lucine, camino) su ombre blu-viola, saturazione media e niente nero puro (l'inchiostro `#1a1733` è un blu molto scuro).

---

## 3. La pixel art generata con Python

Non serve saper disegnare: la grafica si può **generare** con del codice e poi ritoccare a mano.

### 3.1 Le basi

```python
import numpy as np
from PIL import Image

W, H = 320, 200
img = np.zeros((H, W, 3), np.uint8)

def rect(x0, y0, x1, y1, col):
    img[y0:y1, x0:x1] = col

rect(0, 0, W, H, (15, 15, 38))          # cielo notturno
Image.fromarray(img).save("bozza.png")
Image.fromarray(img).resize((W*4, H*4), Image.NEAREST).save("bozza_x4.png")  # per guardarla
```

Ingrandisci **sempre** con `NEAREST`: qualsiasi altro filtro sfoca i pixel.

### 3.2 La stanza in prospettiva (raycasting "al contrario")

Per ogni pixel dello schermo calcoli quale superficie della stanza (pavimento, soffitto o pareti) vede la telecamera e a quale distanza:

```python
# telecamera sulla porta, che guarda verso la finestra
for y in range(H):
    for x in range(W):
        dx = (x - W/2) / FOCALE
        dy = (y - ORIZZONTE) / FOCALE
        # intersezione del raggio (dx, dy, 1) con i piani della stanza
        t_pav = ALTEZZA_OCCHI / dy if dy > 0 else 1e9
        t_sx  = -MEZZA_LARGH / dx if dx < 0 else 1e9
        ...
        t = min(t_pav, t_sof, t_sx, t_dx, t_fondo)
        # colore = materiale della superficie colpita × luce(t)
```

Poi i mobili si "proiettano" come scatole: si calcolano gli 8 vertici e si riempiono le facce.

### 3.3 I trucchi che fanno la differenza

- **Dithering di Bayer.** Le sfumature (luce della lampada, cielo) diventano retinature a scacchi invece di gradienti lisci:

  ```python
  BAYER4 = np.array([[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]) / 16
  def dither(v, x, y, livelli=4):          # v in 0..1
      return np.floor(v * livelli + BAYER4[y % 4, x % 4]) / livelli
  ```
- **Contorni da 1 pixel** attorno agli oggetti, ottenuti confrontando la maschera con se stessa spostata di un pixel (vedi §5).
- **Texture procedurali**: venature del legno con `sin(x*0.3 + rumore)`, righe dei libri con colori pescati dalla palette, fogli di fisica sul pavimento come piccoli rettangoli con righe.
- **Luce additiva**: calcola una mappa della luce (lampada, finestra) e moltiplica i colori, ma quantizzala con il dithering.

### 3.4 Strada e salotto a livelli (parallasse)

La strada è composta da **tre immagini**: `far` (512 px, colline e stelle), `mid` (896 px, case lontane) e `near` (1600 px, la strada vera). Si muovono a velocità diverse:

```
x_far  = -camera * 0.15
x_mid  = -camera * 0.45
x_near = -camera
```

Accanto a ogni immagine salva un **JSON con le coordinate** delle cose animate: lampioni, finestre accese, comignolo, porta di casa, altezza dei piedi. Il gioco legge quei numeri invece di averli scritti nel codice:

```json
{"world": 1600, "feet": 168, "start": 36, "door": {"x": 1488, "y": 104},
 "chimney": {"x": 1554, "y": 30}, "lamps": [{"x": 110, "y": 64}, ...]}
```

> **Approfondimento — generare vs disegnare.** Generare ti permette di cambiare idea (porta a destra, letto più lungo) rieseguendo uno script. Il limite sono i dettagli "umani" (il gatto sul divano, le pieghe della tenda): lì conviene un passaggio a mano in Pixelorama, sopra il PNG generato.

---

## 4. La maschera degli oggetti cliccabili

Come fa il gioco a sapere che hai cliccato la lavagna? Con una seconda immagine, **mask.png**, grande quanto la stanza. Nel canale rosso ogni pixel contiene il numero dell'oggetto:

```
0 = niente   1 = letto   2 = scrivania   3 = lavagna   4 = libreria   5 = finestra
```

**Fallo**: mentre generi la stanza, ogni volta che disegni un pixel di un oggetto scrivi anche nella maschera:

```python
mask[y, x] = 3   # questo pixel appartiene alla lavagna
```

Nel gioco, al primo avvio, dalla maschera ricavi tre cose per ogni oggetto:

1. il **riquadro** (x0, y0, x1, y1) e il **centro** (la mediana delle x, più robusta della media);
2. un'immagine **"dim"** che scurisce tutto *tranne* l'oggetto;
3. un'immagine **"ring"** con il contorno chiaro attorno all'oggetto.

Al passaggio del mouse disegni dim + ring sopra la stanza e l'oggetto "si accende". È un effetto da avventura grafica che costa pochissimo.

```gdscript
# room.gd (estratto): un solo passaggio su tutti i pixel
for y in 200:
    for x in 320:
        var v := mask[y * 320 + x]
        if v < 1 or v > 5: continue
        dimg[v].set_pixel(x, y, Color(0, 0, 0, 0))        # buco nello scurimento
        for dy in range(-1, 2):
            for dx in range(-1, 2):
                var xx := x + dx; var yy := y + dy
                if xx >= 0 and yy >= 0 and xx < 320 and yy < 200 and mask[yy * 320 + xx] != v:
                    rimg[v].set_pixel(xx, yy, ring)          # bordo luminoso
```

> **Approfondimento — prestazioni.** La prima versione, per ogni oggetto, controllava i vicini di *tutti* i 64.000 pixel: 5 × 64.000 × 9 controlli in GDScript, cioè secondi di attesa nel browser. Rovesciando il ciclo (si parte dai pixel *dell'oggetto* e si marcano i vicini) si scende a qualche decina di migliaia di operazioni.

> **Approfondimento — stanza personalizzata.** Dalla dashboard puoi caricare un'altra immagine della stanza **e** la sua maschera. Basta che la maschera usi gli stessi numeri: anche un disegno fatto a mano diventa subito cliccabile.

---

## 5. Lo sprite dell'omino

Felpa nera, sciarpa rossa, pantaloni larghi, sneakers bianche. Un'unica immagine orizzontale con **10 frame**: 4 da fermo (respiro) e 6 di camminata.

```
player.png   [idle0][idle1][idle2][idle3][walk0]...[walk5]
player.json  {"fw": 30, "fh": 53, "idle": [0,1,2,3], "walk": [4,...,9], "footY": 48}
```

**Fallo**

1. Disegna l'omino rivolto a **destra**; per andare a sinistra il gioco lo specchia.
2. La camminata è un ciclo sinusoidale: piede vicino e piede lontano in opposizione di fase, braccia al contrario delle gambe, il corpo che si abbassa di un pixel quando i piedi si incrociano.

   ```python
   ph = i / 6 * 2 * math.pi
   piede_vicino  = round(3.2 * math.sin(ph))
   piede_lontano = -piede_vicino
   braccio       = round(-2.2 * math.sin(ph))
   ```
3. Disegna **prima ciò che sta dietro** (braccio e gamba lontani, coda della sciarpa), poi il corpo, poi ciò che sta davanti.
4. Alla fine aggiungi il contorno:

   ```python
   m = alpha > 0
   bordo = (roll(m, 1, 0) | roll(m, -1, 0) | roll(m, 1, 1) | roll(m, -1, 1)) & ~m
   img[bordo] = INCHIOSTRO
   ```

### Ingrandire uno sprite senza rovinarlo

Ci è stato chiesto un omino "un po' più grande, proporzionato, che non ostruisca la vista". Scalare l'immagine del 25% nel motore produce pixel irregolari. La soluzione è **rigenerarlo**: il generatore disegna su una griglia logica 24×42 e ogni "pixel logico" riempie un blocco di 1 o 2 pixel reali, senza buchi. Il contorno, calcolato dopo, resta di 1 pixel netto.

```python
S = 1.25
def p(x, y, c):
    x0, x1 = floor(x*S), max(floor(x*S) + 1, floor((x+1)*S))
    y0, y1 = floor(y*S), max(floor(y*S) + 1, floor((y+1)*S))
    img[y0:y1, x0:x1] = c
```

Nella cameretta, dove la stanza è in prospettiva, l'omino viene poi rimpicciolito con la profondità (§11).

> **Approfondimento — i passi a tempo.** Il suono del passo parte quando il frame della camminata è il 2 o il 5, cioè quando un piede tocca terra. Così suono e animazione restano sincronizzati a qualsiasi velocità (camminata o corsa).

---

## 6. Il backend: FastAPI + SQLite

### 6.1 Lo schema

```sql
settings (key TEXT PRIMARY KEY, value TEXT)            -- testi del menu, URL, volumi, colori…
sections (id TEXT PRIMARY KEY, object_name, sign_label, title, intro, color,
          sort, visible, object_name_en, sign_label_en, title_en, intro_en,
          link_url, link_label, link_label_en)
items    (id INTEGER PRIMARY KEY, section_id, grp, kicker, title, description,
          tags, url, link_label, image, status, sort, visible, updated_at,
          grp_en, kicker_en, title_en, description_en, link_label_en, status_en)
bubbles  (id INTEGER PRIMARY KEY, kind, text, text_en, author, sort, visible)
assets   (id INTEGER PRIMARY KEY, filename, original_name, mime, size, label, created_at)
```

**La scelta chiave per le due lingue**: ogni campo testuale ha un gemello `_en`. Il gioco usa `title_en` se la lingua è inglese e il campo non è vuoto, altrimenti `title`. Niente tabelle di traduzione, niente complicazioni.

### 6.2 Migrare senza perdere dati

Quando aggiungi una colonna a un database che esiste già:

```python
def init_db():
    con.executescript(SCHEMA)                         # CREATE TABLE IF NOT EXISTS ...
    for table, cols in EXTRA.items():                 # colonne aggiunte dopo
        have = {r[1] for r in con.execute(f"PRAGMA table_info({table})")}
        for name, decl in cols:
            if name not in have:
                con.execute(f"ALTER TABLE {table} ADD COLUMN {name} {decl}")
```

### 6.3 Gli endpoint

```python
@app.get("/api/public")                         # unico endpoint usato dal gioco
def public_data():
    return {"settings": ..., "sections": [... con items visibili ...], "bubbles": ...}

def require_admin(x_admin_token: Optional[str] = Header(default=None)):
    token = os.environ.get("CAMERETTA_ADMIN_TOKEN", "")
    if token and x_admin_token != token:
        raise HTTPException(401)

@app.put("/api/items/{iid}", dependencies=[Depends(require_admin)])
def update_item(iid: int, body: ItemIn): ...
```

Poi gli upload (`POST /api/assets` multipart, limite 25 MB, solo estensioni ammesse, nome file casuale) e l'export di tutto in JSON.

### 6.4 I file statici

```python
mimetypes.add_type("application/wasm", ".wasm")   # Windows a volte non lo conosce!
mimetypes.add_type("application/octet-stream", ".pck")

app.mount("/uploads", StaticFiles(directory=UPLOADS))
app.mount("/game",    StaticFiles(directory=PUBLIC / "game", html=True))
app.mount("/admin",   StaticFiles(directory=PUBLIC / "admin", html=True))
```

> **Approfondimento — sicurezza minima ma seria.**
> - Il server ascolta su **127.0.0.1**: dall'esterno ci arriva solo Caddy.
> - Il token admin sta in una **variabile d'ambiente**, mai nel codice e mai incollato in una chat.
> - Gli URL che arrivano dal database passano da un controllo (`http(s)://`, `/`, `mailto:`), così nessuno può infilare un `javascript:`.
> - Non si cancella un file caricato se è ancora usato da una voce (risposta 409).

---

## 7. La dashboard admin

Volutamente **senza pixel art**: è uno strumento, deve essere chiara. Un solo `index.html` con JavaScript puro e cinque schede:

1. **Generale**: testi del menu (IT/EN affiancati), link, email, colore d'accento, lingua predefinita, cursori dei volumi (ambiente, passi, musica).
2. **Sezioni e voci**: per ogni oggetto il titolo, l'introduzione e un link; per ogni voce gruppo, occhiello, titolo, descrizione, tag, link, immagine e stato. L'ordine si cambia con le frecce.
3. **Strada**: le bolle (presentazione o citazione con autore).
4. **File**: libreria dei file caricati, con ricerca.
5. **Backup**: export JSON e `data.json` per l'uso offline.

**Il selettore di file** è il pezzo più utile: ogni campo "immagine/musica/CV" ha tre pulsanti, *Scegli dal PC…*, *Dalla libreria…* e *Togli*. "Scegli dal PC" carica il file e compila il campo in un colpo solo.

> **Approfondimento — errori da HTML.** Un `<form>` dentro un altro `<form>` viene ignorato dal browser senza avvisare. Le finestre di modifica usano quindi dei `div` e raccolgono i campi a mano. E la libreria dei file è una finestra separata, per non sovrascrivere quella della voce che stai modificando.

---

## 8. Il gioco in Godot: struttura del progetto

```
cameretta-godot/
  project.godot          renderer Compatibility (WebGL2), finestra 1280×800
  main.tscn              un solo nodo Control con main.gd
  scripts/
    g.gd        (autoload "G")    testi, dati dal server, preferenze salvate
    sfx.gd      (autoload "Sfx")  suoni e bus audio
    main.gd     regia: layout, HUD, menu, schede, input, transizioni
    menu.gd, street.gd, living.gd, room.gd    le quattro scene
    player.gd   l'omino      layer.gd   livelli di disegno (anche additivi)
    ui.gd       font e mattoncini UI      panels.gd   contenuto delle schede
  assets/img, assets/data, sounds/, fonts/, licenses/
```

**Fallo**

1. Crea il progetto scegliendo il renderer **Compatibility**: è l'unico che va nel browser su tutti i dispositivi.
2. In *Project Settings → Autoload* aggiungi `g.gd` come `G` e `sfx.gd` come `Sfx`. Sono raggiungibili da qualsiasi script.
3. Imposta `rendering/textures/canvas_textures/default_texture_filter = Nearest`.

> **Approfondimento — scene in codice o nell'editor?** Qui quasi tutto è costruito **in codice** (`Button.new()`, `add_child`…). È più facile da leggere in un tutorial, da confrontare con git e da verificare in automatico. Per scene molto "visive" (posizionare a mano un albero, una luce) l'editor resta più comodo: puoi mescolare i due approcci.

### Caricare i dati

```gdscript
func fetch_json(path: String):
    var http := HTTPRequest.new()
    add_child(http)
    http.request(base_url + path)
    var res = await http.request_completed        # [result, code, headers, body]
    http.queue_free()
    return JSON.parse_string(res[3].get_string_from_utf8()) if res[1] == 200 else null
```

Nel browser l'indirizzo del server è quello della pagina stessa:

```gdscript
base_url = str(JavaScriptBridge.eval("location.origin", true)) if OS.has_feature("web") \
           else "http://127.0.0.1:8000"
```

Le immagini caricate dall'admin si scaricano come byte e diventano texture:

```gdscript
var img := Image.new()
if img.load_png_from_buffer(b) != OK and img.load_jpg_from_buffer(b) != OK:
    img.load_webp_from_buffer(b)
var tex := ImageTexture.create_from_image(img)
```

---

## 9. Disegnare a 320×200: SubViewport, livelli e luci

### 9.1 Pixel netti a qualsiasi dimensione

Il mondo viene disegnato in un **SubViewport 320×200**. La sua texture viene poi mostrata da un `TextureRect` ingrandito con filtro *nearest*. L'interfaccia invece sta fuori, a risoluzione piena, così i testi restano nitidi.

```gdscript
sv = SubViewport.new()
sv.size = Vector2i(320, 200)
sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
view = TextureRect.new()
view.texture = sv.get_texture()
view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
```

**Scala intera quando possibile**: se lo schermo permette un ingrandimento intero (×4, ×5) che occupa almeno l'88% dello spazio, usalo e accetta un bordo. Altrimenti usa una scala frazionaria.

### 9.2 Il "palco" per l'interfaccia legata al mondo

Bolle, cartelli e scritte "premi E" devono seguire oggetti del mondo, ma con testo nitido. Il trucco: un `Control` di 1280×800 (cioè il mondo ×4) posizionato e scalato esattamente sopra la vista. Dentro si ragiona in "coordinate ×4":

```gdscript
stage.position = world_rect.position
stage.scale = Vector2.ONE * (world_rect.size.x / 1280.0)
bolla.position = Vector2(x_mondo * 4 - 60 - camera * 4, top)
```

### 9.3 Livelli e luci additive

Ogni scena è fatta di tre livelli: **base** (sfondo, fuoco, TV), **luci** (somma additiva) e **sopra** (scintille, omino).

```gdscript
static func make(parent, f: Callable, additive := false) -> Layer:
    var l := Layer.new(); l.fn = f
    if additive:
        var m := CanvasItemMaterial.new()
        m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        l.material = m
    parent.add_child(l)
    return l
```

Gli aloni sono una sola `GradientTexture2D` radiale (bianco → trasparente), disegnata più grande o più piccola e colorata con `modulate`. Fuoco, lampade, TV e porta luminosa usano tutti la stessa texture.

> **Approfondimento — perché `_draw()` e non nodi Sprite?** Molti effetti sono "pixel per pixel": il fuoco (colonne di altezza sinusoidale colorate per fasce), la neve statica della TV, le stelle che brillano. In `_draw()` li scrivi come in un canvas, ridisegnando ogni frame. A 320×200 il costo è trascurabile.

---

## 10. Le scene: menu, strada, salotto

### 10.1 Menu

- Il cielo è un PNG con le stelle salvate in un JSON: ogni stella brilla con `sin(t + i*1.7)`.
- Ogni tanto passa una **stella cadente** (una scia di 10 pixel che sfuma).
- La **finestra accesa** tremola ed è cliccabile: porta dritto in cameretta con uno zoom (un `Tween` sulla scala della vista).
- Le voci del menu si scelgono con ↑/↓ e Invio oppure con il mouse; la voce selezionata è in oro con il triangolino.

### 10.2 Strada

```gdscript
camera = clamp(P.x - 120, 0, mondo - 320)      # l'omino sta a 120 px da sinistra
```

- **Neve su due piani**: fiocchi piccoli e lenti dietro le case vicine, grandi e veloci davanti all'omino. Si spostano anche con la telecamera, il che rafforza la parallasse.
- **Fumo dal comignolo** e **respiro nel freddo**: particelle semplici (posizione, velocità, alpha che cala).
- **Bolle "macchina da scrivere"**: quando l'omino si avvicina, il testo appare lettera per lettera. Le pause dipendono dalla punteggiatura e ogni carattere fa suonare un tasto.

  ```gdscript
  B.t += 0.22 if ".!?".contains(ch) else 0.12 if ",;:".contains(ch) else randf_range(0.024, 0.046)
  ```
- **Davanti alla porta** compare "[E] Entra in casa": un pulsante sul palco che si può anche toccare.

### 10.3 Salotto

Tre punti di interesse, ognuno con un'azione: **TV** (cambia canale tra tramonto, telegiornale, neve statica e pong), **camino** (scaldati le mani, con una pioggia di scintille) e **porta luminosa** (in cameretta). Si mostra il prompt del punto più vicino, entro 20 pixel.

> **Approfondimento — game feel a costo zero.** Sono i dettagli a rendere vivo un ambiente: il pendolo, il vapore dalla tazza, le lucine che si accendono a onda, il bagliore della TV che cambia colore con il canale, il volume del camino che sale quando ti avvicini. Ognuno è fatto di 3-5 righe di codice.

---

## 11. La cameretta: punta e clicca e modalità cammina

La cameretta offre **due modi di esplorare**. Il visitatore sceglie al primo avvio, può cambiare nelle Impostazioni, e la modalità attiva è **sempre indicata** con un'etichetta in alto (cliccabile per passare all'altra).

### 11.1 Punta e clicca

- Il passaggio del mouse legge la maschera e accende l'oggetto (§4).
- Appare un **cartello di legno** sopra l'oggetto (nome + etichetta).
- I **segnalini a rombo** indicano gli oggetti: oro = da vedere, verde = già visto.
- Da tastiera: ←/→ passano da un oggetto all'altro, Invio apre.

### 11.2 Modalità cammina: il pavimento in prospettiva

Il pavimento visto dalla porta è un **trapezio**: stretto in fondo, largo davanti. Lo descrivi con due funzioni della profondità `y`:

```gdscript
const FY0 := 140.0   # fondo (vicino alla finestra)
const FY1 := 196.0   # davanti (vicino a chi guarda)

static func floor_x(y):        # limiti sinistro e destro del pavimento a quella y
    var t := clampf((y - FY0) / (FY1 - FY0), 0, 1)
    return Vector2(lerpf(128, 66, t), lerpf(190, 202, t))

static func depth(y):          # quanto è grande l'omino a quella y
    return lerpf(0.56, 0.86, clampf((y - FY0) / (FY1 - FY0), 0, 1))
```

- **Movimento**: ←/→ in larghezza, ↑/↓ in profondità. La velocità si scala con `depth` e quella in profondità è ridotta, perché in fondo un pixel "vale" più distanza.
- **Punto d'appoggio** di ogni oggetto: davanti al suo riquadro, riportato dentro il trapezio.
- **Oggetto vicino** (meno di 26 px): si accende e compare "[E] Apri: Lavagna".
- **Cliccare un oggetto** fa camminare l'omino fino a lì e apre la scheda all'arrivo (una `Callable` salvata come "cosa fare all'arrivo").

> **Approfondimento — non coprire la scena.** In modalità cammina l'omino non deve nascondere gli oggetti. Per questo la scala massima è 0.86 e non 1. E in modalità punta e clicca l'omino non compare proprio.

---

## 12. Interfaccia: HUD, schede che scorrono, impostazioni

### 12.1 Stile "pixel" con StyleBoxFlat

```gdscript
static func box(bg, border := Color(0,0,0,0), bw := 0, pad := 0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg; s.anti_aliasing = false
    if bw > 0: s.border_color = border; s.set_border_width_all(bw)
    s.content_margin_left = pad; ...
    return s
```

Il doppio bordo (crema dentro, inchiostro fuori) si ottiene con due `PanelContainer` uno dentro l'altro.

### 12.2 Le schede delle sezioni

Ogni scheda ha un'intestazione (icona pixel 12×12, occhiello, titolo, chiudi), un **ScrollContainer** con il contenuto e un piè di pagina con oggetto precedente, pallini di avanzamento e oggetto successivo. Il contenuto cambia a seconda della sezione:

- **Finestra**: il primo gruppo è una *timeline* (data | titolo + descrizione).
- **Libreria**: il primo gruppo è uno *scaffale* (copertine colorate o immagini).
- **Lavagna**: card verdi "di gesso" con cornice di legno.
- **Gli altri**: card in griglia (una colonna su telefono, tre su desktop).

**Lo scorrimento col dito funziona** se i figli dello ScrollContainer lasciano passare gli eventi:

```gdscript
label.mouse_filter = Control.MOUSE_FILTER_PASS
```

> **Approfondimento — il pannello che cresceva.** I `RichTextLabel` con `fit_content` e a capo automatico, al primo frame, credono di essere larghi pochi pixel e chiedono un'altezza enorme. Il `PanelContainer` si allarga e poi **non si restringe più**. Soluzione: ricordare il rettangolo voluto e reimporlo a ogni frame finché il layout non si stabilizza.

### 12.3 Impostazioni e preferenze

Lingua, audio, modalità della cameretta, volume della musica e degli effetti. Si salvano con `ConfigFile` in `user://` (nel browser finisce in IndexedDB) insieme agli oggetti già esplorati e al canale TV preferito.

### 12.4 Focus e tastiera

Tutti i pulsanti hanno `focus_mode = FOCUS_NONE`: altrimenti Invio e Spazio "premono" l'ultimo pulsante cliccato invece di fare l'azione di gioco. La tastiera viene gestita in un unico `_unhandled_input`, con una regola chiara per ogni scena.

---

## 13. Telefono, tablet e schermi diversi

Ci sono tre casi:

| Caso | Riconoscimento (pixel CSS) | Comportamento |
|---|---|---|
| Desktop | resto dei casi | mondo intero centrato, HUD sopra |
| Orizzontale basso | altezza < 520 | interfaccia compatta |
| Verticale | larghezza < 760 e altezza > larghezza | barra in alto, mondo ingrandito che segue l'omino, riquadro per le bolle, pulsanti ◀ ▶ ★, elenco degli oggetti |

**Densità di pixel**: nel browser Godot lavora a risoluzione fisica (un telefono ha `devicePixelRatio` 3). Si calcola un fattore e lo si assegna a `content_scale_factor`:

```gdscript
var dpr := DisplayServer.screen_get_scale()
var css := Vector2(get_window().size) / dpr
var f := css.x / 430.0 if portrait else clampf(min(css.x / 1280, css.y / 800), 0.62, 2.2)
get_window().content_scale_factor = f * dpr
```

**In verticale la telecamera segue**: il mondo è più largo dello schermo e si sposta (con un `lerp` morbido) per tenere al centro l'omino o l'oggetto selezionato.

> **Approfondimento — i font nel browser.** Sul tuo PC Godot usa i font di sistema per i caratteri mancanti (frecce, ★, ☰), nel browser **no**: vedresti dei quadratini. I font pixel non hanno questi simboli, quindi aggiungi un font di riserva *ridotto ai soli caratteri usati* (con `pyftsubset`, pochi kB). Nei test spegni il fallback di sistema per vedere ciò che vedrà il browser:
>
> ```gdscript
> pix.fallbacks = [load("res://fonts/SymbolsB.ttf"), load("res://fonts/SymbolsA.ttf")]
> pix.allow_system_fallback = false
> ```

---

## 14. Due lingue

- **Testi dell'interfaccia**: un dizionario `T = {"en": {...}, "it": {...}}` in `g.gd` e una funzione `t("chiave")`.
- **Contenuti**: i campi `_en` del database e una funzione `L(oggetto, "campo")`.
- **Cambio lingua**: un segnale `lang_changed` ricostruisce menu, HUD e la scheda aperta. Le bolle già lette vengono completate subito nella nuova lingua, senza riscriverle lettera per lettera.
- **Predefinita**: l'inglese (impostabile dall'admin). La scelta del visitatore viene ricordata.

I tasti nei testi si scrivono `[k]E[/k]` e diventano un riquadro crema con BBCode:

```gdscript
func kbd(s): return s.replace("[k]", "[bgcolor=#f6e9c8][color=#1a1733] ").replace("[/k]", " [/color][/bgcolor]")
```

---

## 15. Il suono

### 15.1 Bus separati

`Music`, `Ambience`, `Steps` e `SFX`, creati da codice. I volumi arrivano dall'admin (uno per tipo) e vengono moltiplicati per i cursori delle Impostazioni del visitatore.

### 15.2 Da dove vengono i suoni

Tutti **CC0** (pubblico dominio), quindi usabili senza obblighi. È buona educazione citarli comunque in `CREDITS.md`.

| Effetto | Fonte |
|---|---|
| passi su neve e legno, clic, tic, porte, pagine | Kenney (Impact, Interface, RPG Audio) |
| tasti della macchina da scrivere, raffiche di vento | Ben Burnes / Abstraction |
| schiocchi del camino | pacchetto CC0 "wood & metal" |

### 15.3 Preparare i file con uno script

`tools/build_sounds.py` decodifica con ffmpeg e lavora i suoni con NumPy:

- **taglia** il silenzio, **normalizza**, aggiunge **dissolvenze** di pochi millisecondi (evitano i "click");
- **filtra** (passa-basso sui passi sulla neve: più ovattati e meno fastidiosi);
- **costruisce il loop del camino**: un ruggito di rumore marrone filtrato, più schiocchi di legno veri posizionati a caso (processo di Poisson, ~4 al secondo, qualcuno a grappolo), con il loop che si richiude senza giunture perché gli schiocchi a cavallo della fine vengono "riavvolti" all'inizio.

### 15.4 L'ambiente per scena

- **Strada e menu**: niente fruscio continuo (stanca, "sembra un fiume"), solo **raffiche** ogni 7-14 secondi.
- **Salotto**: il camino e la TV cambiano volume con la distanza dell'omino; c'è il tic-tac del pendolo; il canale della TV decide se si sentono voci o statico.
- **Cameretta**: il camino attutito "attraverso il muro".

> **Approfondimento — passi che non annoiano.** Cinque varianti per superficie, scelte a caso, con volume e intonazione leggermente diversi ogni volta (`pitch_scale` tra 0.9 e 1.08). Il cervello non riconosce la ripetizione.

---

## 16. Esportare per il web

1. *Editor → Manage Export Templates → Download and Install* (una volta).
2. Preset **Web**, con **Thread Support disattivato**: così non servono gli header COOP/COEP, che su molti hosting sono un problema.
3. In *Resources → Filters* includi i file che non sono risorse Godot: `assets/data/*.json, licenses/*.txt`.
4. Esporta in `build/web/index.html` e copia tutto in `public/game/`.

```bash
godot --headless --export-release "Web" build/web/index.html
```

> **Approfondimento.** Metti un file vuoto `.gdignore` dentro `build/`: altrimenti Godot "importa" anche i file esportati e lascia in giro dei `.import`.

---

## 17. Mettere online su Windows (Azure + Aruba)

### 17.1 Python e servizio

1. Installa Python da python.org (**non** quello del Microsoft Store: dentro un servizio non funziona e il servizio resta in `SERVICE_PAUSED`).
2. Trova il percorso esatto con `py -0p`.
3. Crea un ambiente virtuale con *quel* Python e installa le dipendenze.
4. Crea il servizio con NSSM (usa il percorso completo, se `nssm` non è nel PATH):

   ```bat
   C:\nssm\win64\nssm.exe install Cameretta "C:\...\.venv\Scripts\python.exe" server.py
   C:\nssm\win64\nssm.exe set Cameretta AppDirectory "C:\...\cameretta-portfolio"
   C:\nssm\win64\nssm.exe set Cameretta AppEnvironmentExtra CAMERETTA_ADMIN_TOKEN=una-password-lunga
   C:\nssm\win64\nssm.exe start Cameretta
   ```

### 17.2 HTTPS con Caddy

```caddy
cristianobattini.com, www.cristianobattini.com {
    encode zstd gzip
    reverse_proxy 127.0.0.1:8000
}
```

Caddy ottiene e rinnova da solo il certificato. Ma servono le porte **80 e 443 libere**:

- Se `netstat -ano | findstr :443` mostra il **PID 4**, la porta è occupata da http.sys (IIS o un altro servizio di Windows). Ferma e disattiva `W3SVC`/`WAS`, o libera la prenotazione con `netsh http show urlacl`.
- Su **Azure** apri nel *Network Security Group* sia la **443** sia la **80**: la 80 serve a Let's Encrypt per la verifica.

### 17.3 DNS

- Se il dominio usa i nameserver di un altro servizio (per esempio Vercel), i record impostati su Aruba vengono ignorati: riporta prima i **nameserver su Aruba**.
- Poi crea i record `A` per `@` e `www` verso l'IP pubblico del server.
- Verifica con `nslookup cristianobattini.com 8.8.8.8` e `dig @<nameserver Aruba> cristianobattini.com`. Se i nameserver rispondono **REFUSED**, la zona non è ancora attiva da loro: aspetta o scrivi al supporto.

> **Approfondimento — perché l'admin "non si vede da fuori".** Il server è collegato apposta a `127.0.0.1`: è sicuro così. Da fuori si arriva solo passando da Caddy, cioè dal dominio (`https://tuodominio/admin/`) una volta che il DNS funziona.

---

## 18. Testare senza cliccare a mano

### 18.1 Un "giro turistico" automatico in Godot

Uno script `tour.gd`, attivo solo se esiste la variabile d'ambiente `CAMERETTA_TOUR`, gira tutto il gioco e salva degli screenshot:

```gdscript
m._start_game(false); await wait(0.4); await shot("scelta_modalita")
m._choose("walk");    m.pad_dir = 1;  await wait(5.0); await shot("strada")
m.worlds.street.P.x = porta - 4; m._do_action(); await wait(1.6); await shot("salotto")
...
for id in ["scrivania", "finestra", "libreria", "lavagna", "letto"]:
    m.open_section(id); await wait(0.8); await shot("scheda_" + id)
```

Su un server senza schermo:

```bash
CAMERETTA_TOUR=/tmp/shots xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x800
CAMERETTA_TOUR=/tmp/shotsm CAMERETTA_SIZE=430x900 xvfb-run -a godot ...   # telefono
```

### 18.2 L'export web in un Chrome vero

Con Playwright si apre la pagina con un telefono emulato (390×844, dpr 3, touch) e si simula un trascinamento del dito per verificare che le schede scorrano:

```python
cdp = await ctx.new_cdp_session(page)
for tipo, y in [("touchStart", 650), ("touchMove", 450), ("touchMove", 350), ("touchEnd", 350)]:
    await cdp.send("Input.dispatchTouchEvent",
                   {"type": tipo, "touchPoints": [] if tipo == "touchEnd" else [{"x": 195, "y": y}]})
```

> **Approfondimento.** Guardare gli screenshot affiancati (desktop, telefono, italiano, inglese) trova in un minuto problemi che a mano emergerebbero dopo giorni: titoli spezzati male, pulsanti sovrapposti, testi illeggibili sulla neve.

---

## 19. Errori che abbiamo incontrato davvero

| Sintomo | Causa | Rimedio |
|---|---|---|
| Le schede non scorrono su telefono | contenitore flex senza `min-height: 0` (versione web); figli che bloccano gli eventi (Godot) | `min-height: 0` e `overflow-y: auto`; `MOUSE_FILTER_PASS` |
| Pannello più alto dello schermo | `RichTextLabel` che al primo frame chiede un'altezza enorme | reimporre la dimensione voluta |
| Quadratini al posto di ◀ ★ ☰ | il browser non ha font di sistema | font di riserva ridotto + `allow_system_fallback = false` nei test |
| Il servizio Windows resta in pausa | Python del Microsoft Store | Python da python.org e venv ricreato |
| `nssm` non riconosciuto | non è nel PATH | percorso completo `C:\nssm\win64\nssm.exe` |
| Caddy: `bind :443 forbidden` | porta occupata da http.sys (PID 4) | fermare IIS/W3SVC |
| Il dominio mostra ancora il vecchio sito | nameserver ancora su Vercel | nameserver su Aruba, poi record A |
| Il gioco web non parte su Windows | `.wasm` servito con il tipo MIME sbagliato | `mimetypes.add_type("application/wasm", ".wasm")` |
| Il menu si rompe quando cambi lingua | nodi rimossi con `queue_free()` ancora presenti con lo stesso nome | `remove_child()` prima di `queue_free()` |
| Il vento "sembra un fiume" | rumore continuo | solo raffiche occasionali |
| Il mouse esce dalla stanza e il cartello resta | evento `mouse_exited` non gestito | togliere l'evidenziazione all'uscita |

**E uno di sicurezza**: non incollare mai password o token in chat, email o screenshot. Se succede, **cambiali subito**.

---

## 20. Idee per andare oltre

- **Giorno/notte reale**: il cielo e le luci seguono l'ora del visitatore.
- **Stagioni**: neve d'inverno, pioggia in autunno, finestra aperta d'estate (tre varianti degli sfondi, scelte in base alla data).
- **Oggetti segreti**: un easter egg (il gatto sul divano che fa le fusa se ci passi davanti tre volte).
- **Contatore "esplorato al 100%"** con una piccola ricompensa (la finestra si apre e si vede il mare con il faro).
- **Pagine indicizzabili**: un gioco in WebGL non viene letto dai motori di ricerca. Fai generare al server anche una versione testuale (`/cv`, `/progetti`) dagli stessi dati, con un link "versione testuale" nel menu: aiuta la SEO e l'accessibilità.
- **Accessibilità**: modalità "testo grande", rispetto di `prefers-reduced-motion`, sottotitoli per i suoni ambientali.
- **Statistiche rispettose**: contare quali oggetti vengono aperti, senza cookie, con un endpoint `POST /api/hit` che salva solo l'id dell'oggetto e la data.

---

*Buon divertimento: il bello di un portfolio così è che non è mai finito. Ogni progetto nuovo è un oggetto in più nella stanza.*
