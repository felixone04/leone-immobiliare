part of 'repository.dart';

/*
 * GIFT CARD
 * Disponibili con il modulo prenotazioni attivo; l'azienda le attiva dalla propria area riservata.
 * Due tipi: "importo" (valore scelto dal cliente, >= minimo) e "proposta" (trattamento/prodotto).
 * Importi salvati in centesimi. Pagamento SOLO in struttura: la carta nasce "da pagare".
 * Stati: da_pagare → attiva → utilizzata (oppure annullata / scaduta)
 */

extension RepoGiftcard on Repo {
  static Json gcDefault() => {
        'attiva': false,
        'libero': true,
        'minimo': 20,
        'massimo': 1000,
        'suggeriti': [25, 50, 100, 150],
        'catalogo': [],
        'proposte': [],
        'validitaMesi': 12,
        'pagamento': 'Il pagamento si effettua in struttura: presenta il codice alla cassa e la gift card verrà attivata.',
        'titolo': 'Regala un momento speciale',
        'testo': 'Scegli un importo o uno dei nostri trattamenti: prepariamo una gift card personalizzata con la tua dedica.',
      };

  Json gcConfig() {
    final c = {...gcDefault(), ...cloneJson(_cfg['giftcard'] ?? {})};
    c['minimo'] = doubleOf(c['minimo']) < 1 ? 1.0 : doubleOf(c['minimo']);
    c['massimo'] = doubleOf(c['massimo']) < 0 ? 0.0 : doubleOf(c['massimo']);
    c['validitaMesi'] = intOf(c['validitaMesi'], 12).clamp(1, 60);
    c['suggeriti'] = [for (final v in (c['suggeriti'] is List ? c['suggeriti'] as List : const [])) if (doubleOf(v) > 0) doubleOf(v)];
    return c;
  }

  bool get gcAttive => (_moduli['prenotazioni'] ?? false) && boolOf((_cfg['giftcard'] ?? const {})['attiva']);

  /// Proposte regalabili: voci del catalogo scelte + proposte extra.
  Map<String, Json> gcProposte([Json? cfg]) {
    cfg ??= gcConfig();
    final out = <String, Json>{};
    final ids = strList(cfg['catalogo']);
    for (final d in items) {
      if (!ids.contains(d['id'])) continue;
      final prezzo = numOrNull(d['prezzo']);
      if (prezzo == null || prezzo <= 0) continue;
      out[d['id'] as String] = {
        'id': d['id'], 'nome': str(d['titolo']), 'prezzo': prezzo.toDouble(),
        'descrizione': cut(str(d['descrizione']).replaceAll(RegExp(r'[*#]'), ''), 200), 'immagine': strList(d['foto']).firstOrNull ?? '',
      };
    }
    for (final p in jsonList(cfg['proposte'])) {
      final prezzo = numOrNull(p['prezzo']);
      if (str(p['id']).isEmpty || str(p['nome']).trim().isEmpty || prezzo == null || prezzo <= 0) continue;
      final id = 'x-${p['id']}';
      out[id] = {'id': id, 'nome': str(p['nome']), 'prezzo': prezzo.toDouble(), 'descrizione': str(p['descrizione']), 'immagine': str(p['immagine'])};
    }
    return out;
  }

  Json gcPubblico() {
    final c = gcConfig();
    return {
      'libero': boolOf(c['libero']), 'minimo': c['minimo'], 'massimo': c['massimo'], 'suggeriti': c['suggeriti'],
      'proposte': gcProposte(c).values.toList(), 'validitaMesi': c['validitaMesi'], 'pagamento': str(c['pagamento']),
      'titolo': str(c['titolo']), 'testo': str(c['testo']),
    };
  }

