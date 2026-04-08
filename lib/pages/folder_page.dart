import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../models/recette.dart';

class FolderPage extends StatefulWidget {
  final String? id;
  final String? label;
  final Color? color;

  const FolderPage({
    Key? key,
    this.id,
    this.label,
    this.color,
  }) : super(key: key);

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  final EcoDietApi _api = EcoDietApi();
  bool isLoading = true;
  List<Recette> recipes = [];

  @override
  void initState() {
    super.initState();
    _loadFolderRecipes();
  }

  Future<void> _loadFolderRecipes() async {
    if (widget.id == null) {
      setState(() => isLoading = false);
      return;
    }

    // Gestion spéciale pour les favoris
    if (widget.id == 'favorites') {
      final result = await _api.getFavorites();
      setState(() {
        recipes = result;
        isLoading = false;
      });
    } else {
      final folderId = int.tryParse(widget.id!);
      if (folderId == null) {
        setState(() => isLoading = false);
        return;
      }

      final result = await _api.getRecipesInFolder(folderId);
      setState(() {
        recipes = result;
        isLoading = false;
      });
    }
  }

  void _removeFromFolder(Recette recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du dossier ?'),
        content: Text(
          'Voulez-vous retirer "${recipe.titre}" de ce dossier ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              if (widget.id == 'favorites') {
                await _api.removeFromFavorites(recipe.recetteId);
              } else {
                final folderId = int.tryParse(widget.id!);
                if (folderId != null) {
                  await _api.removeRecipeFromFolder(folderId, recipe.recetteId);
                }
              }
              
              setState(() {
                recipes.removeWhere((r) => r.recetteId == recipe.recetteId);
              });
            },
            child: const Text(
              'Retirer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return "$minutes'";
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h${remainingMinutes > 0 ? "$remainingMinutes'" : ""}';
  }

  @override
  Widget build(BuildContext context) {
    final folderColor = widget.color ?? const Color(0xFFF4A259);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(folderColor),

            // Contenu
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : recipes.isEmpty
                      ? _buildEmptyState()
                      : _buildRecipesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color folderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2E1F)),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: folderColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.folder,
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
                  widget.label ?? 'Dossier',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2E1F),
                  ),
                ),
                Text(
                  '${recipes.length} recette(s)',
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune recette dans ce dossier',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des recettes depuis la page d\'une recette',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecipeCard(recipe),
        );
      },
    );
  }

  Widget _buildRecipeCard(Recette recipe) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/recipe',
        arguments: {
          'id': recipe.recetteId,
          'title': recipe.titre,
        },
      ),
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
            // Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                image: recipe.photo.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(recipe.photo),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: recipe.photo.isEmpty
                  ? Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 30,
                        color: Colors.grey[400],
                      ),
                    )
                  : null,
            ),
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.titre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2E1F),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(recipe.dureeMinute),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Bouton supprimer
            IconButton(
              icon: Icon(
                Icons.remove_circle_outline,
                color: Colors.red[300],
              ),
              onPressed: () => _removeFromFolder(recipe),
            ),
          ],
        ),
      ),
    );
  }
}
