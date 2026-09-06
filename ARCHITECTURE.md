# Architettura

## Componenti

- Flutter/Dart: un solo codebase Android, iOS e Web; Riverpod per dipendenze/stato, go_router per navigazione.
- Firebase Auth: identità client e Custom Claim `admin` assegnato solo da Admin SDK.
- Firestore: dati realtime, regole deny-by-default e indici dichiarativi.
- Callable Functions TypeScript: unica autorità per appuntamenti, profili, device token e transizioni.
- Trigger Functions: FCM e sincronizzazione Calendar idempotenti.
- Scheduled Function: ogni 5 minuti controlla l'orario configurato in `Europe/Rome` e invia i reminder del giorno successivo.

## Confini di fiducia

Il client può leggere soltanto i propri dati e i servizi attivi. Non può scrivere appuntamenti, claim, `CONFIRMED`, lock, `googleCalendarEventId`, reminder o notification log. Le modifiche admin a servizi/config sono ammesse dalle Rules soltanto con Custom Claim valido. Ogni callable controlla auth/App Check, schema Zod, ruolo e rate limit.

## Flusso prenotazione

```text
Cliente -> createAppointmentRequest (anche su fascia occupata) -> PENDING_ADMIN
                                      |-> adminReject -> REJECTED
                                      |-> adminCounterPropose -> COUNTER_PROPOSED
                                      |                         |-> client reject -> COUNTER_REJECTED
                                      |                         `-> client accept -> transaction + locks -> CONFIRMED
                                      `-> admin accept -> transaction + locks -> CONFIRMED

CONFIRMED -> trigger FCM + trigger Calendar
          -> admin reschedule -> replace locks atomica -> update Calendar + FCM
          -> cancel -> release locks -> delete Calendar + FCM
          `-> scheduled reminder idempotente
```

## Anti doppia prenotazione

La richiesta del cliente non acquisisce lock e può sovrapporsi a un appuntamento confermato. L'area admin evidenzia il conflitto e richiede di liberare la fascia o proporre un altro orario prima della conferma.

Ogni intervallo confermato include durata servizio e buffer. Il backend lo suddivide in documenti deterministici da 5 minuti in `appointmentLocks`. La transazione legge tutti i bucket, fallisce se uno appartiene a un altro appuntamento confermato e scrive lock + stato `CONFIRMED` nello stesso commit. Due transazioni concorrenti toccano almeno un documento identico: Firestore ne serializza una e l'altra vede `SLOT_UNAVAILABLE`.

I blocchi agenda sono promemoria amministrativi morbidi: non nascondono gli slot al cliente e non impediscono richieste o conferme. Il loro motivo è visibile soltanto all'admin come avviso. Lo spostamento di un appuntamento legge insieme vecchi e nuovi lock, elimina soltanto quelli non più usati e acquisisce i nuovi nello stesso commit.

Il test `lock-race.emulator.test.ts` invia due acquisizioni contemporanee e verifica un solo successo.

## Collezioni principali

- `users/{uid}`: profilo minimizzato; `devices/{hash}` per token FCM multipli.
- `services/{id}`: nome, descrizione, durata, buffer, prezzo, attivo, ordine.
- `appointments/{id}`: snapshot servizio/cliente, requested/proposed/confirmed UTC, stato corrente, history, Calendar e reminder.
- `appointmentLocks/{bucket}`: holder dell'appuntamento confermato e bucket UTC; mai leggibile dal client.
- `blocks/{id}`: promemoria admin per ferie, chiusure o fasce manuali; non bloccanti per il cliente.
- `studio/config`: brand operativo, timezone, valuta, reminder e openingHours.
- `notificationLogs/{id}`: claim/SENT/FAILED/SKIPPED per deduplicazione e diagnosi.
- `rateLimits/{uid_action}`: finestra contatori callable.

## Date e DST

Firestore contiene soltanto `Timestamp` UTC. Luxon/timezone convertono con zona IANA `Europe/Rome`; non vengono memorizzati offset fissi. I test coprono giorni da 23 e 25 ore nei cambi DST 2026.

## Idempotenza esterna

- Calendar Event ID = SHA-256 dell'appointment ID; `update`, poi `insert`, con gestione 404/409.
- Notification log deterministico; un retry non reinvia dopo `SENT`.
- Reminder marcato soltanto dopo almeno un invio FCM riuscito.
- Trigger Calendar ignora scritture dei propri campi di sync per evitare loop.

## Estendibilità

La prima release visualizza il solo operatore Alessio, ma la produzione dovrà
associare `operatorId` a servizi, appuntamenti, blocchi, lock e calendario. Il
bucket del lock dovrà essere partizionato per operatore, così due operatori
possono lavorare nello stesso orario senza generare un falso conflitto. Gli
eventi importati da Google Calendar saranno documenti admin-only o appuntamenti
con sorgente esterna e senza account cliente. Note e motivi dei blocchi restano
sempre admin-only.
