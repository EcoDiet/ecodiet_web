import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/favorites_service.dart';

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
    setState(() {});
  }

  Future<void> _loadData() async {
    // TODO: Remplacer par les appels API réels
    // Simulation de chargement de données
    await Future.delayed(const Duration(milliseconds: 500));

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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final desktop = isDesktop(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(desktop ? 32.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(context, desktop),
                    const SizedBox(height: 24),

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
                      _buildSectionTitle('⭐ Juste pour vous'),
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
                      _buildSectionTitle('🍽️ Nos recettes'),
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
                      _buildSectionTitle('🧠 Testez vos connaissances', showViewAll: false),
                      const SizedBox(height: 12),
                      if (desktop)
                        GridView.count(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.8,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: quizzes
                              .map((quiz) => _buildQuizCard(quiz))
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
                'Bonjour !',
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Bonjour !',
              style: TextStyle(
                fontSize: 24,
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
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/profile'),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 28, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeGrid(BuildContext context, List<Recipe> recipes) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 4 : width >= 850 ? 3 : 2;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recipes.length,
      itemBuilder: (context, index) =>
          _buildRecipeCard(context, recipes[index]),
    );
  }

  Widget _buildSectionTitle(String title, {bool showViewAll = true}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
          ),
        ),
        if (showViewAll)
          GestureDetector(
            onTap: () {},
            child: const Text(
              'Voir tout',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2F6B3F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecipeCard(BuildContext context, Recipe recipe) {
    final desktop = isDesktop(context);
    return GestureDetector(
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
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleFavorite(recipe),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FavoritesService().isFavorite(recipe.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 20,
                        color: Colors.red[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(Quiz quiz) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/quiz',
          arguments: {
            'id': quiz.id,
            'title': quiz.title,
            'description': quiz.description,
          },
        );
      },
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
            // Image
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
                      child: Icon(
                        quiz.icon,
                        size: 36,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    )
                  : null,
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
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    );
  }
}
