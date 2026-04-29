import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/ecodiet_api.dart';
import '../utils/responsive.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

// ── Test profiles (no Supabase needed) ───────────────────────────────────────
const _testProfiles = [
  {'prenom': 'Marie',  'emoji': '👩', 'regime': 'vegetarian',  'allergies': ['lactose', 'gluten'],          'desc': 'Végétarien · lactose + gluten'},
  {'prenom': 'Jean',   'emoji': '👨', 'regime': 'carnivore',   'allergies': ['crustaces', 'mollusques'],    'desc': 'Carnivore · crustacés + mollusques'},
  {'prenom': 'Sophie', 'emoji': '👩', 'regime': 'vegan',       'allergies': ['soja', 'sesame'],             'desc': 'Vegan · soja + sésame'},
  {'prenom': 'Lucas',  'emoji': '👨', 'regime': 'pescetarian', 'allergies': <String>[],                     'desc': 'Pescétarien · aucune allergie'},
  {'prenom': 'Clara',  'emoji': '👩', 'regime': 'carnivore',   'allergies': ['arachide', 'fruits_a_coque'], 'desc': 'Carnivore · arachide + fruits à coque'},
];

class _LoginPageState extends State<LoginPage> {
  final EcoDietApi _api = EcoDietApi();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showTestProfiles = false;
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

  Widget _buildSocialButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDADCE0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3C4043),
                ),
              ),
            ],
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
                  _obscurePassword ? 'Show' : 'Hide',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ),
          ),
        ),
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

        // Boutons réseaux sociaux
        Column(
          children: [
            _buildSocialButton(
              icon: const _GoogleGLogo(size: 20),
              label: 'Continuer avec Google',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildSocialButton(
              icon: const FaIcon(FontAwesomeIcons.facebook, size: 20, color: Color(0xFF1877F2)),
              label: 'Continuer avec Facebook',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            _buildSocialButton(
              icon: const FaIcon(FontAwesomeIcons.apple, size: 20, color: Colors.black),
              label: 'Continuer avec Apple',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Lien vers la création de compte
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Pas encore de compte ? "),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/create_account'),
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

        const SizedBox(height: 24),

        // ── Mode Test ────────────────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() => _showTestProfiles = !_showTestProfiles),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_outlined, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Mode Test — profils prédéfinis',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(width: 6),
                Icon(
                  _showTestProfiles ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ),
        ),

        if (_showTestProfiles) ...[
          const SizedBox(height: 12),
          ...(_testProfiles.map((p) => _buildTestProfileTile(p))),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTestProfileTile(Map<String, dynamic> profile) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          _api.setTestProfile(
            prenom:    profile['prenom'] as String,
            regime:    profile['regime'] as String,
            allergies: List<String>.from(profile['allergies'] as List),
          );
          Navigator.pushReplacementNamed(context, '/home');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF2F6B3F).withOpacity(0.05),
            border: Border.all(color: const Color(0xFF2F6B3F).withOpacity(0.25)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(profile['emoji'] as String, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile['prenom'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF1F2E1F),
                      ),
                    ),
                    Text(
                      profile['desc'] as String,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo Google officiel (SVG) ───────────────────────────────────────────────

class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({this.size = 20});

  // SVG officiel du logo Google G (source : Google Brand Guidelines)
  static const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>
  <path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>
  <path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24c0 3.55.85 6.91 2.34 9.88l7.35-5.7z"/>
  <path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
    );
  }
}
