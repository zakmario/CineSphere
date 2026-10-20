import 'dart:async';
import 'dart:convert';

import 'package:cine_sphere/custom_code/actions/auth_service.dart';
import 'package:cine_sphere/custom_code/actions/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fake_auth_gateway.dart';

const _url = 'https://test.supabase.co';

/// Passerelle Supabase dont les réponses HTTP sont simulées par [handler].
SupabaseAuthGateway _gateway(
  FutureOr<http.Response> Function(http.Request request) handler, {
  List<http.Request>? requests,
}) {
  final client = SupabaseClient(
    _url,
    'anon-key',
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
    httpClient: MockClient((request) async {
      requests?.add(request);
      final response = await handler(request);
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers, request: request);
    }),
  );
  return SupabaseAuthGateway(client);
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response _authError(String code, String message, {int status = 400}) =>
    _json({'code': status, 'error_code': code, 'msg': message}, status);

Map<String, dynamic> _user({List<Map<String, dynamic>>? identities}) => {
      'id': '11111111-1111-1111-1111-111111111111',
      'aud': 'authenticated',
      'email': 'zak@example.com',
      'created_at': '2026-10-20T09:30:00Z',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {'username': 'zak'},
      'identities': identities ??
          [
            {
              'id': '11111111-1111-1111-1111-111111111111',
              'identity_id': '22222222-2222-2222-2222-222222222222',
              'user_id': '11111111-1111-1111-1111-111111111111',
              'provider': 'email',
              'identity_data': <String, dynamic>{},
              'created_at': '2026-10-20T09:30:00Z',
              'last_sign_in_at': '2026-10-20T09:30:00Z',
              'updated_at': '2026-10-20T09:30:00Z',
            }
          ],
    };

Map<String, dynamic> _session() => {
      'access_token': 'access',
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'refresh',
      'user': _user(),
    };

