import 'dart:convert';
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

/// Apre un'immagine PNG in una nuova finestra e avvia la stampa.
void printImage(Uint8List png, String title) {
  final safeTitle = const HtmlEscape().convert(title);
  final html = '<!doctype html><html lang="it"><head><meta charset="utf-8"><title>$safeTitle</title>'
      '<style>body{margin:0;display:grid;place-items:center;min-height:100vh}img{width:17cm;max-width:100%}</style></head>'
      '<body><img src="data:image/png;base64,${base64Encode(png)}" alt=""><script>addEventListener("load",()=>{print()})</script></body></html>';
  final blob = web.Blob([html.toJS].toJS, web.BlobPropertyBag(type: 'text/html'));
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}
