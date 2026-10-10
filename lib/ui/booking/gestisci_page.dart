/// #/mia-prenotazione/ID: il cliente rivede, sposta o annulla l'appuntamento con il suo link personale.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../dialogs.dart';
import '../forms_public.dart';
import '../inputs.dart';
import '../kit.dart';
import '../shell.dart';
import 'booking_widgets.dart';

const kStatiPren = {
  'in_attesa': ('In attesa di conferma', 'warn'),
  'confermata': ('Confermata', 'ok'),
  'annullata': ('Annullata', 'err'),
  'completata': ('Completata', 'muted'),
  'assente': ('Non presentato', 'err'),
};

class GestisciPage extends StatefulWidget {
  final String id;
  const GestisciPage({super.key, required this.id});
  @override
  State<GestisciPage> createState() => _GestisciPageState();
}

class _GestisciPageState extends State<GestisciPage> {
  var _sposta = false;
  Map<String, int> _giorni = {};
  String _data = '', _ora = '';
  String? _err;

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Json? p;
    try {
      p = s.repo.prenCliente(widget.id);
    } on AppError {
      p = null;
    }
    Widget body;
    if (p == null) {
      body = const EmptyState(icon: 'calendar', title: 'Prenotazione non trovata', text: 'Controlla il link o contattaci.', actions: [VButton('Contatti', kind: BtnKind.primary, href: '#/p/contatti')]);
    } else {
      final set = s.settings;
      final pr = p;
      final tel = str(set['telefono']);
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: CardBox(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: Alignment.centerLeft, child: statoPill(kStatiPren, str(pr['stato']))),
              const SizedBox(height: 12),
              Text(str(pr['servizio']), style: t.title(size: t.h2(context))),
              const SizedBox(height: 12),
              Riep([
                ('Quando', '${fmtDate(str(pr['data']))}, ${pr['ora']}–${pr['fine']}'),
                ('Con', str(pr['collaboratore'])),
                ('Dove', str(set['indirizzo'])),
                ('A nome di', str(pr['nome'])),
                ('Codice', Text(codicePren(pr['id']), style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 20),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (pr['modificabile'] == true) ...[
                  VButton('Sposta', icon: 'calendar', kind: BtnKind.outline, onPressed: () => setState(() {
                    _sposta = true;
                    _giorni = s.repo.prenGiorniSposta(widget.id);
                  })),
                  VButton('Annulla appuntamento', icon: 'x', kind: BtnKind.ghost, danger: true, onAsync: () async {
                    if (!await confirmDialog(context, "Vuoi davvero annullare l'appuntamento?")) return;
                    final ok = await s.run(() => s.repo.prenClienteAnnulla(widget.id));
                    if (ok != null) {
                      s.toast('Appuntamento annullato');
                      setState(() => _sposta = false);
                    }
                  }),
                ],
                if (pr['passata'] == true && s.modulo('recensioni') && !['annullata', 'assente'].contains(pr['stato']))
                  VButton('Lascia una recensione', icon: 'star', kind: BtnKind.accent, href: '#/recensioni?pren=${pr['id']}'),
              ]),
              if (pr['modificabile'] != true && ['in_attesa', 'confermata'].contains(pr['stato']) && pr['passata'] != true)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(children: [
                    Text('${pr['motivo']}', style: t.text(size: 14.1, color: t.muted)),
                    if (tel.isNotEmpty) ...[Text(' Tel. ', style: t.text(size: 14.1, color: t.muted)), TextLink(tel, 'tel:${telHref(tel)}', style: t.text(size: 14.1, color: t.primary))],
                  ]),
                ),
              if (_sposta) ...[
                const SizedBox(height: 22),
                Text('Scegli il nuovo giorno', style: t.title(size: 16.8, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                CalGrid(giorni: _giorni, sel: _data, onTap: (d) => setState(() {
                  _data = d;
                  _ora = '';
                })),
                if (_data.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Text('Scegli il nuovo orario', style: t.title(size: 16.8, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  OreGrid(ore: s.repo.prenSlotSposta(widget.id, _data), sel: _ora, onTap: (o) => setState(() => _ora = o)),
                ],
                if (_ora.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  VButton('Sposta a ${fmtDate(_data)} alle $_ora', icon: 'check', kind: BtnKind.primary, block: true, onAsync: () async {
                    try {
                      await s.repo.prenClienteSposta(widget.id, _data, _ora);
                      s.toast('Appuntamento spostato');
                      setState(() {
                        _sposta = false;
                        _data = _ora = '';
                        _err = null;
                      });
                    } on AppError catch (e) {
                      setState(() => _err = e.message);
                    }
                  }),
                ],
                FormError(_err),
              ],
            ]),
          ),
        ),
      );
    }
    return PageScroll(children: [
      const PageHero('La tua prenotazione', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }
}
