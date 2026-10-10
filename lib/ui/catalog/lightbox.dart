/// Galleria foto a schermo intero: frecce, miniature, tastiera (← → Esc) e scorrimento col dito.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons.dart';
import '../../state/app_state.dart';
import '../kit.dart';

void showLightbox(BuildContext context, List<String> fotos, int start) {
  final s = App.read(context);
  showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xF208090E),
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (ctx, _, _) => App(state: s, child: _Lightbox(fotos: fotos, start: start)),
  );
}

class _Lightbox extends StatefulWidget {
  final List<String> fotos;
  final int start;
  const _Lightbox({required this.fotos, required this.start});
  @override
  State<_Lightbox> createState() => _LightboxState();
}

class _LightboxState extends State<_Lightbox> {
  late int i = widget.start;
  late final _page = PageController(initialPage: widget.start);
  final _focus = FocusNode();

  @override
  void dispose() {
    _page.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int d) {
    final n = widget.fotos.length;
    final k = (i + d + n) % n;
    _page.jumpToPage(k);
  }

  Widget _btn(String icon, VoidCallback onTap, String label) => Semantics(
        button: true,
        label: label,
        child: Hover(
          onTap: onTap,
          builder: (_, h) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: h ? .24 : .12), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: VIcon(icon, color: Colors.white, size: 22),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final f = widget.fotos;
    final single = f.length < 2;
    final narrow = MediaQuery.sizeOf(context).width <= 640;
    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        if (e.logicalKey == LogicalKeyboardKey.escape) Navigator.of(context).pop();
        if (e.logicalKey == LogicalKeyboardKey.arrowLeft && !single) _go(-1);
        if (e.logicalKey == LogicalKeyboardKey.arrowRight && !single) _go(1);
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(children: [
          Column(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: PageView.builder(
                  controller: _page,
                  itemCount: f.length,
                  onPageChanged: (k) => setState(() => i = k),
                  itemBuilder: (c, k) => Padding(
                    padding: narrow ? const EdgeInsets.fromLTRB(8, 64, 8, 8) : const EdgeInsets.fromLTRB(72, 56, 72, 12),
                    child: Center(child: GestureDetector(onTap: () {}, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: VImage(f[k], fit: BoxFit.contain)))),
                  ),
                ),
              ),
            ),
            if (!single)
              SizedBox(
                height: 80,
                child: Center(
                  child: ListView(
                    shrinkWrap: true,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (var k = 0; k < f.length; k++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => _page.jumpToPage(k),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Opacity(
                                opacity: k == i ? 1 : .5,
                                child: Container(
                                  width: 76,
                                  height: 56,
                                  decoration: BoxDecoration(border: Border.all(color: k == i ? Colors.white : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(8)),
                                  clipBehavior: Clip.antiAlias,
                                  child: VImage(f[k]),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ]),
          Positioned(top: 24, left: 24, child: Text('${i + 1} / ${f.length}', style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w600, fontSize: 16))),
          Positioned(top: 14, right: 14, child: _btn('x', () => Navigator.of(context).pop(), 'Chiudi')),
          if (!single) ...[
            Positioned(left: 14, top: narrow ? null : 0, bottom: narrow ? 90 : 80, child: Center(child: _btn('chevronLeft', () => _go(-1), 'Foto precedente'))),
            Positioned(right: 14, top: narrow ? null : 0, bottom: narrow ? 90 : 80, child: Center(child: _btn('chevronRight', () => _go(1), 'Foto successiva'))),
          ],
        ]),
      ),
    );
  }
}
