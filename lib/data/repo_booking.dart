part of 'repository.dart';

/*
 * MODULO PRENOTAZIONI
 * Orari liberi in base a: durata del servizio, orari di apertura (dell'attività o del collaboratore),
 * chiusure/ferie, appuntamenti già presi, pausa tra appuntamenti, preavviso minimo e anticipo massimo.
 * Orari in minuti dalla mezzanotte (es. 9:30 = 570).
 */

const kStatiAttivi = ['in_attesa', 'confermata'];

extension RepoBooking on Repo {
  static Json prenDefault() {
    const g = [
      ['09:00', '13:00'],
      ['14:30', '19:00']
    ];
    return {
      'conferma': 'automatica',
      'passo': 15,
      'pausa': 0,
      'preavviso': 2,
      'anticipo': 60,
      'orari': {'1': g, '2': g, '3': g, '4': g, '5': g, '6': [['09:00', '13:00']], '0': []},
      'chiusure': [],
      'collaboratori': [],
      'servizi': [],
      'durataPredefinita': 30,
      'messaggio': 'Grazie! Ti aspettiamo.',
      'modificaCliente': true,
      'limiteModificaOre': 24,
      'listaAttesa': true,
    };
  }

  Json prenConfig() {
    final c = {...prenDefault(), ...cloneJson(_cfg['prenotazioni'] ?? {})};
    const lim = {'passo': [5, 120], 'pausa': [0, 240], 'preavviso': [0, 720], 'anticipo': [1, 365]};
    lim.forEach((k, r) => c[k] = intOf(c[k]).clamp(r[0], r[1]));
    c['orari'] = _orariMappa(c['orari']);
    return c;
  }

  /// Gli orari possono arrivare come lista [dom, lun, …] o come mappa {"0": …}: li normalizziamo in mappa.
  static Json _orariMappa(Object? o) {
    if (o is List) return {for (var i = 0; i < o.length && i < 7; i++) '$i': o[i]};
    return jsonOf(o);
  }

  Future<Json> savePrenConfig(Json c) async {
    _richiediModulo('prenotazioni');
    final def = prenDefault();
    final out = {for (final e in c.entries) if (def.containsKey(e.key)) e.key: e.value};
    for (final k in ['collaboratori', 'servizi']) {
      out[k] = Repo.conId(jsonList(out[k]));
    }
    await _setCfg('prenotazioni', out);
    return prenConfig();
  }

  /// Servizi prenotabili: voci del catalogo con durata + servizi extra definiti nelle impostazioni.
  Map<String, Json> prenServizi([Json? cfg]) {
    cfg ??= prenConfig();
    final out = <String, Json>{};
    for (final d in items) {
      final dur = intOf(d['durata']);
      if (dur <= 0 || d['prenotabile'] == false) continue;
      out[d['id'] as String] = {'id': d['id'], 'nome': str(d['titolo']), 'durata': dur, 'prezzo': d['prezzo'], 'categoria': str(d['categoria'])};
    }
    for (final s in jsonList(cfg['servizi'])) {
      if (str(s['id']).isEmpty || str(s['nome']).trim().isEmpty) continue;
      final id = 'x-${s['id']}';
      out[id] = {'id': id, 'nome': str(s['nome']), 'durata': intOf(s['durata'], intOf(cfg['durataPredefinita'], 30)).clamp(5, 100000), 'prezzo': s['prezzo'], 'categoria': ''};
    }
    return out;
  }

  /// Collaboratori che possono svolgere il servizio. Senza collaboratori c'è un'unica agenda (id '').
  List<Json> prenCollaboratori(Json cfg, [String servizio = '']) {
    final attivi = jsonList(cfg['collaboratori']).where((c) => str(c['id']).isNotEmpty && c['attivo'] != false).toList();
    if (attivi.isEmpty) return [{'id': '', 'nome': '', 'orari': null, 'chiusure': []}];
    if (servizio.isEmpty) return attivi;
    return attivi.where((c) {
      final s = strList(c['servizi']);
      return s.isEmpty || s.contains(servizio);
    }).toList();
  }

  static bool _inChiusura(Object? chiusure, String data) {
    for (final c in jsonList(chiusure)) {
      final dal = str(c['dal']);
      final al = str(c['al']).isEmpty ? dal : str(c['al']);
      if (dal.isNotEmpty && data.compareTo(dal) >= 0 && data.compareTo(al) <= 0) return true;
    }
    return false;
  }

