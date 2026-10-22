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

  group('validateWatchlistName', () {
    test('valides', () {
      expect(validateWatchlistName('À voir ce week-end'), isNull);
      expect(validateWatchlistName('x' * 60), isNull);
    });
    test('invalides', () {
      expect(validateWatchlistName('   '), 'Donnez un nom à la liste.');
      expect(validateWatchlistName(null), 'Donnez un nom à la liste.');
      expect(validateWatchlistName('x' * 61),
          'Le nom ne doit pas dépasser 60 caractères.');
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
          mapSupabaseError(
                  const PostgrestException(message: 'x', code: '23505'))
              .message,
          'Cet élément existe déjà.');
      expect(
          mapSupabaseError(
                  const PostgrestException(message: 'x', code: '42501'))
              .kind,
          CineFailureKind.forbidden);
      expect(
          mapSupabaseError(
                  const PostgrestException(message: 'x', code: '23514'))
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
        throwsA(isA<CineFailure>()
            .having((f) => f.kind, 'kind', CineFailureKind.unauthenticated)),
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
        throwsA(isA<CineFailure>().having(
            (f) => f.message, 'message', 'Ce pseudo est déjà utilisé.')),
      );
    });

    test('isUsernameAvailable appelle la fonction username_available',
        () async {
      final requests = <http.Request>[];
      final free = _service(
          (r) => http.Response('true', 200,
              headers: {'content-type': 'application/json'}),
          requests: requests);
      expect(await free.isUsernameAvailable(' nouveau '), isTrue);
      expect(requests.single.url.path, '/rest/v1/rpc/username_available');
      expect(jsonDecode(requests.single.body), {'candidate': 'nouveau'});

      final taken = _service((r) => http.Response('false', 200,
          headers: {'content-type': 'application/json'}));
      expect(await taken.isUsernameAvailable('zak'), isFalse);
    });

    test('fetchPublicProfile appelle get_public_profile (sans e-mail)',
        () async {
      final requests = <http.Request>[];
      final service = _service(
          (r) => http.Response(
              jsonEncode([
                {'id': 'u2', 'username': 'bob', 'avatar_url': null, 'bio': 'Hi'}
              ]),
              200,
              headers: {'content-type': 'application/json'}),
          requests: requests);

      final profile = await service.fetchPublicProfile('u2');

      expect(profile?.username, 'bob');
      expect(profile?.email, isNull);
      expect(requests.single.url.path, '/rest/v1/rpc/get_public_profile');

      final none = _service((r) => http.Response('[]', 200,
          headers: {'content-type': 'application/json'}));
      expect(await none.fetchPublicProfile('x'), isNull);
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
      expect(
          request.headers['Prefer'], contains('resolution=merge-duplicates'));
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
      expect(
          await service.fetchGenres(), [const Genre(id: 28, name: 'Action')]);
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

    test("deleteMyAccount retire l'avatar puis supprime le compte", () async {
      final requests = <http.Request>[];
      final service = _service((r) {
        if (r.url.path == '/storage/v1/object/list/avatars') {
          return http.Response(
              jsonEncode([
                {'name': 'avatar.png', 'id': 'f1'},
              ]),
              200,
              headers: {'content-type': 'application/json'});
        }
        if (r.url.path.startsWith('/storage/')) {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 204);
      }, requests: requests);

      await service.deleteMyAccount();

      expect(requests.map((r) => r.url.path), [
        '/storage/v1/object/list/avatars',
        '/storage/v1/object/avatars',
        '/rest/v1/rpc/delete_my_account',
      ]);
      expect(jsonDecode(requests[0].body)['prefix'], _userId);
      expect(jsonDecode(requests[1].body)['prefixes'], ['$_userId/avatar.png']);
    });

    test('deleteMyAccount sans avatar appelle seulement la fonction SQL',
        () async {
      final requests = <http.Request>[];
      final service = _service((r) {
        if (r.url.path.startsWith('/storage/')) {
          return http.Response('[]', 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('', 204);
      }, requests: requests);

      await service.deleteMyAccount();

      expect(requests.map((r) => r.url.path), [
        '/storage/v1/object/list/avatars',
        '/rest/v1/rpc/delete_my_account',
      ]);
    });

    test('deleteMyAccount sans session : erreur, aucune requête', () async {
      final requests = <http.Request>[];
      final service = _service((r) => http.Response('', 204),
          requests: requests, userId: null);

      await expectLater(
          service.deleteMyAccount(),
          throwsA(isA<CineFailure>()
              .having((f) => f.kind, 'kind', CineFailureKind.unauthenticated)));
      expect(requests, isEmpty);
    });

    test("createWatchlist insère la liste de l'utilisateur courant", () async {
      final requests = <http.Request>[];
      final service = _service(
          (r) => _rows(r, [
                {
                  'id': 'w1',
                  'user_id': _userId,
                  'name': 'Films cultes',
                  'description': null,
                  'is_public': false,
                  'created_at': '2026-10-21T10:00:00Z',
                }
              ]),
          requests: requests);

      final list = await service.createWatchlist('  Films cultes ');

      expect(list.name, 'Films cultes');
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/rest/v1/watchlists');
      expect(jsonDecode(requests.single.body),
          {'user_id': _userId, 'name': 'Films cultes'});
    });

    test('createWatchlist valide le nom avant tout appel réseau', () async {
      final requests = <http.Request>[];
      final service = _service((r) => _rows(r, []), requests: requests);

      await expectLater(
        service.createWatchlist('  '),
        throwsA(isA<CineFailure>()
            .having((f) => f.message, 'message', 'Donnez un nom à la liste.')),
      );
      expect(requests, isEmpty);
    });

    test("renameWatchlist met à jour la liste de l'utilisateur", () async {
      final requests = <http.Request>[];
      final service = _service(
          (r) => _rows(r, [
                {
                  'id': 'w1',
                  'user_id': _userId,
                  'name': 'Soirées SF',
                  'created_at': '2026-10-21T10:00:00Z',
                }
              ]),
          requests: requests);

      final list = await service.renameWatchlist('w1', ' Soirées SF ');

      expect(list.name, 'Soirées SF');
      expect(requests.single.method, 'PATCH');
      expect(requests.single.url.queryParameters['id'], 'eq.w1');
      expect(requests.single.url.queryParameters['user_id'], 'eq.$_userId');
      expect(jsonDecode(requests.single.body), {'name': 'Soirées SF'});
    });

    test('renameWatchlist refuse un nom vide sans appel réseau', () async {
      final requests = <http.Request>[];
      final service = _service((r) => _rows(r, []), requests: requests);

      await expectLater(
        service.renameWatchlist('w1', ''),
        throwsA(isA<CineFailure>()
            .having((f) => f.kind, 'kind', CineFailureKind.invalid)),
      );
      expect(requests, isEmpty);
    });

    test("deleteWatchlist supprime la liste de l'utilisateur", () async {
      final requests = <http.Request>[];
      final service =
          _service((r) => http.Response('', 204), requests: requests);

      await service.deleteWatchlist('w1');

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/rest/v1/watchlists');
      expect(requests.single.url.queryParameters['id'], 'eq.w1');
      expect(requests.single.url.queryParameters['user_id'], 'eq.$_userId');
    });

    test('addMediaToWatchlist insère le titre du catalogue', () async {
      final requests = <http.Request>[];
      final service =
          _service((r) => http.Response('', 201), requests: requests);

      await service.addMediaToWatchlist('w1', 'm1');

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/rest/v1/watchlist_items');
      expect(jsonDecode(requests.single.body),
          {'watchlist_id': 'w1', 'media_id': 'm1'});
    });

    test('addMediaToWatchlist : titre déjà présent -> conflit', () async {
      final service = _service((r) => _pgError('23505',
          'duplicate key value violates unique constraint "watchlist_items_media_key"'));

      await expectLater(
        service.addMediaToWatchlist('w1', 'm1'),
        throwsA(isA<CineFailure>()
            .having((f) => f.kind, 'kind', CineFailureKind.conflict)),
      );
    });

    test('removeWatchlistItem supprime la ligne demandée', () async {
      final requests = <http.Request>[];
      final service =
          _service((r) => http.Response('', 204), requests: requests);

      await service.removeWatchlistItem('i1');

      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, '/rest/v1/watchlist_items');
      expect(requests.single.url.queryParameters['id'], 'eq.i1');
    });

    test('fetchMyWatchlists lit les listes du membre, récentes d\'abord',
        () async {
      final requests = <http.Request>[];
      final service = _service(
          (r) => _rows(r, [
                {
                  'id': 'w2',
                  'user_id': _userId,
                  'name': 'Week-end',
                  'created_at': '2026-10-21T11:00:00Z',
                },
                {
                  'id': 'w1',
                  'user_id': _userId,
                  'name': 'À voir',
                  'created_at': '2026-10-21T10:00:00Z',
                },
              ]),
          requests: requests);

      final lists = await service.fetchMyWatchlists();

      expect(lists.map((l) => l.name), ['Week-end', 'À voir']);
      expect(requests.single.url.queryParameters['user_id'], 'eq.$_userId');
      expect(requests.single.url.queryParameters['order'],
          startsWith('created_at.desc'));
    });

    test('watchlistIdsWithMedia renvoie les listes contenant le titre',
        () async {
      final requests = <http.Request>[];
      final service = _service(
          (r) => _rows(r, [
                {'watchlist_id': 'w1'},
                {'watchlist_id': 'w3'},
              ]),
          requests: requests);

      expect(await service.watchlistIdsWithMedia('m1'), {'w1', 'w3'});
      expect(requests.single.url.path, '/rest/v1/watchlist_items');
      expect(requests.single.url.queryParameters['media_id'], 'eq.m1');
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
