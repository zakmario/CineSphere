import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

/// Fiche en mémoire, sans images (pas d'accès réseau) ni session
/// (recordView ne fait alors rien).
class _DetailFake extends FakeCineFirebaseService {
  _DetailFake(this.row) : super(userId: null);

  Map<String, dynamic>? row;

  @override
  Future<Map<String, dynamic>?> fetchMedia(String key) async => row;
}

final _dune = <String, dynamic>{
  'id': 'movie_438631',
  'title': 'Dune',
  'media_type': 'movie',
  'status': 'released',
  'rating': 7.8,
  'release_date': '2021-09-15',
  'runtime_minutes': 155,
  'genres': ['Science-Fiction', 'Aventure'],
  'platforms': ['Netflix'],
  'overview': 'Paul Atreides, un jeune homme brillant et doué au destin '
      'plus grand que lui-même, doit se rendre sur la planète la plus '
      'dangereuse de l’univers afin d’assurer l’avenir de sa famille et de '
      'son peuple. Alors que des forces maléfiques se disputent la '
      'possession de l’épice, seuls ceux qui parviennent à dominer leur '
      'peur pourront survivre.',
};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late _DetailFake remote;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = _DetailFake(Map.of(_dune));
    CineFirebaseService.debugInstance = remote;
    CineNotificationService.debugInstance = CineNotificationService(
      notifier: FakeNotifier(),
      store: FakeNotificationStore(),
      local: MemoryLocalDb(),
      remote: remote,
    );
  });

  tearDown(() {
    CineFirebaseService.debugInstance = null;
    CineNotificationService.debugInstance = null;
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MediaDetailView(mediaId: 'movie_438631')),
    ));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('affiche titre, chiffres clés, genres et plateformes',
      (tester) async {
    await pump(tester);

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('FILM'), findsOneWidget);
    expect(find.text('7.8'), findsOneWidget);
    expect(find.text('2021'), findsOneWidget);
    expect(find.text('Durée'), findsOneWidget);
    expect(find.text('Science-Fiction'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le synopsis long se déplie', (tester) async {
    await pump(tester);

    await tester.scrollUntilVisible(find.text('Lire la suite'), 200,
        scrollable: find.byType(Scrollable).first);
    // Sort le bouton de sous la barre du haut (épinglée).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Lire la suite'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Réduire'), findsOneWidget);
  });

  testWidgets('contenu introuvable : message et bouton Réessayer',
      (tester) async {
    remote.row = null;
    await pump(tester);

    expect(find.text('Contenu introuvable.'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
