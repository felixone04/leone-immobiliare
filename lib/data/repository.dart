/// Tutti i dati del sito e le regole di gestione (quello che nella versione web facevano api.php e inc/*.php).
/// I dati vivono in memoria per una visualizzazione immediata e ogni modifica viene salvata subito
/// nell'archivio locale del browser.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sembast/sembast.dart';

import '../app_config.dart';
import '../core/util.dart';
import 'preset.dart';
import 'store.dart';

part 'repo_booking.dart';
part 'repo_clienti.dart';
part 'repo_giftcard.dart';

const kModuli = ['prenotazioni', 'fedelta', 'pacchetti', 'offerte', 'recensioni'];

/// Moduli attivabili: [chiave, etichetta, descrizione, icona]
const kModuliInfo = [
  ['prenotazioni', 'Prenotazioni online', "Agenda con orari, collaboratori, lista d'attesa e gift card", 'calendar'],
  ['fedelta', 'Tessera fedeltà', 'Timbri o punti raccolti a ogni visita', 'star'],
  ['pacchetti', 'Pacchetti a sedute', 'Es. 10 ingressi, con le sedute scalate a ogni visita', 'layers'],
  ['offerte', 'Offerte a tempo e coupon', 'Promozioni con scadenza e conto alla rovescia', 'tag'],
  ['recensioni', 'Recensioni dei clienti', "Con moderazione e risposta dell'azienda", 'heart'],
];

class Repo extends ChangeNotifier {
  final LocalStore _s;
  Repo._(this._s);

  Preset get preset => AppConfig.preset;
  CatalogSchema get schema => preset.catalogo;

  // Contenuti del sito
  Json settings = {};
  List<Json> items = [];
  List<Json> pages = [];
  List<Json> widgets = [];
  Map<String, bool> _moduli = {};
  final Map<String, Json> _cfg = {};

  // Dati dei clienti
  List<Json> _pren = [], _gift = [], _rich = [], _att = [], _tess = [], _rec = [];
  final Map<String, Uint8List> media = {};

  String? consenso;

  static Future<Repo> open() async {
    final s = await LocalStore.open(AppConfig.dbName);
    final r = Repo._(s);
    if (await s.get('seeded') != true) await r._seed();
    await r._load();
    return r;
  }

  /* ---------------- Caricamento ---------------- */

  Future<void> _seed() async {
    final seed = jsonDecode(await rootBundle.loadString(AppConfig.seedAsset)) as Json;
    await _s.transaction((txn) async {
      await LocalStore.kv.record('settings').put(txn, seed['settings']);
      await LocalStore.kv.record('pages').put(txn, seed['pages']);
      await LocalStore.kv.record('widgets').put(txn, seed['widgets']);
      await LocalStore.kv.record('moduli').put(txn, seed['moduli'] ?? {});
      for (final k in ['prenotazioni', 'giftcard', 'fedelta', 'pacchetti', 'offerte']) {
        if (seed[k] != null) await LocalStore.kv.record('cfg_$k').put(txn, seed[k]);
      }
      if (seed['recensioniCfg'] != null) await LocalStore.kv.record('cfg_recensioni').put(txn, seed['recensioniCfg']);
      for (final it in jsonList(seed['items'])) {
        await LocalStore.coll('items').record(it['id'] as String).put(txn, it);
      }
      for (final r in jsonList(seed['recensioni'])) {
        await LocalStore.coll('recensioni').record(r['id'] as String).put(txn, r);
      }
      await LocalStore.kv.record('seeded').put(txn, true);
    });
  }

  Future<void> _load() async {
    settings = jsonOf(LocalStore.mutable(await _s.get('settings')));
    settings['tipo'] = preset.tipo;
    pages = jsonList(LocalStore.mutable(await _s.get('pages')));
    widgets = jsonList(LocalStore.mutable(await _s.get('widgets')));
    final m = jsonOf(await _s.get('moduli'));
    _moduli = {for (final k in kModuli) k: boolOf(m[k])};
    for (final k in [...kModuli, 'giftcard']) {
      _cfg[k] = jsonOf(LocalStore.mutable(await _s.get('cfg_$k')));
    }
    items = await _s.all('items');
    items.sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
    _pren = await _s.all('prenotazioni');
    _gift = await _s.all('giftcard');
    _rich = await _s.all('richieste');
    _att = await _s.all('attesa');
    _tess = await _s.all('tessere');
    _rec = await _s.all('recensioni');
    for (final r in await _s.all('media')) {
      media[r['id'] as String] = base64Decode(r['b64'] as String);
    }
    consenso = await _s.get('consenso') as String?;
  }

