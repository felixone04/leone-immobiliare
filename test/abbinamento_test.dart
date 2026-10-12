// Regole di abbinamento, avvisi ai clienti, posta in uscita, etichette e statistiche (senza interfaccia).
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:leone_immobiliare/app_config.dart';
import 'package:leone_immobiliare/core/util.dart';
import 'package:leone_immobiliare/data/abbinamento.dart';
import 'package:leone_immobiliare/data/catalog.dart';
import 'package:leone_immobiliare/data/repository.dart';
import 'package:leone_immobiliare/data/store_factory.dart';

Json casa({String contratto = 'Vendita', num prezzo = 300000, num locali = 3, num mq = 90, List<String> dotazioni = const []}) => {
      'titolo': 'Trilocale di prova',
      'contratto': contratto,
      'tipologia': 'Appartamento',
      'prezzo': prezzo,
      'mq': mq,
      'locali': locali,
      'bagni': 1,
      'citta': 'Milano',
      'statoAnnuncio': 'Disponibile',
      'dotazioni': dotazioni,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('regole di abbinamento', () {
    test('il contratto deve coincidere', () {
      expect(abbina({'contratto': 'Affitto'}, casa()), isNull);
      expect(abbina({'contratto': 'Vendita'}, casa()), isNotNull);
    });

    test('prezzo fino al 10% sopra il budget', () {
      expect(abbina({'contratto': 'Vendita', 'budget': 280000}, casa(prezzo: 308000))!.sopraBudget, isTrue); // +10%
      expect(abbina({'contratto': 'Vendita', 'budget': 280000}, casa(prezzo: 308001)), isNull); // oltre il 10%
      expect(abbina({'contratto': 'Vendita', 'budget': 300000}, casa(prezzo: 290000))!.sopraBudget, isFalse);
    });

    test('almeno il 70% dei requisiti', () {
      // 3 requisiti, 2 soddisfatti = 67%: non basta
      expect(abbina({'contratto': 'Vendita', 'localiMin': 3, 'mqMin': 80, 'bagniMin': 2}, casa()), isNull);
      // 10 requisiti, 7 soddisfatti = 70%: basta, e dice cosa manca
      final a = abbina({
        'contratto': 'Vendita',
        'localiMin': 3,
        'mqMin': 80,
        'citta': ['Milano'],
        'tipologie': ['Appartamento'],
        'dotazioni': ['Ascensore', 'Cantina', 'Balcone', 'Piscina', 'Allarme', 'Camino'],
      }, casa(dotazioni: ['Ascensore', 'Cantina', 'Balcone']));
      expect(a, isNotNull);
      expect(a!.percentuale, 70);
      expect(a.mancano, ['piscina', 'allarme', 'camino']);
    });
  });

  group('archivio', () {
    late Repo repo;
    setUp(() async {
      Intl.defaultLocale = 'it';
      await initializeDateFormatting('it');
      await dbFactory.deleteDatabase(AppConfig.dbName);
      repo = await Repo.open();
    });

    test('un immobile che diventa disponibile avvisa il cliente una sola volta', () async {
      await repo.clienteRegistra({'nome': 'Anna Verdi', 'email': 'anna@example.com', 'password': 'prova1234'});
      await repo.ricercaSalva({'contratto': 'Vendita', 'budget': 280000, 'localiMin': 3, 'citta': ['Milano']}, nome: 'Trilocale Milano');
      final primaPosta = repo.posta().length;

      final nuovo = await repo.saveItem(casa(prezzo: 300000)); // +7% sul budget: va bene
      final c = repo.cliente!;
      expect(repo.notificheNuove(c), 1);
      final email = repo.posta().first;
      expect(repo.posta().length, primaPosta + 1);
      expect(email['a'], 'anna@example.com');
      expect(email['tipo'], 'abbinamento');
      expect(str(email['testo']), contains('/scheda/${nuovo['id']}'));
      expect(str(email['testo']), contains('sopra il tuo budget'));

      // nuove modifiche, venduto e di nuovo disponibile: nessun doppio avviso
      await repo.saveItem({...nuovo, 'titolo': 'Trilocale luminoso'});
      await repo.saveItem({...repo.item(nuovo['id'] as String)!, 'statoAnnuncio': 'Venduto'});
      await repo.saveItem({...repo.item(nuovo['id'] as String)!, 'statoAnnuncio': 'Disponibile'});
      expect(repo.posta().length, primaPosta + 1);
      expect(repo.interessatiA(repo.item(nuovo['id'] as String)!).length, 1);
    });

    test('prezzo ribassato ed esclusiva diventano etichette', () async {
      final i = await repo.saveItem(casa(prezzo: 300000));
      final rib = await repo.saveItem({...i, 'prezzo': 280000, 'esclusiva': true});
      final cat = Catalog(repo.schema, repo.items);
      expect(rib['prezzoPrecedente'], 300000);
      expect(cat.etichette(rib), containsAll(['Esclusiva', 'Nuovo', 'Prezzo ribassato']));
      final su = await repo.saveItem({...rib, 'prezzo': 320000});
      expect(su['prezzoPrecedente'], isNull);
      expect(cat.etichette({...su, 'statoAnnuncio': 'Venduto'}), isEmpty);
    });

    test("un messaggio dal sito prepara l'email per l'agenzia", () async {
      final i = repo.items.first;
      await repo.richiestaCrea({'nome': 'Luca Bianchi', 'email': 'luca@example.com', 'messaggio': 'Posso visitarla sabato?', 'immobile': i['id']});
      final e = repo.posta().first;
      expect(e['tipo'], 'messaggio');
      expect(e['a'], repo.emailAgenzia);
      expect(str(e['oggetto']), contains(str(i['titolo'])));
      expect(repo.contatori()['messaggi'], 1);
      expect(repo.contatori()['posta'], greaterThan(0));
    });

    test('le proposte vanno solo a chi ha dato il consenso', () async {
      await repo.clienteRegistra({'nome': 'Con Consenso', 'email': 'si@example.com', 'password': 'prova1234', 'consenso': true});
      await repo.clienteRegistra({'nome': 'Senza Consenso', 'email': 'no@example.com', 'password': 'prova1234', 'consenso': false});
      final n = await repo.propostaInvia(immobili: [repo.items.first['id'] as String], oggetto: 'Novità', messaggio: 'Ecco un immobile per te');
      expect(n, 1);
      expect(repo.posta().first['a'], 'si@example.com');
    });

    test('accesso, preferiti e statistiche', () async {
      await repo.clienteRegistra({'nome': 'Paolo Neri', 'email': 'paolo@example.com', 'password': 'prova1234'});
      await repo.clienteEsci();
      expect(() => repo.clienteAccedi('paolo@example.com', 'sbagliata1'), throwsA(isA<AppError>()));
      await repo.clienteAccedi('PAOLO@example.com', 'prova1234');
      final id = repo.items.first['id'] as String;
      expect(await repo.preferitoCambia(id), isTrue);
      expect(repo.preferitiCount(id), 1);
      await repo.registraVista(id);
      await repo.registraVista(id);
      final st = repo.statistiche().firstWhere((r) => r['id'] == id);
      expect(st['viste'], 2);
      expect(st['preferiti'], 1);
    });
  });
}
