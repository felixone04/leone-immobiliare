/// Account dei clienti: accesso e registrazione, preferiti, ricerche salvate ("la casa che cerco"),
/// immobili per te e dati personali (#/account, #/account/preferiti, #/account/ricerche, #/account/dati).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../core/util.dart';
import '../../data/abbinamento.dart';
import '../../data/preset.dart';
import '../../data/repository.dart';
import '../../state/app_state.dart';
import '../admin/form/vform.dart';
import '../catalog/item_card.dart';
import '../dialogs.dart';
import '../forms_public.dart';
import '../inputs.dart';
import '../kit.dart';
import '../shell.dart';

/* ================= Preferiti ================= */

/// Cuore per salvare un immobile tra i preferiti (chiede di accedere se serve).
class PreferitoBtn extends StatelessWidget {
  final String itemId;
  final double size;
  const PreferitoBtn(this.itemId, {super.key, this.size = 38});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final on = s.repo.preferito(itemId);
    return Semantics(
      button: true,
      label: on ? 'Togli dai preferiti' : 'Salva tra i preferiti',
      child: Tooltip(
        message: on ? 'Togli dai preferiti' : 'Salva tra i preferiti',
        child: Hover(
          onTap: () => cambiaPreferito(context, itemId),
          builder: (_, h) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), shape: BoxShape.circle, boxShadow: t.shadowSm),
            child: VIcon('heart', size: size * .5, filled: on, color: on || h ? VTheme.danger : t.ink),
          ),
        ),
      ),
    );
  }
}

Future<void> cambiaPreferito(BuildContext context, String itemId) async {
  final s = App.read(context);
  if (s.repo.cliente == null && !await apriAccesso(context, motivo: 'Accedi o crea un account gratuito per salvare i tuoi immobili preferiti e ritrovarli sempre.')) return;
  final ora = await s.run(() => s.repo.preferitoCambia(itemId));
  if (ora != null) s.toast(ora ? 'Salvato tra i preferiti' : 'Tolto dai preferiti');
}

/* ================= Accesso e registrazione ================= */

/// Finestra di accesso; restituisce true se il cliente ha effettuato l'accesso.
Future<bool> apriAccesso(BuildContext context, {String? motivo}) async {
  final ok = await showVModal<bool>(context, 'Il tuo account', (ctx) => AccessoForm(motivo: motivo, onFatto: () => Navigator.of(ctx).pop(true)));
  return ok == true;
}

class AccessoForm extends StatefulWidget {
  final String? motivo;
  final VoidCallback onFatto;
  final bool registrati;
  const AccessoForm({super.key, required this.onFatto, this.motivo, this.registrati = false});
  @override
  State<AccessoForm> createState() => _AccessoFormState();
}

class _AccessoFormState extends State<AccessoForm> {
  late var _nuovo = widget.registrati;
  final _nome = TextEditingController(), _email = TextEditingController(), _tel = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  var _privacy = false, _consenso = false, _tentato = false;
  String? _err;

