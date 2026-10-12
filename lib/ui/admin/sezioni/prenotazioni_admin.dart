/// Visite e appuntamenti: agenda del giorno per agente, prossimi appuntamenti, impostazioni.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/abbinamento.dart';
import '../../../data/preset.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../booking/booking_widgets.dart';
import '../../dialogs.dart';
import '../../forms_public.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';
import '../form/vform.dart';

const kStatiPrenAdmin = {
  'in_attesa': ('Da confermare', 'warn'),
  'confermata': ('Confermata', 'ok'),
  'completata': ('Completata', 'muted'),
  'assente': ('Non presentato', 'err'),
  'annullata': ('Annullata', 'err'),
};

int _min(String hm) {
  final p = hm.split(':').map(int.parse).toList();
  return p[0] * 60 + p[1];
}

class PrenotazioniAdmin extends StatelessWidget {
  final List<String> rest;
  final Map<String, String> query;
  const PrenotazioniAdmin({super.key, required this.rest, required this.query});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    if (!s.modulo('prenotazioni')) return AlertBox.text('Il modulo prenotazioni non è attivo per questo sito: puoi attivarlo da Impostazioni → Funzioni attive.');
    final vista = rest.isEmpty ? 'agenda' : rest[0];
    final data = validIsoDate(query['data'] ?? '') ? query['data']! : oggi();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Prenotazioni', sub: 'Appuntamenti prenotati dal sito o inseriti da te.', actions: [
        VButton('Nuova prenotazione', icon: 'plus', kind: BtnKind.primary, onPressed: () => nuovaPrenotazione(context, data)),
      ]),
      SubTabs(base: 'prenotazioni', current: vista, tabs: const [('agenda', 'Agenda del giorno'), ('lista', 'Prossimi appuntamenti'), ('impostazioni', 'Orari, agenti e servizi')]),
      switch (vista) {
        'lista' => const _Lista(),
        'impostazioni' => const _Impostazioni(),
        _ => _Agenda(data: data),
      },
    ]);
  }
}

/* ---------------- Agenda del giorno ---------------- */

