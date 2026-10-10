/// Gift card: elenco, attivazione al pagamento, utilizzo, vendita in sede e impostazioni.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/preset.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../clienti/cards.dart';
import '../../dialogs.dart';
import '../../forms_public.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';
import '../form/vform.dart';
import 'cassa.dart';

class GiftcardAdmin extends StatefulWidget {
  final List<String> rest;
  const GiftcardAdmin({super.key, required this.rest});
  @override
  State<GiftcardAdmin> createState() => _GiftcardAdminState();
}

class _GiftcardAdminState extends State<GiftcardAdmin> {
  var _q = '';

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    if (!s.modulo('prenotazioni')) return AlertBox.text('Le gift card sono disponibili solo con il modulo prenotazioni attivo (Impostazioni → Funzioni attive).');
    final vista = widget.rest.isEmpty ? 'elenco' : widget.rest[0];
    final cfg = s.repo.gcConfig();
    final head = [
      AdminHead('Gift card', sub: 'Il cliente la richiede dal sito e la paga in struttura: attivala quando ricevi il pagamento.', actions: [
        VButton('Gift card venduta in sede', icon: 'plus', kind: BtnKind.primary, onPressed: () => _nuova(context, cfg)),
      ]),
      SubTabs(base: 'giftcard', current: vista, tabs: const [('elenco', 'Elenco e utilizzo'), ('impostazioni', 'Impostazioni')]),
    ];
    if (vista == 'impostazioni') return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...head, const _GcImpostazioni()]);
    final lista = s.repo.gcLista(_q);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...head,
      if (cfg['attiva'] != true)
        AlertBox(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('La vendita sul sito è disattivata: attivala da '),
            TextLink('Impostazioni', '#/admin/giftcard/impostazioni', style: t.text(color: t.primary)),
            const Text('. Puoi comunque registrare gift card vendute in sede.'),
          ]),
        ),
      AdminSearch(hint: 'Cerca per codice o nome (es. GC-AB12)…', onChanged: (v) => setState(() => _q = v)),
      if (lista.isEmpty)
        EmptyState(icon: 'gift', small: true, text: 'Nessuna gift card${_q.isNotEmpty ? ' trovata' : ' ancora'}.')
      else
        AdminTable(head: const ['Codice', 'Per / da', 'Valore', 'Saldo', 'Stato', 'Scadenza', ''], rows: [
          for (final g in lista)
            [
              Hover(onTap: () => apriCarta(context, 'giftcard', g, dopo: () => setState(() {})), builder: (_, h) => CodeTag(str(g['codice']))),
              Cell2(str(g['destinatario']).isEmpty ? '—' : str(g['destinatario']), sub: 'da ${g['nome']}${str(g['telefono']).isNotEmpty ? ' · ${g['telefono']}' : ''}', bold: false),
              Cell2(str(g['proposta']).isNotEmpty ? str(g['proposta']) : euro(g['valore']), sub: str(g['proposta']).isNotEmpty ? euro(g['valore']) : null, bold: false),
              Text(str(g['proposta']).isNotEmpty ? (g['stato'] == 'utilizzata' ? '—' : '1 utilizzo') : euro(g['saldo']), style: t.text(size: 14.9)),
              statoPill(kStatiCarta, str(g['stato'])),
              Text(fmtDateShort(str(g['scadenza'])), style: t.text(size: 14.9)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (g['stato'] == 'da_pagare')
                  VButton('Pagata', size: BtnSize.sm, kind: BtnKind.primary, onAsync: () async {
                    if (!await confirmDialog(context, 'Confermi di aver ricevuto il pagamento di ${euro(g['valore'])} per la gift card ${g['codice']}?')) return;
                    if (await s.run(() => s.repo.gcPaga(g['id'])) != null) s.toast('Gift card attivata');
                  }),
                if (g['stato'] == 'attiva') VButton('Usa', size: BtnSize.sm, kind: BtnKind.accent, onPressed: () => apriCarta(context, 'giftcard', g, dopo: () => setState(() {}))),
                IconBtn('printer', tooltip: 'Vedi / stampa', onPressed: () => openLink(context, '#/giftcard/${g['codice']}', newTab: true)),
              ]),
            ],
        ]),
    ]);
  }

  void _nuova(BuildContext context, Json cfg) {
    final s = App.read(context);
    final sugg = cfg['suggeriti'] as List;
    final imp = TextEditingController(text: str(sugg.length > 1 ? sugg[1] : 50));
    final dest = TextEditingController(), msg = TextEditingController(), nome = TextEditingController(), tel = TextEditingController(), email = TextEditingController();
    var pagata = true;
    String? err;
    showVModal(context, 'Gift card venduta in sede', (ctx) {
      return StatefulBuilder(builder: (ctx, setM) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FieldLabel('Importo', child: Row(children: [Expanded(child: VInput(controller: imp, keyboard: const TextInputType.numberWithOptions(decimal: true))), const SizedBox(width: 8), const Text('€')])),
          const Gap(12),
          FieldLabel('Per (destinatario)', child: VInput(controller: dest)),
          const Gap(12),
          FieldLabel('Dedica', child: VInput(controller: msg, minLines: 2, maxLines: 4, maxLength: 400)),
          const Gap(12),
          FieldLabel('Acquirente (nome e cognome)', child: VInput(controller: nome)),
          const Gap(12),
          TwoCols(FieldLabel('Telefono', child: VInput(controller: tel, keyboard: TextInputType.phone)), FieldLabel('Email', child: VInput(controller: email, keyboard: TextInputType.emailAddress))),
          const Gap(12),
          VCheck(value: pagata, onChanged: (v) => setM(() => pagata = v), label: const Text('Già pagata (attiva subito)')),
          const Gap(8),
          FormError(err),
          const Gap(8),
          VButton('Crea gift card', icon: 'gift', kind: BtnKind.primary, block: true, onAsync: () async {
            try {
              final g = await s.repo.gcCrea({
                'tipo': 'importo', 'importo': imp.text, 'destinatario': dest.text, 'messaggio': msg.text,
                'nome': nome.text, 'telefono': tel.text, 'email': email.text, 'stato': pagata ? 'attiva' : 'da_pagare',
              }, admin: true);
              if (ctx.mounted) Navigator.of(ctx).pop();
              s.toast('Gift card ${g['codice']} creata');
              if (context.mounted) openLink(context, '#/giftcard/${g['codice']}', newTab: true);
            } on AppError catch (e) {
              setM(() => err = e.message);
            }
          }),
        ]);
      });
    });
  }
}