  @override
  void dispose() {
    for (final c in [_nome, _email, _tel, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _invia() async {
    final s = App.read(context);
    setState(() {
      _tentato = true;
      _err = null;
    });
    try {
      if (_nuovo) {
        if (!_privacy) throw const AppError("Accetta l'informativa per creare l'account");
        if (_pw.text != _pw2.text) throw const AppError('Le due password non coincidono');
        await s.repo.clienteRegistra({'nome': _nome.text, 'email': _email.text, 'telefono': _tel.text, 'password': _pw.text, 'consenso': _consenso});
        s.toast('Account creato: benvenuto!');
      } else {
        await s.repo.clienteAccedi(_email.text, _pw.text);
        s.toast('Bentornato!');
      }
      widget.onFatto();
    } on AppError catch (e) {
      if (mounted) setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inv = _tentato;
    return AutofillGroup(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (widget.motivo != null) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(widget.motivo!, style: t.text(color: t.ink2))),
        SegButtons(
          options: const [('accedi', 'Accedi'), ('nuovo', 'Crea un account')],
          value: _nuovo ? 'nuovo' : 'accedi',
          onChanged: (v) => setState(() {
            _nuovo = v == 'nuovo';
            _err = null;
            _tentato = false;
          }),
        ),
        const Gap(16),
        if (_nuovo) ...[
          FieldLabel('Nome e cognome', child: VInput(controller: _nome, autofill: const [AutofillHints.name], invalid: inv && _nome.text.trim().isEmpty)),
          const Gap(12),
        ],
        TwoCols(
          FieldLabel('Email', child: VInput(controller: _email, keyboard: TextInputType.emailAddress, autofill: const [AutofillHints.email], invalid: inv && !validEmail(_email.text.trim()))),
          _nuovo
              ? FieldLabel('Telefono (facoltativo)', child: VInput(controller: _tel, keyboard: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber]))
              : FieldLabel('Password', child: VInput(controller: _pw, obscure: true, autofill: const [AutofillHints.password], onSubmitted: (_) => _invia())),
        ),
        if (_nuovo) ...[
          const Gap(12),
          TwoCols(
            FieldLabel('Password', hint: 'Almeno 8 caratteri, con lettere e numeri', child: VInput(controller: _pw, obscure: true, autofill: const [AutofillHints.newPassword])),
            FieldLabel('Ripeti la password', child: VInput(controller: _pw2, obscure: true, autofill: const [AutofillHints.newPassword], onSubmitted: (_) => _invia())),
          ),
          const Gap(14),
          VCheck(
            value: _consenso,
            onChanged: (v) => setState(() => _consenso = v),
            label: const Text('Voglio ricevere via email nuovi immobili e offerte (facoltativo, puoi cambiare idea in ogni momento)'),
          ),
          const Gap(8),
          PrivacyCheck(value: _privacy, onChanged: (v) => setState(() => _privacy = v), scopo: "per creare l'account", invalid: inv && !_privacy),
        ],
        const Gap(10),
        FormError(_err),
        const Gap(10),
        VButton(_nuovo ? 'Crea account' : 'Accedi', icon: _nuovo ? 'user' : 'lock', kind: BtnKind.primary, size: BtnSize.lg, block: true, onAsync: _invia),
      ]),
    );
  }
}

/* ================= Pagina "Il mio account" ================= */

const _kSchede = [('per-te', 'bell', 'Immobili per te'), ('preferiti', 'heart', 'Preferiti'), ('ricerche', 'bookmark', 'Ricerche salvate'), ('dati', 'user', 'I miei dati')];

class AccountPage extends StatelessWidget {
  final String tab;
  const AccountPage({super.key, this.tab = ''});

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final c = s.repo.cliente;
    if (c == null) {
      return PageScroll(children: [
        const PageHero('Il tuo account', slim: true),
        Contained(
          child: Padding(
            padding: pagePad(context),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CardBox(
                  padding: const EdgeInsets.all(28),
                  shadow: t.shadow,
                  child: AccessoForm(
                    motivo: 'Salva i tuoi immobili preferiti e descrivi la casa che cerchi: ti avvisiamo noi appena ne arriva una adatta.',
                    registrati: tab == 'ricerche' || tab == 'preferiti',
                    onFatto: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ]);
    }
    final scheda = _kSchede.any((x) => x.$1 == tab) ? tab : 'per-te';
    final nuove = s.repo.notificheNuove(c);
    final contatori = {'per-te': nuove, 'preferiti': strList(c['preferiti']).length, 'ricerche': s.repo.ricercheDi(c).length};
    return PageScroll(children: [
      PageHero('Ciao ${str(c['nome']).split(' ').first}', slim: true),
      Contained(
        child: Padding(
          padding: pagePad(context),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (k, ic, l) in _kSchede)
                Hover(
                  onTap: () => context.go(k == 'per-te' ? '/account' : '/account/$k'),
                  builder: (_, h) {
                    final on = k == scheda;
                    final n = contatori[k] ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: on ? t.primary : (h ? t.primarySoft : t.surface), border: Border.all(color: on ? t.primary : t.line), borderRadius: t.rSm),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        VIcon(ic, color: on ? t.onPrimary : t.primary),
                        const SizedBox(width: 8),
                        Text(l, style: t.text(weight: FontWeight.w600, color: on ? t.onPrimary : t.ink, height: 1.3)),
                        if (n > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: k == 'per-te' ? VTheme.danger : (on ? t.onPrimary : t.primarySoft), borderRadius: BorderRadius.circular(999)),
                            child: Text('$n', style: t.text(size: 12, weight: FontWeight.w800, color: k == 'per-te' ? Colors.white : t.primary, height: 1.4)),
                          ),
                        ],
                      ]),
                    );
                  },
                ),
            ]),
            const Gap(28),
            switch (scheda) {
              'preferiti' => _Preferiti(c),
              'ricerche' => _Ricerche(c),
              'dati' => _Dati(c, key: ValueKey(c['id'])),
              _ => _PerTe(c),
            },
          ]),
        ),
      ),
    ]);
  }
}

