# Configurazione

## Account da creare

Tutti gli account e i metodi di recupero devono essere intestati all’attività, non allo sviluppatore e non a un profilo Google personale:

1. organizzazione MongoDB Atlas con cluster nella regione UE;
2. workspace OneSignal;
3. casella mittente o provider SMTP del dominio;
4. progetto Google Cloud dedicato per Cloud Run e trasporto push Android;
5. Apple Developer dell’attività per APNs e pubblicazione iOS;
6. calendario Google dedicato allo studio, se si desidera la sincronizzazione.

Conservare proprietari di riserva e codici di recupero in un password manager aziendale.

## Backend locale o staging

1. Installare Python 3.11+ e creare `backend/.venv`.
2. Installare `backend/requirements-dev.txt`.
3. Copiare i nomi da `.env.example` nel gestore variabili dell’ambiente. Il codice non carica automaticamente file `.env`.
4. Impostare `MONGODB_URI` su un database di sviluppo separato. Per Mongo locale lasciare `MONGODB_TRANSACTIONS=false`; Atlas di produzione usa `true`.
5. Eseguire lo script di bootstrap una sola volta.
6. Avviare Uvicorn e verificare `/healthz`, `/readyz` e `/docs`.

In sviluppo `EXPOSE_DEV_TOKENS=true` restituisce i token di verifica/reset nelle risposte API. La modalità produzione rifiuta esplicitamente questa opzione.

## Flutter

Creare un file ignorato da Git partendo da `config/emulator.example.json` o `config/production.example.json`:

```json
{
  "BACKEND_API_URL": "https://api.example.it",
  "ONESIGNAL_APP_ID": "00000000-0000-0000-0000-000000000000"
}
```

Avviare Android Emulator con:

```powershell
flutter run -d android --dart-define-from-file=config/emulator.json
```

Access e refresh token sono memorizzati con `flutter_secure_storage`; nessun segreto backend deve entrare nel file JSON Flutter.

## Email di verifica e reset

Configurare `SMTP_HOST`, porta, utente, password e mittente verificato. `PUBLIC_APP_URL` deve puntare al dominio HTTPS che ospita il client Flutter Web. Le email generano collegamenti hash `/#/verify-email` e `/#/reset-password`, quindi funzionano anche su hosting statico senza regole di rewrite. Le due pagine sono già presenti nel router Flutter.

## OneSignal

1. Creare una app OneSignal dell’attività.
2. Inserire l’App ID pubblico nel JSON Flutter e nel runtime backend.
3. Inserire la REST API key esclusivamente nel Secret Manager del backend.
4. In OneSignal configurare Android con le credenziali FCM del progetto aziendale.
5. Configurare iOS con la chiave APNs dell’account Apple aziendale e completare in Xcode Push Notifications, Background Modes e Notification Service Extension.
6. Provare su dispositivi reali: foreground, background, app terminata, logout, reinstallazione e secondo dispositivo.

OneSignal elimina il codice Firebase dall’app e centralizza targeting/log, ma Android continua necessariamente a usare il trasporto push di Google. Questo non richiede collegare un account personale: progetto e credenziali devono appartenere all’attività.

## Google Calendar senza account personale

Creare un calendario dedicato, per esempio `Prenotazioni AGH`, posseduto dall’account aziendale. Dopo il deploy condividere soltanto quel calendario con il service account Cloud Run stampato dallo script, autorizzandolo a modificare gli eventi. Impostare l’ID in `GOOGLE_CALENDAR_ID`.

Il database resta MongoDB: Calendar è una copia operativa degli appuntamenti confermati, non contiene utenti, password o ruoli.
