part of 'repository.dart';

/*
 * ACCOUNT DEI CLIENTI
 *  - registrazione e accesso (la password è salvata solo come impronta PBKDF2), uscita, cancellazione
 *  - immobili preferiti
 *  - ricerche salvate ("la casa che cerco"): quando un immobile disponibile corrisponde,
 *    il cliente riceve una notifica nel suo account e un'email con il link all'annuncio
 *  - consenso facoltativo a ricevere via email nuovi immobili e offerte
 * Senza server i dati restano in questo browser; le email vanno nella posta in uscita dell'agenzia.
 */

const kMaxRicerche = 10;

extension RepoAccount on Repo {
  /* ================= Accesso ================= */

  /// Cliente collegato in questo browser (null se nessuno).
  Json? get cliente => _sessione == null ? null : _clienti.where((c) => c['id'] == _sessione).firstOrNull;

  Json? _clientePerEmail(String email) => _clienti.where((c) => c['email'] == email.trim().toLowerCase()).firstOrNull;

  static void _passwordOk(String p) {
    if (p.length < 8) throw const AppError('La password deve avere almeno 8 caratteri');
    if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) throw const AppError('La password deve contenere lettere e numeri');
  }

  Future<void> clienteRegistra(Json input) async {
    final c = Repo.contattoCliente(input, emailObbligatoria: true);
    final email = str(c['email']).toLowerCase();
    final password = str(input['password']);
    _passwordOk(password);
    if (_clientePerEmail(email) != null) throw const AppError('Esiste già un account con questa email: accedi');
    _limita('registrazione', max: 5);
    final id = newId();
    await _put('clienti', _clienti, {
      'id': id,
      ...c,
      'email': email,
      'password': await AuthService.hashPassword(password),
      'consenso': boolOf(input['consenso']),
      'creato': nowMs(),
      'preferiti': <String>[],
      'ricerche': <Json>[],
      'notifiche': <Json>[],
      'avvisati': <String>[],
    });
    await _entraCliente(id);
  }

  Future<void> clienteAccedi(String email, String password) async {
    _limita('accesso_cliente', max: 10);
    final c = _clientePerEmail(email);
    if (c == null || !await AuthService.verificaPassword(password, jsonOf(c['password']))) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      throw const AppError('Email o password non corretti');
    }
    await _entraCliente(c['id'] as String);
  }

  Future<void> _entraCliente(String id) async {
    _sessione = id;
    await _s.set('sessioneCliente', id);
    _changed();
  }

  Future<void> clienteEsci() async {
    _sessione = null;
    await _s.remove('sessioneCliente');
    _changed();
  }

  Json _io() {
    final c = cliente;
    if (c == null) throw const AppError('Accedi o crea un account per continuare');
    return c;
  }

  Future<void> _salvaCliente(Json c) => _put('clienti', _clienti, c);

  Future<void> clienteAggiorna(Json input) async {
    final c = _io();
    final dati = Repo.contattoCliente({...input, 'email': c['email']}, emailObbligatoria: true);
    await _salvaCliente({...c, 'nome': dati['nome'], 'telefono': dati['telefono'], 'consenso': boolOf(input['consenso'])});
  }

  Future<void> clienteCambiaPassword(String attuale, String nuova) async {
    final c = _io();
    if (!await AuthService.verificaPassword(attuale, jsonOf(c['password']))) throw const AppError('La password attuale non è corretta');
    _passwordOk(nuova);
    await _salvaCliente({...c, 'password': await AuthService.hashPassword(nuova)});
  }

  /// Cancellazione dell'account da parte del cliente (diritto all'oblio) o dall'area riservata.
  Future<void> clienteElimina([String? id]) async {
    final c = id == null ? _io() : _clienti.where((x) => x['id'] == id).firstOrNull;
    if (c == null) return;
    if (c['id'] == _sessione) await clienteEsci();
    await _delete('clienti', _clienti, c['id'] as String);
  }

  /* ================= Preferiti ================= */

  bool preferito(String itemId) => strList(cliente?['preferiti']).contains(itemId);

  /// Aggiunge o toglie un immobile dai preferiti; restituisce true se ora è tra i preferiti.
  Future<bool> preferitoCambia(String itemId) async {
    final c = _io();
    final l = strList(c['preferiti']);
    final ora = !l.contains(itemId);
    ora ? l.insert(0, itemId) : l.remove(itemId);
    await _salvaCliente({...c, 'preferiti': l});
    return ora;
  }

  /// Immobili preferiti ancora presenti nel catalogo (anche se nel frattempo venduti: il cliente lo vede).
  List<Json> preferitiDi(Json c) => [for (final id in strList(c['preferiti'])) ?item(id)];

  /* ================= Ricerche salvate ================= */

  List<Json> ricercheDi(Json c) => jsonList(c['ricerche']);

  /// Crea o modifica una ricerca. Gli immobili che corrispondono già vengono mostrati subito
  /// nell'account (senza email): l'email arriva solo per quelli che diventano disponibili dopo.
  Future<Json> ricercaSalva(Json criteri, {String? id, String nome = ''}) async {
    final c = _io();
    final ricerche = ricercheDi(c);
    final pulito = _criteriPuliti(criteri);
    if (str(pulito['contratto']).isEmpty) throw const AppError('Scegli se cerchi in vendita o in affitto');
    final esistente = id == null ? null : ricerche.where((r) => r['id'] == id).firstOrNull;
    if (esistente == null && ricerche.length >= kMaxRicerche) throw const AppError('Puoi salvare al massimo $kMaxRicerche ricerche');
    final r = {
      'id': esistente?['id'] ?? newId(5),
      'nome': Repo.testoBreve(nome, 80).isEmpty ? descriviCriteri(pulito) : Repo.testoBreve(nome, 80),
      'criteri': pulito,
      'creato': esistente?['creato'] ?? nowMs(),
    };
    final avvisati = strList(c['avvisati']);
    for (final (i, _) in abbinamentiPer(pulito)) {
      final k = '${r['id']}:${i['id']}';
      if (!avvisati.contains(k)) avvisati.add(k);
    }
    await _salvaCliente({
      ...c,
      'ricerche': esistente == null ? [...ricerche, r] : [for (final x in ricerche) x['id'] == r['id'] ? r : x],
      'avvisati': avvisati,
    });
    return r;
  }

  Future<void> ricercaElimina(String id) async {
    final c = _io();
    await _salvaCliente({
      ...c,
      'ricerche': ricercheDi(c).where((r) => r['id'] != id).toList(),
      'avvisati': strList(c['avvisati']).where((k) => !k.startsWith('$id:')).toList(),
    });
  }

  static Json _criteriPuliti(Json c) => {
        'contratto': ['Vendita', 'Affitto'].contains(c['contratto']) ? c['contratto'] : '',
        for (final k in ['budget', 'mqMin', 'localiMin', 'camereMin', 'bagniMin'])
          if ((numOrNull(c[k]) ?? 0) > 0) k: numOrNull(c[k]),
        for (final k in ['tipologie', 'citta', 'esterno', 'dotazioni', 'condizioni'])
          if (strList(c[k]).isNotEmpty) k: strList(c[k]),
        if (str(c['zona']).trim().isNotEmpty) 'zona': Repo.testoBreve(c['zona'], 120),
        if (boolOf(c['parcheggio'])) 'parcheggio': true,
      };

  /// Immobili disponibili che corrispondono ai criteri, dal più adatto.
  List<(Json, Abbinamento)> abbinamentiPer(Json criteri) {
    final out = <(Json, Abbinamento)>[
      for (final i in items)
        if (immobileDisponibile(i))
          if (abbina(criteri, i) case final a?) (i, a),
    ];
    out.sort((x, y) {
      final d = y.$2.punteggio.compareTo(x.$2.punteggio);
      return d != 0 ? d : intOf(y.$1['creato']).compareTo(intOf(x.$1['creato']));
    });
    return out;
  }

  /* ================= Notifiche del cliente ================= */

  List<Json> notificheDi(Json c) => jsonList(c['notifiche'])..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
  int notificheNuove(Json? c) => c == null ? 0 : jsonList(c['notifiche']).where((n) => n['letta'] != true).length;

  Future<void> notificheSegnaLette() async {
    final c = cliente;
    if (c == null || notificheNuove(c) == 0) return;
    await _salvaCliente({...c, 'notifiche': [for (final n in jsonList(c['notifiche'])) {...n, 'letta': true}]});
  }

  /* ================= Abbinamento automatico ================= */

  /// Un immobile è (di nuovo) disponibile: avvisa i clienti con una ricerca compatibile,
  /// una sola volta per ogni ricerca e immobile.
  Future<void> avvisaAbbinamenti(Json immobile) async {
    for (final c in [..._clienti]) {
      final avvisati = strList(c['avvisati']);
      final nuove = <Json>[];
      for (final r in ricercheDi(c)) {
        final k = '${r['id']}:${immobile['id']}';
        if (avvisati.contains(k)) continue;
        final a = abbina(jsonOf(r['criteri']), immobile);
        if (a == null) continue;
        avvisati.add(k);
        nuove.add({'id': newId(5), 'tipo': 'abbinamento', 'immobile': immobile['id'], 'ricerca': r['id'], 'ricercaNome': r['nome'], 'percentuale': a.percentuale, 'creato': nowMs(), 'letta': false});
        await _emailImmobileTrovato(c, immobile, r, a);
      }
      if (nuove.isNotEmpty) await _salvaCliente({...c, 'avvisati': avvisati, 'notifiche': [...jsonList(c['notifiche']), ...nuove]});
    }
  }

  /// Per l'agente: clienti con una ricerca che corrisponde all'immobile (dal più adatto).
  List<(Json cliente, Json ricerca, Abbinamento a)> interessatiA(Json immobile) {
    final out = <(Json, Json, Abbinamento)>[
      for (final c in _clienti)
        for (final r in ricercheDi(c))
          if (abbina(jsonOf(r['criteri']), immobile) case final a?) (c, r, a),
    ];
    out.sort((x, y) => y.$3.punteggio.compareTo(x.$3.punteggio));
    return out;
  }

  /// Quanti clienti hanno l'immobile tra i preferiti.
  int preferitiCount(String itemId) => _clienti.where((c) => strList(c['preferiti']).contains(itemId)).length;

  /* ================= Area riservata ================= */

  List<Json> get clienti => [..._clienti]..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
  Json? clienteDa(String id) => _clienti.where((c) => c['id'] == id).firstOrNull;
}
