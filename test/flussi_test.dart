// Flussi principali usati come farebbe una persona: tocchi, campi compilati, pulsanti.
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
import 'package:leone_immobiliare/ui/clienti/account.dart';
import 'package:leone_immobiliare/ui/kit.dart';

void main() {
  late AppState state;
  var n = 0;

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

  Future<void> avvia(WidgetTester tester, {bool admin = false, double altezza = 900}) async {
    tester.view.physicalSize = Size(1280, altezza);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      Intl.defaultLocale = 'it';
      await initializeDateFormatting('it');
      await dbFactory.deleteDatabase(AppConfig.dbName);
      final repo = await Repo.open();
      await repo.setConsenso('necessari');
      final auth = await AuthService.open(await LocalStore.open('flussi_${n++}.auth'));
      if (admin) await auth.crea('prova', 'provaprova123');
      state = AppState(repo, auth);
    });
    await tester.pumpWidget(VetrinaApp(state: state));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> vai(WidgetTester tester, String path) async {
    GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Esegue il lavoro asincrono vero (cifratura della password) e aggiorna lo schermo.
  Future<void> attendi(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> chiudi(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('cuore senza account → registrazione → immobile tra i preferiti', (tester) async {
    await avvia(tester);
    await vai(tester, '/catalogo');
    final primo = state.repo.items.first['id'] as String;
    await tester.tap(find.byType(PreferitoBtn).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Il tuo account'), findsOneWidget);

    await tester.tap(find.text('Crea un account'));
    await tester.pump(const Duration(milliseconds: 300));
    final campi = find.descendant(of: find.byType(AccessoForm), matching: find.byType(EditableText));
    await tester.enterText(campi.at(0), 'Giulia Neri');
    await tester.enterText(campi.at(1), 'giulia@example.com');
    await tester.enterText(campi.at(3), 'casa2026ok');
    await tester.enterText(campi.at(4), 'casa2026ok');
    await tester.tap(find.textContaining('Acconsento al trattamento'));
    await tester.pump();
    await tester.tap(find.text('Crea account'));
    await attendi(tester);

    expect(state.repo.cliente?['email'], 'giulia@example.com');
    expect(state.repo.preferito(primo), isTrue);
    expect(find.text('Il tuo account'), findsNothing);
    await chiudi(tester);
  });

  testWidgets('"La casa che cerchi": salvata e con gli immobili adatti', (tester) async {
    await avvia(tester);
    await tester.runAsync(() => state.repo.clienteRegistra({'nome': 'Marco Blu', 'email': 'marco@example.com', 'password': 'prova1234'}));
    await vai(tester, '/account/ricerche');
    await tester.tap(find.text('Crea la tua ricerca').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('La casa che cerchi'), findsWidgets);
    final nome = find.byType(EditableText).at(1); // il primo è la ricerca nell'intestazione
    await tester.enterText(nome, 'Casa in vendita');
    // il modulo è lungo (pulsante in fondo alla finestra): si preme il pulsante direttamente
    final salva = tester.widget<VButton>(find.widgetWithText(VButton, 'Salva la ricerca'));
    await tester.runAsync(() => salva.onAsync!());
    await tester.pump(const Duration(milliseconds: 400));
    await attendi(tester);

    final ricerche = state.repo.ricercheDi(state.repo.cliente!);
    expect(ricerche.single['nome'], 'Casa in vendita');
    expect(jsonOf(ricerche.single['criteri'])['contratto'], 'Vendita');
    expect(find.textContaining('immobili disponibili corrispondono'), findsOneWidget);
    await chiudi(tester);
  });

  testWidgets("proposta dal gestionale: l'email finisce in «Da inviare»", (tester) async {
    await avvia(tester, admin: true);
    await tester.runAsync(() async {
      await state.repo.clienteRegistra({'nome': 'Sara Gialli', 'email': 'sara@example.com', 'password': 'prova1234', 'consenso': true});
      await state.repo.clienteEsci();
    });
    final id = state.repo.items.firstWhere((i) => str(i['statoAnnuncio']) == 'Disponibile')['id'];
    await vai(tester, '/admin/posta/nuova?immobili=$id');
    expect(find.textContaining('Chi ha dato il consenso (1)'), findsOneWidget);
    await tester.ensureVisible(find.textContaining('Prepara le email'));
    await tester.pump();
    await tester.tap(find.textContaining('Prepara le email'));
    await attendi(tester);
    final e = state.repo.posta().firstWhere((p) => p['tipo'] == 'proposta');
    expect(e['a'], 'sara@example.com');
    expect(str(e['testo']), contains('/scheda/$id'));
    await chiudi(tester);
  });
}
