/// Tema grafico del sito: stessi valori delle variabili CSS (--primary, --radius, …) e dei 5 temi.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'util.dart';

class TemaInfo {
  final String nome, desc;
  const TemaInfo(this.nome, this.desc);
}

const Map<String, TemaInfo> kTemi = {
  'leone': TemaInfo('Leone', 'Bianco, nero e azzurro del marchio, linee nette'),
  'classico': TemaInfo('Classico', 'Pulito e rassicurante, angoli morbidi'),
  'elegante': TemaInfo('Elegante', 'Titoli con grazie, linee sottili, molto spazio'),
  'moderno': TemaInfo('Moderno', 'Forme arrotondate, titoli grandi e decisi'),
  'minimal': TemaInfo('Minimal', 'Essenziale, angoli vivi, bianco e nero'),
};

/// Tutti i "token" grafici, calcolati dai colori scelti dall'azienda e dal tema.
@immutable
class VTheme {
  final String tema;
  final Color primary, accent, onPrimary, onAccent, primarySoft, primaryDark;
  final Color bg, surface, ink, ink2, muted, line, line2;
  final double radius, radiusSm, btnRadius;
  final String font, fontTitoli;
  final List<BoxShadow> shadowSm, shadow, shadowLg;
  final double logoH;

  static const ok = Color(0xFF1F7A4D);
  static const warn = Color(0xFFB25E09);
  static const danger = Color(0xFFB42318);
  static const okSoft = Color(0xFFE3F4EA);
  static const warnSoft = Color(0xFFFDF0E1);
  static const errSoft = Color(0xFFFDECEA);
  static const mutedSoft = Color(0xFFEEF0F2);
  static const dark = Color(0xFF1B1F24);
  static const footer = Color(0xFF13171B);

  /// Colori del marchio Leone Immobiliare
  static const leoneBlu = Color(0xFF0189EE);
  static const leoneNero = Color(0xFF0B0D10);

  const VTheme._({
    required this.tema,
    required this.primary,
    required this.accent,
    required this.onPrimary,
    required this.onAccent,
    required this.primarySoft,
    required this.primaryDark,
    required this.bg,
    required this.surface,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.line2,
    required this.radius,
    required this.radiusSm,
    required this.btnRadius,
    required this.font,
    required this.fontTitoli,
    required this.shadowSm,
    required this.shadow,
    required this.shadowLg,
    required this.logoH,
  });

