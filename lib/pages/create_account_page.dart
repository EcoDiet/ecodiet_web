import 'package:flutter/material.dart';

class CreateAccountPage extends StatelessWidget {
  const CreateAccountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
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
                // Implémenter la création de compte
                // Pour l'instant on redirige vers /home
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: const Text('Créer'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                // L'utilisateur a déjà un compte -> renvoyer vers login
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('J\'ai déjà un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