  void _changed() => notifyListeners();

  /* ---------------- Consenso ai contenuti esterni (mappe) ---------------- */

  Future<void> setConsenso(String v) async {
    consenso = v;
    await _s.set('consenso', v);
    _changed();
  }

  /* ---------------- Moduli ---------------- */

  /// Moduli attivi; le gift card dipendono dalle prenotazioni e dall'attivazione dell'azienda.
  Map<String, bool> get moduli => {..._moduli, 'giftcard': gcAttive};
  bool modulo(String k) => moduli[k] ?? false;
  Map<String, bool> get moduliBase => Map.of(_moduli);

  Future<void> setModuli(Map<String, bool> m) async {
    _moduli = {for (final k in kModuli) k: m[k] ?? false};
    await _s.set('moduli', _moduli);
    _changed();
  }

  void _richiediModulo(String k) {
    if (!modulo(k)) throw const AppError('Funzione non disponibile');
  }

  /* ---------------- Contenuti del sito ---------------- */

  Json? item(String id) {
    for (final i in items) {
      if (i['id'] == id) return i;
    }
    return null;
  }

  Future<void> saveSettings(Json s) async {
    final out = Map<String, dynamic>.from(s)..removeWhere((k, _) => const ['tipo', 'password', 'passwordHash'].contains(k));
    await _s.set('settings', out);
    settings = {...out, 'tipo': preset.tipo};
    _changed();
  }

  Future<Json> saveItem(Json input) async {
    final it = cloneJson(input);
    if (str(it['titolo']).trim().isEmpty) throw const AppError('Il titolo è obbligatorio');
    final now = nowMs();
    final id = _cleanId(it['id']);
    final old = id != null ? item(id) : null;
    final saved = {
      ...it,
      'id': id ?? newId(),
      'titolo': cut(str(it['titolo']), 255),
      'creato': old != null ? intOf(old['creato'], now) : intOf(it['creato'], now),
      'modificato': now,
    };
    await _s.put('items', saved['id'] as String, saved);
    if (old != null) {
      items[items.indexOf(old)] = saved;
    } else {
      items.insert(0, saved);
    }
    _changed();
    return saved;
  }

  Future<void> deleteItem(String id) async {
    await _s.delete('items', id);
    items.removeWhere((i) => i['id'] == id);
    _changed();
  }

  /// La pagina Contatti e l'informativa privacy sono obbligatorie.
  static List<Json> _garantisciPagine(List<Json> pagine) {
    var contatti = false, privacy = false;
    for (final p in pagine) {
      if (p['tipo'] == 'contatti') {
        if (contatti) {
          p['tipo'] = 'testo';
          continue;
        }
        contatti = true;
        p['menu'] = true;
        p['footer'] = true;
      }
    }
    if (!contatti) pagine.add({'slug': 'contatti', 'titolo': 'Contatti', 'tipo': 'contatti', 'menu': true, 'footer': true, 'contenuto': 'Scrivici per qualsiasi informazione.'});
    for (final p in pagine) {
      if (p['tipo'] == 'privacy' || (!privacy && p['slug'] == 'privacy')) {
        if (privacy) {
          p['tipo'] = 'testo';
          continue;
        }
        privacy = true;
        p['tipo'] = 'privacy';
        p['footer'] = true;
      }
    }
    if (!privacy) pagine.add({'slug': 'privacy', 'titolo': 'Privacy e cookie', 'tipo': 'privacy', 'menu': false, 'footer': true, 'contenuto': ''});
    return pagine;
  }

  Future<void> savePages(List<Json> input) async {
    final list = _garantisciPagine(cloneJson(input));
    final usati = <String>{};
    for (final p in list) {
      p['id'] = _cleanId(p['id']) ?? newId();
      final base = cut(slugify(str(p['slug']).isNotEmpty ? str(p['slug']) : str(p['titolo'])), 100);
      var s = base, n = 2;
      while (usati.contains(s)) {
        s = '$base-${n++}';
      }
      usati.add(s);
      p['slug'] = s;
    }
    await _s.set('pages', list);
    pages = list;
    _changed();
  }