/// Immobili che corrispondono alle ricerche salvate (i nuovi sono evidenziati).
class _PerTe extends StatefulWidget {
  final Json c;
  const _PerTe(this.c);
  @override
  State<_PerTe> createState() => _PerTeState();
}

class _PerTeState extends State<_PerTe> {
  late final Set<String> _nuovi = {for (final n in jsonList(widget.c['notifiche'])) if (n['letta'] != true) str(n['immobile'])};

  @override
  void initState() {
    super.initState();
    // visti: le notifiche nuove diventano lette (restano evidenziate finché si resta nella pagina)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) App.read(context).repo.notificheSegnaLette();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final ricerche = s.repo.ricercheDi(widget.c);
    if (ricerche.isEmpty) {
      return EmptyState(
        icon: 'bookmark',
        title: 'Descrivi la casa che cerchi',
        text: 'Indica zona, budget, metri quadri e quello che non può mancare: ti mostriamo gli immobili adatti e ti avvisiamo via email quando ne arriva uno nuovo.',
        actions: [VButton('Crea la tua ricerca', icon: 'plus', kind: BtnKind.primary, onPressed: () => apriRicerca(context))],
      );
    }
    // per ogni immobile il miglior abbinamento tra tutte le ricerche
    final migliori = <String, (Json, Abbinamento, Json)>{};
    for (final r in ricerche) {
      for (final (i, a) in s.repo.abbinamentiPer(jsonOf(r['criteri']))) {
        final id = i['id'] as String;
        if (migliori[id] == null || a.punteggio > migliori[id]!.$2.punteggio) migliori[id] = (i, a, r);
      }
    }
    final lista = migliori.values.toList()
      ..sort((x, y) {
        final n = (_nuovi.contains(y.$1['id']) ? 1 : 0).compareTo(_nuovi.contains(x.$1['id']) ? 1 : 0);
        return n != 0 ? n : y.$2.punteggio.compareTo(x.$2.punteggio);
      });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(
        title: lista.isEmpty ? 'Ancora nessun immobile adatto' : '${lista.length} ${lista.length == 1 ? 'immobile adatto' : 'immobili adatti'} a te',
        subtitle: 'In base alle tue ricerche salvate. Ti avvisiamo via email quando ne arriva uno nuovo che corrisponde ad almeno il 70% di quello che cerchi, anche fino al 10% sopra il budget.',
        trailing: VButton('Le mie ricerche', icon: 'bookmark', kind: BtnKind.outline, href: '#/account/ricerche'),
      ),
      if (lista.isEmpty)
        const EmptyState(icon: 'search', small: true, text: 'Al momento nessun annuncio corrisponde: appena ne arriva uno ti scriviamo.')
      else
        // come l'elenco immobili: schede alla stessa altezza per riga (sui telefoni una per riga)
        AutoGrid(minWidth: context.vw <= 640 ? 9999 : 290, gap: 24, children: [
          for (final (i, a, r) in lista)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (_nuovi.contains(i['id'])) const Pill('Nuovo per te', tone: 'err', icon: 'bell'),
                  Pill('${a.percentuale}% · ${r['nome']}', tone: 'plain'),
                  if (a.sopraBudget) const Pill('Sopra il budget', tone: 'warn'),
                ]),
              ),
              Expanded(child: ItemCard(i)),
              if (a.mancano.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Non corrisponde: ${a.mancano.join(', ')}', style: t.text(size: 13.1, color: t.muted))),
            ]),
        ]),
    ]);
  }
}

