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
  bool isLoading = true;
  late final FavoritesService _favoritesService;

  String? imageUrl;
  int duration = 0;
  int portions = 0;
  int difficulty = 0;
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

  void _onFavoritesChanged() => setState(() {});

  Future<void> _loadRecipeDetails() async {
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      duration = 1800;
      portions = 4;
      difficulty = 120;
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
  }

  bool get _isFavorite =>
      widget.id != null && _favoritesService.isFavorite(widget.id!);

  void _addToFolder() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ajouter à un dossier',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Fonctionnalité à implémenter'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);

    if (!desktop) {
      return _buildMobileScaffold();
    }

    // ── Desktop layout ──────────────────────────────────────────────────────
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              children: [
                _buildDesktopHeader(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          child: _buildDesktopContent(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile ─────────────────────────────────────────────────────────────────

  Widget _buildMobileScaffold() {
    if (isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: CustomScrollView(
        slivers: [
          _buildMobileSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildMobileContent(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1F3A24),
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: Colors.black26,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black26,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: Icon(
                _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _isFavorite ? Colors.red[300] : Colors.white,
                size: 22,
              ),
              tooltip: _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
              onPressed: _toggleFavorite,
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.fromLTRB(60, 0, 60, 14),
        title: Text(
          widget.title ?? '',
          style: const TextStyle(
              fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F3A24), Color(0xFF2F6B3F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: imageUrl == null
                  ? Center(
                      child: Icon(Icons.eco_rounded,
                          size: 80,
                          color: Colors.white.withOpacity(0.12)))
                  : null,
            ),
            // Bottom scrim
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.55),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Text(
          widget.title ?? 'Titre de la recette',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
            height: 1.2,
          ),
        ),
        // Catégorie pill
        if (widget.description != null &&
            widget.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2F6B3F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.description!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2F6B3F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Info stats
        _buildMobileInfoRow(),
        const SizedBox(height: 16),
        // Empreinte carbone
        _buildCarbonFootprint(),
        const SizedBox(height: 28),
        // Ingrédients
        _buildMobileSection('Ingrédients', ingredients),
        const SizedBox(height: 28),
        // Instructions
        _buildMobileSection('Instructions', instructions, numbered: true),
        const SizedBox(height: 32),
        // Boutons
        _buildActionButtons(false),
      ],
    );
  }

  Widget _buildMobileInfoRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildInfoStat(
              Icons.access_time_rounded, 'Temps', widget.duration ?? '–'),
          _buildInfoDivider(),
          _buildInfoStat(
              Icons.people_rounded, 'Portions', '${portions}p'),
          _buildInfoDivider(),
          _buildInfoStat(
              Icons.signal_cellular_alt_rounded, 'Difficulté', 'Facile'),
        ],
      ),
    );
  }

  Widget _buildInfoStat(IconData icon, String label, String value) {
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

  Widget _buildInfoDivider() {
    return Container(width: 1, height: 40, color: const Color(0xFFEEEEEE));
  }

  Widget _buildMobileSection(String title, List<String> items,
      {bool numbered = false}) {
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2F6B3F).withOpacity(0.1),
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

  // ── Desktop ────────────────────────────────────────────────────────────────

  Widget _buildDesktopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 20),
            label: const Text('Retour'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2F6B3F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: _buildImage(height: 260)),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title ?? 'Titre de la recette',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2E1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.description ?? 'Description',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCards(),
                  const SizedBox(height: 16),
                  _buildCarbonFootprint(),
                  const SizedBox(height: 20),
                  _buildActionButtons(true),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildSection('Ingrédients', 'liste des ingrédients',
                  ingredients),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: _buildSection(
                  'Instructions', 'étapes à suivre', instructions,
                  numbered: true),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildImage({required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: imageUrl == null
          ? Center(
              child: Icon(Icons.eco, size: 60, color: Colors.white.withOpacity(0.3)))
          : null,
    );
  }

  Widget _buildInfoCards() {
    final difficultyLabel = difficulty <= 60
        ? 'Facile'
        : difficulty <= 120
            ? 'Moyen'
            : 'Difficile';
    return Row(
      children: [
        _buildInfoCard(
          icon: Icons.access_time,
          label: 'Temps',
          value: widget.duration ?? '–',
          color: const Color(0xFF2F6B3F),
        ),
        const SizedBox(width: 12),
        _buildInfoCard(
          icon: Icons.people,
          label: 'Portions',
          value: '${portions}p',
          color: const Color(0xFF2F6B3F),
        ),
        const SizedBox(width: 12),
        _buildInfoCard(
          icon: Icons.trending_up,
          label: 'Difficultés',
          value: difficultyLabel,
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

  Widget _buildCarbonFootprint() {
    return Container(
      padding: const EdgeInsets.all(12),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2F6B3F).withOpacity(0.12),
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
              Text(
                '${carbonFootprint.toStringAsFixed(1)} kg CO₂',
                style: const TextStyle(
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
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[700])),
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
                        color: Color(0xFF1F2E1F)),
                  )
                else
                  const Text(
                    '• ',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F6B3F)),
                  ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF1F2E1F)),
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
                  size: 18),
              label: Text(
                _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
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
              onPressed: _addToFolder,
              icon: const Icon(Icons.folder_outlined, size: 18),
              label: const Text(
                'Ajouter à un dossier',
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
            onPressed: _toggleFavorite,
            icon: Icon(
                _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 20),
            label: Text(
              _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
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
            onPressed: _addToFolder,
            icon: const Icon(Icons.folder_outlined, size: 20),
            label: const Text(
              'Ajouter à un dossier',
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
