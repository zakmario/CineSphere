import 'dart:async';

import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:cine_sphere/custom_code/widgets/offline_banner.dart'
    show kSyncedBannerDuration;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fake_firebase_service.dart';
import 'offline_test_utils.dart';

void main() {
  late FakeCineFirebaseService remote;
  late MemoryLocalDb local;
  late FakeNetwork network;
  late FakeRemoteWriter writer;
  late CineSyncService sync;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    remote = FakeCineFirebaseService();
    local = MemoryLocalDb();
    network = FakeNetwork(online: false);
    writer = FakeRemoteWriter();
    sync = CineSyncService(
      local: local,
      remote: remote,
      network: network,
      writer: writer.call,
      fetchFavorites: writer.fetchFavorites,
    );
    CineFirebaseService.debugInstance = remote;
    CineLocalDb.debugInstance = local;
    CineSyncService.debugInstance = sync;
  });

  tearDown(() async {
    CineFirebaseService.debugInstance = null;
    CineLocalDb.debugInstance = null;
    CineSyncService.debugInstance = null;
    await sync.dispose();
    await local.close();
  });

  /// Laisse passer les requêtes SQLite et les animations courtes.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Map<String, dynamic> title(String key, String name, {num popularity = 0}) {
    final parsed = parseMediaKey(key)!;
    return {
      'id': key,
      'media_type': parsed.type,
      'tmdb_id': parsed.tmdbId,
      'title': name,
      'poster_url': null,
      'rating': 8.0,
      'popularity': popularity,
    };
  }

  group('OfflineBanner', () {
    Future<List<String>> pump(WidgetTester tester) async {
      final refreshed = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            OfflineBanner(onBackOnline: () async => refreshed.add('refresh')),
            const Expanded(child: Text('Page')),
          ]),
        ),
      ));
      await settle(tester);
      return refreshed;
    }

    testWidgets('en ligne : rien n\'est affiché', (tester) async {
      network.online = true;
      await pump(tester);
      expect(find.text('Hors connexion'), findsNothing);
      expect(find.text('Page'), findsOneWidget);
    });

    testWidgets('hors connexion : bandeau et modifications en attente',
        (tester) async {
      await local.enqueuePending(favoriteOp('movie_1'));
      await local.enqueuePending(favoriteOp('movie_2'));
      await pump(tester);

      expect(find.text('Hors connexion'), findsOneWidget);
      expect(find.text('2 modifications en attente d\'envoi.'), findsOneWidget);

      await sync.write(favoriteOp('movie_3'));
      await settle(tester);
      expect(find.text('3 modifications en attente d\'envoi.'), findsOneWidget);
    });

    testWidgets(
        'retour du réseau : synchronisation, « À jour », puis '
        'disparition', (tester) async {
      await local.enqueuePending(favoriteOp('movie_1'));
      final refreshed = await pump(tester);
      expect(find.text('Hors connexion'), findsOneWidget);

      network.set(true);
      await settle(tester);

      expect(writer.sent.single.docId, 'movie_1');
      expect(find.text('À jour'), findsOneWidget);
      expect(find.text('1 modification envoyée.'), findsOneWidget);
      expect(refreshed, ['refresh']);

      await tester.pump(kSyncedBannerDuration);
      await settle(tester);
      expect(find.text('À jour'), findsNothing);
    });

    testWidgets(
        'toucher « Hors connexion » appelle onTap, pas pendant la '
        'synchronisation', (tester) async {
      final taps = <String>[];
      final gate = Completer<void>();
      writer.gate = gate;
      await local.enqueuePending(favoriteOp('movie_1'));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            OfflineBanner(onTap: () async => taps.add('tap')),
          ]),
        ),
      ));
      await settle(tester);

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await tester.tap(find.text('Hors connexion'));
      expect(taps, ['tap']);

      network.set(true);
      await settle(tester);
      expect(find.text('Synchronisation en cours…'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      await tester.tap(find.text('Connexion rétablie'));
      expect(taps, ['tap']);

      gate.complete();
      await settle(tester);
    });
  });

  group('OfflineScreen', () {
    Future<({List<String> taps, List<String> back})> pump(
        WidgetTester tester) async {
      final taps = <String>[];
      final back = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: OfflineScreen(
            onItemTap: (id) async => taps.add(id),
            onBackOnline: () async => back.add('back'),
          ),
        ),
      ));
      await settle(tester);
      return (taps: taps, back: back);
    }

    testWidgets('affiche les favoris et le catalogue enregistrés',
        (tester) async {
      await local.saveCatalog([
        title('movie_550', 'Fight Club', popularity: 5),
        title('series_1399', 'Game of Thrones', popularity: 9),
      ]);
      await local.setLocalFavorite(
          'u1', title('movie_27205', 'Inception'), true);
      await local.enqueuePending(favoriteOp('movie_1'));
      final result = await pump(tester);

      expect(find.text('Vous êtes hors connexion'), findsOneWidget);
      expect(find.text('1 modification en attente'), findsOneWidget);
      expect(find.text('Mes favoris'), findsOneWidget);
      expect(find.text('Inception'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Fight Club'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Catalogue enregistré'), findsOneWidget);
      expect(find.text('Game of Thrones'), findsOneWidget);

      await tester.ensureVisible(find.text('Fight Club'));
      await tester.pump();
      await tester.tap(find.text('Fight Club'));
      expect(result.taps, ['movie_550']);
    });

    testWidgets('cache vide : message d\'aide', (tester) async {
      await pump(tester);
      expect(find.textContaining('Aucun contenu enregistré'), findsOneWidget);
    });

    testWidgets(
        '« Réessayer » toujours hors ligne : message ; réseau '
        'revenu : onBackOnline une seule fois', (tester) async {
      final result = await pump(tester);

      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(find.textContaining('Toujours hors connexion'), findsOneWidget);
      expect(result.back, isEmpty);

      network.set(true);
      await settle(tester);
      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(result.back, ['back']);
    });
  });
}
