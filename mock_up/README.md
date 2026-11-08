# Demo interattiva — Alessio Garreffa Hair

Apri `index.html` con Google Chrome, Edge, Firefox o Safari. Non servono backend,
installazioni o account: la demo è contenuta interamente nella cartella.

## Come presentarla

1. Usa **Simula cliente** per mostrare popup, home, prenotazione progressiva,
   appuntamenti, profilo e informativa privacy completa.
2. Nella prenotazione scegli un servizio: la lista si compatta automaticamente
   e lascia spazio a giorno e orario. La lista degli orari è scorrevole.
3. Usa **Simula admin** per entrare nella console proprietario.
4. Il menu amministrativo parte chiuso. Premi `☰` per aprire il drawer e
   raggiungere Dashboard, Richieste, Agenda, Clienti, Servizi, Orari,
   Impostazioni, Avviso clienti e Staff/Ruoli.
5. `↺ Riavvia` riporta la demo allo stato iniziale; `? Guida` spiega i comandi.

## Vincoli rispettati

- viene usato direttamente `assets/branding/agh_primary.png`, senza modifiche;
- l'indirizzo pubblico è Via G. Cottolengo 44, Vinovo;
- il domicilio fiscale in Privacy resta Via Gavuzzi 10, Vinovo;
- i contenuti legali, i fornitori e i tempi di conservazione derivano dalla
  Privacy Policy effettiva del progetto;
- nessuna azione invia dati: salvataggi, cancellazioni e prenotazioni sono
  simulati localmente.

## Collegamenti diretti opzionali

- Prenotazione con lista orari aperta:
  `index.html?demo=client&page=book&service=cut&overlay=times`
- Admin con menu aperto:
  `index.html?demo=admin&page=dashboard&overlay=drawer`

La cartella è indipendente dall'app Flutter e può essere copiata, compressa o
inviata così com'è: logo originale e font sono già inclusi localmente.
