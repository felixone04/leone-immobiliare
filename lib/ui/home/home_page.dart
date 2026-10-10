/// Home page: i widget scelti nell'area riservata, nell'ordine stabilito.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/markdown.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../catalog/item_card.dart';
import '../catalog/listing.dart';
import '../clienti/cards.dart';
import '../kit.dart';
import '../map/vmap.dart';
import '../shell.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final ws = s.repo.widgets.where((w) => w['attivo'] != false && kWidgetRender.containsKey(w['tipo'])).toList();
    if (ws.isEmpty) {
      return PageScroll(children: [
        Contained(
          child: Padding(
            padding: pagePad(context),
            child: EmptyState(
              icon: 'layers',
              title: 'La home page è vuota',
              text: "Aggiungi i widget dall'area riservata.",
              actions: [VButton('Gestisci la home', kind: BtnKind.primary, href: '#/admin/widget')],
            ),
          ),
        ),
      ]);
    }
    // Come nel CSS: le sezioni consecutive non "alt" riducono lo spazio superiore
    final out = <Widget>[];
    String? prevKind;
    for (final w in ws) {
      final built = kWidgetRender[w['tipo']]!(context, w);
      if (built == null) continue;
      out.add(built.wrap(context, prevKind));
      prevKind = built.kind;
    }
    return PageScroll(children: out);
  }
}

/// Risultato del disegno di un widget: contenuto e tipo di sezione (per le spaziature).
class Built {
  final Widget child;
  final String kind; // section | alt | band (fasce piene senza spaziatura)
  const Built(this.child, {this.kind = 'section'});

  Widget wrap(BuildContext context, String? prev) {
    if (kind == 'band') return child;
    final t = context.t;
    final narrow = context.vw <= 640;
    final full = narrow ? 48.0 : 72.0;
    final top = kind == 'section' && prev == 'section' ? 16.0 : full;
    final alt = kind == 'alt';
    Color? bg;
    if (alt) bg = t.moderno ? mix(t.primary, .05, Colors.white) : (t.minimal ? const Color(0xFFF6F6F6) : t.surface);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: alt && !t.moderno ? Border.symmetric(horizontal: BorderSide(color: t.line)) : null,
      ),
      padding: EdgeInsets.only(top: top, bottom: full),
      child: Contained(child: child),
    );
  }
}

typedef WidgetRender = Built? Function(BuildContext context, Json w);

final Map<String, WidgetRender> kWidgetRender = {
  'hero': (c, w) => Built(HeroWidget(w), kind: 'band'),
  'catalogo': _catalogo,
  'servizi': _servizi,
  'numeri': (c, w) => Built(NumeriWidget(w), kind: 'band'),
  'testo': _testo,
  'recensioni': _recensioni,
  'mappa': _mappa,
  'prenota': _prenota,
  'offerte': _offerte,
  'fedelta': _fedelta,
  'giftcard': _giftcard,
  'contatti': (c, w) => Built(ContattiCta(w)),
};

/* ---------------- Banner principale ---------------- */

class HeroWidget extends StatefulWidget {
  final Json w;
  const HeroWidget(this.w, {super.key});
  @override
  State<HeroWidget> createState() => _HeroWidgetState();
}

