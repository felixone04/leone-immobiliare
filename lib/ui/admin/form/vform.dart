/// Moduli dell'area riservata costruiti dalle definizioni dei campi (come V.form della versione web).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/preset.dart';
import '../../../state/app_state.dart';
import '../../booking/booking_widgets.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../../map/vmap.dart';
import 'upload.dart';

/* ======================= Controller ======================= */

class FormCtrl extends ChangeNotifier {
  final List<FieldDef> defs;
  final Json values;
  final Set<String> invalid = {};
  final Map<String, GlobalKey> keys = {};
  final Map<String, List<FormCtrl>> lists = {};

  FormCtrl(this.defs, Json initial) : values = cloneJson(initial) {
    for (final d in defs) {
      if (values[d.key] == null && d.defaultValue != null) values[d.key] = d.defaultValue;
      keys[d.key] = GlobalKey();
    }
  }

  dynamic operator [](String k) => values[k];

  void set(String k, Object? v, {bool rebuild = false}) {
    values[k] = v;
    if (invalid.remove(k) || rebuild) notifyListeners();
  }

  /// Valori finali (testi senza spazi superflui, righe delle liste aggiornate).
  Json get vals {
    final out = <String, dynamic>{};
    for (final e in values.entries) {
      out[e.key] = e.value is String ? (e.value as String).trim() : e.value;
    }
    for (final e in lists.entries) {
      out[e.key] = [for (final c in e.value) c.vals];
    }
    return out;
  }

  /// Controlla i campi obbligatori; porta in vista il primo errato.
  bool validate() {
    invalid.clear();
    for (final d in defs) {
      if (d.required && isEmptyValue(d.type == 'list' ? lists[d.key] : (values[d.key] is String ? (values[d.key] as String).trim() : values[d.key]))) invalid.add(d.key);
    }
    var ok = invalid.isEmpty;
    for (final l in lists.values) {
      for (final c in l) {
        if (!c.validate()) ok = false;
      }
    }
    notifyListeners();
    if (invalid.isNotEmpty) {
      final first = defs.firstWhere((d) => invalid.contains(d.key));
      final c = keys[first.key]?.currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: .4, duration: const Duration(milliseconds: 300));
    }
    return ok;
  }
}

/* ======================= Vista del modulo ======================= */

/// Modulo completo; con [groups] i campi sono divisi in riquadri per "gruppo" (fieldset).
class VFormView extends StatelessWidget {
  final FormCtrl ctrl;
  final bool groups;
  final double minWidth;
  final Map<String, GlobalKey>? groupKeys;
  const VFormView(this.ctrl, {super.key, this.groups = false, this.minWidth = 230, this.groupKeys});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctrl,
      builder: (context, _) {
        final t = context.t;
        if (!groups) return FieldGrid(ctrl: ctrl, defs: ctrl.defs, minWidth: minWidth);
        final out = <Widget>[];
        String? g;
        var buf = <FieldDef>[];
        void flush() {
          if (buf.isEmpty) return;
          final name = g ?? '';
          out.add(Container(
            key: groupKeys?[name],
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
            decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(name, style: t.title(size: 17.6, weight: FontWeight.w800))),
              FieldGrid(ctrl: ctrl, defs: buf, minWidth: minWidth),
            ]),
          ));
          buf = [];
        }

        for (final d in ctrl.defs) {
          if (d.gruppo != g) {
            flush();
            g = d.gruppo;
          }
          buf.add(d);
        }
        flush();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: out);
      },
    );
  }
}

/// Griglia dei campi (.form-grid): i campi "wide" occupano la riga intera.
class FieldGrid extends StatelessWidget {
  final FormCtrl ctrl;
  final List<FieldDef> defs;
  final double minWidth;
  const FieldGrid({super.key, required this.ctrl, required this.defs, this.minWidth = 230});

  static bool _isWide(FieldDef d) => d.wide || const ['photos', 'geo', 'list', 'orari'].contains(d.type);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gx = 20.0, gy = 18.0;
      final n = AutoGrid.cols(box.maxWidth, minWidth, gx);
      final rows = <Widget>[];
      var cur = <FieldDef>[];
      void flush() {
        if (cur.isEmpty) return;
        final cells = <Widget>[];
        for (var k = 0; k < n; k++) {
          if (k > 0) cells.add(const SizedBox(width: gx));
          cells.add(Expanded(child: k < cur.length ? _cell(cur[k]) : const SizedBox.shrink()));
        }
        rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
        cur = [];
      }

