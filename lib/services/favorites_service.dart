import 'package:flutter/material.dart';

/// Modèle partagé pour une recette (utilisé dans les favoris et les dossiers)
class FavoriteRecipe {
  final String id;
  final String title;
  final String category;
  final String duration;
  final String? imageUrl;

  FavoriteRecipe({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    this.imageUrl,
  });
}

/// Service singleton pour gérer les favoris entre les pages
class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  final List<FavoriteRecipe> _favorites = [];

  List<FavoriteRecipe> get favorites => List.unmodifiable(_favorites);
  int get count => _favorites.length;

  bool isFavorite(String id) => _favorites.any((r) => r.id == id);

  void addFavorite(FavoriteRecipe recipe) {
    if (!isFavorite(recipe.id)) {
      _favorites.add(recipe);
      notifyListeners();
    }
  }

  void removeFavorite(String id) {
    _favorites.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void toggle(FavoriteRecipe recipe) {
    if (isFavorite(recipe.id)) {
      removeFavorite(recipe.id);
    } else {
      addFavorite(recipe);
    }
  }
}