Map<String, dynamic> _body(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

Matcher _failure(CineFailureKind kind, [String? message]) => isA<CineFailure>()
    .having((f) => f.kind, 'kind', kind)
    .having((f) => f.message, 'message', message ?? anything);

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

    test('code reçu par e-mail : 6 à 8 chiffres', () {
      expect(validateOtpCode('123456'), isNull);
      expect(validateOtpCode(' 12345678 '), isNull);
      for (final code in ['', '12345', '123456789', '12a456']) {
        expect(validateOtpCode(code), isNotNull, reason: code);
      }
    });
  });

  group('mapAuthError', () {
    test('codes GoTrue traduits en français', () {
      expect(
          mapAuthError(const AuthException('x', code: 'invalid_credentials')),
          _failure(CineFailureKind.unauthenticated,
              'E-mail ou mot de passe incorrect.'));
      expect(mapAuthError(const AuthException('x', code: 'email_exists')),
          _failure(CineFailureKind.conflict));
      expect(mapAuthError(const AuthException('x', code: 'otp_expired')),
          _failure(CineFailureKind.invalid, 'Code incorrect ou expiré.'));
      expect(
          mapAuthError(
              const AuthException('x', code: 'over_email_send_rate_limit')),
          _failure(CineFailureKind.forbidden));
    });

    test('anciens messages sans code', () {
      expect(mapAuthError(const AuthException('Invalid login credentials')),
          _failure(CineFailureKind.unauthenticated));
      expect(
          mapAuthError(const AuthException('Email not confirmed')),
          _failure(CineFailureKind.unauthenticated,
              'Confirmez votre adresse e-mail avant de vous connecter.'));
      expect(
          authErrorCode(const AuthException('Token has expired or is invalid')),
          'otp_expired');
    });

    test('mot de passe faible, réseau, 429, inconnu', () {
      expect(
          mapAuthError(AuthWeakPasswordException(
              message: 'weak', statusCode: '422', reasons: const ['length'])),
          _failure(CineFailureKind.invalid));
      expect(mapAuthError(AuthRetryableFetchException(message: 'offline')),
          _failure(CineFailureKind.network));
      expect(mapAuthError(const AuthException('slow down', statusCode: '429')),
          _failure(CineFailureKind.forbidden));
      expect(mapAuthError(const AuthException('???')),
          _failure(CineFailureKind.unknown));
      expect(mapAuthError(AuthSessionMissingException()),
          _failure(CineFailureKind.unauthenticated));
    });

    test('les autres erreurs passent par mapSupabaseError', () {
      expect(mapAuthError(TimeoutException('t')),
          _failure(CineFailureKind.network));
      const failure = CineFailure(CineFailureKind.invalid, 'déjà typée');
      expect(mapAuthError(failure), same(failure));
    });
  });

  group('AuthService', () {
    late FakeAuthGateway gateway;
    late AuthService service;

    setUp(() {
      gateway = FakeAuthGateway();
      service = AuthService(gateway);
    });

    test('signIn nettoie l\'e-mail et refuse les champs vides', () async {
      await service.signIn(email: ' zak@example.com ', password: 'secret123');
      expect(gateway.calls, ['signIn zak@example.com']);
      expect(service.hasSession, isTrue);

      await expectLater(service.signIn(email: 'zak', password: 'x'),
          throwsA(_failure(CineFailureKind.invalid)));
      await expectLater(
          service.signIn(email: 'zak@example.com', password: ''),
          throwsA(_failure(
              CineFailureKind.invalid, 'Saisissez votre mot de passe.')));
    });

    test('signIn traduit les erreurs Supabase', () async {
      gateway.error =
          const AuthException('Invalid login credentials', statusCode: '400');
      await expectLater(
          service.signIn(email: 'zak@example.com', password: 'secret123'),
          throwsA(_failure(CineFailureKind.unauthenticated,
              'E-mail ou mot de passe incorrect.')));
    });

    test('signUp vérifie le pseudo avant de créer le compte', () async {
      gateway.takenUsernames.add('zak');
      await expectLater(
        service.signUp(
            username: 'zak', email: 'zak@example.com', password: 'secret123'),
        throwsA(
            _failure(CineFailureKind.conflict, 'Ce pseudo est déjà utilisé.')),
      );
      expect(gateway.calls, ['isUsernameAvailable zak']);
    });

    test('signUp valide les champs sans appeler Supabase', () async {
      await expectLater(
          service.signUp(
              username: 'z', email: 'zak@example.com', password: 'secret123'),
          throwsA(_failure(CineFailureKind.invalid)));
      await expectLater(
          service.signUp(username: 'zak', email: 'zak', password: 'secret123'),
          throwsA(_failure(CineFailureKind.invalid)));
      await expectLater(
          service.signUp(
              username: 'zak', email: 'zak@example.com', password: 'court'),
          throwsA(_failure(CineFailureKind.invalid)));
      expect(gateway.calls, isEmpty);
    });

    test('signUp transmet pseudo et e-mail nettoyés', () async {
      gateway.signUpOutcome = SignUpOutcome.confirmationRequired;
      final outcome = await service.signUp(
          username: ' zak ', email: ' zak@example.com', password: 'secret123');
      expect(outcome, SignUpOutcome.confirmationRequired);
      expect(gateway.calls,
          ['isUsernameAvailable zak', 'signUp zak@example.com zak']);
    });

    test('checkUsername : format, disponibilité, erreur réseau ignorée',
        () async {
      gateway.takenUsernames.add('zak');
      expect(await service.checkUsername('z'), contains('au moins 3'));
      expect(await service.checkUsername('zak'), 'Ce pseudo est déjà utilisé.');
      expect(await service.checkUsername('nouveau'), isNull);
      gateway.error = AuthRetryableFetchException(message: 'offline');
      expect(await service.checkUsername('autre'), isNull);
    });

    test('confirmSignUp et resendSignUpCode', () async {
      await expectLater(
          service.confirmSignUp(email: 'zak@example.com', code: '12'),
          throwsA(_failure(CineFailureKind.invalid)));
      await service.confirmSignUp(email: 'zak@example.com', code: ' 123456 ');
      await service.resendSignUpCode(' zak@example.com ');
      expect(gateway.calls, [
        'verifySignUpCode zak@example.com 123456',
        'resendSignUpCode zak@example.com',
      ]);
    });

    test('resetPassword avec code : vérifie puis change le mot de passe',
        () async {
      await service.sendPasswordResetCode('zak@example.com');
      await service.resetPassword(
          email: 'zak@example.com',
          code: '12345678',
          newPassword: 'nouveau123');
      expect(gateway.calls, [
        'sendPasswordResetCode zak@example.com',
        'verifyRecoveryCode zak@example.com 12345678',
        'updatePassword nouveau123',
      ]);
    });

    test('resetPassword sans code exige une session', () async {
      await expectLater(service.resetPassword(newPassword: 'nouveau123'),
          throwsA(_failure(CineFailureKind.unauthenticated)));
      gateway.session = true;
      await service.resetPassword(newPassword: 'nouveau123');
      expect(gateway.calls, ['updatePassword nouveau123']);
    });

    test('resetPassword refuse un mot de passe trop court', () async {
      gateway.session = true;
      await expectLater(service.resetPassword(newPassword: 'court'),
          throwsA(_failure(CineFailureKind.invalid)));
      expect(gateway.calls, isEmpty);
    });

    test('signOut', () async {
      gateway.session = true;
      await service.signOut();
      expect(service.hasSession, isFalse);
    });

    test('debugInstance remplace le service partagé', () {
      AuthService.debugInstance = service;
      addTearDown(() => AuthService.debugInstance = null);
      expect(AuthService.instance, same(service));
    });
  });

  group('SupabaseAuthGateway', () {
    test('inscription avec session : connecté, pseudo dans les métadonnées',
        () async {
      final requests = <http.Request>[];
      final gateway = _gateway((_) => _json(_session()), requests: requests);
      final outcome =
          await gateway.signUp('zak@example.com', 'secret123', username: 'zak');
      expect(outcome, SignUpOutcome.signedIn);
      expect(gateway.hasSession, isTrue);
      expect(requests.single.url.path, '/auth/v1/signup');
      expect(_body(requests.single)['data'], {'username': 'zak'});
    });

    test('inscription à confirmer', () async {
      final gateway = _gateway((_) => _json(_user()));
      expect(
          await gateway.signUp('zak@example.com', 'secret123', username: 'zak'),
          SignUpOutcome.confirmationRequired);
      expect(gateway.hasSession, isFalse);
    });

    test('e-mail déjà inscrit (utilisateur sans identité)', () async {
      final service = AuthService(_gateway((request) =>
          request.url.path.contains('rpc')
              ? _json(true)
              : _json(_user(identities: []))));
      await expectLater(
        service.signUp(
            username: 'zak', email: 'zak@example.com', password: 'secret123'),
        throwsA(_failure(CineFailureKind.conflict,
            'Un compte existe déjà avec cette adresse e-mail.')),
      );
    });

    test('connexion refusée', () async {
      final service = AuthService(_gateway((_) =>
          _authError('invalid_credentials', 'Invalid login credentials')));
      await expectLater(
          service.signIn(email: 'zak@example.com', password: 'mauvais'),
          throwsA(_failure(CineFailureKind.unauthenticated,
              'E-mail ou mot de passe incorrect.')));
    });

    test('connexion réussie', () async {
      final requests = <http.Request>[];
      final gateway = _gateway((_) => _json(_session()), requests: requests);
      await gateway.signIn('zak@example.com', 'secret123');
      expect(gateway.hasSession, isTrue);
      expect(requests.single.url.path, '/auth/v1/token');
      expect(requests.single.url.queryParameters['grant_type'], 'password');
    });

    test('disponibilité du pseudo par RPC', () async {
      final requests = <http.Request>[];
      final gateway = _gateway((_) => _json(false), requests: requests);
      expect(await gateway.isUsernameAvailable('zak'), isFalse);
      expect(requests.single.url.path, '/rest/v1/rpc/username_available');
      expect(_body(requests.single), {'candidate': 'zak'});
    });

    test('codes e-mail : vérification, renvoi, récupération', () async {
      final requests = <http.Request>[];
      final gateway = _gateway(
          (request) => request.url.path.endsWith('/verify')
              ? _json(_session())
              : request.url.path.endsWith('/user')
                  ? _json(_user())
                  : _json(<String, dynamic>{}),
          requests: requests);

      await gateway.verifySignUpCode('zak@example.com', '123456');
      await gateway.resendSignUpCode('zak@example.com');
      await gateway.sendPasswordResetCode('zak@example.com');
      await gateway.verifyRecoveryCode('zak@example.com', '654321');
      await gateway.updatePassword('nouveau123');

      expect(requests.map((r) => r.url.path), [
        '/auth/v1/verify',
        '/auth/v1/resend',
        '/auth/v1/recover',
        '/auth/v1/verify',
        '/auth/v1/user',
      ]);
      expect(_body(requests[0]), containsPair('type', 'signup'));
      expect(_body(requests[0]), containsPair('token', '123456'));
      expect(_body(requests[1]), containsPair('type', 'signup'));
      expect(_body(requests[2]), containsPair('email', 'zak@example.com'));
      expect(_body(requests[3]), containsPair('type', 'recovery'));
      expect(_body(requests[4]), containsPair('password', 'nouveau123'));
    });

    test('déconnexion', () async {
      final gateway = _gateway((request) => request.url.path.endsWith('/logout')
          ? http.Response('', 204)
          : _json(_session()));
      await gateway.signIn('zak@example.com', 'secret123');
      await gateway.signOut();
      expect(gateway.hasSession, isFalse);
    });
  });
}
