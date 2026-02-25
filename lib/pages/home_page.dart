import 'package:flutter/material.dart';
import '../utils/responsive.dart';

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

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
          title: 'Quiz 1',
          description: 'Testez vos connaissances sur les légumes',
        ),
        Quiz(
          id: '2',
          title: 'Quiz 2',
          description: 'Les fruits et leurs bienfaits',
        ),
      ];

      isLoading = false;
    });
  }

  void _toggleFavorite(Recipe recipe) {
    setState(() {
      recipe.isFavorite = !recipe.isFavorite;
    });
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

                    // Section "Juste pour vous"
                    if (recommendedRecipes.isNotEmpty) ...[
                      _buildSectionTitle('Juste pour vous'),
                      const SizedBox(height: 12),
                      if (desktop)
                        _buildRecipeGrid(context, recommendedRecipes)
                      else
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: recommendedRecipes.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildRecipeCard(
                                  context,
                                  recommendedRecipes[index],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],

                    // Section "Nos recettes"
                    if (allRecipes.isNotEmpty) ...[
                      _buildSectionTitle('Nos recettes'),
                      const SizedBox(height: 12),
                      if (desktop)
                        _buildRecipeGrid(context, allRecipes)
                      else
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: allRecipes.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _buildRecipeCard(
                                  context,
                                  allRecipes[index],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],

                    // Section "Testez vos connaissances"
                    if (quizzes.isNotEmpty) ...[
                      _buildSectionTitle('Testez vos connaissances'),
                      const SizedBox(height: 12),
                      if (desktop)
                        GridView.count(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.2,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour !',
              style: TextStyle(
                fontSize: desktop ? 32 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2F6B3F),
              ),
            ),
            const Text(
              'Mangez sainement, naturellement',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        if (!desktop)
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/profile'),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 28,
                color: Colors.grey,
              ),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1F2E1F),
      ),
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
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border.all(color: const Color(0xFF87CEEB), width: 2),
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
                        Icons.image,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Text(
                      recipe.duration,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
                            color: Colors.red[300],
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
                        recipe.isFavorite
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
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
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
                        Icons.image,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    )
                  : null,
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quiz.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2E1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quiz.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
