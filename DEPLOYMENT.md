# Deploy produzione

La destinazione prevista è FastAPI su Google Cloud Run con MongoDB Atlas e segreti in Google Secret Manager. L’account cloud deve essere intestato all’attività.

## 1. MongoDB Atlas

Creare un cluster production in UE con backup, point-in-time recovery e almeno due amministratori. Creare un utente database dedicato all’API con accesso al solo database `alessio_garreffa_hair`. Limitare la rete con Private Service Connect oppure egress statico Cloud Run; l’apertura temporanea a `0.0.0.0/0` va compensata con credenziali forti e rimossa appena configurata la rete privata.

Il connection string deve abilitare TLS ed essere salvato nel secret `agh-mongodb-uri`. Non inserirlo in Git, nel JSON Flutter o nella riga di comando condivisa.

## 2. Secret Manager

Creare dall’interfaccia Cloud Console questi secret e aggiungere una versione:

- `agh-mongodb-uri`: URI completo Atlas;
- `agh-jwt-secret`: almeno 32 byte casuali, unici;
- `agh-onesignal-api-key`: REST API key OneSignal;
- `agh-cron-secret`: almeno 32 byte casuali per il bootstrap e il fallback operativo;
- `agh-smtp-password`: password SMTP, necessario solo se SMTP è configurato.

Lo script verifica che esistano ma non legge né stampa i valori.

## 3. Cloud Run e promemoria

Autenticarsi con l’account aziendale e lanciare:

```powershell
.\infrastructure\deploy-gcp.ps1 `
  -ProjectId 'agh-booking-prod' `
  -BillingAccount 'XXXXXX-XXXXXX-XXXXXX' `
  -PublicAppUrl 'https://prenota.example.it' `
  -OneSignalAppId '00000000-0000-0000-0000-000000000000' `
  -GoogleCalendarId 'calendar-id@group.calendar.google.com' `
  -SmtpHost 'smtp.example.it' `
  -SmtpUsername 'prenotazioni@example.it' `
  -SmtpFrom 'prenotazioni@example.it'
```

Lo script abilita le API necessarie, crea service account con privilegi limitati, distribuisce il container, collega i secret e crea Cloud Scheduler ogni 15 minuti con autenticazione OIDC. Il backend invia i promemoria soltanto nella finestra configurata in `reminderTime`, con idempotenza MongoDB.

Cloud Run resta pubblicamente raggiungibile perché login e app mobile devono chiamarlo, ma tutte le rotte applicative verificano JWT; la rotta dei promemoria verifica l’identità OIDC dello scheduler.

## 4. Bootstrap e proprietario

Eseguire `bootstrap_production.py` una sola volta contro Atlas. Registrare l’account del titolare dall’app, verificarne l’email e promuoverlo da una postazione fidata con `set_owner.py`. Non creare proprietari predefiniti o password nel repository.

## 5. Build client

Inserire l’URL Cloud Run e l’App ID OneSignal in `config/production.json`, ignorato da Git:

```powershell
flutter build appbundle --release --dart-define-from-file=config/production.json
flutter build web --release --dart-define-from-file=config/production.json
```

La build iOS, l’estensione OneSignal, APNs e la firma richiedono macOS con Xcode.

## 6. Verifiche prima del rilascio

- registrazione, verifica email, login, refresh ruotato, reset e revoca sessioni;
- ruoli client/manager/owner e divieto di auto-declassamento owner;
- due richieste sulla stessa fascia, warning admin e una sola conferma;
- blocco con motivo visibile ma non impeditivo;
- push OneSignal in tutti gli stati dell’app;
- evento Calendar creato, spostato e cancellato;
- backup Atlas e ripristino provato;
- log senza token, password o dati superflui.
