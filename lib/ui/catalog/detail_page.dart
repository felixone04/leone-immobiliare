/// #/scheda/ID: pagina di dettaglio di un annuncio.
library;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/icons.dart';
import '../../core/markdown.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/abbinamento.dart';
import '../../data/preset.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../clienti/account.dart';
import '../forms_public.dart';
import '../kit.dart';
import '../map/vmap.dart';
import '../shell.dart';
import 'item_card.dart';
import 'lightbox.dart';

class DetailPage extends StatelessWidget {
  final String id;
  const DetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final sch = s.repo.schema;
    final item = s.repo.item(id);
    if (item == null) {
      return PageScroll(children: [
        Contained(
          child: Padding(
            padding: pagePad(context),
            child: EmptyState(
              icon: 'search',
              title: '${sch.singolare} non trovato',
              text: "L'annuncio potrebbe essere stato rimosso.",
              actions: [const VButton('Vedi tutti', kind: BtnKind.primary, href: '#/catalogo')],
            ),
          ),
        ),
      ]);
    }
    final cat = s.cat;
    final cd = sch.card;
    final fotos = cat.foto(item);
    final g = cat.geo(item);
    final nastro = cat.nastro(item);
    final mostraPrivati = cat.mostraPrivati(item);
    final et = cat.etichette(item);
    final set = s.settings;

    // Caratteristiche principali
    final principali = [for (final p in sch.scheda.principali) (p, cat.fmt(item, p.campo))].where((x) => x.$2.isNotEmpty).toList();

