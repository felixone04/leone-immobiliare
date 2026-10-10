/// "Home e widget" e "Pagine e menu": liste ordinabili con modifica in linea.
library;

import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/preset.dart';
import '../../../state/app_state.dart';
import '../../dialogs.dart';
import '../../home/widget_defs.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';
import '../form/vform.dart';

/// Lista ordinabile generica.
class SortableList extends StatefulWidget {
  final List<Json> lista;
  final String Function(Json) nome;
  final (String icona, String testo) Function(Json) descr;
  final List<FieldDef> Function(Json) campi;
  final Future<void> Function(List<Json> lista, String? msg) salva;
  final String Function(Json)? bloccato;
  final bool toggle;
  final String? aperto;
  const SortableList({super.key, required this.lista, required this.nome, required this.descr, required this.campi, required this.salva, this.bloccato, this.toggle = false, this.aperto});
  @override
  State<SortableList> createState() => SortableListState();
}

class SortableListState extends State<SortableList> {
  late List<Json> lista = cloneJson(widget.lista);
  late String? open = widget.aperto;
  FormCtrl? _form;

  void aggiungi(Json x) {
    setState(() {
      lista.add(x);
      _apri(x);
    });
  }

  void _apri(Json? x) {
    _form?.dispose();
    _form = x == null ? null : FormCtrl(widget.campi(x), x);
    open = x?['id'] as String?;
  }

  Future<void> _salva([String? msg]) => widget.salva(lista, msg);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (lista.isEmpty) return Padding(padding: const EdgeInsets.all(32), child: Text('Nessun elemento.', textAlign: TextAlign.center, style: t.text(color: t.muted)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < lista.length; i++) ...[if (i > 0) const SizedBox(height: 10), _riga(context, i)],
    ]);
  }

  Widget _riga(BuildContext context, int i) {
    final s = App.of(context);
    final t = context.t;
    final x = lista[i];
    final isOpen = open == x['id'];
    final off = x['attivo'] == false;
    final (ic, testo) = widget.descr(x);
    return Container(
      key: ValueKey(x['id']),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: isOpen ? t.line2 : t.line), borderRadius: t.r, boxShadow: isOpen ? t.shadow : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _apri(isOpen ? null : x)),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
              child: Opacity(
                opacity: off ? .55 : 1,
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(10)),
                    child: VIcon(ic, color: t.primary),
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.nome(x), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text(weight: FontWeight.w700, height: 1.35)),
                      Text(testo, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text(size: 13.6, color: t.muted, height: 1.35)),
                    ]),
                  ),
                  if (widget.toggle)
                    Tooltip(
                      message: 'Visibile',
                      child: VSwitch(small: true, value: !off, onChanged: (v) {
                        setState(() => x['attivo'] = v);
                        _salva();
                      }),
                    ),
                  IconBtn('chevronUp', tooltip: 'Sposta su', onPressed: i == 0 ? null : () {
                    setState(() {
                      lista.insert(i - 1, lista.removeAt(i));
                    });
                    _salva();
                  }),
                  IconBtn('chevronDown', tooltip: 'Sposta giù', onPressed: i == lista.length - 1 ? null : () {
                    setState(() {
                      lista.insert(i + 1, lista.removeAt(i));
                    });
                    _salva();
                  }),
                  IconBtn('edit', tooltip: 'Modifica', onPressed: () => setState(() => _apri(isOpen ? null : x))),
                  IconBtn('trash', tooltip: 'Elimina', danger: true, onPressed: () async {
                    final b = widget.bloccato?.call(x) ?? '';
                    if (b.isNotEmpty) {
                      s.toast(b, err: true);
                      return;
                    }
                    if (!await confirmDialog(context, 'Eliminare «${widget.nome(x)}»?')) return;
                    setState(() {
                      lista.removeAt(i);
                      if (isOpen) _apri(null);
                    });
                    await _salva('Eliminato');
                  }),
                ]),
              ),
            ),
          ),
        ),
        if (isOpen && _form != null)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              VFormView(_form!),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                VButton('Chiudi', kind: BtnKind.ghost, onPressed: () => setState(() => _apri(null))),
                const SizedBox(width: 8),
                VButton('Salva', icon: 'check', kind: BtnKind.primary, onAsync: () async {
                  if (!_form!.validate()) return;
                  x.addAll(_form!.vals);
                  await _salva('Salvato');
                  if (mounted) setState(() => _apri(null));
                }),
              ]),
            ]),
          ),
      ]),
    );
  }
}

/* ---------------- Home e widget ---------------- */

class WidgetAdmin extends StatefulWidget {
  const WidgetAdmin({super.key});
  @override
  State<WidgetAdmin> createState() => _WidgetAdminState();
}

