// Automatic FlutterFlow imports
import '/backend/supabase/supabase.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:developer' as developer;

import '/custom_code/actions/supabase_service.dart';

/// Vrai si un membre est connecté (session Supabase active).
/// Action FlutterFlow, utilisable dans un *Conditional* ou un *On Page Load*.
Future<bool> authService() async => AuthService.instance.hasSession;

/// Longueur minimale du mot de passe (cahier des charges, section 6.2).
const int kMinPasswordLength = 8;

/// Délai avant de pouvoir renvoyer un code par e-mail.
const Duration kResendCooldown = Duration(seconds: 60);

// Validation des champs ------------------------------------------------------

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

/// Renvoie un message d'erreur en français, ou null si l'e-mail est valide.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Saisissez votre adresse e-mail.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Adresse e-mail invalide.';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Saisissez un mot de passe.';
  }
  if (password.length < kMinPasswordLength) {
    return 'Le mot de passe doit contenir au moins '
        '$kMinPasswordLength caractères.';
  }
  return null;
}

String? validatePasswordConfirmation(String? password, String? confirmation) {
  if ((confirmation ?? '').isEmpty) {
    return 'Confirmez le mot de passe.';
  }
  if (password != confirmation) {
    return 'Les mots de passe ne correspondent pas.';
  }
  return null;
}

/// Code à usage unique envoyé par e-mail (6 à 8 chiffres selon Supabase).
String? validateOtpCode(String? value) {
  final code = value?.trim() ?? '';
  if (!RegExp(r'^\d{6,8}$').hasMatch(code)) {
    return 'Saisissez le code reçu par e-mail.';
  }
  return null;
}

// Erreurs --------------------------------------------------------------------

const _authMessages = <String, (CineFailureKind, String)>{
  'invalid_credentials': (
    CineFailureKind.unauthenticated,
    'E-mail ou mot de passe incorrect.'
  ),
  'email_not_confirmed': (
    CineFailureKind.unauthenticated,
    'Confirmez votre adresse e-mail avant de vous connecter.'
  ),
  'user_already_exists': (
    CineFailureKind.conflict,
    'Un compte existe déjà avec cette adresse e-mail.'
  ),
  'email_exists': (
    CineFailureKind.conflict,
    'Un compte existe déjà avec cette adresse e-mail.'
  ),
  'weak_password': (
    CineFailureKind.invalid,
    'Mot de passe trop faible : choisissez-en un plus long.'
  ),
  'same_password': (
    CineFailureKind.invalid,
    'Le nouveau mot de passe doit être différent de l\'ancien.'
  ),
  'otp_expired': (CineFailureKind.invalid, 'Code incorrect ou expiré.'),
  'email_address_invalid': (
    CineFailureKind.invalid,
    'Adresse e-mail invalide.'
  ),
  'validation_failed': (CineFailureKind.invalid, 'Données invalides.'),
  'over_email_send_rate_limit': (
    CineFailureKind.forbidden,
    'Trop d\'e-mails envoyés. Patientez quelques minutes avant de réessayer.'
  ),
  'over_request_rate_limit': (
    CineFailureKind.forbidden,
    'Trop de tentatives. Patientez quelques minutes avant de réessayer.'
  ),
  'signup_disabled': (
    CineFailureKind.forbidden,
    'Les inscriptions sont momentanément fermées.'
  ),
  'user_banned': (CineFailureKind.forbidden, 'Ce compte a été suspendu.'),
  'user_not_found': (CineFailureKind.notFound, 'Aucun compte avec cet e-mail.'),
  'session_not_found': (
    CineFailureKind.unauthenticated,
    'Votre session a expiré. Reconnectez-vous.'
  ),
  'session_expired': (
    CineFailureKind.unauthenticated,
    'Votre session a expiré. Reconnectez-vous.'
  ),
};

/// Anciens serveurs GoTrue : pas de `code`, seulement un message en anglais.
const _legacyMessages = <String, String>{
  'invalid login credentials': 'invalid_credentials',
  'email not confirmed': 'email_not_confirmed',
  'user already registered': 'user_already_exists',
  'token has expired or is invalid': 'otp_expired',
  'should be different from the old password': 'same_password',
  'for security purposes, you can only request this': 'over_request_rate_limit',
  'email rate limit exceeded': 'over_email_send_rate_limit',
};

