# Dichiarazioni privacy per App Store e Google Play

Valori verificati sul codice della versione `2026-11-07-v3`.

## URL da inserire negli store

- Privacy Policy: `https://www.molelabs.eu/privacy/app-ale`
- Eliminazione account e dati: `https://www.molelabs.eu/privacy/app-ale/account-deletion`
- Supporto: `mailto:alessiogarreffa995@gmail.com`

## Apple App Privacy

L’app raccoglie dati collegati all’identità dell’utente esclusivamente per **App Functionality**:

| Categoria Apple | Dati | Collegati all’utente | Tracking |
| --- | --- | --- | --- |
| Contact Info | nome, email, numero di telefono | sì | no |
| Identifiers | identificativo utente e identificatore push/dispositivo | sì | no |
| User Content → Other User Content | richieste e dati degli appuntamenti | sì | no |
| Diagnostics → Other Diagnostic Data | dati tecnici e di sicurezza presenti nei log | sì | no |

- L’app non mostra pubblicità e non usa dati per marketing, pubblicità di terzi o profilazione.
- L’app non esegue tracking tra app o siti di altre aziende e non richiede ATT.
- Le notifiche push sono facoltative e sono gestite tramite OneSignal.
- La posizione non viene raccolta e l’app non richiede il relativo permesso.
- L’app non raccoglie dati finanziari, sanitari, contatti della rubrica, foto, audio o cronologia di navigazione/ricerca.

## Google Play Data safety

Risposte generali:

- L’app raccoglie dati: **Sì**.
- L’app condivide dati con terzi: **No**, considerando i fornitori elencati nell’informativa come service provider che trattano i dati per conto del titolare. Se un fornitore viene usato per finalità proprie ulteriori, aggiornare questa risposta.
- Tutti i dati sono cifrati in transito: **Sì**.
- Gli utenti possono richiedere la cancellazione: **Sì**, dall’app e dall’URL pubblico indicato sopra.
- L’app segue la Families Policy: **No / non destinata specificamente ai bambini**.

Tipi di dati raccolti:

| Sezione Google Play | Tipo | Obbligatorio | Finalità |
| --- | --- | --- | --- |
| Personal info | Name | sì | App functionality, Account management |
| Personal info | Email address | sì | App functionality, Account management |
| Personal info | Phone number | sì | App functionality, Account management |
| Personal info | User IDs | sì | App functionality, Account management |
| App activity | Other user-generated content | sì per usare le prenotazioni | App functionality |
| Device or other IDs | identificatore push | no, solo se si abilitano le notifiche | App functionality |
| App info and performance | Other app performance/diagnostic data | raccolta tecnica del backend | Security, fraud prevention, App functionality |

Per ogni tipo: dati non venduti, nessuna pubblicità, nessun marketing e nessuna personalizzazione pubblicitaria.

## Permessi e caratteristiche rilevanti

- Android: `INTERNET` e `POST_NOTIFICATIONS`.
- iOS: notifiche remote; nessun permesso posizione.
- Eliminazione account disponibile in Profilo e tramite endpoint autenticato `DELETE /v1/account`.
- Nessun pagamento in-app e nessun acquisto di beni digitali.
- Nessun social login; accesso tramite email e password.

## Sequenza di pubblicazione

1. Pubblicare e verificare gli URL privacy e cancellazione.
2. Caricare la build aggiornata nei canali TestFlight e Google Play Internal testing.
3. Compilare App Privacy e Data safety con i valori sopra.
4. Completare test interno, credenziali demo e note per la review.
5. Promuovere la build testata a produzione e inviarla alla revisione degli store.
