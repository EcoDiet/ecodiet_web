import 'dart:math';

import '../../models/taste_profile.dart';
import '../../models/user.dart' show UserPreference;
import '../../utils/text_labels.dart';
import '../home/home_models.dart';
import '../home/recipe_filtering.dart';

// Les swipes (verdict, vote) sont des données stockées : ils vivent dans le
// modèle, réexportés ici pour les pages du swipe.
export '../../models/taste_profile.dart'
    show SwipeVerdict, SwipeVerdictWeight, SwipeVote;

// Logique pure du swipe de goûts : choix des cartes, construction du profil
// et score des recettes. Sans état ni widget, donc testable unitairement.

/// Nombre de cartes proposées par session de swipe.
const int kSwipeDeckSize = 12;

/// Contraintes strictes du profil appliquées au choix des cartes.
class SwipeConstraints {
  /// Mots-clés (ASCII, minuscules) interdits dans les allergènes/ingrédients.
  final Set<String> blockedKeywords;

  /// Régime minimal exigé (`null` : pas de contrainte).
  final DietLevel? minDiet;

  const SwipeConstraints({this.blockedKeywords = const {}, this.minDiet});
}

// ── Caractéristiques d'une recette ──────────────────────────────────────────

/// Ingrédients trop courants pour dire quelque chose des goûts.
/// Comparé aux clés de `ingredientKey` (ASCII, singulier).
const Set<String> _staples = {
  'sel',
  'gros sel',
  'fleur de sel',
  'poivre',
  'sel et poivre',
  'sel poivre',
  'poivre du moulin',
  'eau',
  'huile',
  'huile d olive',
  'huile de tournesol',
  'huile vegetale',
  'sucre',
};

// ── Nettoyage des ingrédients ───────────────────────────────────────────────
//
// Les libellés bruts ressemblent à « "2 cuillères à café d huile dolive" »
// ou « 350 g de poulet coupé en dés » : on garde « Huile d'olive » et
// « Poulet ».

// `\b` ignore les lettres accentuées en Dart : on borne les mots à la main.
const _l = r"a-zà-ÿœ";
const _b = "(?<![$_l])"; // début de mot
const _e = "(?![$_l])"; // fin de mot

/// Unités toujours suivies de l'ingrédient (« 2 gousses d ail »).
const _size =
    "petite?s?|petits|grande?s?|grosses?|gros|moyen(ne)?s?|bonne?s?|belles?|beaux?|"
    "rases?|bomb[ée]es?|pleines?|g[ée]n[ée]reuse?s?";

final _unitPrefix = RegExp(
  "^(($_size) )?(cuill[eè]res?|c\\.? ?[àa] ?[sc]\\.?|cs|cc|kg|mg|gr|grammes?|g|ml|cl|dl|l|litres?|"
  "verres?|bols?|tasses?|bo[iî]tes?|bouteilles?|sachets?|pinc[ée]es?|gousses?|"
  "tranches?|morceaux?|bouquets?|branches?|brins?|poign[ée]es?|rouleaux?|"
  "pots?|paquets?|barquettes?|briques?|cubes?|doses?|louches?|blocs?)$_e"
  "( ($_size))?( [àa] (soupe|caf[ée]|th[ée]))?( ($_size))?$_e ?",
);

/// Mots qui ne sont une unité que suivis de « de » (« une noix de beurre »,
/// mais « noix » seule est un ingrédient).
final _unitBeforeDe = RegExp(
  "^(noix|noisettes?|feuilles?|filets?|bottes?|zestes?|traits?|tiges?|"
  "t[eê]tes?|grappes?|quartiers?|lamelles?|d[ée]s) (?=(de|d|du|des)$_e)",
);

final _article =
    RegExp("^(un|une|des|du|de la|de l|de|d|l|le|la|les|quelques)$_e ?");

/// Fin de libellé à couper : précisions, découpe, quantités secondaires.
final _descriptor = RegExp(
  "\\s*([,(;:]|$_b(ou|soit|environ|finement|grossi[eè]rement|"
  "coup[ée]e?s?|hach[ée]e?s?|[ée]minc[ée]e?s?|r[âa]p[ée]e?s?|pel[ée]e?s?|"
  "moulue?s?|pil[ée]e?s?|fondue?s?|ramollie?s?|concass[ée]e?s?|piqu[ée]e?s?|"
  "pr[ée]par[ée]e?s?|mix[ée]e?s?|dilu[ée]e?s?|tremp[ée]e?s?|roul[ée]e?s?|pr[ée]cuite?s?|"
  "entiers?|enti[eè]res?|plut[ôo]t|dans|au go[uû]t|[àa] votre go[uû]t|"
  "moyen(ne)?s?|bien fra[iî]che?s?|"
  "en (d[ée]s|rondelles|morceaux|lamelles|tranches|cubes|conserve|poudre|bo[iî]te)|"
  "de taille|selon|facultatif|pour (la|le|les|l)|[àa] temp[ée]rature|"
  "bien m[uû]re?s?|de pr[ée]f[ée]rence|si possible|type)$_e).*\$",
);

