/// Elementi condivisi delle funzioni per i clienti: offerte, recensioni, gift card e carte con codice.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../dialogs.dart';
import '../forms_public.dart';
import '../kit.dart';

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

/* ================= Offerte ================= */

String _two(int n) => n.toString().padLeft(2, '0');

/// Conto alla rovescia fino alla fine del giorno indicato.
class Countdown extends StatefulWidget {
  final String al;
  const Countdown(this.al, {super.key});
  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final fine = parseDate(widget.al).add(const Duration(hours: 23, minutes: 59, seconds: 59));
    final s = fine.difference(DateTime.now()).inSeconds.clamp(0, 1 << 31);
    final g = s ~/ 86400, h = s % 86400 ~/ 3600, m = s % 3600 ~/ 60, sec = s % 60;
    Widget part(String n, String u) => Text.rich(
          TextSpan(children: [
            TextSpan(text: n, style: TextStyle(fontFamily: t.font, fontSize: 22.4, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
            TextSpan(text: u),
          ]),
          style: t.text(color: t.primary, height: 1.2),
        );
    return Wrap(spacing: 10, children: [if (g > 0) part('$g', 'g'), part(_two(h), 'h'), part(_two(m), 'm'), part(_two(sec), 's')]);
  }
}

class OffertaCard extends StatelessWidget {
  final Json o;
  final List<Json> tutte;
  const OffertaCard(this.o, this.tutte, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final img = safeSrc(o['immagine']);
    final rimasti = o['rimasti'];
    final noBorder = t.elegante || t.moderno;
    return Container(
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: noBorder ? Colors.transparent : t.line), borderRadius: t.r, boxShadow: noBorder ? t.shadow : null),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (img.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: VImage(img)),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (str(o['sconto']).isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: t.accent, borderRadius: t.rSm),
                  child: Text(str(o['sconto']), style: t.title(size: 17.6, color: t.onAccent, weight: FontWeight.w800, height: 1.3)),
                ),
              Text(str(o['titolo']), style: t.title(size: 17.6, weight: FontWeight.w700)),
              if (str(o['descrizione']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(str(o['descrizione']), style: t.text(size: 14.7, color: t.muted))),
              const SizedBox(height: 8),
              if (str(o['al']).isNotEmpty && o['countdown'] == true)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: t.primarySoft, borderRadius: t.rSm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TERMINA TRA', style: t.caps(size: 11.5, spacing: .08)),
                    Countdown(str(o['al'])),
                  ]),
                )
              else if (str(o['al']).isNotEmpty)
                Text('Valida fino al ${fmtDate(str(o['al']), 'd MMMM')}', style: t.text(size: 13.6, color: t.muted)),
              if (rimasti != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(intOf(rimasti) > 0 ? 'Ancora $rimasti disponibili' : 'Esaurita', style: t.text(size: 13.6, weight: FontWeight.w700, color: VTheme.warn)),
                ),
              const Spacer(),
              const SizedBox(height: 8),
              if (o['personale'] == true)
                (rimasti == 0 ? const SizedBox.shrink() : VButton('Ottieni il coupon', icon: 'tag', kind: BtnKind.accent, block: true, onPressed: () => apriCoupon(context, o)))
              else if (str(o['codice']).isNotEmpty)
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Codice da mostrare in cassa: '),
                    WidgetSpan(alignment: PlaceholderAlignment.middle, child: CodeTag(str(o['codice']), size: 16)),
                  ]),
                  style: t.text(size: 14.4),
                )
              else
                Text('Valida in struttura, senza codice', style: t.text(size: 14.4)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Codice evidenziato (<code>)
class CodeTag extends StatelessWidget {
  final String code;
  final double size;
  final Color? bg, fg;
  const CodeTag(this.code, {super.key, this.size = 14.4, this.bg, this.fg});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * .35, vertical: size * .1),
      decoration: BoxDecoration(color: bg ?? t.primarySoft, borderRadius: BorderRadius.circular(5)),
      child: SelectableText(code, style: TextStyle(fontFamily: 'monospace', fontSize: size * .95, letterSpacing: size * .06, color: fg ?? t.ink, height: 1.3)),
    );
  }
}

