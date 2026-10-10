/// #/prenota: prenotazione online in passaggi (servizio, collaboratore, giorno, orario, dati).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../forms_public.dart';
import '../inputs.dart';
import '../kit.dart';
import '../shell.dart';
import 'booking_widgets.dart';

class PrenotaPage extends StatefulWidget {
  final String servizio;
  const PrenotaPage({super.key, this.servizio = ''});
  @override
  State<PrenotaPage> createState() => _PrenotaPageState();
}

class _PrenotaPageState extends State<PrenotaPage> {
  late final Json dati = App.read(context).repo.prenPubblico();
  Json? servizio;
  String coll = '', data = '', ora = '';
  Map<String, int> giorni = {};
  String cerca = '';
  Json? confermata;
  final _scroll = ScrollController();
  final _kColl = GlobalKey(), _kData = GlobalKey(), _kOra = GlobalKey(), _kDati = GlobalKey();

  // dati del cliente
  final _nome = TextEditingController(), _email = TextEditingController(), _tel = TextEditingController(), _note = TextEditingController();
  var _privacy = false, _tentato = false;
  String? _err;

  List<Json> get _servizi => jsonList(dati['servizi']);
  List<Json> get _colls => jsonList(dati['collaboratori']);

  @override
  void initState() {
    super.initState();
    if (!App.read(context).modulo('prenotazioni')) return;
    servizio = _servizi.where((s) => s['id'] == widget.servizio).firstOrNull;
    if (servizio != null) {
      _carica();
      WidgetsBinding.instance.addPostFrameCallback((_) => _vai(_kData));
    }
  }

