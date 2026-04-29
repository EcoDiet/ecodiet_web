import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eco_diet_v0/pages/quiz_page.dart';

void main() {
  testWidgets('QuizPage displays title from arguments',
      (WidgetTester tester) async {
    // Create the quiz page with test data
    await tester.pumpWidget(
      const MaterialApp(
        home: QuizPage(
          id: '1',
          title: 'Quiz Test',
          description: 'This is a test quiz',
        ),
      ),
    );

    // Wait for loading to finish
    await tester.pumpAndSettle();

    // Verify the title is displayed in the header
    expect(find.text('Quiz Test'), findsAtLeastNWidgets(1));
  });

  testWidgets('QuizPage shows empty state when no questions',
      (WidgetTester tester) async {
    // Create the quiz page with an ID that has no questions in test env
    await tester.pumpWidget(
      const MaterialApp(
        home: QuizPage(
          id: '999',
          title: 'Quiz Vide',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify empty state message
    expect(find.text('Aucune question disponible'), findsOneWidget);
  });

  testWidgets('QuizPage shows default title when no arguments',
      (WidgetTester tester) async {
    // Create the quiz page without arguments
    await tester.pumpWidget(
      const MaterialApp(
        home: QuizPage(),
      ),
    );

    await tester.pumpAndSettle();

    // When no id is given, loading finishes immediately with empty questions
    // The default title 'Quiz' is shown in the app bar
    expect(find.text('Quiz'), findsAtLeastNWidgets(1));
    expect(find.text('Aucune question disponible'), findsOneWidget);
  });
}
