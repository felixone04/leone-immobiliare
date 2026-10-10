/// Cassa: verifica di un codice qualsiasi e operazioni sulle carte (gift card, fedeltà, pacchetti, coupon).
library;

import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../clienti/cards.dart';
import '../../dialogs.dart';
import '../../forms_public.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';

class CassaAdmin extends StatelessWidget {
  const CassaAdmin({super.key});
  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AdminHead('Cassa', sub: 'Verifica e usa gift card, tessere fedeltà, pacchetti e coupon presentati dai clienti.'),
        BoxCassa(autofocus: true),
      ]);
}

/// Casella "verifica un codice" (Cassa e Panoramica)
class BoxCassa extends StatefulWidget {
  final bool autofocus;
  const BoxCassa({super.key, this.autofocus = false});
  @override
  State<BoxCassa> createState() => _BoxCassaState();
}

class _BoxCassaState extends State<BoxCassa> {
  final _c = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _cerca() {
    final s = App.read(context);
    setState(() => _err = null);
    try {
      final (tipo, carta) = s.repo.cassa(_c.text);
      _c.clear();
      apriCarta(context, tipo, carta);
    } on AppError catch (e) {
      setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BoxTitle('Verifica un codice', icon: 'search'),
        Text('Gift card, tessera fedeltà, pacchetto o coupon: scrivi il codice che ti mostra il cliente.', style: t.text(size: 14.1, color: t.muted)),
        const Gap(12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
            child: VInput(controller: _c, hint: 'es. GC-AB12-CD34', autofocus: widget.autofocus, caps: TextCapitalization.characters, onSubmitted: (_) => _cerca(), style: t.text(size: 16, spacing: 1)),
          ),
          VButton('Cerca', kind: BtnKind.primary, onPressed: _cerca),
        ]),
        const Gap(6),
        FormError(_err),
      ]),
    );
  }
}

/// Finestra con la carta e le operazioni possibili.
Future<void> apriCarta(BuildContext context, String tipo, Json c, {VoidCallback? dopo}) async {
  final s = App.read(context);
  await showVModal(context, str(c['codice']), (ctx) => _CartaOps(state: s, tipo: tipo, c: c, dopo: dopo), wide: true);
}

class _CartaOps extends StatefulWidget {
  final AppState state;
  final String tipo;
  final Json c;
  final VoidCallback? dopo;
  const _CartaOps({required this.state, required this.tipo, required this.c, this.dopo});
  @override
  State<_CartaOps> createState() => _CartaOpsState();
}

class _CartaOpsState extends State<_CartaOps> {
  late Json c = widget.c;
  final _nota = TextEditingController();
  late final _imp = TextEditingController(text: str(c['saldo']));
  final _n = TextEditingController(text: '1');

  @override
  void dispose() {
    for (final x in [_nota, _imp, _n]) {
      x.dispose();
    }
    super.dispose();
  }

  Repo get repo => widget.state.repo;

