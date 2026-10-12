/// Percorsi del sito: gli stessi indirizzi della versione web (#/catalogo, #/scheda/ID, #/admin…).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/util.dart';
import '../state/app_state.dart';
import 'admin/admin_page.dart';
import 'booking/gestisci_page.dart';
import 'booking/prenota_page.dart';
import 'catalog/catalog_page.dart';
import 'catalog/detail_page.dart';
import 'clienti/account.dart';
import 'clienti/recensioni_page.dart';
import 'home/home_page.dart';
import 'pages/info_page.dart';
import 'pages/not_found.dart';
import 'shell.dart';

GoRouter buildRouter(AppState state) {
  Page<void> page(GoRouterState st, Widget child, String title) {
    _setTitle(state, title);
    return NoTransitionPage(key: ValueKey(st.uri.toString()), child: child);
  }

  GoRoute r(String path, Widget Function(GoRouterState st) build, String Function(GoRouterState st) title) =>
      GoRoute(path: path, pageBuilder: (c, st) => page(st, build(st), title(st)));

  String q(GoRouterState st, String k) => st.uri.queryParameters[k] ?? '';
  String p(GoRouterState st, String k) => st.pathParameters[k] ?? '';

  return GoRouter(
    initialLocation: '/',
    errorPageBuilder: (c, st) => page(st, const NotFoundPage(), 'Pagina non trovata'),
    routes: [
      ShellRoute(
        builder: (c, st, child) => SiteShell(location: st.uri.toString(), child: child),
        routes: [
          r('/', (st) => const HomePage(), (_) => ''),
          r('/catalogo', (st) => CatalogPage(query: st.uri.queryParameters), (_) => state.repo.schema.plurale),
          r('/scheda/:id', (st) => DetailPage(id: p(st, 'id')), (st) => str(state.repo.item(p(st, 'id'))?['titolo'] ?? 'Non trovato')),
          r('/p/:slug', (st) => InfoPage(slug: p(st, 'slug')), (st) => str(state.repo.pages.where((x) => x['slug'] == p(st, 'slug')).firstOrNull?['titolo'] ?? 'Pagina non trovata')),
          r('/prenota', (st) => PrenotaPage(servizio: q(st, 'servizio'), immobile: q(st, 'immobile')), (_) => 'Prenota una visita'),
          r('/mia-prenotazione/:id', (st) => GestisciPage(id: p(st, 'id')), (_) => 'La tua prenotazione'),
          r('/recensioni', (st) => RecensioniPage(pren: q(st, 'pren')), (_) => 'Recensioni'),
          r('/account', (st) => const AccountPage(), (_) => 'Il mio account'),
          r('/account/:tab', (st) => AccountPage(tab: p(st, 'tab')), (_) => 'Il mio account'),
          r('/admin', (st) => AdminPage(parts: const [], query: st.uri.queryParameters), (_) => 'Area riservata'),
          r('/admin/:tab', (st) => AdminPage(parts: [p(st, 'tab')], query: st.uri.queryParameters), (_) => 'Area riservata'),
          r('/admin/:tab/:sub', (st) => AdminPage(parts: [p(st, 'tab'), p(st, 'sub')], query: st.uri.queryParameters), (_) => 'Area riservata'),
        ],
      ),
    ],
  );
}

/// Titolo della scheda del browser, come nella versione web.
void _setTitle(AppState s, String title) {
  final set = s.settings;
  final nome = str(set['nome']);
  final full = title.isNotEmpty ? '$title · $nome' : '$nome${str(set['slogan']).isNotEmpty ? ' · ${set['slogan']}' : ''}';
  SystemChrome.setApplicationSwitcherDescription(ApplicationSwitcherDescription(label: full, primaryColor: s.theme.primary.toARGB32()));
}