class _Agenda extends StatelessWidget {
  final String data;
  const _Agenda({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final cfg = s.repo.prenConfig();
    void vai(String d) => context.go('/admin/prenotazioni/agenda?data=$d');
    final giorno = s.repo.prenElenco(data, data);
    final futuri = s.repo.prenElenco(oggi(), addDays(oggi(), 120));
    final attesa = futuri.where((p) => p['stato'] == 'in_attesa').toList();

    // Colonne: un collaboratore per colonna (o un'unica agenda)
    final w = '${parseDate(data).weekday % 7}';
    final attivi = jsonList(cfg['collaboratori']).where((c) => c['attivo'] != false).toList();
    final colonne = attivi.isNotEmpty
        ? [for (final c in attivi) (id: str(c['id']), nome: str(c['nome']), orari: boolOf(c['orariPropri']) && c['orari'] != null ? jsonOf(c['orari']) : jsonOf(cfg['orari']))]
        : [(id: '', nome: 'Agenda', orari: jsonOf(cfg['orari']))];
    for (final p in giorno) {
      if (!colonne.any((c) => c.id == p['collaboratore_id'])) colonne.add((id: str(p['collaboratore_id']), nome: str(p['collaboratore']).isEmpty ? 'Non assegnato' : str(p['collaboratore']), orari: <String, dynamic>{}));
    }
    List<List<int>> fasce(Json orari) {
      final o = orari[w] is List ? orari[w] as List : const [];
      return [for (final iv in o) if (iv is List && iv.length > 1 && hm(str(iv[0])) != null && hm(str(iv[1])) != null) [hm(str(iv[0]))!, hm(str(iv[1]))!]];
    }

    var da = 24 * 60, a = 0;
    for (final c in colonne) {
      for (final f in fasce(c.orari)) {
        if (f[0] < da) da = f[0];
        if (f[1] > a) a = f[1];
      }
    }
    for (final p in giorno) {
      if (_min(str(p['ora'])) < da) da = _min(str(p['ora']));
      if (_min(str(p['fine'])) > a) a = _min(str(p['fine']));
    }
    if (da >= a) {
      da = 8 * 60;
      a = 19 * 60;
    }
    da = (da ~/ 60) * 60;
    a = ((a + 59) ~/ 60) * 60;
    const k = 1.4; // pixel per minuto
    final ore = [for (var x = da; x < a; x += 60) x];

    Widget evento(Json p) {
      final tone = kStatiPrenAdmin[p['stato']]?.$2 ?? 'muted';
      final (bg, bd) = switch (tone) {
        'warn' => (VTheme.warnSoft, VTheme.warn),
        'muted' => (VTheme.mutedSoft, const Color(0xFF9AA3AD)),
        'err' => (VTheme.errSoft, VTheme.danger),
        _ => (t.primarySoft, t.primary),
      };
      final annullata = p['stato'] == 'annullata';
      final top = (_min(str(p['ora'])) - da) * k;
      final h = ((_min(str(p['fine'])) - _min(str(p['ora']))) * k - 2).clamp(22.0, 9999.0);
      return Positioned(
        top: top,
        left: 4,
        right: 4,
        height: h,
        child: Opacity(
          opacity: annullata ? .55 : 1,
          child: Hover(
            onTap: () => dettaglioPrenotazione(context, p),
            // striscia colorata a sinistra: bordo non uniforme, quindi gli angoli si arrotondano ritagliando
            builder: (_, hv) => Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: hv ? t.shadow : null),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: bg, border: Border(left: BorderSide(color: bd, width: 4))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text.rich(
                      TextSpan(children: [TextSpan(text: '${p['ora']}–${p['fine']} ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: str(p['nome']))]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.text(size: 12.8, height: 1.25).copyWith(decoration: annullata ? TextDecoration.lineThrough : null),
                    ),
                    Text(str(p['immobile']).isNotEmpty ? str(p['immobile']) : str(p['servizio']), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text(size: 12.2, color: t.muted, height: 1.25)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final altezza = (a - da) * k;
    final agenda = Container(
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (c, box) {
        final colW = ((box.maxWidth - 58) / colonne.length).clamp(170.0, 9999.0);
        final totW = 58 + colW * colonne.length;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totW,
            child: Column(children: [
              Container(
                color: context.t.tint,
                child: Row(children: [
                  const SizedBox(width: 58),
                  for (final col in colonne)
                    Container(
                      width: colW,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: t.line), bottom: BorderSide(color: t.line))),
                      child: Row(children: [
                        Flexible(child: Text(col.nome, overflow: TextOverflow.ellipsis, style: t.text(weight: FontWeight.w700))),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                          decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(999)),
                          child: Text('${giorno.where((p) => p['collaboratore_id'] == col.id && p['stato'] != 'annullata').length}', style: t.text(size: 12, color: t.primary)),
                        ),
                      ]),
                    ),
                ]),
              ),
              SizedBox(
                height: altezza,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SizedBox(
                    width: 58,
                    child: Stack(children: [
                      for (final o in ore)
                        Positioned(
                          top: (o - da) * k + (o == da ? 0 : -8),
                          right: 8,
                          child: Text('${(o ~/ 60).toString().padLeft(2, '0')}:00', style: t.text(size: 12, weight: FontWeight.w600, color: t.muted, height: 1.2)),
                        ),
                    ]),
                  ),
                  for (final col in colonne)
                    Container(
                      width: colW,
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: t.line)), color: context.t.tint2),
                      child: Stack(children: [
                        for (final f in fasce(col.orari)) Positioned(top: (f[0] - da) * k, height: (f[1] - f[0]) * k, left: 0, right: 0, child: Container(color: Colors.white)),
                        for (final o in ore) Positioned(top: (o - da) * k, left: 0, right: 0, child: Container(height: 1, color: t.line)),
                        for (final p in giorno.where((p) => p['collaboratore_id'] == col.id)) evento(p),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        );
      }),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (attesa.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: const Color(0xFFFFFAF2), border: Border.all(color: mix(VTheme.warn, .4, Colors.white)), borderRadius: t.r),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BoxTitle('${attesa.length} ${attesa.length == 1 ? 'richiesta da confermare' : 'richieste da confermare'}', icon: 'clock', size: 17.6, color: VTheme.warn),
            for (final p in attesa.take(8))
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
                child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
                  Cell2('${fmtDate(str(p['data']), 'EEE d MMM')} ${p['ora']} · ${p['servizio']} · ${p['nome']}', onTap: () => dettaglioPrenotazione(context, p), bold: false),
                  Wrap(spacing: 6, children: [
                    VButton('Conferma', size: BtnSize.sm, kind: BtnKind.primary, onAsync: () => _cambia(context, p['id'], 'confermata')),
                    VButton('Rifiuta', size: BtnSize.sm, kind: BtnKind.ghost, danger: true, onAsync: () => _cambia(context, p['id'], 'annullata')),
                  ]),
                ]),
              ),
          ]),
        ),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        IconBtn('chevronLeft', tooltip: 'Giorno precedente', onPressed: () => vai(addDays(data, -1))),
        SizedBox(width: 160, child: DateInput(value: data, dense: true, onChanged: (d) => d.isNotEmpty ? vai(d) : null)),
        IconBtn('chevronRight', tooltip: 'Giorno successivo', onPressed: () => vai(addDays(data, 1))),
        VButton('Oggi', size: BtnSize.sm, onPressed: () => vai(oggi())),
        Padding(padding: const EdgeInsets.only(left: 8), child: Text(capitalize(fmtDate(data, 'EEEE d MMMM y')), style: t.text(weight: FontWeight.w700))),
      ]),
      const Gap(16),
      agenda,
      if (giorno.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Nessun appuntamento in questo giorno.', textAlign: TextAlign.center, style: t.text(color: t.muted))),
    ]);
  }
}