class _HeroWidgetState extends State<HeroWidget> {
  final _vals = <String, String>{};
  final _ctrl = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _cerca() {
    final q = {for (final e in _vals.entries) if (e.value.trim().isNotEmpty) e.key: e.value.trim()};
    context.go(Uri(path: '/catalogo', queryParameters: q.isEmpty ? null : q).toString());
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final w = widget.w;
    final img = safeSrc(w['immagine']);
    final narrow = context.vw <= 640;
    final qf = s.repo.schema.filtri.where((f) => f.rapido).toList();
    final h1 = t.elegante ? VTheme.clampVw(context, 41.6, 28.8, 3.6, 73.6) : (t.moderno ? VTheme.clampVw(context, 38.4, 25.6, 4, 70.4) : VTheme.clampVw(context, 33.6, 22.4, 3.3, 60.8));
    final sub = VTheme.clampVw(context, 16.3, 15.2, .4, 20);

    Widget campo(f) {
      Widget input;
      String label = f.label;
      if (f.tipo == 'range') {
        label = '${f.label.replaceAll(RegExp(r'\s*\(.*\)'), '')} max';
        final c = _ctrl.putIfAbsent(f.id, () => TextEditingController());
        input = TextField(
          controller: c,
          keyboardType: TextInputType.number,
          onChanged: (v) => _vals['${f.id}_max'] = v,
          onSubmitted: (_) => _cerca(),
          style: t.text(weight: FontWeight.w600, height: 1.3),
          decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: 'Qualsiasi', hintStyle: t.text(weight: FontWeight.w400, color: t.muted), contentPadding: const EdgeInsets.symmetric(vertical: 2)),
        );
      } else if (f.tipo == 'testo') {
        final c = _ctrl.putIfAbsent(f.id, () => TextEditingController());
        input = TextField(
          controller: c,
          onChanged: (v) => _vals[f.id] = v,
          onSubmitted: (_) => _cerca(),
          style: t.text(weight: FontWeight.w600, height: 1.3),
          decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: f.placeholder, contentPadding: const EdgeInsets.symmetric(vertical: 2)),
        );
      } else {
        input = DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _vals[f.id] ?? '',
            isExpanded: true,
            isDense: true,
            focusColor: Colors.transparent,
            icon: VIcon('chevronDown', size: 16, color: t.ink2),
            style: t.text(weight: FontWeight.w600, height: 1.3),
            dropdownColor: Colors.white,
            items: [
              DropdownMenuItem(value: '', child: Text('Tutti', style: t.text(weight: FontWeight.w600))),
              for (final o in s.cat.opzioni(f)) DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _vals[f.id] = v ?? ''),
          ),
        );
      }
      return Hover(
        builder: (_, h) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: h ? t.bg : null, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label.toUpperCase(), style: t.caps(size: 11.5)),
            const SizedBox(height: 2),
            input,
          ]),
        ),
      );
    }

    final quick = boolOf(w['ricerca']) && qf.isNotEmpty
        ? Container(
            constraints: const BoxConstraints(maxWidth: 960),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(t.minimal ? 0 : (t.elegante ? 3 : (t.leone ? 12 : (narrow ? 16 : 20)))), boxShadow: t.shadowLg),
            child: LayoutBuilder(builder: (c, box) {
              final btn = SizedBox(
                height: narrow ? 48 : 54,
                child: VButton('Cerca', icon: 'search', kind: t.leone ? BtnKind.primary : BtnKind.accent, size: BtnSize.lg, block: narrow, radius: t.minimal ? 0 : (t.leone ? 8 : 14), onPressed: _cerca),
              );
              if (narrow) {
                return Column(children: [
                  Wrap(children: [for (final f in qf) SizedBox(width: (box.maxWidth) / 2, child: campo(f))]),
                  const SizedBox(height: 8),
                  btn,
                ]);
              }
              return Row(children: [
                for (final f in qf) Expanded(flex: 4, child: campo(f)),
                const SizedBox(width: 8),
                btn,
              ]);
            }),
          )
        : null;

    final content = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (str(w['titolo']).isNotEmpty)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: h1 * 11),
          child: Padding(
            padding: EdgeInsets.only(bottom: h1 * .35),
            child: Text(str(w['titolo']),
                style: t.title(size: h1, color: Colors.white, weight: t.elegante ? FontWeight.w500 : null).copyWith(shadows: const [Shadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 2))])),
          ),
        ),
      if (str(w['sottotitolo']).isNotEmpty)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: sub * 30),
          child: Padding(padding: EdgeInsets.only(bottom: sub * 1.8), child: Text(str(w['sottotitolo']), style: t.text(size: sub, color: Colors.white.withValues(alpha: .92)))),
        ),
      ?quick,
      if (str(w['pulsante']).isNotEmpty) ...[
        if (quick != null) const SizedBox(height: 24),
        VButton(str(w['pulsante']), iconAfter: 'arrowRight', kind: t.leone ? BtnKind.primary : BtnKind.accent, size: BtnSize.lg, href: safeUrl(w['link']).isEmpty ? '#/catalogo' : safeUrl(w['link'])),
      ],
    ]);

    if (img.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [t.primary, t.primaryDark])),
        child: Contained(child: Padding(padding: EdgeInsets.symmetric(vertical: narrow ? 56 : 80), child: content)),
      );
    }
    final overlay = t.moderno
        ? LinearGradient(colors: [t.primary.withValues(alpha: .85), const Color(0x590A1016)], stops: const [0, .7])
        : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x400A1016), Color(0x8C0A1016), Color(0xB30A1016)], stops: [0, .6, 1]);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: (context.vh * .78).clamp(0.0, 640.0)),
      child: Stack(children: [
        Positioned.fill(child: Container(color: t.primaryDark)),
        Positioned.fill(child: VImage(img)),
        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: overlay))),
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Contained(child: Padding(padding: EdgeInsets.symmetric(vertical: narrow ? 56 : 80), child: content)),
          ),
        ),
        // definisce l'altezza: almeno quella del contenuto
        Opacity(opacity: 0, child: IgnorePointer(child: Contained(child: Padding(padding: EdgeInsets.symmetric(vertical: narrow ? 56 : 80), child: content)))),
      ]),
    );
  }
}

