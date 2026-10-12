/// Elenco completo con filtri di ricerca, ordinamento e vista mappa (C.listing).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/catalog.dart';
import '../../data/preset.dart';
import '../../state/app_state.dart';
import '../clienti/account.dart';
import '../inputs.dart';
import '../kit.dart';
import '../map/vmap.dart';
import 'item_card.dart';

/// Stato dei filtri, condiviso tra la barra laterale (o il pannello mobile) e i risultati.
class ListingState extends ChangeNotifier {
  final Map<String, String> st;
  String? sort;
  String view;
  int pag = 12;
  int version = 0; // cambia quando i campi vanno ridisegnati (azzera, rimozione chip)
  ListingState(Map<String, String> initial, CatalogSchema s)
      : st = Map.of(initial)..removeWhere((k, v) => k == 'ordina' || k == 'vista' || v.isEmpty),
        sort = s.ordina.any((o) => o.id == initial['ordina']) ? initial['ordina'] : s.ordina.firstOrNull?.id,
        view = initial['vista'] == 'mappa' && s.hasGeo ? 'mappa' : 'griglia';

  void set(String k, String v, {bool redraw = false}) {
    if (v.isEmpty) {
      st.remove(k);
    } else {
      st[k] = v;
    }
    pag = 12;
    if (redraw) version++;
    notifyListeners();
  }

  void reset() {
    st.clear();
    pag = 12;
    version++;
    notifyListeners();
  }

  void remove(FilterDef f, String? val) {
    if (val != null) {
      final rest = (st[f.id] ?? '').split('|').where((x) => x != val).join('|');
      set(f.id, rest, redraw: true);
      return;
    }
    if (f.tipo == 'range') {
      st.remove('${f.id}_min');
      st.remove('${f.id}_max');
    } else {
      st.remove(f.id);
    }
    pag = 12;
    version++;
    notifyListeners();
  }

  void setSort(String? v) {
    sort = v;
    pag = 12;
    notifyListeners();
  }

  void setView(String v) {
    view = v;
    notifyListeners();
  }

  void more() {
    pag += 12;
    notifyListeners();
  }
}

class Listing extends StatefulWidget {
  final Map<String, String> initial;
  const Listing({super.key, this.initial = const {}});
  @override
  State<Listing> createState() => _ListingState();
}

class _ListingState extends State<Listing> {
  late ListingState ls;

  @override
  void initState() {
    super.initState();
    ls = ListingState(widget.initial, App.read(context).repo.schema);
    ls.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    ls.removeListener(_rebuild);
    ls.dispose();
    super.dispose();
  }

  void _openFilters() {
    final s = App.read(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi filtri',
      barrierColor: const Color(0x730A0E14),
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a, _, child) => SlideTransition(position: Tween(begin: const Offset(-1.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.ease)), child: child),
      pageBuilder: (ctx, _, _) => App(
        state: s,
        child: VT(
          theme: s.theme,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: (MediaQuery.sizeOf(ctx).width * .92).clamp(0.0, 380.0),
              height: double.infinity,
              child: Material(
                color: s.theme.surface,
                borderRadius: BorderRadius.horizontal(right: Radius.circular(s.theme.radius)),
                child: ListenableBuilder(listenable: ls, builder: (c, _) => FiltersPanel(ls: ls, mobile: true, onClose: () => Navigator.of(ctx).pop())),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = context.vw > 1000;
    final results = _Results(ls: ls, onOpenFilters: _openFilters, mobile: !wide);
    if (!wide) return results;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 290, child: FiltersPanel(ls: ls)),
      const SizedBox(width: 32),
      Expanded(child: results),
    ]);
  }
}

/* ---------------- Pannello dei filtri ---------------- */

