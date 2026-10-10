/// Anteprima di un annuncio (.card) e griglia di anteprime.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../state/app_state.dart';
import '../kit.dart';

class ItemCard extends StatefulWidget {
  final Json item;
  const ItemCard(this.item, {super.key});
  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  var _h = false;

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final cat = s.cat;
    final cd = s.repo.schema.card;
    final item = widget.item;
    if (s.repo.schema.isListino) return _ListinoCard(item);
    final fotos = cat.foto(item), nastro = cat.nastro(item), luogo = cat.luogo(item);
    final chips = cd.chips != null ? strList(item[cd.chips]).take(3).toList() : <String>[];
    final specs = [for (final sp in cd.specs) (sp.icona, cat.spec(item, sp))].where((x) => x.$2.isNotEmpty).toList();
    final estratto = cd.estratto != null ? str(item[cd.estratto]) : '';
    final hoverLift = t.minimal ? 0.0 : (t.moderno ? -4.0 : -2.0);
    final border = t.minimal && _h ? const Color(0xFF111111) : (t.elegante || t.moderno ? Colors.transparent : t.line);
    final shadow = t.minimal ? null : ((_h || t.elegante || t.moderno) ? t.shadow : null);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: () => context.go('/scheda/${item['id']}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _h ? hoverLift : 0, 0),
          decoration: BoxDecoration(color: t.surface, borderRadius: t.r, border: Border.all(color: border), boxShadow: shadow),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(fit: StackFit.expand, children: [
                PlaceholderIcon(s.repo.schema.icona),
                if (fotos.isNotEmpty)
                  ClipRect(
                    child: AnimatedScale(
                      scale: _h && !t.minimal ? 1.04 : 1,
                      duration: const Duration(milliseconds: 500),
                      child: ColorFiltered(
                        colorFilter: nastro.isNotEmpty ? _saturate(.55) : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                        child: VImage(fotos.first),
                      ),
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 90,
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (var i = 0; i < cd.badge.length; i++)
                      if (str(item[cd.badge[i]]).isNotEmpty) VBadge(str(item[cd.badge[i]]), soft: i > 0),
                  ]),
                ),
                if (nastro.isNotEmpty) Positioned(top: 12, right: 12, child: Ribbon(nastro)),
                if (fotos.length > 1)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const VIcon('image', size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text('${fotos.length}', style: t.text(size: 12.5, weight: FontWeight.w600, color: Colors.white, height: 1.3)),
                      ]),
                    ),
                  ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PriceText(item, size: t.elegante ? 23.2 : 20.8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 6),
                    child: Text(str(item[cd.titolo]), style: t.title(size: 16.5, weight: FontWeight.w700, height: 1.25)),
                  ),
                  if (luogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        VIcon('pin', size: 16, color: t.muted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(luogo, style: t.text(size: 14.4, color: t.muted, height: 1.4))),
                      ]),
                    ),
                  if (estratto.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(estratto, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.text(size: 14.4, color: t.ink2))),
                  if (chips.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final c in chips)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(t.pill)),
                            child: Text(t.elegante ? c.toUpperCase() : c, style: t.text(size: t.elegante ? 10.9 : 12.2, weight: FontWeight.w600, color: t.primary, height: 1.3)),
                          ),
                      ]),
                    ),
                  const Spacer(),
                  if (specs.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
                      child: Wrap(spacing: 16, runSpacing: 6, children: [
                        for (final (ic, txt) in specs)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            VIcon(ic, size: 17, color: t.muted),
                            const SizedBox(width: 6),
                            Text(txt, style: t.text(size: 14.1, weight: FontWeight.w600, color: t.ink2, height: 1.3)),
                          ]),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Filtro di saturazione (immagini degli annunci non disponibili)
ColorFilter _saturate(double s) {
  final inv = 1 - s;
  final r = .2126 * inv, g = .7152 * inv, b = .0722 * inv;
  return ColorFilter.matrix([
    r + s, g, b, 0, 0, //
    r, g + s, b, 0, 0,
    r, g, b + s, 0, 0,
    0, 0, 0, 1, 0,
  ]);
}

/// Prezzo con l'eventuale prezzo pieno barrato.
class PriceText extends StatelessWidget {
  final Json item;
  final double size;
  final Color? color;
  const PriceText(this.item, {super.key, this.size = 20.8, this.color});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final pieno = s.cat.prezzoPieno(item);
    final c = color ?? t.priceColor;
    return Text.rich(
      TextSpan(children: [
        if (pieno != null) TextSpan(text: '$pieno ', style: TextStyle(color: t.muted, fontWeight: FontWeight.w500, fontSize: size * .82, decoration: TextDecoration.lineThrough, decorationColor: t.muted)),
        TextSpan(text: s.cat.prezzo(item), style: TextStyle(color: pieno != null ? VTheme.danger : c)),
      ]),
      style: t.title(size: size, weight: t.elegante ? FontWeight.w700 : FontWeight.w800, spacing: -.02 * size, height: 1.2),
    );
  }
}

/// Riga compatta da listino prezzi (tipologie a listino).
class _ListinoCard extends StatelessWidget {
  final Json item;
  const _ListinoCard(this.item);
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final cat = s.cat;
    final cd = s.repo.schema.card;
    final foto = cat.foto(item).firstOrNull;
    final et = cat.etichetta(item);
    final specs = [for (final sp in cd.specs) (sp.icona, cat.spec(item, sp))].where((x) => x.$2.isNotEmpty).toList();
    final estratto = cd.estratto != null ? str(item[cd.estratto]).replaceAll(RegExp(r'[*#]'), '') : '';
    return Hover(
      onTap: () => context.go('/scheda/${item['id']}'),
      builder: (_, h) => Container(
        decoration: BoxDecoration(color: t.surface, borderRadius: t.r, border: Border.all(color: h ? mix(t.primary, .35, t.line) : t.line)),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (foto != null) SizedBox(width: context.vw <= 480 ? 88 : 116, child: VImage(foto, fallback: Container(color: t.primarySoft))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(str(item[cd.titolo]), style: t.title(size: 16.3, weight: FontWeight.w700))),
                    const SizedBox(width: 12),
                    PriceText(item, size: 17.3),
                  ]),
                  if (et.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: TagPromo(et)),
                  if (estratto.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(estratto, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.text(size: 14.1, color: t.muted))),
                  if (specs.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.only(top: 10),
                      width: double.infinity,
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
                      child: Wrap(spacing: 16, runSpacing: 6, children: [
                        for (final (ic, txt) in specs)
                          Row(mainAxisSize: MainAxisSize.min, children: [VIcon(ic, size: 17, color: t.muted), const SizedBox(width: 6), Text(txt, style: t.text(size: 13.4, weight: FontWeight.w600, color: t.ink2))]),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Griglia di anteprime (.cards)
class CardsGrid extends StatelessWidget {
  final List<Json> items;
  final double minWidth;
  const CardsGrid(this.items, {super.key, this.minWidth = 290});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final listino = s.repo.schema.isListino;
    final narrow = context.vw <= 640;
    return AutoGrid(
      minWidth: listino ? 420 : (narrow ? 9999 : minWidth),
      gap: listino ? 14 : (narrow ? 16 : 24),
      children: [for (final i in items) ItemCard(i, key: ValueKey(i['id']))],
    );
  }
}
