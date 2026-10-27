import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';

void main() {
  late FakeCineFirebaseService service;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeCineFirebaseService();
    CineFirebaseService.debugInstance = service;
  });

  tearDown(() => CineFirebaseService.debugInstance = null);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: PreferencesPanel())),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> waitSave(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
  }

  testWidgets('genres et plateformes : choix groupés en une écriture',
      (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Drame'));
    await tester.tap(find.widgetWithText(FilterChip, 'Netflix'));
    await tester.pump();
    expect(service.savedPreferences, isEmpty);

    await waitSave(tester);
    expect(service.savedPreferences, hasLength(1));
    expect(service.preferences.favoriteGenres, [18]);
    expect(service.preferences.favoritePlatforms, ['Netflix']);
    // « Pour vous » lit les genres par leur nom.
    final local = await SharedPreferences.getInstance();
    expect(local.getStringList('cs_favorite_genres'), ['Drame']);

    await tester.tap(find.widgetWithText(FilterChip, 'Drame'));
    await waitSave(tester);
    expect(service.preferences.favoriteGenres, isEmpty);
  });

  testWidgets('thème : Clair enregistré dans les préférences', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Clair'));
    await waitSave(tester);
    expect(service.preferences.themeMode, AppThemeMode.light);
  });

  testWidgets('types de contenus : au moins un reste choisi', (tester) async {
    await pump(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Films'));
    await waitSave(tester);
    expect(service.preferences.contentTypes, [MediaType.series]);

    await tester.tap(find.widgetWithText(FilterChip, 'Séries'));
    await waitSave(tester);
    expect(service.preferences.contentTypes, [MediaType.series]);
  });

  testWidgets('déconnecté : message, mais thème et cache restent disponibles',
      (tester) async {
    service.userId = null;
    await pump(tester);
    expect(find.text('Connectez-vous pour régler vos préférences.'),
        findsOneWidget);
    expect(find.text('Sombre'), findsOneWidget);
    expect(find.text('Vider le cache'), findsOneWidget);
  });
}
