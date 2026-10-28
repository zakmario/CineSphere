import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

/// FlutterLocalNotifier contre le canal Android simulé du plugin : vérifie
/// ce qu'Android reçoit vraiment (canaux, mode inexact, fuseau, charge
/// utile) et le retour d'un tap.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const plugin = MethodChannel('dexterous.com/flutter/local_notifications');
  const timezone = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late Map<String, Object?> launch;
  late Object? zone;

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    launch = {'notificationLaunchedApp': false};
    zone = 'Europe/Paris';
    messenger.setMockMethodCallHandler(plugin, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'requestNotificationsPermission' => true,
        'getNotificationAppLaunchDetails' => launch,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(timezone, (call) async {
      if (zone == null) {
        throw PlatformException(code: 'absent');
      }
      return zone;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(plugin, null);
    messenger.setMockMethodCallHandler(timezone, null);
  });

  List<MethodCall> named(String method) =>
      calls.where((c) => c.method == method).toList();

  test('initialisation : fuseau de l\'appareil et trois canaux Android',
      () async {
    final notifier = FlutterLocalNotifier();
    expect(await notifier.initialize((_) {}), isTrue);
    // Une seule initialisation.
    expect(await notifier.initialize((_) {}), isTrue);

    expect(named('initialize'), hasLength(1));
    expect(tz.local.name, 'Europe/Paris');
    expect(
        named('createNotificationChannel')
            .map((c) => (c.arguments as Map)['id']),
        ['cinesphere_releases', 'cinesphere_episodes', 'cinesphere_reminders']);
  });

  test('fuseau inconnu : initialisation quand même', () async {
    zone = null;
    expect(await FlutterLocalNotifier().initialize((_) {}), isTrue);
  });

  test('programmation : canal, mode inexact, heure locale, charge utile',
      () async {
    final notifier = FlutterLocalNotifier();
    await notifier.initialize((_) {});
    final at = DateTime.now().add(const Duration(days: 3));
    final payload = notificationPayload(mediaType: 'movie', tmdbId: 550);

    await notifier.schedule(
      id: 42,
      title: 'Fight Club',
      body: 'Sortie demain',
      at: at,
      channel: NotificationChannelKind.episodes,
      payload: payload,
    );

    final args = named('zonedSchedule').single.arguments as Map;
    expect(args['id'], 42);
    expect(args['title'], 'Fight Club');
    expect(args['payload'], payload);
    expect(args['timeZoneName'], 'Europe/Paris');
    final specifics = args['platformSpecifics'] as Map;
    expect(specifics['channelId'], 'cinesphere_episodes');
    expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
    // Même instant, exprimé dans le fuseau de l'appareil.
    expect(
        tz.TZDateTime.parse(
                tz.local, args['scheduledDateTimeISO8601'] as String)
            .isAtSameMomentAs(at),
        isTrue);
  });

  test('affichage immédiat, annulation, permission', () async {
    final notifier = FlutterLocalNotifier();
    await notifier.initialize((_) {});
    await notifier.show(
        id: 7,
        title: 'Test',
        body: 'Ça marche',
        channel: NotificationChannelKind.reminders);
    await notifier.cancel(7);
    await notifier.cancelAll();
    expect(await notifier.requestPermission(), isTrue);

    final show = named('show').single.arguments as Map;
    expect((show['platformSpecifics'] as Map)['channelId'],
        'cinesphere_reminders');
    expect((named('cancel').single.arguments as Map)['id'], 7);
    expect(named('cancelAll'), hasLength(1));
    expect(named('requestNotificationsPermission'), hasLength(1));
  });

  test('tap sur une notification : la charge utile revient au service',
      () async {
    final taps = <String?>[];
    await FlutterLocalNotifier().initialize(taps.add);

    await messenger.handlePlatformMessage(
      plugin.name,
      plugin.codec
          .encodeMethodCall(const MethodCall('didReceiveNotificationResponse', {
        'notificationId': 42,
        'payload': '{"type":"movie","tmdbId":550}',
        'notificationResponseType': 0,
      })),
      (_) {},
    );
    expect(taps, ['{"type":"movie","tmdbId":550}']);
  });

  test('notification qui a lancé l\'application', () async {
    final notifier = FlutterLocalNotifier();
    expect(await notifier.launchPayload(), isNull);

    launch = {
      'notificationLaunchedApp': true,
      'notificationResponse': {
        'notificationId': 1,
        'notificationResponseType': 0,
        'payload': '{"type":"series","tmdbId":1399}',
      },
    };
    expect(await notifier.launchPayload(), '{"type":"series","tmdbId":1399}');
  });
}