final _elision = RegExp("$_b([dl]) (?=[aeiouyhéèêàâîôû])");

/// Libellé d'ingrédient lisible, accents conservés (« Huile d'olive »).
/// Chaîne vide si rien d'exploitable (« 8 kg »).
String ingredientDisplayName(String raw) {
  // Apostrophes remplacées par des espaces pour simplifier les motifs ;
  // les données en ont déjà perdu (« d huile dolive », « denviron »).
  var s = stripQuotesAndSpaces(raw)
      .toLowerCase()
      .replaceAll(RegExp("['’`]"), ' ')
      .replaceAllMapped(
          RegExp("${_b}d(olive|auvergne|ail|oignon|agneau)$_e"), (m) => 'd ${m[1]}')
      .replaceAll(RegExp("${_b}denviron$_e"), 'environ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Quantités, unités et articles en tête, parfois répétés (« 1 kg 500 g de »).
  for (var i = 0; i < 6; i++) {
    final before = s;
    s = s
        .replaceFirst(RegExp(r'^[\d½¼¾⅓⅔.,/x×\s-]+'), '')
        .replaceFirst(_unitPrefix, '')
        .replaceFirst(_unitBeforeDe, '')
        .replaceFirst(_article, '')
        .trim();
    if (s == before) break;
  }

  s = s.replaceFirst(_descriptor, '').trim();
  // Quantité secondaire après le nom (« filet mignon de porc de 600 g »).
  s = s.replaceFirst(RegExp("($_b(de|d|à|a))? ?\\d.*\$"), '').trim();
  s = s.replaceAllMapped(_elision, (m) => "${m[1]}'");
  if (s.length < 2 || RegExp(r'\d').hasMatch(s)) return '';
  return s[0].toUpperCase() + s.substring(1);
}

/// Ligne d'ingrédient complète pour la fiche détaillée, quantité comprise
/// (« 2 cuillères à café d'huile d'olive »). Vide pour les fragments sans
/// ingrédient (« si possible) », « 8 kg »), issus du découpage des données.
String ingredientLine(String raw) {
  if (ingredientDisplayName(raw).isEmpty) return '';
  var s = stripQuotesAndSpaces(raw)
      .replaceAll(RegExp("['’`]"), ' ')
      .replaceAllMapped(RegExp("${_b}d(olive|auvergne|ail|oignon|agneau)$_e"),
          (m) => 'd ${m[1]}')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  s = s.replaceAllMapped(
      RegExp("$_b([dlDL]) (?=[aeiouyhéèêàâîôûAEIOUYH])"), (m) => "${m[1]}'");
  // Parenthèse ouverte par le découpage des données : on la referme.
  if (s.contains('(') && !s.contains(')')) s = '$s)';
  return s[0].toUpperCase() + s.substring(1);
}

/// Lignes d'ingrédients de la fiche détaillée (fragments et doublons retirés).
List<String> recipeIngredientLines(RecipeDisplayModel recipe) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in recipe.ingredients.split(',')) {
    final line = ingredientLine(raw);
    if (line.isEmpty || !seen.add(line.toLowerCase())) continue;
    out.add(line);
  }
  return out;
}

/// Aperçu des ingrédients pour une carte : noms seuls, sans quantités ni
/// doublons (« Ail, Huile d'olive, Persil »).
String recipeIngredientSummary(RecipeDisplayModel recipe) {
  final seen = <String>{};
  final names = <String>[];
  for (final raw in recipe.ingredients.split(',')) {
    final name = ingredientDisplayName(raw);
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    names.add(name);
  }
  return names.join(', ');
}

/// Liste lisible d'une colonne « a, b, c » des données (ustensiles,
/// allergènes, occasions) : `fruits_a_coque` → « Fruits a coque »,
/// « 1 hachoir » → « Hachoir ».
List<String> recipeTagList(String raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final part in raw.split(',')) {
    var s = stripQuotesAndSpaces(part)
        .replaceAll('_', ' ')
        .replaceFirst(RegExp(r'^\d+\s+'), '')
        .trim();
    if (s.isEmpty || !seen.add(s.toLowerCase())) continue;
    s = _accentedTags[s.toLowerCase()] ?? s;
    out.add(s[0].toUpperCase() + s.substring(1));
  }
  return out;
}

