# Audit funzionale azione per azione

Data verifica: 8 novembre 2026

## Esito sintetico

- Backend/API: **31 test superati**.
- Interfaccia Flutter: **22 test superati**.
- Analisi statica Flutter: **0 problemi**.
- Test end-to-end su dispositivo: non eseguibile in questo repository, perché il progetto non contiene il target Windows e Flutter non supporta `flutter test integration_test` su browser web.
- Servizi esterni (SMTP, OneSignal e Google Calendar): verificati tramite contratti, persistenza, gestione errori e mock. Non sono stati inviati messaggi né creati eventi reali.

## Matrice delle azioni verificate

| Area | Azioni | Esito |
|---|---|---|
| Avvio e sicurezza | health check, link verifica/reset, route sconosciuta, endpoint protetti senza token | Superato |
| Registrazione e accesso | registrazione, login, sessione corrente, refresh, anti-replay refresh, logout | Superato |
| Verifica e recupero account | blocco utente non verificato, verifica email monouso, reinvio verifica, password dimenticata senza enumerazione account, reset monouso | Superato |
| Profilo | modifica nome/cognome/telefono, cancellazione e anonimizzazione account, revoca sessione | Superato |
| Permessi | separazione client/manager/owner, blocco route proprietario, promozione staff, revoca sessioni dopo cambio ruolo, divieto di auto-rimozione owner | Superato |
| Servizi | elenco attivi, elenco inclusi inattivi solo admin, creazione, modifica, disattivazione, servizio inesistente | Superato |
| Configurazione studio | lettura e modifica configurazione, indirizzo `Via G. Cottolengo 44, Vinovo`, timezone, valuta e durata slot | Superato |
| Disponibilità | calcolo slot, orari di apertura, blocchi agenda, prevenzione doppia prenotazione | Superato |
| Prenotazione cliente | creazione richiesta, elenco appuntamenti, accettazione/rifiuto controproposta, richiesta annullamento, richiesta spostamento | Superato |
| Agenda admin | vista giorno/settimana/mese, slot temporali, appuntamenti e blocchi | Superato |
| Gestione appuntamenti admin | accetta, rifiuta con motivo, controproposta, approva/rifiuta richiesta cliente, sposta, completa, inserisce appuntamento manuale | Superato |
| Gestione indisponibilità | creazione blocco e persistenza in agenda | Superato |
| Annunci | autorizzazione owner, salvataggio annuncio, popup lato cliente | Superato |
| Navigazione/prenotazione UI | servizi dinamici, selezione separata giorno/orario, slot occupato disabilitato, pulsante prenotazione | Superato |
| Aspetto UI modificato | card appuntamento senza overflow, calendario admin giorno/settimana/mese, popup annuncio | Superato |
| Notifiche e promemoria | credenziali scheduler, idempotenza, fallimento temporaneo e retry push | Superato con mock |

## Limiti della verifica automatica

Un test locale non può certificare la consegna reale di email/push o la sincronizzazione con un account Google Calendar di produzione senza credenziali e ambiente di staging. Inoltre, il click manuale pixel-per-pixel su ogni dispositivo richiede almeno un target mobile o web configurato per i test end-to-end. Queste verifiche restano quindi una checklist manuale di accettazione prima della pubblicazione.

## Comandi di verifica

```text
python -m pytest backend/tests -q
flutter analyze --no-pub
flutter test --no-pub
```
