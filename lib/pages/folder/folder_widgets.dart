import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/favorites_service.dart' show FavoriteRecipe;
import 'folder_controller.dart' show recipeCountLong, recipeCountShort;

void openRecipe(BuildContext context, FavoriteRecipe recipe) {
  Navigator.pushNamed(context, '/recipe', arguments: {
    'id': recipe.id,
    'title': recipe.title,
    'description': recipe.category,
    'duration': recipe.duration,
  });
}

class FolderDesktopHeader extends StatelessWidget {
  const FolderDesktopHeader(
      {super.key,
      required this.label,
      required this.folderColor,
      required this.isFavorites,
      required this.recipeCount,
      required this.showBackButton});

  final String label;
  final Color folderColor;
  final bool isFavorites;
  final int recipeCount;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (showBackButton) ...[
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text('Retour'),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2F6B3F)),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: folderColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isFavorites ? Icons.favorite : Icons.folder,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2E1F),
                  ),
                ),
                Text(
                  recipeCountShort(recipeCount),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FolderRecipesGrid extends StatelessWidget {
  const FolderRecipesGrid(
      {super.key, required this.recipes, required this.onRemove});

  final List<FavoriteRecipe> recipes;
  final ValueChanged<FavoriteRecipe> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 3.5,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) => DesktopFolderCard(
        recipe: recipes[index],
        onRemove: () => onRemove(recipes[index]),
      ),
    );
  }
}

class DesktopFolderCard extends StatelessWidget {
  const DesktopFolderCard(
      {super.key, required this.recipe, required this.onRemove});

  final FavoriteRecipe recipe;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Recette : ${recipe.title}, ${recipe.category}',
      button: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => openRecipe(context, recipe),
          borderRadius: BorderRadius.circular(12),
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
            child: Row(
              children: [
                Container(
                  width: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12)),
                    image: recipe.imageUrl != null
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(recipe.imageUrl!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: recipe.imageUrl == null
                      ? Center(
                          child: Icon(Icons.eco,
                              size: 28,
                              color: Colors.white.withValues(alpha: 0.5)))
                      : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          recipe.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2E1F),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          recipe.category,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF2F6B3F)),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon:
                      Icon(Icons.remove_circle_outline, color: Colors.red[300]),
                  tooltip: 'Retirer de la liste',
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero plein écran (onglet favoris, sans bouton retour).
class FolderMobileHero extends StatelessWidget {
  const FolderMobileHero(
      {super.key,
      required this.label,
      required this.isFavorites,
      required this.recipeCount});

  final String label;
  final bool isFavorites;
  final int recipeCount;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            isFavorites ? const Color(0xFF3A1F1F) : const Color(0xFF1F3A24),
            isFavorites ? const Color(0xFFB03A2E) : const Color(0xFF2F6B3F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorites ? Icons.favorite_rounded : Icons.folder_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recipeCountLong(recipeCount),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tête compact avec bouton retour (navigation push).
class FolderMobileHeaderWithBack extends StatelessWidget {
  const FolderMobileHeaderWithBack(
      {super.key,
      required this.label,
      required this.folderColor,
      required this.isFavorites,
      required this.recipeCount});

  final String label;
  final Color folderColor;
  final bool isFavorites;
  final int recipeCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 20, color: Color(0xFF1F2E1F)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: folderColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isFavorites ? Icons.favorite : Icons.folder,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2E1F),
                    ),
                  ),
                  Text(
                    recipeCountShort(recipeCount),
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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

/// Carte mobile : balayer vers la gauche retire la recette, avec annulation.
class DismissibleFolderCard extends StatelessWidget {
  const DismissibleFolderCard(
      {super.key,
      required this.recipe,
      required this.onRemove,
      required this.onRestore});

  final FavoriteRecipe recipe;
  final VoidCallback onRemove;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(recipe.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Colors.white, size: 26),
            SizedBox(height: 4),
            Text(
              'Retirer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) {
        onRemove();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«\u202f${recipe.title}\u202f» retiré'),
            action: SnackBarAction(
              label: 'Annuler',
              onPressed: onRestore,
            ),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      },
      child: MobileFolderCard(recipe: recipe),
    );
  }
}

class MobileFolderCard extends StatelessWidget {
  const MobileFolderCard({super.key, required this.recipe});

  final FavoriteRecipe recipe;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openRecipe(context, recipe),
          child: Row(
            children: [
              // Image / placeholder
              Container(
                width: 100,
                height: 90,
                decoration: BoxDecoration(
                  gradient: recipe.imageUrl == null
                      ? const LinearGradient(
                          colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  image: recipe.imageUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(recipe.imageUrl!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: recipe.imageUrl == null
                    ? Center(
                        child: Icon(Icons.eco_rounded,
                            size: 32,
                            color: Colors.white.withValues(alpha: 0.45)))
                    : null,
              ),
              // Contenu
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Pill catégorie
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6B3F)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              recipe.category,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2F6B3F),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.access_time_rounded,
                              size: 13, color: Colors.grey[400]),
                          const SizedBox(width: 3),
                          Text(
                            recipe.duration,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Chevron
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right,
                    color: Colors.grey[300], size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FolderEmptyState extends StatelessWidget {
  const FolderEmptyState({super.key, required this.isFavorites});

  final bool isFavorites;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: isFavorites
                  ? Colors.red[50]
                  : const Color(0xFFF4A259).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFavorites
                  ? Icons.favorite_border_rounded
                  : Icons.folder_open_rounded,
              size: 48,
              color: isFavorites ? Colors.red[200] : Colors.orange[200],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFavorites ? 'Aucun favori pour l\'instant' : 'Dossier vide',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2E1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFavorites
                ? 'Appuyez sur ♡ dans une recette pour l\'ajouter ici'
                : 'Ajoutez des recettes depuis la page d\'une recette',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
