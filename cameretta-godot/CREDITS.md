# Crediti

## Suoni (tutti CC0 / pubblico dominio)

Registrazioni originali, poi tagliate, filtrate e mixate da `tools/build_sounds.py`:

| File nel gioco | Origine |
|---|---|
| `step_snow_*`, `step_wood_*` | Kenney — *Impact Sounds* (footstep_snow, footstep_wood), CC0 — kenney.nl |
| `ui_*`, `clock_tick` | Kenney — *Interface Sounds* (tick, select, click, switch), CC0 |
| `ui_open`, `ui_page`, `door_open`, `door_close` | Kenney — *RPG Audio* (bookFlip, doorOpen, doorClose), CC0 |
| `key_*` | Ben Burnes (Abstraction) — *Keyboard Sounds*, CC0 |
| `wind_gust` | Ben Burnes (Abstraction) — *2HTC Samples Vol 4*, "Snow Day – Windy", CC0 |
| `fire_loop` | schiocchi di legno da *100 CC0 wood & metal SFX* (raccolta lavenderdotpet/CC0-Public-Domain-Sounds) su un ruggito di rumore filtrato |
| `tv_voices`, `tv_static` | generati (rumore filtrato a sillabe / statico) |
| `engine_loop`, `vespa_*`, `horn`, `helmet`, `waves_loop`, `gull`, `stop_pop`, `brake_snow` | sintetizzati da `tools/build_sea_sounds.py` (nessuna registrazione) |

Le licenze sono in `licenses/`.

## Font (SIL Open Font License 1.1)

- **Pixelify Sans** — Stefie Justprince
- **VT323** — Peter Hull
- **Noto Sans Symbols 2** e **Noto Sans Math** (sottoinsiemi per frecce e simboli) — Google

## Grafica e codice

Pixel art e codice: fatti per CRI's CAMERETTA (generatori in `cameretta-portfolio/tools/`).

## Templi, negozio e citazioni

- Grafica dei templi e degli oggetti del negozio: originale, generata da `tools/build_grove.py` e `tools/build_shop.py`. I tre templi sono omaggi non ufficiali a Star Wars, Harry Potter e Dune: nessun logo, personaggio o musica delle saghe; i testi delle preghiere sono originali. I nomi appartengono ai rispettivi titolari.
- Suoni delle preghiere: sintetizzati da `cameretta-godot/tools/build_grove_sounds.py` (CC0).
- Citazioni: in `scripts/quotes.gd`, con autore e, dove noto, opera o anno; le traduzioni italiane sono nostre.

## Luoghi

- Cielo dell'osservatorio: stelle e costellazioni da [d3-celestial](https://github.com/ofrohn/d3-celestial) di Olaf Frohn (BSD 3, testo in `licenses/d3-celestial-BSD.txt`); Sole, Luna e pianeti calcolati in `scripts/astro.gd` (confrontati con astropy: errore massimo 0,07°).
- Osservatorio, treno, sala giochi, Torre di Pisa, faro, molo e bottiglie: grafica originale da `tools/build_places.py`.
