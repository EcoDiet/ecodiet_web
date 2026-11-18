import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/ecodiet_api.dart';

/// Statistique (icône, valeur, libellé) de la ligne d'infos mobile.
class InfoStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const InfoStat(this.icon, this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF2F6B3F), size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1F2E1F),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Séparateur vertical entre deux `InfoStat`.
class InfoDivider extends StatelessWidget {
  const InfoDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));
  }
}

/// Section liste (ingrédients, étapes…) version mobile.
class MobileSection extends StatelessWidget {
  final String title;
  final List<String> items;
  final bool numbered;

  const MobileSection(this.title, this.items,
      {super.key, this.numbered = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2E1F),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2F6B3F).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2F6B3F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numbered)
                  Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F6B3F),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 7, right: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F6B3F),
                      shape: BoxShape.circle,
                    ),
                  ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1F2E1F),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Pastille « libellé : valeur » colorée.
class MetaChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MetaChip(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2E1F)),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Image de recette avec dégradé de repli.
class RecipeImage extends StatelessWidget {
  final String? photo;
  final double height;

  const RecipeImage({super.key, required this.photo, required this.height});

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
                    size: 60, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            if (photo != null && photo.isNotEmpty)
              CachedNetworkImage(
                imageUrl: recetteImageUrl(photo),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                placeholder: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'info (temps, difficulté) version desktop.
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const InfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2F6B3F),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encart impact carbone (valeur non encore calculée).
class CarbonFootprintCard extends StatelessWidget {
  const CarbonFootprintCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2F6B3F).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.eco, color: Color(0xFF2F6B3F), size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'Impact carbone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2E1F),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '-',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F6B3F),
                ),
              ),
              Text(
                'par portion',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Section liste version desktop.
class RecipeSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> items;
  final bool numbered;

  const RecipeSection(this.title, this.subtitle, this.items,
      {super.key, this.numbered = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2F6B3F),
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numbered)
                  Text(
                    '${index + 1}. ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF1F2E1F)),
                  )
                else
                  const Text(
                    '- ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF2F6B3F)),
                  ),
                Expanded(
                  child: Text(
                    item,
                    style:
                        const TextStyle(fontSize: 14, color: Color(0xFF1F2E1F)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Boutons « favoris » et « ajouter à un dossier ».
class RecipeActionButtons extends StatelessWidget {
  final bool desktop;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToFolder;

  const RecipeActionButtons({
    super.key,
    required this.desktop,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToFolder,
  });

  @override
  Widget build(BuildContext context) {
    if (desktop) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onToggleFavorite,
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 18),
              label: Text(
                isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F6B3F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onAddToFolder,
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text(
                'Ajouter Ã  un dossier',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4A259),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onToggleFavorite,
            icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 20),
            label: Text(
              isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6B3F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAddToFolder,
            icon: const Icon(Icons.folder_outlined, size: 20),
            label: const Text(
              'Ajouter Ã  un dossier',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4A259),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}
