import 'dart:math';

import 'package:eco_diet_v0/models/taste_profile.dart';
import 'package:eco_diet_v0/models/user.dart' show UserPreference;
import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/home/recipe_filtering.dart';
import 'package:eco_diet_v0/pages/taste/taste_logic.dart';
import 'package:flutter_test/flutter_test.dart';

RecipeDisplayModel _r(
  String id, {
  String category = 'plat principal',
  String ingredients = 'tomate',
  String diets = '',
  String allergens = '',
  String occasions = '',
  String duration = '20 min',
  bool photo = true,
}) =>
    RecipeDisplayModel(
      id: id,
      title: 'Recette $id',
      category: category,
      ingredients: ingredients,
      diets: diets,
      allergens: allergens,
      occasions: occasions,
      duration: duration,
      imageUrl: photo ? 'https://img/$id.jpg' : null,
    );

void main() {
  group('tasteFeatures', () {
    test('type, régime, durée, occasions et ingrédients hors basiques', () {
      final f = tasteFeatures(_r(
        '1',
        category: 'Dessert',
        ingredients: 'Pommes, Sel, flocons d avoine',
        diets: 'vegetarian',
        occasions: 'Goûter',
        duration: '50 min',
      ));

      expect(f['type:dessert'], 1.0);
      expect(f['regime:vegetarian'], 1.0);
      expect(f['duree:long'], 0.6);
      expect(f['occ:gouter'], 0.5);
      expect(f.keys.where((k) => k.startsWith('ing:')), hasLength(2));
      expect(f.containsKey('ing:sel'), isFalse);
      // Les ingrédients se partagent un poids total de 1,5.
      final ingWeight = f.entries
          .where((e) => e.key.startsWith('ing:'))
          .fold<double>(0, (s, e) => s + e.value);
      expect(ingWeight, closeTo(1.5, 1e-9));
    });

    test('tranches de durée', () {
      expect(durationBucket(15), 'rapide');
      expect(durationBucket(20), 'rapide');
      expect(durationBucket(45), 'moyen');
      expect(durationBucket(46), 'long');
    });
  });

  group('nettoyage des ingrédients', () {
    test('quantités, unités, articles et précisions retirés', () {
      const cases = {
        '"2 cuillères à café d huile dolive"': "Huile d'olive",
        '1 cuillère à soupe d huile de tournesol': 'Huile de tournesol',
        '350 g de poulet coupé en dés': 'Poulet',
        '"1 gousse d ail finement hachées"': "Ail",
        '4 gousses d ail': 'Ail',
        '100 g de pois chiches en conserve': 'Pois chiches',
        '1 boîte de tomates pelées (on garde le jus aussi)': 'Tomates',
        '"5 tranches de pain d épices (si possible maison)"': "Pain d'épices",
        '1 pot de crème fraîche épaisse': 'Crème fraîche épaisse',
        '2 cuillères à soupe de noix pilées': 'Noix',
        'noix': 'Noix',
        'feuille de menthe': 'Menthe',
        '"1 rôti de veau denviron 1 kg"': 'Rôti de veau',
        '10 cl de vinaigre blanc': 'Vinaigre blanc',
        '4 pincées de curry': 'Curry',
        '1 l de bouillon de volaille': 'Bouillon de volaille',
        '4 tomates bien mûres': 'Tomates',
      };
      cases.forEach((raw, expected) {
        expect(ingredientDisplayName(raw), expected, reason: raw);
      });
    });

    test('ligne complète de la fiche : quantité gardée, apostrophes rétablies',
        () {
      expect(ingredientLine('"2 cuillères à café d huile dolive"'),
          "2 cuillères à café d'huile d'olive");
      expect(ingredientLine('350 g de poulet coupé en dés'),
          '350 g de poulet coupé en dés');
      expect(ingredientLine('(fraîches ou en boîte'), '');
      expect(ingredientLine('8 kg'), '');
      expect(ingredientLine('100 g de coulis (maison'), '100 g de coulis (maison)');
    });

    test('lignes de la fiche sans fragments ni doublons', () {
      final r = _r('x', ingredients: '3 tomates, si possible), 3 tomates, sel');
      expect(recipeIngredientLines(r), ['3 tomates', 'Sel']);
    });

    test('listes de tags : quantité, soulignés et accents', () {
      expect(recipeTagList('1 hachoir, 2 casseroles, 1 hachoir'),
          ['Hachoir', 'Casseroles']);
      expect(recipeTagList('fruits_a_coque, oeuf, celeri'),
          ['Fruits à coque', 'Œufs', 'Céleri']);
      expect(recipeTagList(''), isEmpty);
    });

    test('rien d exploitable : chaîne vide', () {
      expect(ingredientDisplayName('8 kg'), '');
      expect(ingredientDisplayName('  '), '');
    });

    test('la clé ignore accents, pluriels et quantités', () {
      expect(ingredientKey('4 gousses d ail'), ingredientKey('1 gousse d ail hachée'));
      expect(ingredientKey('3 tomates'), 'tomate');
      expect(ingredientKey('Crème fraîche'), 'creme fraiche');
      expect(ingredientKey('pois chiches'), 'pois chiche');
      expect(ingredientKey('2 poireaux'), 'poireau');
    });
  });

  group('contraintes', () {
    test('allergies de l inscription traduites en mots-clés français', () {
      final k = allergyKeywords(['nuts', 'eggs', 'Sésame']);
      expect(k, containsAll(['noix', 'amande', 'oeuf', 'sesame']));
    });

    test('lues depuis les préférences du profil', () {
      final c = constraintsFromPreferences([
        UserPreference(label: 'Régime', value: 'vegan'),
        UserPreference(label: 'Allergènes', value: 'lactose,soy'),
      ]);
      expect(c.minDiet, DietLevel.vegan);
      expect(c.blockedKeywords, containsAll(['lait', 'tofu']));
    });
  });

  group('selectSwipeDeck', () {
    test('écarte allergènes et régime incompatible, garde les faux amis', () {
      final source = [
        _r('lait', ingredients: 'lait, riz'),
        _r('coco', ingredients: 'lait de coco, lentilles'),
        _r('poulet', ingredients: 'poulet, riz'),
        _r('legumes', ingredients: 'courgette, riz'),
      ];
      final deck = selectSwipeDeck(
        source,
        constraints: SwipeConstraints(
          blockedKeywords: allergyKeywords(['lactose']),
          minDiet: DietLevel.vegetarian,
        ),
        random: Random(1),
      );
      expect(deck.map((r) => r.id).toSet(), {'coco', 'legumes'});
    });

    test('limite la taille et privilégie la variété', () {
      final source = [
        for (var i = 0; i < 10; i++) _r('plat$i', ingredients: 'riz'),
        _r('dessert', category: 'dessert', ingredients: 'pomme'),
        _r('entree', category: 'entree', ingredients: 'concombre'),
      ];
      final deck = selectSwipeDeck(source, size: 4, random: Random(3));
      expect(deck, hasLength(4));
      expect(deck.map((r) => r.id), containsAll(['dessert', 'entree']));
    });

    test('préfère les recettes avec photo quand il y en a assez', () {
      final source = [
        _r('a'),
        _r('b'),
        _r('sans', photo: false, category: 'dessert'),
      ];
      final deck = selectSwipeDeck(source, size: 2, random: Random(0));
      expect(deck.map((r) => r.id).toSet(), {'a', 'b'});
    });

    test('complète avec des recettes sans photo si besoin', () {
      final deck = selectSwipeDeck(
        [_r('a'), _r('b', photo: false)],
        size: 12,
        random: Random(0),
      );
      expect(deck, hasLength(2));
    });
  });

  group('profil', () {
    final dhal = _r('dhal',
        ingredients: 'lentilles, lait de coco', diets: 'vegan');
    final poulet = _r('poulet',
        ingredients: 'poulet, thym', duration: '75 min', diets: 'carnivore');
    final buddha =
        _r('buddha', ingredients: 'lentilles, quinoa', diets: 'vegan');

    test('les votes donnent des poids normalisés et les coups de cœur', () {
      final p = buildTasteProfile(
        [dhal, poulet],
        const [
          SwipeVote('dhal', SwipeVerdict.superLike),
          SwipeVote('poulet', SwipeVerdict.dislike),
        ],
        now: DateTime(2026, 11, 18),
      );

      expect(p.weights['regime:vegan'], 1.0);
      expect(p.weights['regime:carnivore'], lessThan(0));
      expect(p.weights.values.every((w) => w.abs() <= 1.0), isTrue);
      expect(p.pendingFavoriteIds, {'dhal'});
      expect(p.voteCount, 2);
    });

    test('rankByTaste met en tête les recettes proches des goûts', () {
      final p = buildTasteProfile(
        [dhal, poulet],
        const [
          SwipeVote('dhal', SwipeVerdict.like),
          SwipeVote('poulet', SwipeVerdict.dislike),
        ],
      );
      final ranked = rankByTaste([poulet, buddha], p);
      expect(ranked.first.id, 'buddha');
      expect(tasteScore(buddha, p), greaterThan(tasteScore(poulet, p)));
    });

    test('sans profil, l ordre est conservé', () {
      final list = [poulet, buddha];
      expect(rankByTaste(list, null), same(list));
      expect(rankByTaste(list, const TasteProfile()), same(list));
    });

    test('topTasteLabels : goûts positifs, lisibles et sans doublon', () {
      final p = buildTasteProfile(
        [dhal, poulet],
        const [
          SwipeVote('dhal', SwipeVerdict.like),
          SwipeVote('poulet', SwipeVerdict.dislike),
        ],
      );
      final labels = topTasteLabels(p);
      expect(labels, contains('Végétalien'));
      expect(labels, contains('Lentilles'));
      expect(labels, isNot(contains('Viande')));
    });

    test('libellés : accents rétablis pour les types courants', () {
      expect(tasteFeatureLabel('type:entree'), 'Entrée');
      expect(tasteFeatureLabel('duree:rapide'), 'Vite prêt');
      expect(tasteFeatureLabel('occ:rapide'), 'Vite prêt');
      expect(tasteFeatureLabel('ing:pois chiches'), 'Pois chiches');
    });

    test('aller-retour JSON', () {
      final p = buildTasteProfile(
        [dhal],
        const [SwipeVote('dhal', SwipeVerdict.superLike)],
        now: DateTime(2026, 11, 18),
      );
      final back = TasteProfile.fromJson(p.toJson());
      expect(back.weights, p.weights);
      expect(back.pendingFavoriteIds, {'dhal'});
      expect(back.voteCount, 1);
      expect(back.updatedAt, DateTime(2026, 11, 18));
    });
  });

  test('recipeIngredientSummary : noms seuls, sans doublons ni fragments', () {
    final recipe = RecipeDisplayModel(
      id: 'x',
      title: 'Aïoli',
      category: '',
      ingredients: '"1 gousse d ail finement hachées", '
          '"2 cuillères à soupe d huile dolive", 8 kg, '
          '2 gousses d ail, sel',
      duration: '',
    );
    expect(recipeIngredientSummary(recipe), "Ail, Huile d'olive, Sel");
  });
}