  @override
  void dispose() {
    for (final c in [_nome, _email, _tel, _note]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  List<Json> _collsPer(Json s) => _colls.where((c) => strList(c['servizi']).isEmpty || strList(c['servizi']).contains(s['id'])).toList();

  void _carica() {
    final s = App.read(context);
    giorni = s.repo.giorniLiberi(servizio!, coll, oggi());
    if (data.isNotEmpty && (giorni[data] ?? 0) == 0) data = '';
  }

  List<String> get _ore => servizio == null || data.isEmpty ? [] : App.read(context).repo.slotLiberi(data, servizio!, coll: coll).keys.toList();

  void _vai(GlobalKey k) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = k.currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    });
  }

  Future<void> _invia() async {
    setState(() => _tentato = true);
    if (_nome.text.trim().isEmpty || !validEmail(_email.text.trim()) || _tel.text.trim().isEmpty || !_privacy) {
      setState(() => _err = 'Compila tutti i campi e accetta il trattamento dei dati.');
      return;
    }
    setState(() => _err = null);
    try {
      final p = await App.read(context).repo.prenCrea({
        'nome': _nome.text, 'email': _email.text, 'telefono': _tel.text, 'note': _note.text,
        'servizio': servizio!['id'], 'collaboratore': coll, 'data': data, 'ora': ora,
      });
      setState(() => confermata = p);
      _scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } on AppError catch (e) {
      setState(() {
        _err = e.message;
        if (e.message.contains('non è più disponibile')) ora = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    Widget body;
    if (!s.modulo('prenotazioni')) {
      body = const EmptyState(icon: 'calendar', title: 'Prenotazioni non disponibili', text: 'Contattaci per fissare un appuntamento.', actions: [VButton('Contatti', kind: BtnKind.primary, href: '#/p/contatti')]);
    } else if (_servizi.isEmpty) {
      body = const EmptyState(icon: 'calendar', title: 'Nessun servizio prenotabile', text: 'Contattaci per fissare un appuntamento.', actions: [VButton('Contatti', kind: BtnKind.primary, href: '#/p/contatti')]);
    } else if (confermata != null) {
      body = _Conferma(p: confermata!, dati: dati);
    } else {
      body = _form(context);
    }
    return PageScroll(controller: _scroll, children: [
      const PageHero('Prenota online', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }

  Widget _form(BuildContext context) {
    final t = context.t;
    final sv = servizio;
    final mostraColl = sv != null && _colls.isNotEmpty && _collsPer(sv).isNotEmpty;
    var n = 1;
    final steps = <Widget>[];

    // 1. Servizio
    final gruppi = <String, List<Json>>{};
    for (final x in _servizi) {
      (gruppi[str(x['categoria']).isEmpty ? 'Servizi' : str(x['categoria'])] ??= []).add(x);
    }
    final q = norm(cerca);
    steps.add(PStep(
      n: n++,
      title: 'Scegli il servizio',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_servizi.length > 8) Padding(padding: const EdgeInsets.only(bottom: 14), child: VInput(hint: 'Cerca un servizio…', icon: 'search', onChanged: (v) => setState(() => cerca = v))),
        for (final e in gruppi.entries)
          if (e.value.any((x) => q.isEmpty || norm(x['nome']).contains(q))) ...[
            Padding(padding: const EdgeInsets.only(bottom: 8, top: 4), child: Text(e.key.toUpperCase(), style: t.caps(size: 12.8))),
            AutoGrid(minWidth: 230, gap: 8, children: [
              for (final x in e.value.where((x) => q.isEmpty || norm(x['nome']).contains(q)))
                POpt(
                  title: str(x['nome']),
                  sub: Row(children: [
                    VIcon('clock', size: 14, color: t.muted),
                    const SizedBox(width: 5),
                    Flexible(child: Text('${durata(intOf(x['durata']))}${prezzoServizio(x['prezzo']).isNotEmpty ? ' · ${prezzoServizio(x['prezzo'])}' : ''}')),
                  ]),
                  on: sv?['id'] == x['id'],
                  onTap: () => setState(() {
                    servizio = x;
                    data = '';
                    ora = '';
                    if (!_collsPer(x).any((c) => c['id'] == coll)) coll = '';
                    _carica();
                    _vai(_colls.isNotEmpty && _collsPer(x).isNotEmpty ? _kColl : _kData);
                  }),
                ),
            ]),
            const SizedBox(height: 16),
          ],
      ]),
    ));

    // 2. Collaboratore
    if (mostraColl) {
      steps.add(KeyedSubtree(
        key: _kColl,
        child: PStep(
          n: n++,
          title: 'Con chi?',
          child: AutoGrid(minWidth: 230, gap: 8, children: [
            POpt(title: 'Nessuna preferenza', sub: const Text('Il primo disponibile'), on: coll.isEmpty, onTap: () => setState(() {
              coll = '';
              ora = '';
              _carica();
            })),
            for (final c in _collsPer(sv))
              POpt(
                title: str(c['nome']),
                sub: str(c['ruolo']).isNotEmpty ? Text(str(c['ruolo'])) : null,
                on: coll == c['id'],
                onTap: () => setState(() {
                  coll = c['id'] as String;
                  ora = '';
                  _carica();
                }),
              ),
          ]),
        ),
      ));
    }

    // 3. Giorno
    if (sv != null) {
      final libero = giorni.values.any((x) => x > 0);
      final attesa = dati['listaAttesa'] == true;
      steps.add(KeyedSubtree(
        key: _kData,
        child: PStep(
          n: n++,
          title: 'Scegli il giorno',
          child: libero
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CalGrid(giorni: giorni, sel: data, onTap: (d) => setState(() {
                    data = d;
                    ora = '';
                    _vai(_kOra);
                  })),
                  if (attesa)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: LinkBtn("Nessuna data ti va bene? Mettiti in lista d'attesa", onTap: () => apriListaAttesa(context, sv, coll, data, _colls)),
                    ),
                ])
              : EmptyState(
                  icon: 'calendar',
                  small: true,
                  text: 'Nessuna disponibilità nelle prossime settimane per questa scelta.',
                  actions: [
                    if (attesa) VButton("Nessuna data ti va bene? Mettiti in lista d'attesa", kind: BtnKind.primary, onPressed: () => apriListaAttesa(context, sv, coll, data, _colls)),
                    const VButton('Contattaci', kind: BtnKind.outline, href: '#/p/contatti'),
                  ],
                ),
        ),
      ));
    }

    // 4. Orario
    if (sv != null && data.isNotEmpty) {
      steps.add(KeyedSubtree(
        key: _kOra,
        child: PStep(
          n: n++,
          title: "Scegli l'orario",
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(fmtDate(data), style: t.text(size: 14.1, color: t.muted))),
            OreGrid(ore: _ore, sel: ora, onTap: (o) => setState(() {
              ora = o;
              _vai(_kDati);
            })),
            if (dati['listaAttesa'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: LinkBtn("Nessun orario ti va bene? Mettiti in lista d'attesa per questo giorno", onTap: () => apriListaAttesa(context, sv, coll, data, _colls)),
              ),
          ]),
        ),
      ));
    }

    // 5. Dati
    if (ora.isNotEmpty) {
      final inv = _tentato;
      steps.add(KeyedSubtree(
        key: _kDati,
        child: PStep(
          n: n++,
          title: 'I tuoi dati',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FieldLabel('Nome e cognome', child: VInput(controller: _nome, autofill: const [AutofillHints.name], invalid: inv && _nome.text.trim().isEmpty)),
            const SizedBox(height: 12),
            TwoCols(
              FieldLabel('Email', child: VInput(controller: _email, keyboard: TextInputType.emailAddress, invalid: inv && !validEmail(_email.text.trim()))),
              FieldLabel('Telefono', child: VInput(controller: _tel, keyboard: TextInputType.phone, invalid: inv && _tel.text.trim().isEmpty)),
            ),
            const SizedBox(height: 12),
            FieldLabel('Note (facoltative)', child: VInput(controller: _note, minLines: 3, maxLines: 6, hint: "Informazioni utili per l'appuntamento")),
            const SizedBox(height: 12),
            PrivacyCheck(value: _privacy, onChanged: (v) => setState(() => _privacy = v), scopo: 'per gestire la prenotazione', linkLabel: 'privacy', invalid: inv && !_privacy),
            const SizedBox(height: 8),
            FormError(_err),
            const SizedBox(height: 8),
            VButton('Conferma prenotazione', icon: 'check', kind: BtnKind.primary, size: BtnSize.lg, block: true, onAsync: _invia),
          ]),
        ),
      ));
    }

    // Riepilogo
    final c = _colls.where((x) => x['id'] == coll).firstOrNull;
    final riep = CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Riepilogo', style: t.title(size: 17.6, weight: FontWeight.w700))),
        if (sv == null)
          Text('Scegli un servizio per iniziare.', style: t.text(color: t.muted))
        else
          Riep([
            ('Servizio', str(sv['nome'])),
            ('Durata', durata(intOf(sv['durata']))),
            ('Prezzo', prezzoServizio(sv['prezzo'])),
            if (mostraColl) ('Con', c != null ? str(c['nome']) : 'Nessuna preferenza'),
            ('Giorno', data.isEmpty ? '' : fmtDate(data)),
            ('Orario', ora),
          ]),
      ]),
    );

    final colSteps = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < steps.length; i++) ...[if (i > 0) const SizedBox(height: 20), steps[i]],
    ]);
    if (context.vw <= 900) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [riep, const SizedBox(height: 32), colSteps]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: colSteps), const SizedBox(width: 32), SizedBox(width: 320, child: riep)]);
  }
}

