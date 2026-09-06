# FastAPI backend

API proprietaria per autenticazione JWT, ruoli, prenotazioni e configurazione studio. Usa MongoDB tramite PyMongo; non dipende da Firebase Auth, Firestore o Cloud Functions.

## Sviluppo

```powershell
py -3.11 -m venv backend\.venv
backend\.venv\Scripts\python.exe -m pip install -r backend\requirements-dev.txt
$env:MONGODB_URI='mongodb://127.0.0.1:27017'
$env:MONGODB_DATABASE='agh_dev'
$env:MONGODB_TRANSACTIONS='false'
$env:EXPOSE_DEV_TOKENS='true'
backend\.venv\Scripts\python.exe -m uvicorn app.main:app --app-dir backend --reload --port 8088
```

OpenAPI è disponibile su `http://127.0.0.1:8088/docs` in sviluppo. In produzione la documentazione interattiva è disabilitata.

## Bootstrap

```powershell
backend\.venv\Scripts\python.exe backend\scripts\bootstrap_production.py
backend\.venv\Scripts\python.exe backend\scripts\set_owner.py owner@example.it
```

Il secondo comando richiede che l’account sia stato registrato prima. Revoca tutte le sue sessioni: il proprietario deve quindi eseguire nuovamente il login.
