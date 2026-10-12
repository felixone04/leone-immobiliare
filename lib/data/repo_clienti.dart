part of 'repository.dart';

/*
 * FUNZIONI PER I CLIENTI
 *  - Messaggi dal modulo contatti
 *  - Recensioni con moderazione
 */

extension RepoClienti on Repo {
  /* ================= Messaggi ================= */

  Future<void> richiestaCrea(Json input) async {
    final c = Repo.contattoCliente(input, emailObbligatoria: true);
    final msg = Repo.testoBreve(input['messaggio'], 3000);
    if (msg.length < 5) throw const AppError('Scrivi il messaggio');
    _limita('msg');
    final immobile = Repo._cleanId(input['immobile']) ?? '';
    final dati = {
      ...c,
      'messaggio': msg,
      'oggetto': Repo.testoBreve(input['oggetto'], 200),
      'pagina': Repo.testoBreve(input['pagina'], 200),
      if (item(immobile) != null) 'immobile': immobile,
    };
    await _put('richieste', _rich, {'id': newId(), 'stato': 'nuova', 'creato': nowMs(), 'dati': dati});
    await _avvisoMessaggio(dati, immobile);
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