    // Altri campi raggruppati come nel modulo di inserimento
    final esclusi = <String>{
      'titolo', 'descrizione', 'foto', 'geo', 'evidenza', 'video', cd.prezzo, ...cd.badge, ?cd.nastroCampo, ?sch.privacyGeo,
      ...sch.scheda.principali.map((p) => p.campo), ...sch.scheda.dettaglio, ...sch.scheda.escludi,
      if (!mostraPrivati) ...sch.privacyCampi,
    };
    final gruppi = <String, ({List<(String, String)> righe, List<FieldDef> liste})>{};
    final testi = <FieldDef>[];
    for (final c in sch.campi) {
      if (esclusi.contains(c.key) || isEmptyValue(item[c.key]) || c.type == 'photos' || c.type == 'geo') continue;
      if (c.type == 'bool' && !boolOf(item[c.key])) continue;
      if (c.type == 'textarea') {
        testi.add(c);
        continue;
      }
      final gr = gruppi.putIfAbsent(c.gruppo ?? '', () => (righe: <(String, String)>[], liste: <FieldDef>[]));
      if (c.type == 'checks') {
        gr.liste.add(c);
      } else {
        gr.righe.add((c.label, cat.fmt(item, c.key)));
      }
    }
    final luogo = [if (mostraPrivati) str(item['indirizzo']), cat.luogo(item)].where((x) => x.isNotEmpty).join(', ');
    final extra = <Widget>[];
    for (final k in sch.scheda.dettaglio) {
      final c = sch.campo(k);
      if (c == null || isEmptyValue(item[k]) || item[k] == false) continue;
      extra.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: c.type == 'bool'
            ? Row(children: [const VIcon('check', color: VTheme.ok), const SizedBox(width: 6), Text(c.label, style: t.text(size: 14.4, color: t.ink2))])
            : Row(children: [
                Expanded(child: Text(c.label, style: t.text(size: 14.4, color: t.ink2))),
                Text(cat.fmt(item, k), style: t.text(size: 14.4, weight: FontWeight.w700, color: t.ink2)),
              ]),
      ));
    }
    final tel = telHref(str(set['telefono'])), wa = onlyDigits(str(set['whatsapp']));
    final rif = str(item['rif']).isNotEmpty ? ' (rif. ${item['rif']})' : '';
    final msg = 'Buongiorno, vorrei ricevere informazioni su «${item['titolo']}»$rif.';
    final oggetto = 'Richiesta informazioni: ${item['titolo']}$rif';
    final wide = context.vw > 1000;

    /* ---------- Colonna principale ---------- */
    Widget dsec(String title, Widget body, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: t.line))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(title, style: t.title(size: 20.8))),
            body,
          ]),
        );

    final sezioni = <(String, Widget)>[
      if (str(item['descrizione']).isNotEmpty) ('Descrizione', Prose(str(item['descrizione']))),
      for (final c in testi) (c.label, Prose(str(item[c.key]))),
      for (final e in gruppi.entries)
        (
          e.key,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (e.value.righe.isNotEmpty)
              AutoGrid(minWidth: 260, gap: 32, rowGap: 0, equalHeight: false, children: [
                for (final (l, v) in e.value.righe)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line, style: BorderStyle.solid))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l, style: t.text(color: t.muted)),
                      const SizedBox(width: 16),
                      Expanded(child: Text(v, textAlign: TextAlign.right, style: t.text(weight: FontWeight.w600))),
                    ]),
                  ),
              ]),
            for (final c in e.value.liste) ...[
              if (c.label != e.key) Padding(padding: const EdgeInsets.only(top: 20, bottom: 10), child: Text(c.label, style: t.title(size: 15.2, color: t.ink2, weight: FontWeight.w700))),
              AutoGrid(minWidth: 200, gap: 24, rowGap: 10, equalHeight: false, children: [
                for (final x in strList(item[c.key]))
                  Row(children: [const VIcon('check', color: VTheme.ok), const SizedBox(width: 10), Expanded(child: Text(x, style: t.text()))]),
              ]),
            ],
          ]),
        ),
      if (str(item['video']).isNotEmpty && safeUrl(item['video']) != '#')
        ('Video', Align(alignment: Alignment.centerLeft, child: VButton('Guarda il video / virtual tour', icon: 'video', kind: BtnKind.outline, href: safeUrl(item['video'])))),
      if (g != null)
        (
          'Posizione',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!g.esatta)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text("La posizione sulla mappa è indicativa: l'indirizzo esatto viene comunicato su richiesta.", style: t.text(size: 14.1, color: t.muted)),
              ),
            VMap(
              height: 360,
              center: LatLng(g.lat, g.lng),
              zoom: g.esatta ? 16 : 14,
              fit: false,
              pins: g.esatta ? [MapPin(LatLng(g.lat, g.lng), '', kind: 'dot')] : const [],
              circle: g.esatta ? null : (pos: LatLng(g.lat, g.lng), radius: 350),
            ),
          ]),
        ),
    ];

    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (var i = 0; i < cd.badge.length; i++)
          if (str(item[cd.badge[i]]).isNotEmpty) VBadge(str(item[cd.badge[i]]), soft: i > 0, onImage: false),
        for (final e in et) EtichettaTag(e),
      ]),
      const SizedBox(height: 12),
      Text(str(item['titolo']), style: t.title(size: t.h1(context))),
      const SizedBox(height: 6),
      if (luogo.isNotEmpty)
        Row(children: [VIcon('pin', color: t.ink2), const SizedBox(width: 8), Expanded(child: Text(luogo, style: t.text(size: 16.8, color: t.ink2)))]),
      if (principali.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 24, bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: t.line))),
          child: AutoGrid(minWidth: 150, gap: 16, equalHeight: false, children: [
            for (final (p, v) in principali)
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: VIcon(p.icona, size: 22, color: t.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v, style: t.text(size: 16.8, weight: FontWeight.w700, height: 1.3)),
                    Text(p.label, style: t.text(size: 13.1, color: t.muted, height: 1.3)),
                  ]),
                ),
              ]),
          ]),
        ),
      for (var k = 0; k < sezioni.length; k++) dsec(sezioni[k].$1, sezioni[k].$2, last: k == sezioni.length - 1),
    ]);

    /* ---------- Colonna laterale ---------- */
    final logo = safeSrc(set['logo']);
    // visita a questo immobile: il servizio "visita" delle prenotazioni, con l'immobile già scelto
    final visita = s.modulo('prenotazioni') && immobileDisponibile(item)
        ? s.repo.prenServizi().values.where((x) => norm(x['nome']).contains('visita')).firstOrNull
        : null;
    final side = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r, boxShadow: t.shadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: PriceText(item, size: 32)),
          PreferitoBtn(item['id'] as String, size: 44),
        ]),
        if (extra.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Column(children: extra)),
        if (visita != null) ...[
          const SizedBox(height: 16),
          VButton('Prenota una visita', icon: 'calendar', kind: BtnKind.accent, size: BtnSize.lg, block: true, href: '#/prenota?servizio=${visita['id']}&immobile=${item['id']}'),
        ],
        Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: t.line))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              if (logo.isNotEmpty) ...[ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: SizedBox(height: 36, child: VImage(logo, fit: BoxFit.contain))), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(str(set['nome']), style: t.text(weight: FontWeight.w700, height: 1.3)),
                  if (str(set['slogan']).isNotEmpty) Text(str(set['slogan']), style: t.text(size: 13.6, color: t.muted, height: 1.3)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              if (tel.isNotEmpty) Expanded(child: VButton('Chiama', icon: 'phone', kind: BtnKind.outline, block: true, href: 'tel:$tel')),
              if (tel.isNotEmpty && wa.isNotEmpty) const SizedBox(width: 8),
              if (wa.isNotEmpty) Expanded(child: VButton('WhatsApp', icon: 'chat', kind: BtnKind.outline, block: true, href: 'https://wa.me/$wa?text=${Uri.encodeComponent(msg)}')),
            ]),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Richiedi informazioni', style: t.title(size: 17.6, weight: FontWeight.w700))),
        ContactForm(oggetto: oggetto, messaggio: msg, pagina: '#/scheda/${item['id']}', immobile: item['id'] as String),
      ]),
    );

    final simili = cat.simili(item);
    return _ContaVista(id: id, child: PageScroll(children: [
      Contained(
        child: Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 72),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Crumbs([('Home', '/'), (sch.plurale, '/catalogo'), (str(item['titolo']), null)]),
            if (fotos.isNotEmpty)
              _Gallery(fotos: fotos, nastro: nastro, titolo: str(item['titolo']))
            else
              Container(height: 260, margin: const EdgeInsets.only(bottom: 32), decoration: BoxDecoration(borderRadius: t.r), clipBehavior: Clip.antiAlias, child: PlaceholderIcon(sch.icona)),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: main),
                const SizedBox(width: 48),
                SizedBox(width: 370, child: side),
              ])
            else ...[main, const SizedBox(height: 16), side],
            if (simili.isNotEmpty) ...[
              const SizedBox(height: 56),
              const SectionHead(title: 'Potrebbero interessarti', trailing: LinkArrow('Vedi tutti', '#/catalogo')),
              CardsGrid(simili),
            ],
          ]),
        ),
      ),
    ]));
  }
}

