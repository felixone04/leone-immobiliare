/// Widget della home: nome, icona, descrizione e campi modificabili dall'area riservata.
library;

import '../../core/icons.dart';
import '../../data/preset.dart';

class WidgetDef {
  final String nome, icona, desc;
  final List<FieldDef> campi;
  const WidgetDef(this.nome, this.icona, this.desc, this.campi);
}

const _t = FieldDef('titolo', 'Titolo');
const _st = FieldDef('sottotitolo', 'Sottotitolo');
const _btn = [
  FieldDef('pulsante', 'Testo del pulsante', hint: 'Lascia vuoto per non mostrarlo'),
  FieldDef('link', 'Link del pulsante', placeholder: '#/p/contatti', hint: 'Pagina interna (#/p/nome-pagina, #/catalogo) o indirizzo esterno'),
];

final Map<String, WidgetDef> kWidgetDefs = {
  'hero': const WidgetDef('Banner principale', 'image', 'Immagine grande con titolo, ricerca rapida e pulsante', [
    _t,
    FieldDef('sottotitolo', 'Sottotitolo', type: 'textarea', rows: 2),
    FieldDef('immagine', 'Immagine di sfondo', type: 'image', wide: true),
    FieldDef('ricerca', 'Mostra la ricerca rapida del catalogo', type: 'bool'),
    ..._btn,
  ]),
  'catalogo': const WidgetDef('Catalogo', 'grid', 'Elenco di annunci/prodotti: solo quelli in evidenza, oppure ricerca completa con filtri', [
    _t,
    _st,
    FieldDef('modalita', 'Cosa mostrare', type: 'select', noEmpty: true, options: [Opt('evidenza', 'Solo quelli "in evidenza"'), Opt('recenti', 'Gli ultimi inseriti'), Opt('completo', 'Tutti, con filtri di ricerca')]),
    FieldDef('quanti', 'Quanti mostrarne (evidenza / ultimi)', type: 'number', min: 1, step: 1),
  ]),
  'servizi': WidgetDef('Servizi / punti di forza', 'star', 'Riquadri con icona, titolo e breve testo', [
    _t,
    _st,
    FieldDef('elementi', 'Riquadri', type: 'list', wide: true, nomeElemento: 'riquadro', fields: [
      FieldDef('icona', 'Icona', type: 'select', noEmpty: true, options: [for (final n in iconNames) Opt(n)]),
      const FieldDef('titolo', 'Titolo'),
      const FieldDef('testo', 'Testo', type: 'textarea', rows: 2, wide: true),
    ]),
  ]),
  'numeri': const WidgetDef('Numeri', 'chart', 'Fascia colorata con numeri importanti', [
    _t,
    FieldDef('elementi', 'Numeri', type: 'list', wide: true, nomeElemento: 'numero', fields: [
      FieldDef('valore', 'Valore', placeholder: 'es. 25+'),
      FieldDef('etichetta', 'Descrizione', placeholder: 'es. anni di esperienza'),
    ]),
  ]),
  'testo': const WidgetDef('Testo e immagine', 'file', 'Paragrafo di presentazione con immagine a fianco', [
    _t,
    FieldDef('testo', 'Testo', type: 'textarea', rows: 6, wide: true, hint: '**grassetto**, "- " per gli elenchi'),
    FieldDef('immagine', 'Immagine', type: 'image', wide: true),
    FieldDef('invertito', 'Immagine a sinistra', type: 'bool'),
    ..._btn,
  ]),
  'recensioni': const WidgetDef('Recensioni', 'heart', 'Opinioni dei clienti con stelle', [
    _t,
    _st,
    FieldDef('fonte', 'Quali recensioni mostrare', type: 'select', noEmpty: true, options: [
      Opt('clienti', 'Le recensioni vere dei clienti (se attive), altrimenti quelle qui sotto'),
      Opt('manuali', 'Solo quelle scritte qui sotto'),
    ]),
    FieldDef('elementi', 'Recensioni', type: 'list', wide: true, nomeElemento: 'recensione', fields: [
      FieldDef('nome', 'Nome'),
      FieldDef('voto', 'Stelle (1–5)', type: 'number', min: 1, step: 1),
      FieldDef('testo', 'Testo', type: 'textarea', rows: 3, wide: true),
    ]),
  ]),
  'mappa': const WidgetDef('Mappa', 'map', 'Mappa con tutti gli annunci geolocalizzati e la sede', [_t, _st, FieldDef('altezza', 'Altezza (pixel)', type: 'number', min: 200, step: 10)]),
  'prenota': const WidgetDef('Prenota online', 'calendar', 'Invito a prenotare un appuntamento (visibile solo se le prenotazioni sono attive)', [
    _t,
    FieldDef('testo', 'Testo', type: 'textarea', rows: 2, wide: true),
    FieldDef('pulsante', 'Testo del pulsante', placeholder: 'Prenota ora'),
  ]),
  'offerte': const WidgetDef('Offerte a tempo', 'tag', 'Le offerte in corso con conto alla rovescia (visibile solo se le offerte sono attive)', [_t, _st, FieldDef('quanti', 'Quante mostrarne', type: 'number', min: 1, step: 1)]),
  'fedelta': const WidgetDef('Tessera fedeltà', 'star', 'Invito a richiedere la tessera fedeltà (visibile solo se attiva)', [_t, FieldDef('testo', 'Testo', type: 'textarea', rows: 2, wide: true)]),
  'giftcard': const WidgetDef('Gift card', 'gift', 'Invito a regalare una gift card (visibile solo se le gift card sono attive)', [
    _t,
    FieldDef('testo', 'Testo', type: 'textarea', rows: 2, wide: true),
    FieldDef('pulsante', 'Testo del pulsante', placeholder: 'Regala una gift card'),
  ]),
  'contatti': const WidgetDef('Invito al contatto', 'phone', 'Fascia con titolo, telefono, email e WhatsApp', [_t, FieldDef('testo', 'Testo', type: 'textarea', rows: 2, wide: true), ..._btn]),
};