      for (final d in defs) {
        if (_isWide(d)) {
          flush();
          rows.add(_cell(d));
        } else {
          cur.add(d);
          if (cur.length == n) flush();
        }
      }
      flush();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: gy), rows[i]],
      ]);
    });
  }

  Widget _cell(FieldDef d) {
    final w = VField(ctrl: ctrl, def: d, key: ctrl.keys[d.key]);
    return d.type == 'bool' ? Align(alignment: Alignment.bottomLeft, child: w) : Align(alignment: Alignment.topLeft, child: w);
  }
}

/* ======================= Campo ======================= */

class VField extends StatelessWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const VField({super.key, required this.ctrl, required this.def});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final d = def;
    final inv = ctrl.invalid.contains(d.key);
    final v = ctrl[d.key];
    Widget input;
    switch (d.type) {
      case 'bool':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _BoolField(ctrl: ctrl, def: d),
          if (d.hint != null) Text(d.hint!, style: t.text(size: 12.8, color: t.muted, height: 1.4)),
        ]);
      case 'checks':
        return _labelled(context, _ChecksField(ctrl: ctrl, def: d), inv, plainLabel: true);
      case 'textarea':
        input = VInput(initial: str(v), minLines: d.rows ?? 4, maxLines: (d.rows ?? 4) + 12, hint: d.placeholder, invalid: inv, onChanged: (x) => ctrl.set(d.key, x));
      case 'number':
      case 'money':
        input = VInput(
          initial: v == null ? '' : str(v),
          keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]'))],
          hint: d.placeholder,
          invalid: inv,
          onChanged: (x) => ctrl.set(d.key, x.trim().isEmpty ? null : numOrNull(x)),
        );
      case 'select':
        final items = <(String, String)>[if (!d.noEmpty) ('', d.required ? 'Seleziona…' : '—'), for (final o in d.options) (o.value, o.label)];
        input = _SelectField(ctrl: ctrl, def: d, items: items, invalid: inv);
      case 'color':
        input = _ColorField(ctrl: ctrl, def: d);
      case 'image':
        input = _ImageField(ctrl: ctrl, def: d);
      case 'photos':
        input = _PhotosField(ctrl: ctrl, def: d);
      case 'geo':
        input = _GeoField(ctrl: ctrl, def: d);
      case 'list':
        input = _ListField(ctrl: ctrl, def: d);
      case 'orari':
        input = _OrariField(ctrl: ctrl, def: d);
      case 'date':
        input = _DateField(ctrl: ctrl, def: d, invalid: inv);
      case 'time':
        input = VInput(initial: str(v), hint: 'hh:mm', formatters: [_TimeFormatter()], invalid: inv, onChanged: (x) => ctrl.set(d.key, x));
      default:
        input = VInput(
          initial: str(v),
          hint: d.placeholder,
          invalid: inv,
          obscure: d.type == 'password',
          keyboard: switch (d.type) { 'email' => TextInputType.emailAddress, 'tel' => TextInputType.phone, 'url' => TextInputType.url, _ => null },
          onChanged: (x) => ctrl.set(d.key, x),
        );
    }
    return _labelled(context, input, inv);
  }

  Widget _labelled(BuildContext context, Widget input, bool inv, {bool plainLabel = false}) {
    final t = context.t;
    final d = def;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (d.label.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(
            TextSpan(text: d.label, children: [
              if (d.required) const TextSpan(text: ' *', style: TextStyle(color: VTheme.danger)),
              if (d.unit != null) TextSpan(text: ' ${d.unit}', style: TextStyle(color: t.muted, fontWeight: FontWeight.w500)),
            ]),
            style: t.text(size: 14.1, weight: FontWeight.w600, color: inv ? VTheme.danger : t.ink, height: 1.3),
          ),
        ),
      input,
      if (d.hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(d.hint!, style: t.text(size: 12.8, color: t.muted, height: 1.4))),
    ]);
  }
}

class _BoolField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _BoolField({required this.ctrl, required this.def});
  @override
  State<_BoolField> createState() => _BoolFieldState();
}

class _BoolFieldState extends State<_BoolField> {
  @override
  Widget build(BuildContext context) => VSwitch(
        value: boolOf(widget.ctrl[widget.def.key]),
        label: widget.def.label,
        onChanged: (v) => setState(() => widget.ctrl.set(widget.def.key, v)),
      );
}

