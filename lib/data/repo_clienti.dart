part of 'repository.dart';

/*
 * FUNZIONI PER I CLIENTI (nessun pagamento online: si paga sempre in struttura)
 *  - Messaggi dal modulo contatti
 *  - Carte con codice: tessera fedeltà, pacchetti a sedute, coupon delle offerte
 *  - Offerte a tempo
 *  - Recensioni con moderazione
 */

const kPrefissi = {'fedelta': 'FD', 'pacchetto': 'PK', 'coupon': 'CP'};

extension RepoClienti on Repo {
  /* ================= Messaggi ================= */

  Future<void> richiestaCrea(Json input) async {
    final c = Repo.contattoCliente(input, emailObbligatoria: true);
    final msg = Repo.testoBreve(input['messaggio'], 3000);
    if (msg.length < 5) throw const AppError('Scrivi il messaggio');
    _limita('msg');
    await _put('richieste', _rich, {
      'id': newId(),
      'stato': 'nuova',
      'creato': nowMs(),
      'dati': {...c, 'messaggio': msg, 'oggetto': Repo.testoBreve(input['oggetto'], 200), 'pagina': Repo.testoBreve(input['pagina'], 200)},
    });
  }

  List<Json> richElenco() {
    final l = [..._rich]..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
    return [for (final r in l) {'id': r['id'], 'stato': r['stato'], 'creato': intOf(r['creato']), ...jsonOf(r['dati'])}];
  }

  Future<void> richStato(String id, String stato) async {
    if (!['nuova', 'letta', 'risposta', 'archiviata'].contains(stato)) throw const AppError('Stato non valido');
    final r = _rich.where((x) => x['id'] == id).firstOrNull;
    if (r != null) await _put('richieste', _rich, {...r, 'stato': stato});
  }

  Future<void> richElimina(String id) => _delete('richieste', _rich, id);

  /* ================= Carte con codice ================= */

  String _codiceUnico(String prefisso, Iterable<Json> esistenti) {
    String c;
    do {
      c = readableCode(prefisso);
    } while (esistenti.any((t) => t['codice'] == c));
    return c;
  }

  /// Offerte in corso (con i codici generici solo se richiesto, per l'area riservata).
  List<Json> offerteAttive({bool conCodici = false}) {
    final oggiS = oggi();
    final out = <Json>[];
    for (final o in jsonList(cfgModulo('offerte')['offerte'])) {
      if (str(o['id']).isEmpty || !boolOf(o['attiva']) || str(o['titolo']).trim().isEmpty) continue;
      if (str(o['dal']).isNotEmpty && str(o['dal']).compareTo(oggiS) > 0) continue;
      if (str(o['al']).isNotEmpty && str(o['al']).compareTo(oggiS) < 0) continue;
      final limite = intOf(o['limite']);
      final usati = limite > 0 ? _tess.where((t) => t['tipo'] == 'coupon' && t['rif'] == o['id'] && t['stato'] != 'annullata').length : 0;
      final pub = <String, dynamic>{
        'id': o['id'], 'titolo': str(o['titolo']), 'descrizione': str(o['descrizione']), 'sconto': str(o['sconto']),
        'dal': str(o['dal']), 'al': str(o['al']), 'immagine': str(o['immagine']), 'countdown': boolOf(o['countdown']),
        'personale': boolOf(o['personale']), 'rimasti': limite > 0 ? (limite - usati).clamp(0, limite) : null,
      };
      // il codice generico si mostra solo per le offerte non "personali"
      if (!boolOf(o['personale']) || conCodici) pub['codice'] = str(o['codice']).toUpperCase();
      out.add(pub);
    }
    return out;
  }

