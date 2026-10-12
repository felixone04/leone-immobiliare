/// Stato condiviso dell'app: dati, accesso all'area riservata, notifiche.
library;

import 'package:flutter/widgets.dart';

import '../core/theme.dart';
import '../core/util.dart';
import '../data/catalog.dart';
import '../data/repository.dart';
import '../services/auth.dart';

class Toast {
  final int id;
  final String msg;
  final bool err;
  Toast(this.id, this.msg, this.err);
}

class AppState extends ChangeNotifier {
  final Repo repo;
  final AuthService auth;
  AppState(this.repo, this.auth) {
    repo.addListener(_onData);
    auth.addListener(notifyListeners);
    _theme = VTheme.from(repo.settings);
  }

  late VTheme _theme;
  VTheme get theme => _theme;

  void _onData() {
    _theme = VTheme.from(repo.settings);
    notifyListeners();
  }

  Catalog get cat => Catalog(repo.schema, repo.items);
  Json get settings => repo.settings;
  bool modulo(String k) => repo.modulo(k);

  /// Banner dei cookie riaperto dall'utente ("Preferenze cookie")
  final cookieBanner = ValueNotifier<bool>(false);

  /* ---------- Notifiche ---------- */
  final toasts = ValueNotifier<List<Toast>>([]);
  var _tid = 0;

  void toast(String msg, {bool err = false}) {
    final t = Toast(_tid++, msg, err);
    toasts.value = [...toasts.value, t];
    Future<void>.delayed(Duration(milliseconds: err ? 5400 : 3200), () {
      toasts.value = toasts.value.where((x) => x.id != t.id).toList();
    });
  }

  /// Esegue un'azione mostrando l'errore come notifica. Restituisce null se fallisce.
  Future<T?> run<T>(Future<T> Function() fn) async {
    auth.tocca();
    try {
      return await fn();
    } on AppError catch (e) {
      toast(e.message, err: true);
    } catch (e) {
      toast('Si è verificato un errore: $e', err: true);
    }
    return null;
  }

  /* ---------- Voci "per te" del menu e del piè di pagina: (percorso, icona, etichetta) ---------- */
  List<(String, String, String)> get vociClienti => [
        ('account/preferiti', 'heart', 'I miei preferiti'),
        ('account/ricerche', 'bookmark', 'Ricerche salvate'),
        if (modulo('recensioni')) ('recensioni', 'star', 'Recensioni'),
      ];

  String get slugPrivacy => str(repo.pages.where((p) => p['tipo'] == 'privacy').firstOrNull?['slug']).isEmpty
      ? 'privacy'
      : str(repo.pages.firstWhere((p) => p['tipo'] == 'privacy')['slug']);
}

/// Accesso allo stato da qualsiasi widget: `App.of(context)` (si ricostruisce ai cambiamenti)
class App extends InheritedNotifier<AppState> {
  const App({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<App>()!.notifier!;

  /// Senza dipendenza (per gli handler degli eventi).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<App>()!.notifier!;
}
