/// Caricamento immagini: scelta dei file, verifica del formato reale, ridimensionamento e
/// ricodifica (elimina eventuali contenuti nascosti nei file), salvataggio nell'archivio locale.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../../../core/util.dart';
import '../../../data/repository.dart';

const _maxMb = 8;

Future<List<PlatformFile>> pickImageFiles({bool multiple = false}) async {
  const ext = ['jpg', 'jpeg', 'png', 'webp', 'gif'];
  if (multiple) return FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ext);
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ext);
  return f == null ? const [] : [f];
}

/// Ridimensiona e salva un'immagine; restituisce il riferimento "media:ID".
Future<String> uploadImage(Repo repo, PlatformFile f, {int max = 1800, bool png = false}) async {
  if ((f.lengthSync() ?? 0) > _maxMb * 1024 * 1024) throw AppError('"${f.name}": file troppo grande (max $_maxMb MB)');
  final bytes = await f.readAsBytes();
  if (bytes.length > _maxMb * 1024 * 1024) throw AppError('"${f.name}": file troppo grande (max $_maxMb MB)');
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw AppError('"${f.name}": formato non supportato (usa JPG, PNG, WEBP o GIF)');
  var im = decoded;
  final lato = im.width > im.height ? im.width : im.height;
  if (lato > max) {
    im = im.width >= im.height ? img.copyResize(im, width: max, interpolation: img.Interpolation.average) : img.copyResize(im, height: max, interpolation: img.Interpolation.average);
  }
  final keepPng = png && im.hasAlpha;
  final Uint8List out = keepPng ? img.encodePng(im, level: 7) : img.encodeJpg(im.hasAlpha ? _suBianco(im) : im, quality: 85);
  return repo.saveMedia(out, keepPng ? 'image/png' : 'image/jpeg');
}

/// Le immagini trasparenti salvate in JPG vengono messe su fondo bianco.
img.Image _suBianco(img.Image src) {
  final bg = img.Image(width: src.width, height: src.height);
  img.fill(bg, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(bg, src);
  return bg;
}
