// Genera il logo con sfondo trasparente e le icone del sito partendo da grafica/logo_originale.jpg
// (logo su fondo bianco). Uso: dart run tool/genera_logo.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const blu = (r: 3, g: 137, b: 238);
const nero = (r: 0, g: 0, b: 0);

void main() {
  final src = img.decodeJpg(File('grafica/logo_originale.jpg').readAsBytesSync())!;

  // 1) Colore del logo: media dei pixel azzurri pieni
  var n = 0, sr = 0, sg = 0, sb = 0;
  for (final p in src) {
    if (p.b > 200 && p.r < 60 && p.g > 100 && p.g < 170) {
      n++;
      sr += p.r.toInt();
      sg += p.g.toInt();
      sb += p.b.toInt();
    }
  }
  if (n > 0) stdout.writeln('Azzurro del logo: #${[sr ~/ n, sg ~/ n, sb ~/ n].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}');

  // 2) "Colore in trasparenza": il bianco diventa trasparente, i bordi restano morbidi
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  var x0 = src.width, y0 = src.height, x1 = 0, y1 = 0;
  for (final p in src) {
    final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
    var a = [255 - r, 255 - g, 255 - b].reduce(math.max) / 255;
    if (a < .06) a = 0;
    if (a == 0) {
      out.setPixelRgba(p.x, p.y, 0, 0, 0, 0);
      continue;
    }
    int un(double c) => (255 - (255 - c) / a).round().clamp(0, 255);
    out.setPixelRgba(p.x, p.y, un(r), un(g), un(b), (a * 255).round());
    if (a > .25) {
      x0 = math.min(x0, p.x);
      y0 = math.min(y0, p.y);
      x1 = math.max(x1, p.x);
      y1 = math.max(y1, p.y);
    }
  }
  const m = 6;
  final crop = img.copyCrop(out, x: x0 - m, y: y0 - m, width: x1 - x0 + 2 * m, height: y1 - y0 + 2 * m);
  final logo = img.copyResize(crop, width: 1200, interpolation: img.Interpolation.average);
  File('assets/logo.png').writeAsBytesSync(img.encodePng(logo, level: 9));
  stdout.writeln('assets/logo.png ${logo.width}x${logo.height}');

  // 3) Icone: tetto e "L" del logo (nero) con la "e" azzurra, su fondo bianco
  final e = img.copyCrop(crop, x: 583 - x0 + m - 4, y: 580 - y0 + m - 4, width: 255, height: 272);
  for (final (nome, lato, scala) in [
    ('web/icons/Icon-512.png', 512, 1.0),
    ('web/icons/Icon-192.png', 192, 1.0),
    ('web/icons/Icon-maskable-512.png', 512, .78),
    ('web/icons/Icon-maskable-192.png', 192, .78),
    ('web/favicon.png', 32, 1.12),
  ]) {
    File(nome).writeAsBytesSync(img.encodePng(_icona(lato, scala, e)));
    stdout.writeln(nome);
  }
}

/// Disegna il marchio su una tela 512 (moltiplicata x4 per avere bordi morbidi) e la riduce a [lato].
img.Image _icona(int lato, double scala, img.Image e) {
  const k = 4, base = 512;
  final c = img.Image(width: base * k, height: base * k, numChannels: 4);
  img.fill(c, color: img.ColorRgba8(255, 255, 255, 255));
  img.Point pt(double x, double y) => img.Point(((x - 256) * scala + 256) * k, ((y - 256) * scala + 256) * k);
  final black = img.ColorRgba8(nero.r, nero.g, nero.b, 255);
  // tetto: cuneo sottile alle estremità e spesso al colmo, come nel logo
  img.fillPolygon(c, vertices: [pt(30, 318), pt(256, 112), pt(482, 318), pt(256, 164)], color: black);
  // la "L" a comignolo
  img.fillPolygon(c, vertices: [pt(118, 112), pt(162, 112), pt(162, 392), pt(236, 392), pt(236, 436), pt(118, 436)], color: black);
  // la "e" azzurra presa dal logo
  final eh = (178 * scala * k).round();
  final es = img.copyResize(e, height: eh, interpolation: img.Interpolation.cubic);
  final ex = (((250 - 256) * scala + 256) * k).round(), ey = (((438 - 256) * scala + 256) * k).round() - eh;
  img.compositeImage(c, es, dstX: ex, dstY: ey);
  return img.copyResize(c, width: lato, height: lato, interpolation: img.Interpolation.average);
}
