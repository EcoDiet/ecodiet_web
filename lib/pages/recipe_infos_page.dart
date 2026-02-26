import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/favorites_service.dart';

class RecipeInfosPage extends StatefulWidget {
  final String? id;
  final String? title;
  final String? description;
  final String? duration;

  const RecipeInfosPage({
    Key? key,
    this.id,
    this.title,
    this.description,
    this.duration,
  }) : super(key: key);

  @override
  State<RecipeInfosPage> createState() => _RecipeInfosPageState();
}

class _RecipeInfosPageState extends State<RecipeInfosPage> {
  // TODO: Charger les données complètes de la recette depuis l'API
  bool isLoading = true;
  late final FavoritesService _favoritesService;

  // Données de la recette (à remplacer par les vraies données)
  String? imageUrl;
  int duration = 0; // en secondes
  int portions = 0;
  int difficulty = 0; // en secondes ou score
  double carbonFootprint = 0.0;
  List<String> ingredients = [];
  List<String> instructions = [];

  @override
  void initState() {
    super.initState();
    _favoritesService = FavoritesService();
    _favoritesService.addListener(_onFavoritesChanged);
    _loadRecipeDetails();
  }

  @override
  void dispose() {
    _favoritesService.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    setState(() {});
  }

  Future<void> _loadRecipeDetails() async {
    // TODO: Remplacer par l'appel API réel
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      // Données de démonstration
      duration = 1800; // 30 minutes en secondes
      portions = 4;
      difficulty = 120; // durée ou score de difficulté
      carbonFootprint = 2.5;
      ingredients = [
        '200g de quinoa',
        '1 concombre',
        '2 tomates',
        '1 oignon rouge',
        'Huile d\'olive',
        'Jus de citron',
      ];
      instructions = [
        'Rincer le quinoa et le cuire selon les instructions.',
        'Couper les légumes en petits dés.',
        'Mélanger le quinoa refroidi avec les légumes.',
        'Assaisonner avec l\'huile d\'olive et le jus de citron.',
        'Servir frais.',
      ];
      isLoading = false;
    });
  }

  void _toggleFavorite() {
    if (widget.id == null) return;
    _favoritesService.toggle(FavoriteRecipe(
      id: widget.id!,
      title: widget.title ?? '',
      category: widget.description ?? '',
      duration: widget.duration ?? '',
      imageUrl: imageUrl,
    ));
    // TODO: Sauvegarder dans la base de données
  }

  bool get _isFavorite =>
      widget.id != null && _favoritesService.isFavorite(widget.id!);

  void _addToFolder() {
    // TODO: Afficher un dialog pour choisir le dossier
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ajouter à un dossier',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // TODO: Liste des dossiers
            const Text('Fonctionnalité à implémenter'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Contenu scrollable
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: desktop ? 32 : 16,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image + titre sur desktop : côte à côte
                              if (desktop) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Image
                                    Expanded(
                                      flex: 5,
                                      child: _buildImage(height: 260),
                                    ),
                                    const SizedBox(width: 24),
                                    // Titre + description + infos
                                    Expanded(
                                      flex: 4,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.title ??
                                                'Titre de la recette',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1F2E1F),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            widget.description ?? 'Description',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          _buildInfoCards(),
                                          const SizedBox(height: 16),
                                          _buildCarbonFootprint(),
                                          const SizedBox(height: 20),
                                          _buildActionButtons(desktop),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                // Ingrédients et Instructions côte à côte
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildSection(
                                        'Ingrédients',
                                        'liste des ingrédients',
                                        ingredients,
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    Expanded(
                                      child: _buildSection(
                                        'Instructions',
                                        'étapes à suivre',
                                        instructions,
                                        numbered: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ] else ...[
                                // Mobile : layout vertical
                                _buildImage(height: 180),
                                const SizedBox(height: 16),
                                Text(
                                  widget.title ?? 'Titre de la recette',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2E1F),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.description ?? 'Description',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _buildInfoCards(),
                                const SizedBox(height: 20),
                                _buildCarbonFootprint(),
                                const SizedBox(height: 24),
                                _buildSection(
                                  'Ingrédients',
                                  'liste des ingrédients',
                                  ingredients,
                                ),
                                const SizedBox(height: 24),
                                _buildSection(
                                  'Instructions',
                                  'étapes à suivre',
                                  instructions,
                                  numbered: true,
                                ),
                                const SizedBox(height: 24),
                                _buildActionButtons(desktop),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final desktop = isDesktop(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        ],
      ),
    );
  }

  Widget _buildImage({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Icon(
                Icons.image,
                size: 60,
                color: Colors.grey[400],
              ),
            )
          : null,
    );
  }

  Widget _buildInfoCards() {
    return Row(
      children: [
        _buildInfoCard(
          icon: Icons.access_time,
          label: 'Temps',
          value: 'Durée (sec)',
          color: const Color(0xFF63A96E),
        ),
        const SizedBox(width: 12),
        _buildInfoCard(
          icon: Icons.people,
          label: 'Portions',
          value: 'nb personnes',
          color: const Color(0xFFF4A259),
        ),
        const SizedBox(width: 12),
        _buildInfoCard(
          icon: Icons.trending_up,
          label: 'Difficultés',
          value: 'Durée (sec)',
          color: const Color(0xFF2F6B3F),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
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
                color: Color(0xFFF4A259),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarbonFootprint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.eco,
              color: Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Impact',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Empreinte carbone',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
              const Text(
                'Empreinte calculée',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F6B3F),
                ),
              ),
              Text(
                'par portion',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    String subtitle,
    List<String> items, {
    bool numbered = false,
  }) {
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
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
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
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2E1F),
                    ),
                  )
                else
                  const Text(
                    '• ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F6B3F),
                    ),
                  ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1F2E1F),
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

  Widget _buildActionButtons(bool desktop) {
    if (desktop) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                size: 18,
              ),
              label: Text(
                _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F6B3F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _addToFolder,
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text(
                'Ajouter à un dossier',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF4A259),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
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
          child: ElevatedButton(
            onPressed: _toggleFavorite,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6B3F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addToFolder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF4A259),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Ajouter à un dossier',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
