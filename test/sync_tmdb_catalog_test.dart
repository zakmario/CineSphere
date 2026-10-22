import 'package:cine_sphere/backend/api_requests/api_calls.dart';
import 'package:cine_sphere/custom_code/actions/supabase_service.dart';
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
}
