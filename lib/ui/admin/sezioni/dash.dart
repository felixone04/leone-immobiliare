/// Panoramica dell'area riservata.
library;

import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../state/app_state.dart';
import '../../kit.dart';
import '../admin_common.dart';
import 'cassa.dart';

class DashAdmin extends StatelessWidget {
  const DashAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final sch = s.repo.schema;
    final cat = s.cat;
    final items = s.repo.items;
    final disp = items.where((i) => cat.nastro(i).isEmpty).length, ev = items.where((i) => boolOf(i['evidenza'])).length;
    final senzaFoto = items.where((i) => cat.foto(i).isEmpty).length;
    final recenti = [...items]..sort((a, b) => intOf(b['modificato'] ?? b['creato']).compareTo(intOf(a['modificato'] ?? a['creato'])));
    final cassa = s.modulo('prenotazioni') || s.modulo('fedelta') || s.modulo('pacchetti') || s.modulo('offerte');

    Widget stat(String n, String l, String href) => Hover(
          onTap: () => openLink(context, href),
          builder: (_, h) => Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: t.surface, border: Border.all(color: h ? t.primary : t.line), borderRadius: t.r),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n, style: t.title(size: 32, color: t.primary, height: 1.1)),
              Text(l, style: t.text(size: 14.4, color: t.muted)),
            ]),
          ),
        );

    final modificati = CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BoxTitle('Modificati di recente'),
        if (recenti.isEmpty)
          Wrap(children: [Text('Nessun contenuto. ', style: t.text(color: t.muted)), TextLink('Aggiungi il primo', '#/admin/catalogo/nuovo')])
        else
          for (final i in recenti.take(5))
            Hover(
              onTap: () => openLink(context, '#/admin/catalogo/${i['id']}'),
              builder: (_, h) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: h ? t.bg : null, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 52,
                      height: 40,
                      color: t.bg,
                      child: cat.foto(i).isNotEmpty ? VImage(cat.foto(i).first) : Center(child: VIcon(sch.icona, color: t.muted)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(str(i['titolo']), maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text(weight: FontWeight.w600, height: 1.35)),
                      Text(cat.prezzo(i), style: t.text(size: 13.6, color: t.muted, height: 1.35)),
                    ]),
                  ),
                  VIcon('edit', color: t.ink2),
                ]),
              ),
            ),
      ]),
    );
    Widget quick(String ic, String l, String href) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Hover(
            onTap: () => openLink(context, href),
            builder: (_, h) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: h ? t.primarySoft : t.bg, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                VIcon(ic, color: h ? t.primary : t.ink),
                const SizedBox(width: 12),
                Expanded(child: Text(l, style: t.text(weight: FontWeight.w600, color: h ? t.primary : t.ink))),
              ]),
            ),
          ),
        );
    final azioni = CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BoxTitle('Azioni rapide'),
        quick('image', 'Cambia logo e colori', '#/admin/impostazioni'),
        quick('layers', 'Organizza la home page', '#/admin/widget'),
        quick('file', 'Modifica Chi siamo, Storia, Contatti…', '#/admin/pagine'),
        quick('download', 'Scarica un backup', '#/admin/backup'),
      ]),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead(
        'Ciao! Ecco il tuo sito',
        subWidget: Text.rich(TextSpan(children: [const TextSpan(text: 'Tipologia: '), TextSpan(text: s.repo.preset.nome, style: const TextStyle(fontWeight: FontWeight.w700))]), style: t.text(color: t.muted)),
        actions: [VButton(sch.nuovo, icon: 'plus', kind: BtnKind.primary, href: '#/admin/catalogo/nuovo')],
      ),
      AutoGrid(minWidth: 160, gap: 16, children: [
        stat('${items.length}', '${sch.plurale} totali', '#/admin/catalogo'),
        stat('$disp', 'disponibili', '#/admin/catalogo'),
        stat('$ev', 'in evidenza', '#/admin/catalogo'),
        stat('${s.repo.pages.length}', 'pagine', '#/admin/pagine'),
      ]),
      const Gap(24),
      DaFare(s.repo.contatori()),
      if (senzaFoto > 0) AlertBox.text('$senzaFoto ${senzaFoto == 1 ? 'elemento è' : 'elementi sono'} senza foto.'),
      AutoGrid(minWidth: 300, gap: 20, equalHeight: false, children: [if (cassa) const BoxCassa(), modificati, azioni]),
    ]);
  }
}