class FiltersPanel extends StatefulWidget {
  final ListingState ls;
  final bool mobile;
  final VoidCallback? onClose;
  const FiltersPanel({super.key, required this.ls, this.mobile = false, this.onClose});
  @override
  State<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<FiltersPanel> {
  bool? _adv;

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final ls = widget.ls;
    final filtri = s.repo.schema.filtri;
    final base = filtri.where((f) => !f.avanzato).toList(), adv = filtri.where((f) => f.avanzato).toList();
    final advOpen = _adv ?? adv.any((f) => Catalog.attivo(f, ls.st));
    final groups = <Widget>[];
    void add(Widget w) {
      if (groups.isNotEmpty) groups.add(Container(height: 1, color: t.line));
      groups.add(Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: w));
    }

    for (final f in base) {
      add(FilterField(f: f, ls: ls, key: ValueKey('${f.id}-${ls.version}')));
    }
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ...groups,
      if (adv.isNotEmpty) ...[
        Container(height: 1, color: t.line, margin: const EdgeInsets.only(top: 4)),
        Hover(
          onTap: () => setState(() => _adv = !advOpen),
          builder: (_, h) => Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(children: [
              AnimatedRotation(turns: advOpen ? .125 : 0, duration: const Duration(milliseconds: 200), child: VIcon('plus', color: t.primary)),
              const SizedBox(width: 8),
              Text('Altri filtri', style: t.text(weight: FontWeight.w700, color: t.primary)),
            ]),
          ),
        ),
        if (advOpen)
          for (var i = 0; i < adv.length; i++) ...[
            if (i > 0) Container(height: 1, color: t.line),
            Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: FilterField(f: adv[i], ls: ls, key: ValueKey('${adv[i].id}-${ls.version}'))),
          ],
      ],
    ]);
    final head = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
      child: Row(children: [
        VIcon('sliders', color: t.ink),
        const SizedBox(width: 8),
        Expanded(child: Text('Filtri', style: t.title(size: 16, weight: FontWeight.w700))),
        LinkBtn('Azzera', onTap: ls.reset),
        if (widget.mobile) ...[const SizedBox(width: 6), IconBtn('x', tooltip: 'Chiudi filtri', onPressed: widget.onClose)],
      ]),
    );
    if (widget.mobile) {
      return Column(children: [
        head,
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 18), child: body)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
          child: VButton('Mostra risultati', kind: BtnKind.primary, block: true, onPressed: widget.onClose),
        ),
      ]);
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.line),
        borderRadius: t.r,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        head,
        Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 18), child: body),
      ]),
    );
  }
}

/// Un singolo filtro, in base al tipo.
class FilterField extends StatefulWidget {
  final FilterDef f;
  final ListingState ls;
  const FilterField({super.key, required this.f, required this.ls});
  @override
  State<FilterField> createState() => _FilterFieldState();
}

class _FilterFieldState extends State<FilterField> {
  Timer? _deb;
  late final _c = TextEditingController(text: widget.ls.st[widget.f.id] ?? '');
  late final _min = TextEditingController(text: widget.ls.st['${widget.f.id}_min'] ?? '');
  late final _max = TextEditingController(text: widget.ls.st['${widget.f.id}_max'] ?? '');

