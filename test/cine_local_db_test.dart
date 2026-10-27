import 'dart:io';

import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_firebase_service.dart';

/// Service Firestore simulé : catalogue renvoyé par [catalog] (ou erreur).
class _CatalogService extends FakeCineFirebaseService {
  List<Map<String, dynamic>> rows = [];
  bool offline = false;
  int catalogCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> catalog({bool refresh = false}) async {
    catalogCalls++;
    if (offline) {
      throw const CineFailure(
          CineFailureKind.network, 'Pas de connexion Internet.');
    }
    return rows;
  }
}

Map<String, dynamic> media(String key, {String? title, num popularity = 0}) {
  final parsed = parseMediaKey(key)!;
  return {
    'id': key,
    'media_type': parsed.type,
    'tmdb_id': parsed.tmdbId,
    'title': title ?? key,
    'poster_url': 'https://image.tmdb.org/$key.jpg',
    'release_date': '2026-11-01T00:00:00.000Z',
    'rating': 7.5,
    'popularity': popularity,
    'genres': ['Drame'],
  };
}

Map<String, dynamic> event(String id, String key, DateTime at,
    {String? platform}) {
  final parsed = parseMediaKey(key)!;
  return {
    'id': id,
    'media_type': parsed.type,
    'tmdb_id': parsed.tmdbId,
    'title': 'Sortie $id',
    'poster_url': null,
    'release_date': at.toUtc().toIso8601String(),
    'platform': platform,
    'season_number': parsed.type == 'series' ? 1 : null,
    'episode_number': parsed.type == 'series' ? 2 : null,
  };
}

PendingSyncOperation op(
  SyncOperation operation,
  String docId, {
  Map<String, dynamic> payload = const {},
  String userId = 'u1',
  String collection = 'users/u1/favorites',
}) =>
    PendingSyncOperation(
      userId: userId,
      operation: operation,
      collection: collection,
      docId: docId,
      payload: payload,
      createdAt: DateTime.utc(2026, 10, 27),
    );

