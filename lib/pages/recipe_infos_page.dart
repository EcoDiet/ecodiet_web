import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../models/recette.dart';
import '../models/user.dart';

class RecipeInfosPage extends StatefulWidget {
  final String? id;
  final String? title;
  final String? description;

  const RecipeInfosPage({
    Key? key,
    this.id,
    this.title,
    this.description,
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
          content: Text(isFavorite ? 'Ajouté aux favoris' : 'Retiré des favoris'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _addToFolder() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajouter à un dossier',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_folders.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Aucun dossier créé')),
              )
            else
              ..._folders.map((folder) => ListTile(
                leading: const Icon(Icons.folder, color: Color(0xFF2F6B3F)),
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
                final result = await _api.createFolder(label: controller.text.trim());
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Contenu scrollable
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : recette == null
                      ? const Center(child: Text('Recette non trouvée'))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image
                              _buildImage(),
                              const SizedBox(height: 16),

                              // Titre
                              Text(
                                recette!.recette.titre,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2E1F),
                                ),
                              ),
                              const SizedBox(height: 8),

                              const SizedBox(height: 20),

                              // Infos (Temps, Portions, Difficultés)
                              _buildInfoCards(),
                              const SizedBox(height: 20),

                              // Type de plat
                              if (recette!.typePlat != null) ...[
                                _buildTypePlat(),
                                const SizedBox(height: 24),
                              ],

                              // Allergènes
                              if (recette!.allergenes.isNotEmpty) ...[
                                _buildAllergenes(),
                                const SizedBox(height: 24),
                              ],

                              // Régime
                              if (recette!.regime != null) ...[
                                _buildRegime(),
                                const SizedBox(height: 24),
                              ],

                              // Ingrédients
                              _buildSection(
                                'Ingrédients',
                                '${recette!.ingredients.length} ingrédients',
                                recette!.ingredients.map((i) => i.nomIngredient).toList(),
                              ),
                              const SizedBox(height: 24),

                              // Boutons
                              _buildActionButtons(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1F2E1F)),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF1F2E1F)),
            onPressed: () {
              // TODO: Afficher le menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final photo = recette?.recette.photo ?? '';
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        image: photo.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(photo),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photo.isEmpty
          ? Center(
              child: Icon(
                Icons.restaurant,
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
          value: _formatDuration(recette?.recette.dureeMinute ?? 0),
          color: const Color(0xFF87CEEB),
        ),
        const SizedBox(width: 12),
        _buildInfoCard(
          icon: Icons.trending_up,
          label: 'Difficulté',
          value: _getDifficultyLabel(),
          color: const Color(0xFFF4A259),
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
          children: recette!.allergenes.map((a) => Chip(
            label: Text(a.libelle),
            backgroundColor: Colors.red[50],
            labelStyle: TextStyle(color: Colors.red[700]),
          )).toList(),
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
            color: Color(0xFF87CEEB),
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

  Widget _buildActionButtons() {
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
              isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
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
