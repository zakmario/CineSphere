// Tests d'intégration du membre 3 (walkthrough, notifications, SQLite, hors
// connexion, déconnexion), à lancer sur un émulateur ou un téléphone
// Android (SQLite et les notifications programmées n'existent pas sur le
// web) :
//
//   flutter test integration_test/membre3_test.dart -d <id de l'appareil>
//
// Le paquet integration_test n'est pas dans pubspec.yaml : FlutterFlow ne
// lit pas les dépendances « sdk: flutter » et affiche alors l'erreur
// « Unrecognized dependency format ». L'ajouter le temps du test, sans le
// pousser vers FlutterFlow ni le commiter :
//
//   dev_dependencies:
//     integration_test:
//       sdk: flutter
//
// puis `git checkout pubspec.yaml pubspec.lock` une fois le test terminé.
//
// Contrairement aux tests de test/, tout tourne sur l'appareil : vraie base
// sqflite (fichier séparé de celle de l'application) et vrai plugin
// flutter_local_notifications (Android). Firestore reste remplacé par les
// faux de test/ : pas de compte ni de réseau nécessaires, et aucune donnée
// écrite dans la vraie base Firebase.
//
// Attention : le test de déconnexion annule toutes les notifications
// programmées de l'application sur l'appareil de test.

import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/complete_onboarding.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/actions/sign_out_cleanup.dart';
import 'package:cine_sphere/custom_code/widgets/onboarding_walkthrough.dart';
import 'package:cine_sphere/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../test/fake_firebase_service.dart';
import '../test/notification_test_utils.dart';
import '../test/offline_test_utils.dart';

/// Vrai plugin de notifications, sans la fenêtre système « Autoriser les
/// notifications ? » (Android 13+), qui bloquerait le test. La
/// programmation fonctionne même sans l'autorisation : seul l'affichage en
/// dépend.
class _GrantedNotifier extends FlutterLocalNotifier {
  @override
  Future<bool> requestPermission() async => true;
}

const _testDbName = 'membre3_integration_test.db';

ReleaseReminder _reminder(String key, DateTime releaseAt) => ReleaseReminder(
      key: key,
      eventId: key,
      mediaType: 'movie',
      tmdbId: 550,
      title: 'Film de test',
      releaseAt: releaseAt,
    );

/// Identifiants des notifications programmées dans Android.
Future<List<int>> _pendingIds() async =>
    (await FlutterLocalNotificationsPlugin().pendingNotificationRequests())
        .map((r) => r.id)
        .toList();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String dbPath;
  late FakeCineFirebaseService remote;
  late CineLocalDb local;
  late FakeNetwork network;
  late FakeRemoteWriter writer;
  late CineSyncService sync;
  late CineNotificationService notifications;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    await (await SharedPreferences.getInstance()).clear();
    dbPath = '${await getDatabasesPath()}/$_testDbName';
    await deleteDatabase(dbPath);

    remote = FakeCineFirebaseService();
    local = CineLocalDb(path: dbPath, remote: remote);
    network = FakeNetwork();
    writer = FakeRemoteWriter();
    sync = CineSyncService(
      local: local,
      remote: remote,
      network: network,
      writer: writer.call,
      fetchFavorites: writer.fetchFavorites,
    );
    notifications = CineNotificationService(
      notifier: _GrantedNotifier(),
      store: FakeNotificationStore(),
      local: local,
      remote: remote,
    );
    CineFirebaseService.debugInstance = remote;
    CineLocalDb.debugInstance = local;
    CineSyncService.debugInstance = sync;
    CineNotificationService.debugInstance = notifications;
    OnboardingService.debugInstance =
        OnboardingService(remote: remote, notifications: notifications);
  });

  tearDown(() async {
    await notifications.cancelAll();
    CineFirebaseService.debugInstance = null;
    CineLocalDb.debugInstance = null;
    CineSyncService.debugInstance = null;
    CineNotificationService.debugInstance = null;
    OnboardingService.debugInstance = null;
    await sync.dispose();
    await local.close();
    await deleteDatabase(dbPath);
  });

  testWidgets('walkthrough complet : profil Firestore et flag sur l\'appareil',
      (tester) async {
    var finished = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OnboardingWalkthrough(onFinish: () async => finished = true),
      ),
    ));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }

    for (final label in ['Drame', 'Netflix']) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(finished, isTrue);
    expect(remote.preferences.onboardingCompleted, isTrue);
    expect(remote.preferences.favoritePlatforms, ['Netflix']);
    expect(remote.preferences.notificationsEnabled, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kOnboardingDoneKey), isTrue);
    expect(prefs.getStringList(kFavoriteGenreNamesKey), ['Drame']);
  });

  testWidgets('« Me prévenir » : rappel programmé dans Android puis annulé',
      (tester) async {
    const key = 'integration_e1';
    final id = notificationIdFromString(key);

    final result = await notifications.scheduleReminder(
        _reminder(key, DateTime.now().add(const Duration(days: 3))));
    expect(result.ok, isTrue, reason: result.error);
    expect(result.at!.isAfter(DateTime.now()), isTrue);
    expect(await _pendingIds(), contains(id));
    expect((await notifications.reminders()).map((r) => r.key), [key]);

    await notifications.cancelReminder(key);
    expect(await _pendingIds(), isNot(contains(id)));
    expect(await notifications.reminders(), isEmpty);
  });

  testWidgets('SQLite sur l\'appareil : schéma à jour et cache calendrier',
      (tester) async {
    final version =
        await (await local.database).rawQuery('PRAGMA user_version');
    expect(version.single.values.single, kLocalDbMigrations.length);

    await local.saveCalendarEvents([
      {
        'id': 'e_offline',
        'media_key': 'series_1399',
        'media_type': 'series',
        'tmdb_id': 1399,
        'title': 'Série',
        'release_date': DateTime.utc(2030, 1, 15).toIso8601String(),
      },
    ]);
    final events = await local.readCalendarEvents(
        from: DateTime.utc(2030, 1, 1), to: DateTime.utc(2030, 2, 1));
    expect(events.single['id'], 'e_offline');

    await local.clearCache();
    expect(
        await local.readCalendarEvents(
            from: DateTime.utc(2030, 1, 1), to: DateTime.utc(2030, 2, 1)),
        isEmpty);
  });

  testWidgets('hors connexion : écriture en file, envoyée au retour du réseau',
      (tester) async {
    network.online = false;
    await sync.checkConnection();

    expect(await sync.write(favoriteOp('movie_550')), isFalse);
    expect(writer.sent, isEmpty);
    expect(await local.pendingCount(), 1);

    network.online = true;
    await sync.checkConnection();
    await sync.syncNow();

    expect(writer.sent.single.docId, 'movie_550');
    expect(await local.pendingCount(), 0);
  });

  testWidgets('déconnexion : envoi, notifications annulées, SQLite privé vidé',
      (tester) async {
    const key = 'integration_logout';
    final result = await notifications.scheduleReminder(
        _reminder(key, DateTime.now().add(const Duration(days: 3))));
    expect(result.ok, isTrue, reason: result.error);
    await local.enqueuePending(favoriteOp('movie_680'));
    await local.setLocalFavorite('u1', {'id': 'movie_680'}, true);

    await signOutCleanup();

    expect(writer.sent.single.docId, 'movie_680');
    expect(await _pendingIds(), isEmpty);
    expect(await local.pendingCount(), 0);
    expect(await local.localFavorites('u1'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(kRemindersKey), isFalse);
  });
}
