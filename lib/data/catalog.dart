/// Catalogo: formattazione dei valori, filtri di ricerca e ordinamenti (come catalog.js).
library;

import '../core/util.dart';
import 'abbinamento.dart';
import 'preset.dart';

/// Un annuncio resta "Nuovo" per questi giorni da quando è disponibile.
const kGiorniNuovo = 14;

class Catalog {
  final CatalogSchema s;
  final List<Json> items;
  const Catalog(this.s, this.items);

  /* ---------- Formattazione ---------- */

  String fmt(Json item, String key) {
    final c = s.campo(key);
    final v = item[key];
    if (isEmptyValue(v)) return '';
    if (c == null) return str(v);
    switch (c.type) {
      case 'money':
        return fmtPrice(numOrNull(v) ?? 0);
      case 'number':
        final n = numOrNull(v);
        if (n == null) return str(v);
        return (c.plain ? str(n) : fmtNum(n)) + (c.unit != null ? ' ${c.unit}' : '');
      case 'bool':
        return boolOf(v) ? 'Sì' : 'No';
      case 'checks':
        return strList(v).join(', ');
      case 'geo':
        return '';
      default:
        return str(v);
    }
  }

  String prezzo(Json item) {
    final cd = s.card;
    final v = item[cd.prezzo];
    if (isEmptyValue(v)) return 'Prezzo su richiesta';
    return fmtPrice(numOrNull(v) ?? 0) + (cd.suffisso?.call(item) ?? '');
  }

  /// Prezzo precedente barrato, se il prezzo è stato ribassato e l'immobile è ancora disponibile.
  String? prezzoPieno(Json item) {
    final pieno = numOrNull(item['prezzoPrecedente']), v = numOrNull(item[s.card.prezzo]);
    return pieno != null && v != null && pieno > v && immobileDisponibile(item) ? fmtPrice(pieno) : null;
  }

  /// Etichette dell'annuncio: Esclusiva (scelta dall'agenzia), Nuovo (disponibile da meno di
  /// [kGiorniNuovo] giorni) e Prezzo ribassato (automatica quando il prezzo scende).
  List<String> etichette(Json item) {
    if (!immobileDisponibile(item)) return const [];
    final dal = intOf(item['disponibileDal'], intOf(item['creato']));
    return [
      if (boolOf(item['esclusiva'])) 'Esclusiva',
      if (dal > 0 && DateTime.now().millisecondsSinceEpoch - dal < kGiorniNuovo * 86400000) 'Nuovo',
      if (prezzoPieno(item) != null) 'Prezzo ribassato',
    ];
  }

  String luogo(Json item) => s.card.luogo.map((k) => str(item[k])).where((x) => x.isNotEmpty).join(', ');

  List<String> foto(Json item) => strList(item['foto']).where((x) => safeSrc(x).isNotEmpty).toList();

  String spec(Json item, SpecDef sp) {
    final v = item[sp.campo];
    if (isEmptyValue(v)) return '';
    final c = s.campo(sp.campo);
    var t = v is num ? (c?.plain == true ? str(v) : fmtNum(v)) : (v is List ? strList(v).join(', ') : str(v));
    if (sp.unita != null) t += ' ${sp.unita}';
    if (sp.unitaUno != null) t += ' ${numOrNull(v) == 1 ? sp.unitaUno : sp.unitaMolti}';
    return t;
  }

  /// Etichetta "nastro" (es. Venduto, In trattativa): vuota se l'annuncio è disponibile.
  String nastro(Json item) {
    final k = s.card.nastroCampo;
    if (k == null) return '';
    final v = str(item[k]);
    return v.isNotEmpty && !s.card.nastroNascondi.contains(v) ? v : '';
  }

  /// Coordinate: se l'annuncio nasconde l'indirizzo, la posizione è resa approssimativa.
  ({double lat, double lng, bool esatta})? geo(Json item) {
    final g = jsonOf(item['geo']);
    final lat = numOrNull(g['lat']), lng = numOrNull(g['lng']);
    if (lat == null || lng == null) return null;
    final p = s.privacyGeo;
    final esatta = p == null || boolOf(item[p]);
    if (esatta) return (lat: lat.toDouble(), lng: lng.toDouble(), esatta: true);
    return (lat: (lat * 250).round() / 250, lng: (lng * 250).round() / 250, esatta: false);
  }

  bool mostraPrivati(Json item) => s.privacyGeo == null || boolOf(item[s.privacyGeo]);

  /* ---------- Filtri ---------- */

  List<String> opzioni(FilterDef f) {
    final c = f.campo != null ? s.campo(f.campo!) : null;
    if (f.distinti || c == null || c.options.isEmpty) {
      final set = <String>{};
      for (final i in items) {
        final v = i[f.campo];
        for (final x in (v is List ? v : [v])) {
          if (!isEmptyValue(x)) set.add(str(x));
        }
      }
      return set.toList()..sort((a, b) => norm(a).compareTo(norm(b)));
    }
    final o = c.options.map((e) => e.value).toList();
    if (!f.usate) return o;
    return o.where((x) => items.any((i) => (i[f.campo] is List ? strList(i[f.campo]) : [str(i[f.campo])]).contains(x))).toList();
  }

  static bool attivo(FilterDef f, Map<String, String> st) =>
      f.tipo == 'range' ? (st['${f.id}_min'] ?? '').isNotEmpty || (st['${f.id}_max'] ?? '').isNotEmpty : (st[f.id] ?? '').isNotEmpty;

