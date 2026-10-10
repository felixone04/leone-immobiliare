# Leone Immobiliare — sito e area riservata in Flutter

Sito di **Leone Immobiliare**, realizzato a partire dal sito Flutter "Casa Aurora": stesse pagine, stesse funzioni e stessa area riservata, con una nuova grafica nei colori del marchio (bianco, nero e azzurro `#0189EE`) e il logo Leone. Funziona **offline**, sul tuo PC: non serve un server PHP né un database online.

## Uso quotidiano (offline)
1. **La prima volta** (e dopo ogni modifica al codice) fai doppio clic su **`compila.bat`**: crea la cartella `sito_offline`.
2. Fai doppio clic su **`avvia-sito.bat`**: si apre il browser su **http://localhost:8282**.
   Tieni aperta la finestra nera finché usi il sito; chiudendola il sito si ferma.

> Usa sempre `avvia-sito.bat` (stessa porta 8282) e lo stesso browser: i dati del sito sono salvati nel browser per quell'indirizzo.

## Area riservata
Menu → **Area riservata** (oppure `http://localhost:8282/#/admin`).
Al primo accesso scegli nome utente e password (almeno 10 caratteri, con lettere e numeri).

Contiene tutte le sezioni della versione web: Panoramica, Immobili, Home e widget, Pagine e menu, Messaggi, Prenotazioni (agenda, elenco, lista d'attesa, orari e collaboratori), Cassa, Gift card, Tessera fedeltà, Pacchetti, Offerte, Recensioni, Impostazioni e Backup.
Le **funzioni attive** (prenotazioni, fedeltà, pacchetti, offerte, recensioni), che nella versione web attivava il proprietario dal suo pannello, si attivano da **Impostazioni → Funzioni attive**.

## Grafica
- Tema **Leone** (predefinito): sfondi bianchi, testi neri, azzurro del logo per pulsanti, prezzi e fasce colorate, piè di pagina nero con dettagli azzurri, il "tetto" del logo sopra i titoli delle sezioni e nelle intestazioni di pagina, etichette spaziate come la scritta IMMOBILIARE.
- Da **Area riservata → Impostazioni** puoi ancora cambiare logo, colori e tema (Classico, Elegante, Moderno, Minimal).

## Backup
I dati restano **solo su questo computer**, nel browser. Scarica regolarmente un backup da **Area riservata → Backup**: il file contiene contenuti, impostazioni e foto caricate.
Il formato è compatibile con i backup della versione web: puoi ripristinare un backup scaricato da Vetrina.

## Cosa richiede internet
Tutto il sito funziona senza connessione. Fanno eccezione solo:
- le **tessere della mappa** (OpenStreetMap), caricate solo dopo il consenso del visitatore. Senza rete i segnaposti restano visibili su uno sfondo neutro;
- **"Trova dall'indirizzo"** nella scheda di un immobile. Senza rete si clicca direttamente sulla mappa;
- i link esterni (WhatsApp, social, Google).

## Sicurezza
- La password non viene mai salvata: si conserva solo un'impronta **PBKDF2-SHA256** (210.000 iterazioni, sale casuale) e il confronto avviene a tempo costante.
- Dopo **8 tentativi errati** in 15 minuti l'accesso si blocca, anche ricaricando la pagina.
- La sessione scade dopo **30 minuti** di inattività e si chiude con la scheda.
- Le immagini caricate vengono controllate, ridimensionate e **ricodificate**, il che elimina eventuali contenuti nascosti.
- I link inseriti nei contenuti sono filtrati (niente `javascript:`) e il testo viene sempre mostrato come testo, mai come codice.
- Il server locale risponde solo a `localhost` e serve solo i file della cartella `sito_offline`.
- A OpenStreetMap (solo dopo il consenso del visitatore) viene comunicato solo l'indirizzo base del sito (`http://localhost:8282`), senza pagine né parametri: senza questa informazione OpenStreetMap risponde con tessere "Blocked".

Limite da conoscere: i dati sono salvati nel profilo del browser e non sono cifrati. Chi può usare il tuo account Windows può leggerli. Per pubblicarlo online con più utenti servirebbe un server con database.

## Sviluppo
- **`sviluppo-live.bat`**: apre il sito in Chrome e lo aggiorna da solo a ogni modifica del codice.
- Flutter è installato in `C:\Users\Utente\flutter`.

### Struttura del codice (`lib/`)
```
app_config.dart          tipologia, nome dell'archivio, file dei contenuti iniziali (l'unico file diverso tra i progetti)
core/                    utilità, icone, tema grafico (5 temi, predefinito "Leone"), testo formattato, funzioni del browser
data/                    archivio locale, regole di prenotazioni / gift card / tessere / recensioni, catalogo, tipologia
services/auth.dart       accesso all'area riservata
state/app_state.dart     stato condiviso e notifiche
ui/                      pagine del sito, area riservata (admin/), mappa, moduli
assets/                  logo (logo.png), foto di esempio, caratteri dei temi, contenuti iniziali (data/seed.json)
grafica/                 logo originali forniti (fondo bianco, grigio, azzurro)
tool/genera_logo.dart    rigenera assets/logo.png (sfondo trasparente) e le icone del sito da grafica/logo_originale.jpg
```
