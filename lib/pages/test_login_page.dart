import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EAD6), // Couleur de fond beige de la maquette
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('lib/assets/logo/EcoDiet-Logo.png', height: 300),
                const SizedBox(height: 10),

                // Sous-titre
                const Text(
                  'Login to your account',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),

                // Champ Email
                TextFormField(
                  decoration: InputDecoration(
                    hintText: 'Email',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 15),

                // Champ Mot de passe
                TextFormField(
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    suffixIcon: TextButton(
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      child: Text(
                        _obscurePassword ? 'Show' : 'Hide',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // Bouton Sign In
                ElevatedButton(
                  onPressed: () {
                    // Logique de connexion
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63), // Couleur rose/magenta
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Sign in', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 30),

                // Séparateur
                const Text('-Or sign in with-'),
                const SizedBox(height: 20),

                // Icônes de réseaux sociaux
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Remplacez par vos propres icônes
                    IconButton(onPressed: () {}, icon: const Icon(Icons.android, size: 30)), // Placeholder Google
                    const SizedBox(width: 20),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.facebook, size: 30)),
                    const SizedBox(width: 20),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.flutter_dash, size: 30)), // Placeholder Twitter
                  ],
                ),
                const SizedBox(height: 40),

                // Lien vers la création de compte
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/create_account');
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}