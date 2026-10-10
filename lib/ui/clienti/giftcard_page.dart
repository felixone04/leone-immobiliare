/// #/giftcard (richiesta) e #/giftcard/CODICE (carta stampabile). Pagamento solo in struttura.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'fedelta_page.dart';
import 'print_card.dart';

class GiftcardPage extends StatelessWidget {
  final String? codice;
  final bool nuova;
  const GiftcardPage({super.key, this.codice, this.nuova = false});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    Widget body;
    if (!s.modulo('giftcard')) {
      body = const EmptyState(icon: 'gift', title: 'Gift card non disponibili', actions: [VButton('Contattaci', kind: BtnKind.primary, href: '#/p/contatti')]);
    } else if (codice != null) {
      body = _Mostra(codice: codice!, nuova: nuova);
    } else {
      body = const _Richiesta();
    }
    return PageScroll(children: [
      const PageHero('Gift card', slim: true),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }
}

class _Richiesta extends StatefulWidget {
  const _Richiesta();
  @override
  State<_Richiesta> createState() => _RichiestaState();
}

class _RichiestaState extends State<_Richiesta> {
  late final Json info = App.read(context).repo.gcPubblico();
  late String tipo = info['libero'] == true ? 'importo' : 'proposta';
  late double importo;
  Json? proposta;
  final _imp = TextEditingController();
  final _dest = TextEditingController(), _msg = TextEditingController(), _nome = TextEditingController(), _email = TextEditingController(), _tel = TextEditingController();
  var _privacy = false, _tentato = false;
  String? _err;

  List<double> get _sugg => [for (final v in (info['suggeriti'] as List)) doubleOf(v)];
  double get _min => doubleOf(info['minimo']);
  double get _max => doubleOf(info['massimo']);

  @override
  void initState() {
    super.initState();
    final s = _sugg;
    importo = s.length > 1 ? s[1] : (s.isNotEmpty ? s[0] : _min);
    if (importo < _min) importo = _min;
    _imp.text = str(importo);
    for (final c in [_dest, _msg, _nome]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_imp, _dest, _msg, _nome, _email, _tel]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _invia() async {
    setState(() => _tentato = true);
    String? e;
    if (tipo == 'importo' && !(importo >= _min)) e = "L'importo minimo è ${euro(_min)}";
    if (tipo == 'importo' && _max > 0 && importo > _max) e = "L'importo massimo è ${euro(_max)}";
    if (tipo == 'proposta' && proposta == null) e = 'Scegli cosa regalare';
    if (e == null && (_nome.text.trim().isEmpty || !validEmail(_email.text.trim()) || _tel.text.trim().isEmpty || !_privacy)) e = 'Compila i tuoi dati e accetta il trattamento dei dati.';
    if (e != null) {
      setState(() => _err = e);
      return;
    }
    setState(() => _err = null);
    try {
      final g = await App.read(context).repo.gcCrea({
        'tipo': tipo, 'importo': importo, 'proposta': proposta?['id'], 'destinatario': _dest.text, 'messaggio': _msg.text,
        'nome': _nome.text, 'email': _email.text, 'telefono': _tel.text,
      });
      if (mounted) context.go('/giftcard/${g['codice']}?nuova=1');
    } on AppError catch (x) {
      setState(() => _err = x.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final libero = info['libero'] == true;
    final proposte = jsonList(info['proposte']);
    final inv = _tentato;
    final scad = isoDate(addMonths(DateTime.now(), intOf(info['validitaMesi'], 12)));
    final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(str(info['titolo']), style: t.title(size: t.h2(context))),
      const Gap(8),
      Text(str(info['testo']), style: t.text(color: t.muted)),
      if (libero && proposte.isNotEmpty) ...[
        const Gap(18),
        Row(children: [
          for (final (v, ic, l) in [('importo', 'tag', 'Importo a scelta'), ('proposta', 'gift', 'Un trattamento o prodotto')])
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: v == 'importo' ? 6 : 0),
                child: Hover(
                  onTap: () => setState(() => tipo = v),
                  builder: (_, h) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: tipo == v ? t.primary : Colors.white, border: Border.all(color: tipo == v || h ? t.primary : t.line2), borderRadius: t.rSm),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      VIcon(ic, color: tipo == v ? t.onPrimary : t.ink),
                      const SizedBox(width: 8),
                      Flexible(child: Text(l, style: t.text(size: 14.4, weight: FontWeight.w600, color: tipo == v ? t.onPrimary : t.ink))),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ],
      if (tipo == 'importo' && libero) ...[
        const FormH3("Scegli l'importo"),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in _sugg.where((v) => v >= _min && (_max == 0 || v <= _max)))
            Hover(
              onTap: () => setState(() {
                importo = v;
                _imp.text = str(v);
              }),
              builder: (_, h) => Container(
                constraints: const BoxConstraints(minWidth: 72),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: importo == v ? t.primary : Colors.white, border: Border.all(color: importo == v || h ? t.primary : t.line2, width: 1.5), borderRadius: BorderRadius.circular(t.minimal ? 0 : 10)),
                child: Text(euro(v), textAlign: TextAlign.center, style: t.text(weight: FontWeight.w700, color: importo == v ? t.onPrimary : t.ink, height: 1.2)),
              ),
            ),
        ]),
        const Gap(12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: FieldLabel(
            "Oppure scrivi l'importo",
            hint: 'Minimo ${euro(_min)}${_max > 0 ? ', massimo ${euro(_max)}' : ''}.',
            child: Row(children: [
              Expanded(
                child: VInput(
                  controller: _imp,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  style: t.text(size: 17.6, weight: FontWeight.w700),
                  onChanged: (v) => setState(() => importo = doubleOf(v)),
                ),
              ),
              const SizedBox(width: 8),
              Text('€', style: t.text(weight: FontWeight.w700)),
            ]),
          ),
        ),
      ],
      if (tipo == 'proposta' && proposte.isNotEmpty) ...[
        const FormH3('Scegli cosa regalare'),
        for (final p in proposte)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Hover(
              onTap: () => setState(() => proposta = p),
              builder: (_, h) {
                final on = proposta?['id'] == p['id'];
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: on ? t.primarySoft : Colors.white, border: Border.all(color: on || h ? t.primary : t.line2, width: on ? 2.5 : 1.5), borderRadius: BorderRadius.circular(t.minimal ? 0 : 14)),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(width: 76, height: 64, child: safeSrc(p['immagine']).isNotEmpty ? VImage(str(p['immagine'])) : Container(color: t.primarySoft, child: Center(child: VIcon('gift', color: t.primary)))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(p['nome']), style: t.text(weight: FontWeight.w700)),
                        if (str(p['descrizione']).isNotEmpty) Text(str(p['descrizione']), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.text(size: 14, color: t.muted)),
                        Text(euro(p['prezzo']), style: t.text(weight: FontWeight.w700, color: t.primary)),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          ),
      ],
      const FormH3('Personalizza'),
      FieldLabel('Per (nome di chi la riceve)', child: VInput(controller: _dest, maxLength: 120, hint: 'es. Giulia')),
      const Gap(12),
      FieldLabel('Dedica', child: VInput(controller: _msg, minLines: 3, maxLines: 5, maxLength: 400, hint: 'es. Buon compleanno! Un momento tutto per te.')),
      const FormH3('I tuoi dati'),
      FieldLabel('Nome e cognome', child: VInput(controller: _nome, invalid: inv && _nome.text.trim().isEmpty)),
      const Gap(12),
      TwoCols(
        FieldLabel('Email', child: VInput(controller: _email, keyboard: TextInputType.emailAddress, invalid: inv && !validEmail(_email.text.trim()))),
        FieldLabel('Telefono', child: VInput(controller: _tel, keyboard: TextInputType.phone, invalid: inv && _tel.text.trim().isEmpty)),
      ),
      const Gap(12),
      AlertBox(
        icon: 'building',
        align: CrossAxisAlignment.start,
        child: Text.rich(TextSpan(children: [
          TextSpan(text: 'Pagamento in struttura\n', style: t.text(weight: FontWeight.w700)),
          TextSpan(text: str(info['pagamento'])),
        ])),
      ),
      PrivacyCheck(value: _privacy, onChanged: (v) => setState(() => _privacy = v), scopo: 'per gestire la gift card', linkLabel: 'privacy', invalid: inv && !_privacy),
      const Gap(8),
      FormError(_err),
      const Gap(8),
      VButton('Richiedi la gift card', icon: 'gift', kind: BtnKind.primary, size: BtnSize.lg, block: true, onAsync: _invia),
    ]);
    return GcPage(
      form: form,
      preview: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardVisual('giftcard', {
          'valore': importo,
          'proposta': tipo == 'proposta' ? (proposta?['nome'] ?? 'Scegli una proposta') : '',
          'destinatario': _dest.text,
          'messaggio': _msg.text,
          'daParte': _nome.text,
          'scadenza': scad,
        }),
        const Gap(10),
        Text('Valida ${info['validitaMesi']} mesi dall\'emissione.', style: t.text(size: 14.1, color: t.muted)),
      ]),
    );
  }
}

