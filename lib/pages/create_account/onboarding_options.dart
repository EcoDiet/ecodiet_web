import 'package:flutter/material.dart';

// ── Modèles de données des options ──────────────────────────────────────────

class GoalOption {
  final String value;
  final IconData icon;
  final String label;
  final String sub;
  const GoalOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.sub,
  });
}

class DietOption {
  final String value;
  final String label;
  final String emoji;
  const DietOption({
    required this.value,
    required this.label,
    required this.emoji,
  });
}

class AllergyOption {
  final String value;
  final String label;
  final String emoji;
  const AllergyOption({
    required this.value,
    required this.label,
    required this.emoji,
  });
}

const goalOptions = [
  GoalOption(
    value: 'lose_weight',
    icon: Icons.trending_down,
    label: 'Perdre du poids',
    sub: 'Atteindre mon poids idéal',
  ),
  GoalOption(
    value: 'maintain',
    icon: Icons.balance,
    label: 'Maintenir mon poids',
    sub: 'Garder ma forme actuelle',
  ),
  GoalOption(
    value: 'gain_muscle',
    icon: Icons.fitness_center,
    label: 'Prendre de la masse',
    sub: 'Développer ma masse musculaire',
  ),
  GoalOption(
    value: 'eat_healthy',
    icon: Icons.spa_outlined,
    label: 'Manger équilibré',
    sub: 'Adopter de meilleures habitudes',
  ),
  GoalOption(
    value: 'reduce_carbon',
    icon: Icons.eco_outlined,
    label: 'Réduire mon empreinte carbone',
    sub: 'Manger local et durable',
  ),
];

const dietOptions = [
  DietOption(value: 'omnivore', label: 'Omnivore', emoji: '🥩'),
  DietOption(value: 'vegetarian', label: 'Végétarien', emoji: '🥦'),
  DietOption(value: 'vegan', label: 'Végétalien', emoji: '🌱'),
  DietOption(value: 'pescatarian', label: 'Pescétarien', emoji: '🐟'),
  DietOption(value: 'flexitarian', label: 'Flexitarien', emoji: '🥗'),
];

const allergyOptions = [
  AllergyOption(value: 'gluten', label: 'Gluten', emoji: '🌾'),
  AllergyOption(value: 'lactose', label: 'Lactose', emoji: '🥛'),
  AllergyOption(value: 'nuts', label: 'Fruits à coque', emoji: '🌰'),
  AllergyOption(value: 'seafood', label: 'Fruits de mer', emoji: '🦐'),
  AllergyOption(value: 'eggs', label: 'Œufs', emoji: '🥚'),
  AllergyOption(value: 'soy', label: 'Soja', emoji: '🫘'),
  AllergyOption(value: 'peanuts', label: 'Arachides', emoji: '🥜'),
];

const onboardingStepTitles = [
  'Créer un compte',
  'Mon profil',
  'Mon objectif',
  'Mon régime',
  'Mes intolérances',
];
