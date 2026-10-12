/// Struttura di una tipologia di attività (campi del catalogo, filtri, ordinamenti, schede).
library;

import '../core/util.dart';

/// Opzione di una select/checks: valore e etichetta.
class Opt {
  final String value, label;
  const Opt(this.value, [String? label]) : label = label ?? value;
}

List<Opt> opts(List<String> v) => v.map((e) => Opt(e)).toList();

/// Campo di un modulo (catalogo, widget, impostazioni…).
/// Tipi: text, textarea, number, money, select, bool, checks, url, email, tel, password, date, time,
/// color, image, photos, geo, list, orari
class FieldDef {
  final String key, label, type;
  final bool required, wide, plain, noEmpty, png;
  final String? gruppo, unit, hint, placeholder, nomeElemento;
  final List<Opt> options;
  final num? min, step;
  final int? rows, max;
  final Object? defaultValue;
  final List<FieldDef> fields;
  final List<String> indirizzo;

  const FieldDef(
    this.key,
    this.label, {
    this.type = 'text',
    this.required = false,
    this.wide = false,
    this.plain = false,
    this.noEmpty = false,
    this.png = false,
    this.gruppo,
    this.unit,
    this.hint,
    this.placeholder,
    this.nomeElemento,
    this.options = const [],
    this.min,
    this.step,
    this.rows,
    this.max,
    this.defaultValue,
    this.fields = const [],
    this.indirizzo = const [],
  });

  FieldDef withGruppo(String g) => FieldDef(key, label,
      type: type, required: required, wide: wide, plain: plain, noEmpty: noEmpty, png: png, gruppo: g, unit: unit, hint: hint,
      placeholder: placeholder, nomeElemento: nomeElemento, options: options, min: min, step: step, rows: rows, max: max,
      defaultValue: defaultValue, fields: fields, indirizzo: indirizzo);
}

/// Ogni campo senza gruppo eredita quello del campo precedente.
List<FieldDef> withGroups(List<FieldDef> defs, [String start = 'Dati principali']) {
  var g = start;
  final out = <FieldDef>[];
  for (final d in defs) {
    if (d.gruppo != null) {
      g = d.gruppo!;
      out.add(d);
    } else {
      out.add(d.withGruppo(g));
    }
  }
  return out;
}

class FilterDef {
  final String id, tipo, label;
  final String? campo, placeholder;
  final List<String> chiavi;
  final bool rapido, usate, distinti, avanzato;
  final List<Object> valori;
  const FilterDef(this.id, this.tipo, this.label,
      {this.campo, this.placeholder, this.chiavi = const [], this.rapido = false, this.usate = false, this.distinti = false, this.avanzato = false, this.valori = const []});
}

class SortDef {
  final String id, label;
  final String? campo;
  final int dir;
  final bool opzioni;
  const SortDef(this.id, this.label, {this.campo, this.dir = 1, this.opzioni = false});
}

class SpecDef {
  final String campo, icona;
  final String? unita, unitaUno, unitaMolti;
  const SpecDef(this.campo, this.icona, {this.unita, this.unitaUno, this.unitaMolti});
}

class KeySpec {
  final String campo, icona, label;
  const KeySpec(this.campo, this.icona, this.label);
}

class CardDef {
  final String titolo, prezzo;
  final String? chips, nastroCampo;
  final List<String> badge, luogo, nastroNascondi;
  final List<SpecDef> specs;
  final String Function(Json item)? suffisso;
  const CardDef({
    this.titolo = 'titolo',
    this.prezzo = 'prezzo',
    this.chips,
    this.nastroCampo,
    this.badge = const [],
    this.luogo = const [],
    this.nastroNascondi = const [],
    this.specs = const [],
    this.suffisso,
  });
}

class SchedaDef {
  final List<KeySpec> principali;
  final List<String> dettaglio, escludi;
  const SchedaDef({this.principali = const [], this.dettaglio = const [], this.escludi = const []});
}

class CatalogSchema {
  final String singolare, plurale, nuovo, icona;
  final String? privacyGeo;
  final List<String> privacyCampi;
  final List<FieldDef> campi;
  final List<FilterDef> filtri;
  final List<SortDef> ordina;
  final CardDef card;
  final SchedaDef scheda;

  CatalogSchema({
    required this.singolare,
    required this.plurale,
    required this.nuovo,
    required this.icona,
    this.privacyGeo,
    this.privacyCampi = const [],
    required List<FieldDef> campi,
    required this.filtri,
    required this.ordina,
    required this.card,
    required this.scheda,
  }) : campi = withGroups(campi);

  FieldDef? campo(String key) {
    for (final c in campi) {
      if (c.key == key) return c;
    }
    return null;
  }

  bool get hasGeo => campi.any((c) => c.type == 'geo');
}

class Preset {
  final String tipo, nome;
  final CatalogSchema catalogo;
  const Preset(this.tipo, this.nome, this.catalogo);
}
