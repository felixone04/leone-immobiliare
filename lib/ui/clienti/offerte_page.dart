/// #/offerte: tutte le offerte in corso.
library;

import 'package:flutter/material.dart';

import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../kit.dart';
import '../shell.dart';
import 'cards.dart';

class OffertePage extends StatelessWidget {
  const OffertePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    Widget body;
    if (!s.modulo('offerte')) {
      body = const EmptyState(icon: 'tag', title: 'Funzione non disponibile', actions: [VButton('Torna alla home', kind: BtnKind.primary, href: '#/')]);
    } else {
      final offerte = s.repo.offerteAttive();
      body = offerte.isEmpty
          ? const EmptyState(icon: 'tag', title: 'Nessuna offerta in corso', text: 'Torna a trovarci presto!')
          : Padding(padding: const EdgeInsets.only(top: 20), child: AutoGrid(minWidth: 290, gap: 20, children: [for (final o in offerte) OffertaCard(o, offerte)]));
    }
    return PageScroll(children: [
      const PageHero('Offerte', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }
}
