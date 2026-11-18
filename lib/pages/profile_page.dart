import 'package:flutter/material.dart';

import '../models/user.dart' show UserFolder;
import '../utils/responsive.dart';
import 'profile/folder_dialogs.dart';
import 'profile/profile_edit_dialog.dart';
import 'profile/profile_controller.dart';
import 'profile/profile_widgets.dart';
import 'taste/taste_entry.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.controller});

  /// Injectable pour les tests ; sinon créé et libéré par la page.
  final ProfileController? controller;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileController _c = widget.controller ?? ProfileController();

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
    _c.load();
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _createFolder() async {
    final input = await showFolderDialog(
      context,
      title: 'Créer un nouveau dossier',
      confirmLabel: 'Créer',
      hint: 'Ex: Mes recettes rapides',
    );
    if (input != null) {
      await _c.createFolder(input.label, input.color.toARGB32());
    }
  }

  Future<void> _editFolder(UserFolder folder) async {
    final input = await showFolderDialog(
      context,
      title: 'Modifier le dossier',
      confirmLabel: 'Enregistrer',
      initialLabel: folder.label,
      initialColor: folder.color,
    );
    if (input != null) {
      await _c.updateFolder(folder, input.label, input.color.toARGB32());
    }
  }

  Future<void> _deleteFolder(UserFolder folder) async {
    if (await confirmDeleteFolder(context, folder)) {
      await _c.deleteFolder(folder);
    }
  }

  /// Au retour d'un dossier, les favoris et les contenus ont pu changer
  /// (retrait dans le dossier, favori basculé sur une recette) : on recharge.
  Future<void> _openFolder(UserFolder folder) async {
    await openFolder(context, folder);
    if (mounted) await _c.load();
  }

  Widget _buildTasteTile() {
    return TasteEntryTile(
      hasProfile: _c.hasTasteProfile,
      onTap: () async {
        final saved = await openTasteSwipe(context);
        if (saved && mounted) _c.markTasteProfileSaved();
      },
    );
  }

  Future<void> _editProfile() async {
    final edit = await showProfileEditDialog(context, _c.currentEdit);
    if (edit == null) return;
    final saved = await _c.saveProfile(edit);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved
          ? 'Profil enregistré.'
          : 'Enregistrement impossible : connecte-toi pour modifier ton profil.'),
    ));
  }

  Future<void> _logout() async {
    await _c.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
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
        ProfileMobileHero(
          avatar: _c.avatar,
          name: _c.displayName,
          onEdit: _editProfile,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MobileFoldersSection(
                folders: _c.folders,
                countOf: _c.recipeCountOf,
                onCreate: _createFolder,
                onEdit: _editFolder,
                onOpen: _openFolder,
                onDelete: _deleteFolder,
              ),
              const SizedBox(height: 24),
              MobilePreferencesSection(
                preferences: _c.displayPreferences,
                onEdit: _editProfile,
                extra: _buildTasteTile(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileDesktopBanner(
          avatar: _c.avatar,
          name: _c.displayName,
          email: _c.displayEmail,
          favoriteCount: _c.favoriteCount,
          folderCount: _c.folders.length,
          profileTag: _c.profileTag,
          onEdit: _editProfile,
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Colonne gauche — dossiers
            Expanded(
              flex: 5,
              child: DesktopFoldersSection(
                folders: _c.folders,
                countOf: _c.recipeCountOf,
                onCreate: _createFolder,
                onEdit: _editFolder,
                onOpen: _openFolder,
              ),
            ),
            const SizedBox(width: 24),
            // Colonne droite — préférences
            Expanded(
              flex: 4,
              child: DesktopPreferencesSection(
                preferences: _c.displayPreferences,
                onLogout: _logout,
                onEdit: _editProfile,
                extra: _buildTasteTile(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