Future<void> _cambia(BuildContext context, String id, String stato) async {
  final s = App.read(context);
  if (stato == 'annullata' && !await confirmDialog(context, "Annullare questo appuntamento? L'orario tornerà disponibile.")) return;
  if (await s.run(() async {
        await s.repo.prenStato(id, stato);
        return true;
      }) ==
      true) {
    s.toast('Aggiornato');
  }
}

/* ---------------- Prossimi appuntamenti ---------------- */

class _Lista extends StatefulWidget {
  const _Lista();
  @override
  State<_Lista> createState() => _ListaState();
}

class _ListaState extends State<_Lista> {
  var _f = '', _g = 30, _agente = '';

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final agenti = jsonList(s.repo.prenConfig()['collaboratori']);
    final arr = s.repo.prenElenco(oggi(), addDays(oggi(), _g)).where((p) => (_f.isEmpty || p['stato'] == _f) && (_agente.isEmpty || p['collaboratore_id'] == _agente)).toList();
    final perGiorno = <String, List<Json>>{};
    for (final p in arr) {
      (perGiorno[str(p['data'])] ??= []).add(p);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Mostra', style: t.text()),
        SizedBox(width: 190, child: VSelect<String>(value: _f, dense: true, items: [('', 'tutti gli stati'), for (final e in kStatiPrenAdmin.entries) (e.key, e.value.$1)], onChanged: (v) => setState(() => _f = v ?? ''))),
        Text('nei prossimi', style: t.text()),
        SizedBox(width: 90, child: VSelect<int>(value: _g, dense: true, items: const [(7, '7'), (30, '30'), (90, '90')], onChanged: (v) => setState(() => _g = v ?? 30))),
        Text('giorni', style: t.text()),
        if (agenti.isNotEmpty) ...[
          Text('agente', style: t.text()),
          SizedBox(width: 200, child: VSelect<String>(value: _agente, dense: true, items: [('', 'tutti'), for (final a in agenti) (str(a['id']), str(a['nome']))], onChanged: (v) => setState(() => _agente = v ?? ''))),
        ],
      ]),
      const Gap(16),
      if (arr.isEmpty)
        const EmptyState(icon: 'calendar', small: true, text: 'Nessun appuntamento nel periodo scelto.')
      else
        for (final e in perGiorno.entries) ...[
          Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text(capitalize(fmtDate(e.key)), style: t.title(size: 17.6, weight: FontWeight.w700))),
          AdminTable(rows: [
            for (final p in e.value)
              [
                Text.rich(TextSpan(children: [TextSpan(text: str(p['ora']), style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: '–${p['fine']}')]), style: t.text(size: 14.9)),
                Cell2(str(p['nome']), sub: [str(p['servizio']), str(p['immobile']), if (str(p['collaboratore']).isNotEmpty) 'con ${p['collaboratore']}'].where((x) => x.isNotEmpty).join(' · '), onTap: () => dettaglioPrenotazione(context, p)),
                str(p['telefono']).isNotEmpty ? TextLink(str(p['telefono']), 'tel:${telHref(str(p['telefono']))}', style: t.text(size: 14.9, color: t.primary)) : const SizedBox.shrink(),
                statoPill(kStatiPrenAdmin, str(p['stato'])),
              ],
          ]),
        ],
    ]);
  }
}