/* ---------------- Catalogo ---------------- */

Built? _catalogo(BuildContext context, Json w) {
  final s = App.of(context);
  final sch = s.repo.schema;
  final completo = w['modalita'] == 'completo';
  final titolo = str(w['titolo']).isNotEmpty ? str(w['titolo']) : (completo ? sch.plurale : '');
  final head = SectionHead(
    title: titolo,
    subtitle: str(w['sottotitolo']),
    trailing: completo ? null : const LinkArrow('Vedi tutti', '#/catalogo'),
  );
  if (completo) return Built(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [head, const Listing()]), kind: 'alt');
  var arr = w['modalita'] == 'evidenza' ? s.repo.items.where((i) => boolOf(i['evidenza'])).toList() : <Json>[];
  if (arr.isEmpty) arr = [...s.repo.items]..sort((a, b) => intOf(b['creato']).compareTo(intOf(a['creato'])));
  arr = arr.take(intOf(w['quanti'], 6) > 0 ? intOf(w['quanti'], 6) : 6).toList();
  return Built(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    head,
    arr.isEmpty ? EmptyState(icon: sch.icona, text: "Nessun contenuto ancora. Aggiungili dall'area riservata.", small: true) : CardsGrid(arr),
  ]));
}

/* ---------------- Servizi / punti di forza ---------------- */

Built? _servizi(BuildContext context, Json w) {
  final t = context.t;
  final el = jsonList(w['elementi']);
  final noBorder = t.elegante || t.moderno;
  return Built(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    SectionHead(title: str(w['titolo']), subtitle: str(w['sottotitolo'])),
    AutoGrid(minWidth: 220, gap: 20, children: [
      for (final x in el)
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: t.surface, border: Border.all(color: noBorder ? Colors.transparent : t.line), borderRadius: t.r, boxShadow: noBorder ? t.shadow : null),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.only(bottom: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.minimal ? const Color(0xFF111111) : t.primarySoft,
                gradient: t.moderno ? LinearGradient(colors: [t.primarySoft, mix(t.accent, .18, Colors.white)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
                borderRadius: BorderRadius.circular(t.minimal ? 0 : (t.moderno ? 18 : 14)),
              ),
              child: VIcon(str(x['icona']).isEmpty ? 'star' : str(x['icona']), size: 26, color: t.minimal ? Colors.white : t.primary),
            ),
            Text(str(x['titolo']), style: t.title(size: 17.6, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(str(x['testo']), style: t.text(size: 15.2, color: t.muted)),
          ]),
        ),
    ]),
  ]));
}

