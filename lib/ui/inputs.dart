/// Campi dei moduli con lo stile del sito: caselle di testo, select, interruttori, chip, segmenti.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import 'kit.dart';

InputDecoration vDecoration(VTheme t,
    {String? hint, String? icon, bool invalid = false, double radius = -1, EdgeInsets? padding, Color? fill, bool dense = false, Widget? suffix}) {
  final r = BorderRadius.circular(radius < 0 ? t.radiusSm : radius);
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: r, borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    isDense: true,
    hintText: hint,
    hintStyle: t.text(color: t.muted.withValues(alpha: .8)),
    filled: true,
    fillColor: invalid ? const Color(0xFFFFF8F7) : (fill ?? Colors.white),
    contentPadding: padding ?? EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 9 : 12),
    prefixIcon: icon != null ? Padding(padding: const EdgeInsets.only(left: 12, right: 8), child: VIcon(icon, color: t.muted)) : null,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    enabledBorder: b(invalid ? VTheme.danger : t.line2),
    border: b(t.line2),
    focusedBorder: b(t.primary, 1.6),
  );
}

/// Casella di testo
class VInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hint, icon, initial;
  final ValueChanged<String>? onChanged, onSubmitted;
  final int minLines, maxLines;
  final TextInputType? keyboard;
  final bool obscure, invalid, readOnly, dense, autofocus;
  final int? maxLength;
  final double radius;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? formatters;
  final Iterable<String>? autofill;
  final TextCapitalization caps;
  final Color? fill;
  final Widget? suffix;
  final TextStyle? style;
  const VInput({
    super.key,
    this.controller,
    this.hint,
    this.icon,
    this.initial,
    this.onChanged,
    this.onSubmitted,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboard,
    this.obscure = false,
    this.invalid = false,
    this.readOnly = false,
    this.dense = false,
    this.autofocus = false,
    this.maxLength,
    this.radius = -1,
    this.focusNode,
    this.formatters,
    this.autofill,
    this.caps = TextCapitalization.none,
    this.fill,
    this.suffix,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initial : null,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      minLines: obscure ? 1 : minLines,
      maxLines: obscure ? 1 : (maxLines < minLines ? minLines : maxLines),
      keyboardType: keyboard ?? (maxLines > 1 ? TextInputType.multiline : null),
      obscureText: obscure,
      readOnly: readOnly,
      autofocus: autofocus,
      focusNode: focusNode,
      inputFormatters: [if (maxLength != null) LengthLimitingTextInputFormatter(maxLength), ...?formatters],
      autofillHints: autofill,
      textCapitalization: caps,
      style: style ?? t.text(size: 15.5, height: 1.4),
      cursorColor: t.primary,
      decoration: vDecoration(t, hint: hint, icon: icon, invalid: invalid, radius: radius, dense: dense, fill: fill, suffix: suffix),
    );
  }
}

/// Etichetta sopra un campo (stile .contact-form label)
class FieldLabel extends StatelessWidget {
  final String text;
  final Widget child;
  final bool required;
  final String? unit, hint;
  final bool strong;
  const FieldLabel(this.text, {super.key, required this.child, this.required = false, this.unit, this.hint, this.strong = false});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: EdgeInsets.only(bottom: strong ? 6 : 4),
        child: Text.rich(
          TextSpan(text: text, children: [
            if (required) const TextSpan(text: ' *', style: TextStyle(color: VTheme.danger)),
            if (unit != null) TextSpan(text: ' $unit', style: TextStyle(color: t.muted, fontWeight: FontWeight.w500)),
          ]),
          style: t.text(size: strong ? 14.1 : 13.6, weight: FontWeight.w600, color: strong ? t.ink : t.ink2, height: 1.3),
        ),
      ),
      child,
      if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: t.text(size: 12.8, color: t.muted, height: 1.4))),
    ]);
  }
}

