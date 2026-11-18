import 'dart:math';

import '../../models/taste_profile.dart';
import '../home/home_models.dart';
import 'taste_logic.dart';

// Recommandations à partir des swipes : pourcentages de préférence par
// ingrédient, puis score de chaque recette du catalogue. Fonctions pures :
// tout se recalcule depuis les swipes bruts (`fact_user_swipe`) et le
// catalogue, ce qui permet de faire évoluer la formule sans migrer la base.
// La vue SQL `v_user_ingredient_preference` (database/taste_swipes.sql)
// applique la même formule côté serveur.

/// Préférence pour un ingrédient, déduite des recettes swipées.
class IngredientPreference {
  final String key;
  final String label;

  /// Part (0–1) du poids des recettes aimées qui contiennent l'ingrédient
  /// (coup de cœur = 2, ça me tente = 1).
  final double likedShare;

  /// Part (0–1) des recettes rejetées qui contiennent l'ingrédient.
  final double dislikedShare;

  /// Nombre de recettes aimées / rejetées qui le contiennent.
  final int likedCount;
  final int dislikedCount;

  const IngredientPreference({
    required this.key,
    required this.label,
    required this.likedShare,
    required this.dislikedShare,
    required this.likedCount,
    required this.dislikedCount,
  });

  /// Affinité nette dans [−1, 1] : aimé moins rejeté.
  double get score => likedShare - dislikedShare;

  /// Pourcentage affiché (part des recettes aimées qui le contiennent).
  int get percent => (likedShare * 100).round();
}

/// Préférences par ingrédient, de la plus forte à la plus faible.
/// `recipesById` : catalogue (ou paquet de cartes) pour retrouver les
/// ingrédients des recettes votées ; les votes inconnus sont ignorés.
List<IngredientPreference> ingredientPreferences(
  List<SwipeVote> votes,
  Map<String, RecipeDisplayModel> recipesById,
) {
  var likedTotal = 0.0;
  var dislikedTotal = 0;
  final liked = <String, double>{};
  final likedCount = <String, int>{};
  final disliked = <String, int>{};
  final labels = <String, String>{};

  for (final vote in votes) {
    final recipe = recipesById[vote.recipeId];
    if (recipe == null) continue;
    final ingredients = tasteIngredients(recipe);
    labels.addAll(ingredients);
    if (vote.verdict == SwipeVerdict.dislike) {
      dislikedTotal++;
      for (final key in ingredients.keys) {
        disliked[key] = (disliked[key] ?? 0) + 1;
      }
    } else {
      final w = vote.verdict.weight;
      likedTotal += w;
      for (final key in ingredients.keys) {
        liked[key] = (liked[key] ?? 0) + w;
        likedCount[key] = (likedCount[key] ?? 0) + 1;
      }
    }
  }

  final prefs = <IngredientPreference>[
    for (final key in {...liked.keys, ...disliked.keys})
      IngredientPreference(
        key: key,
        label: labels[key] ?? key,
        likedShare: likedTotal == 0 ? 0 : (liked[key] ?? 0) / likedTotal,
        dislikedShare:
            dislikedTotal == 0 ? 0 : (disliked[key] ?? 0) / dislikedTotal,
        likedCount: likedCount[key] ?? 0,
        dislikedCount: disliked[key] ?? 0,
      ),
  ];
  prefs.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final byCount = b.likedCount.compareTo(a.likedCount);
    return byCount != 0 ? byCount : a.label.compareTo(b.label);
  });
  return prefs;
}

/// Ingrédients préférés à afficher : affinité nette positive, triés par le
/// pourcentage affiché (sinon « Ail 56 % » passerait avant « Oignon 67 % »
/// quand l'oignon figure aussi dans une recette rejetée).
List<IngredientPreference> topIngredients(
  List<IngredientPreference> prefs, {
  int count = 5,
}) {
  final shown = prefs.where((p) => p.score > 0 && p.likedCount > 0).toList()
    ..sort((a, b) {
      final byPercent = b.likedShare.compareTo(a.likedShare);
      return byPercent != 0 ? byPercent : b.score.compareTo(a.score);
    });
  return shown.take(count).toList();
}

/// Part des ingrédients dans le score final ; le reste vient du type de
/// plat, du régime, de la durée et des occasions.
const double kIngredientWeight = 0.65;

/// Score de recommandation d'une recette.
///
/// - Ingrédients : somme des affinités de ses ingrédients, divisée par la
///   racine de leur nombre (une longue liste n'est pas avantagée).
/// - Autres caractéristiques : poids du profil (type, régime, durée…).
/// - Recette déjà rejetée au swipe : pénalité forte (−1).
double recommendationScore(
  RecipeDisplayModel recipe, {
  required Map<String, IngredientPreference> prefsByKey,
  required Map<String, double> featureWeights,
  required Map<String, SwipeVerdict> verdictByRecipe,
}) {
  final keys = tasteIngredients(recipe).keys.toList();
  final ingredientPart = keys.isEmpty
      ? 0.0
      : keys.fold<double>(0, (s, k) => s + (prefsByKey[k]?.score ?? 0)) /
          sqrt(keys.length);

  var featurePart = 0.0;
  tasteFeatures(recipe).forEach((key, w) {
    if (!key.startsWith('ing:')) featurePart += w * (featureWeights[key] ?? 0);
  });

  final penalty =
      verdictByRecipe[recipe.id] == SwipeVerdict.dislike ? 1.0 : 0.0;
  return kIngredientWeight * ingredientPart +
      (1 - kIngredientWeight) * featurePart -
      penalty;
}

