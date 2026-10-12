/// Anteprima di un annuncio (.card) e griglia di anteprime.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../state/app_state.dart';
import '../clienti/account.dart';
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
    final fotos = cat.foto(item), nastro = cat.nastro(item), luogo = cat.luogo(item), etichette = cat.etichette(item);
    final chips = cd.chips != null ? strList(item[cd.chips]).take(3).toList() : <String>[];
    final specs = [for (final sp in cd.specs) (sp.icona, cat.spec(item, sp))].where((x) => x.$2.isNotEmpty).toList();
    final hoverLift = -2.0;
    final border = t.line;
    final shadow = _h ? t.shadow : null;

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
                      scale: _h ? 1.04 : 1,
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
                  right: 60,
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (var i = 0; i < cd.badge.length; i++)
                      if (str(item[cd.badge[i]]).isNotEmpty) VBadge(str(item[cd.badge[i]]), soft: i > 0),
                    if (nastro.isNotEmpty) Ribbon(nastro),
                  ]),
                ),
                Positioned(top: 10, right: 10, child: PreferitoBtn(item['id'] as String)),
                if (etichette.isNotEmpty)
                  Positioned(left: 12, bottom: 12, right: 60, child: Wrap(spacing: 6, runSpacing: 6, children: [for (final e in etichette) EtichettaTag(e)])),
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
                  PriceText(item, size: 20.8),
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
                  if (chips.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final c in chips)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(t.pill)),
                            child: Text(c, style: t.text(size: 12.2, weight: FontWeight.w600, color: t.primary, height: 1.3)),
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
    final c = color ?? t.primary;
    return Text.rich(
      TextSpan(children: [
        if (pieno != null) TextSpan(text: '$pieno ', style: TextStyle(color: t.muted, fontWeight: FontWeight.w500, fontSize: size * .82, decoration: TextDecoration.lineThrough, decorationColor: t.muted)),
        TextSpan(text: s.cat.prezzo(item), style: TextStyle(color: pieno != null ? VTheme.danger : c)),
      ]),
      style: t.title(size: size, spacing: -.02 * size, height: 1.2),
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
    final narrow = context.vw <= 640;
    return AutoGrid(
      minWidth: narrow ? 9999 : minWidth,
      gap: narrow ? 16 : 24,
      children: [for (final i in items) ItemCard(i, key: ValueKey(i['id']))],
    );
  }
}

/// Riga compatta di un immobile: foto, titolo, prezzo e luogo (account del cliente, area riservata).
class ItemRow extends StatelessWidget {
  final Json item;
  final String? nota;
  final Widget? trailing;
  final String? href;
  const ItemRow(this.item, {super.key, this.nota, this.trailing, this.href});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final foto = s.cat.foto(item).firstOrNull;
    final nastro = s.cat.nastro(item);
    return Hover(
      onTap: () => openLink(context, href ?? '#/scheda/${item['id']}'),
      builder: (_, h) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: h ? t.tint2 : null, borderRadius: t.rSm),
        child: Row(children: [
          ClipRRect(
            borderRadius: t.rSm,
            child: Container(width: 72, height: 54, color: t.primarySoft, child: foto != null ? VImage(foto) : PlaceholderIcon(s.repo.schema.icona, size: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(str(item['titolo']), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text(weight: FontWeight.w600, height: 1.35)),
              Text(
                [s.cat.prezzo(item), s.cat.luogo(item), if (nastro.isNotEmpty) nastro].where((x) => x.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.text(size: 13.6, color: t.muted, height: 1.35),
              ),
              if (nota != null && nota!.isNotEmpty) Text(nota!, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.text(size: 13.1, weight: FontWeight.w600, color: t.primary, height: 1.35)),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}
