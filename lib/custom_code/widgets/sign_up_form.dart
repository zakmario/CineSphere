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

import 'dart:async';

import '/custom_code/actions/auth_service.dart';
import '/custom_code/actions/supabase_service.dart';

/// Écran d'inscription : pseudo (unicité vérifiée pendant la saisie), e-mail,
/// mot de passe et confirmation. Si Supabase exige une confirmation, une
/// seconde étape demande le code reçu par e-mail.
class SignUpForm extends StatefulWidget {
  const SignUpForm({
    super.key,
    this.width,
    this.height,
    this.onSignedUp,
    this.onGoToLogin,
  });

  final double? width;
  final double? height;
  final Future Function()? onSignedUp;
  final Future Function()? onGoToLogin;

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

enum _UsernameStatus { idle, checking, available, taken }

class _SignUpFormState extends State<SignUpForm> {
  static const _usernameDebounce = Duration(milliseconds: 500);

  final _formKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  Timer? _debounce;
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  String? _usernameError;
  bool _loading = false;
  bool _awaitingCode = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _usernameStatus = _UsernameStatus.idle;
      _usernameError = null;
    });
    if (validateUsername(value) != null) {
      return;
    }
    _debounce = Timer(_usernameDebounce, () => _checkUsername(value));
  }

  Future<void> _checkUsername(String value) async {
    setState(() => _usernameStatus = _UsernameStatus.checking);
    final error = await AuthService.instance.checkUsername(value);
    // Le pseudo a pu changer pendant la requête.
    if (!mounted || _username.text != value) {
      return;
    }
    setState(() {
      _usernameStatus =
          error == null ? _UsernameStatus.available : _UsernameStatus.taken;
      _usernameError = error;
    });
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

  Future<void> _signUp() async {
    // L'inscription vérifie déjà le pseudo : inutile de le refaire ensuite.
    _debounce?.cancel();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await _run(() async {
      final outcome = await AuthService.instance.signUp(
        username: _username.text,
        email: _email.text,
        password: _password.text,
      );
      if (outcome == SignUpOutcome.signedIn) {
        await widget.onSignedUp?.call();
      } else if (mounted) {
        setState(() => _awaitingCode = true);
      }
    });
  }

  Future<void> _confirm() async {
    if (!_codeFormKey.currentState!.validate()) {
      return;
    }
    await _run(() async {
      await AuthService.instance
          .confirmSignUp(email: _email.text, code: _code.text);
      await widget.onSignedUp?.call();
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
      _awaitingCode ? _buildCodeStep() : _buildForm(context);

  Widget _buildMessages() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) AuthMessageBanner(message: _error!),
          if (_info != null) AuthMessageBanner(message: _info!, isError: false),
        ],
      );

  Widget? _usernameSuffix(FlutterFlowTheme theme) => switch (_usernameStatus) {
        _UsernameStatus.idle => null,
        _UsernameStatus.checking => const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        _UsernameStatus.available => Semantics(
            label: 'Pseudo disponible',
            child: Icon(Icons.check_circle, color: theme.success),
          ),
        _UsernameStatus.taken => Semantics(
            label: 'Pseudo déjà utilisé',
            child: Icon(Icons.cancel, color: theme.error),
          ),
      };

  Widget _buildForm(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return AuthFormShell(
      width: widget.width,
      height: widget.height,
      title: 'Créer un compte',
      subtitle: 'Favoris, listes, calendrier des sorties et rappels : '
          'tout commence ici.',
      onBack: _loading ? null : () => widget.onGoToLogin?.call(),
      children: [
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: _username,
                  label: 'Pseudo',
                  icon: Icons.person_outline,
                  autofillHints: const [AutofillHints.newUsername],
                  maxLength: 24,
                  helperText: _usernameStatus == _UsernameStatus.available
                      ? 'Ce pseudo est disponible.'
                      : '3 à 24 caractères : lettres, chiffres, _ . -',
                  suffix: _usernameSuffix(theme),
                  onChanged: _onUsernameChanged,
                  validator: (value) =>
                      validateUsername(value) ?? _usernameError,
                ),
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
                  onSubmitted: (_) => _signUp(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildMessages(),
        AuthPrimaryButton(
          label: 'Créer mon compte',
          loading: _loading,
          onPressed: _signUp,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text('Déjà membre ?',
                  style: theme.bodyMedium.copyWith(color: theme.secondaryText)),
            ),
            TextButton(
              onPressed: _loading ? null : () => widget.onGoToLogin?.call(),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCodeStep() => AuthFormShell(
        width: widget.width,
        height: widget.height,
        icon: Icons.mark_email_unread_outlined,
        title: 'Vérifiez vos e-mails',
        subtitle: 'Nous avons envoyé un code à ${_email.text.trim()}. '
            'Saisissez-le pour activer votre compte.',
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
            label: 'Activer mon compte',
            loading: _loading,
            onPressed: _confirm,
          ),
          const SizedBox(height: 8),
          ResendCodeButton(onResend: _resend),
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _awaitingCode = false;
                      _error = null;
                      _info = null;
                    }),
            child: const Text('Modifier l\'adresse e-mail'),
          ),
        ],
      );
}
