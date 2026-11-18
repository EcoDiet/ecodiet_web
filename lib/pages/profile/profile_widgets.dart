import 'package:flutter/material.dart';

import '../../models/user.dart';
import 'profile_controller.dart' show countLabel, isFavoritesFolder;

/// Ouvre la page du dossier ; le Future se termine au retour sur le profil.
Future<void> openFolder(BuildContext context, UserFolder folder) {
  return Navigator.pushNamed(context, '/folder', arguments: {
    'id': folder.folderId?.toString() ?? '',
    'label': folder.label,
    'color': folder.color,
  });
}

class ProfileMobileHero extends StatelessWidget {
  const ProfileMobileHero(
      {super.key, required this.avatar, required this.name});

  final String avatar;
  final String name;

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white.withValues(alpha: 0.25), width: 3),
            ),
            child: Center(
              child: Text(
                avatar,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          // Bouton modifier
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 14),
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
}

class ProfileDesktopBanner extends StatelessWidget {
  const ProfileDesktopBanner(
      {super.key,
      required this.avatar,
      required this.name,
      required this.email,
      required this.favoriteCount,
      required this.folderCount,
      required this.profileTag});

  final String avatar;
  final String name;
  final String email;
  final int favoriteCount;
  final int folderCount;
  final String profileTag;

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.white.withValues(alpha: 0.04),
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
                    color: Colors.white.withValues(alpha: 0.03),
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
                  color: Colors.black.withValues(alpha: 0.08),
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
                    border:
                        Border.all(color: const Color(0xFFF5ECD9), width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2F6B3F).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      avatar,
                      style: const TextStyle(
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
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2E1F),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 14),
                      // Stats pills
                      Wrap(
                        spacing: 8,
                        children: [
                          StatChip(Icons.favorite_rounded,
                              countLabel(favoriteCount, 'favori'), Colors.red),
                          StatChip(
                              Icons.folder_rounded,
                              countLabel(folderCount, 'dossier'),
                              const Color(0xFFF4A259)),
                          StatChip(Icons.eco_rounded, profileTag,
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
                    side:
                        const BorderSide(color: Color(0xFF2F6B3F), width: 1.5),
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
}

class StatChip extends StatelessWidget {
  const StatChip(this.icon, this.label, this.color, {super.key});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
}

class DesktopFoldersSection extends StatelessWidget {
  const DesktopFoldersSection(
      {super.key,
      required this.folders,
      required this.countOf,
      required this.onCreate,
      required this.onEdit,
      required this.onOpen});

  final List<UserFolder> folders;
  final int Function(UserFolder) countOf;
  final VoidCallback onCreate;
  final ValueChanged<UserFolder> onEdit;
  final ValueChanged<UserFolder> onOpen;

  @override
  Widget build(BuildContext context) {
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
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nouveau dossier'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4A259),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
          itemBuilder: (_, i) => KeyedSubtree(
            key: ValueKey(folders[i].folderId),
            child: DesktopFolderTile(
              folder: folders[i],
              count: countOf(folders[i]),
              onEdit: () => onEdit(folders[i]),
              onOpen: () => onOpen(folders[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class DesktopFolderTile extends StatelessWidget {
  const DesktopFolderTile(
      {super.key,
      required this.folder,
      required this.count,
      required this.onEdit,
      required this.onOpen});

  final UserFolder folder;
  final int count;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final isFavorites = isFavoritesFolder(folder);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
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
                      color: folder.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isFavorites
                          ? Icons.favorite_rounded
                          : Icons.folder_rounded,
                      color: folder.color,
                      size: 20,
                    ),
                  ),
                  if (!isFavorites)
                    InkWell(
                      onTap: onEdit,
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
                    countLabel(count, 'recette'),
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
}

class DesktopPreferencesSection extends StatelessWidget {
  const DesktopPreferencesSection(
      {super.key,
      required this.preferences,
      required this.onLogout,
      this.extra});

  final List<UserPreference> preferences;
  final VoidCallback onLogout;

  /// Bloc affiché entre les préférences et la déconnexion (« Mes goûts »).
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
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
                  DesktopPrefRow(pref: pref, index: i),
                  if (i < preferences.length - 1)
                    Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey[100],
                        indent: 16,
                        endIndent: 16),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (extra != null) ...[
          extra!,
          const SizedBox(height: 16),
        ],
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
              onTap: onLogout,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.logout_rounded,
                          color: Colors.red[400], size: 18),
                    ),
                    const SizedBox(width: 14),
                    Text('Déconnexion',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.red[400])),
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
}

/// Les trois premières préférences ont chacune leur icône et leur couleur.
class DesktopPrefRow extends StatelessWidget {
  const DesktopPrefRow({super.key, required this.pref, required this.index});

  final UserPreference pref;
  final int index;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.flag_outlined,
      Icons.restaurant_outlined,
      Icons.warning_amber_outlined
    ];
    const colors = [Color(0xFF2F6B3F), Color(0xFFF4A259), Color(0xFF3A7BD5)];
    final idx = index.clamp(0, 2);

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
                  color: colors[idx].withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icons[idx], color: colors[idx], size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pref.label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F2E1F))),
                    Text(pref.value,
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[700])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileFoldersSection extends StatelessWidget {
  const MobileFoldersSection(
      {super.key,
      required this.folders,
      required this.countOf,
      required this.onCreate,
      required this.onEdit,
      required this.onOpen,
      required this.onDelete});

  final List<UserFolder> folders;
  final int Function(UserFolder) countOf;
  final VoidCallback onCreate;
  final ValueChanged<UserFolder> onEdit;
  final ValueChanged<UserFolder> onOpen;
  final ValueChanged<UserFolder> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SectionHeader(icon: Icons.folder, title: 'Mes dossiers'),
            Tooltip(
              message: 'Créer un dossier',
              child: InkWell(
                onTap: onCreate,
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
              child: FolderItem(
                folder: folder,
                count: countOf(folder),
                onEdit: () => onEdit(folder),
                onOpen: () => onOpen(folder),
                onDelete: () => onDelete(folder),
              ),
            )),
      ],
    );
  }
}

class MobilePreferencesSection extends StatelessWidget {
  const MobilePreferencesSection(
      {super.key, required this.preferences, this.extra});

  final List<UserPreference> preferences;

  /// Bloc affiché sous les préférences (« Mes goûts »).
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(icon: Icons.tune, title: 'Mes préférences'),
        const SizedBox(height: 12),
        ...preferences.map((pref) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PreferenceItem(pref: pref),
            )),
        if (extra != null) extra!,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
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
}

class FolderItem extends StatelessWidget {
  const FolderItem(
      {super.key,
      required this.folder,
      required this.count,
      required this.onEdit,
      required this.onOpen,
      required this.onDelete});

  final UserFolder folder;
  final int count;
  final VoidCallback onEdit;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isFavorites = isFavoritesFolder(folder);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: folder.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isFavorites ? Icons.favorite : Icons.folder,
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
                        countLabel(count, 'recette'),
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                if (!isFavorites)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz,
                        color: Colors.grey[400], size: 22),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Modifier'),
                          ],
                        ),
                      ),
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
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                  )
                else
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PreferenceItem extends StatelessWidget {
  const PreferenceItem({super.key, required this.pref});

  final UserPreference pref;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4A259).withValues(alpha: 0.15),
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
                      Text(pref.label,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2E1F))),
                      const SizedBox(height: 2),
                      Text(pref.value,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