class _Preferiti extends StatelessWidget {
  final Json c;
  const _Preferiti(this.c);
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final pref = s.repo.preferitiDi(c);
    if (pref.isEmpty) {
      return const EmptyState(
        icon: 'heart',
        title: 'Nessun preferito',
        text: 'Tocca il cuore sugli annunci che ti piacciono: li ritrovi qui, sempre.',
        actions: [VButton('Guarda gli immobili', kind: BtnKind.primary, href: '#/catalogo')],
      );
    }
    final disp = pref.where(immobileDisponibile).toList(), altri = pref.where((i) => !immobileDisponibile(i)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(title: 'I tuoi preferiti', subtitle: '${pref.length} ${pref.length == 1 ? 'immobile salvato' : 'immobili salvati'}'),
      if (disp.isNotEmpty) CardsGrid(disp),
      if (altri.isNotEmpty) ...[
        const Gap(32),
        SectionHead(title: 'Non più disponibili', subtitle: 'Venduti, affittati o in trattativa: li teniamo qui per tuo promemoria.'),
        CardsGrid(altri),
      ],
    ]);
  }
}

class _Ricerche extends StatelessWidget {
  final Json c;
  const _Ricerche(this.c);
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final ricerche = s.repo.ricercheDi(c);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHead(
        title: 'La casa che cerchi',
        subtitle: 'Ti avvisiamo via email quando arriva un immobile che corrisponde ad almeno il 70% di quello che cerchi, anche se costa fino al 10% in più del tuo budget.',
        trailing: ricerche.length < kMaxRicerche ? VButton('Nuova ricerca', icon: 'plus', kind: BtnKind.primary, onPressed: () => apriRicerca(context)) : null,
      ),
      if (ricerche.isEmpty)
        EmptyState(icon: 'bookmark', small: true, text: 'Nessuna ricerca salvata.', actions: [VButton('Crea la tua ricerca', icon: 'plus', kind: BtnKind.primary, onPressed: () => apriRicerca(context))])
      else
        for (final r in ricerche)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CardBox(
              child: Builder(builder: (context) {
                final trovati = s.repo.abbinamentiPer(jsonOf(r['criteri']));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(str(r['nome']), style: t.title(size: 18.4)),
                        const Gap(4),
                        Text(descriviCriteri(jsonOf(r['criteri'])), style: t.text(size: 14.4, color: t.muted)),
                      ]),
                    ),
                    IconBtn('edit', tooltip: 'Modifica', onPressed: () => apriRicerca(context, ricerca: r)),
                    IconBtn('trash', tooltip: 'Elimina', danger: true, onPressed: () async {
                      if (await confirmDialog(context, 'Eliminare la ricerca «${r['nome']}»? Non riceverai più avvisi per questa ricerca.', danger: true, ok: 'Elimina')) {
                        await s.run(() => s.repo.ricercaElimina(r['id'] as String));
                      }
                    }),
                  ]),
                  const Gap(12),
                  Text(
                    trovati.isEmpty ? 'Nessun immobile disponibile corrisponde, per ora: ti avvisiamo appena arriva.' : '${trovati.length} ${trovati.length == 1 ? 'immobile disponibile corrisponde' : 'immobili disponibili corrispondono'}:',
                    style: t.text(size: 14.4, weight: FontWeight.w600),
                  ),
                  for (final (i, a) in trovati.take(4)) ItemRow(i, nota: '${a.percentuale}% di quello che cerchi${a.sopraBudget ? ' · un po\' sopra il budget' : ''}'),
                  if (trovati.length > 4) Align(alignment: Alignment.centerLeft, child: LinkArrow('Vedili tutti', '#/account')),
                ]);
              }),
            ),
          ),
    ]);
  }
}

