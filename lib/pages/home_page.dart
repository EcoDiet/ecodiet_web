import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../models/recette.dart';
import '../utils/responsive.dart';
import '../services/favorites_service.dart';
import 'all_recipes_page.dart';

/// Modèle local pour une recette avec favoris
class RecipeDisplayModel {
  final String id;
  final String title;
  final String category;
  final String ingredients;
  final String duration;
  final double? budgetEur;
  final String? imageUrl;
  bool isFavorite;

  RecipeDisplayModel({
    required this.id,
    required this.title,
    required this.category,
    required this.ingredients,
    required this.duration,
    this.budgetEur,
    this.imageUrl,
    this.isFavorite = false,
  });

  static RecipeDisplayModel fromPreview(
      RecettePreview recette, Set<String> favoriteIds) {
    return RecipeDisplayModel(
      id: recette.recetteId,
      title: recette.titre,
      category: recette.typePlatLibelle ?? 'Recette',
      ingredients: '',
      duration: recette.dureeMinute > 0 ? "${recette.dureeMinute} min" : '',
      budgetEur: null,
      imageUrl:
          recette.photo.isNotEmpty ? recetteImageUrl(recette.photo) : null,
      isFavorite: favoriteIds.contains(recette.recetteId),
    );
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
  budgetAsc,
  budgetDesc,
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final EcoDietApi _api = EcoDietApi();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<RecipeDisplayModel> recommendedRecipes = [];
  List<RecipeDisplayModel> allRecipes = [];
  List<Quiz> quizzes = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  RecipeFilters _filters = RecipeFilters.empty();
  RecipeSortMode _sortMode = RecipeSortMode.pertinence;

  static const List<String> _fallbackIngredients = [
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

  static const List<String> _fallbackUtensils = [
    'Poêle',
    'Four',
    'Casserole',
    'Mixeur',
    'Cuiseur vapeur',
    'Wok',
    'Grill',
  ];

  static const List<String> _fallbackDiets = [
    'Végétarien',
    'Végan',
    'Carnivore',
    'Pescétarien',
    'Sans gluten',
    'Sans lactose',
  ];

  static const List<String> _fallbackAllergens = [
    'Gluten',
    'Lactose',
    'Arachides',
    'Fruits à coque',
    'Œufs',
    'Soja',
    'Poisson',
  ];

  List<Recipe> get _filteredRecommended => _sortRecipes(
      recommendedRecipes.where(_matchesSearch).where(_matchesFilters).toList());

  List<Recipe> get _filteredAll => _sortRecipes(
      allRecipes.where(_matchesSearch).where(_matchesFilters).toList());

  bool get _hasActiveFilters => _filters.hasAny;

  int get _activeFiltersCount => _filters.activeCount;

  List<String> get _ingredientOptions {
    final fromData = allRecipes
        .expand((r) => r.ingredients.split(','))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    fromData.sort();
    return fromData.isNotEmpty ? fromData : _fallbackIngredients;
  }

  List<String> get _utensilOptions => _fallbackUtensils;

  List<String> get _dietOptions {
    final categoryText = allRecipes
        .map((r) => r.category.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    categoryText.sort();
    return {
      ..._fallbackDiets,
      ...categoryText,
    }.toList()
      ..sort();
  }

  List<String> get _allergenOptions => _fallbackAllergens;

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
      if (mounted) setState(() => _searchQuery = value.toLowerCase().trim());
    });
  }

