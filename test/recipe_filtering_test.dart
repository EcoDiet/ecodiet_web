import 'package:eco_diet_v0/models/user.dart' show UserPreference;
import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/home/recipe_filtering.dart';
import 'package:flutter_test/flutter_test.dart';

RecipeDisplayModel _recipe({
  String id = '1',
  String title = 'Recette',
  String category = 'plat',
  String ingredients = '',
  String utensils = '',
  String allergens = '',
  String duration = '',
}) {
  return RecipeDisplayModel(
    id: id,
    title: title,
    category: category,
    ingredients: ingredients,
    utensils: utensils,
    allergens: allergens,
    duration: duration,
  );
}

void main() {
  group('normalisation', () {
    test('normalizeAscii retire les accents et ligatures', () {
      expect(normalizeAscii('Bœuf crème brûlée'), 'Boeuf creme brulee');
    });

    test('ingredientFilterLabel canonise les quantités et pluriels', () {
      expect(ingredientFilterLabel('200 g de tomates'), 'Tomate');
      expect(ingredientFilterLabel('2 œufs'), 'Oeuf');
      expect(ingredientFilterLabel('1 sachet de levure'), 'Levure');
    });

    test('parseDurationMinutes lit le premier nombre', () {
      expect(parseDurationMinutes('25 min'), 25);
      expect(parseDurationMinutes(''), isNull);
    });
  });

  group('recherche et filtres', () {
    final curry = _recipe(
      title: 'Curry de lentilles',
      ingredients: 'lentilles, curry, lait de coco',
      utensils: 'Casserole',
      duration: '30 min',
    );
    final poulet = _recipe(
      id: '2',
      title: 'Poulet rôti',
      ingredients: 'poulet, beurre',
      utensils: 'Four',
      allergens: 'Lactose',
      duration: '60 min',
    );

    test('matchesSearch cherche dans titre et ingrédients', () {
      expect(matchesSearch(curry, 'lentilles'), isTrue);
      expect(matchesSearch(curry, 'poulet'), isFalse);
      expect(matchesSearch(curry, ''), isTrue);
    });

    test('filtre ingrédient, ustensile et durée max', () {
      final filters = RecipeFilters.empty()
        ..ingredients.add('Lentilles')
        ..utensils.add('casserole')
        ..maxTimeMinutes = 45;
      expect(matchesFilters(curry, filters), isTrue);
      expect(matchesFilters(poulet, filters), isFalse);
    });

    test('un allergène sélectionné exclut la recette', () {
      final filters = RecipeFilters.empty()..allergens.add('Lactose');
      expect(matchesFilters(poulet, filters), isFalse);
      expect(matchesFilters(curry, filters), isTrue);
    });

    test('régime végétarien exclut la viande', () {
      final filters = RecipeFilters.empty()..diets.add('Végétarien');
      expect(matchesFilters(curry, filters), isTrue);
      expect(matchesFilters(poulet, filters), isFalse);
    });

    test('sortRecipes trie par temps croissant', () {
      final sorted = sortRecipes([poulet, curry], RecipeSortMode.tempsAsc);
      expect(sorted.map((r) => r.id), ['1', '2']);
    });
  });

  group('recommandations', () {
    final salade = _recipe(id: 'a', title: 'Salade', ingredients: 'tomate');
    final steak = _recipe(id: 'b', title: 'Steak frites', ingredients: 'boeuf');

    test('le régime du profil écarte les recettes incompatibles', () {
      final result = buildRecommendedRecipes(
        [salade, steak],
        [UserPreference(label: 'Régime', value: 'Végétarien')],
      );
      expect(result.map((r) => r.id), ['a']);
    });

    test('retourne la source si aucune recette ne correspond', () {
      final result = buildRecommendedRecipes(
        [steak],
        [UserPreference(label: 'Régime', value: 'Végan')],
      );
      expect(result.map((r) => r.id), ['b']);
    });
  });
}