class _Dati extends StatefulWidget {
  final Json c;
  const _Dati(this.c, {super.key});
  @override
  State<_Dati> createState() => _DatiState();
}

class _DatiState extends State<_Dati> {
  late final _nome = TextEditingController(text: str(widget.c['nome'])), _tel = TextEditingController(text: str(widget.c['telefono']));
  final _pwAtt = TextEditingController(), _pw = TextEditingController();
  late var _consenso = boolOf(widget.c['consenso']);
  String? _err, _errPw;

  @override
  void dispose() {
    for (final c in [_nome, _tel, _pwAtt, _pw]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const BoxTitle('I tuoi dati', icon: 'user'),
            TwoCols(FieldLabel('Nome e cognome', child: VInput(controller: _nome)), FieldLabel('Telefono', child: VInput(controller: _tel, keyboard: TextInputType.phone))),
            const Gap(12),
            FieldLabel('Email', child: Text(str(widget.c['email']), style: t.text(weight: FontWeight.w600))),
            const Gap(14),
            VSwitch(value: _consenso, onChanged: (v) => setState(() => _consenso = v), label: 'Ricevi via email nuovi immobili e offerte'),
            const Gap(10),
            FormError(_err),
            const Gap(8),
            Align(
              alignment: Alignment.centerLeft,
              child: VButton('Salva', icon: 'check', kind: BtnKind.primary, onAsync: () async {
                setState(() => _err = null);
                try {
                  await s.repo.clienteAggiorna({'nome': _nome.text, 'telefono': _tel.text, 'consenso': _consenso});
                  s.toast('Dati salvati');
                } on AppError catch (e) {
                  setState(() => _err = e.message);
                }
              }),
            ),
          ]),
        ),
        const Gap(20),
        CardBox(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const BoxTitle('Password', icon: 'lock'),
            TwoCols(
              FieldLabel('Password attuale', child: VInput(controller: _pwAtt, obscure: true, autofill: const [AutofillHints.password])),
              FieldLabel('Nuova password', hint: 'Almeno 8 caratteri, con lettere e numeri', child: VInput(controller: _pw, obscure: true, autofill: const [AutofillHints.newPassword])),
            ),
            const Gap(10),
            FormError(_errPw),
            const Gap(8),
            Align(
              alignment: Alignment.centerLeft,
              child: VButton('Cambia password', icon: 'lock', onAsync: () async {
                setState(() => _errPw = null);
                try {
                  await s.repo.clienteCambiaPassword(_pwAtt.text, _pw.text);
                  _pwAtt.clear();
                  _pw.clear();
                  s.toast('Password cambiata');
                } on AppError catch (e) {
                  setState(() => _errPw = e.message);
                }
              }),
            ),
          ]),
        ),
        const Gap(20),
        Wrap(spacing: 10, runSpacing: 10, children: [
          VButton('Esci', icon: 'logout', onAsync: () async {
            await s.repo.clienteEsci();
            if (context.mounted) context.go('/');
          }),
          VButton('Elimina il mio account', icon: 'trash', kind: BtnKind.ghost, danger: true, onAsync: () async {
            if (!await confirmDialog(context, 'Eliminare definitivamente il tuo account, con preferiti e ricerche salvate?', danger: true, ok: 'Elimina')) return;
            await s.repo.clienteElimina();
            s.toast('Account eliminato');
            if (context.mounted) context.go('/');
          }),
        ]),
      ]),
    );
  }
}

/* ================= "La casa che cerco" ================= */

