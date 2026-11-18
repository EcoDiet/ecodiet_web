import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/home/quiz_card.dart';
import 'package:eco_diet_v0/pages/home/recipe_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  final quiz = Quiz(id: '1', title: 'Les légumes', description: 'Saison');

  for (final desktop in [true, false]) {
    testWidgets('QuizCard affiche titre et bouton (desktop: $desktop)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(SizedBox(
            width: 340, child: QuizCard(quiz: quiz, desktop: desktop))),
      );
      expect(find.text('Les légumes'), findsOneWidget);
      expect(find.text('Jouer'), findsOneWidget);
    });
  }

  testWidgets('RecipeCard affiche la recette et déclenche le favori',
      (tester) async {
    var toggled = 0;
    final recipe = RecipeDisplayModel(
      id: 'r1',
      title: 'Curry',
      category: 'plat principal',
      ingredients: 'lentilles',
      duration: '30 min',
    );
    await tester.pumpWidget(_wrap(SizedBox(
      width: 220,
      height: 220,
      child: RecipeCard(recipe: recipe, onToggleFavorite: () => toggled++),
    )));
    expect(find.text('Curry'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    expect(toggled, 1);
  });
}