/// Modulo per ottenere un coupon personale.
void apriCoupon(BuildContext context, Json o) {
  final s = App.read(context);
  showVModal(context, 'Coupon: ${o['titolo']}', (ctx) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Ricevi un coupon personale da mostrare in cassa${str(o['al']).isNotEmpty ? ', valido fino al ${fmtDate(str(o['al']), 'd MMMM')}' : ''}.', style: ctx.t.text()),
      const SizedBox(height: 14),
      ContattoForm(
        bottone: 'Ottieni il coupon',
        icona: 'tag',
        scopo: 'per ricevere il coupon',
        telObbligatorio: false,
        onSubmit: (d) async {
          final c = await s.repo.tesseraCrea('coupon', {...d, 'offerta': o['id']});
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (context.mounted) context.go('/carta/${c['codice']}?nuova=1');
        },
      ),
    ]);
  });
}

/* ================= Gift card e carte con codice ================= */

/// Disegno della carta (gift card, tessera fedeltà, pacchetto, coupon).
class CardVisual extends StatelessWidget {
  final String tipo; // giftcard | fedelta | pacchetto | coupon
  final Json c;
  final double maxWidth;
  final double angle;
  const CardVisual(this.tipo, this.c, {super.key, this.maxWidth = 460, this.angle = 0});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final set = s.settings;
    final logo = safeSrc(set['logo']);
    const white = Colors.white;
    final label = switch (tipo) { 'fedelta' => 'TESSERA FEDELTÀ', 'pacchetto' => 'PACCHETTO', 'coupon' => 'COUPON', _ => 'GIFT CARD' };
    final icon = switch (tipo) { 'fedelta' => 'star', 'pacchetto' => 'layers', 'coupon' => 'tag', _ => 'gift' };
    TextStyle st(double sz, {FontWeight w = FontWeight.w400, double op = 1, bool italic = false}) =>
        t.text(size: sz, weight: w, color: white.withValues(alpha: op), height: 1.3).copyWith(fontStyle: italic ? FontStyle.italic : null);
    TextStyle val(double sz) => t.title(size: sz, color: white, weight: FontWeight.w800, height: 1.1, spacing: -.03 * sz);