  Future<Json> tesseraCrea(String tipo, Json input, {bool admin = false}) async {
    if (!kPrefissi.containsKey(tipo)) throw const AppError('Tipo non valido');
    var valore = 0, saldo = 0;
    var stato = 'attiva', scadenza = '', rif = '';
    var extra = <String, dynamic>{};
    Json c;
    if (tipo == 'fedelta') {
      _richiediModulo('fedelta');
      if (!admin && !boolOf(cfgModulo('fedelta')['richiestaOnline'])) throw const AppError('La tessera si richiede in struttura');
      c = Repo.contattoCliente(input, telObbligatorio: true);
      final tel = onlyDigits(str(c['telefono']));
      for (final r in _tess) {
        if (r['tipo'] == 'fedelta' && r['stato'] == 'attiva' && onlyDigits(str(jsonOf(r['dati'])['telefono'])) == tel) {
          throw const AppError('Esiste già una tessera con questo numero di telefono: chiedila in struttura');
        }
      }
    } else if (tipo == 'pacchetto') {
      _richiediModulo('pacchetti');
      c = Repo.contattoCliente(input, emailObbligatoria: !admin, telObbligatorio: !admin);
      final p = jsonList(cfgModulo('pacchetti')['pacchetti']).where((x) => x['id'] == input['pacchetto']).firstOrNull;
      if (p == null || intOf(p['sedute']) < 1) throw const AppError('Pacchetto non disponibile');
      valore = saldo = intOf(p['sedute']);
      stato = admin && boolOf(input['pagato']) ? 'attiva' : 'da_pagare';
      scadenza = isoDate(addMonths(DateTime.now(), intOf(p['validitaMesi'], 12).clamp(1, 600)));
      rif = str(p['id']);
      extra = {'nomePacchetto': str(p['nome']), 'prezzo': doubleOf(p['prezzo'])};
    } else {
      _richiediModulo('offerte');
      c = Repo.contattoCliente(input);
      final o = offerteAttive(conCodici: true).where((x) => x['id'] == input['offerta']).firstOrNull;
      if (o == null || o['personale'] != true) throw const AppError('Offerta non disponibile');
      if (o['rimasti'] != null && intOf(o['rimasti']) < 1) throw const AppError('I coupon di questa offerta sono esauriti');
      valore = saldo = 1;
      scadenza = str(o['al']);
      rif = str(o['id']);
      extra = {'offerta': o['titolo'], 'sconto': o['sconto']};
    }
    if (!admin) _limita('tess_$tipo');
    final row = {
      'id': newId(),
      'tipo': tipo,
      'codice': _codiceUnico(kPrefissi[tipo]!, _tess),
      'valore': valore,
      'saldo': saldo,
      'stato': stato,
      'scadenza': scadenza,
      'rif': rif,
      'creato': nowMs(),
      'dati': {...c, ...extra, 'origine': admin ? 'area riservata' : 'sito', 'premi': 0, 'movimenti': []},
    };
    await _put('tessere', _tess, row);
    return tesseraFormatta(row, completo: true);
  }

  Json? _tessera(String campo, String v) => _tess.where((t) => t[campo] == v).firstOrNull;

  Json tesseraFormatta(Json r, {bool completo = false}) {
    final d = jsonOf(r['dati']);
    var stato = str(r['stato']);
    if (str(r['scadenza']).isNotEmpty && str(r['scadenza']).compareTo(oggi()) < 0 && ['attiva', 'da_pagare'].contains(stato)) stato = 'scaduta';
    final out = <String, dynamic>{
      'id': r['id'], 'tipo': r['tipo'], 'codice': r['codice'], 'valore': intOf(r['valore']), 'saldo': intOf(r['saldo']), 'stato': stato,
      'scadenza': str(r['scadenza']), 'creato': intOf(r['creato']), 'nome': str(d['nome']), 'premi': intOf(d['premi']),
      'nomePacchetto': str(d['nomePacchetto']), 'offerta': str(d['offerta']), 'sconto': str(d['sconto']),
    };
    if (completo) {
      out.addAll({'email': str(d['email']), 'telefono': str(d['telefono']), 'prezzo': d['prezzo'], 'origine': str(d['origine']), 'movimenti': d['movimenti'] ?? []});
    }
    if (r['tipo'] == 'fedelta') {
      final f = cfgModulo('fedelta');
      out.addAll({'obiettivo': intOf(f['obiettivo']), 'unita': str(f['unita']), 'premio': str(f['premio'])});
    }
    return out;
  }

