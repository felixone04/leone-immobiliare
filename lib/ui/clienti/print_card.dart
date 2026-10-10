/// Carta stampabile: viene "fotografata" e aperta in una finestra di stampa con solo la carta.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/platform/browser.dart';
import '../kit.dart';

class PrintableCard extends StatefulWidget {
  final Widget child;
  final String title;
  final Widget Function(VoidCallback print) actions;
  const PrintableCard({super.key, required this.child, required this.title, required this.actions});
  @override
  State<PrintableCard> createState() => _PrintableCardState();
}

class _PrintableCardState extends State<PrintableCard> {
  final _key = GlobalKey();

  Future<void> _print() async {
    final b = _key.currentContext?.findRenderObject();
    if (b is! RenderRepaintBoundary) return;
    final img = await b.toImage(pixelRatio: 3);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data != null) printImage(data.buffer.asUint8List(), widget.title);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: RepaintBoundary(key: _key, child: Padding(padding: const EdgeInsets.all(12), child: widget.child))),
        const Gap(22),
        widget.actions(_print),
      ]);
}