/* ---------------- Numeri ---------------- */

class NumeriWidget extends StatelessWidget {
  final Json w;
  const NumeriWidget(this.w, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final el = jsonList(w['elementi']);
    final big = VTheme.clampVw(context, 35.2, 28.8, 1.6, 51.2);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.heroBg,
        gradient: t.moderno ? LinearGradient(colors: [t.primary, mix(t.primary, .6, t.accent)]) : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Contained(
        child: Column(children: [
          if (str(w['titolo']).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 32), child: Text(str(w['titolo']), textAlign: TextAlign.center, style: t.title(size: t.h2(context), color: t.onHero))),
          AutoGrid(minWidth: 170, gap: 24, equalHeight: false, children: [
            for (final x in el)
              Column(children: [
                Text(str(x['valore']), textAlign: TextAlign.center, style: t.title(size: big, color: t.accent, weight: t.elegante ? FontWeight.w600 : FontWeight.w800, height: 1.1, spacing: -.03 * big)),
                Text(str(x['etichetta']), textAlign: TextAlign.center, style: t.text(weight: FontWeight.w500, color: t.onHero.withValues(alpha: .85))),
              ]),
          ]),
        ]),
      ),
    );
  }
}

/* ---------------- Testo e immagine ---------------- */

Built? _testo(BuildContext context, Json w) {
  final t = context.t;
  final img = safeSrc(w['immagine']);
  final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (str(w['titolo']).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(str(w['titolo']), style: t.title(size: t.h2(context)))),
    Prose(str(w['testo'])),
    if (str(w['pulsante']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: VButton(str(w['pulsante']), iconAfter: 'arrowRight', kind: BtnKind.primary, size: BtnSize.lg, href: safeUrl(w['link']).isEmpty ? '#/catalogo' : safeUrl(w['link']))),
  ]);
  if (img.isEmpty) return Built(text);
  final image = ClipRRect(borderRadius: t.r, child: AspectRatio(aspectRatio: 4 / 3, child: VImage(img)));
  if (context.vw <= 860) return Built(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 28), image]));
  final rev = boolOf(w['invertito']);
  return Built(Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
    Expanded(child: rev ? image : text),
    const SizedBox(width: 56),
    Expanded(child: rev ? text : image),
  ]));
}

/* ---------------- Recensioni ---------------- */

Built? _recensioni(BuildContext context, Json w) {
  final s = App.of(context);
  final t = context.t;
  if (w['fonte'] != 'manuali' && s.modulo('recensioni')) {
    final d = s.repo.recInfo();
    if (intOf(d['totale']) > 0) {
      final media = doubleOf(d['media']);
      return Built(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHead(
            title: str(w['titolo']).isEmpty ? 'Dicono di noi' : str(w['titolo']),
            subtitleWidget: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              Stars(media),
              Text.rich(TextSpan(children: [
                TextSpan(text: str(media).replaceAll('.', ','), style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: ' su 5 · ${d['totale']} recensioni'),
              ]), style: t.text(color: t.muted)),
            ]),
            trailing: const LinkArrow('Tutte le recensioni', '#/recensioni'),
          ),
          AutoGrid(minWidth: 270, gap: 20, children: [for (final r in jsonList(d['recensioni']).take(3)) ReviewTile(r)]),
        ]),
        kind: 'alt',
      );
    }
  }
  return Built(
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(title: str(w['titolo']), subtitle: str(w['sottotitolo'])),
      AutoGrid(minWidth: 270, gap: 20, children: [
        for (final x in jsonList(w['elementi'])) ReviewTile({'voto': intOf(x['voto'], 5).clamp(0, 5), 'testo': x['testo'], 'nome': x['nome']}),
      ]),
    ]),
    kind: 'alt',
  );
}

