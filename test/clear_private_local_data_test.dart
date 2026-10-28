import 'package:cine_sphere/custom_code/actions/clear_private_local_data.dart';
import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/complete_onboarding.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/actions/get_pending_changes_count.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

Map<String, dynamic> media(String key) {
  final parsed = parseMediaKey(key)!;
  return {
    'id': key,
    'media_type': parsed.type,
    'tmdb_id': parsed.tmdbId,
    'title': key,
    'release_date': '2026-11-01T00:00:00.000Z',
  };
}

void main() {
  sqfliteFfiInit();

  late FakeCineFirebaseService remote;
  late CineLocalDb local;
  late FakeNetwork network;
  late FakeRemoteWriter writer;
  late FakeNotifier notifier;
  late CineSyncService sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      kRemindersKey: ['e1'],
      kReminderDetailsKey: '{}',
      kAutomaticRemindersKey: ['auto_e2'],
      kNotificationSettingsKey: '{"enabled":true}',
      kLastRescheduleKey: '2026-10-28T09:00:00.000',
      kOnboardingPendingKey: '{}',
      kFavoriteGenreNamesKey: ['Drame'],
      kOnboardingDoneKey: true,
      kHomeTourDoneKey: true,
      'theme_mode': 'dark',
    });
    remote = FakeCineFirebaseService();
    local = CineLocalDb(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
        remote: remote);
    network = FakeNetwork();
    writer = FakeRemoteWriter();
    notifier = FakeNotifier();
    sync = CineSyncService(
      local: local,
      remote: remote,
      network: network,
      writer: writer.call,
      fetchFavorites: writer.fetchFavorites,
    );
    CineFirebaseService.debugInstance = remote;
    CineLocalDb.debugInstance = local;
    CineSyncService.debugInstance = sync;
    CineNotificationService.debugInstance = CineNotificationService(
      notifier: notifier,
      store: FakeNotificationStore(),
      local: local,
      remote: remote,
    );

    await local.saveCatalog([media('movie_1'), media('series_2')]);
    await local.saveHomeSection('pour_vous', [media('movie_1')]);
    await local.saveCalendarEvents([
      {
        ...media('movie_1'),
        'id': 'e1',
        'media_key': 'movie_1',
      },
    ]);
    await local.setLocalFavorite('u1', media('movie_1'), true);
    await local.addRecentSearch('u1', 'dune');
    await local.enqueuePending(favoriteOp('series_2'));
    await notifier.schedule(
      id: 1,
      title: 'Rappel',
      body: 'Demain',
      at: DateTime(2026, 11, 1),
      channel: NotificationChannelKind.reminders,
    );
  });

  tearDown(() async {
    CineFirebaseService.debugInstance = null;
    CineLocalDb.debugInstance = null;
    CineSyncService.debugInstance = null;
    CineNotificationService.debugInstance = null;
    await sync.dispose();
    await local.close();
  });

  Future<void> expectPrivateDataCleared() async {
    expect(await local.localFavorites('u1'), isEmpty);
    expect(await local.recentSearches('u1'), isEmpty);
    expect(await local.pendingCount(), 0);
    expect(await local.readHomeSection('pour_vous'), isNull);
    // Cache public gardé : consultable hors connexion après reconnexion.
    expect((await local.readCatalog())!.value, hasLength(2));
    expect(await local.readCalendarEvents(), hasLength(1));

    expect(notifier.scheduled, isEmpty);
    expect(notifier.cancelAllCalls, 1);
    final prefs = await SharedPreferences.getInstance();
    for (final key in kPrivatePreferenceKeys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(prefs.getBool(kOnboardingDoneKey), isTrue);
    expect(prefs.getBool(kHomeTourDoneKey), isTrue);
    expect(prefs.getString('theme_mode'), 'dark');
  }

  test('en ligne : modifications envoyées puis données privées effacées',
      () async {
    expect(await getPendingChangesCount(), 1);
    expect(await clearPrivateLocalData(), 0);

    expect(writer.sent.single.docId, 'series_2');
    await expectPrivateDataCleared();
    expect(await getPendingChangesCount(), 0);
  });

  test('hors connexion : modifications perdues comptées, tout est effacé',
      () async {
    network.online = false;
    expect(await clearPrivateLocalData(), 1);

    expect(writer.sent, isEmpty);
    await expectPrivateDataCleared();
  });

  test('envoi refusé (ex. permission) : compté comme perdu, effacé quand même',
      () async {
    writer.errors['series_2'] = 'permission-denied';
    // Erreur non réseau : l'opération reste en file (nouvel essai plus tard).
    final lost = await clearPrivateLocalData();
    expect(lost, 1);
    expect(writer.sent, isEmpty);
    await expectPrivateDataCleared();
  });

  test('compte supprimé : rien n\'est envoyé, tout est effacé', () async {
    remote.userId = null;
    expect(await clearPrivateLocalData(), 1);

    expect(writer.sent, isEmpty);
    await expectPrivateDataCleared();
  });

  test('web (sans SQLite) : notifications et préférences quand même', () async {
    final web = CineLocalDb(supported: false, remote: remote);
    CineLocalDb.debugInstance = web;
    expect(await getPendingChangesCount(), 0);
    expect(await clearPrivateLocalData(), 0);

    expect(notifier.scheduled, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(kRemindersKey), isFalse);
    expect(prefs.getBool(kOnboardingDoneKey), isTrue);
  });
}
