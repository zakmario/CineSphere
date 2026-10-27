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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReviewsSection(mediaId: _mediaId),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('sans avis : état vide et bouton pour donner le sien',
      (tester) async {
    await pump(tester);
    expect(find.text('Aucune note'), findsOneWidget);
    expect(find.text('Aucun avis pour l\'instant. Soyez le premier !'),
        findsOneWidget);
    expect(find.text('Donner mon avis'), findsOneWidget);
  });

  testWidgets('publier un avis : note obligatoire, puis carte « Votre avis »',
      (tester) async {
    await pump(tester);
    await tapVisible(tester, find.text('Donner mon avis'));

    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();
    expect(find.text('Choisissez une note.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('star8')));
    await tester.enterText(find.byType(TextField), 'Culte');
    await tester.tap(find.text('Publier'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('createReview 8 Culte false'));
    expect(find.text('Avis publié.'), findsOneWidget);
    expect(find.text('Votre avis'), findsOneWidget);
    expect(find.text('8/10'), findsOneWidget);
    expect(find.text('Culte'), findsOneWidget);
    expect(find.text('★ 8,0'), findsOneWidget);
    expect(find.text('1 avis'), findsOneWidget);
    expect(find.text('Donner mon avis'), findsNothing);
  });

  testWidgets('modifier puis supprimer son avis', (tester) async {
    service.addReview('u1', 7, content: 'Pas mal', username: 'moi');
    await pump(tester);
    expect(find.text('7/10'), findsOneWidget);

    await tapVisible(tester, find.text('Modifier'));
    expect(find.text('Modifier votre avis'), findsOneWidget);
    expect(find.text('7/10'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('star9')));
    await tester.tap(find.text('Avis privé'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(service.calls, contains('updateReview r1 9 Pas mal true'));
    expect(find.text('Avis modifié.'), findsOneWidget);
    expect(find.text('9/10'), findsOneWidget);
    expect(find.text('Privé'), findsOneWidget);
    // Un avis privé ne compte pas dans la moyenne publique.
    expect(find.text('Aucune note'), findsOneWidget);

    await tapVisible(tester, find.text('Supprimer'));
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer').last);
    await tester.pumpAndSettle();
    expect(service.calls, contains('deleteReview r1'));
    expect(find.text('Avis supprimé.'), findsOneWidget);
    expect(find.text('Donner mon avis'), findsOneWidget);
  });

  testWidgets('like optimiste, annulé si Firestore refuse', (tester) async {
    service.addReview('u2', 6, content: 'Bien', username: 'bob');
    await pump(tester);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    await tapVisible(tester, find.byIcon(Icons.favorite_border));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(service.likedReviews, {'r1'});

    service.failLikes = true;
    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Pas de connexion Internet.'), findsOneWidget);
  });

  testWidgets('avis paginés par 20 : « Voir plus d\'avis » charge la suite',
      (tester) async {
    for (var i = 1; i <= 25; i++) {
      service.addReview('autre$i', 5, username: 'membre$i');
    }
    await pump(tester);
    expect(find.text('membre25'), findsOneWidget);
    expect(find.text('membre5'), findsNothing);

    await tapVisible(tester, find.text('Voir plus d\'avis'));
    expect(service.calls, ['fetchReviews 0', 'fetchReviews 20']);
    expect(find.text('membre1'), findsOneWidget);
    expect(find.text('Voir plus d\'avis'), findsNothing);
  });
}