  factory VTheme.from(Json settings) {
    final tema = kTemi.containsKey(settings['tema']) ? settings['tema'] as String : 'leone';
    final p = hexColor(settings['colorePrimario'], leoneBlu);
    final a = hexColor(settings['coloreAccento'], leoneNero);
    const sh = [BoxShadow(color: Color(0x0D14181E), blurRadius: 2, offset: Offset(0, 1)), BoxShadow(color: Color(0x3814181E), blurRadius: 30, spreadRadius: -14, offset: Offset(0, 10))];
    const shLg = [BoxShadow(color: Color(0x5914181E), blurRadius: 60, spreadRadius: -20, offset: Offset(0, 24))];
    const shSm = [BoxShadow(color: Color(0x0F14181E), blurRadius: 2, offset: Offset(0, 1))];
    final base = (
      bg: const Color(0xFFF7F6F3),
      ink: const Color(0xFF1B1F24),
      line: const Color(0xFFE7E4DE),
      line2: const Color(0xFFD8D4CC),
      radius: 14.0,
      radiusSm: 9.0,
      btnRadius: 999.0,
      font: 'PlusJakartaSans',
      titoli: 'PlusJakartaSans',
      shadow: sh,
      shadowLg: shLg,
    );
    var t = base;
    switch (tema) {
      case 'leone':
        t = (
          bg: const Color(0xFFF5F7FA), ink: leoneNero, line: const Color(0xFFE3E7EC), line2: const Color(0xFFCDD3DA),
          radius: 10.0, radiusSm: 6.0, btnRadius: 6.0, font: 'Inter', titoli: 'Arial',
          shadow: const [BoxShadow(color: Color(0x0D0B1A2E), blurRadius: 3, offset: Offset(0, 1)), BoxShadow(color: Color(0x2E0B1A2E), blurRadius: 32, spreadRadius: -16, offset: Offset(0, 14))],
          shadowLg: const [BoxShadow(color: Color(0x4D0B1A2E), blurRadius: 60, spreadRadius: -20, offset: Offset(0, 24))],
        );
      case 'elegante':
        t = (
          bg: const Color(0xFFFAF8F4), ink: base.ink, line: base.line, line2: base.line2,
          radius: 4.0, radiusSm: 3.0, btnRadius: 2.0, font: 'Jost', titoli: 'CormorantGaramond',
          shadow: const [BoxShadow(color: Color(0x0A14181E), blurRadius: 2, offset: Offset(0, 1)), BoxShadow(color: Color(0x3314181E), blurRadius: 30, spreadRadius: -18, offset: Offset(0, 12))],
          shadowLg: shLg,
        );
      case 'moderno':
        t = (
          bg: const Color(0xFFF4F5F8), ink: base.ink, line: base.line, line2: base.line2,
          radius: 24.0, radiusSm: 14.0, btnRadius: 999.0, font: 'Inter', titoli: 'Sora',
          shadow: const [BoxShadow(color: Color(0x0D14181E), blurRadius: 6, offset: Offset(0, 2)), BoxShadow(color: Color(0x4714181E), blurRadius: 40, spreadRadius: -20, offset: Offset(0, 18))],
          shadowLg: shLg,
        );
      case 'minimal':
        t = (
          bg: const Color(0xFFFFFFFF), ink: const Color(0xFF111111), line: const Color(0xFFE5E5E5), line2: const Color(0xFFCFCFCF),
          radius: 0.0, radiusSm: 0.0, btnRadius: 0.0, font: 'Inter', titoli: 'SpaceGrotesk',
          shadow: const <BoxShadow>[],
          shadowLg: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, spreadRadius: -10, offset: Offset(0, 10))],
        );
    }
    return VTheme._(
      tema: tema,
      primary: p,
      accent: a,
      onPrimary: contrastOn(p),
      onAccent: contrastOn(a),
      primarySoft: mix(p, .09, Colors.white),
      primaryDark: mix(p, .78, Colors.black),
      bg: t.bg,
      surface: Colors.white,
      ink: t.ink,
      ink2: tema == 'leone' ? const Color(0xFF3A4049) : const Color(0xFF454C55),
      muted: const Color(0xFF6B7280),
      line: t.line,
      line2: t.line2,
      radius: t.radius,
      radiusSm: t.radiusSm,
      btnRadius: t.btnRadius,
      font: t.font,
      fontTitoli: t.titoli,
      shadowSm: shSm,
      shadow: t.shadow,
      shadowLg: t.shadowLg,
      logoH: math.min(90, math.max(24, doubleOf(settings['logoAltezza'], 44))),
    );
  }

  bool get minimal => tema == 'minimal';
  bool get elegante => tema == 'elegante';
  bool get moderno => tema == 'moderno';
  bool get leone => tema == 'leone';

  /// Piè di pagina: nero del marchio con dettagli azzurri nel tema Leone
  Color get footerBg => leone ? leoneNero : footer;
  Color get footerAccent => leone ? primary : accent;
  Color get onFooterAccent => leone ? onPrimary : onAccent;

  /// Fondi neutri di area riservata, tabelle e riquadri (grigi freddi nel tema Leone)
  Color get adminBg => leone ? const Color(0xFFEEF1F5) : const Color(0xFFF2F1ED);
  Color get tint => leone ? const Color(0xFFF8FAFC) : const Color(0xFFFBFAF8);
  Color get tint2 => leone ? const Color(0xFFF0F3F7) : const Color(0xFFF4F3F0);

  /// Sfondo delle fasce "colorate" (intestazione delle pagine, numeri)
  Color get heroBg => minimal ? const Color(0xFF111111) : primary;
  Color get onHero => minimal ? Colors.white : onPrimary;

  /// Colore del prezzo in evidenza
  Color get priceColor => minimal ? const Color(0xFF111111) : primary;

  /// Pulsante principale (il tema minimal lo vuole nero)
  Color get btnPrimaryBg => minimal ? const Color(0xFF111111) : primary;
  Color get btnPrimaryFg => minimal ? Colors.white : onPrimary;

  BorderRadius get r => BorderRadius.circular(radius);
  BorderRadius get rSm => BorderRadius.circular(radiusSm);

  /// Raggio di "pillole" (badge, chip): 999 salvo i temi che le vogliono squadrate.
  double get pill => minimal ? 0 : (elegante ? 2 : (leone ? 4 : 999));
  double get controlRadius => minimal ? 0 : (elegante ? 3 : (leone ? 8 : 999));

  TextStyle text({double size = 16, FontWeight weight = FontWeight.w400, Color? color, double height = 1.55, double? spacing}) =>
      TextStyle(fontFamily: font, fontSize: size, fontWeight: weight, color: color ?? ink, height: height, letterSpacing: spacing);

  TextStyle title({double size = 24, FontWeight? weight, Color? color, double height = 1.2, double? spacing}) => TextStyle(
        fontFamily: fontTitoli,
        fontSize: size,
        fontWeight: weight ?? (elegante ? FontWeight.w600 : (minimal || leone ? FontWeight.w700 : FontWeight.w800)),
        color: color ?? ink,
        height: height,
        letterSpacing: spacing ?? (elegante ? 0 : (moderno ? -.035 * size : (minimal || leone ? -.03 * size : -.015 * size))),
      );

  /// Etichette maiuscole piccole (es. "CONTRATTO", "FILTRI").
  /// Nel tema Leone riprendono la scritta "IMMOBILIARE" del logo: carattere geometrico e lettere spaziate.
  TextStyle caps({double size = 12.8, Color? color, FontWeight weight = FontWeight.w700, double spacing = .06}) => leone
      ? TextStyle(fontFamily: 'Jost', fontSize: size * 1.05, fontWeight: FontWeight.w500, color: color ?? muted, letterSpacing: .14 * size, height: 1.3)
      : text(size: size, weight: weight, color: color ?? muted, spacing: spacing * size, height: 1.3);

  /// clamp(min, base + vw, max) del CSS
  static double clampVw(BuildContext c, double min, double base, double vw, double max) {
    final w = MediaQuery.sizeOf(c).width;
    return (base + w * vw / 100).clamp(min, max);
  }

  double h1(BuildContext c) => elegante ? clampVw(c, 35.2, 25.6, 2.4, 51.2) : clampVw(c, 28.8, 20.8, 2, 41.6);
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
