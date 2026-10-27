import 'dart:convert';

import 'package:cine_sphere/custom_code/actions/cancel_all_notifications.dart';
import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/cine_sync_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/actions/get_unread_notifications_count.dart';
import 'package:cine_sphere/custom_code/actions/mark_all_notifications_read.dart';
import 'package:cine_sphere/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

Map<String, dynamic> release(String id, String key, DateTime at,
    {String? platform, int? season, int? episode}) {
  final parsed = parseMediaKey(key)!;
  return {
    'id': id,
    'media_type': parsed.type,
    'tmdb_id': parsed.tmdbId,
    'media_key': key,
    'title': 'Titre $id',
    'release_date': at.toUtc().toIso8601String(),
    'platform': platform,
    'season_number': season,
    'episode_number': episode,
  };
}

void main() {
  late DateTime clock;
  late FakeCineFirebaseService remote;
  late MemoryLocalDb local;
  late FakeNotifier notifier;
  late FakeNotificationStore store;
  late List<String> opened;
  late CineNotificationService service;

  ScheduledNotification? scheduledFor(String key) =>
      notifier.scheduled[notificationIdFromString(key)];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 11, 10, 9);
    remote = FakeCineFirebaseService();
    local = MemoryLocalDb(now: () => clock)
      ..remoteEvents = [
        release('e1', 'movie_1', DateTime(2026, 11, 12, 20),
            platform: 'Netflix'),
        release('e2', 'series_2', DateTime(2026, 11, 13, 21),
            platform: 'Disney Plus', season: 1, episode: 3),
        release('e3', 'movie_3', DateTime(2026, 11, 14, 20),
            platform: 'Canal+'),
        release('e4', 'movie_4', DateTime(2026, 11, 15, 20),
            platform: 'Prime Video'),
        release('e5', 'series_5', DateTime(2026, 11, 16, 20)),
      ];
    local
      ..setLocalFavorite('u1', {'id': 'series_2'}, true)
      ..setLocalFavorite('u1', {'id': 'movie_3'}, true);
    notifier = FakeNotifier();
    store = FakeNotificationStore();
    opened = [];
    service = CineNotificationService(
      notifier: notifier,
      store: store,
      local: local,
      remote: remote,
      now: () => clock,
      openMedia: opened.add,
    );
  });

  ReleaseReminder reminderOf(int index) =>
      ReleaseReminder.fromEvent(local.remoteEvents[index])!;

  group('fonctions', () {
    test('trois canaux Android', () {
      expect(kNotificationChannels.values.map((c) => c.id), [
        'cinesphere_releases',
        'cinesphere_episodes',
        'cinesphere_reminders',
      ]);
    });

    test('charge utile : type + tmdbId (+ id de la notification)', () {
      final payload =
          notificationPayload(mediaType: 'series', tmdbId: 1399, id: 'e2');
      expect(
          jsonDecode(payload), {'type': 'series', 'tmdbId': 1399, 'id': 'e2'});
      final parsed = parseNotificationPayload(payload)!;
      expect(parsed.mediaKey, 'series_1399');
      expect(parsed.id, 'e2');
      expect(parseNotificationPayload('e2'), isNull);
      expect(parseNotificationPayload('{"type":"x","tmdbId":1}'), isNull);
      expect(parseNotificationPayload(null), isNull);
    });

    test('heure du rappel : la veille à 18 h par défaut', () {
      final releaseAt = DateTime(2026, 11, 20, 21);
      expect(reminderDateFor(releaseAt, now: DateTime(2026, 11, 10)),
          DateTime(2026, 11, 19, 18));
      expect(
          reminderDateFor(releaseAt,
              now: DateTime(2026, 11, 10), dayBefore: false, hour: 9),
          DateTime(2026, 11, 20, 9));
      // Jour J après l'heure de sortie : à la sortie.
      expect(
          reminderDateFor(DateTime(2026, 11, 20, 14),
              now: DateTime(2026, 11, 10), dayBefore: false),
          DateTime(2026, 11, 20, 14));
      // La veille est passée : une heure avant.
      expect(reminderDateFor(releaseAt, now: DateTime(2026, 11, 20, 9)),
          DateTime(2026, 11, 20, 20));
      expect(reminderDateFor(releaseAt, now: DateTime(2026, 11, 20, 20, 30)),
          isNull);
    });

    test('texte d\'un rappel de film et d\'épisode', () {
      expect(
          reminderOf(0).body, 'Sortie le 12 novembre 2026 à 20:00 sur Netflix');
      expect(reminderOf(1).body,
          'Épisode S1 · É3 le 13 novembre 2026 à 21:00 sur Disney Plus');
      expect(reminderOf(0).channel, NotificationChannelKind.reminders);
      expect(
          ReleaseReminder.fromEvent(local.remoteEvents[1], automatic: true)!
              .channel,
          NotificationChannelKind.episodes);
    });
  });

  group('« Me prévenir »', () {
    test(
        'programmé la veille à 18 h sur le canal Rappels, noté dans '
        'Firestore', () async {
      final result = await service.scheduleReminder(reminderOf(0));

      expect(result.at, DateTime(2026, 11, 11, 18));
      final scheduled = scheduledFor('e1')!;
      expect(scheduled.at, DateTime(2026, 11, 11, 18));
      expect(scheduled.channel, NotificationChannelKind.reminders);
      expect(scheduled.title, 'Titre e1');
      expect(parseNotificationPayload(scheduled.payload)!.mediaKey, 'movie_1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(kRemindersKey), ['e1']);
      final entry = store.docs['e1']!;
      expect(entry.scheduledAt, DateTime(2026, 11, 11, 18));
      expect(entry.mediaKeyValue, 'movie_1');
      expect(entry.isRead, isFalse);
    });

    test('réglages : le jour J à 9 h', () async {
      await service.saveSettings(const NotificationSettings(
          time: TimeOfDay(hour: 9, minute: 0), dayBefore: false));
      await pumpEventQueue();
      expect(
          remote.preferences.reminderTime, const TimeOfDay(hour: 9, minute: 0));

      final result = await service.scheduleReminder(reminderOf(0));
      expect(result.at, DateTime(2026, 11, 12, 9));
    });

    test('notifications désactivées : rien n\'est programmé', () async {
      remote.preferences =
          const UserPreferences(userId: 'u1', notificationsEnabled: false);
      final result = await service.scheduleReminder(reminderOf(0));
      expect(result.ok, isFalse);
      expect(result.error, contains('désactivées'));
      expect(notifier.scheduled, isEmpty);
    });

    test('permission refusée : message d\'erreur', () async {
      notifier.permission = false;
      final result = await service.scheduleReminder(reminderOf(0));
      expect(result.error, contains('refusées'));
      expect(store.docs, isEmpty);
    });

    test('annulé : notification, registre et document supprimés', () async {
      await service.scheduleReminder(reminderOf(0));
      await service.cancelReminder('e1');

      expect(scheduledFor('e1'), isNull);
      expect(store.docs, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(kRemindersKey), isEmpty);
      expect(await service.reminders(), isEmpty);
    });
  });

  group('reprogrammation', () {
    test('nouvelle heure : les rappels sont reprogrammés', () async {
      await service.scheduleReminder(reminderOf(0));
      await service.saveSettings(
          const NotificationSettings(time: TimeOfDay(hour: 20, minute: 30)));
      expect(scheduledFor('e1')!.at, DateTime(2026, 11, 11, 20, 30));
    });

    test(
        'notifications automatiques : séries favorites, films favoris ou '
        'des plateformes suivies', () async {
      remote.preferences =
          const UserPreferences(userId: 'u1', favoritePlatforms: ['Netflix']);
      final count = await service.rescheduleAll();

      expect(count, 3);
      expect(
          scheduledFor('auto_e1')!.channel, NotificationChannelKind.releases);
      expect(
          scheduledFor('auto_e2')!.channel, NotificationChannelKind.episodes);
      expect(
          scheduledFor('auto_e3')!.channel, NotificationChannelKind.releases);
      expect(scheduledFor('auto_e4'), isNull);
      expect(scheduledFor('auto_e5'), isNull);
      expect(store.docs.keys, {'auto_e1', 'auto_e2', 'auto_e3'});

      // Deuxième passage : pas de nouveau document Firestore.
      store.calls.clear();
      expect(await service.rescheduleAll(), 3);
      expect(store.calls, isEmpty);
    });

    test('sorties ou séries désactivées', () async {
      remote.preferences = const UserPreferences(
          userId: 'u1',
          notifyReleases: false,
          favoritePlatforms: ['Netflix']);
      await service.rescheduleAll();
      expect(notifier.scheduled.keys, [notificationIdFromString('auto_e2')]);

      remote.preferences =
          const UserPreferences(userId: 'u1', notifyFavoriteSeries: false);
      await service.rescheduleAll();
      expect(scheduledFor('auto_e2'), isNull);
      expect(scheduledFor('auto_e3'), isNotNull);
    });

    test('« Me prévenir » déjà demandé : pas de doublon automatique', () async {
      await service.scheduleReminder(reminderOf(2));
      await service.rescheduleAll();
      expect(scheduledFor('e3'), isNotNull);
      expect(scheduledFor('auto_e3'), isNull);
    });

    test('sortie passée : rappel oublié ; ancien rappel sans détails gardé',
        () async {
      SharedPreferences.setMockInitialValues({
        kRemindersKey: ['ancien'],
      });
      await service.scheduleReminder(reminderOf(0));
      clock = DateTime(2026, 11, 13);
      await service.rescheduleAll();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(kRemindersKey), ['ancien']);
      expect(await service.reminders(), isEmpty);
      expect(scheduledFor('e1'), isNull);
    });

    test('désactivées : tout est annulé', () async {
      await service.scheduleReminder(reminderOf(0));
      final count = await service
          .saveSettings(const NotificationSettings(enabled: false));
      expect(count, 0);
      expect(notifier.scheduled, isEmpty);
      expect(notifier.cancelAllCalls, 1);
      // Le rappel revient si les notifications sont réactivées.
      await service.saveSettings(const NotificationSettings());
      expect(scheduledFor('e1'), isNotNull);
    });

    test('au démarrage : au plus une fois toutes les 6 h', () async {
      await service.rescheduleIfStale();
      expect(notifier.scheduled, isNotEmpty);
      notifier.scheduled.clear();

      clock = clock.add(const Duration(hours: 2));
      await service.rescheduleIfStale();
      expect(notifier.scheduled, isEmpty);

      clock = clock.add(const Duration(hours: 5));
      await service.rescheduleIfStale();
      expect(notifier.scheduled, isNotEmpty);
    });
  });

  group('tap sur une notification', () {
    test('ouvre la fiche et marque la notification comme lue', () async {
      await service.scheduleReminder(reminderOf(0));
      final payload = scheduledFor('e1')!.payload;
      final taps = <String>[];
      service.taps.listen(taps.add);

      notifier.onTap!(payload);
      await pumpEventQueue();

      expect(opened, ['movie_1']);
      expect(taps, ['movie_1']);
      expect(store.docs['e1']!.isRead, isTrue);
    });

    test('notification qui a lancé l\'application', () async {
      notifier.launch = notificationPayload(mediaType: 'series', tmdbId: 2);
      await service.init();
      expect(opened, ['series_2']);
    });

    test('charge utile illisible : rien', () async {
      await service.handleTap('n\'importe quoi');
      expect(opened, isEmpty);
    });
  });

  group('notifications Firestore', () {
    test('écritures par la file hors connexion (pending_sync)', () async {
      final writer = FakeRemoteWriter();
      final sync = CineSyncService(
          local: local,
          remote: remote,
          network: FakeNetwork(),
          writer: writer.call);
      final real = NotificationStore(remote: remote, sync: sync);

      await real
          .save(notificationEntry('e1', at: DateTime.utc(2026, 11, 11, 17)));
      await real.markRead('e1');
      await real.delete('e1');

      expect(writer.sent.map((o) => '${o.operation.value} ${o.path}'), [
        'set users/u1/notifications/e1',
        'update users/u1/notifications/e1',
        'delete users/u1/notifications/e1',
      ]);
      expect(writer.sent.first.payload['scheduled_at'],
          '2026-11-11T17:00:00.000Z');
      expect(writer.sent[1].payload, {'is_read': true});
    });

    test('actions : non lues, tout marquer comme lu, tout annuler', () async {
      CineNotificationService.debugInstance = service;
      addTearDown(() => CineNotificationService.debugInstance = null);
      store
        ..add(notificationEntry('a', at: DateTime(2026, 11, 9)))
        ..add(notificationEntry('b', at: DateTime(2026, 11, 10, 8)))
        ..add(notificationEntry('later', at: DateTime(2026, 11, 20)))
        ..add(
            notificationEntry('read', at: DateTime(2026, 11, 1), isRead: true));

      expect(await getUnreadNotificationsCount(), 2);
      expect(await markAllNotificationsRead(), 2);
      expect(await getUnreadNotificationsCount(), 0);
      expect(store.docs['later']!.isRead, isFalse);

      await service.scheduleReminder(reminderOf(0));
      await cancelAllNotifications();
      expect(notifier.scheduled, isEmpty);
    });
  });
}
