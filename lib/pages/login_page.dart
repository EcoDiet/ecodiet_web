import 'package:flutter/material.dart';
import '../utils/responsive.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    if (desktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0EAD6),
        body: Row(
          children: [
            // Panneau branding gauche
            Expanded(
              flex: 5,
              child: Container(
                color: const Color(0xFF1F3A24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/assets/logo/EcoDiet-Logo.png',
                      height: 180,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'EcoDiet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Mangez sainement, naturellement.',
                      style: TextStyle(
                        color: Color(0xFF8FBF97),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF2F5435)),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Des recettes saines pour la planete',
                        style: TextStyle(color: Color(0xFF8FBF97), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Panneau formulaire droite
            Expanded(
              flex: 4,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: _buildForm(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0EAD6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: _buildForm(context),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final desktop = isDesktop(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!desktop) ...[
          Center(child: Image.asset('lib/assets/logo/EcoDiet-Logo.png', height: 200)),
          const SizedBox(height: 10),
        ],

        Text(
          desktop ? 'Connexion' : 'Login to your account',
          style: TextStyle(
            fontSize: desktop ? 28 : 16,
            fontWeight: desktop ? FontWeight.bold : FontWeight.normal,
            color: desktop ? const Color(0xFF1F2E1F) : Colors.black54,
          ),
        ),
        if (desktop) ...[
          const SizedBox(height: 4),
          const Text(
            'Bienvenue sur EcoDiet',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 28),

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
            Navigator.pushReplacementNamed(context, '/home');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F6B3F),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Se connecter', style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 24),

        // Séparateur
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),

        // Icônes de réseaux sociaux
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.android, size: 30)),
            const SizedBox(width: 20),
            IconButton(onPressed: () {}, icon: const Icon(Icons.facebook, size: 30)),
            const SizedBox(width: 20),
            IconButton(onPressed: () {}, icon: const Icon(Icons.flutter_dash, size: 30)),
          ],
        ),
        const SizedBox(height: 32),

        // Lien vers la création de compte
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Pas encore de compte ? "),
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/create_account');
              },
              child: const Text(
                'Créer un compte',
                style: TextStyle(
                  color: Color(0xFF2F6B3F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}