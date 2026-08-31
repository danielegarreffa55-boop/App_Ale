# Checklist privacy e GDPR

Questa è una checklist tecnica, non consulenza legale. Il titolare deve far validare testi, basi giuridiche e tempi di conservazione.

## Informazioni richieste al titolare

- [ ] Ragione sociale/nome, indirizzo, P.IVA/C.F. e contatti del titolare.
- [ ] Contatto privacy/DPO se applicabile.
- [ ] Finalità e base giuridica per account, appuntamenti, notifiche e reminder.
- [ ] Tempi di conservazione per clienti, appuntamenti, log tecnici e backup.
- [ ] Regole di cancellazione per appuntamenti futuri/storico fiscale.
- [ ] Elenco responsabili/sub-responsabili: Google Firebase/Cloud/Calendar, Apple, Google Play ed eventuali fornitori.
- [ ] Trasferimenti extra SEE, SCC e riferimenti al DPA Google applicabile.
- [ ] Procedura per accesso, rettifica, portabilità, opposizione e reclamo al Garante.

## Implementato tecnicamente

- [x] Minimizzazione: nome, cognome, email, telefono e dati appuntamento essenziali.
- [x] Consenso/informativa obbligatoria in registrazione (testo placeholder da sostituire).
- [x] Eliminazione account con rimozione Auth/device token e anonimizzazione snapshot cliente.
- [x] Nessun advertising ID, tracking pubblicitario o social login nell'MVP.
- [x] Analytics non usato per profilazione; configurare soltanto eventi aggregati necessari.
- [x] Dati appuntamento UTC, ruoli server-side, Rules deny-by-default e App Check.
- [x] Log backend privi di password/token e con errori Calendar troncati.
- [x] Permesso notifiche richiesto da azione esplicita nella pagina profilo.

## Prima della produzione

- [ ] Sostituire placeholder Privacy Policy in app e store con URL HTTPS pubblico.
- [ ] Definire se il consenso è la base corretta o se alcune finalità usano esecuzione contrattuale/interesse legittimo.
- [ ] Configurare Firestore/Functions in regioni UE e verificare data location di ogni servizio.
- [ ] Abilitare MFA per account Google/Apple amministrativi e least privilege IAM.
- [ ] Configurare TTL per `rateLimits` e policy di retention per `notificationLogs`/Cloud Logging.
- [ ] Documentare e provare data breach response, export dati e cancellazione completa.
- [ ] Firmare DPA con fornitori e aggiornare registro trattamenti/DPIA se necessaria.
- [ ] Evitare dati sanitari/note sensibili nelle descrizioni Calendar e nelle push.
- [ ] Verificare che testo push su lock screen sia accettabile per il titolare.
