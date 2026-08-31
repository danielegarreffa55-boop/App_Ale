# Setup sviluppo

## Toolchain verificata

Ambiente preparato su Windows 11 Pro x64:

- Flutter stable 3.47.2, Dart 3.13.2.
- Android Studio 2026.1.3.7 con JBR 25.0.2.
- Android SDK/API 36, build-tools 36.0.0, platform-tools 37.0.1, NDK 28.2.13676358.
- Node.js 22.14.0, npm 10.9.2.
- Firebase CLI 15.28.2, FlutterFire CLI 1.4.1, Git 2.52.0.

Flutter è in `C:\Users\Daniele\develop\flutter`; SDK Android in `%LOCALAPPDATA%\Android\Sdk`. `PATH`, `JAVA_HOME`, `ANDROID_HOME` e `ANDROID_SDK_ROOT` sono impostati per l'utente. Riavviare terminali/IDE già aperti per rileggere le variabili.

Visual Studio C++ non è installato perché il repository non targetta Windows desktop. Xcode non è disponibile su Windows: usare un Mac per iOS.

## Configurazione centralizzata

I valori client sono letti con `--dart-define-from-file`. Copiare senza committare:

```powershell
Copy-Item config\dev.example.json config\dev.json
```

Compilare `STUDIO_NAME`, `APP_NAME`, contatti, Firebase public config e chiave VAPID. I file JSON client Firebase non contengono segreti, ma sono tenuti per ambiente fuori da Git. I segreti reali, service account, chiavi APNs e keystore non devono mai entrare nel repository.

## Firebase production

Passaggi manuali inevitabili:

1. Eseguire `firebase login` e completare OAuth nel browser.
2. Creare o scegliere un progetto Firebase; abilitare billing per Functions Gen 2 e Scheduler.
3. In Authentication abilitare Email/Password e configurare domini/link email.
4. Creare Firestore in una regione UE coerente, preferibilmente `eur3`.
5. Registrare app Android, iOS e Web con identificatori definitivi.
6. Eseguire:

```powershell
flutterfire configure --project YOUR_PROJECT_ID --platforms android,ios,web
```

I file nativi generati sono ignorati da Git. Copiare anche il config Web/Android/iOS pubblico dentro `config/dev.json`; l'app usa opzioni esplicite per supportare più ambienti.

7. Copiare `.firebaserc.example` in `.firebaserc` e sostituire il project ID.
8. Per FCM Web creare una Web Push certificate, inserire la chiave pubblica in `FCM_WEB_VAPID_KEY`, quindi:

```powershell
npm run configure:web-fcm
```

9. Configurare App Check: Play Integrity per Android, App Attest con fallback DeviceCheck per iOS e reCAPTCHA v3 per Web. In debug registrare soltanto token debug autorizzati.

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

## Primo amministratore

Creare prima l'utente tramite app/Auth. Poi autenticare Application Default Credentials (`gcloud auth application-default login`) oppure impostare `GOOGLE_APPLICATION_CREDENTIALS` verso un file esterno al repository e lanciare:

```powershell
npm --prefix functions run set-admin -- amministratore@example.it
```

Lo script imposta il Custom Claim `admin` e il campo server-only `isAdmin` usato per notificare gli amministratori. L'utente deve uscire e rientrare per ricevere un nuovo ID token. Nessuna schermata client può assegnare il ruolo.
