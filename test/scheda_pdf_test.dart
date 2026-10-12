// La scheda PDF per la vetrina si genera per ogni immobile ed è una sola pagina A4.
// Con --dart-define=SALVA_PDF=percorso salva la scheda del primo immobile per controllarla a occhio.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leone_immobiliare/app_config.dart';
import 'package:leone_immobiliare/data/repository.dart';
import 'package:leone_immobiliare/data/store_factory.dart';
import 'package:leone_immobiliare/ui/admin/scheda_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scheda PDF di ogni immobile', () async {
    await dbFactory.deleteDatabase(AppConfig.dbName);
    final repo = await Repo.open();
    expect(repo.items, isNotEmpty);
    for (final i in repo.items) {
      final pdf = await schedaPdf(repo, i);
      final testo = String.fromCharCodes(pdf.take(2000));
      expect(testo.startsWith('%PDF'), isTrue, reason: '${i['titolo']}');
      expect(RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(pdf)).length, 1, reason: 'una sola pagina: ${i['titolo']}');
    }
    const salva = String.fromEnvironment('SALVA_PDF');
    if (salva.isNotEmpty) {
      final i = repo.items.firstWhere((x) => x['prezzoPrecedente'] != null, orElse: () => repo.items.first);
      File(salva).writeAsBytesSync(await schedaPdf(repo, i));
    }
  });
}