/// Code d'erreur GoTrue de [error] (`invalid_credentials`…), ou null.
String? authErrorCode(AuthException error) {
  if (error is AuthWeakPasswordException) {
    return 'weak_password';
  }
  final code = error.code;
  if (code != null && code.isNotEmpty) {
    return code;
  }
  final message = error.message.toLowerCase();
  for (final entry in _legacyMessages.entries) {
    if (message.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

/// Traduit une erreur Supabase Auth en [CineFailure] (message en français).
CineFailure mapAuthError(Object error) {
  if (error is CineFailure) {
    return error;
  }
  if (error is AuthRetryableFetchException) {
    return CineFailure(CineFailureKind.network,
        'Pas de connexion Internet. Réessayez plus tard.', error);
  }
  if (error is AuthSessionMissingException) {
    return CineFailure(CineFailureKind.unauthenticated,
        'Votre session a expiré. Reconnectez-vous.', error);
  }
  if (error is AuthException) {
    final known = _authMessages[authErrorCode(error)];
    if (known != null) {
      return CineFailure(known.$1, known.$2, error);
    }
    if (error.statusCode == '429') {
      return CineFailure(CineFailureKind.forbidden,
          'Trop de tentatives. Patientez quelques minutes.', error);
    }
    return CineFailure(CineFailureKind.unknown,
        'L\'authentification a échoué. Réessayez.', error);
  }
  return mapSupabaseError(error);
}

// Service --------------------------------------------------------------------

/// Résultat d'une inscription.
enum SignUpOutcome {
  /// Compte créé et membre connecté.
  signedIn,

  /// Compte créé : il faut saisir le code reçu par e-mail.
  confirmationRequired,
}

/// Opérations Supabase Auth utilisées par l'application (remplaçable en test).
abstract class AuthGateway {
  bool get hasSession;

  Future<void> signIn(String email, String password);

  Future<SignUpOutcome> signUp(String email, String password,
      {required String username});

  Future<bool> isUsernameAvailable(String username);

  Future<void> verifySignUpCode(String email, String code);

  Future<void> resendSignUpCode(String email);

  Future<void> sendPasswordResetCode(String email);

  Future<void> verifyRecoveryCode(String email, String code);

  Future<void> updatePassword(String newPassword);

  Future<void> signOut();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  bool get hasSession => _auth.currentSession != null;

  @override
  Future<void> signIn(String email, String password) =>
      _auth.signInWithPassword(email: email, password: password);

  @override
  Future<SignUpOutcome> signUp(String email, String password,
      {required String username}) async {
    // Le pseudo est lu par le trigger `on_auth_user_created`.
    final response = await _auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    if (response.session != null) {
      return SignUpOutcome.signedIn;
    }
    // Quand la confirmation est activée, Supabase ne signale pas un e-mail
    // déjà inscrit : il renvoie un utilisateur sans identité.
    if (response.user?.identities?.isEmpty ?? false) {
      throw const AuthException('User already registered',
          code: 'user_already_exists');
    }
    return SignUpOutcome.confirmationRequired;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final available = await _client
        .rpc('username_available', params: {'candidate': username});
    return available == true;
  }

  @override
  Future<void> verifySignUpCode(String email, String code) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.signup);

  @override
  Future<void> resendSignUpCode(String email) =>
      _auth.resend(email: email, type: OtpType.signup);

  @override
  Future<void> sendPasswordResetCode(String email) =>
      _auth.resetPasswordForEmail(email);

  @override
  Future<void> verifyRecoveryCode(String email, String code) =>
      _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);

  @override
  Future<void> updatePassword(String newPassword) =>
      _auth.updateUser(UserAttributes(password: newPassword));

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Connexion, inscription et mot de passe oublié avec Supabase Auth.
///
/// Valide les champs avant chaque appel et lève une [CineFailure] dont le
/// message, en français, peut être affiché tel quel.
class AuthService {
  AuthService(this._gateway);

  static AuthService? _instance;
  static AuthService? _override;

  static AuthService get instance =>
      _override ??
      (_instance ??= AuthService(SupabaseAuthGateway(SupaFlow.client)));

  /// Remplace le service partagé (tests). `null` rétablit Supabase.
  @visibleForTesting
  static set debugInstance(AuthService? service) => _override = service;

  final AuthGateway _gateway;

  bool get hasSession => _gateway.hasSession;

  Future<T> _guard<T>(String operation, Future<T> Function() run) async {
    try {
      return await run();
    } catch (error, stack) {
      final failure = mapAuthError(error);
      developer.log('$operation : ${failure.kind.name}',
          name: 'AuthService', error: error, stackTrace: stack);
      throw failure;
    }
  }

  static void _check(String? error) {
    if (error != null) {
      throw CineFailure(CineFailureKind.invalid, error);
    }
  }

  Future<void> signIn({required String email, required String password}) =>
      _guard('signIn', () async {
        _check(validateEmail(email));
        if (password.isEmpty) {
          _check('Saisissez votre mot de passe.');
        }
        await _gateway.signIn(email.trim(), password);
      });

  Future<SignUpOutcome> signUp({
    required String username,
    required String email,
    required String password,
  }) =>
      _guard('signUp', () async {
        _check(validateUsername(username));
        _check(validateEmail(email));
        _check(validatePassword(password));
        if (!await _gateway.isUsernameAvailable(username.trim())) {
          throw const CineFailure(
              CineFailureKind.conflict, 'Ce pseudo est déjà utilisé.');
        }
        return _gateway.signUp(email.trim(), password,
            username: username.trim());
      });

  /// Null si le pseudo est libre, sinon un message d'erreur.
  Future<String?> checkUsername(String username) async {
    final error = validateUsername(username);
    if (error != null) {
      return error;
    }
    try {
      final available = await _gateway.isUsernameAvailable(username.trim());
      return available ? null : 'Ce pseudo est déjà utilisé.';
    } catch (error) {
      // Vérification indicative : le serveur tranchera à l'inscription.
      developer.log('checkUsername', name: 'AuthService', error: error);
      return null;
    }
  }

  Future<void> confirmSignUp({required String email, required String code}) =>
      _guard('confirmSignUp', () async {
        _check(validateOtpCode(code));
        await _gateway.verifySignUpCode(email.trim(), code.trim());
      });

  Future<void> resendSignUpCode(String email) =>
      _guard('resendSignUpCode', () async {
        _check(validateEmail(email));
        await _gateway.resendSignUpCode(email.trim());
      });

  Future<void> sendPasswordResetCode(String email) =>
      _guard('sendPasswordResetCode', () async {
        _check(validateEmail(email));
        await _gateway.sendPasswordResetCode(email.trim());
      });

  /// Vérifie le code de récupération (ce qui connecte le membre), puis
  /// enregistre le nouveau mot de passe. Sans [code], le membre doit déjà
  /// être connecté (changement de mot de passe depuis l'application).
  Future<void> resetPassword({
    String? email,
    String? code,
    required String newPassword,
  }) =>
      _guard('resetPassword', () async {
        _check(validatePassword(newPassword));
        if (code != null) {
          _check(validateEmail(email));
          _check(validateOtpCode(code));
          await _gateway.verifyRecoveryCode(email!.trim(), code.trim());
        } else if (!_gateway.hasSession) {
          throw const CineFailure(CineFailureKind.unauthenticated,
              'Le lien a expiré. Demandez un nouveau code.');
        }
        await _gateway.updatePassword(newPassword);
      });

  Future<void> signOut() => _guard('signOut', _gateway.signOut);
}

// Composants d'interface partagés par les formulaires d'authentification ------

/// Mise en page commune : logo, titre, sous-titre et formulaire centré.
class AuthFormShell extends StatelessWidget {
  const AuthFormShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.width,
    this.height,
    this.icon = Icons.movie_filter_rounded,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final double? width;
  final double? height;
  final IconData icon;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [theme.primary, theme.secondary],
                            ),
                          ),
                          child: Icon(icon, size: 44, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium
                            .copyWith(color: theme.secondaryText),
                      ),
                      const SizedBox(height: 32),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
            if (onBack != null)
              Positioned(
                top: 4,
                left: 4,
                child: IconButton(
                  tooltip: 'Retour',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: onBack,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Champ de formulaire avec icône, message d'erreur et, pour un mot de passe,
/// bouton afficher / masquer.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.suffix,
    this.helperText,
    this.maxLength,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FormFieldValidator<String>? validator;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final String? helperText;
  final int? maxLength;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.alternate),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: widget.isPassword && _obscure,
        enableSuggestions: !widget.isPassword,
        autocorrect: false,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        maxLength: widget.maxLength,
        validator: widget.validator,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        style: theme.bodyLarge,
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          counterText: '',
          prefixIcon: Icon(widget.icon),
          suffixIcon: widget.isPassword
              ? IconButton(
                  tooltip: _obscure
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : widget.suffix,
          filled: true,
          fillColor: theme.secondaryBackground,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: theme.primary, width: 2),
          ),
          errorBorder: border.copyWith(
            borderSide: BorderSide(color: theme.error),
          ),
          focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(color: theme.error, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Champ du code à usage unique reçu par e-mail.
class AuthCodeField extends StatelessWidget {
  const AuthCodeField({
    super.key,
    required this.controller,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => AuthTextField(
        controller: controller,
        label: 'Code reçu par e-mail',
        icon: Icons.pin_outlined,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.oneTimeCode],
        maxLength: 8,
        validator: validateOtpCode,
        onSubmitted: onSubmitted,
      );
}

/// Bouton principal avec état de chargement.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }
}

/// Bandeau d'erreur ou d'information au-dessus du bouton principal.
class AuthMessageBanner extends StatelessWidget {
  const AuthMessageBanner({
    super.key,
    required this.message,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final color = isError ? theme.error : theme.success;
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: theme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// Bouton « Renvoyer le code » désactivé pendant [kResendCooldown].
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.onResend,
    this.startCoolingDown = true,
  });

  /// Renvoie le message d'erreur à afficher, ou null si l'envoi a réussi.
  final Future<String?> Function() onResend;
  final bool startCoolingDown;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _secondsLeft = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.startCoolingDown) {
      _startCooldown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    _secondsLeft = kResendCooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final error = await widget.onResend();
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (error == null) {
      _startCooldown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _secondsLeft > 0;
    return TextButton(
      onPressed: waiting || _sending ? null : _resend,
      child: Text(waiting
          ? 'Renvoyer le code dans $_secondsLeft s'
          : 'Renvoyer le code'),
    );
  }
}
