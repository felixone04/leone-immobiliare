# Leone Immobiliare

Sito vetrina e area riservata per l'agenzia **Leone Immobiliare**, in Flutter Web.

**Sito online:** https://felixone04.github.io/leone-immobiliare/

- Catalogo immobili con filtri, mappa e schede dettagliate
- Prenotazioni online, offerte, recensioni, pagine informative
- Area riservata (`#/admin`) per gestire immobili, home, pagine, messaggi, prenotazioni e impostazioni

## Come funzionano i dati
Il sito non ha un server: contenuti e account dell'area riservata sono salvati **nel browser di chi lo usa**.
Sulla versione online ogni visitatore parte quindi dai contenuti di esempio e, al primo accesso a `#/admin`,
crea il proprio account valido solo nel suo browser. Le modifiche fatte da un browser non si vedono dagli altri.

## Pubblicazione
A ogni push su `master` il workflow `.github/workflows/deploy.yml` ricompila il sito e lo pubblica su GitHub Pages.

Uso offline sul PC e struttura del codice: vedi [LEGGIMI.md](LEGGIMI.md).
