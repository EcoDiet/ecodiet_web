import 'package:flutter/material.dart';

import '../../services/ecodiet_api.dart';

/// « Mot de passe oublié ? » : demande d'un lien de réinitialisation.
Future<void> showPasswordResetDialog(
  BuildContext context, {
  String initialEmail = '',
  EcoDietApi? api,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PasswordResetDialog(
      initialEmail: initialEmail,
      api: api ?? EcoDietApi(),
    ),
  );
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.initialEmail, required this.api});

  final String initialEmail;
  final EcoDietApi api;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Saisis une adresse e-mail valide.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.api.requestPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = error == null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mot de passe oublié'),
      content: SizedBox(
        width: 400,
        child: _sent
            ? const Text(
                'Si un compte existe pour cette adresse, un e-mail vient de '
                'partir avec un lien valable une heure. Pense à vérifier les '
                'courriers indésirables.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indique ton adresse : tu recevras un lien pour choisir '
                    'un nouveau mot de passe.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ],
              ),
      ),
      actions: _sent
          ? [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6B3F),
                ),
                child: const Text('OK'),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6B3F),
                ),
                child: Text(_sending ? 'Envoi…' : 'Envoyer le lien'),
              ),
            ],
    );
  }
}
