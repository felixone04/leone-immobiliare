/// Componenti grafici di base (pulsanti, badge, riquadri, intestazioni…), con gli stessi stili del CSS.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';

/* ---------------- Navigazione ---------------- */

/// Apre un link: "#/percorso" o "/percorso" nell'app, altrimenti in una nuova scheda / app esterna.
void openLink(BuildContext context, String href, {bool newTab = false}) {
  final h = safeUrl(href);
  if (h.isEmpty || h == '#') return;
  if (h.startsWith('#/') || h.startsWith('/')) {
    final path = h.startsWith('#') ? h.substring(1) : h;
    if (newTab) {
      launchUrl(Uri.base.replace(fragment: path, query: ''), webOnlyWindowName: '_blank');
    } else {
      context.go(path);
    }
    return;
  }
  launchUrl(Uri.parse(h), webOnlyWindowName: h.startsWith('http') ? '_blank' : '_self');
}

/// Indirizzo completo di una pagina dell'app (per i link da copiare o condividere).
String fullLink(String path) => Uri.base.replace(fragment: path, query: '').toString();

/* ---------------- Layout ---------------- */

/// .container: larghezza massima 1240 con margini laterali
class Contained extends StatelessWidget {
  final Widget child;
  final double max;
  const Contained({super.key, required this.child, this.max = 1240});
  @override
  Widget build(BuildContext context) {
    final pad = context.vw <= 640 ? 16.0 : 24.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: max),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: pad), child: child),
      ),
    );
  }
}

/// .page-pad
EdgeInsets pagePad(BuildContext context) => context.vw <= 640 ? const EdgeInsets.only(top: 24, bottom: 48) : const EdgeInsets.only(top: 40, bottom: 72);

/// Griglia "auto-fill, minmax(min, 1fr)": calcola le colonne e allinea le righe in altezza.
class AutoGrid extends StatelessWidget {
  final double minWidth, gap, rowGap;
  final List<Widget> children;
  final bool equalHeight;
  final int? maxCols;
  const AutoGrid({super.key, required this.minWidth, required this.children, this.gap = 24, double? rowGap, this.equalHeight = true, this.maxCols})
      : rowGap = rowGap ?? gap;

  static int cols(double w, double minWidth, double gap) => ((w + gap) / (minWidth + gap)).floor().clamp(1, 99);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      var n = cols(c.maxWidth, minWidth, gap);
      if (maxCols != null && n > maxCols!) n = maxCols!;
      final rows = <Widget>[];
      for (var i = 0; i < children.length; i += n) {
        final cells = <Widget>[];
        for (var k = 0; k < n; k++) {
          if (k > 0) cells.add(SizedBox(width: gap));
          cells.add(Expanded(child: i + k < children.length ? children[i + k] : const SizedBox.shrink()));
        }
        final row = Row(crossAxisAlignment: equalHeight ? CrossAxisAlignment.stretch : CrossAxisAlignment.start, children: cells);
        if (rows.isNotEmpty) rows.add(SizedBox(height: rowGap));
        rows.add(equalHeight ? IntrinsicHeight(child: row) : row);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}

/// Riga che va a capo (flex-wrap) con spaziatura.
class Flow2 extends StatelessWidget {
  final List<Widget> children;
  final double gap, runGap;
  final WrapAlignment align;
  final WrapCrossAlignment cross;
  const Flow2({super.key, required this.children, this.gap = 8, double? runGap, this.align = WrapAlignment.start, this.cross = WrapCrossAlignment.center})
      : runGap = runGap ?? gap;
  @override
  Widget build(BuildContext context) => Wrap(spacing: gap, runSpacing: runGap, alignment: align, crossAxisAlignment: cross, children: children);
}

/* ---------------- Hover ---------------- */

class Hover extends StatefulWidget {
  final Widget Function(BuildContext context, bool hover) builder;
  final VoidCallback? onTap;
  final MouseCursor? cursor;
  const Hover({super.key, required this.builder, this.onTap, this.cursor});
  @override
  State<Hover> createState() => _HoverState();
}

class _HoverState extends State<Hover> {
  var _h = false;
  @override
  Widget build(BuildContext context) {
    final child = MouseRegion(
      cursor: widget.cursor ?? (widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer),
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: widget.builder(context, _h),
    );
    if (widget.onTap == null) return child;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: child);
  }
}

/* ---------------- Pulsanti ---------------- */

enum BtnKind { normal, primary, accent, outline, light, ghost }

enum BtnSize { sm, md, lg }

