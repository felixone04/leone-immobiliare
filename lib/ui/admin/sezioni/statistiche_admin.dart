/// Statistiche degli annunci: visite alla scheda, preferiti, richieste, visite prenotate,
/// clienti interessati e giorni sul mercato.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';

const _kColonne = [
  ('viste', 'Visite alla scheda'),
  ('preferiti', 'Preferiti'),
  ('richieste', 'Richieste'),
  ('visite', 'Visite prenotate'),
  ('interessati', 'Clienti interessati'),
  ('giorni', 'Giorni sul mercato'),
];

class StatisticheAdmin extends StatefulWidget {
  const StatisticheAdmin({super.key});
  @override
  State<StatisticheAdmin> createState() => _StatisticheAdminState();
}

class _StatisticheAdminState extends State<StatisticheAdmin> {
  var _ordina = 'viste';

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final righe = s.repo.statistiche()..sort((a, b) => intOf(b[_ordina]).compareTo(intOf(a[_ordina])));
    int somma(String k) => righe.fold(0, (x, r) => x + intOf(r[k]));
    final disp = righe.where((r) => r['stato'] == 'Disponibile').toList();
    final mediaGiorni = disp.isEmpty ? 0 : (disp.fold<int>(0, (x, r) => x + intOf(r['giorni'])) / disp.length).round();
    final clienti = s.repo.clienti;
    final ricerche = clienti.fold<int>(0, (x, c) => x + s.repo.ricercheDi(c).length);

    Widget tile(String n, String l) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: t.title(size: 28, color: t.primary, height: 1.1)),
            Text(l, style: t.text(size: 13.6, color: t.muted)),
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AdminHead('Statistiche', sub: 'Come stanno andando gli annunci. Le visite alla scheda non contano quelle fatte da te mentre sei collegato.'),
      AutoGrid(minWidth: 150, gap: 14, children: [
        tile('${somma('viste')}', 'visite alle schede'),
        tile('${somma('richieste')}', 'richieste dagli annunci'),
        tile('${somma('visite')}', 'visite prenotate'),
        tile('${clienti.length}', 'clienti registrati'),
        tile('$ricerche', 'ricerche salvate'),
        tile('$mediaGiorni', 'giorni medi sul mercato'),
      ]),
      const Gap(16),
      AlertBox.text('Senza server i numeri sono quelli di questo browser. Con il database online conteranno le visite di tutti i visitatori.'),
      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Ordina per', style: t.text(size: 14.4, color: t.muted)),
        SizedBox(
          width: 230,
          child: VSelect<String>(value: _ordina, dense: true, items: [for (final c in _kColonne) c], onChanged: (v) => setState(() => _ordina = v ?? 'viste')),
        ),
      ]),
      const Gap(12),
      AdminTable(
        head: ['Immobile', for (final c in _kColonne) c.$2],
        widths: const {0: FlexColumnWidth(2.2)},
        empty: 'Nessun immobile.',
        rows: [
          for (final r in righe)
            [
              Cell2(str(r['titolo']), sub: str(r['stato']), onTap: () => context.go('/admin/catalogo/${r['id']}')),
              for (final (k, _) in _kColonne)
                Text('${intOf(r[k])}', style: t.text(size: 14.9, weight: k == _ordina ? FontWeight.w700 : FontWeight.w400, color: k == _ordina ? t.primary : t.ink)),
            ],
        ],
      ),
    ]);
  }
}
