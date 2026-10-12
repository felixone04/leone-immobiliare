/// #/p/SLUG: pagine di testo, pagina Contatti e informativa privacy generata automaticamente.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/icons.dart';
import '../../core/markdown.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../state/app_state.dart';
import '../forms_public.dart';
import '../kit.dart';
import '../map/vmap.dart';
import '../shell.dart';
import 'not_found.dart';

class InfoPage extends StatelessWidget {
  final String slug;
  const InfoPage({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final p = s.repo.pages.where((x) => x['slug'] == slug).firstOrNull;
    if (p == null) return const NotFoundPage();
    if (p['tipo'] == 'privacy') return PrivacyPage(page: p);
    if (p['tipo'] == 'contatti') return _ContattiPage(page: p);
    final t = context.t;
    final img = safeSrc(p['immagine']);
    final prose = Prose(str(p['contenuto']));
    Widget body;
    if (img.isEmpty) {
      body = prose;
    } else {
      final image = Container(
        decoration: BoxDecoration(borderRadius: t.r, boxShadow: t.shadow),
        clipBehavior: Clip.antiAlias,
        child: VImage(img, fit: BoxFit.fitWidth),
      );
      body = context.vw <= 860
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [prose, const SizedBox(height: 32), image])
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 10, child: prose), const SizedBox(width: 48), Expanded(flex: 8, child: image)]);
    }
    return PageScroll(children: [
      PageHero(str(p['titolo'])),
      Contained(child: Padding(padding: pagePad(context), child: body)),
    ]);
  }
}

class _ContattiPage extends StatelessWidget {
  final Json page;
  const _ContattiPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final set = s.settings;
    final tel = telHref(str(set['telefono'])), wa = onlyDigits(str(set['whatsapp']));
    Widget item(String icon, String label, Widget value) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(12)),
              child: VIcon(icon, size: 22, color: t.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label.toUpperCase(), style: t.caps(size: 12.8)),
                DefaultTextStyle(style: t.text(size: 16.8, weight: FontWeight.w600), child: value),
              ]),
            ),
          ]),
        );
    final valueStyle = t.text(size: 16.8, weight: FontWeight.w600);
    final left = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (str(page['contenuto']).isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 24), child: Prose(str(page['contenuto']), size: 17.9)),
      if (str(set['indirizzo']).isNotEmpty) item('pin', 'Indirizzo', Text(str(set['indirizzo']))),
      if (tel.isNotEmpty) item('phone', 'Telefono', TextLink(str(set['telefono']), 'tel:$tel', style: valueStyle)),
      if (wa.isNotEmpty) item('chat', 'WhatsApp', TextLink('Scrivici su WhatsApp', 'https://wa.me/$wa', style: valueStyle)),
      if (str(set['email']).isNotEmpty) item('mail', 'Email', TextLink(str(set['email']), 'mailto:${set['email']}', style: valueStyle)),
      if (str(set['orari']).isNotEmpty) item('clock', 'Orari', Text(str(set['orari']))),
    ]);
    final form = CardBox(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const BoxTitle('Scrivici'),
        ContactForm(oggetto: 'Richiesta dal sito ${set['nome']}', pagina: '#/p/${page['slug']}'),
      ]),
    );
    final sede = sedePin(s);
    return PageScroll(children: [
      PageHero(str(page['titolo'])),
      Contained(
        child: Padding(
          padding: pagePad(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (context.vw <= 860)
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, const SizedBox(height: 32), form])
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), const SizedBox(width: 48), SizedBox(width: 460, child: form)]),
            if (sede != null) ...[const SizedBox(height: 48), VMap(pins: [sede], center: sede.pos, zoom: 15, height: 380, fit: false)],
          ]),
        ),
      ),
    ]);
  }
}