class _SelectField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  final List<(String, String)> items;
  final bool invalid;
  const _SelectField({required this.ctrl, required this.def, required this.items, required this.invalid});
  @override
  State<_SelectField> createState() => _SelectFieldState();
}

class _SelectFieldState extends State<_SelectField> {
  @override
  Widget build(BuildContext context) {
    final v = str(widget.ctrl[widget.def.key]);
    return VSelect<String>(
      value: widget.items.any((e) => e.$1 == v) ? v : (widget.def.noEmpty && widget.items.isNotEmpty ? widget.items.first.$1 : ''),
      items: widget.items,
      invalid: widget.invalid,
      onChanged: (x) => setState(() => widget.ctrl.set(widget.def.key, x ?? '')),
    );
  }
}

class _ChecksField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _ChecksField({required this.ctrl, required this.def});
  @override
  State<_ChecksField> createState() => _ChecksFieldState();
}

class _ChecksFieldState extends State<_ChecksField> {
  @override
  Widget build(BuildContext context) {
    final cur = strList(widget.ctrl[widget.def.key]);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in widget.def.options)
        VChip(o.label, selected: cur.contains(o.value), onTap: () {
          final n = cur.contains(o.value) ? cur.where((x) => x != o.value).toList() : [...cur, o.value];
          // mantiene l'ordine delle opzioni
          final ord = [for (final x in widget.def.options) if (n.contains(x.value)) x.value];
          setState(() => widget.ctrl.set(widget.def.key, ord));
        }),
    ]);
  }
}

class _DateField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  final bool invalid;
  const _DateField({required this.ctrl, required this.def, required this.invalid});
  @override
  State<_DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<_DateField> {
  @override
  Widget build(BuildContext context) =>
      DateInput(value: str(widget.ctrl[widget.def.key]), clearable: true, invalid: widget.invalid, onChanged: (v) => setState(() => widget.ctrl.set(widget.def.key, v)));
}

/// Inserimento orari "hh:mm"
class _TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (d.length > 4) d = d.substring(0, 4);
    final t = d.length > 2 ? '${d.substring(0, 2)}:${d.substring(2)}' : d;
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// Campo orario compatto usato nell'editor degli orari
class TimeBox extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  const TimeBox({super.key, required this.value, required this.onChanged, required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 92,
        child: Semantics(label: label, child: VInput(initial: value, hint: 'hh:mm', dense: true, formatters: [_TimeFormatter()], onChanged: onChanged)),
      );
}

/* ---------------- Colore ---------------- */

class _ColorField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _ColorField({required this.ctrl, required this.def});
  @override
  State<_ColorField> createState() => _ColorFieldState();
}

class _ColorFieldState extends State<_ColorField> {
  late final _hex = TextEditingController(text: _valid(str(widget.ctrl[widget.def.key])));

  static String _valid(String v) => RegExp(r'^#[\da-fA-F]{6}$').hasMatch(v) ? v.toLowerCase() : '#1d4e5a';

  static const _palette = [
    '#1d4e5a', '#1b2a41', '#0f3d3e', '#264653', '#2a9d8f', '#14532d', '#3f6212', '#365314',
    '#7c2d12', '#9a3412', '#b45309', '#d99a4e', '#e4572e', '#e76f51', '#be123c', '#9d174d',
    '#6d28d9', '#4338ca', '#1d4ed8', '#0369a1', '#0e7490', '#111111', '#374151', '#78716c',
  ];

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _set(String v) {
    widget.ctrl.set(widget.def.key, v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cur = _valid(str(widget.ctrl[widget.def.key]));
    return Row(children: [
      PopupMenuButton<String>(
        tooltip: 'Scegli un colore',
        onSelected: (c) {
          _hex.text = c;
          _set(c);
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            enabled: false,
            child: SizedBox(
              width: 216,
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      _hex.text = c;
                      _set(c);
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: hexColor(c), borderRadius: BorderRadius.circular(6), border: Border.all(color: c == cur ? t.ink : Colors.transparent, width: 2))),
                    ),
                  ),
              ]),
            ),
          ),
        ],
        child: Container(
          width: 52,
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: t.line2), borderRadius: t.rSm),
          child: Container(decoration: BoxDecoration(color: hexColor(cur), borderRadius: BorderRadius.circular(4))),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 110,
        child: VInput(
          controller: _hex,
          maxLength: 7,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
          onChanged: (x) {
            if (RegExp(r'^#[\da-fA-F]{6}$').hasMatch(x)) _set(x.toLowerCase());
          },
        ),
      ),
    ]);
  }
}

