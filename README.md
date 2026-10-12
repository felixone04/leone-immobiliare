# Leone Immobiliare

Sito vetrina, area clienti e gestionale per l'agenzia **Leone Immobiliare**, in Flutter Web.

**Sito online:** https://felixone04.github.io/leone-immobiliare/

- Catalogo immobili con filtri, mappa, schede dettagliate ed etichette (Esclusiva, Nuovo, Prezzo ribassato)
- Account dei clienti: preferiti e ricerche salvate con avviso quando arriva un immobile adatto
  (almeno 70% dei requisiti, fino al 10% sopra il budget)
- Visite prenotabili dalla scheda dell'immobile, con agenda per agente
- Area riservata (`#/admin`): immobili con clienti interessati e scheda PDF per la vetrina, statistiche,
  messaggi, email ai clienti, clienti, visite, recensioni, pagine e impostazioni

## Come funzionano i dati
Il sito non ha ancora un server: contenuti, account e area riservata sono salvati **nel browser di chi lo usa**.
Sulla versione online ogni visitatore parte dai contenuti di esempio e le sue modifiche non si vedono dagli altri browser.
Le email vengono preparate nella posta in uscita dell'area riservata, finché non sarà collegato un servizio di invio.

## Pubblicazione
A ogni push su `master` il workflow `.github/workflows/deploy.yml` controlla il codice, esegue i test
(tutte le pagine su desktop, tablet e telefono; regole di abbinamento; scheda PDF), ricompila il sito e lo pubblica su GitHub Pages.

Uso offline sul PC e struttura del codice: vedi [LEGGIMI.md](LEGGIMI.md).
