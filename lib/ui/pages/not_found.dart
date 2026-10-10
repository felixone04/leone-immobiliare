import 'package:flutter/material.dart';

import '../kit.dart';
import '../shell.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) => PageScroll(children: [
        Contained(
          child: Padding(
            padding: pagePad(context),
            child: const EmptyState(
              icon: 'search',
              title: 'Pagina non trovata',
              text: 'Il link potrebbe essere errato o la pagina è stata rimossa.',
              actions: [VButton('Torna alla home', kind: BtnKind.primary, href: '#/')],
            ),
          ),
        ),
      ]);
}
