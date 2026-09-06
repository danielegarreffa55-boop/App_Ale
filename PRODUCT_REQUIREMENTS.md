# Requisiti prodotto — Alessio Garreffa Hair

Aggiornato: 6 settembre 2026.

Questo documento raccoglie le decisioni approvate per trasformare la demo in
prodotto. Password, chiavi, certificati e credenziali non devono essere salvati
nel repository.

## Identità

- Nome: **Alessio Garreffa Hair**.
- Marchio principale: concept 03, monogramma **AGH**, con `H` subordinata ad
  `A` e `G`.
- Concept 01 e 02: eventuali elementi editoriali secondari.
- Payoff secondario: **Hair is a form of expression.**
- Palette: `#181818`, `#E8E1D5`, `#7A302B`.
- I font definitivi devono avere una licenza commerciale chiara per app, web,
  store e materiali promozionali.
- Contenuti Instagram utilizzabili soltanto dopo conferma dei diritti da parte
  di Alessio.

## Studio

- Indirizzo: Via Cottolengo 44, 10048 Vinovo TO.
- Telefono: +39 342 535 5594.
- Email e dominio: da definire.
- Orari, ferie, festività e aperture straordinarie sono modificabili
  dall'amministratore.
- Al lancio è presente il solo operatore Alessio; modello dati, lock, servizi e
  calendari devono supportare in seguito più operatori indipendenti.

## Servizi

- Campi: categoria, nome, descrizione, durata, prezzo, indicatore "a partire
  da", operatori abilitati, stato prenotabile e ordinamento.
- Categorie iniziali: Taglio, Styling/Piega, Colore, Schiariture, Trattamenti,
  Barba e Altri servizi; devono restare modificabili dall'admin.
- Nessun buffer automatico di preparazione/pulizia nella prima versione.
- Catalogo e prezzi reali: da raccogliere da Alessio.

## Prenotazioni

- Intervallo iniziale: 30 minuti.
- Anticipo minimo iniziale: 2 ore.
- Orizzonte iniziale: 90 giorni.
- I tre valori sono modificabili dall'admin.
- Il cliente richiede soltanto fasce comprese negli orari di apertura.
- Slot occupati e blocchi non impediscono la richiesta del cliente.
- Il motivo di un blocco è visibile esclusivamente all'admin.
- L'admin vede gli eventuali conflitti e decide se confermare, rifiutare o
  controproporre; un appuntamento confermato non può sovrapporsi a un altro
  confermato dello stesso operatore senza una futura azione esplicita di
  override.
- Annullamento cliente fino a 24 ore prima; oltre il limite deve contattare lo
  studio. Il limite è modificabile dall'admin.
- Richiesta di spostamento cliente entro 24 ore: da implementare.
- Policy ritardi/no-show e relative limitazioni: testo e regole definitive da
  approvare.

## Account e comunicazioni

- Catalogo consultabile senza account; registrazione obbligatoria per inviare
  una richiesta.
- Telefono obbligatorio; verifica SMS rinviata.
- Accessi previsti: email/password, Google e Apple su iOS.
- Nessun pagamento online al lancio; predisposizione futura per acconto Stripe.
- Push per richiesta ricevuta, conferma, rifiuto, controproposta, modifica,
  cancellazione e promemoria 24 ore prima.
- Testi professionali, diretti, contemporanei e personali; approvazione finale
  di Alessio.

## Calendari e web

- Un Google Calendar per operatore.
- Sincronizzazione bidirezionale: gli eventi creati da Alessio direttamente in
  Calendar devono comparire nell'agenda admin come appuntamenti esterni, senza
  creare account cliente e senza essere visibili a clienti non associati.
- Gli appuntamenti esterni concorrono agli avvisi di sovrapposizione, ma non
  nascondono gli slot al cliente.
- Pagina web pubblica responsive con brand, servizi, contatti, mappa e pulsante
  Prenota. Web app completa in una fase successiva.

## Infrastruttura, privacy e qualità

- Progetto Firebase production nuovo, posseduto dall'attività e ospitato in
  Europa dove supportato.
- Amministratori iniziali: Alessio e un eventuale secondo account concordato.
- Dominio, email ufficiale, dati legali e testi privacy ancora da definire.
- Analytics solo aggregati e necessari; Crashlytics abilitato.
- Le notifiche sulla lock screen mostrano soltanto studio, giorno e ora.
- Pubblicazione store sospesa fino a nuova decisione.

## Questioni ancora aperte

- Ragione sociale/nome legale, P.IVA o C.F. e contatto privacy.
- Email ufficiale, dominio e account Google proprietario.
- Orari iniziali reali, catalogo servizi e prezzi.
- Font o file vettoriali ufficiali del marchio.
- Convenzione dei titoli degli eventi inseriti a mano in Google Calendar:
  almeno nome cliente e servizio, con telefono facoltativo.
- Regola finale in caso di doppia conferma richiesta dall'admin.
- Testo definitivo per ritardi, no-show, privacy e notifiche.
