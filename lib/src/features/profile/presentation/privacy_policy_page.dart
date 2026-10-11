import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const version = '2026-10-11-v2';

  static const _sections = <(String, String)>[
    (
      '1. Titolare del trattamento e contatti',
      'Il titolare del trattamento è Alessio Garreffa Hair, con sede in Via '
          'Cottolengo, 44, 10048 Vinovo (TO), Italia. Per informazioni o per '
          'esercitare i diritti: alessiogarreffa995@gmail.com · +39 388 986 5985. '
          'Non è stato nominato un Responsabile della protezione dei dati (RPD/DPO), '
          'non ricorrendone allo stato i presupposti di legge.',
    ),
    (
      '2. Dati personali trattati',
      'Trattiamo nome, cognome, email, telefono; identificativo e stato '
          'dell’account; password conservata esclusivamente in forma protetta; '
          'servizio, operatore, data, ora, stato e cronologia delle prenotazioni; '
          'comunicazioni di servizio; identificatore del dispositivo e preferenze '
          'push se abilitate; dati tecnici e di sicurezza eventualmente presenti '
          'nei log. L’app non gestisce pagamenti, non vende dati, non effettua '
          'pubblicità comportamentale, profilazione o decisioni automatizzate con '
          'effetti giuridici. Non inserire dati sanitari nelle prenotazioni.',
    ),
    (
      '3. Finalità e basi giuridiche',
      'Account, verifica email, prenotazioni, modifiche, annullamenti, promemoria '
          'e comunicazioni strettamente necessarie si basano sull’esecuzione del '
          'servizio richiesto (art. 6(1)(b) GDPR). Sicurezza, prevenzione degli '
          'abusi e difesa dei diritti si basano sul legittimo interesse del '
          'titolare (art. 6(1)(f)); gli adempimenti normativi sull’obbligo legale '
          '(art. 6(1)(c)). Le notifiche push facoltative si basano sul consenso '
          '(art. 6(1)(a)), revocabile dal Profilo o dal dispositivo.',
    ),
    (
      '4. Dati obbligatori e presa visione',
      'Nome, cognome, email, telefono e dati necessari alla prenotazione sono '
          'obbligatori per creare l’account ed erogare il servizio; senza di essi '
          'non è possibile registrarsi o gestire l’appuntamento. Le notifiche push '
          'sono facoltative e il rifiuto non limita l’uso dell’app. La dichiarazione '
          'in registrazione documenta la presa visione di questa informativa: non '
          'è un consenso generale ai trattamenti necessari al servizio.',
    ),
    (
      '5. Modalità e sicurezza',
      'Il trattamento avviene prevalentemente con strumenti elettronici secondo '
          'i principi di liceità, trasparenza, minimizzazione e limitazione della '
          'conservazione. Sono utilizzati controlli di accesso per ruolo, verifica '
          'dell’email, protezione delle credenziali, scadenza dei token e '
          'connessioni cifrate. Nessun sistema può garantire un rischio pari a zero.',
    ),
    (
      '6. Destinatari e fornitori',
      'I dati sono accessibili al titolare e al personale autorizzato. Nei limiti '
          'necessari possono essere trattati da FastAPI Cloud (hosting), MongoDB '
          'Atlas (database), Brevo (email), OneSignal (push), Apple e Google '
          '(servizi di sistema e distribuzione) e Google Calendar, se la '
          'sincronizzazione è configurata. I fornitori operano, secondo il caso, '
          'come responsabili ex art. 28 GDPR o autonomi titolari. I dati non sono '
          'diffusi né venduti e sono comunicati alle autorità solo quando previsto.',
    ),
    (
      '7. Trasferimenti fuori dal SEE',
      'I fornitori internazionali possono comportare trasferimenti fuori dallo '
          'Spazio economico europeo. Il trasferimento avviene in presenza di una '
          'decisione di adeguatezza o di garanzie degli artt. 46 e seguenti GDPR, '
          'come le clausole contrattuali standard e le eventuali misure '
          'supplementari. Le garanzie applicabili possono essere richieste al titolare.',
    ),
    (
      '8. Conservazione',
      'I dati dell’account restano finché l’account è attivo. Alla cancellazione '
          'sono rimossi i dati identificativi e di contatto e sono revocate le '
          'sessioni; nella cronologia degli appuntamenti nome e telefono sono '
          'rimossi o sostituiti. La cronologia residua può essere conservata per '
          'esigenze organizzative e tutela dei diritti, non oltre i termini di '
          'prescrizione applicabili. I token scadono automaticamente; i log di '
          'consegna push restano al massimo 180 giorni. Obblighi di legge o '
          'controversie possono giustificare un periodo diverso. I backup seguono '
          'i cicli tecnici di sovrascrittura del fornitore.',
    ),
    (
      '9. Diritti dell’interessato',
      'Nei casi previsti dagli artt. 15-22 GDPR puoi chiedere accesso, copia, '
          'rettifica, cancellazione, limitazione, portabilità o opposizione e '
          'revocare il consenso push senza pregiudicare i trattamenti precedenti. '
          'Scrivi a alessiogarreffa995@gmail.com; la risposta è fornita di norma '
          'entro un mese e potrà essere verificata la tua identità. Puoi eliminare '
          'l’account dal Profilo. Puoi inoltre proporre reclamo al Garante per la '
          'protezione dei dati personali tramite www.garanteprivacy.it.',
    ),
    (
      '10. Minori',
      'L’app non è progettata per l’uso autonomo da parte di minori di 14 anni. '
          'Per tali utenti registrazione e prenotazione devono essere effettuate o '
          'autorizzate da chi esercita la responsabilità genitoriale.',
    ),
    (
      '11. Modifiche',
      'Le modifiche sostanziali saranno comunicate nell’app e, quando necessario, '
          'sarà richiesta una nuova presa visione o uno specifico consenso. La '
          'versione e la data applicabili sono indicate all’inizio.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Informativa privacy')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informativa sul trattamento dei dati personali',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Alessio Garreffa Hair · versione $version · '
                  'ultimo aggiornamento 11 ottobre 2026',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Informativa resa ai sensi degli articoli 12 e 13 del '
                  'Regolamento (UE) 2016/679 (GDPR).',
                ),
                const SizedBox(height: 24),
                for (final section in _sections) ...[
                  Text(
                    section.$1,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(section.$2),
                  const SizedBox(height: 22),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