class _GcImpostazioni extends StatefulWidget {
  const _GcImpostazioni();
  @override
  State<_GcImpostazioni> createState() => _GcImpostazioniState();
}

class _GcImpostazioniState extends State<_GcImpostazioni> {
  late final s = App.read(context);
  late final cfg = s.repo.gcConfig();
  late final ctrl = FormCtrl(_defs(), {...cfg, 'suggeriti': (cfg['suggeriti'] as List).map((v) => str(v)).join(', ')});

  List<FieldDef> _defs() {
    final voci = s.repo.gcVoci;
    return withGroups([
      const FieldDef('attiva', 'Vendi gift card sul sito', type: 'bool', wide: true, gruppo: 'Vendita sul sito', hint: 'Compaiono nel menu e nella pagina "Gift card". Il pagamento avviene solo in struttura.'),
      const FieldDef('titolo', 'Titolo della pagina', wide: true),
      const FieldDef('testo', 'Testo introduttivo', type: 'textarea', rows: 2, wide: true),
      const FieldDef('pagamento', 'Istruzioni per il pagamento in struttura', type: 'textarea', rows: 2, wide: true),
      const FieldDef('validitaMesi', 'Validità', type: 'number', unit: 'mesi', min: 1, step: 1),
      const FieldDef('libero', "Il cliente può scegliere l'importo", type: 'bool', gruppo: 'Importo a scelta'),
      const FieldDef('minimo', 'Importo minimo', type: 'money', unit: '€', min: 1, step: 1, required: true),
      const FieldDef('massimo', 'Importo massimo (0 = nessun limite)', type: 'money', unit: '€', min: 0, step: 1),
      const FieldDef('suggeriti', 'Importi suggeriti', placeholder: '25, 50, 100, 150', hint: 'Separati da virgola'),
      if (voci.isNotEmpty) FieldDef('catalogo', 'Trattamenti e prodotti del catalogo regalabili', type: 'checks', wide: true, gruppo: 'Proposte da regalare', options: voci),
      FieldDef('proposte', 'Altre proposte (pacchetti, esperienze…)', type: 'list', wide: true, gruppo: voci.isEmpty ? 'Proposte da regalare' : null, nomeElemento: 'proposta', fields: const [
        FieldDef('nome', 'Nome', required: true),
        FieldDef('prezzo', 'Prezzo', type: 'money', unit: '€', required: true),
        FieldDef('descrizione', 'Descrizione', type: 'textarea', rows: 2, wide: true),
        FieldDef('immagine', 'Immagine', type: 'image', wide: true),
      ]),
    ], 'Vendita sul sito');
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      VFormView(ctrl, groups: true),
      FormFoot(right: [
        VButton('Salva impostazioni', icon: 'check', kind: BtnKind.primary, onAsync: () async {
          if (!ctrl.validate()) return;
          final v = ctrl.vals;
          if (!(doubleOf(v['minimo']) > 0)) {
            s.toast("L'importo minimo deve essere maggiore di zero", err: true);
            return;
          }
          v['suggeriti'] = [for (final x in str(v['suggeriti']).split(RegExp(r'[,;\s]+'))) if (doubleOf(x) > 0) doubleOf(x)];
          if (await s.run(() => s.repo.gcSaveConfig({...cfg, ...v})) != null) s.toast('Impostazioni gift card salvate');
        }),
      ]),
    ]);
  }
}