  /// Carta visibile al cliente dal suo codice.
  Json cartaVedi(String codice) {
    final r = _tessera('codice', codice.trim().toUpperCase());
    if (r == null) throw const AppError('Codice non trovato');
    return tesseraFormatta(r);
  }

  /// Operazioni in cassa sulle carte.
  Future<Json> tesseraAzione(String id, String azione, {int n = 1, String nota = ''}) async {
    final r = _tessera('id', id);
    if (r == null) throw const AppError('Carta non trovata');
    final t = tesseraFormatta(r);
    final d = jsonOf(r['dati']);
    var saldo = intOf(r['saldo']);
    var stato = str(r['stato']);
    final mov = <String, dynamic>{'data': nowStamp(), 'tipo': azione, 'nota': Repo.testoBreve(nota, 200)};
    if (azione == 'annulla') {
      stato = 'annullata';
    } else if (t['stato'] == 'scaduta') {
      throw const AppError('Questa carta è scaduta');
    } else if (t['stato'] == 'annullata') {
      throw const AppError('Questa carta è annullata');
    } else if (r['tipo'] == 'fedelta') {
      final obiettivo = intOf(cfgModulo('fedelta')['obiettivo'], 1).clamp(1, 100000);
      if (azione == 'aggiungi') {
        if (n < 1 || n > 100) throw const AppError('Quantità non valida');
        saldo += n;
        mov['quantita'] = n;
      } else if (azione == 'togli') {
        if (n < 1 || n > saldo) throw const AppError('Quantità non valida');
        saldo -= n;
        mov['quantita'] = -n;
      } else if (azione == 'riscatta') {
        if (saldo < obiettivo) throw const AppError('Obiettivo non ancora raggiunto');
        saldo -= obiettivo;
        d['premi'] = intOf(d['premi']) + 1;
      } else {
        throw const AppError('Operazione non valida');
      }
    } else if (r['tipo'] == 'pacchetto') {
      if (azione == 'paga') {
        if (stato != 'da_pagare') throw const AppError('Il pacchetto non è in attesa di pagamento');
        stato = 'attiva';
      } else if (azione == 'usa') {
        if (stato == 'da_pagare') throw const AppError('Il pacchetto non è ancora stato pagato');
        if (saldo < 1) throw const AppError('Sedute esaurite');
        saldo--;
        if (saldo == 0) stato = 'utilizzata';
      } else {
        throw const AppError('Operazione non valida');
      }
    } else {
      if (azione != 'usa' || stato != 'attiva') throw const AppError('Coupon già utilizzato o non valido');
      saldo = 0;
      stato = 'utilizzata';
    }
    d['movimenti'] = [...jsonList(d['movimenti']), mov];
    final row = {...r, 'saldo': saldo, 'stato': stato, 'dati': d};
    await _put('tessere', _tess, row);
    return tesseraFormatta(row, completo: true);
  }

  List<Json> tessLista(String tipo, String cerca) {
    final q = cerca.trim().toUpperCase();
    final l = _tess.where((t) => t['tipo'] == tipo).toList()..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
    return [
      for (final r in l)
        if (q.isEmpty || () {
          final x = tesseraFormatta(r, completo: true);
          return '${x['codice']} ${x['nome']} ${x['telefono']} ${x['email']}'.toUpperCase().contains(q);
        }())
          tesseraFormatta(r, completo: true)
    ];
  }

