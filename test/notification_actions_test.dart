import 'package:cine_sphere/custom_code/actions/cancel_release_notification.dart';
import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/get_scheduled_reminders.dart';
import 'package:cine_sphere/custom_code/actions/init_local_notifications.dart';
import 'package:cine_sphere/custom_code/actions/reschedule_all_notifications.dart';
import 'package:cine_sphere/custom_code/actions/schedule_release_notification.dart';
import 'package:cine_sphere/custom_code/actions/show_instant_notification.dart';
import 'package:cine_sphere/flutter_flow/custom_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

/// Actions FlutterFlow des notifications (signatures d'origine gardées) et
/// action d'ancrage cineNotificationService.
void main() {
  late FakeNotifier notifier;
  late FakeCineFirebaseService remote;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifier = FakeNotifier();
    remote = FakeCineFirebaseService();
    CineNotificationService.debugInstance = CineNotificationService(
      notifier: notifier,
      store: FakeNotificationStore(),
      local: MemoryLocalDb(),
      remote: remote,
    );
  });

  tearDown(() => CineNotificationService.debugInstance = null);

  final later = DateTime.now().add(const Duration(days: 2));

  test('initLocalNotifications demande la permission', () async {
    expect(await initLocalNotifications(), isTrue);
    expect(notifier.permissionRequests, 1);

    notifier.permission = false;
    expect(await initLocalNotifications(), isFalse);
  });

  test('scheduleReleaseNotification : canal Rappels, clé gardée une fois',
      () async {
    expect(await scheduleReleaseNotification('e1', 'Dune', 'Demain', later),
        isTrue);
    expect(await scheduleReleaseNotification('e1', 'Dune', 'Demain', later),
        isTrue);

    final scheduled = notifier.scheduled[notificationIdFromString('e1')]!;
    expect(scheduled.title, 'Dune');
    expect(scheduled.at, later);
    expect(scheduled.channel, NotificationChannelKind.reminders);
    expect(await getScheduledReminders(), ['e1']);
  });

  test('scheduleReleaseNotification : date passée ou permission refusée',
      () async {
    expect(
        await scheduleReleaseNotification('e1', 'Dune', 'Hier',
            DateTime.now().subtract(const Duration(hours: 1))),
        isFalse);
    notifier.permission = false;
    expect(await scheduleReleaseNotification('e2', 'Dune', 'Demain', later),
        isFalse);
    expect(notifier.scheduled, isEmpty);
    expect(await getScheduledReminders(), isEmpty);
  });

  test('cancelReleaseNotification annule et oublie le rappel', () async {
    await scheduleReleaseNotification('e1', 'Dune', 'Demain', later);
    await scheduleReleaseNotification('e2', 'Alien', 'Demain', later);
    await cancelReleaseNotification('e1');

    expect(notifier.scheduled.keys, [notificationIdFromString('e2')]);
    expect(await getScheduledReminders(), ['e2']);
  });

  test('showInstantNotification', () async {
    expect(await showInstantNotification('CinéSphère', 'Test'), isTrue);
    expect(notifier.shown, ['CinéSphère']);

    notifier.permission = false;
    expect(await showInstantNotification('CinéSphère', 'Test'), isFalse);
  });

  test('rescheduleAllNotifications et action d\'ancrage', () async {
    expect(await rescheduleAllNotifications(), 0);
    expect(await cineNotificationService(), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kLastRescheduleKey), isNotNull);

    remote.preferences =
        const UserPreferences(userId: 'u1', notificationsEnabled: false);
    expect(await cineNotificationService(), isFalse);
  });

  test('rescheduleAllNotifications : erreur interceptée', () async {
    CineNotificationService.debugInstance = _BrokenService();
    expect(await rescheduleAllNotifications(), 0);
  });
}

class _BrokenService extends CineNotificationService {
  @override
  Future<int> rescheduleAll({NotificationSettings? settings}) async =>
      throw StateError('plugin absent');
}
