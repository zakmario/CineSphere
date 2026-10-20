import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() {
    // Pas d'accès réseau pendant les tests : on n'essaie pas de télécharger
    // les polices Google.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('MediaCard', () {
    testWidgets('affiche titre, type, note et année', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 160,
        height: 320,
        child: MediaCard(
          title: 'Inception',
          mediaType: 'movie',
          rating: 8.8,
          releaseDate: DateTime(2010, 7, 16),
        ),
      )));

      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('Film'), findsOneWidget);
      expect(find.text('★ 8.8'), findsOneWidget);
      expect(find.text('2010'), findsOneWidget);
    });

    testWidgets('affiche un compte à rebours pour une sortie à venir',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(SizedBox(
        width: 160,
        height: 320,
        child: MediaCard(
          title: 'One Piece',
          mediaType: 'series',
          releaseDate: DateTime(now.year, now.month, now.day + 5),
        ),
      )));

      expect(find.text('Série'), findsOneWidget);
      expect(find.text('★ —'), findsOneWidget);
      expect(find.text('Dans 5 jours'), findsOneWidget);
    });

    testWidgets('déclenche onTap', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(_wrap(SizedBox(
        width: 160,
        height: 320,
        child: MediaCard(
          title: 'Dune',
          onTap: () async => tapped++,
        ),
      )));

      await tester.tap(find.text('Dune'));
      expect(tapped, 1);
    });
  });

  group('OnboardingWalkthrough', () {
    testWidgets('fait défiler les 4 étapes puis le choix des genres',
        (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingWalkthrough()));
      await tester.pump();

      expect(find.text('Découvrir'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);

      for (final title in ['Rechercher', 'Organiser', 'Ne rien manquer']) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
      }

      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(find.text('Vos genres préférés'), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);

      // Supabase n'est pas initialisé dans les tests : la liste par défaut
      // des genres est utilisée.
      await tester.tap(find.text('Comédie'));
      await tester.pump();
      final chip = tester.widget<FilterChip>(
          find.widgetWithText(FilterChip, 'Comédie'));
      expect(chip.selected, isTrue);
    });

    testWidgets('"Passer" mène directement au choix des genres',
        (tester) async {
      await tester.pumpWidget(_wrap(const OnboardingWalkthrough()));
      await tester.pump();

      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(find.text('Vos genres préférés'), findsOneWidget);
    });
  });
}
