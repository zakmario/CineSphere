import 'package:cine_sphere/custom_code/actions/auth_service.dart';

/// Passerelle d'authentification en mémoire : enregistre chaque appel dans
/// [calls] et lève [error] (toutes les méthodes) ou `errors[méthode]`.
class FakeAuthGateway implements AuthGateway {
  final calls = <String>[];
  final takenUsernames = <String>{};
  final errors = <String, Object>{};
  SignUpOutcome signUpOutcome = SignUpOutcome.confirmationRequired;
  Object? error;
  bool signedIn = false;
  bool emailVerified = true;

  /// Valeur renvoyée par [refreshEmailVerified] (lien cliqué ou non).
  bool verifiedAfterRefresh = true;
  bool recentLogin = true;

  Future<void> _record(String call) async {
    calls.add(call);
    final pending = errors[call.split(' ').first] ?? error;
    if (pending != null) {
      throw pending;
    }
  }

  @override
  bool get isSignedIn => signedIn;

  @override
  bool get isEmailVerified => signedIn && emailVerified;

  @override
  Future<void> signIn(String email, String password) async {
    await _record('signIn $email');
    signedIn = true;
  }

  @override
  Future<SignUpOutcome> signUp(String email, String password,
      {required String username}) async {
    await _record('signUp $email $username');
    signedIn = true;
    emailVerified = signUpOutcome == SignUpOutcome.signedIn;
    return signUpOutcome;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await _record('isUsernameAvailable $username');
    return !takenUsernames.contains(username);
  }

  @override
  Future<bool> refreshEmailVerified() async {
    await _record('refreshEmailVerified');
    emailVerified = verifiedAfterRefresh;
    return emailVerified;
  }

  @override
  Future<void> sendEmailVerification() => _record('sendEmailVerification');

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _record('sendPasswordResetEmail $email');

  @override
  Future<void> updatePassword(String newPassword) =>
      _record('updatePassword $newPassword');

  @override
  Future<bool> signedInRecently() async {
    await _record('signedInRecently');
    return recentLogin;
  }

  @override
  Future<void> deleteAccount() async {
    await _record('deleteAccount');
    signedIn = false;
  }

  @override
  Future<void> signOut() async {
    await _record('signOut');
    signedIn = false;
  }
}
