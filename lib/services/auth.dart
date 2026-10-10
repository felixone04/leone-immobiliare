/// Accesso all'area riservata.
///  - Password salvata solo come hash PBKDF2-HMAC-SHA256 con sale casuale (mai in chiaro).
///  - Massimo 8 tentativi falliti in 15 minuti (il blocco resta anche ricaricando la pagina).
///  - La sessione scade dopo 30 minuti di inattività ed è solo in memoria: chiudendo la scheda si esce.
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../core/util.dart';
import '../data/store.dart';

class AuthService extends ChangeNotifier {
  final LocalStore _store;
  AuthService(this._store);

  static const _iterazioni = 210000;
  static const _maxTentativi = 8;
  static const _finestra = Duration(minutes: 15);
  static const _scadenza = Duration(minutes: 30);

  String? _utente;
  DateTime _ultimaAttivita = DateTime.fromMillisecondsSinceEpoch(0);
  Json? _account;

  static Future<AuthService> open(LocalStore store) async {
    final a = AuthService(store);
    a._account = jsonOf(LocalStore.mutable(await store.get('auth')));
    if (a._account!.isEmpty) a._account = null;
    return a;
  }

  bool get configurato => _account != null;
  String? get utente => isAdmin ? _utente : null;

  bool get isAdmin {
    if (_utente == null) return false;
    if (DateTime.now().difference(_ultimaAttivita) > _scadenza) {
      _utente = null;
      return false;
    }
    return true;
  }

  /// Da chiamare a ogni azione nell'area riservata: rinnova la sessione.
  void tocca() {
    if (isAdmin) _ultimaAttivita = DateTime.now();
  }

  /// Primo avvio: crea l'account amministratore.
  Future<void> crea(String username, String password) async {
    if (configurato) throw const AppError("L'account esiste già");
    final u = username.trim();
    if (!RegExp(r'^[a-zA-Z0-9._-]{3,40}$').hasMatch(u)) throw const AppError('Nome utente: da 3 a 40 caratteri tra lettere, numeri, punto, trattino');
    _controllaRobustezza(password);
    _account = {'username': u, ...await _hash(password), 'creato': nowMs()};
    await _store.set('auth', _account);
    _entra(u);
  }

  Future<void> login(String username, String password) async {
    final tentativi = await _tentativiRecenti();
    if (tentativi.length >= _maxTentativi) throw const AppError('Troppi tentativi. Riprova tra qualche minuto.');
    final a = _account;
    final ok = a != null && username.trim() == a['username'] && await _verifica(password, a);
    if (!ok) {
      await _store.set('tentativi', [...tentativi, nowMs()]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      throw const AppError('Nome utente o password non corretti');
    }
    await _store.set('tentativi', <int>[]);
    _entra(a['username'] as String);
  }

  void logout() {
    _utente = null;
    notifyListeners();
  }

  Future<void> cambiaPassword(String attuale, String nuova) async {
    final a = _account;
    if (a == null || !isAdmin) throw const AppError('Nessun account da modificare');
    if (!await _verifica(attuale, a)) throw const AppError('La password attuale non è corretta');
    _controllaRobustezza(nuova);
    _account = {...a, ...await _hash(nuova)};
    await _store.set('auth', _account);
  }

  /* ---------------- interni ---------------- */

  void _entra(String u) {
    _utente = u;
    _ultimaAttivita = DateTime.now();
    notifyListeners();
  }

  static void _controllaRobustezza(String p) {
    if (p.length < 10) throw const AppError('La password deve avere almeno 10 caratteri');
    if (!RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) throw const AppError('La password deve contenere lettere e numeri');
  }

  Future<List<int>> _tentativiRecenti() async {
    final limite = DateTime.now().subtract(_finestra).millisecondsSinceEpoch;
    final l = await _store.get('tentativi');
    return [for (final t in (l is List ? l : const [])) if (intOf(t) > limite) intOf(t)];
  }

  static Future<Json> _hash(String password) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final h = await _derive(password, salt, _iterazioni);
    return {'salt': base64Encode(salt), 'hash': base64Encode(h), 'iter': _iterazioni, 'alg': 'pbkdf2-sha256'};
  }

  static Future<List<int>> _derive(String password, List<int> salt, int iter) async {
    final algo = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iter, bits: 256);
    final key = await algo.deriveKeyFromPassword(password: password, nonce: salt);
    return key.extractBytes();
  }

  static Future<bool> _verifica(String password, Json a) async {
    final h = await _derive(password, base64Decode(str(a['salt'])), intOf(a['iter'], _iterazioni));
    final atteso = base64Decode(str(a['hash']));
    // confronto a tempo costante
    var diff = h.length ^ atteso.length;
    for (var i = 0; i < min(h.length, atteso.length); i++) {
      diff |= h[i] ^ atteso[i];
    }
    return diff == 0;
  }
}
