import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recipes = [
      {
        'title': 'Salade de quinoa',
        'description': 'Quinoa, légumes frais et vinaigrette légère.'
      },
      {
        'title': 'Soupe de lentilles',
        'description': 'Riche en protéines et très réconfortante.'
      },
      {
        'title': 'Smoothie vert',
        'description': 'Épinards, banane et lait végétal.'
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bienvenue sur EcoDiet',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/profile'),
              child: const Text('Voir mon profil'),
            ),
            const SizedBox(height: 12),
            const Text('Recettes recommandées',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final r = recipes[index];
                  return Card(
                    child: ListTile(
                      title: Text(r['title']!),
                      subtitle: Text(r['description']!),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/recipe',
                        arguments: {
                          'title': r['title'],
                          'description': r['description']
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
