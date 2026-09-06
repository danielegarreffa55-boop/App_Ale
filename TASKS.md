# Stato lavorazione

## Completato nel codice

- [x] UI cliente e amministratore con brand Alessio Garreffa Hair.
- [x] Agenda giornaliera a slot e dashboard amministrativa navigabile.
- [x] Richieste cliente per fasce già occupate e avvisi conflitto lato admin.
- [x] Blocchi agenda motivati come avvisi non impeditivi.
- [x] API FastAPI come unico accesso ai dati.
- [x] Autenticazione Argon2id + access/refresh JWT ruotati e revocabili.
- [x] Ruoli owner, manager e client salvati in MongoDB.
- [x] Persistenza MongoDB e lock transazionali anti-sovrapposizione.
- [x] Push OneSignal e reminder schedulati idempotenti.
- [x] Email di verifica/reset e relative pagine Flutter.
- [x] Sincronizzazione in uscita con Google Calendar dedicato.
- [x] CI Flutter/Python senza backend Firebase legacy.

## Richiede account o decisioni del titolare

- [ ] Dati legali, email ufficiale, dominio e Privacy Policy.
- [ ] Organizzazione e cluster MongoDB Atlas production.
- [ ] Workspace OneSignal, progetto push Android e chiave APNs iOS.
- [ ] Account Google Cloud aziendale con billing per il deploy.
- [ ] Provider SMTP e mittente verificato.
- [ ] Calendario aziendale dedicato condiviso con il service account.
- [ ] Servizi reali, prezzi, orari, regole di cancellazione e reminder.
- [ ] Bundle ID/Application ID definitivi e account store.
- [ ] Test end-to-end staging su Android e iPhone reali.
