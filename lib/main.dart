import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/theme.dart';
import 'data/repository.dart';
import 'data/store.dart';
import 'services/auth.dart';
import 'state/app_state.dart';
import 'app_config.dart';
import 'ui/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'it';
  await initializeDateFormatting('it');
  final repo = await Repo.open();
  final auth = await AuthService.open(await LocalStore.open('${AppConfig.dbName}.auth'));
  runApp(VetrinaApp(state: AppState(repo, auth)));
}

class VetrinaApp extends StatefulWidget {
  final AppState state;
  const VetrinaApp({super.key, required this.state});
  @override
  State<VetrinaApp> createState() => _VetrinaAppState();
}

class _VetrinaAppState extends State<VetrinaApp> {
  late final router = buildRouter(widget.state);

  @override
  Widget build(BuildContext context) {
    return App(
      state: widget.state,
      child: Builder(builder: (context) {
        final s = App.of(context);
        final set = s.settings;
        return VT(
          theme: s.theme,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: '${set['nome'] ?? ''}${(set['slogan'] ?? '').toString().isNotEmpty ? ' · ${set['slogan']}' : ''}',
            theme: s.theme.material(),
            routerConfig: router,
            locale: const Locale('it'),
            supportedLocales: const [Locale('it')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            builder: (context, child) => VT(theme: s.theme, child: child!),
          ),
        );
      }),
    );
  }
}
