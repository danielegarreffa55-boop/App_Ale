# Deployment e release

## Precondizioni

- Brand, package name/bundle ID, contatti e testi legali approvati.
- Account Google Cloud con billing attivo e permessi per creare progetto, Firestore, Cloud Run, Auth e service account.
- `gcloud auth login`, `gcloud auth application-default login`, `firebase login` e `config/production.json` non committato.
- Test automatici puliti e UAT su progetto staging separato.

## Backend Python e database reale

```powershell
.\infrastructure\deploy-gcp.ps1 `
  -ProjectId 'PROJECT_ID_UNIVOCO' `
  -BillingAccount 'XXXXXX-XXXXXX-XXXXXX' `
  -GoogleCalendarId 'CALENDAR_ID'
```

Lo script crea o riutilizza il progetto, collega il billing, abilita le API, crea Firestore Native in `eur3` con protezione eliminazione, pubblica Rules/Indexes, crea un service account con privilegi minimi e distribuisce FastAPI su Cloud Run in `europe-west1`. Il servizio è raggiungibile via HTTPS, mentre tutte le rotte applicative richiedono un Firebase ID token valido.

Creare `config/production.json` dal relativo esempio, inserire l'URL restituito in `BACKEND_API_URL` e compilare i valori pubblici Firebase. Quindi:

```powershell
flutter build appbundle --release --dart-define-from-file=config/production.json
```

Le callable Functions restano disponibili come fallback locale. I worker FCM/reminder TypeScript possono essere distribuiti separatamente finché non vengono sostituiti da worker Python:

```powershell
npm --prefix functions ci
firebase deploy --only functions:appointmentNotifications,functions:sendAppointmentReminders
```

## Google Calendar

1. Nel progetto Google Cloud abilitare Google Calendar API.
2. Nell'account Google dello studio creare il calendario dedicato `Appuntamenti Studio`.
3. Lo script stampa il runtime service account `salon-api@PROJECT_ID.iam.gserviceaccount.com`.
4. In Google Calendar: Impostazioni calendario → Condividi con persone specifiche → aggiungere quell'email con permesso **Apportare modifiche agli eventi**.
5. Copiare l'ID calendario da `Integra calendario` nel parametro `GOOGLE_CALENDAR_ID` e ridistribuire Cloud Run se necessario.
6. Confermare un appuntamento staging, verificare un solo evento, poi spostarlo e annullarlo verificando update/delete dello stesso event ID.

L'account Google dello studio può aggiungere lo stesso calendario all'iPhone; Calendar iOS lo mostrerà senza EventKit e senza credenziali Google nell'app Flutter.

## FCM e APNs

Android usa FCM e richiede l'app registrata con SHA-256 di debug/release quando applicabile. Per iOS:

1. Su Apple Developer creare una APNs Auth Key `.p8`, conservarla fuori dal repository.
2. Caricare key, Key ID e Team ID in Firebase Console → Cloud Messaging → app iOS.
3. Su macOS aprire `ios/Runner.xcworkspace`, impostare Team e aggiungere Push Notifications + Background Modes/Remote notifications.
4. Testare permesso, foreground/background/terminated su dispositivo fisico.

Per Web configurare Web Push certificate/VAPID e generare `firebase-messaging-sw.js` con `npm run configure:web-fcm`. Hosting deve essere HTTPS.

## Android signing e Play Store

Sostituire prima `it.studio.salon.salon_booking` con l'application ID definitivo. Generare un upload keystore in una directory sicura e copiare `android/key.properties.example` in `android/key.properties`; entrambi sono ignorati da Git.

```powershell
flutter build appbundle --release --dart-define-from-file=config/production.json
```

Senza `key.properties` la build di verifica resta intenzionalmente unsigned: non viene mai usata la debug key per una release. Conservare keystore e password in password manager/backup cifrato. Abilitare Play App Signing, caricare su Internal testing, completare Data safety e content rating, poi promuovere.

## iOS, TestFlight e App Store

Operazioni da macOS con Xcode stable:

1. Cambiare `PRODUCT_BUNDLE_IDENTIFIER` con il bundle ID definitivo e registrarlo su Apple Developer.
2. Impostare Team/Signing, Push Notifications e profili distribution.
3. Inserire `GoogleService-Info.plist` generato da FlutterFire (ignorato da Git).
4. Eseguire `flutter pub get`, `flutter analyze`, `flutter test` e:

```bash
flutter build ipa --release --dart-define-from-file=config/production.json
```

5. Caricare con Xcode/Transporter, distribuire a tester interni TestFlight, compilare App Privacy e inviare a review.

La build/firma iOS non è supportata su Windows e non è stata simulata.

## Rollback e monitoraggio

- Mantenere staging e production separati; mai testare seed sull'ambiente reale.
- Controllare Cloud Logging per `SLOT_UNAVAILABLE`, errori Calendar/FCM/reminder senza loggare contenuti sensibili.
- Verificare Crashlytics dSYM/mapping upload dopo il collegamento nativo del progetto.
- Prima di modificare Rules/Indexes eseguire Emulator test e deploy staging.
- Per rollback Functions usare la revisione precedente in Cloud Run/Functions; per app distribuire un nuovo build number, non riutilizzare binari firmati.