class VButton extends StatefulWidget {
  final String label;
  final String? icon, iconAfter;
  final BtnKind kind;
  final BtnSize size;
  final bool block, danger;
  final VoidCallback? onPressed;
  final Future<void> Function()? onAsync;
  final String? href;
  final bool newTab;
  final double? radius;
  const VButton(this.label,
      {super.key, this.icon, this.iconAfter, this.kind = BtnKind.normal, this.size = BtnSize.md, this.block = false, this.danger = false, this.onPressed, this.onAsync, this.href, this.newTab = false, this.radius});

  @override
  State<VButton> createState() => _VButtonState();
}

class _VButtonState extends State<VButton> {
  var _hover = false, _busy = false;

  bool get _enabled => !_busy && (widget.onPressed != null || widget.onAsync != null || widget.href != null);

  Future<void> _tap() async {
    if (!_enabled) return;
    if (widget.href != null) return openLink(context, widget.href!, newTab: widget.newTab);
    if (widget.onPressed != null) return widget.onPressed!();
    setState(() => _busy = true);
    try {
      await widget.onAsync!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    var bg = t.surface, fg = t.ink, border = _hover ? t.ink2 : t.line2;
    switch (widget.kind) {
      case BtnKind.primary:
        bg = _hover ? t.primaryDark : t.primary;
        fg = t.onPrimary;
        border = bg;
      case BtnKind.accent:
        bg = _hover ? Color.lerp(t.accent, Colors.white, .06)! : t.accent;
        fg = t.onAccent;
        border = t.accent;
      case BtnKind.outline:
        bg = _hover ? t.primarySoft : Colors.transparent;
        fg = t.primary;
        border = t.primary;
      case BtnKind.light:
        bg = _hover ? Colors.white : Colors.white.withValues(alpha: .95);
        fg = t.ink;
        border = Colors.transparent;
      case BtnKind.ghost:
        bg = _hover ? Colors.black.withValues(alpha: .05) : Colors.transparent;
        border = Colors.transparent;
      case BtnKind.normal:
        break;
    }
    if (widget.danger) fg = VTheme.danger;
    final sz = switch (widget.size) { BtnSize.sm => 13.8, BtnSize.md => 15.2, BtnSize.lg => 16.0 };
    final fontSize = sz;
    final pad = switch (widget.size) {
      BtnSize.sm => EdgeInsets.symmetric(horizontal: sz * .85, vertical: sz * .42),
      BtnSize.md => EdgeInsets.symmetric(horizontal: sz * 1.15, vertical: sz * .66),
      BtnSize.lg => EdgeInsets.symmetric(horizontal: sz * 1.5, vertical: sz * .85),
    };
    final label = widget.label;
    final style = t.text(size: fontSize, weight: FontWeight.w600, color: _busy ? Colors.transparent : fg, height: 1.3);
    final iconSize = fontSize * 1.15;
    Widget content = Row(
      mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[VIcon(widget.icon!, size: iconSize, color: _busy ? Colors.transparent : fg), if (label.isNotEmpty) SizedBox(width: fontSize * .5)],
        if (label.isNotEmpty) Flexible(child: Text(label, style: style, overflow: TextOverflow.ellipsis, maxLines: 1)),
        if (widget.iconAfter != null) ...[SizedBox(width: fontSize * .5), VIcon(widget.iconAfter!, size: iconSize, color: _busy ? Colors.transparent : fg)],
      ],
    );
    if (_busy) {
      content = Stack(alignment: Alignment.center, children: [
        content,
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: t.muted)),
      ]);
    }
    final radius = widget.radius ?? t.btnRadius;
    return Opacity(
      opacity: _enabled || _busy ? 1 : .55,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _tap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: pad,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

/// .icon-btn (36×36)
class IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool danger;
  final double size;
  final Color? color;
  const IconBtn(this.icon, {super.key, this.onPressed, this.tooltip, this.danger = false, this.size = 36, this.color});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final btn = Hover(
      onTap: onPressed,
      builder: (c, h) => Opacity(
        opacity: onPressed == null ? .3 : 1,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: h && onPressed != null ? Colors.black.withValues(alpha: .06) : null, borderRadius: BorderRadius.circular(10)),
          child: VIcon(icon, size: 18, color: color ?? (danger ? VTheme.danger : t.ink2)),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// .link-btn: testo sottolineato cliccabile
class LinkBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  const LinkBtn(this.label, {super.key, this.onTap, this.size = 14.4, this.color});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = color ?? t.primary;
    return Hover(
      onTap: onTap,
      builder: (_, h) => Text(label,
          style: t.text(size: size, weight: FontWeight.w600, color: c).copyWith(decoration: TextDecoration.underline, decorationColor: c)),
    );
  }
}

