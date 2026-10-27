import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:cine_sphere/custom_code/widgets/profile_stats.dart'
    show watchTimeLabel;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';

void main() {
  group('computeUserStats', () {
    final catalog = {
      'movie_550': {
        'runtime_minutes': 139,
        'genres': ['Drame', 'Thriller'],
      },
      'movie_603': {
        'runtime_minutes': 136,
        'genres': ['Action', 'Science-Fiction'],
      },
      'series_1399': {
        'episodes': 73,
        'genres': ['Drame', 'Science-Fiction'],
      },
      'series_66732': {
        'episodes': 34,
        'genres': ['Drame'],
      },
    };

    test('films, séries, durée, genre le plus fréquent', () {
      final stats = computeUserStats(
        watchedKeys: ['movie_550', 'movie_603', 'series_1399'],
        favoriteKeys: ['series_1399', 'series_66732', 'movie_550'],
        catalogByKey: catalog,
      );
      expect(stats.moviesWatched, 2);
      expect(stats.seriesWatched, 1);
      expect(stats.seriesFollowed, 2);
      expect(stats.watchMinutes, 139 + 136 + 73 * kEpisodeMinutes);
      // Drame : 550, 1399, 66732 (chaque titre compté une fois).
      expect(stats.favoriteGenre, 'Drame');
    });

    test('rien de vu ni de favori', () {
      final stats = computeUserStats(
          watchedKeys: [], favoriteKeys: [], catalogByKey: catalog);
      expect(stats.moviesWatched, 0);
      expect(stats.watchMinutes, 0);
      expect(stats.favoriteGenre, isNull);
    });

    test('titre absent du catalogue ou clé invalide : compté sans durée', () {
      final stats = computeUserStats(
        watchedKeys: ['movie_1', 'series_1399_s1e1', 'movie_550'],
        favoriteKeys: [],
        catalogByKey: catalog,
      );
      expect(stats.moviesWatched, 2);
      expect(stats.seriesWatched, 0);
      expect(stats.watchMinutes, 139);
    });

    test('égalité de genres : ordre alphabétique', () {
      final stats = computeUserStats(
        watchedKeys: ['movie_603'],
        favoriteKeys: [],
        catalogByKey: catalog,
      );
      expect(stats.favoriteGenre, 'Action');
    });
  });

  test('watchTimeLabel', () {
    expect(watchTimeLabel(0), '0 h');
    expect(watchTimeLabel(45), '45 min');
    expect(watchTimeLabel(120), '2 h');
    expect(watchTimeLabel(135), '2 h 15');
    expect(watchTimeLabel(3365), '56 h 05');
  });

  group('ProfileStats', () {
    late FakeCineFirebaseService service;

    setUpAll(() {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() {
      service = FakeCineFirebaseService();
      CineFirebaseService.debugInstance = service;
    });

    tearDown(() => CineFirebaseService.debugInstance = null);

    testWidgets('affiche les 4 statistiques', (tester) async {
      service.stats = const UserStats(
        moviesWatched: 12,
        seriesWatched: 1,
        seriesFollowed: 3,
        watchMinutes: 1530,
        favoriteGenre: 'Drame',
      );
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ProfileStats()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Films vus'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Séries suivies'), findsOneWidget);
      expect(find.text('25 h 30'), findsOneWidget);
      expect(find.text('Drame'), findsOneWidget);
    });

    testWidgets('se met à jour quand un titre est marqué comme vu',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(children: [
            ProfileStats(),
            MarkWatchedButton(mediaId: 'movie_550'),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('—'), findsOneWidget);

      await tester.tap(find.text('Marquer comme vu'));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
      expect(service.calls.where((c) => c == 'fetchMyStats'), hasLength(2));
    });
  });
}
