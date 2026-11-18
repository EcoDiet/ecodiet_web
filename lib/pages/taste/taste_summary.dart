import 'package:flutter/material.dart';

import '../../models/taste_profile.dart';
import 'swipe_card.dart';
import 'taste_logic.dart';
import 'taste_recommendation.dart';

/// Écran de fin du swipe : goûts les plus marqués et action principale.
class TasteSummary extends StatelessWidget {
  final TasteProfile profile;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback onRestart;

  /// Message sous les goûts (ex. coups de cœur ajoutés aux favoris).
  final String? note;

  /// Ingrédients préférés et leur pourcentage.
  final List<IngredientPreference> ingredients;

  const TasteSummary({
    super.key,
    required this.profile,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onRestart,
    this.note,
    this.ingredients = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Avec les pourcentages par ingrédient, les puces gardent le reste
    // (type de plat, régime, durée, occasions).
    final labels = topTasteLabels(
      ingredients.isEmpty
          ? profile
          : TasteProfile(
              weights: Map.fromEntries(profile.weights.entries
                  .where((e) => !e.key.startsWith('ing:'))),
            ),
      count: 5,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: SwipeColors.greenTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.restaurant_menu_rounded,
                    color: SwipeColors.green, size: 26),
              ),
              const SizedBox(height: 14),
              Semantics(
                header: true,
                child: Text(
                  'Votre profil gourmand',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: SwipeColors.text,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels.isEmpty
                    ? 'Rien ne vous a vraiment tenté : on garde une sélection variée.'
                    : 'On s\'en sert pour trier « Juste pour vous ».',
                style: const TextStyle(fontSize: 13, color: SwipeColors.muted),
              ),
              if (labels.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: labels
                      .map(
                        (l) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: SwipeColors.greenTint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            l,
                            style: const TextStyle(
                              fontSize: 13,
                              color: SwipeColors.darkGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (ingredients.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Vos ingrédients préférés',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: SwipeColors.text,
                      ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Part des recettes aimées qui en contiennent.',
                  style: TextStyle(fontSize: 12, color: SwipeColors.muted),
                ),
                const SizedBox(height: 10),
                ...ingredients.map((p) => IngredientShareBar(preference: p)),
              ],
              if (note != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.favorite_rounded,
                        size: 16, color: SwipeColors.heart),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note!,
                        style: const TextStyle(
                            fontSize: 13, color: SwipeColors.text),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwipeColors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Recommencer'),
                  style: TextButton.styleFrom(
                    foregroundColor: SwipeColors.green,
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne « ingrédient — barre — pourcentage ».
class IngredientShareBar extends StatelessWidget {
  final IngredientPreference preference;
  const IngredientShareBar({super.key, required this.preference});

  @override
  Widget build(BuildContext context) {
    final p = preference;
    return Semantics(
      label: '${p.label} : ${p.percent} % des recettes aimées',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                p.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: SwipeColors.text),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: p.likedShare.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEDE6D6),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(SwipeColors.green),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text(
                '${p.percent} %',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SwipeColors.darkGreen,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Phrase sur les coups de cœur ajoutés (ou à ajouter) aux favoris.
String? superLikeNote(int count, {required bool pending}) {
  if (count == 0) return null;
  final recettes = count == 1 ? '1 recette' : '$count recettes';
  final plural = count == 1 ? '' : 's';
  return pending
      ? '$recettes coup de cœur ${count == 1 ? 'rejoindra' : 'rejoindront'} '
          'vos favoris à votre première connexion.'
      : '$recettes coup de cœur ajoutée$plural à vos favoris.';
}
