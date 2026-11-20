import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../../widgets/favorite_button.dart';
import '../taste/taste_logic.dart' show recipeIngredientSummary;
import 'home_models.dart';
import '../../widgets/cover_network_image.dart';

/// Carte recette de l'accueil (image, durée, titre, bouton favori).
class RecipeCard extends StatelessWidget {
  final RecipeDisplayModel recipe;
  final VoidCallback onToggleFavorite;

  /// Raison de la recommandation (« Lentilles, Lait de coco ») : remplace la
  /// ligne d'ingrédients dans « Juste pour vous ».
  final String? reason;

  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onToggleFavorite,
    this.reason,
  });

  @override
  Widget build(BuildContext context) {
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
                              size: 40,
                              color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ),
                      if (recipe.imageUrl != null)
                        CoverNetworkImage(imageUrl: recipe.imageUrl!),
                      // Badge durée
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (reason != null)
                            Row(
                              children: [
                                const Icon(Icons.favorite_rounded,
                                    size: 11, color: Color(0xFFD9692A)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    reason!,
                                    semanticsLabel:
                                        'Recommandée pour : ${reason!}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8A4A15),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              recipeIngredientSummary(recipe),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    FavoriteButton(
                      recipeId: recipe.id,
                      onToggle: onToggleFavorite,
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
