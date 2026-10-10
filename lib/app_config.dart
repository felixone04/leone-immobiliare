import 'data/preset.dart';
import 'data/presets/immobiliare.dart';

/// Configurazione di QUESTA app (l'unico file che cambia tra i progetti).
class AppConfig {
  /// Tipologia dell'attività: campi, filtri e schede del catalogo.
  static final Preset preset = presetImmobiliare;

  /// Nome dell'archivio locale nel browser (dati separati per ogni app).
  static const dbName = 'leone_immobiliare.db';

  /// Contenuti iniziali del sito.
  static const seedAsset = 'assets/data/seed.json';

  /// Prefisso dei file di backup.
  static const backupName = 'leone-immobiliare';
}
