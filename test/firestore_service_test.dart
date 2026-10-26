import 'dart:async';

import 'package:cine_sphere/custom_code/actions/firestore_service.dart';
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

  test('identifiants déterministes', () {
    expect(userMediaDocId('u1', 'm1'), 'u1_m1');
    expect(watchlistItemDocId('w1', 'm1'), 'w1_m1');
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
    final service = FirestoreService(_UnusedDb(), currentUserId: () => null);
    expect(() => service.requireUserId,
        throwsA(isA<CineFailure>().having(
            (f) => f.kind, 'kind', CineFailureKind.unauthenticated)));
    expect(
        FirestoreService(_UnusedDb(), currentUserId: () => 'u1').requireUserId,
        'u1');
  });
}

class _UnusedDb extends Mock implements FirebaseFirestore {}
