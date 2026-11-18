import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../models/recette.dart';
import '../models/user.dart' show UserPreference;
import '../utils/responsive.dart';
import '../services/favorites_service.dart';
import 'all_recipes_page.dart';
import 'home/filter_panel.dart';
import 'home/home_models.dart';
import 'home/quiz_card.dart';
import 'home/recipe_card.dart';
import 'home/recipe_filtering.dart';

export 'home/home_models.dart';
export '../widgets/favorite_button.dart';

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
}
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static _HomeDataCache? _memoryCache;
  static const Duration _memoryCacheTtl = Duration(minutes: 3);

  final EcoDietApi _api = EcoDietApi();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<RecipeDisplayModel> _recipeSource = [];
  List<RecipeDisplayModel> recommendedRecipes = [];
  List<RecipeDisplayModel> allRecipes = [];
  List<Quiz> quizzes = [];
  bool isLoading = true;
  static const int _recipesPerPage = 25;
  int _recipePage = 0;
  int _filteredRecipeCount = 0;
  bool _hasNextRecipePage = false;
  String? _loadWarning;
  List<String> _ingredientOptionsFromRef = [];
  List<String> _utensilOptionsFromRef = [];
  List<String> _dietOptionsFromRef = [];
  List<String> _allergenOptionsFromRef = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  RecipeFilters _filters = RecipeFilters.empty();
  RecipeSortMode _sortMode = RecipeSortMode.pertinence;

  List<Recipe> get _filteredRecommended =>
      (_searchQuery.isEmpty && !_hasActiveFilters) ? recommendedRecipes : [];

  List<Recipe> get _filteredAll => allRecipes;

  bool get _hasActiveFilters => _filters.hasAny;

  int get _activeFiltersCount => _filters.activeCount;

  int get _totalRecipePages =>
      _filteredRecipeCount == 0 ? 1 : ((_filteredRecipeCount - 1) ~/ _recipesPerPage) + 1;

  List<String> get _ingredientOptions {
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

  List<String> get _utensilOptions {
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

  List<String> get _dietOptions {
    if (_dietOptionsFromRef.isNotEmpty) return _dietOptionsFromRef;
    final categoryText = _recipeSource
        .expand((r) => [r.category, r.diets])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    categoryText.sort();
    return {
      ...fallbackDiets,
      ...categoryText,
    }.toList()
      ..sort();
  }

  List<String> get _allergenOptions {
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.toLowerCase().trim();
        _recomputeVisibleRecipes(resetPage: true);
      });
    });
  }

  void _recomputeVisibleRecipes({bool resetPage = false}) {
    if (resetPage) _recipePage = 0;

    final matching = sortRecipes(
      _recipeSource
          .where((r) => matchesSearch(r, _searchQuery))
          .where((r) => matchesFilters(r, _filters))
          .toList(),
      _sortMode,
    );

    final maxPage =
        matching.isEmpty ? 0 : (matching.length - 1) ~/ _recipesPerPage;
    if (_recipePage > maxPage) _recipePage = maxPage;

    final start = _recipePage * _recipesPerPage;
    allRecipes = matching.skip(start).take(_recipesPerPage).toList();
    _filteredRecipeCount = matching.length;
    _hasNextRecipePage = start + _recipesPerPage < matching.length;
  }

  void _openFilters() {
    if (isDesktop(context)) {
      _scaffoldKey.currentState?.openEndDrawer();
      return;
    }
    _openMobileFiltersSheet();
  }

  bool _isCacheUsable() {
    final cache = _memoryCache;
    if (cache == null) return false;
    return DateTime.now().difference(cache.fetchedAt) < _memoryCacheTtl;
  }

  void _applyLoadedData({
    required List<RecettePreview> previews,
    required Set<String> favoriteIds,
    required List loadedQuizzes,
    required List<Ingredient> ingredientRefs,
    required List<Equipement> equipementRefs,
    required List<Regime> regimeRefs,
    required List<TypePlat> typePlatRefs,
    required List<Allergene> allergeneRefs,
    required List<UserPreference> userPreferences,
  }) {
    final models = previews
        .map((r) => RecipeDisplayModel.fromPreview(r, favoriteIds))
        .toList();

    final favService = FavoritesService();
    favService.clear();
    for (final recipe in models.where((m) => favoriteIds.contains(m.id))) {
      favService.addFavorite(
        FavoriteRecipe(
          id: recipe.id,
          title: recipe.title,
          category: recipe.category,
          duration: recipe.duration,
          imageUrl: recipe.imageUrl,
        ),
      );
    }

    _memoryCache = _HomeDataCache(
      fetchedAt: DateTime.now(),
      previews: previews,
      quizzes: loadedQuizzes,
      ingredientRefs: ingredientRefs,
      equipementRefs: equipementRefs,
      regimeRefs: regimeRefs,
      typePlatRefs: typePlatRefs,
      allergeneRefs: allergeneRefs,
      userPreferences: userPreferences,
    );

    setState(() {
      _loadWarning = (_api.isBridgeMode && models.isEmpty)
          ? 'Aucune recette re?ue depuis l API Cloud Run. V?rifie le service et son JSON.'
          : null;
      _recipeSource = models;
      _ingredientOptionsFromRef = ingredientRefs
          .map((i) => ingredientFilterLabel(i.nomIngredient))
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _utensilOptionsFromRef = equipementRefs
          .map((e) =>
              cleanLabel(e.nomEquipement).replaceFirst(RegExp(r'^\d+\s+'), ''))
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      _dietOptionsFromRef = [
        ...regimeRefs.map((r) => cleanLabel(r.libelle)),
        ...models.map((m) => cleanLabel(m.category)),
      ].where((v) => v.isNotEmpty).toSet().toList()
        ..sort();
      _allergenOptionsFromRef = allergeneRefs
          .map((a) => cleanLabel(a.libelle))
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      recommendedRecipes = buildRecommendedRecipes(
        models,
        userPreferences,
        selectedDietFilters: _filters.diets,
      ).take(10).toList();
      _recomputeVisibleRecipes();
      quizzes = loadedQuizzes
          .map((q) => Quiz(
                id: q.quizId?.toString() ?? '',
                title: q.title,
                description: q.description ?? '',
                imageUrl: q.imageUrl,
              ))
          .toList();
      isLoading = false;
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheUsable()) {
      final cache = _memoryCache!;
      final favoriteIds = await _api.getFavoriteIds();
      _applyLoadedData(
        previews: cache.previews,
        favoriteIds: favoriteIds,
        loadedQuizzes: cache.quizzes,
        ingredientRefs: cache.ingredientRefs,
        equipementRefs: cache.equipementRefs,
        regimeRefs: cache.regimeRefs,
        typePlatRefs: cache.typePlatRefs,
        allergeneRefs: cache.allergeneRefs,
        userPreferences: cache.userPreferences,
      );
      return;
    }

    setState(() => isLoading = true);

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

      final previews = results[0] as List<RecettePreview>;
      final favoriteIds = results[1] as Set<String>;
      final loadedQuizzes = results[2] as List;
      final ingredientRefs = results[3] as List<Ingredient>;
      final equipementRefs = results[4] as List<Equipement>;
      final regimeRefs = results[5] as List<Regime>;
      final typePlatRefs = results[6] as List<TypePlat>;
      final allergeneRefs = results[7] as List<Allergene>;
      final userPreferences = results[8] as List<UserPreference>;

      _applyLoadedData(
        previews: previews,
        favoriteIds: favoriteIds,
        loadedQuizzes: loadedQuizzes,
        ingredientRefs: ingredientRefs,
        equipementRefs: equipementRefs,
        regimeRefs: regimeRefs,
        typePlatRefs: typePlatRefs,
        allergeneRefs: allergeneRefs,
        userPreferences: userPreferences,
      );
    } catch (e) {
      setState(() {
        isLoading = false;
        _loadWarning = 'Erreur chargement data bridge: $e';
      });
      debugPrint('Erreur chargement données: $e');
    }
  }

  Future<void> _goToRecipePage(int page) async {
    if (page < 0 || page == _recipePage || isLoading) return;
    setState(() {
      _recipePage = page;
      _recomputeVisibleRecipes();
    });
  }

  Future<void> _toggleFavorite(RecipeDisplayModel recipe) async {
    // Bascule locale immédiate : l'UI répond toujours, même hors ligne.
    final wasFavorite = FavoritesService().isFavorite(recipe.id);
    final nowFavorite = !wasFavorite;
    setState(() => recipe.isFavorite = nowFavorite);

    if (nowFavorite) {
      FavoritesService().addFavorite(FavoriteRecipe(
        id: recipe.id,
        title: recipe.title,
        category: recipe.category,
        duration: recipe.duration,
        imageUrl: recipe.imageUrl,
      ));
    } else {
      FavoritesService().removeFavorite(recipe.id);
    }

    // Synchronisation backend au mieux (nécessite une session active).
    final success = await _api.toggleFavorite(recipe.id);
    if (!mounted) return;
    if (nowFavorite && !success && !_api.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Favori enregistré sur cet appareil. Connecte-toi pour le synchroniser.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Chargement en cours',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_loadWarning != null && _recipeSource.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5ECD9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _loadWarning!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7A2E2E), fontSize: 15),
            ),
          ),
        ),
      );
    }

    final desktop = isDesktop(context);

    final hPad = desktop ? 32.0 : 16.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5ECD9),
      endDrawer: desktop
          ? Drawer(
              width: 430,
              backgroundColor: const Color(0xFFF8F2E5),
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(24)),
              ),
              child: SafeArea(
                child: DesktopFilterDrawerContent(
                  initialFilters: _filters,
                  ingredientOptions: _ingredientOptions,
                  utensilOptions: _utensilOptions,
                  dietOptions: _dietOptions,
                  allergenOptions: _allergenOptions,
                  onApply: (filters) {
                    setState(() {
                      _filters = filters;
                      _recomputeVisibleRecipes(resetPage: true);
                    });
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header fixe (ne scrolle pas)
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(hPad, desktop ? 32 : 16, hPad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, desktop),
                      const SizedBox(height: 16),
                      if (!desktop) ...[
                        _buildMobileSearchBar(),
                        const SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),

                // Contenu scrollable
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadData(forceRefresh: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          hPad, 0, hPad, desktop ? 32 : 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Message "aucun résultat" si recherche active
                          if ((_searchQuery.isNotEmpty || _hasActiveFilters) &&
                              _filteredRecommended.isEmpty &&
                              _filteredAll.isEmpty) ...[
                            const SizedBox(height: 48),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Aucune recette trouvée pour "$_searchQuery" avec ces filtres.'
                                        : 'Aucune recette ne correspond aux filtres sélectionnés.',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Section "Juste pour vous"
                          if (_filteredRecommended.isNotEmpty) ...[
                            _buildSectionTitle(
                              'Juste pour vous',
                              icon: Icons.star_rounded,
                              onViewAll: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AllRecipesPage(
                                    title: 'Juste pour vous',
                                    recipes: _filteredRecommended,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (desktop)
                              _buildRecipeGrid(context, _filteredRecommended)
                            else
                              SizedBox(
                                height: 220,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _filteredRecommended.length,
                                  itemBuilder: (context, index) {
                                    final recipe = _filteredRecommended[index];
                                    return Padding(
                                      key: ValueKey(recipe.id),
                                      padding: const EdgeInsets.only(right: 12),
                                      child: RecipeCard(
          recipe: recipe,
          onToggleFavorite: () => _toggleFavorite(recipe),
        ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],

                          // Section "Nos recettes"
                          if (_filteredAll.isNotEmpty) ...[
                            _buildSectionTitle(
                              'Nos recettes ($_filteredRecipeCount)',
                              icon: Icons.restaurant_rounded,
                              showViewAll: false,
                            ),
                            const SizedBox(height: 12),
                            if (desktop)
                              _buildRecipeGrid(context, _filteredAll)
                            else
                              SizedBox(
                                height: 220,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _filteredAll.length,
                                  itemBuilder: (context, index) {
                                    final recipe = _filteredAll[index];
                                    return Padding(
                                      key: ValueKey(recipe.id),
                                      padding: const EdgeInsets.only(right: 12),
                                      child: RecipeCard(
          recipe: recipe,
          onToggleFavorite: () => _toggleFavorite(recipe),
        ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 12),
                            _buildRecipePagination(),
                            const SizedBox(height: 24),
                          ],

                          // Section "Testez vos connaissances"
                          if (quizzes.isNotEmpty &&
                              _searchQuery.isEmpty &&
                              !_hasActiveFilters) ...[
                            _buildSectionTitle('Testez vos connaissances',
                                showViewAll: false,
                                icon: Icons.psychology_rounded),
                            const SizedBox(height: 12),
                            if (desktop)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: quizzes
                                    .map((quiz) => SizedBox(
                                          key: ValueKey(quiz.id),
                                          width: 340,
                                          child: QuizCard(quiz: quiz, desktop: true),
                                        ))
                                    .toList(),
                              )
                            else
                              ...quizzes.map((quiz) => Padding(
                                    key: ValueKey(quiz.id),
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: QuizCard(quiz: quiz),
                                  )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool desktop) {
    if (desktop) {
      return Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour 👋',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F6B3F),
                ),
              ),
              Text(
                'Mangez sainement, naturellement',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 430,
            child: Row(
              children: [
                Expanded(
                  child: _buildSearchField(onChanged: _onSearchChanged),
                ),
                const SizedBox(width: 8),
                _buildFilterButton(),
                const SizedBox(width: 8),
                _buildSortButton(),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bonjour 👋',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _getFormattedDate(),
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche'
    ];
    const months = [
      'jan.',
      'fév.',
      'mar.',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sep.',
      'oct.',
      'nov.',
      'déc.'
    ];
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  Widget _buildMobileSearchBar() {
    return Row(
      children: [
        Expanded(
          child: _buildSearchField(onChanged: _onSearchChanged),
        ),
        const SizedBox(width: 8),
        _buildFilterButton(),
        const SizedBox(width: 8),
        _buildSortButton(),
      ],
    );
  }

  Widget _buildSearchField({required ValueChanged<String> onChanged}) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Rechercher une recette…',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[400]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                  onPressed: () {
                    _debounceTimer?.cancel();
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _recomputeVisibleRecipes(resetPage: true);
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: 'Ouvrir les filtres',
          child: Material(
            color: _hasActiveFilters ? const Color(0xFF2F6B3F) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.tune_rounded,
                  color: _hasActiveFilters
                      ? Colors.white
                      : const Color(0xFF2F6B3F),
                ),
              ),
            ),
          ),
        ),
        if (_activeFiltersCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF39A5A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_activeFiltersCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSortButton() {
    final hasSort = _sortMode != RecipeSortMode.pertinence;
    return PopupMenuButton<RecipeSortMode>(
      tooltip: 'Trier les recettes',
      initialValue: _sortMode,
      onSelected: (value) => setState(() {
        _sortMode = value;
        _recomputeVisibleRecipes(resetPage: true);
      }),
      itemBuilder: (context) => RecipeSortMode.values
          .map(
            (mode) => PopupMenuItem<RecipeSortMode>(
              value: mode,
              child: Row(
                children: [
                  Expanded(child: Text(mode.label)),
                  if (mode == _sortMode)
                    const Icon(Icons.check_rounded, size: 16),
                ],
              ),
            ),
          )
          .toList(),
      child: Material(
        color: hasSort ? const Color(0xFF2F6B3F) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.sort_rounded,
            color: hasSort ? Colors.white : const Color(0xFF2F6B3F),
          ),
        ),
      ),
    );
  }

  void _openMobileFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF8F2E5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: MobileFilterSheetContent(
                initialFilters: _filters,
                ingredientOptions: _ingredientOptions,
                utensilOptions: _utensilOptions,
                dietOptions: _dietOptions,
                allergenOptions: _allergenOptions,
                onApply: (filters) {
                  setState(() {
                    _filters = filters;
                    _recomputeVisibleRecipes(resetPage: true);
                  });
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipeGrid(
      BuildContext context, List<RecipeDisplayModel> recipes) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100
        ? 4
        : width >= 850
            ? 3
            : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 210,
      ),
      itemCount: recipes.length,
      itemBuilder: (_, i) {
        final recipe = recipes[i];
        return KeyedSubtree(
          key: ValueKey(recipe.id),
          child: RecipeCard(
          recipe: recipe,
          onToggleFavorite: () => _toggleFavorite(recipe),
        ),
        );
      },
    );
  }

  Widget _buildRecipePagination() {
    final canGoPrevious = _recipePage > 0 && !isLoading;
    final canGoNext = _hasNextRecipePage && !isLoading;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed:
              canGoPrevious ? () => _goToRecipePage(_recipePage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Précédent'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Page ${_recipePage + 1} / $_totalRecipePages',
            style: const TextStyle(
              color: Color(0xFF1F2E1F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: canGoNext ? () => _goToRecipePage(_recipePage + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Suivant'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title,
      {bool showViewAll = true, IconData? icon, VoidCallback? onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: const Color(0xFF2F6B3F)),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2E1F),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        if (showViewAll && onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2F6B3F),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Voir tout',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

}
