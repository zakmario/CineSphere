import 'dart:async';

import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// Simulacre de test : DocumentSnapshot est scellée mais sans implémentation
// publique utilisable hors de Firestore.
// ignore: subtype_of_sealed_class
class _Doc extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

DocumentSnapshot<Map<String, dynamic>> _doc(
    String id, Map<String, dynamic>? data) {
  final doc = _Doc();
  when(() => doc.id).thenReturn(id);
  when(() => doc.data()).thenReturn(data);
  return doc;
}

void main() {
  group('pageRange', () {
    test('pages de 20 par défaut', () {
      expect(pageRange(0), (from: 0, to: 19));
      expect(pageRange(2), (from: 40, to: 59));
    });

    test('taille personnalisée', () {
      expect(pageRange(1, pageSize: 5), (from: 5, to: 9));
    });
  });

  group('validateUsername', () {
    test('valides', () {
      for (final name in ['zak', 'Zak_22', 'a.b-c', 'x' * 24]) {
        expect(validateUsername(name), isNull, reason: name);
      }
    });

    test('trop court, trop long, caractères interdits', () {
      expect(validateUsername('ab'), contains('au moins 3'));
      expect(validateUsername('x' * 25), contains('24'));
      expect(validateUsername('zak !'), isNotNull);
      expect(validateUsername(null), isNotNull);
    });
  });

  group('validateWatchlistName', () {
    test('valides', () {
      expect(validateWatchlistName('À voir'), isNull);
      expect(validateWatchlistName('x' * 60), isNull);
    });

    test('invalides', () {
      expect(validateWatchlistName('  '), 'Donnez un nom à la liste.');
      expect(validateWatchlistName('x' * 61), contains('60'));
    });
  });

  group('cineRow', () {
    test('clés snake_case, dates ISO, id du document', () {
      final row = cineRow(_doc('m1', {
        'mediaType': 'movie',
        'posterUrl': 'https://img/p.jpg',
        'releaseDate': Timestamp.fromDate(DateTime.utc(2026, 11, 25)),
        'genres': ['Action', 'Drame'],
        'id': 'ignoré',
      }));
      expect(row, {
        'media_type': 'movie',
        'poster_url': 'https://img/p.jpg',
        'release_date': '2026-11-25T00:00:00.000Z',
        'genres': ['Action', 'Drame'],
        'id': 'm1',
      });
    });

    test('document absent : seulement l\'id', () {
      expect(cineRow(_doc('x', null)), {'id': 'x'});
    });
  });

  test('toFirestoreFields : camelCase, dates en Timestamp, sans id', () {
    final fields = toFirestoreFields({
      'id': 'w1',
      'is_public': false,
      'created_at': '2026-10-20T09:30:00.000Z',
      'favorite_genres': [28, 18],
    });
    expect(fields.keys, ['isPublic', 'createdAt', 'favoriteGenres']);
    expect((fields['createdAt'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 20, 9, 30));
  });

  group('clé de titre (movie_550)', () {
    test('mediaKey et parseMediaKey', () {
      expect(mediaKey('movie', 550), 'movie_550');
      expect(mediaKey('series', 1399), 'series_1399');
      expect(parseMediaKey('series_1399'), (type: 'series', tmdbId: 1399));
      for (final bad in [null, '', 'movie_', 'film_550', 'movie_55a', '550']) {
        expect(parseMediaKey(bad), isNull, reason: bad);
      }
    });

    test('collection du catalogue', () {
      expect(catalogCollection('movie'), 'movies');
      expect(catalogCollection('series'), 'series');
    });
  });

  group('catalogRow', () {
    test('film : clé, durée, genres nommés', () {
      final row = catalogRow(
          'movie',
          _doc('550', {
            'tmdbId': 550,
            'title': 'Fight Club',
            'description': 'Un employé…',
            'posterUrl': 'https://img/p.jpg',
            'releaseDate': Timestamp.fromDate(DateTime.utc(1999, 11, 10)),
            'duration': 139,
            'rating': 8.4,
            'genreIds': [18, 99999],
            'platforms': ['Netflix'],
          }),
          {18: 'Drame'});
      expect(row['id'], 'movie_550');
      expect(row['media_type'], 'movie');
      expect(row['overview'], 'Un employé…');
      expect(row['release_date'], '1999-11-10T00:00:00.000Z');
      expect(row['runtime_minutes'], 139);
      expect(row['seasons'], isNull);
      expect(row['genres'], ['Drame']);
      expect(row['platforms'], ['Netflix']);
    });

    test('série : première diffusion, saisons et épisodes', () {
      final row = catalogRow(
          'series',
          _doc('1399', {
            'tmdbId': 1399,
            'title': 'Game of Thrones',
            'firstAirDate': Timestamp.fromDate(DateTime.utc(2011, 4, 17)),
            'numberOfSeasons': 8,
            'numberOfEpisodes': 73,
            'status': 'ended',
          }));
      expect(row['id'], 'series_1399');
      expect(row['release_date'], '2011-04-17T00:00:00.000Z');
      expect((row['seasons'], row['episodes']), (8, 73));
      expect(row['runtime_minutes'], isNull);
      expect(row['rating'], 0);
    });

    test('mediaSummary : champs dénormalisés', () {
      expect(
          mediaSummary({
            'media_type': 'movie',
            'tmdb_id': 550,
            'title': 'Fight Club',
            'poster_url': 'p',
          }),
          {
            'mediaType': 'movie',
            'tmdbId': 550,
            'title': 'Fight Club',
            'posterUrl': 'p',
          });
    });
  });

  test('validateReview : note 1-10, 2000 caractères', () {
    expect(validateReview(7, 'Bien'), isNull);
    expect(validateReview(10, null), isNull);
    expect(validateReview(0, ''), isNotNull);
    expect(validateReview(11, ''), isNotNull);
    expect(validateReview(5, 'x' * 2001), contains('2000'));
  });

  group('mapFirestoreError', () {
    test('codes Firestore', () {
      final cases = {
        'permission-denied': CineFailureKind.forbidden,
        'unauthenticated': CineFailureKind.unauthenticated,
        'already-exists': CineFailureKind.conflict,
        'not-found': CineFailureKind.notFound,
        'invalid-argument': CineFailureKind.invalid,
        'unavailable': CineFailureKind.network,
        'internal': CineFailureKind.unknown,
      };
      cases.forEach((code, kind) {
        expect(
            mapFirestoreError(
                    FirebaseException(plugin: 'cloud_firestore', code: code))
                .kind,
            kind,
            reason: code);
      });
    });

    test('réseau', () {
      expect(mapFirestoreError(TimeoutException('lent')).kind,
          CineFailureKind.network);
      expect(mapFirestoreError(http.ClientException('offline')).kind,
          CineFailureKind.network);
    });

    test('inconnue et déjà typée', () {
      expect(mapFirestoreError(StateError('?')).kind, CineFailureKind.unknown);
      const failure = CineFailure(CineFailureKind.conflict, 'déjà');
      expect(identical(mapFirestoreError(failure), failure), isTrue);
    });
  });

  test('requireUserId sans session : CineFailure unauthenticated', () {
    final service = CineFirebaseService(_UnusedDb(), currentUserId: () => null);
    expect(() => service.requireUserId,
        throwsA(isA<CineFailure>().having(
            (f) => f.kind, 'kind', CineFailureKind.unauthenticated)));
    expect(
        CineFirebaseService(_UnusedDb(), currentUserId: () => 'u1').requireUserId,
        'u1');
  });
}

class _UnusedDb extends Mock implements FirebaseFirestore {}