  Future<void> _op(Future<Json> Function() f) async {
    final r = await widget.state.run(f);
    if (r == null) return;
    widget.state.toast('Operazione registrata');
    widget.dopo?.call();
    setState(() {
      c = widget.tipo == 'fedelta' ? {...c, ...r} : r;
      _imp.text = str(c['saldo']);
      _nota.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final gift = widget.tipo == 'giftcard';
    final attiva = c['stato'] == 'attiva';
    final azioni = <Widget>[];
    if (gift) {
      if (c['stato'] == 'da_pagare') azioni.add(VButton('Pagata in struttura', icon: 'check', kind: BtnKind.primary, onAsync: () => _op(() => repo.gcPaga(c['id']))));
      if (attiva) {
        if (str(c['proposta']).isNotEmpty) {
          azioni.add(VButton('Segna come utilizzata', kind: BtnKind.primary, onAsync: () => _op(() => repo.gcUsa(c['id'], tutto: true, nota: _nota.text))));
        } else {
          azioni.addAll([
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Importo da scalare ', style: t.text(weight: FontWeight.w600)),
              SizedBox(width: 90, child: VInput(controller: _imp, dense: true, keyboard: const TextInputType.numberWithOptions(decimal: true))),
              Text(' €', style: t.text(weight: FontWeight.w600)),
            ]),
            VButton('Scala importo', kind: BtnKind.primary, onAsync: () => _op(() => repo.gcUsa(c['id'], importo: _imp.text, nota: _nota.text))),
          ]);
        }
      }
    } else if (widget.tipo == 'fedelta' && attiva) {
      azioni.addAll([
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Aggiungi ', style: t.text(weight: FontWeight.w600)),
          SizedBox(width: 70, child: VInput(controller: _n, dense: true, keyboard: TextInputType.number)),
          Text(' ${str(c['unita']).isEmpty ? 'timbri' : c['unita']}', style: t.text(weight: FontWeight.w600)),
        ]),
        VButton('Aggiungi', icon: 'plus', kind: BtnKind.primary, onAsync: () => _op(() => repo.tesseraAzione(c['id'], 'aggiungi', n: intOf(_n.text, 1), nota: _nota.text))),
        VButton('Togli 1', onAsync: () => _op(() => repo.tesseraAzione(c['id'], 'togli', nota: _nota.text))),
        if (intOf(c['saldo']) >= intOf(c['obiettivo'], 1)) VButton('Consegna premio', icon: 'gift', kind: BtnKind.accent, onAsync: () => _op(() => repo.tesseraAzione(c['id'], 'riscatta', nota: _nota.text))),
      ]);
    } else if (widget.tipo == 'pacchetto') {
      if (c['stato'] == 'da_pagare') azioni.add(VButton('Pagato in struttura', icon: 'check', kind: BtnKind.primary, onAsync: () => _op(() => repo.tesseraAzione(c['id'], 'paga', nota: _nota.text))));
      if (attiva) azioni.add(VButton('Usa una seduta', icon: 'check', kind: BtnKind.primary, onAsync: () => _op(() => repo.tesseraAzione(c['id'], 'usa', nota: _nota.text))));
    } else if (widget.tipo == 'coupon' && attiva) {
      azioni.add(VButton('Segna come utilizzato', icon: 'check', kind: BtnKind.primary, onAsync: () => _op(() => repo.tesseraAzione(c['id'], 'usa', nota: _nota.text))));
    }
    final info = gift
        ? (str(c['proposta']).isNotEmpty ? 'Valida per: ${c['proposta']}' : 'Saldo: ${euro(c['saldo'])} di ${euro(c['valore'])}')
        : widget.tipo == 'fedelta'
            ? '${c['saldo']} ${c['unita']} · premi consegnati: ${c['premi']}'
            : widget.tipo == 'pacchetto'
                ? 'Sedute rimaste: ${c['saldo']} di ${c['valore']}${c['prezzo'] != null ? ' · prezzo ${euro(c['prezzo'])}' : ''}'
                : '${c['offerta']}${str(c['sconto']).isNotEmpty ? ' · ${c['sconto']}' : ''}';
    final mov = jsonList(c['movimenti']).reversed.take(15).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Transform.scale(scale: .94, child: CardVisual(widget.tipo, gift ? {...c, 'daParte': c['nome']} : c))),
      const Gap(8),
      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [statoPill(kStatiCarta, str(c['stato'])), Text(info, style: t.text())]),
      const Gap(12),
      Riep([
        ('Intestatario', str(c['nome'])),
        ('Telefono', str(c['telefono']).isEmpty ? '' : TextLink(str(c['telefono']), 'tel:${telHref(str(c['telefono']))}', style: t.text(weight: FontWeight.w600, color: t.primary))),
        ('Email', str(c['email'])),
        ('Scadenza', str(c['scadenza']).isEmpty ? '' : fmtDateLong(str(c['scadenza']))),
      ]),
      if (azioni.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.bg, borderRadius: t.rSm),
          child: Column(children: [
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: azioni),
            const Gap(8),
            VInput(controller: _nota, hint: 'Nota (facoltativa)', dense: true),
          ]),
        ),
      if (mov.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text('Movimenti', style: t.title(size: 15.2, color: t.ink2, weight: FontWeight.w700))),
        for (final x in mov)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '${x['data']}  ', style: TextStyle(color: t.muted)),
              TextSpan(
                  text:
                      '${x['tipo']}${x['quantita'] != null ? ' ${intOf(x['quantita']) > 0 ? '+' : ''}${x['quantita']}' : ''}${x['importo'] != null ? ' −${euro(x['importo'])}' : ''}${str(x['nota']).isNotEmpty ? ' · ${x['nota']}' : ''}'),
            ]), style: t.text(size: 14.1)),
          ),
      ],
      if (['attiva', 'da_pagare'].contains(c['stato']))
        Padding(
          padding: const EdgeInsets.only(top: 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: VButton('Annulla carta', kind: BtnKind.ghost, danger: true, onAsync: () async {
              if (!await confirmDialog(context, 'Annullare questa carta?')) return;
              await _op(() => gift ? repo.gcAnnulla(c['id']) : repo.tesseraAzione(c['id'], 'annulla'));
            }),
          ),
        ),
    ]);
  }
}

