import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../models/user.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final EcoDietApi _api = EcoDietApi();
  
  List<UserFolder> folders = [];
  List<UserPreference> preferences = [];
  int favoriteCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final loadedFolders = await _api.getFolders();
      final loadedPreferences = await _api.getUserPreferences();
      final favorites = await _api.getFavorites();

      setState(() {
        folders = loadedFolders;
        preferences = loadedPreferences;
        favoriteCount = favorites.length;
      });
    } catch (e) {
      debugPrint('Erreur chargement profil: $e');
    }
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo de profil
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Mes dossiers avec bouton +
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader(Icons.folder, 'Mes dossiers'),
                        GestureDetector(
                          onTap: _showCreateFolderDialog,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4A259),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...folders.map((folder) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildFolderItem(folder),
                        )),
                    const SizedBox(height: 24),

                    // Mes préférences
                    _buildSectionHeader(Icons.tune, 'Mes préférences'),
                    const SizedBox(height: 12),
                    ...preferences.map((pref) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPreferenceItem(pref),
                        )),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Center(
        child: Text(
          'Profil',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
          ),
        ),
      ),
    );
  }

  void _showCreateFolderDialog() {
    final TextEditingController labelController = TextEditingController();
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Créer un nouveau dossier'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Nom du dossier',
                  hintText: 'Ex: Mes recettes rapides',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              const Text('Couleur du dossier', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
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
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == color
                            ? Border.all(
                                color: const Color(0xFF1F2E1F),
                                width: 3,
                              )
                            : null,
                      ),
                      child: selectedColor == color
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
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
            TextButton(
              onPressed: () async {
                if (labelController.text.trim().isEmpty) {
                  return;
                }

                final result = await _api.createFolder(
                  label: labelController.text.trim(),
                  colorValue: selectedColor.toARGB32(),
                );

                if (result.isSuccess) {
                  await _loadProfileData();
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFF4A259), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderItem(UserFolder folder) {
    final isFavorites = folder.label.toLowerCase() == 'favoris';
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/folder',
          arguments: {
            'id': folder.folderId.toString(),
            'label': folder.label,
            'color': folder.color,
          },
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: folder.color,
              borderRadius: BorderRadius.circular(8),
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
                  folder.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2E1F),
                  ),
                ),
                Text(
                  '🍴 ${folder.recipeCount} recette(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.grey[400],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPreferenceItem(UserPreference pref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Color(0xFFF4A259),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pref.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2E1F),
            ),
          ),
          Text(
            pref.value,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
