/// Messaggi: le richieste inviate dai visitatori con i moduli del sito.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../dialogs.dart';
import '../../forms_public.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';

const kStatiMsg = {'nuova': ('Nuovo', 'warn'), 'letta': ('Letto', 'muted'), 'risposta': ('Risposto', 'ok'), 'archiviata': ('Archiviato', 'muted')};

class MessaggiAdmin extends StatefulWidget {
  const MessaggiAdmin({super.key});
  @override
  State<MessaggiAdmin> createState() => _MessaggiAdminState();
}

class _MessaggiAdminState extends State<MessaggiAdmin> {
  var _f = 'attivi', _q = '';

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final q = norm(_q);
    final arr = s.repo.richElenco().where((m) {
      final okF = _f == 'attivi' ? m['stato'] != 'archiviata' : (_f.isEmpty || m['stato'] == _f);
      return okF && (q.isEmpty || norm([m['nome'], m['email'], m['telefono'], m['messaggio'], m['oggetto']].map(str).join(' ')).contains(q));
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AdminHead('Messaggi', sub: 'Le richieste inviate dai visitatori con i moduli del sito.'),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 170,
          child: VSelect<String>(value: _f, dense: true, items: const [('attivi', 'Da gestire'), ('', 'Tutti'), ('archiviata', 'Archiviati')], onChanged: (v) => setState(() => _f = v ?? '')),
        ),
        SizedBox(width: 340, child: VInput(hint: 'Cerca per nome, email, testo…', icon: 'search', dense: true, onChanged: (v) => setState(() => _q = v))),
      ]),
      const Gap(16),
      if (arr.isEmpty)
        const EmptyState(icon: 'mail', small: true, text: 'Nessun messaggio.')
      else
        for (final m in arr)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Hover(
              onTap: () => _apri(context, m),
              builder: (_, h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(
                    left: BorderSide(color: m['stato'] == 'nuova' ? VTheme.warn : (h ? t.primary : t.line), width: m['stato'] == 'nuova' ? 4 : 1),
                    top: BorderSide(color: h ? t.primary : t.line),
                    right: BorderSide(color: h ? t.primary : t.line),
                    bottom: BorderSide(color: h ? t.primary : t.line),
                  ),
                  borderRadius: t.rSm,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(str(m['nome']), style: t.text(weight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    statoPill(kStatiMsg, str(m['stato'])),
                    const Spacer(),
                    Text(quando(m['creato']), style: t.text(size: 13.1, color: t.muted)),
                  ]),
                  if (str(m['oggetto']).isNotEmpty) Text(str(m['oggetto']), style: t.text(size: 14.4, weight: FontWeight.w600)),
                  Text(str(m['messaggio']), maxLines: 2, overflow: TextOverflow.ellipsis, style: t.text(size: 14.4, color: t.muted)),
                ]),
              ),
            ),
          ),
    ]);
  }

  Future<void> _apri(BuildContext context, Json m) async {
    final s = App.read(context);
    if (m['stato'] == 'nuova') await s.repo.richStato(m['id'], 'letta');
    final risposta = 'Buongiorno ${str(m['nome']).split(' ').first}, grazie per averci scritto.\n\n';
    if (!context.mounted) return;
    await showVModal(context, 'Messaggio di ${m['nome']}', wide: true, (ctx) {
      final t = ctx.t;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Riep([('Ricevuto', quando(m['creato'])), ('Email', str(m['email'])), ('Telefono', str(m['telefono'])), ('Oggetto', str(m['oggetto']))]),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: t.bg, borderRadius: t.rSm),
          child: SelectableText(str(m['messaggio']), style: t.text()),
        ),
        Padding(padding: const EdgeInsets.only(top: 6, bottom: 10), child: Text('Rispondi', style: t.title(size: 15.2, color: t.ink2, weight: FontWeight.w700))),
        Wrap(spacing: 8, runSpacing: 8, children: contattiBtn(m, risposta, 'Re: ${str(m['oggetto']).isEmpty ? 'la tua richiesta' : m['oggetto']}')),
        const Gap(18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          VButton('Segna come risposto', icon: 'check', kind: BtnKind.primary, onAsync: () async {
            await s.repo.richStato(m['id'], 'risposta');
            if (ctx.mounted) Navigator.of(ctx).pop();
          }),
          VButton('Archivia', onAsync: () async {
            await s.repo.richStato(m['id'], 'archiviata');
            if (ctx.mounted) Navigator.of(ctx).pop();
          }),
          VButton('Elimina', icon: 'trash', kind: BtnKind.ghost, danger: true, onAsync: () async {
            if (!await confirmDialog(ctx, 'Eliminare definitivamente il messaggio?')) return;
            await s.repo.richElimina(m['id']);
            if (ctx.mounted) Navigator.of(ctx).pop();
          }),
        ]),
      ]);
    });
  }
}
