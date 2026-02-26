import 'package:flutter/material.dart';
import '../services/favorites_service.dart';
import '../utils/responsive.dart';

class FolderPage extends StatefulWidget {
  final String? id;
  final String? label;
  final Color? color;
  final bool showBackButton;

  const FolderPage({
    Key? key,
    this.id,
    this.label,
    this.color,
    this.showBackButton = true,
  }) : super(key: key);

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  bool isLoading = true;
  List<FavoriteRecipe> recipes = [];

  bool get _isFavorites => widget.id == 'favorites';

  @override
  void initState() {
    super.initState();
    _loadFolderRecipes();
    if (_isFavorites) FavoritesService().addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    if (_isFavorites) FavoritesService().removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    setState(() => recipes = List.of(FavoritesService().favorites));
  }

  Future<void> _loadFolderRecipes() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      switch (widget.id) {
        case 'favorites':
          recipes = List.of(FavoritesService().favorites);
          break;
        case '2':
          recipes = [
            FavoriteRecipe(
                id: '3',
                title: 'Smoothie vert',
                category: 'Boisson',
                duration: "5'"),
          ];
          break;
        default:
          recipes = [];
      }
      isLoading = false;
    });
  }

  void _removeRecipe(FavoriteRecipe recipe) {
    if (_isFavorites) {
      FavoritesService().removeFavorite(recipe.id);
    } else {
      setState(() => recipes.removeWhere((r) => r.id == recipe.id));
    }
  }

  void _restoreRecipe(FavoriteRecipe recipe) {
    if (_isFavorites) {
      FavoritesService().addFavorite(recipe);
    } else {
      setState(() => recipes.add(recipe));
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    final folderColor = widget.color ?? const Color(0xFFF4A259);

    if (desktop) return _buildDesktop(folderColor);
    return _buildMobile(folderColor);
  }

  // ── Desktop ────────────────────────────────────────────────────────────────

  Widget _buildDesktop(Color folderColor) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                _buildDesktopHeader(folderColor),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : recipes.isEmpty
                          ? _buildEmptyState()
                          : _buildRecipesGrid(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(Color folderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          if (widget.showBackButton) ...[
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
              _isFavorites ? Icons.favorite : Icons.folder,
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2E1F),
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
      itemBuilder: (context, index) => _buildDesktopCard(recipes[index]),
    );
  }

  Widget _buildDesktopCard(FavoriteRecipe recipe) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/recipe', arguments: {
        'id': recipe.id,
        'title': recipe.title,
        'description': recipe.category,
        'duration': recipe.duration,
      }),
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
            Container(
              width: 90,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(12)),
                image: recipe.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(recipe.imageUrl!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: recipe.imageUrl == null
                  ? Center(
                      child: Icon(Icons.eco,
                          size: 28,
                          color: Colors.white.withOpacity(0.5)))
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
              icon: Icon(Icons.remove_circle_outline,
                  color: Colors.red[300]),
              onPressed: () => _removeRecipe(recipe),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile ─────────────────────────────────────────────────────────────────

  Widget _buildMobile(Color folderColor) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Hero header
                SliverToBoxAdapter(
                  child: widget.showBackButton
                      ? _buildMobileHeaderWithBack(folderColor)
                      : _buildMobileHero(folderColor),
                ),
                // Contenu
                if (recipes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDismissibleCard(recipes[index]),
                        ),
                        childCount: recipes.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // Hero plein écran (onglet favoris, pas de retour)
  Widget _buildMobileHero(Color folderColor) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isFavorites
                ? const Color(0xFF3A1F1F)
                : const Color(0xFF1F3A24),
            _isFavorites
                ? const Color(0xFFB03A2E)
                : const Color(0xFF2F6B3F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorites ? Icons.favorite_rounded : Icons.folder_rounded,
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
                  widget.label ?? 'Dossier',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  recipes.isEmpty
                      ? 'Aucune recette'
                      : '${recipes.length} recette${recipes.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header compact avec bouton retour (navigation push)
  Widget _buildMobileHeaderWithBack(Color folderColor) {
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
                _isFavorites ? Icons.favorite : Icons.folder,
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Carte avec swipe-to-delete
  Widget _buildDismissibleCard(FavoriteRecipe recipe) {
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
        _removeRecipe(recipe);
        final removed = recipe;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('«\u202f${removed.title}\u202f» retiré'),
            action: SnackBarAction(
              label: 'Annuler',
              onPressed: () => _restoreRecipe(removed),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      },
      child: _buildMobileCard(recipe),
    );
  }

  Widget _buildMobileCard(FavoriteRecipe recipe) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/recipe', arguments: {
            'id': recipe.id,
            'title': recipe.title,
            'description': recipe.category,
            'duration': recipe.duration,
          }),
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
                          image: NetworkImage(recipe.imageUrl!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: recipe.imageUrl == null
                    ? Center(
                        child: Icon(Icons.eco_rounded,
                            size: 32,
                            color: Colors.white.withOpacity(0.45)))
                    : null,
              ),
              // Contenu
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
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
                              color: const Color(0xFF2F6B3F).withOpacity(0.1),
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
                                fontSize: 12, color: Colors.grey[500]),
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

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: _isFavorites
                  ? Colors.red[50]
                  : const Color(0xFFF4A259).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorites ? Icons.favorite_border_rounded : Icons.folder_open_rounded,
              size: 48,
              color: _isFavorites ? Colors.red[200] : Colors.orange[200],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isFavorites ? 'Aucun favori pour l\'instant' : 'Dossier vide',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2E1F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isFavorites
                ? 'Appuyez sur ♡ dans une recette pour l\'ajouter ici'
                : 'Ajoutez des recettes depuis la page d\'une recette',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