class _Conferma extends StatelessWidget {
  final Json p, dati;
  const _Conferma({required this.p, required this.dati});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final set = s.settings;
    final ok = p['stato'] == 'confermata';
    final link = fullLink('/mia-prenotazione/${p['id']}');
    final modifica = dati['modificaCliente'] == true;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CardBox(
          child: Column(children: [
            BigStatusIcon(ok: ok),
            Text(ok ? 'Prenotazione confermata!' : 'Richiesta inviata', textAlign: TextAlign.center, style: t.title(size: t.h2(context))),
            const SizedBox(height: 8),
            Text(ok ? str(dati['messaggio']) : "Ti ricontatteremo a breve per confermare l'appuntamento.", textAlign: TextAlign.center, style: t.text()),
            const SizedBox(height: 20),
            Riep([
              ('Servizio', str(p['servizio'])),
              ('Quando', '${fmtDate(str(p['data']))}, ore ${p['ora']}'),
              ('Con', str(p['collaboratore'])),
              ('Dove', str(set['indirizzo'])),
              ('Codice', Text(codicePren(p['id']), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 20),
            if (modifica)
              AlertBox(
                icon: 'key',
                align: CrossAxisAlignment.start,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Il tuo link personale', style: t.text(weight: FontWeight.w700)),
                  Text("Con questo link puoi rivedere, spostare o annullare l'appuntamento (fino a ${dati['limiteModificaOre']} ore prima). Salvalo o aggiungilo al calendario.", style: t.text()),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: VInput(initial: link, readOnly: true, dense: true, style: t.text(size: 13.1))),
                    const SizedBox(width: 8),
                    VButton('Copia', icon: 'copy', size: BtnSize.sm, onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      s.toast('Link copiato');
                    }),
                  ]),
                ]),
              ),
            Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
              VButton('Aggiungi al calendario', icon: 'calendar', kind: BtnKind.outline, onPressed: () => scaricaIcs(s, p, link)),
              if (modifica) VButton('Gestisci prenotazione', icon: 'edit', kind: BtnKind.outline, href: '#/mia-prenotazione/${p['id']}'),
              const VButton('Torna alla home', kind: BtnKind.primary, href: '#/'),
            ]),
            if (str(set['telefono']).isNotEmpty && !modifica)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text('Per spostare o annullare chiama il ${set['telefono']}.', style: t.text(size: 14.1, color: t.muted))),
          ]),
        ),
      ),
    );
  }
}