  bool match(Json item, Map<String, String> st) {
    for (final f in s.filtri) {
      final v = st[f.id] ?? '';
      List<String> arr() => item[f.campo] is List ? strList(item[f.campo]) : (isEmptyValue(item[f.campo]) ? [] : [str(item[f.campo])]);
      final ok = switch (f.tipo) {
        'testo' => v.isEmpty ||
            (() {
              final hay = norm(f.chiavi.map((k) => item[k] is List ? strList(item[k]).join(' ') : str(item[k])).join(' '));
              return norm(v).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).every(hay.contains);
            })(),
        'select' || 'segmenti' => v.isEmpty || str(item[f.campo]) == v,
        'range' => (() {
            final lo = numOrNull(st['${f.id}_min']), hi = numOrNull(st['${f.id}_max']);
            if (lo == null && hi == null) return true;
            final n = numOrNull(item[f.campo]);
            if (n == null) return false;
            return (lo == null || n >= lo) && (hi == null || n <= hi);
          })(),
        'min' => v.isEmpty || (numOrNull(item[f.campo]) ?? 0) >= (numOrNull(v) ?? 0),
        'contiene' => v.isEmpty || (v == '*' ? arr().isNotEmpty : arr().contains(v)),
        'tutti' => v.isEmpty || v.split('|').every(arr().contains),
        'nessuno' => v.isEmpty || !v.split('|').any(arr().contains),
        'bool' => v.isEmpty || !isEmptyValue(item[f.campo]) && item[f.campo] != false,
        'escludi' => v.isEmpty || !f.valori.contains(item[f.campo]),
        _ => true,
      };
      if (!ok) return false;
    }
    return true;
  }

  List<Json> sort(List<Json> arr, String? sid) {
    final ord = s.ordina;
    final o = ord.where((x) => x.id == sid).firstOrNull ?? (ord.isEmpty ? null : ord.first);
    int recenti(Json a, Json b) => intOf(b['creato']).compareTo(intOf(a['creato']));
    if (o == null || o.campo == null) return arr..sort(recenti);
    final c = s.campo(o.campo!);
    Object? key(Json i) {
      if (o.opzioni && c != null && c.options.isNotEmpty) {
        final k = c.options.indexWhere((x) => x.value == i[o.campo]);
        return k < 0 ? 999 : k;
      }
      return i[o.campo];
    }

    return arr
      ..sort((a, b) {
        final x = key(a), y = key(b);
        if (isEmptyValue(x)) return isEmptyValue(y) ? 0 : 1;
        if (isEmptyValue(y)) return -1;
        final d = x is num && y is num ? x.compareTo(y) : norm(x).compareTo(norm(y));
        final r = d * o.dir;
        return r != 0 ? r : recenti(a, b);
      });
  }

  /// Etichette dei filtri attivi (i "chip" rimovibili sopra i risultati).
  List<({String id, String? val, String t})> chipsAttivi(Map<String, String> st) {
    final out = <({String id, String? val, String t})>[];
    String n(String x) => fmtNum(numOrNull(x) ?? 0);
    for (final f in s.filtri) {
      if (!attivo(f, st)) continue;
      final v = st[f.id] ?? '';
      final label = f.label.replaceAll(RegExp(r'\s*\(.*\)'), '');
      if (f.tipo == 'range') {
        final lo = st['${f.id}_min'] ?? '', hi = st['${f.id}_max'] ?? '';
        out.add((id: f.id, val: null, t: '$label: ${lo.isNotEmpty && hi.isNotEmpty ? '${n(lo)}–${n(hi)}' : lo.isNotEmpty ? 'da ${n(lo)}' : 'fino a ${n(hi)}'}'));
      } else if (f.tipo == 'tutti' || f.tipo == 'nessuno') {
        for (final x in v.split('|')) {
          out.add((id: f.id, val: x, t: (f.tipo == 'nessuno' ? 'Senza ' : '') + x));
        }
      } else if (f.tipo == 'min') {
        out.add((id: f.id, val: null, t: '${f.label}: $v+'));
      } else if (f.tipo == 'bool' || f.tipo == 'escludi') {
        out.add((id: f.id, val: null, t: f.label));
      } else if (f.tipo == 'contiene' && v == '*') {
        out.add((id: f.id, val: null, t: '${f.label}: sì'));
      } else if (f.tipo == 'testo') {
        out.add((id: f.id, val: null, t: '“$v”'));
      } else {
        out.add((id: f.id, val: null, t: v));
      }
    }
    return out;
  }

  /// Annunci simili: stessa città o stessa tipologia, escludendo quelli non disponibili.
  List<Json> simili(Json item) {
    final k1 = s.card.luogo.isEmpty ? null : s.card.luogo.last;
    final k2 = s.card.badge.isEmpty ? null : s.card.badge.last;
    final l = items.where((i) => i['id'] != item['id'] && nastro(i).isEmpty).map((i) {
      final p = (k1 != null && i[k1] == item[k1] ? 2 : 0) + (k2 != null && i[k2] == item[k2] ? 1 : 0);
      return (i: i, p: p);
    }).toList();
    // ordinamento stabile come Array.sort di JavaScript
    final idx = {for (var k = 0; k < l.length; k++) l[k].i['id']: k};
    l.sort((a, b) => b.p != a.p ? b.p.compareTo(a.p) : idx[a.i['id']]!.compareTo(idx[b.i['id']]!));
    return l.take(3).map((x) => x.i).toList();
  }
}