/// Menu a tendina
class VSelect<T> extends StatelessWidget {
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?>? onChanged;
  final bool invalid, dense;
  final double radius;
  final String? hint;
  final double? height;
  final TextStyle? style;
  const VSelect({super.key, required this.value, required this.items, this.onChanged, this.invalid = false, this.dense = false, this.radius = -1, this.hint, this.height, this.style});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final r = radius < 0 ? t.radiusSm : radius;
    final has = items.any((e) => e.$1 == value);
    return Container(
      height: height ?? (dense ? 38 : 44),
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: invalid ? const Color(0xFFFFF8F7) : Colors.white,
        border: Border.all(color: invalid ? VTheme.danger : t.line2),
        borderRadius: BorderRadius.circular(r),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: has ? value : null,
          isExpanded: true,
          isDense: true,
          focusColor: Colors.transparent,
          icon: VIcon('chevronDown', size: 16, color: t.ink2),
          borderRadius: BorderRadius.circular(10),
          dropdownColor: Colors.white,
          hint: hint != null ? Text(hint!, style: t.text(color: t.muted, size: 15)) : null,
          style: style ?? t.text(size: 15, height: 1.3),
          items: [for (final (v, l) in items) DropdownMenuItem<T>(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Interruttore (.switch)
class VSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final bool small;
  final TextStyle? labelStyle;
  const VSwitch({super.key, required this.value, this.onChanged, this.label, this.small = false, this.labelStyle});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final track = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: value ? t.primary : t.line2, borderRadius: BorderRadius.circular(999)),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 3, offset: Offset(0, 1))]),
        ),
      ),
    );
    return Semantics(
      toggled: value,
      label: label,
      child: Hover(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        builder: (_, h) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: small ? 0 : 44),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            track,
            if (label != null) ...[
              const SizedBox(width: 10),
              Flexible(child: Text(label!, style: labelStyle ?? t.text(size: 14.7, weight: FontWeight.w600, height: 1.35))),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Casella di spunta con testo (label.check)
class VCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget label;
  final bool invalid;
  const VCheck({super.key, required this.value, required this.onChanged, required this.label, this.invalid = false});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hover(
      onTap: () => onChanged(!value),
      builder: (_, h) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            color: value ? t.primary : Colors.white,
            border: Border.all(color: value ? t.primary : (invalid ? VTheme.danger : const Color(0xFF8A8F96)), width: 1.4),
            borderRadius: BorderRadius.circular(3),
          ),
          child: value ? VIcon('check', size: 13, stroke: 3, color: t.onPrimary) : null,
        ),
        const SizedBox(width: 10),
        Expanded(child: DefaultTextStyle(style: t.text(size: 14.1, weight: FontWeight.w500, color: t.ink2, height: 1.45), child: label)),
      ]),
    );
  }
}

/// Chip selezionabile (.chip)
class VChip extends StatelessWidget {
  final String label;
  final bool selected, small;
  final String icon;
  final VoidCallback onTap;
  const VChip(this.label, {super.key, required this.selected, required this.onTap, this.small = false, this.icon = 'check'});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hover(
      onTap: onTap,
      builder: (_, h) => AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(horizontal: small ? 11 : 14, vertical: small ? 5 : 7),
        decoration: BoxDecoration(
          color: selected ? t.primary : Colors.white,
          border: Border.all(color: selected || h ? t.primary : t.line2),
          borderRadius: BorderRadius.circular(t.controlRadius),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 120),
            child: selected ? Padding(padding: const EdgeInsets.only(right: 6), child: VIcon(icon, size: 14, color: t.onPrimary)) : const SizedBox.shrink(),
          ),
          Text(label, style: t.text(size: small ? 13.4 : 14.1, weight: FontWeight.w600, color: selected ? t.onPrimary : t.ink, height: 1.3)),
        ]),
      ),
    );
  }
}

/// Pulsanti a segmenti (.seg)
class SegButtons extends StatelessWidget {
  final List<(String, String)> options; // (valore, etichetta)
  final String value;
  final ValueChanged<String> onChanged;
  const SegButtons({super.key, required this.options, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return LayoutBuilder(builder: (c, box) {
      return Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (v, l) in options)
          Hover(
            onTap: () => onChanged(v),
            builder: (_, h) {
              final on = v == value;
              return Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: on ? t.primary : Colors.white,
                  border: Border.all(color: on || h ? t.primary : t.line2),
                  borderRadius: BorderRadius.circular(t.minimal ? 0 : (t.elegante ? 3 : t.radiusSm)),
                ),
                child: Text(l, textAlign: TextAlign.center, style: t.text(size: 14.4, weight: FontWeight.w600, color: on ? t.onPrimary : t.ink, height: 1.3)),
              );
            },
          ),
      ]);
    });
  }
}

/// Testo dell'errore di un modulo (.login-err)
class FormError extends StatelessWidget {
  final String? text;
  const FormError(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox(height: 4);
    return Text(text!, style: context.t.text(size: 14.4, weight: FontWeight.w600, color: VTheme.danger));
  }
}

/// Esito positivo di un modulo (.msg-ok)
class MsgOk extends StatelessWidget {
  final String title;
  final String? text;
  final List<Widget> extra;
  const MsgOk(this.title, {super.key, this.text, this.extra = const []});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: VTheme.okSoft, borderRadius: t.rSm),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const VIcon('check', size: 28, color: VTheme.ok),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.text(weight: FontWeight.w700)),
            if (text != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(text!, style: t.text())),
            ...extra,
          ]),
        ),
      ]),
    );
  }
}
