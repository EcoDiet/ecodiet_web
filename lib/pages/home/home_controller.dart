import 'package:flutter/foundation.dart';

import '../../models/recette.dart';
import '../../models/taste_profile.dart';
import '../../models/user.dart' show UserPreference;
import '../../services/ecodiet_api.dart';
import '../../services/favorites_service.dart';
import '../taste/taste_logic.dart'
    show constraintsFromPreferences, isRecipeAllowed;
import '../taste/taste_recommendation.dart';
import 'home_models.dart';
import 'recipe_filtering.dart';

/// Données brutes de l'accueil gardées en mémoire entre deux visites.
class _HomeDataCache {
  final DateTime fetchedAt;
  final List<RecettePreview> previews;
  final List quizzes;
  final List<Ingredient> ingredientRefs;
  final List<Equipement> equipementRefs;
  final List<Regime> regimeRefs;
  final List<TypePlat> typePlatRefs;
  final List<Allergene> allergeneRefs;
  final List<UserPreference> userPreferences;

  _HomeDataCache({
    required this.fetchedAt,
    required this.previews,
    required this.quizzes,
    required this.ingredientRefs,
    required this.equipementRefs,
    required this.regimeRefs,
    required this.typePlatRefs,
    required this.allergeneRefs,
    required this.userPreferences,
  });

  /// Même contenu, horodaté maintenant (le cache est renouvelé à chaque
  /// affichage, comme avant l'extraction du contrôleur).
  _HomeDataCache touched() => _HomeDataCache(
        fetchedAt: DateTime.now(),
        previews: previews,
        quizzes: quizzes,
        ingredientRefs: ingredientRefs,
        equipementRefs: equipementRefs,
        regimeRefs: regimeRefs,
        typePlatRefs: typePlatRefs,
        allergeneRefs: allergeneRefs,
        userPreferences: userPreferences,
      );
}

/// État de l'accueil : chargement, recherche, filtres, tri et pagination.
///
/// Sans dépendance aux widgets : l'API est injectée, ce qui permet de tester
/// le comportement avec une fausse implémentation.
class HomeController extends ChangeNotifier {
  HomeController({EcoDietApi? api}) : _api = api ?? EcoDietApi();

  static const int recipesPerPage = 25;
  static const Duration _memoryCacheTtl = Duration(minutes: 3);
  static _HomeDataCache? _memoryCache;

  /// Vide le cache partagé (utile en test).
  @visibleForTesting
  static void resetCache() => _memoryCache = null;

  final EcoDietApi _api;
  bool _disposed = false;

  List<RecipeDisplayModel> _recipeSource = [];
  List<RecipeDisplayModel> _recommendedRecipes = [];
  List<RecipeDisplayModel> _visibleRecipes = [];
  List<Quiz> _quizzes = [];
  bool _isLoading = true;
  int _recipePage = 0;
  int _filteredRecipeCount = 0;
  bool _hasNextRecipePage = false;
  String? _loadWarning;
  List<String> _ingredientOptionsFromRef = [];
  List<String> _utensilOptionsFromRef = [];
  List<String> _dietOptionsFromRef = [];
  List<String> _allergenOptionsFromRef = [];
  TasteProfile? _tasteProfile;
  Map<String, List<IngredientPreference>> _reasons = const {};
  Set<String> _alreadyLiked = const {};
  List<IngredientPreference> _ingredientPreferences = const [];

  String _searchQuery = '';
  RecipeFilters _filters = RecipeFilters.empty();
  RecipeSortMode _sortMode = RecipeSortMode.pertinence;

  // ── Lecture ────────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  String? get loadWarning => _loadWarning;
  bool get hasRecipes => _recipeSource.isNotEmpty;
  List<Quiz> get quizzes => _quizzes;
  String get searchQuery => _searchQuery;
  RecipeFilters get filters => _filters;
  RecipeSortMode get sortMode => _sortMode;
  bool get hasActiveFilters => _filters.hasAny;
  int get activeFiltersCount => _filters.activeCount;
  bool get isLoggedIn => _api.isLoggedIn;

  /// Vrai si l'utilisateur a déjà fait le swipe de goûts.
  bool get hasTasteProfile => _tasteProfile != null && !_tasteProfile!.isEmpty;

  /// Ingrédients préférés (pourcentages), recalculés depuis les swipes.
  List<IngredientPreference> get ingredientPreferences =>
      _ingredientPreferences;

  /// « Pourquoi cette recette » : « Déjà aimée » pour une recette aimée au
  /// swipe, sinon les ingrédients aimés qu'elle contient.
  String? recommendationReasonFor(String recipeId) =>
      _alreadyLiked.contains(recipeId)
          ? 'Déjà aimée'
          : recommendationReason(_reasons[recipeId]);

  /// Recommandations, masquées dès qu'une recherche ou un filtre est actif.
  List<RecipeDisplayModel> get recommendedRecipes =>
      (_searchQuery.isEmpty && !hasActiveFilters) ? _recommendedRecipes : [];

