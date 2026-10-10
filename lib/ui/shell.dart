/// Intestazione (logo, ricerca, menu), piè di pagina, banner cookie e contenitore delle pagine.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../state/app_state.dart';
import 'dialogs.dart';
import 'kit.dart';

/// Contenitore comune: intestazione fissa in alto, contenuto, notifiche e banner cookie.
class SiteShell extends StatefulWidget {
  final String location;
  final Widget child;
  const SiteShell({super.key, required this.location, required this.child});
  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> {
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    // "/" porta alla ricerca (come nella versione web)
    if (e is KeyDownEvent && e.character == '/' && FocusManager.instance.primaryFocus?.context?.widget is! EditableText) {
      final f = FocusManager.instance.primaryFocus;
      if (f == null || f.context == null || f.context!.findAncestorWidgetOfExactType<EditableText>() == null) {
        _searchFocus.requestFocus();
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void deactivate() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final admin = widget.location.startsWith('/admin');
    return Scaffold(
      backgroundColor: admin ? context.t.adminBg : context.t.bg,
      body: Stack(children: [
        Column(children: [
          SiteHeader(location: widget.location, searchFocus: _searchFocus),
          Expanded(child: widget.child),
        ]),
        const ToastHost(),
        ValueListenableBuilder<bool>(
          valueListenable: s.cookieBanner,
          builder: (c, forza, _) => (s.repo.consenso == null || forza) ? const CookieBanner() : const SizedBox.shrink(),
        ),
      ]),
    );
  }
}

/// Pagina scorrevole con il piè di pagina in fondo.
class PageScroll extends StatelessWidget {
  final List<Widget> children;
  final bool footer;
  final ScrollController? controller;
  const PageScroll({super.key, required this.children, this.footer = true, this.controller});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        controller: controller,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            if (footer) const SiteFooter(),
          ]),
        ),
      );
    });
  }
}

/* ======================= Intestazione ======================= */

class SiteHeader extends StatelessWidget {
  final String location;
  final FocusNode searchFocus;
  const SiteHeader({super.key, required this.location, required this.searchFocus});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final narrow = context.vw <= 860;
    final brand = const _Brand();
    final menu = _MenuButton(location: location);
    final search = _SearchBox(focus: searchFocus);
    return Container(
      decoration: BoxDecoration(
        color: t.minimal || t.leone ? Colors.white : Colors.white.withValues(alpha: t.moderno ? .8 : .92),
        border: Border(bottom: t.leone ? BorderSide(color: t.primary, width: 3) : BorderSide(color: t.minimal ? const Color(0xFF111111) : t.line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: narrow
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [Expanded(child: Align(alignment: Alignment.centerLeft, child: brand)), menu]),
                    const SizedBox(height: 10),
                    search,
                  ]),
                )
              : Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LayoutBuilder(builder: (c, box) {
                    final side = ((box.maxWidth - 40 - 560) / 2).clamp(150.0, 9999.0);
                    final sw = (box.maxWidth - 40 - 2 * side).clamp(200.0, 560.0);
                    return Row(children: [
                      Expanded(child: Align(alignment: Alignment.centerLeft, child: brand)),
                      const SizedBox(width: 20),
                      SizedBox(width: sw, child: search),
                      const SizedBox(width: 20),
                      Expanded(child: Align(alignment: Alignment.centerRight, child: menu)),
                    ]);
                  }),
                ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).settings;
    final t = context.t;
    final logo = safeSrc(s['logo']);
    final narrow = context.vw <= 860;
    final h = narrow ? (t.logoH < 40 ? t.logoH : 40.0) : t.logoH;
    final mostraNome = boolOf(s['mostraNome']) || logo.isEmpty;
    return Semantics(
      label: 'Home',
      link: true,
      child: Hover(
        onTap: () => context.go('/'),
        builder: (_, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (logo.isNotEmpty)
            Flexible(
              child: ConstrainedBox(constraints: BoxConstraints(maxWidth: narrow ? 180 : 240, maxHeight: h), child: SizedBox(height: h, child: VImage(logo, fit: BoxFit.contain, alignment: Alignment.centerLeft))),
            ),
          if (logo.isNotEmpty && mostraNome) const SizedBox(width: 12),
          if (mostraNome)
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(str(s['nome']), overflow: TextOverflow.ellipsis, style: t.title(size: 18.4, weight: FontWeight.w800, height: 1.1, spacing: -.37)),
                if (str(s['slogan']).isNotEmpty && logo.isEmpty)
                  Text(str(s['slogan']), overflow: TextOverflow.ellipsis, style: t.text(size: 12, weight: FontWeight.w500, color: t.muted, height: 1.3)),
              ]),
            ),
        ]),
      ),
    );
  }
}

