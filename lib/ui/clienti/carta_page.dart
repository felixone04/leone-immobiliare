/// #/carta/CODICE (e #/fedelta/CODICE): la carta del cliente con il suo stato.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../kit.dart';
import '../shell.dart';
import 'cards.dart';
import 'print_card.dart';

class CartaPage extends StatelessWidget {
  final String codice;
  final bool nuova;
  const CartaPage({super.key, required this.codice, this.nuova = false});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Json? c;
    try {
      c = s.repo.cartaVedi(codice);
    } on AppError {
      c = null;
    }
    Widget body;
    if (c == null) {
      body = const EmptyState(icon: 'search', title: 'Codice non trovato', text: 'Controlla il codice inserito.');
    } else {
      final tipo = str(c['tipo']);
      final testo = switch (tipo) {
        'fedelta' => 'Mostra questo codice in cassa a ogni visita per ricevere i timbri.',
        'pacchetto' => c['stato'] == 'da_pagare' ? 'Presenta il codice in struttura: dopo il pagamento il pacchetto sarà attivo.' : 'Mostra il codice a ogni seduta: te la scaliamo noi.',
        _ => "Mostra questo codice in cassa per usufruire dell'offerta.",
      };
      body = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (nuova)
              AlertBox(
                icon: 'check',
                ok: true,
                align: CrossAxisAlignment.start,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: 'Fatto!', style: t.text(weight: FontWeight.w700)),
                  const TextSpan(text: ' Salva questa pagina tra i preferiti o fai uno screenshot: il tuo codice è '),
                  WidgetSpan(alignment: PlaceholderAlignment.middle, child: CodeTag(str(c['codice']))),
                  const TextSpan(text: '.'),
                ])),
              ),
            PrintableCard(
              title: str(c['codice']),
              child: CardVisual(tipo, c),
              actions: (print) => Column(children: [
                statoPill(kStatiCarta, str(c!['stato'])),
                const Gap(12),
                Text(testo, textAlign: TextAlign.center, style: t.text(color: t.muted)),
                const Gap(16),
                Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                  VButton('Stampa', icon: 'printer', kind: BtnKind.outline, onPressed: print),
                  const VButton('Torna alla home', kind: BtnKind.primary, href: '#/'),
                ]),
              ]),
            ),
          ]),
        ),
      );
    }
    return PageScroll(children: [
      const PageHero('La tua carta', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }
}
