/// Parti riutilizzabili delle prenotazioni: calendario, orari, passaggi, lista d'attesa, file .ics.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';
import '../../core/platform/browser.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../dialogs.dart';
import '../forms_public.dart';
import '../inputs.dart';
import '../kit.dart';

/// Riquadro di un passaggio numerato (.pstep)
class PStep extends StatelessWidget {
  final int n;
  final String title;
  final Widget child;
  const PStep({super.key, required this.n, required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.moderno ? Colors.transparent : t.line), borderRadius: t.r, boxShadow: t.moderno ? t.shadow : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.primary, shape: BoxShape.circle),
              child: Text('$n', style: t.text(size: 15.2, weight: FontWeight.w700, color: t.onPrimary, height: 1)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: t.title(size: 19.2))),
          ]),
        ),
        child,
      ]),
    );
  }
}

/// Opzione selezionabile (.popt)
class POpt extends StatelessWidget {
  final String title;
  final Widget? sub;
  final bool on;
  final VoidCallback onTap;
  const POpt({super.key, required this.title, this.sub, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hover(
      onTap: onTap,
      builder: (_, h) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on ? t.primarySoft : Colors.white,
          border: Border.all(color: on || h ? t.primary : t.line2, width: on ? 2.5 : 1.5),
          borderRadius: BorderRadius.circular(t.minimal ? 0 : 12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: t.text(weight: FontWeight.w700, height: 1.35)),
          if (sub != null) DefaultTextStyle(style: t.text(size: 13.6, color: t.muted, height: 1.4), child: sub!),
        ]),
      ),
    );
  }
}

/// Calendario di 6 settimane: giorni = { 'YYYY-MM-DD': numero di orari liberi }
class CalGrid extends StatelessWidget {
  final Map<String, int> giorni;
  final String sel;
  final ValueChanged<String> onTap;
  const CalGrid({super.key, required this.giorni, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final date = giorni.keys.toList();
    if (date.isEmpty) return const SizedBox.shrink();
    final offset = (parseDate(date.first).weekday + 6) % 7;
    final cells = <Widget>[
      for (final g in ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom']) Center(child: Text(g.toUpperCase(), style: t.caps(size: 12, spacing: 0))),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (final d in date) _day(context, d, date.first),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: LayoutBuilder(builder: (c, box) {
        final w = (box.maxWidth - 6 * 6) / 7;
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < cells.length; i++) SizedBox(width: w, height: i < 7 ? 20 : w, child: cells[i]),
        ]);
      }),
    );
  }

  Widget _day(BuildContext context, String d, String first) {
    final t = context.t;
    final n = giorni[d] ?? 0;
    final dt = parseDate(d);
    final on = sel == d;
    final off = n == 0;
    final month = dt.day == 1 || d == first ? DateFormat('MMM', 'it').format(dt).toUpperCase() : null;
    return Tooltip(
      message: '${fmtDate(d)}${n > 0 ? ' · $n orari liberi' : ' · non disponibile'}',
      child: Hover(
        onTap: off ? null : () => onTap(d),
        builder: (_, h) => Container(
          decoration: BoxDecoration(
            color: on ? t.primary : (off ? Colors.transparent : Colors.white),
            border: Border.all(color: on || (h && !off) ? t.primary : (off ? Colors.transparent : t.line2), width: 1.5),
            borderRadius: BorderRadius.circular(t.minimal ? 0 : 12),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${dt.day}', style: t.text(size: 16.3, weight: FontWeight.w700, color: on ? t.onPrimary : (off ? const Color(0xFFB7BCC3) : t.ink), height: 1.1)),
            if (month != null) Text(month, style: t.text(size: 10.5, color: on ? t.onPrimary : t.muted, height: 1.1)),
          ]),
        ),
      ),
    );
  }
}

/// Orari divisi in mattina / pomeriggio / sera
class OreGrid extends StatelessWidget {
  final List<String> ore;
  final String sel;
  final ValueChanged<String> onTap;
  const OreGrid({super.key, required this.ore, required this.sel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (ore.isEmpty) return Text('Nessun orario libero in questo giorno: scegline un altro.', style: t.text(color: t.muted));
    final fasce = [
      ('Mattina', ore.where((o) => o.compareTo('12:00') < 0).toList()),
      ('Pomeriggio', ore.where((o) => o.compareTo('12:00') >= 0 && o.compareTo('18:00') < 0).toList()),
      ('Sera', ore.where((o) => o.compareTo('18:00') >= 0).toList()),
    ].where((f) => f.$2.isNotEmpty).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < fasce.length; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(fasce[i].$1.toUpperCase(), style: t.caps(size: 12.8))),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final o in fasce[i].$2) OraChip(o, on: o == sel, onTap: () => onTap(o))]),
      ],
    ]);
  }
}

