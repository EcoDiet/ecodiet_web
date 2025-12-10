import 'package:flutter/material.dart';

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
  bool isLoading = true;
  List<FolderRecipe> recipes = [];

  @override
  void initState() {
    super.initState();
    _loadFolderRecipes();
  }

  Future<void> _loadFolderRecipes() async {
    // TODO: Remplacer par l'appel API réel
    // final recipes = await api.getFolderRecipes(widget.id);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      // Chaque dossier a ses propres recettes selon son id
      // À remplacer par les vraies données de l'API
      switch (widget.id) {
        case 'favorites':
          recipes = _getFavoritesRecipes();
          break;
        case '2':
          recipes = _getFolder2Recipes();
          break;
        case '3':
          recipes = _getFolder3Recipes();
          break;
        default:
          recipes = [];
      }
      isLoading = false;
    });
  }

  // Recettes favorites
  List<FolderRecipe> _getFavoritesRecipes() {
    return [];
  }

  // Recettes du dossier 2
  List<FolderRecipe> _getFolder2Recipes() {
    return [
      FolderRecipe(
        id: '3',
        title: 'Smoothie vert',
        category: 'Boisson',
        duration: "5'",
        imageUrl: null,
      ),
    ];
  }

  // Recettes du dossier 3 - vide pour l'exemple
  List<FolderRecipe> _getFolder3Recipes() {
    return [];
  }

  void _removeFromFolder(FolderRecipe recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du dossier ?'),
        content: Text(
          'Voulez-vous retirer "${recipe.title}" de ce dossier ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                recipes.removeWhere((r) => r.id == recipe.id);
              });
              Navigator.pop(context);
              // TODO: Appeler l'API pour retirer la recette du dossier
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

  Widget _buildRecipeCard(FolderRecipe recipe) {
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
                image: recipe.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(recipe.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: recipe.imageUrl == null
                  ? Center(
                      child: Icon(
                        Icons.image,
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
                          recipe.duration,
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

/// Modèle pour une recette dans un dossier
class FolderRecipe {
  final String id;
  final String title;
  final String category;
  final String duration;
  final String? imageUrl;

  FolderRecipe({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    this.imageUrl,
  });
}