  /// Intervalli di lavoro [inizio, fine] di un collaboratore in una data.
  List<List<int>> _intervalli(Json cfg, Json coll, String data) {
    if (_inChiusura(cfg['chiusure'], data) || _inChiusura(coll['chiusure'], data)) return [];
    final orari = boolOf(coll['orariPropri']) && coll['orari'] != null ? _orariMappa(coll['orari']) : jsonOf(cfg['orari']);
    final w = '${parseDate(data).weekday % 7}';
    final out = <List<int>>[];
    for (final iv in (orari[w] is List ? orari[w] as List : const [])) {
      if (iv is! List || iv.length < 2) continue;
      final a = hm(str(iv[0])), b = hm(str(iv[1]));
      if (a != null && b != null && b > a) out.add([a, b]);
    }
    return out;
  }

  /// Appuntamenti che occupano l'agenda in una data, per collaboratore.
  Map<String, List<(int, int, String)>> _occupati(String data) {
    final out = <String, List<(int, int, String)>>{};
    for (final p in _pren) {
      if (p['data'] != data || !kStatiAttivi.contains(p['stato'])) continue;
      (out[str(p['collaboratore_id'])] ??= []).add((intOf(p['inizio']), intOf(p['fine']), p['id'] as String));
    }
    return out;
  }

