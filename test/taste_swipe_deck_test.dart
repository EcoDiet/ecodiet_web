import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/taste/swipe_card.dart';
import 'package:eco_diet_v0/pages/taste/taste_logic.dart';
import 'package:eco_diet_v0/pages/taste/taste_swipe_deck.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

RecipeDisplayModel _r(String id) => RecipeDisplayModel(
      id: id,
      title: 'Recette $id',
      category: 'plat principal',
      ingredients: 'tomate, riz',
      duration: '20 min',
    );

Future<List<SwipeVote>?> _pump(
  WidgetTester tester,
  List<RecipeDisplayModel> deck,
  void Function(List<SwipeVote>) onFinished,
) async {
  tester.view.physicalSize = const Size(420, 860);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TasteSwipeDeck(deck: deck, onFinished: onFinished),
    ),
  ));
  await tester.pump();
  return null;
}

void main() {
  testWidgets('boutons, annulation et fin de pile', (tester) async {
    List<SwipeVote>? result;
    await _pump(tester, [_r('a'), _r('b'), _r('c')], (v) => result = v);

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Recette a'), findsOneWidget);

    await tester.tap(find.byTooltip('Ça me tente'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Pas pour moi'));
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    // Annuler revient sur la carte b.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Coup de cœur, ajouter aux favoris'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pas pour moi'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.map((v) => '${v.recipeId}:${v.verdict.name}'), [
      'a:like',
      'b:superLike',
      'c:dislike',
    ]);
  });

  testWidgets('glisser à droite ou à gauche vote ; un petit geste revient',
      (tester) async {
    List<SwipeVote>? result;
    await _pump(tester, [_r('a'), _r('b')], (v) => result = v);

    // Petit déplacement : la carte revient, aucun vote.
    await tester.drag(find.byType(SwipeRecipeCard).last, const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.drag(find.byType(SwipeRecipeCard).last, const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.drag(find.byType(SwipeRecipeCard).last, const Offset(-250, 0));
    await tester.pumpAndSettle();

    expect(result!.map((v) => v.verdict),
        [SwipeVerdict.like, SwipeVerdict.dislike]);
  });

  testWidgets('fiche détaillée : ouverture, contenu, fermeture et vote',
      (tester) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final recipe = RecipeDisplayModel(
      id: 'dhal',
      title: 'Dhal de lentilles',
      category: 'plat principal',
      ingredients: '"200 g de lentilles corail", 1 boîte de lait de coco, 1 cuillère à café de curry',
      utensils: '1 casserole, 1 planche',
      allergens: '',
      occasions: 'quotidien',
      diets: 'vegan',
      duration: '30 min',
    );
    final loaded = <String>[];
    List<SwipeVote>? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TasteSwipeDeck(
          deck: [recipe, _r('b')],
          onFinished: (v) => result = v,
          loadSteps: (id) async {
            loaded.add(id);
            return ['Rincer les lentilles.', 'Cuire 20 min dans le lait de coco.'];
          },
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Voir la recette'));
    await tester.pumpAndSettle();

    expect(loaded, ['dhal']);
    expect(find.text('200 g de lentilles corail'), findsOneWidget);
    expect(find.text('1 boîte de lait de coco'), findsOneWidget);
    expect(find.text('Quotidien'), findsOneWidget);
    // Le bas de la fiche n'est construit qu'une fois déroulé.
    final sheet = find.descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('Rincer les lentilles.'), 120,
        scrollable: sheet);
    await tester.scrollUntilVisible(
        find.text('Aucun allergène majeur signalé.'), 120,
        scrollable: sheet);
    expect(find.text('Casserole'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Échap revient à la carte.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Rincer les lentilles.'), findsNothing);
    expect(find.text('Voir la recette'), findsOneWidget);

    // Toucher la carte rouvre la fiche ; on vote depuis la fiche.
    await tester.tap(find.text('Dhal de lentilles'));
    await tester.pumpAndSettle();
    expect(find.text('Réduire'), findsOneWidget);
    await tester.tap(find.byTooltip('Ça me tente'));
    await tester.pumpAndSettle();
    expect(find.text('Réduire'), findsNothing);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Pas pour moi'));
    await tester.pumpAndSettle();
    expect(result!.map((v) => '${v.recipeId}:${v.verdict.name}'),
        ['dhal:like', 'b:dislike']);
  });

  testWidgets('fiche détaillée sans étapes : message clair', (tester) async {
    tester.view.physicalSize = const Size(420, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TasteSwipeDeck(
          deck: [_r('a')],
          onFinished: (_) {},
          loadSteps: (_) async => throw Exception('hors ligne'),
        ),
      ),
    ));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Les étapes ne sont pas disponibles pour cette recette.'),
        findsOneWidget);
  });

  testWidgets('petit écran (360 × 640) : pas de débordement', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: TasteSwipeDeck(deck: [_r('a'), _r('b')], onFinished: (_) {}),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Recette a'), findsOneWidget);
  });

  testWidgets('les flèches du clavier votent', (tester) async {
    List<SwipeVote>? result;
    await _pump(tester, [_r('a'), _r('b')], (v) => result = v);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(result!.map((v) => v.verdict),
        [SwipeVerdict.superLike, SwipeVerdict.like]);
  });
}
