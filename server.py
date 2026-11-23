"""La cameretta — server locale.

Avvio:  python server.py          (poi apri http://localhost:8000 e http://localhost:8000/admin)
Dati:   data/cameretta.db (SQLite)  ·  file caricati in data/uploads/

Variabili d'ambiente opzionali:
  CAMERETTA_PORT        porta (default 8000)
  CAMERETTA_HOST        host (default 127.0.0.1, solo questo computer)
  CAMERETTA_ADMIN_TOKEN se impostata, l'admin chiede questa password per salvare
  CAMERETTA_KOFI_TOKEN  token di verifica del webhook di Ko-fi (senza, le donazioni non accreditano monete)

Ogni testo visibile ha due versioni: il campo normale (italiano) e quello con
suffisso _en (inglese). Se il campo _en è vuoto, il sito mostra l'italiano.
"""
import hashlib
import hmac
import json
import mimetypes
import os
import re
import secrets
import sqlite3
import ssl
import threading
import time
import urllib.request
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Optional

from fastapi import Depends, FastAPI, File, Header, HTTPException, Request, UploadFile
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# Windows non sempre conosce questi tipi: il gioco Godot (WebAssembly) non partirebbe
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")
mimetypes.add_type("text/javascript", ".js")

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
UPLOADS = DATA / "uploads"
DB_PATH = DATA / "cameretta.db"
PUBLIC = ROOT / "public"
DATA.mkdir(exist_ok=True)
UPLOADS.mkdir(exist_ok=True)

