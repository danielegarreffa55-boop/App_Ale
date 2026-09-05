# Barbatum — Barberia Sartoriale

Applicazione Flutter per iOS, Android e Web con interfaccia cliente, dashboard amministratore responsive e backend Firebase. `salon_booking` è soltanto il nome tecnico; brand, contatti, colori e identificatori di pubblicazione sono sostituibili.

## Funzioni implementate

- Registrazione email/password, verifica email, recupero password, logout ed eliminazione/anomizzazione account.
- Catalogo servizi amministrabile, orari settimanali, ferie/chiusure tramite blocchi agenda.
- Richiesta cliente sempre `PENDING_ADMIN`; l'admin può accettare, rifiutare o fare una controproposta.
- Accettazione/rifiuto della controproposta da parte del cliente.
- Conferma e spostamento protetti da transazioni e lock Firestore a bucket da 5 minuti.
- Dashboard admin Web/mobile: metriche, richieste, agenda, clienti, servizi, orari e impostazioni.
- FCM multi-dispositivo, pulizia token invalidi e log idempotente delle notifiche.
- Promemoria schedulato il giorno precedente in `Europe/Rome`.
- Google Calendar solo backend, con event ID deterministico e aggiornamento/cancellazione idempotenti.
- Security Rules deny-by-default, Custom Claims admin, App Check e rate limiting callable.
- Emulator Suite, seed demo, test Flutter/backend/rules/race, CI GitHub Actions.

## Avvio rapido locale

```powershell
Copy-Item config\emulator.example.json config\emulator.json
npm install
npm --prefix functions install
npm run emulators
```

In un secondo terminale:

```powershell
$env:FIRESTORE_EMULATOR_HOST='127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST='127.0.0.1:9099'
$env:GCLOUD_PROJECT='salon-booking-demo'
npm run seed
flutter run -d chrome --dart-define-from-file=config/emulator.json
```

Account demo creati esclusivamente nell'emulatore:

- `admin@demo.local` / `DemoOnly-ChangeMe-123!`
- `cliente@demo.local` / `DemoOnly-ChangeMe-123!`

Per ambiente, Firebase, Calendar, notifiche e release seguire [SETUP.md](SETUP.md) e [DEPLOYMENT.md](DEPLOYMENT.md). Le decisioni tecniche e il modello dati sono in [ARCHITECTURE.md](ARCHITECTURE.md).

## Qualità

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
npm --prefix functions run build
npm --prefix functions test
npm --prefix functions audit --omit=dev
```

Il test race e i test Security Rules completi richiedono Firestore Emulator:

```powershell
firebase emulators:exec --only firestore --project salon-booking-demo "npm --prefix functions test"
```

## Limite iOS su Windows

Il progetto iOS è incluso e configurato, ma Xcode, firma, APNs e `flutter build ipa --release` richiedono obbligatoriamente macOS. Non esiste una build iOS locale supportata su Windows.
