/// Briques communes de nettoyage des libellés venant des données.

/// Retire les guillemets parasites et normalise les espaces.
String stripQuotesAndSpaces(String value) {
  return value
      .replaceAll('"""', '')
      .replaceAll('"', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Libellé de type de plat homogène : minuscules, `_`/`-` remplacés par des
/// espaces, faute « apperitif » corrigée.
String normalizeTypeLabel(String rawType) {
  final normalized = rawType
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  if (normalized == 'apperitif') return 'aperitif';
  return normalized;
}
