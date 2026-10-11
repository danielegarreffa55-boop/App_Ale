import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  static const _sections = <(String, String)>[
    (
      'Titolare del trattamento',
      'Marco Capusso, Via della Chiesa 17, 10040 La Loggia (TO), Italia. '
          'Contatti: marco.capusso98@gmail.com · +39 391 124 6837.',
    ),
    (
      'Dati trattati',
      'Nome, cognome, email, telefono, credenziali protette, dati essenziali '
          'degli appuntamenti, identificativi tecnici e log di sicurezza. Il token '
          'del dispositivo viene trattato solo quando abiliti le notifiche. '
          'L’app non gestisce pagamenti e non usa pubblicità comportamentale.',
    ),
    (
      'Finalità e basi giuridiche',
      'I dati servono a creare e proteggere l’account, gestire prenotazioni e '
          'comunicazioni di servizio, fornire assistenza, prevenire abusi e '
          'adempiere agli obblighi di legge. Le funzioni necessarie al servizio '
          'si basano sull’esecuzione del rapporto richiesto; le notifiche '
          'facoltative sul consenso, revocabile dal Profilo.',
    ),
    (
      'Fornitori',
      'Per erogare il servizio possono essere utilizzati FastAPI Cloud per '
          'l’hosting, MongoDB Atlas per il database, Brevo per le email, OneSignal '
          'per le notifiche, servizi Apple e Google per la distribuzione e, se '
          'configurato, Google Calendar. I dati non vengono venduti.',
    ),
    (
      'Trasferimenti internazionali',
      'Alcuni fornitori possono trattare dati fuori dallo Spazio Economico '
          'Europeo. Quando necessario vengono applicate decisioni di adeguatezza, '
          'clausole contrattuali standard o altre garanzie previste dal GDPR.',
    ),
    (
      'Conservazione e cancellazione',
      'I dati sono conservati per il tempo necessario al servizio, alla sicurezza '
          'e agli obblighi di legge. Eliminando l’account, i dati identificativi '
          'sono cancellati o anonimizzati; eventuali backup seguono i normali '
          'cicli tecnici di sovrascrittura.',
    ),
    (
      'I tuoi diritti',
      'Puoi chiedere accesso, rettifica, cancellazione, limitazione, portabilità '
          'o opposizione e revocare i consensi. Puoi eliminare l’account dal '
          'Profilo, scrivere a marco.capusso98@gmail.com e proporre reclamo al '
          'Garante per la protezione dei dati personali (garanteprivacy.it).',
    ),
    (
      'Sicurezza, minori e aggiornamenti',
      'Sono adottate misure tecniche e organizzative adeguate. Il servizio non è '
          'rivolto specificamente ai minori. L’informativa può essere aggiornata '
          'quando cambiano il servizio, i fornitori o la normativa.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Policy')),
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
                  'Informativa sulla privacy',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Alessio Garreffa Hair · ultimo aggiornamento 11 ottobre 2026',
                  style: Theme.of(context).textTheme.bodySmall,
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
