import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/favorites_service.dart';
import 'all_recipes_page.dart';

/// Modèle pour une recette
class Recipe {
  final String id;
  final String title;
  final String category;
  final String ingredients;
  final String duration;
  final String? imageUrl;
  bool isFavorite;

  Recipe({
    required this.id,
    required this.title,
    required this.category,
    required this.ingredients,
    required this.duration,
    this.imageUrl,
    this.isFavorite = false,
  });
}

/// Modèle pour un quiz
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
  // TODO: Remplacer par les données récupérées depuis l'API/base de données
  List<Recipe> recommendedRecipes = [];
  List<Recipe> allRecipes = [];
  List<Quiz> quizzes = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    FavoritesService().addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    FavoritesService().removeListener(_onFavoritesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadData() async {
    // TODO: Remplacer par les appels API réels
    // Simulation de chargement de données
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    setState(() {
      // Données de démonstration - à remplacer par les vraies données
      recommendedRecipes = [
        Recipe(
          id: '1',
          title: 'Salade de quinoa',
          category: 'Entrée',
          ingredients: '5 ingrédients',
          duration: "15'",
        ),
        Recipe(
          id: '2',
          title: 'Soupe de lentilles',
          category: 'Plat',
          ingredients: '6 ingrédients',
          duration: "30'",
        ),
        Recipe(
          id: '3',
          title: 'Smoothie vert',
          category: 'Boisson',
          ingredients: '4 ingrédients',
          duration: "5'",
        ),
      ];

      allRecipes = [
        Recipe(
          id: '4',
          title: 'Bowl Buddha',
          category: 'Plat',
          ingredients: '8 ingrédients',
          duration: "20'",
        ),
        Recipe(
          id: '5',
          title: 'Tarte aux légumes',
          category: 'Plat',
          ingredients: '7 ingrédients',
          duration: "45'",
        ),
      ];

      quizzes = [
        Quiz(
          id: '1',
          title: 'Vitamines & Nutriments',
          description: 'Testez vos connaissances sur les vitamines et nutriments',
          icon: Icons.science_outlined,
        ),
        Quiz(
          id: '2',
          title: 'Fruits & Bienfaits',
          description: 'Les fruits et leurs bienfaits pour la santé',
          icon: Icons.local_florist_outlined,
        ),
      ];

      isLoading = false;
    });
  }

  void _toggleFavorite(Recipe recipe) {
    FavoritesService().toggle(FavoriteRecipe(
      id: recipe.id,
      title: recipe.title,
      category: recipe.category,
      duration: recipe.duration,
      imageUrl: recipe.imageUrl,
    ));
    // TODO: Sauvegarder le statut favori dans la base de données
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: desktop
                    ? const EdgeInsets.all(32.0)
                    : const EdgeInsets.fromLTRB(16, 16, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(context, desktop),
                    const SizedBox(height: 16),

                    // Barre de recherche mobile
                    if (!desktop) ...[
                      _buildMobileSearchBar(),
                      const SizedBox(height: 20),
                    ],

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
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildRecipeCard(
                                  context,
                                  _filteredRecommended[index],
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
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildRecipeCard(
                                  context,
                                  _filteredAll[index],
                                ),
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
                                    width: 340,
                                    child: _buildQuizCard(quiz, desktop: true),
                                  ))
                              .toList(),
                        )
                      else
                        ...quizzes.map((quiz) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildQuizCard(quiz),
                            )),
                    ],
                  ],
                ),
              ),
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

  Widget _buildRecipeGrid(BuildContext context, List<Recipe> recipes) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 4 : width >= 850 ? 3 : 2;
    final spacing = 12.0;
    final cardWidth = (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: recipes
          .map((r) => SizedBox(width: cardWidth, child: _buildRecipeCard(context, r)))
          .toList(),
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

  Widget _buildRecipeCard(BuildContext context, Recipe recipe) {
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
              color: Colors.black.withOpacity(0.05),
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
                        image: NetworkImage(recipe.imageUrl!),
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
                    tooltip: FavoritesService().isFavorite(recipe.id)
                        ? 'Retirer des favoris'
                        : 'Ajouter aux favoris',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      minimumSize: const Size(44, 44),
                    ),
                    icon: Icon(
                      FavoritesService().isFavorite(recipe.id)
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
              color: Colors.black.withOpacity(0.05),
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
                        image: NetworkImage(quiz.imageUrl!),
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
