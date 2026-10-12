/// Utilità comuni: formattazione di numeri, prezzi e date, testo normalizzato, colori.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';

typedef Json = Map<String, dynamic>;

/// Errore "previsto" con un messaggio da mostrare all'utente (equivalente di InvalidArgumentException).
class AppError implements Exception {
  final String message;
  const AppError(this.message);
  @override
  String toString() => message;
}

/* ---------------- Valori ---------------- */

bool isEmptyValue(Object? v) => v == null || (v is String && v.isEmpty) || (v is List && v.isEmpty);

String str(Object? v) => v == null ? '' : (v is double && v == v.roundToDouble() ? v.toInt().toString() : v.toString());

num? numOrNull(Object? v) {
  if (v is num) return v;
  if (v is String && v.trim().isNotEmpty) return num.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

int intOf(Object? v, [int def = 0]) => numOrNull(v)?.toInt() ?? def;
double doubleOf(Object? v, [double def = 0]) => numOrNull(v)?.toDouble() ?? def;
bool boolOf(Object? v) => v == true || v == 1 || v == '1' || v == 'true';
List<String> strList(Object? v) => v is List ? v.map((e) => str(e)).where((e) => e.isNotEmpty).toList() : <String>[];
Json jsonOf(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Json> jsonList(Object? v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Json>[];

/// Copia profonda di dati JSON (mappe e liste annidate).
/// jsonDecode restituisce sempre `List<dynamic>`: le liste tipizzate (es. `List<Json>`) vanno ricostruite.
T cloneJson<T>(T v) {
  final c = jsonDecode(jsonEncode(v));
  if (c is List && c is! T) {
    if (<Json>[] is T) return jsonList(c) as T;
    if (<String>[] is T) return c.map((e) => '$e').toList() as T;
  }
  return c as T;
}

/* ---------------- Testo ---------------- */

const _accenti = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
};

/// Minuscolo e senza accenti (per le ricerche).
String norm(Object? s) {
  final low = str(s).toLowerCase();
  final b = StringBuffer();
  for (final ch in low.split('')) {
    b.write(_accenti[ch] ?? ch);
  }
  return b.toString();
}

String slugify(String s) {
  final out = norm(s).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  return out.isEmpty ? 'pagina' : out;
}

final _rnd = Random.secure();

/// Identificativo casuale (16 caratteri esadecimali, come nuovo_id() in PHP).
String newId([int bytes = 8]) => List.generate(bytes, (_) => _rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

String uid() => DateTime.now().millisecondsSinceEpoch.toRadixString(36) + newId(3);

/// Link consentiti nei contenuti (blocca javascript: e simili).
String safeUrl(Object? u) {
  final s = str(u).trim();
  if (s.isEmpty) return '';
  return RegExp(r'^(https?:|mailto:|tel:|#|/|\./)', caseSensitive: false).hasMatch(s) ? s : '#';
}

/// Sorgenti d'immagine consentite: asset dell'app, immagini caricate (media:) e indirizzi web.
String safeSrc(Object? u) {
  final s = str(u).trim();
  return RegExp(r'^(https?:|assets/|media:)', caseSensitive: false).hasMatch(s) ? s : '';
}

String onlyDigits(String s) => s.replaceAll(RegExp(r'\D'), '');
String telHref(String s) => s.replaceAll(RegExp(r'[^\d+]'), '');

/// Numero WhatsApp: senza "+", con prefisso 39 se manca (cellulari italiani).
String waNumber(String tel) {
  final t = telHref(tel).replaceFirst(RegExp(r'^\+'), '');
  return t.startsWith('3') && t.length <= 10 ? '39$t' : t;
}

bool validEmail(String s) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s);
bool validPhone(String s) => RegExp(r'^[\d +().-]{6,20}$').hasMatch(s);

String cut(String s, int max) => s.length > max ? s.substring(0, max) : s;

/* ---------------- Numeri e prezzi ---------------- */

final _num = NumberFormat.decimalPattern('it');

String fmtNum(num n) => _num.format(n);

String fmtPrice(num n) {
  final dec = n % 1 != 0;
  return NumberFormat.currency(locale: 'it', symbol: '€', decimalDigits: dec ? 2 : 0).format(n);
}

String shortPrice(num n) {
  if (n >= 1e6) {
    var s = (n / 1e6).toStringAsFixed(n % 1e6 != 0 ? 2 : 0).replaceAll('.', ',');
    s = s.replaceFirst(RegExp(r',?0+$'), '');
    return '$s mln €';
  }
  if (n >= 10000) return '${(n / 1000).round()}k €';
  return fmtPrice(n);
}


/* ---------------- Date ---------------- */

String isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String oggi() => isoDate(DateTime.now());

DateTime parseDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

bool validIsoDate(String s) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s)) return false;
  final d = parseDate(s);
  return isoDate(d) == s;
}

String addDays(String s, int n) {
  final d = parseDate(s);
  return isoDate(DateTime(d.year, d.month, d.day + n));
}


/// "mercoledì 8 ottobre" (come toLocaleDateString con weekday long, day numeric, month long)
String fmtDate(String iso, [String pattern = 'EEEE d MMMM']) => DateFormat(pattern, 'it').format(parseDate(iso));

/// "8 ott, 10:42"
String fmtWhen(int ms) => DateFormat('d MMM, HH:mm', 'it').format(DateTime.fromMillisecondsSinceEpoch(ms));

String nowStamp() => DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

int nowMs() => DateTime.now().millisecondsSinceEpoch;

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

int? hm(String s) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  return h < 24 && mi < 60 ? h * 60 + mi : null;
}

String fmtHm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

String durata(int m) => m >= 60 ? '${m ~/ 60} h${m % 60 != 0 ? ' ${m % 60} min' : ''}' : '$m min';

/* ---------------- Colori ---------------- */

Color hexColor(Object? hex, [Color def = const Color(0xFF1D4E5A)]) {
  final m = RegExp(r'^#?([\da-fA-F]{6})$').firstMatch(str(hex));
  if (m == null) return def;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Testo leggibile sopra un colore (stessa formula della versione web).
Color contrastOn(Color c) {
  double lin(double v) => v <= .03928 ? v / 12.92 : pow((v + .055) / 1.055, 2.4).toDouble();
  final l = .2126 * lin(c.r) + .7152 * lin(c.g) + .0722 * lin(c.b);
  return l > .42 ? const Color(0xFF15191D) : const Color(0xFFFFFFFF);
}

/// Equivalente di color-mix(in srgb, a p%, b)
Color mix(Color a, double p, Color b) => Color.lerp(b, a, p)!;