class _WidgetAdminState extends State<WidgetAdmin> {
  final _list = GlobalKey<SortableListState>();

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Future<void> salva(List<Json> lista, String? msg) async {
      await s.run(() => s.repo.saveWidgets(lista));
      if (msg != null) s.toast(msg);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Home e widget', sub: 'Scegli quali blocchi mostrare nella home, in che ordine e con quali testi.', actions: [
        VButton('Vedi la home', icon: 'eye', kind: BtnKind.ghost, onPressed: () => openLink(context, '#/', newTab: true)),
      ]),
      SortableList(
        key: _list,
        lista: s.repo.widgets,
        toggle: true,
        salva: salva,
        nome: (w) => str(w['titolo']).isNotEmpty ? str(w['titolo']) : (kWidgetDefs[w['tipo']]?.nome ?? str(w['tipo'])),
        descr: (w) => (kWidgetDefs[w['tipo']]?.icona ?? 'layers', kWidgetDefs[w['tipo']]?.nome ?? 'Widget sconosciuto'),
        campi: (w) => kWidgetDefs[w['tipo']]?.campi ?? const [],
      ),
      const SizedBox(height: 28),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Aggiungi un widget', style: t.title(size: 17.6, weight: FontWeight.w700))),
          AutoGrid(minWidth: 210, gap: 10, children: [
            for (final e in kWidgetDefs.entries)
              Hover(
                onTap: () {
                  final w = <String, dynamic>{'id': 'n${uid()}', 'tipo': e.key, 'attivo': true, 'titolo': e.value.nome};
                  if (e.key == 'catalogo') {
                    w['modalita'] = 'evidenza';
                    w['quanti'] = 3;
                  }
                  _list.currentState?.aggiungi(w);
                  final st = _list.currentState;
                  if (st != null) salva(st.lista, 'Widget aggiunto: completalo e salva');
                },
                builder: (_, h) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: h ? t.primarySoft : context.t.tint, border: Border.all(color: h ? t.primary : t.line), borderRadius: t.rSm),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 2), child: VIcon(e.value.icona, size: 22, color: t.primary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e.value.nome, style: t.text(weight: FontWeight.w700, height: 1.35)),
                        Text(e.value.desc, style: t.text(size: 13.1, color: t.muted, height: 1.35)),
                      ]),
                    ),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    ]);
  }
}

/* ---------------- Pagine e menu ---------------- */

class PagineAdmin extends StatefulWidget {
  const PagineAdmin({super.key});
  @override
  State<PagineAdmin> createState() => _PagineAdminState();
}

class _PagineAdminState extends State<PagineAdmin> {
  final _list = GlobalKey<SortableListState>();
  var _gen = 0;

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    List<FieldDef> campi(Json p) {
      final speciale = ['contatti', 'privacy'].contains(p['tipo']);
      return [
        const FieldDef('titolo', 'Titolo', required: true),
        const FieldDef('slug', 'Indirizzo della pagina', hint: 'Parte finale del link, es. "chi-siamo". Lascia vuoto per generarlo dal titolo.'),
        if (!speciale) ...[const FieldDef('menu', 'Mostra nel menu a tendina', type: 'bool'), const FieldDef('footer', 'Mostra nel piè di pagina', type: 'bool')],
        FieldDef(
          'contenuto',
          p['tipo'] == 'contatti'
              ? 'Testo introduttivo (recapiti, modulo e mappa vengono aggiunti in automatico)'
              : p['tipo'] == 'privacy'
                  ? "Ulteriori informazioni (facoltative: l'informativa viene generata in automatico con i dati inseriti in Impostazioni)"
                  : 'Contenuto',
          type: 'textarea',
          rows: p['tipo'] == 'contatti' ? 4 : (p['tipo'] == 'privacy' ? 5 : 12),
          wide: true,
          hint: 'Formattazione: **grassetto**, *corsivo*, "## " a inizio riga per un sottotitolo, "- " per un elenco puntato.',
        ),
        if (!speciale) const FieldDef('immagine', 'Immagine (facoltativa)', type: 'image', wide: true),
      ];
    }

    Future<void> salva(List<Json> lista, String? msg) async {
      for (final p in lista) {
        p['slug'] = str(p['slug']).isEmpty ? slugify(str(p['titolo'])) : slugify(str(p['slug']));
      }
      await s.run(() => s.repo.savePages(lista));
      if (msg != null) s.toast(msg);
      // gli indirizzi possono essere stati corretti: ridisegna con i dati salvati
      if (mounted) setState(() => _gen++);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead(
        'Pagine e menu',
        sub: 'Le pagine informative (Chi siamo, Storia, Contatti…) che compaiono nel menu a tendina e nel piè di pagina.',
        actions: [
          VButton('Nuova pagina', icon: 'plus', kind: BtnKind.primary, onPressed: () {
            _list.currentState?.aggiungi({'id': 'n${uid()}', 'titolo': 'Nuova pagina', 'slug': '', 'tipo': 'testo', 'menu': true, 'footer': true, 'contenuto': ''});
          }),
        ],
      ),
      SortableList(
        key: _list,
        lista: s.repo.pages,
        aperto: null,
        salva: salva,
        campi: campi,
        bloccato: (p) => p['tipo'] == 'contatti'
            ? 'La pagina Contatti è obbligatoria e non può essere eliminata'
            : p['tipo'] == 'privacy'
                ? "L'informativa privacy è obbligatoria e non può essere eliminata"
                : '',
        nome: (p) => str(p['titolo']).isEmpty ? 'Senza titolo' : str(p['titolo']),
        descr: (p) => (
          p['tipo'] == 'contatti' ? 'mail' : p['tipo'] == 'privacy' ? 'shield' : 'file',
          '/p/${str(p['slug']).isEmpty ? '…' : p['slug']}${p['tipo'] == 'contatti' ? ' · obbligatoria, sempre nel menu' : p['tipo'] == 'privacy' ? ' · obbligatoria, generata in automatico' : boolOf(p['menu']) ? ' · nel menu' : ''}',
        ),
      ),
    ]);
  }
}