/// Libellés des tables de référence stockés sans accents.
const Map<String, String> _accentedTags = {
  'fruits a coque': 'Fruits à coque',
  'crustaces': 'Crustacés',
  'oeuf': 'Œufs',
  'celeri': 'Céleri',
  'sesame': 'Sésame',
  'noel': 'Noël',
  'ete': 'Été',
  'paques': 'Pâques',
  'entree': 'Entrée',
  'aperitif': 'Apéritif',
  'petit dejeuner': 'Petit-déjeuner',
};

/// Mots en -s qui ne sont pas des pluriels.
const _invariable = {'gros', 'ananas', 'os', 'sans', 'dans', 'tapas', 'anis'};

/// Clé stable d'un ingrédient : ASCII, minuscules, pluriels simples
/// ramenés au singulier (« Tomates » et « tomate » donnent `tomate`).
String ingredientKey(String raw) {
  final display = ingredientDisplayName(raw);
  if (display.isEmpty) return '';
  final ascii = normalizeAscii(display.toLowerCase()).replaceAll("'", ' ');
  return ascii
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) {
        if (w.length > 3 && w.endsWith('eaux')) return w.substring(0, w.length - 1);
        if (_invariable.contains(w)) return w;
        if (w.length > 3 &&
            w.endsWith('s') &&
            !w.endsWith('ss') &&
            !w.endsWith('is') &&
            !w.endsWith('us')) {
          return w.substring(0, w.length - 1);
        }
        return w;
      })
      .join(' ');
}

/// Tranche de durée : `rapide` (≤ 20 min), `moyen` (≤ 45 min) ou `long`.
String durationBucket(int minutes) {
  if (minutes <= 20) return 'rapide';
  if (minutes <= 45) return 'moyen';
  return 'long';
}

List<String> _splitTags(String raw) => raw
    .split(',')
    .map((e) => asciiFilterLabel(e).toLowerCase())
    .where((e) => e.isNotEmpty)
    .toSet()
    .toList();

/// Caractéristiques d'une recette et leur poids relatif. Les ingrédients se
/// partagent un poids total de 1,5 pour ne pas écraser le type de plat.
Map<String, double> tasteFeatures(RecipeDisplayModel recipe) {
  final features = <String, double>{};

  final type = normalizeTypeLabel(recipe.category);
  if (type.isNotEmpty && type != 'recette') {
    features['type:${normalizeAscii(type)}'] = 1.0;
  }

  features['regime:${recipeDietLevel(recipe).name}'] = 1.0;

  final minutes = parseDurationMinutes(recipe.duration);
  if (minutes != null && minutes > 0) {
    features['duree:${durationBucket(minutes)}'] = 0.6;
  }

  for (final occasion in _splitTags(recipe.occasions)) {
    features['occ:$occasion'] = 0.5;
  }

  final ingredients = tasteIngredients(recipe).keys.toList();
  for (final ingredient in ingredients) {
    features['ing:$ingredient'] = 1.5 / ingredients.length;
  }

  return features;
}

/// Ingrédients marquants d'une recette (8 au plus, hors basiques), de la
/// clé vers le libellé lisible : `{'huile d olive': "Huile d'olive"}`.
Map<String, String> tasteIngredients(RecipeDisplayModel recipe) {
  final out = <String, String>{};
  for (final raw in recipe.ingredients.split(',')) {
    final key = ingredientKey(raw);
    if (key.isEmpty || _staples.contains(key) || out.containsKey(key)) continue;
    out[key] = ingredientDisplayName(raw);
    if (out.length == 8) break;
  }
  return out;
}

// ── Contraintes (allergies, régime) ─────────────────────────────────────────

