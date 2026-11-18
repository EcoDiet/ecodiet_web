import 'package:flutter/material.dart';

import '../../services/ecodiet_api.dart';

/// Page ouverte depuis le lien reçu par e-mail (`#/reset_password?token=…`).
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, required this.token, this.api});

  final String token;
  final EcoDietApi? api;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < 8) {
      setState(() => _error = 'Au moins 8 caractères.');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = 'Les deux mots de passe sont différents.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await (widget.api ?? EcoDietApi())
        .confirmPasswordReset(widget.token, password);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _done = error == null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2F6B3F);
    final missingToken = widget.token.isEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nouveau mot de passe',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                if (missingToken)
                  const Text(
                    'Ce lien est incomplet. Refais une demande depuis l\'écran '
                    'de connexion.',
                  )
                else if (_done)
                  const Text(
                    'Mot de passe enregistré. Tu peux te connecter.',
                  )
                else ...[
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Nouveau mot de passe'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le mot de passe',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _saving ? 'Enregistrement…' : 'Enregistrer',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text(
                    'Retour à la connexion',
                    style: TextStyle(color: green),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
