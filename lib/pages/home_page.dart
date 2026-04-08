import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../models/recette.dart';
import '../models/user.dart' as user_models;

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

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final EcoDietApi _api = EcoDietApi();
  
  List<RecipeDisplayModel> recommendedRecipes = [];
  List<RecipeDisplayModel> allRecipes = [];
  List<user_models.Quiz> quizzes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      // Charger les recettes recommandées
      final recommended = await _api.getRecommendedRecettes(limit: 5);
      final recommendedModels = <RecipeDisplayModel>[];
      for (final r in recommended) {
        recommendedModels.add(await RecipeDisplayModel.fromRecette(r, _api));
      }

      // Charger toutes les recettes
      final all = await _api.getAllRecettes();
      final allModels = <RecipeDisplayModel>[];
      for (final r in all.take(10)) {
        allModels.add(await RecipeDisplayModel.fromRecette(r, _api));
      }

      // Charger les quiz
      final loadedQuizzes = await _api.getAllQuizzes();

      setState(() {
        recommendedRecipes = recommendedModels;
        allRecipes = allModels;
        quizzes = loadedQuizzes;
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context),
                const SizedBox(height: 24),

                // Section "Juste pour vous"
                if (recommendedRecipes.isNotEmpty) ...[
                  _buildSectionTitle('Juste pour vous'),
                  const SizedBox(height: 12),
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
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

  Widget _buildRecipeCard(BuildContext context, RecipeDisplayModel recipe) {
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
        width: 200,
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

  Widget _buildQuizCard(user_models.Quiz quiz) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/quiz',
          arguments: {
            'id': quiz.quizId.toString(),
            'title': quiz.title,
            'description': quiz.description ?? '',
          },
        );
      },
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
                    quiz.description ?? '',
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
