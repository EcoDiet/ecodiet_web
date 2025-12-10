import 'package:flutter/material.dart';

/// Modèle pour un dossier
class Folder {
  final String id;
  final String label;
  final int recipeCount;
  final Color color;

  Folder({
    required this.id,
    required this.label,
    required this.recipeCount,
    required this.color,
  });
}

/// Modèle pour une préférence
class Preference {
  final String label;
  final String value;

  Preference({
    required this.label,
    required this.value,
  });
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // TODO: Charger les données depuis l'API
  List<Folder> folders = [];
  List<Preference> preferences = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    // TODO: Remplacer par les appels API réels
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      folders = [
        Folder(
          id: 'favorites',
          label: 'Favoris',
          recipeCount: 0, // Nombre de recettes favorites
          color: Colors.red,
        ),
        Folder(
          id: '2',
          label: 'Label 2',
          recipeCount: 1, // Nombre de recettes dans ce dossier
          color: Colors.amber,
        ),
        Folder(
          id: '3',
          label: 'Label 3',
          recipeCount: 0, // Dossier vide
          color: const Color(0xFF87CEEB),
        ),
      ];

      preferences = [
        Preference(label: 'Label 1', value: 'Préférence 1'),
        Preference(label: 'Label 2', value: 'Préférence 2'),
        Preference(label: 'Label 3', value: 'Préférence 3'),
      ];
    });
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: const Center(
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
              onPressed: () {
                if (labelController.text.trim().isEmpty) {
                  return;
                }

                setState(() {
                  folders.add(Folder(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    label: labelController.text.trim(),
                    recipeCount: 0,
                    color: selectedColor,
                  ));
                });

                Navigator.pop(context);
                // TODO: Appeler l'API pour créer le dossier
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

  Widget _buildFolderItem(Folder folder) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/folder',
          arguments: {
            'id': folder.id,
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
              color: Colors.black.withOpacity(0.05),
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
              folder.id == 'favorites' ? Icons.favorite : Icons.folder,
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

  Widget _buildPreferenceItem(Preference pref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFFF4A259),
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
