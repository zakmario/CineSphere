import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'fake_firebase_service.dart';

/// Catalogue en mémoire (sans affiches : pas d'accès réseau).
class _CatalogFake extends FakeCineFirebaseService {
  @override
  Future<List<Map<String, dynamic>>> catalog({bool refresh = false}) async => [
        {
          'id': 'm1',
          'title': 'Dune',
          'overview': 'Désert et épice',
          'media_type': 'movie',
          'rating': 8.2,
          'popularity': 90,
          'genres': ['Science-Fiction'],
        },
        {
          'id': 's1',
          'title': 'Arcane',
          'overview': 'Piltover et Zaun',
          'media_type': 'series',
          'rating': 9.0,
          'popularity': 80,
          'genres': ['Animation'],
        },
        {
          'id': 'm2',
          'title': 'Cats',
          'overview': 'Comédie musicale',
          'media_type': 'movie',
          'rating': 2.8,
          'popularity': 10,
          'genres': ['Comédie'],
        },
      ];
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => CineFirebaseService.debugInstance = _CatalogFake());
  tearDown(() => CineFirebaseService.debugInstance = null);

  testWidgets('affiche le catalogue trié par popularité', (tester) async {
    await tester.pumpWidget(_wrap(const CatalogBrowser()));
    await tester.pumpAndSettle();

    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Arcane'), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('3 titres'), findsOneWidget);
    expect(find.text('Vous avez tout vu'), findsOneWidget);
  });

  testWidgets('le sélecteur Films / Séries filtre par type', (tester) async {
    await tester.pumpWidget(_wrap(const CatalogBrowser()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Séries'));
    await tester.pumpAndSettle();
    expect(find.text('Arcane'), findsOneWidget);
    expect(find.text('Dune'), findsNothing);

    await tester.tap(find.text('Tous'));
    await tester.pumpAndSettle();
    expect(find.text('Dune'), findsOneWidget);
  });

  testWidgets('la recherche cherche aussi dans le synopsis', (tester) async {
    await tester.pumpWidget(_wrap(const CatalogBrowser()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'épice');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('Arcane'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Aucun résultat pour « zzz »'), findsOneWidget);

    await tester.tap(find.text('Effacer les filtres'));
    await tester.pumpAndSettle();
    expect(find.text('Cats'), findsOneWidget);
  });

  testWidgets('la feuille de filtres applique un genre', (tester) async {
    await tester.pumpWidget(_wrap(const CatalogBrowser()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filtres'));
    await tester.pumpAndSettle();
    expect(find.text('Note minimale'), findsOneWidget);

    await tester.tap(find.text('Comédie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appliquer'));
    await tester.pumpAndSettle();

    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('Dune'), findsNothing);
    expect(find.text('1'), findsOneWidget); // pastille du bouton Filtres
  });
}
