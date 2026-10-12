part of 'repository.dart';

/*
 * POSTA IN USCITA E STATISTICHE
 * Ogni email che il sito deve mandare (avvisi all'agenzia, immobili trovati, proposte ai clienti,
 * promemoria delle visite) viene preparata qui e messa in coda. Finché non è collegato un servizio
 * di invio, l'agenzia la apre nel suo programma di posta con un clic e la segna come inviata.
 */

const kTipiEmail = {
  'messaggio': 'Nuovo messaggio',
  'prenotazione': 'Nuova prenotazione',
  'abbinamento': 'Immobile per un cliente',
  'proposta': 'Proposta ai clienti',
  'promemoria': 'Promemoria visita',
};

extension RepoPosta on Repo {
  /* ================= Coda delle email ================= */

  /// Indirizzo a cui arrivano gli avvisi per l'agenzia.
  String get emailAgenzia => str(settings['emailAvvisi']).isNotEmpty ? str(settings['emailAvvisi']) : str(settings['email']);

  /// Link pubblico a una pagina del sito (nelle email e nel QR della scheda in vetrina).
  String linkSito(String path) {
    final base = str(settings['urlSito']).trim();
    if (base.isEmpty) return Uri.base.replace(fragment: path, query: '').toString().replaceFirst('?#', '#');
    return '${base.endsWith('/') ? base : '$base/'}#$path';
  }

  Future<void> _accoda(String tipo, {required String a, String nome = '', required String oggetto, required String testo, String rif = ''}) async {
    if (!validEmail(a)) return;
    await _put('posta', _posta, {
      'id': newId(),
      'tipo': tipo,
      'a': a,
      'nome': nome,
      'oggetto': cut(oggetto, 200),
      'testo': testo,
      'rif': rif,
      'stato': 'da_inviare',
      'creato': nowMs(),
    });
  }

