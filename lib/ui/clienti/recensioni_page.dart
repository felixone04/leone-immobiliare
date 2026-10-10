/// #/recensioni: media, elenco e modulo per lasciare una recensione (con stelle interattive).
library;

import 'package:flutter/material.dart';

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

class RecensioniPage extends StatefulWidget {
  final String pren;
  const RecensioniPage({super.key, this.pren = ''});
  @override
  State<RecensioniPage> createState() => _RecensioniPageState();
}

class _RecensioniPageState extends State<RecensioniPage> {
  late var _form = widget.pren.isNotEmpty;
  final _formKey = GlobalKey();
  var _voto = 0, _hoverVoto = 0, _privacy = false, _tentato = false;
  final _testo = TextEditingController(), _nome = TextEditingController(), _email = TextEditingController();
  String? _err;
  Json? _esito;

  @override
  void dispose() {
    for (final c in [_testo, _nome, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _invia() async {
    setState(() => _tentato = true);
    if (_voto < 1 || _testo.text.trim().length < 10 || _nome.text.trim().isEmpty || !_privacy) {
      setState(() => _err = "Compila i campi richiesti e accetta l'informativa.");
      return;
    }
    try {
      final r = await App.read(context).repo.recCrea({'voto': _voto, 'testo': _testo.text, 'nome': _nome.text, 'email': _email.text, 'prenotazione': widget.pren});
      setState(() => _esito = r);
    } on AppError catch (e) {
      setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Widget body;
    if (!s.modulo('recensioni')) {
      body = const EmptyState(icon: 'star', title: 'Funzione non disponibile', actions: [VButton('Torna alla home', kind: BtnKind.primary, href: '#/')]);
    } else {
      final d = s.repo.recInfo();
      final totale = intOf(d['totale']);
      final media = doubleOf(d['media']);
      final puo = widget.pren.isNotEmpty || d['aperte'] == true;
      final lista = jsonList(d['recensioni']);
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 16, children: [
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
              Text(totale > 0 ? str(media).replaceAll('.', ',') : '—', style: t.title(size: 41.6, height: 1)),
              Stars(media),
              Text('$totale ${totale == 1 ? 'recensione' : 'recensioni'}', style: t.text(color: t.muted)),
            ]),
            if (puo)
              VButton('Scrivi una recensione', icon: 'edit', kind: BtnKind.primary, onPressed: () {
                setState(() => _form = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final c = _formKey.currentContext;
                  if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300));
                });
              }),
          ]),
        ),
        if (_form)
          Padding(
            key: _formKey,
            padding: const EdgeInsets.only(bottom: 28),
            child: Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: _modulo(context, s))),
          ),
        if (lista.isEmpty)
          Text('Ancora nessuna recensione: sii il primo!', style: t.text(color: t.muted))
        else
          AutoGrid(minWidth: 270, gap: 20, children: [for (final r in lista) ReviewTile(r)]),
      ]);
    }
    return PageScroll(children: [
      const PageHero('Recensioni', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }

  Widget _modulo(BuildContext context, AppState s) {
    final t = context.t;
    if (_esito != null) {
      final google = str(_esito!['google']);
      return MsgOk(
        'Grazie per la tua recensione!',
        text: _esito!['stato'] == 'pubblicata' ? 'È già visibile sul sito.' : 'Sarà pubblicata dopo una breve verifica.',
        extra: [
          if (google.isNotEmpty) ...[
            const Gap(8),
            Text('Ti va di lasciarla anche su Google? Ci aiuti tantissimo.', style: t.text()),
            const Gap(8),
            VButton('Recensisci su Google', icon: 'star', kind: BtnKind.outline, href: safeUrl(google)),
          ],
        ],
      );
    }
    final inv = _tentato;
    final shown = _hoverVoto > 0 ? _hoverVoto : _voto;
    return CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.pren.isNotEmpty ? "Com'è andato il tuo appuntamento?" : 'La tua recensione', style: t.title(size: 17.6, weight: FontWeight.w700)),
        const Gap(12),
        Row(children: [
          for (var n = 1; n <= 5; n++)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoverVoto = n),
              onExit: (_) => setState(() => _hoverVoto = 0),
              child: GestureDetector(
                onTap: () => setState(() => _voto = n),
                child: Tooltip(
                  message: '$n stelle',
                  child: Padding(padding: const EdgeInsets.only(right: 4), child: VIcon('star', size: 34, color: n <= shown ? t.accent : (inv && _voto == 0 ? VTheme.danger.withValues(alpha: .4) : t.line2), filled: n <= _voto)),
                ),
              ),
            ),
        ]),
        const Gap(12),
        FieldLabel('La tua esperienza', child: VInput(controller: _testo, minLines: 4, maxLines: 10, maxLength: 2000, invalid: inv && _testo.text.trim().length < 10)),
        const Gap(12),
        TwoCols(
          FieldLabel('Nome (verrà pubblicato)', child: VInput(controller: _nome, maxLength: 80, hint: 'es. Giulia R.', invalid: inv && _nome.text.trim().isEmpty)),
          FieldLabel('Email (non pubblicata, facoltativa)', child: VInput(controller: _email, keyboard: TextInputType.emailAddress)),
        ),
        const Gap(12),
        PrivacyCheck(value: _privacy, onChanged: (v) => setState(() => _privacy = v), scopo: 'per pubblicare la recensione', invalid: inv && !_privacy),
        const Gap(8),
        FormError(_err),
        const Gap(8),
        VButton('Invia recensione', icon: 'check', kind: BtnKind.primary, block: true, onAsync: _invia),
      ]),
    );
  }
}
