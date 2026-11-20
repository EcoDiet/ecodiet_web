import 'package:flutter/material.dart';

import '../../services/ecodiet_api.dart';
import '../home/home_models.dart';
import '../home/recipe_filtering.dart';
import '../recipe_infos/recipe_info_widgets.dart' show InfoDivider, InfoStat;
import '../recipe_infos/recipe_text.dart';
import 'swipe_card.dart';
import 'taste_logic.dart';
import '../../widgets/cover_network_image.dart';

/// Charge les étapes de préparation d'une recette (vide si indisponibles).
typedef StepsLoader = Future<List<String>> Function(String recipeId);

/// Étapes lues via l'API (même source que la page recette).
Future<List<String>> loadRecipeSteps(String recipeId) async {
  final complete = await EcoDietApi().getRecetteComplete(recipeId);
  return parseInstructions(complete?.recette.etapes ?? '');
}

/// « Profil » déroulé d'une recette pendant le swipe : photo, chiffres clés,
/// ingrédients avec quantités, préparation, ustensiles, allergènes et
/// occasions. Les boutons de vote restent sous la fiche.
class SwipeRecipeDetails extends StatefulWidget {
  final RecipeDisplayModel recipe;
  final VoidCallback onCollapse;
  final StepsLoader loadSteps;

  /// Hauteur disponible pour la fiche (règle la taille de la photo).
  final double availableHeight;

  const SwipeRecipeDetails({
    super.key,
    required this.recipe,
    required this.onCollapse,
    this.loadSteps = loadRecipeSteps,
    this.availableHeight = 560,
  });

  @override
  State<SwipeRecipeDetails> createState() => _SwipeRecipeDetailsState();
}

class _SwipeRecipeDetailsState extends State<SwipeRecipeDetails> {
  late final Future<List<String>> _steps =
      widget.loadSteps(widget.recipe.id).catchError((_) => <String>[]);

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final ingredients = recipeIngredientLines(r);
    final utensils = recipeTagList(r.utensils);
    final allergens = recipeTagList(r.allergens);
    final occasions = recipeTagList(r.occasions);
    final minutes = parseDurationMinutes(r.duration);
    final category = recipeTagList(r.category).join();
    final diet = tasteFeatureLabel('regime:${recipeDietLevel(r).name}');

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
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Photo proportionnelle à la hauteur disponible : sur un petit
              // écran, la fiche garde de la place pour le contenu.
              SliverToBoxAdapter(
                child: _Header(
                  recipe: r,
                  height: (widget.availableHeight * 0.3).clamp(90.0, 180.0),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                sliver: SliverList.list(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        r.title,
                        style:
                            Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: SwipeColors.text,
                                ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (category.isNotEmpty && category != 'Recette')
                          _Tag(category, SwipeColors.greenTint,
                              SwipeColors.darkGreen),
                        _Tag(diet, SwipeColors.orangeTint,
                            SwipeColors.orangeText),
                        ...occasions.map((o) => _Tag(
                            o, const Color(0xFFF1ECE1), SwipeColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: SwipeColors.beige.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          InfoStat(Icons.timer_outlined, 'Temps',
                              minutes != null && minutes > 0
                                  ? formatDuration(minutes)
                                  : '—'),
                          const InfoDivider(),
                          InfoStat(Icons.trending_up_rounded, 'Difficulté',
                              minutes != null && minutes > 0
                                  ? difficultyLabel(minutes)
                                  : '—'),
                          const InfoDivider(),
                          InfoStat(Icons.shopping_basket_outlined,
                              'Ingrédients', '${ingredients.length}'),
                        ],
                      ),
                    ),
                    if (ingredients.isNotEmpty) ...[
                      const _SectionTitle('Ingrédients'),
                      ...ingredients.map((i) => _Bullet(i)),
                    ],
                    const _SectionTitle('Préparation'),
                    FutureBuilder<List<String>>(
                      future: _steps,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: SwipeColors.green),
                                ),
                                SizedBox(width: 10),
                                Text('Chargement des étapes…',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: SwipeColors.muted)),
                              ],
                            ),
                          );
                        }
                        final steps = snap.data ?? const [];
                        if (steps.isEmpty) {
                          return const Text(
                            'Les étapes ne sont pas disponibles pour cette recette.',
                            style: TextStyle(
                                fontSize: 13, color: SwipeColors.muted),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < steps.length; i++)
                              _Step(i + 1, steps[i]),
                          ],
                        );
                      },
                    ),
                    if (utensils.isNotEmpty) ...[
                      const _SectionTitle('Ustensiles'),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: utensils
                            .map((u) => _Tag(u, const Color(0xFFF1ECE1),
                                SwipeColors.text))
                            .toList(),
                      ),
                    ],
                    const _SectionTitle('Allergènes'),
                    if (allergens.isEmpty)
                      const Text(
                        'Aucun allergène majeur signalé.',
                        style:
                            TextStyle(fontSize: 13, color: SwipeColors.muted),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: allergens
                            .map((a) => _Tag(a, const Color(0xFFFCE8E6),
                                const Color(0xFF8C2A1E),
                                icon: Icons.warning_amber_rounded))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.white,
              shape: const StadiumBorder(),
              elevation: 2,
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: widget.onCollapse,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 20, color: SwipeColors.green),
                      SizedBox(width: 4),
                      Text(
                        'Réduire',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: SwipeColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final RecipeDisplayModel recipe;
  final double height;
  const _Header({required this.recipe, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
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
                  size: 52, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          if (recipe.imageUrl != null)
            CoverNetworkImage(imageUrl: recipe.imageUrl!),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: SwipeColors.green,
              ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 10),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: SwipeColors.lightGreen,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, height: 1.35, color: SwipeColors.text)),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  const _Step(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 10),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: SwipeColors.greenTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: SwipeColors.darkGreen,
              ),
            ),
          ),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: SwipeColors.text)),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const _Tag(this.label, this.background, this.foreground, {this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
