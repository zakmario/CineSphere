import 'package:cine_sphere/custom_code/actions/cine_local_db.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/actions/sign_out_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryLocalDb local;
  late FakeNotifier notifier;
  late FakeRemoteWriter writer;
  late CineSyncService sync;

  setUp(() {
    final remote = FakeCineFirebaseService();
    local = MemoryLocalDb();
    notifier = FakeNotifier();
    writer = FakeRemoteWriter();
    sync = CineSyncService(
      local: local,
      remote: remote,
      network: FakeNetwork(),
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
  });

  tearDown(() async {
    CineFirebaseService.debugInstance = null;
    CineLocalDb.debugInstance = null;
    CineSyncService.debugInstance = null;
    CineNotificationService.debugInstance = null;
    await sync.dispose();
  });

  test('efface rappels et genres du membre, garde l\'onboarding', () async {
    SharedPreferences.setMockInitialValues({
      'cs_reminders': ['movie_550_2026-11-01'],
      'cs_favorite_genres': ['Drame'],
      'cs_onboarding_done': true,
    });

    await signOutCleanup();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('cs_reminders'), isNull);
    expect(prefs.getStringList('cs_favorite_genres'), isNull);
    expect(prefs.getBool('cs_onboarding_done'), isTrue);
  });

  test(
      'membre 3 : modifications envoyées, notifications annulées, SQLite '
      'privé vidé', () async {
    SharedPreferences.setMockInitialValues({});
    await local.enqueuePending(favoriteOp('movie_1'));
    await local.setLocalFavorite('u1', {'id': 'movie_1'}, true);

    await signOutCleanup();

    expect(writer.sent.single.docId, 'movie_1');
    expect(notifier.cancelAllCalls, 1);
    expect(await local.pendingCount(), 0);
    expect(await local.localFavorites('u1'), isEmpty);
  });
}