/// Campi del modulo di ricerca, con le scelte prese dal catalogo.
List<FieldDef> ricercaDefs(Repo repo) {
  final sch = repo.schema;
  List<Opt> opzioni(String campo) => sch.campo(campo)?.options ?? const [];
  final citta = {for (final i in repo.items) str(i['citta'])}.where((c) => c.isNotEmpty).toList()..sort();
  return [
    const FieldDef('nome', 'Dai un nome alla ricerca', wide: true, gruppo: 'La casa che cerchi', placeholder: 'es. Casa per la famiglia, Monolocale in centro…'),
    FieldDef('contratto', 'Cerchi', type: 'select', required: true, noEmpty: true, options: [const Opt('Vendita', 'Da comprare'), const Opt('Affitto', 'In affitto')]),
    const FieldDef('budget', 'Budget massimo', type: 'money', unit: '€', step: 1000, hint: 'Ti avvisiamo anche per immobili fino al 10% sopra il budget'),
    FieldDef('tipologie', 'Tipologia', type: 'checks', wide: true, options: opzioni('tipologia')),
    FieldDef('citta', 'Città', type: 'checks', wide: true, gruppo: 'Dove', options: opts(citta)),
    const FieldDef('zona', 'Zone o quartieri', wide: true, placeholder: 'es. Isola, Porta Romana', hint: 'Separati da virgola'),
    const FieldDef('mqMin', 'Superficie minima', type: 'number', unit: 'm²', min: 0, gruppo: 'Spazi'),
    const FieldDef('localiMin', 'Locali (almeno)', type: 'number', min: 0, step: 1),
    const FieldDef('camereMin', 'Camere (almeno)', type: 'number', min: 0, step: 1),
    const FieldDef('bagniMin', 'Bagni (almeno)', type: 'number', min: 0, step: 1),
    FieldDef('esterno', 'Spazio esterno (uno di questi)', type: 'checks', wide: true, gruppo: 'Cosa non può mancare', options: opzioni('spazioEsterno')),
    const FieldDef('parcheggio', 'Posto auto o box', type: 'bool'),
    FieldDef('dotazioni', 'Dotazioni', type: 'checks', wide: true, options: opzioni('dotazioni')),
    FieldDef('condizioni', 'Condizioni', type: 'checks', wide: true, options: opzioni('stato')),
  ];
}

/// Criteri di ricerca dai filtri dell'elenco immobili ("Salva questa ricerca").
Json criteriDaFiltri(Map<String, String> st) {
  final park = st['parcheggio'] ?? '';
  return {
    'contratto': st['contratto'] ?? '',
    if ((st['tipologia'] ?? '').isNotEmpty) 'tipologie': [st['tipologia']],
    if ((st['citta'] ?? '').isNotEmpty) 'citta': [st['citta']],
    if ((st['zona'] ?? '').isNotEmpty) 'zona': st['zona'],
    if (numOrNull(st['prezzo_max']) != null) 'budget': numOrNull(st['prezzo_max']),
    if (numOrNull(st['mq_min']) != null) 'mqMin': numOrNull(st['mq_min']),
    if (numOrNull(st['locali']) != null) 'localiMin': numOrNull(st['locali']),
    if (numOrNull(st['camere']) != null) 'camereMin': numOrNull(st['camere']),
    if (numOrNull(st['bagni']) != null) 'bagniMin': numOrNull(st['bagni']),
    if ((st['esterno'] ?? '').isNotEmpty && st['esterno'] != '*') 'esterno': [st['esterno']],
    if (park.isNotEmpty && park != 'Nessuno') 'parcheggio': true,
    if ((st['stato'] ?? '').isNotEmpty) 'condizioni': [st['stato']],
    if ((st['dotazioni'] ?? '').isNotEmpty) 'dotazioni': st['dotazioni']!.split('|'),
  };
}

/// Crea o modifica una ricerca salvata (chiede di accedere se serve).
Future<void> apriRicerca(BuildContext context, {Json? ricerca, Json? criteri}) async {
  final s = App.read(context);
  if (s.repo.cliente == null && !await apriAccesso(context, motivo: 'Accedi o crea un account gratuito: salviamo la tua ricerca e ti avvisiamo appena arriva un immobile adatto.')) return;
  if (!context.mounted) return;
  await showVModal<void>(context, ricerca == null ? 'La casa che cerchi' : 'Modifica la ricerca', (ctx) => _RicercaForm(ricerca: ricerca, criteri: criteri, ctx: ctx), wide: true);
}

