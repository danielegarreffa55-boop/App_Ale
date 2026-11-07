# Checklist Google Play

## Identità e build

- [ ] Application ID definitivo e immutabile.
- [x] URL Privacy Policy e cancellazione account definiti in `STORE_PRIVACY_DECLARATIONS.md`.
- [ ] Icona 512×512, feature graphic 1024×500 e screenshot phone/tablet approvati.
- [ ] Upload keystore in backup cifrato; Play App Signing abilitato.
- [ ] `flutter build appbundle --release` firmato e versione/build number incrementati.
- [ ] Target SDK/API conforme al requisito Play vigente al momento dell'invio.

## Dichiarazioni

- [x] Data safety mappata in `STORE_PRIVACY_DECLARATIONS.md`.
- [x] Cifratura in transito, eliminazione e assenza di pubblicità documentate.
- [x] URL web per richiesta eliminazione account predisposto.
- [ ] Content rating, target audience, ads declaration = nessuna pubblicità.
- [ ] App access: credenziali demo e istruzioni per flusso cliente/admin.
- [ ] Permissions declaration: `POST_NOTIFICATIONS` contestuale; nessun permesso sensibile non necessario.

## Test e rollout

- [ ] Internal App Sharing/closed testing su dispositivi Android 6+ e Android 13+.
- [ ] Verificare protezioni anti-abuso API, rate limit e build distribuita da Play.
- [ ] Verificare OneSignal in foreground/background/app terminata, logout e reinstallazione.
- [ ] Pre-launch report senza crash/ANR critici e accessibilità accettabile.
- [ ] Rollout graduale con monitoraggio Cloud Logging e OneSignal delivery.
