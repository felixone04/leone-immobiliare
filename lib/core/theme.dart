/// Tema grafico Leone Immobiliare: bianco, nero e azzurro del marchio, linee nette.
/// I colori principale e secondario si possono cambiare da Area riservata → Impostazioni.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'util.dart';

/// Tutti i "token" grafici, calcolati dai colori scelti nelle impostazioni.
@immutable
class VTheme {
  final Color primary, accent, onPrimary, onAccent, primarySoft, primaryDark;
  final double logoH;

  static const ok = Color(0xFF1F7A4D);
  static const warn = Color(0xFFB25E09);
  static const danger = Color(0xFFB42318);
  static const okSoft = Color(0xFFE3F4EA);
  static const warnSoft = Color(0xFFFDF0E1);
  static const errSoft = Color(0xFFFDECEA);
  static const mutedSoft = Color(0xFFEEF0F2);
  static const dark = Color(0xFF1B1F24);

  /// Colori del marchio
  static const leoneBlu = Color(0xFF0189EE);
  static const leoneNero = Color(0xFF0B0D10);

  // Fondi, testi e linee
  final Color bg = const Color(0xFFF5F7FA);
  final Color surface = Colors.white;
  final Color ink = leoneNero;
  final Color ink2 = const Color(0xFF3A4049);
  final Color muted = const Color(0xFF6B7280);
  final Color line = const Color(0xFFE3E7EC);
  final Color line2 = const Color(0xFFCDD3DA);

  /// Area riservata, righe di tabelle e riquadri
  final Color adminBg = const Color(0xFFEEF1F5);
  final Color tint = const Color(0xFFF8FAFC);
  final Color tint2 = const Color(0xFFF0F3F7);

  // Forme: angoli netti, pulsanti e campi leggermente arrotondati
  final double radius = 10, radiusSm = 6, btnRadius = 6, pill = 4, controlRadius = 8;

  // Caratteri: testi in Inter, titoli in Arimo (metriche di Arial, come "Leone" nel logo)
  final String font = 'Inter', fontTitoli = 'Arial';

  final List<BoxShadow> shadowSm = const [BoxShadow(color: Color(0x0F14181E), blurRadius: 2, offset: Offset(0, 1))];
  final List<BoxShadow> shadow = const [
    BoxShadow(color: Color(0x0D0B1A2E), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x2E0B1A2E), blurRadius: 32, spreadRadius: -16, offset: Offset(0, 14)),
  ];
  final List<BoxShadow> shadowLg = const [BoxShadow(color: Color(0x4D0B1A2E), blurRadius: 60, spreadRadius: -20, offset: Offset(0, 24))];

  VTheme._({required this.primary, required this.accent, required this.logoH})
      : onPrimary = contrastOn(primary),
        onAccent = contrastOn(accent),
        primarySoft = mix(primary, .09, Colors.white),
        primaryDark = mix(primary, .78, Colors.black);

  factory VTheme.from(Json settings) => VTheme._(
        primary: hexColor(settings['colorePrimario'], leoneBlu),
        accent: hexColor(settings['coloreAccento'], leoneNero),
        logoH: math.min(90, math.max(24, doubleOf(settings['logoAltezza'], 44))),
      );

  /// Piè di pagina: nero del marchio con dettagli nel colore principale
  Color get footerBg => leoneNero;

  BorderRadius get r => BorderRadius.circular(radius);
  BorderRadius get rSm => BorderRadius.circular(radiusSm);

  TextStyle text({double size = 16, FontWeight weight = FontWeight.w400, Color? color, double height = 1.55, double? spacing}) =>
      TextStyle(fontFamily: font, fontSize: size, fontWeight: weight, color: color ?? ink, height: height, letterSpacing: spacing);

  TextStyle title({double size = 24, FontWeight? weight, Color? color, double height = 1.2, double? spacing}) => TextStyle(
        fontFamily: fontTitoli,
        fontSize: size,
        fontWeight: weight ?? FontWeight.w700,
        color: color ?? ink,
        height: height,
        letterSpacing: spacing ?? -.03 * size,
      );

  /// Etichette maiuscole piccole (es. "CONTRATTO", "FILTRI"): riprendono la scritta "IMMOBILIARE"
  /// del logo, con carattere geometrico e lettere spaziate.
  TextStyle caps({double size = 12.8, Color? color}) =>
      TextStyle(fontFamily: 'Jost', fontSize: size * 1.05, fontWeight: FontWeight.w500, color: color ?? muted, letterSpacing: .14 * size, height: 1.3);

  /// clamp(min, base + vw, max) del CSS
  static double clampVw(BuildContext c, double min, double base, double vw, double max) {
    final w = MediaQuery.sizeOf(c).width;
    return (base + w * vw / 100).clamp(min, max);
  }

  double h1(BuildContext c) => clampVw(c, 28.8, 20.8, 2, 41.6);
  double h2(BuildContext c) => clampVw(c, 22.4, 18.4, 1, 30.4);

  ThemeData material() {
    final scheme = ColorScheme.fromSeed(seedColor: primary, primary: primary, secondary: accent, surface: surface);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: font,
      textTheme: ThemeData.light().textTheme.apply(fontFamily: font, bodyColor: ink, displayColor: ink),
      textSelectionTheme: TextSelectionThemeData(cursorColor: primary, selectionColor: primary.withValues(alpha: .2)),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(6)),
        textStyle: text(size: 12.5, color: Colors.white, height: 1.3),
        waitDuration: const Duration(milliseconds: 400),
      ),
      scrollbarTheme: const ScrollbarThemeData(thickness: WidgetStatePropertyAll(8)),
    );
  }
}

/// Rende disponibile il tema a tutti i widget: `VT.of(context)`.
class VT extends InheritedWidget {
  final VTheme theme;
  const VT({super.key, required this.theme, required super.child});

  static VTheme of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<VT>()!.theme;

  @override
  bool updateShouldNotify(VT old) => old.theme != theme;
}

/// Larghezza della finestra, per i "media query" del CSS.
extension Viewport on BuildContext {
  double get vw => MediaQuery.sizeOf(this).width;
  double get vh => MediaQuery.sizeOf(this).height;
  VTheme get t => VT.of(this);
}
