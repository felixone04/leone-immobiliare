// Controllo di tutte le pagine: apre ogni percorso del sito e dell'area riservata (desktop e telefono)
// e fallisce se Flutter segnala un errore (eccezioni, riquadri grigi, contenuti che escono dallo spazio).
// Uso: flutter test
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:leone_immobiliare/app_config.dart';
import 'package:leone_immobiliare/core/util.dart';
import 'package:leone_immobiliare/data/repository.dart';
import 'package:leone_immobiliare/data/store.dart';
import 'package:leone_immobiliare/data/store_factory.dart';
import 'package:leone_immobiliare/main.dart';
import 'package:leone_immobiliare/services/auth.dart';
import 'package:leone_immobiliare/state/app_state.dart';

void main() {
  late AppState state;
  var dbN = 0;

  // Nei test Flutter usa un carattere "a quadretti" più largo di quelli veri: carichiamo i caratteri
  // del sito (e le icone Material) perché gli spazi misurati siano quelli reali.
  setUpAll(() async {
    final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final f in manifest.cast<Map>()) {
      final loader = FontLoader(f['family'] as String);
      for (final a in (f['fonts'] as List).cast<Map>()) {
        loader.addFont(rootBundle.load(a['asset'] as String));
      }
      await loader.load();
    }
  });

  Future<void> avvia(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.runAsync(() async {
      Intl.defaultLocale = 'it';
      await initializeDateFormatting('it');
      await dbFactory.deleteDatabase(AppConfig.dbName); // ogni prova riparte dai contenuti di esempio
      final repo = await Repo.open();
      final auth = await AuthService.open(await LocalStore.open('test_${dbN++}.auth'));
      if (!auth.configurato) await auth.crea('prova', 'provaprova123');
      state = AppState(repo, auth);
    });
    // le sezioni dell'area riservata vanno controllate da dentro, non dalla pagina di accesso
    expect(state.auth.isAdmin, isTrue);
    await tester.pumpWidget(VetrinaApp(state: state));
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<String> percorsi() {
    final repo = state.repo;
    final ids = [for (final i in repo.items) str(i['id'])];
    final slugs = [for (final p in repo.pages) str(p['slug'])];
    return [
      '/',
      '/catalogo',
      '/catalogo?vista=mappa',
      '/catalogo?contratto=Affitto',
      for (final id in ids) '/scheda/$id',
      '/scheda/inesistente',
      for (final s in slugs) '/p/$s',
      '/prenota',
      '/giftcard',
      '/fedelta',
      '/pacchetti',
      '/offerte',
      '/recensioni',
      '/pagina-che-non-esiste',
      '/admin',
      '/admin/catalogo',
      '/admin/catalogo/nuovo',
      for (final id in ids) '/admin/catalogo/$id',
      '/admin/widget',
      '/admin/pagine',
      '/admin/messaggi',
      for (final v in ['agenda', 'lista', 'attesa', 'impostazioni']) '/admin/prenotazioni/$v',
      '/admin/cassa',
      for (final v in ['elenco', 'impostazioni']) '/admin/giftcard/$v',
      for (final v in ['tessere', 'impostazioni']) '/admin/fedelta/$v',
      for (final v in ['venduti', 'offerti']) '/admin/pacchetti/$v',
      for (final v in ['offerte', 'coupon']) '/admin/offerte/$v',
      for (final v in ['elenco', 'impostazioni']) '/admin/recensioni/$v',
      '/admin/impostazioni',
      '/admin/backup',
    ];
  }

  // Errori segnalati da Flutter, raccolti dall'avvio dell'app alla fine della prova
  final errori = <String>[];
  var corrente = '/';
  final dettagli = <String>{};

  /// Inizia a raccogliere gli errori; restituisce la funzione che rimette il gestore originale.
  VoidCallback ascolta() {
    errori.clear();
    dettagli.clear();
    corrente = '/';
    final originale = FlutterError.onError;
    FlutterError.onError = (d) {
      errori.add('$corrente → ${d.exceptionAsString().split('\n').first}');
      // dove: primo widget del progetto citato nel rapporto dell'errore
      final dove = RegExp(r'file:///\S*/lib/\S+').firstMatch(d.toString())?.group(0) ?? '?';
      if (dettagli.add(dove)) debugPrint('DOVE $corrente → $dove');
    };
    return () => FlutterError.onError = originale;
  }

  Future<List<String>> visita(WidgetTester tester) async {
    for (final p in percorsi()) {
      corrente = p;
      GoRouter.of(tester.element(find.byType(Navigator).first)).go(p);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      if (p.startsWith('/admin') && (find.text('Entra').evaluate().isNotEmpty || find.text('Crea account ed entra').evaluate().isNotEmpty)) {
        errori.add('$p → mostra la pagina di accesso invece della sezione');
      }
      // in fondo alla pagina (piè di pagina e ultimi blocchi)
      final scroll = find.byType(Scrollable);
      if (scroll.evaluate().isNotEmpty) {
        await tester.drag(scroll.first, const Offset(0, -20000), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }
      final e = tester.takeException();
      if (e != null) errori.add('$p → $e');
    }
    // chiude l'app (timer di notifiche e conti alla rovescia)
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    return List.of(errori);
  }

  for (final (nome, size) in [('desktop', const Size(1280, 900)), ('tablet', const Size(768, 1024)), ('telefono', const Size(375, 812)), ('telefono piccolo', const Size(320, 640))]) {
    testWidgets('tutte le pagine si aprono senza errori ($nome)', (tester) async {
      final ripristina = ascolta();
      final List<String> trovati;
      try {
        await avvia(tester, size);
        trovati = await visita(tester);
      } finally {
        ripristina();
      }
      expect(trovati, isEmpty, reason: trovati.join('\n'));
      tester.view.reset();
    });

    testWidgets('tutte le pagine con tutte le funzioni attive ($nome)', (tester) async {
      final ripristina = ascolta();
      final List<String> trovati;
      try {
        await avvia(tester, size);
        await tester.runAsync(() => state.repo.setModuli({for (final k in kModuli) k: true}));
        await tester.pump();
        trovati = await visita(tester);
      } finally {
        ripristina();
      }
      expect(trovati, isEmpty, reason: trovati.join('\n'));
      tester.view.reset();
    });
  }
}
