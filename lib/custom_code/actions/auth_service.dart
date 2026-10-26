// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:developer' as developer;

import '/custom_code/actions/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Vrai si un membre est connecté avec une adresse e-mail confirmée.
/// Action FlutterFlow, utilisable dans un *Conditional* ou un *On Page Load*.
Future<bool> authService() async => AuthService.instance.hasSession;

/// Longueur minimale du mot de passe (cahier des charges, section 6.2).
const int kMinPasswordLength = 8;

/// Délai avant de pouvoir renvoyer un e-mail.
const Duration kResendCooldown = Duration(seconds: 60);

/// Résultat des actions authSignIn / authSignUp quand le membre doit
/// confirmer son adresse avec le lien reçu par e-mail (page ConfirmationEmail).
const String kAuthNeedsCode = 'CONFIRM';

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

/// Code à usage unique (6 à 8 chiffres). Firebase envoie des liens : ce
/// validateur ne sert plus qu'aux anciens formulaires.
String? validateOtpCode(String? value) {
  final code = value?.trim() ?? '';
  if (!RegExp(r'^\d{6,8}$').hasMatch(code)) {
    return 'Saisissez le code reçu par e-mail.';
  }
  return null;
}

// Erreurs --------------------------------------------------------------------

const _authMessages = <String, (CineFailureKind, String)>{
  'invalid-credential': (
    CineFailureKind.unauthenticated,
    'E-mail ou mot de passe incorrect.'
  ),
  'wrong-password': (
    CineFailureKind.unauthenticated,
    'E-mail ou mot de passe incorrect.'
  ),
  'user-not-found': (
    CineFailureKind.unauthenticated,
    'E-mail ou mot de passe incorrect.'
  ),
  'email-not-verified': (
    CineFailureKind.unauthenticated,
    'Confirmez votre adresse e-mail avant de vous connecter.'
  ),
  'email-already-in-use': (
    CineFailureKind.conflict,
    'Un compte existe déjà avec cette adresse e-mail.'
  ),
  'weak-password': (
    CineFailureKind.invalid,
    'Mot de passe trop faible : choisissez-en un plus long.'
  ),
  'invalid-email': (CineFailureKind.invalid, 'Adresse e-mail invalide.'),
  'too-many-requests': (
    CineFailureKind.forbidden,
    'Trop de tentatives. Patientez quelques minutes avant de réessayer.'
  ),
  'operation-not-allowed': (
    CineFailureKind.forbidden,
    'Les inscriptions sont momentanément fermées.'
  ),
  'user-disabled': (CineFailureKind.forbidden, 'Ce compte a été suspendu.'),
  'requires-recent-login': (
    CineFailureKind.unauthenticated,
    'Pour des raisons de sécurité, reconnectez-vous puis réessayez.'
  ),
  'user-token-expired': (
    CineFailureKind.unauthenticated,
    'Votre session a expiré. Reconnectez-vous.'
  ),
  'network-request-failed': (
    CineFailureKind.network,
    'Pas de connexion Internet. Réessayez plus tard.'
  ),
};

/// Traduit une erreur Firebase Auth en [CineFailure] (message en français).
CineFailure mapAuthError(Object error) {
  if (error is CineFailure) {
    return error;
  }
  if (error is fb.FirebaseAuthException) {
    final known = _authMessages[error.code];
    if (known != null) {
      return CineFailure(known.$1, known.$2, error);
    }
    return CineFailure(CineFailureKind.unknown,
        'L\'authentification a échoué. Réessayez.', error);
  }
  return mapFirestoreError(error);
}

// Service --------------------------------------------------------------------

/// Résultat d'une inscription.
enum SignUpOutcome {
  /// Compte créé et membre connecté.
  signedIn,

  /// Compte créé : il faut confirmer l'adresse avec le lien reçu par e-mail.
  confirmationRequired,
}

/// Opérations Firebase Auth utilisées par l'application (remplaçable en test).
abstract class AuthGateway {
  /// Vrai si un membre est connecté (adresse confirmée ou non).
  bool get isSignedIn;

  bool get isEmailVerified;

  Future<void> signIn(String email, String password);

  Future<SignUpOutcome> signUp(String email, String password,
      {required String username});

  Future<bool> isUsernameAvailable(String username);

  /// Recharge le compte et renvoie vrai si l'adresse est confirmée.
  Future<bool> refreshEmailVerified();

  Future<void> sendEmailVerification();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> updatePassword(String newPassword);

  /// Vrai si la dernière connexion date de moins de 5 minutes (Firebase
  /// l'exige pour supprimer un compte).
  Future<bool> signedInRecently();

  Future<void> deleteAccount();