class _RicercaForm extends StatefulWidget {
  final Json? ricerca, criteri;
  final BuildContext ctx;
  const _RicercaForm({this.ricerca, this.criteri, required this.ctx});
  @override
  State<_RicercaForm> createState() => _RicercaFormState();
}

class _RicercaFormState extends State<_RicercaForm> {
  late final s = App.read(context);
  late final ctrl = FormCtrl(ricercaDefs(s.repo), {
    'contratto': 'Vendita',
    ...widget.criteri ?? jsonOf(widget.ricerca?['criteri']),
    'nome': widget.ricerca == null ? '' : str(widget.ricerca!['nome']),
  });
  String? _err;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!ctrl.validate()) return;
    final v = ctrl.vals;
    try {
      final r = await s.repo.ricercaSalva(v, id: widget.ricerca?['id'] as String?, nome: str(v['nome']));
      final n = s.repo.abbinamentiPer(jsonOf(r['criteri'])).length;
      s.toast(n == 0 ? 'Ricerca salvata: ti avvisiamo appena arriva un immobile adatto' : 'Ricerca salvata: ${n == 1 ? 'un immobile corrisponde' : '$n immobili corrispondono'} già');
      if (widget.ctx.mounted) Navigator.of(widget.ctx).pop();
      if (mounted) GoRouter.of(context).go('/account/ricerche');
    } on AppError catch (e) {
      setState(() => _err = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(
        'Indica solo quello che conta per te: ti mostriamo gli immobili adatti e ti scriviamo quando ne arriva uno che corrisponde ad almeno il 70% delle richieste.',
        style: t.text(size: 14.4, color: t.ink2),
      ),
      const Gap(16),
      VFormView(ctrl, groups: true),
      FormError(_err),
      const Gap(12),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        VButton('Annulla', kind: BtnKind.ghost, onPressed: () => Navigator.of(widget.ctx).pop()),
        const SizedBox(width: 8),
        VButton('Salva la ricerca', icon: 'bookmark', kind: BtnKind.primary, onAsync: _salva),
      ]),
    ]);
  }
}

/* ================= Pulsante account nell'intestazione ================= */

/// "Accedi" oppure il nome del cliente, con il numero di immobili nuovi per lui.
class AccountBtn extends StatelessWidget {
  final bool compatto;
  const AccountBtn({super.key, this.compatto = false});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    final c = s.repo.cliente;
    final nuove = s.repo.notificheNuove(c);
    final pref = strList(c?['preferiti']).length;
    Widget badge(int n) => Positioned(
          right: -4,
          top: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18),
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: VTheme.danger, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 1.5)),
            child: Text('$n', style: t.text(size: 10.5, weight: FontWeight.w800, color: Colors.white, height: 1)),
          ),
        );
    Widget bottone(String icona, String? testo, String path, String tip, {int n = 0, Color? colore}) => Tooltip(
          message: tip,
          child: Hover(
            onTap: () => context.go(path),
            builder: (_, h) => Stack(clipBehavior: Clip.none, children: [
              Container(
                height: compatto ? 42 : 46,
                padding: EdgeInsets.symmetric(horizontal: testo == null ? 0 : 14),
                width: testo == null ? (compatto ? 42 : 46) : null,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: h ? t.primary : t.line2), borderRadius: BorderRadius.circular(t.controlRadius)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  VIcon(icona, color: colore ?? (h ? t.primary : t.ink), filled: colore != null),
                  if (testo != null) ...[const SizedBox(width: 8), Text(testo, style: t.text(weight: FontWeight.w700, color: h ? t.primary : t.ink, height: 1.2))],
                ]),
              ),
              if (n > 0) badge(n),
            ]),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (c != null) ...[
        bottone('heart', null, '/account/preferiti', 'I miei preferiti', colore: pref > 0 ? VTheme.danger : null),
        const SizedBox(width: 8),
      ],
      bottone('user', compatto ? null : (c == null ? 'Accedi' : str(c['nome']).split(' ').first), '/account', c == null ? 'Accedi o crea un account' : 'Il mio account', n: nuove),
    ]);
  }
}
