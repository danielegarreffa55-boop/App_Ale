# API Python

API FastAPI destinata a Google Cloud Run. Usa Firebase Authentication per
l'identità, i Custom Claims per i ruoli e Cloud Firestore in Native mode come
database persistente.

## Sviluppo locale

```powershell
python -m venv backend\.venv
backend\.venv\Scripts\python.exe -m pip install -r backend\requirements-dev.txt
$env:GOOGLE_CLOUD_PROJECT='salon-booking-demo'
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
npm run api:run
```

Health check: `http://127.0.0.1:8088/healthz`. Per far usare l'API locale
all'emulatore Android impostare `BACKEND_API_URL` a `http://10.0.2.2:8088`.
Senza questo valore l'app continua a usare le callable Functions locali.

## Produzione

L'infrastruttura viene creata con:

```powershell
.\infrastructure\deploy-gcp.ps1 `
  -ProjectId 'PROJECT_ID_UNIVOCO' `
  -BillingAccount 'XXXXXX-XXXXXX-XXXXXX' `
  -GoogleCalendarId 'CALENDAR_ID'
```

Il servizio Cloud Run è pubblico a livello di rete per consentire l'accesso
alle app mobili, ma ogni rotta applicativa verifica un Firebase ID token. Solo
`/healthz` è pubblica. Il runtime usa un service account dedicato con i soli
ruoli Firestore, Firebase Authentication e logging necessari.

Dopo la creazione dell'utente proprietario, assegnare il primo ruolo con ADC:

```powershell
gcloud auth application-default login
$env:GOOGLE_CLOUD_PROJECT='PROJECT_ID'
backend\.venv\Scripts\python.exe backend\scripts\bootstrap_production.py
backend\.venv\Scripts\python.exe backend\scripts\set_owner.py EMAIL
```

Il bootstrap usa `create`: se `studio/config` esiste già non sovrascrive nulla
e non inserisce account o servizi demo. I servizi reali si aggiungono dalla
dashboard proprietario.
