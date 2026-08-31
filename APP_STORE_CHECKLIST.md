# Checklist Apple App Store

## Identità e asset

- [ ] Nome commerciale definitivo, sottotitolo, descrizione e keyword in italiano.
- [ ] Bundle ID definitivo, SKU, versione/build number.
- [ ] Icona 1024×1024 senza trasparenza e splash approvati.
- [ ] Screenshot iPhone richiesti e, se dichiarato, iPad; dashboard admin mostrata solo se utile.
- [ ] URL supporto, marketing e Privacy Policy HTTPS.

## Account e firma

- [ ] Apple Developer Program attivo, contratti e dati fiscali completati.
- [ ] Team, certificate distribution e provisioning profile.
- [ ] APNs Auth Key caricata su Firebase e testata su device reale.
- [ ] Sign in with Apple non richiesto: l'MVP usa soltanto email/password.
- [ ] `flutter build ipa --release` eseguito su macOS e archivio validato in Xcode.

## App Privacy e review

- [ ] Dichiarare contact info (nome/email/telefono) e user content (appuntamenti), con finalità App Functionality.
- [ ] Dichiarare diagnostic data solo se Crashlytics è abilitato; no tracking cross-app.
- [ ] Compilare privacy nutrition labels coerenti con SDK Firebase effettivamente abilitati.
- [ ] Fornire account demo review non admin e istruzioni per controproposta; predisporre admin demo se la dashboard è parte della review.
- [ ] Eliminazione account accessibile nell'app verificata end-to-end.
- [ ] Testare Dynamic Type, VoiceOver, contrasto, offline/error state e permessi contestuali.
- [ ] TestFlight interno/esterno completato senza crash bloccanti.
- [ ] Note review spiegano login, push e che Calendar è un'integrazione server-side dello studio.
