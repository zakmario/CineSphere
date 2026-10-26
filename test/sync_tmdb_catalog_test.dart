import 'package:cine_sphere/backend/api_requests/api_calls.dart';
import 'package:cine_sphere/custom_code/actions/firestore_service.dart';
import 'package:cine_sphere/custom_code/actions/sync_tmdb_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

ApiCallResponse _ok(List<Map<String, dynamic>> results) =>
    ApiCallResponse({'page': 1, 'results': results, 'total_pages': 1}, {}, 200);

const _film = {
  'id': 693134,
  'title': 'Dune : Deuxième partie',
  'overview': 'Paul Atréides...',
  'poster_path': '/poster.jpg',
  'backdrop_path': '/fond.jpg',
  'release_date': '2024-02-27',
  'vote_average': 8.1,
  'popularity': 312.7,
  'genre_ids': [878, 12],
};

const _serie = {
  'id': 94605,
  'name': 'Arcane',
  'poster_path': null,
  'first_air_date': '2021-11-06',
  'vote_average': 8.7,
  'popularity': 80.2,
  'genre_ids': [16],
};

void main() {
  group('tmdbToMediaPayload', () {
    test('film : URLs des images, date et genres', () {
      final p = tmdbToMediaPayload(_film, type: 'movie')!;
      expect(p['media_type'], 'movie');
      expect(p['tmdb_id'], 693134);
      expect(p['title'], 'Dune : Deuxième partie');
      expect(p['poster_url'], 'https://image.tmdb.org/t/p/w500/poster.jpg');
      expect(p['backdrop_url'], 'https://image.tmdb.org/t/p/w1280/fond.jpg');
      expect(p['release_date'], '2024-02-27');
      expect(p['genre_ids'], [878, 12]);
    });

    test('série : name, first_air_date, image absente', () {
      final p = tmdbToMediaPayload(_serie, type: 'tv')!;
      expect(p['media_type'], 'series');
      expect(p['title'], 'Arcane');
      expect(p['release_date'], '2021-11-06');
      expect(p['poster_url'], isNull);
    });

    test('tendances : le type vient de media_type, les personnes sont ignorées',
        () {
      expect(tmdbToMediaPayload({..._serie, 'media_type': 'tv'})!['media_type'],
          'series');
      expect(
          tmdbToMediaPayload(
              {'id': 1, 'name': 'Zendaya', 'media_type': 'person'}),
          isNull);
      expect(
          tmdbToMediaPayload({'id': 2, 'title': ' '}, type: 'movie'), isNull);
      expect(tmdbToMediaPayload({'title': 'Sans id'}, type: 'movie'), isNull);
    });

    test('date vide : null', () {
      expect(
          tmdbToMediaPayload({..._film, 'release_date': ''},
              type: 'movie')!['release_date'],
          isNull);
    });
  });

  group('TmdbCatalogImporter', () {
    test('fusionne les listes sans doublon et enregistre', () async {
      final saved = <List<Map<String, dynamic>>>[];
      final importer = TmdbCatalogImporter(
        loadIncomplete: () async => [],
        sources: [
          (
            type: null,
            fetch: () async => _ok([
                  {..._film, 'media_type': 'movie'},
                  {'id': 9, 'name': 'Une personne', 'media_type': 'person'},
                ])
          ),
          (type: 'movie', fetch: () async => _ok([_film])),
          (type: 'tv', fetch: () async => _ok([_serie])),
        ],
        save: (items) async {
          saved.add(items);
          return items.length;
        },
      );

      expect(await importer.run(), 2);
      expect(saved, hasLength(1));
      expect(saved.single.map((p) => '${p['media_type']}:${p['tmdb_id']}'),
          ['movie:693134', 'series:94605']);
    });

    test('envoie par lots de 200', () async {
      final sizes = <int>[];
      final many = [
        for (var i = 1; i <= 450; i++) {'id': i, 'title': 'Film $i'}
      ];
      final importer = TmdbCatalogImporter(
        loadIncomplete: () async => [],
        sources: [(type: 'movie', fetch: () async => _ok(many))],
        save: (items) async {
          sizes.add(items.length);
          return items.length;
        },
      );

      expect(await importer.run(), 450);
      expect(sizes, [200, 200, 50]);
    });

    test('une liste en erreur est ignorée', () async {
      final importer = TmdbCatalogImporter(
        loadIncomplete: () async => [],
        sources: [
          (
            type: 'movie',
            fetch: () async => const ApiCallResponse(null, {}, 500)
          ),
          (type: 'tv', fetch: () async => _ok([_serie])),
        ],
        save: (items) async => items.length,
      );

      expect(await importer.run(), 1);
    });

    test('TMDB injoignable : CineFailure réseau, rien enregistré', () async {
      var saveCalled = false;
      final importer = TmdbCatalogImporter(
        loadIncomplete: () async => [],
        sources: [
          (
            type: 'movie',
            fetch: () async => const ApiCallResponse(null, {}, -1)
          ),
          (
            type: 'tv',
            fetch: () async => const ApiCallResponse({'x': 1}, {}, 401)
          ),
        ],
        save: (items) async {
          saveCalled = true;
          return 0;
        },
      );

      await expectLater(
          importer.run(),
          throwsA(isA<CineFailure>()
              .having((f) => f.kind, 'kind', CineFailureKind.network)));
      expect(saveCalled, isFalse);
    });
  });

  group('pickTrailerUrl', () {
    test('bande-annonce française, puis autre langue, puis teaser', () {
      final videos = [
        {
          'site': 'YouTube',
          'type': 'Teaser',
          'key': 'teaser',
          'iso_639_1': 'fr'
        },
        {'site': 'YouTube', 'type': 'Trailer', 'key': 'en', 'iso_639_1': 'en'},
        {'site': 'YouTube', 'type': 'Trailer', 'key': 'fr', 'iso_639_1': 'fr'},
        {'site': 'Vimeo', 'type': 'Trailer', 'key': 'vimeo', 'iso_639_1': 'fr'},
      ];
      expect(pickTrailerUrl(videos), 'https://www.youtube.com/watch?v=fr');
      expect(pickTrailerUrl(videos.sublist(0, 2)),
          'https://www.youtube.com/watch?v=en');
      expect(pickTrailerUrl(videos.sublist(0, 1)),
          'https://www.youtube.com/watch?v=teaser');
    });

    test('rien d\'exploitable : null', () {
      expect(pickTrailerUrl(null), isNull);
      expect(
          pickTrailerUrl([
            {'site': 'YouTube', 'type': 'Featurette', 'key': 'x'},
            {'site': 'Vimeo', 'type': 'Trailer', 'key': 'y'},
          ]),
          isNull);
    });
  });

  group('tmdbDetailsPayload', () {
    test('film : durée, bande-annonce, plateformes en France', () {
      final p = tmdbDetailsPayload((
        kind: 'movie',
        tmdbId: 693134
      ), {
        'runtime': 167,
        'status': 'Released',
        'videos': {
          'results': [
            {
              'site': 'YouTube',
              'type': 'Trailer',
              'key': 'abc',
              'iso_639_1': 'fr'
            },
          ]
        },
        'watch/providers': {
          'results': {
            'FR': {
              'flatrate': [
                {'provider_id': 8, 'provider_name': 'Netflix'},
                {
                  'provider_id': 1796,
                  'provider_name': 'Netflix Standard with Ads'
                },
              ]
            },
            'US': {
              'flatrate': [
                {'provider_id': 1899, 'provider_name': 'Max'},
              ]
            },
          }
        },
      });
      expect(p['media_type'], 'movie');
      expect(p['runtime_minutes'], 167);
      expect(p['ended'], isFalse);
      expect(p['trailer_url'], 'https://www.youtube.com/watch?v=abc');
      expect(p['providers'], [
        {'id': 8, 'name': 'Netflix'},
      ]);
    });

    test('série terminée sans plateforme en France', () {
      final p = tmdbDetailsPayload((
        kind: 'series',
        tmdbId: 1396
      ), {
        'number_of_seasons': 5,
        'number_of_episodes': 62,
        'status': 'Ended',
        'watch/providers': {'results': {}},
      });
      expect(p['seasons'], 5);
      expect(p['episodes'], 62);
      expect(p['ended'], isTrue);
      expect(p['trailer_url'], isNull);
      expect(p['providers'], isEmpty);
    });
  });

  group('TmdbCatalogImporter.completeDetails', () {
    test('appelle le bon détail par titre et ignore les échecs', () async {
      final called = <String>[];
      final saved = <Map<String, dynamic>>[];
      final importer = TmdbCatalogImporter(
        sources: const [],
        loadIncomplete: () async => [
          (kind: 'movie', tmdbId: 1),
          (kind: 'series', tmdbId: 2),
          (kind: 'movie', tmdbId: 3),
        ],
        fetchDetails: (title) async {
          called.add('${title.kind}:${title.tmdbId}');
          return title.tmdbId == 3
              ? const ApiCallResponse(null, {}, 404)
              : const ApiCallResponse(
                  {'runtime': 100, 'number_of_seasons': 2}, {}, 200);
        },
        saveDetails: (items) async {
          saved.addAll(items);
          return items.length;
        },
      );

      expect(await importer.completeDetails(), 2);
      expect(called, ['movie:1', 'series:2', 'movie:3']);
      expect(saved.map((p) => '${p['media_type']}:${p['tmdb_id']}'),
          ['movie:1', 'series:2']);
    });

    test('rien à compléter : aucun enregistrement', () async {
      var saveCalled = false;
      final importer = TmdbCatalogImporter(
        sources: const [],
        loadIncomplete: () async => [],
        saveDetails: (items) async {
          saveCalled = true;
          return 0;
        },
      );

      expect(await importer.completeDetails(), 0);
      expect(saveCalled, isFalse);
    });

    test('run enregistre les listes même si les détails échouent', () async {
      final importer = TmdbCatalogImporter(
        sources: [
          (type: 'tv', fetch: () async => _ok([_serie]))
        ],
        save: (items) async => items.length,
        loadIncomplete: () async => throw const CineFailure(
            CineFailureKind.network, 'Firestore injoignable'),
      );

      expect(await importer.run(), 1);
    });
  });
}