/* ---------------- Mappa ---------------- */

Built? _mappa(BuildContext context, Json w) {
  final s = App.of(context);
  final pins = <MapPin>[if (s.repo.schema.hasGeo) ...catalogPins(s, s.repo.items)];
  final sede = sedePin(s);
  if (sede != null) pins.add(sede);
  return Built(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    SectionHead(title: str(w['titolo']), subtitle: str(w['sottotitolo'])),
    VMap(pins: pins, height: doubleOf(w['altezza'], 460) < 200 ? 200 : doubleOf(w['altezza'], 460), zoom: pins.length == 1 ? 14 : 6),
  ]));
}

/* ---------------- Inviti (prenota, fedeltà, gift card) ---------------- */

class PrenCta extends StatelessWidget {
  final String icon, title, text, button, href;
  const PrenCta({super.key, required this.icon, required this.title, required this.text, required this.button, required this.href});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // Su telefono l'icona va sopra il testo: affiancati (64 + 24 + almeno 200 px) uscivano dal riquadro
    final stretto = context.vw <= 520;
    final icona = Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: t.minimal ? const Color(0xFF111111) : t.primarySoft, borderRadius: BorderRadius.circular(t.minimal ? 0 : 18)),
      child: VIcon(icon, size: 30, color: t.minimal ? Colors.white : t.primary),
    );
    final testi = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: t.title(size: t.h2(context))),
      if (text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(text, style: t.text(color: t.muted))),
    ]);
    return Container(
      padding: stretto ? const EdgeInsets.all(22) : const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.minimal ? 0 : t.radius + 6), boxShadow: t.shadow),
      // larghezza dei testi misurata sullo spazio reale del riquadro (icona 64 + distanza 24)
      child: LayoutBuilder(builder: (context, box) {
        return Wrap(spacing: 24, runSpacing: 20, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
          if (stretto)
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [icona, const SizedBox(height: 16), testi])
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              icona,
              const SizedBox(width: 24),
              ConstrainedBox(constraints: BoxConstraints(maxWidth: (box.maxWidth - 88).clamp(200.0, 640.0)), child: testi),
            ]),
          VButton(button, iconAfter: 'arrowRight', kind: BtnKind.accent, size: BtnSize.lg, href: href),
        ]);
      }),
    );
  }
}

Built? _prenota(BuildContext context, Json w) {
  if (!App.of(context).modulo('prenotazioni')) return null;
  return Built(PrenCta(
    icon: 'calendar',
    title: str(w['titolo']).isEmpty ? 'Prenota online' : str(w['titolo']),
    text: str(w['testo']),
    button: str(w['pulsante']).isEmpty ? 'Prenota ora' : str(w['pulsante']),
    href: '#/prenota',
  ));
}

Built? _fedelta(BuildContext context, Json w) {
  if (!App.of(context).modulo('fedelta')) return null;
  return Built(PrenCta(icon: 'star', title: str(w['titolo']).isEmpty ? 'Tessera fedeltà' : str(w['titolo']), text: str(w['testo']), button: 'Scopri come funziona', href: '#/fedelta'));
}

Built? _giftcard(BuildContext context, Json w) {
  final s = App.of(context);
  if (!s.modulo('giftcard')) return null;
  final t = context.t;
  final txt = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(str(w['titolo']).isEmpty ? "Regala un'esperienza" : str(w['titolo']), style: t.title(size: t.h2(context))),
    if (str(w['testo']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8, bottom: 16), child: Text(str(w['testo']), style: t.text(color: t.muted))),
    VButton(str(w['pulsante']).isEmpty ? 'Regala una gift card' : str(w['pulsante']), icon: 'gift', kind: BtnKind.accent, size: BtnSize.lg, href: '#/giftcard'),
  ]);
  final card = CardVisual('giftcard', const {'valore': 50, 'destinatario': 'Te', 'messaggio': 'Un momento tutto per te', 'codice': 'GC-XXXX-XXXX'}, maxWidth: 420, angle: -.052);
  final narrow = context.vw <= 900;
  return Built(Container(
    padding: narrow ? const EdgeInsets.symmetric(horizontal: 22, vertical: 28) : const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
    decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: BorderRadius.circular(t.minimal ? 0 : t.radius + 6)),
    child: narrow
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [txt, const SizedBox(height: 28), Center(child: card)])
        : Row(children: [Expanded(flex: 11, child: txt), const SizedBox(width: 40), Expanded(flex: 9, child: Align(alignment: Alignment.centerRight, child: card))]),
  ));
}

