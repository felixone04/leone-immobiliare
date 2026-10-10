/// Funzioni per i clienti nell'area riservata: fedeltà, pacchetti, offerte e coupon, recensioni.
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

Widget _nonAttivo(String nome) => AlertBox.text('$nome non è attiva per questo sito: puoi attivarla da Impostazioni → Funzioni attive.');

/// Modulo impostazioni di una funzione (fedelta, pacchetti, offerte, recensioni)
class ModConfigForm extends StatefulWidget {
  final String modulo;
  final List<FieldDef> defs;
  const ModConfigForm({super.key, required this.modulo, required this.defs});
  @override
  State<ModConfigForm> createState() => _ModConfigFormState();
}

class _ModConfigFormState extends State<ModConfigForm> {
  late final s = App.read(context);
  late final ctrl = FormCtrl(withGroups(widget.defs, widget.defs.first.gruppo ?? ''), s.repo.cfgModulo(widget.modulo));

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
            if (await s.run(() => s.repo.saveModConfig(widget.modulo, {...s.repo.cfgModulo(widget.modulo), ...ctrl.vals})) != null) s.toast('Impostazioni salvate');
          }),
        ]),
      ]);
}

/* ================= Fedeltà ================= */

class FedeltaAdmin extends StatefulWidget {
  final List<String> rest;
  const FedeltaAdmin({super.key, required this.rest});
  @override
  State<FedeltaAdmin> createState() => _FedeltaAdminState();
}

class _FedeltaAdminState extends State<FedeltaAdmin> {
  var _gen = 0;

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    if (!s.modulo('fedelta')) return _nonAttivo('La tessera fedeltà');
    final vista = widget.rest.isEmpty ? 'tessere' : widget.rest[0];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Tessera fedeltà', sub: 'Timbri o punti raccolti dai clienti a ogni visita.', actions: [
        VButton('Nuova tessera', icon: 'plus', kind: BtnKind.primary, onPressed: () => _nuova(context)),
      ]),
      SubTabs(base: 'fedelta', current: vista, tabs: const [('tessere', 'Tessere'), ('impostazioni', 'Impostazioni')]),
      if (vista == 'impostazioni')
        const ModConfigForm(modulo: 'fedelta', defs: [
          FieldDef('obiettivo', 'Obiettivo per il premio', type: 'number', min: 1, step: 1, required: true, gruppo: 'Regole'),
          FieldDef('unita', 'Cosa si raccoglie', type: 'select', noEmpty: true, options: [Opt('timbri', 'Timbri'), Opt('punti', 'Punti'), Opt('visite', 'Visite')]),
          FieldDef('perVisita', 'Quanti per ogni visita (proposti in cassa)', type: 'number', min: 1, step: 1),
          FieldDef('premio', 'Premio', required: true, wide: true, placeholder: 'es. Un massaggio di 30 minuti in omaggio'),
          FieldDef('regole', 'Come funziona (testo per i clienti)', type: 'textarea', rows: 3, wide: true),
          FieldDef('richiestaOnline', 'I clienti possono richiedere la tessera dal sito', type: 'bool', wide: true),
        ])
      else
        ElencoCarte(key: ValueKey(_gen), tipo: 'fedelta', colonne: [
          ('Raccolti', (c) => Text('${c['saldo']}', style: t.text(weight: FontWeight.w700))),
          ('Premi', (c) => Text('${c['premi']}', style: t.text())),
        ]),
    ]);
  }

  void _nuova(BuildContext context) {
    final s = App.read(context);
    showVModal(context, 'Nuova tessera fedeltà', (ctx) => ContattoFormAdmin(
          bottone: 'Crea tessera',
          onSubmit: (d) async {
            final c = await s.repo.tesseraCrea('fedelta', d, admin: true);
            if (ctx.mounted) Navigator.of(ctx).pop();
            s.toast('Tessera ${c['codice']} creata');
            setState(() => _gen++);
            if (context.mounted) apriCarta(context, 'fedelta', c, dopo: () => setState(() => _gen++));
          },
        ));
  }
}

/// Dati del cliente inseriti dall'azienda (nome, telefono, email)
class ContattoFormAdmin extends StatefulWidget {
  final String bottone;
  final Future<void> Function(Json d) onSubmit;
  final List<Widget> extraTop, extraBottom;
  final Json Function()? extraValues;
  const ContattoFormAdmin({super.key, required this.bottone, required this.onSubmit, this.extraTop = const [], this.extraBottom = const [], this.extraValues});
  @override
  State<ContattoFormAdmin> createState() => _ContattoFormAdminState();
}