  /// Crea una gift card. [admin] = venduta in sede: può nascere già attiva.
  Future<Json> gcCrea(Json input, {bool admin = false}) async {
    if (!admin && !gcAttive) throw const AppError('Gift card non disponibili');
    if (admin && !modulo('prenotazioni')) throw const AppError('Le gift card sono disponibili solo con le prenotazioni attive');
    final cfg = gcConfig();
    final tipo = input['tipo'] == 'proposta' ? 'proposta' : 'importo';
    Json? proposta;
    double euroV;
    if (tipo == 'importo') {
      if (!boolOf(cfg['libero']) && !admin) throw const AppError('Importo libero non disponibile: scegli una proposta');
      euroV = (doubleOf(input['importo']) * 100).round() / 100;
      if (!(euroV > 0)) throw const AppError("L'importo deve essere maggiore di zero");
      if (euroV < doubleOf(cfg['minimo'])) throw AppError("L'importo minimo è ${euro(cfg['minimo'])}");
      if (doubleOf(cfg['massimo']) > 0 && euroV > doubleOf(cfg['massimo']) && !admin) throw AppError("L'importo massimo è ${euro(cfg['massimo'])}");
    } else {
      proposta = gcProposte(cfg)[str(input['proposta'])];
      if (proposta == null) throw const AppError('Proposta non disponibile');
      euroV = doubleOf(proposta['prezzo']);
    }
    final nome = str(input['nome']).trim(), email = str(input['email']).trim(), tel = str(input['telefono']).trim();
    if (nome.isEmpty || nome.length > 120) throw const AppError('Inserisci il tuo nome e cognome');
    if (!admin && !validEmail(email)) throw const AppError('Inserisci un indirizzo email valido');
    if (!admin && !validPhone(tel)) throw const AppError('Inserisci un numero di telefono valido');
    if (!admin) _limita('gc', max: 5);
    final cent = (euroV * 100).round();
    final stato = admin && input['stato'] == 'attiva' ? 'attiva' : 'da_pagare';
    final row = {
      'id': newId(),
      'codice': _codiceUnico('GC', _gift),
      'tipo': tipo,
      'valore': cent,
      'saldo': cent,
      'stato': stato,
      'scadenza': isoDate(addMonths(DateTime.now(), intOf(cfg['validitaMesi'], 12))),
      'creato': nowMs(),
      'dati': {
        'proposta': proposta?['nome'] ?? '', 'propostaId': proposta?['id'] ?? '',
        'nome': nome, 'email': email, 'telefono': tel,
        'destinatario': Repo.testoBreve(input['destinatario'], 120),
        'messaggio': Repo.testoBreve(input['messaggio'], 400),
        'origine': admin ? 'area riservata' : 'sito',
        'movimenti': stato == 'attiva' ? [{'data': nowStamp(), 'tipo': 'attivazione', 'nota': 'Venduta in sede'}] : [],
      },
    };
    await _put('giftcard', _gift, row);
    return gcFormatta(row, completo: true);
  }

  Json gcFormatta(Json r, {bool completo = false}) {
    final d = jsonOf(r['dati']);
    var stato = str(r['stato']);
    if (['attiva', 'da_pagare'].contains(stato) && str(r['scadenza']).compareTo(oggi()) < 0) stato = 'scaduta';
    return {
      'id': r['id'], 'codice': r['codice'], 'tipo': r['tipo'], 'valore': intOf(r['valore']) / 100, 'saldo': intOf(r['saldo']) / 100,
      'stato': stato, 'scadenza': str(r['scadenza']), 'creato': intOf(r['creato']),
      'proposta': str(d['proposta']), 'destinatario': str(d['destinatario']), 'messaggio': str(d['messaggio']), 'daParte': str(d['nome']),
      if (completo) ...{'nome': str(d['nome']), 'email': str(d['email']), 'telefono': str(d['telefono']), 'origine': str(d['origine']), 'movimenti': d['movimenti'] ?? []},
    };
  }

  Json gcVedi(String codice) {
    if (!gcAttive) throw const AppError('Gift card non disponibili');
    final r = _gift.where((g) => g['codice'] == codice.trim().toUpperCase()).firstOrNull;
    if (r == null) throw const AppError('Gift card non trovata');
    return gcFormatta(r);
  }

