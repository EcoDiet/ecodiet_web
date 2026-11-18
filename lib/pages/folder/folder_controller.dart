import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../models/recette.dart';
import '../../services/ecodiet_api.dart';
import '../../services/favorites_service.dart';

/// Identifiant de route du dossier virtuel « Favoris ».
const favoritesFolderId = 'favorites';

/// Durée courte : « 45' », « 1h », « 1h30' ».
String formatShortDuration(int minutes) {
  if (minutes < 60) return "$minutes'";
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return '${hours}h${rest > 0 ? "$rest'" : ""}';
}

FavoriteRecipe favoriteRecipeFrom(Recette r) {
  final url = r.photo.isEmpty ? '' : recetteImageUrl(r.photo);
  return FavoriteRecipe(
    id: r.recetteId,
    title: r.titre,
    category: 'Recette',
    duration: formatShortDuration(r.dureeMinute),
    imageUrl: url.isEmpty ? null : url,
  );
}

/// « 3 recette(s) » (en-têtes compacts).
String recipeCountShort(int count) => '$count recette(s)';

/// « Aucune recette », « 1 recette », « 2 recettes » (hero mobile).
String recipeCountLong(int count) {
  if (count == 0) return 'Aucune recette';
  return '$count recette${count > 1 ? 's' : ''}';
}

/// Contenu d'un dossier (ou des favoris). L'API est injectable pour les tests.
class FolderController extends ChangeNotifier {
  FolderController({required this.folderId, EcoDietApi? api})
      : _api = api ?? EcoDietApi();

  /// `null`, [favoritesFolderId] ou l'identifiant numérique d'un dossier.
  final String? folderId;
  final EcoDietApi _api;
  final Logger _log = Logger();
  bool _disposed = false;

  bool _isLoading = true;
  final List<FavoriteRecipe> _recipes = [];

  bool get isFavorites => folderId == favoritesFolderId;
  bool get isLoading => _isLoading;
  List<FavoriteRecipe> get recipes => List.unmodifiable(_recipes);

  int? get _numericId => int.tryParse(folderId ?? '');

  Future<void> load() async {
    try {
      final List<Recette> result;
      if (isFavorites) {
        result = await _api.getFavorites();
      } else if (_numericId != null) {
        result = await _api.getRecipesInFolder(_numericId!);
      } else {
        result = const [];
      }
      _recipes
        ..clear()
        ..addAll(result.map(favoriteRecipeFrom));
    } catch (error, stack) {
      _log.w('Erreur chargement dossier $folderId',
          error: error, stackTrace: stack);
    }
    _isLoading = false;
    _notify();
  }

  /// Retire la recette de l'affichage tout de suite, puis côté données.
  void remove(FavoriteRecipe recipe) {
    _recipes.removeWhere((r) => r.id == recipe.id);
    _notify();
    if (isFavorites) {
      _api.removeFromFavorites(recipe.id);
    } else if (_numericId != null) {
      _api.removeRecipeFromFolder(_numericId!, recipe.id);
    }
  }

  /// « Annuler » après un retrait : réaffiche la recette (localement).
  void restore(FavoriteRecipe recipe) {
    _recipes.add(recipe);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
