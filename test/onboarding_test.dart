import 'dart:convert';

import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/complete_onboarding.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/actions/has_completed_onboarding.dart';
import 'package:cine_sphere/custom_code/actions/mark_home_tour_done.dart';
import 'package:cine_sphere/custom_code/actions/reset_onboarding.dart';
import 'package:cine_sphere/custom_code/actions/should_start_home_tour.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

/// Firestore injoignable tant que [offline] est vrai.
class _FlakyFirebaseService extends FakeCineFirebaseService {
  bool offline = false;

  void _check() {
    if (offline) {
      throw const CineFailure(CineFailureKind.network, 'Hors connexion');
    }
  }

  @override
  Future<UserPreferences> fetchPreferences() async {
    _check();
    return super.fetchPreferences();
  }

  @override
  Future<UserPreferences> savePreferences(UserPreferences prefs) async {
    _check();
    return super.savePreferences(prefs);
  }
}

const _choices = OnboardingChoices(
  genreIds: [18],
  genreNames: ['Drame'],
  platforms: ['Netflix'],
  contentTypes: [MediaType.series],
  notificationsEnabled: true,
);

void main() {
  final now = DateTime(2026, 11, 10, 9);
  late _FlakyFirebaseService remote;
  late FakeNotifier notifier;
  late OnboardingService service;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = _FlakyFirebaseService();
    notifier = FakeNotifier();
    service = OnboardingService(
      remote: remote,
      notifications: CineNotificationService(
        notifier: notifier,
        store: FakeNotificationStore(),
        local: MemoryLocalDb(now: () => now),
        remote: remote,
        now: () => now,
      ),
    );
    OnboardingService.debugInstance = service;
  });

  tearDown(() => OnboardingService.debugInstance = null);

  group('OnboardingService', () {
    test('fin du walkthrough : flag sur l\'appareil et dans le profil',
        () async {
      expect(await hasCompletedOnboarding(), isFalse);
      expect(await service.complete(_choices), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kOnboardingDoneKey), isTrue);
      expect(prefs.getStringList(kFavoriteGenreNamesKey), ['Drame']);
      expect(prefs.containsKey(kOnboardingPendingKey), isFalse);

      final saved = remote.preferences;
      expect(saved.onboardingCompleted, isTrue);
      expect(saved.favoriteGenres, [18]);
      expect(saved.favoritePlatforms, ['Netflix']);
      expect(saved.contentTypes, [MediaType.series]);
      expect(remote.savedPreferences, hasLength(1));

      // Réglages des notifications copiés, sans seconde écriture.
      final mirror = jsonDecode(prefs.getString(kNotificationSettingsKey)!);
      expect(mirror['platforms'], ['Netflix']);
      expect(mirror['enabled'], isTrue);
      expect(await hasCompletedOnboarding(), isTrue);
    });

    test('hors connexion : gardé sur l\'appareil, écrit au retour du réseau',
        () async {
      remote.offline = true;
      expect(await service.complete(_choices), isFalse);
      expect(await hasCompletedOnboarding(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kOnboardingPendingKey), isTrue);
      expect(remote.savedPreferences, isEmpty);

      remote.offline = false;
      expect(await hasCompletedOnboarding(), isTrue);
      await pumpEventQueue();
      expect(remote.preferences.onboardingCompleted, isTrue);
      expect(remote.preferences.favoritePlatforms, ['Netflix']);
      expect(prefs.containsKey(kOnboardingPendingKey), isFalse);
    });

    test('choix en attente : n\'écrase pas un profil modifié depuis', () async {
      remote.offline = true;
      await service.complete(_choices);
      remote
        ..offline = false
        ..preferences = const UserPreferences(
          userId: 'u1',
          onboardingCompleted: true,
          favoritePlatforms: ['Canal+'],
        );

      expect(await service.syncPending(), isTrue);
      expect(remote.savedPreferences, isEmpty);
      expect(remote.preferences.favoritePlatforms, ['Canal+']);
    });

    test('réinstallation : le profil Firestore suffit', () async {
      remote.preferences =
          const UserPreferences(userId: 'u1', onboardingCompleted: true);
      expect(await hasCompletedOnboarding(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kOnboardingDoneKey), isTrue);
      expect(await shouldStartHomeTour(), isFalse);
    });

    test('déconnecté ou hors connexion sans flag : à faire', () async {
      remote.userId = null;
      expect(await hasCompletedOnboarding(), isFalse);
      remote
        ..userId = 'u1'
        ..offline = true;
      expect(await hasCompletedOnboarding(), isFalse);
    });

    test('visite guidée : après le walkthrough, une seule fois', () async {
      expect(await shouldStartHomeTour(), isFalse);
      await service.complete(_choices);
      expect(await shouldStartHomeTour(), isTrue);
      await markHomeTourDone();
      expect(await shouldStartHomeTour(), isFalse);

      await resetOnboarding();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kOnboardingDoneKey), isNull);
      expect(prefs.getBool(kHomeTourDoneKey), isNull);
    });

    test('completeOnboarding (noms de genres) : identifiants TMDB', () async {
      await completeOnboarding(['Drame', 'Inconnu']);
      expect(remote.preferences.favoriteGenres, [18]);
      expect(remote.preferences.onboardingCompleted, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(kFavoriteGenreNamesKey), ['Drame', 'Inconnu']);
    });

    test('catalogue injoignable : genres et plateformes par défaut', () async {
      remote
        ..genres = const []
        ..platforms = const [];
      expect(await service.genres(), kFallbackGenres);
      expect(await service.platforms(), kFallbackPlatforms);
    });

    test('choix : aller-retour JSON', () {
      final back = OnboardingChoices.fromJson(
          jsonDecode(jsonEncode(_choices.toJson())) as Map<String, dynamic>);
      expect(back.toJson(), _choices.toJson());
    });
  });

  group('OnboardingWalkthrough', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<List<String>> pumpToPreferences(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final finished = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body:
              OnboardingWalkthrough(onFinish: () async => finished.add('fini')),
        ),
      ));
      await settle(tester);
      await tester.tap(find.text('Passer'));
      await settle(tester);
      return finished;
    }

    FilterChip chip(WidgetTester tester, String label) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));

    testWidgets('Préférences : genres, plateformes, types, notifications',
        (tester) async {
      final finished = await pumpToPreferences(tester);
      expect(find.text('Vos genres préférés'), findsOneWidget);
      expect(find.text('Vos plateformes'), findsOneWidget);
      expect(find.text('Types de contenus'), findsOneWidget);

      await tester.tap(find.text('Drame'));
      await tester.tap(find.text('Netflix'));
      await tester.tap(find.text('Films'));
      await tester.pump();
      // Le dernier type ne peut pas être retiré.
      await tester.tap(find.text('Séries'));
      await tester.pump();
      expect(chip(tester, 'Séries').selected, isTrue);
      expect(chip(tester, 'Films').selected, isFalse);

      await tester.tap(find.text('Commencer'));
      await settle(tester);

      expect(finished, ['fini']);
      expect(notifier.permissionRequests, 1);
      final saved = remote.preferences;
      expect(saved.onboardingCompleted, isTrue);
      expect(saved.favoriteGenres, [18]);
      expect(saved.favoritePlatforms, ['Netflix']);
      expect(saved.contentTypes, [MediaType.series]);
      expect(saved.notificationsEnabled, isTrue);
    });

    testWidgets('autorisation refusée : notifications désactivées',
        (tester) async {
      notifier.permission = false;
      final finished = await pumpToPreferences(tester);
      await tester.tap(find.text('Commencer'));
      await settle(tester);

      expect(find.textContaining('Notifications refusées'), findsOneWidget);
      expect(remote.preferences.notificationsEnabled, isFalse);
      expect(finished, ['fini']);
    });

    testWidgets('sans notifications : pas de demande d\'autorisation',
        (tester) async {
      await pumpToPreferences(tester);
      await tester.tap(find.text('Me prévenir des sorties'));
      await tester.pump();
      await tester.tap(find.text('Commencer'));
      await settle(tester);

      expect(notifier.permissionRequests, 0);
      expect(remote.preferences.notificationsEnabled, isFalse);
    });

    testWidgets('revu depuis Paramètres : choix du profil pré-cochés',
        (tester) async {
      remote.preferences = const UserPreferences(
        userId: 'u1',
        onboardingCompleted: true,
        favoriteGenres: [35],
        favoritePlatforms: ['Disney Plus'],
        contentTypes: [MediaType.movie],
        notificationsEnabled: false,
      );
      await pumpToPreferences(tester);

      expect(chip(tester, 'Comédie').selected, isTrue);
      expect(chip(tester, 'Drame').selected, isFalse);
      expect(chip(tester, 'Disney Plus').selected, isTrue);
      expect(chip(tester, 'Séries').selected, isFalse);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse);
    });
  });

  group('WalkthroughStep', () {
    Future<void> pumpStep(WidgetTester tester, WalkthroughStep step) =>
        tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Center(child: SizedBox(width: 320, child: step)))));

    testWidgets('progression, Passer et Suivant', (tester) async {
      final calls = <String>[];
      await pumpStep(
          tester,
          WalkthroughStep(
            title: 'Recherche',
            text: 'Trouvez un film par son titre.',
            stepNumber: 2,
            stepCount: 4,
            onNext: () async => calls.add('suivant'),
            onSkip: () async => calls.add('passer'),
          ));

      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(find.text('Recherche'), findsOneWidget);
      await tester.tap(find.text('Passer'));
      await tester.tap(find.text('Suivant'));
      expect(calls, ['passer', 'suivant']);
    });

    testWidgets('dernière étape : Terminer, sans Passer', (tester) async {
      await pumpStep(
          tester,
          WalkthroughStep(
            title: 'Profil',
            text: 'Vos statistiques.',
            stepNumber: 4,
            stepCount: 4,
            onNext: () async {},
            onSkip: () async {},
          ));
      expect(find.text('Terminer'), findsOneWidget);
      expect(find.text('Passer'), findsNothing);
    });

    testWidgets('sans actions ni numéro : texte seul', (tester) async {
      await pumpStep(tester,
          const WalkthroughStep(title: 'Calendrier', text: 'Les sorties.'));
      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('Étape'), findsNothing);
    });
  });
}