/// .link-arrow: "Vedi tutti →"
class LinkArrow extends StatelessWidget {
  final String label, href;
  const LinkArrow(this.label, this.href, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hover(
      onTap: () => openLink(context, href),
      builder: (_, h) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: t.text(weight: FontWeight.w700, color: t.primary)),
        const SizedBox(width: 6),
        AnimatedSlide(offset: Offset(h ? .17 : 0, 0), duration: const Duration(milliseconds: 150), child: VIcon('arrowRight', color: t.primary)),
      ]),
    );
  }
}

/// Testo-link generico (es. nel piè di pagina o nei contatti)
class TextLink extends StatelessWidget {
  final String text, href;
  final TextStyle? style;
  final bool underlineOnHover;
  const TextLink(this.text, this.href, {super.key, this.style, this.underlineOnHover = true});
  @override
  Widget build(BuildContext context) {
    final st = style ?? context.t.text(color: context.t.primary);
    return Hover(
      onTap: () => openLink(context, href),
      builder: (_, h) => Text(text, style: h && underlineOnHover ? st.copyWith(decoration: TextDecoration.underline, decorationColor: st.color) : st),
    );
  }
}

/* ---------------- Etichette ---------------- */

class VBadge extends StatelessWidget {
  final String text;
  final bool soft, onImage;
  const VBadge(this.text, {super.key, this.soft = false, this.onImage = true});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    Color bg, fg;
    if (!soft) {
      bg = t.primary;
      fg = t.onPrimary;
    } else if (onImage) {
      bg = Colors.white.withValues(alpha: .94);
      fg = t.ink;
    } else {
      bg = t.primarySoft;
      fg = t.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.pill)),
      child: Text(text, style: t.text(size: 12.2, weight: FontWeight.w700, color: fg, height: 1.25, spacing: .12)),
    );
  }
}

/// Pillola di stato (.pill.st-ok / warn / err / muted)
class Pill extends StatelessWidget {
  final String text, tone;
  final String? icon;
  const Pill(this.text, {super.key, this.tone = 'muted', this.icon});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (bg, fg) = switch (tone) {
      'ok' => (VTheme.okSoft, VTheme.ok),
      'warn' => (VTheme.warnSoft, VTheme.warn),
      'err' => (VTheme.errSoft, VTheme.danger),
      'plain' => (t.bg, t.ink2),
      _ => (VTheme.mutedSoft, t.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[VIcon(icon!, size: 13, color: fg), const SizedBox(width: 4)],
        Text(text, style: t.text(size: 12.5, weight: FontWeight.w700, color: fg, height: 1.3)),
      ]),
    );
  }
}

/// Stati con etichetta e colore: { 'stato': ('Etichetta', 'tono') }
Widget statoPill(Map<String, (String, String)> stati, String s) {
  final v = stati[s];
  return Pill(v?.$1 ?? s, tone: v?.$2 ?? 'muted');
}

class Ribbon extends StatelessWidget {
  final String text;
  final bool big;
  const Ribbon(this.text, {super.key, this.big = false});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final sz = big ? 13.6 : 12.2;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 6 : 4),
      decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(t.pill)),
      child: Text(text.toUpperCase(), style: t.text(size: sz, weight: FontWeight.w800, color: t.onAccent, height: 1.25, spacing: sz * .05)),
    );
  }
}

/// Etichetta di un annuncio: Esclusiva (nero), Nuovo (colore principale), Prezzo ribassato (rosso).
class EtichettaTag extends StatelessWidget {
  final String text;
  const EtichettaTag(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bg = switch (text) { 'Esclusiva' => t.accent, 'Prezzo ribassato' => VTheme.danger, _ => t.primary };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(t.pill)),
      child: Text(text.toUpperCase(), style: t.text(size: 11.2, weight: FontWeight.w800, color: contrastOn(bg), spacing: .6, height: 1.3)),
    );
  }
}

/* ---------------- Riquadri ---------------- */

/// .card-box
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color, borderColor;
  final List<BoxShadow>? shadow;
  final double? radius;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(24), this.color, this.borderColor, this.shadow, this.radius});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.surface,
        border: Border.all(color: borderColor ?? t.line),
        borderRadius: BorderRadius.circular(radius ?? t.radius),
        boxShadow: shadow,
      ),
      child: child,
    );
  }
}

