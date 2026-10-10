// Sviluppo con aggiornamento in tempo reale.
// Avvia l'app in Chrome e, a ogni file salvato in lib/ o assets/, la ricarica da sola
// (hot reload; se non basta, riavvio; se il compilatore si blocca, nuova sessione).
// Nel terminale: r = ricarica   R = riavvia   q = esci
//
// Uso:  C:\Users\Utente\flutter\bin\dart.bat run tool/live.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

late String _exe;
Process? _flutter;
String? _appId;
var _nextId = 1;
var _busy = false;
var _pending = false;
var _respawning = false;
var _quitting = false;
final _waiting = <int, Completer<Map<String, dynamic>>>{};

Future<void> main() async {
  // dart.exe si trova in <flutter>/bin/cache/dart-sdk/bin: risaliamo alla cartella di Flutter
  final flutterRoot = File(Platform.resolvedExecutable).parent.parent.parent.parent.parent;
  final sep = Platform.pathSeparator;
  _exe = '${flutterRoot.path}${sep}bin${sep}flutter${Platform.isWindows ? '.bat' : ''}';
  await _spawn();

  Timer? debounce;
  for (final dir in ['lib', 'assets']) {
    if (!Directory(dir).existsSync()) continue;
    Directory(dir).watch(recursive: true).listen((e) {
      if (e.path.endsWith('~') || e.path.contains('.tmp')) return;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 600), () => _reload(full: false));
    });
  }

  try {
    if (stdin.hasTerminal) stdin.lineMode = false;
    stdin.transform(utf8.decoder).listen((s) {
      for (final ch in s.split('')) {
        if (ch == 'r') _reload(full: false);
        if (ch == 'R') _reload(full: true);
        if (ch == 'q') _stop();
      }
    });
  } catch (_) {
    // senza terminale interattivo restano attivi gli aggiornamenti automatici
  }
}

Future<void> _spawn() async {
  _appId = null;
  stdout.writeln('Avvio dell\'app in Chrome (la compilazione richiede circa un minuto)…');
  final p = await Process.start(_exe, ['run', '-d', 'chrome', '--machine', '--web-port', '8091'], runInShell: true);
  _flutter = p;
  p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine);
  p.stderr.transform(utf8.decoder).listen(stderr.write);
  unawaited(p.exitCode.then((c) async {
    if (identical(p, _flutter) && !_respawning && !_quitting) {
      // finestra chiusa o compilatore bloccato: si riparte da soli
      stdout.writeln('Sessione terminata (codice $c): riavvio automatico tra 3 secondi…');
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!_respawning && !_quitting) await _spawn();
    }
  }));
}

Future<void> _respawn() async {
  _respawning = true;
  stdout.writeln('⟳ Nuova sessione di compilazione…');
  final old = _flutter;
  if (_appId != null) {
    try {
      await _send('app.stop', {'appId': _appId}).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
  old?.kill();
  await Future<void>.delayed(const Duration(seconds: 2));
  await _spawn();
  _respawning = false;
}

void _onLine(String line) {
  if (!line.startsWith('[{')) {
    if (line.trim().isNotEmpty) stdout.writeln(line);
    return;
  }
  List<dynamic> list;
  try {
    list = jsonDecode(line) as List<dynamic>;
  } catch (_) {
    stdout.writeln(line);
    return;
  }
  for (final m in list.cast<Map<String, dynamic>>()) {
    final id = m['id'];
    if (id is int && _waiting.containsKey(id)) {
      _waiting.remove(id)!.complete(m);
      continue;
    }
    final p = (m['params'] as Map?)?.cast<String, dynamic>() ?? {};
    switch (m['event']) {
      case 'app.start':
        _appId = p['appId'] as String?;
      case 'app.started':
        stdout.writeln('\n✔ App avviata in Chrome: ogni file salvato aggiorna la pagina da solo.\n');
      case 'app.log':
        stdout.writeln(p['log']);
      case 'app.progress':
        if (p['finished'] != true && p['message'] != null) stdout.writeln('… ${p['message']}');
      case 'daemon.logMessage':
        if (p['level'] == 'error') stderr.writeln(p['message']);
    }
  }
}

Future<Map<String, dynamic>> _send(String method, Map<String, dynamic> params) {
  final id = _nextId++;
  final c = Completer<Map<String, dynamic>>();
  _waiting[id] = c;
  _flutter!.stdin.writeln(jsonEncode([
    {'id': id, 'method': method, 'params': params}
  ]));
  return c.future;
}

Future<void> _reload({required bool full}) async {
  if (_appId == null || _respawning) return;
  if (_busy) {
    _pending = true;
    return;
  }
  _busy = true;
  final sw = Stopwatch()..start();
  Map<String, dynamic> r;
  try {
    r = await _send('app.restart', {'appId': _appId, 'fullRestart': full, 'pause': false, 'reason': 'manual'}).timeout(const Duration(minutes: 3));
  } catch (_) {
    r = {'error': 'timeout'};
  }
  final res = (r['result'] as Map?)?.cast<String, dynamic>();
  final ok = r['error'] == null && (res?['code'] ?? 0) == 0;
  _busy = false;
  if (ok) {
    stdout.writeln('↻ ${full ? 'Riavviata' : 'Aggiornata'} in ${sw.elapsedMilliseconds} ms');
  } else {
    final msg = '${r['error'] ?? res?['message'] ?? ''}';
    if (!full) return _reload(full: true);
    if (msg.contains('summary') || msg.contains('timeout') || msg.contains('Failed to recompile')) {
      await _respawn();
      return;
    }
    stderr.writeln('✖ Aggiornamento non riuscito: $msg (correggi l\'errore e salva di nuovo)');
  }
  if (_pending) {
    _pending = false;
    await _reload(full: false);
  }
}

Future<void> _stop() async {
  _quitting = true;
  if (_appId != null) await _send('app.stop', {'appId': _appId});
  _flutter?.kill();
  exit(0);
}
