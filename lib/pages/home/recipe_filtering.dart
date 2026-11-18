import '../../models/user.dart' show UserPreference;
import '../../utils/text_labels.dart';
import 'home_models.dart';

// Logique pure de recherche, filtrage, tri et recommandation des recettes
// de l'accueil : sans état ni widget, donc testable unitairement.

const List<String> fallbackIngredients = [
  'Poulet',
  'Tofu',
  'Tomate',
  'Courgette',
  'Œuf',
  'Riz',
  'Pâtes',
  'Fromage',
  'Poisson',
  'Lentilles',
];

const List<String> fallbackUtensils = [
  'Poêle',
  'Four',
  'Casserole',
  'Mixeur',
  'Cuiseur vapeur',
  'Wok',
  'Grill',
];

const List<String> fallbackDiets = [
  'Végétarien',
  'Végan',
  'Carnivore',
  'Pescétarien',
  'Sans gluten',
  'Sans lactose',
];

const List<String> fallbackAllergens = [
  'Gluten',
  'Lactose',
  'Arachides',
  'Fruits à coque',
  'Œufs',
  'Soja',
  'Poisson',
];

/// Libellé de filtre : sans accents, guillemets ni espaces superflus.
String asciiFilterLabel(String value) =>
    stripQuotesAndSpaces(normalizeAscii(value));

String normalizeAscii(String input) {
  var s = input;
  const repl = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'õ': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'œ': 'oe',
    'æ': 'ae',
    'Ã©': 'e',
    'Ã¨': 'e',
    'Ãª': 'e',
    'Ã«': 'e',
    'Ã ': 'a',
    'Ã¢': 'a',
    'Ã§': 'c',
    'Ã®': 'i',
    'Ã¯': 'i',
    'Ã´': 'o',
    'Ã¶': 'o',
    'Ã¹': 'u',
    'Ã»': 'u',
    'Ã¼': 'u',
    'Å“': 'oe',
  };
  repl.forEach((k, v) => s = s.replaceAll(k, v));
  return s;
}