/// Titolo di un card-box (h2 1.25rem con icona)
class BoxTitle extends StatelessWidget {
  final String text;
  final String? icon;
  final double size;
  final Color? color;
  const BoxTitle(this.text, {super.key, this.icon, this.size = 20, this.color});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: EdgeInsets.only(bottom: size * .5),
      child: Row(children: [
        if (icon != null) ...[VIcon(icon!, size: size * 1.1, color: color ?? t.ink), const SizedBox(width: 10)],
        Expanded(child: Text(text, style: t.title(size: size, color: color))),
      ]),
    );
  }
}

/// .alert
class AlertBox extends StatelessWidget {
  final Widget child;
  final String icon;
  final bool err, ok;
  final CrossAxisAlignment align;
  const AlertBox({super.key, required this.child, this.icon = 'info', this.err = false, this.ok = false, this.align = CrossAxisAlignment.center});
  factory AlertBox.text(String text, {String icon = 'info', bool err = false}) => AlertBox(icon: icon, err: err, child: _AlertText(text, err: err));
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final bg = err ? VTheme.errSoft : ok ? VTheme.okSoft : mix(t.accent, .16, Colors.white);
    final bd = err ? const Color(0xFFF5C2BD) : ok ? const Color(0xFFB9E3C9) : mix(t.accent, .4, Colors.white);
    final fg = err ? VTheme.danger : ok ? VTheme.ok : t.ink;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: bg, border: Border.all(color: bd), borderRadius: t.rSm),
      child: Row(crossAxisAlignment: align, children: [
        Padding(padding: EdgeInsets.only(top: align == CrossAxisAlignment.start ? 3 : 0), child: VIcon(icon, color: fg)),
        const SizedBox(width: 10),
        Expanded(child: DefaultTextStyle(style: t.text(color: err ? VTheme.danger : t.ink), child: child)),
      ]),
    );
  }
}

class _AlertText extends StatelessWidget {
  final String text;
  final bool err;
  const _AlertText(this.text, {this.err = false});
  @override
  Widget build(BuildContext context) => Text(text);
}

/* ---------------- Intestazioni di pagina ---------------- */

/// Il tetto del logo Leone: cuneo sottile alle estremità e spesso al colmo.
class RoofMark extends StatelessWidget {
  final double width, height;
  final Color color;
  const RoofMark({super.key, required this.width, required this.height, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height, child: CustomPaint(painter: _RoofPainter(color)));
}

class _RoofPainter extends CustomPainter {
  final Color color;
  const _RoofPainter(this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(0, s.height)
      ..lineTo(s.width / 2, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width / 2, s.height * .3)
      ..close();
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_RoofPainter old) => old.color != color;
}

/// .page-hero con briciole di pane
class PageHero extends StatelessWidget {
  final String title;
  final bool slim;
  final List<(String, String?)> crumbs;
  const PageHero(this.title, {super.key, this.slim = false, this.crumbs = const []});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: t.primary),
      clipBehavior: Clip.hardEdge,
      child: Stack(children: [
        // il tetto del logo, grande e in trasparenza
        Positioned(right: -60, bottom: -6, child: RoofMark(width: 620, height: 190, color: Colors.white.withValues(alpha: .1))),
        Contained(
          child: Padding(
            padding: slim ? const EdgeInsets.only(top: 32, bottom: 28) : const EdgeInsets.only(top: 44, bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Crumbs([('Home', '/'), ...crumbs, (title, null)], light: true),
                Text(title, style: t.title(size: t.h1(context), color: t.onPrimary)),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

class Crumbs extends StatelessWidget {
  final List<(String, String?)> items;
  final bool light;
  const Crumbs(this.items, {super.key, this.light = false});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final base = light ? t.onPrimary.withValues(alpha: .75) : t.muted;
    final cur = light ? t.onPrimary : t.ink;
    final kids = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final (label, href) = items[i];
      if (i > 0) kids.add(Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: VIcon('chevronRight', size: 14, color: base.withValues(alpha: base.a * .6))));
      if (href != null) {
        kids.add(TextLink(label, '#$href', style: t.text(size: 13.9, color: base)));
      } else {
        kids.add(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1, style: t.text(size: 13.9, weight: FontWeight.w600, color: cur)),
        ));
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: kids),
    );
  }
}

/// .section-head: titolo, sottotitolo e link a destra
class SectionHead extends StatelessWidget {
  final String? title, subtitle;
  final Widget? trailing, subtitleWidget;
  const SectionHead({super.key, this.title, this.subtitle, this.trailing, this.subtitleWidget});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (title == null && subtitle == null && trailing == null && subtitleWidget == null) return const SizedBox.shrink();
    final txt = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null && title!.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.only(bottom: 12), child: RoofMark(width: 54, height: 16, color: t.primary)),
          Text(title!, style: t.title(size: t.h2(context))),
        ],
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Text(subtitle!, style: t.text(color: t.muted))),
          ),
        if (subtitleWidget != null) Padding(padding: const EdgeInsets.only(top: 6), child: subtitleWidget!),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 24,
        runSpacing: 16,
        children: [txt, ?trailing],
      ),
    );
  }
}

