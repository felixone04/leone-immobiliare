# Leone Immobiliare — sito e area riservata in Flutter

Sito e gestionale di **Leone Immobiliare**, nei colori del marchio (bianco, nero e azzurro `#0189EE`) con il logo Leone.
Per ora funziona **senza server**: i dati sono salvati nel browser. Il codice è pronto per collegare in seguito un database online (es. Supabase) e un servizio di invio email.

## Uso quotidiano (offline)
1. **La prima volta** (e dopo ogni modifica al codice) fai doppio clic su **`compila.bat`**: crea la cartella `sito_offline`.
2. Fai doppio clic su **`avvia-sito.bat`**: si apre il browser su **http://localhost:8282**.
   Tieni aperta la finestra nera finché usi il sito; chiudendola il sito si ferma.

> Usa sempre `avvia-sito.bat` (stessa porta 8282) e lo stesso browser: i dati del sito sono salvati nel browser per quell'indirizzo.

## Per i clienti (sito pubblico)
- **Account gratuito**: con email e password (in alto a destra, «Accedi»). Facoltativo il consenso a ricevere via email nuovi immobili e offerte.
- **Preferiti**: il cuore su ogni annuncio; li ritrovi in «Il mio account → Preferiti», anche quelli nel frattempo venduti.
- **La casa che cerco** (ricerche salvate): contratto, budget, zone, metri quadri, locali, dotazioni… Si crea dall'account o con «Salva questa ricerca» in fondo all'elenco immobili, che riprende i filtri scelti.
  Quando un immobile **diventa disponibile** e corrisponde ad **almeno il 70%** dei requisiti (con lo stesso contratto e un prezzo **al massimo il 10% sopra il budget**), il cliente riceve una notifica nell'account e un'**email con il link all'immobile**. Ogni immobile viene segnalato una sola volta per ricerca.