  Future<void> signOut();
}

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this._auth, this._data);

  final fb.FirebaseAuth _auth;
  final FirestoreService _data;

  fb.User get _user {
    final user = _auth.currentUser;
    if (user == null) {
      throw const CineFailure(CineFailureKind.unauthenticated,
          'Votre session a expiré. Reconnectez-vous.');
    }
    return user;
  }

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  @override
  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<SignUpOutcome> signUp(String email, String password,
      {required String username}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final user = credential.user!;
    try {
      await _data.createProfile(
          userId: user.uid, username: username, email: email);
    } catch (_) {
      // Pseudo pris entre la vérification et l'inscription : pas de compte
      // sans profil.
      await user.delete();
      rethrow;
    }
    await user.sendEmailVerification();
    return SignUpOutcome.confirmationRequired;
  }

  @override
  Future<bool> isUsernameAvailable(String username) =>
      _data.isUsernameAvailable(username);

  @override
  Future<bool> refreshEmailVerified() async {
    await _user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<void> sendEmailVerification() => _user.sendEmailVerification();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> updatePassword(String newPassword) =>
      _user.updatePassword(newPassword);

  @override
  Future<bool> signedInRecently() async {
    final authTime = (await _user.getIdTokenResult()).authTime;
    return authTime != null &&
        DateTime.now().difference(authTime) < const Duration(minutes: 5);
  }

  @override
  Future<void> deleteAccount() => _user.delete();

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Connexion, inscription et mot de passe oublié avec Firebase Auth.
///
/// Valide les champs avant chaque appel et lève une [CineFailure] dont le
/// message, en français, peut être affiché tel quel.
class AuthService {
  AuthService(this._gateway);

  static AuthService? _instance;
  static AuthService? _override;

  static AuthService get instance =>
      _override ??
      (_instance ??= AuthService(FirebaseAuthGateway(
          fb.FirebaseAuth.instance, FirestoreService.instance)));

  /// Remplace le service partagé (tests). `null` rétablit Firebase.
  @visibleForTesting
  static set debugInstance(AuthService? service) => _override = service;

  final AuthGateway _gateway;

  /// Connecté avec une adresse confirmée.
  bool get hasSession => _gateway.isSignedIn && _gateway.isEmailVerified;

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

  /// Connecte le membre. Si son adresse n'est pas confirmée, il reste
  /// connecté (pour pouvoir renvoyer le lien) et l'erreur
  /// `email-not-verified` est levée.
  Future<void> signIn({required String email, required String password}) =>
      _guard('signIn', () async {
        _check(validateEmail(email));
        if (password.isEmpty) {
          _check('Saisissez votre mot de passe.');
        }
        await _gateway.signIn(email.trim(), password);
        if (!_gateway.isEmailVerified) {
          throw fb.FirebaseAuthException(code: 'email-not-verified');
        }
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
      // Vérification indicative : l'inscription tranchera.
      developer.log('checkUsername', name: 'AuthService', error: error);
      return null;
    }
  }

  /// Vérifie que le membre a cliqué sur le lien de confirmation.
  Future<void> confirmSignUp() => _guard('confirmSignUp', () async {
        if (!_gateway.isSignedIn) {
          throw const CineFailure(CineFailureKind.unauthenticated,
              'Reconnectez-vous pour terminer l\'inscription.');
        }
        if (!await _gateway.refreshEmailVerified()) {
          throw const CineFailure(CineFailureKind.invalid,
              'Adresse pas encore confirmée : cliquez sur le lien reçu par '
              'e-mail, puis réessayez.');
        }
      });

  Future<void> resendConfirmation() => _guard('resendConfirmation', () async {
        if (!_gateway.isSignedIn) {
          throw const CineFailure(CineFailureKind.unauthenticated,
              'Reconnectez-vous pour recevoir un nouveau lien.');
        }
        await _gateway.sendEmailVerification();
      });

  Future<void> sendPasswordReset(String email) =>
      _guard('sendPasswordReset', () async {
        _check(validateEmail(email));
        await _gateway.sendPasswordResetEmail(email.trim());
      });

  /// Change le mot de passe du membre connecté. Le mot de passe oublié passe
  /// par le lien reçu par e-mail (page Firebase), pas par cette méthode.
  Future<void> changePassword(String newPassword) =>
      _guard('changePassword', () async {
        _check(validatePassword(newPassword));
        if (!_gateway.isSignedIn) {
          throw const CineFailure(CineFailureKind.unauthenticated,
              'Utilisez le lien reçu par e-mail pour choisir un nouveau '
              'mot de passe.');
        }
        await _gateway.updatePassword(newPassword);
      });

  /// Supprime les données Firestore du membre puis son compte. Vérifie
  /// d'abord la connexion récente : sans elle, Firebase refuserait de
  /// supprimer le compte après l'effacement des données.
  Future<void> deleteAccount() => _guard('deleteAccount', () async {
        if (!await _gateway.signedInRecently()) {
          throw fb.FirebaseAuthException(code: 'requires-recent-login');
        }
        await FirestoreService.instance.deleteMyData();
        await _gateway.deleteAccount();
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
