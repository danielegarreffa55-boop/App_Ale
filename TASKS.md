# Stato attività

Aggiornato: 6 settembre 2026.

## DONE

- [x] Inventario Windows 11 x64 e repository inizialmente vuoto.
- [x] Flutter 3.47.2 / Dart 3.13.2, Android Studio 2026.1.3.7, SDK 36, JDK integrato, Node 22, Firebase CLI e FlutterFire CLI.
- [x] Scaffold Flutter Android/iOS/Web, Git, configurazione centralizzata e gestione sicura dei file locali.
- [x] Architettura Riverpod + go_router, UI premium responsive cliente/admin.
- [x] Auth completa MVP, profilo cliente, consenso privacy ed eliminazione account.
- [x] Servizi, disponibilità, richiesta, accetta/rifiuta/controproponi e risposta cliente.
- [x] Creazione/spostamento/cancellazione manuale admin e blocchi agenda.
- [x] Lock transazionali anti-overlap con race test Firestore Emulator.
- [x] Custom Claims admin, rules deny-by-default, App Check e test Security Rules.
- [x] FCM multi-token e log idempotente; promemoria schedulati configurabili.
- [x] Google Calendar backend idempotente con create/update/delete.
- [x] Firestore indexes, Emulator Suite, seed demo, test, CI e checklist store/GDPR.
- [x] `dart format`, `flutter analyze`, test Flutter, build/test TypeScript e `npm audit` puliti.

## TODO

- [x] Rimuovere il vecchio brand Barbatum e applicare la palette Alessio Garreffa Hair (`#181818`, `#E8E1D5`, `#7A302B`).
- [x] Confermare il concept 03 con monogramma AGH e H subordinata.
- [x] Generare e integrare una prima versione PNG trasparente del marchio AGH.
- [ ] Fornire/esportare il logo definitivo in SVG/PDF vettoriale e confermare il font.
- [x] Configurare telefono, indirizzo e payoff approvati.
- [x] Applicare slot da 30 minuti, anticipo 2 ore, orizzonte 90 giorni e limite annullamento 24 ore, modificabili dall'admin.
- [x] Supportare categorie servizio e prezzi “a partire da”.
- [ ] Inserire catalogo, prezzi e orari reali approvati da Alessio.
- [ ] Completare modello multi-operatore e calendario indipendente per operatore.
- [ ] Implementare import idempotente Google Calendar → agenda admin.
- [ ] Implementare richiesta cliente di spostamento entro il limite configurato.
- [ ] Integrare login Google e Sign in with Apple.
- [ ] Realizzare landing page pubblica con mappa e CTA Prenota.
- [ ] Aggiornare i plugin Firebase quando supporteranno il nuovo Built-in Kotlin di Flutter; la build attuale mostra solo un avviso futuro non bloccante.
- [ ] Generare icone e screenshot store dal logo definitivo approvato.
- [ ] Eseguire UAT con dati reali dello studio e almeno due dispositivi fisici.
- [ ] Far revisionare Privacy Policy, termini e strategia di conservazione da un professionista.
- [ ] TestFlight, closed testing Play e verifica accessibilità con utenti reali.

## BLOCKED — richiede account o decisione del titolare

- [ ] Login Firebase/Google e scelta/creazione del progetto production.
- [ ] Abilitazione piano billing per Functions Gen 2, Scheduler e API Calendar.
- [ ] ID calendario Google e condivisione con l'identità runtime backend.
- [ ] APNs Auth Key, Apple Developer Team, certificati e provisioning profile.
- [ ] Package name Android e bundle identifier iOS definitivi.
- [ ] Keystore upload Android e password conservate fuori dal repository.
- [ ] Account App Store Connect / Play Console e dati legali/fiscali.
- [ ] Build/firma iOS finale su macOS.

## IN PROGRESS

- [ ] Raccolta dei dati reali ancora mancanti elencati in `PRODUCT_REQUIREMENTS.md`.
- [ ] Sostituzione dei placeholder demo e definizione delle identità tecniche production.
- [ ] Pulizia progressiva del repository: rimossi asset Barbatum e motore Flutter di disponibilità duplicato/non usato.
