# Setup sviluppo

## Toolchain verificata

Ambiente preparato su Windows 11 Pro x64:

- Flutter stable 3.47.2, Dart 3.13.2.
- Android Studio 2026.1.3.7 con JBR 25.0.2.
- Android SDK/API 36, build-tools 36.0.0, platform-tools 37.0.1, NDK 28.2.13676358.
- Node.js 22.14.0, npm 10.9.2.
- Firebase CLI 15.28.2, FlutterFire CLI 1.4.1, Git 2.52.0.
- Python 3 con ambiente virtuale in `backend/.venv`; Google Cloud CLI per il deploy Cloud Run.

Flutter è in `C:\Users\Daniele\develop\flutter`; SDK Android in `%LOCALAPPDATA%\Android\Sdk`. `PATH`, `JAVA_HOME`, `ANDROID_HOME` e `ANDROID_SDK_ROOT` sono impostati per l'utente. Riavviare terminali/IDE già aperti per rileggere le variabili.

Visual Studio C++ non è installato perché il repository non targetta Windows desktop. Xcode non è disponibile su Windows: usare un Mac per iOS.

## Configurazione centralizzata

I valori client sono letti con `--dart-define-from-file`. Copiare senza committare:

```powershell
Copy-Item config\dev.example.json config\dev.json
```

Compilare `STUDIO_NAME`, `APP_NAME`, contatti, Firebase public config e chiave VAPID. I file JSON client Firebase non contengono segreti, ma sono tenuti per ambiente fuori da Git. I segreti reali, service account, chiavi APNs e keystore non devono mai entrare nel repository.

## Produzione Cloud Run + Firestore

Passaggi manuali inevitabili:

1. Eseguire `firebase login` e completare OAuth nel browser.
2. Eseguire `gcloud auth login` e `gcloud auth application-default login`.
3. Identificare il billing account con `gcloud billing accounts list`.
4. Creare progetto, database Firestore UE, service account e API Cloud Run con:

```powershell
.\infrastructure\deploy-gcp.ps1 `
  -ProjectId 'PROJECT_ID_UNIVOCO' `
  -BillingAccount 'XXXXXX-XXXXXX-XXXXXX' `
  -GoogleCalendarId 'CALENDAR_ID'
```

5. In Authentication abilitare Email/Password e configurare domini/link email.
6. Registrare app Android, iOS e Web con identificatori definitivi.
7. Copiare `config/production.example.json` in `config/production.json` e compilare le opzioni pubbliche Firebase e l'URL Cloud Run stampato dallo script.
8. Eseguire:

```powershell
flutterfire configure --project YOUR_PROJECT_ID --platforms android,ios,web
```

I file nativi generati sono ignorati da Git. L'app usa anche le opzioni esplicite in `config/production.json` per supportare più ambienti.

9. Copiare `.firebaserc.example` in `.firebaserc` e sostituire il project ID.
10. Configurare App Check: Play Integrity per Android, App Attest con fallback DeviceCheck per iOS e reCAPTCHA v3 per Web. In debug registrare soltanto token debug autorizzati.

### API Python locale

```powershell
python -m venv backend\.venv
backend\.venv\Scripts\python.exe -m pip install -r backend\requirements-dev.txt
$env:GOOGLE_CLOUD_PROJECT='salon-booking-demo'
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
npm run api:run
```

Per Android Emulator impostare anche `BACKEND_API_URL` a `http://10.0.2.2:8088`. Se rimane vuoto viene usato il fallback Functions.

## Configurazione Firebase client

Passaggi successivi al deploy:

1. Per FCM Web creare una Web Push certificate, inserire la chiave pubblica in `FCM_WEB_VAPID_KEY`, quindi:

```powershell
npm run configure:web-fcm
```


## Emulatori

`npm run emulators` avvia Auth, Firestore, Functions, Hosting e UI su `http://localhost:4000`. Copiare `config/emulator.example.json` in `config/emulator.json`.

Firebase CLI richiede Java 21 o successivo. Su questa workstation una vecchia installazione Oracle può precedere il JBR nel `PATH`; prima di avviare gli emulatori verificare `java --version` e, se mostra Java 8, usare nella sessione corrente:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
```

Per seed in PowerShell:

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:GCLOUD_PROJECT='salon-booking-demo'
npm run seed
```

Per Android Emulator sovrascrivere l'host:

```powershell
flutter run --dart-define-from-file=config/emulator.json --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Il test d'integrazione Flutter richiede un dispositivo Android/iOS reale o emulato (il runner non supporta Chrome):

```powershell
flutter test integration_test\app_test.dart -d DEVICE_ID
```

## Primo proprietario e gestori

Creare prima l'utente tramite app/Auth. Poi autenticare Application Default Credentials (`gcloud auth application-default login`) oppure impostare `GOOGLE_APPLICATION_CREDENTIALS` verso un file esterno al repository e lanciare:

```powershell
$env:GOOGLE_CLOUD_PROJECT='PROJECT_ID'
backend\.venv\Scripts\python.exe backend\scripts\bootstrap_production.py
backend\.venv\Scripts\python.exe backend\scripts\set_owner.py proprietario@example.it
```

Lo script crea il primo `owner`, che ha accesso completo e può assegnare i ruoli dalla sezione **Staff e ruoli** della console. I ruoli disponibili sono proprietario, gestore prenotazioni e cliente. Il gestore usa tutta la console operativa ma non può cambiare i permessi.

Il comando `set-admin` resta disponibile soltanto come procedura tecnica di emergenza e assegna il ruolo di gestore. Dopo ogni cambio di ruolo l'account interessato deve uscire e rientrare per ricevere un nuovo ID token. Nessuna schermata cliente e nessuna scrittura diretta su Firestore possono modificare i ruoli.
