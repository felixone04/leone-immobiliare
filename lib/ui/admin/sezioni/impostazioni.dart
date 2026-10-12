/// Impostazioni: identità, aspetto e tema, contatti, privacy, social, funzioni attive e password.
library;

import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/theme.dart';
import '../../../core/util.dart';
import '../../../data/preset.dart';
import '../../../data/repository.dart';
import '../../../state/app_state.dart';
import '../../inputs.dart';
import '../../kit.dart';
import '../admin_common.dart';
import '../form/vform.dart';

List<FieldDef> settingsDefs() {
  final sezioni = <(String, List<FieldDef>)>[
    (
      'Identità e aspetto',
      [
        const FieldDef('nome', "Nome dell'attività", required: true),
        const FieldDef('slogan', 'Slogan / sottotitolo'),
        const FieldDef('logo', 'Logo', type: 'image', wide: true, png: true, max: 800, hint: 'Consigliato PNG con sfondo trasparente, orizzontale.'),
        const FieldDef('logoAltezza', 'Altezza del logo', type: 'number', unit: 'pixel', min: 24, step: 1),
        const FieldDef('mostraNome', 'Mostra il nome accanto al logo', type: 'bool'),
        const FieldDef('colorePrimario', 'Colore principale', type: 'color', hint: "L'azzurro del logo: #0189EE"),
        const FieldDef('coloreAccento', 'Colore secondario (pulsanti in evidenza)', type: 'color', hint: 'Il nero del logo: #0B0D10'),
      ]
    ),
    (
      'Contatti',
      const [
        FieldDef('telefono', 'Telefono', type: 'tel'),
        FieldDef('whatsapp', 'Numero WhatsApp', type: 'tel', hint: 'Con prefisso internazionale, es. 393331234567'),
        FieldDef('email', 'Email', type: 'email', hint: 'Indirizzo mostrato ai visitatori'),
        FieldDef('emailAvvisi', 'Email per gli avvisi', type: 'email', hint: 'Dove arrivano gli avvisi di nuovi messaggi e prenotazioni. Se vuoto si usa l\'email qui sopra'),
        FieldDef('urlSito', 'Indirizzo del sito online', type: 'url', placeholder: 'https://felixone04.github.io/leone-immobiliare/', hint: 'Usato nei link delle email e nel QR code delle schede in vetrina'),
        FieldDef('piva', 'Partita IVA'),
        FieldDef('indirizzo', 'Indirizzo della sede', wide: true),
        FieldDef('orari', 'Orari di apertura', type: 'textarea', rows: 3, wide: true),
        FieldDef('sedeGeo', 'Posizione della sede sulla mappa', type: 'geo', wide: true, indirizzo: ['indirizzo']),
      ]
    ),
    (
      "Privacy (per l'informativa generata in automatico)",
      const [
        FieldDef('ragioneSociale', 'Ragione sociale / titolare', placeholder: 'es. Rossi S.r.l.', hint: "Se vuoto si usa il nome dell'attività"),
        FieldDef('emailPrivacy', 'Email per le richieste privacy', type: 'email', hint: "Se vuoto si usa l'email principale"),
        FieldDef('pec', 'PEC (facoltativa)', type: 'email'),
      ]
    ),
    (
      'Social',
      const [
        FieldDef('facebook', 'Facebook', type: 'url', placeholder: 'https://facebook.com/…'),
        FieldDef('instagram', 'Instagram', type: 'url', placeholder: 'https://instagram.com/…'),
        FieldDef('linkedin', 'LinkedIn', type: 'url', placeholder: 'https://linkedin.com/…'),
      ]
    ),
  ];
  return [for (final (g, campi) in sezioni) for (final c in campi) c.withGruppo(g)];
}

class ImpostazioniAdmin extends StatefulWidget {
  const ImpostazioniAdmin({super.key});
  @override
  State<ImpostazioniAdmin> createState() => _ImpostazioniAdminState();
}

