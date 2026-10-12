/// Recensioni dei clienti nell'area riservata: approvazione, risposta e impostazioni.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/preset.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../clienti/cards.dart';
import '../../dialogs.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';
import '../form/vform.dart';

/// Modulo impostazioni delle recensioni
class _RecConfigForm extends StatefulWidget {
  final List<FieldDef> defs;
  const _RecConfigForm({required this.defs});
  @override
  State<_RecConfigForm> createState() => _RecConfigFormState();
}

class _RecConfigFormState extends State<_RecConfigForm> {
  late final s = App.read(context);
  late final ctrl = FormCtrl(withGroups(widget.defs, widget.defs.first.gruppo ?? ''), s.repo.cfgModulo('recensioni'));

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        VFormView(ctrl, groups: true),
        FormFoot(right: [
          VButton('Salva impostazioni', icon: 'check', kind: BtnKind.primary, onAsync: () async {
            if (!ctrl.validate()) return;
            if (await s.run(() => s.repo.saveModConfig('recensioni', {...s.repo.cfgModulo('recensioni'), ...ctrl.vals})) != null) s.toast('Impostazioni salvate');
          }),
        ]),
      ]);
}

/* ================= Recensioni ================= */

const kStatiRec = {'in_attesa': ('Da approvare', 'warn'), 'pubblicata': ('Pubblicata', 'ok'), 'rifiutata': ('Rifiutata', 'err')};

class RecensioniAdmin extends StatelessWidget {
  final List<String> rest;
  const RecensioniAdmin({super.key, required this.rest});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    if (!s.modulo('recensioni')) return AlertBox.text('Le recensioni non sono attive: puoi attivarle da Impostazioni → Funzioni attive.');
    final vista = rest.isEmpty ? 'elenco' : rest[0];
    final lista = s.repo.recElenco(soloPubblicate: false)..sort((a, b) => (a['stato'] == 'in_attesa' ? 0 : 1).compareTo(b['stato'] == 'in_attesa' ? 0 : 1));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Recensioni', sub: 'Approva le recensioni dei clienti prima che compaiano sul sito e rispondi pubblicamente.', actions: [
        VButton('Vedi sul sito', icon: 'eye', kind: BtnKind.ghost, onPressed: () => openLink(context, '#/recensioni', newTab: true)),
      ]),
      SubTabs(base: 'recensioni', current: vista, tabs: const [('elenco', 'Recensioni'), ('impostazioni', 'Impostazioni')]),
      if (vista == 'impostazioni')
        const _RecConfigForm(defs: [
          FieldDef('approvazione', 'Pubblicazione', type: 'select', noEmpty: true, gruppo: 'Regole', options: [Opt('manuale', 'Le approvo io prima della pubblicazione'), Opt('automatica', 'Pubblica subito')]),
          FieldDef('aperte', 'Chiunque può lasciare una recensione (se disattivo: solo chi ha prenotato, con il suo link)', type: 'bool', wide: true),
          FieldDef('googleUrl', 'Link per le recensioni su Google (facoltativo)', type: 'url', wide: true, placeholder: 'https://g.page/r/…/review', hint: 'Dopo aver lasciato la recensione sul sito, al cliente viene proposto di lasciarla anche su Google.'),
        ])
      else if (lista.isEmpty)
        const EmptyState(icon: 'star', small: true, text: 'Nessuna recensione ancora.')
      else
        AutoGrid(minWidth: 270, gap: 20, equalHeight: false, children: [for (final r in lista) _RecAdmin(r: r, key: ValueKey(r['id']))]),
    ]);
  }
}

class _RecAdmin extends StatefulWidget {
  final Json r;
  const _RecAdmin({super.key, required this.r});
  @override
  State<_RecAdmin> createState() => _RecAdminState();
}

class _RecAdminState extends State<_RecAdmin> {
  late final _risp = TextEditingController(text: str(widget.r['risposta']));
  @override
  void dispose() {
    _risp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final r = widget.r;
    return ReviewTile(
      r,
      admin: true,
      footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Gap(12),
        VInput(controller: _risp, minLines: 2, maxLines: 6, hint: 'Rispondi pubblicamente (facoltativo)'),
        const Gap(12),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          statoPill(kStatiRec, str(r['stato'])),
          Text(quando(r['creato']), style: t.text(size: 13.1, color: t.muted)),
        ]),
        const Gap(12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (r['stato'] != 'pubblicata') VButton('Pubblica', icon: 'check', size: BtnSize.sm, kind: BtnKind.primary, onAsync: () => s.repo.recStato(r['id'], 'pubblicata')),
          if (r['stato'] != 'rifiutata') VButton('Rifiuta', size: BtnSize.sm, onAsync: () => s.repo.recStato(r['id'], 'rifiutata')),
          VButton('Salva risposta', size: BtnSize.sm, onAsync: () async {
            await s.repo.recRisposta(r['id'], _risp.text);
            s.toast('Risposta salvata');
          }),
          IconBtn('trash', tooltip: 'Elimina', danger: true, onPressed: () async {
            if (await confirmDialog(context, 'Eliminare la recensione?')) await s.repo.recElimina(r['id']);
          }),
        ]),
      ]),
    );
  }
}