class OraChip extends StatelessWidget {
  final String ora;
  final bool on;
  final VoidCallback onTap;
  const OraChip(this.ora, {super.key, required this.on, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Hover(
      onTap: onTap,
      builder: (_, h) => Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: on ? t.primary : Colors.white,
          border: Border.all(color: on || h ? t.primary : t.line2, width: 1.5),
          borderRadius: BorderRadius.circular(t.minimal ? 0 : 10),
        ),
        child: Text(ora, textAlign: TextAlign.center, style: t.text(weight: FontWeight.w700, color: on ? t.onPrimary : t.ink, height: 1.2)),
      ),
    );
  }
}

/// Lista d'attesa: il cliente lascia i suoi dati per un giorno e una fascia oraria.
void apriListaAttesa(BuildContext context, Json servizio, String coll, String data, List<Json> collaboratori) {
  final s = App.read(context);
  final cn = str(collaboratori.where((c) => c['id'] == coll).firstOrNull?['nome']);
  showVModal(context, "Lista d'attesa", (ctx) => _AttesaForm(state: s, servizio: servizio, coll: coll, data: data, collNome: cn));
}

class _AttesaForm extends StatefulWidget {
  final AppState state;
  final Json servizio;
  final String coll, data, collNome;
  const _AttesaForm({required this.state, required this.servizio, required this.coll, required this.data, required this.collNome});
  @override
  State<_AttesaForm> createState() => _AttesaFormState();
}

class _AttesaFormState extends State<_AttesaForm> {
  late String data = widget.data;
  var fascia = 'qualsiasi';
  final nome = TextEditingController(), tel = TextEditingController(), email = TextEditingController(), note = TextEditingController();
  var privacy = false, tentato = false, fatto = false;
  String? err;

  Future<void> _invia() async {
    setState(() => tentato = true);
    if (data.isEmpty || nome.text.trim().isEmpty || tel.text.trim().isEmpty || !privacy) {
      setState(() => err = "Compila giorno, nome e telefono e accetta l'informativa.");
      return;
    }
    try {
      await widget.state.repo.attCrea({
        'data': data, 'fascia': fascia, 'nome': nome.text, 'telefono': tel.text, 'email': email.text, 'note': note.text,
        'servizio': widget.servizio['id'], 'collaboratore': widget.coll,
      });
      setState(() => fatto = true);
    } on AppError catch (e) {
      setState(() => err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (fatto) return const MsgOk("Sei in lista d'attesa!", text: 'Ti contatteremo appena si libera un posto.');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text.rich(
        TextSpan(children: [
          const TextSpan(text: 'Se si libera un posto per '),
          TextSpan(text: str(widget.servizio['nome']), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (widget.collNome.isNotEmpty) TextSpan(text: ' con ${widget.collNome}'),
          const TextSpan(text: ' ti contattiamo noi.'),
        ]),
        style: t.text(),
      ),
      const SizedBox(height: 14),
      TwoCols(
        FieldLabel('Giorno desiderato', child: DateInput(value: data, min: oggi(), onChanged: (v) => setState(() => data = v), invalid: tentato && data.isEmpty)),
        FieldLabel(
          'Fascia oraria',
          child: VSelect<String>(
            value: fascia,
            items: const [('qualsiasi', 'Qualsiasi orario'), ('mattina', 'Mattina'), ('pomeriggio', 'Pomeriggio'), ('sera', 'Sera')],
            onChanged: (v) => setState(() => fascia = v ?? 'qualsiasi'),
          ),
        ),
      ),
      const SizedBox(height: 12),
      FieldLabel('Nome e cognome', child: VInput(controller: nome, invalid: tentato && nome.text.trim().isEmpty)),
      const SizedBox(height: 12),
      TwoCols(
        FieldLabel('Telefono', child: VInput(controller: tel, keyboard: TextInputType.phone, invalid: tentato && tel.text.trim().isEmpty)),
        FieldLabel('Email (facoltativa)', child: VInput(controller: email, keyboard: TextInputType.emailAddress)),
      ),
      const SizedBox(height: 12),
      FieldLabel('Note', child: VInput(controller: note, maxLength: 500, hint: 'es. vado bene anche con breve preavviso')),
      const SizedBox(height: 12),
      PrivacyCheck(value: privacy, onChanged: (v) => setState(() => privacy = v), scopo: 'per essere ricontattato', invalid: tentato && !privacy),
      const SizedBox(height: 8),
      FormError(err),
      const SizedBox(height: 8),
      VButton("Mettimi in lista d'attesa", icon: 'clock', kind: BtnKind.primary, block: true, onAsync: _invia),
    ]);
  }
}

/// Campo data con calendario (valore 'YYYY-MM-DD', mostrato come gg/mm/aaaa).
class DateInput extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String? min;
  final bool invalid, dense, clearable;
  const DateInput({super.key, required this.value, required this.onChanged, this.min, this.invalid = false, this.dense = false, this.clearable = false});
  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final txt = validIsoDate(value) ? DateFormat('dd/MM/yyyy').format(parseDate(value)) : '';
    Future<void> pick() async {
      final now = DateTime.now();
      final first = min != null && validIsoDate(min!) ? parseDate(min!) : DateTime(now.year - 5);
      final init = validIsoDate(value) ? parseDate(value) : (now.isBefore(first) ? first : now);
      final d = await showDatePicker(
        context: context,
        initialDate: init.isBefore(first) ? first : init,
        firstDate: first,
        lastDate: DateTime(now.year + 5),
        locale: const Locale('it'),
        builder: (c, child) => Theme(data: Theme.of(c).copyWith(colorScheme: ColorScheme.light(primary: t.primary, onPrimary: t.onPrimary)), child: child!),
      );
      if (d != null) onChanged(isoDate(d));
    }

