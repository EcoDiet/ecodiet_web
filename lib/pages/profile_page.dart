import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../services/favorites_service.dart';

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
    FavoritesService().addListener(_onFavoritesChanged);
  }

  @override
  void dispose() {
    FavoritesService().removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    setState(() {});
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
    final desktop = isDesktop(context);

    if (desktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5ECD9),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: _buildDesktopLayout(),
              ),
            ),
          ),
        ),
      );
    }

    // Mobile : hero va sous la status bar
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: _buildMobileLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMobileHero(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFoldersSection(),
              const SizedBox(height: 24),
              _buildPreferencesSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHero() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F3A24), Color(0xFF2F6B3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Avatar circulaire
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF63A96E),
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 3),
            ),
            child: const Center(
              child: Text(
                'U',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Utilisateur',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // Bouton modifier
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {},
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined,
                        color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Modifier le profil',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHero() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(24, topPadding + 24, 24, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F3A24), Color(0xFF2F6B3F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Avatar circulaire
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF63A96E),
              border: Border.all(
                  color: Colors.white.withOpacity(0.25), width: 3),
            ),
            child: const Center(
              child: Text(
                'U',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Utilisateur',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // Bouton modifier
          Material(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {},
              child: const Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined,
                        color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Modifier le profil',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDesktopBanner(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne gauche — dossiers
            Expanded(
              flex: 5,
              child: _buildDesktopFoldersSection(),
            ),
            const SizedBox(width: 24),
            // Colonne droite — préférences
            Expanded(
              flex: 4,
              child: _buildDesktopPreferencesSection(),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Banner + carte profil ─────────────────────────────────────────────────

  Widget _buildDesktopBanner() {
    final favCount = FavoritesService().count;
    return Column(
      children: [
        // Banner gradient
        Container(
          height: 140,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1F3A24), Color(0xFF2F6B3F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Stack(
            children: [
              // Motif décoratif
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              Positioned(
                right: 60,
                bottom: -40,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.03),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Carte profil (chevauchement)
        Transform.translate(
          offset: const Offset(0, -40),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2F6B3F), Color(0xFF63A96E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                        color: const Color(0xFFF5ECD9), width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2F6B3F).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'U',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Nom + infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Utilisateur',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2E1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'utilisateur@ecodiet.fr',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 14),
                      // Stats pills
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildStatChip(
                              Icons.favorite_rounded,
                              '$favCount favori${favCount > 1 ? 's' : ''}',
                              Colors.red),
                          _buildStatChip(
                              Icons.folder_rounded,
                              '${folders.length} dossier${folders.length > 1 ? 's' : ''}',
                              const Color(0xFFF4A259)),
                          _buildStatChip(
                              Icons.eco_rounded,
                              'Végétarien',
                              const Color(0xFF2F6B3F)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bouton modifier
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2F6B3F),
                    side: const BorderSide(
                        color: Color(0xFF2F6B3F), width: 1.5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Préférences desktop ───────────────────────────────────────────────────

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dossiers desktop ──────────────────────────────────────────────────────

  Widget _buildDesktopFoldersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Mes dossiers',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2E1F),
              ),
            ),
            FilledButton.icon(
              onPressed: _showCreateFolderDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nouveau dossier'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4A259),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: folders.length,
          itemBuilder: (_, i) => _buildDesktopFolderTile(folders[i]),
        ),
      ],
    );
  }

  Widget _buildDesktopFolderTile(Folder folder) {
    final count = folder.id == 'favorites'
        ? FavoritesService().count
        : folder.recipeCount;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/folder', arguments: {
          'id': folder.id,
          'label': folder.label,
          'color': folder.color,
        }),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[100]!),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: folder.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      folder.id == 'favorites'
                          ? Icons.favorite_rounded
                          : Icons.folder_rounded,
                      color: folder.color,
                      size: 20,
                    ),
                  ),
                  if (folder.id != 'favorites')
                    InkWell(
                      onTap: () => _showDeleteFolderDialog(folder),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.more_horiz,
                            color: Colors.grey[400], size: 18),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2E1F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count recette${count > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Préférences desktop ───────────────────────────────────────────────────

  Widget _buildDesktopPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mes préférences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2E1F),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: preferences.asMap().entries.map((entry) {
              final i = entry.key;
              final pref = entry.value;
              return Column(
                children: [
                  _buildDesktopPrefRow(pref),
                  if (i < preferences.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey[100],
                      indent: 16,
                      endIndent: 16,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Section déconnexion
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[100]!),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushReplacementNamed(
                  context, '/login'),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.logout_rounded,
                          color: Colors.red[400], size: 18),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Déconnexion',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.red[400],
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: Colors.grey[300], size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopPrefRow(Preference pref) {
    const icons = [Icons.flag_outlined, Icons.restaurant_outlined, Icons.warning_amber_outlined];
    const colors = [Color(0xFF2F6B3F), Color(0xFFF4A259), Color(0xFF3A7BD5)];
    final idx = preferences.indexOf(pref).clamp(0, 2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors[idx].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icons[idx], color: colors[idx], size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                          fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey[300], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoldersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(Icons.folder, 'Mes dossiers'),
            Tooltip(
              message: 'Créer un dossier',
              child: InkWell(
                onTap: _showCreateFolderDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4A259),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, size: 20, color: Colors.white),
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
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.tune, 'Mes préférences'),
        const SizedBox(height: 12),
        ...preferences.map((pref) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildPreferenceItem(pref),
            )),
      ],
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
                  final colorName = {
                    Colors.red: 'Rouge',
                    Colors.orange: 'Orange',
                    Colors.amber: 'Ambre',
                    Colors.green: 'Vert',
                    Colors.blue: 'Bleu',
                    const Color(0xFF87CEEB): 'Bleu ciel',
                    Colors.purple: 'Violet',
                    Colors.pink: 'Rose',
                  }[color] ?? 'Couleur';
                  return Semantics(
                    label: '$colorName${selectedColor == color ? ', sélectionné' : ''}',
                    button: true,
                    child: InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedColor = color;
                        });
                      },
                      borderRadius: BorderRadius.circular(18),
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

  void _showDeleteFolderDialog(Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le dossier ?'),
        content: Text(
            'Voulez-vous supprimer le dossier "${folder.label}" ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                folders.removeWhere((f) => f.id == folder.id);
              });
              Navigator.pop(context);
              // TODO: Appeler l'API pour supprimer le dossier
            },
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem(Folder folder) {
    final count = folder.id == 'favorites'
        ? FavoritesService().count
        : folder.recipeCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            '/folder',
            arguments: {
              'id': folder.id,
              'label': folder.label,
              'color': folder.color,
            },
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: folder.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    folder.id == 'favorites'
                        ? Icons.favorite
                        : Icons.folder,
                    color: folder.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2E1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count recette${count > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                if (folder.id != 'favorites')
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz, color: Colors.grey[400], size: 22),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: Colors.red[400], size: 18),
                            const SizedBox(width: 10),
                            Text('Supprimer',
                                style: TextStyle(color: Colors.red[400])),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') _showDeleteFolderDialog(folder);
                    },
                  )
                else
                  Icon(Icons.chevron_right,
                      color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceItem(Preference pref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4A259).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.tune,
                      color: Color(0xFFF4A259), size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pref.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2E1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pref.value,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
