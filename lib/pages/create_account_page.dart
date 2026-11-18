import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:email_validator/email_validator.dart';
import '../services/ecodiet_api.dart';
import '../utils/responsive.dart';
import 'create_account/onboarding_options.dart';
import 'create_account/onboarding_widgets.dart';


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
  final _pseudoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  Timer? _pseudoDebounce;
  Timer? _emailDebounce;
  bool _isCheckingPseudo = false;
  bool? _isPseudoAvailable;
  String? _pseudoCheckMessage;
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable;
  String? _emailCheckMessage;

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
    _pseudoController.addListener(_onPseudoChanged);
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _pseudoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _pseudoDebounce?.cancel();
    _emailDebounce?.cancel();
    super.dispose();
  }

  void _onPseudoChanged() {
    _pseudoDebounce?.cancel();
    final raw = _pseudoController.text.trim();
    if (raw.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isCheckingPseudo = false;
        _isPseudoAvailable = null;
        _pseudoCheckMessage = null;
      });
      return;
    }

    _pseudoDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() {
        _isCheckingPseudo = true;
        _pseudoCheckMessage = null;
      });
      final available = await _api.isPseudoAvailable(raw);
      if (!mounted) return;
      setState(() {
        _isCheckingPseudo = false;
        _isPseudoAvailable = available;
        _pseudoCheckMessage =
            available ? 'Pseudo disponible' : 'Pseudo deja utilise';
      });
    });
  }

  void _onEmailChanged() {
    _emailDebounce?.cancel();
    final raw = _emailController.text.trim();
    if (raw.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = false;
        _isEmailAvailable = null;
        _emailCheckMessage = null;
      });
      return;
    }

    _emailDebounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = true;
        _emailCheckMessage = null;
      });
      final available = await _api.isEmailAvailable(raw);
      if (!mounted) return;
      setState(() {
        _isCheckingEmail = false;
        _isEmailAvailable = available;
        _emailCheckMessage =
            available ? 'Email disponible' : 'Email deja utilise';
      });
    });
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
    final height = _heightController.text.trim().isNotEmpty
        ? double.tryParse(_heightController.text.trim())
        : null;
    final weight = _weightController.text.trim().isNotEmpty
        ? double.tryParse(_weightController.text.trim())
        : null;
    final targetWeight = _targetWeightController.text.trim().isNotEmpty
        ? double.tryParse(_targetWeightController.text.trim())
        : null;
    final profile = <String, dynamic>{
      if (_dietType != null) 'regime': _dietType,
      if (_mainGoal != null) 'objectif': _mainGoal,
      if (_gender != null) 'genre': _gender,
      if (_birthDate != null)
        'date_naissance':
            '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}',
      if (height != null) 'taille_cm': height,
      if (weight != null) 'poids_kg': weight,
      if (targetWeight != null) 'poids_cible_kg': targetWeight,
      if (_allergies.isNotEmpty) 'allergies': _allergies.join(','),
    };
    final result = await _api.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nom: _lastNameController.text.trim().isNotEmpty
          ? _lastNameController.text.trim()
          : null,
      prenom: _firstNameController.text.trim().isNotEmpty
          ? _firstNameController.text.trim()
          : null,
      pseudo: _pseudoController.text.trim().isNotEmpty
          ? _pseudoController.text.trim()
          : null,
      profile: profile,
    );
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pushReplacementNamed(context, '/login');
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

  Future<void> _validateStep1() async {
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
    if (_isCheckingEmail) {
      _showError('Verification de l email en cours...');
      return;
    }
    if (_isEmailAvailable == null) {
      final available = await _api.isEmailAvailable(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _isEmailAvailable = available;
        _emailCheckMessage = available ? 'Email disponible' : 'Email deja utilise';
      });
    }
    if (_isEmailAvailable == false) {
      _showError('Cet email existe deja');
      return;
    }
    if (_pseudoController.text.trim().isEmpty) {
      _showError('Le pseudo est requis');
      return;
    }
    if (_isCheckingPseudo) {
      _showError('Verification du pseudo en cours...');
      return;
    }
    if (_isPseudoAvailable == null) {
      final available =
          await _api.isPseudoAvailable(_pseudoController.text.trim());
      if (!mounted) return;
      setState(() {
        _isPseudoAvailable = available;
        _pseudoCheckMessage =
            available ? 'Pseudo disponible' : 'Pseudo deja utilise';
      });
    }
    if (_isPseudoAvailable == false) {
      _showError('Ce pseudo existe deja');
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

  Widget _genderChip(String label, IconData icon, String value) {
    return GenderChip(
      label: label,
      icon: icon,
      selected: _gender == value,
      onTap: () => setState(() => _gender = value),
    );
  }

  void _toggleAllergy(String value) {
    setState(() {
      if (!_allergies.remove(value)) _allergies.add(value);
    });
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
              child: OnboardingBrandingPanel(
                currentStep: _currentStep,
                onLogoTap: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
              ),
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
                          onboardingStepTitles[_currentStep],
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
                    const OnboardingLabel(text: 'Prénom'),
                    TextField(
                      controller: _firstNameController,
                      decoration: onboardingFieldDecoration('Jean'),
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
                    const OnboardingLabel(text: 'Nom'),
                    TextField(
                      controller: _lastNameController,
                      decoration: onboardingFieldDecoration('Dupont'),
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const OnboardingLabel(text: 'Email'),
          TextField(
            controller: _emailController,
            decoration: onboardingFieldDecoration(
              'jean@exemple.com',
              prefixIcon: Icon(Icons.mail_outline,
                  size: 18, color: Colors.grey[400]),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          if (_isCheckingEmail || _emailCheckMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (_isCheckingEmail)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_isCheckingEmail) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isCheckingEmail
                        ? 'Verification de l email...'
                        : (_emailCheckMessage ?? ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: (_isEmailAvailable ?? false)
                          ? const Color(0xFF2F6B3F)
                          : const Color(0xFFB3261E),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          const OnboardingLabel(text: 'Pseudo'),
          TextField(
            controller: _pseudoController,
            decoration: onboardingFieldDecoration(
              'Ex : jean_du_94',
              prefixIcon: Icon(Icons.alternate_email,
                  size: 18, color: Colors.grey[400]),
            ),
          ),
          if (_isCheckingPseudo || _pseudoCheckMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (_isCheckingPseudo)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_isCheckingPseudo) const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _isCheckingPseudo
                        ? 'Verification du pseudo...'
                        : (_pseudoCheckMessage ?? ''),
                    style: TextStyle(
                      fontSize: 12,
                      color: (_isPseudoAvailable ?? false)
                          ? const Color(0xFF2F6B3F)
                          : const Color(0xFFB3261E),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          const OnboardingLabel(text: 'Mot de passe'),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: onboardingFieldDecoration(
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

          const OnboardingLabel(text: 'Confirmer le mot de passe'),
          TextField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            decoration: onboardingFieldDecoration(
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

          OnboardingPrimaryButton(label: 'Continuer', onPressed: () => _validateStep1()),
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
    return PasswordStrengthIndicator(controller: _passwordController);
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

          const OnboardingLabel(text: 'Genre'),
          Row(
            children: [
              _genderChip('Homme', Icons.male_outlined, 'male'),
              const SizedBox(width: 8),
              _genderChip('Femme', Icons.female_outlined, 'female'),
              const SizedBox(width: 8),
              _genderChip('Autre', Icons.person_outline, 'other'),
            ],
          ),
          const SizedBox(height: 16),

          const OnboardingLabel(text: 'Date de naissance'),
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
                    const OnboardingLabel(text: 'Taille (cm)'),
                    TextField(
                      controller: _heightController,
                      decoration: onboardingFieldDecoration('Ex : 170'),
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
                    const OnboardingLabel(text: 'Poids actuel (kg)'),
                    TextField(
                      controller: _weightController,
                      decoration: onboardingFieldDecoration('Ex : 68'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          const OnboardingLabel(text: 'Poids cible (kg)'),
          TextField(
            controller: _targetWeightController,
            decoration: onboardingFieldDecoration('Ex : 65'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 28),

          OnboardingPrimaryButton(label: 'Continuer', onPressed: () => _goToStep(2)),
        ],
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
          ...goalOptions.map(
            (option) => GoalCard(
              option: option,
              selected: _mainGoal == option.value,
              onTap: () => setState(() => _mainGoal = option.value),
            ),
          ),
          const SizedBox(height: 8),
          OnboardingPrimaryButton(
            label: 'Continuer',
            onPressed: _mainGoal != null ? () => _goToStep(3) : null,
          ),
        ],
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
                dietOptions
                .map(
                  (option) => DietChip(
                    option: option,
                    selected: _dietType == option.value,
                    onTap: () => setState(() => _dietType = option.value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 32),
          OnboardingPrimaryButton(
            label: 'Continuer',
            onPressed: _dietType != null ? () => _goToStep(4) : null,
          ),
        ],
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
                allergyOptions
                .map(
                  (option) => AllergyChip(
                    option: option,
                    selected: _allergies.contains(option.value),
                    onTap: () => _toggleAllergy(option.value),
                  ),
                )
                .toList(),
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
                child: OnboardingPrimaryButton(
                    label: 'Terminer', onPressed: _isLoading ? null : _finishOnboarding),
              ),
            ],
          ),
        ],
      ),
    );
  }

}
