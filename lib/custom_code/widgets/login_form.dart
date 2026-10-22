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
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

/// Écran de connexion par e-mail et mot de passe (Supabase Auth).
///
/// Si l'adresse n'a pas encore été confirmée, propose de saisir le code reçu
/// par e-mail sans quitter l'écran.
class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    this.width,
    this.height,
    this.onSignedIn,
    this.onCreateAccount,
    this.onForgotPassword,
  });

  final double? width;
  final double? height;
  final Future Function()? onSignedIn;
  final Future Function()? onCreateAccount;
  final Future Function()? onForgotPassword;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _loading = false;
  bool _awaitingCode = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
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

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _run(() async {
      try {
        await AuthService.instance
            .signIn(email: _email.text, password: _password.text);
      } on CineFailure catch (failure) {
        final cause = failure.cause;
        if (cause is supa.AuthException &&
            authErrorCode(cause) == 'email_not_confirmed') {
          await AuthService.instance.resendSignUpCode(_email.text);
          if (!mounted) {
            return;
          }
          setState(() {
            _awaitingCode = true;
            _info = 'Un nouveau code a été envoyé à ${_email.text.trim()}.';
          });
          return;
        }
        rethrow;
      }
      await widget.onSignedIn?.call();
    });
  }

  Future<void> _confirm() async {
    if (!_codeFormKey.currentState!.validate()) {
      return;
    }
    await _run(() async {
      await AuthService.instance
          .confirmSignUp(email: _email.text, code: _code.text);
      await widget.onSignedIn?.call();
    });
  }

  Future<String?> _resend() async {
    try {
      await AuthService.instance.resendSignUpCode(_email.text);
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
  Widget build(BuildContext context) =>
      _awaitingCode ? _buildCodeStep(context) : _buildLogin(context);

  Widget _buildMessages() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) AuthMessageBanner(message: _error!),
          if (_info != null) AuthMessageBanner(message: _info!, isError: false),
        ],
      );

  Widget _buildLogin(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AuthFormShell(
      width: widget.width,
      height: widget.height,
      title: 'Bon retour sur CinéSphère',
      subtitle: 'Tout le cinéma et les séries, dans une seule sphère.',
      children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _email,
                  label: 'Adresse e-mail',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: validateEmail,
                ),
                AuthTextField(
                  controller: _password,
                  label: 'Mot de passe',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Saisissez votre mot de passe.'
                      : null,
                  onSubmitted: (_) => _signIn(),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading ? null : () => widget.onForgotPassword?.call(),
            child: const Text('Mot de passe oublié ?'),
          ),
        ),
        const SizedBox(height: 8),
        _buildMessages(),
        AuthPrimaryButton(
          label: 'Se connecter',
          loading: _loading,
          onPressed: _signIn,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text('Pas encore de compte ?',
                  style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
            ),
            TextButton(
              onPressed: _loading ? null : () => widget.onCreateAccount?.call(),
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeStep(BuildContext context) => AuthFormShell(
        width: widget.width,
        height: widget.height,
        icon: Icons.mark_email_unread_outlined,
        title: 'Confirmez votre adresse',
        subtitle: 'Saisissez le code envoyé à ${_email.text.trim()} pour '
            'activer votre compte.',
        onBack: _loading
            ? null
            : () => setState(() {
                  _awaitingCode = false;
                  _error = null;
                  _info = null;
                }),
        children: [
          Form(
            key: _codeFormKey,
            child: AuthCodeField(
              controller: _code,
              onSubmitted: (_) => _confirm(),
            ),
          ),
          _buildMessages(),
          AuthPrimaryButton(
            label: 'Valider le code',
            loading: _loading,
            onPressed: _confirm,
          ),
          const SizedBox(height: 8),
          ResendCodeButton(onResend: _resend),
        ],
      );
}
