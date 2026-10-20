import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:cine_sphere/custom_code/actions/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = 'https://test.supabase.co';
const _userId = '11111111-1111-1111-1111-111111111111';

/// Client Supabase dont les réponses HTTP sont simulées par [handler].
/// Chaque requête reçue est ajoutée à [requests].
SupabaseService _service(
  FutureOr<http.Response> Function(http.Request request) handler, {
  List<http.Request>? requests,
  String? userId = _userId,
}) {
  final client = SupabaseClient(
    _url,
    'anon-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      requests?.add(request);
      final response = await handler(request);
      // postgrest lit response.request.
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers, request: request);
    }),
  );
  return SupabaseService(client, currentUserId: () => userId);
}

/// Réponse PostgREST : objet si `.single()/.maybeSingle()`, sinon liste.
http.Response _rows(http.Request request, List<Map<String, dynamic>> rows) {
  final wantsObject =
      request.headers['Accept']?.contains('vnd.pgrst.object') ?? false;
  return http.Response(
    jsonEncode(wantsObject ? rows.first : rows),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

http.Response _pgError(String code, String message, {int status = 409}) =>
    http.Response(
      jsonEncode({'code': code, 'message': message, 'details': null}),
      status,
      headers: {'content-type': 'application/json'},
    );

final _profileRow = {
  'id': _userId,
  'username': 'zak',
  'email': 'zak@example.com',
  'avatar_url': null,
  'bio': null,
  'role': 'user',
  'created_at': '2026-10-20T09:30:00Z',
  'updated_at': '2026-10-20T09:30:00Z',
};

void main() {
  group('pageRange', () {
    test('pages de 20 par défaut', () {
      expect(pageRange(0), (from: 0, to: 19));
      expect(pageRange(2), (from: 40, to: 59));
    });
    test('taille personnalisée', () {
      expect(pageRange(1, pageSize: 10), (from: 10, to: 19));
    });
  });

  group('validateUsername', () {
    test('valides', () {
      for (final name in ['zak', 'zak_22', 'jean.dupont', 'a-b-c']) {
        expect(validateUsername(name), isNull, reason: name);
      }
    });
    test('trop court, trop long, caractères interdits', () {
      expect(validateUsername('ab'), contains('3 caractères'));
      expect(validateUsername(null), contains('3 caractères'));
      expect(validateUsername('a' * 25), contains('24 caractères'));
      expect(validateUsername('zak!'), contains('lettres'));
      expect(validateUsername('zak akh'), contains('lettres'));
    });
  });

  group('avatarStoragePath', () {
    test('dossier de l\'utilisateur et extension normalisée', () {
      expect(avatarStoragePath('u1', 'PNG'), 'u1/avatar.png');
      expect(avatarStoragePath('u1', '.jpeg'), 'u1/avatar.jpg');
      expect(avatarStoragePath('u1', 'gif'), 'u1/avatar.jpg');
    });
  });

  group('mapSupabaseError', () {
    test('pseudo déjà pris', () {
      final failure = mapSupabaseError(const PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"profiles_username_key"',
        code: '23505',
      ));
      expect(failure.kind, CineFailureKind.conflict);
      expect(failure.message, 'Ce pseudo est déjà utilisé.');
    });

    test('autres doublons, droits, données invalides, introuvable', () {
      expect(
          mapSupabaseError(const PostgrestException(message: 'x', code: '23505'))
              .message,
          'Cet élément existe déjà.');
      expect(
          mapSupabaseError(const PostgrestException(message: 'x', code: '42501'))
              .kind,
          CineFailureKind.forbidden);
      expect(
          mapSupabaseError(const PostgrestException(message: 'x', code: '23514'))
              .kind,
          CineFailureKind.invalid);
      expect(
          mapSupabaseError(
                  const PostgrestException(message: 'x', code: 'PGRST116'))
              .kind,
          CineFailureKind.notFound);
    });

    test('session expirée', () {
      expect(mapSupabaseError(const AuthException('expired')).kind,
          CineFailureKind.unauthenticated);
      expect(
          mapSupabaseError(
                  const PostgrestException(message: 'JWT', code: 'PGRST301'))
              .kind,
          CineFailureKind.unauthenticated);
    });

    test('réseau', () {
      expect(mapSupabaseError(TimeoutException('lent')).kind,
          CineFailureKind.network);
      expect(mapSupabaseError(http.ClientException('offline')).kind,
          CineFailureKind.network);
    });

    test('Storage', () {
      expect(
          mapSupabaseError(const StorageException('big', statusCode: '413'))
              .message,
          contains('2 Mo'));
      expect(
          mapSupabaseError(const StorageException('no', statusCode: '403'))
              .kind,
          CineFailureKind.forbidden);
    });

    test('inconnue et déjà typée', () {
      expect(mapSupabaseError(StateError('?')).kind, CineFailureKind.unknown);
      const failure = CineFailure(CineFailureKind.invalid, 'déjà typée');
      expect(identical(mapSupabaseError(failure), failure), isTrue);
    });
  });

  group('SupabaseService', () {
    test('fetchProfile lit la ligne de l\'utilisateur courant', () async {
      final requests = <http.Request>[];
      final service =
          _service((r) => _rows(r, [_profileRow]), requests: requests);

      final profile = await service.fetchProfile();

      expect(profile?.username, 'zak');
      expect(requests.single.url.path, '/rest/v1/profiles');
      expect(requests.single.url.queryParameters['id'], 'eq.$_userId');
    });

    test('fetchProfile renvoie null si la ligne n\'existe pas', () async {
      final service = _service((r) => http.Response('[]', 200,
          headers: {'content-type': 'application/json'}));
      expect(await service.fetchProfile(), isNull);
    });

    test('sans session : CineFailure unauthenticated, aucune requête',
        () async {
      final requests = <http.Request>[];
      final service = _service((r) => _rows(r, [_profileRow]),
          requests: requests, userId: null);

      await expectLater(
        service.fetchPreferences(),
        throwsA(isA<CineFailure>().having(
            (f) => f.kind, 'kind', CineFailureKind.unauthenticated)),
      );
      expect(requests, isEmpty);
    });

    test('updateProfile valide le pseudo avant tout appel réseau', () async {
      final requests = <http.Request>[];
      final service =
          _service((r) => _rows(r, [_profileRow]), requests: requests);

      await expectLater(
        service.updateProfile(username: 'a!'),
        throwsA(isA<CineFailure>()
            .having((f) => f.kind, 'kind', CineFailureKind.invalid)),
      );
      expect(requests, isEmpty);
    });

    test('updateProfile envoie uniquement les champs modifiés', () async {
      final requests = <http.Request>[];
      final service = _service(
          (r) => _rows(r, [
                {..._profileRow, 'username': 'zakaria', 'bio': null}
              ]),
          requests: requests);

      final profile =
          await service.updateProfile(username: ' zakaria ', bio: '   ');

      expect(profile.username, 'zakaria');
      expect(requests.single.method, 'PATCH');
      expect(jsonDecode(requests.single.body),
          {'username': 'zakaria', 'bio': null});
    });

    test('updateProfile traduit le conflit de pseudo', () async {
      final service = _service((r) => _pgError('23505',
          'duplicate key value violates unique constraint "profiles_username_key"'));

      await expectLater(
        service.updateProfile(username: 'pris'),
        throwsA(isA<CineFailure>()
            .having((f) => f.message, 'message', 'Ce pseudo est déjà utilisé.')),
      );
    });

    test('isUsernameAvailable interroge la vue publique', () async {
      final requests = <http.Request>[];
      final free = _service((r) => _rows(r, []), requests: requests);
      expect(await free.isUsernameAvailable('nouveau'), isTrue);
      expect(requests.single.url.path, '/rest/v1/public_profiles');

      final taken = _service((r) => _rows(r, [
            {'id': 'autre'}
          ]));
      expect(await taken.isUsernameAvailable('zak'), isFalse);

      final mine = _service((r) => _rows(r, [
            {'id': _userId}
          ]));
      expect(await mine.isUsernameAvailable('zak'), isTrue);
    });

    test('fetchPreferences : valeurs par défaut si aucune ligne', () async {
      final service = _service((r) => http.Response('[]', 200,
          headers: {'content-type': 'application/json'}));
      final prefs = await service.fetchPreferences();
      expect(prefs, const UserPreferences(userId: _userId));
    });

    test('savePreferences fait un upsert sur user_preferences', () async {
      final requests = <http.Request>[];
      final prefs = const UserPreferences(userId: 'ignoré')
          .copyWith(favoriteGenres: [28], onboardingCompleted: true);
      final service = _service(
          (r) => _rows(r, [
                {...prefs.toJson(), 'user_id': _userId}
              ]),
          requests: requests);

      final saved = await service.savePreferences(prefs);

      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/user_preferences');
      expect(request.headers['Prefer'], contains('resolution=merge-duplicates'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['user_id'], _userId);
      expect(body.containsKey('updated_at'), isFalse);
      expect(saved.favoriteGenres, [28]);
      expect(saved.onboardingCompleted, isTrue);
    });

    test('fetchGenres et fetchPlatforms', () async {
      final service = _service((r) => _rows(
          r,
          r.url.path.endsWith('genres')
              ? [
                  {'id': 28, 'name': 'Action'}
                ]
              : [
                  {'id': 8, 'name': 'Netflix', 'logo_url': null}
                ]));
      expect(await service.fetchGenres(), [const Genre(id: 28, name: 'Action')]);
      expect(await service.fetchPlatforms(),
          [const Platform(id: 8, name: 'Netflix')]);
    });

    test('cacheMovie / cacheSeries appellent les fonctions RPC', () async {
      final requests = <http.Request>[];
      final service = _service(
          (r) => http.Response('"uuid-1"', 200,
              headers: {'content-type': 'application/json'}),
          requests: requests);

      final movieId = await service.cacheMovie(
          const Movie(tmdbId: 27205, title: 'Inception', genreIds: [28]));
      final seriesId =
          await service.cacheSeries(const Series(tmdbId: 70523, title: 'Dark'));

      expect(movieId, 'uuid-1');
      expect(seriesId, 'uuid-1');
      expect(requests[0].url.path, '/rest/v1/rpc/upsert_movie_from_tmdb');
      expect(requests[1].url.path, '/rest/v1/rpc/upsert_series_from_tmdb');
      final payload =
          (jsonDecode(requests[0].body) as Map<String, dynamic>)['payload'];
      expect(payload['tmdb_id'], 27205);
      expect(payload['genre_ids'], [28]);
      expect((payload as Map).containsKey('id'), isFalse);
    });

    test('uploadAvatar écrit dans avatars/{user_id}/ puis met à jour le profil',
        () async {
      final requests = <http.Request>[];
      final service = _service((r) {
        if (r.url.path.startsWith('/storage/')) {
          return http.Response(jsonEncode({'Key': 'avatars/x'}), 200,
              headers: {'content-type': 'application/json'});
        }
        return _rows(r, [_profileRow]);
      }, requests: requests);

      final url = await service.uploadAvatar(Uint8List.fromList([1, 2, 3]),
          extension: 'png');

      expect(requests.first.url.path,
          '/storage/v1/object/avatars/$_userId/avatar.png');
      expect(requests.first.headers['x-upsert'], 'true');
      expect(url, startsWith('$_url/storage/v1/object/public/avatars/'));
      expect(url, contains('$_userId/avatar.png?v='));
      final update = requests.last;
      expect(update.url.path, '/rest/v1/profiles');
      expect(jsonDecode(update.body)['avatar_url'], url);
    });

    test('erreur réseau -> CineFailure network', () async {
      final service =
          _service((r) => throw http.ClientException('Network is unreachable'));
      await expectLater(
        service.fetchGenres(),
        throwsA(isA<CineFailure>()
            .having((f) => f.kind, 'kind', CineFailureKind.network)),
      );
    });
  });
}
