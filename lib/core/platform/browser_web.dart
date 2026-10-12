import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Scarica un file generato dall'app.
void downloadBytes(Uint8List bytes, String filename, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(a);
  a.click();
  a.remove();
  Future<void>.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
}

/// Apre un file generato dall'app in una nuova scheda (es. PDF da stampare).
void openBytes(Uint8List bytes, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  web.window.open(web.URL.createObjectURL(blob), '_blank');
}