/* ---------- Ricerca con suggerimenti ---------- */

class _SearchBox extends StatefulWidget {
  final FocusNode focus;
  const _SearchBox({required this.focus});
  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _c = TextEditingController();
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _group = Object();

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(() {
      setState(() {});
      if (widget.focus.hasFocus && _c.text.trim().length >= 2) _portal.show();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _cerca() {
    _c.text.trim().length >= 2 ? _portal.show() : _portal.hide();
    setState(() {});
  }

  void _vai(String path) {
    _portal.hide();
    _c.clear();
    widget.focus.unfocus();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final s = App.of(context);
    final narrow = context.vw <= 860;
    final focused = widget.focus.hasFocus;
    return TapRegion(
      groupId: _group,
      onTapOutside: (_) => _portal.hide(),
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (ctx) => CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.bottomLeft,
            offset: const Offset(0, 8),
            child: Align(
              alignment: Alignment.topLeft,
              child: TapRegion(groupId: _group, child: _SearchResults(query: _c.text.trim(), width: _link.leaderSize?.width ?? 400, onGo: _vai, state: s)),
            ),
          ),
          child: SizedBox(
            height: narrow ? 42 : 46,
            child: Stack(alignment: Alignment.centerLeft, children: [
              CallbackShortcuts(
                bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _portal.hide()},
                child: TextField(
                  controller: _c,
                  focusNode: widget.focus,
                  onChanged: (_) => _cerca(),
                  onSubmitted: (q) {
                    if (q.trim().isNotEmpty) _vai('/catalogo?q=${Uri.encodeQueryComponent(q.trim())}');
                  },
                  style: t.text(size: 15.5, height: 1.2),
                  cursorColor: t.primary,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: focused ? Colors.white : t.bg,
                    hintText: 'Cerca ${s.repo.schema.plurale.toLowerCase()}, città, pagine…',
                    hintStyle: t.text(size: 15.5, color: t.muted, height: 1.2),
                    contentPadding: const EdgeInsets.fromLTRB(44, 13, 44, 13),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.controlRadius), borderSide: BorderSide(color: t.line2)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(t.controlRadius), borderSide: BorderSide(color: t.primary)),
                  ),
                ),
              ),
              Positioned(left: 16, child: IgnorePointer(child: VIcon('search', color: t.muted))),
              if (!focused && !narrow)
                Positioned(
                  right: 14,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: t.line2), borderRadius: BorderRadius.circular(6)),
                      child: Text('/', style: t.text(size: 12, weight: FontWeight.w600, color: t.muted, height: 1.4)),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final String query;
  final double width;
  final void Function(String) onGo;
  final AppState state;
  const _SearchResults({required this.query, required this.width, required this.onGo, required this.state});

  @override
  Widget build(BuildContext context) {
    final t = state.theme;
    final cat = state.cat;
    final sch = state.repo.schema;
    final words = norm(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final hasQ = sch.filtri.any((f) => f.id == 'q');
    final items = cat.items.where((i) => hasQ ? cat.match(i, {'q': query}) : words.every(norm(i['titolo']).contains)).toList();
    final pages = state.repo.pages.where((p) {
      final hay = norm('${p['titolo']} ${p['contenuto'] ?? ''}');
      return words.every(hay.contains);
    }).toList();

    Widget sec(String l) => Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 4), child: Text(l.toUpperCase(), style: t.caps(size: 11.5, spacing: .08)));
    Widget row({required Widget thumb, required String title, String? sub, required String path}) => Hover(
          onTap: () => onGo(path),
          builder: (_, h) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: h ? t.primarySoft : null, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(width: 48, height: 40, color: t.bg, alignment: Alignment.center, child: thumb),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text(size: 15.2, weight: FontWeight.w600, height: 1.35)),
                  if (sub != null && sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.text(size: 13.1, color: t.muted, height: 1.35)),
                ]),
              ),
            ]),
          ),
        );

    final children = <Widget>[];
    if (items.isEmpty && pages.isEmpty) {
      children.add(Padding(padding: const EdgeInsets.all(16), child: Text('Nessun risultato per «$query»', textAlign: TextAlign.center, style: t.text(color: t.muted))));
    } else {
      if (items.isNotEmpty) {
        children.add(sec(sch.plurale));
        for (final i in items.take(5)) {
          final f = cat.foto(i);
          children.add(row(
            thumb: f.isNotEmpty ? VImage(f.first, width: 48, height: 40, fallback: VIcon(sch.icona, color: t.muted)) : VIcon(sch.icona, color: t.muted),
            title: str(i['titolo']),
            sub: [cat.luogo(i), cat.prezzo(i)].where((x) => x.isNotEmpty).join(' · '),
            path: '/scheda/${i['id']}',
          ));
        }
      }
      if (pages.isNotEmpty) {
        children.add(sec('Pagine'));
        for (final p in pages.take(3)) {
          children.add(row(thumb: VIcon('file', color: t.muted), title: str(p['titolo']), path: '/p/${p['slug']}'));
        }
      }
      if (items.isNotEmpty) {
        children.add(Container(
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
          child: Hover(
            onTap: () => onGo('/catalogo?q=${Uri.encodeQueryComponent(query)}'),
            builder: (_, h) => Container(
              color: h ? t.primarySoft : null,
              padding: const EdgeInsets.all(10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Vedi tutti i ${items.length} risultati', style: t.text(size: 14.4, weight: FontWeight.w700, color: t.primary)),
                const SizedBox(width: 6),
                VIcon('arrowRight', color: t.primary),
              ]),
            ),
          ),
        ));
      }
    }
    return VT(
      theme: t,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          constraints: BoxConstraints(maxHeight: (MediaQuery.sizeOf(context).height * .7).clamp(200.0, 520.0)),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: t.line), borderRadius: t.r, boxShadow: t.shadowLg),
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children)),
        ),
      ),
    );
  }
}