ADMIN_TOKEN = os.environ.get("CAMERETTA_ADMIN_TOKEN", "")
KOFI_TOKEN = os.environ.get("CAMERETTA_KOFI_TOKEN", "").strip()
KOFI_TEST_TX = "00000000-1111-2222-3333-444444444444"   # transazione finta del pulsante di prova di Ko-fi
CATALOG_PATH = ROOT / "cameretta-godot" / "store" / "catalog.json"
MAX_UPLOAD = 25 * 1024 * 1024
ALLOWED_EXT = {".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".pdf", ".mp3", ".ogg", ".wav", ".m4a", ".json", ".txt", ".md", ".zip"}

# ---------------------------------------------------------------- schema

SCHEMA = """
CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS sections (
  id TEXT PRIMARY KEY, object_name TEXT NOT NULL, sign_label TEXT NOT NULL, title TEXT NOT NULL,
  intro TEXT NOT NULL DEFAULT '', color TEXT NOT NULL DEFAULT '#2b2550',
  sort INTEGER NOT NULL DEFAULT 0, visible INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  section_id TEXT NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
  grp TEXT NOT NULL DEFAULT '', kicker TEXT NOT NULL DEFAULT '', title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '', tags TEXT NOT NULL DEFAULT '', url TEXT NOT NULL DEFAULT '',
  link_label TEXT NOT NULL DEFAULT '', image TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT '',
  sort INTEGER NOT NULL DEFAULT 0, visible INTEGER NOT NULL DEFAULT 1, updated_at INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS bubbles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  kind TEXT NOT NULL DEFAULT 'intro',        -- intro | quote
  text TEXT NOT NULL, text_en TEXT NOT NULL DEFAULT '', author TEXT NOT NULL DEFAULT '',
  sort INTEGER NOT NULL DEFAULT 0, visible INTEGER NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT, filename TEXT NOT NULL UNIQUE, original_name TEXT NOT NULL,
  mime TEXT NOT NULL DEFAULT '', size INTEGER NOT NULL DEFAULT 0, label TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL
);
-- il cielo dei caffè: una stella per donazione, col nome scelto da chi dona (visibile dopo l'approvazione)
CREATE TABLE IF NOT EXISTS stars (
  id INTEGER PRIMARY KEY AUTOINCREMENT, tx TEXT NOT NULL UNIQUE, wallet TEXT NOT NULL, name TEXT NOT NULL DEFAULT '', ok INTEGER NOT NULL DEFAULT 0
);
-- bottiglie nel mare: messaggi dei visitatori, visibili solo dopo l'approvazione
CREATE TABLE IF NOT EXISTS bottles (
  id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, name TEXT NOT NULL DEFAULT '', ok INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
);
-- negozio: nessun dato personale, solo un codice a caso per ogni portafoglio
-- code = password del portafoglio (privata); deposit = codice per le donazioni (può essere pubblico: serve solo a ricevere)
CREATE TABLE IF NOT EXISTS wallets (code TEXT PRIMARY KEY, created_at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS ledger (
  id INTEGER PRIMARY KEY AUTOINCREMENT, wallet TEXT NOT NULL REFERENCES wallets(code), delta INTEGER NOT NULL,
  reason TEXT NOT NULL, ref TEXT NOT NULL, created_at INTEGER NOT NULL, UNIQUE (wallet, reason, ref)
);
CREATE TABLE IF NOT EXISTS donations (
  tx TEXT PRIMARY KEY, amount REAL NOT NULL, currency TEXT NOT NULL DEFAULT '', coins INTEGER NOT NULL,
  wallet TEXT, status TEXT NOT NULL, created_at INTEGER NOT NULL   -- status: ok | da_assegnare | prova | rimborsata
);
"""

# colonne aggiunte dopo la prima versione (migrazione automatica)
EXTRA_COLUMNS = {
    "sections": ["object_name_en", "sign_label_en", "title_en", "intro_en", "link_url", "link_label", "link_label_en"],
    "items": ["grp_en", "kicker_en", "title_en", "description_en", "link_label_en", "status_en"],
}

# ---------------------------------------------------------------- contenuti iniziali

DEFAULT_SETTINGS = {
    "site_name": "CRI's CAMERETTA",
    "site_url": "https://www.cristianobattini.com",
    "menu_kicker": "PORTFOLIO · 2026", "menu_kicker_en": "PORTFOLIO · 2026",
    "menu_subtitle": "~ la cameretta ~", "menu_subtitle_en": "~ the little room ~",
    "menu_tagline": "sviluppo · fisica · appunti · libri", "menu_tagline_en": "code · physics · notes · books",
    "menu_enter_label": "INIZIA", "menu_enter_label_en": "START",
    "press_text": "PREMI INVIO PER INIZIARE", "press_text_en": "PRESS ENTER TO START",
    "footer_text": "v3.0 · fatto a mano a Rosignano", "footer_text_en": "v3.0 · handmade in Rosignano",
    "room_crumb": "la cameretta", "room_crumb_en": "the little room",
    "location": "Rosignano Solvay (LI), vicino a Pisa", "location_en": "Rosignano Solvay, near Pisa, Italy",
    "github_url": "https://github.com/cristianobattini",
    "github_physics_url": "https://github.com/cbattini",
    "email": "", "cv_url": "",
    "menu_background": "", "menu_background_pixelated": "1", "menu_shooting_stars": "1",
    "room_image": "", "room_mask": "",
    "audio_default": "1", "music_url": "", "music_volume": "0.35",
    "ambience_volume": "0.5", "steps_volume": "0.7",
    "accent_color": "#f2b85b",
    "default_lang": "en",
    "skip_intro": "0",
    "store_enabled": "1", "donate_url": "https://ko-fi.com/cristianob", "coins_per_unit": "100",
}

GH = "https://github.com/cristianobattini/"

SEED_SECTIONS = [
    dict(id="finestra", object_name="Finestra", object_name_en="Window", sign_label="Percorso", sign_label_en="Journey",
         title="Il mio percorso e CV", title_en="My journey and CV", color="#1b2350", sort=1,
         intro="Dalla finestra si vede il mare. Questa è la strada fatta finora, e quella che ho davanti.",
         intro_en="From the window you can see the sea. This is the road so far, and the one ahead."),
    dict(id="scrivania", object_name="Scrivania", object_name_en="Desk", sign_label="Progetti", sign_label_en="Projects",
         title="Progetti di programmazione", title_en="Programming projects", color="#23406e", sort=2,
         intro="Qui sopra c'è tutto quello che ho scritto, rotto e rimesso in piedi. Dal web al telefono, dalle stelle ai mercati.",
         intro_en="Everything I've written, broken and put back together lives on this desk. From the web to your phone, from the stars to the markets.",
         link_url="https://github.com/cristianobattini", link_label="Tutti i progetti su GitHub ↗", link_label_en="All projects on GitHub ↗"),
    dict(id="lavagna", object_name="Lavagna", object_name_en="Blackboard", sign_label="Fisica", sign_label_en="Physics",
         title="Appunti di fisica e materiale", title_en="Physics notes and material", color="#2f5d48", sort=3,
         intro="Dopo ogni lezione integro gli appunti, poi ci ripasso sopra con gli esercizi. Mi appassionano soprattutto l'elettromagnetismo e la relatività.",
         intro_en="After every lecture I rewrite my notes, then go over them again with exercises. Electromagnetism and relativity are my favourite topics.",
         link_url="https://github.com/cbattini", link_label="I progetti di fisica su GitHub ↗", link_label_en="Physics projects on GitHub ↗"),
    dict(id="libreria", object_name="Libreria", object_name_en="Bookcase", sign_label="Libri", sign_label_en="Books",
         title="I miei libri e attestati", title_en="My books and certificates", color="#5e3b22", sort=4,
         intro="Gli scaffali di quello che leggo e di quello che ho imparato.",
         intro_en="The shelves of what I read and what I've learned."),
    dict(id="letto", object_name="Letto", object_name_en="Bed", sign_label="Scritti", sign_label_en="Writing",
         title="Articoli ed elaborati personali", title_en="Articles and personal essays", color="#7a3626", sort=5,
         intro="Le cose che scrivo la sera, quando la scrivania è spenta.",
         intro_en="The things I write at night, when the desk lamp is off."),
]


def it(section, grp, grp_en, kicker, kicker_en, title, title_en, desc, desc_en, tags="", url="", status="", status_en="", ll="", ll_en=""):
    return dict(section_id=section, grp=grp, grp_en=grp_en, kicker=kicker, kicker_en=kicker_en, title=title, title_en=title_en,
                description=desc, description_en=desc_en, tags=tags, url=url, status=status, status_en=status_en,
                link_label=ll, link_label_en=ll_en)


SEED_ITEMS = [
    # --- dal CV di cristianobattini.com
    it("finestra", "Il percorso", "The journey", "2026 — in corso", "2026 — now", "Studente di Fisica · Università di Pisa", "Physics student · University of Pisa",
       "Immatricolato al corso di laurea in Fisica: Fisica 1, Analisi Matematica, Geometria e Algebra Lineare, Laboratorio 1.",
       "Enrolled in the Physics degree: Physics 1, Calculus, Geometry and Linear Algebra, Lab 1."),
    it("finestra", "Il percorso", "The journey", "Diploma", "High school", "Diploma di Maturità", "High-school diploma",
       "Conseguito con votazione 100/100.", "Graduated with full marks, 100/100."),
    it("finestra", "Il percorso", "The journey", "Lavoro", "Work", "Sviluppatore full-stack", "Full-stack developer",
       "Esperienza in ruoli di R&D e frontend: interfacce in Angular e React, servizi in Python e FastAPI.",
       "Experience in R&D and frontend roles: interfaces in Angular and React, services in Python and FastAPI."),
    it("finestra", "Strumenti", "Toolbox", "Stack", "Stack", "Con cosa lavoro", "What I work with", "", "",
       "Angular, React, React Native, Expo, TypeScript, NestJS, Python, FastAPI, Supabase, C#, C++"),

    # --- progetti da cristianobattini.com (in evidenza come sul sito)
    it("scrivania", "In evidenza", "Featured", "2026 · terminale", "2026 · terminal", "Astro Assistant", "Astro Assistant",
       "App da terminale a schermo intero per pianificare le notti di astrofotografia: punteggio dei soggetti, finestre di ripresa e un vero registro delle osservazioni. Basata su Astropy/Astroplan, con tutto il catalogo Messier già pronto.",
       "A full-screen terminal app for planning astrophotography nights: target scoring, shooting windows and a real observation log. Built on Astropy/Astroplan, with the whole Messier catalogue ready on first launch.",
       "Python, Textual, Rich, Astropy, Astroplan, SQLModel, SQLite", GH + "astro_assistant", status="Open source", status_en="Open source"),
    it("scrivania", "In evidenza", "Featured", "2026 · mobile", "2026 · mobile", "Provia", "Provia",
       "Compagna per gli studenti universitari italiani: voti, CFU, medie, orario e appelli, inseriti da te e privati. Nessun login d'ateneo, abbonamento Pro con paywall animato su misura.",
       "A companion for Italian university students: grades, credits, averages, timetable and exam sessions, all self-tracked and private. No university login, Pro subscription with a custom animated paywall.",
       "React Native, Expo, TypeScript, Supabase, Zustand, TanStack Query", GH + "Provia", status="Open source", status_en="Open source"),
    it("scrivania", "In evidenza", "Featured", "2026 · full stack", "2026 · full stack", "UniTrend", "UniTrend",
       "Si collega al tuo ateneo con OAuth2/OIDC e tiene sincronizzati voti, CFU, orario e appelli. Monorepo NestJS + Prisma con connettori per ESSE3/CINECA e GOMP, token cifrati lato server.",
       "Connects to your university via OAuth2/OIDC and keeps grades, credits, timetable and exams in sync. NestJS + Prisma monorepo with connectors for ESSE3/CINECA and GOMP, tokens encrypted server-side.",
       "NestJS, Prisma, PostgreSQL, Redis, React Native, Expo, TypeScript", GH + "universita_app", status="Open source", status_en="Open source"),
    it("scrivania", "Altri progetti", "More projects", "2025 · mobile", "2025 · mobile", "YouVault", "YouVault",
       "Una cassaforte privata e cifrata per le credenziali: tutto resta sul telefono, si sblocca solo con Face ID o impronta.",
       "A private, encrypted vault for your credentials: everything stays on the phone, unlocked only with Face ID or fingerprint.",
       "React Native, Expo, Realm, TypeScript, Crypto-JS", GH + "YouVault", status="Open source", status_en="Open source"),
    it("scrivania", "Altri progetti", "More projects", "2026 · mobile", "2026 · mobile", "GalleryClean", "GalleryClean",
       "Svuota il rullino in fretta con uno swipe: a destra elimini, a sinistra tieni, con annulla, anteprima dei video e una griglia di controllo prima di cancellare.",
       "Clear out your camera roll fast with a swipe: right to delete, left to keep, with undo, video preview and a review grid before anything is removed.",
       "React Native, Expo, Kotlin", GH + "GalleryClean", status="Open source", status_en="Open source"),
    it("scrivania", "Altri progetti", "More projects", "2025 · trading", "2025 · trading", "Anakin cTrader Algo", "Anakin cTrader Algo",
       "Bot di trading algoritmico per cTrader: ingressi precisi, due take profit indipendenti, break-even automatico e dimensionamento a rischio percentuale.",
       "An algorithmic trading bot for cTrader: precise entries, two independent take-profit levels, automatic break-even and risk-percent position sizing.",
       "C#, cTrader, cAlgo", GH + "Anakin-cAlgo", status="Open source", status_en="Open source"),

    it("lavagna", "Corsi", "Courses", "Università di Pisa", "University of Pisa", "Fisica 1", "Physics 1",
       "Appunti in LaTeX, un file per argomento con uno stile condiviso.", "Notes in LaTeX, one file per topic with a shared style.", "LaTeX"),
    it("lavagna", "Corsi", "Courses", "Università di Pisa", "University of Pisa", "Analisi Matematica", "Calculus",
       "Appunti su Goodnotes con il metodo Cornell: le domande chiave nella colonna a sinistra.",
       "Notes in Goodnotes with the Cornell method: key questions in the left column.", "Goodnotes"),
    it("lavagna", "Corsi", "Courses", "Università di Pisa", "University of Pisa", "Geometria e Algebra Lineare", "Geometry and Linear Algebra",
       "Appunti in LaTeX, divisi in parti.", "Notes in LaTeX, split into parts.", "LaTeX"),
    it("lavagna", "Corsi", "Courses", "Università di Pisa", "University of Pisa", "Laboratorio 1", "Lab 1",
       "Relazioni in LaTeX, analisi dei dati in Python.", "Lab reports in LaTeX, data analysis in Python.", "LaTeX, NumPy, Matplotlib, SciPy"),
    it("lavagna", "Materiale", "Material", "Fisica 1", "Physics 1", "Cinematica", "Kinematics",
       "Appunti completi in PDF.", "Complete notes as a PDF.", status="in arrivo", status_en="coming soon"),
    it("lavagna", "Materiale", "Material", "GAL", "Linear Algebra", "Parte 1", "Part 1",
       "Appunti completi in PDF.", "Complete notes as a PDF.", status="in arrivo", status_en="coming soon"),
    it("lavagna", "Progetti di fisica", "Physics projects", "2025 · simulazione", "2025 · simulation", "Simulatore delle linee di forza", "Electric Field Force Lines Simulator",
       "App desktop che disegna campo elettrico e linee di forza per configurazioni di cariche puntiformi a scelta. Nata come strumento didattico e di visualizzazione.",
       "A desktop app that draws electric field and force lines around any point-charge configuration. Built as a teaching and visualisation aid.",
       "Python, NumPy, Matplotlib, PyQt5", GH + "electric_field_force_lines_sim", status="Open source", status_en="Open source"),
    it("lavagna", "Progetti di fisica", "Physics projects", "GitHub", "GitHub", "cbattini", "cbattini",
       "Il profilo dove tengo codice e materiale di fisica.", "The profile where I keep my physics code and material.",
       url="https://github.com/cbattini", ll="apri il profilo ↗", ll_en="open profile ↗"),

    it("libreria", "Sullo scaffale", "On the shelf", "Sigmund Freud", "Sigmund Freud", "L'interpretazione dei sogni", "The Interpretation of Dreams", "", ""),
    it("libreria", "Sullo scaffale", "On the shelf", "James Joyce", "James Joyce", "Gente di Dublino", "Dubliners", "", ""),
    it("libreria", "Sullo scaffale", "On the shelf", "Giovanni Pascoli", "Giovanni Pascoli", "Il fanciullino", "Il fanciullino", "", ""),

    it("letto", "Elaborati", "Essays", "Letteratura inglese", "English literature", "Joyce: «The Sisters» e «A Mother»", "Joyce: “The Sisters” and “A Mother”",
       "Due racconti di Gente di Dublino, analizzati in due presentazioni.", "Two stories from Dubliners, analysed in two presentations.", "Joyce, Dubliners"),
    it("letto", "Elaborati", "Essays", "Letteratura italiana", "Italian literature", "Fanciullino e superuomo", "The child and the superman",
       "Pascoli e D'Annunzio: due risposte opposte del Decadentismo.", "Pascoli and D'Annunzio: two opposite answers of Decadentism.", "Pascoli, D'Annunzio"),
    it("letto", "Elaborati", "Essays", "Psicoanalisi", "Psychoanalysis", "Freud e i sogni", "Freud and dreams",
       "L'interpretazione dei sogni e il ruolo degli stimoli organici.", "The Interpretation of Dreams and the role of organic stimuli.", "Freud"),
    it("letto", "Articoli", "Articles", "Forum", "Forum", "anakin/ — pensare ad alta voce", "anakin/ — thinking out loud",
       "Il mio forum personale, dove scrivo quello che penso mentre lo penso.", "My personal forum, where I write what I think while I'm thinking it."),
]

SEED_BUBBLES = [
    ("intro", "Ciao! Benvenuto in CRI's CAMERETTA, il mio piccolo angolo di internet.", "Hi! Welcome to CRI's CAMERETTA, my little corner of the internet.", ""),
    ("intro", "Sono uno sviluppatore full-stack di Rosignano Solvay, un paese sul mare vicino a Pisa.", "I'm a full-stack developer from Rosignano Solvay, a small town by the sea near Pisa.", ""),
    ("intro", "Dal 2026 studio Fisica all'Università di Pisa. Il mio preferito? L'elettromagnetismo.", "Since 2026 I've been studying Physics at the University of Pisa. My favourite part? Electromagnetism.", ""),
    ("quote", "Ciò che non so creare, non lo capisco.", "What I cannot create, I do not understand.", "Richard Feynman"),
    ("intro", "Ho costruito app per studenti, un assistente per l'astrofotografia, una cassaforte per password e un bot di trading.", "I've built apps for students, an astrophotography planner, a password vault and a trading bot.", ""),
    ("quote", "I suoi errori sono volontari e sono i portali della scoperta.", "His errors are volitional and are the portals of discovery.", "James Joyce, Ulisse"),
    ("quote", "È dentro noi un fanciullino.", "Within us there is a little child.", "Giovanni Pascoli"),
    ("intro", "La casa in fondo alla strada è la mia. Entra pure, dentro fa caldo.", "That house at the end of the street is mine. Come in, it's warm inside.", ""),
]

# ---------------------------------------------------------------- database


def connect():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys = ON")
    return con


@contextmanager
def db():
    con = connect()
    try:
        yield con
        con.commit()
    finally:
        con.close()


ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"   # senza 0/O e 1/I


def rand_code(prefix):
    s = "".join(secrets.choice(ALPHABET) for _ in range(8))
    return f"{prefix}-{s[:4]}-{s[4:]}"


def init_db():
    with db() as con:
        con.executescript(SCHEMA)
        for table, cols in EXTRA_COLUMNS.items():
            have = {r["name"] for r in con.execute(f"PRAGMA table_info({table})")}
            for c in cols:
                if c not in have:
                    con.execute(f"ALTER TABLE {table} ADD COLUMN {c} TEXT NOT NULL DEFAULT ''")
        if "deposit" not in {r["name"] for r in con.execute("PRAGMA table_info(wallets)")}:
            con.execute("ALTER TABLE wallets ADD COLUMN deposit TEXT")
        con.execute("CREATE UNIQUE INDEX IF NOT EXISTS wallets_deposit ON wallets(deposit)")
        for r in con.execute("SELECT code FROM wallets WHERE deposit IS NULL").fetchall():
            con.execute("UPDATE wallets SET deposit = ? WHERE code = ?", (rand_code("DON"), r["code"]))
        for k, v in DEFAULT_SETTINGS.items():
            con.execute("INSERT OR IGNORE INTO settings(key, value) VALUES (?, ?)", (k, v))
        # versione 3.0: aggiorna la scritta in fondo al menu, se comincia ancora con v2.0
        con.execute("UPDATE settings SET value = 'v3.0' || substr(value, 5) WHERE key IN ('footer_text', 'footer_text_en') AND value LIKE 'v2.0%'")
        if con.execute("SELECT COUNT(*) FROM sections").fetchone()[0] == 0:
            for s in SEED_SECTIONS:
                cols = ", ".join(s); qs = ", ".join("?" * len(s))
                con.execute(f"INSERT INTO sections({cols}) VALUES ({qs})", tuple(s.values()))
            now = int(time.time())
            for i, item in enumerate(SEED_ITEMS):
                item = {**item, "sort": i, "updated_at": now}
                cols = ", ".join(item); qs = ", ".join("?" * len(item))
                con.execute(f"INSERT INTO items({cols}) VALUES ({qs})", tuple(item.values()))
        if con.execute("SELECT COUNT(*) FROM bubbles").fetchone()[0] == 0:
            for i, (kind, t, t_en, author) in enumerate(SEED_BUBBLES):
                con.execute("INSERT INTO bubbles(kind, text, text_en, author, sort) VALUES (?,?,?,?,?)", (kind, t, t_en, author, i))


def rows(cur):
    return [dict(r) for r in cur.fetchall()]


def item_out(r):
    d = dict(r)
    d["tags"] = [t.strip() for t in d["tags"].split(",") if t.strip()]
    d["visible"] = bool(d["visible"])
    return d


# ---------------------------------------------------------------- app

app = FastAPI(title="La cameretta", docs_url="/api/docs", redoc_url=None)


def require_admin(x_admin_token: Optional[str] = Header(default=None)):
    if ADMIN_TOKEN and x_admin_token != ADMIN_TOKEN:
        raise HTTPException(401, "Password admin mancante o errata")


@app.get("/api/public")
def public_data():
    """Tutto quello che serve al gioco, in una chiamata."""
    with db() as con:
        settings = {r["key"]: r["value"] for r in con.execute("SELECT key, value FROM settings")}
        sections = rows(con.execute("SELECT * FROM sections WHERE visible = 1 ORDER BY sort"))
        for s in sections:
            s["items"] = [item_out(r) for r in con.execute(
                "SELECT * FROM items WHERE section_id = ? AND visible = 1 ORDER BY sort, id", (s["id"],))]
        bubbles = rows(con.execute("SELECT id, kind, text, text_en, author FROM bubbles WHERE visible = 1 ORDER BY sort, id"))
    settings["donations_ready"] = "1" if KOFI_TOKEN else "0"     # il gioco promette monete solo se arrivano davvero
    return {"settings": settings, "sections": sections, "bubbles": bubbles}


@app.get("/api/auth", dependencies=[Depends(require_admin)])
def auth_check():
    return {"ok": True, "protected": bool(ADMIN_TOKEN)}


# --- impostazioni
@app.get("/api/settings", dependencies=[Depends(require_admin)])
def get_settings():
    with db() as con:
        return {r["key"]: r["value"] for r in con.execute("SELECT key, value FROM settings ORDER BY key")}


@app.put("/api/settings", dependencies=[Depends(require_admin)])
def put_settings(data: dict):
    with db() as con:
        for k, v in data.items():
            if not re.fullmatch(r"[a-z0-9_]{1,64}", k):
                raise HTTPException(400, f"Chiave non valida: {k}")
            con.execute("INSERT INTO settings(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                        (k, "" if v is None else str(v)))
    return get_settings()


# --- sezioni
class SectionIn(BaseModel):
    object_name: str
    object_name_en: str = ""
    sign_label: str
    sign_label_en: str = ""
    title: str
    title_en: str = ""
    intro: str = ""
    intro_en: str = ""
    link_url: str = ""
    link_label: str = ""
    link_label_en: str = ""
    color: str = "#2b2550"
    sort: int = 0
    visible: bool = True


@app.get("/api/sections", dependencies=[Depends(require_admin)])
def list_sections():
    with db() as con:
        out = rows(con.execute("SELECT * FROM sections ORDER BY sort"))
        for s in out:
            s["count"] = con.execute("SELECT COUNT(*) FROM items WHERE section_id = ?", (s["id"],)).fetchone()[0]
            s["visible"] = bool(s["visible"])
        return out


@app.put("/api/sections/{sid}", dependencies=[Depends(require_admin)])
def update_section(sid: str, body: SectionIn):
    data = body.model_dump()
    data["visible"] = int(data["visible"])
    sets = ", ".join(f"{k} = ?" for k in data)
    with db() as con:
        cur = con.execute(f"UPDATE sections SET {sets} WHERE id = ?", (*data.values(), sid))
        if cur.rowcount == 0:
            raise HTTPException(404, "Sezione non trovata")
    return {"ok": True}


# --- voci
class ItemIn(BaseModel):
    section_id: str
    grp: str = ""
    grp_en: str = ""
    kicker: str = ""
    kicker_en: str = ""
    title: str
    title_en: str = ""
    description: str = ""
    description_en: str = ""
    tags: list[str] | str = ""
    url: str = ""
    link_label: str = ""
    link_label_en: str = ""
    image: str = ""
    status: str = ""
    status_en: str = ""
    visible: bool = True
    sort: Optional[int] = None


def tags_str(t):
    if isinstance(t, list):
        return ", ".join(x.strip() for x in t if x.strip())
    return ", ".join(x.strip() for x in (t or "").split(",") if x.strip())


def item_values(body: ItemIn):
    d = body.model_dump(exclude={"sort"})
    d["tags"] = tags_str(body.tags)
    d["visible"] = int(body.visible)
    return d


@app.get("/api/items", dependencies=[Depends(require_admin)])
def list_items(section: Optional[str] = None, q: Optional[str] = None):
    sql, args = "SELECT * FROM items WHERE 1=1", []
    if section:
        sql += " AND section_id = ?"; args.append(section)
    if q:
        like = f"%{q}%"
        sql += " AND (title LIKE ? OR title_en LIKE ? OR description LIKE ? OR description_en LIKE ? OR tags LIKE ? OR kicker LIKE ? OR grp LIKE ?)"
        args += [like] * 7
    sql += " ORDER BY section_id, sort, id"
    with db() as con:
        return [item_out(r) for r in con.execute(sql, args)]


@app.post("/api/items", dependencies=[Depends(require_admin)])
def create_item(body: ItemIn):
    with db() as con:
        if not con.execute("SELECT 1 FROM sections WHERE id = ?", (body.section_id,)).fetchone():
            raise HTTPException(400, "Sezione inesistente")
        d = item_values(body)
        d["sort"] = body.sort if body.sort is not None else con.execute(
            "SELECT COALESCE(MAX(sort), -1) + 1 FROM items WHERE section_id = ?", (body.section_id,)).fetchone()[0]
        d["updated_at"] = int(time.time())
        cur = con.execute(f"INSERT INTO items({', '.join(d)}) VALUES ({', '.join('?' * len(d))})", tuple(d.values()))
        return item_out(con.execute("SELECT * FROM items WHERE id = ?", (cur.lastrowid,)).fetchone())


@app.put("/api/items/{iid}", dependencies=[Depends(require_admin)])
def update_item(iid: int, body: ItemIn):
    with db() as con:
        old = con.execute("SELECT * FROM items WHERE id = ?", (iid,)).fetchone()
        if not old:
            raise HTTPException(404, "Voce non trovata")
        d = item_values(body)
        d["sort"] = old["sort"] if body.sort is None else body.sort
        d["updated_at"] = int(time.time())
        con.execute(f"UPDATE items SET {', '.join(f'{k} = ?' for k in d)} WHERE id = ?", (*d.values(), iid))
        return item_out(con.execute("SELECT * FROM items WHERE id = ?", (iid,)).fetchone())


@app.delete("/api/items/{iid}", dependencies=[Depends(require_admin)])
def delete_item(iid: int):
    with db() as con:
        con.execute("DELETE FROM items WHERE id = ?", (iid,))
    return {"ok": True}


class Reorder(BaseModel):
    ids: list[int]


@app.post("/api/items/reorder", dependencies=[Depends(require_admin)])
def reorder_items(body: Reorder):
    with db() as con:
        for i, iid in enumerate(body.ids):
            con.execute("UPDATE items SET sort = ? WHERE id = ?", (i, iid))
    return {"ok": True}


# --- bolle della strada
class BubbleIn(BaseModel):
    kind: str = "intro"
    text: str
    text_en: str = ""
    author: str = ""
    visible: bool = True


@app.get("/api/bubbles", dependencies=[Depends(require_admin)])
def list_bubbles():
    with db() as con:
        out = rows(con.execute("SELECT * FROM bubbles ORDER BY sort, id"))
    for b in out:
        b["visible"] = bool(b["visible"])
    return out


@app.post("/api/bubbles", dependencies=[Depends(require_admin)])
def create_bubble(body: BubbleIn):
    with db() as con:
        sort = con.execute("SELECT COALESCE(MAX(sort), -1) + 1 FROM bubbles").fetchone()[0]
        cur = con.execute("INSERT INTO bubbles(kind, text, text_en, author, sort, visible) VALUES (?,?,?,?,?,?)",
                          (body.kind, body.text, body.text_en, body.author, sort, int(body.visible)))
        return dict(con.execute("SELECT * FROM bubbles WHERE id = ?", (cur.lastrowid,)).fetchone())


@app.put("/api/bubbles/{bid}", dependencies=[Depends(require_admin)])
def update_bubble(bid: int, body: BubbleIn):
    with db() as con:
        con.execute("UPDATE bubbles SET kind=?, text=?, text_en=?, author=?, visible=? WHERE id=?",
                    (body.kind, body.text, body.text_en, body.author, int(body.visible), bid))
    return {"ok": True}


@app.delete("/api/bubbles/{bid}", dependencies=[Depends(require_admin)])
def delete_bubble(bid: int):
    with db() as con:
        con.execute("DELETE FROM bubbles WHERE id = ?", (bid,))
    return {"ok": True}


@app.post("/api/bubbles/reorder", dependencies=[Depends(require_admin)])
def reorder_bubbles(body: Reorder):
    with db() as con:
        for i, bid in enumerate(body.ids):
            con.execute("UPDATE bubbles SET sort = ? WHERE id = ?", (i, bid))
    return {"ok": True}


# --- file caricati
def asset_out(r):
    d = dict(r)
    d["url"] = f"/uploads/{d['filename']}"
    return d


@app.get("/api/assets", dependencies=[Depends(require_admin)])
def list_assets(q: Optional[str] = None, kind: Optional[str] = None):
    sql, args = "SELECT * FROM assets WHERE 1=1", []
    if q:
        sql += " AND (original_name LIKE ? OR label LIKE ?)"; args += [f"%{q}%"] * 2
    if kind == "image":
        sql += " AND mime LIKE 'image/%'"
    elif kind == "audio":
        sql += " AND mime LIKE 'audio/%'"
    elif kind == "pdf":
        sql += " AND mime = 'application/pdf'"
    sql += " ORDER BY created_at DESC, id DESC"
    with db() as con:
        return [asset_out(r) for r in con.execute(sql, args)]


@app.post("/api/assets", dependencies=[Depends(require_admin)])
async def upload_assets(files: list[UploadFile] = File(...)):
    out = []
    for f in files:
        ext = Path(f.filename or "").suffix.lower()
        if ext not in ALLOWED_EXT:
            raise HTTPException(400, f"Tipo di file non ammesso: {f.filename}")
        data = await f.read()
        if len(data) > MAX_UPLOAD:
            raise HTTPException(400, f"{f.filename} supera i 25 MB")
        stem = re.sub(r"[^a-zA-Z0-9_-]+", "-", Path(f.filename).stem).strip("-")[:40] or "file"
        name = f"{stem}-{uuid.uuid4().hex[:8]}{ext}"
        (UPLOADS / name).write_bytes(data)
        with db() as con:
            cur = con.execute("INSERT INTO assets(filename, original_name, mime, size, created_at) VALUES (?,?,?,?,?)",
                              (name, f.filename, f.content_type or "", len(data), int(time.time())))
            out.append(asset_out(con.execute("SELECT * FROM assets WHERE id = ?", (cur.lastrowid,)).fetchone()))
    return out


class AssetLabel(BaseModel):
    label: str = ""


@app.put("/api/assets/{aid}", dependencies=[Depends(require_admin)])
def label_asset(aid: int, body: AssetLabel):
    with db() as con:
        con.execute("UPDATE assets SET label = ? WHERE id = ?", (body.label, aid))
    return {"ok": True}


@app.delete("/api/assets/{aid}", dependencies=[Depends(require_admin)])
def delete_asset(aid: int):
    with db() as con:
        r = con.execute("SELECT * FROM assets WHERE id = ?", (aid,)).fetchone()
        if not r:
            raise HTTPException(404, "File non trovato")
        url = f"/uploads/{r['filename']}"
        used = con.execute("SELECT COUNT(*) FROM settings WHERE value = ?", (url,)).fetchone()[0] + \
            con.execute("SELECT COUNT(*) FROM items WHERE image = ? OR url = ?", (url, url)).fetchone()[0]
        if used:
            raise HTTPException(409, "Il file è in uso (impostazioni o voci): sostituiscilo prima di eliminarlo")
        con.execute("DELETE FROM assets WHERE id = ?", (aid,))
    (UPLOADS / r["filename"]).unlink(missing_ok=True)
    return {"ok": True}


# --- backup
@app.get("/api/export", dependencies=[Depends(require_admin)])
def export_all():
    with db() as con:
        return {
            "settings": {r["key"]: r["value"] for r in con.execute("SELECT key, value FROM settings")},
            "sections": rows(con.execute("SELECT * FROM sections ORDER BY sort")),
            "items": rows(con.execute("SELECT * FROM items ORDER BY section_id, sort")),
            "bubbles": rows(con.execute("SELECT * FROM bubbles ORDER BY sort")),
        }


# ---------------------------------------------------------------- negozio
# Le monete si guadagnano giocando (premi fissi, una volta sola) o donando su Ko-fi:
# chi dona incolla nel messaggio il suo codice per le donazioni (DON-…) e il webhook accredita le monete.

CATALOG = json.loads(CATALOG_PATH.read_text(encoding="utf-8")) if CATALOG_PATH.exists() else {"categories": [], "items": [], "earn": {}}
PRICES = {i["id"]: int(i["price"]) for i in CATALOG["items"]}
PRIZES = {i["id"]: i["prize"] for i in CATALOG["items"] if i.get("prize")}
SECRETS = set(CATALOG.get("secrets", []))
CODE_RE = re.compile(r"CRI-([A-Z2-9]{4})-([A-Z2-9]{4})", re.I)
DEPOSIT_RE = re.compile(r"DON-([A-Z2-9]{4})-([A-Z2-9]{4})", re.I)
_hits = {}


def limit(request: Request, what: str, n: int, secs: int):
    """Al massimo n richieste ogni `secs` secondi per indirizzo."""
    now = time.time()
    if len(_hits) > 5000:
        _hits.clear()
    key = (what, request.client.host if request.client else "?")
    q = [t for t in _hits.get(key, []) if now - t < secs]
    if len(q) >= n:
        raise HTTPException(429, "Troppe richieste, riprova tra poco")
    _hits[key] = q + [now]


def store_on(con):
    r = con.execute("SELECT value FROM settings WHERE key = 'store_enabled'").fetchone()
    if r and r["value"] == "0":
        raise HTTPException(404, "Negozio chiuso")


def wallet_out(con, code):
    w = con.execute("SELECT deposit FROM wallets WHERE code = ?", (code,)).fetchone()
    if not w:
        raise HTTPException(404, "Portafoglio non trovato")
    bal = con.execute("SELECT COALESCE(SUM(delta), 0) FROM ledger WHERE wallet = ?", (code,)).fetchone()[0]
    owned = [r["ref"] for r in con.execute("SELECT ref FROM ledger WHERE wallet = ? AND reason = 'buy' ORDER BY id", (code,))]
    got = [r["ref"] for r in con.execute("SELECT ref FROM ledger WHERE wallet = ? AND reason = 'earn'", (code,))]
    stars = [r["name"] for r in con.execute("SELECT name FROM stars WHERE wallet = ? ORDER BY id DESC", (code,))]
    return {"code": code, "deposit": w["deposit"], "balance": bal, "owned": owned, "earned": got, "stars": stars}


def norm_code(code):
    m = CODE_RE.fullmatch(code.strip())
    if not m:
        raise HTTPException(404, "Portafoglio non trovato")
    return f"CRI-{m[1]}-{m[2]}".upper()


def by_deposit(con, text):
    """Il portafoglio a cui appartiene il codice per le donazioni scritto in un testo (o None)."""
    m = DEPOSIT_RE.search(text) if isinstance(text, str) else None
    r = con.execute("SELECT code FROM wallets WHERE deposit = ?", (f"DON-{m[1]}-{m[2]}".upper(),)).fetchone() if m else None
    return r["code"] if r else None


def admin_code(con, code):
    """In admin va bene sia il codice del portafoglio sia quello per le donazioni."""
    return by_deposit(con, code) or norm_code(code)


def ledger_add(con, code, delta, reason, ref):
    """False se la stessa riga c'era già."""
    cur = con.execute("INSERT OR IGNORE INTO ledger(wallet, delta, reason, ref, created_at) VALUES (?,?,?,?,?)",
                      (code, delta, reason, ref, int(time.time())))
    return cur.rowcount == 1


@app.post("/api/wallet")
def new_wallet(request: Request):
    limit(request, "new", 10, 3600)
    with db() as con:
        store_on(con)
        while True:
            code = rand_code("CRI")
            if con.execute("INSERT OR IGNORE INTO wallets(code, created_at, deposit) VALUES (?, ?, ?)", (code, int(time.time()), rand_code("DON"))).rowcount:
                return wallet_out(con, code)


@app.get("/api/wallet/{code}")
def get_wallet(code: str, request: Request):
    limit(request, "get", 90, 60)
    with db() as con:
        return wallet_out(con, norm_code(code))


class StoreIn(BaseModel):
    id: str


@app.post("/api/wallet/{code}/buy")
def buy(code: str, body: StoreIn, request: Request):
    limit(request, "buy", 60, 60)
    code = norm_code(code)
    if body.id not in PRICES:
        raise HTTPException(404, "Articolo non trovato")
    with db() as con:
        store_on(con)
        con.execute("BEGIN IMMEDIATE")          # due acquisti insieme non possono spendere le stesse monete
        w = wallet_out(con, code)
        if body.id in w["owned"] or (PRICES[body.id] == 0 and body.id not in PRIZES):
            return w
        if body.id in PRIZES and not all(f"secret:{s}" in w["earned"] for s in SECRETS):
            raise HTTPException(403, "Premio non ancora conquistato")
        if w["balance"] < PRICES[body.id]:
            raise HTTPException(402, "Monete insufficienti")
        ledger_add(con, code, -PRICES[body.id], "buy", body.id)
        return wallet_out(con, code)


@app.post("/api/wallet/{code}/earn")
def earn(code: str, body: StoreIn, request: Request):
    """Premi del gioco: ogni traguardo una volta sola; quelli giornalieri una volta al giorno."""
    limit(request, "earn", 90, 60)
    code = norm_code(code)
    kind, _, arg = body.id.partition(":")
    e = CATALOG["earn"]
    with db() as con:
        store_on(con)
        wallet_out(con, code)
        day = time.strftime("%Y-%m-%d")
        if kind == "stop" and arg.isdigit() and con.execute("SELECT 1 FROM items WHERE id = ? AND visible = 1", (int(arg),)).fetchone():
            ref = body.id
        elif kind == "section" and con.execute("SELECT 1 FROM sections WHERE id = ? AND visible = 1", (arg,)).fetchone():
            ref = body.id
        elif body.id == "ride_end" or (kind == "secret" and arg in SECRETS):
            ref = body.id
        elif body.id in ("daily", "fish") or (kind == "pray" and arg in ("stelle", "magia", "dune")):
            ref = f"{body.id}:{day}"
        else:
            raise HTTPException(400, "Premio sconosciuto")
        new = ledger_add(con, code, int(e.get(kind, 0)), "earn", ref)
        return {**wallet_out(con, code), "got": int(e.get(kind, 0)) if new else 0}


@app.post("/api/kofi/webhook")
async def kofi_webhook(request: Request):
    """Ko-fi manda un modulo con un campo "data" che contiene un JSON; lo si riconosce dal token di verifica."""
    if not KOFI_TOKEN:
        raise HTTPException(503, "Webhook non configurato")
    limit(request, "kofi", 120, 60)
    try:
        data = json.loads(str((await request.form()).get("data") or ""))
        token = str(data.get("verification_token") or "")
    except (ValueError, AttributeError):
        raise HTTPException(400, "Messaggio non valido")
    if not hmac.compare_digest(token.encode(), KOFI_TOKEN.encode()):
        raise HTTPException(401, "Token non valido")
    kind = str(data.get("type", ""))
    tx = str(data.get("kofi_transaction_id") or "")[:80]
    if kind not in ("Donation", "Subscription") or not tx:
        return {"ok": True, "ignored": kind}
    with db() as con:
        con.execute("BEGIN IMMEDIATE")
        if con.execute("SELECT 1 FROM donations WHERE tx = ?", (tx,)).fetchone():   # Ko-fi ripete l'avviso se non riceve risposta
            return {"ok": True, "ignored": "già registrata"}
        try:
            amount = float(str(data.get("amount") or "0").replace(",", "."))
            rate = float((con.execute("SELECT value FROM settings WHERE key = 'coins_per_unit'").fetchone() or {"value": "100"})["value"])
        except ValueError:
            raise HTTPException(400, "Importo non valido")
        if not 0 < amount < 100000:
            return {"ok": True, "ignored": kind}
        coins = int(round(amount * max(0.0, rate)))
        # i messaggi di Ko-fi possono essere pubblici: si accetta solo il codice per ricevere, mai quello del portafoglio
        code = by_deposit(con, data.get("message"))
        status = "prova" if tx == KOFI_TEST_TX else "ok" if code else "da_assegnare"
        con.execute("INSERT INTO donations VALUES (?,?,?,?,?,?,?)", (tx, amount, str(data.get("currency", ""))[:8], coins, code, status, int(time.time())))
        if status == "ok":
            ledger_add(con, code, coins, "donation", tx)
            con.execute("INSERT OR IGNORE INTO stars(tx, wallet) VALUES (?, ?)", (tx, code))
    return {"ok": True}


@app.get("/api/store/donations", dependencies=[Depends(require_admin)])
def list_donations():
    with db() as con:
        return {"configured": bool(KOFI_TOKEN), "wallets": con.execute("SELECT COUNT(*) FROM wallets").fetchone()[0],
                "donations": rows(con.execute("SELECT * FROM donations ORDER BY created_at DESC LIMIT 200"))}


class AssignIn(BaseModel):
    tx: str
    code: str


@app.post("/api/store/assign", dependencies=[Depends(require_admin)])
def assign_donation(body: AssignIn):
    """Una donazione arrivata senza codice: si assegna a mano a un portafoglio."""
    with db() as con:
        con.execute("BEGIN IMMEDIATE")
        code = admin_code(con, body.code)
        wallet_out(con, code)
        d = con.execute("SELECT * FROM donations WHERE tx = ? AND status = 'da_assegnare'", (body.tx,)).fetchone()
        if not d:
            raise HTTPException(404, "Donazione non trovata o già assegnata")
        ledger_add(con, code, d["coins"], "donation", body.tx)
        con.execute("UPDATE donations SET wallet = ?, status = 'ok' WHERE tx = ?", (code, body.tx))
        con.execute("INSERT OR IGNORE INTO stars(tx, wallet) VALUES (?, ?)", (body.tx, code))
        return wallet_out(con, code)


class RefundIn(BaseModel):
    tx: str


@app.post("/api/store/refund", dependencies=[Depends(require_admin)])
def refund_donation(body: RefundIn):
    """Ko-fi non avvisa dei rimborsi: le monete si tolgono da qui."""
    with db() as con:
        con.execute("BEGIN IMMEDIATE")
        d = con.execute("SELECT * FROM donations WHERE tx = ? AND status = 'ok'", (body.tx,)).fetchone()
        if not d:
            raise HTTPException(404, "Donazione non trovata o già stornata")
        ledger_add(con, d["wallet"], -d["coins"], "refund", body.tx)
        con.execute("UPDATE donations SET status = 'rimborsata' WHERE tx = ?", (body.tx,))
        con.execute("DELETE FROM stars WHERE tx = ?", (body.tx,))
    return {"ok": True}


class GiftIn(BaseModel):
    code: str
    coins: int


@app.post("/api/store/gift", dependencies=[Depends(require_admin)])
def gift(body: GiftIn):
    if not 0 < body.coins <= 100000:
        raise HTTPException(400, "Numero di monete non valido")
    with db() as con:
        code = admin_code(con, body.code)
        wallet_out(con, code)
        ledger_add(con, code, body.coins, "gift", uuid.uuid4().hex)
        return wallet_out(con, code)


# ---------------------------------------------------------------- bottiglie nel mare

class BottleIn(BaseModel):
    text: str
    name: str = ""


def clean(s, n):
    """Una riga sola, senza caratteri di controllo, al massimo n caratteri."""
    return re.sub(r"\s+", " ", "".join(c for c in s if c.isprintable() or c.isspace())).strip()[:n]


@app.get("/api/bottles")
def get_bottles(request: Request):
    limit(request, "bottles", 60, 60)
    with db() as con:
        return rows(con.execute("SELECT text, name FROM bottles WHERE ok = 1 ORDER BY RANDOM() LIMIT 40"))


@app.post("/api/bottles")
def new_bottle(body: BottleIn, request: Request):
    limit(request, "bottle", 5, 3600)
    text, name = clean(body.text, 200), clean(body.name, 24)
    if len(text) < 4:
        raise HTTPException(400, "Messaggio troppo corto")
    with db() as con:
        if con.execute("SELECT COUNT(*) FROM bottles WHERE ok = 0").fetchone()[0] >= 500:
            raise HTTPException(429, "Troppe bottiglie in attesa")
        con.execute("INSERT INTO bottles(text, name, created_at) VALUES (?,?,?)", (text, name, int(time.time())))
    return {"ok": True}


@app.get("/api/bottles/all", dependencies=[Depends(require_admin)])
def all_bottles():
    with db() as con:
        return rows(con.execute("SELECT * FROM bottles ORDER BY ok, created_at DESC LIMIT 600"))


@app.put("/api/bottles/{bid}", dependencies=[Depends(require_admin)])
def approve_bottle(bid: int, data: dict):
    with db() as con:
        con.execute("UPDATE bottles SET ok = ? WHERE id = ?", (1 if data.get("ok") else 0, bid))
    return {"ok": True}


@app.delete("/api/bottles/{bid}", dependencies=[Depends(require_admin)])
def delete_bottle(bid: int):
    with db() as con:
        con.execute("DELETE FROM bottles WHERE id = ?", (bid,))
    return {"ok": True}


# ---------------------------------------------------------------- il cielo dei caffè

class StarIn(BaseModel):
    name: str


@app.get("/api/stars")
def get_stars(request: Request):
    limit(request, "stars", 60, 60)
    with db() as con:
        return [{"id": r["id"], "name": r["name"] if r["ok"] else ""} for r in con.execute("SELECT id, name, ok FROM stars ORDER BY id DESC LIMIT 300")]


@app.post("/api/wallet/{code}/star")
def name_star(code: str, body: StarIn, request: Request):
    """Il nome della stella più recente di questo portafoglio; si vede dopo l'approvazione."""
    limit(request, "star", 10, 3600)
    code, name = norm_code(code), clean(body.name, 24)
    if len(name) < 2:
        raise HTTPException(400, "Nome troppo corto")
    with db() as con:
        r = con.execute("SELECT id FROM stars WHERE wallet = ? ORDER BY id DESC LIMIT 1", (code,)).fetchone()
        if not r:
            raise HTTPException(404, "Nessuna stella")
        con.execute("UPDATE stars SET name = ?, ok = 0 WHERE id = ?", (name, r["id"]))
        return wallet_out(con, code)


@app.get("/api/store/stars", dependencies=[Depends(require_admin)])
def all_stars():
    with db() as con:
        return rows(con.execute("SELECT id, name, ok FROM stars WHERE name <> '' ORDER BY ok, id DESC LIMIT 300"))


@app.put("/api/store/stars/{sid}", dependencies=[Depends(require_admin)])
def approve_star(sid: int, data: dict):
    with db() as con:
        if data.get("ok"):
            con.execute("UPDATE stars SET ok = 1 WHERE id = ?", (sid,))
        else:
            con.execute("UPDATE stars SET ok = 0, name = '' WHERE id = ?", (sid,))
    return {"ok": True}


# ---------------------------------------------------------------- meteo vero (Open-Meteo, senza chiave)
# Lo chiede il server per tutti, al massimo ogni 15 minuti: gli indirizzi dei visitatori non escono da qui.

WEATHER_URL = "https://api.open-meteo.com/v1/forecast?latitude=43.39&longitude=10.44&current=temperature_2m,weather_code,wind_speed_10m,is_day"
try:                                            # se c'è certifi si usano i suoi certificati, altrimenti quelli di sistema
    import certifi
    SSL_CTX = ssl.create_default_context(cafile=certifi.where())
except ImportError:
    SSL_CTX = ssl.create_default_context()
_weather = {"at": 0.0, "data": {"ok": False}}
_weather_lock = threading.Lock()


def weather_kind(code):
    if code in (45, 48):
        return "nebbia"
    if code in (71, 73, 75, 77, 85, 86):
        return "neve"
    if code >= 95:
        return "temporale"
    if 51 <= code <= 67 or 80 <= code <= 82:
        return "pioggia"
    return "nuvole" if code in (2, 3) else "sereno"


@app.get("/api/weather")
def weather(request: Request):
    limit(request, "weather", 60, 60)
    with _weather_lock:
        if time.time() - _weather["at"] > (900 if _weather["data"]["ok"] else 300):
            _weather["at"] = time.time()
            try:
                with urllib.request.urlopen(WEATHER_URL, timeout=5, context=SSL_CTX) as r:
                    c = json.loads(r.read(20000))["current"]
                _weather["data"] = {"ok": True, "kind": weather_kind(int(c["weather_code"])), "temp": round(float(c["temperature_2m"])), "wind": round(float(c["wind_speed_10m"]))}
            except Exception:                     # senza rete il gioco va avanti col tempo di sempre
                _weather["data"] = {"ok": False}
        return _weather["data"]


# ---------------------------------------------------------------- fantasmi gentili
# Chi c'è adesso: solo in memoria, per pochi secondi, senza nomi né indirizzi.

GHOST_SCENES = {"street", "grove", "arcade", "train", "lab"}
_ghosts = {}
_ghost_lock = threading.Lock()
_ghost_salt = secrets.token_bytes(8)


class GhostIn(BaseModel):
    id: str
    scene: str
    x: float = 0
    dir: int = 1
    wave: int = 0


@app.post("/api/presence")
def presence(body: GhostIn, request: Request):
    limit(request, "presence", 240, 60)
    if not re.fullmatch(r"[a-z0-9]{12,32}", body.id) or body.scene not in GHOST_SCENES or not -100 < body.x < 10000:
        raise HTTPException(400, "Dati non validi")
    now = time.time()
    with _ghost_lock:
        for k in [k for k, g in _ghosts.items() if now - g["t"] > 9]:
            del _ghosts[k]
        if body.id in _ghosts or len(_ghosts) < 400:
            _ghosts[body.id] = {"t": now, "scene": body.scene, "x": round(body.x, 1), "dir": 1 if body.dir > 0 else -1, "wave": body.wave % 1000}
        others = [(k, g) for k, g in _ghosts.items() if k != body.id and g["scene"] == body.scene][:12]
    # agli altri arriva un'impronta, non l'id: nessuno può fingersi un altro
    return [{"k": hashlib.sha256(_ghost_salt + k.encode()).hexdigest()[:10], "x": g["x"], "dir": g["dir"], "wave": g["wave"]} for k, g in others]


# ---------------------------------------------------------------- importazione

TABLE_COLS = {}


def table_cols(con, table):
    if table not in TABLE_COLS:
        TABLE_COLS[table] = [r["name"] for r in con.execute(f"PRAGMA table_info({table})")]
    return TABLE_COLS[table]


@app.post("/api/import", dependencies=[Depends(require_admin)])
def import_all(data: dict):
    """Ripristina un backup (Esporta tutto / data.json / contenuti.json).
    settings: aggiornate chiave per chiave. sections, items, bubbles: se presenti nel file SOSTITUISCONO quelle attuali.
    Prima di toccare qualcosa salva una copia del database in data/backup-AAAAMMGG-HHMMSS.db."""
    import shutil
    stamp = time.strftime("%Y%m%d-%H%M%S")
    backup = DATA / f"backup-{stamp}.db"
    n = 1
    while backup.exists():
        n += 1
        backup = DATA / f"backup-{stamp}-{n}.db"
    with db() as con:
        con.execute("VACUUM INTO ?", (str(backup),)) if sqlite3.sqlite_version_info >= (3, 27) else shutil.copy(DB_PATH, backup)
    counts = {}
    with db() as con:
        settings = data.get("settings") or {}
        for k, v in settings.items():
            if re.fullmatch(r"[a-z0-9_]{1,64}", k):
                con.execute("INSERT INTO settings(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                            (k, "" if v is None else str(v)))
        counts["settings"] = len(settings)
        sections = data.get("sections")
        items = data.get("items")
        if items is None and sections and any("items" in s for s in sections):   # formato di /api/public e data.json
            items = [it for s in sections for it in s.get("items", [])]
        if sections is not None:
            con.execute("DELETE FROM items")
            con.execute("DELETE FROM sections")
            cols = table_cols(con, "sections")
            for s in sections:
                row = {k: (int(v) if isinstance(v, bool) else v) for k, v in s.items() if k in cols}
                con.execute(f"INSERT INTO sections({', '.join(row)}) VALUES ({', '.join('?' * len(row))})", tuple(row.values()))
            counts["sections"] = len(sections)
        if items is not None:
            if sections is None:
                con.execute("DELETE FROM items")
            cols = table_cols(con, "items")
            now = int(time.time())
            for it in items:
                row = {k: v for k, v in it.items() if k in cols and k != "id"}
                if isinstance(row.get("tags"), list):
                    row["tags"] = ", ".join(row["tags"])
                row = {k: (int(v) if isinstance(v, bool) else v) for k, v in row.items()}
                row.setdefault("updated_at", now)
                con.execute(f"INSERT INTO items({', '.join(row)}) VALUES ({', '.join('?' * len(row))})", tuple(row.values()))
            counts["items"] = len(items)
        bubbles = data.get("bubbles")
        if bubbles is not None:
            con.execute("DELETE FROM bubbles")
            cols = table_cols(con, "bubbles")
            for b in bubbles:
                row = {k: (int(v) if isinstance(v, bool) else v) for k, v in b.items() if k in cols and k != "id"}
                con.execute(f"INSERT INTO bubbles({', '.join(row)}) VALUES ({', '.join('?' * len(row))})", tuple(row.values()))
            counts["bubbles"] = len(bubbles)
    return {"ok": True, "imported": counts, "backup": backup.name}


# ---------------------------------------------------------------- statici

app.mount("/uploads", StaticFiles(directory=UPLOADS), name="uploads")
app.mount("/game", StaticFiles(directory=PUBLIC / "game", html=True), name="game")          # versione Godot
app.mount("/classic", StaticFiles(directory=PUBLIC / "classic", html=True), name="classic")  # versione HTML/JS
app.mount("/admin", StaticFiles(directory=PUBLIC / "admin", html=True), name="admin")


@app.get("/")
def root():
    return RedirectResponse("/game/")


init_db()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=os.environ.get("CAMERETTA_HOST", "127.0.0.1"), port=int(os.environ.get("CAMERETTA_PORT", "8000")))