  @override
  void dispose() {
    _deb?.cancel();
    _c.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _later(String k, String v) {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 250), () => widget.ls.set(k, v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final f = widget.f, ls = widget.ls;
    final v = ls.st[f.id] ?? '';
    final label = Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(f.label.toUpperCase(), style: t.caps(size: 12.8)));
    final cat = s.cat;
    Widget field;
    switch (f.tipo) {
      case 'testo':
        field = VInput(controller: _c, hint: f.placeholder, icon: 'search', onChanged: (x) => _later(f.id, x), dense: true);
      case 'select':
        field = VSelect<String>(value: v, items: [('', 'Tutti'), for (final o in cat.opzioni(f)) (o, o)], onChanged: (x) => ls.set(f.id, x ?? ''), height: 42);
      case 'segmenti':
        field = SegButtons(options: [('', 'Tutti'), for (final o in cat.opzioni(f)) (o, o)], value: v, onChanged: (x) => ls.set(f.id, x));
      case 'min':
        field = SegButtons(options: [('', 'Tutti'), for (final o in f.valori) ('$o', '$o+')], value: v, onChanged: (x) => ls.set(f.id, x));
      case 'range':
        final fmt = [FilteringTextInputFormatter.digitsOnly];
        field = Row(children: [
          Expanded(child: VInput(controller: _min, hint: 'Min', keyboard: TextInputType.number, formatters: fmt, dense: true, onChanged: (x) => _later('${f.id}_min', x))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('–', style: t.text(color: t.muted))),
          Expanded(child: VInput(controller: _max, hint: 'Max', keyboard: TextInputType.number, formatters: fmt, dense: true, onChanged: (x) => _later('${f.id}_max', x))),
        ]);
      case 'contiene':
        field = VSelect<String>(value: v, items: [('', 'Indifferente'), ('*', 'Almeno uno'), for (final o in cat.opzioni(f)) (o, o)], onChanged: (x) => ls.set(f.id, x ?? ''), height: 42);
      case 'tutti':
      case 'nessuno':
        final sel = v.isEmpty ? <String>[] : v.split('|');
        field = Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in cat.opzioni(f))
            VChip(o, small: true, icon: f.tipo == 'nessuno' ? 'x' : 'check', selected: sel.contains(o), onTap: () {
              final n = sel.contains(o) ? sel.where((x) => x != o).toList() : [...sel, o];
              ls.set(f.id, n.join('|'));
            }),
        ]);
      case 'bool':
      case 'escludi':
        return VSwitch(value: v.isNotEmpty, label: f.label, onChanged: (x) => ls.set(f.id, x ? '1' : ''));
      default:
        return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [label, field]);
  }
}

/* ---------------- Risultati ---------------- */

class _Results extends StatelessWidget {
  final ListingState ls;
  final VoidCallback onOpenFilters;
  final bool mobile;
  const _Results({required this.ls, required this.onOpenFilters, required this.mobile});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final sch = s.repo.schema;
    final cat = s.cat;
    final list = cat.sort(cat.items.where((i) => cat.match(i, ls.st)).toList(), ls.sort);
    final n = list.length;
    final chips = cat.chipsAttivi(ls.st);
    final ord = sch.ordina;