  List<Json> posta({bool inviate = false}) =>
      _posta.where((p) => (p['stato'] == 'inviata') == inviate).toList()..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));

  int get postaDaInviare => _posta.where((p) => p['stato'] != 'inviata').length;

  Future<void> postaSegnaInviata(String id) async {
    final p = _posta.where((x) => x['id'] == id).firstOrNull;
    if (p != null) await _put('posta', _posta, {...p, 'stato': 'inviata', 'inviata': nowMs()});
  }

  Future<void> postaElimina(String id) => _delete('posta', _posta, id);

  String get _firma => '${settings['nome']}\n${[str(settings['telefono']), str(settings['email']), str(settings['indirizzo'])].where((x) => x.isNotEmpty).join(' · ')}';

  String _riepilogoImmobile(Json i) {
    final c = Catalog(schema, items);
    final righe = [
      str(i['titolo']),
      [c.prezzo(i), c.luogo(i)].where((x) => x.isNotEmpty).join(' · '),
      [
        if (numOrNull(i['mq']) != null) '${fmtNum(numOrNull(i['mq'])!)} m²',
        if (numOrNull(i['locali']) != null) '${fmtNum(numOrNull(i['locali'])!)} locali',
        if (numOrNull(i['bagni']) != null) '${fmtNum(numOrNull(i['bagni'])!)} bagni',
      ].join(' · '),
      linkSito('/scheda/${i['id']}'),
    ];
    return righe.where((x) => x.isNotEmpty).join('\n');
  }

  /* ================= Avvisi all'agenzia ================= */

  Future<void> _avvisoMessaggio(Json dati, String immobile) async {
    final i = immobile.isEmpty ? null : item(immobile);
    await _accoda(
      'messaggio',
      a: emailAgenzia,
      nome: str(settings['nome']),
      oggetto: 'Nuovo messaggio da ${dati['nome']}${i != null ? ' per «${i['titolo']}»' : ''}',
      testo: [
        '${dati['nome']} ha scritto dal sito${i != null ? " a proposito dell'immobile «${i['titolo']}»" : ''}:',
        '',
        str(dati['messaggio']),
        '',
        'Email: ${dati['email']}${str(dati['telefono']).isNotEmpty ? ' · Telefono: ${dati['telefono']}' : ''}',
        if (i != null) 'Annuncio: ${linkSito('/scheda/${i['id']}')}',
        'Rispondi dall\'area riservata: ${linkSito('/admin/messaggi')}',
      ].join('\n'),
    );
  }

  Future<void> _avvisoPrenotazione(Json p) async {
    final d = jsonOf(p['dati']);
    final quando = '${fmtDate(str(p['data']), 'EEEE d MMMM')} alle ${fmtHm(intOf(p['inizio']))}';
    await _accoda(
      'prenotazione',
      a: emailAgenzia,
      nome: str(settings['nome']),
      oggetto: '${p['stato'] == 'in_attesa' ? 'Da confermare' : 'Nuova prenotazione'}: ${d['servizio']} $quando',
      testo: [
        '${d['nome']} ha prenotato dal sito:',
        '',
        '${d['servizio']}${str(d['immobile']).isNotEmpty ? ' · ${d['immobile']}' : ''}',
        quando + (str(d['collaboratore']).isNotEmpty ? ' con ${d['collaboratore']}' : ''),
        if (str(d['note']).isNotEmpty) 'Note: ${d['note']}',
        '',
        'Email: ${d['email']} · Telefono: ${d['telefono']}',
        'Agenda: ${linkSito('/admin/prenotazioni')}',
      ].join('\n'),
      rif: str(p['id']),
    );
  }

  /* ================= Email ai clienti ================= */

  Future<void> _emailImmobileTrovato(Json c, Json i, Json ricerca, Abbinamento a) async {
    final nome = str(c['nome']).split(' ').first;
    await _accoda(
      'abbinamento',
      a: str(c['email']),
      nome: str(c['nome']),
      oggetto: '$nome, è disponibile un immobile per te: ${i['titolo']}',
      testo: [
        'Ciao $nome,',
        '',
        'è appena diventato disponibile un immobile che corrisponde alla tua ricerca «${ricerca['nome']}»'
            '${a.percentuale < 100 ? ' (${a.percentuale}% di quello che cerchi)' : ''}:',
        '',
        _riepilogoImmobile(i),
        if (a.sopraBudget) '\nIl prezzo è un po\' sopra il tuo budget, ma potrebbe comunque interessarti.',
        if (a.mancano.isNotEmpty) '\nCosa non corrisponde: ${a.mancano.join(', ')}.',
        '',
        'Vuoi vederlo dal vivo? Rispondi a questa email o prenota una visita dal sito.',
        '',
        _firma,
        '',
        'Ricevi questa email perché hai salvato una ricerca sul nostro sito. Puoi modificarla o eliminarla dal tuo account: ${linkSito('/account')}',
      ].join('\n'),
      rif: str(i['id']),
    );
  }

  /// Email ai clienti con immobili scelti dall'agenzia (nuovi annunci, offerte).
  /// Senza destinatari indicati: tutti i clienti che hanno dato il consenso a ricevere proposte.
  Future<int> propostaInvia({required List<String> immobili, List<String>? clienti, required String oggetto, required String messaggio}) async {
    final scelti = [for (final id in immobili) ?item(id)];
    if (oggetto.trim().isEmpty) throw const AppError("Scrivi l'oggetto dell'email");
    if (scelti.isEmpty && messaggio.trim().isEmpty) throw const AppError('Scegli almeno un immobile o scrivi un messaggio');
    final dest = clienti == null ? _clienti.where((c) => boolOf(c['consenso'])).toList() : [for (final id in clienti) ?clienteDa(id)];
    if (dest.isEmpty) throw const AppError('Nessun destinatario: scegli almeno un cliente');
    for (final c in dest) {
      final nome = str(c['nome']).split(' ').first;
      await _accoda(
        'proposta',
        a: str(c['email']),
        nome: str(c['nome']),
        oggetto: Repo.testoBreve(oggetto, 200),
        testo: [
          'Ciao $nome,',
          '',
          if (messaggio.trim().isNotEmpty) ...[messaggio.trim(), ''],
          for (final i in scelti) ...[_riepilogoImmobile(i), ''],
          _firma,
          if (boolOf(c['consenso'])) ...['', 'Non vuoi più ricevere proposte? Puoi toglierle dal tuo account: ${linkSito('/account')}'],
        ].join('\n'),
      );
    }
    return dest.length;
  }

  /// Promemoria per le visite di domani (una volta sola per visita).
  Future<void> promemoriaVisite() async {
    final domani = addDays(oggi(), 1);
    for (final p in [..._pren]) {
      final d = jsonOf(p['dati']);
      if (p['data'] != domani || p['stato'] != 'confermata' || boolOf(d['promemoria']) || !validEmail(str(d['email']))) continue;
      await _accoda(
        'promemoria',
        a: str(d['email']),
        nome: str(d['nome']),
        oggetto: 'Promemoria: ${d['servizio']} domani alle ${fmtHm(intOf(p['inizio']))}',
        testo: [
          'Ciao ${str(d['nome']).split(' ').first},',
          '',
          'ti ricordiamo l\'appuntamento di domani, ${fmtDate(domani, 'EEEE d MMMM')} alle ${fmtHm(intOf(p['inizio']))}:',
          '${d['servizio']}${str(d['immobile']).isNotEmpty ? ' · ${d['immobile']}' : ''}${str(d['collaboratore']).isNotEmpty ? ', con ${d['collaboratore']}' : ''}.',
          '',
          'Per spostarlo o annullarlo: ${linkSito('/mia-prenotazione/${p['id']}')}',
          '',
          _firma,
        ].join('\n'),
        rif: str(p['id']),
      );
      await _put('prenotazioni', _pren, {...p, 'dati': {...d, 'promemoria': true}});
    }
  }

  /* ================= Statistiche degli annunci ================= */

  /// Una visita alla scheda di un immobile (non conta l'agenzia collegata).
  Future<void> registraVista(String itemId) async {
    final s = jsonOf(_stat[itemId]);
    _stat[itemId] = {'viste': intOf(s['viste']) + 1, 'ultima': nowMs()};
    await _s.set('stat', _stat);
  }

  /// Numeri per ogni immobile: visite alla scheda, preferiti, richieste, visite prenotate,
  /// clienti con una ricerca compatibile e giorni sul mercato.
  List<Json> statistiche() {
    final rich = <String, int>{}, vis = <String, int>{};
    for (final r in _rich) {
      final id = str(jsonOf(r['dati'])['immobile']);
      if (id.isNotEmpty) rich[id] = (rich[id] ?? 0) + 1;
    }
    for (final p in _pren) {
      final id = str(p['immobile_id']);
      if (id.isNotEmpty && p['stato'] != 'annullata') vis[id] = (vis[id] ?? 0) + 1;
    }
    final ora = nowMs();
    return [
      for (final i in items)
        {
          'id': i['id'],
          'titolo': str(i['titolo']),
          'stato': str(i['statoAnnuncio']).isEmpty ? 'Disponibile' : str(i['statoAnnuncio']),
          'viste': intOf(jsonOf(_stat[i['id']])['viste']),
          'preferiti': preferitiCount(i['id'] as String),
          'richieste': rich[i['id']] ?? 0,
          'visite': vis[i['id']] ?? 0,
          'interessati': interessatiA(i).map((x) => x.$1['id']).toSet().length,
          'giorni': ((intOf(i['chiusoIl'], ora) - intOf(i['disponibileDal'], intOf(i['creato'], ora))) / 86400000).floor().clamp(0, 100000),
        }
    ];
  }
}
