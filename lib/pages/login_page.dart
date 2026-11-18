import 'package:flutter/material.dart';
import '../services/ecodiet_api.dart';
import '../utils/responsive.dart';
import 'login/password_reset_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final EcoDietApi _api = EcoDietApi();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _api.login(email: email, password: password);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    if (desktop) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5ECD9),
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
                      'lib/assets/logo/EcoDiet-Logo-beige.png',
                      height: 200,
                      semanticLabel: 'Logo EcoDiet',
                    ),
                    const SizedBox(height: 20),
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
                        'Des recettes saines pour la planète',
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
      backgroundColor: const Color(0xFFF5ECD9),
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
          Center(child: Image.asset('lib/assets/logo/EcoDiet-Logo.png', height: 200, semanticLabel: 'Logo EcoDiet')),
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

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Text(_errorMessage!,
                style: TextStyle(color: Colors.red[700], fontSize: 13)),
          ),
        ],

        // Champ Email
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email',
            hintText: 'votre@email.com',
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
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            hintText: 'Votre mot de passe',
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
            suffixIcon: Tooltip(
              message: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                child: Text(
                  _obscurePassword ? 'Afficher' : 'Masquer',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ),
        ),
        if (_api.usesAuthService)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showPasswordResetDialog(
                context,
                initialEmail: _emailController.text.trim(),
              ),
              child: const Text(
                'Mot de passe oublié ?',
                style: TextStyle(color: Color(0xFF2F6B3F)),
              ),
            ),
          )
        else
          const SizedBox(height: 25),

        // Bouton Se connecter
        ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F6B3F),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Se connecter',
                  style: TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 32),

        // Lien vers la création de compte
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text("Pas encore de compte ? "),
            InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/create_account');
              },
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Créer un compte',
                  style: TextStyle(
                    color: Color(0xFF2F6B3F),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