  /// Recettes de la page courante, après recherche, filtres et tri.
  List<RecipeDisplayModel> get visibleRecipes => _visibleRecipes;

  int get filteredRecipeCount => _filteredRecipeCount;
  int get recipePage => _recipePage;
  int get totalRecipePages => _filteredRecipeCount == 0
      ? 1
      : ((_filteredRecipeCount - 1) ~/ recipesPerPage) + 1;
  bool get canGoPrevious => _recipePage > 0 && !_isLoading;
  bool get canGoNext => _hasNextRecipePage && !_isLoading;

  List<String> get ingredientOptions {
    if (_ingredientOptionsFromRef.isNotEmpty) return _ingredientOptionsFromRef;
    final fromData = _recipeSource
        .expand((r) => r.ingredients.split(','))
        .map(ingredientFilterLabel)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    fromData.sort();
    return fromData.isNotEmpty ? fromData : fallbackIngredients;
  }

  List<String> get utensilOptions {
    if (_utensilOptionsFromRef.isNotEmpty) return _utensilOptionsFromRef;
    final fromData = _recipeSource
        .expand((r) => r.utensils.split(','))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    fromData.sort();
    return fromData.isNotEmpty ? fromData : fallbackUtensils;
  }

  List<String> get dietOptions {
    if (_dietOptionsFromRef.isNotEmpty) return _dietOptionsFromRef;
    final categoryText = _recipeSource
        .expand((r) => [r.category, r.diets])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    categoryText.sort();
    return {...fallbackDiets, ...categoryText}.toList()..sort();
  }

