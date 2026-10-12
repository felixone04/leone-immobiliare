/// Moduli del sito pubblico: richiesta informazioni e dati di contatto con consenso privacy.
library;

import 'package:flutter/material.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../core/util.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import 'inputs.dart';
import 'kit.dart';

/// Casella "Acconsento al trattamento dei dati … (informativa)"
class PrivacyCheck extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String scopo;
  final bool invalid;
  final String linkLabel;
  const PrivacyCheck({super.key, required this.value, required this.onChanged, required this.scopo, this.invalid = false, this.linkLabel = 'informativa'});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    return VCheck(
      value: value,
      onChanged: onChanged,
      invalid: invalid,
      label: Text.rich(TextSpan(children: [
        TextSpan(text: 'Acconsento al trattamento dei dati $scopo ('),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: TextLink(linkLabel, '#/p/${s.slugPrivacy}', style: t.text(size: 14.1, color: t.primary, weight: FontWeight.w500).copyWith(decoration: TextDecoration.underline, decorationColor: t.primary)),
        ),
        const TextSpan(text: ')'),
      ])),
    );
  }
}

/// Riga con due campi affiancati (si impilano sotto i 460 px)
class TwoCols extends StatelessWidget {
  final Widget a, b;
  const TwoCols(this.a, this.b, {super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, box) {
        if (box.maxWidth < 380) return Column(children: [a, const SizedBox(height: 12), b]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
      });
}

/// Modulo "richiedi informazioni": la richiesta finisce nei Messaggi dell'area riservata.
class ContactForm extends StatefulWidget {
  final String oggetto, messaggio;
  final String pagina, immobile;
  const ContactForm({super.key, required this.oggetto, this.messaggio = '', this.pagina = '', this.immobile = ''});
  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _nome = TextEditingController(), _email = TextEditingController(), _tel = TextEditingController();
  late final _msg = TextEditingController(text: widget.messaggio);
  var _privacy = false, _tentato = false, _inviato = false;
  String? _err;
  String _nomeInviato = '';

  @override
  void dispose() {
    for (final c in [_nome, _email, _tel, _msg]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _invia() async {
    setState(() => _tentato = true);
    if (_nome.text.trim().isEmpty || !validEmail(_email.text.trim()) || _msg.text.trim().isEmpty || !_privacy) {
      setState(() => _err = "Compila nome, email e messaggio e accetta l'informativa.");
      return;
    }
    setState(() => _err = null);
    try {
      await App.read(context).repo.richiestaCrea({
        'nome': _nome.text, 'email': _email.text, 'telefono': _tel.text, 'messaggio': _msg.text, 'oggetto': widget.oggetto, 'pagina': widget.pagina, 'immobile': widget.immobile,
      });
      setState(() {
        _nomeInviato = _nome.text.trim().split(' ').first;
        _inviato = true;
      });
    } on AppError catch (e) {
      setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_inviato) return MsgOk('Messaggio inviato!', text: 'Grazie $_nomeInviato, ti risponderemo al più presto.');
    final inv = _tentato;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FieldLabel('Nome e cognome', child: VInput(controller: _nome, autofill: const [AutofillHints.name], invalid: inv && _nome.text.trim().isEmpty)),
      const SizedBox(height: 12),
      TwoCols(
        FieldLabel('Email', child: VInput(controller: _email, keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], invalid: inv && !validEmail(_email.text.trim()))),
        FieldLabel('Telefono', child: VInput(controller: _tel, keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber])),
      ),
      const SizedBox(height: 12),
      FieldLabel('Messaggio', child: VInput(controller: _msg, minLines: 4, maxLines: 10, invalid: inv && _msg.text.trim().isEmpty)),
      const SizedBox(height: 12),
      PrivacyCheck(value: _privacy, onChanged: (v) => setState(() => _privacy = v), scopo: 'per ricevere una risposta', invalid: inv && !_privacy),
      const SizedBox(height: 8),
      FormError(_err),
      const SizedBox(height: 8),
      VButton('Invia richiesta', icon: 'mail', kind: BtnKind.primary, block: true, onAsync: _invia),
    ]);
  }
}

/// Riga "etichetta: valore" dei riepiloghi (.riep)
class RiepRow extends StatelessWidget {
  final String label;
  final Widget value;
  final bool last;
  const RiepRow(this.label, this.value, {super.key, this.last = false});
  factory RiepRow.text(String label, String value, {bool last = false}) => RiepRow(label, _RiepVal(value), last: last);
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.text(color: t.muted)),
          const SizedBox(width: 14),
          Expanded(child: Align(alignment: Alignment.centerRight, child: DefaultTextStyle(style: t.text(weight: FontWeight.w600), textAlign: TextAlign.right, child: value))),
        ]),
      ),
      if (!last) DashedLine(color: t.line),
    ]);
  }
}

class _RiepVal extends StatelessWidget {
  final String v;
  const _RiepVal(this.v);
  @override
  Widget build(BuildContext context) => Text(v, textAlign: TextAlign.right);
}

/// Riepilogo completo da una lista di righe (salta i valori vuoti)
class Riep extends StatelessWidget {
  final List<(String, Object?)> rows;
  const Riep(this.rows, {super.key});
  @override
  Widget build(BuildContext context) {
    final list = rows.where((r) => r.$2 != null && !(r.$2 is String && (r.$2 as String).isEmpty)).toList();
    return Column(children: [
      for (var i = 0; i < list.length; i++)
        list[i].$2 is Widget ? RiepRow(list[i].$1, list[i].$2 as Widget, last: i == list.length - 1) : RiepRow.text(list[i].$1, str(list[i].$2), last: i == list.length - 1),
    ]);
  }
}

/// Icona tonda grande dei messaggi di conferma (.pren-ok-ic)
class BigStatusIcon extends StatelessWidget {
  final bool ok;
  const BigStatusIcon({super.key, this.ok = true});
  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: ok ? VTheme.okSoft : VTheme.warnSoft, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: VIcon(ok ? 'check' : 'clock', size: 36, color: ok ? VTheme.ok : VTheme.warn),
      );
}