class _ImpostazioniAdminState extends State<ImpostazioniAdmin> {
  late final s = App.read(context);
  late final ctrl = FormCtrl(settingsDefs(), s.settings);
  late Map<String, bool> moduli = s.repo.moduliBase;
  final _att = TextEditingController(), _nuova = TextEditingController(), _nuova2 = TextEditingController();
  String? _pwErr;

  @override
  void dispose() {
    ctrl.dispose();
    for (final c in [_att, _nuova, _nuova2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salva() async {
    if (!ctrl.validate()) return;
    final ok = await s.run(() async {
      await s.repo.saveSettings({...s.settings, ...ctrl.vals});
      return true;
    });
    if (ok == true) s.toast('Impostazioni salvate');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final salva = VButton('Salva', icon: 'check', kind: BtnKind.primary, onAsync: _salva);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AdminHead('Impostazioni', sub: 'Logo, colori, recapiti e accesso.', actions: [salva]),
      CardBox(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const BoxTitle('Tipo di attività'),
          Text(s.repo.preset.nome, style: t.text(color: t.muted)),
        ]),
      ),
      const Gap(20),
      VFormView(ctrl, groups: true),
      _moduli(context),
      _sicurezza(context),
      FormFoot(right: [salva]),
    ]);
  }

  /// Funzioni attive (nella versione web le attivava il proprietario del gestionale)
  Widget _moduli(BuildContext context) {
    final t = context.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Funzioni attive', style: t.title(size: 17.6, weight: FontWeight.w800)),
        const Gap(6),
        Text('Messaggi e privacy sono sempre attivi. Le gift card si attivano dalla loro sezione e richiedono le prenotazioni.', style: t.text(size: 14.1, color: t.muted)),
        const Gap(12),
        for (final m in kModuliInfo)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              VSwitch(value: moduli[m[0]] ?? false, onChanged: (v) async {
                setState(() => moduli[m[0]] = v);
                await s.repo.setModuli(moduli);
                s.toast(v ? '${m[1]}: attivato' : '${m[1]}: disattivato');
              }),
              const SizedBox(width: 12),
              VIcon(m[3], color: t.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m[1], style: t.text(weight: FontWeight.w700, height: 1.3)),
                  Text(m[2], style: t.text(size: 13.6, color: t.muted, height: 1.35)),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _sicurezza(BuildContext context) {
    final t = context.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Sicurezza', style: t.title(size: 17.6, weight: FontWeight.w800)),
        const Gap(8),
        Text.rich(TextSpan(children: [const TextSpan(text: 'Utente collegato: '), TextSpan(text: s.auth.utente ?? '', style: const TextStyle(fontWeight: FontWeight.w700))]), style: t.text(size: 14.1, color: t.muted)),
        const Gap(14),
        LayoutBuilder(builder: (c, box) {
          final w = box.maxWidth > 760 ? (box.maxWidth - 40) / 3 : box.maxWidth;
          return Wrap(spacing: 20, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.end, children: [
            SizedBox(width: w, child: FieldLabel('Password attuale', strong: true, child: VInput(controller: _att, obscure: true, autofill: const [AutofillHints.password]))),
            SizedBox(width: w, child: FieldLabel('Nuova password', strong: true, hint: 'Almeno 10 caratteri, con lettere e numeri', child: VInput(controller: _nuova, obscure: true, autofill: const [AutofillHints.newPassword]))),
            SizedBox(width: w, child: FieldLabel('Ripeti la nuova password', strong: true, child: VInput(controller: _nuova2, obscure: true))),
          ]);
        }),
        const Gap(12),
        FormError(_pwErr),
        const Gap(8),
        Align(
          alignment: Alignment.centerLeft,
          child: VButton('Cambia password', icon: 'lock', onAsync: () async {
            setState(() => _pwErr = null);
            try {
              if (_nuova.text != _nuova2.text) throw const AppError('Le due password non coincidono');
              await s.auth.cambiaPassword(_att.text, _nuova.text);
              for (final c in [_att, _nuova, _nuova2]) {
                c.clear();
              }
              s.toast('Password cambiata');
            } on AppError catch (e) {
              setState(() => _pwErr = e.message);
            }
          }),
        ),
      ]),
    );
  }
}
