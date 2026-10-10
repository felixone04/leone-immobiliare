import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../kit.dart';
import '../shell.dart';
import 'listing.dart';

/// #/catalogo: elenco completo con filtri (i parametri dell'indirizzo precompilano i filtri).
class CatalogPage extends StatelessWidget {
  final Map<String, String> query;
  const CatalogPage({super.key, this.query = const {}});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final title = s.repo.schema.plurale;
    return PageScroll(children: [
      PageHero(title, slim: true),
      Contained(child: Padding(padding: pagePad(context), child: Listing(initial: query))),
    ]);
  }
}
