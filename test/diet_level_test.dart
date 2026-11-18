import 'package:eco_diet_v0/models/user.dart' show UserPreference;
import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/home/recipe_filtering.dart';
import 'package:flutter_test/flutter_test.dart';

RecipeDisplayModel _r(String id,
        {String diets = '', String ingredients = ''}) =>
    RecipeDisplayModel(
      id: id,
      title: 'Recette $id',
      category: 'plat principal',
      ingredients: ingredients,
      diets: diets,
      duration: '',
    );

bool _diet(RecipeDisplayModel r, String filter) =>
    matchesFilters(r, RecipeFilters.empty()..diets.add(filter));

void main() {
  group('dietLevelFromLabel', () {
    test('reconnaît les libellés anglais et français', () {
      expect(dietLevelFromLabel('vegan'), DietLevel.vegan);
      expect(dietLevelFromLabel('Végétalien'), DietLevel.vegan);
      expect(dietLevelFromLabel('vegetarian'), DietLevel.vegetarian);
      expect(dietLevelFromLabel('Végétarien'), DietLevel.vegetarian);
      expect(dietLevelFromLabel('pescetarian'), DietLevel.pescetarian);
      expect(dietLevelFromLabel('carnivore'), DietLevel.carnivore);
      expect(dietLevelFromLabel(''), isNull);
      expect(dietLevelFromLabel('sans gluten'), isNull);
    });
  });

  group('le régime des données prime sur les mots-clés', () {
    // Ingrédients que les mots-clés ne reconnaissent pas comme animaux.
    final andouillette =
        _r('a', diets: 'carnivore', ingredients: '4 andouillettes, moutarde');
    final raie = _r('b', diets: 'pescetarian', ingredients: '4 raies, câpres');
    final cocoSoup =
        _r('c', diets: 'vegan', ingredients: 'lentilles, lait de coco');

    test('filtre végétarien', () {
      expect(_diet(andouillette, 'Végétarien'), isFalse);
      expect(_diet(raie, 'Végétarien'), isFalse);
      expect(_diet(cocoSoup, 'Végétarien'), isTrue);
    });

    test('filtre végan', () {
      expect(_diet(cocoSoup, 'Végan'), isTrue);
      expect(_diet(raie, 'Végan'), isFalse);
    });

    test('filtre pescétarien : poisson, végétarien et végan acceptés', () {
      expect(_diet(raie, 'pescetarian'), isTrue);
      expect(_diet(cocoSoup, 'pescetarian'), isTrue);
      expect(_diet(andouillette, 'pescetarian'), isFalse);
    });

    test('filtre carnivore : correspondance sur le libellé', () {
      expect(_diet(andouillette, 'carnivore'), isTrue);
      expect(_diet(raie, 'carnivore'), isFalse);
    });
  });

  test('sans régime fourni, les mots-clés servent de secours', () {
    expect(recipeDietLevel(_r('d', ingredients: 'poulet, riz')),
        DietLevel.carnivore);
    expect(recipeDietLevel(_r('e', ingredients: 'saumon, riz')),
        DietLevel.pescetarian);
    expect(recipeDietLevel(_r('f', ingredients: 'oeufs, farine')),
        DietLevel.vegetarian);
    expect(
        recipeDietLevel(_r('g', ingredients: 'riz, tomates')), DietLevel.vegan);
  });

  group('recommandations selon le régime du profil', () {
    final steak = _r('s', diets: 'carnivore');
    final fish = _r('p', diets: 'pescetarian');
    final omelette = _r('o', diets: 'vegetarian');
    final salad = _r('v', diets: 'vegan');
    final all = [steak, fish, omelette, salad];

    List<String> recos(String regime) => buildRecommendedRecipes(
          all,
          [UserPreference(label: 'Régime', value: regime)],
        ).map((r) => r.id).toList();

    test('végétarien', () => expect(recos('vegetarian'), ['o', 'v']));
    test('pescétarien', () => expect(recos('pescatarian'), ['p', 'o', 'v']));
    test('végan : le poisson est aussi exclu', () {
      expect(recos('vegan'), ['v']);
    });
    test('omnivore : aucune contrainte', () {
      expect(recos('omnivore'), ['s', 'p', 'o', 'v']);
    });
  });
}