/// .empty
class EmptyState extends StatelessWidget {
  final String icon;
  final String? title, text;
  final List<Widget> actions;
  final bool small;
  const EmptyState({super.key, required this.icon, this.title, this.text, this.actions = const [], this.small = false});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(small ? 32 : 56).copyWith(left: 24, right: 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: t.r,
        border: Border.all(color: t.line2),
      ),
      child: Column(children: [
        VIcon(icon, size: 44, color: t.muted),
        const SizedBox(height: 12),
        if (title != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title!, textAlign: TextAlign.center, style: t.title(size: t.h2(context)))),
        if (text != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(text!, textAlign: TextAlign.center, style: t.text(color: t.muted))),
        if (actions.isNotEmpty) Flow2(align: WrapAlignment.center, children: actions),
      ]),
    );
  }
}

class Loader extends StatelessWidget {
  final bool small;
  const Loader({super.key, this.small = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: small ? 20 : 60),
        child: Center(child: SizedBox(width: small ? 24 : 36, height: small ? 24 : 36, child: CircularProgressIndicator(strokeWidth: 3, color: context.t.primary))),
      );
}

/// Linea divisoria orizzontale
class HLine extends StatelessWidget {
  final double top, bottom;
  final bool dashed;
  const HLine({super.key, this.top = 0, this.bottom = 0, this.dashed = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: bottom),
        child: dashed ? DashedLine(color: context.t.line) : Container(height: 1, color: context.t.line),
      );
}

class DashedLine extends StatelessWidget {
  final Color color;
  final double dash, gap;
  const DashedLine({super.key, required this.color, this.dash = 4, this.gap = 3});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, box) {
        final n = (box.maxWidth / (dash + gap)).floor();
        return Row(children: [for (var i = 0; i < n; i++) Container(width: dash, height: 1, margin: EdgeInsets.only(right: gap), color: color)]);
      });
}

/* ---------------- Immagini ---------------- */

/// Immagine da asset, da caricamento locale (media:) o dal web; se non disponibile mostra [fallback].
class VImage extends StatelessWidget {
  final String src;
  final BoxFit fit;
  final double? width, height;
  final Widget? fallback;
  final Alignment alignment;
  const VImage(this.src, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.fallback, this.alignment = Alignment.center});

  @override
  Widget build(BuildContext context) {
    final s = safeSrc(src);
    final fb = fallback ?? const SizedBox.shrink();
    if (s.isEmpty) return fb;
    Widget err(BuildContext c, Object e, StackTrace? st) => fb;
    if (s.startsWith('assets/')) {
      if (s.endsWith('.svg')) return SvgPicture.asset(s, fit: fit, width: width, height: height, alignment: alignment);
      return Image.asset(s, fit: fit, width: width, height: height, alignment: alignment, errorBuilder: err, gaplessPlayback: true);
    }
    if (s.startsWith('media:')) {
      final bytes = App.of(context).repo.media[s.substring(6)];
      if (bytes == null) return fb;
      return Image.memory(bytes, fit: fit, width: width, height: height, alignment: alignment, errorBuilder: err, gaplessPlayback: true);
    }
    return Image.network(s, fit: fit, width: width, height: height, alignment: alignment, errorBuilder: err);
  }
}

/// Segnaposto con l'icona del catalogo (.ph)
class PlaceholderIcon extends StatelessWidget {
  final String icon;
  final double size;
  const PlaceholderIcon(this.icon, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      color: t.primarySoft,
      alignment: Alignment.center,
      child: VIcon(icon, size: size, stroke: 1.3, color: t.primary.withValues(alpha: .4)),
    );
  }
}

/// Spaziatura verticale rapida
class Gap extends StatelessWidget {
  final double h;
  const Gap(this.h, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}