String ingredientFilterLabel(String raw) {
  final cleaned = normalizeAscii(raw)
      .toLowerCase()
      .replaceAll('"', ' ')
      .replaceAll(RegExp(r'[0-9]+([.,][0-9]+)?'), ' ')
      .replaceAll(RegExp(r'[^a-z\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final canonicalIngredients = <String, String>{
    'poivre en grains': 'Poivre',
    'grains de poivre': 'Poivre',
    'grain poivre': 'Poivre',
    'grains poivre': 'Poivre',
    'poivre noir': 'Poivre',
    'poivre blanc': 'Poivre',
    'poivre': 'Poivre',
    'pommes de terre': 'Pomme de terre',
    'pomme de terre': 'Pomme de terre',
    'pois chiches': 'Pois chiches',
    'haricots verts': 'Haricots verts',
    'huile olive': 'Huile d olive',
    'huile dolive': 'Huile d olive',
    'pates': 'Pates',
    'pâtes': 'Pates',
    'nouilles': 'Nouilles',
    'spaghetti': 'Pates',
    'tagliatelles': 'Pates',
    'riz': 'Riz',
    'farine': 'Farine',
    'pain': 'Pain',
    'poulet': 'Poulet',
    'dinde': 'Dinde',
    'canard': 'Canard',
    'boeuf': 'Boeuf',
    'bœuf': 'Boeuf',
    'veau': 'Veau',
    'porc': 'Porc',
    'agneau': 'Agneau',
    'jambon': 'Jambon',
    'lardons': 'Lardons',
    'saucisse': 'Saucisse',
    'saumon': 'Saumon',
    'thon': 'Thon',
    'cabillaud': 'Cabillaud',
    'poisson': 'Poisson',
    'crevettes': 'Crevettes',
    'crevette': 'Crevettes',
    'oeufs': 'Oeuf',
    'oeuf': 'Oeuf',
    'œufs': 'Oeuf',
    'œuf': 'Oeuf',
    'tomates': 'Tomate',
    'tomate': 'Tomate',
    'courgettes': 'Courgette',
    'courgette': 'Courgette',
    'carottes': 'Carotte',
    'carotte': 'Carotte',
    'oignons': 'Oignon',
    'oignon': 'Oignon',
    'ail': 'Ail',
    'champignons': 'Champignon',
    'champignon': 'Champignon',
    'lentilles': 'Lentilles',
    'poireaux': 'Poireau',
    'poireau': 'Poireau',
    'aubergines': 'Aubergine',
    'aubergine': 'Aubergine',
    'poivrons': 'Poivron',
    'poivron': 'Poivron',
    'fromage': 'Fromage',
    'mozzarella': 'Mozzarella',
    'parmesan': 'Parmesan',
    'gruyère': 'Gruyere',
    'gruyere': 'Gruyere',
    'lait': 'Lait',
    'crème': 'Creme',
    'creme': 'Creme',
    'beurre': 'Beurre',
    'citron': 'Citron',
    'curry': 'Curry',
  };

  for (final entry in canonicalIngredients.entries) {
    final pattern = RegExp(
      '(^|\\s)${RegExp.escape(entry.key)}(\\s|\$)',
      caseSensitive: false,
    );
    if (pattern.hasMatch(cleaned)) return entry.value;
  }

  final stopWords = {
    'a',
    'au',
    'aux',
    'd',
    'de',
    'des',
    'du',
    'en',
    'et',
    'la',
    'le',
    'les',
    'ou',
    'un',
    'une',
    'g',
    'kg',
    'l',
    'cl',
    'ml',
    'cm',
    'cuillère',
    'cuillères',
    'café',
    'soupe',
    'verre',
    'verres',
    'bol',
    'bols',
    'boîte',
    'boîtes',
    'bouteille',
    'bouteilles',
    'bouquet',
    'branche',
    'branches',
    'gousse',
    'gousses',
    'pincée',
    'pincées',
    'sachet',
    'tranche',
    'tranches',
    'morceau',
    'morceaux',
    'environ',
    'denviron',
    'selon',
    'goût',
    'facultatif',
    'frais',
    'fraîche',
    'haché',
    'hachée',
    'émincé',
    'émincée',
    'fermier',
    'fermière',
    'coupé',
    'coupée',
  };

  final words = cleaned
      .split(' ')
      .map((word) => word.trim())
      .where((word) => word.length > 1 && !stopWords.contains(word))
      .toList();

  if (words.isEmpty) return '';
  final label = words.take(2).join(' ');
  return label[0].toUpperCase() + label.substring(1);
}

/// `query` doit déjà être en minuscules et sans espaces de bord.
bool matchesSearch(RecipeDisplayModel recipe, String query) {
  if (query.isEmpty) return true;
  final q = query;
  return recipe.title.toLowerCase().contains(q) ||
      recipe.category.toLowerCase().contains(q) ||
      recipe.ingredients.toLowerCase().contains(q) ||
      recipe.utensils.toLowerCase().contains(q) ||
      recipe.diets.toLowerCase().contains(q) ||
      recipe.allergens.toLowerCase().contains(q) ||
      recipe.occasions.toLowerCase().contains(q);
}

bool matchesFilters(RecipeDisplayModel recipe, RecipeFilters filters) {
  final ingredientTags = recipe.ingredients
      .split(',')
      .map(ingredientFilterLabel)
      .where((v) => v.isNotEmpty)
      .map((v) => v.toLowerCase())
      .toSet();
  final utensilText = normalizeAscii(recipe.utensils).toLowerCase();
  final dietText =
      normalizeAscii('${recipe.category} ${recipe.diets}').toLowerCase();
  final allergenText = normalizeAscii(recipe.allergens).toLowerCase();

  if (filters.ingredients.isNotEmpty &&
      !filters.ingredients.any((v) =>
          ingredientTags.contains(ingredientFilterLabel(v).toLowerCase()))) {
    return false;
  }

  if (filters.utensils.isNotEmpty &&
      !filters.utensils
          .any((v) => utensilText.contains(normalizeAscii(v).toLowerCase()))) {
    return false;
  }

  final duration = parseDurationMinutes(recipe.duration);
  if (filters.minTimeMinutes != null &&
      duration != null &&
      duration < filters.minTimeMinutes!) {
    return false;
  }
  if (filters.maxTimeMinutes != null &&
      duration != null &&
      duration > filters.maxTimeMinutes!) {
    return false;
  }

  if (filters.diets.isNotEmpty &&
      !filters.diets.any((v) =>
          matchesDiet(recipe, normalizeAscii(v).toLowerCase(), dietText))) {
    return false;
  }

  if (filters.allergens.isNotEmpty &&
      filters.allergens
          .any((v) => allergenText.contains(normalizeAscii(v).toLowerCase()))) {
    return false;
  }

  return true;
}

bool matchesDiet(RecipeDisplayModel recipe, String filter, String dietText) {
  final text =
      '${recipe.title} ${recipe.ingredients} ${recipe.category} ${recipe.diets}'
          .toLowerCase();
  final hasMeat = RegExp(
    r'(boeuf|b[œoe]uf|porc|poulet|dinde|agneau|veau|jambon|lardon|saucisse|steak|magret|canard|viande|hot ?dog|knack)',
  ).hasMatch(text);
  final hasFish = RegExp(
    r'(poisson|saumon|thon|cabillaud|truite|sole|crevette|fruits de mer|moule|saint jacques|st jacques)',
  ).hasMatch(text);
  final hasAnimalProducts =
      RegExp(r'(oeuf|œuf|lait|fromage|beurre|creme|crème|yaourt|miel)')
          .hasMatch(text);

  if (filter.contains('vegetar')) return !hasMeat && !hasFish;
  if (filter.contains('vegan') || filter.contains('végétalien')) {
    return !hasMeat && !hasFish && !hasAnimalProducts;
  }
  if (filter.contains('pesc')) return !hasMeat;
  return dietText.contains(filter);
}

int? parseDurationMinutes(String duration) {
  final match = RegExp(r'(\d+)').firstMatch(duration);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

List<Recipe> sortRecipes(List<Recipe> recipes, RecipeSortMode mode) {
  final sorted = [...recipes];
  switch (mode) {
    case RecipeSortMode.pertinence:
      return sorted;
    case RecipeSortMode.titreAsc:
      sorted.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      return sorted;
    case RecipeSortMode.titreDesc:
      sorted.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
      return sorted;
    case RecipeSortMode.tempsAsc:
      sorted.sort((a, b) {
        final aMin = parseDurationMinutes(a.duration) ?? 99999;
        final bMin = parseDurationMinutes(b.duration) ?? 99999;
        return aMin.compareTo(bMin);
      });
      return sorted;
    case RecipeSortMode.tempsDesc:
      sorted.sort((a, b) {
        final aMin = parseDurationMinutes(a.duration) ?? -1;
        final bMin = parseDurationMinutes(b.duration) ?? -1;
        return bMin.compareTo(aMin);
      });
      return sorted;
  }
}

/// Recettes compatibles avec les allergies/régime du profil et les régimes
/// choisis dans les filtres (`selectedDietFilters`). Retourne `source` si
/// rien ne correspond.
List<RecipeDisplayModel> buildRecommendedRecipes(
  List<RecipeDisplayModel> source,
  List<UserPreference> prefs, {
  Set<String> selectedDietFilters = const {},
}) {
  if (source.isEmpty) return const [];

  final blockedKeywords = <String>{};
  final regimeKeywords = <String>{};

  for (final p in prefs) {
    final label = normalizeAscii(p.label).toLowerCase();
    final values = normalizeAscii(p.value)
        .toLowerCase()
        .split(RegExp(r'[,;/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    if (label.contains('allerg') || label.contains('intoler')) {
      blockedKeywords.addAll(values);
    } else if (label.contains('regime') || label.contains('régime')) {
      regimeKeywords.addAll(values);
    }
  }

  bool violatesAllergens(RecipeDisplayModel r) {
    if (blockedKeywords.isEmpty) return false;
    final text =
        normalizeAscii('${r.allergens} ${r.ingredients}').toLowerCase();
    return blockedKeywords.any((k) => k.isNotEmpty && text.contains(k));
  }

  bool violatesRegime(RecipeDisplayModel r) {
    if (regimeKeywords.isEmpty) return false;
    final text = normalizeAscii(
      '${r.title} ${r.diets} ${r.category} ${r.ingredients} ${r.allergens}',
    ).toLowerCase();

    final vegetarian = regimeKeywords.any(
      (k) => k.contains('vegetar') || k.contains('végétar'),
    );
    final vegan = regimeKeywords.any(
      (k) => k.contains('vegan') || k.contains('végétalien'),
    );
    final pescetarian = regimeKeywords.any(
      (k) => k.contains('pesc') || k.contains('poisson'),
    );

    final hasMeat = RegExp(
      r'(boeuf|b[oe]uf|porc|poulet|dinde|agneau|veau|jambon|lardon|saucisse|viande|steak|charcut|hot ?dog|knack|lard|canard|magret)',
    ).hasMatch(text);
    final hasFish = RegExp(
      r'(thon|saumon|poisson|cabillaud|truite|sardine|anchois|fruits de mer|crevette|moule)',
    ).hasMatch(text);
    final hasAnimalProducts =
        RegExp(r'(oeuf|œuf|lait|fromage|beurre|creme|crème|yaourt|miel)')
            .hasMatch(text);

    if (vegetarian && hasMeat) return true;
    if (vegan && (hasMeat || hasAnimalProducts)) return true;
    if (pescetarian && hasMeat) return true;
    if (!pescetarian && vegetarian && hasFish) return true;
    return false;
  }

  // Si l'utilisateur a choisi un régime dans les filtres UI, on l'applique aussi ici.
  final selectedDiets =
      selectedDietFilters.map((d) => normalizeAscii(d).toLowerCase()).toSet();
  if (selectedDiets.any((d) => d.contains('vegetar'))) {
    regimeKeywords.add('vegetarien');
  }
  if (selectedDiets
      .any((d) => d.contains('vegan') || d.contains('vegetalien'))) {
    regimeKeywords.add('vegan');
  }
  if (selectedDiets.any((d) => d.contains('pesc'))) {
    regimeKeywords.add('pescetarien');
  }

  final filtered =
      source.where((r) => !violatesAllergens(r) && !violatesRegime(r)).toList();
  if (filtered.isNotEmpty) return filtered;
  return source;
}