    final scad = str(c['scadenza']);
    final corpo = <Widget>[];
    if (tipo == 'giftcard') {
      corpo.addAll([
        const Spacer(),
        if (str(c['proposta']).isNotEmpty) ...[
          Text('VALIDA PER', style: st(12.5, w: FontWeight.w600, op: .8)),
          Text(str(c['proposta']), style: val(30), maxLines: 2, overflow: TextOverflow.ellipsis),
        ] else
          Text(euro(c['valore']), style: val(36)),
        if (str(c['destinatario']).isNotEmpty) Text.rich(TextSpan(children: [const TextSpan(text: 'Per '), TextSpan(text: str(c['destinatario']), style: const TextStyle(fontWeight: FontWeight.w700))]), style: st(16)),
        if (str(c['messaggio']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('“${c['messaggio']}”', maxLines: 2, overflow: TextOverflow.ellipsis, style: st(14.7, op: .92, italic: true))),
        if (str(c['daParte']).isNotEmpty) Text('da ${c['daParte']}', style: st(13.6, op: .85)),
      ]);
    } else if (tipo == 'fedelta') {
      final n = intOf(c['obiettivo'], 10).clamp(1, 1000);
      final saldo = intOf(c['saldo']);
      final pieni = saldo < n ? saldo : n;
      final cols = n < 10 ? n : 10;
      corpo.addAll([
        const Spacer(),
        Text(str(c['nome']), style: st(16, w: FontWeight.w700)),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: LayoutBuilder(builder: (ctx, box) {
            final w = (box.maxWidth - 6 * (cols - 1)) / cols;
            return Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < n; i++)
                Container(
                  width: w,
                  height: w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < pieni ? t.accent : null,
                    border: Border.all(color: i < pieni ? t.accent : white.withValues(alpha: .5), width: 2),
                  ),
                  child: i < pieni ? VIcon('check', size: w * .6, color: t.onAccent) : Text('${i + 1}', style: st(11.5, w: FontWeight.w700, op: .7)),
                ),
            ]);
          }),
        ),
        Text(saldo >= n ? 'Premio disponibile: ${c['premio']}' : '$saldo di $n ${str(c['unita']).isEmpty ? 'timbri' : c['unita']} · premio: ${c['premio']}', style: st(13.6, op: .85)),
      ]);
    } else if (tipo == 'pacchetto') {
      corpo.addAll([
        const Spacer(),
        Text(str(c['nomePacchetto']).toUpperCase(), style: st(12.5, w: FontWeight.w600, op: .8)),
        Text.rich(TextSpan(children: [TextSpan(text: '${c['saldo']} / ${c['valore']} '), TextSpan(text: 'sedute', style: st(16, w: FontWeight.w600, op: .8))]), style: val(36)),
        Text.rich(TextSpan(children: [const TextSpan(text: 'Intestato a '), TextSpan(text: str(c['nome']), style: const TextStyle(fontWeight: FontWeight.w700))]), style: st(16)),
      ]);
    } else {
      corpo.addAll([
        const Spacer(),
        Text(str(c['offerta']).toUpperCase(), style: st(12.5, w: FontWeight.w600, op: .8)),
        Text(str(c['sconto']).isEmpty ? 'Offerta' : str(c['sconto']), style: val(36)),
        Text.rich(TextSpan(children: [const TextSpan(text: 'Per '), TextSpan(text: str(c['nome']), style: const TextStyle(fontWeight: FontWeight.w700))]), style: st(16)),
      ]);
    }

    final card = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.minimal ? 0 : 20),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.primary, t.primaryDark]),
            boxShadow: t.shadowLg,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned(
              right: -80,
              top: -80,
              child: Container(width: 260, height: 260, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [t.accent.withValues(alpha: .45), t.accent.withValues(alpha: 0)]))),
            ),
            Positioned(right: -18, bottom: -18, child: Opacity(opacity: .1, child: VIcon(icon, size: 150, stroke: 1.2, color: white))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (logo.isNotEmpty)
                    Container(
                      height: 30,
                      constraints: const BoxConstraints(maxWidth: 140),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: white, borderRadius: BorderRadius.circular(8)),
                      child: VImage(logo, fit: BoxFit.contain),
                    )
                  else
                    Flexible(child: Text(str(set['nome']), overflow: TextOverflow.ellipsis, style: st(16.8, w: FontWeight.w700))),
                  const Spacer(),
                  Text(label, style: st(11.5, w: FontWeight.w800, op: .85).copyWith(letterSpacing: 2.3)),
                ]),
                ...corpo,
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: white.withValues(alpha: .35)))),
                  child: Row(children: [
                    CodeTag(str(c['codice']).isEmpty ? '${tipo == 'giftcard' ? 'GC' : 'XX'}-····-····' : str(c['codice']), bg: white.withValues(alpha: .18), fg: white, size: 15),
                    const Spacer(),
                    if (scad.isNotEmpty) Flexible(child: Text('Valida fino al ${fmtDateLong(scad)}', textAlign: TextAlign.right, style: st(12.5))),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
    return angle == 0 ? card : Transform.rotate(angle: angle, child: card);
  }
}

/// Stati delle carte con codice
const kStatiCarta = {
  'da_pagare': ('Da pagare in struttura', 'warn'),
  'attiva': ('Attiva', 'ok'),
  'utilizzata': ('Utilizzata', 'muted'),
  'scaduta': ('Scaduta', 'err'),
  'annullata': ('Annullata', 'err'),
};
