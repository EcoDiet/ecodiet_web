// Nettoyage et formatage des données texte d'une recette : fonctions pures,
// testables sans widget.

import 'dart:convert';

import '../../utils/text_labels.dart';

String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  return '${hours}h${remainingMinutes > 0 ? " ${remainingMinutes}min" : ""}';
}

String formatTypeLabel(String rawType) =>
    normalizeTypeLabel(displayLabel(rawType));

/// Libellé affichable : accents conservés, mojibake corrigé, guillemets et
/// espaces superflus retirés.
String displayLabel(String value) => stripQuotesAndSpaces(fixMojibake(value));

/// Répare un texte UTF-8 relu par erreur en Windows-1252 (« Ã© » → « é »,
/// « â€™ » → « ' »), y compris encodé deux fois. Les puces et guillemets
/// typographiques sont ramenés à leur forme simple.
String fixMojibake(String input) {
  // « à » mal encodé dont l'espace insécable est devenue une espace simple.
  var s = input.replaceAll(RegExp('Ã {1,2}'), 'à ');
  for (var i = 0; i < 3; i++) {
    final repaired = s.replaceAllMapped(_mojibakeRun, _repairRun);
    if (repaired == s) break;
    s = repaired;
  }
  return s
      .replaceAll(RegExp('[•–—]'), '-')
      .replaceAll(RegExp('[“”]'), '"')
      .replaceAll('’', "'");
}

/// Suites typiques : un octet de tête UTF-8 (Â–ô) suivi d'octets de
/// continuation lus comme caractères Windows-1252.
final _mojibakeRun = RegExp(
  '(?:[\u00C2-\u00F4]'
  '[\u0080-\u00BF\u0152\u0153\u0160\u0161\u0178\u017D\u017E\u0192\u02C6'
  '\u02DC\u2013\u2014\u2018-\u201E\u2020-\u2022\u2026\u2030\u2039\u203A'
  '\u20AC\u2122]+)+',
);

/// Caractères Windows-1252 de la plage 0x80–0x9F ; les autres caractères
/// valent leur code Latin-1.
const _cp1252 = {
  '€': 0x80, '‚': 0x82, 'ƒ': 0x83, '„': 0x84, '…': 0x85, '†': 0x86, //
  '‡': 0x87, 'ˆ': 0x88, '‰': 0x89, 'Š': 0x8A, '‹': 0x8B, 'Œ': 0x8C, //
  'Ž': 0x8E, '‘': 0x91, '’': 0x92, '“': 0x93, '”': 0x94, '•': 0x95, //
  '–': 0x96, '—': 0x97, '˜': 0x98, '™': 0x99, 'š': 0x9A, '›': 0x9B, //
  'œ': 0x9C, 'ž': 0x9E, 'Ÿ': 0x9F,
};

/// Ré-encode la suite en octets puis la relit en UTF-8 ; la laisse telle
/// quelle si le résultat n'est pas de l'UTF-8 valide.
String _repairRun(Match m) {
  final run = m[0]!;
  final bytes = <int>[];
  for (final rune in run.runes) {
    final byte = _cp1252[String.fromCharCode(rune)] ?? rune;
    if (byte > 0xFF) return run;
    bytes.add(byte);
  }
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return run;
  }
}

/// Découpe le champ `etapes` brut (JSON-like ou texte) en étapes lisibles.
List<String> parseInstructions(String raw) {
  if (raw.trim().isEmpty) return [];

  final text = cleanEtapesText(raw);
  return text
      .split(RegExp(r'\n+'))
      .map(displayLabel)
      .where((value) => value.isNotEmpty)
      .where((value) =>
          !RegExp(r'^pr[ée]paration', caseSensitive: false).hasMatch(value))
      .map((value) => value
          .replaceFirst(
            RegExp(r'^(étape|etape)\s+\d+\s*', caseSensitive: false),
            '',
          )
          .trim())
      .where((value) => value.isNotEmpty)
      .toList();
}

String cleanEtapesText(String raw) {
  var text = raw.trim();
  if (text.startsWith('[') && text.endsWith(']')) {
    text = text.substring(1, text.length - 1).trim();
  }

  return text
      .replaceAll('\r\n', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(RegExp(r'''['"]\s*,\s*['"]'''), '\n')
      .replaceAll('""', '"')
      .replaceAll(RegExp(r'''^\s*['"]+'''), '')
      .replaceAll(RegExp(r'''['"]+\s*$'''), '')
      .trim();
}

/// Difficulté estimée d'après la durée (en minutes).
String difficultyLabel(int duree) {
  if (duree <= 15) return 'Facile';
  if (duree <= 30) return 'Moyen';
  return 'Difficile';
}
