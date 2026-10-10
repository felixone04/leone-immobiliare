/// Finestre modali, conferme e richieste di testo (al posto di confirm() / prompt() del browser).
library;

import 'package:flutter/material.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'inputs.dart';
import 'kit.dart';

/// Finestra modale (.modal): titolo, pulsante di chiusura, contenuto scorrevole.
Future<T?> showVModal<T>(BuildContext context, String title, Widget Function(BuildContext ctx) body, {bool wide = false}) {
  final state = App.read(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Chiudi',
    barrierColor: const Color(0x800C1016),
    transitionDuration: const Duration(milliseconds: 150),
    transitionBuilder: (c, a, _, child) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, -.01), end: Offset.zero).animate(a), child: child)),
    pageBuilder: (ctx, _, _) => App(
      state: state,
      child: VT(
        theme: state.theme,
        child: Builder(builder: (ctx) {
          final t = ctx.t;
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 820 : 560, maxHeight: MediaQuery.sizeOf(ctx).height - 32),
                  child: Material(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(18),
                    elevation: 0,
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: t.shadowLg),
                      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(22, 14, 14, 14),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
                          child: Row(children: [
                            Expanded(child: Text(title, style: t.title(size: 20))),
                            IconBtn('x', tooltip: 'Chiudi', onPressed: () => Navigator.of(ctx).pop()),
                          ]),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                            child: DefaultTextStyle(style: t.text(), child: body(ctx)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

/// Conferma sì/no.
Future<bool> confirmDialog(BuildContext context, String text, {String ok = 'Conferma', bool danger = false}) async {
  final r = await showVModal<bool>(
    context,
    'Conferma',
    (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text, style: ctx.t.text(size: 16)),
      const SizedBox(height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        VButton('Annulla', kind: BtnKind.ghost, onPressed: () => Navigator.of(ctx).pop(false)),
        const SizedBox(width: 8),
        VButton(ok, kind: BtnKind.primary, danger: false, onPressed: () => Navigator.of(ctx).pop(true)),
      ]),
    ]),
  );
  return r ?? false;
}

/// Richiesta di un testo (null se annullata).
Future<String?> promptDialog(BuildContext context, String text, {String initial = '', String ok = 'Conferma'}) {
  final c = TextEditingController(text: initial);
  return showVModal<String>(
    context,
    'Conferma',
    (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(text, style: ctx.t.text()),
      const SizedBox(height: 12),
      VInput(controller: c, autofocus: true, onSubmitted: (_) => Navigator.of(ctx).pop(c.text)),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        VButton('Annulla', kind: BtnKind.ghost, onPressed: () => Navigator.of(ctx).pop()),
        const SizedBox(width: 8),
        VButton(ok, kind: BtnKind.primary, onPressed: () => Navigator.of(ctx).pop(c.text)),
      ]),
    ]),
  );
}

/// Area notifiche in basso al centro (.toasts)
class ToastHost extends StatelessWidget {
  const ToastHost({super.key});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context);
    final t = context.t;
    return ValueListenableBuilder<List<Toast>>(
      valueListenable: s.toasts,
      builder: (c, list, _) => Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: IgnorePointer(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final x in list)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(x.id),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 200),
                  builder: (c, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(color: x.err ? VTheme.danger : VTheme.dark, borderRadius: BorderRadius.circular(12), boxShadow: t.shadowLg),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        VIcon(x.err ? 'info' : 'check', color: x.err ? Colors.white : const Color(0xFF6EE7A8)),
                        const SizedBox(width: 10),
                        Flexible(child: Text(x.msg, style: t.text(color: Colors.white, weight: FontWeight.w500, height: 1.4))),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
