import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../utils/responsive.dart';

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
  List<FavoriteRecipe> recipes = [];

  @override
  void initState() {
    super.initState();
    _loadFolderRecipes();
    if (widget.id == 'favorites') {
      FavoritesService().addListener(_onFavoritesChanged);
    }
  }

  @override
  void dispose() {
    if (widget.id == 'favorites') {
      FavoritesService().removeListener(_onFavoritesChanged);
    }
    super.dispose();
  }

  void _onFavoritesChanged() {
    setState(() {
      recipes = List.of(FavoritesService().favorites);
    });
  }

  Future<void> _loadFolderRecipes() async {
    // TODO: Remplacer par l'appel API réel
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      switch (widget.id) {
        case 'favorites':
          recipes = List.of(FavoritesService().favorites);
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

  List<FavoriteRecipe> _getFolder2Recipes() {
    return [
      FavoriteRecipe(
        id: '3',
        title: 'Smoothie vert',
        category: 'Boisson',
        duration: "5'",
        imageUrl: null,
      ),
    ];
  }

  List<FavoriteRecipe> _getFolder3Recipes() {
    return [];
  }

  void _removeFromFolder(FavoriteRecipe recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer du dossier ?'),
        content: Text('Voulez-vous retirer "${recipe.title}" de ce dossier ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (widget.id == 'favorites') {
                FavoritesService().removeFavorite(recipe.id);
              } else {
                setState(() {
                  recipes.removeWhere((r) => r.id == recipe.id);
                });
              }
              Navigator.pop(context);
              // TODO: Appeler l'API pour retirer la recette du dossier
            },
            child: const Text('Retirer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final folderColor = widget.color ?? const Color(0xFFF4A259);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                _buildHeader(folderColor, desktop),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : recipes.isEmpty
                          ? _buildEmptyState()
                          : desktop
                              ? _buildRecipesGrid()
                              : _buildRecipesList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color folderColor, bool desktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 24 : 8,
        vertical: 12,
      ),
      child: Row(
        children: [
          if (desktop)
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, size: 20),
              label: const Text('Retour'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2F6B3F),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2E1F)),
              onPressed: () => Navigator.pop(context),
            ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: folderColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.id == 'favorites' ? Icons.favorite : Icons.folder,
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
                  widget.label ?? 'Dossier',
                  style: TextStyle(
                    fontSize: desktop ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2E1F),
                  ),
                ),
                Text(
                  '${recipes.length} recette(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
          Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Aucune recette dans ce dossier',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez des recettes depuis la page d\'une recette',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
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
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildRecipeCard(recipes[index]),
      ),
    );
  }

  Widget _buildRecipesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 3.5,
      ),
      itemCount: recipes.length,
      itemBuilder: (context, index) => _buildRecipeCard(recipes[index]),
    );
  }

  Widget _buildRecipeCard(FavoriteRecipe recipe) {
    return GestureDetector(
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
              width: 90,
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
                      child: Icon(Icons.eco,
                          size: 28, color: Colors.grey[400]),
                    )
                  : null,
            ),
            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    Row(
                      children: [
                        Text(
                          recipe.category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2F6B3F),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Text(
                          recipe.duration,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Bouton retirer
            IconButton(
              icon: Icon(Icons.remove_circle_outline, color: Colors.red[300]),
              onPressed: () => _removeFromFolder(recipe),
            ),
          ],
        ),
      ),
    );
  }
}
