import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/release_calendar.dart';
import 'package:cine_sphere/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

/// Sortie `releaseEvents` au format [releaseEventRow] ; [at] en heure locale.
Map<String, dynamic> release(String id, String key, DateTime at,
    {String? platform, int? season, int? episode}) {
  final parsed = parseMediaKey(key)!;
  return {
    'id': id,
    'media_type': parsed.type,
    'tmdb_id': parsed.tmdbId,
    'media_key': key,
    'title': 'Titre $id',
    'poster_url': null,
    'release_date': at.toUtc().toIso8601String(),
    'platform': platform,
    'season_number': season,
    'episode_number': episode,
  };
}

void main() {
  group('fonctions du calendrier', () {
    test('période chargée : le mois et 7 jours autour', () {
      final range = calendarRangeFor(DateTime(2026, 11, 15));
      expect(range.from, DateTime(2026, 10, 25));
      expect(range.to, DateTime(2026, 12, 8));
      final december = calendarRangeFor(DateTime(2026, 12, 31));
      expect(december.to, DateTime(2027, 1, 8));
    });

    test('filtres : plateformes et favoris', () {
      final events = [
        release('e1', 'movie_1', DateTime(2026, 11, 10, 20),
            platform: 'Netflix'),
        release('e2', 'series_2', DateTime(2026, 11, 10, 21),
            platform: 'Disney Plus'),
        release('e3', 'movie_3', DateTime(2026, 11, 12)),
      ];
      expect(filterReleaseEvents(events).length, 3);
      expect(
          filterReleaseEvents(events, platforms: {'Netflix'})
              .map((e) => e['id']),
          ['e1']);
      expect(
          filterReleaseEvents(events,
              favoritesOnly: true,
              favoriteKeys: {'movie_3', 'series_2'}).map((e) => e['id']),
          ['e2', 'e3']);
      expect(filterReleaseEvents(events, favoritesOnly: true), isEmpty);
    });

    test('regroupement par jour local, dans l\'ordre de l\'heure', () {
      final days = groupReleaseEventsByDay([
        release('late', 'movie_1', DateTime(2026, 11, 10, 22)),
        release('early', 'movie_2', DateTime(2026, 11, 10, 8)),
        release('next', 'movie_3', DateTime(2026, 11, 11, 0, 30)),
      ]);
      expect(days[DateTime.utc(2026, 11, 10)]!.map((e) => e['id']),
          ['early', 'late']);
      expect(days[DateTime.utc(2026, 11, 11)]!.single['id'], 'next');
    });

    test('libellé d\'épisode', () {
      expect(
          episodeLabel(
              release('e', 'series_1', DateTime(2026), season: 2, episode: 5)),
          'S2 · É5');
      expect(episodeLabel(release('e', 'series_1', DateTime(2026))), 'Série');
    });
  });

  group('ReleaseCalendar', () {
    final today = DateTime(2026, 11, 10, 9);
    late MemoryLocalDb local;
    late FakeCineFirebaseService remote;
    late FakeNotifier notifier;
    late FakeNotificationStore store;
    late List<String> taps;

    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      remote = FakeCineFirebaseService();
      local = MemoryLocalDb(now: () => today)
        ..remoteEvents = [
          release('e1', 'movie_1', DateTime(2026, 11, 10, 20),
              platform: 'Netflix'),
          release('e2', 'series_2', DateTime(2026, 11, 10, 21),
              platform: 'Disney Plus', season: 1, episode: 2),
          release('e3', 'movie_3', DateTime(2026, 11, 12, 20)),
        ];
      CineFirebaseService.debugInstance = remote;
      CineLocalDb.debugInstance = local;
      CineSyncService.debugInstance =
          CineSyncService(local: local, remote: remote, network: FakeNetwork());
      notifier = FakeNotifier();
      store = FakeNotificationStore();
      CineNotificationService.debugInstance = CineNotificationService(
          notifier: notifier,
          store: store,
          local: local,
          remote: remote,
          now: () => today);
      taps = [];
    });

    tearDown(() {
      CineFirebaseService.debugInstance = null;
      CineLocalDb.debugInstance = null;
      CineSyncService.debugInstance = null;
      CineNotificationService.debugInstance = null;
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester, {String? view}) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReleaseCalendar(
            initialView: view,
            onItemTap: (id) async => taps.add(id),
          ),
        ),
      ));
      await settle(tester);
    }

    Color dotColor(WidgetTester tester, String id) =>
        ((tester.widget<Container>(find.byKey(ValueKey('dot-$id'))).decoration
                as BoxDecoration)
            .color)!;

    testWidgets('points or (film) et violet (épisode), liste du jour',
        (tester) async {
      await pump(tester);
      final context = tester.element(find.byType(ReleaseCalendar));
      final theme = FlutterFlowTheme.of(context);

      expect(dotColor(tester, 'e1'), theme.primary);
      expect(dotColor(tester, 'e2'), theme.secondary);
      expect(find.byKey(const ValueKey('dot-e3')), findsOneWidget);

      expect(find.textContaining('2 sorties'), findsOneWidget);
      expect(find.text('Titre e1'), findsOneWidget);
      expect(find.text('Film • 20:00 • Netflix'), findsOneWidget);
      expect(find.text('S1 · É2 • 21:00 • Disney Plus'), findsOneWidget);
      // Les sorties sont enregistrées pour l'affichage hors connexion.
      expect(local.calendar.length, 3);

      await tester.tap(find.text('Titre e2'));
      expect(taps, ['series_2']);
    });

    testWidgets('choisir un autre jour affiche ses sorties', (tester) async {
      await pump(tester);
      await tester.tap(find.text('12'));
      await settle(tester);
      expect(find.text('Titre e3'), findsOneWidget);
      expect(find.text('Titre e1'), findsNothing);
    });

    testWidgets('filtre par plateforme', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Netflix'));
      await settle(tester);
      expect(find.text('Titre e1'), findsOneWidget);
      expect(find.text('Titre e2'), findsNothing);
      expect(find.byKey(const ValueKey('dot-e3')), findsNothing);
    });

    testWidgets('« Mes favoris » ne garde que les titres favoris',
        (tester) async {
      await local.setLocalFavorite(
          'u1', {'id': 'movie_3', 'title': 'Trois'}, true);
      await pump(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Mes favoris'));
      await settle(tester);

      expect(find.text('Aucune sortie ce jour-là avec ces filtres.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('dot-e1')), findsNothing);
      expect(find.byKey(const ValueKey('dot-e3')), findsOneWidget);
    });

    testWidgets('un favori ajouté ailleurs apparaît tout de suite',
        (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Mes favoris'));
      await settle(tester);
      expect(find.byKey(const ValueKey('dot-e1')), findsNothing);

      await remote.setFavorite('movie_1', true);
      await settle(tester);
      expect(find.byKey(const ValueKey('dot-e1')), findsOneWidget);
    });

    testWidgets('« Me prévenir » programme le rappel, puis l\'annule',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Me prévenir').first);
      await settle(tester);

      // La veille à 18 h est passée : une heure avant la sortie de 20 h.
      final scheduled = notifier.scheduled.values.single;
      expect(scheduled.title, 'Titre e1');
      expect(scheduled.body, 'Sortie le 10 novembre 2026 à 20:00 sur Netflix');
      expect(scheduled.at, DateTime(2026, 11, 10, 19));
      expect(store.docs.keys, ['e1']);
      expect(find.textContaining('à 19:00'), findsOneWidget);
      expect(find.byTooltip('Supprimer le rappel'), findsOneWidget);

      await tester.tap(find.byTooltip('Supprimer le rappel'));
      await settle(tester);
      expect(find.text('Rappel supprimé'), findsOneWidget);
      expect(notifier.scheduled, isEmpty);
      expect(find.text('Me prévenir'), findsNWidgets(2));
    });

    testWidgets('hors connexion : sorties enregistrées et mention',
        (tester) async {
      local
        ..calendar.addAll(local.remoteEvents)
        ..calendarCachedAt = DateTime(2026, 11, 8)
        ..offline = true;
      await pump(tester);
      expect(find.text('Titre e1'), findsOneWidget);
      expect(find.textContaining('Hors connexion · enregistré le 8 novembre'),
          findsOneWidget);
    });

    testWidgets('hors connexion sans cache : message', (tester) async {
      local.offline = true;
      await pump(tester);
      expect(find.textContaining('ce mois n\'a pas encore été enregistré'),
          findsOneWidget);
    });

    testWidgets('vue semaine puis mois', (tester) async {
      await pump(tester, view: 'week');
      expect(find.text('Semaine'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('25'), findsNothing);

      await tester.tap(find.text('Semaine'));
      await settle(tester);
      expect(find.text('Mois'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });
  });
}
