/// #/fedelta: come funziona la tessera, richiesta online e ricerca del proprio codice.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../forms_public.dart';
import '../inputs.dart';
import '../kit.dart';
import '../shell.dart';
import 'cards.dart';

/// Layout a due colonne delle pagine clienti (.gc-page): modulo a sinistra, anteprima a destra.
class GcPage extends StatelessWidget {
  final Widget form, preview;
  final String previewLabel;
  const GcPage({super.key, required this.form, required this.preview, this.previewLabel = 'Anteprima'});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final formBox = Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
      child: form,
    );
    final prev = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(previewLabel, style: t.text(size: 14.1, color: t.muted))),
      preview,
    ]);
    if (context.vw <= 900) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: prev)), const SizedBox(height: 40), formBox]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: formBox), const SizedBox(width: 40), SizedBox(width: 400, child: prev)]);
  }
}

/// Sottotitolo delle sezioni nei moduli (.gc-form-col h3)
class FormH3 extends StatelessWidget {
  final String text;
  const FormH3(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Text(text, style: context.t.title(size: 16.8, weight: FontWeight.w700)));
}

/// Casella "cerca il tuo codice"
class CercaCodice extends StatefulWidget {
  final String hint, bottone;
  final void Function(String) onSearch;
  const CercaCodice({super.key, required this.hint, required this.bottone, required this.onSearch});
  @override
  State<CercaCodice> createState() => _CercaCodiceState();
}

class _CercaCodiceState extends State<CercaCodice> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    if (_c.text.trim().isNotEmpty) widget.onSearch(_c.text.trim().toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
        child: VInput(controller: _c, hint: widget.hint, caps: TextCapitalization.characters, onSubmitted: (_) => _go(), style: t.text(size: 16, spacing: 1)),
      ),
      VButton(widget.bottone, onPressed: _go),
    ]);
  }
}

class FedeltaPage extends StatelessWidget {
  const FedeltaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Widget body;
    if (!s.modulo('fedelta')) {
      body = const EmptyState(icon: 'star', title: 'Funzione non disponibile', actions: [VButton('Torna alla home', kind: BtnKind.primary, href: '#/')]);
    } else {
      final f = s.repo.cfgModulo('fedelta');
      final obiettivo = intOf(f['obiettivo'], 10);
      body = GcPage(
        previewLabel: 'Così sarà la tua tessera',
        preview: CardVisual('fedelta', {'nome': 'Il tuo nome', 'saldo': (obiettivo * .6).floor(), 'obiettivo': obiettivo, 'unita': f['unita'], 'premio': f['premio'], 'codice': 'FD-····-····'}),
        form: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Ogni visita ti avvicina a un regalo', style: t.title(size: t.h2(context))),
          const Gap(10),
          Text(str(f['regole']), style: t.text(size: 17.3, color: t.ink2)),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 18),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(color: t.primarySoft, borderRadius: t.r),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.primary, borderRadius: BorderRadius.circular(t.minimal ? 0 : 12)),
                child: VIcon('star', size: 22, color: t.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ogni $obiettivo ${f['unita']}', style: t.text(size: 14, weight: FontWeight.w600, color: t.muted)),
                  Text(str(f['premio']), style: t.text(size: 17.6, weight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          if (boolOf(f['richiestaOnline'])) ...[
            const FormH3('Richiedi la tua tessera digitale'),
            Text('È gratuita: la trovi sempre sul telefono, senza tessere di plastica.', style: t.text(size: 14.1, color: t.muted)),
            const Gap(12),
            ContattoForm(
              bottone: 'Crea la mia tessera',
              icona: 'star',
              scopo: 'per gestire la tessera fedeltà',
              onSubmit: (d) async {
                final c = await s.repo.tesseraCrea('fedelta', d);
                if (context.mounted) context.go('/carta/${c['codice']}?nuova=1');
              },
            ),
          ] else
            AlertBox.text('La tessera si richiede in struttura, alla prima visita.'),
          const FormH3('Hai già la tessera?'),
          CercaCodice(hint: 'Codice (es. FD-AB12-CD34)', bottone: 'Vedi i miei ${f['unita']}', onSearch: (c) => context.go('/carta/$c')),
        ]),
      );
    }
    return PageScroll(children: [
      const PageHero('Tessera fedeltà', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }
}
