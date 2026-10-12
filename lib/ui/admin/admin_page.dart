/// #/admin: area riservata (primo accesso, login, menu laterale, sezioni).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../inputs.dart';
import '../kit.dart';
import '../shell.dart';
import 'sezioni/backup.dart';
import 'sezioni/catalogo.dart';
import 'sezioni/clienti_admin.dart';
import 'sezioni/dash.dart';
import 'sezioni/impostazioni.dart';
import 'sezioni/messaggi.dart';
import 'sezioni/ordinabili.dart';
import 'sezioni/posta_admin.dart';
import 'sezioni/prenotazioni_admin.dart';
import 'sezioni/recensioni_admin.dart';
import 'sezioni/statistiche_admin.dart';

class AdminPage extends StatelessWidget {
  final List<String> parts;
  final Map<String, String> query;
  const AdminPage({super.key, required this.parts, this.query = const {}});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    if (!s.auth.configurato) return const _Accesso(primo: true);
    if (!s.auth.isAdmin) return const _Accesso(primo: false);
    s.auth.tocca();
    // senza server i promemoria delle visite di domani si preparano quando l'agenzia apre l'area riservata
    if (s.modulo('prenotazioni')) WidgetsBinding.instance.addPostFrameCallback((_) => s.repo.promemoriaVisite());
    return _AdminShell(tab: parts.isEmpty ? 'panoramica' : parts[0], rest: parts.length > 1 ? parts.sublist(1) : const [], query: query);
  }
}

/* ---------------- Primo accesso e login ---------------- */

class _Accesso extends StatefulWidget {
  final bool primo;
  const _Accesso({required this.primo});
  @override
  State<_Accesso> createState() => _AccessoState();
}

class _AccessoState extends State<_Accesso> {
  final _u = TextEditingController(), _p = TextEditingController(), _p2 = TextEditingController();
  final _pf = FocusNode();
  String? _err;

  @override
  void dispose() {
    for (final c in [_u, _p, _p2]) {
      c.dispose();
    }
    _pf.dispose();
    super.dispose();
  }