  /// Cerca un codice qualsiasi: gift card, tessera fedeltà, pacchetto o coupon.
  (String, Json) cassa(String codice) {
    final cod = codice.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cod.isEmpty) throw const AppError('Inserisci un codice');
    final g = _gift.where((x) => x['codice'] == cod).firstOrNull;
    if (g != null) return ('giftcard', gcFormatta(g, completo: true));
    final t = _tessera('codice', cod);
    if (t != null) return (t['tipo'] as String, tesseraFormatta(t, completo: true));
    throw AppError('Nessuna carta trovata con il codice $cod');
  }

  /* ================= Recensioni ================= */

  Future<Json> recCrea(Json input) async {
    _richiediModulo('recensioni');
    final cfg = cfgModulo('recensioni');
    final voto = intOf(input['voto']);
    if (voto < 1 || voto > 5) throw const AppError('Scegli da 1 a 5 stelle');
    final testo = Repo.testoBreve(input['testo'], 2000);
    if (testo.length < 10) throw const AppError('Scrivi qualche parola in più (almeno 10 caratteri)');
    final nome = Repo.testoBreve(input['nome'], 80);
    if (nome.isEmpty) throw const AppError('Inserisci il tuo nome');
    var verificata = false;
    var servizio = '';
    final pid = Repo._cleanId(input['prenotazione']) ?? '';
    if (pid.isNotEmpty) {
      final p = _prenRiga(pid);
      if (p == null || ['annullata', 'assente'].contains(p['stato']) || str(p['data']).compareTo(oggi()) > 0) {
        throw const AppError("Potrai lasciare la recensione dopo l'appuntamento");
      }
      if (_rec.any((r) => r['prenotazione'] == pid)) throw const AppError('Hai già lasciato una recensione per questo appuntamento. Grazie!');
      verificata = true;
      servizio = str(jsonOf(p['dati'])['servizio']);
    } else if (!boolOf(cfg['aperte'])) {
      throw const AppError('Le recensioni si possono lasciare solo dopo un appuntamento');
    }
    _limita('rec');
    final stato = cfg['approvazione'] == 'automatica' ? 'pubblicata' : 'in_attesa';
    await _put('recensioni', _rec, {
      'id': newId(), 'voto': voto, 'stato': stato, 'creato': nowMs(),
      'nome': nome, 'testo': testo, 'email': Repo.testoBreve(input['email'], 160), 'prenotazione': pid, 'servizio': servizio, 'verificata': verificata, 'risposta': '',
    });
    return {'stato': stato, 'google': str(cfg['googleUrl'])};
  }

  List<Json> recElenco({bool soloPubblicate = true}) {
    final l = _rec.where((r) => !soloPubblicate || r['stato'] == 'pubblicata').toList()..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
    return [
      for (final r in l)
        {
          'id': r['id'], 'voto': intOf(r['voto']), 'stato': r['stato'], 'creato': intOf(r['creato']), 'nome': str(r['nome']), 'testo': str(r['testo']),
          'risposta': str(r['risposta']), 'verificata': boolOf(r['verificata']), 'servizio': str(r['servizio']),
          if (!soloPubblicate) 'email': str(r['email']),
        }
    ];
  }

  Json recInfo() {
    final l = recElenco();
    final cfg = cfgModulo('recensioni');
    final media = l.isEmpty ? 0.0 : (l.fold<int>(0, (s, r) => s + intOf(r['voto'])) / l.length * 10).round() / 10;
    return {'recensioni': l, 'media': media, 'totale': l.length, 'aperte': boolOf(cfg['aperte']), 'google': str(cfg['googleUrl'])};
  }

  Future<void> recStato(String id, String stato) async {
    if (!['pubblicata', 'rifiutata', 'in_attesa'].contains(stato)) throw const AppError('Stato non valido');
    final r = _rec.where((x) => x['id'] == id).firstOrNull;
    if (r != null) await _put('recensioni', _rec, {...r, 'stato': stato});
  }

  Future<void> recRisposta(String id, String risposta) async {
    final r = _rec.where((x) => x['id'] == id).firstOrNull;
    if (r == null) throw const AppError('Recensione non trovata');
    await _put('recensioni', _rec, {...r, 'risposta': Repo.testoBreve(risposta, 1500)});
  }

  Future<void> recElimina(String id) => _delete('recensioni', _rec, id);
}
