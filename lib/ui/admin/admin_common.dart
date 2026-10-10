/// Elementi comuni delle sezioni dell'area riservata.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../kit.dart';

/// Intestazione di sezione (.admin-head)
class AdminHead extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? subWidget;
  final List<Widget> actions;
  final (String, String)? back; // (etichetta, percorso)
  const AdminHead(this.title, {super.key, this.sub, this.subWidget, this.actions = const [], this.back});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, spacing: 24, runSpacing: 16, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (back != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Hover(
                onTap: () => context.go(back!.$2),
                builder: (_, h) => Row(mainAxisSize: MainAxisSize.min, children: [
                  VIcon('arrowLeft', size: 16, color: h ? t.primary : t.muted),
                  const SizedBox(width: 6),
                  Text(back!.$1, style: t.text(size: 14.4, weight: FontWeight.w600, color: h ? t.primary : t.muted)),
                ]),
              ),
            ),
          if (t.leone && back == null) Padding(padding: const EdgeInsets.only(bottom: 10), child: RoofMark(width: 46, height: 14, color: t.primary)),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Text(title, style: t.title(size: 28))),
          if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: Text(sub!, style: t.text(color: t.muted)))),
          if (subWidget != null) Padding(padding: const EdgeInsets.only(top: 4), child: subWidget!),
        ]),
        if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
      ]),
    );
  }
}

/// Sotto-schede (.subtabs)
class SubTabs extends StatelessWidget {
  final String base, current;
  final List<(String, String)> tabs;
  const SubTabs({super.key, required this.base, required this.current, required this.tabs});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line2))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (k, l) in tabs)
            Hover(
              onTap: () => context.go('/admin/$base/$k'),
              builder: (_, h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: k == current ? t.primary : Colors.transparent, width: 3))),
                child: Text(l, style: t.text(weight: FontWeight.w700, color: k == current ? t.primary : (h ? t.ink : t.muted))),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Tabella (.table-wrap .tbl)
class AdminTable extends StatelessWidget {
  final List<String>? head;
  final List<List<Widget>> rows;
  final Map<int, TableColumnWidth> widths;
  final String? empty;
  const AdminTable({super.key, this.head, required this.rows, this.widths = const {}, this.empty});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cols = head?.length ?? (rows.isEmpty ? 1 : rows.first.length);
    return Container(
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(builder: (c, box) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: box.maxWidth),
            child: Table(
              columnWidths: widths,
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: TableBorder(horizontalInside: BorderSide(color: t.line)),
              children: [
                if (head != null)
                  TableRow(
                    decoration: BoxDecoration(color: context.t.tint),
                    children: [for (final h in head!) Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Text(h.toUpperCase(), style: t.caps(size: 12)))],
                  ),
                if (rows.isEmpty && empty != null)
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.all(32), child: Text(empty!, textAlign: TextAlign.center, style: t.text(color: t.muted))),
                    for (var i = 1; i < cols; i++) const SizedBox.shrink(),
                  ]),
                for (final r in rows) TableRow(children: [for (final cell in r) Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: cell)]),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// Testo principale + riga secondaria piccola in una cella
class Cell2 extends StatelessWidget {
  final String main;
  final String? sub;
  final bool bold;
  final VoidCallback? onTap;
  final Widget? mainWidget;
  const Cell2(this.main, {super.key, this.sub, this.bold = true, this.onTap, this.mainWidget});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final m = mainWidget ??
        (onTap != null
            ? Hover(
                onTap: onTap,
                builder: (_, h) => Text(main, style: t.text(size: 14.9, weight: bold ? FontWeight.w700 : FontWeight.w400, color: h ? t.primary : t.ink).copyWith(decoration: h ? TextDecoration.underline : null, decorationColor: t.primary)),
              )
            : Text(main, style: t.text(size: 14.9, weight: bold ? FontWeight.w700 : FontWeight.w400)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      m,
      if (sub != null && sub!.isNotEmpty) Text(sub!, style: t.text(size: 13.1, color: t.muted, height: 1.35)),
    ]);
  }
}

/// Barra di ricerca dell'area riservata (.admin-toolbar)
class AdminSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const AdminSearch({super.key, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            onChanged: onChanged,
            style: t.text(size: 15, height: 1.2),
            decoration: vDecorationPill(t, hint),
          ),
        ),
      ),
    );
  }
}

InputDecoration vDecorationPill(VTheme t, String hint) => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: t.text(size: 15, color: t.muted, height: 1.2),
      prefixIcon: Padding(padding: const EdgeInsets.only(left: 14, right: 8), child: VIcon('search', color: t.muted)),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.controlRadius), borderSide: BorderSide(color: t.line2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.controlRadius), borderSide: BorderSide(color: t.primary, width: 1.6)),
    );

/// Barra in fondo ai moduli lunghi con il pulsante Salva (.form-foot)
class FormFoot extends StatelessWidget {
  final Widget? left;
  final List<Widget> right;
  const FormFoot({super.key, this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
      // Wrap: su schermi stretti i pulsanti di destra vanno sotto invece di uscire dalla barra
      child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 10, children: [
        left ?? const SizedBox.shrink(),
        Wrap(spacing: 8, runSpacing: 8, children: right),
      ]),
    );
  }
}

/// Pulsanti per contattare il cliente (WhatsApp, chiamata, email) con un messaggio già scritto.
List<Widget> contattiBtn(Json d, String msg, String oggetto) => [
      if (str(d['telefono']).isNotEmpty) ...[
        VButton('WhatsApp', icon: 'chat', size: BtnSize.sm, href: 'https://wa.me/${waNumber(str(d['telefono']))}?text=${Uri.encodeComponent(msg)}'),
        VButton('Chiama', icon: 'phone', size: BtnSize.sm, href: 'tel:${telHref(str(d['telefono']))}'),
      ],
      if (str(d['email']).isNotEmpty) VButton('Email', icon: 'mail', size: BtnSize.sm, href: 'mailto:${d['email']}?subject=${Uri.encodeComponent(oggetto)}&body=${Uri.encodeComponent(msg)}'),
    ];

/// Data e ora brevi "8 ott, 10:42"
String quando(Object? ms) => fmtWhen(intOf(ms));
