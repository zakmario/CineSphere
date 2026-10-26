import 'package:cine_sphere/custom_code/actions/auth_service.dart';
import 'package:cine_sphere/custom_code/actions/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_gateway.dart';

/// Échec attendu : [CineFailure] de type [kind].
Matcher _failure(CineFailureKind kind, [Object? message]) =>
    isA<CineFailure>().having((f) => f.kind, 'kind', kind).having(
        (f) => f.message, 'message', message ?? anything);

void main() {
  group('validation', () {
    test('e-mail', () {
      expect(validateEmail('zak@example.com'), isNull);
      expect(validateEmail('  zak@example.com '), isNull);
      expect(validateEmail(''), 'Saisissez votre adresse e-mail.');
      expect(validateEmail(null), 'Saisissez votre adresse e-mail.');
      for (final email in [
        'zak',
        'zak@',
        '@example.com',
        'zak@example',
        'a b@c.fr'
      ]) {
        expect(validateEmail(email), 'Adresse e-mail invalide.', reason: email);
      }
    });

    test('mot de passe : 8 caractères minimum', () {
      expect(validatePassword('12345678'), isNull);
      expect(validatePassword(''), 'Saisissez un mot de passe.');
      expect(validatePassword('1234567'), contains('au moins 8'));
    });

    test('confirmation du mot de passe', () {
      expect(validatePasswordConfirmation('motdepasse', 'motdepasse'), isNull);
      expect(validatePasswordConfirmation('motdepasse', ''),
          'Confirmez le mot de passe.');
      expect(validatePasswordConfirmation('motdepasse', 'autre'),
          'Les mots de passe ne correspondent pas.');
    });
  });

  group('mapAuthError', () {
    test('codes Firebase traduits en français', () {
      final cases = {
        'invalid-credential': (
          CineFailureKind.unauthenticated,
          'E-mail ou mot de passe incorrect.'
        ),
        'email-already-in-use': (
          CineFailureKind.conflict,
          'Un compte existe déjà avec cette adresse e-mail.'
        ),
        'weak-password': (CineFailureKind.invalid, null),
        'too-many-requests': (CineFailureKind.forbidden, null),
        'requires-recent-login': (CineFailureKind.unauthenticated, null),
        'network-request-failed': (CineFailureKind.network, null),
        'email-not-verified': (CineFailureKind.unauthenticated, null),
      };
      cases.forEach((code, expected) {
        final failure = mapAuthError(fb.FirebaseAuthException(code: code));
        expect(failure.kind, expected.$1, reason: code);
        if (expected.$2 != null) {
          expect(failure.message, expected.$2, reason: code);
        }
      });
    });

    test('code inconnu', () {
      expect(mapAuthError(fb.FirebaseAuthException(code: 'quoi')).kind,
          CineFailureKind.unknown);
    });

    test('les autres erreurs passent par mapFirestoreError', () {
      const failure = CineFailure(CineFailureKind.conflict, 'déjà');
      expect(mapAuthError(failure), same(failure));
      expect(mapAuthError(StateError('x')).kind, CineFailureKind.unknown);
    });
  });

  group('AuthService', () {
    late FakeAuthGateway gateway;
    late AuthService service;

    setUp(() {
      gateway = FakeAuthGateway();
      service = AuthService(gateway);
    });

    test('hasSession exige une adresse confirmée', () async {
      expect(service.hasSession, isFalse);
      gateway
        ..signedIn = true
        ..emailVerified = false;
      expect(service.hasSession, isFalse);
      gateway.emailVerified = true;
      expect(service.hasSession, isTrue);
    });

    test('signIn nettoie l\'e-mail et refuse les champs vides', () async {
      await service.signIn(email: ' zak@example.com ', password: 'secret12');
      expect(gateway.calls, ['signIn zak@example.com']);
      await expectLater(service.signIn(email: 'zak@example.com', password: ''),
          throwsA(_failure(CineFailureKind.invalid)));
      await expectLater(service.signIn(email: 'zak', password: 'secret12'),
          throwsA(_failure(CineFailureKind.invalid)));
      expect(gateway.calls, hasLength(1));
    });

    test('signIn : adresse non confirmée -> email-not-verified', () async {
      gateway.emailVerified = false;
      await expectLater(
          service.signIn(email: 'zak@example.com', password: 'secret12'),
          throwsA(isA<CineFailure>().having(
              (f) => (f.cause as fb.FirebaseAuthException).code,
              'code',
              'email-not-verified')));
      expect(gateway.signedIn, isTrue, reason: 'reste connecté pour renvoyer');
    });

    test('signIn traduit les erreurs Firebase', () async {
      gateway.errors['signIn'] =
          fb.FirebaseAuthException(code: 'invalid-credential');
      await expectLater(
          service.signIn(email: 'zak@example.com', password: 'mauvais1'),
          throwsA(_failure(CineFailureKind.unauthenticated,
              'E-mail ou mot de passe incorrect.')));
    });

    test('signUp vérifie le pseudo avant de créer le compte', () async {
      gateway.takenUsernames.add('zak');
      await expectLater(
          service.signUp(
              username: 'zak', email: 'zak@example.com', password: 'secret12'),
          throwsA(_failure(
              CineFailureKind.conflict, 'Ce pseudo est déjà utilisé.')));
      expect(gateway.calls, ['isUsernameAvailable zak']);
    });

    test('signUp valide les champs sans appeler Firebase', () async {
      for (final (username, email, password) in [
        ('za', 'zak@example.com', 'secret12'),
        ('zak', 'zak', 'secret12'),
        ('zak', 'zak@example.com', 'court'),
      ]) {
        await expectLater(
            service.signUp(username: username, email: email, password: password),
            throwsA(_failure(CineFailureKind.invalid)));
      }
      expect(gateway.calls, isEmpty);
    });

    test('signUp transmet pseudo et e-mail nettoyés', () async {
      final outcome = await service.signUp(
          username: ' zak ', email: ' zak@example.com ', password: 'secret12');
      expect(outcome, SignUpOutcome.confirmationRequired);
      expect(gateway.calls.last, 'signUp zak@example.com zak');
    });

    test('checkUsername : format, disponibilité, erreur réseau ignorée',
        () async {
      expect(await service.checkUsername('z'), isNotNull);
      expect(await service.checkUsername('zak'), isNull);
      gateway.takenUsernames.add('zak');
      expect(await service.checkUsername('zak'), 'Ce pseudo est déjà utilisé.');
      gateway.errors['isUsernameAvailable'] = StateError('réseau');
      expect(await service.checkUsername('zak'), isNull);
    });

    test('confirmSignUp : lien cliqué ou non', () async {
      await expectLater(service.confirmSignUp(),
          throwsA(_failure(CineFailureKind.unauthenticated)));
      gateway
        ..signedIn = true
        ..verifiedAfterRefresh = false;
      await expectLater(service.confirmSignUp(),
          throwsA(_failure(CineFailureKind.invalid, contains('lien'))));
      gateway.verifiedAfterRefresh = true;
      await service.confirmSignUp();
      expect(service.hasSession, isTrue);
    });

    test('resendConfirmation exige un compte connecté', () async {
      await expectLater(service.resendConfirmation(),
          throwsA(_failure(CineFailureKind.unauthenticated)));
      gateway.signedIn = true;
      await service.resendConfirmation();
      expect(gateway.calls, ['sendEmailVerification']);
    });

    test('sendPasswordReset valide puis envoie le lien', () async {
      await expectLater(service.sendPasswordReset('zak'),
          throwsA(_failure(CineFailureKind.invalid)));
      await service.sendPasswordReset(' zak@example.com ');
      expect(gateway.calls, ['sendPasswordResetEmail zak@example.com']);
    });

    test('changePassword : session et longueur exigées', () async {
      await expectLater(service.changePassword('nouveau12'),
          throwsA(_failure(CineFailureKind.unauthenticated)));
      gateway.signedIn = true;
      await expectLater(service.changePassword('court'),
          throwsA(_failure(CineFailureKind.invalid)));
      await service.changePassword('nouveau12');
      expect(gateway.calls, ['updatePassword nouveau12']);
    });

    test('deleteAccount exige une connexion récente', () async {
      gateway
        ..signedIn = true
        ..recentLogin = false;
      await expectLater(
          service.deleteAccount(),
          throwsA(_failure(CineFailureKind.unauthenticated,
              contains('reconnectez-vous'))));
      expect(gateway.calls, ['signedInRecently']);
      gateway.recentLogin = true;
      await service.deleteAccount();
      expect(gateway.calls.last, 'deleteAccount');
      expect(gateway.signedIn, isFalse);
    });

    test('signOut', () async {
      gateway.signedIn = true;
      await service.signOut();
      expect(gateway.signedIn, isFalse);
    });

    test('debugInstance remplace le service partagé', () {
      AuthService.debugInstance = service;
      expect(AuthService.instance, same(service));
      AuthService.debugInstance = null;
    });
  });
}