/* ---------------- Immagine singola ---------------- */

class _ImageField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _ImageField({required this.ctrl, required this.def});
  @override
  State<_ImageField> createState() => _ImageFieldState();
}

class _ImageFieldState extends State<_ImageField> {
  late final _url = TextEditingController(text: _isWeb(str(widget.ctrl[widget.def.key])) ? str(widget.ctrl[widget.def.key]) : '');
  var _busy = false;
  static bool _isWeb(String s) => s.startsWith('http');

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    final s = App.read(context);
    final files = await pickImageFiles();
    if (files.isEmpty) return;
    setState(() => _busy = true);
    final ref = await s.run(() => uploadImage(s.repo, files.first, max: widget.def.max ?? 1800, png: widget.def.png));
    if (ref != null) {
      widget.ctrl.set(widget.def.key, ref);
      _url.clear();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final cur = str(widget.ctrl[widget.def.key]);
    final prev = Container(
      width: 180,
      height: 120,
      decoration: BoxDecoration(color: context.t.tint2, border: Border.all(color: t.line2), borderRadius: t.rSm),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (safeSrc(cur).isNotEmpty) VImage(cur, fit: BoxFit.contain, fallback: Center(child: VIcon('image', color: t.muted))) else Center(child: VIcon('image', color: t.muted)),
        if (_busy) const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
      ]),
    );
    final side = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        VButton('Carica', icon: 'upload', size: BtnSize.sm, onAsync: _carica),
        if (cur.isNotEmpty)
          VButton('Rimuovi', icon: 'trash', size: BtnSize.sm, kind: BtnKind.ghost, onPressed: () {
            _url.clear();
            setState(() => widget.ctrl.set(widget.def.key, ''));
          }),
      ]),
      const SizedBox(height: 10),
      VInput(
        controller: _url,
        hint: "…oppure incolla l'indirizzo di un'immagine",
        dense: true,
        keyboard: TextInputType.url,
        onSubmitted: (x) => setState(() => widget.ctrl.set(widget.def.key, x.trim())),
        onChanged: (x) {
          if (safeSrc(x.trim()).isNotEmpty || x.trim().isEmpty) setState(() => widget.ctrl.set(widget.def.key, x.trim()));
        },
      ),
    ]);
    return Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [prev, ConstrainedBox(constraints: const BoxConstraints(minWidth: 220, maxWidth: 420), child: side)]);
  }
}

/* ---------------- Galleria foto ---------------- */

class _PhotosField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _PhotosField({required this.ctrl, required this.def});
  @override
  State<_PhotosField> createState() => _PhotosFieldState();
}

class _PhotosFieldState extends State<_PhotosField> {
  late List<String> arr = strList(widget.ctrl[widget.def.key]);
  final _url = TextEditingController();
  String? _prog;
  int? _over;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _save() => widget.ctrl.set(widget.def.key, [...arr]);

  void _move(int from, int to) {
    if (to < 0 || to >= arr.length || from == to) return;
    setState(() {
      final x = arr.removeAt(from);
      arr.insert(to, x);
      _save();
    });
  }

  Future<void> _aggiungi() async {
    final s = App.read(context);
    final files = await pickImageFiles(multiple: true);
    for (var k = 0; k < files.length; k++) {
      setState(() => _prog = 'Caricamento ${k + 1} di ${files.length}…');
      final ref = await s.run(() => uploadImage(s.repo, files[k]));
      if (ref != null) {
        setState(() {
          arr.add(ref);
          _save();
        });
      }
    }
    if (mounted) setState(() => _prog = null);
  }

