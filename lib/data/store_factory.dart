// Nel browser i dati restano in IndexedDB; sulle altre piattaforme (test) in memoria.
export 'store_factory_memory.dart' if (dart.library.js_interop) 'store_factory_web.dart';