    return Hover(
      onTap: pick,
      builder: (_, h) => Container(
        height: dense ? 38 : 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: invalid ? const Color(0xFFFFF8F7) : Colors.white,
          border: Border.all(color: invalid ? VTheme.danger : (h ? t.primary : t.line2)),
          borderRadius: BorderRadius.circular(dense ? 10 : t.radiusSm),
        ),
        child: Row(children: [
          Expanded(child: Text(txt.isEmpty ? 'gg/mm/aaaa' : txt, style: t.text(size: 15, color: txt.isEmpty ? t.muted : t.ink, height: 1.2))),
          if (clearable && txt.isNotEmpty) GestureDetector(onTap: () => onChanged(''), child: VIcon('x', size: 15, color: t.muted)),
          const SizedBox(width: 6),
          VIcon('calendar', size: 16, color: t.ink2),
        ]),
      ),
    );
  }
}

/// File .ics per aggiungere l'appuntamento al calendario del telefono.
void scaricaIcs(AppState s, Json p, String link) {
  String tm(String d, String o) => '${d.replaceAll('-', '')}T${o.replaceAll(':', '')}00';
  String esc(Object? x) => str(x).replaceAllMapped(RegExp(r'[\\;,]'), (m) => '\\${m[0]}').replaceAll('\n', '\\n');
  final set = s.settings;
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').replaceAll(RegExp(r'\.\d+'), '');
  final txt = [
    'BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Vetrina//Prenotazioni//IT', 'BEGIN:VEVENT',
    'UID:${p['id']}@vetrina', 'DTSTAMP:$stamp',
    'DTSTART;TZID=Europe/Rome:${tm(str(p['data']), str(p['ora']))}', 'DTEND;TZID=Europe/Rome:${tm(str(p['data']), str(p['fine']))}',
    'SUMMARY:${esc('${p['servizio']} - ${set['nome']}')}', 'LOCATION:${esc(set['indirizzo'])}',
    'DESCRIPTION:${esc('Prenotazione ${str(p['id']).substring(0, 8).toUpperCase()}${str(set['telefono']).isNotEmpty ? '. Tel. ${set['telefono']}' : ''}. Gestisci: $link')}',
    'END:VEVENT', 'END:VCALENDAR',
  ].join('\r\n');
  downloadBytes(utf8.encode(txt), 'appuntamento.ics', 'text/calendar');
}

/// Prezzo e durata dei servizi prenotabili
String prezzoServizio(Object? p) {
  final n = numOrNull(p);
  if (n == null) return '';
  return n == 0 ? 'Gratuita' : fmtPrice(n);
}

/// Codice breve della prenotazione
String codicePren(Object? id) => str(id).length >= 8 ? str(id).substring(0, 8).toUpperCase() : str(id).toUpperCase();
