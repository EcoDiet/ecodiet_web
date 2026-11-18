// Nettoyage et formatage des données texte d'une recette : fonctions pures,
// testables sans widget.

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

String fixMojibake(String input) {
  var s = input;
  const replacements = {
    "Ã¢â‚¬Â¢": "-",
    "Ã¢â‚¬â€œ": "-",
    "Ã¢â‚¬â€": "-",
    "Ã¢â‚¬Â": '"',
    "Ã¢â‚¬Å“": '"',
    "Ã¢â‚¬â„¢": "'",
    "ÃƒÂ©": "?",
    "ÃƒÂ¨": "?",
    "ÃƒÂª": "?",
    "ÃƒÂ«": "?",
    "ÃƒÂ ": "?",
    "ÃƒÂ¢": "?",
    "ÃƒÂ®": "?",
    "ÃƒÂ¯": "?",
    "ÃƒÂ´": "?",
    "ÃƒÂ¶": "?",
    "ÃƒÂ¹": "?",
    "ÃƒÂ»": "?",
    "ÃƒÂ¼": "?",
    "ÃƒÂ§": "?",
    "Ã…â€œ": "?",
    "Ã‚": "",
  };
  replacements.forEach((k, v) => s = s.replaceAll(k, v));
  return s;
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
          !RegExp(r'^pr[Ã©e]paration', caseSensitive: false).hasMatch(value))
      .map((value) => value
          .replaceFirst(
            RegExp(r'^(Ã©tape|etape)\s+\d+\s*', caseSensitive: false),
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
