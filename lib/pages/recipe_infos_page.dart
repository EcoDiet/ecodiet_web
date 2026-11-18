import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/ecodiet_api.dart';
import '../services/favorites_service.dart';
import '../models/recette.dart';
import '../models/user.dart';
import '../utils/responsive.dart';
import 'recipe_infos/recipe_info_widgets.dart';
import 'recipe_infos/recipe_text.dart';
import 'taste/taste_logic.dart' show ingredientLine;

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
  late final VoidCallback _favoritesListener;

  bool isFavorite = false;
  bool isLoading = true;
  RecetteComplete? recette;
  List<UserFolder> _folders = [];

  bool get _isFavorite => isFavorite;

  @override
  void initState() {
    super.initState();
    _favoritesListener = () {
      final id = recette?.recette.recetteId ?? widget.id;
      if (id == null || !mounted) return;
      final next = FavoritesService().isFavorite(id);
      if (next != isFavorite) {
        setState(() => isFavorite = next);
      }
    };
    FavoritesService().addListener(_favoritesListener);
    _loadRecipeDetails();
  }

  @override
  void dispose() {
    FavoritesService().removeListener(_favoritesListener);
    super.dispose();
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
        isFavorite = favResult || FavoritesService().isFavorite(recetteId);
        _folders = foldersResult;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (recette == null) return;

    final r = recette!.recette;

    // Bascule locale immédiate : l'UI répond toujours, même hors ligne.
    setState(() => isFavorite = !isFavorite);

    if (isFavorite) {
      FavoritesService().addFavorite(FavoriteRecipe(
        id: r.recetteId,
        title: r.titre,
        category: 'Recette',
        duration: r.dureeMinute > 0 ? '${r.dureeMinute} min' : '',
        imageUrl: r.photo.isNotEmpty ? recetteImageUrl(r.photo) : null,
      ));
    } else {
      FavoritesService().removeFavorite(r.recetteId);
    }

    // Synchronisation backend au mieux (nécessite une session active).
    final success = await _api.toggleFavorite(r.recetteId);
    if (!mounted) return;
    if (isFavorite && !success && !_api.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Favori enregistré sur cet appareil. Connecte-toi pour le synchroniser.',
          ),
          duration: Duration(seconds: 3),
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
    Color selectedColor = Colors.blue;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nouveau dossier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Nom du dossier',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Couleur du dossier', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: [
                  Colors.red,
                  Colors.orange,
                  Colors.amber,
                  Colors.green,
                  Colors.blue,
                  const Color(0xFF87CEEB),
                  Colors.purple,
                  Colors.pink,
                ].map((color) {
                  return InkWell(
                    onTap: () => setDialogState(() => selectedColor = color),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == color
                            ? Border.all(
                                color: const Color(0xFF1F2E1F),
                                width: 2.5,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
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
                    label: controller.text.trim(),
                    colorValue: selectedColor.toARGB32(),
                  );
                  if (result.isSuccess) {
                    final createdFolder = result.data;
                    final recetteId = recette?.recette.recetteId;
                    if (createdFolder?.folderId != null &&
                        recetteId != null &&
                        recetteId.isNotEmpty) {
                      await _api.addRecipeToFolder(
                        createdFolder!.folderId!,
                        recetteId,
                      );
                    }
                    final foldersResult = await _api.getFolders();
                    setState(() => _folders = foldersResult);
                  }
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Cr\u00e9er'),
            ),
          ],
        ),
      ),
    );
  }
  String get _recipeTitle =>
      recette?.recette.titre ?? widget.title ?? 'Titre de la recette';

  String? get _recipeCategory {
    final raw = (recette?.typePlat?.libelle ??
            recette?.regime?.libelle ??
            widget.description)
        ?.trim();
    if (raw == null || raw.isEmpty) return raw;
    return formatTypeLabel(raw);
  }

  /// Lignes avec quantités, apostrophes rétablies, fragments et doublons
  /// retirés (« 1 gousse d'ail »).
  List<String> _ingredientLabels() {
    final seen = <String>{};
    return [
      for (final i in recette?.ingredients ?? const <Ingredient>[])
        if (ingredientLine(fixMojibake(i.nomIngredient)) case final line
            when line.isNotEmpty && seen.add(line.toLowerCase()))
          line,
    ];
  }

  List<String> _equipmentLabels() =>
      recette?.equipements.map((e) => displayLabel(e.nomEquipement)).toList() ??
      [];

  List<String> _occasionLabels() =>
      recette?.occasions.map((o) => displayLabel(o.libelle)).toList() ?? [];

  List<String> _instructionLabels() =>
      parseInstructions(recette?.recette.etapes ?? '');

  Widget _actionButtons(bool desktop) => RecipeActionButtons(
        desktop: desktop,
        isFavorite: _isFavorite,
        onToggleFavorite: _toggleFavorite,
        onAddToFolder: _addToFolder,
      );

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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1F3A24), Color(0xFF2F6B3F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(Icons.eco_rounded,
                    size: 80, color: Colors.white.withValues(alpha: 0.12)),
              ),
            ),
            if (photo != null && photo.isNotEmpty)
              CachedNetworkImage(
                imageUrl: recetteImageUrl(photo),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
                placeholder: (_, __) => const SizedBox.shrink(),
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
                      Colors.black.withValues(alpha: 0.55),
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
    final ingredients = _ingredientLabels();
    final equipments = _equipmentLabels();
    final occasions = _occasionLabels();
    final instructions = _instructionLabels();
    final category = _recipeCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Text(
          _recipeTitle,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
            height: 1.2,
          ),
        ),
        // Catégorie pill
        if (category != null && category.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2F6B3F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category,
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
        const CarbonFootprintCard(),

        if (_hasMetaInlineData(occasions)) ...[
          const SizedBox(height: 20),
          _buildMetaInlineBar(occasions),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 28),
          MobileSection('Ingr\u00e9dients', ingredients),
        ],

        if (equipments.isNotEmpty) ...[
          const SizedBox(height: 24),
          MobileSection('Equipements', equipments),
        ],

        if (instructions.isNotEmpty) ...[
          const SizedBox(height: 24),
          MobileSection('Etapes', instructions, numbered: true),
        ],

        const SizedBox(height: 32),
        // Boutons
        _actionButtons(false),
      ],
    );
  }

  Widget _buildMobileInfoRow() {
    final durationStr = widget.duration ??
        formatDuration(recette?.recette.dureeMinute ?? 0);
    final difficulty = difficultyLabel(recette?.recette.dureeMinute ?? 0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          InfoStat(
              Icons.access_time_rounded, 'Temps', durationStr),
          const InfoDivider(),
          InfoStat(Icons.signal_cellular_alt_rounded, 'Difficulté',
              difficulty),
        ],
      ),
    );
  }

  bool _hasMetaInlineData(List<String> occasions) {
    final hasAllergenes = recette != null && recette!.allergenes.isNotEmpty;
    final hasType = recette?.typePlat?.libelle.trim().isNotEmpty ?? false;
    final hasRegime = recette?.regime?.libelle.trim().isNotEmpty ?? false;
    return hasAllergenes || hasType || hasRegime || occasions.isNotEmpty;
  }

  Widget _buildMetaInlineBar(List<String> occasions) {
    final chips = <Widget>[];

    if (recette != null && recette!.allergenes.isNotEmpty) {
      chips.add(MetaChip(
        'Allergène',
        recette!.allergenes.first.libelle,
        const Color(0xFFD94F3D),
      ));
    }
    final typeRaw = recette?.typePlat?.libelle.trim() ?? '';
    final type = typeRaw.isEmpty ? '' : formatTypeLabel(typeRaw);
    if (type.isNotEmpty) {
      chips.add(MetaChip('Type', type, const Color(0xFF3F6FC6)));
    }
    final regime = recette?.regime?.libelle.trim() ?? '';
    if (regime.isNotEmpty) {
      chips.add(MetaChip('Régime', regime, const Color(0xFF4F8D4F)));
    }
    if (occasions.isNotEmpty) {
      chips.add(MetaChip('Occasion', occasions.first, const Color(0xFFCF8748)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips),
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
    final ingredients = _ingredientLabels();
    final equipments = _equipmentLabels();
    final occasions = _occasionLabels();
    final instructions = _instructionLabels();
    final category = _recipeCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: RecipeImage(photo: recette?.recette.photo, height: 260)),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _recipeTitle,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2E1F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category ?? 'D\u00e9tail de la recette',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoCards(),
                  const SizedBox(height: 16),
                  const CarbonFootprintCard(),
                  const SizedBox(height: 20),
                  _actionButtons(true),
                ],
              ),
            ),
          ],
        ),
        if (_hasMetaInlineData(occasions)) ...[
          const SizedBox(height: 24),
          _buildMetaInlineBar(occasions),
        ],
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: 32),
          RecipeSection('Ingr\u00e9dients', 'liste des Ingr\u00e9dients', ingredients),
        ],
        if (equipments.isNotEmpty) ...[
          const SizedBox(height: 24),
          RecipeSection('\u00c9quipements', 'mat\u00e9riel conseill\u00e9', equipments),
        ],
        if (instructions.isNotEmpty) ...[
          const SizedBox(height: 24),
          RecipeSection('\u00c9tapes', 'pr\u00e9paration', instructions,
              numbered: true),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  Widget _buildInfoCards() {
    final durationStr = widget.duration ??
        formatDuration(recette?.recette.dureeMinute ?? 0);
    final difficulty = difficultyLabel(recette?.recette.dureeMinute ?? 0);

    return Row(
      children: [
        InfoCard(
          icon: Icons.access_time,
          label: 'Temps',
          value: durationStr,
          color: const Color(0xFF2F6B3F),
        ),
        const SizedBox(width: 12),
        InfoCard(
          icon: Icons.trending_up,
          label: 'Difficultés',
          value: difficulty,
          color: const Color(0xFF2F6B3F),
        ),
      ],
    );
  }

}