    final count = Text.rich(
      TextSpan(children: [
        TextSpan(text: '$n', style: t.text(size: 17.6, weight: FontWeight.w700, color: t.ink)),
        TextSpan(text: ' ${n == 1 ? sch.singolare.toLowerCase() : sch.plurale.toLowerCase()} ${n == 1 ? 'trovato' : 'trovati'}'),
      ]),
      style: t.text(color: t.ink2),
    );
    // Wrap: sui telefoni più stretti (320 px) la scelta elenco/mappa va sotto l'ordinamento
    final tools = Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      if (ord.length > 1)
        SizedBox(
          width: 230,
          child: VSelect<String>(
            value: ls.sort,
            height: 40,
            radius: t.controlRadius,
            style: t.text(size: 14.4, weight: FontWeight.w600, height: 1.3),
            items: [for (final o in ord) (o.id, o.label)],
            onChanged: ls.setSort,
          ),
        ),
      if (sch.hasGeo) ...[
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: t.line2), borderRadius: BorderRadius.circular(t.controlRadius)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (v, ic, tip) in [('griglia', 'grid', 'Vista elenco'), ('mappa', 'map', 'Vista mappa')])
              Tooltip(
                message: tip,
                child: Hover(
                  onTap: () => ls.setView(v),
                  builder: (_, h) => Container(
                    width: 36,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: ls.view == v ? t.primary : Colors.transparent, borderRadius: BorderRadius.circular(t.controlRadius)),
                    child: VIcon(ic, color: ls.view == v ? t.onPrimary : t.muted),
                  ),
                ),
              ),
          ]),
        ),
      ],
    ]);
    final filtersBtn = Hover(
      onTap: onOpenFilters,
      builder: (_, h) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
        decoration: BoxDecoration(color: h ? t.primarySoft : Colors.transparent, border: Border.all(color: t.primary), borderRadius: BorderRadius.circular(t.btnRadius)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          VIcon('sliders', color: t.primary),
          const SizedBox(width: 8),
          Text('Filtri', style: t.text(size: 15.2, weight: FontWeight.w600, color: t.primary, height: 1.3)),
          if (chips.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(999)),
              child: Text('${chips.length}', style: t.text(size: 12, weight: FontWeight.w700, color: t.onPrimary, height: 1)),
            ),
          ],
        ]),
      ),
    );

    final bar = mobile
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [filtersBtn, tools]),
            const SizedBox(height: 12),
            count,
          ])
        // Wrap: su tablet la colonna dei risultati è stretta e ordinamento + vista vanno sotto al conteggio
        : Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [count, tools]);

    Widget content;
    if (n == 0) {
      content = EmptyState(
        icon: 'search',
        title: 'Nessun risultato',
        text: 'Prova ad allargare la ricerca o a togliere qualche filtro.',
        actions: [VButton('Azzera i filtri', kind: BtnKind.outline, onPressed: ls.reset)],
      );
    } else if (ls.view == 'mappa') {
      final pins = catalogPins(s, list);
      final senza = list.where((i) => cat.geo(i) == null).length;
      content = VMap(
        pins: pins,
        height: (context.vh * .7).clamp(300.0, 620.0),
        note: senza > 0 ? '$senza risultati senza posizione non sono mostrati sulla mappa' : null,
      );
    } else {
      content = CardsGrid(list.take(ls.pag).toList(), minWidth: 270);
      if (n > ls.pag) {
        content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          content,
          const SizedBox(height: 28),
          Center(child: VButton('Mostra altri (${n - ls.pag})', kind: BtnKind.outline, onPressed: ls.more)),
        ]);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      bar,
      const SizedBox(height: 12),
      if (chips.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final c in chips)
              Hover(
                onTap: () => ls.remove(sch.filtri.firstWhere((x) => x.id == c.id), c.val),
                builder: (_, h) => Container(
                  padding: const EdgeInsets.fromLTRB(12, 5, 8, 5),
                  decoration: BoxDecoration(
                    color: h ? mix(t.primary, .16, Colors.white) : t.primarySoft,
                    border: Border.all(color: t.primary.withValues(alpha: .2)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(c.t, style: t.text(size: 13.6, weight: FontWeight.w600, color: t.primary, height: 1.3)),
                    const SizedBox(width: 6),
                    VIcon('x', size: 14, color: t.primary),
                  ]),
                ),
              ),
            LinkBtn('Azzera tutto', onTap: ls.reset),
          ]),
        ),
      content,
      const SizedBox(height: 32),
      _SalvaRicerca(criteri: criteriDaFiltri(ls.st)),
    ]);
  }
}


/// Invito a salvare la ricerca: il cliente viene avvisato quando arriva un immobile adatto.
class _SalvaRicerca extends StatelessWidget {
  final Json criteri;
  const _SalvaRicerca({required this.criteri});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(color: t.primarySoft, border: Border.all(color: t.primary.withValues(alpha: .25)), borderRadius: t.r),
      child: Wrap(spacing: 20, runSpacing: 14, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 2), child: VIcon('bell', size: 22, color: t.primary)),
            const SizedBox(width: 12),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Non trovi la casa giusta?', style: t.title(size: 17.6)),
                const SizedBox(height: 2),
                Text('Salva questa ricerca: ti scriviamo appena arriva un immobile adatto a te.', style: t.text(size: 14.4, color: t.ink2)),
              ]),
            ),
          ]),
        ),
        VButton('Salva questa ricerca', icon: 'bookmark', kind: BtnKind.primary, onPressed: () => apriRicerca(context, criteri: criteri)),
      ]),
    );
  }
}