/* ---------- Menu a tendina ---------- */

class _MenuButton extends StatefulWidget {
  final String location;
  const _MenuButton({required this.location});
  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  final _group = Object();
  var _hover = false;

  void _go(String path) {
    _portal.hide();
    setState(() {});
    if (path.startsWith('tel:')) {
      openLink(context, path);
    } else {
      context.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final s = App.of(context);
    final open = _portal.isShowing;
    final small = context.vw <= 400;
    final narrow = context.vw <= 860;
    return TapRegion(
      groupId: _group,
      onTapOutside: (_) {
        if (_portal.isShowing) setState(_portal.hide);
      },
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: (ctx) => CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 8),
            child: Align(
              alignment: Alignment.topRight,
              child: TapRegion(groupId: _group, child: _MenuDropdown(state: s, location: widget.location, onGo: _go)),
            ),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              onTap: () => setState(_portal.toggle),
              child: Semantics(
                button: true,
                expanded: open,
                label: 'Menu',
                child: Container(
                  height: narrow ? 42 : 46,
                  padding: EdgeInsets.symmetric(horizontal: narrow ? 14 : 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _hover || open ? t.primary : t.line2),
                    borderRadius: BorderRadius.circular(t.controlRadius),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    VIcon('menu', stroke: 2, color: _hover || open ? t.primary : t.ink),
                    if (!small) ...[
                      const SizedBox(width: 8),
                      Text('Menu', style: t.text(weight: FontWeight.w700, color: _hover || open ? t.primary : t.ink, height: 1.2)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuDropdown extends StatelessWidget {
  final AppState state;
  final String location;
  final void Function(String) onGo;
  const _MenuDropdown({required this.state, required this.location, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final t = state.theme;
    final sch = state.repo.schema;
    final set = state.settings;
    final tel = str(set['telefono']);
    final cur = location.split('?').first;
    Widget item(String path, String icon, String label, {bool cta = false, bool small = false}) {
      final active = !cta && (path == '/' ? cur == '/' : cur == path);
      return Hover(
        onTap: () => onGo(path),
        builder: (_, h) {
          final bg = cta ? (h ? Color.lerp(t.accent, Colors.white, .05) : t.accent) : (active || h ? t.primarySoft : null);
          final fg = cta ? t.onAccent : (active ? t.primary : (small ? t.muted : t.ink));
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              VIcon(icon, color: cta ? t.onAccent : (active ? t.primary : t.muted)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: t.text(size: small ? 14.4 : 16, weight: FontWeight.w600, color: fg, height: 1.3))),
            ]),
          );
        },
      );
    }

    Widget hr() => Container(height: 1, color: t.line, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6));
    final voci = state.vociClienti;
    return VT(
      theme: t,
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 140),
          builder: (c, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, -4 * (1 - v)), child: child)),
          child: Container(
            constraints: BoxConstraints(minWidth: 250, maxWidth: 320, maxHeight: MediaQuery.sizeOf(context).height - 100),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: t.line), borderRadius: t.r, boxShadow: t.shadowLg),
            child: IntrinsicWidth(
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  item('/', 'home', 'Home'),
                  item('/catalogo', sch.icona, sch.plurale),
                  if (state.modulo('prenotazioni')) item('/prenota', 'calendar', 'Prenota online', cta: true),
                  if (voci.isNotEmpty) ...[
                    hr(),
                    Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 2), child: Text('PER TE', style: t.caps(size: 11.2, weight: FontWeight.w800, spacing: .1))),
                    for (final (h, ic, l) in voci) item('/$h', ic, l),
                    hr(),
                  ],
                  for (final p in state.repo.pages.where((p) => boolOf(p['menu']))) item('/p/${p['slug']}', p['tipo'] == 'contatti' ? 'mail' : 'file', str(p['titolo'])),
                  if (tel.isNotEmpty) ...[hr(), item('tel:${telHref(tel)}', 'phone', tel)],
                  hr(),
                  item('/admin', 'lock', 'Area riservata', small: true),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ======================= Piè di pagina ======================= */

class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final set = s.settings;
    final logo = safeSrc(set['logo']);
    final tel = telHref(str(set['telefono']));
    final pagine = s.repo.pages.where((p) => p['footer'] != false).toList();
    final social = ['facebook', 'instagram', 'linkedin'].where((k) => str(set[k]).isNotEmpty && safeUrl(set[k]) != '#').toList();
    const txt = Color(0xFFC5CAD1);
    final base = t.text(size: 15.2, color: txt);
    Widget h4(String x) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(x.toUpperCase(), style: t.title(size: 12.8, color: Colors.white, weight: FontWeight.w700, spacing: 1.28)));
    Widget link(String label, String href) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextLink(label, href, style: base.copyWith(height: 1.4)));

    final colBrand = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (logo.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(t.leone ? 8 : 12)),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200), child: SizedBox(height: t.leone ? 56 : 40, child: VImage(logo, fit: BoxFit.contain, alignment: Alignment.centerLeft))),
        )
      else
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(str(set['nome']), style: t.title(size: 20.8, color: Colors.white))),
      if (str(set['slogan']).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(str(set['slogan']), style: base)),
      if (social.isNotEmpty)
        Wrap(spacing: 8, children: [
          for (final k in social)
            Tooltip(
              message: k,
              child: Hover(
                onTap: () => openLink(context, str(set[k])),
                builder: (_, h) => Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: h ? t.footerAccent : Colors.white.withValues(alpha: .08), shape: t.minimal ? BoxShape.rectangle : BoxShape.circle),
                  child: VIcon(k, color: h ? t.onFooterAccent : txt),
                ),
              ),
            ),
        ]),
    ]);
    final colEsplora = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      h4('Esplora'),
      link(s.repo.schema.plurale, '#/catalogo'),
      if (s.modulo('prenotazioni')) link('Prenota online', '#/prenota'),
      for (final (h, _, l) in s.vociClienti) link(l, '#/$h'),
      for (final p in pagine) link(str(p['titolo']), '#/p/${p['slug']}'),
    ]);
    Widget contact(String icon, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 3), child: VIcon(icon, color: t.footerAccent)),
            const SizedBox(width: 10),
            Expanded(child: child),
          ]),
        );
    final colContatti = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      h4('Contatti'),
      if (str(set['indirizzo']).isNotEmpty) contact('pin', Text(str(set['indirizzo']), style: base)),
      if (tel.isNotEmpty) contact('phone', TextLink(str(set['telefono']), 'tel:$tel', style: base)),
      if (str(set['email']).isNotEmpty) contact('mail', TextLink(str(set['email']), 'mailto:${set['email']}', style: base)),
    ]);
    final colOrari = str(set['orari']).isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [h4('Orari'), Text(str(set['orari']), style: base)]);

    final cols = [colBrand, colEsplora, colContatti, ?colOrari];
    final w = context.vw;
    Widget grid;
    if (w > 860) {
      final flex = [14, 10, 12, 10];
      grid = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < cols.length; i++) ...[if (i > 0) const SizedBox(width: 40), Expanded(flex: flex[i], child: cols[i])],
        if (cols.length < 4) const Expanded(flex: 10, child: SizedBox()),
      ]);
    } else if (w > 520) {
      grid = AutoGrid(minWidth: 200, gap: 32, maxCols: 2, equalHeight: false, children: cols);
    } else {
      grid = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final c in cols) Padding(padding: const EdgeInsets.only(bottom: 32), child: c)]);
    }
    final bottomStyle = t.text(size: 13.6, color: const Color(0xFF8B929B));
    return Container(
      decoration: BoxDecoration(color: t.footerBg, border: t.leone ? Border(top: BorderSide(color: t.primary, width: 4)) : null),
      padding: const EdgeInsets.only(top: 56),
      child: Contained(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.only(bottom: 40), child: grid),
          Container(
            padding: const EdgeInsets.only(top: 20, bottom: 28),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: .1)))),
            child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 16, runSpacing: 12, children: [
              Text('© ${DateTime.now().year} ${str(set['ragioneSociale']).isNotEmpty ? set['ragioneSociale'] : set['nome']}${str(set['piva']).isNotEmpty ? ' · P.IVA ${set['piva']}' : ''}', style: bottomStyle),
              Wrap(spacing: 16, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                TextLink('Privacy e cookie', '#/p/${s.slugPrivacy}', style: bottomStyle),
                Hover(
                  onTap: () => s.cookieBanner.value = true,
                  builder: (_, h) => Text('Preferenze cookie', style: h ? bottomStyle.copyWith(color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white) : bottomStyle),
                ),
                Hover(
                  onTap: () => context.go('/admin'),
                  builder: (_, h) => Row(mainAxisSize: MainAxisSize.min, children: [
                    VIcon('lock', size: 15, color: h ? Colors.white : const Color(0xFF8B929B)),
                    const SizedBox(width: 6),
                    Text('Area riservata', style: h ? bottomStyle.copyWith(color: Colors.white, decoration: TextDecoration.underline, decorationColor: Colors.white) : bottomStyle),
                  ]),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/* ======================= Banner cookie ======================= */

class CookieBanner extends StatelessWidget {
  const CookieBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Future<void> scegli(String v) async {
      s.cookieBanner.value = false;
      await s.repo.setConsenso(v);
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r, boxShadow: t.shadowLg),
              child: Wrap(spacing: 24, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420, minWidth: 260),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('La tua privacy', style: t.text(weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Usiamo solo cookie tecnici. Con il tuo consenso carichiamo anche contenuti esterni (mappe OpenStreetMap). '),
                        WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: TextLink('Informativa', '#/p/${s.slugPrivacy}', style: t.text(size: 14.4, color: t.primary).copyWith(decoration: TextDecoration.underline, decorationColor: t.primary))),
                      ]),
                      style: t.text(size: 14.4, color: t.ink2, height: 1.5),
                    ),
                  ]),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  VButton('Solo necessari', kind: BtnKind.ghost, onAsync: () => scegli('necessari')),
                  VButton('Accetta tutto', kind: BtnKind.primary, onAsync: () => scegli('tutti')),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
