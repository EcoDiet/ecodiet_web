import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:email_validator/email_validator.dart';
import '../services/ecodiet_api.dart';
import '../utils/responsive.dart';

// ── Modèles de données des options ──────────────────────────────────────────

class _GoalOption {
  final String value;
  final IconData icon;
  final String label;
  final String sub;
  const _GoalOption({
    required this.value,
    required this.icon,
    required this.label,
    required this.sub,
  });
}

class _DietOption {
  final String value;
  final String label;
  final String emoji;
  const _DietOption({
    required this.value,
    required this.label,
    required this.emoji,
  });
}

class _AllergyOption {
  final String value;
  final String label;
  final String emoji;
  const _AllergyOption({
    required this.value,
    required this.label,
    required this.emoji,
  });
}

const _goalOptions = [
  _GoalOption(
    value: 'lose_weight',
    icon: Icons.trending_down,
    label: 'Perdre du poids',
    sub: 'Atteindre mon poids idéal',
  ),
  _GoalOption(
    value: 'maintain',
    icon: Icons.balance,
    label: 'Maintenir mon poids',
    sub: 'Garder ma forme actuelle',
  ),
  _GoalOption(
    value: 'gain_muscle',
    icon: Icons.fitness_center,
    label: 'Prendre de la masse',
    sub: 'Développer ma masse musculaire',
  ),
  _GoalOption(
    value: 'eat_healthy',
    icon: Icons.spa_outlined,
    label: 'Manger équilibré',
    sub: 'Adopter de meilleures habitudes',
  ),
  _GoalOption(
    value: 'reduce_carbon',
    icon: Icons.eco_outlined,
    label: 'Réduire mon empreinte carbone',
    sub: 'Manger local et durable',
  ),
];

const _dietOptions = [
  _DietOption(value: 'omnivore', label: 'Omnivore', emoji: '🥩'),
  _DietOption(value: 'vegetarian', label: 'Végétarien', emoji: '🥦'),
  _DietOption(value: 'vegan', label: 'Végétalien', emoji: '🌱'),
  _DietOption(value: 'pescatarian', label: 'Pescétarien', emoji: '🐟'),
  _DietOption(value: 'flexitarian', label: 'Flexitarien', emoji: '🥗'),
];

const _allergyOptions = [
  _AllergyOption(value: 'gluten', label: 'Gluten', emoji: '🌾'),
  _AllergyOption(value: 'lactose', label: 'Lactose', emoji: '🥛'),
  _AllergyOption(value: 'nuts', label: 'Fruits à coque', emoji: '🌰'),
  _AllergyOption(value: 'seafood', label: 'Fruits de mer', emoji: '🦐'),
  _AllergyOption(value: 'eggs', label: 'Œufs', emoji: '🥚'),
  _AllergyOption(value: 'soy', label: 'Soja', emoji: '🫘'),
  _AllergyOption(value: 'peanuts', label: 'Arachides', emoji: '🥜'),
];

const _stepTitles = [
  'Créer un compte',
  'Mon profil',
  'Mon objectif',
  'Mon régime',
  'Mes intolérances',
];

