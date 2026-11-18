import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../home/home_models.dart';
import '../home/recipe_filtering.dart';
import 'taste_logic.dart';

/// Couleurs du swipe, alignées sur la DA EcoDiet.
class SwipeColors {
  static const green = Color(0xFF2F6B3F);
  static const darkGreen = Color(0xFF1F3A24);
  static const lightGreen = Color(0xFF63A96E);
  static const greenTint = Color(0xFFE5F0E7);
  static const beige = Color(0xFFF5ECD9);
  static const text = Color(0xFF1F2E1F);
  static const muted = Color(0xFF5C6B5C);

  /// Orange de l'accent favoris, un peu assombri pour garder un contraste
  /// ≥ 3:1 sur fond blanc (icônes, WCAG 1.4.11).
  static const heart = Color(0xFFD9692A);
  static const orangeTint = Color(0xFFFDEBDC);
  static const orangeText = Color(0xFF8A4A15);

  /// Gris du « pas pour moi » (contraste 3,5:1 sur blanc).
  static const nope = Color(0xFF8A8A80);
}

/// Carte recette du swipe : grande photo, durée, titre, type, régime et
/// ingrédients principaux. `likeOpacity`, `nopeOpacity` et `loveOpacity`
/// pilotent les tampons affichés pendant le glissement.
class SwipeRecipeCard extends StatelessWidget {
  final RecipeDisplayModel recipe;
  final double likeOpacity;
  final double nopeOpacity;
  final double loveOpacity;

  /// Ouvre la fiche détaillée (bouton « Voir la recette »). `null` : bouton
  /// masqué (carte suivante, en arrière-plan).
  final VoidCallback? onShowDetails;

  const SwipeRecipeCard({
    super.key,
    required this.recipe,
    this.likeOpacity = 0,
    this.nopeOpacity = 0,
    this.loveOpacity = 0,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final dietLabel =
        tasteFeatureLabel('regime:${recipeDietLevel(recipe).name}');
    // Libellé accentué (« entree » → « Entrée »), comme dans la fiche.
    final category = recipeTagList(recipe.category).join();
    final ingredients = tasteIngredients(recipe).values.take(3).join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fond affiché si l'image est absente ou en erreur.
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [SwipeColors.green, SwipeColors.lightGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(Icons.eco,
                        size: 64, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ),
                if (recipe.imageUrl != null)
                  CachedNetworkImage(
                    imageUrl: recipe.imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    placeholder: (_, __) => const SizedBox.shrink(),
                  ),
                if (recipe.duration.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _DurationBadge(duration: recipe.duration),
                  ),
                Positioned(
                  top: 22,
                  left: 18,
                  child: _Stamp(
                    label: 'MIAM',
                    color: SwipeColors.green,
                    angle: -0.22,
                    opacity: likeOpacity,
                  ),
                ),
                Positioned(
                  top: 22,
                  right: 18,
                  child: _Stamp(
                    label: 'BOF',
                    color: SwipeColors.nope,
                    angle: 0.22,
                    opacity: nopeOpacity,
                  ),
                ),
                Positioned(
                  bottom: 18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _Stamp(
                      label: 'COUP DE CŒUR',
                      color: SwipeColors.heart,
                      angle: -0.08,
                      opacity: loveOpacity,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: SwipeColors.text,
                                ),
                      ),
                    ),
                    if (onShowDetails != null) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Voir la recette en détail',
                        child: Material(
                          color: SwipeColors.greenTint,
                          shape: const StadiumBorder(),
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: onShowDetails,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 16, color: SwipeColors.darkGreen),
                                  SizedBox(width: 4),
                                  Text(
                                    'Voir la recette',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: SwipeColors.darkGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (category.isNotEmpty && category != 'Recette')
                      _Chip(
                        label: category,
                        background: SwipeColors.greenTint,
                        foreground: SwipeColors.darkGreen,
                      ),
                    _Chip(
                      label: dietLabel,
                      background: SwipeColors.orangeTint,
                      foreground: SwipeColors.orangeText,
                    ),
                  ],
                ),
                if (ingredients.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    ingredients,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

}

class _DurationBadge extends StatelessWidget {
  final String duration;
  const _DurationBadge({required this.duration});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            duration,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  final String label;
  final Color color;
  final double angle;
  final double opacity;

  const _Stamp({
    required this.label,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _Chip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
