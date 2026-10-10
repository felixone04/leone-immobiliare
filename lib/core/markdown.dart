/// Markdown minimale come nella versione web: **grassetto**, *corsivo*, ## titoli, elenchi "- ".
/// Il testo viene sempre trattato come testo semplice: nessun HTML o codice viene interpretato.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

sealed class MdBlock {}

class MdHeading extends MdBlock {
  final int level;
  final String text;
  MdHeading(this.level, this.text);
}

class MdPara extends MdBlock {
  final List<String> lines;
  MdPara(this.lines);
}

class MdList extends MdBlock {
  final List<String> items;
  MdList(this.items);
}

List<MdBlock> parseMd(String? text) {
  final out = <MdBlock>[];
  var para = <String>[];
  List<String>? list;
  void flush() {
    if (para.isNotEmpty) out.add(MdPara(para));
    para = [];
  }

  void close() {
    if (list != null) out.add(MdList(list!));
    list = null;
  }

  for (final raw in (text ?? '').split(RegExp(r'\r?\n'))) {
    final t = raw.trim();
    if (t.isEmpty) {
      flush();
      close();
      continue;
    }
    final h = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(t);
    if (h != null) {
      flush();
      close();
      out.add(MdHeading(h.group(1)!.length + 1, h.group(2)!));
      continue;
    }
    final li = RegExp(r'^[-•*]\s+').firstMatch(t);
    if (li != null) {
      flush();
      (list ??= []).add(t.substring(li.end));
      continue;
    }
    close();
    para.add(t);
  }
  flush();
  close();
  return out;
}

/// Grassetto e corsivo in linea.
List<InlineSpan> inlineMd(String s, TextStyle base, {Color? strongColor}) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
  var i = 0;
  for (final m in re.allMatches(s)) {
    if (m.start > i) spans.add(TextSpan(text: s.substring(i, m.start)));
    if (m.group(1) != null) {
      spans.add(TextSpan(text: m.group(1), style: TextStyle(fontWeight: FontWeight.w700, color: strongColor)));
    } else {
      spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
    }
    i = m.end;
  }
  if (i < s.length) spans.add(TextSpan(text: s.substring(i)));
  return spans;
}

/// Blocco di testo formattato (classe .prose).
class Prose extends StatelessWidget {
  final String? text;
  final double size;
  final double maxWidth;
  const Prose(this.text, {super.key, this.size = 16.6, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    final t = VT.of(context);
    final base = t.text(size: size, color: t.ink2, height: 1.6);
    final blocks = parseMd(text);
    final children = <Widget>[];
    for (var k = 0; k < blocks.length; k++) {
      final b = blocks[k];
      final first = k == 0;
      switch (b) {
        case MdHeading():
          final sz = b.level == 2 ? t.h2(context) : (b.level == 3 ? 20.0 : 17.0);
          children.add(Padding(
            padding: EdgeInsets.only(top: first ? 0 : sz * 1.4, bottom: sz * .5),
            child: Text.rich(TextSpan(children: inlineMd(b.text, base)), style: t.title(size: sz)),
          ));
        case MdPara():
          children.add(Padding(
            padding: EdgeInsets.only(bottom: size),
            child: Text.rich(TextSpan(children: inlineMd(b.lines.join('\n'), base, strongColor: t.ink)), style: base),
          ));
        case MdList():
          children.add(Padding(
            padding: EdgeInsets.only(bottom: size, left: size * .2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final it in b.items)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: size * .3),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: EdgeInsets.only(top: size * .62, right: size * .65),
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle)),
                      ),
                      Expanded(child: Text.rich(TextSpan(children: inlineMd(it, base, strongColor: t.ink)), style: base)),
                    ]),
                  ),
              ],
            ),
          ));
      }
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}