  void _addUrl() {
    final s = App.read(context);
    final u = _url.text.trim();
    if (safeSrc(u).isNotEmpty) {
      setState(() {
        arr.add(u);
        _save();
        _url.clear();
      });
    } else if (u.isNotEmpty) {
      s.toast('Indirizzo immagine non valido', err: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Widget tool(String icon, String tip, VoidCallback? onTap, {bool danger = false}) => Tooltip(
          message: tip,
          child: Hover(
            onTap: onTap,
            builder: (_, h) => Opacity(
              opacity: onTap == null ? .35 : 1,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(8)),
                child: VIcon(icon, size: 16, color: danger ? VTheme.danger : t.ink),
              ),
            ),
          ),
        );
    Widget item(int i) {
      final tile = Container(
        decoration: BoxDecoration(color: t.bg, borderRadius: t.rSm, border: Border.all(color: _over == i ? t.primary : Colors.transparent, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(fit: StackFit.expand, children: [
            VImage(arr[i], fallback: Center(child: VIcon('image', color: t.muted))),
            if (i == 0)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(999)),
                  child: Text('COPERTINA', style: t.text(size: 11.2, weight: FontWeight.w800, color: t.onAccent, height: 1.3)),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xA6000000)])),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  tool('chevronLeft', 'Sposta indietro', i == 0 ? null : () => _move(i, i - 1)),
                  const SizedBox(width: 4),
                  if (i > 0) ...[tool('star', 'Imposta come copertina', () => _move(i, 0)), const SizedBox(width: 4)],
                  tool('chevronRight', 'Sposta avanti', i == arr.length - 1 ? null : () => _move(i, i + 1)),
                  const SizedBox(width: 4),
                  tool('trash', 'Elimina', () => setState(() {
                    arr.removeAt(i);
                    _save();
                  }), danger: true),
                ]),
              ),
            ),
          ]),
        ),
      );
      // trascina una foto su un'altra per cambiarne l'ordine
      return DragTarget<int>(
        onWillAcceptWithDetails: (d) {
          setState(() => _over = i);
          return d.data != i;
        },
        onLeave: (_) => setState(() => _over = null),
        onAcceptWithDetails: (d) {
          _over = null;
          _move(d.data, i);
        },
        builder: (c, _, _) => Draggable<int>(
          data: i,
          feedback: SizedBox(width: 150, child: Opacity(opacity: .8, child: Material(color: Colors.transparent, child: AspectRatio(aspectRatio: 4 / 3, child: VImage(arr[i]))))),
          childWhenDragging: Opacity(opacity: .4, child: tile),
          child: MouseRegion(cursor: SystemMouseCursors.grab, child: tile),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (arr.isNotEmpty) ...[
        AutoGrid(minWidth: 150, gap: 12, equalHeight: false, children: [for (var i = 0; i < arr.length; i++) item(i)]),
        const SizedBox(height: 12),
      ],
      Hover(
        onTap: _prog == null ? _aggiungi : null,
        builder: (_, h) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          decoration: BoxDecoration(
            color: h ? t.primarySoft : context.t.tint,
            border: Border.all(color: h ? t.primary : t.line2, width: 2),
            borderRadius: t.r,
          ),
          child: Column(children: [
            VIcon('upload', size: 30, color: t.primary),
            const SizedBox(height: 8),
            Text.rich(TextSpan(children: [const TextSpan(text: 'Aggiungi le foto: '), TextSpan(text: 'sfoglia', style: TextStyle(color: t.primary, decoration: TextDecoration.underline, decorationColor: t.primary))]), style: t.text(weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Puoi selezionarne più di una. Vengono ridimensionate automaticamente. La prima è la copertina: trascinale per cambiare l\'ordine.',
                textAlign: TextAlign.center, style: t.text(size: 13.6, color: t.muted)),
            if (_prog != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_prog!, style: t.text(weight: FontWeight.w700, color: t.primary))),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: VInput(controller: _url, hint: 'Aggiungi da indirizzo web (https://…)', keyboard: TextInputType.url, onSubmitted: (_) => _addUrl())),
        const SizedBox(width: 8),
        VButton('Aggiungi', size: BtnSize.sm, onPressed: _addUrl),
      ]),
    ]);
  }
}

/* ---------------- Posizione sulla mappa ---------------- */

class _GeoField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _GeoField({required this.ctrl, required this.def});
  @override
  State<_GeoField> createState() => _GeoFieldState();
}

class _GeoFieldState extends State<_GeoField> {
  late final _lat = TextEditingController(), _lng = TextEditingController();
  LatLng? pos;
  var _ver = 0;

