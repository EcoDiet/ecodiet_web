import 'package:eco_diet_v0/models/taste_profile.dart';
import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/taste/taste_logic.dart';
import 'package:eco_diet_v0/pages/taste/taste_recommendation.dart';
import 'package:flutter_test/flutter_test.dart';

RecipeDisplayModel _r(String id, String ingredients,
        {String category = 'plat principal', String diets = 'vegetarian'}) =>
    RecipeDisplayModel(
      id: id,
      title: 'Recette $id',
      category: category,
      ingredients: ingredients,
      diets: diets,
      duration: '30 min',
    );

void main() {
  final dhal = _r('dhal', '200 g de lentilles, 1 boîte de lait de coco, 1 oignon');
  final soupe = _r('soupe', '150 g de lentilles, 2 carottes, 1 oignon');
  final curry = _r('curry', '1 boîte de pois chiches, 1 boîte de lait de coco');
  final gratin = _r('gratin', '200 g de fromage, 1 kg de pommes de terre, 1 oignon');
  final salade = _r('salade', '1 concombre, 2 tomates');
  final catalog = [dhal, soupe, curry, gratin, salade];
  final byId = {for (final r in catalog) r.id: r};

  group('ingredientPreferences', () {
    test('part pondérée des recettes aimées, moins celle des rejetées', () {
      final prefs = ingredientPreferences(const [
        SwipeVote('dhal', SwipeVerdict.superLike), // poids 2
        SwipeVote('soupe', SwipeVerdict.like), // poids 1
        SwipeVote('curry', SwipeVerdict.like), // poids 1
        SwipeVote('gratin', SwipeVerdict.dislike),
      ], byId);
      final p = {for (final x in prefs) x.key: x};

      // Lentilles : dhal (2) + soupe (1) sur 4 → 75 %.
      expect(p['lentille']!.percent, 75);
      // Lait de coco : dhal (2) + curry (1) sur 4 → 75 %.
      expect(p['lait de coco']!.percent, 75);
      // Oignon : aimé à 75 % mais présent dans la seule recette rejetée.
      expect(p['oignon']!.likedShare, closeTo(0.75, 1e-9));
      expect(p['oignon']!.dislikedShare, 1.0);
      expect(p['oignon']!.score, closeTo(-0.25, 1e-9));
      expect(p['fromage']!.score, -1.0);

      // Tri : affinité nette décroissante.
      expect(prefs.first.score, greaterThanOrEqualTo(prefs.last.score));
      expect(prefs.last.key, anyOf('fromage', 'pomme de terre'));
    });

    test('libellés lisibles et nombre de recettes', () {
      final prefs = ingredientPreferences(
          const [SwipeVote('dhal', SwipeVerdict.like)], byId);
      final coco = prefs.firstWhere((p) => p.key == 'lait de coco');
      expect(coco.label, 'Lait de coco');
      expect(coco.likedCount, 1);
      expect(coco.percent, 100);
    });

    test('votes inconnus du catalogue ignorés', () {
      expect(
          ingredientPreferences(
              const [SwipeVote('absente', SwipeVerdict.like)], byId),
          isEmpty);
    });

    test('topIngredients : trié par pourcentage affiché', () {
      final top = topIngredients(ingredientPreferences(const [
        SwipeVote('dhal', SwipeVerdict.like),
        SwipeVote('soupe', SwipeVerdict.like),
        SwipeVote('curry', SwipeVerdict.like),
        SwipeVote('salade', SwipeVerdict.dislike),
      ], byId));
      final percents = top.map((p) => p.percent).toList();
      expect(percents, [...percents]..sort((a, b) => b.compareTo(a)));
    });

    test('topIngredients ne garde que les affinités positives', () {
      final top = topIngredients(ingredientPreferences(const [
        SwipeVote('dhal', SwipeVerdict.like),
        SwipeVote('gratin', SwipeVerdict.dislike),
      ], byId));
      expect(top.map((p) => p.key), containsAll(['lentille', 'lait de coco']));
      expect(top.map((p) => p.key), isNot(contains('oignon')));
      expect(top.map((p) => p.key), isNot(contains('fromage')));
    });
  });

  group('rankRecommendations', () {
    const profile = TasteProfile(votes: [
      SwipeVote('dhal', SwipeVerdict.superLike),
      SwipeVote('gratin', SwipeVerdict.dislike),
    ]);

    test('cible les recettes riches en ingrédients aimés', () {
      final ranked = rankRecommendations(
        [salade, gratin, curry, soupe],
        profile,
        catalog: catalog,
      );
      // Curry (lait de coco) et soupe (lentilles) avant salade ; gratin,
      // rejeté, en dernier.
      expect(ranked.recipes.take(2).map((r) => r.id).toSet(),
          {'curry', 'soupe'});
      expect(ranked.recipes.last.id, 'gratin');
    });

    test('donne la raison de chaque recommandation', () {
      final ranked = rankRecommendations([curry, salade], profile,
          catalog: catalog);
      expect(recommendationReason(ranked.reasons['curry']), 'Lait de coco');
      expect(ranked.reasons['salade'], isNull);
      expect(ranked.preferences, isNotEmpty);
    });

    test('mélange : 1 sur 3 déjà aimée, nouvelles autour, rejetées à la fin',
        () {
      final ranked = rankRecommendations(
        [salade, gratin, curry, soupe, dhal],
        profile, // dhal aimée (coup de cœur), gratin rejetée
        catalog: catalog,
      );
      final ids = ranked.recipes.map((r) => r.id).toList();
      expect(ids[1], 'dhal'); // position réservée à une recette déjà aimée
      expect(ids.last, 'gratin');
      expect(ids.toSet(), {'salade', 'gratin', 'curry', 'soupe', 'dhal'});
      expect(ranked.alreadyLiked, {'dhal'});
      // Les nouvelles restent triées par goûts : curry et soupe avant salade.
      final fresh = ids.where((id) => id != 'dhal' && id != 'gratin').toList();
      expect(fresh.last, 'salade');
    });

    test('mixRecommendations : alternance et complément', () {
      expect(mixRecommendations(['n1', 'n2', 'n3', 'n4'], ['a1', 'a2']),
          ['n1', 'a1', 'n2', 'n3', 'a2', 'n4']);
      expect(mixRecommendations(['n1'], ['a1', 'a2', 'a3']),
          ['n1', 'a1', 'a2', 'a3']);
      expect(mixRecommendations(<String>[], ['a1']), ['a1']);
      expect(mixRecommendations(['n1', 'n2'], <String>[]), ['n1', 'n2']);
    });

    test('sans profil : ordre conservé', () {
      final list = [salade, curry];
      expect(rankRecommendations(list, null, catalog: catalog).recipes,
          same(list));
      expect(
          rankRecommendations(list, const TasteProfile(), catalog: catalog)
              .recipes,
          same(list));
    });

    test('ancien profil sans swipes bruts : repli sur les poids', () {
      const old = TasteProfile(weights: {'type:dessert': 1.0});
      final dessert = _r('d', 'pomme', category: 'dessert');
      expect(
          rankRecommendations([salade, dessert], old, catalog: catalog)
              .recipes
              .first
              .id,
          'd');
    });
  });

  group('swipes stockés', () {
    test('mergeVotes : un vote par recette, le plus récent gagne', () {
      final t0 = DateTime.utc(2026, 11, 1);
      final t1 = DateTime.utc(2026, 11, 2);
      final merged = mergeVotes(
        [
          SwipeVote('a', SwipeVerdict.like, votedAt: t1),
          SwipeVote('b', SwipeVerdict.like, votedAt: t0),
        ],
        [
          SwipeVote('a', SwipeVerdict.dislike, votedAt: t0),
          SwipeVote('b', SwipeVerdict.dislike, votedAt: t1),
          SwipeVote('c', SwipeVerdict.superLike, votedAt: t0),
        ],
      );
      final m = {for (final v in merged) v.recipeId: v.verdict};
      expect(m, {
        'a': SwipeVerdict.like,
        'b': SwipeVerdict.dislike,
        'c': SwipeVerdict.superLike,
      });
    });

    test('format base : verdict, poids et date UTC', () {
      final json = SwipeVote('r1', SwipeVerdict.superLike,
              votedAt: DateTime.utc(2026, 11, 18, 10))
          .toJson();
      expect(json, {
        'recette_id': 'r1',
        'verdict': 'super_like',
        'poids': 2,
        'voted_at': '2026-11-18T10:00:00.000Z',
      });
      final back = SwipeVote.fromJson(json)!;
      expect(back.verdict, SwipeVerdict.superLike);
      expect(SwipeVote.fromJson({'recette_id': 'x', 'verdict': '??'}), isNull);
    });

    test('profil : votes horodatés, à synchroniser, aller-retour JSON', () {
      final p = buildTasteProfile([dhal], const [
        SwipeVote('dhal', SwipeVerdict.like),
      ], now: DateTime.utc(2026, 11, 18));
      expect(p.votes.single.votedAt, DateTime.utc(2026, 11, 18));
      expect(p.needsSync, isTrue);

      final synced = p.copyWith(syncedAt: DateTime.utc(2026, 11, 18, 1));
      expect(synced.needsSync, isFalse);
      final back = TasteProfile.fromJson(synced.toJson());
      expect(back.votes.single.recipeId, 'dhal');
      expect(back.needsSync, isFalse);
    });
  });
}
