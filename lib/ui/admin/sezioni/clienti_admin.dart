/// Clienti registrati sul sito: preferiti, ricerche salvate e immobili abbinati (abbinamento automatico).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/abbinamento.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../catalog/item_card.dart';
import '../../dialogs.dart';
import '../../kit.dart';
import '../admin_common.dart';

class ClientiAdmin extends StatefulWidget {
  final List<String> rest;
  const ClientiAdmin({super.key, required this.rest});
  @override
  State<ClientiAdmin> createState() => _ClientiAdminState();
}

class _ClientiAdminState extends State<ClientiAdmin> {
  var _q = '';

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    if (widget.rest.isNotEmpty) {
      final c = s.repo.clienteDa(widget.rest[0]);
      return c == null ? const AdminHead('Cliente non trovato', back: ('Clienti', '/admin/clienti')) : _Cliente(c);
    }
    final q = norm(_q);
    final lista = s.repo.clienti.where((c) => q.isEmpty || norm('${c['nome']} ${c['email']} ${c['telefono']}').contains(q)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Clienti', sub: '${s.repo.clienti.length} registrati sul sito, con i loro preferiti e le ricerche salvate.', actions: [
        const VButton('Scrivi ai clienti', icon: 'send', kind: BtnKind.primary, href: '#/admin/posta/nuova'),
      ]),
      AlertBox.text("Senza server i clienti restano salvati nel browser in cui si sono registrati: qui vedi quelli di questo computer. Con il database online li vedrai tutti."),
      AdminSearch(hint: 'Cerca per nome, email, telefono…', onChanged: (v) => setState(() => _q = v)),
      AdminTable(
        head: const ['Cliente', 'Preferiti', 'Ricerche', 'Proposte', 'Registrato'],
        widths: const {0: FlexColumnWidth()},
        empty: s.repo.clienti.isEmpty ? 'Ancora nessun cliente registrato.' : 'Nessun risultato',
        rows: [
          for (final c in lista)
            [
              Cell2(str(c['nome']), sub: [str(c['email']), str(c['telefono'])].where((x) => x.isNotEmpty).join(' · '), onTap: () => context.go('/admin/clienti/${c['id']}')),
              Text('${strList(c['preferiti']).length}', style: t.text(size: 14.9)),
              Text('${s.repo.ricercheDi(c).length}', style: t.text(size: 14.9)),
              boolOf(c['consenso']) ? const Pill('Sì', tone: 'ok') : const Pill('No'),
              Text(fmtWhen(intOf(c['creato'])), style: t.text(size: 13.6, color: t.muted)),
            ],
        ],
      ),
    ]);
  }
}

class _Cliente extends StatelessWidget {
  final Json c;
  const _Cliente(this.c);
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final ricerche = s.repo.ricercheDi(c);
    final pref = s.repo.preferitiDi(c);
    final tel = telHref(str(c['telefono']));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead(str(c['nome']), back: ('Clienti', '/admin/clienti'), subWidget: Text('${c['email']}${tel.isNotEmpty ? ' · ${c['telefono']}' : ''} · registrato ${fmtWhen(intOf(c['creato']))}', style: t.text(color: t.muted)), actions: [
        VButton('Scrivigli', icon: 'send', kind: BtnKind.primary, href: '#/admin/posta/nuova?clienti=${c['id']}'),
        if (tel.isNotEmpty) VButton('Chiama', icon: 'phone', href: 'tel:$tel'),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        boolOf(c['consenso']) ? const Pill('Accetta proposte di immobili e offerte', tone: 'ok', icon: 'check') : const Pill('Non vuole proposte commerciali'),
      ]),
      const Gap(20),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BoxTitle('Ricerche salvate (${ricerche.length})', icon: 'bookmark', size: 17.6),
          if (ricerche.isEmpty) Text('Nessuna ricerca salvata.', style: t.text(color: t.muted)),
          for (final r in ricerche) ...[
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(str(r['nome']), style: t.text(weight: FontWeight.w700))),
            Text(descriviCriteri(jsonOf(r['criteri'])), style: t.text(size: 14.1, color: t.muted)),
            Builder(builder: (context) {
              final trovati = s.repo.abbinamentiPer(jsonOf(r['criteri']));
              if (trovati.isEmpty) return Padding(padding: const EdgeInsets.only(top: 4), child: Text('Nessun immobile disponibile corrisponde.', style: t.text(size: 14.1)));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (i, a) in trovati.take(6))
                  ItemRow(i, href: '#/admin/catalogo/${i['id']}', nota: '${a.percentuale}%${a.sopraBudget ? ' · sopra il budget' : ''}${a.mancano.isNotEmpty ? ' · manca: ${a.mancano.join(', ')}' : ''}'),
              ]);
            }),
          ],
        ]),
      ),
      const Gap(16),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BoxTitle('Preferiti (${pref.length})', icon: 'heart', size: 17.6),
          if (pref.isEmpty) Text('Nessun immobile tra i preferiti.', style: t.text(color: t.muted)),
          for (final i in pref) ItemRow(i, href: '#/admin/catalogo/${i['id']}'),
        ]),
      ),
      const Gap(16),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          BoxTitle('Avvisi ricevuti', icon: 'bell', size: 17.6),
          if (s.repo.notificheDi(c).isEmpty) Text('Ancora nessun avviso.', style: t.text(color: t.muted)),
          for (final n in s.repo.notificheDi(c).take(10))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                VIcon('mail', size: 16, color: t.muted),
                const SizedBox(width: 8),
                Expanded(child: Text('${s.repo.item(str(n['immobile']))?['titolo'] ?? 'Immobile rimosso'} · ${n['percentuale']}% di «${n['ricercaNome']}»', style: t.text(size: 14.1))),
                Text(fmtWhen(intOf(n['creato'])), style: t.text(size: 13.1, color: t.muted)),
              ]),
            ),
        ]),
      ),
      const Gap(20),
      Align(
        alignment: Alignment.centerLeft,
        child: VButton('Elimina il cliente', icon: 'trash', kind: BtnKind.ghost, danger: true, onAsync: () async {
          if (!await confirmDialog(context, 'Eliminare ${c['nome']} con preferiti e ricerche salvate?', danger: true, ok: 'Elimina')) return;
          await s.repo.clienteElimina(c['id'] as String);
          s.toast('Cliente eliminato');
          if (context.mounted) context.go('/admin/clienti');
        }),
      ),
    ]);
  }
}
