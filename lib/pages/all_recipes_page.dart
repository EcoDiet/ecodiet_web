import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../utils/responsive.dart';
import 'home_page.dart';

class AllRecipesPage extends StatefulWidget {
  final String title;
  final List<Recipe> recipes;

  const AllRecipesPage({
    Key? key,
    required this.title,
    required this.recipes,
  }) : super(key: key);

  @override
  State<AllRecipesPage> createState() => _AllRecipesPageState();
}

class _AllRecipesPageState extends State<AllRecipesPage> {
  @override
  void initState() {
    super.initState();
    FavoritesService().addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    FavoritesService().removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() => setState(() {});

  void _toggleFavorite(Recipe recipe) {
    FavoritesService().toggle(FavoriteRecipe(
      id: recipe.id,
      title: recipe.title,
      category: recipe.category,
      duration: recipe.duration,
      imageUrl: recipe.imageUrl,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5ECD9),
        elevation: 0,
        leading: desktop
            ? TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF2F6B3F), size: 18),
                label: const Text(
                  'Retour',
                  style: TextStyle(color: Color(0xFF2F6B3F), fontSize: 14),
                ),
              )
            : IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2F6B3F)),
                tooltip: 'Retour',
              ),
        leadingWidth: desktop ? 100 : 56,
        title: Text(
          widget.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          desktop ? 32 : 16,
          16,
          desktop ? 32 : 16,
          100,
        ),
        child: _buildRecipeGrid(context),
      ),
    );
  }

  Widget _buildRecipeGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 4 : width >= 850 ? 3 : 2;
    const spacing = 12.0;
    final cardWidth = (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: widget.recipes
          .map((r) => SizedBox(width: cardWidth, child: _buildRecipeCard(context, r)))
          .toList(),
    );
  }

  Widget _buildRecipeCard(BuildContext context, Recipe recipe) {
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2F6B3F)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            recipe.ingredients,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
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
}