/// Conta una visita alla scheda (per le statistiche), una volta per apertura; non conta l'agenzia collegata.
class _ContaVista extends StatefulWidget {
  final String id;
  final Widget child;
  const _ContaVista({required this.id, required this.child});
  @override
  State<_ContaVista> createState() => _ContaVistaState();
}

class _ContaVistaState extends State<_ContaVista> {
  @override
  void initState() {
    super.initState();
    final s = App.read(context);
    if (!s.auth.isAdmin) s.repo.registraVista(widget.id);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Galleria con fino a 5 foto (.gallery g1…g5)
class _Gallery extends StatelessWidget {
  final List<String> fotos;
  final String nastro, titolo;
  const _Gallery({required this.fotos, required this.nastro, required this.titolo});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final w = context.vw;
    final n = fotos.length < 5 ? fotos.length : 5;
    final single = w <= 760;
    final bleed = w <= 640;
    final h = bleed ? 280.0 : (single ? 340.0 : (context.vh * .62).clamp(0.0, 520.0));
    Widget tile(int k) => Semantics(
          button: true,
          label: 'Apri foto ${k + 1}',
          child: _GalleryTile(src: fotos[k], onTap: () => showLightbox(context, fotos, k)),
        );
    const gap = 8.0;
    Widget grid;
    if (single || n == 1) {
      grid = tile(0);
    } else if (n == 2) {
      grid = Row(children: [Expanded(child: tile(0)), const SizedBox(width: gap), Expanded(child: tile(1))]);
    } else if (n == 3) {
      grid = Row(children: [
        Expanded(flex: 2, child: tile(0)),
        const SizedBox(width: gap),
        Expanded(child: Column(children: [Expanded(child: tile(1)), const SizedBox(height: gap), Expanded(child: tile(2))])),
      ]);
    } else if (n == 4) {
      grid = Row(children: [
        Expanded(flex: 2, child: tile(0)),
        const SizedBox(width: gap),
        Expanded(
          flex: 2,
          child: Column(children: [
            Expanded(child: Row(children: [Expanded(child: tile(1)), const SizedBox(width: gap), Expanded(child: tile(2))])),
            const SizedBox(height: gap),
            Expanded(child: tile(3)),
          ]),
        ),
      ]);
    } else {
      grid = Row(children: [
        Expanded(flex: 2, child: tile(0)),
        const SizedBox(width: gap),
        Expanded(child: Column(children: [Expanded(child: tile(1)), const SizedBox(height: gap), Expanded(child: tile(3))])),
        const SizedBox(width: gap),
        Expanded(child: Column(children: [Expanded(child: tile(2)), const SizedBox(height: gap), Expanded(child: tile(4))])),
      ]);
    }
    final box = Container(
      height: h,
      margin: EdgeInsets.only(bottom: 32, left: bleed ? 0 : 0),
      decoration: BoxDecoration(borderRadius: bleed ? null : t.r),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        grid,
        if (fotos.length > 1)
          Positioned(right: 16, bottom: 16, child: Container(decoration: BoxDecoration(boxShadow: t.shadow, borderRadius: BorderRadius.circular(t.btnRadius)), child: VButton('Tutte le foto (${fotos.length})', icon: 'image', kind: BtnKind.light, onPressed: () => showLightbox(context, fotos, 0)))),
        if (nastro.isNotEmpty) Positioned(top: 16, right: 16, child: Ribbon(nastro, big: true)),
      ]),
    );
    // sui telefoni la galleria occupa tutta la larghezza dello schermo (annulla il margine laterale di 16 px)
    if (!bleed) return box;
    return LayoutBuilder(
      builder: (c, bc) => Container(
        height: h + 32,
        alignment: Alignment.topCenter,
        child: OverflowBox(minWidth: bc.maxWidth + 32, maxWidth: bc.maxWidth + 32, minHeight: h + 32, maxHeight: h + 32, child: box),
      ),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final String src;
  final VoidCallback onTap;
  const _GalleryTile({required this.src, required this.onTap});
  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  var _h = false;
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: t.primarySoft,
          child: ClipRect(
            child: AnimatedScale(
              scale: _h ? 1.03 : 1,
              duration: const Duration(milliseconds: 400),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: _h ? .06 : 0), BlendMode.darken),
                child: SizedBox.expand(child: VImage(widget.src)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
