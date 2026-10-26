import 'package:cine_sphere/custom_code/actions/firestore_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firestore_service.dart';

const _mediaId = '22222222-2222-2222-2222-222222222222';

void main() {
  late FakeFirestoreService service;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    service = FakeFirestoreService();
    FirestoreService.debugInstance = service;
  });

  tearDown(() => FirestoreService.debugInstance = null);

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
      'toggleWatched $_mediaId',
      'toggleWatched $_mediaId',
    ]);
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
