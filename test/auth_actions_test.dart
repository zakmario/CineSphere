import 'package:cine_sphere/custom_code/actions/auth_confirm_sign_up.dart';
import 'package:cine_sphere/custom_code/actions/auth_resend_code.dart';
import 'package:cine_sphere/custom_code/actions/auth_reset_password.dart';
import 'package:cine_sphere/custom_code/actions/auth_send_reset_code.dart';
import 'package:cine_sphere/custom_code/actions/auth_service.dart';
import 'package:cine_sphere/custom_code/actions/auth_sign_in.dart';
import 'package:cine_sphere/custom_code/actions/auth_sign_up.dart';
import 'package:cine_sphere/custom_code/actions/delete_my_account.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_gateway.dart';

/// Actions FlutterFlow des pages d'authentification (membre 1) :
/// "" = succès, [kAuthNeedsCode] = adresse à confirmer, sinon le message.
void main() {
  late FakeAuthGateway gateway;

  setUp(() {
    gateway = FakeAuthGateway();
    AuthService.debugInstance = AuthService(gateway);
  });

  tearDown(() => AuthService.debugInstance = null);

  group('authSignIn', () {
    test('retourne "" quand la connexion réussit', () async {
      expect(await authSignIn('zak@example.com', 'secret12'), '');
    });

    test('retourne le message français des identifiants invalides', () async {
      gateway.errors['signIn'] =
          fb.FirebaseAuthException(code: 'invalid-credential');
      expect(await authSignIn('zak@example.com', 'mauvais1'),
          'E-mail ou mot de passe incorrect.');
    });

    test('retourne CONFIRM si l\'adresse n\'est pas confirmée', () async {
      gateway.emailVerified = false;
      expect(await authSignIn('zak@example.com', 'secret12'), kAuthNeedsCode);
    });

    test('valide l\'e-mail avant d\'appeler Firebase', () async {
      expect(await authSignIn('zak', 'secret12'), 'Adresse e-mail invalide.');
      expect(gateway.calls, isEmpty);
    });
  });

  group('authSignUp', () {
    test('retourne CONFIRM : lien de confirmation envoyé', () async {
      expect(
          await authSignUp('zak', 'zak@example.com', 'secret12', 'secret12'),
          kAuthNeedsCode);
    });

    test('retourne "" si le compte est déjà actif', () async {
      gateway.signUpOutcome = SignUpOutcome.signedIn;
      expect(
          await authSignUp('zak', 'zak@example.com', 'secret12', 'secret12'),
          '');
    });

    test('refuse une confirmation différente sans appeler Firebase', () async {
      expect(await authSignUp('zak', 'zak@example.com', 'secret12', 'autre123'),
          'Les mots de passe ne correspondent pas.');
      expect(gateway.calls, isEmpty);
    });

    test('signale un pseudo déjà pris', () async {
      gateway.takenUsernames.add('zak');
      expect(
          await authSignUp('zak', 'zak@example.com', 'secret12', 'secret12'),
          'Ce pseudo est déjà utilisé.');
    });
  });

  test('authConfirmSignUp vérifie le lien cliqué', () async {
    gateway
      ..signedIn = true
      ..verifiedAfterRefresh = false;
    expect(await authConfirmSignUp('zak@example.com', ''), contains('lien'));
    gateway.verifiedAfterRefresh = true;
    expect(await authConfirmSignUp('zak@example.com', ''), '');
  });

  test('authResendCode et authSendResetCode envoient un lien', () async {
    gateway.signedIn = true;
    expect(await authResendCode('zak@example.com'), '');
    expect(await authSendResetCode('zak@example.com'), '');
    expect(gateway.calls,
        ['sendEmailVerification', 'sendPasswordResetEmail zak@example.com']);
  });

  group('authResetPassword', () {
    test('change le mot de passe du membre connecté', () async {
      gateway.signedIn = true;
      expect(
          await authResetPassword(
              'zak@example.com', '', 'nouveau12', 'nouveau12'),
          '');
      expect(gateway.calls, ['updatePassword nouveau12']);
    });

    test('refuse une confirmation différente', () async {
      gateway.signedIn = true;
      expect(
          await authResetPassword(
              'zak@example.com', '', 'nouveau12', 'autre123'),
          'Les mots de passe ne correspondent pas.');
      expect(gateway.calls, isEmpty);
    });
  });

  test('deleteMyAccount demande une connexion récente', () async {
    gateway
      ..signedIn = true
      ..recentLogin = false;
    expect(await deleteMyAccount(), contains('reconnectez-vous'));
    gateway.recentLogin = true;
    expect(await deleteMyAccount(), '');
  });
}
