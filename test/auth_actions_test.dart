import 'package:cine_sphere/custom_code/actions/auth_confirm_sign_up.dart';
import 'package:cine_sphere/custom_code/actions/auth_resend_code.dart';
import 'package:cine_sphere/custom_code/actions/auth_reset_password.dart';
import 'package:cine_sphere/custom_code/actions/auth_send_reset_code.dart';
import 'package:cine_sphere/custom_code/actions/auth_service.dart';
import 'package:cine_sphere/custom_code/actions/auth_sign_in.dart';
import 'package:cine_sphere/custom_code/actions/auth_sign_up.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth_gateway.dart';

/// Actions FlutterFlow des pages d'authentification (membre 1) :
/// "" = succès, [kAuthNeedsCode] = code e-mail à saisir, sinon le message.
void main() {
  late FakeAuthGateway gateway;

  setUp(() {
    gateway = FakeAuthGateway();
    AuthService.debugInstance = AuthService(gateway);
  });

  tearDown(() => AuthService.debugInstance = null);

  group('authSignIn', () {
    test('retourne "" quand la connexion réussit', () async {
      expect(await authSignIn('zak@example.com', 'secret123'), '');
      expect(gateway.session, isTrue);
    });

    test('retourne le message français des identifiants invalides', () async {
      gateway.errors['signIn'] = AuthApiException('Invalid login',
          statusCode: '400', code: 'invalid_credentials');
      expect(await authSignIn('zak@example.com', 'mauvais1'),
          'E-mail ou mot de passe incorrect.');
    });

    test('renvoie un code et retourne CONFIRM si l\'e-mail n\'est pas confirmé',
        () async {
      gateway.errors['signIn'] = AuthApiException('Email not confirmed',
          statusCode: '400', code: 'email_not_confirmed');
      expect(await authSignIn('zak@example.com', 'secret123'), kAuthNeedsCode);
      expect(gateway.calls, contains('resendSignUpCode zak@example.com'));
    });

    test('valide l\'e-mail avant d\'appeler Supabase', () async {
      expect(await authSignIn('pas-un-email', 'secret123'),
          'Adresse e-mail invalide.');
      expect(gateway.calls, isEmpty);
    });
  });

  group('authSignUp', () {
    test('retourne "" quand le compte est créé et connecté', () async {
      expect(
          await authSignUp('zak', 'zak@example.com', 'secret123', 'secret123'),
          '');
    });

    test('retourne CONFIRM quand Supabase demande le code e-mail', () async {
      gateway.signUpOutcome = SignUpOutcome.confirmationRequired;
      expect(
          await authSignUp('zak', 'zak@example.com', 'secret123', 'secret123'),
          kAuthNeedsCode);
    });

    test('refuse une confirmation différente sans appeler Supabase', () async {
      expect(
          await authSignUp('zak', 'zak@example.com', 'secret123', 'autre1234'),
          'Les mots de passe ne correspondent pas.');
      expect(gateway.calls, isEmpty);
    });

    test('signale un pseudo déjà pris', () async {
      gateway.takenUsernames.add('zak');
      expect(
          await authSignUp('zak', 'zak@example.com', 'secret123', 'secret123'),
          'Ce pseudo est déjà utilisé.');
    });
  });

  test('authConfirmSignUp valide le code reçu', () async {
    expect(await authConfirmSignUp('zak@example.com', '123456'), '');
    expect(gateway.calls, ['verifySignUpCode zak@example.com 123456']);
    expect(await authConfirmSignUp('zak@example.com', '12'),
        'Saisissez le code reçu par e-mail.');
  });

  test('authResendCode et authSendResetCode envoient le code', () async {
    expect(await authResendCode('zak@example.com'), '');
    expect(await authSendResetCode('zak@example.com'), '');
    expect(gateway.calls, [
      'resendSignUpCode zak@example.com',
      'sendPasswordResetCode zak@example.com',
    ]);
  });

  group('authResetPassword', () {
    test('vérifie le code puis enregistre le mot de passe', () async {
      expect(
          await authResetPassword(
              'zak@example.com', '123456', 'nouveau123', 'nouveau123'),
          '');
      expect(gateway.calls, [
        'verifyRecoveryCode zak@example.com 123456',
        'updatePassword nouveau123',
      ]);
    });

    test('refuse une confirmation différente', () async {
      expect(
          await authResetPassword(
              'zak@example.com', '123456', 'nouveau123', 'autre1234'),
          'Les mots de passe ne correspondent pas.');
      expect(gateway.calls, isEmpty);
    });
  });
}