/* ---------------- Dettaglio di una prenotazione ---------------- */

Future<void> dettaglioPrenotazione(BuildContext context, Json p) {
  final s = App.read(context);
  final set = s.settings;
  final linkCliente = s.repo.linkSito('/mia-prenotazione/${p['id']}');
  final msg = 'Buongiorno ${p['nome']}, le confermiamo l\'appuntamento per ${p['servizio']} ${fmtDate(str(p['data']))} alle ${p['ora']}. Per rivederlo, spostarlo o annullarlo: $linkCliente — ${set['nome']}';
  final linkRec = s.repo.linkSito('/recensioni?pren=${p['id']}');
  final msgRec = 'Buongiorno ${str(p['nome']).split(' ').first}, grazie per essere venuto da noi! Ci lasci un parere? Bastano 30 secondi: $linkRec — ${set['nome']}';
  final puoRec = s.modulo('recensioni') && str(p['data']).compareTo(oggi()) <= 0 && !['annullata', 'assente'].contains(p['stato']);
  final tel = str(p['telefono']);
  return showVModal(context, 'Appuntamento', (ctx) {
    final t = ctx.t;
    Future<void> stato(String st) async {
      Navigator.of(ctx).pop();
      await _cambia(context, p['id'], st);
    }

    final storia = jsonList(p['storia']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(alignment: Alignment.centerLeft, child: statoPill(kStatiPrenAdmin, str(p['stato']))),
      const Gap(12),
      Riep([
        ('Quando', '${fmtDate(str(p['data']))}, ${p['ora']}–${p['fine']}'),
        ('Servizio', '${p['servizio']}${p['durata'] != null ? ' (${p['durata']} min)' : ''}'),
        ('Immobile', str(p['immobile'])),
        ('Agente', str(p['collaboratore'])),
        ('Cliente', Text(str(p['nome']), style: const TextStyle(fontWeight: FontWeight.w700))),
        (
          'Telefono',
          tel.isEmpty
              ? ''
              : Wrap(alignment: WrapAlignment.end, children: [
                  TextLink(tel, 'tel:${telHref(tel)}', style: t.text(weight: FontWeight.w600, color: t.primary)),
                  Text(' · ', style: t.text()),
                  TextLink('WhatsApp', 'https://wa.me/${waNumber(tel)}?text=${Uri.encodeComponent(msg)}', style: t.text(weight: FontWeight.w600, color: t.primary)),
                ])
        ),
        ('Email', str(p['email']).isEmpty ? '' : TextLink(str(p['email']), 'mailto:${p['email']}?subject=${Uri.encodeComponent('Appuntamento ${set['nome']}')}&body=${Uri.encodeComponent(msg)}', style: t.text(weight: FontWeight.w600, color: t.primary))),
        ('Note', str(p['note'])),
        ('Origine', str(p['origine']).isEmpty ? 'sito' : str(p['origine'])),
        ('Modifiche', storia.isEmpty ? '' : storia.map((x) => '${x['data']} · ${x['evento']}').join('\n')),
      ]),
      const Gap(18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        VButton('Copia link del cliente', icon: 'copy', size: BtnSize.sm, onPressed: () {
          Clipboard.setData(ClipboardData(text: linkCliente));
          s.toast('Link del cliente copiato');
        }),
        if (puoRec && tel.isNotEmpty) VButton('Chiedi una recensione', icon: 'star', size: BtnSize.sm, kind: BtnKind.accent, href: 'https://wa.me/${waNumber(tel)}?text=${Uri.encodeComponent(msgRec)}'),
        if (puoRec && str(p['email']).isNotEmpty)
          VButton('Recensione via email', icon: 'mail', size: BtnSize.sm, href: "mailto:${p['email']}?subject=${Uri.encodeComponent("Com'è andata? ${set['nome']}")}&body=${Uri.encodeComponent(msgRec)}"),
      ]),
      const Gap(18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (p['stato'] == 'in_attesa') VButton('Conferma', icon: 'check', kind: BtnKind.primary, onAsync: () => stato('confermata')),
        if (['confermata', 'in_attesa'].contains(p['stato'])) ...[
          VButton('Completata', onAsync: () => stato('completata')),
          VButton('Non presentato', onAsync: () => stato('assente')),
          VButton('Annulla', kind: BtnKind.ghost, danger: true, onAsync: () => stato('annullata')),
        ] else
          VButton('Riporta a confermata', onAsync: () => stato('confermata')),
        VButton('Elimina', icon: 'trash', kind: BtnKind.ghost, danger: true, onAsync: () async {
          if (!await confirmDialog(ctx, 'Eliminare definitivamente questo appuntamento?')) return;
          await s.repo.prenElimina(p['id']);
          if (ctx.mounted) Navigator.of(ctx).pop();
          s.toast('Eliminato');
        }),
      ]),
    ]);
  });
}

