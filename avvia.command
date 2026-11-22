#!/bin/bash
# Doppio clic su macOS: prepara l'ambiente la prima volta e avvia il server.
cd "$(dirname "$0")"
if [ ! -d .venv ]; then
  python3 -m venv .venv && ./.venv/bin/pip install -q -r requirements.txt
fi
( sleep 2; open "http://localhost:8000/" ; open "http://localhost:8000/admin/" ) &
./.venv/bin/python server.py
