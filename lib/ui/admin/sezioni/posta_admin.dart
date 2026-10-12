/// Email: posta in uscita (avvisi all'agenzia, immobili trovati per i clienti, proposte, promemoria)
/// e nuove proposte di immobili e offerte ai clienti.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/abbinamento.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../dialogs.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';

class PostaAdmin extends StatelessWidget {
  final List<String> rest;
  final Map<String, String> query;
  const PostaAdmin({super.key, required this.rest, this.query = const {}});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final vista = rest.isEmpty ? 'uscita' : rest[0];
    final daInviare = s.repo.postaDaInviare;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Email', sub: 'Avvisi per te, immobili trovati per i clienti, proposte e promemoria delle visite.', actions: [
        VButton('Nuova proposta ai clienti', icon: 'send', kind: BtnKind.primary, href: '#/admin/posta/nuova'),
      ]),
      SubTabs(base: 'posta', current: vista, tabs: [('uscita', daInviare > 0 ? 'Da inviare ($daInviare)' : 'Da inviare'), ('inviate', 'Inviate'), ('nuova', 'Nuova proposta')]),
      switch (vista) {
        'nuova' => _Proposta(immobili: (query['immobili'] ?? '').split(','), clienti: (query['clienti'] ?? '').split(','), key: ValueKey(query.toString())),
        'inviate' => const _Elenco(inviate: true),
        _ => const _Elenco(inviate: false),
      },
    ]);
  }
}

/* ---------------- Posta in uscita ---------------- */

class _Elenco extends StatelessWidget {
  final bool inviate;
  const _Elenco({required this.inviate});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final lista = s.repo.posta(inviate: inviate);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!inviate)
        AlertBox(
          icon: 'info',
          align: CrossAxisAlignment.start,
          child: Text(
            'Il servizio di invio automatico non è ancora collegato: le email restano qui. '
            'Aprile nel tuo programma di posta con «Apri nella posta» e poi segnale come inviate. '
            'Quando collegheremo il servizio email partiranno da sole.',
            style: t.text(size: 14.4),
          ),
        ),
      if (lista.isEmpty)
        EmptyState(icon: 'send', small: true, text: inviate ? 'Nessuna email inviata.' : 'Nessuna email da inviare.')
      else
        for (final e in lista) _Email(e, key: ValueKey(e['id'])),
    ]);
  }
}

class _Email extends StatelessWidget {
  final Json e;
  const _Email(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final mailto = 'mailto:${e['a']}?subject=${Uri.encodeComponent(str(e['oggetto']))}&body=${Uri.encodeComponent(str(e['testo']))}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Pill(kTipiEmail[e['tipo']] ?? 'Email', tone: e['tipo'] == 'messaggio' || e['tipo'] == 'prenotazione' ? 'warn' : 'plain'),
            Text('A: ${str(e['nome']).isNotEmpty ? '${e['nome']} · ' : ''}${e['a']}', style: t.text(size: 14.1, weight: FontWeight.w600)),
            Text(e['stato'] == 'inviata' ? 'inviata ${quando(e['inviata'])}' : quando(e['creato']), style: t.text(size: 13.1, color: t.muted)),
          ]),
          const Gap(8),
          Text(str(e['oggetto']), style: t.text(weight: FontWeight.w700)),
          const Gap(4),
          Text(str(e['testo']), maxLines: 4, overflow: TextOverflow.ellipsis, style: t.text(size: 14.1, color: t.ink2)),
          const Gap(12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            VButton('Apri nella posta', icon: 'mail', size: BtnSize.sm, kind: e['stato'] == 'inviata' ? BtnKind.normal : BtnKind.primary, href: mailto),
            VButton('Leggi tutto', icon: 'eye', size: BtnSize.sm, onPressed: () => _leggi(context, e)),
            if (e['stato'] != 'inviata') VButton('Segna come inviata', icon: 'check', size: BtnSize.sm, onAsync: () => s.repo.postaSegnaInviata(e['id'] as String)),
            IconBtn('trash', tooltip: 'Elimina', danger: true, onPressed: () async {
              if (await confirmDialog(context, 'Eliminare questa email?', danger: true, ok: 'Elimina')) await s.repo.postaElimina(e['id'] as String);
            }),
          ]),
        ]),
      ),
    );
  }

  void _leggi(BuildContext context, Json e) {
    final s = App.read(context);
    showVModal(context, str(e['oggetto']), wide: true, (ctx) {
      final t = ctx.t;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('A: ${e['a']}', style: t.text(weight: FontWeight.w600)),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.bg, borderRadius: t.rSm),
          child: SelectableText(str(e['testo']), style: t.text(size: 15)),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          VButton('Copia il testo', icon: 'copy', onPressed: () {
            Clipboard.setData(ClipboardData(text: str(e['testo'])));
            s.toast('Testo copiato');
          }),
          VButton('Chiudi', kind: BtnKind.ghost, onPressed: () => Navigator.of(ctx).pop()),
        ]),
      ]);
    });
  }
}

/* ---------------- Nuova proposta ---------------- */

class _Proposta extends StatefulWidget {
  final List<String> immobili, clienti;
  const _Proposta({super.key, this.immobili = const [], this.clienti = const []});
  @override
  State<_Proposta> createState() => _PropostaState();
}