  List<String> get allergenOptions {
    if (_allergenOptionsFromRef.isNotEmpty) return _allergenOptionsFromRef;
    final fromData = _recipeSource
        .expand((r) => r.allergens.split(','))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    fromData.sort();
    return fromData.isNotEmpty ? fromData : fallbackAllergens;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void setSearchQuery(String value) {
    _searchQuery = value.toLowerCase().trim();
    _recompute(resetPage: true);
  }

  void applyFilters(RecipeFilters filters) {
    _filters = filters;
    _recompute(resetPage: true);
  }

  void setSortMode(RecipeSortMode mode) {
    _sortMode = mode;
    _recompute(resetPage: true);
  }

  void goToPage(int page) {
    if (page < 0 || page == _recipePage || _isLoading) return;
    _recipePage = page;
    _recompute();
  }

  /// Bascule le favori localement tout de suite, puis synchronise au mieux.
  /// Retourne `true` si le favori n'a pu être enregistré que sur l'appareil
  /// faute de session (l'UI peut alors inviter à se connecter).
  Future<bool> toggleFavorite(RecipeDisplayModel recipe) async {
    final nowFavorite = !FavoritesService().isFavorite(recipe.id);
    recipe.isFavorite = nowFavorite;
    if (nowFavorite) {
      FavoritesService().addFavorite(_favoriteOf(recipe));
    } else {
      FavoritesService().removeFavorite(recipe.id);
    }
    _notify();

    final success = await _api.toggleFavorite(recipe.id);
    return nowFavorite && !success && !_api.isLoggedIn;
  }

  Future<void> load({bool forceRefresh = false}) async {
    // Lecture locale peu coûteuse : relue à chaque affichage pour prendre en
    // compte un swipe fait entre-temps, même quand les recettes sont en cache.
    _tasteProfile = await _loadTasteProfile();

    final cache = _memoryCache;
    if (!forceRefresh &&
        cache != null &&
        DateTime.now().difference(cache.fetchedAt) < _memoryCacheTtl) {
      final favoriteIds = await _api.getFavoriteIds();
      _memoryCache = cache.touched();
      _apply(cache, favoriteIds);
      await _applyPendingFavorites();
      return;
    }

    _isLoading = true;
    _notify();

    try {
      // Previews legeres: on filtre toute la data puis on affiche 25 cartes.
      final results = await Future.wait([
        _api.getAllRecettesPreview(),
        _api.getFavoriteIds(),
        _api.getAllQuizzes(),
        _api.getAllIngredients(),
        _api.getAllEquipements(),
        _api.getAllRegimes(),
        _api.getAllTypesPlat(),
        _api.getAllAllergenes(),
        _api.getUserPreferences(),
      ]);

      final fresh = _HomeDataCache(
        fetchedAt: DateTime.now(),
        previews: results[0] as List<RecettePreview>,
        quizzes: results[2] as List,
        ingredientRefs: results[3] as List<Ingredient>,
        equipementRefs: results[4] as List<Equipement>,
        regimeRefs: results[5] as List<Regime>,
        typePlatRefs: results[6] as List<TypePlat>,
        allergeneRefs: results[7] as List<Allergene>,
        userPreferences: results[8] as List<UserPreference>,
      );
      _memoryCache = fresh;
      _apply(fresh, results[1] as Set<String>);
      await _applyPendingFavorites();
    } catch (e) {
      _isLoading = false;
      _loadWarning = 'Erreur chargement data bridge: $e';
      debugPrint('Erreur chargement données: $e');
      _notify();
    }
  }

  // ── Interne ────────────────────────────────────────────────────────────────

  Future<TasteProfile?> _loadTasteProfile() async {
    try {
      return await _api.getTasteProfile();
    } catch (e) {
      debugPrint('Profil de goûts illisible: $e');
      return null;
    }
  }

  /// Ajoute aux favoris les « coups de cœur » du swipe fait à l'inscription
  /// (avant connexion), puis les retire du profil.
  Future<void> _applyPendingFavorites() async {
    final profile = _tasteProfile;
    if (profile == null ||
        profile.pendingFavoriteIds.isEmpty ||
        !_api.isLoggedIn) {
      return;
    }
    final byId = {for (final r in _recipeSource) r.id: r};
    for (final id in profile.pendingFavoriteIds) {
      final recipe = byId[id];
      if (recipe == null || FavoritesService().isFavorite(id)) continue;
      recipe.isFavorite = true;
      FavoritesService().addFavorite(_favoriteOf(recipe));
      await _api.addToFavorites(id);
    }
    _tasteProfile = await _api
        .saveTasteProfile(profile.copyWith(pendingFavoriteIds: const {}));
    _notify();
  }

  void _apply(_HomeDataCache data, Set<String> favoriteIds) {
    final models = data.previews
        .map((r) => RecipeDisplayModel.fromPreview(r, favoriteIds))
        .toList();

    final favService = FavoritesService();
    favService.clear();
    for (final recipe in models.where((m) => favoriteIds.contains(m.id))) {
      favService.addFavorite(_favoriteOf(recipe));
    }

    _loadWarning = (_api.isBridgeMode && models.isEmpty)
        ? 'Aucune recette reçue depuis l\'API Cloud Run. Vérifie le service et son JSON.'
        : null;
    _recipeSource = models;
    _ingredientOptionsFromRef = data.ingredientRefs
        .map((i) => ingredientFilterLabel(i.nomIngredient))
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    _utensilOptionsFromRef = data.equipementRefs
        .map((e) => asciiFilterLabel(e.nomEquipement)
            .replaceFirst(RegExp(r'^\d+\s+'), ''))
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    _dietOptionsFromRef = [
      ...data.regimeRefs.map((r) => asciiFilterLabel(r.libelle)),
      ...models.map((m) => asciiFilterLabel(m.category)),
      // Régimes présents dans les recettes : en mode bridge, la table de
      // référence des régimes n'est pas chargée.
      ...models.map((m) => asciiFilterLabel(m.diets)),
    ].where((v) => v.isNotEmpty).toSet().toList()
      ..sort();
    _allergenOptionsFromRef = data.allergeneRefs
        .map((a) => asciiFilterLabel(a.libelle))
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    // Filtres stricts (allergies, régime) d'abord, puis classement selon les
    // swipes : pourcentages par ingrédient + type, régime, durée.
    // `buildRecommendedRecipes` se fie aux étiquettes d'allergènes, souvent
    // incomplètes : on vérifie aussi les ingrédients (lait, fromages…).
    final constraints = constraintsFromPreferences(data.userPreferences);
    final recommendations = rankRecommendations(
      buildRecommendedRecipes(
        models,
        data.userPreferences,
        selectedDietFilters: _filters.diets,
      ).where((r) => isRecipeAllowed(r, constraints)).toList(),
      _tasteProfile,
      catalog: models,
    );
    _recommendedRecipes = recommendations.recipes.take(10).toList();
    _reasons = recommendations.reasons;
    _alreadyLiked = recommendations.alreadyLiked;
    _ingredientPreferences = recommendations.preferences;
    _quizzes = data.quizzes
        .map((q) => Quiz(
              id: q.quizId?.toString() ?? '',
              title: q.title,
              description: q.description ?? '',
              imageUrl: q.imageUrl,
            ))
        .toList();
    _isLoading = false;
    _recompute();
  }

  void _recompute({bool resetPage = false}) {
    if (resetPage) _recipePage = 0;

    final matching = sortRecipes(
      _recipeSource
          .where((r) => matchesSearch(r, _searchQuery))
          .where((r) => matchesFilters(r, _filters))
          .toList(),
      _sortMode,
    );

    final maxPage =
        matching.isEmpty ? 0 : (matching.length - 1) ~/ recipesPerPage;
    if (_recipePage > maxPage) _recipePage = maxPage;

    final start = _recipePage * recipesPerPage;
    _visibleRecipes = matching.skip(start).take(recipesPerPage).toList();
    _filteredRecipeCount = matching.length;
    _hasNextRecipePage = start + recipesPerPage < matching.length;
    _notify();
  }

  FavoriteRecipe _favoriteOf(RecipeDisplayModel recipe) => FavoriteRecipe(
        id: recipe.id,
        title: recipe.title,
        category: recipe.category,
        duration: recipe.duration,
        imageUrl: recipe.imageUrl,
      );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