/// Informativa privacy e cookie generata con i dati dell'azienda e le funzioni attive.
class PrivacyPage extends StatelessWidget {
  final Json page;
  const PrivacyPage({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final set = s.settings;
    final titolare = str(set['ragioneSociale']).isNotEmpty ? str(set['ragioneSociale']) : str(set['nome']);
    final emailPriv = str(set['emailPrivacy']).isNotEmpty ? str(set['emailPrivacy']) : str(set['email']);
    final tratt = [
      ['Richieste di contatto', 'nome, email, telefono e testo del messaggio', 'rispondere alla tua richiesta', 'misure precontrattuali / consenso', '24 mesi'],
      if (s.modulo('prenotazioni')) ['Visite e appuntamenti', "nome, email, telefono, immobile o servizio, data e note", "organizzare l'appuntamento con l'agente", 'esecuzione di un servizio da te richiesto', "24 mesi dall'appuntamento"],
      ['Account cliente', 'nome, email, telefono, password (solo in forma cifrata), immobili preferiti, ricerche salvate', 'conservare preferiti e ricerche e avvisarti quando un immobile corrisponde a una tua ricerca', 'esecuzione del servizio da te richiesto', "fino alla cancellazione dell'account"],
      ['Proposte di immobili e offerte via email', 'nome ed email', 'inviarti nuovi immobili e offerte', 'consenso (facoltativo, revocabile in ogni momento)', 'fino alla revoca del consenso'],
      if (s.modulo('recensioni')) ['Recensioni', 'nome (pubblicato), testo, voto, email facoltativa (non pubblicata)', 'pubblicare la tua opinione', 'consenso', 'fino alla richiesta di cancellazione'],
    ];
    final agg = DateFormat('d MMMM y', 'it').format(DateTime.now());
    final base = t.text(size: 16.6, color: t.ink2, height: 1.6);
    final strong = TextStyle(fontWeight: FontWeight.w700, color: t.ink);
    Widget h2(String x) => Padding(padding: const EdgeInsets.only(top: 33, bottom: 10), child: Text(x, style: t.title(size: 20.8)));
    Widget p(List<InlineSpan> spans) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text.rich(TextSpan(children: spans), style: base));
    InlineSpan link(String text, String href) => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: TextLink(text, href, style: base.copyWith(color: t.primary, decoration: TextDecoration.underline, decorationColor: t.primary)),
        );
    Widget bullet(List<InlineSpan> spans) => Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 10, right: 10), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle))),
            Expanded(child: Text.rich(TextSpan(children: spans), style: base)),
          ]),
        );
    final righe = <String>[
      if (str(set['indirizzo']).isNotEmpty) str(set['indirizzo']),
      if (str(set['piva']).isNotEmpty) 'P.IVA ${set['piva']}',
    ];
    final table = Container(
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.line), borderRadius: t.r),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: (context.vw - 48).clamp(0.0, 720.0)),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            columnWidths: const {0: FixedColumnWidth(140), 1: FixedColumnWidth(170), 2: FixedColumnWidth(170), 3: FixedColumnWidth(140), 4: FixedColumnWidth(130)},
            border: TableBorder(horizontalInside: BorderSide(color: t.line)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: context.t.tint),
                children: [for (final h in ['Attività', 'Dati', 'Finalità', 'Base giuridica', 'Conservazione']) Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Text(h.toUpperCase(), style: t.caps(size: 12)))],
              ),
              for (final r in tratt) TableRow(children: [for (final c in r) Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Text(c, style: t.text(size: 14.1)))]),
            ],
          ),
        ),
      ),
    );
    return PageScroll(children: [
      PageHero(str(page['titolo']), slim: true),
      Contained(
        child: Padding(
          padding: pagePad(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Informativa ai sensi del Regolamento UE 2016/679 (GDPR). Ultimo aggiornamento: $agg.', style: t.text(size: 14.1, color: t.muted)),
              h2('Titolare del trattamento'),
              p([
                TextSpan(text: titolare, style: strong),
                for (final r in righe) TextSpan(text: '\n$r'),
                if (emailPriv.isNotEmpty) ...[const TextSpan(text: '\nEmail: '), link(emailPriv, 'mailto:$emailPriv')],
                if (str(set['pec']).isNotEmpty) TextSpan(text: '\nPEC: ${set['pec']}'),
                if (str(set['telefono']).isNotEmpty) TextSpan(text: '\nTelefono: ${set['telefono']}'),
              ]),
              h2('Quali dati trattiamo e perché'),
              table,
              const SizedBox(height: 16),
              p(const [
                TextSpan(
                    text:
                        'I dati sono forniti volontariamente da te tramite i moduli del sito. Senza i dati obbligatori non è possibile rispondere o erogare il servizio richiesto. Non effettuiamo profilazione né decisioni automatizzate e non vendiamo i tuoi dati.'),
              ]),
              h2('Chi può accedere ai dati'),
              p(const [TextSpan(text: 'Il personale autorizzato del titolare. I dati sono conservati localmente, sul dispositivo in cui è installato il sito, e non vengono inviati a server esterni.')]),
              h2('I tuoi diritti'),
              p([
                const TextSpan(text: "Puoi chiedere in ogni momento l'accesso, la rettifica, la cancellazione o la limitazione dei tuoi dati, opporti al trattamento, chiedere la portabilità e revocare il consenso scrivendo a "),
                if (emailPriv.isNotEmpty) link(emailPriv, 'mailto:$emailPriv') else const TextSpan(text: 'il titolare'),
                const TextSpan(text: '. Hai inoltre diritto di proporre reclamo al Garante per la protezione dei dati personali ('),
                link('garanteprivacy.it', 'https://www.garanteprivacy.it'),
                const TextSpan(text: ').'),
              ]),
              h2('Cookie e contenuti esterni'),
              p([const TextSpan(text: 'Questo sito '), TextSpan(text: 'non usa cookie di profilazione né strumenti di statistica di terze parti', style: strong), const TextSpan(text: '.')]),
              bullet([
                TextSpan(text: 'Dati tecnici', style: strong),
                const TextSpan(text: ": una preferenza salvata nel tuo browser per ricordare la scelta sui contenuti esterni e i dati necessari al funzionamento del sito. Non richiedono consenso."),
              ]),
              bullet([
                TextSpan(text: 'Contenuti esterni', style: strong),
                const TextSpan(text: ' (caricati '),
                const TextSpan(text: 'solo se li accetti', style: TextStyle(fontStyle: FontStyle.italic)),
                const TextSpan(text: '): mappe di OpenStreetMap. Questo servizio riceve il tuo indirizzo IP quando la mappa viene caricata. Caratteri e immagini del sito sono inclusi nel sito stesso.'),
              ]),
              const SizedBox(height: 16),
              VButton('Modifica le preferenze sui cookie', icon: 'settings', kind: BtnKind.outline, onPressed: () => s.cookieBanner.value = true),
              if (str(page['contenuto']).isNotEmpty) ...[h2('Ulteriori informazioni'), Prose(str(page['contenuto']))],
            ]),
          ),
        ),
      ),
    ]);
  }
}