  /// Orari liberi per un servizio in una data: { 'HH:MM': [id collaboratori liberi] }
  Map<String, List<String>> slotLiberi(String data, Json servizio, {String coll = '', Json? cfg, bool admin = false, String escludi = ''}) {
    cfg ??= prenConfig();
    if (!validIsoDate(data)) return {};
    final oggiS = oggi();
    if (!admin && (data.compareTo(oggiS) < 0 || data.compareTo(addDays(oggiS, intOf(cfg['anticipo']))) > 0)) return {};
    final limite = admin ? null : DateTime.now().add(Duration(hours: intOf(cfg['preavviso'])));
    final dur = intOf(servizio['durata']), pausa = intOf(cfg['pausa']), passo = intOf(cfg['passo']);
    final occ = _occupati(data);
    final giorno = parseDate(data);
    final out = <String, List<String>>{};
    for (final c in prenCollaboratori(cfg, str(servizio['id']))) {
      final cid = str(c['id']);
      if (coll.isNotEmpty && cid != coll) continue;
      final busy = (occ[cid] ?? []).where((o) => o.$3 != escludi).toList();
      for (final iv in _intervalli(cfg, c, data)) {
        for (var t = iv[0]; t + dur <= iv[1]; t += passo) {
          if (limite != null && giorno.add(Duration(minutes: t)).isBefore(limite)) continue;
          final libero = busy.every((o) => !(t < o.$2 + pausa && t + dur + pausa > o.$1));
          if (libero) (out[fmtHm(t)] ??= []).add(cid);
        }
      }
    }
    return Map.fromEntries(out.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  /// Numero di orari liberi per ogni giorno di un periodo (per il calendario).
  Map<String, int> giorniLiberi(Json servizio, String coll, String dal, [int giorni = 42]) {
    final cfg = prenConfig();
    return {
      for (var i = 0; i < giorni; i++) addDays(dal, i): slotLiberi(addDays(dal, i), servizio, coll: coll, cfg: cfg).length,
    };
  }

  /// Dati pubblici per il modulo di prenotazione del sito.
  Json prenPubblico() {
    final cfg = prenConfig();
    return {
      'servizi': prenServizi(cfg).values.toList(),
      'collaboratori': [
        for (final c in prenCollaboratori(cfg))
          if (str(c['id']).isNotEmpty) {'id': c['id'], 'nome': str(c['nome']), 'ruolo': str(c['ruolo']), 'servizi': strList(c['servizi'])}
      ],
      'anticipo': cfg['anticipo'],
      'conferma': cfg['conferma'],
      'messaggio': str(cfg['messaggio']),
      'listaAttesa': boolOf(cfg['listaAttesa']),
      'modificaCliente': boolOf(cfg['modificaCliente']),
      'limiteModificaOre': intOf(cfg['limiteModificaOre']),
    };
  }

  /// Crea una prenotazione verificando che l'orario sia ancora libero.
  /// [admin]: inserimento dall'area riservata (può scegliere lo stato e ignorare il preavviso).
  Future<Json> prenCrea(Json input, {bool admin = false}) async {
    _richiediModulo('prenotazioni');
    if (!admin) _limita('pren', max: 5);
    final cfg = prenConfig();
    final s = prenServizi(cfg)[str(input['servizio'])];
    if (s == null) throw const AppError('Servizio non disponibile');
    final data = str(input['data']), ora = str(input['ora']);
    var coll = str(input['collaboratore']);
    final nome = str(input['nome']).trim(), email = str(input['email']).trim(), tel = str(input['telefono']).trim();
    if (nome.isEmpty || nome.length > 120) throw const AppError('Inserisci nome e cognome');
    if (!admin && !validEmail(email)) throw const AppError('Inserisci un indirizzo email valido');
    if (!admin && !validPhone(tel)) throw const AppError('Inserisci un numero di telefono valido');
    final inizio = hm(ora);
    if (!validIsoDate(data) || inizio == null) throw const AppError('Data o orario non validi');
    final forza = admin && boolOf(input['forza']);
    final liberi = slotLiberi(data, s, coll: coll, cfg: cfg, admin: admin);
    if (!forza && (liberi[fmtHm(inizio)] ?? []).isEmpty) throw const AppError('Questo orario non è più disponibile: scegline un altro');
    if (coll.isEmpty) {
      // "Nessuna preferenza": il collaboratore libero con meno appuntamenti quel giorno
      final cand = [...(liberi[fmtHm(inizio)] ?? [str(prenCollaboratori(cfg, s['id'] as String).first['id'])])];
      final carico = _occupati(data);
      cand.sort((a, b) => (carico[a]?.length ?? 0).compareTo(carico[b]?.length ?? 0));
      coll = cand.isEmpty ? '' : cand.first;
    }
    final stato = admin && kStatiAttivi.contains(input['stato'])
        ? input['stato'] as String
        : (cfg['conferma'] == 'manuale' && !admin ? 'in_attesa' : 'confermata');
    var collNome = '';
    for (final c in jsonList(cfg['collaboratori'])) {
      if (c['id'] == coll) collNome = str(c['nome']);
    }
    final row = {
      'id': newId(),
      'data': data,
      'inizio': inizio,
      'fine': inizio + intOf(s['durata']),
      'collaboratore_id': coll,
      'servizio_id': s['id'],
      'stato': stato,
      'creato': nowMs(),
      'dati': {
        'servizio': s['nome'], 'durata': s['durata'], 'prezzo': s['prezzo'], 'collaboratore': collNome,
        'nome': nome, 'email': email, 'telefono': tel,
        'note': Repo.testoBreve(input['note'], 1000),
        'origine': admin ? 'area riservata' : 'sito',
      },
    };
    await _put('prenotazioni', _pren, row);
    return prenFormatta(row);
  }

  static Json prenFormatta(Json r) => {
        'id': r['id'],
        'data': r['data'],
        'ora': fmtHm(intOf(r['inizio'])),
        'fine': fmtHm(intOf(r['fine'])),
        'collaboratore_id': str(r['collaboratore_id']),
        'servizio_id': str(r['servizio_id']),
        'stato': r['stato'],
        'creato': intOf(r['creato']),
        ...jsonOf(r['dati']),
      };

  List<Json> prenElenco(String dal, String al) {
    final l = _pren.where((p) => str(p['data']).compareTo(dal) >= 0 && str(p['data']).compareTo(al) <= 0).toList()
      ..sort((a, b) {
        final d = str(a['data']).compareTo(str(b['data']));
        return d != 0 ? d : intOf(a['inizio']).compareTo(intOf(b['inizio']));
      });
    return l.map(prenFormatta).toList();
  }

  Json? _prenRiga(String id) {
    for (final p in _pren) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  /* ----- Gestione da parte del cliente, con il link personale (contiene l'id segreto) ----- */

  /// Il cliente può ancora modificare? Restituisce il motivo se non può.
  String _modificabile(Json cfg, Json r) {
    if (!boolOf(cfg['modificaCliente'])) return 'Per modifiche contatta direttamente la struttura.';
    if (!kStatiAttivi.contains(r['stato'])) return 'Questa prenotazione non è più modificabile.';
    final quando = parseDate(str(r['data'])).add(Duration(minutes: intOf(r['inizio'])));
    final ore = intOf(cfg['limiteModificaOre']);
    if (quando.difference(DateTime.now()).inSeconds < ore * 3600) return 'Mancano meno di $ore ore: per modifiche contatta la struttura.';
    return '';
  }

  Json prenCliente(String id) {
    _richiediModulo('prenotazioni');
    final r = _prenRiga(id);
    if (r == null) throw const AppError('Prenotazione non trovata');
    final cfg = prenConfig();
    final p = prenFormatta(r);
    final motivo = _modificabile(cfg, r);
    return {
      'id': p['id'], 'data': p['data'], 'ora': p['ora'], 'fine': p['fine'], 'stato': p['stato'],
      'servizio': str(p['servizio']), 'servizio_id': p['servizio_id'], 'collaboratore': str(p['collaboratore']), 'collaboratore_id': p['collaboratore_id'],
      'nome': str(p['nome']), 'modificabile': motivo.isEmpty, 'motivo': motivo, 'passata': str(p['data']).compareTo(oggi()) < 0,
      'limiteOre': intOf(cfg['limiteModificaOre']), 'storia': p['storia'] ?? [],
    };
  }

  Json _conStoria(Json r, String evento) {
    final d = jsonOf(r['dati']);
    d['storia'] = [...jsonList(d['storia']), {'data': nowStamp(), 'evento': evento}];
    return {...r, 'dati': d};
  }

  Future<Json> prenClienteAnnulla(String id) async {
    _limita('pren_mia');
    final r = _prenRiga(id);
    if (r == null) throw const AppError('Prenotazione non trovata');
    final motivo = _modificabile(prenConfig(), r);
    if (motivo.isNotEmpty) throw AppError(motivo);
    await _put('prenotazioni', _pren, {..._conStoria(r, 'Annullata dal cliente'), 'stato': 'annullata'});
    attAggiorna();
    return prenCliente(id);
  }

  /// Orari liberi per spostare la prenotazione (stesso servizio e stesso collaboratore).
  List<String> prenSlotSposta(String id, String data) {
    final r = _prenRiga(id);
    if (r == null) return [];
    final s = prenServizi()[str(r['servizio_id'])];
    if (s == null) return [];
    return slotLiberi(data, s, coll: str(r['collaboratore_id']), escludi: id).keys.toList();
  }

  Map<String, int> prenGiorniSposta(String id) => {
        for (var i = 0; i < 42; i++) addDays(oggi(), i): prenSlotSposta(id, addDays(oggi(), i)).length,
      };

  Future<Json> prenClienteSposta(String id, String data, String ora) async {
    _limita('pren_mia');
    final r = _prenRiga(id);
    if (r == null) throw const AppError('Prenotazione non trovata');
    final motivo = _modificabile(prenConfig(), r);
    if (motivo.isNotEmpty) throw AppError(motivo);
    final s = prenServizi()[str(r['servizio_id'])];
    if (s == null) throw const AppError('Il servizio non è più prenotabile online: contatta la struttura');
    final inizio = hm(ora);
    if (!validIsoDate(data) || inizio == null) throw const AppError('Data o orario non validi');
    if (!prenSlotSposta(id, data).contains(fmtHm(inizio))) throw const AppError('Questo orario non è più disponibile: scegline un altro');
    final vecchia = '${r['data']} ${fmtHm(intOf(r['inizio']))}';
    await _put('prenotazioni', _pren, {
      ..._conStoria(r, 'Spostata dal cliente (prima: $vecchia)'),
      'data': data,
      'inizio': inizio,
      'fine': inizio + intOf(s['durata']),
    });
    attAggiorna();
    return prenCliente(id);
  }

  /* ----- Area riservata ----- */

  Future<void> prenStato(String id, String stato) async {
    if (!['in_attesa', 'confermata', 'annullata', 'completata', 'assente'].contains(stato)) throw const AppError('Stato non valido');
    final r = _prenRiga(id);
    if (r == null) throw const AppError('Prenotazione non trovata');
    await _put('prenotazioni', _pren, {...r, 'stato': stato});
    attAggiorna(); // un posto liberato può interessare la lista d'attesa
  }

  Future<void> prenElimina(String id) async {
    await _delete('prenotazioni', _pren, id);
    attAggiorna();
  }

  int get prenDaConfermare => _pren.where((p) => p['stato'] == 'in_attesa' && str(p['data']).compareTo(oggi()) >= 0).length;

  /* ----- Lista d'attesa ----- */

  static bool _fasciaOk(String ora, String fascia) => switch (fascia) {
        'mattina' => ora.compareTo('12:00') < 0,
        'pomeriggio' => ora.compareTo('12:00') >= 0 && ora.compareTo('18:00') < 0,
        'sera' => ora.compareTo('18:00') >= 0,
        _ => true,
      };

  Future<void> attCrea(Json input) async {
    _richiediModulo('prenotazioni');
    final cfg = prenConfig();
    if (!boolOf(cfg['listaAttesa'])) throw const AppError("Lista d'attesa non disponibile");
    final s = prenServizi(cfg)[str(input['servizio'])];
    if (s == null) throw const AppError('Servizio non disponibile');
    final data = str(input['data']);
    if (!validIsoDate(data) || data.compareTo(oggi()) < 0 || data.compareTo(addDays(oggi(), intOf(cfg['anticipo']))) > 0) throw const AppError('Data non valida');
    final fascia = ['mattina', 'pomeriggio', 'sera'].contains(input['fascia']) ? input['fascia'] as String : 'qualsiasi';
    final c = Repo.contattoCliente(input, telObbligatorio: true);
    _limita('att');
    await _put('attesa', _att, {
      'id': newId(),
      'servizio_id': s['id'],
      'collaboratore_id': Repo._cleanId(input['collaboratore']) ?? '',
      'data': data,
      'stato': 'in_attesa',
      'creato': nowMs(),
      'dati': {...c, 'servizio': s['nome'], 'fascia': fascia, 'note': Repo.testoBreve(input['note'], 500)},
    });
    attAggiorna();
  }

  /// Ricontrolla la lista d'attesa: segna "posto libero" chi ora trova un orario adatto.
  void attAggiorna() {
    final cfg = prenConfig();
    final servizi = prenServizi(cfg);
    final oggiS = oggi();
    for (var i = 0; i < _att.length; i++) {
      final r = _att[i];
      if (!['in_attesa', 'posto_libero'].contains(r['stato'])) continue;
      Json nuovo;
      if (str(r['data']).compareTo(oggiS) < 0) {
        nuovo = {...r, 'stato': 'scaduta'};
      } else {
        final s = servizi[str(r['servizio_id'])];
        if (s == null) continue;
        final d = jsonOf(r['dati']);
        final ore = slotLiberi(str(r['data']), s, coll: str(r['collaboratore_id']), cfg: cfg).keys.where((o) => _fasciaOk(o, str(d['fascia']))).toList();
        d['orariLiberi'] = ore.take(8).toList();
        nuovo = {...r, 'stato': ore.isNotEmpty ? 'posto_libero' : 'in_attesa', 'dati': d};
      }
      if (jsonEncode(nuovo) != jsonEncode(r)) {
        _att[i] = nuovo;
        _s.put('attesa', r['id'] as String, nuovo);
      }
    }
  }

  List<Json> attElenco() {
    attAggiorna();
    final l = [..._att]..sort((a, b) {
        final d = str(a['data']).compareTo(str(b['data']));
        return d != 0 ? d : intOf(a['creato']).compareTo(intOf(b['creato']));
      });
    return [
      for (final r in l)
        {'id': r['id'], 'data': r['data'], 'stato': r['stato'], 'servizio_id': r['servizio_id'], 'collaboratore_id': r['collaboratore_id'], 'creato': r['creato'], ...jsonOf(r['dati'])}
    ];
  }

  Future<void> attStato(String id, String stato) async {
    if (!['avvisato', 'prenotato', 'chiusa', 'in_attesa'].contains(stato)) throw const AppError('Stato non valido');
    final r = _att.where((a) => a['id'] == id).firstOrNull;
    if (r == null) return;
    await _put('attesa', _att, {...r, 'stato': stato});
  }

  Future<void> attElimina(String id) => _delete('attesa', _att, id);
}
