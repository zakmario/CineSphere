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

/// Écran « Nouveau mot de passe ».
///
/// - Avec [email] (venant de « Mot de passe oublié ») : code reçu par e-mail
///   + nouveau mot de passe. La vérification du code connecte le membre.
/// - Sans [email] et avec une session (lien de récupération, ou changement
///   depuis les paramètres) : seulement le nouveau mot de passe.
class NewPasswordForm extends StatefulWidget {
  const NewPasswordForm({
    super.key,
    this.width,
    this.height,
    this.email,
    this.onPasswordUpdated,
    this.onBack,
  });

  final double? width;
  final double? height;
  final String? email;
  final Future Function()? onPasswordUpdated;
  final Future Function()? onBack;

  @override
  State<NewPasswordForm> createState() => _NewPasswordFormState();
}

class _NewPasswordFormState extends State<NewPasswordForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  late bool _needsCode;
  bool _codeVerified = false;
  bool _loading = false;
  String? _error;
  String? _info;

  bool get _hasEmailParam => (widget.email ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _email.text = widget.email?.trim() ?? '';
    _needsCode = _hasEmailParam || !AuthService.instance.hasSession;
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      // Après une vérification réussie, le code n'est plus valable : on ne
      // renvoie que le mot de passe (par exemple après « same_password »).
      final withCode = _needsCode && !_codeVerified;
      await AuthService.instance.resetPassword(
        email: withCode ? _email.text : null,
        code: withCode ? _code.text : null,
        newPassword: _password.text,
      );
      await widget.onPasswordUpdated?.call();
    } on CineFailure catch (failure) {
      if (mounted) {
        setState(() {
          _error = failure.message;
          _codeVerified = _needsCode && AuthService.instance.hasSession;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<String?> _resend() async {
    try {
      await AuthService.instance.sendPasswordResetCode(_email.text);
      if (mounted) {
        setState(() {
          _error = null;
          _info = 'Code renvoyé à ${_email.text.trim()}.';
        });
      }
      return null;
    } on CineFailure catch (failure) {
      if (mounted) {
        setState(() => _error = failure.message);
      }
      return failure.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCode = _needsCode && !_codeVerified;
    return AuthFormShell(
      width: widget.width,
      height: widget.height,
      icon: Icons.password_rounded,
      title: 'Nouveau mot de passe',
      subtitle: showCode
          ? (_hasEmailParam
              ? 'Saisissez le code envoyé à ${_email.text} puis choisissez '
                  'votre nouveau mot de passe.'
              : 'Saisissez votre adresse, le code reçu par e-mail et votre '
                  'nouveau mot de passe.')
          : 'Choisissez votre nouveau mot de passe.',
      onBack: _loading || widget.onBack == null
          ? null
          : () => widget.onBack!.call(),
      children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showCode && !_hasEmailParam)
                  AuthTextField(
                    controller: _email,
                    label: 'Adresse e-mail',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: validateEmail,
                  ),
                if (showCode) AuthCodeField(controller: _code),
                AuthTextField(
                  controller: _password,
                  label: 'Nouveau mot de passe',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  helperText: 'Au moins $kMinPasswordLength caractères.',
                  validator: validatePassword,
                ),
                AuthTextField(
                  controller: _confirmation,
                  label: 'Confirmer le mot de passe',
                  icon: Icons.lock_reset_outlined,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) =>
                      validatePasswordConfirmation(_password.text, value),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null) AuthMessageBanner(message: _error!),
        if (_info != null) AuthMessageBanner(message: _info!, isError: false),
        AuthPrimaryButton(
          label: 'Enregistrer le mot de passe',
          loading: _loading,
          onPressed: _submit,
        ),
        if (showCode) ...[
          const SizedBox(height: 8),
          ResendCodeButton(
            onResend: _resend,
            startCoolingDown: _hasEmailParam,
          ),
        ],
      ],
    );
  }
}