/// Résultat du classement : recettes triées et raisons par recette.
class Recommendations {
  final List<RecipeDisplayModel> recipes;
  final List<IngredientPreference> preferences;

  /// Recette → ingrédients aimés qu'elle contient (pour « Pourquoi ? »).
  final Map<String, List<IngredientPreference>> reasons;

  /// Recettes déjà aimées au swipe (ça me tente ou coup de cœur).
  final Set<String> alreadyLiked;

  const Recommendations({
    required this.recipes,
    this.preferences = const [],
    this.reasons = const {},
    this.alreadyLiked = const {},
  });
}

/// Une recommandation sur `kLikedEvery` est une recette déjà aimée ; les
/// autres sont des recettes jamais swipées, choisies d'après les goûts.
const int kLikedEvery = 3;

/// Mélange les deux listes (chacune déjà triée par score) : positions
/// 1, 4, 7… pour les déjà aimées, le reste pour les nouvelles. Quand une liste
/// est épuisée, l'autre complète.
List<T> mixRecommendations<T>(List<T> fresh, List<T> liked,
    {int likedEvery = kLikedEvery}) {
  final out = <T>[];
  var f = 0;
  var l = 0;
  while (f < fresh.length || l < liked.length) {
    final likedTurn = out.length % likedEvery == 1;
    if ((likedTurn && l < liked.length) || f >= fresh.length) {
      out.add(liked[l++]);
    } else {
      out.add(fresh[f++]);
    }
  }
  return out;
}

/// Classe `candidates` selon les swipes du profil. Le catalogue complet
/// (`catalog`) sert à relire les recettes votées. Sans swipes, l'ordre
/// d'origine est conservé (ou `rankByTaste` pour un ancien profil sans
/// votes bruts).
Recommendations rankRecommendations(
  List<RecipeDisplayModel> candidates,
  TasteProfile? profile, {
  required List<RecipeDisplayModel> catalog,
}) {
  if (profile == null || profile.isEmpty) {
    return Recommendations(recipes: candidates);
  }
  if (profile.votes.isEmpty) {
    return Recommendations(recipes: rankByTaste(candidates, profile));
  }

  final byId = {for (final r in catalog) r.id: r};
  final prefs = ingredientPreferences(profile.votes, byId);
  final prefsByKey = {for (final p in prefs) p.key: p};
  // Poids recalculés depuis les votes et le catalogue à jour.
  final weights = buildTasteProfile(catalog, profile.votes).weights;
  final verdicts = {for (final v in profile.votes) v.recipeId: v.verdict};

  final scored = [
    for (var i = 0; i < candidates.length; i++)
      (
        i: i,
        recipe: candidates[i],
        score: recommendationScore(
          candidates[i],
          prefsByKey: prefsByKey,
          featureWeights: weights,
          verdictByRecipe: verdicts,
        ),
      ),
  ]..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.i.compareTo(b.i);
    });

  final reasons = <String, List<IngredientPreference>>{};
  for (final s in scored) {
    final liked = tasteIngredients(s.recipe)
        .keys
        .map((k) => prefsByKey[k])
        .whereType<IngredientPreference>()
        .where((p) => p.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (liked.isNotEmpty) reasons[s.recipe.id] = liked.take(2).toList();
  }

  // Nouvelles d'après les goûts, entrecoupées de recettes déjà aimées ; les
  // rejetées restent à la fin.
  final fresh = <RecipeDisplayModel>[];
  final liked = <RecipeDisplayModel>[];
  final rejected = <RecipeDisplayModel>[];
  for (final s in scored) {
    switch (verdicts[s.recipe.id]) {
      case null:
        fresh.add(s.recipe);
      case SwipeVerdict.dislike:
        rejected.add(s.recipe);
      case SwipeVerdict.like:
      case SwipeVerdict.superLike:
        liked.add(s.recipe);
    }
  }

  return Recommendations(
    recipes: [...mixRecommendations(fresh, liked), ...rejected],
    preferences: prefs,
    reasons: reasons,
    alreadyLiked: {for (final r in liked) r.id},
  );
}

/// Phrase courte « pourquoi cette recette » : « Lentilles, Lait de coco ».
String? recommendationReason(List<IngredientPreference>? reasons) {
  if (reasons == null || reasons.isEmpty) return null;
  return reasons.map((p) => p.label).join(', ');
}
