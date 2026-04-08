import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/ecodiet_api.dart';
import '../models/recette.dart';
import '../models/user.dart';
import '../utils/responsive.dart';

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
  final EcoDietApi _api = EcoDietApi();

  bool isFavorite = false;
  bool isLoading = true;
  RecetteComplete? recette;
  List<UserFolder> _folders = [];

  bool get _isFavorite => isFavorite;

  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
  }

  Future<void> _loadRecipeDetails() async {
    if (widget.id == null) {
      setState(() => isLoading = false);
      return;
    }

    final recetteId = widget.id!;
    final result = await _api.getRecetteComplete(recetteId);

    if (result != null) {
      final favResult = await _api.isFavorite(recetteId);
      final foldersResult = await _api.getFolders();

      setState(() {
        recette = result;
        isFavorite = favResult;
        _folders = foldersResult;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (recette == null) return;

    final success = await _api.toggleFavorite(recette!.recette.recetteId);
    if (success) {
      setState(() => isFavorite = !isFavorite);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            if (_folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Aucun dossier créé')),
              )
            else
              ..._folders.map((folder) => ListTile(
                    leading:
                        const Icon(Icons.folder, color: Color(0xFF2F6B3F)),
                    title: Text(folder.label),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      if (recette != null && folder.folderId != null) {
                        final success = await _api.addRecipeToFolder(
                          folder.folderId!,
                          recette!.recette.recetteId,
                        );
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Ajouté à "${folder.label}"'
                                  : 'Erreur lors de l\'ajout',
                            ),
                          ),
                        );
                      }
                    },
                  )),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Nouveau dossier'),
                onPressed: () {
                  Navigator.pop(context);
                  _showCreateFolderDialog();
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau dossier'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom du dossier',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final result = await _api.createFolder(
                    label: controller.text.trim());
                if (result.isSuccess) {
                  final foldersResult = await _api.getFolders();
                  setState(() => _folders = foldersResult);
                }
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h${remainingMinutes > 0 ? " ${remainingMinutes}min" : ""}';
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
    final photo = recette?.recette.photo;
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
              tooltip:
                  _isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
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
                image: photo != null && photo.isNotEmpty
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(photo),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: photo == null || photo.isEmpty
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
    final ingredients = recette?.ingredients
            .map((i) => i.nomIngredient)
            .toList() ??
        [];

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

        // Allergènes
        if (recette != null && recette!.allergenes.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildAllergenes(),
        ],

        // Type de plat
        if (recette != null && recette!.typePlat != null) ...[
          const SizedBox(height: 20),
          _buildTypePlat(),
        ],

        // Régime
        if (recette != null && recette!.regime != null) ...[
          const SizedBox(height: 20),
          _buildRegime(),
        ],

        // Ingrédients
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 28),
          _buildMobileSection('Ingrédients', ingredients),
        ],

        const SizedBox(height: 32),
        // Boutons
        _buildActionButtons(false),
      ],
    );
  }

  Widget _buildMobileInfoRow() {
    final durationStr = widget.duration ??
        _formatDuration(recette?.recette.dureeMinute ?? 0);
    final difficultyLabel = _getDifficultyLabel();

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
              Icons.access_time_rounded, 'Temps', durationStr),
          _buildInfoDivider(),
          _buildInfoStat(Icons.signal_cellular_alt_rounded, 'Difficulté',
              difficultyLabel),
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
    final ingredients = recette?.ingredients
            .map((i) => i.nomIngredient)
            .toList() ??
        [];

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
        if (recette != null && recette!.allergenes.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildAllergenes(),
        ],
        if (recette != null && recette!.typePlat != null) ...[
          const SizedBox(height: 24),
          _buildTypePlat(),
        ],
        if (recette != null && recette!.regime != null) ...[
          const SizedBox(height: 24),
          _buildRegime(),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildSection('Ingrédients', 'liste des ingrédients', ingredients),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildImage({required double height}) {
    final photo = recette?.recette.photo;
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
        image: photo != null && photo.isNotEmpty
            ? DecorationImage(
                image: CachedNetworkImageProvider(photo),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photo == null || photo.isEmpty
          ? Center(
              child: Icon(Icons.eco,
                  size: 60, color: Colors.white.withOpacity(0.3)))
          : null,
    );
  }

  Widget _buildInfoCards() {
    final durationStr = widget.duration ??
        _formatDuration(recette?.recette.dureeMinute ?? 0);
    final difficultyLabel = _getDifficultyLabel();

    return Row(
      children: [
        _buildInfoCard(
          icon: Icons.access_time,
          label: 'Temps',
          value: durationStr,
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

  String _getDifficultyLabel() {
    final duree = recette?.recette.dureeMinute ?? 0;
    if (duree <= 15) return 'Facile';
    if (duree <= 30) return 'Moyen';
    return 'Difficile';
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

  Widget _buildAllergenes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Allergènes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF44336),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recette!.allergenes
              .map((a) => Chip(
                    label: Text(a.libelle),
                    backgroundColor: Colors.red[50],
                    labelStyle: TextStyle(color: Colors.red[700]),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildTypePlat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type de plat',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2F6B3F),
          ),
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(recette!.typePlat!.libelle),
          backgroundColor: Colors.blue[50],
          labelStyle: TextStyle(color: Colors.blue[700]),
        ),
      ],
    );
  }

  Widget _buildRegime() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Régime compatible',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2F6B3F),
          ),
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(recette!.regime!.libelle),
          backgroundColor: Colors.green[50],
          labelStyle: TextStyle(color: Colors.green[700]),
        ),
      ],
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
            child:
                const Icon(Icons.eco, color: Color(0xFF2F6B3F), size: 24),
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
                '–',
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
                style:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
                _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
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
