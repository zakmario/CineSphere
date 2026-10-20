// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import '/custom_code/actions/index.dart'; // Imports custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/auth_service.dart';
import '/custom_code/actions/supabase_service.dart';

/// Écran « Mot de passe oublié » : envoie un code de récupération par e-mail,
/// puis appelle [onCodeSent] avec l'adresse (à passer à la page
/// NouveauMotDePasse).
class ForgotPasswordForm extends StatefulWidget {
  const ForgotPasswordForm({
    super.key,
    this.width,
    this.height,
    this.onCodeSent,
    this.onBackToLogin,
  });

  final double? width;
  final double? height;
  final Future Function(String email)? onCodeSent;
  final Future Function()? onBackToLogin;

  @override
  State<ForgotPasswordForm> createState() => _ForgotPasswordFormState();
}

class _ForgotPasswordFormState extends State<ForgotPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.sendPasswordResetCode(_email.text);
      await widget.onCodeSent?.call(_email.text.trim());
    } on CineFailure catch (failure) {
      if (mounted) {
        setState(() => _error = failure.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AuthFormShell(
        width: widget.width,
        height: widget.height,
        icon: Icons.lock_reset_rounded,
        title: 'Mot de passe oublié',
        subtitle: 'Saisissez l\'adresse de votre compte : nous vous enverrons '
            'un code pour choisir un nouveau mot de passe.',
        onBack: _loading ? null : () => widget.onBackToLogin?.call(),
        children: [
          Form(
            key: _formKey,
            child: AuthTextField(
              controller: _email,
              label: 'Adresse e-mail',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: validateEmail,
              onSubmitted: (_) => _send(),
            ),
          ),
          if (_error != null) AuthMessageBanner(message: _error!),
          AuthPrimaryButton(
            label: 'Envoyer le code',
            loading: _loading,
            onPressed: _send,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading ? null : () => widget.onBackToLogin?.call(),
            child: const Text('Retour à la connexion'),
          ),
        ],
      );
}
