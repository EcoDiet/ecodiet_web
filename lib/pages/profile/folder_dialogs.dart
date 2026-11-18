import 'package:flutter/material.dart';

import '../../models/user.dart';

final folderColors = <Color, String>{
  Colors.red: 'Rouge',
  Colors.orange: 'Orange',
  Colors.amber: 'Ambre',
  Colors.green: 'Vert',
  Colors.blue: 'Bleu',
  const Color(0xFF87CEEB): 'Bleu ciel',
  Colors.purple: 'Violet',
  Colors.pink: 'Rose',
};

typedef FolderInput = ({String label, Color color});

/// Saisie du nom et de la couleur d'un dossier (création ou modification).
/// Retourne `null` si l'utilisateur annule ou laisse le nom vide.
Future<FolderInput?> showFolderDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String initialLabel = '',
  Color initialColor = Colors.blue,
  String? hint,
}) {
  final controller = TextEditingController(text: initialLabel);
  var selected = initialColor;

  return showDialog<FolderInput>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Nom du dossier',
                hintText: hint,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('Couleur du dossier', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: folderColors.entries.map((entry) {
                final color = entry.key;
                final isSelected = selected == color;
                return Semantics(
                  label: '${entry.value}${isSelected ? ', sélectionné' : ''}',
                  button: true,
                  child: InkWell(
                    onTap: () => setDialogState(() => selected = color),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF1F2E1F), width: 3)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
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
              final label = controller.text.trim();
              if (label.isEmpty) return;
              Navigator.pop(context, (label: label, color: selected));
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
}

/// Confirmation avant suppression ; `true` si l'utilisateur confirme.
Future<bool> confirmDeleteFolder(
    BuildContext context, UserFolder folder) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Supprimer le dossier ?'),
      content: Text(
          'Voulez-vous supprimer le dossier "${folder.label}" ? Cette action est irréversible.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
