/// Scheda A4 in PDF da esporre in vetrina: foto, prezzo, caratteristiche, descrizione,
/// contatti dell'agenzia e QR code che porta all'annuncio sul sito.
library;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/platform/browser.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/catalog.dart';
import '../../data/repository.dart';

/// Crea il PDF e lo apre in una nuova scheda del browser, pronto da stampare o salvare.
Future<void> apriSchedaPdf(Repo repo, Json item) async {
  final bytes = await schedaPdf(repo, item);
  openBytes(bytes, 'application/pdf');
}

Future<Uint8List> schedaPdf(Repo repo, Json item) async {
  final cat = Catalog(repo.schema, repo.items);
  final set = repo.settings;
  Future<pw.Font> font(String f) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$f.ttf'));
  final testo = await font('Inter-400'), medio = await font('Inter-600'), grassetto = await font('Inter-700'), titoli = await font('Arimo-700'), caps = await font('Jost-500');

  Future<pw.ImageProvider?> immagine(String src) async {
    try {
      if (src.startsWith('assets/')) return pw.MemoryImage((await rootBundle.load(src)).buffer.asUint8List());
      if (src.startsWith('media:')) {
        final b = repo.media[src.substring(6)];
        return b == null ? null : pw.MemoryImage(b);
      }
    } catch (_) {}
    return null;
  }

  final foto = <pw.ImageProvider>[];
  for (final f in cat.foto(item).take(4)) {
    final i = await immagine(f);
    if (i != null) foto.add(i);
  }
  final logo = await immagine(safeSrc(set['logo']));

  final blu = PdfColor.fromInt(VTheme.leoneBlu.toARGB32()), nero = PdfColor.fromInt(VTheme.leoneNero.toARGB32());
  const grigio = PdfColor.fromInt(0xFF6B7280), linea = PdfColor.fromInt(0xFFE3E7EC), rosso = PdfColor.fromInt(0xFFB42318);
  pw.TextStyle st(double size, {pw.Font? f, PdfColor color = const PdfColor.fromInt(0xFF0B0D10), double? spacing}) =>
      pw.TextStyle(font: f ?? testo, fontSize: size, color: color, letterSpacing: spacing, lineSpacing: 2);

  final contratto = str(item['contratto']);
  final prezzoPrima = cat.prezzoPieno(item);
  final etichette = cat.etichette(item);
  final principali = [for (final p in repo.schema.scheda.principali) (p.label, cat.fmt(item, p.campo))].where((x) => x.$2.isNotEmpty).toList();
  final dettagli = [
    for (final k in ['tipologia', 'stato', 'riscaldamento', 'arredato', 'parcheggio', 'spese', 'anno'])
      if (repo.schema.campo(k) case final c? when !isEmptyValue(item[k])) (c.label, cat.fmt(item, k)),
    if (strList(item['spazioEsterno']).isNotEmpty) ('Spazi esterni', strList(item['spazioEsterno']).join(', ')),
    if (strList(item['dotazioni']).isNotEmpty) ('Dotazioni', strList(item['dotazioni']).take(6).join(', ')),
  ];
  // testo semplice: senza segni di formattazione né righe vuote
  var descr = str(item['descrizione']).replaceAll(RegExp(r'[*#]'), '').split('\n').map((r) => r.replaceFirst(RegExp(r'^- '), '• ').trim()).where((r) => r.isNotEmpty).join('\n');
  if (descr.length > 520) descr = '${descr.substring(0, descr.lastIndexOf(' ', 500))}…';
  final link = repo.linkSito('/scheda/${item['id']}');
  final contatti = [str(set['telefono']), str(set['email']), str(set['indirizzo'])].where((x) => x.isNotEmpty).toList();

  pw.Widget fotoBox(pw.ImageProvider i, double h) => pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.SizedBox(height: h, width: double.infinity, child: pw.Image(i, fit: pw.BoxFit.cover)),
      );
  pw.Widget etichetta(String e) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        margin: const pw.EdgeInsets.only(right: 5),
        decoration: pw.BoxDecoration(color: e == 'Esclusiva' ? nero : (e == 'Prezzo ribassato' ? rosso : blu), borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Text(e.toUpperCase(), style: st(8, f: grassetto, color: PdfColors.white, spacing: .5)),
      );

  final doc = pw.Document(title: str(item['titolo']), author: str(set['nome']));
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(30),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      // intestazione: logo e contratto
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        if (logo != null) pw.SizedBox(height: 50, width: 150, child: pw.Image(logo, fit: pw.BoxFit.contain, alignment: pw.Alignment.centerLeft)) else pw.Text(str(set['nome']), style: st(20, f: titoli)),
        pw.Spacer(),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          if (contratto.isNotEmpty) pw.Text(contratto == 'Affitto' ? 'IN AFFITTO' : 'IN VENDITA', style: st(18, f: caps, color: blu, spacing: 3)),
          if (str(item['rif']).isNotEmpty) pw.Text('Rif. ${item['rif']}', style: st(9, color: grigio)),
        ]),
      ]),
      pw.Container(height: 3, color: blu, margin: const pw.EdgeInsets.only(top: 10, bottom: 14)),
      // foto
      if (foto.isNotEmpty) fotoBox(foto.first, foto.length > 1 ? 225 : 300),
      if (foto.length > 1)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(children: [
            for (var k = 1; k < 4; k++) ...[
              if (k > 1) pw.SizedBox(width: 6),
              pw.Expanded(child: k < foto.length ? fotoBox(foto[k], 74) : pw.SizedBox()),
            ],
          ]),
        ),
      pw.SizedBox(height: 14),
      // titolo, luogo, prezzo
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (etichette.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Row(children: [for (final e in etichette) etichetta(e)])),
            pw.Text(str(item['titolo']), style: st(19, f: titoli), maxLines: 2),
            if (cat.luogo(item).isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 3), child: pw.Text(cat.luogo(item), style: st(10.5, color: grigio))),
          ]),
        ),
        pw.SizedBox(width: 16),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          if (prezzoPrima != null) pw.Text(prezzoPrima, style: st(11, color: grigio).copyWith(decoration: pw.TextDecoration.lineThrough)),
          pw.Text(cat.prezzo(item), style: st(24, f: titoli, color: prezzoPrima != null ? rosso : blu)),
        ]),
      ]),
      // caratteristiche principali
      if (principali.isNotEmpty)
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.symmetric(vertical: 9),
          decoration: const pw.BoxDecoration(border: pw.Border.symmetric(horizontal: pw.BorderSide(color: linea))),
          child: pw.Row(children: [
            for (final (l, v) in principali.take(6))
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Text(v, style: st(12, f: grassetto), textAlign: pw.TextAlign.center),
                  pw.Text(l.toUpperCase(), style: st(7, f: caps, color: grigio, spacing: 1), textAlign: pw.TextAlign.center),
                ]),
              ),
          ]),
        ),
      pw.SizedBox(height: 12),
      // descrizione e dettagli
      pw.Expanded(
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (descr.isNotEmpty) ...[
                pw.Text('DESCRIZIONE', style: st(8, f: caps, color: blu, spacing: 1.5)),
                pw.SizedBox(height: 4),
                pw.Text(descr, style: st(9.2, color: const PdfColor.fromInt(0xFF3A4049)), maxLines: 11, overflow: pw.TextOverflow.clip),
              ],
            ]),
          ),
          pw.SizedBox(width: 18),
          pw.Expanded(
            flex: 2,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('DETTAGLI', style: st(8, f: caps, color: blu, spacing: 1.5)),
              pw.SizedBox(height: 4),
              for (final (l, v) in dettagli)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2.5),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.SizedBox(width: 84, child: pw.Text(l, style: st(8.5, color: grigio))),
                    pw.Expanded(child: pw.Text(v, style: st(8.5, f: medio))),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
      // contatti e QR code
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.fromLTRB(18, 14, 14, 14),
        decoration: pw.BoxDecoration(color: nero, border: pw.Border(top: pw.BorderSide(color: blu, width: 4))),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(str(set['nome']), style: st(14, f: titoli, color: PdfColors.white)),
              pw.SizedBox(height: 4),
              for (final c in contatti) pw.Text(c, style: st(9.5, color: const PdfColor.fromInt(0xFFC5CAD1))),
              pw.SizedBox(height: 6),
              pw.Text('Inquadra il codice per tutte le foto e la mappa', style: st(8.5, f: medio, color: blu)),
            ]),
          ),
          pw.Container(
            color: PdfColors.white,
            padding: const pw.EdgeInsets.all(5),
            child: pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: link, width: 78, height: 78, drawText: false),
          ),
        ]),
      ),
    ]),
  ));
  return doc.save();
}
