/// Archivio locale persistente (IndexedDB nel browser, tramite sembast).
library;

import 'package:sembast/sembast.dart';

import 'store_factory.dart';

class LocalStore {
  final Database db;
  LocalStore._(this.db);

  static final kv = StoreRef<String, Object?>('kv');
  static StoreRef<String, Map<String, Object?>> coll(String name) => StoreRef<String, Map<String, Object?>>(name);

  static Future<LocalStore> open(String name) async => LocalStore._(await dbFactory.openDatabase(name));

  Future<Object?> get(String key) => kv.record(key).get(db);
  Future<void> set(String key, Object? value) => kv.record(key).put(db, value);
  Future<void> remove(String key) => kv.record(key).delete(db);

  Future<List<Map<String, dynamic>>> all(String store) async {
    final recs = await coll(store).find(db);
    return [for (final r in recs) Map<String, dynamic>.from(_deep(r.value) as Map)];
  }

  Future<void> put(String store, String id, Map<String, dynamic> value) => coll(store).record(id).put(db, value);
  Future<void> delete(String store, String id) => coll(store).record(id).delete(db);
  Future<void> clear(String store) => coll(store).delete(db);

  /// Esegue più scritture in un'unica transazione (tutto o niente).
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) => db.transaction(action);

  /// I valori letti da sembast sono immutabili: li copiamo in strutture modificabili.
  static Object? _deep(Object? v) {
    if (v is Map) return {for (final e in v.entries) e.key.toString(): _deep(e.value)};
    if (v is List) return [for (final x in v) _deep(x)];
    return v;
  }

  static Object? mutable(Object? v) => _deep(v);
}
