import 'package:cine_sphere/custom_code/actions/auth_service.dart';

/// Passerelle d'authentification en mémoire : enregistre chaque appel dans
/// [calls] et lève [error] (toutes les méthodes) ou `errors[méthode]`.
class FakeAuthGateway implements AuthGateway {
  final calls = <String>[];
  final takenUsernames = <String>{};
  final errors = <String, Object>{};
  SignUpOutcome signUpOutcome = SignUpOutcome.signedIn;
  Object? error;
  bool session = false;

  Future<void> _record(String call) async {
    calls.add(call);
    final pending = errors[call.split(' ').first] ?? error;
    if (pending != null) {
      throw pending;
    }
  }

  @override
  bool get hasSession => session;

  @override
  Future<void> signIn(String email, String password) async {
    await _record('signIn $email');
    session = true;
  }

  @override
  Future<SignUpOutcome> signUp(String email, String password,
      {required String username}) async {
    await _record('signUp $email $username');
    session = signUpOutcome == SignUpOutcome.signedIn;
    return signUpOutcome;
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await _record('isUsernameAvailable $username');
    return !takenUsernames.contains(username);
  }

  @override
  Future<void> verifySignUpCode(String email, String code) async {
    await _record('verifySignUpCode $email $code');
    session = true;
  }

  @override
  Future<void> resendSignUpCode(String email) =>
      _record('resendSignUpCode $email');

  @override
  Future<void> sendPasswordResetCode(String email) =>
      _record('sendPasswordResetCode $email');

  @override
  Future<void> verifyRecoveryCode(String email, String code) async {
    await _record('verifyRecoveryCode $email $code');
    session = true;
  }

  @override
  Future<void> updatePassword(String newPassword) =>
      _record('updatePassword $newPassword');

  @override
  Future<void> signOut() async {
    await _record('signOut');
    session = false;
  }
}