  bool _matchesSearch(RecipeDisplayModel recipe) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery;
    return recipe.title.toLowerCase().contains(q) ||
        recipe.category.toLowerCase().contains(q) ||
        recipe.ingredients.toLowerCase().contains(q);
  }

  bool _matchesFilters(RecipeDisplayModel recipe) {
    final haystack = '${recipe.title} ${recipe.category} ${recipe.ingredients}'
        .toLowerCase();

    if (_filters.ingredients.isNotEmpty &&
        !_filters.ingredients.any((v) => haystack.contains(v.toLowerCase()))) {
      return false;
    }

    if (_filters.utensils.isNotEmpty) {
      // En attendant les métadonnées ustensiles depuis l'API, on ne bloque pas les résultats.
    }

    final duration = _parseDurationMinutes(recipe.duration);
    if (_filters.minTimeMinutes != null &&
        duration != null &&
        duration < _filters.minTimeMinutes!) {
      return false;
    }
    if (_filters.maxTimeMinutes != null &&
        duration != null &&
        duration > _filters.maxTimeMinutes!) {
      return false;
    }

    if (_filters.diets.isNotEmpty &&
        !_filters.diets.any((v) => haystack.contains(v.toLowerCase()))) {
      return false;
    }

    if (_filters.allergens.isNotEmpty &&
        _filters.allergens.any((v) => haystack.contains(v.toLowerCase()))) {
      return false;
    }

    return true;
  }

  int? _parseDurationMinutes(String duration) {
    final match = RegExp(r'(\d+)').firstMatch(duration);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  List<Recipe> _sortRecipes(List<Recipe> recipes) {
    final sorted = [...recipes];
    switch (_sortMode) {
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
          final aMin = _parseDurationMinutes(a.duration) ?? 99999;
          final bMin = _parseDurationMinutes(b.duration) ?? 99999;
          return aMin.compareTo(bMin);
        });
        return sorted;
      case RecipeSortMode.tempsDesc:
        sorted.sort((a, b) {
          final aMin = _parseDurationMinutes(a.duration) ?? -1;
          final bMin = _parseDurationMinutes(b.duration) ?? -1;
          return bMin.compareTo(aMin);
        });
        return sorted;
      case RecipeSortMode.budgetAsc:
        sorted.sort((a, b) {
          final aPrice = a.budgetEur;
          final bPrice = b.budgetEur;
          if (aPrice == null && bPrice == null) return 0;
          if (aPrice == null) return 1;
          if (bPrice == null) return -1;
          return aPrice.compareTo(bPrice);
        });
        return sorted;
      case RecipeSortMode.budgetDesc:
        sorted.sort((a, b) {
          final aPrice = a.budgetEur;
          final bPrice = b.budgetEur;
          if (aPrice == null && bPrice == null) return 0;
          if (aPrice == null) return 1;
          if (bPrice == null) return -1;
          return bPrice.compareTo(aPrice);
        });
        return sorted;
    }
  }

  String _sortLabel(RecipeSortMode mode) {
    switch (mode) {
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
      case RecipeSortMode.budgetAsc:
        return 'Moins cher';
      case RecipeSortMode.budgetDesc:
        return 'Plus cher';
    }
  }

  void _openFilters() {
    if (isDesktop(context)) {
      _scaffoldKey.currentState?.openEndDrawer();
      return;
    }
    _openMobileFiltersSheet();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // 2 requêtes au lieu de ~120 : previews + favoris en parallèle
      final results = await Future.wait([
        _api.getRecettesPreview(limit: 20),
        _api.getFavoriteIds(),
        _api.getAllQuizzes(),
      ]);

      final previews = results[0] as List<RecettePreview>;
      final favoriteIds = results[1] as Set<String>;
      final loadedQuizzes = results[2] as List;

      final models = previews
          .map((r) => RecipeDisplayModel.fromPreview(r, favoriteIds))
          .toList();

      setState(() {
        recommendedRecipes = models.take(5).toList();
        allRecipes = models;
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
    } catch (e) {
      setState(() => isLoading = false);
      debugPrint('Erreur chargement données: $e');
    }
  }

  Future<void> _toggleFavorite(RecipeDisplayModel recipe) async {
    final success = await _api.toggleFavorite(recipe.id);
    if (success) {
      setState(() {
        recipe.isFavorite = !recipe.isFavorite;
      });
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
                child: _DesktopFilterDrawerContent(
                  initialFilters: _filters,
                  ingredientOptions: _ingredientOptions,
                  utensilOptions: _utensilOptions,
                  dietOptions: _dietOptions,
                  allergenOptions: _allergenOptions,
                  onApply: (filters) {
                    setState(() => _filters = filters);
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
                    onRefresh: _loadData,
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
                                      child: _buildRecipeCard(context, recipe),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],

                          // Section "Nos recettes"
                          if (_filteredAll.isNotEmpty) ...[
                            _buildSectionTitle(
                              'Nos recettes',
                              icon: Icons.restaurant_rounded,
                              onViewAll: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AllRecipesPage(
                                    title: 'Nos recettes',
                                    recipes: _filteredAll,
                                  ),
                                ),
                              ),
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
                                      child: _buildRecipeCard(context, recipe),
                                    );
                                  },
                                ),
                              ),
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
                                          child: _buildQuizCard(quiz,
                                              desktop: true),
                                        ))
                                    .toList(),
                              )
                            else
                              ...quizzes.map((quiz) => Padding(
                                    key: ValueKey(quiz.id),
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildQuizCard(quiz),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
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
          child: _buildSearchField(
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase().trim()),
          ),
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
            color: Colors.black.withOpacity(0.06),
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
                    _searchController.clear();
                    setState(() => _searchQuery = '');
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
      onSelected: (value) => setState(() => _sortMode = value),
      itemBuilder: (context) => RecipeSortMode.values
          .map(
            (mode) => PopupMenuItem<RecipeSortMode>(
              value: mode,
              child: Row(
                children: [
                  Expanded(child: Text(_sortLabel(mode))),
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
              child: _MobileFilterSheetContent(
                initialFilters: _filters,
                ingredientOptions: _ingredientOptions,
                utensilOptions: _utensilOptions,
                dietOptions: _dietOptions,
                allergenOptions: _allergenOptions,
                onApply: (filters) {
                  setState(() => _filters = filters);
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
          child: _buildRecipeCard(context, recipe),
        );
      },
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

  Widget _buildRecipeCard(BuildContext context, RecipeDisplayModel recipe) {
    final desktop = isDesktop(context);
    return Semantics(
      label:
          'Recette : ${recipe.title}, ${recipe.category}, ${recipe.duration}',
      button: true,
      child: InkWell(
        onTap: () => Navigator.pushNamed(
          context,
          '/recipe',
          arguments: {
            'id': recipe.id,
            'title': recipe.title,
            'description': recipe.category,
            'duration': recipe.duration,
          },
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: desktop ? null : 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient de fond affiché si l'image échoue ou est absente
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(Icons.eco,
                              size: 40, color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                      if (recipe.imageUrl != null)
                        CachedNetworkImage(
                          imageUrl: recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          placeholder: (_, __) => const SizedBox.shrink(),
                        ),
                      // Badge durée
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined,
                                  size: 11, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                recipe.duration,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2E1F),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recipe.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2F6B3F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recipe.ingredients,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _toggleFavorite(recipe),
                      tooltip: recipe.isFavorite
                          ? 'Retirer des favoris'
                          : 'Ajouter aux favoris',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        minimumSize: const Size(44, 44),
                      ),
                      icon: Icon(
                        recipe.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: Colors.red[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard(Quiz quiz, {bool desktop = false}) {
    void onTap() => Navigator.pushNamed(
          context,
          '/quiz',
          arguments: {
            'id': quiz.id,
            'title': quiz.title,
            'description': quiz.description,
          },
        );

    if (desktop) {
      // Carte horizontale compacte : pas de bannière image, hauteur libre
      return Semantics(
        label: 'Quiz : ${quiz.title}',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icône colorée à gauche
                Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4A259), Color(0xFFEA853D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(quiz.icon, size: 28, color: Colors.white),
                ),
                // Texte
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2E1F),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          quiz.description,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // Bouton jouer
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4A259),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Jouer',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile : carte verticale avec bannière
    return Semantics(
      label: 'Quiz : ${quiz.title}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: quiz.imageUrl == null
                      ? const LinearGradient(
                          colors: [Color(0xFFF4A259), Color(0xFFEA853D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  image: quiz.imageUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(quiz.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: quiz.imageUrl == null
                    ? Center(
                        child: Icon(quiz.icon,
                            size: 36, color: Colors.white.withOpacity(0.7)),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2E1F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quiz.description,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4A259),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Jouer',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeFilters {
  Set<String> ingredients;
  Set<String> utensils;
  Set<String> diets;
  Set<String> allergens;
  int? minTimeMinutes;
  int? maxTimeMinutes;
  double minBudget;
  double maxBudget;

  RecipeFilters({
    required this.ingredients,
    required this.utensils,
    required this.diets,
    required this.allergens,
    this.minTimeMinutes,
    this.maxTimeMinutes,
    this.minBudget = 0,
    this.maxBudget = 100,
  });

  factory RecipeFilters.empty() {
    return RecipeFilters(
      ingredients: <String>{},
      utensils: <String>{},
      diets: <String>{},
      allergens: <String>{},
      minBudget: 0,
      maxBudget: 100,
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
      minBudget: minBudget,
      maxBudget: maxBudget,
    );
  }

  bool get hasAny => activeCount > 0;

  int get activeCount {
    var count = 0;
    if (ingredients.isNotEmpty) count++;
    if (utensils.isNotEmpty) count++;
    if (diets.isNotEmpty) count++;
    if (allergens.isNotEmpty) count++;
    if (minTimeMinutes != null || maxTimeMinutes != null) count++;
    if (minBudget > 0 || maxBudget < 100) count++;
    return count;
  }

  void reset() {
    ingredients.clear();
    utensils.clear();
    diets.clear();
    allergens.clear();
    minTimeMinutes = null;
    maxTimeMinutes = null;
    minBudget = 0;
    maxBudget = 100;
  }
}

class _DesktopFilterDrawerContent extends StatelessWidget {
  final RecipeFilters initialFilters;
  final List<String> ingredientOptions;
  final List<String> utensilOptions;
  final List<String> dietOptions;
  final List<String> allergenOptions;
  final ValueChanged<RecipeFilters> onApply;

  const _DesktopFilterDrawerContent({
    required this.initialFilters,
    required this.ingredientOptions,
    required this.utensilOptions,
    required this.dietOptions,
    required this.allergenOptions,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return _FilterPanel(
      desktop: true,
      initialFilters: initialFilters,
      ingredientOptions: ingredientOptions,
      utensilOptions: utensilOptions,
      dietOptions: dietOptions,
      allergenOptions: allergenOptions,
      onApply: onApply,
      onClose: () => Navigator.of(context).maybePop(),
    );
  }
}

class _MobileFilterSheetContent extends StatelessWidget {
  final RecipeFilters initialFilters;
  final List<String> ingredientOptions;
  final List<String> utensilOptions;
  final List<String> dietOptions;
  final List<String> allergenOptions;
  final ValueChanged<RecipeFilters> onApply;

  const _MobileFilterSheetContent({
    required this.initialFilters,
    required this.ingredientOptions,
    required this.utensilOptions,
    required this.dietOptions,
    required this.allergenOptions,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return _FilterPanel(
      desktop: false,
      initialFilters: initialFilters,
      ingredientOptions: ingredientOptions,
      utensilOptions: utensilOptions,
      dietOptions: dietOptions,
      allergenOptions: allergenOptions,
      onApply: onApply,
      onClose: () => Navigator.of(context).maybePop(),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  final bool desktop;
  final RecipeFilters initialFilters;
  final List<String> ingredientOptions;
  final List<String> utensilOptions;
  final List<String> dietOptions;
  final List<String> allergenOptions;
  final ValueChanged<RecipeFilters> onApply;
  final VoidCallback onClose;

  const _FilterPanel({
    required this.desktop,
    required this.initialFilters,
    required this.ingredientOptions,
    required this.utensilOptions,
    required this.dietOptions,
    required this.allergenOptions,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late RecipeFilters _draft;
  late TextEditingController _minTimeController;
  late TextEditingController _maxTimeController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters.copy();
    _minTimeController = TextEditingController(
      text: _draft.minTimeMinutes?.toString() ?? '',
    );
    _maxTimeController = TextEditingController(
      text: _draft.maxTimeMinutes?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minTimeController.dispose();
    _maxTimeController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _draft.reset();
      _minTimeController.text = '';
      _maxTimeController.text = '';
    });
  }

  void _apply() {
    final min = int.tryParse(_minTimeController.text.trim());
    final max = int.tryParse(_maxTimeController.text.trim());
    _draft.minTimeMinutes = min;
    _draft.maxTimeMinutes = max;
    if (_draft.minTimeMinutes != null &&
        _draft.maxTimeMinutes != null &&
        _draft.minTimeMinutes! > _draft.maxTimeMinutes!) {
      final tmp = _draft.minTimeMinutes!;
      _draft.minTimeMinutes = _draft.maxTimeMinutes;
      _draft.maxTimeMinutes = tmp;
    }
    widget.onApply(_draft.copy());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              const Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2E1F),
                ),
              ),
              const SizedBox(width: 10),
              if (_draft.activeCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6B3F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_draft.activeCount} ${_draft.activeCount > 1 ? 'actifs' : 'actif'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _FilterMultiSelectCard(
                title: 'Ingrédients',
                hintText: 'Rechercher un ingrédient',
                options: widget.ingredientOptions,
                selected: _draft.ingredients,
                onChanged: (values) =>
                    setState(() => _draft.ingredients = values),
              ),
              const SizedBox(height: 12),
              _FilterMultiSelectCard(
                title: 'Ustensiles',
                hintText: 'Rechercher un ustensile',
                options: widget.utensilOptions,
                selected: _draft.utensils,
                onChanged: (values) => setState(() => _draft.utensils = values),
              ),
              const SizedBox(height: 12),
              _FilterCard(
                title: 'Temps de cuisine (min)',
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minTimeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'De',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _maxTimeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'A',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FilterCard(
                title: 'Budget (EUR)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RangeSlider(
                      values: RangeValues(_draft.minBudget, _draft.maxBudget),
                      min: 0,
                      max: 100,
                      divisions: 20,
                      labels: RangeLabels(
                        '${_draft.minBudget.round()} EUR',
                        '${_draft.maxBudget.round()} EUR',
                      ),
                      activeColor: const Color(0xFF2F6B3F),
                      onChanged: (values) {
                        setState(() {
                          _draft.minBudget = values.start;
                          _draft.maxBudget = values.end;
                        });
                      },
                    ),
                    Text(
                      'De ${_draft.minBudget.round()} EUR a ${_draft.maxBudget.round()} EUR',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _FilterMultiSelectCard(
                title: 'Type de régime',
                hintText: 'Rechercher un régime',
                options: widget.dietOptions,
                selected: _draft.diets,
                onChanged: (values) => setState(() => _draft.diets = values),
              ),
              const SizedBox(height: 12),
              _FilterMultiSelectCard(
                title: 'Allergènes à éviter',
                hintText: 'Rechercher un allergène',
                options: widget.allergenOptions,
                selected: _draft.allergens,
                onChanged: (values) =>
                    setState(() => _draft.allergens = values),
              ),
              const SizedBox(height: 8),
              Text(
                'Note : filtres en partie basés sur des valeurs temporaires, en attente des distincts API.',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2F6B3F)),
                    foregroundColor: const Color(0xFF2F6B3F),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F6B3F),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6DCC9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2E1F),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _FilterMultiSelectCard extends StatefulWidget {
  final String title;
  final String hintText;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _FilterMultiSelectCard({
    required this.title,
    required this.hintText,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_FilterMultiSelectCard> createState() => _FilterMultiSelectCardState();
}

class _FilterMultiSelectCardState extends State<_FilterMultiSelectCard> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final visible = widget.options
        .where((o) => o.toLowerCase().contains(_query.toLowerCase()))
        .take(8)
        .toList();

    return _FilterCard(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<String>(
            optionsBuilder: (value) {
              final q = value.text.trim().toLowerCase();
              if (q.isEmpty) {
                return widget.options
                    .where((o) => !widget.selected.contains(o))
                    .take(6);
              }
              return widget.options
                  .where((o) =>
                      o.toLowerCase().contains(q) &&
                      !widget.selected.contains(o))
                  .take(6);
            },
            onSelected: (choice) {
              final next = {...widget.selected, choice};
              widget.onChanged(next);
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              );
            },
          ),
          if (widget.selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.selected
                  .map((s) => InputChip(
                        label: Text(s),
                        onDeleted: () {
                          final next = {...widget.selected}..remove(s);
                          widget.onChanged(next);
                        },
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          ...visible.map(
            (option) => CheckboxListTile(
              value: widget.selected.contains(option),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(option, style: const TextStyle(fontSize: 13)),
              onChanged: (checked) {
                final next = {...widget.selected};
                if (checked == true) {
                  next.add(option);
                } else {
                  next.remove(option);
                }
                widget.onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton favori isolé : seul ce widget se reconstruit quand les favoris changent.
class FavoriteButton extends StatefulWidget {
  final String recipeId;
  final VoidCallback onToggle;

  const FavoriteButton({
    Key? key,
    required this.recipeId,
    required this.onToggle,
  }) : super(key: key);

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    FavoritesService().addListener(_listener);
  }

  @override
  void dispose() {
    FavoritesService().removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFav = FavoritesService().isFavorite(widget.recipeId);
    return IconButton(
      onPressed: widget.onToggle,
      tooltip: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
      style: IconButton.styleFrom(
        backgroundColor: Colors.red[50],
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 20,
        color: Colors.red[400],
      ),
    );
  }
}
