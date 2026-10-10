/// Backup: scarica / ripristina tutti i contenuti, pulizia delle immagini non usate.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app_config.dart';
import '../../../core/platform/browser.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../state/app_state.dart';
import '../../dialogs.dart';
import '../../kit.dart';
import '../admin_common.dart';

class BackupAdmin extends StatelessWidget {
  const BackupAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    Widget box(String icon, String title, String text, Widget action) => CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            BoxTitle(title, icon: icon),
            Text(text, style: t.text(color: t.muted)),
            const Gap(16),
            Align(alignment: Alignment.centerLeft, child: action),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AdminHead('Backup', sub: 'Scarica una copia di sicurezza di tutti i contenuti o ripristinane una.'),
      AutoGrid(minWidth: 300, gap: 20, equalHeight: false, children: [
        box(
          'download',
          'Scarica backup',
          'Un file .json con impostazioni, catalogo, pagine, widget e le foto caricate. Conservalo in un posto sicuro: i dati del sito restano solo su questo computer.',
          VButton('Scarica backup', icon: 'download', kind: BtnKind.primary, onPressed: () {
            final json = const JsonEncoder.withIndent(' ').convert(s.repo.exportFull());
            downloadBytes(utf8.encode(json), 'backup-${AppConfig.backupName}-${oggi()}.json', 'application/json');
          }),
        ),
        box(
          'upload',
          'Ripristina',
          'Sostituisce tutti i contenuti attuali con quelli del file di backup (anche quelli scaricati dalla versione web del sito).',
          VButton('Scegli file di backup', icon: 'upload', onAsync: () async {
            final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['json']);
            if (f == null) return;
            Json data;
            try {
              data = jsonDecode(utf8.decode(await f.readAsBytes())) as Json;
            } catch (_) {
              s.toast('Il file non è un backup valido', err: true);
              return;
            }
            if (!context.mounted || !await confirmDialog(context, 'Sostituire tutti i contenuti del sito con quelli del backup?')) return;
            if (await s.run(() async {
                  await s.repo.importSite(data);
                  return true;
                }) ==
                true) {
              s.toast('Backup ripristinato');
            }
          }),
        ),
        box(
          'trash',
          'Pulizia foto',
          'Elimina le foto caricate che non sono più usate da nessun contenuto, per liberare spazio.',
          VButton('Elimina foto non usate', onAsync: () async {
            if (!await confirmDialog(context, "Eliminare le foto non utilizzate? L'operazione non si può annullare.")) return;
            final n = await s.run(() => s.repo.cleanupMedia());
            if (n != null) s.toast('$n foto eliminate');
          }),
        ),
      ]),
    ]);
  }
}
