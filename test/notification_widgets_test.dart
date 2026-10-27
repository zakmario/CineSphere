import 'package:cine_sphere/custom_code/actions/cine_models.dart';
import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/custom_code/actions/firebase_service.dart';
import 'package:cine_sphere/custom_code/widgets/index.dart';
import 'package:cine_sphere/custom_code/widgets/notification_settings_panel.dart'
    show kSettingsSaveDelay;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

void main() {
  final now = DateTime(2026, 11, 10, 9);
  late FakeCineFirebaseService remote;
  late FakeNotifier notifier;
  late FakeNotificationStore store;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    remote = FakeCineFirebaseService();
    notifier = FakeNotifier();
    store = FakeNotificationStore();
    CineFirebaseService.debugInstance = remote;
    CineNotificationService.debugInstance = CineNotificationService(
      notifier: notifier,
      store: store,
      local: MemoryLocalDb(now: () => now),
      remote: remote,
      now: () => now,
    );
  });

  tearDown(() {
    CineFirebaseService.debugInstance = null;
    CineNotificationService.debugInstance = null;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await settle(tester);
  }

  group('NotificationBell', () {
    testWidgets(
        'badge : non lues déjà remises seulement, mis à jour en '
        'direct', (tester) async {
      store
        ..add(notificationEntry('a', at: DateTime(2026, 11, 9)))
        ..add(notificationEntry('b', at: DateTime(2026, 11, 10, 8)))
        ..add(notificationEntry('futur', at: DateTime(2026, 11, 20)))
        ..add(
            notificationEntry('lue', at: DateTime(2026, 11, 1), isRead: true));
      var taps = 0;
      await pumpApp(tester, NotificationBell(onTap: () async => taps++));

      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip('Notifications, 2 non lues'), findsOneWidget);

      await store.markRead('a');
      await settle(tester);
      expect(find.text('1'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
    });

    testWidgets('plus de 9 : « 9+ » ; aucune : pas de badge', (tester) async {
      for (var i = 0; i < 12; i++) {
        store.add(notificationEntry('n$i', at: DateTime(2026, 11, 9, i)));
      }
      await pumpApp(tester, const NotificationBell());
      expect(find.text('9+'), findsOneWidget);

      for (var i = 0; i < 12; i++) {
        await store.markRead('n$i');
      }
      await settle(tester);
      expect(find.text('9+'), findsNothing);
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });
  });

  group('NotificationsCenter', () {
    testWidgets(
        'liste remise, la plus récente d\'abord, sans les rappels à '
        'venir', (tester) async {
      store
        ..add(notificationEntry('vieille', at: DateTime(2026, 11, 8)))
        ..add(notificationEntry('recente', at: DateTime(2026, 11, 10, 8)))
        ..add(notificationEntry('futur', at: DateTime(2026, 11, 20)));
      await pumpApp(tester, const NotificationsCenter());

      expect(find.text('2 non lues'), findsOneWidget);
      final titles = tester
          .widgetList<Text>(find.textContaining('Titre '))
          .map((t) => t.data)
          .toList();
      expect(titles, ['Titre recente', 'Titre vieille']);
      expect(find.textContaining('il y a'), findsNWidgets(2));
    });

    testWidgets('pagination au scroll', (tester) async {
      for (var i = 0; i < 25; i++) {
        store.add(notificationEntry('n$i',
            at: DateTime(2026, 11, 10, 8).subtract(Duration(hours: i))));
      }
      await pumpApp(tester, const NotificationsCenter(pageSize: 20));
      expect(store.calls, ['fetchPage 0']);

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await settle(tester);
      expect(store.calls, ['fetchPage 0', 'fetchPage 20']);
      await tester.scrollUntilVisible(find.text('Titre n24'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Titre n24'), findsOneWidget);
    });

    testWidgets('tap : marquée comme lue et fiche ouverte', (tester) async {
      store.add(notificationEntry('e1',
          at: DateTime(2026, 11, 10, 8), mediaType: 'series', tmdbId: 1399));
      final opened = <String>[];
      await pumpApp(tester,
          NotificationsCenter(onOpenMedia: (id) async => opened.add(id)));

      await tester.tap(find.text('Titre e1'));
      await settle(tester);
      expect(opened, ['series_1399']);
      expect(store.docs['e1']!.isRead, isTrue);
      expect(find.text('Tout est lu'), findsOneWidget);
    });

    testWidgets('« Marquer comme lu » sans ouvrir la fiche', (tester) async {
      store.add(notificationEntry('e1', at: DateTime(2026, 11, 10, 8)));
      final opened = <String>[];
      await pumpApp(tester,
          NotificationsCenter(onOpenMedia: (id) async => opened.add(id)));

      await tester.tap(find.byTooltip('Marquer comme lu'));
      await settle(tester);
      expect(store.calls, contains('markRead e1'));
      expect(opened, isEmpty);
    });

    testWidgets('tout marquer comme lu', (tester) async {
      store
        ..add(notificationEntry('a', at: DateTime(2026, 11, 9)))
        ..add(notificationEntry('b', at: DateTime(2026, 11, 10, 8)));
      await pumpApp(tester, const NotificationsCenter());

      await tester.tap(find.text('Tout marquer comme lu'));
      await settle(tester);
      expect(find.text('2 notifications marquées comme lues'), findsOneWidget);
      expect(find.text('Tout est lu'), findsOneWidget);
      expect(store.docs.values.every((n) => n.isRead), isTrue);
    });

    testWidgets('vide, puis déconnecté', (tester) async {
      await pumpApp(tester, const NotificationsCenter());
      expect(find.textContaining('Aucune notification'), findsOneWidget);

      store.uid = null;
      await pumpApp(tester, NotificationsCenter(key: UniqueKey()));
      expect(find.textContaining('Connectez-vous'), findsOneWidget);
    });
  });

  group('NotificationSettingsPanel', () {
    Future<void> pumpPanel(WidgetTester tester) => pumpApp(tester,
        const SingleChildScrollView(child: NotificationSettingsPanel()));

    Future<void> waitSave(WidgetTester tester) async {
      await tester.pump(kSettingsSaveDelay);
      await settle(tester);
    }

    testWidgets('sorties, séries, plateformes : une écriture groupée',
        (tester) async {
      await pumpPanel(tester);
      expect(find.text('18:00'), findsOneWidget);

      await tester.tap(find.text('Sorties de films'));
      await tester.tap(find.widgetWithText(FilterChip, 'Netflix'));
      await tester.pump();
      expect(remote.savedPreferences, isEmpty);

      await waitSave(tester);
      expect(remote.savedPreferences, hasLength(1));
      expect(remote.preferences.notifyReleases, isFalse);
      expect(remote.preferences.favoritePlatforms, ['Netflix']);
      expect(find.text('0 programmée'), findsOneWidget);
    });

    testWidgets('« Le jour J » gardé sur l\'appareil', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('Le jour J'));
      await waitSave(tester);

      final settings = await CineNotificationService.instance.loadSettings();
      expect(settings.dayBefore, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kNotificationSettingsKey),
          contains('"day_before":false'));
    });

    testWidgets('désactiver annule tout', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('Notifications'));
      await waitSave(tester);
      expect(notifier.cancelAllCalls, 1);
      expect(remote.preferences.notificationsEnabled, isFalse);
      expect(find.text('Aucune notification ne sera envoyée'), findsOneWidget);
    });

    testWidgets('réactiver sans permission : message, reste désactivé',
        (tester) async {
      remote.preferences =
          const UserPreferences(userId: 'u1', notificationsEnabled: false);
      notifier.permission = false;
      await pumpPanel(tester);
      await tester.tap(find.text('Notifications'));
      await settle(tester);
      expect(
          find.textContaining('Autorisez les notifications'), findsOneWidget);
      expect(find.text('Aucune notification ne sera envoyée'), findsOneWidget);
    });

    testWidgets('tester une notification', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('Tester une notification'));
      await settle(tester);
      expect(notifier.shown, ['CinéSphère']);
    });

    testWidgets('l\'heure ouvre le sélecteur', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.text('18:00'));
      await tester.pumpAndSettle();
      expect(find.text('Heure du rappel'), findsNWidgets(2));
    });
  });
}
