import 'package:flutter/material.dart';

import '../create_account/onboarding_options.dart';
import '../create_account/onboarding_widgets.dart';
import 'profile_controller.dart' show ProfileEdit;

/// Boîte « Modifier le profil » : prénom, nom, régime et allergies, avec les
/// mêmes choix qu'à l'inscription. Retourne `null` si l'utilisateur annule.
Future<ProfileEdit?> showProfileEditDialog(
  BuildContext context,
  ProfileEdit initial,
) {
  return showDialog<ProfileEdit>(
    context: context,
    builder: (_) => _ProfileEditDialog(initial: initial),
  );
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.initial});

  final ProfileEdit initial;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final _prenom = TextEditingController(text: widget.initial.prenom);
  late final _nom = TextEditingController(text: widget.initial.nom);
  late String? _regime = widget.initial.regime;
  late final Set<String> _allergies = {...widget.initial.allergies};

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop<ProfileEdit>(context, (
      prenom: _prenom.text.trim(),
      nom: _nom.text.trim(),
      regime: _regime,
      allergies: _allergies,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le profil'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prenom,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _nom,
                      decoration: const InputDecoration(labelText: 'Nom'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const OnboardingLabel(text: 'Régime alimentaire'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in dietOptions)
                    DietChip(
                      option: option,
                      selected: _regime == option.value,
                      // Un second appui désélectionne : aucun régime.
                      onTap: () => setState(() => _regime =
                          _regime == option.value ? null : option.value),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const OnboardingLabel(text: 'Allergies et intolérances'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in allergyOptions)
                    AllergyChip(
                      option: option,
                      selected: _allergies.contains(option.value),
                      onTap: () => setState(() {
                        if (!_allergies.remove(option.value)) {
                          _allergies.add(option.value);
                        }
                      }),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2F6B3F),
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