  Future<void> saveWidgets(List<Json> input) async {
    final list = cloneJson(input);
    for (final w in list) {
      w['id'] = _cleanId(w['id']) ?? newId();
    }
    await _s.set('widgets', list);
    widgets = list;
    _changed();
  }

  /* ---------------- Configurazioni dei moduli ---------------- */

  static Json cfgDefault(String k) => switch (k) {
        'fedelta' => {
            'obiettivo': 10, 'unita': 'timbri', 'perVisita': 1, 'premio': 'Un servizio in omaggio',
            'regole': "Ricevi un timbro a ogni visita. Al raggiungimento dell'obiettivo il premio è tuo!", 'richiestaOnline': true,
          },
        'pacchetti' => {'pacchetti': [], 'testo': 'Risparmia acquistando più sedute insieme. Il pagamento si effettua in struttura.'},
        'offerte' => {'offerte': []},
        'recensioni' => {'approvazione': 'manuale', 'googleUrl': '', 'aperte': true},
        _ => {},
      };

  Json cfgModulo(String k) => {...cfgDefault(k), ...cloneJson(_cfg[k] ?? {})};

  Future<Json> saveModConfig(String k, Json c) async {
    if (!['fedelta', 'pacchetti', 'offerte', 'recensioni'].contains(k)) throw const AppError('Modulo non valido');
    if (!modulo(k)) throw const AppError('Questa funzione non è attiva per il sito');
    final def = cfgDefault(k);
    final out = {for (final e in c.entries) if (def.containsKey(e.key)) e.key: e.value};
    if (k == 'pacchetti') out['pacchetti'] = conId(jsonList(out['pacchetti']));
    if (k == 'offerte') out['offerte'] = conId(jsonList(out['offerte']));
    if (k == 'fedelta' && intOf(out['obiettivo']) < 1) throw const AppError("L'obiettivo deve essere almeno 1");
    await _setCfg(k, out);
    return cfgModulo(k);
  }

  Future<void> _setCfg(String k, Json v) async {
    _cfg[k] = v;
    await _s.set('cfg_$k', v);
    _changed();
  }

  /// Voci del catalogo [id, titolo] per le select delle impostazioni.
  List<Opt> get vociCatalogo {
    final l = [...items]..sort((a, b) => str(a['titolo']).compareTo(str(b['titolo'])));
    return [for (final i in l) Opt(i['id'] as String, str(i['titolo']))];
  }

  /* ---------------- Immagini caricate ---------------- */

  Future<String> saveMedia(Uint8List bytes, String mime) async {
    final id = newId();
    await _s.put('media', id, {'id': id, 'mime': mime, 'b64': base64Encode(bytes), 'creato': nowMs()});
    media[id] = bytes;
    return 'media:$id';
  }

  /// Elimina le immagini caricate che nessun contenuto usa più.
  Future<int> cleanupMedia() async {
    final tutto = jsonEncode(exportSite());
    var n = 0;
    for (final id in media.keys.toList()) {
      if (!tutto.contains('media:$id')) {
        await _s.delete('media', id);
        media.remove(id);
        n++;
      }
    }
    return n;
  }

  /* ---------------- Backup ---------------- */

  /// Stesso formato del backup della versione web (compatibile in entrambe le direzioni);
  /// le immagini caricate sono incluse nel file.
  Json exportSite() => {
        'settings': cloneJson(settings),
        'items': cloneJson(items),
        'pages': cloneJson(pages),
        'widgets': cloneJson(widgets),
        'prenotazioni': prenConfig(),
        'giftcard': gcConfig(),
        for (final m in ['fedelta', 'pacchetti', 'offerte', 'recensioni']) m: cfgModulo(m),
      };

  Json exportFull() => {
        ...exportSite(),
        'media': {
          for (final e in media.entries) e.key: base64Encode(e.value),
        },
      };