  List<Json> gcLista(String cerca) {
    final q = cerca.trim().toUpperCase();
    final l = [..._gift]..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
    return [
      for (final r in l)
        if (q.isEmpty || () {
          final g = gcFormatta(r, completo: true);
          return '${g['codice']} ${g['nome']} ${g['destinatario']} ${g['email']}'.toUpperCase().contains(q);
        }())
          gcFormatta(r, completo: true)
    ];
  }

  Json _gcRiga(String id) {
    final r = _gift.where((g) => g['id'] == id).firstOrNull;
    if (r == null) throw const AppError('Gift card non trovata');
    return r;
  }

  Future<Json> _gcAggiorna(Json r, String stato, int saldo, Json mov) async {
    final d = jsonOf(r['dati']);
    d['movimenti'] = [...jsonList(d['movimenti']), {...mov, 'data': nowStamp()}];
    final row = {...r, 'stato': stato, 'saldo': saldo, 'dati': d};
    await _put('giftcard', _gift, row);
    return gcFormatta(row, completo: true);
  }

  Future<Json> gcPaga(String id) {
    final r = _gcRiga(id);
    if (r['stato'] != 'da_pagare') throw const AppError('Questa gift card non è in attesa di pagamento');
    return _gcAggiorna(r, 'attiva', intOf(r['saldo']), {'tipo': 'pagamento', 'nota': 'Pagata in struttura'});
  }

  Future<Json> gcAnnulla(String id, [String nota = '']) {
    final r = _gcRiga(id);
    return _gcAggiorna(r, 'annullata', intOf(r['saldo']), {'tipo': 'annullamento', 'nota': Repo.testoBreve(nota, 200)});
  }

  /// Scala un importo (o tutto il saldo per le proposte).
  Future<Json> gcUsa(String id, {Object? importo, bool tutto = false, String nota = ''}) {
    final r = _gcRiga(id);
    final g = gcFormatta(r);
    if (g['stato'] != 'attiva') {
      throw AppError(g['stato'] == 'da_pagare' ? 'La gift card non è ancora stata pagata' : 'La gift card non è utilizzabile (${g['stato']})');
    }
    final saldoC = intOf(r['saldo']);
    final cent = r['tipo'] == 'proposta' || tutto ? saldoC : (doubleOf(importo) * 100).round();
    if (cent <= 0) throw const AppError('Indica un importo maggiore di zero');
    if (cent > saldoC) throw AppError("L'importo supera il saldo disponibile (${euro(saldoC / 100)})");
    final nuovo = saldoC - cent;
    return _gcAggiorna(r, nuovo == 0 ? 'utilizzata' : 'attiva', nuovo, {'tipo': 'utilizzo', 'importo': cent / 100, 'nota': Repo.testoBreve(nota, 200)});
  }

  Future<Json> gcSaveConfig(Json c) async {
    if (!modulo('prenotazioni')) throw const AppError('Le gift card sono disponibili solo nei siti con le prenotazioni attive');
    final def = gcDefault();
    final out = {for (final e in c.entries) if (def.containsKey(e.key)) e.key: e.value};
    out['proposte'] = Repo.conId(jsonList(out['proposte']));
    if (out.containsKey('minimo') && doubleOf(out['minimo']) <= 0) throw const AppError("L'importo minimo deve essere maggiore di zero");
    await _setCfg('giftcard', out);
    return gcConfig();
  }

  /// Voci del catalogo con un prezzo, tra cui scegliere quelle regalabili.
  List<Opt> get gcVoci {
    final l = [...items]..sort((a, b) => str(a['titolo']).compareTo(str(b['titolo'])));
    return [
      for (final d in l)
        if ((numOrNull(d['prezzo']) ?? 0) > 0) Opt(d['id'] as String, '${d['titolo']} — ${fmtPrice(numOrNull(d['prezzo'])!)}')
    ];
  }
}