class _ContattoFormAdminState extends State<ContattoFormAdmin> {
  final nome = TextEditingController(), tel = TextEditingController(), email = TextEditingController();
  String? err;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...widget.extraTop,
        FieldLabel('Nome e cognome', child: VInput(controller: nome)),
        const Gap(12),
        TwoCols(FieldLabel('Telefono', child: VInput(controller: tel, keyboard: TextInputType.phone)), FieldLabel('Email', child: VInput(controller: email, keyboard: TextInputType.emailAddress))),
        ...widget.extraBottom,
        const Gap(8),
        FormError(err),
        const Gap(8),
        VButton(widget.bottone, icon: 'plus', kind: BtnKind.primary, block: true, onAsync: () async {
          try {
            await widget.onSubmit({'nome': nome.text, 'telefono': tel.text, 'email': email.text, ...?widget.extraValues?.call()});
          } on AppError catch (e) {
            setState(() => err = e.message);
          }
        }),
      ]);
}

/* ================= Pacchetti ================= */

class PacchettiAdmin extends StatefulWidget {
  final List<String> rest;
  const PacchettiAdmin({super.key, required this.rest});
  @override
  State<PacchettiAdmin> createState() => _PacchettiAdminState();
}

class _PacchettiAdminState extends State<PacchettiAdmin> {
  var _gen = 0;

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    if (!s.modulo('pacchetti')) return _nonAttivo('La funzione Pacchetti');
    final vista = widget.rest.isEmpty ? 'venduti' : widget.rest[0];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Pacchetti a sedute', sub: 'Il cliente li richiede dal sito e li paga in struttura; tu scali le sedute a ogni visita.', actions: [
        VButton('Pacchetto venduto in sede', icon: 'plus', kind: BtnKind.primary, onPressed: () => _nuovo(context)),
      ]),
      SubTabs(base: 'pacchetti', current: vista, tabs: const [('venduti', 'Pacchetti dei clienti'), ('offerti', 'Pacchetti in vendita')]),
      if (vista == 'offerti')
        const ModConfigForm(modulo: 'pacchetti', defs: [
          FieldDef('testo', 'Testo introduttivo della pagina Pacchetti', type: 'textarea', rows: 2, wide: true, gruppo: 'Pagina'),
          FieldDef('pacchetti', 'Pacchetti in vendita', type: 'list', wide: true, gruppo: 'Pacchetti', nomeElemento: 'pacchetto', fields: [
            FieldDef('nome', 'Nome', required: true, placeholder: 'es. 10 ingressi SPA'),
            FieldDef('sedute', 'Numero di sedute', type: 'number', min: 1, step: 1, required: true),
            FieldDef('prezzo', 'Prezzo', type: 'money', unit: '€', required: true),
            FieldDef('prezzoPieno', 'Prezzo senza pacchetto (per mostrare il risparmio)', type: 'money', unit: '€'),
            FieldDef('validitaMesi', 'Validità', type: 'number', unit: 'mesi', min: 1, step: 1),
            FieldDef('descrizione', 'Descrizione', type: 'textarea', rows: 2, wide: true),
            FieldDef('immagine', 'Immagine', type: 'image', wide: true),
          ]),
        ])
      else
        ElencoCarte(key: ValueKey(_gen), tipo: 'pacchetto', colonne: [
          ('Pacchetto', (c) => Text(str(c['nomePacchetto']), style: t.text())),
          ('Sedute', (c) => Text.rich(TextSpan(children: [TextSpan(text: '${c['saldo']}', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: ' / ${c['valore']}')]), style: t.text())),
          ('Scadenza', (c) => Text(str(c['scadenza']).isEmpty ? '' : fmtDateShort(str(c['scadenza'])), style: t.text())),
        ]),
    ]);
  }

  void _nuovo(BuildContext context) {
    final s = App.read(context);
    final lista = jsonList(s.repo.cfgModulo('pacchetti')['pacchetti']);
    if (lista.isEmpty) {
      s.toast('Crea prima un pacchetto in "Pacchetti in vendita"', err: true);
      return;
    }
    var scelto = str(lista.first['id']);
    var pagato = true;
    showVModal(context, 'Pacchetto venduto in sede', (ctx) => StatefulBuilder(
          builder: (ctx, setM) => ContattoFormAdmin(
            bottone: 'Crea',
            extraTop: [
              FieldLabel('Pacchetto', child: VSelect<String>(value: scelto, items: [for (final p in lista) (str(p['id']), '${p['nome']} — ${intOf(p['sedute'])} sedute, ${euro(p['prezzo'])}')], onChanged: (v) => setM(() => scelto = v ?? scelto))),
              const Gap(12),
            ],
            extraBottom: [const Gap(12), VCheck(value: pagato, onChanged: (v) => setM(() => pagato = v), label: const Text('Già pagato (attivo subito)'))],
            extraValues: () => {'pacchetto': scelto, 'pagato': pagato},
            onSubmit: (d) async {
              final c = await s.repo.tesseraCrea('pacchetto', d, admin: true);
              if (ctx.mounted) Navigator.of(ctx).pop();
              setState(() => _gen++);
              if (context.mounted) apriCarta(context, 'pacchetto', c, dopo: () => setState(() => _gen++));
            },
          ),
        ));
  }
}

