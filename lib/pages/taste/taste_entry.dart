import 'package:flutter/material.dart';

import 'swipe_card.dart';

/// Ouvre le swipe de goûts. Renvoie `true` si un profil a été enregistré.
Future<bool> openTasteSwipe(BuildContext context) async {
  final result = await Navigator.pushNamed(context, '/taste');
  return result == true;
}

/// Bannière de l'accueil invitant à swiper, tant qu'aucun profil de goûts
/// n'existe. Reprend le vert foncé de la barre latérale.
class TastePromptCard extends StatelessWidget {
  final VoidCallback onStart;

  const TastePromptCard({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: SwipeColors.darkGreen,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Petite pile de cartes stylisée.
          ExcludeSemantics(
            child: SizedBox(
              width: 58,
              height: 64,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 6,
                    child: Transform.rotate(
                      angle: -0.18,
                      child: _miniCard(SwipeColors.lightGreen),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    top: 2,
                    child: Transform.rotate(
                      angle: 0.12,
                      child: _miniCard(const Color(0xFFF4A259),
                          icon: Icons.favorite_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qu\'est-ce qui vous fait envie ?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: SwipeColors.beige,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Swipez 12 recettes : vos suggestions s\'adaptent à vos goûts.',
                  style: TextStyle(fontSize: 13, color: Color(0xFFCFE3D2)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.swipe_rounded, size: 18),
                    label: const Text('C\'est parti'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwipeColors.beige,
                      foregroundColor: SwipeColors.darkGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _miniCard(Color color, {IconData icon = Icons.eco}) {
    return Container(
      width: 40,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

/// Ligne « Mes goûts » du profil.
class TasteEntryTile extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasProfile;

  const TasteEntryTile({
    super.key,
    required this.onTap,
    required this.hasProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SwipeColors.greenTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swipe_rounded,
                      color: SwipeColors.green, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mes goûts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: SwipeColors.text,
                        ),
                      ),
                      Text(
                        hasProfile
                            ? 'Refaire le swipe pour affiner vos suggestions'
                            : 'Swipez 12 recettes pour des suggestions à votre goût',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