  Future<void> _entra() async {
    final s = App.read(context);
    setState(() => _err = null);
    try {
      if (widget.primo) {
        if (_p.text != _p2.text) throw const AppError('Le due password non coincidono');
        await s.auth.crea(_u.text, _p.text);
        s.toast('Account creato: benvenuto!');
      } else {
        await s.auth.login(_u.text, _p.text);
      }
    } on AppError catch (e) {
      setState(() => _err = e.message);
      _p.selection = TextSelection(baseOffset: 0, extentOffset: _p.text.length);
      _pf.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final logo = safeSrc(App.of(context).settings['logo']);
    final marchio = logo.isNotEmpty;
    return PageScroll(footer: false, children: [
      Contained(
        child: Padding(
          padding: pagePad(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: CardBox(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  shadow: marchio ? t.shadowLg : null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (marchio) ...[
                      Center(child: SizedBox(height: 72, child: VImage(logo, fit: BoxFit.contain))),
                      const Gap(18),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        VIcon('lock', size: 14, color: t.primary),
                        const SizedBox(width: 8),
                        Text('AREA RISERVATA', style: t.caps(size: 12)),
                      ]),
                      const Gap(10),
                    ] else
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        margin: const EdgeInsets.only(bottom: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(18)),
                        child: VIcon('lock', size: 28, color: t.primary),
                      ),
                    ),
                    Text(widget.primo ? 'Crea il tuo account' : (marchio ? 'Bentornato' : 'Area riservata'), textAlign: TextAlign.center, style: t.title(size: 25.6)),
                    const Gap(12),
                    Text(
                      widget.primo
                          ? 'Primo accesso: scegli nome utente e password per gestire il sito. La password viene salvata solo in forma cifrata.'
                          : 'Accedi per gestire i contenuti del sito.',
                      textAlign: TextAlign.center,
                      style: t.text(color: t.muted),
                    ),
                    const Gap(12),
                    VInput(controller: _u, hint: 'Nome utente', autofocus: true, autofill: const [AutofillHints.username], onSubmitted: (_) => _pf.requestFocus()),
                    const Gap(12),
                    VInput(
                      controller: _p,
                      focusNode: _pf,
                      hint: widget.primo ? 'Password (almeno 10 caratteri, lettere e numeri)' : 'Password',
                      obscure: true,
                      autofill: [widget.primo ? AutofillHints.newPassword : AutofillHints.password],
                      onSubmitted: (_) => widget.primo ? null : _entra(),
                    ),
                    if (widget.primo) ...[
                      const Gap(12),
                      VInput(controller: _p2, hint: 'Ripeti la password', obscure: true, autofill: const [AutofillHints.newPassword], onSubmitted: (_) => _entra()),
                    ],
                    const Gap(12),
                    FormError(_err),
                    const Gap(12),
                    VButton(widget.primo ? 'Crea account ed entra' : 'Entra', kind: BtnKind.primary, size: BtnSize.lg, block: true, onAsync: _entra),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/* ---------------- Struttura con menu laterale ---------------- */

typedef SezioneBuilder = Widget Function(List<String> rest, Map<String, String> query);

class _AdminShell extends StatelessWidget {
  final String tab;
  final List<String> rest;
  final Map<String, String> query;
  const _AdminShell({required this.tab, required this.rest, required this.query});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final sch = s.repo.schema;
    final pren = s.modulo('prenotazioni');
    final cnt = s.repo.contatori();
    final sezioni = <(String, List<(String, String, String, int)>)>[
      ('Sito', [('panoramica', 'grid', 'Panoramica', 0), ('catalogo', sch.icona, sch.plurale, 0), ('statistiche', 'chart', 'Statistiche', 0), ('widget', 'layers', 'Home e widget', 0), ('pagine', 'file', 'Pagine e menu', 0)]),
      (
        'Clienti',
        [
          ('messaggi', 'mail', 'Messaggi', cnt['messaggi'] ?? 0),
          ('posta', 'send', 'Email', cnt['posta'] ?? 0),
          ('clienti', 'users', 'Clienti', 0),
          if (pren) ('prenotazioni', 'calendar', 'Visite e agenda', cnt['prenotazioni'] ?? 0),
          if (s.modulo('recensioni')) ('recensioni', 'heart', 'Recensioni', cnt['recensioni'] ?? 0),
        ]
      ),
      ('Configurazione', [('impostazioni', 'settings', 'Impostazioni', 0), ('backup', 'download', 'Backup', 0)]),
    ];
    final narrow = context.vw <= 900;
    // Tema Leone: menu laterale nero con la voce attiva azzurra, come il piè di pagina del sito
    final scuro = !narrow;
    const chiaro = Color(0xFFC5CAD1), spento = Color(0xFF8B929B);
    final rItem = BorderRadius.circular(8);
    Color fgVoce(bool active, bool h) => active ? t.onPrimary : (scuro ? (h ? Colors.white : chiaro) : (h ? t.ink : t.ink2));
    Color? bgVoce(bool active, bool h) => active ? t.primary : (h ? (scuro ? Colors.white.withValues(alpha: .08) : t.bg) : null);

    Widget navItem(String k, String ic, String l, int n) {
      final active = k == tab;
      return Hover(
        onTap: () => context.go('/admin/$k'),
        builder: (_, h) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: bgVoce(active, h), borderRadius: rItem),
          child: Row(mainAxisSize: narrow ? MainAxisSize.min : MainAxisSize.max, children: [
            VIcon(ic, color: fgVoce(active, h)),
            const SizedBox(width: 12),
            Text(l, style: t.text(size: 15.2, weight: FontWeight.w600, color: fgVoce(active, h), height: 1.3)),
            if (n > 0) ...[
              if (narrow) const SizedBox(width: 8) else const Spacer(),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: VTheme.danger, borderRadius: BorderRadius.circular(999)),
                child: Text('$n', style: t.text(size: 11.5, weight: FontWeight.w800, color: Colors.white, height: 1)),
              ),
            ],
          ]),
        ),
      );
    }

    Widget footItem(String ic, String l, VoidCallback onTap) => Hover(
          onTap: onTap,
          builder: (_, h) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: bgVoce(false, h), borderRadius: rItem),
            child: Row(mainAxisSize: narrow ? MainAxisSize.min : MainAxisSize.max, children: [
              VIcon(ic, color: fgVoce(false, h)),
              const SizedBox(width: 12),
              Text(l, style: t.text(size: 15.2, weight: FontWeight.w600, color: fgVoce(false, h), height: 1.3)),
            ]),
          ),
        );
    final vedi = footItem('eye', 'Vedi il sito', () => openLink(context, '#/', newTab: true));
    final esci = footItem('logout', 'Esci', () {
      s.auth.logout();
      context.go('/');
      s.toast("Sei uscito dall'area riservata");
    });

    final Widget nav;
    if (narrow) {
      nav = Container(
        decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.line))),
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (_, voci) in sezioni)
              for (final (k, ic, l, n) in voci) navItem(k, ic, l, n),
            vedi,
            esci,
          ]),
        ),
      );
    } else {
      final logo = safeSrc(s.settings['logo']);
      nav = Container(
        width: 250,
        decoration: scuro
            ? BoxDecoration(color: t.footerBg, border: Border(right: BorderSide(color: t.primary, width: 3)))
            : BoxDecoration(color: t.surface, border: Border(right: BorderSide(color: t.line))),
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (scuro && logo.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(4, 0, 4, 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: rItem),
              child: SizedBox(height: 52, child: VImage(logo, fit: BoxFit.contain)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(children: [
              VIcon('lock', size: 14, color: scuro ? t.primary : t.muted),
              const SizedBox(width: 8),
              Text('AREA RISERVATA', style: t.caps(size: 12, color: scuro ? Colors.white : null)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final (titolo, voci) in sezioni) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 4), child: Text(titolo.toUpperCase(), style: t.caps(size: 10.9, color: scuro ? spento : null))),
                  for (final (k, ic, l, n) in voci) Padding(padding: const EdgeInsets.only(bottom: 2), child: navItem(k, ic, l, n)),
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: scuro ? Colors.white.withValues(alpha: .1) : t.line))),
            child: Column(children: [vedi, esci]),
          ),
        ]),
      );
    }

    final main = _sezione(context);
    final content = PageScroll(
      footer: false,
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(padding: narrow ? const EdgeInsets.fromLTRB(16, 24, 16, 64) : const EdgeInsets.fromLTRB(40, 32, 40, 80), child: main),
          ),
        ),
      ],
    );
    if (narrow) return Column(children: [nav, Expanded(child: content)]);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [nav, Expanded(child: content)]);
  }

  Widget _sezione(BuildContext context) {
    final key = ValueKey('$tab/${rest.join('/')}?$query');
    return switch (tab) {
      'catalogo' => CatalogoAdmin(key: key, rest: rest),
      'widget' => WidgetAdmin(key: key),
      'pagine' => PagineAdmin(key: key),
      'impostazioni' => ImpostazioniAdmin(key: key),
      'backup' => BackupAdmin(key: key),
      'messaggi' => MessaggiAdmin(key: key),
      'prenotazioni' => PrenotazioniAdmin(key: key, rest: rest, query: query),
      'recensioni' => RecensioniAdmin(key: key, rest: rest),
      'clienti' => ClientiAdmin(key: key, rest: rest),
      'posta' => PostaAdmin(key: key, rest: rest, query: query),
      'statistiche' => StatisticheAdmin(key: key),
      _ => DashAdmin(key: key),
    };
  }
}

/// Accesso rapido ai dati per le sezioni
extension AdminCtx on BuildContext {
  Repo get repo => App.of(this).repo;
}
