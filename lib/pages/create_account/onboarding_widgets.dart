import 'package:flutter/material.dart';

import 'onboarding_options.dart';

/// Panneau gauche (desktop) : logo, accroche et indicateur d'étapes.
class OnboardingBrandingPanel extends StatelessWidget {
  final int currentStep;
  final VoidCallback onLogoTap;

  const OnboardingBrandingPanel({
    super.key,
    required this.currentStep,
    required this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1F3A24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onLogoTap,
            child: Image.asset('lib/assets/logo/EcoDiet-Logo-beige.png',
                height: 200, semanticLabel: 'Logo EcoDiet'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mangez sainement, naturellement.',
            style: TextStyle(color: Color(0xFF8FBF97), fontSize: 16),
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF2F5435)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Text(
              'Des recettes saines pour la planète',
              style: TextStyle(color: Color(0xFF8FBF97), fontSize: 13),
            ),
          ),
          const SizedBox(height: 48),
          // Indicateur d'étapes animé
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(onboardingStepTitles.length, (i) {
              final isActive = i == currentStep;
              final isDone = i < currentStep;
              return Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF63A96E)
                          : isActive
                              ? const Color(0xFF8FBF97)
                              : const Color(0xFF2F5435),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  if (i < onboardingStepTitles.length - 1)
                    const SizedBox(width: 6),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'Étape ${currentStep + 1} sur ${onboardingStepTitles.length}',
            style: const TextStyle(
              color: Color(0xFF8FBF97),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Libellé de champ du formulaire.
class OnboardingLabel extends StatelessWidget {
  final String text;

  const OnboardingLabel({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2E1F),
        ),
      ),
    );
  }
}

/// Décoration commune des champs texte de l'inscription.
InputDecoration onboardingFieldDecoration(String hint,
    {Widget? suffixIcon, Widget? prefixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.grey),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF63A96E), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffixIcon,
    prefixIcon: prefixIcon,
  );
}

/// Bouton principal vert (grisé si `onPressed` est null).
class OnboardingPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const OnboardingPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              onPressed != null ? const Color(0xFF2F6B3F) : Colors.grey[300],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Choix du genre (étape 2). Renvoie un `Expanded` : à placer dans une `Row`.
class GenderChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const GenderChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2F6B3F) : Colors.white,
              border: Border.all(
                color:
                    selected ? const Color(0xFF2F6B3F) : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected ? Colors.white : const Color(0xFF1F2E1F)),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : const Color(0xFF1F2E1F),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Carte objectif (étape 3).
class GoalCard extends StatelessWidget {
  final GoalOption option;
  final bool selected;
  final VoidCallback onTap;

  const GoalCard({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${option.label} : ${option.sub}',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2F6B3F).withValues(alpha: 0.06)
                : Colors.white,
            border: Border.all(
              color: selected ? const Color(0xFF2F6B3F) : Colors.grey.shade200,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2F6B3F).withValues(alpha: 0.12)
                      : const Color(0xFF8FBF97).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  option.icon,
                  size: 22,
                  color: selected
                      ? const Color(0xFF2F6B3F)
                      : const Color(0xFF63A96E),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1F2E1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.sub,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: Color(0xFF2F6B3F), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puce régime (étape 4).
class DietChip extends StatelessWidget {
  final DietOption option;
  final bool selected;
  final VoidCallback onTap;

  const DietChip({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: option.label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2F6B3F) : Colors.white,
            border: Border.all(
              color: selected ? const Color(0xFF2F6B3F) : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF1F2E1F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puce allergie (étape 5), sélection multiple.
class AllergyChip extends StatelessWidget {
  final AllergyOption option;
  final bool selected;
  final VoidCallback onTap;

  const AllergyChip({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: option.label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2F6B3F) : Colors.white,
            border: Border.all(
              color: selected ? const Color(0xFF2F6B3F) : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                option.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF1F2E1F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Score de robustesse de 0 à 4 : longueur ≥ 8, majuscule, chiffre, symbole.
int passwordStrength(String pwd) {
  int strength = 0;
  if (pwd.length >= 8) strength++;
  if (pwd.contains(RegExp(r'[A-Z]'))) strength++;
  if (pwd.contains(RegExp(r'[0-9]'))) strength++;
  if (pwd.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength++;
  return strength;
}

class PasswordStrengthIndicator extends StatefulWidget {
  final TextEditingController controller;

  const PasswordStrengthIndicator({super.key, required this.controller});

  @override
  State<PasswordStrengthIndicator> createState() =>
      PasswordStrengthIndicatorState();
}

class PasswordStrengthIndicatorState extends State<PasswordStrengthIndicator> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pwd = widget.controller.text;
    if (pwd.isEmpty) return const SizedBox.shrink();

    final strength = passwordStrength(pwd);

    final colors = [
      Colors.red[400]!,
      Colors.orange[400]!,
      const Color(0xFF63A96E),
      const Color(0xFF2F6B3F),
    ];
    final labels = ['Faible', 'Moyen', 'Bon', 'Excellent'];

    return Row(
      children: [
        ...List.generate(
          4,
          (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(
                color: i < strength ? colors[strength - 1] : Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          strength > 0 ? labels[strength - 1] : '',
          style: TextStyle(
            fontSize: 11,
            color: strength > 0 ? colors[strength - 1] : Colors.transparent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
