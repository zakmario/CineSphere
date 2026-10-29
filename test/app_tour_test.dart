import 'package:cine_sphere/custom_code/actions/app_tour.dart';
import 'package:cine_sphere/custom_code/actions/complete_onboarding.dart';
import 'package:cine_sphere/flutter_flow/nav/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _labels = ['Accueil', 'Catalogue', 'Favoris', 'Inconnu'];

/// Page avec une barre de navigation, comme NavBarPage de FlutterFlow.
Widget _app() => MaterialApp(
      navigatorKey: appNavigatorKey,
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: [
            for (final label in _labels)
              BottomNavigationBarItem(
                  icon: const Icon(Icons.circle), label: label),
          ],
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('buildTourSteps', () {
    test('accueil, un onglet par libellé, conclusion', () {
      final steps =
          buildTourSteps(const Rect.fromLTWH(0, 700, 400, 56), _labels);

      expect(steps.map((s) => s.title), [
        'Bienvenue sur CinéSphère',
        'Accueil',
        'Catalogue et recherche',
        'Vos favoris',
        'Inconnu',
        'Vous êtes prêt !',
      ]);
      expect(steps.first.target, isNull);
      expect(steps.last.target, isNull);
      // Onglets de même largeur, de gauche à droite.
      expect(steps[1].target, const Rect.fromLTWH(0, 700, 100, 56));
      expect(steps[3].target, const Rect.fromLTWH(200, 700, 100, 56));
      expect(steps[4].text, contains('« Inconnu »'));
    });
  });

  group('AppTour', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<bool> start(WidgetTester tester, Future<bool> Function() run) async {
      await tester.pumpWidget(_app());
      final shown = run();
      await settle(tester);
      return shown;
    }

    testWidgets('Suivant, Retour puis Passer : guide terminé', (tester) async {
      expect(await start(tester, AppTour.start), isTrue);
      expect(find.text('Bienvenue sur CinéSphère'), findsOneWidget);
      expect(find.text('ÉTAPE 1 SUR 6'), findsOneWidget);

      await tester.tap(find.text('Commencer la visite'));
      await settle(tester);
      expect(find.text('Catalogue et recherche'), findsNothing);
      expect(find.text('ÉTAPE 2 SUR 6'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await settle(tester);
      expect(find.text('Catalogue et recherche'), findsOneWidget);

      await tester.tap(find.text('Retour'));
      await settle(tester);
      expect(find.text('ÉTAPE 2 SUR 6'), findsOneWidget);

      await tester.tap(find.text('Passer'));
      await settle(tester);
      expect(AppTour.isShowing, isFalse);
      expect(find.textContaining('ÉTAPE'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kHomeTourDoneKey), isTrue);
    });

    testWidgets('jusqu’au bout : « C’est parti » ferme le guide',
        (tester) async {
      await start(tester, AppTour.start);
      await tester.tap(find.text('Commencer la visite'));
      await settle(tester);
      for (var i = 0; i < _labels.length; i++) {
        await tester.tap(find.text('Suivant'));
        await settle(tester);
      }
      expect(find.text('Vous êtes prêt !'), findsOneWidget);
      expect(find.text('Passer'), findsNothing);

      await tester.tap(find.text('C’est parti'));
      await settle(tester);
      expect(AppTour.isShowing, isFalse);
    });

    testWidgets('après l’onboarding : une seule fois', (tester) async {
      SharedPreferences.setMockInitialValues({kOnboardingDoneKey: true});
      expect(await start(tester, AppTour.startAfterOnboarding), isTrue);
      await tester.tap(find.text('Passer'));
      await settle(tester);

      expect(await start(tester, AppTour.startAfterOnboarding), isFalse);
      expect(find.textContaining('ÉTAPE'), findsNothing);
    });

    testWidgets('onboarding pas fait : pas de guide', (tester) async {
      expect(await start(tester, AppTour.startAfterOnboarding), isFalse);
    });
  });
}
