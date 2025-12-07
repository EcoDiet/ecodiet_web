import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final recipes = [
      {
        'title': 'Tarte aux légumes',
        'description': 'Tarte légère avec pâte complète.'
      },
      {
        'title': 'Porridge aux fruits',
        'description': 'Petit-déjeuner énergétique.'
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
            const SizedBox(height: 12),
            const Text('Nom d\'utilisateur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('email@example.com'),
            const SizedBox(height: 16),
            const Text('Favoris',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            // Favoris (exemples)
            SizedBox(
              height: 80,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: recipes
                    .map((r) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            label: Text(r['title']!),
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/recipe',
                              arguments: {
                                'title': r['title'],
                                'description': r['description']
                              },
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Dossiers',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Mes recettes rapides'),
              onTap: () {},
            ),
            const SizedBox(height: 8),
            const Text('Préférences',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(title: const Text('Végétarien')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Déconnexion ou actions de profil
                Navigator.pop(context);
              },
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
  }
}