// ── Page principale ──────────────────────────────────────────────────────────

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({Key? key}) : super(key: key);

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final EcoDietApi _api = EcoDietApi();
  bool _isLoading = false;

  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Étape 1 — Compte
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Étape 2 — Profil
  String? _gender;
  DateTime? _birthDate;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  // Étape 3 — Objectif
  String? _mainGoal;

  // Étape 4 — Régime
  String? _dietType;

  // Étape 5 — Allergies
  final Set<String> _allergies = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _onBackPressed() {
    if (_currentStep == 0) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      _goToStep(_currentStep - 1);
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    final result = await _api.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nom: _lastNameController.text.trim().isNotEmpty
          ? _lastNameController.text.trim()
          : null,
      prenom: _firstNameController.text.trim().isNotEmpty
          ? _firstNameController.text.trim()
          : null,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _showError(result.error ?? 'Erreur lors de la création du compte');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2F6B3F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _validateStep1() {
    if (_firstNameController.text.trim().isEmpty) {
      _showError('Le prénom est requis');
      return;
    }
    if (_lastNameController.text.trim().isEmpty) {
      _showError('Le nom est requis');
      return;
    }
    if (!EmailValidator.validate(_emailController.text.trim())) {
      _showError('Adresse email invalide');
      return;
    }
    if (_passwordController.text.length < 8) {
      _showError('Le mot de passe doit contenir au moins 8 caractères');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }
    _goToStep(1);
  }

  // ── Build principal ─────────────────────────────────────────────────────────

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
              child: _buildBrandingPanel(),
            ),
            // Panneau formulaire droite
            Expanded(
              flex: 4,
              child: _buildFormPanel(desktop: true),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileHeader(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _buildStepPages(desktop: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Panneau branding (desktop gauche) ───────────────────────────────────────

  Widget _buildBrandingPanel() {
    return Container(
      color: const Color(0xFF1F3A24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            child: Image.asset('lib/assets/logo/EcoDiet-Logo-beige.png', height: 200, semanticLabel: 'Logo EcoDiet'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mangez sainement, naturellement.',
            style: TextStyle(color: Color(0xFF8FBF97), fontSize: 16),
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
          const SizedBox(height: 48),
          // Indicateur d'étapes animé
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final isActive = i == _currentStep;
              final isDone = i < _currentStep;
              return Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: isActive ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFF63A96E)
                          : isActive
                              ? const Color(0xFF8FBF97)
                              : const Color(0xFF2F5435),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  if (i < 4) const SizedBox(width: 6),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            'Étape ${_currentStep + 1} sur 5',
            style: const TextStyle(
              color: Color(0xFF8FBF97),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ── Header mobile ───────────────────────────────────────────────────────────

  Widget _buildMobileHeader() {
    return Container(
      color: const Color(0xFFF5ECD9),
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Color(0xFF1F2E1F), size: 18),
                onPressed: _onBackPressed,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Image.asset(
                    'lib/assets/logo/EcoDiet-Logo.png',
                    height: 36,
                    semanticLabel: 'Logo EcoDiet - retour à la connexion',
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / 5,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF2F6B3F)),
                minHeight: 7,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Étape ${_currentStep + 1} sur 5',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Panneau formulaire (desktop droite) ─────────────────────────────────────

  Widget _buildFormPanel({required bool desktop}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          children: [
            // Header avec back + titre + barre
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Color(0xFF1F2E1F), size: 18),
                        onPressed: _onBackPressed,
                      ),
                      Expanded(
                        child: Text(
                          _stepTitles[_currentStep],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2E1F),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: (_currentStep + 1) / 5,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF2F6B3F)),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Étape ${_currentStep + 1} sur 5',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: _buildStepPages(desktop: desktop),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStepPages({required bool desktop}) {
    return [
      _buildStep1(),
      _buildStep2(),
      _buildStep3(),
      _buildStep4(),
      _buildStep5(),
    ];
  }

  // ── Helpers UI ──────────────────────────────────────────────────────────────

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2E1F),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint,
      {Widget? suffixIcon, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Color(0xFF63A96E), width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffixIcon,
      prefixIcon: prefixIcon,
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed != null
              ? const Color(0xFF2F6B3F)
              : Colors.grey[300],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Étape 1 : Compte ────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Champs nom / prénom
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Prénom'),
                    TextField(
                      controller: _firstNameController,
                      decoration: _fieldDecoration('Jean'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Nom'),
                    TextField(
                      controller: _lastNameController,
                      decoration: _fieldDecoration('Dupont'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildLabel('Email'),
          TextField(
            controller: _emailController,
            decoration: _fieldDecoration(
              'jean@exemple.com',
              prefixIcon: Icon(Icons.mail_outline,
                  size: 18, color: Colors.grey[400]),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          _buildLabel('Mot de passe'),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _fieldDecoration(
              '8 caractères minimum',
              prefixIcon: Icon(Icons.lock_outline,
                  size: 18, color: Colors.grey[400]),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          _buildLabel('Confirmer le mot de passe'),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: _fieldDecoration(
              'Répétez le mot de passe',
              prefixIcon: Icon(Icons.lock_outline,
                  size: 18, color: Colors.grey[400]),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ),
            ),
          ),

          // Indicateur force du mot de passe
          const SizedBox(height: 8),
          _buildPasswordStrength(),
          const SizedBox(height: 24),

          _buildPrimaryButton('Continuer', _validateStep1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Déjà un compte ? ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              InkWell(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Se connecter',
                    style: TextStyle(
                      color: Color(0xFF2F6B3F),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPasswordStrength() {
    return _PasswordStrengthIndicator(controller: _passwordController);
  }

  // ── Étape 2 : Profil ────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ces informations nous permettent de personnaliser vos recettes.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          _buildLabel('Genre'),
          Row(
            children: [
              _buildGenderChip('Homme', Icons.male_outlined, 'male'),
              const SizedBox(width: 8),
              _buildGenderChip('Femme', Icons.female_outlined, 'female'),
              const SizedBox(width: 8),
              _buildGenderChip('Autre', Icons.person_outline, 'other'),
            ],
          ),
          const SizedBox(height: 16),

          _buildLabel('Date de naissance'),
          Semantics(
            label: _birthDate != null
                ? 'Date de naissance : ${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                : 'Date de naissance, sélectionner une date',
            button: true,
            child: InkWell(
              onTap: _pickBirthDate,
              borderRadius: BorderRadius.circular(8),
              child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 10),
                  Text(
                    _birthDate != null
                        ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                        : 'JJ/MM/AAAA',
                    style: TextStyle(
                      fontSize: 14,
                      color: _birthDate != null
                          ? const Color(0xFF1F2E1F)
                          : Colors.grey[400],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.keyboard_arrow_down,
                      color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Taille (cm)'),
                    TextField(
                      controller: _heightController,
                      decoration: _fieldDecoration('Ex : 170'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Poids actuel (kg)'),
                    TextField(
                      controller: _weightController,
                      decoration: _fieldDecoration('Ex : 68'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildLabel('Poids cible (kg)'),
          TextField(
            controller: _targetWeightController,
            decoration: _fieldDecoration('Ex : 65'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 28),

          _buildPrimaryButton('Continuer', () => _goToStep(2)),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, IconData icon, String value) {
    final selected = _gender == value;
    return Expanded(
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _gender = value),
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF2F6B3F)
                : Colors.white,
            border: Border.all(
              color: selected
                  ? const Color(0xFF2F6B3F)
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color:
                      selected ? Colors.white : const Color(0xFF1F2E1F)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF1F2E1F),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2F6B3F),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  // ── Étape 3 : Objectif ──────────────────────────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quel est votre objectif principal ?',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ..._goalOptions.map(_buildGoalCard),
          const SizedBox(height: 8),
          _buildPrimaryButton(
            'Continuer',
            _mainGoal != null ? () => _goToStep(3) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(_GoalOption option) {
    final selected = _mainGoal == option.value;
    return Semantics(
      label: '${option.label} : ${option.sub}',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() => _mainGoal = option.value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2F6B3F).withOpacity(0.06)
              : Colors.white,
          border: Border.all(
            color: selected
                ? const Color(0xFF2F6B3F)
                : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2F6B3F).withOpacity(0.12)
                    : const Color(0xFF8FBF97).withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                option.icon,
                size: 22,
                color: selected
                    ? const Color(0xFF2F6B3F)
                    : const Color(0xFF63A96E),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2E1F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.sub,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF2F6B3F), size: 22),
          ],
        ),
      ),
    ),
  );
  }

  // ── Étape 4 : Régime ────────────────────────────────────────────────────────

  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quel est votre type de régime alimentaire ?',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _dietOptions.map(_buildDietChip).toList(),
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            'Continuer',
            _dietType != null ? () => _goToStep(4) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDietChip(_DietOption option) {
    final selected = _dietType == option.value;
    return Semantics(
      label: option.label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() => _dietType = option.value),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2F6B3F)
              : Colors.white,
          border: Border.all(
            color: selected
                ? const Color(0xFF2F6B3F)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    selected ? Colors.white : const Color(0xFF1F2E1F),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  // ── Étape 5 : Allergies ─────────────────────────────────────────────────────

  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avez-vous des allergies ou intolérances ?',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Sélectionnez tout ce qui s\'applique.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children:
                _allergyOptions.map(_buildAllergyChip).toList(),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _finishOnboarding,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F6B3F),
                      side: const BorderSide(
                          color: Color(0xFF2F6B3F)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Passer',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPrimaryButton(
                    'Terminer', _isLoading ? null : _finishOnboarding),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllergyChip(_AllergyOption option) {
    final selected = _allergies.contains(option.value);
    return Semantics(
      label: option.label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => setState(() {
          if (selected) {
            _allergies.remove(option.value);
          } else {
            _allergies.add(option.value);
          }
        }),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2F6B3F)
              : Colors.white,
          border: Border.all(
            color: selected
                ? const Color(0xFF2F6B3F)
                : Colors.grey.shade300,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              option.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color:
                    selected ? Colors.white : const Color(0xFF1F2E1F),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _PasswordStrengthIndicator extends StatefulWidget {
  final TextEditingController controller;

  const _PasswordStrengthIndicator({required this.controller});

  @override
  State<_PasswordStrengthIndicator> createState() =>
      _PasswordStrengthIndicatorState();
}

class _PasswordStrengthIndicatorState
    extends State<_PasswordStrengthIndicator> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pwd = widget.controller.text;
    if (pwd.isEmpty) return const SizedBox.shrink();

    int strength = 0;
    if (pwd.length >= 8) strength++;
    if (pwd.contains(RegExp(r'[A-Z]'))) strength++;
    if (pwd.contains(RegExp(r'[0-9]'))) strength++;
    if (pwd.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) strength++;

    final colors = [
      Colors.red[400]!,
      Colors.orange[400]!,
      const Color(0xFF63A96E),
      const Color(0xFF2F6B3F),
    ];
    final labels = ['Faible', 'Moyen', 'Bon', 'Excellent'];

    return Row(
      children: [
        ...List.generate(
          4,
          (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(
                color: i < strength ? colors[strength - 1] : Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          strength > 0 ? labels[strength - 1] : '',
          style: TextStyle(
            fontSize: 11,
            color: strength > 0 ? colors[strength - 1] : Colors.transparent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