class _Mostra extends StatelessWidget {
  final String codice;
  final bool nuova;
  const _Mostra({required this.codice, required this.nuova});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Json? g;
    try {
      g = s.repo.gcVedi(codice);
    } on AppError {
      g = null;
    }
    if (g == null) {
      return const EmptyState(icon: 'gift', title: 'Gift card non trovata', text: 'Controlla il codice.', actions: [VButton('Richiedi una gift card', kind: BtnKind.primary, href: '#/giftcard')]);
    }
    final gc = g;
    final set = s.settings;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (nuova)
            AlertBox(
              icon: 'check',
              ok: true,
              align: CrossAxisAlignment.start,
              child: Text.rich(TextSpan(children: [
                TextSpan(text: 'Richiesta registrata!', style: t.text(weight: FontWeight.w700)),
                const TextSpan(text: ' Presenta il codice '),
                WidgetSpan(alignment: PlaceholderAlignment.middle, child: CodeTag(str(gc['codice']))),
                const TextSpan(text: ' in struttura: dopo il pagamento la gift card sarà attiva. Salva o stampa questa pagina.'),
              ])),
            ),
          PrintableCard(
            title: str(gc['codice']),
            child: CardVisual('giftcard', gc),
            actions: (print) => Column(children: [
              statoPill(kStatiCarta, str(gc['stato'])),
              if (gc['stato'] == 'attiva' && str(gc['proposta']).isEmpty) ...[
                const Gap(10),
                Text.rich(TextSpan(children: [const TextSpan(text: 'Saldo disponibile: '), TextSpan(text: euro(gc['saldo']), style: const TextStyle(fontWeight: FontWeight.w700))]), style: t.text()),
              ],
              if (gc['stato'] == 'da_pagare') ...[
                const Gap(10),
                Text('Pagamento in struttura${str(set['indirizzo']).isNotEmpty ? ': ${set['indirizzo']}' : ''}.', textAlign: TextAlign.center, style: t.text(color: t.muted)),
              ],
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
}