  Future<void> importSite(Json sito) async {
    if (sito['items'] is! List || sito['pages'] is! List || sito['widgets'] is! List) throw const AppError('File di backup non valido');
    final mediaIn = jsonOf(sito['media']);
    for (final e in mediaIn.entries) {
      final bytes = base64Decode(str(e.value));
      await _s.put('media', e.key, {'id': e.key, 'mime': 'image/jpeg', 'b64': str(e.value), 'creato': nowMs()});
      media[e.key] = bytes;
    }
    if (sito['settings'] is Map) await saveSettings(jsonOf(sito['settings']));
    await _s.clear('items');
    items = [];
    for (final it in jsonList(sito['items'])) {
      final now = nowMs();
      final id = _cleanId(it['id']) ?? newId();
      final saved = {...it, 'id': id, 'creato': intOf(it['creato'], now), 'modificato': intOf(it['modificato'], now)};
      await _s.put('items', id, saved);
      items.add(saved);
    }
    items.sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
    await savePages(jsonList(sito['pages']));
    await saveWidgets(jsonList(sito['widgets']));
    const liste = {'prenotazioni': ['collaboratori', 'servizi'], 'giftcard': ['proposte'], 'fedelta': <String>[], 'pacchetti': ['pacchetti'], 'offerte': ['offerte'], 'recensioni': <String>[]};
    for (final e in liste.entries) {
      if (sito[e.key] is! Map) continue;
      final c = jsonOf(sito[e.key]);
      for (final l in e.value) {
        c[l] = conId(jsonList(c[l]));
      }
      await _setCfg(e.key, c);
    }
    _changed();
  }

  /* ---------------- Contatori per l'area riservata ---------------- */

  Map<String, int> contatori() {
    final oggiS = oggi();
    if (modulo('prenotazioni')) attAggiorna();
    return {
      'messaggi': _rich.where((r) => r['stato'] == 'nuova').length,
      'recensioni': _rec.where((r) => r['stato'] == 'in_attesa').length,
      'prenotazioni': modulo('prenotazioni') ? _pren.where((p) => p['stato'] == 'in_attesa' && str(p['data']).compareTo(oggiS) >= 0).length : 0,
      'attesa': modulo('prenotazioni') ? _att.where((a) => a['stato'] == 'posto_libero').length : 0,
    };
  }

  /* ---------------- Limiti anti-abuso (per sessione, come in PHP) ---------------- */

  final Map<String, List<int>> _limiti = {};

  void _limita(String k, {int max = 8}) {
    final ora = nowMs();
    final l = (_limiti[k] ?? []).where((t) => t > ora - 3600000).toList();
    if (l.length >= max) throw const AppError('Troppe richieste ravvicinate: riprova più tardi o contattaci per telefono.');
    _limiti[k] = [...l, ora];
  }

  /* ---------------- Utilità ---------------- */

  static String? _cleanId(Object? id) => id is String && RegExp(r'^[a-zA-Z0-9_-]{1,32}$').hasMatch(id) ? id : null;

  /// Assicura un id valido a ogni elemento di una lista (collaboratori, servizi, proposte, offerte…)
  static List<Json> conId(List<Json> lista) => [
        for (final x in lista) {...x, 'id': _cleanId(x['id']) ?? newId(5)}
      ];

  static String testoBreve(Object? v, int max) => cut(str(v).trim(), max);

  /// Dati di contatto del cliente: nome obbligatorio, almeno telefono o email validi.
  static Json contattoCliente(Json input, {bool emailObbligatoria = false, bool telObbligatorio = false}) {
    final nome = testoBreve(input['nome'], 120), email = testoBreve(input['email'], 160), tel = testoBreve(input['telefono'], 30);
    if (nome.isEmpty) throw const AppError('Inserisci nome e cognome');
    if (email.isNotEmpty && !validEmail(email)) throw const AppError('Indirizzo email non valido');
    if (tel.isNotEmpty && !validPhone(tel)) throw const AppError('Numero di telefono non valido');
    if (emailObbligatoria && email.isEmpty) throw const AppError("Inserisci l'indirizzo email");
    if (telObbligatorio && tel.isEmpty) throw const AppError('Inserisci il numero di telefono');
    if (email.isEmpty && tel.isEmpty) throw const AppError('Inserisci almeno telefono o email');
    return {'nome': nome, 'email': email, 'telefono': tel};
  }

  Future<void> _put(String store, List<Json> list, Json row) async {
    await _s.put(store, row['id'] as String, row);
    final i = list.indexWhere((x) => x['id'] == row['id']);
    if (i < 0) {
      list.add(row);
    } else {
      list[i] = row;
    }
    _changed();
  }

  Future<void> _delete(String store, List<Json> list, String id) async {
    await _s.delete(store, id);
    list.removeWhere((x) => x['id'] == id);
    _changed();
  }
}
