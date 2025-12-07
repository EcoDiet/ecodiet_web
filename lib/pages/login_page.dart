import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Email')),
            const SizedBox(height: 8),
            const TextField(
                decoration: InputDecoration(labelText: 'Mot de passe'),
                obscureText: true),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Ici appeler l'API / authentification
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Se connecter'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/create-account'),
              child: const Text('Créer un compte'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // BOUTON DEBUG: skip login
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Debug: skip login'),
            ),
          ],
        ),
      ),
    );
  }
}
