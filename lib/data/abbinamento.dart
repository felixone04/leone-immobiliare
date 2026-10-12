/// Abbinamento tra la "casa che cerco" di un cliente e gli immobili.
///
/// Regole:
///  - il contratto (vendita/affitto) deve coincidere;
///  - il prezzo può superare il budget al massimo del 10%;
///  - dei requisiti indicati dal cliente ne deve essere soddisfatto almeno il 70%
///    (ogni dotazione richiesta conta come un requisito).
library;

import '../core/util.dart';

/// Soglia minima di requisiti soddisfatti e tolleranza sul budget.
const kSogliaAbbinamento = .7;
const kTolleranzaBudget = .10;

/// Stati dell'annuncio per cui l'immobile è proponibile.
bool immobileDisponibile(Json i) => str(i['statoAnnuncio']).isEmpty || i['statoAnnuncio'] == 'Disponibile';

class Abbinamento {
  /// Requisiti soddisfatti e mancanti (in parole, per mostrarli al cliente e all'agente).
  final List<String> ok, mancano;
  final bool sopraBudget;
  const Abbinamento(this.ok, this.mancano, {this.sopraBudget = false});

  int get totali => ok.length + mancano.length;

  /// Da 0 a 1; senza requisiti oltre a contratto e budget vale 1.
  double get punteggio => totali == 0 ? 1 : ok.length / totali;
  int get percentuale => (punteggio * 100).round();
}

/// Confronta i criteri di una ricerca con un immobile.
/// Restituisce null se contratto o budget escludono l'immobile, o se i requisiti soddisfatti sono meno del 70%.
Abbinamento? abbina(Json criteri, Json immobile) {
  final contratto = str(criteri['contratto']);
  if (contratto.isNotEmpty && immobile['contratto'] != contratto) return null;
  final budget = numOrNull(criteri['budget']), prezzo = numOrNull(immobile['prezzo']);
  if (budget != null && budget > 0) {
    if (prezzo == null || prezzo > budget * (1 + kTolleranzaBudget)) return null;
  }

  final ok = <String>[], mancano = <String>[];
  void req(bool soddisfatto, String descrizione) => (soddisfatto ? ok : mancano).add(descrizione);
  String n(Object? v) => norm(str(v));

  final tipologie = strList(criteri['tipologie']);
  if (tipologie.isNotEmpty) req(tipologie.contains(immobile['tipologia']), tipologie.join(' o '));

  final citta = strList(criteri['citta']);
  if (citta.isNotEmpty) req(citta.map(n).contains(n(immobile['citta'])), 'a ${citta.join(' o ')}');

  final zona = str(criteri['zona']).trim();
  if (zona.isNotEmpty) {
    final dove = n('${immobile['zona']} ${immobile['indirizzo']} ${immobile['cap']}');
    req(zona.split(',').map(n).where((z) => z.isNotEmpty).any(dove.contains), 'zona $zona');
  }

  void minimo(String campo, String etichetta, {String unita = ''}) {
    final m = numOrNull(criteri['${campo}Min']);
    if (m == null || m <= 0) return;
    final v = numOrNull(immobile[campo]);
    req(v != null && v >= m, 'almeno ${fmtNum(m)}$unita $etichetta'.trim());
  }

  minimo('mq', '', unita: ' m²');
  minimo('locali', 'locali');
  minimo('camere', 'camere');
  minimo('bagni', 'bagni');

  final esterni = strList(criteri['esterno']);
  if (esterni.isNotEmpty) req(strList(immobile['spazioEsterno']).any(esterni.contains), esterni.join(' o ').toLowerCase());

  if (boolOf(criteri['parcheggio'])) {
    final p = str(immobile['parcheggio']);
    req(p.isNotEmpty && p != 'Nessuno', 'posto auto o box');
  }

  final dotazioni = strList(immobile['dotazioni']);
  for (final d in strList(criteri['dotazioni'])) {
    req(dotazioni.contains(d), d.toLowerCase());
  }

  final condizioni = strList(criteri['condizioni']);
  if (condizioni.isNotEmpty) req(condizioni.contains(immobile['stato']), condizioni.join(' o ').toLowerCase());

  final a = Abbinamento(ok, mancano, sopraBudget: budget != null && prezzo != null && prezzo > budget);
  return a.punteggio >= kSogliaAbbinamento ? a : null;
}

/// Riassunto leggibile dei criteri: "Vendita · Appartamento · Milano · fino a 350.000 € · almeno 3 locali"
String descriviCriteri(Json c) {
  final parti = <String>[
    if (str(c['contratto']).isNotEmpty) str(c['contratto']),
    ...strList(c['tipologie']).isEmpty ? <String>[] : [strList(c['tipologie']).join(', ')],
    ...strList(c['citta']).isEmpty ? <String>[] : [strList(c['citta']).join(', ')],
    if (str(c['zona']).isNotEmpty) 'zona ${c['zona']}',
    if ((numOrNull(c['budget']) ?? 0) > 0) 'fino a ${fmtPrice(numOrNull(c['budget'])!)}',
    if ((numOrNull(c['mqMin']) ?? 0) > 0) 'da ${fmtNum(numOrNull(c['mqMin'])!)} m²',
    if ((numOrNull(c['localiMin']) ?? 0) > 0) 'almeno ${fmtNum(numOrNull(c['localiMin'])!)} locali',
    if ((numOrNull(c['camereMin']) ?? 0) > 0) 'almeno ${fmtNum(numOrNull(c['camereMin'])!)} camere',
    if ((numOrNull(c['bagniMin']) ?? 0) > 0) 'almeno ${fmtNum(numOrNull(c['bagniMin'])!)} bagni',
    ...strList(c['esterno']).isEmpty ? <String>[] : [strList(c['esterno']).join(' o ').toLowerCase()],
    if (boolOf(c['parcheggio'])) 'posto auto',
    ...strList(c['dotazioni']).map((d) => d.toLowerCase()),
  ];
  return parti.isEmpty ? 'Qualsiasi immobile' : parti.join(' · ');
}