/* ---------------- Nuova prenotazione (inserita dall'azienda) ---------------- */

void nuovaPrenotazione(BuildContext context, String data) {
  final s = App.read(context);
  final servizi = s.repo.prenServizi().values.toList();
  if (servizi.isEmpty) {
    s.toast('Aggiungi prima dei servizi prenotabili (con una durata) o dei servizi extra nelle impostazioni', err: true);
    return;
  }
  showVModal(context, 'Nuova prenotazione', (ctx) => _NuovaPren(state: s, servizi: servizi, data: data));
}

class _NuovaPren extends StatefulWidget {
  final AppState state;
  final List<Json> servizi;
  final String data;
  const _NuovaPren({required this.state, required this.servizi, required this.data});
  @override
  State<_NuovaPren> createState() => _NuovaPrenState();
}

class _NuovaPrenState extends State<_NuovaPren> {
  late String servizio = str(widget.servizi.first['id']);
  String coll = '', ora = '', statoP = 'confermata', oraManuale = '', immobile = '';
  late String data = widget.data;
  var forza = false;
  final nome = TextEditingController(), tel = TextEditingController(), email = TextEditingController(), note = TextEditingController();
  String? err;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final repo = widget.state.repo;
    final colls = jsonList(repo.prenConfig()['collaboratori']).where((c) => c['attivo'] != false).toList();
    final sv = widget.servizi.firstWhere((x) => x['id'] == servizio);
    final ore = repo.slotLiberi(data, sv, coll: coll, admin: true).keys.toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FieldLabel('Servizio', child: VSelect<String>(value: servizio, items: [for (final x in widget.servizi) (str(x['id']), '${x['nome']} (${x['durata']} min)')], onChanged: (v) => setState(() {
        servizio = v ?? servizio;
        ora = '';
      }))),
      if (norm(sv['nome']).contains('visita')) ...[
        const Gap(12),
        FieldLabel('Immobile da visitare', child: VSelect<String>(value: immobile, items: [('', 'Da definire'), for (final i in repo.items.where(immobileDisponibile)) (i['id'] as String, str(i['titolo']))], onChanged: (v) => setState(() => immobile = v ?? ''))),
      ],
      const Gap(12),
      TwoCols(
        colls.isNotEmpty
            ? FieldLabel('Agente', child: VSelect<String>(value: coll, items: [('', 'Assegna automaticamente'), for (final c in colls) (str(c['id']), str(c['nome']))], onChanged: (v) => setState(() {
                coll = v ?? '';
                ora = '';
              })))
            : const SizedBox.shrink(),
        FieldLabel('Giorno', child: DateInput(value: data, onChanged: (v) => setState(() {
          data = v.isEmpty ? data : v;
          ora = '';
        }))),
      ),
      const Gap(12),
      Text('Orari liberi', style: t.text(size: 14.1, weight: FontWeight.w600)),
      const Gap(6),
      ore.isEmpty
          ? Text('Nessun orario libero: scegli un altro giorno o inserisci un orario a scelta.', style: t.text(size: 14.1, color: t.muted))
          : Wrap(spacing: 6, runSpacing: 6, children: [for (final o in ore) OraChip(o, on: o == ora, onTap: () => setState(() => ora = o))]),
      const Gap(12),
      VCheck(value: forza, onChanged: (v) => setState(() => forza = v), label: const Text('Inserisci comunque a un orario a scelta (anche se occupato o fuori orario)')),
      if (forza) ...[const Gap(8), FieldLabel('Orario', child: TimeBox(value: oraManuale, label: 'Orario', onChanged: (v) => oraManuale = v))],
      const Gap(12),
      FieldLabel('Nome e cognome del cliente', child: VInput(controller: nome)),
      const Gap(12),
      TwoCols(FieldLabel('Telefono', child: VInput(controller: tel, keyboard: TextInputType.phone)), FieldLabel('Email', child: VInput(controller: email, keyboard: TextInputType.emailAddress))),
      const Gap(12),
      FieldLabel('Note', child: VInput(controller: note, minLines: 2, maxLines: 5)),
      const Gap(12),
      FieldLabel('Stato', child: VSelect<String>(value: statoP, items: const [('confermata', 'Confermata'), ('in_attesa', 'Da confermare')], onChanged: (v) => setState(() => statoP = v ?? 'confermata'))),
      const Gap(8),
      FormError(err),
      const Gap(8),
      VButton('Salva prenotazione', icon: 'check', kind: BtnKind.primary, block: true, onAsync: () async {
        final o = forza ? oraManuale : ora;
        if (o.isEmpty) {
          setState(() => err = 'Scegli un orario');
          return;
        }
        try {
          await repo.prenCrea({
            'servizio': servizio, 'collaboratore': coll, 'data': data, 'ora': o, 'forza': forza, 'stato': statoP, 'immobile': immobile,
            'nome': nome.text, 'telefono': tel.text, 'email': email.text, 'note': note.text,
          }, admin: true);
          if (!context.mounted) return;
          Navigator.of(context).pop();
          widget.state.toast('Prenotazione inserita');
          GoRouter.of(context).go('/admin/prenotazioni/agenda?data=$data');
        } on AppError catch (e) {
          setState(() => err = e.message);
        }
      }),
    ]);
  }
}

