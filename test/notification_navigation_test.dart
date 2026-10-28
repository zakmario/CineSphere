import 'package:cine_sphere/custom_code/actions/cine_notification_service.dart';
import 'package:cine_sphere/flutter_flow/nav/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_firebase_service.dart';
import 'notification_test_utils.dart';
import 'offline_test_utils.dart';

/// Tap sur une notification -> fiche MediaDetail, par le navigateur global
/// de FlutterFlow (appNavigatorKey), comme dans l'application.
void main() {
  late FakeNotificationStore store;
  late CineNotificationService service;
  late List<Object?> extras;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FakeNotificationStore();
    service = CineNotificationService(
      notifier: FakeNotifier(),
      store: store,
      local: MemoryLocalDb(),
      remote: FakeCineFirebaseService(),
    );
    extras = [];
  });

  Widget app() => MaterialApp.router(
        routerConfig: GoRouter(
          navigatorKey: appNavigatorKey,
          routes: [
            GoRoute(path: '/', builder: (_, __) => const Text('Accueil')),
            GoRoute(
              name: kMediaDetailRoute,
              path: '/mediaDetail',
              builder: (_, state) {
                extras.add(state.extra);
                return Text('Fiche ${state.uri.queryParameters['mediaId']}');
              },
            ),
          ],
        ),
      );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('ouvre la fiche, en glissant du bas, et marque comme lue',
      (tester) async {
    store.add(notificationEntry('e1', at: DateTime(2026, 11, 10)));
    await tester.pumpWidget(app());

    await service.handleTap(
        notificationPayload(mediaType: 'movie', tmdbId: 550, id: 'e1'));
    await settle(tester);

    expect(find.text('Fiche movie_550'), findsOneWidget);
    final extra = extras.last as Map;
    expect(extra[kTransitionInfoKey], same(kNotificationOpenTransition));
    expect(store.docs['e1']!.isRead, isTrue);
  });

  testWidgets('lancement par la notification : attend la première page',
      (tester) async {
    await tester.pumpWidget(const SizedBox());
    await service
        .handleTap(notificationPayload(mediaType: 'series', tmdbId: 1399));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.text('Fiche series_1399'), findsOneWidget);
  });
}