void main() {
  sqfliteFfiInit();

  var clock = DateTime.utc(2026, 10, 27, 12);
  late _CatalogService remote;
  late CineLocalDb db;

  setUp(() {
    clock = DateTime.utc(2026, 10, 27, 12);
    remote = _CatalogService();
    db = CineLocalDb(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
      remote: remote,
      now: () => clock,
    );
  });

  tearDown(() => db.close());

  group('schéma', () {
    test('version 1 : toutes les tables du cahier des charges', () async {
      final database = await db.database;
      final tables = (await database.query('sqlite_master',
              columns: ['name'], where: "type = 'table'"))
          .map((r) => r['name'])
          .toSet();
      expect(
          tables,
          containsAll([
            'cached_movies',
            'cached_series',
            'cached_home_sections',
            'local_favorites',
            'recent_searches',
            'calendar_events',
            'pending_sync',
          ]));
      expect(await database.getVersion(), 1);
      expect(db.version, kLocalDbMigrations.length);
    });

    test(
        'onUpgrade : seules les migrations manquantes sont jouées, '
        'les données sont gardées', () async {
      final dir = await Directory.systemTemp.createTemp('cinesphere_db');
      final path = '${dir.path}/$kLocalDbName';
      try {
        final v1 = CineLocalDb(factory: databaseFactoryFfi, path: path);
        await v1.saveCatalog([media('movie_550')]);
        await v1.close();

        final v2 = CineLocalDb(
          factory: databaseFactoryFfi,
          path: path,
          migrations: [
            ...kLocalDbMigrations,
            ['ALTER TABLE cached_movies ADD COLUMN trailer_url TEXT'],
          ],
        );
        final database = await v2.database;
        expect(await database.getVersion(), 2);
        final columns =
            (await database.rawQuery('PRAGMA table_info(cached_movies)'))
                .map((c) => c['name']);
        expect(columns, contains('trailer_url'));
        expect((await v2.readMedia('movie_550'))?.value['title'], 'movie_550');
        await v2.close();
      } finally {
        await dir.delete(recursive: true);
      }
    });

    test('web : rien n\'est gardé, le réseau est utilisé', () async {
      final web = CineLocalDb(supported: false, remote: remote);
      remote.rows = [media('movie_1')];
      await web.saveCatalog([media('movie_550')]);
      expect(await web.readCatalog(), isNull);
      expect(await web.enqueuePending(op(SyncOperation.set, 'movie_1')), 0);
      expect(await web.cacheSizeBytes(), 0);

      final results = await web.watchCatalog().toList();
      expect(results.single.source, CacheSource.network);
      expect(results.single.data.single['id'], 'movie_1');
    });
  });

  group('catalogue en cache', () {
    test('films et séries rangés dans leur table, relus par popularité',
        () async {
      await db.saveCatalog([
        media('movie_550', popularity: 10),
        media('series_1399', popularity: 50),
      ]);
      final database = await db.database;
      expect((await database.query('cached_movies')).single['tmdb_id'], 550);
      expect((await database.query('cached_series')).single['tmdb_id'], 1399);

      final cached = await db.readCatalog();
      expect(cached!.value.map((r) => r['id']), ['series_1399', 'movie_550']);
      expect(cached.value.first['genres'], ['Drame']);
      expect(cached.cachedAt, clock);
    });

    test('replaceAll retire les titres disparus du catalogue', () async {
      await db.saveCatalog([media('movie_1'), media('movie_2')]);
      await db
          .saveCatalog([media('movie_2', title: 'Nouveau')], replaceAll: true);
      final cached = await db.readCatalog();
      expect(cached!.value.single['title'], 'Nouveau');
    });

    test('la date du catalogue est celle du titre le plus ancien', () async {
      await db.saveCatalog([media('movie_1'), media('movie_2')]);
      final first = clock;
      clock = clock.add(const Duration(hours: 30));
      await db.saveCatalog([media('movie_2')]);
      expect((await db.readCatalog())!.cachedAt, first);
      expect((await db.readMedia('movie_2'))!.cachedAt, clock);
    });

    test('sections de l\'accueil', () async {
      await db.saveHomeSection('trending', [media('movie_550')]);
      final cached = await db.readHomeSection('trending');
      expect(cached!.value.single['id'], 'movie_550');
      expect(await db.readHomeSection('upcoming'), isNull);
    });
  });

  group('cache puis réseau (TTL 24 h)', () {
    test('sans cache : réseau, puis enregistré', () async {
      remote.rows = [media('movie_550')];
      final results = await db.watchCatalog().toList();
      expect(results.map((r) => r.source), [CacheSource.network]);
      expect((await db.readCatalog())!.value.single['id'], 'movie_550');
    });

    test('cache frais : affiché seul, Firestore n\'est pas lu', () async {
      await db.saveCatalog([media('movie_550')]);
      clock = clock.add(const Duration(hours: 23));
      final results = await db.watchCatalog().toList();
      expect(results.single.source, CacheSource.cache);
      expect(results.single.isStale, isFalse);
      expect(remote.catalogCalls, 0);
    });

    test('cache périmé : cache tout de suite, puis réseau', () async {
      await db.saveCatalog([media('movie_100')]);
      clock = clock.add(const Duration(hours: 25));
      remote.rows = [media('movie_200')];
      final results = await db.watchCatalog().toList();
      expect(results.map((r) => r.source),
          [CacheSource.cache, CacheSource.network]);
      expect(results.first.isStale, isTrue);
      expect(results.first.data.single['id'], 'movie_100');
      expect(results.last.data.single['id'], 'movie_200');
      expect((await db.readCatalog())!.value.single['id'], 'movie_200');
    });

    test('forceRefresh interroge le réseau même si le cache est frais',
        () async {
      await db.saveCatalog([media('movie_1')]);
      remote.rows = [media('movie_2')];
      final results = await db.watchCatalog(forceRefresh: true).toList();
      expect(results.length, 2);
      expect(remote.catalogCalls, 1);
    });

    test('hors connexion : le cache reste affiché, marqué périmé', () async {
      await db.saveCatalog([media('movie_550')]);
      clock = clock.add(const Duration(days: 3));
      remote.offline = true;
      final results = await db.watchCatalog().toList();
      expect(results.length, 2);
      expect(results.last.fromCache, isTrue);
      expect(results.last.isStale, isTrue);
      expect(results.last.error, isA<CineFailure>());
    });

    test('hors connexion et sans cache : l\'erreur est transmise', () {
      remote.offline = true;
      expect(db.watchCatalog().toList(), throwsA(isA<CineFailure>()));
    });
  });

  group('file pending_sync', () {
    test('rejouée dans l\'ordre d\'arrivée', () async {
      await db.enqueuePending(op(SyncOperation.set, 'movie_1'));
      await db.enqueuePending(op(SyncOperation.set, 'movie_2'));
      await db.enqueuePending(op(SyncOperation.delete, 'movie_3'));
      final ops = await db.pendingOperations();
      expect(ops.map((o) => o.docId), ['movie_1', 'movie_2', 'movie_3']);
      expect(ops.first.path, 'users/u1/favorites/movie_1');
      expect(await db.pendingCount(), 3);
    });

    test('payload JSON relu à l\'identique (dates en ISO 8601)', () async {
      await db.enqueuePending(op(SyncOperation.set, 'movie_1', payload: {
        'title': 'Fight Club',
        'tmdb_id': 550,
        'added_at': DateTime.utc(2026, 10, 27, 8),
      }));
      final saved = (await db.pendingOperations()).single;
      expect(saved.operation, SyncOperation.set);
      expect(saved.payload, {
        'title': 'Fight Club',
        'tmdb_id': 550,
        'added_at': '2026-10-27T08:00:00.000Z',
      });
      expect(saved.retryCount, 0);
    });

    test('dernière écriture gagnante : set puis delete → delete seul',
        () async {
      await db.enqueuePending(op(SyncOperation.set, 'movie_1'));
      await db.enqueuePending(op(SyncOperation.set, 'movie_2'));
      await db.enqueuePending(op(SyncOperation.delete, 'movie_1'));
      final ops = await db.pendingOperations();
      expect(ops.map((o) => '${o.operation.value} ${o.docId}'),
          ['set movie_2', 'delete movie_1']);
    });

    test('update après set : un seul set avec les champs fusionnés', () async {
      const notif = 'users/u1/notifications';
      await db.enqueuePending(op(SyncOperation.set, 'n1',
          collection: notif, payload: {'title': 'Dune', 'is_read': false}));
      await db.enqueuePending(op(SyncOperation.update, 'n1',
          collection: notif, payload: {'is_read': true}));
      final saved = (await db.pendingOperations()).single;
      expect(saved.operation, SyncOperation.set);
      expect(saved.payload, {'title': 'Dune', 'is_read': true});
    });

    test('update après delete : ignoré', () async {
      await db.enqueuePending(op(SyncOperation.delete, 'movie_1'));
      await db.enqueuePending(
          op(SyncOperation.update, 'movie_1', payload: {'title': 'x'}));
      final saved = (await db.pendingOperations()).single;
      expect(saved.operation, SyncOperation.delete);
    });

    test('échec : retry_count augmente ; succès : retirée', () async {
      final id = await db.enqueuePending(op(SyncOperation.set, 'movie_1'));
      await db.markPendingFailed(id, 'unavailable');
      await db.markPendingFailed(id, 'unavailable');
      final failed = (await db.pendingOperations()).single;
      expect(failed.retryCount, 2);
      expect(failed.lastError, 'unavailable');

      await db.removePending(id);
      expect(await db.pendingCount(), 0);
    });

    test('opérations séparées par membre', () async {
      await db.enqueuePending(op(SyncOperation.set, 'movie_1'));
      await db.enqueuePending(op(SyncOperation.set, 'movie_1',
          userId: 'u2', collection: 'users/u2/favorites'));
      expect(await db.pendingCount(userId: 'u1'), 1);
      expect((await db.pendingOperations(userId: 'u2')).single.userId, 'u2');
    });
  });

  group('données locales', () {
    test('calendrier : période, plateformes et favoris', () async {
      final day = DateTime.utc(2026, 11, 1, 20);
      await db.saveCalendarEvents([
        event('e1', 'movie_1', day, platform: 'Netflix'),
        event('e2', 'series_2', day.add(const Duration(days: 1)),
            platform: 'Disney Plus'),
        event('e3', 'movie_3', day.add(const Duration(days: 40))),
      ]);
      final november = await db.readCalendarEvents(
          from: DateTime.utc(2026, 11), to: DateTime.utc(2026, 12));
      expect(november.map((e) => e['id']), ['e1', 'e2']);
      expect(november[1]['episode_number'], 2);

      final netflix = await db.readCalendarEvents(platforms: ['Netflix']);
      expect(netflix.single['id'], 'e1');
      final favorites = await db.readCalendarEvents(mediaKeys: ['movie_3']);
      expect(favorites.single['id'], 'e3');

      expect(await db.deleteCalendarEventsBefore(DateTime.utc(2026, 11, 2)), 1);
    });

    test('favoris locaux par membre, les plus récents d\'abord', () async {
      await db.replaceLocalFavorites('u1', [
        {...media('movie_1'), 'added_at': '2026-10-01T00:00:00.000Z'},
        {...media('movie_2'), 'added_at': '2026-10-20T00:00:00.000Z'},
      ]);
      await db.setLocalFavorite('u2', media('movie_9'), true);
      expect((await db.localFavorites('u1')).map((f) => f['id']),
          ['movie_2', 'movie_1']);

      await db.setLocalFavorite('u1', media('movie_2'), false);
      expect((await db.localFavorites('u1')).single['id'], 'movie_1');
      expect((await db.localFavorites('u2')).single['id'], 'movie_9');
    });

    test('recherches récentes : sans doublon, 20 au plus', () async {
      for (var i = 0; i < 25; i++) {
        clock = clock.add(const Duration(minutes: 1));
        await db.addRecentSearch('u1', 'recherche $i');
      }
      clock = clock.add(const Duration(minutes: 1));
      await db.addRecentSearch('u1', '  recherche 10 ');
      await db.addRecentSearch('u1', '   ');

      final all = await db.recentSearches('u1', limit: 50);
      expect(all.length, kMaxRecentSearches);
      expect(all.first, 'recherche 10');
      expect(all.where((q) => q == 'recherche 10').length, 1);
    });

    test('vider le cache garde les données du membre', () async {
      await db.saveCatalog([media('movie_550')]);
      await db.saveHomeSection('trending', [media('movie_550')]);
      await db.saveCalendarEvents(
          [event('e1', 'movie_550', DateTime.utc(2026, 11, 1))]);
      await db.setLocalFavorite('u1', media('movie_550'), true);
      await db.enqueuePending(op(SyncOperation.set, 'movie_550'));

      final size = await db.cacheSizeBytes();
      expect(size, greaterThan(0));
      expect(await db.clearCache(), size);
      expect(await db.cacheSizeBytes(), 0);
      expect(await db.readCatalog(), isNull);
      expect(await db.localFavorites('u1'), isNotEmpty);
      expect(await db.pendingCount(), 1);
    });

    test('données privées effacées, cache public gardé', () async {
      await db.saveCatalog([media('movie_550')]);
      await db.setLocalFavorite('u1', media('movie_550'), true);
      await db.addRecentSearch('u1', 'dune');
      await db.enqueuePending(op(SyncOperation.set, 'movie_550'));

      await db.clearPrivateData();
      expect(await db.localFavorites('u1'), isEmpty);
      expect(await db.recentSearches('u1'), isEmpty);
      expect(await db.pendingCount(), 0);
      expect(await db.readCatalog(), isNotNull);
    });
  });
}
