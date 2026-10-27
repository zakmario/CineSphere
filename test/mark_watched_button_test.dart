import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';

const _mediaId = 'movie_550';

void main() {
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

  Future<void> pump(WidgetTester tester, {List<bool>? changes}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MarkWatchedButton(
          mediaId: _mediaId,
          onChanged: (v) async => changes?.add(v),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('non vu : marquer comme vu puis retirer', (tester) async {
    final changes = <bool>[];
    await pump(tester, changes: changes);
    expect(find.text('Marquer comme vu'), findsOneWidget);

    await tester.tap(find.text('Marquer comme vu'));
    await tester.pumpAndSettle();
    expect(find.text('Vu'), findsOneWidget);
    expect(find.text('Ajouté à vos titres vus'), findsOneWidget);
    expect(service.watched, {_mediaId});

    await tester.tap(find.text('Vu'));
    await tester.pumpAndSettle();
    expect(find.text('Marquer comme vu'), findsOneWidget);
    expect(service.watched, isEmpty);
    expect(changes, [true, false]);
    expect(service.calls, [
      'isWatched $_mediaId',
      'setWatched $_mediaId true',
      'setWatched $_mediaId false',
    ]);
  });

  testWidgets('hors connexion : « Vu » tout de suite, sans attendre Firestore',
      (tester) async {
    service.holdWrites = true;
    await pump(tester);
    await tester.tap(find.text('Marquer comme vu'));
    await tester.pump();
    expect(find.text('Vu'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await service.flushWrites();
    await tester.pumpAndSettle();
    expect(find.text('Vu'), findsOneWidget);
  });

  testWidgets('écriture refusée : retour à « Marquer comme vu » et message',
      (tester) async {
    final changes = <bool>[];
    service.failWrites = true;
    await pump(tester, changes: changes);
    await tester.tap(find.text('Marquer comme vu'));
    await tester.pumpAndSettle();
    expect(find.text('Marquer comme vu'), findsOneWidget);
    expect(find.text('Pas de connexion Internet.'), findsOneWidget);
    expect(changes, [true, false]);
  });

  testWidgets('deux boutons du même titre restent synchronisés',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          MarkWatchedButton(mediaId: _mediaId),
          FavoriteButton(mediaId: _mediaId),
          FavoriteButton(mediaId: _mediaId),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsNWidgets(2));
    expect(find.text('Ajouté aux favoris'), findsOneWidget);
    expect(service.favorites, {_mediaId});
    // Le bouton « vu » n'est pas concerné.
    expect(find.text('Marquer comme vu'), findsOneWidget);
  });

  testWidgets('déjà vu au chargement', (tester) async {
    service.watched.add(_mediaId);
    await pump(tester);
    expect(find.text('Vu'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('déconnecté : non vu, sans requête', (tester) async {
    service.userId = null;
    await pump(tester);
    expect(find.text('Marquer comme vu'), findsOneWidget);
    expect(service.calls, isEmpty);
  });
}