const Map<String, List<String>> _allergyKeywords = {
  'gluten': ['gluten', 'ble', 'farine', 'pain', 'pates', 'semoule', 'orge'],
  'lactose': [
    'lactose',
    'lait',
    'fromage',
    'beurre',
    'creme',
    'yaourt',
    'mozzarella',
    'parmesan',
    // Les étiquettes d'allergènes des données sont incomplètes (« Mac and
    // cheese » n'est marqué que gluten) : on reconnaît aussi les fromages.
    'cheddar',
    'emmental',
    'gruyere',
    'comte',
    'tomme',
    'raclette',
    'reblochon',
    'camembert',
    'brie',
    'roquefort',
    'gorgonzola',
    'chevre',
    'feta',
    'ricotta',
    'mascarpone',
    'burrata',
    'ghee',
  ],
  'nuts': [
    'fruits a coque',
    'noix',
    'amande',
    'noisette',
    'cajou',
    'pistache',
    'pecan',
    'macadamia',
  ],
  'seafood': [
    'fruits de mer',
    'crustace',
    'mollusque',
    'crevette',
    'moule',
    'homard',
    'crabe',
    'calamar',
    'huitre',
    'saint jacques',
  ],
  'eggs': ['oeuf'],
  'soy': ['soja', 'tofu', 'tempeh', 'edamame'],
  'peanuts': ['arachide', 'cacahuete'],
};

/// Mots-clés interdits pour des allergies, qu'elles viennent de
/// l'inscription (`gluten`, `nuts`…) ou de libellés français.
Set<String> allergyKeywords(Iterable<String> allergies) {
  final keywords = <String>{};
  for (final raw in allergies) {
    final value = normalizeAscii(raw).toLowerCase().trim();
    if (value.isEmpty) continue;
    keywords.addAll(_allergyKeywords[value] ?? [value]);
  }
  return keywords;
}

/// Lit les préférences du profil (« Régime », « Allergènes »…).
SwipeConstraints constraintsFromPreferences(List<UserPreference> prefs) {
  final allergies = <String>[];
  DietLevel? diet;
  for (final p in prefs) {
    final label = normalizeAscii(p.label).toLowerCase();
    final values = p.value.split(RegExp(r'[,;/|]'));
    if (label.contains('allerg') || label.contains('intoler')) {
      allergies.addAll(values);
    } else if (label.contains('regime')) {
      for (final v in values) {
        diet ??= dietLevelFromLabel(v);
      }
    }
  }
  return SwipeConstraints(
    blockedKeywords: allergyKeywords(allergies),
    minDiet: diet,
  );
}

/// Faux amis à retirer avant de chercher les allergènes (« lait de coco »
/// n'est pas du lactose, « noix de coco » n'est pas un fruit à coque).
final _falseFriends = RegExp(
  r"(lait|creme|yaourt) (de |d )?(coco|soja|amande|avoine|riz)|noix de (coco|muscade)|beurre de cacahuete",
);

/// Vrai si la recette respecte les allergies et le régime. Lit les
/// ingrédients en plus des étiquettes d'allergènes, souvent incomplètes dans
/// les données.
bool isRecipeAllowed(RecipeDisplayModel recipe, SwipeConstraints constraints) {
  if (constraints.blockedKeywords.isNotEmpty) {
    final text = normalizeAscii('${recipe.allergens} ${recipe.ingredients}')
        .toLowerCase()
        .replaceAll("'", ' ')
        .replaceAll(_falseFriends, ' ');
    if (constraints.blockedKeywords.any(text.contains)) return false;
  }
  final minDiet = constraints.minDiet;
  if (minDiet != null && recipeDietLevel(recipe).index < minDiet.index) {
    return false;
  }
  return true;
}

// ── Choix des cartes ────────────────────────────────────────────────────────

/// Choisit `size` recettes compatibles avec le profil et aussi variées que
/// possible : à chaque tour, la recette qui apporte le plus de
/// caractéristiques encore jamais vues (type de plat, durée, régime…).
/// Les recettes avec photo passent en priorité.
List<RecipeDisplayModel> selectSwipeDeck(
  List<RecipeDisplayModel> source, {
  SwipeConstraints constraints = const SwipeConstraints(),
  int size = kSwipeDeckSize,
  Random? random,
}) {
  final allowed = source.where((r) => isRecipeAllowed(r, constraints)).toList()
    ..shuffle(random ?? Random());
  final withPhoto = allowed.where((r) => r.imageUrl != null).toList();
  final pool = withPhoto.length >= size ? withPhoto : allowed;

  final deck = <RecipeDisplayModel>[];
  final seen = <String>{};
  final seenTitles = <String>{};
  final remaining = [...pool];

  while (deck.length < size && remaining.isNotEmpty) {
    var bestIndex = -1;
    var bestGain = -1.0;
    for (var i = 0; i < remaining.length; i++) {
      final recipe = remaining[i];
      if (seenTitles.contains(recipe.title.toLowerCase())) continue;
      var gain = 0.0;
      for (final key in tasteFeatures(recipe).keys) {
        if (!seen.contains(key)) gain += key.startsWith('ing:') ? 0.3 : 1.0;
      }
      if (gain > bestGain) {
        bestGain = gain;
        bestIndex = i;
      }
    }
    if (bestIndex < 0) break;
    final picked = remaining.removeAt(bestIndex);
    deck.add(picked);
    seenTitles.add(picked.title.toLowerCase());
    seen.addAll(tasteFeatures(picked).keys);
  }
  return deck;
}