/* ================= Offerte e coupon ================= */

class OfferteAdmin extends StatelessWidget {
  final List<String> rest;
  const OfferteAdmin({super.key, required this.rest});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    if (!s.modulo('offerte')) return _nonAttivo('La funzione Offerte');
    final vista = rest.isEmpty ? 'offerte' : rest[0];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Offerte a tempo', sub: 'Promozioni con date di inizio e fine, codice da mostrare in cassa o coupon personali a numero limitato.', actions: [
        VButton('Vedi sul sito', icon: 'eye', kind: BtnKind.ghost, onPressed: () => openLink(context, '#/offerte', newTab: true)),
      ]),
      SubTabs(base: 'offerte', current: vista, tabs: const [('offerte', 'Offerte'), ('coupon', 'Coupon emessi')]),
      if (vista == 'coupon')
        ElencoCarte(tipo: 'coupon', colonne: [
          ('Offerta', (c) => Text(str(c['offerta']), style: t.text())),
          ('Sconto', (c) => Text(str(c['sconto']), style: t.text())),
        ])
      else
        const ModConfigForm(modulo: 'offerte', defs: [
          FieldDef('offerte', 'Offerte', type: 'list', wide: true, gruppo: 'Offerte', nomeElemento: 'offerta', fields: [
            FieldDef('titolo', 'Titolo', required: true, placeholder: 'es. Settimana del sorriso'),
            FieldDef('sconto', 'Sconto / vantaggio', placeholder: 'es. -20%, 2x1, Omaggio'),
            FieldDef('attiva', 'Attiva', type: 'bool', defaultValue: true),
            FieldDef('dal', 'Dal', type: 'date'),
            FieldDef('al', 'Al (compreso)', type: 'date'),
            FieldDef('countdown', 'Mostra il conto alla rovescia', type: 'bool'),
            FieldDef('descrizione', 'Descrizione', type: 'textarea', rows: 2, wide: true),
            FieldDef('personale', 'Coupon personale (il cliente lascia i suoi dati e riceve un codice unico)', type: 'bool', wide: true),
            FieldDef('limite', 'Numero massimo di coupon (0 = illimitati)', type: 'number', min: 0, step: 1),
            FieldDef('codice', 'Codice uguale per tutti (se non personale)', placeholder: 'es. SORRISO20'),
            FieldDef('immagine', 'Immagine', type: 'image', wide: true),
          ]),
        ]),
    ]);
  }
}

/* ================= Recensioni ================= */

const kStatiRec = {'in_attesa': ('Da approvare', 'warn'), 'pubblicata': ('Pubblicata', 'ok'), 'rifiutata': ('Rifiutata', 'err')};

class RecensioniAdmin extends StatelessWidget {
  final List<String> rest;
  const RecensioniAdmin({super.key, required this.rest});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    if (!s.modulo('recensioni')) return _nonAttivo('La funzione Recensioni');
    final vista = rest.isEmpty ? 'elenco' : rest[0];
    final lista = s.repo.recElenco(soloPubblicate: false)..sort((a, b) => (a['stato'] == 'in_attesa' ? 0 : 1).compareTo(b['stato'] == 'in_attesa' ? 0 : 1));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Recensioni', sub: 'Approva le recensioni dei clienti prima che compaiano sul sito e rispondi pubblicamente.', actions: [
        VButton('Vedi sul sito', icon: 'eye', kind: BtnKind.ghost, onPressed: () => openLink(context, '#/recensioni', newTab: true)),
      ]),
      SubTabs(base: 'recensioni', current: vista, tabs: const [('elenco', 'Recensioni'), ('impostazioni', 'Impostazioni')]),
      if (vista == 'impostazioni')
        const ModConfigForm(modulo: 'recensioni', defs: [
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
