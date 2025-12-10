import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eco_diet_v0/main.dart';
import 'package:eco_diet_v0/pages/quiz_page.dart';

void main() {
  testWidgets('Quiz navigation test', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const MyApp());

    // Navigate to the quiz page programmatically
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuizPage(
                      id: '1',
                      title: 'Test Quiz',
                      description: 'Test Description',
                    ),
                  ),
                );
              },
              child: const Text('Open Quiz'),
            ),
          ),
        ),
      ),
    );

    // Tap the button to navigate to quiz page
    await tester.tap(find.text('Open Quiz'));
    await tester.pumpAndSettle();

    // Verify that the quiz page is displayed
    expect(find.text('Test Quiz'), findsOneWidget);
    expect(find.text('Test Description'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
  });

  testWidgets('QuizPage displays correct content', (WidgetTester tester) async {
    // Create the quiz page with test data
    await tester.pumpWidget(
      const MaterialApp(
        home: QuizPage(
          id: 'test-id',
          title: 'Quiz Test',
          description: 'This is a test quiz',
        ),
      ),
    );

    // Verify the content
    expect(find.text('Quiz Test'), findsAtLeastNWidgets(1));
    expect(find.text('This is a test quiz'), findsOneWidget);
    expect(find.text('Retour'), findsOneWidget);
  });

  testWidgets('QuizPage displays default content when no arguments',
      (WidgetTester tester) async {
    // Create the quiz page without arguments
    await tester.pumpWidget(
      const MaterialApp(
        home: QuizPage(),
      ),
    );

    // Verify default content
    expect(find.text('Titre du quiz'), findsOneWidget);
    expect(find.text('Description du quiz...'), findsOneWidget);
  });
}
