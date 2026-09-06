# Architettura

## Componenti

- Flutter contiene soltanto UI, cache di sessione cifrata e client HTTP. Non accede direttamente al database.
- FastAPI è l’unico confine applicativo e applica autenticazione, autorizzazione, validazione, rate limit e transizioni di stato.
- MongoDB Atlas è il database di produzione. Le collezioni principali sono `users`, `refresh_tokens`, `auth_tokens`, `services`, `studio`, `appointments`, `appointment_locks`, `blocks`, `rate_limits` e `notification_logs`.
- OneSignal invia push agli utenti usando come `external_id` l’UUID interno del profilo.
- SMTP invia verifica email e recupero password.
- Google Calendar è un’integrazione opzionale in uscita e non è la fonte primaria delle prenotazioni.

## Autenticazione e ruoli

Le password sono hash Argon2id e non vengono mai restituite. Il login produce un access token JWT di 15 minuti e un refresh token JWT di 30 giorni. Ogni refresh token viene conservato soltanto come hash, ruotato a ogni uso e invalidato dopo il logout. Il riuso di un token già ruotato revoca l’intera famiglia di sessione.

Ogni token include la versione di sessione dell’utente. Cambio password, cambio ruolo e cancellazione account incrementano tale versione, invalidando i token precedenti. Le autorizzazioni effettive vengono sempre lette da MongoDB; non ci si fida del ruolo inviato dal client.

I ruoli sono:

- `client`: profilo e proprie prenotazioni;
- `manager`: agenda, richieste, clienti, servizi, orari e blocchi;
- `owner`: tutte le funzioni manager e assegnazione ruoli.

Il primo proprietario viene promosso da un ambiente fidato con `backend/scripts/set_owner.py`. Successivamente i ruoli si gestiscono dalla console proprietario.

## Prenotazioni e concorrenza

La disponibilità mostra gli orari configurati senza nascondere fasce già richieste o confermate. Una richiesta cliente crea sempre `PENDING_ADMIN` se la data è valida: è l’amministratore a vedere gli eventuali conflitti e decidere se rifiutare o proporre un altro orario.

La conferma crea lock deterministici ogni 5 minuti nella collezione `appointment_locks`. L’indice univoco su `_id` impedisce due conferme sovrapposte. In produzione le scritture lock + appuntamento vengono eseguite in una transazione MongoDB; per questo `MONGODB_TRANSACTIONS=true` è obbligatorio e il cluster deve supportare transazioni.

I blocchi agenda sono avvisi morbidi con motivo. Non impediscono richieste né conferme; la console evidenzia la sovrapposizione. Gli appuntamenti già confermati sono invece vincoli rigidi: per confermare una richiesta conflittuale occorre liberare la fascia o fare una controproposta.

Le date sono memorizzate in UTC e visualizzate nella zona IANA `Europe/Rome`, inclusi i cambi dell’ora legale.

## Notifiche

Il backend invia a OneSignal messaggi idempotenti e registra payload, stato e tentativi in `notification_logs`. Gli invii transitoriamente falliti vengono ritentati dal job schedulato con un limite di tentativi; i log scadono automaticamente dopo 180 giorni. Login/logout OneSignal seguono la sessione applicativa, così più dispositivi possono appartenere allo stesso utente. Le notifiche coperte sono nuova richiesta agli amministratori, conferma, rifiuto, controproposta, spostamento, annullamento e promemoria.

Su Android OneSignal usa FCM come trasporto di sistema; su iOS usa APNs. Queste credenziali appartengono agli account aziendali Google/Apple e non sostituiscono né leggono l’autenticazione JWT o MongoDB.

## Servizi esterni e segreti

Il client riceve soltanto `BACKEND_API_URL` e `ONESIGNAL_APP_ID`, entrambi pubblici. URI MongoDB, chiave JWT, chiave API OneSignal, password SMTP e credenziali Calendar vivono solo nel runtime backend/Secret Manager. I file reali non sono versionati.
