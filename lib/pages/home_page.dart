import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'all_recipes_page.dart';
import 'home/filter_panel.dart';
import 'home/home_controller.dart';
import 'home/home_models.dart';
import 'home/quiz_card.dart';
import 'home/recipe_card.dart';
import 'taste/taste_entry.dart';
import 'taste/taste_recommendation.dart' show topIngredients;

export 'home/home_models.dart';
export '../widgets/favorite_button.dart';

class HomePage extends StatefulWidget {
  /// `controller` permet d'injecter un état préparé (tests) ; sinon la page
  /// crée le sien.
  final HomeController? controller;

  const HomePage({super.key, this.controller});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _c = widget.controller ?? HomeController();
  late final bool _ownsController = widget.controller == null;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onControllerChanged);
    _c.load();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _c.removeListener(_onControllerChanged);
    if (_ownsController) _c.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _c.setSearchQuery(value);
    });
  }

  void _openFilters() {
    if (isDesktop(context)) {
      _scaffoldKey.currentState?.openEndDrawer();
      return;
    }
    _openMobileFiltersSheet();
  }

  Future<void> _openTasteSwipe() async {
    final saved = await openTasteSwipe(context);
    if (saved && mounted) await _c.load();
  }

  Future<void> _toggleFavorite(RecipeDisplayModel recipe) async {
    final savedOnlyLocally = await _c.toggleFavorite(recipe);
    if (!mounted || !savedOnlyLocally) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Favori enregistré sur cet appareil. Connecte-toi pour le synchroniser.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isLoading) {
      return Scaffold(
        body: Center(
          child: Semantics(
            label: 'Chargement en cours',
            child: const CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_c.loadWarning != null && !_c.hasRecipes) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5ECD9),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _c.loadWarning!,
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
                  initialFilters: _c.filters,
                  ingredientOptions: _c.ingredientOptions,
                  utensilOptions: _c.utensilOptions,
                  dietOptions: _c.dietOptions,
                  allergenOptions: _c.allergenOptions,
                  onApply: (filters) {
                    _c.applyFilters(filters);
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
                    onRefresh: () => _c.load(forceRefresh: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                          hPad, 0, hPad, desktop ? 32 : 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Invitation au swipe de goûts (tant qu'aucun profil)
                          if (!_c.hasTasteProfile &&
                              _c.searchQuery.isEmpty &&
                              !_c.hasActiveFilters) ...[
                            TastePromptCard(onStart: _openTasteSwipe),
                            const SizedBox(height: 24),
                          ],

                          // Message "aucun résultat" si recherche active
                          if ((_c.searchQuery.isNotEmpty || _c.hasActiveFilters) &&
                              _c.recommendedRecipes.isEmpty &&
                              _c.visibleRecipes.isEmpty) ...[
                            const SizedBox(height: 48),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off,
                                      size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 12),
                                  Text(
                                    _c.searchQuery.isNotEmpty
                                        ? 'Aucune recette trouvée pour "${_c.searchQuery}" avec ces filtres.'
                                        : 'Aucune recette ne correspond aux filtres sélectionnés.',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Section "Juste pour vous"
                          if (_c.recommendedRecipes.isNotEmpty) ...[
                            _buildSectionTitle(
                              'Juste pour vous',
                              icon: Icons.star_rounded,
                              extraAction: _c.hasTasteProfile
                                  ? TextButton.icon(
                                      onPressed: _openTasteSwipe,
                                      icon: const Icon(Icons.swipe_rounded,
                                          size: 16),
                                      label: const Text(
                                        'Affiner',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF2F6B3F),
                                        minimumSize: const Size(44, 36),
                                      ),
                                    )
                                  : null,
                              onViewAll: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AllRecipesPage(
                                    title: 'Juste pour vous',
                                    recipes: _c.recommendedRecipes,
                                    onToggleFavorite: _toggleFavorite,
                                  ),
                                ),
                              ),
                            ),
                            if (_c.ingredientPreferences.isNotEmpty)
                              _buildTasteLine(),
                            const SizedBox(height: 12),
                            if (desktop)
                              _buildRecipeGrid(context, _c.recommendedRecipes,
                                  withReasons: true)
                            else
                              SizedBox(
                                height: 220,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _c.recommendedRecipes.length,
                                  itemBuilder: (context, index) {
                                    final recipe = _c.recommendedRecipes[index];
                                    return Padding(
                                      key: ValueKey(recipe.id),
                                      padding: const EdgeInsets.only(right: 12),
                                      child: RecipeCard(
          recipe: recipe,
          reason: _c.recommendationReasonFor(recipe.id),
          onToggleFavorite: () => _toggleFavorite(recipe),
        ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 24),
                          ],

                          // Section "Nos recettes"
                          if (_c.visibleRecipes.isNotEmpty) ...[
                            _buildSectionTitle(
                              'Nos recettes (${_c.filteredRecipeCount})',
                              icon: Icons.restaurant_rounded,
                              showViewAll: false,
                            ),
                            const SizedBox(height: 12),
                            if (desktop)
                              _buildRecipeGrid(context, _c.visibleRecipes)
                            else
                              SizedBox(
                                height: 220,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _c.visibleRecipes.length,
                                  itemBuilder: (context, index) {
                                    final recipe = _c.visibleRecipes[index];
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
                          if (_c.quizzes.isNotEmpty &&
                              _c.searchQuery.isEmpty &&
                              !_c.hasActiveFilters) ...[
                            _buildSectionTitle('Testez vos connaissances',
                                showViewAll: false,
                                icon: Icons.psychology_rounded),
                            const SizedBox(height: 12),
                            if (desktop)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: _c.quizzes
                                    .map((quiz) => SizedBox(
                                          key: ValueKey(quiz.id),
                                          width: 340,
                                          child: QuizCard(quiz: quiz, desktop: true),
                                        ))
                                    .toList(),
                              )
                            else
                              ..._c.quizzes.map((quiz) => Padding(
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _c.greeting,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F6B3F),
                ),
              ),
              const Text(
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
        Text(
          _c.greeting,
          style: const TextStyle(
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
          suffixIcon: _c.searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                  onPressed: () {
                    _debounceTimer?.cancel();
                    _searchController.clear();
                    _c.setSearchQuery('');
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
            color: _c.hasActiveFilters ? const Color(0xFF2F6B3F) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _openFilters,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.tune_rounded,
                  color: _c.hasActiveFilters
                      ? Colors.white
                      : const Color(0xFF2F6B3F),
                ),
              ),
            ),
          ),
        ),
        if (_c.activeFiltersCount > 0)
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
                '${_c.activeFiltersCount}',
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
    final hasSort = _c.sortMode != RecipeSortMode.pertinence;
    return PopupMenuButton<RecipeSortMode>(
      tooltip: 'Trier les recettes',
      initialValue: _c.sortMode,
      onSelected: _c.setSortMode,
      itemBuilder: (context) => RecipeSortMode.values
          .map(
            (mode) => PopupMenuItem<RecipeSortMode>(
              value: mode,
              child: Row(
                children: [
                  Expanded(child: Text(mode.label)),
                  if (mode == _c.sortMode)
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
                initialFilters: _c.filters,
                ingredientOptions: _c.ingredientOptions,
                utensilOptions: _c.utensilOptions,
                dietOptions: _c.dietOptions,
                allergenOptions: _c.allergenOptions,
                onApply: (filters) {
                  _c.applyFilters(filters);
                  Navigator.of(context).maybePop();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// « Selon vos goûts : Lentilles 67 % · Lait de coco 50 % ».
  Widget _buildTasteLine() {
    final top = topIngredients(_c.ingredientPreferences, count: 3)
        .map((p) => '${p.label} ${p.percent} %')
        .join(' · ');
    if (top.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        'Selon vos goûts : $top',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: Color(0xFF5C6B5C)),
      ),
    );
  }

  Widget _buildRecipeGrid(
      BuildContext context, List<RecipeDisplayModel> recipes,
      {bool withReasons = false}) {
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
          reason: withReasons ? _c.recommendationReasonFor(recipe.id) : null,
          onToggleFavorite: () => _toggleFavorite(recipe),
        ),
        );
      },
    );
  }

  Widget _buildRecipePagination() {
    final canGoPrevious = _c.canGoPrevious;
    final canGoNext = _c.canGoNext;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed:
              canGoPrevious ? () => _c.goToPage(_c.recipePage - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Précédent'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'Page ${_c.recipePage + 1} / ${_c.totalRecipePages}',
            style: const TextStyle(
              color: Color(0xFF1F2E1F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: canGoNext ? () => _c.goToPage(_c.recipePage + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Suivant'),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title,
      {bool showViewAll = true,
      IconData? icon,
      VoidCallback? onViewAll,
      Widget? extraAction}) {
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
        const Spacer(),
        if (extraAction != null) extraAction,
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