/* ---------------- Impostazioni delle prenotazioni ---------------- */

class _Impostazioni extends StatefulWidget {
  const _Impostazioni();
  @override
  State<_Impostazioni> createState() => _ImpostazioniState();
}

class _ImpostazioniState extends State<_Impostazioni> {
  late final s = App.read(context);
  late FormCtrl ctrl = _nuovo();

  FormCtrl _nuovo() {
    final servizi = s.repo.prenServizi().values.where((x) => !str(x['id']).startsWith('x-')).toList();
    final opzServ = [for (final x in servizi) Opt(str(x['id']), str(x['nome']))];
    final defs = withGroups([
      const FieldDef('conferma', 'Conferma delle prenotazioni', type: 'select', noEmpty: true, gruppo: 'Regole', options: [
        Opt('automatica', "Automatica: l'orario viene confermato subito"),
        Opt('manuale', 'Manuale: confermi tu ogni richiesta'),
      ]),
      const FieldDef('passo', 'Proponi un orario ogni', type: 'number', unit: 'minuti', min: 5, step: 5),
      const FieldDef('pausa', 'Pausa tra due appuntamenti', type: 'number', unit: 'minuti', min: 0, step: 5),
      const FieldDef('preavviso', 'Preavviso minimo', type: 'number', unit: 'ore', min: 0, step: 1),
      const FieldDef('anticipo', 'Prenotabile fino a', type: 'number', unit: 'giorni in avanti', min: 1, step: 1),
      const FieldDef('messaggio', 'Messaggio dopo la prenotazione', type: 'textarea', rows: 2, wide: true),
      const FieldDef('modificaCliente', 'Il cliente può spostare o annullare da solo, con il suo link personale', type: 'bool', wide: true),
      const FieldDef('limiteModificaOre', 'Fino a quante ore prima', type: 'number', unit: 'ore', min: 0, step: 1),
      const FieldDef('orari', 'Orari in cui si possono prenotare appuntamenti', type: 'orari', wide: true, gruppo: 'Orari e chiusure'),
      const FieldDef('chiusure', 'Chiusure e ferie', type: 'list', wide: true, nomeElemento: 'chiusura', fields: [
        FieldDef('dal', 'Dal', type: 'date'),
        FieldDef('al', 'Al (compreso)', type: 'date'),
        FieldDef('motivo', 'Motivo', placeholder: 'es. Ferie estive'),
      ]),
      FieldDef('collaboratori', 'Agenti',
          type: 'list',
          wide: true,
          gruppo: 'Agenti',
          nomeElemento: 'agente',
          hint: "Ogni agente ha la sua agenda: gli orari liberi sono calcolati per ciascuno e il cliente può scegliere con chi fare la visita. Senza agenti c'è un'unica agenda.",
          fields: [
            const FieldDef('nome', 'Nome', required: true),
            const FieldDef('ruolo', 'Ruolo', placeholder: 'es. Consulente immobiliare'),
            const FieldDef('attivo', 'Attivo (prenotabile)', type: 'bool', defaultValue: true),
            if (opzServ.isNotEmpty) FieldDef('servizi', 'Servizi che svolge (nessuno selezionato = tutti)', type: 'checks', wide: true, options: opzServ),
            const FieldDef('orariPropri', 'Ha orari diversi da quelli generali', type: 'bool'),
            const FieldDef('orari', "Orari dell'agente", type: 'orari', wide: true),
            const FieldDef('chiusure', 'Ferie / assenze', type: 'list', wide: true, nomeElemento: 'assenza', fields: [
              FieldDef('dal', 'Dal', type: 'date'),
              FieldDef('al', 'Al', type: 'date'),
              FieldDef('motivo', 'Motivo'),
            ]),
          ]),
      const FieldDef('servizi', 'Appuntamenti prenotabili',
          type: 'list',
          wide: true,
          gruppo: 'Servizi',
          nomeElemento: 'servizio',
          hint: "Gli appuntamenti che i clienti possono prenotare (es. «Visita di un immobile», «Valutazione gratuita»). Per quelli con la parola «visita» nel nome il cliente sceglie anche l'immobile.",
          fields: [
            FieldDef('nome', 'Nome', required: true),
            FieldDef('durata', 'Durata', type: 'number', unit: 'minuti', min: 5, step: 5),
            FieldDef('prezzo', 'Prezzo (vuoto se gratuito)', type: 'money', unit: '€'),
          ]),
    ], 'Regole');
    return FormCtrl(defs, s.repo.prenConfig());
  }

  @override
  Widget build(BuildContext context) {
    final servizi = s.repo.prenServizi().values.toList();
    final nomi = servizi.take(4).map((x) => x['nome']).join(', ');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AlertBox(child: Text.rich(TextSpan(children: [
        const TextSpan(text: 'Prenotabili ora: '),
        TextSpan(text: '${servizi.length}', style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: ' servizi${servizi.isNotEmpty ? ' ($nomi${servizi.length > 4 ? '…' : ''})' : ''}.'),
      ]))),
      VFormView(ctrl, groups: true),
      FormFoot(right: [
        VButton('Salva impostazioni', icon: 'check', kind: BtnKind.primary, onAsync: () async {
          if (!ctrl.validate()) return;
          final r = await s.run(() => s.repo.savePrenConfig({...s.repo.prenConfig(), ...ctrl.vals}));
          if (r == null) return;
          s.toast('Impostazioni delle prenotazioni salvate');
          setState(() => ctrl = _nuovo());
        }),
      ]),
    ]);
  }
}

