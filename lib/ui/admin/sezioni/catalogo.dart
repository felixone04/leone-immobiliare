/// Catalogo: elenco degli annunci e modulo di inserimento/modifica.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../state/app_state.dart';
import '../../dialogs.dart';
import '../../kit.dart';
import '../admin_common.dart';
import '../form/vform.dart';

class CatalogoAdmin extends StatelessWidget {
  final List<String> rest;
  const CatalogoAdmin({super.key, required this.rest});
  @override
  Widget build(BuildContext context) {
    if (rest.isNotEmpty) return ItemEditor(id: rest[0] == 'nuovo' ? null : rest[0]);
    return const _Elenco();
  }
}

class _Elenco extends StatefulWidget {
  const _Elenco();
  @override
  State<_Elenco> createState() => _ElencoState();
}

class _ElencoState extends State<_Elenco> {
  var _q = '';

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final sch = s.repo.schema;
    final cat = s.cat;
    final q = norm(_q);
    final list = cat.sort([...s.repo.items], 'recenti').where((i) => q.isEmpty || norm([i['titolo'], cat.luogo(i), i['rif'], i['codice']].map(str).join(' ')).contains(q)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead(sch.plurale, sub: '${s.repo.items.length} in totale', actions: [VButton(sch.nuovo, icon: 'plus', kind: BtnKind.primary, href: '#/admin/catalogo/nuovo')]),
      AdminSearch(hint: 'Cerca per titolo, città, codice…', onChanged: (v) => setState(() => _q = v)),
      AdminTable(
        head: const ['', 'Titolo', 'Prezzo', 'Stato', '★', ''],
        widths: const {0: FixedColumnWidth(96), 1: FlexColumnWidth()},
        empty: s.repo.items.isEmpty ? 'Ancora nessun contenuto. Aggiungi il primo con il pulsante in alto.' : 'Nessun risultato',
        rows: [
          for (final i in list)
            [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 68,
                  height: 50,
                  child: cat.foto(i).isNotEmpty ? VImage(cat.foto(i).first) : Container(color: t.bg, child: Center(child: VIcon(sch.icona, color: t.muted))),
                ),
              ),
              Cell2(
                str(i['titolo']),
                sub: [cat.luogo(i), sch.card.badge.map((k) => str(i[k])).where((x) => x.isNotEmpty).join(' · ')].where((x) => x.isNotEmpty).join(' — '),
                onTap: () => context.go('/admin/catalogo/${i['id']}'),
              ),
              Text(cat.prezzo(i), style: t.text(size: 14.9)),
              cat.nastro(i).isNotEmpty ? Pill(cat.nastro(i), tone: 'warn') : const Pill('Visibile', tone: 'ok'),
              Tooltip(
                message: boolOf(i['evidenza']) ? "Togli dall'evidenza" : 'Metti in evidenza',
                child: Hover(
                  onTap: () => s.run(() => s.repo.saveItem({...i, 'evidenza': !boolOf(i['evidenza'])})),
                  builder: (_, h) => Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: h ? t.bg : null, borderRadius: BorderRadius.circular(8)),
                    child: VIcon('star', color: boolOf(i['evidenza']) || h ? t.accent : t.line2, filled: boolOf(i['evidenza'])),
                  ),
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                IconBtn('eye', tooltip: 'Vedi sul sito', onPressed: () => openLink(context, '#/scheda/${i['id']}', newTab: true)),
                IconBtn('edit', tooltip: 'Modifica', onPressed: () => context.go('/admin/catalogo/${i['id']}')),
                IconBtn('copy', tooltip: 'Duplica', onPressed: () async {
                  final copia = cloneJson(i)..remove('id')..remove('creato');
                  copia['titolo'] = '${i['titolo']} (copia)';
                  copia['evidenza'] = false;
                  if (await s.run(() => s.repo.saveItem(copia)) != null) s.toast('Duplicato creato');
                }),
                IconBtn('trash', tooltip: 'Elimina', danger: true, onPressed: () async {
                  if (!await confirmDialog(context, 'Eliminare definitivamente «${i['titolo']}»?')) return;
                  await s.run(() => s.repo.deleteItem(i['id']));
                  s.toast('Eliminato');
                }),
              ]),
            ],
        ],
      ),
    ]);
  }
}

class ItemEditor extends StatefulWidget {
  final String? id;
  const ItemEditor({super.key, this.id});
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  late final s = App.read(context);
  late final Json? item = widget.id != null ? s.repo.item(widget.id!) : null;
  late final ctrl = FormCtrl(s.repo.schema.campi, item != null ? cloneJson(item!) : {});
  final _groupKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!ctrl.validate()) {
      s.toast('Compila i campi obbligatori evidenziati', err: true);
      return;
    }
    final dati = ctrl.vals;
    final r = await s.run(() => s.repo.saveItem(item != null ? {...item!, ...dati} : dati));
    if (r == null) return;
    s.toast('Salvato');
    if (mounted) context.go('/admin/catalogo');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sch = s.repo.schema;
    if (widget.id != null && item == null) return AdminHead('Elemento non trovato', back: (sch.plurale, '/admin/catalogo'));
    final gruppi = <String>[];
    for (final c in sch.campi) {
      if (!gruppi.contains(c.gruppo)) gruppi.add(c.gruppo ?? '');
    }
    for (final g in gruppi) {
      _groupKeys.putIfAbsent(g, () => GlobalKey());
    }
    final salva = VButton('Salva', icon: 'check', kind: BtnKind.primary, onAsync: _salva);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead(
        item != null ? str(item!['titolo']) : sch.nuovo,
        sub: item != null ? 'Modifica ${sch.singolare.toLowerCase()}' : 'Compila i campi: quelli con * sono obbligatori',
        back: (sch.plurale, '/admin/catalogo'),
        actions: [
          if (item != null) VButton('Anteprima', icon: 'eye', kind: BtnKind.ghost, onPressed: () => openLink(context, '#/scheda/${item!['id']}', newTab: true)),
          salva,
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in gruppi)
            Hover(
              onTap: () {
                final c = _groupKeys[g]?.currentContext;
                if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350));
              },
              builder: (_, h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: t.surface, border: Border.all(color: h ? t.primary : t.line), borderRadius: BorderRadius.circular(999)),
                child: Text(g, style: t.text(size: 13.6, weight: FontWeight.w600, color: h ? t.primary : t.ink2, height: 1.3)),
              ),
            ),
        ]),
      ),
      VFormView(ctrl, groups: true, groupKeys: _groupKeys),
      FormFoot(
        left: item != null
            ? VButton('Elimina', icon: 'trash', kind: BtnKind.ghost, danger: true, onAsync: () async {
                if (!await confirmDialog(context, 'Eliminare definitivamente «${item!['titolo']}»?')) return;
                await s.run(() => s.repo.deleteItem(item!['id']));
                s.toast('Eliminato');
                if (context.mounted) context.go('/admin/catalogo');
              })
            : null,
        right: [const VButton('Annulla', kind: BtnKind.ghost, href: '#/admin/catalogo'), salva],
      ),
    ]);
  }
}
