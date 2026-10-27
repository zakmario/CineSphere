import 'package:cine_sphere/custom_code/actions/check_internet_connection.dart';
import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/clear_local_cache.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/actions/get_local_cache_size.dart';
import 'package:cine_sphere/custom_code/actions/save_to_sqlite.dart';
import 'package:cine_sphere/custom_code/actions/sync_sqlite_with_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_firebase_service.dart';
import 'offline_test_utils.dart';

void main() {
  sqfliteFfiInit();

  late FakeCineFirebaseService remote;
  late CineLocalDb local;
  late FakeNetwork network;
  late FakeRemoteWriter writer;
  late CineSyncService sync;

  CineSyncService service({CineLocalDb? db}) => CineSyncService(
        local: db ?? local,
        remote: remote,
        network: network,
        writer: writer.call,
        fetchFavorites: writer.fetchFavorites,
      );

  setUp(() {
    remote = FakeCineFirebaseService();
    local = CineLocalDb(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
        remote: remote);
    network = FakeNetwork();
    writer = FakeRemoteWriter();
    sync = service();
  });

  tearDown(() async {
    await sync.dispose();
    await local.close();
  });

  group('écriture', () {
    test('en ligne : envoyée tout de suite, rien en file', () async {
      expect(await sync.write(favoriteOp('movie_1')), isTrue);
      expect(writer.sent.single.docId, 'movie_1');
      expect(await local.pendingCount(), 0);
    });

    test('hors connexion : mise en file, événement « queued »', () async {
      network.online = false;
      await sync.start();
      final events = <SyncEvent>[];
      sync.events.listen(events.add);

      expect(await sync.write(favoriteOp('movie_1')), isFalse);
      expect(writer.sent, isEmpty);
      expect(await local.pendingCount(), 1);
      await pumpEventQueue();
      expect(events.single.kind, SyncEventKind.queued);
      expect(events.single.remaining, 1);
    });

    test('réseau perdu pendant l\'envoi : mise en file, état hors ligne',
        () async {
      writer.errors['movie_1'] = 'unavailable';
      expect(await sync.write(favoriteOp('movie_1')), isFalse);
      expect(sync.isOnline, isFalse);
      expect(await local.pendingCount(), 1);
    });

    test('écriture refusée (droits) : erreur levée, pas de file', () async {
      writer.errors['movie_1'] = 'permission-denied';
      expect(
          sync.write(favoriteOp('movie_1')),
          throwsA(isA<CineFailure>()
              .having((f) => f.kind, 'kind', CineFailureKind.forbidden)));
      await pumpEventQueue();
      expect(await local.pendingCount(), 0);
    });

    test('web (sans SQLite) : envoyée directement à Firestore', () async {
      final web = service(db: CineLocalDb(supported: false));
      network.online = false;
      expect(await web.write(favoriteOp('movie_1')), isTrue);
      await pumpEventQueue();
      expect(writer.sent.single.docId, 'movie_1');
    });
  });

  group('retour du réseau', () {
    setUp(() async {
      network.online = false;
      await sync.start();
      await sync.write(favoriteOp('movie_1'));
      await sync.write(favoriteOp('movie_2'));
      await sync.write(favoriteOp('movie_1', operation: SyncOperation.delete));
    });

    test(
        'file rejouée dans l\'ordre, dernière écriture gagnante, '
        'puis événement de rafraîchissement', () async {
      writer.favorites = [
        {'id': 'movie_2', 'title': 'Deux', 'added_at': '2026-10-28T10:00:00Z'},
      ];
      final synced =
          sync.events.firstWhere((e) => e.kind == SyncEventKind.synced);

      network.set(true);
      final event = await synced;

      expect(writer.sent.map((o) => '${o.operation.value} ${o.docId}'),
          ['set movie_2', 'delete movie_1']);
      expect(event.synced, 2);
      expect(event.remaining, 0);
      expect(sync.isOnline, isTrue);
      expect(await local.pendingCount(), 0);
      expect((await local.localFavorites('u1')).single['title'], 'Deux');
    });

    test(
        'réseau perdu en cours : arrêt, la suite reste en file sans '
        'compter d\'échec', () async {
      writer.errors['movie_1'] = 'unavailable';
      final event = await sync.syncNow();

      expect(event.interrupted, isTrue);
      expect(event.synced, 1);
      expect(event.remaining, 1);
      expect(sync.isOnline, isFalse);
      expect((await local.pendingOperations()).single.retryCount, 0);
    });

    test(
        'opération refusée : réessayée puis abandonnée après '
        '$kMaxSyncRetries échecs', () async {
      writer.errors['movie_2'] = 'permission-denied';
      for (var i = 1; i < kMaxSyncRetries; i++) {
        final event = await sync.syncNow();
        expect(event.failed, 1);
        expect((await local.pendingOperations()).single.retryCount, i);
      }
      final last = await sync.syncNow();
      expect(last.dropped, 1);
      expect(await local.pendingCount(), 0);
      // L'opération suivante (delete movie_1) est passée dès le 1er essai.
      expect(writer.sent.single.docId, 'movie_1');
    });

    test('un seul passage à la fois', () async {
      final first = sync.syncNow();
      final second = sync.syncNow();
      expect(identical(first, second), isTrue);
      await first;
      expect(writer.sent.length, 2);
    });
  });

  test('seules les opérations du membre connecté sont rejouées', () async {
    await local.enqueuePending(favoriteOp('movie_1'));
    await local.enqueuePending(favoriteOp('movie_9', userId: 'u2'));
    final event = await sync.syncNow();
    expect(writer.sent.single.docId, 'movie_1');
    expect(event.remaining, 0);
    expect(await local.pendingCount(userId: 'u2'), 1);
  });

  test('déconnecté : rien n\'est rejoué', () async {
    remote.userId = null;
    await local.enqueuePending(favoriteOp('movie_1'));
    await sync.syncNow();
    expect(writer.sent, isEmpty);
  });

  group('actions FlutterFlow', () {
    setUp(() {
      CineFirebaseService.debugInstance = remote;
      CineLocalDb.debugInstance = local;
      CineSyncService.debugInstance = sync;
    });

    tearDown(() {
      CineFirebaseService.debugInstance = null;
      CineLocalDb.debugInstance = null;
      CineSyncService.debugInstance = null;
    });

    test('saveToSqlite : titre, section de l\'accueil, sorties', () async {
      expect(
          await saveToSqlite('cached_movies', '550', {'title': 'Fight Club'}),
          isTrue);
      final movie = await local.readMedia('movie_550');
      expect(movie!.value['title'], 'Fight Club');
      expect(movie.value['media_type'], 'movie');

      expect(
          await saveToSqlite('cached_home_sections', 'trending', [
            {'id': 'series_1399', 'title': 'GoT'},
          ]),
          isTrue);
      expect((await local.readHomeSection('trending'))!.value.single['id'],
          'series_1399');

      expect(
          await saveToSqlite('calendar_events', '', [
            {
              'id': 'e1',
              'media_type': 'movie',
              'tmdb_id': 550,
              'release_date': '2026-11-01T20:00:00Z',
            },
          ]),
          isTrue);
      expect((await local.readCalendarEvents()).single['id'], 'e1');
    });

    test('saveToSqlite refuse une table ou des données invalides', () async {
      expect(await saveToSqlite('pending_sync', 'x', {'a': 1}), isFalse);
      expect(await saveToSqlite('cached_movies', 'abc', {'a': 1}), isFalse);
      expect(await saveToSqlite('cached_movies', '550', null), isFalse);
    });

    test('taille du cache puis clearLocalCache', () async {
      expect(await getLocalCacheSize(), '0 o');
      await saveToSqlite('cached_movies', '550', {'title': 'Fight Club'});
      final size = await getLocalCacheSize();
      expect(size, endsWith(' o'));
      expect(await clearLocalCache(), 'Cache vidé : $size libérés');
      expect(await getLocalCacheSize(), '0 o');
    });

    test('checkInternetConnection suit le réseau', () async {
      expect(await checkInternetConnection(), isTrue);
      network.online = false;
      expect(await checkInternetConnection(), isFalse);
    });

    test('syncSqliteWithFirestore renvoie le nombre d\'envois', () async {
      await local.enqueuePending(favoriteOp('movie_1'));
      await local.enqueuePending(favoriteOp('movie_2'));
      expect(await syncSqliteWithFirestore(), 2);
      expect(await syncSqliteWithFirestore(), 0);
    });
  });

  test('formatBytes', () {
    expect(formatBytes(0), '0 o');
    expect(formatBytes(512), '512 o');
    expect(formatBytes(48 * 1024), '48 Ko');
    expect(formatBytes(1258291), '1,2 Mo');
    expect(formatBytes(3 * 1024 * 1024), '3 Mo');
  });
}