/// Elenco delle carte di un tipo, con ricerca (fedeltà, pacchetti, coupon)
class ElencoCarte extends StatefulWidget {
  final String tipo;
  final List<(String, Widget Function(Json c))> colonne;
  const ElencoCarte({super.key, required this.tipo, required this.colonne});
  @override
  State<ElencoCarte> createState() => _ElencoCarteState();
}

class _ElencoCarteState extends State<ElencoCarte> {
  var _q = '';
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final lista = s.repo.tessLista(widget.tipo, _q);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminSearch(hint: 'Cerca per codice, nome, telefono…', onChanged: (v) => setState(() => _q = v)),
      if (lista.isEmpty)
        EmptyState(icon: 'search', small: true, text: 'Nessuna carta${_q.isNotEmpty ? ' trovata' : ' ancora'}.')
      else
        AdminTable(
          head: ['Codice', 'Intestatario', for (final (h, _) in widget.colonne) h, 'Stato', ''],
          rows: [
            for (final c in lista)
              [
                CodeTag(str(c['codice'])),
                Cell2(str(c['nome']), sub: str(c['telefono']).isNotEmpty ? str(c['telefono']) : str(c['email']), bold: false),
                for (final (_, f) in widget.colonne) f(c),
                statoPill(kStatiCarta, str(c['stato'])),
                Align(alignment: Alignment.centerRight, child: VButton('Gestisci', size: BtnSize.sm, kind: BtnKind.primary, onPressed: () => apriCarta(context, widget.tipo, c, dopo: () => setState(() {})))),
              ],
          ],
        ),
      if (lista.isNotEmpty) Text('', style: t.text(size: 1)),
    ]);
  }
}

/// Riquadro "Da fare" della panoramica
class DaFare extends StatelessWidget {
  final Map<String, int> c;
  const DaFare(this.c, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final voci = [
      (c['messaggi'] ?? 0, 'mail', c['messaggi'] == 1 ? 'nuovo messaggio' : 'nuovi messaggi', 'messaggi'),
      (c['prenotazioni'] ?? 0, 'calendar', c['prenotazioni'] == 1 ? 'prenotazione da confermare' : 'prenotazioni da confermare', 'prenotazioni'),
      (c['attesa'] ?? 0, 'clock', "in lista d'attesa: si è liberato un posto", 'prenotazioni/attesa'),
      (c['recensioni'] ?? 0, 'star', c['recensioni'] == 1 ? 'recensione da approvare' : 'recensioni da approvare', 'recensioni'),
    ].where((v) => v.$1 > 0).toList();
    if (voci.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: const Color(0xFFFFFAF2), border: Border.all(color: mix(VTheme.warn, .35, Colors.white)), borderRadius: t.r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BoxTitle('Da fare', icon: 'check', size: 17.6),
        for (final (n, ic, l, h) in voci)
          Hover(
            onTap: () => openLink(context, '#/admin/$h'),
            builder: (_, hv) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: hv ? Colors.white : null, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                VIcon(ic, color: VTheme.warn),
                const SizedBox(width: 8),
                Text('$n', style: t.text(weight: FontWeight.w700)),
                const SizedBox(width: 4),
                Expanded(child: Text(l, style: t.text())),
              ]),
            ),
          ),
      ]),
    );
  }
}
