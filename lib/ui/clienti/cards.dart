/// Stelle e riquadro di una recensione (sito e area riservata).
library;

import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../state/app_state.dart';

/* ================= Stelle ================= */

class Stars extends StatelessWidget {
  final num voto;
  final double size;
  const Stars(this.voto, {super.key, this.size = 18});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final n = voto.round();
    return Semantics(
      label: '$n stelle su 5',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var k = 0; k < 5; k++) Padding(padding: const EdgeInsets.only(right: 2), child: VIcon('star', size: size, color: k < n ? t.accent : t.line2, filled: k < n)),
      ]),
    );
  }
}

/* ================= Recensioni ================= */

class ReviewTile extends StatelessWidget {
  final Json r;
  final bool admin;
  final Widget? footer;
  const ReviewTile(this.r, {super.key, this.admin = false, this.footer});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: admin ? t.surface : t.bg, borderRadius: t.r, border: admin ? Border.all(color: t.line) : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (footer != null && admin) const SizedBox.shrink(),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Stars(intOf(r['voto'], 5))),
        Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(str(r['testo']), style: t.text(size: 16.3))),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
          Text(str(r['nome']), style: t.text(weight: FontWeight.w700)),
          if (boolOf(r['verificata']))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(color: VTheme.okSoft, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const VIcon('check', size: 12, color: VTheme.ok),
                const SizedBox(width: 3),
                Text('Cliente verificato', style: t.text(size: 12, weight: FontWeight.w700, color: VTheme.ok, height: 1.4)),
              ]),
            ),
        ]),
        if (str(r['servizio']).isNotEmpty) Text(str(r['servizio']), style: t.text(size: 13.1, weight: FontWeight.w500, color: t.muted)),
        if (admin && str(r['email']).isNotEmpty) Text(str(r['email']), style: t.text(size: 13.1, color: t.muted)),
        if (str(r['risposta']).isNotEmpty && !admin)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: t.surface, border: Border(left: BorderSide(color: t.primary, width: 3)), borderRadius: BorderRadius.horizontal(right: Radius.circular(t.radiusSm))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Risposta di ${s.settings['nome']}', style: t.text(size: 14.7, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(str(r['risposta']), style: t.text(size: 14.7)),
            ]),
          ),
        ?footer,
      ]),
    );
  }
}