  @override
  void initState() {
    super.initState();
    final g = jsonOf(widget.ctrl[widget.def.key]);
    final la = numOrNull(g['lat']), ln = numOrNull(g['lng']);
    if (la != null && ln != null) pos = LatLng(la.toDouble(), ln.toDouble());
    _sync();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _sync({bool fields = true}) {
    if (fields) {
      _lat.text = pos != null ? pos!.latitude.toStringAsFixed(6) : '';
      _lng.text = pos != null ? pos!.longitude.toStringAsFixed(6) : '';
    }
    widget.ctrl.set(widget.def.key, pos == null ? null : {'lat': double.parse(pos!.latitude.toStringAsFixed(6)), 'lng': double.parse(pos!.longitude.toStringAsFixed(6))});
  }

  /// Ricerca dell'indirizzo con il servizio gratuito di OpenStreetMap (serve la connessione).
  Future<void> _trova() async {
    final s = App.read(context);
    final q = widget.def.indirizzo.map((k) => str(widget.ctrl[k])).where((x) => x.isNotEmpty).join(', ');
    if (q.isEmpty) {
      s.toast('Compila prima indirizzo e città', err: true);
      return;
    }
    try {
      final r = await _geocode(q);
      if (r != null) {
        setState(() {
          pos = r;
          _ver++;
          _sync();
        });
        s.toast('Posizione trovata: controlla e sposta il segnaposto se serve');
      } else {
        s.toast('Indirizzo non trovato: clicca direttamente sulla mappa', err: true);
      }
    } catch (_) {
      s.toast('Ricerca non disponibile (serve la connessione): clicca direttamente sulla mappa', err: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final sede = sedePin(s);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        VButton("Trova dall'indirizzo", icon: 'search', size: BtnSize.sm, onAsync: _trova),
        SizedBox(
          width: 150,
          child: VInput(controller: _lat, hint: 'Latitudine', dense: true, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => _fromInputs()),
        ),
        SizedBox(
          width: 150,
          child: VInput(controller: _lng, hint: 'Longitudine', dense: true, keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true), onChanged: (_) => _fromInputs()),
        ),
        VButton('Rimuovi', size: BtnSize.sm, kind: BtnKind.ghost, onPressed: () => setState(() {
          pos = null;
          _sync();
        })),
      ]),
      const SizedBox(height: 8),
      VMap(
        key: ValueKey(_ver),
        height: 320,
        fit: false,
        center: pos ?? sede?.pos,
        zoom: pos != null ? 15 : (sede != null ? 11 : 6),
        pins: pos != null ? [MapPin(pos!, '', kind: 'dot')] : const [],
        onTap: (ll) => setState(() {
          pos = ll;
          _sync();
        }),
      ),
      const SizedBox(height: 6),
      Text('Clicca sulla mappa per indicare la posizione esatta.', style: t.text(size: 12.8, color: t.muted)),
    ]);
  }

  void _fromInputs() {
    final la = numOrNull(_lat.text), ln = numOrNull(_lng.text);
    if (la != null && ln != null && la.abs() <= 90 && ln.abs() <= 180) {
      setState(() {
        pos = LatLng(la.toDouble(), ln.toDouble());
        _ver++;
        _sync(fields: false);
      });
    }
  }
}

/* ---------------- Lista di elementi (collaboratori, servizi, offerte…) ---------------- */

class _ListField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _ListField({required this.ctrl, required this.def});
  @override
  State<_ListField> createState() => _ListFieldState();
}

class _ListFieldState extends State<_ListField> {
  late List<FormCtrl> rows;
  var _gen = 0;

  @override
  void initState() {
    super.initState();
    rows = [for (final r in jsonList(widget.ctrl[widget.def.key])) FormCtrl(widget.def.fields, r)];
    widget.ctrl.lists[widget.def.key] = rows;
  }

  void _update() {
    widget.ctrl.lists[widget.def.key] = rows;
    _gen++;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < rows.length; i++)
        Container(
          key: ValueKey('$_gen-$i'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
          decoration: BoxDecoration(color: context.t.tint, border: Border.all(color: t.line), borderRadius: t.rSm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('${i + 1}.', style: t.text(weight: FontWeight.w700)),
              const Spacer(),
              IconBtn('chevronUp', tooltip: 'Su', onPressed: i == 0 ? null : () {
                final x = rows.removeAt(i);
                rows.insert(i - 1, x);
                _update();
              }),
              IconBtn('chevronDown', tooltip: 'Giù', onPressed: i == rows.length - 1 ? null : () {
                final x = rows.removeAt(i);
                rows.insert(i + 1, x);
                _update();
              }),
              IconBtn('trash', tooltip: 'Elimina', danger: true, onPressed: () {
                rows.removeAt(i);
                _update();
              }),
            ]),
            const SizedBox(height: 6),
            VFormView(rows[i], minWidth: 180),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: VButton('Aggiungi ${widget.def.nomeElemento ?? 'elemento'}', icon: 'plus', size: BtnSize.sm, onPressed: () {
          rows.add(FormCtrl(widget.def.fields, {}));
          _update();
        }),
      ),
    ]);
  }
}