- **Etichette** sugli annunci: **Esclusiva** (la scegli nella scheda dell'immobile), **Nuovo** (disponibile da meno di 14 giorni), **Prezzo ribassato** (automatica quando abbassi il prezzo, con il prezzo precedente barrato).
- **Prenota una visita** dalla scheda dell'immobile: il cliente sceglie giorno, orario e agente.

## Area riservata
Menu → **Area riservata** (oppure `http://localhost:8282/#/admin`). Al primo accesso scegli nome utente e password (almeno 10 caratteri, con lettere e numeri).

- **Campanella** in alto: messaggi nuovi, visite da confermare, recensioni da approvare ed email da inviare.
- **Immobili**: inserimento e modifica; per ogni immobile i **clienti interessati** (abbinamento automatico con le ricerche salvate) e la **scheda PDF per la vetrina** (A4 con foto, prezzo, caratteristiche, contatti e QR code che porta all'annuncio).
- **Statistiche**: visite alla scheda, preferiti, richieste, visite prenotate, clienti interessati e giorni sul mercato per ogni immobile.
- **Messaggi**: le richieste dal sito, con l'immobile a cui si riferiscono.
- **Email**: la posta in uscita (avvisi per te, immobili trovati per i clienti, promemoria delle visite) e le **proposte**: scegli gli immobili e i destinatari (chi ha dato il consenso, i clienti interessati, una scelta tua) e scrivi il messaggio.
- **Clienti**: i clienti registrati con preferiti, ricerche e immobili abbinati.
- **Visite e agenda**: agenda del giorno con una colonna per agente, prossimi appuntamenti filtrabili per agente, orari, agenti e appuntamenti prenotabili.
- **Recensioni**, **Home e widget**, **Pagine e menu**, **Impostazioni**, **Backup**.

### Le email, per ora
Il servizio di invio non è ancora collegato: le email vengono preparate e messe in **Area riservata → Email → Da inviare**. Da lì «Apri nella posta» le apre già compilate nel tuo programma di posta; poi «Segna come inviata».
In **Impostazioni** indica l'**email per gli avvisi** e l'**indirizzo del sito online** (usato nei link delle email e nel QR delle schede).

## Backup
I dati restano **solo su questo computer**, nel browser. Scarica regolarmente un backup da **Area riservata → Backup**: il file contiene contenuti, impostazioni e foto caricate.

## Cosa richiede internet
Tutto il sito funziona senza connessione. Fanno eccezione solo:
- le **tessere della mappa** (OpenStreetMap), caricate solo dopo il consenso del visitatore. Senza rete i segnaposti restano visibili su uno sfondo neutro;
- **"Trova dall'indirizzo"** nella scheda di un immobile. Senza rete si clicca direttamente sulla mappa;
- i link esterni (WhatsApp, social, Google).

## Sicurezza
- Le password (agenzia e clienti) non vengono mai salvate: si conserva solo un'impronta **PBKDF2-SHA256** (210.000 iterazioni, sale casuale) e il confronto avviene a tempo costante.
- Area riservata: dopo **8 tentativi errati** in 15 minuti l'accesso si blocca; la sessione scade dopo **30 minuti** di inattività e si chiude con la scheda.
- Le immagini caricate vengono controllate, ridimensionate e **ricodificate**, il che elimina eventuali contenuti nascosti.
- I link inseriti nei contenuti sono filtrati (niente `javascript:`) e il testo viene sempre mostrato come testo, mai come codice.
- Il server locale risponde solo a `localhost` e serve solo i file della cartella `sito_offline`.
- A OpenStreetMap (solo dopo il consenso del visitatore) viene comunicato solo l'indirizzo base del sito, senza pagine né parametri: senza questa informazione OpenStreetMap risponde con tessere "Blocked".
- Le proposte commerciali vanno solo ai clienti che hanno dato il consenso; ogni cliente può revocarlo o cancellare l'account dalla sua pagina.

Limite da conoscere: senza server i dati (anche gli account dei clienti) sono salvati nel profilo del browser e non sono cifrati, e ogni browser ha i suoi. Per avere clienti, preferiti e statistiche condivisi e le email automatiche serve il database online.

## Sviluppo
- **`sviluppo-live.bat`**: apre il sito in Chrome e lo aggiorna da solo a ogni modifica del codice.
- Flutter è installato in `C:\Users\Utente\flutter`.
- **Controlli automatici** (`flutter test`), eseguiti anche su GitHub prima di ogni pubblicazione:
  - `test/pagine_test.dart` apre tutte le pagine del sito, dell'account cliente e dell'area riservata (desktop, tablet, telefono e telefono piccolo; senza e con un cliente collegato) e segnala errori o contenuti che escono dallo spazio;
  - `test/abbinamento_test.dart` verifica le regole di abbinamento (70%, +10% sul budget), gli avvisi ai clienti, la posta in uscita, le etichette e le statistiche;
  - `test/scheda_pdf_test.dart` crea la scheda PDF di ogni immobile e controlla che stia in una pagina.

## Versione online
Il sito è pubblicato su GitHub Pages: https://felixone04.github.io/leone-immobiliare/ (codice: https://github.com/felixone04/leone-immobiliare).
A ogni `git push` sul ramo `master` GitHub controlla il codice, esegue i controlli automatici e ripubblica il sito.
Online i dati restano nel browser di chi lo visita: ognuno vede i contenuti di esempio e account e area riservata valgono solo per il proprio browser.

### Struttura del codice (`lib/`)
```
app_config.dart          tipologia, nome dell'archivio, file dei contenuti iniziali
core/                    utilità, icone, tema grafico Leone, testo formattato, funzioni del browser
data/                    archivio locale, catalogo, abbinamento ricerche-immobili,
                         account dei clienti, posta in uscita e statistiche, visite, messaggi e recensioni
services/auth.dart       accesso all'area riservata (e impronta delle password)
state/app_state.dart     stato condiviso e notifiche
ui/                      pagine del sito, account dei clienti (clienti/), area riservata (admin/), mappa, moduli
assets/                  logo (logo.png), foto di esempio, caratteri (Inter, Arimo, Jost), contenuti iniziali (data/seed.json)
grafica/                 logo originali forniti (fondo bianco, grigio, azzurro)
tool/genera_logo.dart    rigenera assets/logo.png (sfondo trasparente) e le icone del sito da grafica/logo_originale.jpg
```
