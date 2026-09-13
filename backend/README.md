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

## Hosting esterno (container o servizio Python)

Impostare **`backend` come root directory** del servizio. Se l'hosting supporta Docker, usare `backend/Dockerfile` (con root directory `backend`). Se usa un processo Python, installare `requirements.txt` e impostare il comando di avvio:

```sh
uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1
```

Per verificare l'avvio, usare `https://<dominio-api>/healthz`; `https://<dominio-api>/readyz` verifica anche il collegamento a MongoDB. Il container apre la porta assegnata dall'hosting tramite `PORT`. Non impostare `PORT` manualmente se la piattaforma lo fornisce.

In ambiente di produzione (`APP_ENV=production`) configurare nel pannello **Variables/Secrets** dell'hosting:

| Variabile | Valore richiesto |
| --- | --- |
| `MONGODB_URI` | Connection string di un cluster MongoDB remoto, raggiungibile dall'hosting; non usare `localhost` |
| `MONGODB_DATABASE` | Nome del database, ad esempio `alessio_garreffa_hair` |
| `MONGODB_TRANSACTIONS` | `true`; il cluster deve supportare le transazioni (replica set) |
| `JWT_SECRET` | Stringa casuale univoca di almeno 32 byte |
| `CRON_SECRET` | Stringa casuale univoca di almeno 32 byte, oppure configurare insieme `CRON_OIDC_AUDIENCE` e `CRON_SERVICE_ACCOUNT` |
| `PUBLIC_APP_URL` | URL HTTPS pubblico usato nei link inviati per email, per esempio `https://prenota.example.it` |
| `ONESIGNAL_APP_ID`, `ONESIGNAL_API_KEY` | Credenziali OneSignal per le notifiche push |
| `SMTP_HOST`, `SMTP_FROM`, `SMTP_PASSWORD` | Parametri del servizio email per verifica account e reset password |

Impostare anche `SMTP_PORT`, `SMTP_USERNAME` e `SMTP_USE_TLS` secondo il provider email. `CORS_ORIGINS` contiene gli origin web Flutter separati da virgole, se si pubblica anche Flutter Web; non serve per le app Android/iOS. Conservare i segreti solo nel pannello dell'hosting, mai nel repository o nel JSON Flutter.

L'app verifica queste variabili all'import: se manca una variabile obbligatoria, FastAPI termina **prima** di aprire la porta. Nei log cercare l'ultima riga `RuntimeError: ...` del traceback, che indica il valore da correggere. Dopo che `/healthz` risponde, controllare anche `/readyz`: se non risponde, verificare URI, credenziali e autorizzazioni di rete di MongoDB Atlas.

Infine inserire l'URL HTTPS dell'API (senza `/healthz`) in `BACKEND_API_URL` di `config/production.json` e ricompilare Flutter con `--dart-define-from-file=config/production.json`.