// ── Profil et score ─────────────────────────────────────────────────────────

/// Construit le profil à partir des votes. Les poids sont ramenés dans
/// [-1, 1] ; les « coups de cœur » sont gardés comme favoris à ajouter.
TasteProfile buildTasteProfile(
  List<RecipeDisplayModel> deck,
  List<SwipeVote> votes, {
  DateTime? now,
}) {
  final byId = {for (final r in deck) r.id: r};
  final raw = <String, double>{};
  final labels = <String, String>{};
  final superLikes = <String>{};

  for (final vote in votes) {
    final recipe = byId[vote.recipeId];
    if (recipe == null) continue;
    if (vote.verdict == SwipeVerdict.superLike) superLikes.add(recipe.id);
    tasteIngredients(recipe).forEach((key, label) => labels['ing:$key'] = label);
    tasteFeatures(recipe).forEach((key, w) {
      raw[key] = (raw[key] ?? 0) + w * vote.verdict.weight;
    });
  }

  raw.removeWhere((_, v) => v.abs() < 1e-9);
  final maxAbs = raw.values.fold<double>(0, (m, v) => max(m, v.abs()));
  final weights = maxAbs == 0
      ? <String, double>{}
      : raw.map((k, v) => MapEntry(k, v / maxAbs));

  labels.removeWhere((key, _) => !weights.containsKey(key));

  final at = now ?? DateTime.now();
  return TasteProfile(
    weights: weights,
    labels: labels,
    // Données brutes horodatées : ce qui part en base.
    votes: votes.map((v) => v.stamped(at)).toList(),
    pendingFavoriteIds: superLikes,
    updatedAt: at,
  );
}

/// Affinité d'une recette avec le profil (0 si aucune caractéristique connue).
double tasteScore(RecipeDisplayModel recipe, TasteProfile profile) {
  var score = 0.0;
  tasteFeatures(recipe).forEach((key, w) {
    score += w * (profile.weights[key] ?? 0);
  });
  return score;
}

/// Trie par affinité décroissante ; à score égal, l'ordre d'origine est
/// conservé. Sans profil, la liste est rendue telle quelle.
List<RecipeDisplayModel> rankByTaste(
  List<RecipeDisplayModel> recipes,
  TasteProfile? profile,
) {
  if (profile == null || profile.isEmpty) return recipes;
  final indexed = [
    for (var i = 0; i < recipes.length; i++)
      (i: i, recipe: recipes[i], score: tasteScore(recipes[i], profile)),
  ];
  indexed.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.i.compareTo(b.i);
  });
  return indexed.map((e) => e.recipe).toList();
}

// ── Libellés ────────────────────────────────────────────────────────────────

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const Map<String, String> _fixedLabels = {
  // Les clés sont en ASCII : on rétablit les accents des types courants.
  'type:entree': 'Entrée',
  'type:aperitif': 'Apéritif',
  'type:plat principal': 'Plat principal',
  'regime:vegan': 'Végétalien',
  'regime:vegetarian': 'Végétarien',
  'regime:pescetarian': 'Poisson',
  'regime:carnivore': 'Viande',
  'duree:rapide': 'Vite prêt',
  'duree:moyen': 'Moins de 45 min',
  'duree:long': 'Plats mijotés',
  // Même idée que la durée « rapide » : un seul libellé, donc pas de doublon.
  'occ:rapide': 'Vite prêt',
};

/// Libellé lisible d'une caractéristique (`ing:lentilles` → « Lentilles »).
String tasteFeatureLabel(String key) {
  final fixed = _fixedLabels[key];
  if (fixed != null) return fixed;
  final colon = key.indexOf(':');
  return _capitalize(colon >= 0 ? key.substring(colon + 1) : key);
}

/// Les `count` goûts les plus marqués (poids positifs uniquement).
List<String> topTasteLabels(TasteProfile profile, {int count = 6}) {
  final positives = profile.weights.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final labels = <String>[];
  for (final entry in positives) {
    final label = profile.labels[entry.key] ?? tasteFeatureLabel(entry.key);
    if (!labels.contains(label)) labels.add(label);
    if (labels.length == count) break;
  }
  return labels;
}
