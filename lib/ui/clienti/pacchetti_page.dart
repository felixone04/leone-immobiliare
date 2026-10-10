/// #/pacchetti: pacchetti a sedute, richiesti online e pagati in struttura.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../dialogs.dart';
import '../forms_public.dart';
import '../kit.dart';
import '../shell.dart';

class PacchettiPage extends StatelessWidget {
  const PacchettiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Widget body;
    if (!s.modulo('pacchetti')) {
      body = const EmptyState(icon: 'layers', title: 'Funzione non disponibile', actions: [VButton('Torna alla home', kind: BtnKind.primary, href: '#/')]);
    } else {
      final cfg = s.repo.cfgModulo('pacchetti');
      final lista = jsonList(cfg['pacchetti']).where((p) => str(p['id']).isNotEmpty && intOf(p['sedute']) > 0 && str(p['nome']).trim().isNotEmpty).toList();
      final noBorder = t.elegante || t.moderno;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(str(cfg['testo']), style: t.text(size: 17.3, color: t.ink2)),
        const Gap(20),
        if (lista.isEmpty)
          const EmptyState(icon: 'layers', small: true, text: 'Nessun pacchetto disponibile al momento.')
        else
          AutoGrid(minWidth: 290, gap: 20, children: [
            for (final p in lista)
              Container(
                decoration: BoxDecoration(color: t.surface, border: Border.all(color: noBorder ? Colors.transparent : t.line), borderRadius: t.r, boxShadow: noBorder ? t.shadow : null),
                clipBehavior: Clip.antiAlias,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (safeSrc(p['immagine']).isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: VImage(str(p['immagine']))),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(p['nome']), style: t.title(size: 17.6, weight: FontWeight.w700)),
                        const Gap(8),
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '${intOf(p['sedute'])}', style: t.title(size: 25.6, color: t.primary)),
                          const TextSpan(text: ' sedute'),
                        ]), style: t.text(weight: FontWeight.w600, color: t.primary)),
                        if (str(p['descrizione']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(str(p['descrizione']), style: t.text(size: 14.7, color: t.muted))),
                        const Spacer(),
                        const Gap(8),
                        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
                          if (doubleOf(p['prezzoPieno']) > doubleOf(p['prezzo']))
                            Text(euro(p['prezzoPieno']), style: t.text(color: t.muted).copyWith(decoration: TextDecoration.lineThrough, decorationColor: t.muted)),
                          Text(euro(p['prezzo']), style: t.title(size: 24, color: t.primary)),
                          if (intOf(p['sedute']) > 0) Text('${euro((doubleOf(p['prezzo']) / intOf(p['sedute']) * 100).round() / 100)} a seduta', style: t.text(color: t.muted)),
                        ]),
                        const Gap(8),
                        Text('Valido ${intOf(p['validitaMesi'], 12)} mesi · pagamento in struttura', style: t.text(size: 13.6, color: t.muted)),
                        const Gap(8),
                        VButton('Richiedi', icon: 'layers', kind: BtnKind.primary, block: true, onPressed: () => _richiedi(context, p)),
                      ]),
                    ),
                  ),
                ]),
              ),
          ]),
      ]);
    }
    return PageScroll(children: [
      const PageHero('Pacchetti', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }

  void _richiedi(BuildContext context, Json p) {
    final s = App.read(context);
    showVModal(context, 'Richiedi: ${p['nome']}', (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${intOf(p['sedute'])} sedute a ${euro(p['prezzo'])}. Riceverai subito il codice: il pacchetto si attiva quando paghi in struttura.', style: ctx.t.text()),
        const Gap(14),
        ContattoForm(
          bottone: 'Richiedi il pacchetto',
          icona: 'check',
          scopo: 'per gestire il pacchetto',
          emailObbligatoria: true,
          onSubmit: (d) async {
            final c = await s.repo.tesseraCrea('pacchetto', {...d, 'pacchetto': p['id']});
            if (ctx.mounted) Navigator.of(ctx).pop();
            if (context.mounted) context.go('/carta/${c['codice']}?nuova=1');
          },
        ),
      ]);
    });
  }
}