/* ---------------- Orari settimanali ---------------- */

const kGiorni = [('1', 'Lunedì'), ('2', 'Martedì'), ('3', 'Mercoledì'), ('4', 'Giovedì'), ('5', 'Venerdì'), ('6', 'Sabato'), ('0', 'Domenica')];

class _OrariField extends StatefulWidget {
  final FormCtrl ctrl;
  final FieldDef def;
  const _OrariField({required this.ctrl, required this.def});
  @override
  State<_OrariField> createState() => _OrariFieldState();
}

class _OrariFieldState extends State<_OrariField> {
  final Map<String, bool> aperto = {};
  final Map<String, List<String>> fasce = {}; // [a1, a2, b1, b2]

  @override
  void initState() {
    super.initState();
    final raw = widget.ctrl[widget.def.key];
    final cur = raw is List ? {for (var i = 0; i < raw.length; i++) '$i': raw[i]} : jsonOf(raw);
    for (final (k, _) in kGiorni) {
      final iv = cur[k] is List ? (cur[k] as List) : const [];
      aperto[k] = iv.isNotEmpty;
      final a = iv.isNotEmpty && iv[0] is List ? (iv[0] as List).map(str).toList() : ['09:00', '13:00'];
      final b = iv.length > 1 && iv[1] is List ? (iv[1] as List).map(str).toList() : ['', ''];
      fasce[k] = [a[0], a[1], b[0], b[1]];
    }
    _save();
  }

  void _save() {
    final out = <String, dynamic>{};
    for (final (k, _) in kGiorni) {
      final f = fasce[k]!;
      out[k] = aperto[k] != true
          ? []
          : [
              [f[0], f[1]],
              [f[2], f[3]]
            ].where((x) => x[0].isNotEmpty && x[1].isNotEmpty && x[0].compareTo(x[1]) < 0).toList();
    }
    widget.ctrl.set(widget.def.key, out);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(children: [
      for (final (k, nome) in kGiorni)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(10)),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6, children: [
            SizedBox(
              width: 150,
              child: VSwitch(small: true, value: aperto[k] == true, label: nome, onChanged: (v) => setState(() {
                aperto[k] = v;
                _save();
              })),
            ),
            if (aperto[k] == true)
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
                TimeBox(value: fasce[k]![0], label: '$nome apertura', onChanged: (v) => _set(k, 0, v)),
                const Text('–'),
                TimeBox(value: fasce[k]![1], label: '$nome chiusura', onChanged: (v) => _set(k, 1, v)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('e', style: t.text(size: 13.6, color: t.muted))),
                TimeBox(value: fasce[k]![2], label: '$nome riapertura', onChanged: (v) => _set(k, 2, v)),
                const Text('–'),
                TimeBox(value: fasce[k]![3], label: '$nome chiusura pomeriggio', onChanged: (v) => _set(k, 3, v)),
              ])
            else
              Text('Chiuso', style: t.text(size: 14.4, weight: FontWeight.w600, color: t.muted)),
          ]),
        ),
    ]);
  }

  void _set(String k, int i, String v) {
    fasce[k]![i] = v;
    _save();
  }
}

/* ---------------- Geocodifica ---------------- */

Future<LatLng?> _geocode(String q) async {
  final uri = Uri.https('nominatim.openstreetmap.org', '/search', {'format': 'jsonv2', 'limit': '1', 'q': q});
  final body = await NetworkAssetBundle(uri).load(uri.toString()).timeout(const Duration(seconds: 10));
  final list = jsonDecode(utf8.decode(body.buffer.asUint8List())) as List;
  if (list.isEmpty) return null;
  final r = list.first as Map;
  return LatLng(double.parse(str(r['lat'])), double.parse(str(r['lon'])));
}

