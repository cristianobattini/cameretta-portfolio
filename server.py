"""La cameretta — server locale.

Avvio:  python server.py          (poi apri http://localhost:8000 e http://localhost:8000/admin)
Dati:   data/cameretta.db (SQLite)  ·  file caricati in data/uploads/

Variabili d'ambiente opzionali:
  CAMERETTA_PORT        porta (default 8000)
  CAMERETTA_HOST        host (default 127.0.0.1, solo questo computer)
  CAMERETTA_ADMIN_TOKEN se impostata, l'admin chiede questa password per salvare

Ogni testo visibile ha due versioni: il campo normale (italiano) e quello con
suffisso _en (inglese). Se il campo _en è vuoto, il sito mostra l'italiano.
"""
import os
import re
import sqlite3
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Optional

from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
UPLOADS = DATA / "uploads"
DB_PATH = DATA / "cameretta.db"
PUBLIC = ROOT / "public"
DATA.mkdir(exist_ok=True)
UPLOADS.mkdir(exist_ok=True)

ADMIN_TOKEN = os.environ.get("CAMERETTA_ADMIN_TOKEN", "")
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
"""

# colonne aggiunte dopo la prima versione (migrazione automatica)
EXTRA_COLUMNS = {
    "sections": ["object_name_en", "sign_label_en", "title_en", "intro_en", "link_url", "link_label", "link_label_en"],
    "items": ["grp_en", "kicker_en", "title_en", "description_en", "link_label_en", "status_en"],
}

# ---------------------------------------------------------------- contenuti iniziali

DEFAULT_SETTINGS = {
    "site_name": "ERACUL",
    "menu_kicker": "PORTFOLIO · 2026", "menu_kicker_en": "PORTFOLIO · 2026",
    "menu_subtitle": "~ la cameretta ~", "menu_subtitle_en": "~ the little room ~",
    "menu_tagline": "sviluppo · fisica · appunti · libri", "menu_tagline_en": "code · physics · notes · books",
    "menu_enter_label": "INIZIA", "menu_enter_label_en": "START",
    "press_text": "PREMI INVIO PER INIZIARE", "press_text_en": "PRESS ENTER TO START",
    "footer_text": "v2.0 · fatto a mano a Rosignano", "footer_text_en": "v2.0 · handmade in Rosignano",
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
}

GH = "https://github.com/cristianobattini/"

SEED_SECTIONS = [
    dict(id="finestra", object_name="Finestra", object_name_en="Window", sign_label="Percorso", sign_label_en="Journey",
         title="Il mio percorso e CV", title_en="My journey and CV", color="#1b2350", sort=1,
         intro="Dalla finestra si vede il mare. Questa è la strada fatta finora, e quella che ho davanti.",
         intro_en="From the window you can see the sea. This is the road so far, and the one ahead."),
    dict(id="scrivania", object_name="Scrivania", object_name_en="Desk", sign_label="Progetti", sign_label_en="Projects",
         title="Progetti di programmazione", title_en="Programming projects", color="#23406e", sort=2,
         intro="Qui sopra c'è tutto quello che ho scritto, rotto e rimesso in piedi. Dal web all'hardware.",
         intro_en="Everything I've written, broken and put back together lives on this desk. From the web to hardware.",
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
    it("finestra", "Il percorso", "The journey", "Adesso", "Now", "Studente di fisica all'Università di Pisa", "Physics student at the University of Pisa",
       "Fisica 1, Analisi Matematica, Geometria e Algebra Lineare, Laboratorio 1 ed Elementi di Computazione.",
       "Physics 1, Calculus, Geometry and Linear Algebra, Lab 1 and Elements of Computing."),
    it("finestra", "Il percorso", "The journey", "Lavoro", "Work", "Sviluppatore full-stack", "Full-stack developer",
       "Esperienza in ruoli di R&D e frontend: interfacce in Angular e React, servizi in Python e FastAPI.",
       "Experience in R&D and frontend roles: interfaces in Angular and React, services in Python and FastAPI."),
    it("finestra", "Il percorso", "The journey", "Sempre", "Always", "Progetti indipendenti", "Independent projects",
       "App per studenti, strumenti con AI, algoritmi di trading, simulazioni di fisica, un logger su Arduino. Sono tutti sulla scrivania.",
       "Apps for students, AI tools, trading algorithms, physics simulations, an Arduino logger. They're all on the desk."),
    it("finestra", "Strumenti", "Toolbox", "Stack", "Stack", "Con cosa lavoro", "What I work with", "", "",
       "Angular, React, React Native, Expo, TypeScript, Next.js, NestJS, Python, FastAPI, Supabase, C++"),

    it("scrivania", "In evidenza", "Featured", "App mobile · Expo", "Mobile app · Expo", "Provia", "Provia",
       "Per studenti universitari: carriera, voti, CFU, medie, tasse, orari e appelli in un posto solo. Privacy by design, nessuna password d'ateneo.",
       "For university students: career, grades, credits, averages, fees, timetables and exams in one place. Privacy by design, no university passwords.",
       "React Native, Expo, Supabase", GH + "Provia"),
    it("scrivania", "In evidenza", "Featured", "Monorepo · NestJS", "Monorepo · NestJS", "UniTrend", "UniTrend",
       "Collega l'ateneo con login ufficiale OAuth2 e analizza l'andamento universitario. Architettura a connettori (ESSE3, GOMP).",
       "Connects to your university via official OAuth2 login and analyses your progress. Connector-based architecture (ESSE3, GOMP).",
       "NestJS, Prisma, Expo, PostgreSQL, Redis", GH + "universita_app"),
    it("scrivania", "In evidenza", "Featured", "Terminale · Astropy", "Terminal · Astropy", "Astro Assistant", "Astro Assistant",
       "App da terminale a schermo intero per pianificare osservazioni e astrofotografia: catalogo Messier, meteo e la notte giusta.",
       "A full-screen terminal app to plan observations and astrophotography: Messier catalogue, conditions and the right night.",
       "Python, Textual, Astropy, SQLite", GH + "astro_assistant"),
    it("scrivania", "In evidenza", "Featured", "Fisica · simulazione", "Physics · simulation", "Linee di forza del campo elettrico", "Electric field lines simulator",
       "Simulatore delle linee di forza del campo elettrico generato da cariche puntiformi.",
       "Simulates the field lines of the electric field generated by point charges.",
       "Python", GH + "electric_field_force_lines_sim"),
    it("scrivania", "In evidenza", "Featured", "Trading · cTrader", "Trading · cTrader", "Anakin cAlgo", "Anakin cAlgo",
       "Algoritmo per cTrader: ingressi precisi, doppio take profit, break-even e gestione del rischio.",
       "A cTrader algorithm: precise entries, dual take profit, break-even and risk management.",
       "C#, cTrader", GH + "Anakin-cAlgo"),
    it("scrivania", "In evidenza", "Featured", "App mobile · Expo", "Mobile app · Expo", "GalleryClean", "GalleryClean",
       "Pulisci la galleria con uno swipe: a destra elimini, a sinistra tieni.",
       "Clean up your photo gallery with a swipe: right to delete, left to keep.",
       "React Native, Expo", GH + "GalleryClean"),
    it("scrivania", "Altri progetti", "More projects", "Next.js · Supabase", "Next.js · Supabase", "anakin/", "anakin/",
       "Il mio forum personale, \"pensare ad alta voce\": sezioni, thread, bacheca file e pannello admin.",
       "My personal forum, \"thinking out loud\": sections, threads, a file board and an admin panel.", "Next.js, Supabase"),
    it("scrivania", "Altri progetti", "More projects", "AI · trading", "AI · trading", "Anakin Next", "Anakin Next",
       "Copilota di trading con AI: un transformer in PyTorch affiancato dalla Claude API.",
       "An AI trading copilot: a PyTorch transformer working alongside the Claude API.", "React, FastAPI, PyTorch"),
    it("scrivania", "Altri progetti", "More projects", "Web · mobile", "Web · mobile", "biblio", "biblio",
       "La mia libreria digitale: scansiono il codice a barre e i dati arrivano da Open Library.",
       "My digital library: scan the barcode and the details come from Open Library.", "Next.js, Expo, Supabase"),
    it("scrivania", "Altri progetti", "More projects", "AI · email", "AI · email", "Mail AI", "Mail AI",
       "Gestione email con AI per Gmail e Outlook. Token solo in locale, ogni azione la approvo io.",
       "AI email management for Gmail and Outlook. Tokens stay local, I approve every action.", "React, FastAPI, Claude API"),
    it("scrivania", "Altri progetti", "More projects", "Hardware", "Hardware", "Motion Logger", "Motion Logger",
       "Arduino Nano + MPU6050: registra il movimento a 50 Hz su scheda SD, in CSV.",
       "Arduino Nano + MPU6050: logs motion at 50 Hz to an SD card, as CSV.", "C++, PlatformIO, Arduino"),
    it("scrivania", "Altri progetti", "More projects", "Questo sito", "This site", "La cameretta", "The little room",
       "Questo portfolio: la stanza è renderizzata da un mini raycaster in Python, i suoni sono sintetizzati nel browser.",
       "This portfolio: the room is rendered by a tiny Python raycaster, every sound is synthesised in the browser.",
       "Python, FastAPI, SQLite, Canvas, Web Audio"),

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
    ("intro", "Ciao! Sono Eracul. Benvenuto nel mio piccolo angolo di internet.", "Hi! I'm Eracul. Welcome to my little corner of the internet.", ""),
    ("intro", "Sono uno sviluppatore full-stack di Rosignano Solvay, un paese sul mare vicino a Pisa.", "I'm a full-stack developer from Rosignano Solvay, a small town by the sea near Pisa.", ""),
    ("intro", "Studio fisica all'Università di Pisa. Il mio preferito? L'elettromagnetismo.", "I study physics at the University of Pisa. My favourite part? Electromagnetism.", ""),
    ("quote", "Ciò che non so creare, non lo capisco.", "What I cannot create, I do not understand.", "Richard Feynman"),
    ("intro", "Ho costruito app per studenti, strumenti con AI, algoritmi di trading e un logger su Arduino.", "I've built apps for students, AI tools, trading algorithms and an Arduino logger.", ""),
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


def init_db():
    with db() as con:
        con.executescript(SCHEMA)
        for table, cols in EXTRA_COLUMNS.items():
            have = {r["name"] for r in con.execute(f"PRAGMA table_info({table})")}
            for c in cols:
                if c not in have:
                    con.execute(f"ALTER TABLE {table} ADD COLUMN {c} TEXT NOT NULL DEFAULT ''")
        for k, v in DEFAULT_SETTINGS.items():
            con.execute("INSERT OR IGNORE INTO settings(key, value) VALUES (?, ?)", (k, v))
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


# ---------------------------------------------------------------- statici

app.mount("/uploads", StaticFiles(directory=UPLOADS), name="uploads")
app.mount("/game", StaticFiles(directory=PUBLIC / "game", html=True), name="game")
app.mount("/admin", StaticFiles(directory=PUBLIC / "admin", html=True), name="admin")


@app.get("/")
def root():
    return RedirectResponse("/game/")


init_db()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=os.environ.get("CAMERETTA_HOST", "127.0.0.1"), port=int(os.environ.get("CAMERETTA_PORT", "8000")))