/* ---------------- Offerte ---------------- */

Built? _offerte(BuildContext context, Json w) {
  final s = App.of(context);
  if (!s.modulo('offerte')) return null;
  final offerte = s.repo.offerteAttive();
  if (offerte.isEmpty) return null;
  final q = intOf(w['quanti'], 3) > 0 ? intOf(w['quanti'], 3) : 3;
  return Built(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    SectionHead(
      title: str(w['titolo']).isEmpty ? 'Offerte in corso' : str(w['titolo']),
      subtitle: str(w['sottotitolo']),
      trailing: const LinkArrow('Tutte le offerte', '#/offerte'),
    ),
    AutoGrid(minWidth: 290, gap: 20, children: [for (final o in offerte.take(q)) OffertaCard(o, offerte)]),
  ]));
}

/* ---------------- Invito al contatto ---------------- */

class ContattiCta extends StatelessWidget {
  final Json w;
  const ContattiCta(this.w, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final set = s.settings;
    final tel = telHref(str(set['telefono'])), wa = onlyDigits(str(set['whatsapp']));
    final narrow = context.vw <= 640;
    return Container(
      padding: narrow ? const EdgeInsets.symmetric(horizontal: 24, vertical: 32) : const EdgeInsets.symmetric(horizontal: 48, vertical: 44),
      decoration: BoxDecoration(
        gradient: t.minimal ? null : LinearGradient(colors: [t.primary, t.primaryDark], transform: const GradientRotation(.52)),
        color: t.minimal ? const Color(0xFF111111) : null,
        borderRadius: BorderRadius.circular(t.minimal ? 0 : t.radius + 6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(clipBehavior: Clip.none, children: [
        if (!t.minimal)
          Positioned(
            right: -60 - (narrow ? 24 : 48),
            bottom: -120 - (narrow ? 32 : 44),
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: t.accent.withValues(alpha: .18))),
          ),
        Wrap(spacing: 40, runSpacing: 24, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(str(w['titolo']), style: t.title(size: t.h2(context), color: t.minimal ? Colors.white : t.onPrimary)),
              if (str(w['testo']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(str(w['testo']), style: t.text(color: (t.minimal ? Colors.white : t.onPrimary).withValues(alpha: .88)))),
            ]),
          ),
          Wrap(spacing: 12, runSpacing: 12, children: [
            if (str(w['pulsante']).isNotEmpty) VButton(str(w['pulsante']), iconAfter: 'arrowRight', kind: BtnKind.accent, size: BtnSize.lg, href: safeUrl(w['link']).isEmpty ? '#/catalogo' : safeUrl(w['link'])),
            if (tel.isNotEmpty) VButton(str(set['telefono']), icon: 'phone', kind: BtnKind.light, size: BtnSize.lg, href: 'tel:$tel'),
            if (wa.isNotEmpty) VButton('WhatsApp', icon: 'chat', kind: BtnKind.light, size: BtnSize.lg, href: 'https://wa.me/$wa'),
            if (str(set['email']).isNotEmpty && str(w['pulsante']).isEmpty) VButton('Scrivici', icon: 'mail', kind: BtnKind.light, size: BtnSize.lg, href: 'mailto:${set['email']}'),
          ]),
        ]),
      ]),
    );
  }
}

