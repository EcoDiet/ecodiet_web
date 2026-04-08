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
  final String? imageUrl;
  bool isFavorite;

  RecipeDisplayModel({
    required this.id,
    required this.title,
    required this.category,
    required this.ingredients,
    required this.duration,
    this.imageUrl,
    this.isFavorite = false,
  });

  static Future<RecipeDisplayModel> fromRecette(Recette recette, EcoDietApi api) async {
    final isFav = await api.isFavorite(recette.recetteId);
    final typePlat = await api.getRecetteComplete(recette.recetteId);

    return RecipeDisplayModel(
      id: recette.recetteId,
      title: recette.titre,
      category: typePlat?.typePlat?.libelle ?? 'Recette',
      ingredients: '${typePlat?.ingredients.length ?? 0} ingrédients',
      duration: "${recette.dureeMinute}'",
      imageUrl: recette.photo.isNotEmpty ? recette.photo : null,
      isFavorite: isFav,
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

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final EcoDietApi _api = EcoDietApi();
  
  List<RecipeDisplayModel> recommendedRecipes = [];
  List<RecipeDisplayModel> allRecipes = [];
  List<Quiz> quizzes = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  List<Recipe> get _filteredRecommended => _searchQuery.isEmpty
      ? recommendedRecipes
      : recommendedRecipes
          .where((r) =>
              r.title.toLowerCase().contains(_searchQuery) ||
              r.category.toLowerCase().contains(_searchQuery))
          .toList();

  List<Recipe> get _filteredAll => _searchQuery.isEmpty
      ? allRecipes
      : allRecipes
          .where((r) =>
              r.title.toLowerCase().contains(_searchQuery) ||
              r.category.toLowerCase().contains(_searchQuery))
          .toList();

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

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final recommended = await _api.getRecommendedRecettes(limit: 5);
      final recommendedModels = <RecipeDisplayModel>[];
      for (final r in recommended) {
        recommendedModels.add(await RecipeDisplayModel.fromRecette(r, _api));
      }

      final all = await _api.getAllRecettes();
      final allModels = <RecipeDisplayModel>[];
      for (final r in all.take(10)) {
        allModels.add(await RecipeDisplayModel.fromRecette(r, _api));
      }

      final loadedQuizzes = await _api.getAllQuizzes();

      setState(() {
        recommendedRecipes = recommendedModels;
        allRecipes = allModels;
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
      backgroundColor: const Color(0xFFF5ECD9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header fixe (ne scrolle pas)
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, desktop ? 32 : 16, hPad, 0),
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
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, desktop ? 32 : 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // Message "aucun résultat" si recherche active
                    if (_searchQuery.isNotEmpty &&
                        _filteredRecommended.isEmpty &&
                        _filteredAll.isEmpty) ...[
                      const SizedBox(height: 48),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              'Aucune recette trouvée pour "$_searchQuery"',
                              style: TextStyle(color: Colors.grey[500], fontSize: 14),
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
                    if (quizzes.isNotEmpty && _searchQuery.isEmpty) ...[
                      _buildSectionTitle('Testez vos connaissances', showViewAll: false, icon: Icons.psychology_rounded),
                      const SizedBox(height: 12),
                      if (desktop)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: quizzes
                              .map((quiz) => SizedBox(
                                    key: ValueKey(quiz.id),
                                    width: 340,
                                    child: _buildQuizCard(quiz, desktop: true),
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
          // Barre de recherche desktop
          Container(
            width: 300,
            height: 42,
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
              onChanged: _onSearchChanged,
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
      'Lundi', 'Mardi', 'Mercredi', 'Jeudi',
      'Vendredi', 'Samedi', 'Dimanche'
    ];
    const months = [
      'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.'
    ];
    return '${days[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }

  Widget _buildMobileSearchBar() {
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
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase().trim()),
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

  Widget _buildRecipeGrid(BuildContext context, List<RecipeDisplayModel> recipes) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 4 : width >= 850 ? 3 : 2;
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

  Widget _buildSectionTitle(String title, {bool showViewAll = true, IconData? icon, VoidCallback? onViewAll}) {
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
      label: 'Recette : ${recipe.title}, ${recipe.category}, ${recipe.duration}',
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
            Container(
              height: 110,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                gradient: recipe.imageUrl == null
                    ? const LinearGradient(
                        colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: recipe.imageUrl != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(recipe.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (recipe.imageUrl == null)
                    Center(
                      child: Icon(
                        Icons.eco,
                        size: 40,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 11, color: Colors.white),
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
                    tooltip: recipe.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      minimumSize: const Size(44, 44),
                    ),
                    icon: Icon(
                      recipe.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
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
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
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
                          size: 36,
                          color: Colors.white.withOpacity(0.7)),
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
    _listener = () { if (mounted) setState(() {}); };
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
