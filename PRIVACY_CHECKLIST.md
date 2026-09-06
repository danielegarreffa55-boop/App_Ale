# Checklist privacy e GDPR

Questa è una checklist tecnica, non consulenza legale. Il titolare deve far validare testi, basi giuridiche e tempi di conservazione.

## Informazioni richieste al titolare

- [ ] Ragione sociale/nome, indirizzo, P.IVA/C.F. e contatti del titolare.
- [ ] Contatto privacy/DPO se applicabile.
- [ ] Finalità e base giuridica per account, appuntamenti, notifiche e reminder.
- [ ] Tempi di conservazione per clienti, appuntamenti, log tecnici e backup.
- [ ] Regole di cancellazione per appuntamenti futuri/storico fiscale.
- [ ] Elenco responsabili/sub-responsabili: MongoDB Atlas, OneSignal, Google Cloud/Calendar, Apple, Google Play e provider email.
- [ ] Trasferimenti extra SEE, SCC e riferimenti al DPA Google applicabile.
- [ ] Procedura per accesso, rettifica, portabilità, opposizione e reclamo al Garante.

## Implementato tecnicamente

- [x] Minimizzazione: nome, cognome, email, telefono e dati appuntamento essenziali.
- [x] Consenso/informativa obbligatoria in registrazione (testo placeholder da sostituire).
- [x] Eliminazione account con revoca sessioni JWT e anonimizzazione dello storico cliente.
- [x] Nessun advertising ID, tracking pubblicitario o social login nell'MVP.
- [x] Analytics non usato per profilazione; configurare soltanto eventi aggregati necessari.
- [x] Dati appuntamento UTC, autorizzazione server-side e nessun accesso diretto del client al database.
- [x] Log backend privi di password/token e con errori Calendar troncati.
- [x] Permesso notifiche richiesto da azione esplicita nella pagina profilo.

## Prima della produzione

- [ ] Sostituire placeholder Privacy Policy in app e store con URL HTTPS pubblico.
- [ ] Definire se il consenso è la base corretta o se alcune finalità usano esecuzione contrattuale/interesse legittimo.
- [ ] Configurare Atlas e servizi cloud in regioni UE e verificare la data location di ogni fornitore.
- [ ] Abilitare MFA per account Google/Apple amministrativi e least privilege IAM.
- [ ] Configurare TTL per `rateLimits` e policy di retention per `notificationLogs`/Cloud Logging.
- [ ] Documentare e provare data breach response, export dati e cancellazione completa.
- [ ] Firmare DPA con fornitori e aggiornare registro trattamenti/DPIA se necessaria.
- [ ] Evitare dati sanitari/note sensibili nelle descrizioni Calendar e nelle push.
- [ ] Verificare che testo push su lock screen sia accettabile per il titolare.
