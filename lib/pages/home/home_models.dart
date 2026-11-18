import 'package:flutter/material.dart';

import '../../models/recette.dart';
import '../../services/ecodiet_api.dart';

/// Modèle local pour une recette avec favoris
class RecipeDisplayModel {
  final String id;
  final String title;
  final String category;
  final String ingredients;
  final String utensils;
  final String diets;
  final String allergens;
  final String occasions;
  final String duration;
  final double? budgetEur;
  final String? imageUrl;
  bool isFavorite;

  RecipeDisplayModel({
    required this.id,
    required this.title,
    required this.category,
    required this.ingredients,
    this.utensils = '',
    this.diets = '',
    this.allergens = '',
    this.occasions = '',
    required this.duration,
    this.budgetEur,
    this.imageUrl,
    this.isFavorite = false,
  });

  static RecipeDisplayModel fromPreview(
      RecettePreview recette, Set<String> favoriteIds) {
    final rawCategory = (recette.typePlatLibelle ?? 'Recette').trim();
    final category = _formatTypeLabel(rawCategory);
    final diets = (recette.regimeLibelle ?? '').trim();

    return RecipeDisplayModel(
      id: recette.recetteId,
      title: recette.titre,
      category: category,
      ingredients: recette.ingredients.join(', '),
      utensils: recette.equipements.join(', '),
      diets: diets,
      allergens: recette.allergenes.join(', '),
      occasions: recette.occasions.join(', '),
      duration: recette.dureeMinute > 0 ? "${recette.dureeMinute} min" : '',
      budgetEur: null,
      imageUrl:
          recette.photo.isNotEmpty ? recetteImageUrl(recette.photo) : null,
      isFavorite: favoriteIds.contains(recette.recetteId),
    );
  }

  static String _formatTypeLabel(String rawType) {
    final normalized = rawType
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalized == 'apperitif') return 'aperitif';
    return normalized;
  }
}

// Alias pour compatibilité avec AllRecipesPage
typedef Recipe = RecipeDisplayModel;

/// Modèle pour un quiz (local, avec icône)
class Quiz {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final IconData icon;

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.icon = Icons.quiz_outlined,
  });
}

enum RecipeSortMode {
  pertinence,
  titreAsc,
  titreDesc,
  tempsAsc,
  tempsDesc,
}

extension RecipeSortModeLabel on RecipeSortMode {
  String get label {
    switch (this) {
      case RecipeSortMode.pertinence:
        return 'Pertinence';
      case RecipeSortMode.titreAsc:
        return 'Titre A-Z';
      case RecipeSortMode.titreDesc:
        return 'Titre Z-A';
      case RecipeSortMode.tempsAsc:
        return 'Temps croissant';
      case RecipeSortMode.tempsDesc:
        return 'Temps décroissant';
    }
  }
}

class RecipeFilters {
  Set<String> ingredients;
  Set<String> utensils;
  Set<String> diets;
  Set<String> allergens;
  int? minTimeMinutes;
  int? maxTimeMinutes;

  RecipeFilters({
    required this.ingredients,
    required this.utensils,
    required this.diets,
    required this.allergens,
    this.minTimeMinutes,
    this.maxTimeMinutes,
  });

  factory RecipeFilters.empty() {
    return RecipeFilters(
      ingredients: <String>{},
      utensils: <String>{},
      diets: <String>{},
      allergens: <String>{},
    );
  }

  RecipeFilters copy() {
    return RecipeFilters(
      ingredients: {...ingredients},
      utensils: {...utensils},
      diets: {...diets},
      allergens: {...allergens},
      minTimeMinutes: minTimeMinutes,
      maxTimeMinutes: maxTimeMinutes,
    );
  }

  bool get hasAny => activeCount > 0;

  int get activeCount {
    var count = 0;
    count += ingredients.length;
    count += utensils.length;
    count += diets.length;
    count += allergens.length;
    if (minTimeMinutes != null || maxTimeMinutes != null) count++;
    return count;
  }

  void reset() {
    ingredients.clear();
    utensils.clear();
    diets.clear();
    allergens.clear();
    minTimeMinutes = null;
    maxTimeMinutes = null;
  }
}