class _PropostaState extends State<_Proposta> {
  late final s = App.read(context);
  late final Set<String> _imm = widget.immobili.where((id) => s.repo.item(id) != null).toSet();
  late final Set<String> _scelti = widget.clienti.where((id) => s.repo.clienteDa(id) != null).toSet();
  late String _a = _scelti.isNotEmpty ? 'scelti' : 'consenso';
  final _oggetto = TextEditingController(), _msg = TextEditingController();
  String? _err;

  @override
  void initState() {
    super.initState();
    if (_imm.length == 1) _oggetto.text = 'Un immobile per te: ${s.repo.item(_imm.first)?['titolo']}';
  }

  @override
  void dispose() {
    _oggetto.dispose();
    _msg.dispose();
    super.dispose();
  }

  /// Clienti con una ricerca compatibile con almeno uno degli immobili scelti.
  Set<String> get _interessati => {
        for (final id in _imm)
          if (s.repo.item(id) case final i?)
            for (final (c, _, _) in s.repo.interessatiA(i)) c['id'] as String,
      };

  List<String> get _destinatari => switch (_a) {
        'tutti' => [for (final c in s.repo.clienti) c['id'] as String],
        'interessati' => _interessati.toList(),
        'scelti' => _scelti.toList(),
        _ => [for (final c in s.repo.clienti) if (boolOf(c['consenso'])) c['id'] as String],
      };

  Future<void> _prepara() async {
    setState(() => _err = null);
    try {
      final n = await s.repo.propostaInvia(immobili: _imm.toList(), clienti: _destinatari, oggetto: _oggetto.text, messaggio: _msg.text);
      s.toast('$n ${n == 1 ? 'email pronta' : 'email pronte'} in «Da inviare»');
      if (mounted) context.go('/admin/posta');
    } on AppError catch (e) {
      setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final repo = App.of(context).repo;
    final disponibili = repo.items.where(immobileDisponibile).toList();
    final clienti = repo.clienti;
    final dest = _destinatari;
    final conConsenso = clienti.where((c) => boolOf(c['consenso'])).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BoxTitle('1. Quali immobili (${_imm.length})', icon: 'home', size: 17.6),
          if (disponibili.isEmpty) Text('Nessun immobile disponibile.', style: t.text(color: t.muted)),
          for (final i in disponibili)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: VCheck(
                value: _imm.contains(i['id']),
                onChanged: (v) => setState(() => v ? _imm.add(i['id'] as String) : _imm.remove(i['id'])),
                label: Text.rich(TextSpan(children: [
                  TextSpan(text: str(i['titolo']), style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' · ${App.of(context).cat.prezzo(i)} · ${App.of(context).cat.luogo(i)}'),
                ])),
              ),
            ),
        ]),
      ),
      const Gap(16),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BoxTitle('2. A chi (${dest.length})', icon: 'users', size: 17.6),
          SegButtons(
            options: [('consenso', 'Chi ha dato il consenso ($conConsenso)'), ('interessati', 'Clienti interessati (${_interessati.length})'), ('scelti', 'Scelgo io'), ('tutti', 'Tutti i clienti (${clienti.length})')],
            value: _a,
            onChanged: (v) => setState(() => _a = v),
          ),
          const Gap(10),
          Text(switch (_a) {
            'consenso' => 'I clienti che hanno chiesto di ricevere nuovi immobili e offerte.',
            'interessati' => 'I clienti con una ricerca salvata compatibile con gli immobili scelti.',
            'tutti' => 'Tutti i clienti registrati: usalo solo per comunicazioni di servizio, le proposte commerciali vanno a chi ha dato il consenso.',
            _ => 'Seleziona i clienti qui sotto.',
          }, style: t.text(size: 14.1, color: t.muted)),
          if (_a == 'scelti') ...[
            const Gap(8),
            if (clienti.isEmpty) Text('Nessun cliente registrato.', style: t.text(color: t.muted)),
            for (final c in clienti)
              VCheck(
                value: _scelti.contains(c['id']),
                onChanged: (v) => setState(() => v ? _scelti.add(c['id'] as String) : _scelti.remove(c['id'])),
                label: Text('${c['nome']} · ${c['email']}${boolOf(c['consenso']) ? '' : ' (senza consenso alle proposte)'}'),
              ),
          ],
        ]),
      ),
      const Gap(16),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const BoxTitle('3. Il messaggio', icon: 'mail', size: 17.6),
          FieldLabel('Oggetto', child: VInput(controller: _oggetto, hint: 'es. Nuovi immobili a Milano, Offerta di ottobre…')),
          const Gap(12),
          FieldLabel('Messaggio', hint: 'Sotto il messaggio aggiungiamo gli immobili scelti con prezzo, dati principali e link, e la firma dell\'agenzia.',
              child: VInput(controller: _msg, minLines: 4, maxLines: 10, hint: 'es. Ciao, ecco le novità della settimana…')),
          const Gap(10),
          FormError(_err),
          const Gap(10),
          Align(alignment: Alignment.centerLeft, child: VButton('Prepara le email (${dest.length})', icon: 'send', kind: BtnKind.primary, onAsync: _prepara)),
        ]),
      ),
    ]);
  }
}
